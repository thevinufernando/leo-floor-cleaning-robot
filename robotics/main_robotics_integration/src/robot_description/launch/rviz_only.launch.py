#!/usr/bin/env python3
"""
Open RViz2 alone with the robot_description config.

Meant to run on the dev machine (WSL2) while robot_state_publisher and
joint_state_publisher run headless on the Pi -- point both machines at the
same ROS_DOMAIN_ID (see NETWORK_SETUP.md). Mirrors
lidar_bringup/launch/rviz_only.launch.py.
"""

import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    rviz_config = os.path.join(
        get_package_share_directory('robot_description'),
        'rviz',
        'robot_description.rviz',
    )

    return LaunchDescription([
        Node(
            package='rviz2',
            executable='rviz2',
            name='rviz2',
            arguments=['-d', rviz_config],
            output='screen',
        ),
    ])
