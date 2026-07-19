#!/usr/bin/env python3
"""
Launch slam_toolbox in online asynchronous mapping mode.

Assumes its prerequisites are already running (start them separately, e.g.
via slam_bringup/launch/slam_prereqs.launch.py):
  * /scan          from rplidar_ros           (frame_id: laser)
  * odom->base_link TF + /odom  from mcu_bridge
  * base_link->laser TF (and rest of the robot) from robot_state_publisher

slam_toolbox adds the map->odom transform on top of that chain. This launch
starts ONLY the mapper, so the map is built the moment you run it.
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    use_sim_time = LaunchConfiguration('use_sim_time', default='false')
    params_file = LaunchConfiguration('params_file')

    default_params = PathJoinSubstitution([
        FindPackageShare('slam_bringup'),
        'config',
        'mapper_params_online_async.yaml',
    ])

    slam_node = Node(
        package='slam_toolbox',
        executable='async_slam_toolbox_node',
        name='slam_toolbox',
        output='screen',
        parameters=[
            params_file,
            {'use_sim_time': use_sim_time},
        ],
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'use_sim_time', default_value='false',
            description='Use /clock (simulation) time'),
        DeclareLaunchArgument(
            'params_file', default_value=default_params,
            description='slam_toolbox online-async parameter YAML'),
        slam_node,
    ])
