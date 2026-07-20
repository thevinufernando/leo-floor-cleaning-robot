/// Compile-time config for the demo relay.
///
/// Pass at run time:
///   flutter run \
///     --dart-define=LEO_RELAY_URL=wss://leo.YOUR_DOMAIN/ws \
///     --dart-define=LEO_RELAY_TOKEN=your-token \
///     --dart-define=LEO_ROBOT_ID=LEO_001
class LeoConfig {
  static const relayUrl = String.fromEnvironment(
    'LEO_RELAY_URL',
    defaultValue: 'ws://10.0.2.2:8080/ws',
  );

  static const token = String.fromEnvironment(
    'LEO_RELAY_TOKEN',
    defaultValue: 'change-me-demo-token',
  );

  static const robotId = String.fromEnvironment(
    'LEO_ROBOT_ID',
    defaultValue: 'LEO_001',
  );
}
