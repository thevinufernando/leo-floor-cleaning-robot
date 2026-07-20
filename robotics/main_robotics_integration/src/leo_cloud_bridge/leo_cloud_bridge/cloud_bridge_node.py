"""
ROS 2 node: outbound WSS to leo-relay for live /map + soft arm of cmd_vel.

Subscribes:
  /map (nav_msgs/OccupancyGrid) — encoded to PNG and sent as type=map
  cmd_vel_in (geometry_msgs/Twist) — gated; remapped from /cmd_vel by launch

Publishes:
  /cmd_vel (geometry_msgs/Twist) — zero when disarmed

Parameters:
  relay_url, robot_id, token, map_min_interval_sec, status_interval_sec
"""

from __future__ import annotations

import asyncio
import json
import math
import threading
import time
from typing import Any

from geometry_msgs.msg import Twist
from leo_cloud_bridge.map_encode import occupancy_grid_to_png_b64
from nav_msgs.msg import OccupancyGrid
import rclpy
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy


def _map_qos() -> QoSProfile:
    # Match slam_toolbox Transient Local /map so late subscribers get the map.
    return QoSProfile(
        reliability=ReliabilityPolicy.RELIABLE,
        durability=DurabilityPolicy.TRANSIENT_LOCAL,
        history=HistoryPolicy.KEEP_LAST,
        depth=1,
    )


class CloudBridgeNode(Node):
    """Bridge ROS map/cmd_vel to the internet relay."""

    def __init__(self) -> None:
        super().__init__('leo_cloud_bridge')

        self.declare_parameter('relay_url', 'wss://leo.example.com/ws')
        self.declare_parameter('robot_id', 'LEO_001')
        self.declare_parameter('token', 'change-me-demo-token')
        self.declare_parameter('map_min_interval_sec', 1.0)
        self.declare_parameter('status_interval_sec', 2.0)
        self.declare_parameter('cmd_vel_in_topic', 'cmd_vel_in')
        self.declare_parameter('cmd_vel_out_topic', 'cmd_vel')

        self._relay_url = self.get_parameter('relay_url').value
        self._robot_id = self.get_parameter('robot_id').value
        self._token = self.get_parameter('token').value
        self._map_min_interval = float(
            self.get_parameter('map_min_interval_sec').value)
        self._status_interval = float(
            self.get_parameter('status_interval_sec').value)
        cmd_in = self.get_parameter('cmd_vel_in_topic').value
        cmd_out = self.get_parameter('cmd_vel_out_topic').value

        self._armed = False
        self._ws_connected = False
        self._last_map_sent = 0.0
        self._outbound: asyncio.Queue | None = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._stop = threading.Event()

        self._cmd_pub = self.create_publisher(Twist, cmd_out, 10)
        self.create_subscription(Twist, cmd_in, self._on_cmd_vel, 10)
        self.create_subscription(
            OccupancyGrid, 'map', self._on_map, _map_qos())

        self.create_timer(0.2, self._tick_zero_when_disarmed)
        self.create_timer(self._status_interval, self._tick_status)

        self._ws_thread = threading.Thread(
            target=self._ws_thread_main, name='LeoRelayWs', daemon=True)
        self._ws_thread.start()
        self.get_logger().info(
            f'leo_cloud_bridge starting; relay={self._relay_url} '
            f'robot_id={self._robot_id}')

    def destroy_node(self) -> bool:
        self._stop.set()
        if self._loop and self._outbound:
            self._loop.call_soon_threadsafe(self._outbound.put_nowait, None)
        return super().destroy_node()

    def _enqueue(self, payload: dict[str, Any]) -> None:
        if self._loop is None or self._outbound is None:
            return
        try:
            self._loop.call_soon_threadsafe(self._outbound.put_nowait, payload)
        except Exception:
            pass

    def _on_cmd_vel(self, msg: Twist) -> None:
        if not self._armed:
            return
        self._cmd_pub.publish(msg)

    def _tick_zero_when_disarmed(self) -> None:
        if self._armed:
            return
        zero = Twist()
        self._cmd_pub.publish(zero)

    def _tick_status(self) -> None:
        self._enqueue({
            'type': 'status',
            'armed': self._armed,
            'connected': True,
            'robotOnline': self._ws_connected,
            'robotId': self._robot_id,
        })

    def _on_map(self, msg: OccupancyGrid) -> None:
        now = time.monotonic()
        if now - self._last_map_sent < self._map_min_interval:
            return
        self._last_map_sent = now

        width = msg.info.width
        height = msg.info.height
        if width == 0 or height == 0:
            return

        try:
            png_b64 = occupancy_grid_to_png_b64(width, height, msg.data)
        except Exception as exc:
            self.get_logger().error(f'map encode failed: {exc}')
            return

        yaw = _yaw_from_quat(msg.info.origin.orientation)
        stamp = float(msg.header.stamp.sec) + float(
            msg.header.stamp.nanosec) * 1e-9
        self._enqueue({
            'type': 'map',
            'width': width,
            'height': height,
            'resolution': float(msg.info.resolution),
            'origin': {
                'x': float(msg.info.origin.position.x),
                'y': float(msg.info.origin.position.y),
                'yaw': yaw,
            },
            'png_base64': png_b64,
            'stamp': stamp,
        })

    def _handle_inbound(self, msg: dict[str, Any]) -> None:
        msg_type = msg.get('type')
        if msg_type == 'set_armed':
            self._armed = bool(msg.get('armed', False))
            self.get_logger().info(f'armed={self._armed}')
            if not self._armed:
                self._cmd_pub.publish(Twist())
            self._enqueue({
                'type': 'status',
                'armed': self._armed,
                'connected': True,
                'robotOnline': True,
                'robotId': self._robot_id,
            })
        elif msg_type == 'welcome':
            self.get_logger().info(f'relay welcome: {msg}')
        elif msg_type == 'error':
            self.get_logger().warning(f'relay error: {msg.get("message")}')
        elif msg_type == 'pong':
            pass

    def _ws_thread_main(self) -> None:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        self._loop = loop
        self._outbound = asyncio.Queue()
        try:
            loop.run_until_complete(self._ws_session())
        finally:
            loop.close()

    async def _ws_session(self) -> None:
        import websockets

        backoff = 1.0
        while not self._stop.is_set():
            try:
                self.get_logger().info(f'connecting to {self._relay_url}')
                async with websockets.connect(
                        self._relay_url, ping_interval=20,
                        ping_timeout=20) as ws:
                    self._ws_connected = True
                    backoff = 1.0
                    await ws.send(json.dumps({
                        'type': 'hello',
                        'role': 'robot',
                        'robotId': self._robot_id,
                        'token': self._token,
                    }))

                    async def reader() -> None:
                        async for raw in ws:
                            try:
                                msg = json.loads(raw)
                            except json.JSONDecodeError:
                                continue
                            self._handle_inbound(msg)

                    async def writer() -> None:
                        assert self._outbound is not None
                        while not self._stop.is_set():
                            payload = await self._outbound.get()
                            if payload is None:
                                break
                            await ws.send(json.dumps(payload))

                    reader_task = asyncio.create_task(reader())
                    writer_task = asyncio.create_task(writer())
                    done, pending = await asyncio.wait(
                        {reader_task, writer_task},
                        return_when=asyncio.FIRST_COMPLETED,
                    )
                    for task in pending:
                        task.cancel()
                    for task in done:
                        exc = task.exception()
                        if exc:
                            raise exc
            except Exception as exc:
                self._ws_connected = False
                self.get_logger().warning(
                    f'relay disconnected ({exc}); retry in {backoff:.0f}s')
                await asyncio.sleep(backoff)
                backoff = min(backoff * 2.0, 30.0)


def _yaw_from_quat(q) -> float:
    # yaw from quaternion (ROS ENU, planar)
    siny_cosp = 2.0 * (q.w * q.z + q.x * q.y)
    cosy_cosp = 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
    return math.atan2(siny_cosp, cosy_cosp)


def main(args=None) -> None:
    rclpy.init(args=args)
    node = CloudBridgeNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
