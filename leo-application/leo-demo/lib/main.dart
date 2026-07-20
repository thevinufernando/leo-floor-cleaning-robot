import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'config.dart';
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
  final LeoRelayClient _client = LeoRelayClient();
  RelayConnectionState _conn = RelayConnectionState.disconnected;
  bool _armed = false;
  bool _robotOnline = false;
  Uint8List? _mapPng;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _client.state.listen((s) => setState(() => _conn = s));
    _client.armed.listen((a) => setState(() => _armed = a));
    _client.robotOnline.listen((o) => setState(() => _robotOnline = o));
    _client.mapPng.listen((png) => setState(() => _mapPng = png));
    _client.messages.listen((m) => setState(() => _log = m));
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _toggleConnect() async {
    if (_conn == RelayConnectionState.connected ||
        _conn == RelayConnectionState.connecting) {
      await _client.disconnect();
      return;
    }
    try {
      await _client.connect();
    } catch (_) {
      // surfaced via messages stream
    }
  }

  void _onArmedChanged(bool value) {
    _client.setArmed(value);
    // Optimistic UI; robot status echo corrects if offline.
    setState(() => _armed = value);
  }

  String get _connLabel {
    switch (_conn) {
      case RelayConnectionState.disconnected:
        return 'Disconnected';
      case RelayConnectionState.connecting:
        return 'Connecting…';
      case RelayConnectionState.connected:
        return 'Connected';
      case RelayConnectionState.error:
        return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('LEO', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                'Demo · live map + soft arm',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Chip(
                    label: _connLabel,
                    ok: _conn == RelayConnectionState.connected,
                  ),
                  _Chip(label: _robotOnline ? 'Robot online' : 'Robot offline',
                      ok: _robotOnline),
                  FilledButton.tonal(
                    onPressed: _toggleConnect,
                    child: Text(
                      _conn == RelayConnectionState.connected
                          ? 'Disconnect'
                          : 'Connect',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                LeoConfig.relayUrl,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  title: const Text('Robot armed (on/off)'),
                  subtitle: Text(_armed
                      ? 'Motion commands allowed'
                      : 'cmd_vel gated — motors hold'),
                  value: _armed,
                  onChanged: _conn == RelayConnectionState.connected
                      ? _onArmedChanged
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text('SLAM map', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
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
                            child: Text(
                              'Waiting for map frames…',
                              style: TextStyle(
                                color: scheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          )
                        : InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 8,
                            child: Center(
                              child: Image.memory(
                                _mapPng!,
                                filterQuality: FilterQuality.none,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (_log.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _log,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF2E8B57) : const Color(0xFF6B7280);
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
