# Leo Demo — runbook (on/off + live SLAM map)

Internet path: **phone ↔ leo-relay (your server) ↔ Pi `leo_cloud_bridge`**.

Firebase is not used for this demo.

## 1. Server (leo-relay)

**Full server-agent handoff (DNS, Nginx, Docker, TLS, verification):**  
[`leo-relay/SERVER_HANDOFF.md`](leo-relay/SERVER_HANDOFF.md)

```bash
cd leo-application/leo-relay
cp .env.example .env   # set LEO_RELAY_TOKEN
# optional UI-only testing without a robot:
# MOCK_MAP=true

docker compose up -d --build
curl http://127.0.0.1:8080/health
```

### Nginx subdomain

1. DNS: `leo.YOUR_DOMAIN` → this VPS  
2. Copy [`nginx/leo.YOUR_DOMAIN.conf`](leo-relay/nginx/leo.YOUR_DOMAIN.conf), replace `YOUR_DOMAIN`, enable site  
3. Certbot TLS for `leo.YOUR_DOMAIN`  
4. Phone / Pi URL: `wss://leo.YOUR_DOMAIN/ws`

## 2. Raspberry Pi (ROS 2)

Build the new package (with your existing workspace):

```bash
cd robotics/main_robotics_integration
# apt: python3-pil python3-websockets  (or pip in a venv used by ROS)
colcon build --packages-select leo_cloud_bridge
source install/setup.bash
```

Mapping + uplink (three terminals):

```bash
# A — SLAM stack (LiDAR + odom + slam_toolbox)
ros2 launch slam_bringup mapping.launch.py

# B — cloud bridge (outbound WSS + cmd_vel gate)
ros2 launch leo_cloud_bridge cloud_bridge.launch.py \
  relay_url:=wss://leo.YOUR_DOMAIN/ws \
  token:=YOUR_TOKEN

# C — drive so the map grows (note cmd_vel_in)
ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args \
  -r cmd_vel:=cmd_vel_in
```

Soft **on/off** from the phone sets `armed`. While disarmed, `/cmd_vel` is held at zero so `mcu_bridge` does not drive motors.

## 3. Android app (leo-demo)

Flutter SDK required on the build machine.

```bash
cd leo-application/leo-demo
flutter pub get
```

### Emulator (default points at host relay)

If relay runs on the Windows/Linux host at port 8080, emulator default is already:

`ws://10.0.2.2:8080/ws` (Android emulator loopback to host)

```bash
flutter run \
  --dart-define=LEO_RELAY_URL=ws://10.0.2.2:8080/ws \
  --dart-define=LEO_RELAY_TOKEN=change-me-demo-token
```

For a **physical phone** on the same LAN as your PC (relay on PC):

```bash
flutter run \
  --dart-define=LEO_RELAY_URL=ws://192.168.x.x:8080/ws \
  --dart-define=LEO_RELAY_TOKEN=change-me-demo-token
```

For **production subdomain** (phone anywhere with internet):

```bash
flutter run \
  --dart-define=LEO_RELAY_URL=wss://leo.YOUR_DOMAIN/ws \
  --dart-define=LEO_RELAY_TOKEN=YOUR_TOKEN \
  --dart-define=LEO_ROBOT_ID=LEO_001
```

App UI: **Connect** → see robot online → **Robot armed** toggle → live SLAM PNG when `/map` updates.

## 4. Protocol (quick reference)

| type | who | meaning |
|------|-----|---------|
| `hello` | phone/robot | first frame; includes `token`, `role`, `robotId` |
| `set_armed` | phone → robot | soft on/off |
| `status` | robot → phones | `armed`, connectivity |
| `map` | robot → phones | OccupancyGrid as `png_base64` |
| `ping` / `pong` | either | keepalive |

## 5. Local self-check (no ROS)

```bash
cd leo-application/leo-relay
pip install -r requirements.txt pillow
python -m app.self_check
```
