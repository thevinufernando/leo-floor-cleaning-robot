#!/usr/bin/env python3
"""
Load the robot URDF/xacro and visualize it (and its TF tree) in RViz2.

By default this uses joint_state_publisher_gui, which opens sliders for
every non-fixed joint (wheels, side brush) so you can manually move them
and watch the TF tree update live. Set use_gui:=false to instead use the
plain joint_state_publisher (publishes zero/default joint states, no GUI)
-- useful once real joint states are published by another node instead.
"""

import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition, UnlessCondition
from launch.substitutions import Command, LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def generate_launch_description():
    pkg_share = get_package_share_directory('robot_description')

    xacro_file = PathJoinSubstitution(
        [pkg_share, 'urdf', 'robot.urdf.xacro']
    )
    rviz_config = os.path.join(pkg_share, 'rviz', 'robot_description.rviz')

    use_gui = LaunchConfiguration('use_gui')
    use_rviz = LaunchConfiguration('use_rviz')

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

    joint_state_publisher_gui_node = Node(
        package='joint_state_publisher_gui',
        executable='joint_state_publisher_gui',
        name='joint_state_publisher_gui',
        condition=IfCondition(use_gui),
    )

    joint_state_publisher_node = Node(
        package='joint_state_publisher',
        executable='joint_state_publisher',
        name='joint_state_publisher',
        condition=UnlessCondition(use_gui),
    )

    rviz_node = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        arguments=['-d', rviz_config],
        output='screen',
        condition=IfCondition(use_rviz),
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'use_gui',
            default_value='true',
            description='Launch joint_state_publisher_gui with sliders instead of joint_state_publisher'),

        DeclareLaunchArgument(
            'use_rviz',
            default_value='true',
            description='Open RViz2 with the robot_description.rviz config'),

        robot_state_publisher_node,
        joint_state_publisher_gui_node,
        joint_state_publisher_node,
        rviz_node,
    ])
