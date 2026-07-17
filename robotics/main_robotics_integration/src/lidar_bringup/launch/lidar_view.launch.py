#!/usr/bin/env python3
"""
Bring up RPLIDAR C1 with TF and open RViz2 for visualization.
"""

import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    serial_port = LaunchConfiguration('serial_port', default='/dev/rplidar')

    rviz_config = os.path.join(
        get_package_share_directory('lidar_bringup'),
        'rviz',
        'lidar_view.rviz',
    )

    lidar_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('lidar_bringup'),
                'launch',
                'lidar.launch.py',
            ])
        ]),
        launch_arguments={'serial_port': serial_port}.items(),
    )

    rviz_node = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        arguments=['-d', rviz_config],
        output='screen',
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'serial_port',
            default_value='/dev/rplidar',
            description='Serial device the RPLIDAR C1 is connected to'),

        lidar_launch,
        rviz_node,
    ])
