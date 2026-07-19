#!/usr/bin/env python3
"""
Full online-async SLAM mapping stack (Pi side, headless).

Starts everything needed to build a map in one shot:
  * slam prereqs  -> rplidar_ros (/scan), robot_state_publisher (robot TF),
                     mcu_bridge (/odom + odom->base_link TF, cmd_vel -> MCU)
  * slam_toolbox  -> map->odom TF and the occupancy grid on /map

It does NOT start teleop — drive the robot yourself so you control where it
goes while mapping. In a separate terminal on the Pi run:

    ros2 run teleop_twist_keyboard teleop_twist_keyboard

Visualise on the WSL2 dev machine (see robotics/viz_ws) — this launch is
headless and starts no RViz. When the map looks complete, save it with:

    ros2 run nav2_map_server map_saver_cli -f ~/maps/my_map

(or the slam_bringup/scripts/save_map.sh helper).
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    lidar_serial_port = LaunchConfiguration('lidar_serial_port')
    mcu_port = LaunchConfiguration('mcu_port')
    params_file = LaunchConfiguration('params_file')

    slam_share = FindPackageShare('slam_bringup')

    prereqs_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([slam_share, 'launch', 'slam_prereqs.launch.py'])
        ]),
        launch_arguments={
            'lidar_serial_port': lidar_serial_port,
            'mcu_port': mcu_port,
        }.items(),
    )

    slam_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([slam_share, 'launch', 'online_async_slam.launch.py'])
        ]),
        launch_arguments={'params_file': params_file}.items(),
    )

    default_params = PathJoinSubstitution([
        slam_share, 'config', 'mapper_params_online_async.yaml',
    ])

    return LaunchDescription([
        DeclareLaunchArgument(
            'lidar_serial_port', default_value='/dev/rplidar',
            description='Serial device for the RPLIDAR C1'),
        DeclareLaunchArgument(
            'mcu_port', default_value='/dev/mcu',
            description='Serial device (udev symlink) for the MCU USB CDC port'),
        DeclareLaunchArgument(
            'params_file', default_value=default_params,
            description='slam_toolbox online-async parameter YAML'),
        prereqs_launch,
        slam_launch,
    ])
