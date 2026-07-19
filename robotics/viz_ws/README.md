# viz_ws — WSL2 visualization workspace

A **separate**, lightweight ROS 2 workspace that runs **only RViz** on the
WSL2 dev machine to visualise what the robot's Pi is doing over the LAN —
primarily the live SLAM map. It contains no drivers and no SLAM compute; all
of that runs headless on the Pi (see
`../main_robotics_integration/src/slam_bringup/`).

Keeping it in its own workspace means WSL2 only builds the few view-only
packages, not the whole robot stack (rplidar SDK, mcu_bridge, etc.).

```
robotics/
├── main_robotics_integration/   # the robot's main workspace (runs on the Pi)
└── viz_ws/                       # THIS workspace (runs on WSL2, RViz only)
    └── src/slam_viz/
```

## 1. One-time WSL2 setup

### Install ROS 2 Jazzy (if not already)
Follow the official Jazzy install for Ubuntu 24.04, then:
```bash
sudo apt install ros-jazzy-rviz2 ros-jazzy-rviz-default-plugins
```

### Networking: let WSL2 see the Pi's DDS traffic
WSL2's default NAT networking blocks the UDP multicast ROS 2 uses for
discovery. Use **mirrored** networking (Windows 11):

Create/edit `C:\Users\<you>\.wslconfig`:
```ini
[wsl2]
networkingMode=mirrored
```
Then in PowerShell: `wsl --shutdown`, and reopen WSL2.

### Shared DDS environment (must match the Pi)
Add to `~/.bashrc` on **WSL2** *and* the **Pi** (see repo `NETWORK_SETUP.md`):
```bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
# ensure NOT set to 1 on either machine:
unset ROS_LOCALHOST_ONLY
```
Install the matching RMW on WSL2 if you use cyclonedds:
```bash
sudo apt install ros-jazzy-rmw-cyclonedds-cpp
```

### Verify discovery
With something publishing on the Pi (e.g. `ros2 launch slam_bringup
mapping.launch.py`), on WSL2:
```bash
source /opt/ros/jazzy/setup.bash
ros2 topic list        # should show /scan /map /odom /tf /robot_description
ros2 topic hz /scan    # confirms data actually crosses the network
```
If topics list but `hz` hangs, discovery works but data isn't flowing —
almost always a networking/firewall issue (recheck mirrored mode + Windows
Defender allowing WSL).

## 2. Build (one-time, and after changes)

```bash
cd robotics/viz_ws
source /opt/ros/jazzy/setup.bash
colcon build
source install/setup.bash
```

## 3. Visualise the live SLAM map

On the **Pi** (see `slam_bringup/README.md`):
```bash
ros2 launch slam_bringup mapping.launch.py
ros2 run teleop_twist_keyboard teleop_twist_keyboard   # drive it
```

On **WSL2**:
```bash
cd robotics/viz_ws && source install/setup.bash
ros2 launch slam_viz slam_view.launch.py
```

RViz opens with the map, live `/scan`, the robot model, and the full TF tree.
Drive the robot slowly with the Pi teleop terminal and watch the map fill in.

## What the RViz config shows

| Display | Topic | Notes |
|---------|-------|-------|
| Map        | `/map`               | Occupancy grid from slam_toolbox (Transient Local QoS). |
| LaserScan  | `/scan`              | Live RPLIDAR C1 points (Best Effort QoS). |
| RobotModel | `/robot_description` | Model from the Pi's robot_state_publisher. |
| TF         | —                    | `map → odom → base_link → laser/...`. |
| Odometry   | `/odom`              | Disabled by default; enable to see the odom trail. |

Fixed frame is `map`, top-down orthographic view following `base_link`.

## Troubleshooting

- **Empty RViz / "No map received"** → topics not crossing the LAN. Recheck
  `ROS_DOMAIN_ID`, `RMW_IMPLEMENTATION`, mirrored networking, `wsl --shutdown`.
- **Map shows but no robot model** → the Pi's `robot_state_publisher` isn't
  running (it's part of `mapping.launch.py` via `lidar_bringup`), or QoS
  mismatch — the config uses Transient Local for `/robot_description`.
- **Scan shows but no map** → slam_toolbox not running on the Pi, or it has
  no `odom → base_link` TF (check `mcu_bridge` / `ros2 topic hz /odom`).
```
