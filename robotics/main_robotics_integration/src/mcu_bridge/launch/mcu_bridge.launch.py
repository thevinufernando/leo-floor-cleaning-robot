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
        description='Serial baudrate, must match MCU firmware')
    imu_frame_id_arg = DeclareLaunchArgument(
        'imu_frame_id', default_value='imu_link',
        description='frame_id for published sensor_msgs/Imu messages, '
                    'must match robot_description/urdf/imu.xacro')

    bridge_node = Node(
        package='mcu_bridge',
        executable='bridge_node',
        name='mcu_bridge_node',
        output='screen',
        parameters=[{
            'port': LaunchConfiguration('port'),
            'baudrate': LaunchConfiguration('baudrate'),
            'imu_frame_id': LaunchConfiguration('imu_frame_id'),
        }],
    )

    return LaunchDescription([port_arg, baudrate_arg, imu_frame_id_arg, bridge_node])
