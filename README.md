# leo-floor-cleaning-robot
An advanced Autonomous Floor Cleaning Robot.

## Demo (on/off + live SLAM map over internet)

See [leo-application/DEMO_RUNBOOK.md](leo-application/DEMO_RUNBOOK.md).

- `leo-application/leo-relay` — WebSocket relay (Docker + Nginx subdomain)
- `leo-application/leo-demo` — minimal Flutter Android app
- `robotics/.../leo_cloud_bridge` — Pi outbound bridge (`/map` → phone, soft arm)
