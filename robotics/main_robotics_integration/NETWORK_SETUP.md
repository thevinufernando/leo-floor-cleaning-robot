# Network setup: Pi (headless) + WSL2 (visualization)

The Pi runs **Ubuntu Server** (no desktop, no GUI) once the robot is
assembled. It publishes/subscribes to ROS 2 topics only -- drivers,
`robot_state_publisher`, `joint_state_publisher`, and later SLAM/Nav2
compute. RViz2 (and any other GUI tool) runs on the **WSL2 dev machine**
instead, over the same LAN.

## Requirements

Both machines must be on the same ROS 2 domain and reachable over the LAN
(same subnet, no client isolation on the router/AP -- a common Wi-Fi gotcha).

- **`ROS_DOMAIN_ID`**: pick a non-default value shared by both machines to
  avoid collisions with other ROS 2 traffic on the network. e.g. add to both
  `~/.bashrc` (Pi) and the WSL2 shell profile:
  ```bash
  export ROS_DOMAIN_ID=42
  ```
- **RMW implementation**: default `rmw_cyclonedds_cpp` or `rmw_fastrtps_cpp`
  both work over a LAN as long as both machines use the *same* one. Set
  explicitly to avoid ambiguity:
  ```bash
  export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  ```
- **`ROS_LOCALHOST_ONLY`**: must be `0` (default) or unset on both machines.
  If either has it set to `1`, cross-machine discovery will silently fail.
- Firewall: ensure UDP multicast/discovery traffic isn't blocked between the
  Pi and the WSL2 VM's virtual network adapter. WSL2 mirrored networking
  (Windows 11, `.wslconfig` -> `networkingMode=mirrored`) makes this far more
  reliable than WSL2's default NAT mode, which can block multicast from the
  LAN reaching WSL2.

## Pattern

Every visualization-capable package in this workspace follows the same
split, so headless (Pi) and RViz (WSL2) processes can be started
independently on either machine:

| Package             | Headless launch (Pi)        | RViz-only launch (WSL2)          |
|----------------------|------------------------------|-----------------------------------|
| `lidar_bringup`      | `lidar.launch.py`            | `rviz_only.launch.py`             |
| `robot_description`  | `display.launch.py use_rviz:=false use_gui:=false` | `rviz_only.launch.py` |

`rviz2`, `rviz_default_plugins`, and `joint_state_publisher_gui` are declared
as `exec_depend` in `package.xml` for documentation/portability, but are only
actually installed and run on the WSL2 side -- the Pi (Ubuntu Server) never
needs an X server, Qt, or an OpenGL stack.

## Typical session

On the Pi:
```bash
ros2 launch lidar_bringup lidar.launch.py
# once SLAM/Nav2 exist, launch those headless stacks here too
```

On WSL2:
```bash
ros2 launch lidar_bringup rviz_only.launch.py
# or, for the full robot model only (no lidar):
ros2 launch robot_description rviz_only.launch.py
```

RViz2 on WSL2 will discover the Pi's topics/TF automatically once
`ROS_DOMAIN_ID` matches and discovery traffic isn't blocked.
