# Raspberry Pi handoff: Leo ROS cloud bridge (`leo_cloud_bridge`)

**Audience:** agent or operator on the Raspberry Pi (Ubuntu Server / ROS 2 Jazzy).  
**Goal:** build and run `leo_cloud_bridge` so the Pi streams live `/map` to the phone via the public relay and soft-arms motors from the app.  
**Scope:** ROS package setup + launch only. Do **not** deploy Nginx, Docker relay, or Flutter on the Pi.

Companion docs:

- Server relay: `leo-application/leo-relay/SERVER_HANDOFF.md`
- Full demo runbook: `leo-application/DEMO_RUNBOOK.md`

---

## 1. What this package does

`leo_cloud_bridge` is a ROS 2 node that:

- Opens an **outbound** WebSocket to `leo-relay` (`role: robot`)
- Subscribes to `/map` (`nav_msgs/OccupancyGrid`) → encodes PNG → sends `map` frames
- Sends periodic `status` (`armed`, `robotOnline`)
- Soft-arms motion: listens on **`cmd_vel_in`**, republishes to **`/cmd_vel`** only when armed; when disarmed publishes zero twist (for `mcu_bridge`)

```text
teleop / planner  →  /cmd_vel_in  →  leo_cloud_bridge  →  /cmd_vel  →  mcu_bridge
slam_toolbox      →  /map         →  leo_cloud_bridge  →  WSS → relay → phone
```

Repo path:

```text
robotics/main_robotics_integration/src/leo_cloud_bridge/
```

---

## 2. Prerequisites on the Pi

- [ ] ROS 2 **Jazzy** workspace at `robotics/main_robotics_integration` (or equivalent) already builds
- [ ] Existing stack works: LiDAR `/scan`, `mcu_bridge` `/odom` + `/cmd_vel`, `slam_bringup` publishes `/map` when mapping
- [ ] Stable device nodes if used: `/dev/mcu`, `/dev/rplidar` (udev rules from existing packages)
- [ ] Outbound HTTPS/WSS to the internet (home NAT is fine; **no inbound** port needed)
- [ ] Shared relay token from server handoff (same as phone)

Python deps:

```bash
sudo apt update
sudo apt install -y python3-pil python3-websockets
# or: pip3 install Pillow websockets   (prefer apt on Ubuntu)
```

---

## 3. Fill these values

| Variable | Current deploy | Notes |
|----------|----------------|--------|
| `relay_url` | `wss://leo.hhhberzerk.me/ws` | Must match server |
| `token` | *(from server handoff — out of band)* | Must match phone + server `.env` |
| `robot_id` | `LEO_001` | Default |

Do **not** commit the token into git.

---

## 4. Build

```bash
cd /path/to/leo-floor-cleaning-robot/robotics/main_robotics_integration
source /opt/ros/jazzy/setup.bash

# Pull latest feature branch / package if needed, then:
colcon build --packages-select leo_cloud_bridge
source install/setup.bash
```

Confirm entry point:

```bash
ros2 pkg executables leo_cloud_bridge
# expect: leo_cloud_bridge cloud_bridge_node
```

---

## 5. Launch (three terminals)

All terminals: `source install/setup.bash` and matching `ROS_DOMAIN_ID` if you use one.

**Terminal A — SLAM stack (existing):**

```bash
ros2 launch slam_bringup mapping.launch.py
```

**Terminal B — cloud bridge:**

```bash
ros2 launch leo_cloud_bridge cloud_bridge.launch.py \
  relay_url:=wss://leo.hhhberzerk.me/ws \
  token:=YOUR_TOKEN \
  robot_id:=LEO_001
```

Expect log lines like: connecting to `wss://…`, then relay `welcome`.

**Terminal C — teleop (must use `cmd_vel_in`):**

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args \
  -r cmd_vel:=cmd_vel_in
```

Drive the robot so `/map` grows; phone should show live map frames.

---

## 6. Soft arm behavior

| Phone | Bridge | Motors |
|-------|--------|--------|
| Disarmed (default) | Publishes zero `/cmd_vel` | Hold / no motion from teleop |
| Armed | Forwards `cmd_vel_in` → `/cmd_vel` | Teleop moves MCU |

If teleop publishes straight to `/cmd_vel`, it **bypasses** the gate — always remap to `cmd_vel_in`.

---

## 7. Verification checklist

```bash
# Map is publishing
ros2 topic hz /map

# Bridge is up
ros2 node list | grep leo_cloud_bridge
ros2 topic echo /cmd_vel --once   # zeros when disarmed

# Optional: watch bridge logs for welcome / map encode errors
```

On the **phone** (leo-demo, connected to same relay):

- [ ] Chip **Robot online** after bridge connects (without reconnecting the phone)
- [ ] Arm unlocks when robot online; locks when bridge stops
- [ ] Map area updates while teleop drives
- [ ] Disarm → robot stops accepting motion through the gate

---

## 8. Common failures

| Symptom | Check |
|---------|--------|
| Phone: Robot offline forever | Bridge running? `relay_url` / `token` match? Outbound WSS blocked? |
| Bridge reconnect loop | DNS/TLS to `leo.hhhberzerk.me`; wrong token (unauthorized) |
| No map on phone | Is `/map` publishing? Is SLAM launched? Drive the robot |
| Motors move while disarmed | Teleop still on `/cmd_vel` instead of `cmd_vel_in` |
| `ModuleNotFoundError: PIL` | Install `python3-pil` |

---

## 9. Out of scope on the Pi

- Do not run `leo-relay` Docker here
- Do not install Flutter / Android tooling
- Do not open inbound firewall ports for the phone
- MCU firmware / power relay hardware is separate

---

## 10. Handoff return (fill and send back)

```text
Pi hostname:          ____________________
Workspace path:       ____________________
colcon build OK:      yes / no
python3-pil OK:       yes / no
websockets OK:        yes / no
relay_url used:       wss://leo.hhhberzerk.me/ws
token set:            yes / no  (do not paste token here)
cloud_bridge launch:  yes / no
relay welcome seen:   yes / no
/map hz OK:           yes / no
Phone Robot online:   yes / no
Arm gate verified:    yes / no
Notes:                ____________________
```
