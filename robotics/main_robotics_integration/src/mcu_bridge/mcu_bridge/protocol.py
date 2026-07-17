"""
Binary serial protocol between the Raspberry Pi and the STM32 MCU.

Frame layout (all multi-byte fields little-endian):

    [START][MSG_ID][LEN][PAYLOAD...][CRC8][END]

    START   1 byte   0xAA
    MSG_ID  1 byte   message type, see MsgId
    LEN     1 byte   number of payload bytes (0-255)
    PAYLOAD LEN bytes
    CRC8    1 byte   CRC-8/SMBUS (poly 0x07, init 0x00) over MSG_ID+LEN+PAYLOAD
    END     1 byte   0x55

This module must stay in sync with the C implementation on the MCU. As of
mcu-ctrl-dev, the firmware does not yet parse this protocol at all (it only
prints plain-text IMU debug lines, see imu_text_parser.py) — CMD_VELOCITY
frames are encoded and sent, but nothing on the MCU consumes them yet.

TODO once firmware grows a real frame parser and encoder/motor control:
  - add ENCODER_TICKS / ODOMETRY / IMU_DATA message IDs here matching the
    firmware side, and add matching decode_* functions.
"""

from enum import IntEnum
import struct

START_BYTE = 0xAA
END_BYTE = 0x55

CRC8_POLY = 0x07
CRC8_INIT = 0x00


class MsgId(IntEnum):
    """Message type byte sent as the second frame field."""

    CMD_VELOCITY = 0x01


def crc8(data: bytes) -> int:
    """Compute CRC-8/SMBUS (poly 0x07, init 0x00) over data."""
    crc = CRC8_INIT
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x80:
                crc = ((crc << 1) ^ CRC8_POLY) & 0xFF
            else:
                crc = (crc << 1) & 0xFF
    return crc


def encode_frame(msg_id: int, payload: bytes) -> bytes:
    """Wrap payload in a full START..END frame, computing its CRC8."""
    if len(payload) > 255:
        raise ValueError('payload too long for a single frame')
    body = bytes([msg_id, len(payload)]) + payload
    return bytes([START_BYTE]) + body + bytes([crc8(body), END_BYTE])


def encode_cmd_velocity(linear_x: float, angular_z: float) -> bytes:
    """
    Encode a CMD_VELOCITY frame.

    linear_x: m/s, angular_z: rad/s (both may be negative). The MCU is
    expected to apply diff-drive kinematics itself (using its own
    wheel_separation) to derive left/right wheel setpoints.
    """
    payload = struct.pack('<ff', linear_x, angular_z)
    return encode_frame(MsgId.CMD_VELOCITY, payload)
