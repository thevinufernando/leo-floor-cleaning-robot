import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'debug_log.dart';

enum RelayConnectionState { disconnected, connecting, connected, error }

class LeoRelayClient {
  LeoRelayClient({DebugLog? log}) : log = log ?? DebugLog();

  final DebugLog log;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _pongWatchdog;
  Timer? _welcomeTimeout;
  Timer? _reconnectTimer;

  bool _wantConnected = false;
  bool _manualDisconnect = false;
  int _reconnectAttempt = 0;
  DateTime? _lastPongAt;

  final _stateController =
      StreamController<RelayConnectionState>.broadcast();
  final _armedController = StreamController<bool>.broadcast();
  final _robotOnlineController = StreamController<bool>.broadcast();
  final _mapController = StreamController<Uint8List?>.broadcast();
  final _eventController = StreamController<String>.broadcast();

  Stream<RelayConnectionState> get state => _stateController.stream;
  Stream<bool> get armed => _armedController.stream;
  Stream<bool> get robotOnline => _robotOnlineController.stream;
  Stream<Uint8List?> get mapPng => _mapController.stream;
  /// User-facing short events (snackbars).
  Stream<String> get events => _eventController.stream;

  RelayConnectionState currentState = RelayConnectionState.disconnected;
  bool currentArmed = false;
  bool currentRobotOnline = false;
  DateTime? lastRobotStatusAt;
  DateTime? lastMapAt;
  String? lastError;
  int? lastMapWidth;
  int? lastMapHeight;

  static const _welcomeTimeoutSec = 8;
  static const _pongTimeoutSec = 45;
  static const _maxReconnectAttempts = 5;

  Future<void> connect() async {
    _manualDisconnect = false;
    _wantConnected = true;
    _reconnectAttempt = 0;
    await _openSocket();
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _wantConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeSocket(RelayConnectionState.disconnected, reason: 'manual disconnect');
  }

  Future<void> _openSocket() async {
    await _closeSocket(null, silent: true);
    _setState(RelayConnectionState.connecting);
    lastError = null;
    log.i('connecting to ${LeoConfig.relayUrl} robotId=${LeoConfig.robotId}');

    try {
      final uri = Uri.parse(LeoConfig.relayUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(
        const Duration(seconds: _welcomeTimeoutSec),
        onTimeout: () => throw TimeoutException('socket ready timeout'),
      );

      _sub = _channel!.stream.listen(
        _onData,
        onError: (Object e) {
          log.e('socket error: $e');
          lastError = '$e';
          _setState(RelayConnectionState.error);
          _emitEvent('socket error');
          _scheduleReconnect();
        },
        onDone: () {
          log.w('socket closed by peer');
          _setRobotOnline(false, reason: 'socket closed');
          if (!_manualDisconnect) {
            _setState(RelayConnectionState.disconnected);
            _scheduleReconnect();
          }
        },
      );

      _send({
        'type': 'hello',
        'role': 'phone',
        'robotId': LeoConfig.robotId,
        'token': LeoConfig.token,
      });
      log.d('hello sent');

      _welcomeTimeout?.cancel();
      _welcomeTimeout = Timer(const Duration(seconds: _welcomeTimeoutSec), () {
        if (currentState == RelayConnectionState.connecting) {
          lastError = 'welcome timeout';
          log.e('no welcome within ${_welcomeTimeoutSec}s');
          _setState(RelayConnectionState.error);
          _emitEvent('Connect timeout — check URL / network');
          _closeSocket(RelayConnectionState.error, silent: true);
          _scheduleReconnect();
        }
      });

      _lastPongAt = DateTime.now();
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _send({'type': 'ping'});
      });
      _pongWatchdog?.cancel();
      _pongWatchdog = Timer.periodic(const Duration(seconds: 10), (_) {
        final last = _lastPongAt;
        if (last == null) return;
        if (DateTime.now().difference(last).inSeconds > _pongTimeoutSec) {
          log.e('pong watchdog expired');
          lastError = 'pong timeout';
          _emitEvent('Relay unresponsive — reconnecting');
          _closeSocket(RelayConnectionState.error, silent: true);
          _scheduleReconnect();
        }
      });
    } catch (e) {
      lastError = '$e';
      log.e('connect failed: $e');
      _setState(RelayConnectionState.error);
      _emitEvent('Connect failed: $e');
      _scheduleReconnect();
    }
  }

  Future<void> _closeSocket(
    RelayConnectionState? nextState, {
    bool silent = false,
    String? reason,
  }) async {
    _welcomeTimeout?.cancel();
    _welcomeTimeout = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongWatchdog?.cancel();
    _pongWatchdog = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (!silent && reason != null) {
      log.i(reason);
    }
    if (nextState != null) {
      _setRobotOnline(false, reason: reason);
      if (currentArmed) {
        _setArmed(false, reason: 'connection closed');
      }
      _setState(nextState);
    }
  }

  void _scheduleReconnect() {
    if (!_wantConnected || _manualDisconnect) return;
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      log.e('gave up after $_maxReconnectAttempts reconnect attempts');
      _emitEvent('Reconnect gave up — tap Connect');
      _wantConnected = false;
      return;
    }
    final delays = [2, 5, 10, 10, 10];
    final delay = delays[_reconnectAttempt.clamp(0, delays.length - 1)];
    _reconnectAttempt++;
    log.w('reconnect attempt $_reconnectAttempt in ${delay}s');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_wantConnected && !_manualDisconnect) {
        _openSocket();
      }
    });
  }

  void setArmed(bool armed) {
    if (currentState != RelayConnectionState.connected) {
      log.w('arm ignored — relay not connected');
      _emitEvent('Connect to relay first');
      return;
    }
    if (!currentRobotOnline) {
      log.w('arm ignored — robot offline');
      _emitEvent('Robot offline — command not delivered');
      return;
    }
    log.i('set_armed request armed=$armed');
    _send({'type': 'set_armed', 'armed': armed});
  }

  void _send(Map<String, Object?> payload) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(payload));
    } catch (e) {
      log.e('send failed: $e');
    }
  }

  void _onData(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      switch (type) {
        case 'welcome':
          _welcomeTimeout?.cancel();
          _welcomeTimeout = null;
          _reconnectAttempt = 0;
          _setState(RelayConnectionState.connected);
          final online = msg['robotOnline'] == true;
          _setRobotOnline(online, reason: 'welcome');
          log.i('welcome robotOnline=$online phoneCount=${msg['phoneCount']}');
          break;
        case 'status':
          lastRobotStatusAt = DateTime.now();
          if (msg.containsKey('armed')) {
            _setArmed(msg['armed'] == true, reason: 'status');
          }
          // robotOnline is source of truth when present.
          if (msg.containsKey('robotOnline')) {
            _setRobotOnline(msg['robotOnline'] == true, reason: 'status');
          }
          log.d(
            'status armed=${msg['armed']} robotOnline=${msg['robotOnline']}',
          );
          break;
        case 'map':
          final b64 = msg['png_base64'] as String?;
          final w = msg['width'] as int?;
          final h = msg['height'] as int?;
          if (b64 != null && b64.isNotEmpty) {
            lastMapAt = DateTime.now();
            lastMapWidth = w;
            lastMapHeight = h;
            _mapController.add(base64Decode(b64));
            log.d('map ${w ?? '?'}x${h ?? '?'}');
          }
          break;
        case 'error':
          final message = '${msg['message']}';
          lastError = message;
          log.e('relay error: $message');
          _emitEvent(message);
          if (message.toLowerCase().contains('robot offline') && currentArmed) {
            _setArmed(false, reason: 'arm rejected');
          }
          break;
        case 'pong':
          _lastPongAt = DateTime.now();
          break;
        default:
          log.w('unhandled type: $type');
      }
    } catch (e) {
      log.e('parse error: $e');
    }
  }

  void _setArmed(bool value, {String? reason}) {
    if (currentArmed == value) return;
    currentArmed = value;
    _armedController.add(value);
    if (reason != null) {
      log.i('armed=$value ($reason)');
    }
  }

  void _setRobotOnline(bool value, {String? reason}) {
    if (currentRobotOnline == value) return;
    currentRobotOnline = value;
    _robotOnlineController.add(value);
    log.i('robotOnline=$value${reason != null ? ' ($reason)' : ''}');
    if (!value && currentArmed) {
      _setArmed(false, reason: 'robot offline');
      _emitEvent('Robot went offline — disarmed');
    }
  }

  void _setState(RelayConnectionState s) {
    if (currentState == s) return;
    currentState = s;
    _stateController.add(s);
    log.d('relay state=$s');
  }

  void _emitEvent(String message) {
    if (!_eventController.isClosed) {
      _eventController.add(message);
    }
  }

  Future<void> dispose() async {
    _wantConnected = false;
    _reconnectTimer?.cancel();
    await disconnect();
    await _stateController.close();
    await _armedController.close();
    await _robotOnlineController.close();
    await _mapController.close();
    await _eventController.close();
    log.dispose();
  }
}
