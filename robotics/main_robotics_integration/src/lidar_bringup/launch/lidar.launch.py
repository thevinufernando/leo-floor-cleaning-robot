#!/usr/bin/env python3
"""
Bring up RPLIDAR C1 with TF supplied by the robot_description URDF.

The full robot TF tree (base_footprint -> base_link -> ... -> laser) now
comes from the robot_description package via robot_state_publisher, which
is the single source of truth for base_link -> laser. See
robot_description/urdf/lidar.xacro / common_properties.xacro to adjust the
LiDAR's physical mounting position.
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import Command, LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    serial_port = LaunchConfiguration('serial_port', default='/dev/rplidar')
    frame_id = LaunchConfiguration('frame_id', default='laser')

    rplidar_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                FindPackageShare('rplidar_ros'),
                'launch',
                'rplidar_c1_launch.py',
            ])
        ]),
        launch_arguments={
            'serial_port': serial_port,
            'frame_id': frame_id,
        }.items(),
    )

    xacro_file = PathJoinSubstitution(
        [FindPackageShare('robot_description'), 'urdf', 'robot.urdf.xacro']
    )

    robot_description = ParameterValue(
        Command(['xacro ', xacro_file]),
        value_type=str,
    )

    robot_state_publisher_node = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        name='robot_state_publisher',
        output='screen',
        parameters=[{
            'robot_description': robot_description,
        }],
    )

    # Publishes zero-valued joint states for the wheels/brush so
    # robot_state_publisher can complete the TF tree. Replace with real
    # joint state feedback (e.g. from mcu_bridge) once encoders are wired up.
    joint_state_publisher_node = Node(
        package='joint_state_publisher',
        executable='joint_state_publisher',
        name='joint_state_publisher',
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'serial_port',
            default_value='/dev/rplidar',
            description='Serial device the RPLIDAR C1 is connected to'),

        DeclareLaunchArgument(
            'frame_id',
            default_value='laser',
            description='TF frame id published on the /scan topic'),

        rplidar_launch,
        robot_state_publisher_node,
        joint_state_publisher_node,
    ])
