#!/usr/bin/env python3
"""
Nav2 localization: map_server (serves a pre-built static map) + AMCL.

Assumes the sensor/odometry prerequisites are already running (rplidar_ros
publishing /scan, mcu_bridge publishing /odom + odom->base_footprint TF,
robot_state_publisher publishing the rest of the robot TF) — e.g. via
slam_bringup/launch/slam_prereqs.launch.py.

This wraps the standard nav2_bringup/launch/localization_launch.py so we
inherit its lifecycle-manager wiring, but points it at this package's
params file and requires an explicit map (no default).

TF produced by this launch:
    map (AMCL) -> odom (mcu_bridge) -> base_footprint -> ... (robot_state_publisher)
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    map_yaml = LaunchConfiguration('map')
    params_file = LaunchConfiguration('params_file')
    use_sim_time = LaunchConfiguration('use_sim_time')
    autostart = LaunchConfiguration('autostart')

    default_params = PathJoinSubstitution([
        FindPackageShare('nav_bringup'), 'config', 'nav2_params.yaml',
    ])

    localization_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('nav2_bringup'), 'launch', 'localization_launch.py',
            ])
        ]),
        launch_arguments={
            'map': map_yaml,
            'params_file': params_file,
            'use_sim_time': use_sim_time,
            'autostart': autostart,
            'use_composition': 'False',
        }.items(),
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'map', default_value='',
            description='Full path to the map YAML file saved from a SLAM '
                        'session (see slam_bringup/scripts/save_map.sh). '
                        'Required — no default map is shipped.'),
        DeclareLaunchArgument(
            'params_file', default_value=default_params,
            description='Nav2 parameter YAML (AMCL, map_server, lifecycle manager).'),
        DeclareLaunchArgument(
            'use_sim_time', default_value='false',
            description='Use /clock (simulation) time'),
        DeclareLaunchArgument(
            'autostart', default_value='true',
            description='Automatically configure+activate the localization lifecycle nodes'),
        localization_launch,
    ])
