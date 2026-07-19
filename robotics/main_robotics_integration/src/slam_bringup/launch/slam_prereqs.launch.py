#!/usr/bin/env python3
"""
Bring up everything slam_toolbox (online async) needs, WITHOUT the mapper.

This starts the full prerequisite stack so you can verify the TF tree and
topics are healthy before running online_async_slam.launch.py:

  * rplidar_ros            -> /scan  (frame_id: laser)
  * robot_state_publisher  -> base_footprint..base_link..laser/imu/... TF
  * mcu_bridge             -> /odom + odom->base_link TF, forwards cmd_vel

Resulting TF chain once the mapper is added:
    map (slam) -> odom (mcu_bridge) -> base_link -> laser (robot_state_pub)

Verify before mapping:
    ros2 topic hz /scan
    ros2 topic hz /odom
    ros2 run tf2_tools view_frames      # or: ros2 run tf2_ros tf2_echo odom base_link
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    lidar_serial_port = LaunchConfiguration('lidar_serial_port')
    mcu_port = LaunchConfiguration('mcu_port')

    # LiDAR + robot_state_publisher (URDF TF) come from lidar_bringup, which
    # already loads robot_description and publishes base_link->laser etc.
    lidar_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('lidar_bringup'),
                'launch',
                'lidar.launch.py',
            ])
        ]),
        launch_arguments={'serial_port': lidar_serial_port}.items(),
    )

    mcu_bridge_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('mcu_bridge'),
                'launch',
                'mcu_bridge.launch.py',
            ])
        ]),
        launch_arguments={'port': mcu_port}.items(),
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'lidar_serial_port', default_value='/dev/rplidar',
            description='Serial device for the RPLIDAR C1'),
        DeclareLaunchArgument(
            'mcu_port', default_value='/dev/mcu',
            description='Serial device (udev symlink) for the MCU USB CDC port'),
        lidar_launch,
        mcu_bridge_launch,
    ])
