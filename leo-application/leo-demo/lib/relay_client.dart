import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';

enum RelayConnectionState { disconnected, connecting, connected, error }

class LeoRelayClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;

  final _stateController =
      StreamController<RelayConnectionState>.broadcast();
  final _armedController = StreamController<bool>.broadcast();
  final _robotOnlineController = StreamController<bool>.broadcast();
  final _mapController = StreamController<Uint8List?>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  Stream<RelayConnectionState> get state => _stateController.stream;
  Stream<bool> get armed => _armedController.stream;
  Stream<bool> get robotOnline => _robotOnlineController.stream;
  Stream<Uint8List?> get mapPng => _mapController.stream;
  Stream<String> get messages => _messageController.stream;

  RelayConnectionState currentState = RelayConnectionState.disconnected;
  bool currentArmed = false;
  bool currentRobotOnline = false;

  Future<void> connect() async {
    await disconnect();
    _setState(RelayConnectionState.connecting);
    try {
      final uri = Uri.parse(LeoConfig.relayUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _sub = _channel!.stream.listen(
        _onData,
        onError: (Object e) {
          _messageController.add('socket error: $e');
          _setState(RelayConnectionState.error);
        },
        onDone: () {
          _setState(RelayConnectionState.disconnected);
          currentRobotOnline = false;
          _robotOnlineController.add(false);
        },
      );

      _send({
        'type': 'hello',
        'role': 'phone',
        'robotId': LeoConfig.robotId,
        'token': LeoConfig.token,
      });

      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _send({'type': 'ping'});
      });
    } catch (e) {
      _messageController.add('connect failed: $e');
      _setState(RelayConnectionState.error);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _setState(RelayConnectionState.disconnected);
  }

  void setArmed(bool armed) {
    _send({'type': 'set_armed', 'armed': armed});
  }

  void _send(Map<String, Object?> payload) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(payload));
  }

  void _onData(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      switch (type) {
        case 'welcome':
          _setState(RelayConnectionState.connected);
          final online = msg['robotOnline'] == true;
          currentRobotOnline = online;
          _robotOnlineController.add(online);
          _messageController.add('welcome robotOnline=$online');
          break;
        case 'status':
          if (msg.containsKey('armed')) {
            currentArmed = msg['armed'] == true;
            _armedController.add(currentArmed);
          }
          if (msg.containsKey('robotOnline') || msg.containsKey('connected')) {
            final online =
                msg['robotOnline'] == true || msg['connected'] == true;
            // Prefer explicit robotOnline when present.
            final resolved = msg.containsKey('robotOnline')
                ? msg['robotOnline'] == true
                : online;
            currentRobotOnline = resolved;
            _robotOnlineController.add(resolved);
          }
          break;
        case 'map':
          final b64 = msg['png_base64'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            _mapController.add(base64Decode(b64));
          }
          break;
        case 'error':
          _messageController.add('relay: ${msg['message']}');
          break;
        case 'pong':
          break;
        default:
          _messageController.add('unhandled: $type');
      }
    } catch (e) {
      _messageController.add('parse error: $e');
    }
  }

  void _setState(RelayConnectionState s) {
    currentState = s;
    _stateController.add(s);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _armedController.close();
    await _robotOnlineController.close();
    await _mapController.close();
    await _messageController.close();
  }
}
