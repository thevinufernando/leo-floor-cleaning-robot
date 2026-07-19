# slam_bringup

Online **asynchronous** SLAM (slam_toolbox) for the autonomous cleaning
robot. Builds a 2D occupancy-grid map of the environment from the RPLIDAR C1
scan and wheel odometry, then lets you save it for later Nav2 use.

This package runs **headless on the Pi** (Ubuntu Server). Visualise the map
live in RViz on the WSL2 dev machine — see `robotics/viz_ws/` and the repo's
`NETWORK_SETUP.md`.

## How the pieces fit

```
                 /scan        ┌───────────────┐
  RPLIDAR C1 ───────────────► │               │  map->odom TF
                              │  slam_toolbox │ ───────────────► /map
  MCU ──/odom + odom->base_link TF──►         │  (async node)
   ▲                          └───────────────┘
   │ MSG_CMD_VEL (motors)
   │
  mcu_bridge ◄── /cmd_vel ◄── teleop_twist_keyboard  (you drive)
```

The MCU streams encoder odometry to the Pi but **does not generate its own
motion** — it only drives the motors in response to `cmd_vel`. So mapping
requires *you* to drive the robot: `teleop_twist_keyboard` publishes
`/cmd_vel`, `mcu_bridge` forwards it to the MCU as `MSG_CMD_VEL`, the MCU
spins the wheels, the robot's pose changes, and slam_toolbox extends the map.

**TF tree while mapping:**
`map` (slam_toolbox) → `odom` (mcu_bridge) → `base_link` → `laser` / sensors
(robot_state_publisher).

## Prerequisites (one-time)

```bash
# ROS packages (Pi):
sudo apt install ros-jazzy-slam-toolbox \
                 ros-jazzy-teleop-twist-keyboard \
                 ros-jazzy-nav2-map-server

# Stable device symlinks (/dev/mcu, /dev/rplidar). The .rules files live in
# the repo; install + reload them:
sudo cp src/mcu_bridge/scripts/mcu_bridge.rules /etc/udev/rules.d/99-mcu-bridge.rules
sudo cp src/rplidar_ros/scripts/rplidar.rules   /etc/udev/rules.d/99-rplidar.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# Build:
colcon build --packages-select slam_bringup mcu_bridge lidar_bringup robot_description
source install/setup.bash
```

Verify the symlinks resolved: `ls -l /dev/mcu /dev/rplidar`.

## Mapping session (Pi)

Open three terminals on the Pi (SSH is fine; each needs
`source install/setup.bash` and a matching `ROS_DOMAIN_ID`).

**Terminal 1 — the full SLAM stack (LiDAR + odometry + slam_toolbox):**
```bash
ros2 launch slam_bringup mapping.launch.py
# args (optional): lidar_serial_port:=/dev/rplidar mcu_port:=/dev/mcu
```

**Terminal 2 — drive the robot.** teleop needs a real keyboard/TTY:
```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
# i/k/j/l to move, drive SLOWLY for clean scan matching
```

**Terminal 3 (WSL2) — watch the map build** (see `robotics/viz_ws/`):
```bash
ros2 launch slam_viz slam_view.launch.py
```

Drive the robot slowly over the whole area, revisiting places to trigger
loop closures.

### Sanity checks before/while driving

```bash
ros2 topic hz /scan                 # ~10 Hz from RPLIDAR C1
ros2 topic hz /odom                 # ~50-100 Hz from mcu_bridge
ros2 run tf2_ros tf2_echo odom base_link   # updates as you drive
ros2 run tf2_ros tf2_echo map odom          # published by slam_toolbox
ros2 topic echo /map --once         # occupancy grid appears
```

## Saving the map

With `mapping.launch.py` still running:
```bash
ros2 run slam_bringup save_map.sh my_map ~/maps
# -> ~/maps/my_map.pgm + ~/maps/my_map.yaml
```

Or use slam_toolbox's own serialization (keeps the pose-graph so you can
resume/continue mapping later):
```bash
ros2 service call /slam_toolbox/serialize_map \
  slam_toolbox/srv/SerializePoseGraph "{filename: '/home/USER/maps/my_map'}"
```

## Files

| File | Purpose |
|------|---------|
| `launch/mapping.launch.py`            | Full stack: prereqs + slam_toolbox (headless). |
| `launch/slam_prereqs.launch.py`       | LiDAR + mcu_bridge + robot TF only (verify before mapping). |
| `launch/online_async_slam.launch.py`  | slam_toolbox mapper only (prereqs assumed running). |
| `launch/teleop_keyboard.launch.py`    | Convenience teleop launch (prefer `ros2 run` for key input). |
| `config/mapper_params_online_async.yaml` | slam_toolbox tuning (frames, RPLIDAR C1 range, scan matching). |
| `scripts/save_map.sh`                 | Save `/map` via nav2_map_server. |
| `rviz/slam.rviz`                      | RViz layout (used by `viz_ws` on WSL2). |

## Notes

- **Async vs sync**: async processes the newest scan and drops backlog to
  stay real-time on the Pi — the right choice for online mapping on
  constrained hardware. Switch to sync only for offline/bagged high-accuracy
  runs.
- **Heading drift**: odometry is encoder-only (no IMU fusion — the PCB's
  magnetometer is unpopulated), so yaw drifts slowly. The mapper params give
  yaw a larger odom covariance so scan matching dominates; loop closure
  cleans up accumulated drift when you revisit areas.
