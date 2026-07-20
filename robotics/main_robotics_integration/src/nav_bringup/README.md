# nav_bringup

Nav2 bringup for the autonomous cleaning robot: **AMCL localization** on a
pre-built static map, plus **point-to-point path planning and following**
(planner, Regulated Pure Pursuit controller, behavior tree navigator).

This is the point-to-point navigation stage. The ultimate goal — the robot
building its own map and doing coverage path planning to clean the whole
floor autonomously — builds on top of this package later (a coverage
planner feeding a stream of `navigate_to_pose` goals instead of you
clicking a single goal in RViz).

Odometry is **encoder-only** (`mcu_bridge`, no IMU fusion — see
`slam_bringup/README.md`). AMCL is tuned to lean on LiDAR scan matching
to correct drift rather than trusting odometry alone.

## How the pieces fit

```
                 /scan        ┌──────────┐   map->odom TF
  RPLIDAR C1 ───────────────► │   AMCL   │ ─────────────────┐
                              └──────────┘                   │
  MCU ──/odom + odom->base_footprint TF──►                   ▼
   ▲                                              ┌─────────────────────┐
   │ MSG_CMD_VEL (motors)                         │   Nav2 nav stack    │
   │                                               │ planner/controller/ │
  mcu_bridge ◄── /cmd_vel_smoothed ◄── velocity ◄──│ bt_navigator/behav  │
                                        smoother    └─────────────────────┘
                                                       ▲
                                          NavigateToPose goal (RViz / API)
```

**TF tree while navigating:**
`map` (AMCL) → `odom` (mcu_bridge) → `base_footprint` → `base_link` →
`laser` / sensors (robot_state_publisher) — identical chain to SLAM
mapping, just with AMCL replacing slam_toolbox as the `map`→`odom`
source.

**Velocity path:** `controller_server`/`behavior_server`/`bt_navigator`
publish to `/cmd_vel_nav` (nav2_bringup's internal remap),
`velocity_smoother` rate/accel-limits it and publishes `/cmd_vel_smoothed`.
`mcu_bridge` only ever subscribes to plain `/cmd_vel`, so
`navigation.launch.py` adds a `topic_tools relay` node forwarding
`cmd_vel_smoothed` → `cmd_vel`. No changes needed in `mcu_bridge` itself.

## Prerequisites (one-time)

```bash
# ROS packages (Pi) — nav2-bringup/amcl/map-server already installed per
# your setup; topic_tools is additionally required for the cmd_vel relay
# (see "How the pieces fit" above):
sudo apt install ros-jazzy-topic-tools

# Build:
colcon build --packages-select nav_bringup slam_bringup mcu_bridge lidar_bringup robot_description
source install/setup.bash
```

## 1. Save a map (one-time, or whenever the environment changes)

You haven't saved a map yet. Run a mapping session first — see
`slam_bringup/README.md` for the full walkthrough:

```bash
# Terminal 1 (Pi): full SLAM stack
ros2 launch slam_bringup mapping.launch.py

# Terminal 2 (Pi): drive the robot around the whole area
ros2 run teleop_twist_keyboard teleop_twist_keyboard

# Terminal 3 (Pi), once the map looks complete:
ros2 run slam_bringup save_map.sh my_map ~/maps
# -> ~/maps/my_map.pgm + ~/maps/my_map.yaml
```

## 2. Point-to-point navigation session (Pi)

**Terminal 1 — full Nav2 stack** (sensors/odometry + AMCL + planner/controller):
```bash
ros2 launch nav_bringup bringup.launch.py map:=$HOME/maps/my_map.yaml
# args (optional): lidar_serial_port:=/dev/rplidar mcu_port:=/dev/mcu
```

**Terminal 2 (WSL2 or any machine with a display) — RViz:**
```bash
rviz2 -d install/nav_bringup/share/nav_bringup/rviz/nav2_view.rviz
```

In RViz:
1. Click **2D Pose Estimate** (or the `SetInitialPose` tool) and click+drag
   on the map where the robot actually is, roughly matching its heading.
   AMCL's particle cloud should collapse onto that pose within a few
   seconds of the robot seeing distinctive geometry.
2. Click **Nav2 Goal** (or the `GoalTool` in the Navigation 2 panel) and
   click+drag a target pose on the map. The robot should plan a path and
   drive to it.

### Sanity checks before/while navigating

```bash
ros2 topic hz /scan                          # ~10 Hz from RPLIDAR C1
ros2 topic hz /odom                          # ~50-100 Hz from mcu_bridge
ros2 run tf2_ros tf2_echo map odom            # published by AMCL once localized
ros2 topic echo /amcl_pose --once             # AMCL's best pose estimate
ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
  "{pose: {header: {frame_id: map}, pose: {position: {x: 1.0, y: 0.0}, orientation: {w: 1.0}}}}"
```

## Files

| File | Purpose |
|------|---------|
| `launch/bringup.launch.py`       | Full stack: sensor prereqs + localization + navigation (headless). |
| `launch/localization.launch.py`  | map_server + AMCL only (wraps `nav2_bringup`'s `localization_launch.py`). |
| `launch/navigation.launch.py`    | planner/controller/smoother/behavior/bt_navigator/velocity_smoother (wraps `nav2_bringup`'s `navigation_launch.py`). |
| `config/nav2_params.yaml`        | All Nav2 node parameters, tuned for this robot (see below). |
| `rviz/nav2_view.rviz`            | RViz layout: map, costmaps, plans, AMCL particles, Nav2 goal/pose tools. |

## Tuning notes

- **Controller: Regulated Pure Pursuit.** Chosen over DWB/MPPI for low CPU
  cost on the Pi and predictable behavior on a slow round diff-drive robot.
  `desired_linear_vel: 0.15` m/s matches the teleop default used for
  mapping — increase once navigation is verified safe and reliable.
- **Robot footprint** is a plain radius (`robot_radius: 0.175` m = half the
  350 mm chassis diameter) rather than a footprint polygon, since the base
  is round.
- **AMCL alphas** (`0.3`/`0.3`/`0.3`/`0.3`) are higher than the TurtleBot3
  defaults this file started from, since encoder-only odometry (no IMU)
  drifts more, especially in yaw — AMCL should correct from scan matches
  more readily rather than trusting the motion model.
- **Velocity limits** (`velocity_smoother`: 0.18 m/s / 0.8 rad/s max) are
  intentionally conservative for early testing. Raise gradually once you've
  verified obstacle avoidance and stopping distances in your space.
- **Costmap inflation** (`inflation_radius: 0.30` m) gives a decent buffer
  around obstacles for a small indoor robot; tighten it if the robot
  refuses to pass through narrow doorways/gaps it should fit through.

## Next steps toward full autonomous cleaning

This package gets you point-to-point navigation on a map you build by
teleop. The remaining pieces for the ultimate goal:

1. **Autonomous mapping** — either drive an exploration behavior (e.g.
   `nav2` frontier exploration) instead of teleop, or accept a one-time
   manual mapping pass per environment.
2. **Coverage path planning** — a full-coverage planner (e.g.
   `opennav_coverage`/`slic3r`-style boustrophedon planning over the free
   space in the saved map) that generates a sequence of waypoints/zig-zag
   path covering the whole floor, fed to this stack as a sequence of
   `navigate_through_poses` / `navigate_to_pose` goals.
3. **Cleaning unit control** — turning the vacuum/side-brush on while
   executing the coverage path and off during transit, if not already
   handled elsewhere.
