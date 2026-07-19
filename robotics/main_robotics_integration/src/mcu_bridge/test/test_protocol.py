"""Unit tests for the binary MCU serial protocol (see PROTOCOL.md)."""

import struct

from mcu_bridge.protocol import (
    crc16_ccitt,
    decode_odometry,
    encode_cmd_vel,
    encode_frame,
    FrameDecoder,
    MsgType,
)


def test_crc16_ccitt_known_vector():
    # CRC-16/CCITT-FALSE of ASCII "123456789" is 0x29B1 (standard check value).
    assert crc16_ccitt(b'123456789') == 0x29B1


def test_cmd_vel_frame_layout():
    frame = encode_cmd_vel(0.1, -0.2)
    assert frame[0] == 0xAA
    assert frame[1] == 0x55
    assert frame[2] == MsgType.CMD_VEL
    assert frame[3] == 8
    v, omega = struct.unpack('<ff', frame[4:12])
    assert abs(v - 0.1) < 1e-6
    assert abs(omega + 0.2) < 1e-6
    body = frame[2:12]
    crc = struct.unpack('<H', frame[12:14])[0]
    assert crc16_ccitt(body) == crc


def test_odometry_roundtrip_through_decoder():
    payload = struct.pack('<fffff', 1.0, 2.0, 0.5, 0.3, -0.1)
    frame = encode_frame(MsgType.ODOMETRY, payload)
    dec = FrameDecoder()
    frames = list(dec.feed(frame))
    assert len(frames) == 1
    msg_type, got_payload = frames[0]
    assert msg_type == MsgType.ODOMETRY
    x, y, theta, v, omega = decode_odometry(got_payload)
    assert abs(x - 1.0) < 1e-6
    assert abs(y - 2.0) < 1e-6
    assert abs(theta - 0.5) < 1e-6
    assert abs(v - 0.3) < 1e-6
    assert abs(omega + 0.1) < 1e-6


def test_decoder_resyncs_after_garbage_and_split_chunks():
    payload = struct.pack('<fffff', 0.0, 0.0, 0.0, 0.0, 0.0)
    frame = encode_frame(MsgType.ODOMETRY, payload)
    dec = FrameDecoder()
    # Leading garbage, then the frame split across two feeds mid-payload.
    assert list(dec.feed(b'\x00\xffgarbage' + frame[:7])) == []
    frames = list(dec.feed(frame[7:]))
    assert len(frames) == 1
    assert frames[0][0] == MsgType.ODOMETRY


def test_decoder_rejects_corrupted_crc():
    payload = struct.pack('<fffff', 1.0, 1.0, 1.0, 1.0, 1.0)
    frame = bytearray(encode_frame(MsgType.ODOMETRY, payload))
    frame[-1] ^= 0xFF  # corrupt CRC high byte
    dec = FrameDecoder()
    assert list(dec.feed(bytes(frame))) == []
