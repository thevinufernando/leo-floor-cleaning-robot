"""ROS 2 node bridging the Pi and the STM32F722RET6 MCU over USB CDC."""

from geometry_msgs.msg import Twist
from mcu_bridge.imu_text_parser import parse_imu_line
from mcu_bridge.protocol import encode_cmd_velocity
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Imu
import serial

# Orientation is not measured on-board (no fusion/EKF on the MCU yet), so
# Imu.orientation is left at all-zero with covariance[0] = -1 per the
# sensor_msgs/Imu convention meaning "orientation data is not available".
ORIENTATION_UNKNOWN_COVARIANCE = -1.0

# Rough placeholder covariances for the ICM-42688-P, until characterized
# from real datasheet/Allan-variance figures.
ACCEL_COVARIANCE_DIAG = 0.02   # (m/s^2)^2
GYRO_COVARIANCE_DIAG = 0.001   # (rad/s)^2


class McuBridgeNode(Node):
    """Publishes IMU telemetry from, and forwards cmd_vel to, the MCU."""

    def __init__(self):
        """Open the serial port and set up publishers/subscriptions."""
        super().__init__('mcu_bridge_node')

        self.declare_parameter('port', '/dev/mcu')
        self.declare_parameter('baudrate', 115200)
        self.declare_parameter('imu_frame_id', 'imu_link')

        port = self.get_parameter('port').get_parameter_value().string_value
        baudrate = self.get_parameter('baudrate').get_parameter_value().integer_value
        self._imu_frame_id = self.get_parameter('imu_frame_id').get_parameter_value().string_value

        self._serial = serial.Serial(port, baudrate, timeout=0)
        self._rx_buffer = bytearray()
        self.get_logger().info(f'Opened serial port {port} @ {baudrate} baud')

        self._imu_pub = self.create_publisher(Imu, 'imu/data', 10)
        self._sub = self.create_subscription(
            Twist, 'cmd_vel', self._on_cmd_vel, 10)

        # The MCU currently streams IMU debug text at 10 Hz (see firmware
        # README); poll faster than that so lines don't pile up in the OS
        # serial buffer.
        self._read_timer = self.create_timer(0.02, self._on_read_timer)

    def _on_cmd_vel(self, msg: Twist):
        frame = encode_cmd_velocity(msg.linear.x, msg.angular.z)
        self._serial.write(frame)

    def _on_read_timer(self):
        try:
            data = self._serial.read(4096)
        except serial.SerialException as exc:
            self.get_logger().error(f'Serial read failed: {exc}')
            return

        if not data:
            return

        self._rx_buffer.extend(data)
        while b'\n' in self._rx_buffer:
            line, _, rest = self._rx_buffer.partition(b'\n')
            self._rx_buffer = bytearray(rest)
            self._handle_line(line.decode('ascii', errors='replace'))

    def _handle_line(self, line: str):
        parsed = parse_imu_line(line)
        if parsed is None:
            return
        ax, ay, az, gx, gy, gz, _temp_c = parsed
        self._publish_imu(ax, ay, az, gx, gy, gz)

    def _publish_imu(self, ax, ay, az, gx, gy, gz):
        msg = Imu()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = self._imu_frame_id

        msg.orientation_covariance[0] = ORIENTATION_UNKNOWN_COVARIANCE

        msg.linear_acceleration.x = ax
        msg.linear_acceleration.y = ay
        msg.linear_acceleration.z = az
        msg.linear_acceleration_covariance[0] = ACCEL_COVARIANCE_DIAG
        msg.linear_acceleration_covariance[4] = ACCEL_COVARIANCE_DIAG
        msg.linear_acceleration_covariance[8] = ACCEL_COVARIANCE_DIAG

        msg.angular_velocity.x = gx
        msg.angular_velocity.y = gy
        msg.angular_velocity.z = gz
        msg.angular_velocity_covariance[0] = GYRO_COVARIANCE_DIAG
        msg.angular_velocity_covariance[4] = GYRO_COVARIANCE_DIAG
        msg.angular_velocity_covariance[8] = GYRO_COVARIANCE_DIAG

        self._imu_pub.publish(msg)

    def destroy_node(self):
        """Close the serial port before tearing down the node."""
        if self._serial.is_open:
            self._serial.close()
        super().destroy_node()


def main(args=None):
    """Run the mcu_bridge node until interrupted."""
    rclpy.init(args=args)
    node = McuBridgeNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
