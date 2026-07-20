# leo-demo

Minimal Flutter Android demo: connect to leo-relay, soft-arm the robot, view live SLAM map.

```bash
flutter pub get
flutter run --dart-define=LEO_RELAY_URL=wss://leo.YOUR_DOMAIN/ws --dart-define=LEO_RELAY_TOKEN=YOUR_TOKEN
```

Full steps: [../DEMO_RUNBOOK.md](../DEMO_RUNBOOK.md).
