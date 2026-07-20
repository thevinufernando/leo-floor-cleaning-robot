"""Launch leo_cloud_bridge (soft arm + live map uplink).

Teleop / planners must publish to /cmd_vel_in. This node republishes to
/cmd_vel only when the phone arms the robot (mcu_bridge listens on /cmd_vel).

Example:
  ros2 launch leo_cloud_bridge cloud_bridge.launch.py \\
    relay_url:=wss://leo.YOUR_DOMAIN/ws token:=YOUR_TOKEN

  ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args \\
    -r cmd_vel:=cmd_vel_in
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    relay_url = DeclareLaunchArgument(
        'relay_url',
        default_value='wss://leo.example.com/ws',
        description='Public WSS URL of leo-relay')
    robot_id = DeclareLaunchArgument(
        'robot_id', default_value='LEO_001')
    token = DeclareLaunchArgument(
        'token', default_value='change-me-demo-token')
    map_min_interval = DeclareLaunchArgument(
        'map_min_interval_sec', default_value='1.0')

    bridge = Node(
        package='leo_cloud_bridge',
        executable='cloud_bridge_node',
        name='leo_cloud_bridge',
        output='screen',
        parameters=[{
            'relay_url': LaunchConfiguration('relay_url'),
            'robot_id': LaunchConfiguration('robot_id'),
            'token': LaunchConfiguration('token'),
            'map_min_interval_sec': LaunchConfiguration(
                'map_min_interval_sec'),
            'cmd_vel_in_topic': 'cmd_vel_in',
            'cmd_vel_out_topic': 'cmd_vel',
        }],
    )

    return LaunchDescription([
        relay_url, robot_id, token, map_min_interval, bridge,
    ])
