"""
ROS 2 node bridging the Pi and the STM32F722 MCU over USB CDC.

Consumes the MCU's binary MSG_ODOMETRY stream and publishes it as a
``nav_msgs/Odometry`` message plus the ``odom`` -> ``base_link`` TF, and
forwards ``cmd_vel`` (``geometry_msgs/Twist``) to the MCU as MSG_CMD_VEL.

The odometry + odom->base_link TF this node publishes is a prerequisite for
running slam_toolbox in online asynchronous mode: slam_toolbox provides
map->odom, but expects odom->base_link to already exist.
"""

import math

from geometry_msgs.msg import Quaternion, TransformStamped, Twist
from mcu_bridge.protocol import (
    decode_odometry,
    encode_cmd_vel,
    FrameDecoder,
    MsgType,
)
from nav_msgs.msg import Odometry
import rclpy
from rclpy.node import Node
import serial
from tf2_ros import TransformBroadcaster


def yaw_to_quaternion(yaw: float) -> Quaternion:
    """Build a quaternion from a yaw-only (planar) rotation."""
    q = Quaternion()
    q.z = math.sin(yaw * 0.5)
    q.w = math.cos(yaw * 0.5)
    return q


class McuBridgeNode(Node):
    """Publishes odometry from, and forwards cmd_vel to, the MCU."""

    def __init__(self):
        """Open the serial port and set up publishers/subscriptions."""
        super().__init__('mcu_bridge_node')

        self.declare_parameter('port', '/dev/mcu')
        self.declare_parameter('baudrate', 115200)
        self.declare_parameter('odom_frame_id', 'odom')
        self.declare_parameter('base_frame_id', 'base_link')
        self.declare_parameter('publish_tf', True)
        # Wheel-only odometry: trust x/y/yaw modestly, and yaw least of all so
        # slam_toolbox leans on its scan match. Diagonal [x, y, yaw].
        self.declare_parameter('pose_covariance_diagonal', [0.05, 0.05, 0.2])
        self.declare_parameter('twist_covariance_diagonal', [0.05, 0.05, 0.2])

        port = self.get_parameter('port').get_parameter_value().string_value
        baudrate = self.get_parameter('baudrate').get_parameter_value().integer_value
        self._odom_frame = self.get_parameter(
            'odom_frame_id').get_parameter_value().string_value
        self._base_frame = self.get_parameter(
            'base_frame_id').get_parameter_value().string_value
        self._publish_tf = self.get_parameter(
            'publish_tf').get_parameter_value().bool_value
        self._pose_cov_diag = list(self.get_parameter(
            'pose_covariance_diagonal').get_parameter_value().double_array_value)
        self._twist_cov_diag = list(self.get_parameter(
            'twist_covariance_diagonal').get_parameter_value().double_array_value)

        self._serial = serial.Serial(port, baudrate, timeout=0)
        self._decoder = FrameDecoder()
        self.get_logger().info(f'Opened serial port {port} @ {baudrate} baud')

        self._odom_pub = self.create_publisher(Odometry, 'odom', 10)
        self._tf_broadcaster = TransformBroadcaster(self)
        self._sub = self.create_subscription(
            Twist, 'cmd_vel', self._on_cmd_vel, 10)

        # MCU streams MSG_ODOMETRY at ~50 Hz; poll comfortably faster so
        # frames don't pile up in the OS serial buffer.
        self._read_timer = self.create_timer(0.01, self._on_read_timer)

    def _on_cmd_vel(self, msg: Twist):
        try:
            self._serial.write(encode_cmd_vel(msg.linear.x, msg.angular.z))
        except serial.SerialException as exc:
            self.get_logger().error(f'Serial write failed: {exc}')

    def _on_read_timer(self):
        try:
            data = self._serial.read(4096)
        except serial.SerialException as exc:
            self.get_logger().error(f'Serial read failed: {exc}')
            return

        if not data:
            return

        for msg_type, payload in self._decoder.feed(data):
            if msg_type == MsgType.ODOMETRY:
                self._handle_odometry(payload)

    def _handle_odometry(self, payload: bytes):
        try:
            x, y, theta, v, omega = decode_odometry(payload)
        except ValueError as exc:
            self.get_logger().warn(f'Bad odometry frame: {exc}')
            return

        stamp = self.get_clock().now().to_msg()
        orientation = yaw_to_quaternion(theta)

        odom = Odometry()
        odom.header.stamp = stamp
        odom.header.frame_id = self._odom_frame
        odom.child_frame_id = self._base_frame

        odom.pose.pose.position.x = x
        odom.pose.pose.position.y = y
        odom.pose.pose.orientation = orientation
        # Pose covariance is a 6x6 row-major [x, y, z, roll, pitch, yaw].
        odom.pose.covariance[0] = self._pose_cov_diag[0]    # x
        odom.pose.covariance[7] = self._pose_cov_diag[1]    # y
        odom.pose.covariance[35] = self._pose_cov_diag[2]   # yaw

        odom.twist.twist.linear.x = v
        odom.twist.twist.angular.z = omega
        odom.twist.covariance[0] = self._twist_cov_diag[0]    # vx
        odom.twist.covariance[7] = self._twist_cov_diag[1]    # vy
        odom.twist.covariance[35] = self._twist_cov_diag[2]   # vyaw

        self._odom_pub.publish(odom)

        if self._publish_tf:
            tf = TransformStamped()
            tf.header.stamp = stamp
            tf.header.frame_id = self._odom_frame
            tf.child_frame_id = self._base_frame
            tf.transform.translation.x = x
            tf.transform.translation.y = y
            tf.transform.rotation = orientation
            self._tf_broadcaster.sendTransform(tf)

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
