#!/usr/bin/env python3
"""
Full point-to-point Nav2 stack (Pi side, headless).

Starts everything needed to send the robot navigation goals on a
pre-built map, in one shot:
  * sensor prereqs -> rplidar_ros (/scan), robot_state_publisher (robot TF),
                       mcu_bridge (/odom + odom->base_footprint TF, cmd_vel -> MCU)
                       (reuses slam_bringup/launch/slam_prereqs.launch.py —
                       identical stack to what SLAM mapping used)
  * localization    -> map_server (serves the saved map) + AMCL
  * navigation       -> planner, controller (Regulated Pure Pursuit),
                        smoother, behavior server, bt_navigator, velocity smoother

Requires a map already saved from a SLAM session (see
slam_bringup/scripts/save_map.sh) — pass its path with map:=.

This launch is headless and starts no RViz. Visualise / send goals from the
WSL2 dev machine (see robotics/viz_ws) with rviz2 + the Nav2 panel, or use
nav_bringup/rviz/nav2_view.rviz on a machine with a display attached.

Example:
    ros2 launch nav_bringup bringup.launch.py map:=$HOME/maps/my_map.yaml
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    lidar_serial_port = LaunchConfiguration('lidar_serial_port')
    mcu_port = LaunchConfiguration('mcu_port')
    map_yaml = LaunchConfiguration('map')
    params_file = LaunchConfiguration('params_file')
    use_sim_time = LaunchConfiguration('use_sim_time')
    autostart = LaunchConfiguration('autostart')

    nav_share = FindPackageShare('nav_bringup')

    prereqs_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('slam_bringup'), 'launch', 'slam_prereqs.launch.py',
            ])
        ]),
        launch_arguments={
            'lidar_serial_port': lidar_serial_port,
            'mcu_port': mcu_port,
        }.items(),
    )

    localization_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([nav_share, 'launch', 'localization.launch.py'])
        ]),
        launch_arguments={
            'map': map_yaml,
            'params_file': params_file,
            'use_sim_time': use_sim_time,
            'autostart': autostart,
        }.items(),
    )

    navigation_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([nav_share, 'launch', 'navigation.launch.py'])
        ]),
        launch_arguments={
            'params_file': params_file,
            'use_sim_time': use_sim_time,
            'autostart': autostart,
        }.items(),
    )

    default_params = PathJoinSubstitution([
        nav_share, 'config', 'nav2_params.yaml',
    ])

    return LaunchDescription([
        DeclareLaunchArgument(
            'lidar_serial_port', default_value='/dev/rplidar',
            description='Serial device for the RPLIDAR C1'),
        DeclareLaunchArgument(
            'mcu_port', default_value='/dev/mcu',
            description='Serial device (udev symlink) for the MCU USB CDC port'),
        DeclareLaunchArgument(
            'map', default_value='',
            description='Full path to the map YAML file saved from a SLAM '
                        'session (see slam_bringup/scripts/save_map.sh). '
                        'Required — no default map is shipped.'),
        DeclareLaunchArgument(
            'params_file', default_value=default_params,
            description='Nav2 parameter YAML.'),
        DeclareLaunchArgument(
            'use_sim_time', default_value='false',
            description='Use /clock (simulation) time'),
        DeclareLaunchArgument(
            'autostart', default_value='true',
            description='Automatically configure+activate all Nav2 lifecycle nodes'),
        prereqs_launch,
        localization_launch,
        navigation_launch,
    ])
