#!/usr/bin/env python3
"""
Keyboard teleop for driving the robot during SLAM mapping (Pi side).

Publishes geometry_msgs/Twist on /cmd_vel, which mcu_bridge forwards to the
MCU as MSG_CMD_VEL; the MCU turns it into per-wheel motor commands. Driving
the robot changes its pose, which is what lets slam_toolbox extend the map.

teleop_twist_keyboard reads the keyboard from its controlling terminal, so it
MUST run in a real interactive terminal (attach a keyboard to the Pi, or an
SSH session with a TTY). Prefer running it directly so key presses reach it:

    ros2 run teleop_twist_keyboard teleop_twist_keyboard

This launch file is provided for convenience/parametrisation, but note that
launch captures stdout — if keys don't register, fall back to `ros2 run`
above in its own terminal.

Speeds are kept low by default: this is a small indoor cleaning robot and
slow, smooth motion produces cleaner scan matching / maps.
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    speed = LaunchConfiguration('speed')
    turn = LaunchConfiguration('turn')

    teleop_node = Node(
        package='teleop_twist_keyboard',
        executable='teleop_twist_keyboard',
        name='teleop_twist_keyboard',
        output='screen',
        prefix='xterm -e',   # give it its own TTY when a GUI/xterm exists
        parameters=[{
            'speed': speed,
            'turn': turn,
        }],
        remappings=[('/cmd_vel', '/cmd_vel')],
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'speed', default_value='0.15',
            description='Initial linear speed (m/s). Keep modest for clean maps.'),
        DeclareLaunchArgument(
            'turn', default_value='0.6',
            description='Initial angular speed (rad/s).'),
        teleop_node,
    ])
