"""
Binary serial protocol between the Raspberry Pi and the STM32F722 MCU.

This is the Python side of the wire format described in the firmware's
``PROTOCOL.md`` (mirrored in ``firmware_reference/mcu_bridge_protocol.h``).
It MUST stay in sync with the C implementation on the MCU.

Frame layout (all multi-byte fields little-endian):

    +--------+--------+--------+--------+===========+--------+--------+
    | SYNC0  | SYNC1  |  TYPE  |  LEN   |  PAYLOAD   | CRC_LO | CRC_HI |
    | 0xAA   | 0x55   | 1 byte | 1 byte |  LEN bytes | 1 byte | 1 byte |
    +--------+--------+--------+--------+===========+--------+--------+

    SYNC0   1 byte   0xAA  frame start marker
    SYNC1   1 byte   0x55  frame start marker
    TYPE    1 byte   message type, see MsgType
    LEN     1 byte   payload length in bytes (0..32)
    PAYLOAD LEN bytes little-endian packed struct for TYPE
    CRC16   2 bytes  CRC-16/CCITT-FALSE over [TYPE, LEN, PAYLOAD], sent LE

CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflection, xor-out 0x0000.
"""

from enum import IntEnum
import struct

SYNC0 = 0xAA
SYNC1 = 0x55

CRC16_POLY = 0x1021
CRC16_INIT = 0xFFFF

# Payload sizes (bytes) — used to sanity-check decoded frames.
ODOMETRY_PAYLOAD_SIZE = 20  # 5 x float32
CMD_VEL_PAYLOAD_SIZE = 8    # 2 x float32


class MsgType(IntEnum):
    """Message type byte (third frame field)."""

    ODOMETRY = 0x01     # MCU -> Pi
    CMD_VEL = 0x02      # Pi -> MCU


def crc16_ccitt(data: bytes) -> int:
    """Compute CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) over data."""
    crc = CRC16_INIT
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ CRC16_POLY) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


def encode_frame(msg_type: int, payload: bytes) -> bytes:
    """Wrap payload in a full SYNC0..CRC16 frame, computing its CRC16."""
    if len(payload) > 32:
        raise ValueError('payload too long for a single frame (max 32 bytes)')
    body = bytes([msg_type, len(payload)]) + payload
    crc = crc16_ccitt(body)
    return bytes([SYNC0, SYNC1]) + body + struct.pack('<H', crc)


def encode_cmd_vel(linear_x: float, angular_z: float) -> bytes:
    """
    Encode a CMD_VEL frame.

    linear_x: m/s (+ = forward), angular_z: rad/s (+ = CCW / left turn),
    both may be negative. The MCU applies diff-drive inverse kinematics
    itself (using its own wheel base) to derive per-wheel speeds.
    """
    payload = struct.pack('<ff', linear_x, angular_z)
    return encode_frame(MsgType.CMD_VEL, payload)


def decode_odometry(payload: bytes):
    """
    Decode a MSG_ODOMETRY payload into (x, y, theta, v, omega).

    All SI units: x/y in metres, theta in rad (wrapped to (-pi, pi]),
    v in m/s, omega in rad/s. Heading is encoder-only (no IMU fusion).
    """
    if len(payload) != ODOMETRY_PAYLOAD_SIZE:
        raise ValueError(
            f'odometry payload must be {ODOMETRY_PAYLOAD_SIZE} bytes, '
            f'got {len(payload)}')
    x, y, theta, v, omega = struct.unpack('<fffff', payload)
    return x, y, theta, v, omega


class FrameDecoder:
    """
    Incremental byte-stream framer.

    Feed raw serial chunks with :meth:`feed`; it yields ``(msg_type,
    payload_bytes)`` tuples for each CRC-valid frame, resynchronising past
    corruption automatically.
    """

    def __init__(self):
        """Start with an empty receive buffer."""
        self._buf = bytearray()

    def feed(self, chunk: bytes):
        """Yield (msg_type, payload) for each valid frame in the stream."""
        self._buf += chunk
        while True:
            i = self._buf.find(bytes([SYNC0, SYNC1]))
            if i < 0:
                # No sync in buffer; keep only a trailing 0xAA that could be
                # the first half of a sync pair split across chunks.
                if self._buf and self._buf[-1] == SYNC0:
                    self._buf = self._buf[-1:]
                else:
                    self._buf.clear()
                return
            # Need at least header (sync0, sync1, type, len).
            if len(self._buf) < i + 4:
                self._buf = self._buf[i:]
                return
            length = self._buf[i + 3]
            frame_end = i + 4 + length + 2
            if len(self._buf) < frame_end:
                self._buf = self._buf[i:]
                return
            msg_type = self._buf[i + 2]
            body = bytes(self._buf[i + 2:i + 4 + length])
            crc_rx = struct.unpack(
                '<H', self._buf[i + 4 + length:frame_end])[0]
            if crc16_ccitt(body) == crc_rx:
                payload = bytes(self._buf[i + 4:i + 4 + length])
                del self._buf[:frame_end]
                yield (msg_type, payload)
            else:
                # Bad frame: drop the false sync bytes and resync.
                del self._buf[:i + 2]
