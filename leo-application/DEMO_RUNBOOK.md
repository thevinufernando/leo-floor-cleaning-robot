# Leo Demo — runbook (on/off + live SLAM map)

Internet path: **phone ↔ leo-relay (your server) ↔ Pi `leo_cloud_bridge`**.

Firebase is not used for this demo.

## Current deploy (hhhberzerk)

| Item | Value |
|------|--------|
| Subdomain | `leo.hhhberzerk.me` |
| WSS | `wss://leo.hhhberzerk.me/ws` |
| Health | `https://leo.hhhberzerk.me/health` |
| Host bind | `127.0.0.1:8088` (8080 taken by Flowise; Nginx proxies to 8088) |
| Compose | `/home/berzerk/projects/leo-floor-cleaning-robot/leo-application/leo-relay` |
| MOCK_MAP | `false` |

Token is **not** stored in git. Use the shared secret from the server handoff (phone + Pi must match).

Local Flutter defines file (gitignored): copy  
[`leo-demo/dart_defines.json.example`](leo-demo/dart_defines.json.example) → `leo-demo/dart_defines.json`, fill in the token, then:

```bash
cd leo-application/leo-demo
flutter run --dart-define-from-file=dart_defines.json
```

## 1. Server (leo-relay)

**Full server-agent handoff (DNS, Nginx, Docker, TLS, verification):**  
[`leo-relay/SERVER_HANDOFF.md`](leo-relay/SERVER_HANDOFF.md)

```bash
cd leo-application/leo-relay
cp .env.example .env   # set LEO_RELAY_TOKEN
# optional UI-only testing without a robot:
# MOCK_MAP=true

docker compose up -d --build
# If host :8080 is taken, map another port (e.g. 8088) and point Nginx at it.
curl http://127.0.0.1:8088/health   # or :8080 if free
```

### Nginx subdomain

1. DNS: `leo.YOUR_DOMAIN` → this VPS  
2. Copy [`nginx/leo.YOUR_DOMAIN.conf`](leo-relay/nginx/leo.YOUR_DOMAIN.conf), replace `YOUR_DOMAIN`, enable site  
3. Certbot TLS for `leo.YOUR_DOMAIN`  
4. Phone / Pi URL: `wss://leo.YOUR_DOMAIN/ws`

## 2. Raspberry Pi (ROS 2)

**Full Pi-agent handoff (deps, build, launch, verify):**  
[`../robotics/main_robotics_integration/src/leo_cloud_bridge/PI_ROS_HANDOFF.md`](../robotics/main_robotics_integration/src/leo_cloud_bridge/PI_ROS_HANDOFF.md)

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
  relay_url:=wss://leo.hhhberzerk.me/ws \
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
flutter run --dart-define-from-file=dart_defines.json
# or:
flutter run \
  --dart-define=LEO_RELAY_URL=wss://leo.hhhberzerk.me/ws \
  --dart-define=LEO_RELAY_TOKEN=YOUR_TOKEN \
  --dart-define=LEO_ROBOT_ID=LEO_001
```

App UI: **Connect** → Relay OK → (wait for Pi) **Robot online** → **Armed** toggle → live SLAM PNG when `/map` updates.

### App status chips / debugging

| Chip / UI | Meaning |
|-----------|---------|
| Relay OK | Phone WebSocket + `welcome` succeeded |
| Relay error | Connect/welcome/pong failed — see Debug log |
| Robot offline | Relay up but Pi bridge not joined (or dropped) — **arm locked** |
| Robot online | Pi `leo_cloud_bridge` connected; arm allowed |
| Armed / Disarmed | Soft gate on Pi `cmd_vel` |
| Debug log | Ring buffer + same lines in `flutter run` console |

**Robot offline checklist:** Pi package built? `cloud_bridge.launch.py` running with matching `relay_url` + token? Outbound WSS OK? See [PI_ROS_HANDOFF.md](../robotics/main_robotics_integration/src/leo_cloud_bridge/PI_ROS_HANDOFF.md).

After relay code changes (robot presence notify), redeploy `leo-relay` on the VPS (`docker compose up -d --build`). Phone-only changes hot-reload.

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
