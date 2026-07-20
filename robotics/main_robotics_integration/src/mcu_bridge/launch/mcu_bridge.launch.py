from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    port_arg = DeclareLaunchArgument(
        'port', default_value='/dev/mcu',
        description='Serial device for the MCU (stable udev symlink; '
                    'see src/mcu_bridge/scripts/mcu_bridge.rules)')
    baudrate_arg = DeclareLaunchArgument(
        'baudrate', default_value='115200',
        description='Serial baudrate. Irrelevant for USB CDC but kept so '
                    'pyserial has a value to open the port with.')
    odom_frame_arg = DeclareLaunchArgument(
        'odom_frame_id', default_value='odom',
        description='frame_id for the published nav_msgs/Odometry and the '
                    'parent of the broadcast odom->base_link TF')
    base_frame_arg = DeclareLaunchArgument(
        'base_frame_id', default_value='base_footprint',
        description='child_frame_id of the odometry / odom->base_footprint '
                    'TF. Per REP-105 this is the robot ground projection '
                    '(the URDF root), not base_link — robot_state_publisher '
                    'supplies base_footprint->base_link from the URDF.')
    publish_tf_arg = DeclareLaunchArgument(
        'publish_tf', default_value='true',
        description='Broadcast odom->base_link TF. Set false if an external '
                    'EKF (robot_localization) owns that transform instead.')

    bridge_node = Node(
        package='mcu_bridge',
        executable='bridge_node',
        name='mcu_bridge_node',
        output='screen',
        parameters=[{
            'port': LaunchConfiguration('port'),
            'baudrate': LaunchConfiguration('baudrate'),
            'odom_frame_id': LaunchConfiguration('odom_frame_id'),
            'base_frame_id': LaunchConfiguration('base_frame_id'),
            'publish_tf': LaunchConfiguration('publish_tf'),
        }],
    )

    return LaunchDescription([
        port_arg, baudrate_arg, odom_frame_arg, base_frame_arg,
        publish_tf_arg, bridge_node,
    ])
