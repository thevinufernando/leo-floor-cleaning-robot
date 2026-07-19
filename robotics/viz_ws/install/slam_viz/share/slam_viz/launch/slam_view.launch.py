#!/usr/bin/env python3
"""
RViz-only view of the live SLAM map (WSL2 dev machine).

Runs ONLY RViz2 — no drivers, no slam_toolbox. It discovers the Pi's topics
and TF over the LAN (matching ROS_DOMAIN_ID / RMW_IMPLEMENTATION; see
robotics/viz_ws/README.md and the repo NETWORK_SETUP.md), then renders:
  * /map              occupancy grid from slam_toolbox
  * /scan             live RPLIDAR C1 scan
  * /robot_description robot model (published by the Pi's robot_state_publisher)
  * TF tree           map -> odom -> base_link -> laser/...

Start the mapping stack on the Pi first:
    ros2 launch slam_bringup mapping.launch.py
"""

import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    default_rviz = os.path.join(
        get_package_share_directory('slam_viz'),
        'rviz',
        'slam_view.rviz',
    )

    rviz_config = LaunchConfiguration('rviz_config')

    return LaunchDescription([
        DeclareLaunchArgument(
            'rviz_config', default_value=default_rviz,
            description='RViz2 config file to load'),
        Node(
            package='rviz2',
            executable='rviz2',
            name='rviz2',
            arguments=['-d', rviz_config],
            output='screen',
        ),
    ])
