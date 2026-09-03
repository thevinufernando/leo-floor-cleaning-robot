# main_robotics_integration

ROS 2 (Jazzy) workspace running **on the Raspberry Pi** that is the
autonomous cleaning robot's onboard brain: it reads the LiDAR and drives
the wheel motors via a custom STM32 MCU, builds a map of the space with
SLAM, and navigates point-to-point on that map with Nav2. This is the
robotics integration layer of the [leo-floor-cleaning-robot](../..)
project — it sits between the MCU firmware (`mcu_firmware/`) and the
higher-level app (`leo-application/`).

The Pi runs **headless** (Ubuntu Server, no desktop). RViz and other GUI
tools run on a separate dev machine over the LAN — see
[NETWORK_SETUP.md](NETWORK_SETUP.md). A sibling workspace,
`robotics/viz_ws`, hosts the visualization-only packages for that dev
machine.

## Robot overview

Round differential-drive base, 350 mm diameter (dimensions and some
sensors are still placeholders pending final assembly — see
`src/robot_description/urdf/common_properties.xacro`):

- 2 driven wheels + 1 passive caster
- RPLIDAR C1 (2D LiDAR)
- IMU (populated on the PCB but **not currently fused** — see below)
- 4 cliff/drop sensors
- Cleaning unit: vacuum + side brush

TF tree (published by `robot_state_publisher` from the URDF, rooted at
the odometry frame):

```
odom -> base_footprint -> base_link -> left_wheel_link
                                     -> right_wheel_link
                                     -> caster_wheel_link
                                     -> laser
                                     -> imu_link
                                     -> cliff_front_left_link / cliff_front_right_link
                                     -> cliff_rear_left_link  / cliff_rear_right_link
                                     -> vacuum_link
                                     -> side_brush_link
```

During SLAM or navigation, `map -> odom` is added by slam_toolbox or AMCL
respectively, completing the standard REP-105 `map -> odom -> base_footprint`
chain.

## Packages

| Package | Role |
|---|---|
| [`robot_description`](src/robot_description/) | URDF/xacro model of the robot (chassis, wheels, LiDAR, IMU, cliff sensors, cleaning unit) and its TF tree. Single source of truth for all physical dimensions/mount positions (`common_properties.xacro`). |
| [`mcu_bridge`](src/mcu_bridge/) | Python node bridging the Pi and the STM32F722RET6 FreeRTOS MCU over USB CDC serial. Forwards `/cmd_vel` to the MCU as `MSG_CMD_VEL`; decodes the MCU's `MSG_ODOMETRY` stream into `nav_msgs/Odometry` and the `odom -> base_footprint` TF. Custom binary framed protocol (sync bytes, type, length, payload, CRC-16) — see `src/mcu_bridge/firmware_reference/mcu_bridge_protocol.h` for the wire format shared with the firmware. |
| [`rplidar_ros`](src/rplidar_ros/) | Vendored Slamtec driver for the RPLIDAR C1, publishing `/scan`. |
| [`lidar_bringup`](src/lidar_bringup/) | Brings up the RPLIDAR driver together with `robot_state_publisher`/`joint_state_publisher` so `/scan` and the robot's TF tree come up as one headless unit on the Pi. |
| [`slam_bringup`](src/slam_bringup/) | Online asynchronous `slam_toolbox` mapping: LiDAR + wheel odometry + robot TF -> a 2D occupancy-grid `/map`, savable for later Nav2 use. |
| [`nav_bringup`](src/nav_bringup/) | Nav2 bringup: AMCL localization against a saved map, plus point-to-point planning/following (planner, Regulated Pure Pursuit controller, behavior-tree navigator). |

Each package's own `README.md` (where present) has the detailed
architecture diagram, launch commands, tuning notes, and sanity checks —
`slam_bringup` and `nav_bringup` in particular are worth reading before
running a mapping or navigation session.

## How it fits together

```
                    /scan                         map->odom TF
  RPLIDAR C1 ──────────────────► slam_toolbox / AMCL ──────────┐
   (rplidar_ros,                                                │
    lidar_bringup)                                              ▼
                                                     odom->base_footprint TF
  STM32 MCU ──/odom──────────────►                  (mcu_bridge)
   ▲                                                             │
   │ MSG_CMD_VEL (motors)                                        ▼
   │                                              robot_state_publisher
  mcu_bridge ◄──/cmd_vel◄── teleop (mapping)      (base_footprint->...
                        or  Nav2 stack (navigation)  ->laser/imu/... from URDF)
```

- **Sensing:** `rplidar_ros` drives the LiDAR hardware; `lidar_bringup`
  wires it together with the robot's TF (from `robot_description`).
- **Odometry & actuation:** `mcu_bridge` is the only link to the MCU.
  Odometry is **encoder-only** — the IMU is not fused in (no
  `robot_localization`/EKF stage yet), so heading drifts slowly over
  distance. This is why SLAM/AMCL tuning leans on LiDAR scan matching to
  correct pose rather than trusting odometry alone (see the tuning notes
  in each package's README).
- **Mapping:** `slam_bringup` consumes `/scan` + `/odom` + TF and builds
  `/map` while you drive the robot (teleop) around the space.
- **Navigation:** `nav_bringup` consumes a saved map + the same sensor/TF
  inputs, localizes with AMCL, and plans/executes point-to-point goals via
  Nav2 (planner, controller, behavior tree, velocity smoother). It
  currently drives to a single goal at a time — coverage path planning for
  full autonomous cleaning is the next layer to build on top of it.
- **Cleaning unit** (vacuum + side brush) is modeled in the URDF but not
  yet wired to a control interface in this workspace.

See also [PI_CMD_VEL_REFERENCE.md](PI_CMD_VEL_REFERENCE.md) for exactly
how `/cmd_vel` is generated and forwarded to the MCU, and
[MCU_NOT_ENUMERATING.md](MCU_NOT_ENUMERATING.md) for a USB
enumeration debugging log.

## Sourcing this workspace

This is a standard `colcon` workspace. From this directory (the workspace
root, containing `src/`):

```bash
# 1. Source the ROS 2 Jazzy underlay (once per shell)
source /opt/ros/jazzy/setup.bash

# 2. Build the workspace
colcon build

# 3. Source this workspace's overlay
source install/setup.bash
```

To have both sourced automatically in every new shell (recommended on the
Pi, since this is its primary job):

```bash
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
echo "source $(pwd)/install/setup.bash" >> ~/.bashrc
```

After editing any package, rebuild just that package rather than the
whole workspace:

```bash
colcon build --packages-select mcu_bridge
source install/setup.bash
```

`build/`, `install/`, and `log/` are machine-specific and gitignored —
never commit them.

### Stable device symlinks

The MCU and LiDAR both need deterministic `/dev` paths (`/dev/mcu`,
`/dev/rplidar`) regardless of USB enumeration order. Install the udev
rules once per Pi:

```bash
sudo cp src/mcu_bridge/scripts/mcu_bridge.rules /etc/udev/rules.d/99-mcu-bridge.rules
sudo cp src/rplidar_ros/scripts/rplidar.rules   /etc/udev/rules.d/99-rplidar.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
ls -l /dev/mcu /dev/rplidar   # verify both resolved
```

### Cross-machine setup (Pi + RViz dev machine)

RViz and other GUI tools don't run on the Pi. See
[NETWORK_SETUP.md](NETWORK_SETUP.md) for `ROS_DOMAIN_ID` /
`RMW_IMPLEMENTATION` / networking requirements to visualize this
workspace's topics live from another machine on the same LAN (e.g. the
`viz_ws` workspace on a WSL2 dev machine).

## Typical sessions

Full walkthroughs with sanity checks live in each package's README, but
at a glance:

**Build a map:**
```bash
ros2 launch slam_bringup mapping.launch.py
ros2 run teleop_twist_keyboard teleop_twist_keyboard   # drive it around
ros2 run slam_bringup save_map.sh my_map ~/maps
```
See [src/slam_bringup/README.md](src/slam_bringup/README.md).

**Navigate on a saved map:**
```bash
ros2 launch nav_bringup bringup.launch.py map:=$HOME/maps/my_map.yaml
```
See [src/nav_bringup/README.md](src/nav_bringup/README.md).
