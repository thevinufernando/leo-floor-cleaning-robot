#!/usr/bin/env python3
"""
Nav2 navigation stack: planner, controller (Regulated Pure Pursuit),
smoother, behavior server, bt_navigator, velocity smoother, and the
costmaps that back them.

Assumes localization (map_server + AMCL, see localization.launch.py) is
already running and publishing the map->odom transform, and that the sensor
prerequisites (rplidar_ros, mcu_bridge, robot_state_publisher) are up.

Wraps nav2_bringup/launch/navigation_launch.py so we inherit its lifecycle
wiring, pointed at this package's params file.

IMPORTANT topic wiring: nav2_bringup's navigation_launch.py internally
remaps controller_server/behavior_server/bt_navigator's cmd_vel output to
cmd_vel_nav, and velocity_smoother consumes cmd_vel_nav and publishes the
rate/accel-limited result on cmd_vel_smoothed (hardcoded in
nav2_velocity_smoother's source, not remappable via that launch file's
arguments) -- NOT plain cmd_vel. Since mcu_bridge subscribes to plain
cmd_vel, this launch adds a topic_tools relay node forwarding
cmd_vel_smoothed -> cmd_vel so Nav2's smoothed output actually reaches the
MCU.
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    params_file = LaunchConfiguration('params_file')
    use_sim_time = LaunchConfiguration('use_sim_time')
    autostart = LaunchConfiguration('autostart')

    default_params = PathJoinSubstitution([
        FindPackageShare('nav_bringup'), 'config', 'nav2_params.yaml',
    ])

    navigation_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('nav2_bringup'), 'launch', 'navigation_launch.py',
            ])
        ]),
        launch_arguments={
            'params_file': params_file,
            'use_sim_time': use_sim_time,
            'autostart': autostart,
            'use_composition': 'False',
        }.items(),
    )

    # See module docstring: velocity_smoother's real output topic is
    # cmd_vel_smoothed, but mcu_bridge listens on plain cmd_vel.
    cmd_vel_relay = Node(
        package='topic_tools',
        executable='relay',
        name='cmd_vel_smoothed_relay',
        output='screen',
        arguments=['cmd_vel_smoothed', 'cmd_vel'],
        parameters=[{'use_sim_time': use_sim_time}],
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'params_file', default_value=default_params,
            description='Nav2 parameter YAML (planner, controller, costmaps, BT navigator).'),
        DeclareLaunchArgument(
            'use_sim_time', default_value='false',
            description='Use /clock (simulation) time'),
        DeclareLaunchArgument(
            'autostart', default_value='true',
            description='Automatically configure+activate the navigation lifecycle nodes'),
        navigation_launch,
        cmd_vel_relay,
    ])
