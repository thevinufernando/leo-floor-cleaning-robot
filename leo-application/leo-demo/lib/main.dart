import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'config.dart';
import 'debug_log.dart';
import 'relay_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LeoDemoApp());
}

class LeoDemoApp extends StatelessWidget {
  const LeoDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leo Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B6B4A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  late final DebugLog _log;
  late final LeoRelayClient _client;
  final _logScroll = ScrollController();

  RelayConnectionState _conn = RelayConnectionState.disconnected;
  bool _armed = false;
  bool _robotOnline = false;
  Uint8List? _mapPng;
  bool _logExpanded = true;
  int _logTick = 0;
  Timer? _ageTimer;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _log = DebugLog();
    _client = LeoRelayClient(log: _log);

    _subs.addAll([
      _client.state.listen((s) => setState(() => _conn = s)),
      _client.armed.listen((a) => setState(() => _armed = a)),
      _client.robotOnline.listen((o) => setState(() => _robotOnline = o)),
      _client.mapPng.listen((png) => setState(() => _mapPng = png)),
      _client.events.listen(_showSnack),
      _log.stream.listen((_) {
        setState(() => _logTick++);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScroll.hasClients) {
            _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
          }
        });
      }),
    ]);

    // Refresh "Xs ago" labels.
    _ageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ageTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _logScroll.dispose();
    _client.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _toggleConnect() async {
    if (_conn == RelayConnectionState.connected ||
        _conn == RelayConnectionState.connecting) {
      await _client.disconnect();
      return;
    }
    await _client.connect();
  }

  void _onArmedChanged(bool value) {
    _client.setArmed(value);
  }

  bool get _canArm =>
      _conn == RelayConnectionState.connected && _robotOnline;

  String get _connLabel {
    switch (_conn) {
      case RelayConnectionState.disconnected:
        return 'Relay off';
      case RelayConnectionState.connecting:
        return 'Connecting…';
      case RelayConnectionState.connected:
        return 'Relay OK';
      case RelayConnectionState.error:
        return 'Relay error';
    }
  }

  String _ago(DateTime? t) {
    if (t == null) return 'never';
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 1) return 'just now';
    if (s < 60) return '${s}s ago';
    return '${s ~/ 60}m ago';
  }

  String get _mapPlaceholder {
    if (_conn != RelayConnectionState.connected) {
      return 'Connect to the relay to receive the map';
    }
    if (!_robotOnline) {
      return 'Waiting for robot…\n(Pi leo_cloud_bridge not on relay)';
    }
    if (_mapPng == null) {
      return 'Robot online — waiting for /map frames…\n(drive teleop so SLAM builds)';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ignore: unused_local_variable — forces rebuild when log grows
    final _ = _logTick;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('LEO', style: Theme.of(context).textTheme.displaySmall),
              Text(
                'Demo · live map + soft arm',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(
                    label: _connLabel,
                    tone: _conn == RelayConnectionState.connected
                        ? _ChipTone.ok
                        : _conn == RelayConnectionState.error
                            ? _ChipTone.bad
                            : _ChipTone.neutral,
                  ),
                  _StatusChip(
                    label: _robotOnline ? 'Robot online' : 'Robot offline',
                    tone: _robotOnline ? _ChipTone.ok : _ChipTone.warn,
                  ),
                  _StatusChip(
                    label: _armed ? 'Armed' : 'Disarmed',
                    tone: _armed ? _ChipTone.ok : _ChipTone.neutral,
                  ),
                  FilledButton.tonal(
                    onPressed: _toggleConnect,
                    child: Text(
                      _conn == RelayConnectionState.connected ||
                              _conn == RelayConnectionState.connecting
                          ? 'Disconnect'
                          : 'Connect',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                LeoConfig.relayUrl,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (_conn == RelayConnectionState.connected && !_robotOnline) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A2E14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC9A227).withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Relay connected but robot is offline. Arm is locked until Pi joins.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: const Text('Robot armed (on/off)'),
                  subtitle: Text(
                    !_canArm
                        ? (_robotOnline
                            ? 'Connect to relay first'
                            : 'Locked — robot offline')
                        : (_armed
                            ? 'Motion commands allowed'
                            : 'cmd_vel gated — motors hold'),
                  ),
                  value: _armed,
                  onChanged: _canArm ? _onArmedChanged : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('SLAM map',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (_client.lastMapAt != null)
                    Text(
                      'updated ${_ago(_client.lastMapAt)}'
                      '${_client.lastMapWidth != null ? ' · ${_client.lastMapWidth}x${_client.lastMapHeight}' : ''}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1410),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outline.withOpacity(0.4),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _mapPng == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _mapPlaceholder,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: scheme.onSurface.withOpacity(0.55),
                                ),
                              ),
                            ),
                          )
                        : InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 8,
                            child: Center(
                              child: Image.memory(
                                _mapPng!,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.none,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Debug log',
                      style: Theme.of(context).textTheme.titleSmall),
                  IconButton(
                    tooltip: _logExpanded ? 'Collapse' : 'Expand',
                    onPressed: () =>
                        setState(() => _logExpanded = !_logExpanded),
                    icon: Icon(
                      _logExpanded
                          ? Icons.expand_more
                          : Icons.chevron_right,
                    ),
                  ),
                  const Spacer(),
                  if (_client.lastRobotStatusAt != null)
                    Text(
                      'status ${_ago(_client.lastRobotStatusAt)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
              if (_logExpanded)
                Expanded(
                  flex: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF12181C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: scheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: ListView.builder(
                      controller: _logScroll,
                      padding: const EdgeInsets.all(8),
                      itemCount: _log.entries.length,
                      itemBuilder: (context, i) {
                        final e = _log.entries[i];
                        final color = switch (e.level) {
                          LogLevel.error => const Color(0xFFE57373),
                          LogLevel.warn => const Color(0xFFFFB74D),
                          LogLevel.info => const Color(0xFF81C784),
                          LogLevel.debug => scheme.onSurface.withOpacity(0.55),
                        };
                        return Text(
                          e.toString(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: color,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ChipTone { ok, warn, bad, neutral }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _ChipTone.ok => const Color(0xFF2E8B57),
      _ChipTone.warn => const Color(0xFFC9A227),
      _ChipTone.bad => const Color(0xFFC62828),
      _ChipTone.neutral => const Color(0xFF6B7280),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
