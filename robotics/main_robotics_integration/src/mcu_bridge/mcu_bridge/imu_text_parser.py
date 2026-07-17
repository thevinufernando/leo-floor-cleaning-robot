"""
Parser for the MCU's current plain-text IMU debug stream.

The mcu-ctrl-dev firmware (Core/Src/main.c, StartDefaultTask) does not yet
implement the framed binary protocol described in protocol.py / firmware_
reference/mcu_bridge_protocol.h for telemetry. It only prints a debug line
over USB CDC at 10 Hz, e.g.:

    ACC[g]: 0.012 -0.003 0.998  GYRO[dps]: 0.10 -0.05 0.02  T[C]: 27.31

optionally followed by ' MAG[G]: 0.123 -0.045 0.210' when the magnetometer
is enabled (LIS2MDL is currently disabled on-board, see firmware README).

This module parses that text so mcu_bridge can publish real sensor_msgs/Imu
data today. Once the firmware moves telemetry onto the framed binary
protocol, this parser should be replaced by protocol.py-based decoding.
"""

import re

_LINE_RE = re.compile(
    r'ACC\[g\]:\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+'
    r'GYRO\[dps\]:\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+'
    r'T\[C\]:\s*([-\d.]+)'
)

G_TO_MPS2 = 9.80665
DEG_TO_RAD = 3.14159265358979323846 / 180.0


def parse_imu_line(line: str):
    """
    Parse one IMU debug line.

    Returns (ax, ay, az, gx, gy, gz, temp_c) in SI units (m/s^2, rad/s,
    degC), or None if the line doesn't match.
    """
    match = _LINE_RE.search(line)
    if not match:
        return None

    ax_g, ay_g, az_g, gx_dps, gy_dps, gz_dps, temp_c = (
        float(g) for g in match.groups()
    )
    return (
        ax_g * G_TO_MPS2,
        ay_g * G_TO_MPS2,
        az_g * G_TO_MPS2,
        gx_dps * DEG_TO_RAD,
        gy_dps * DEG_TO_RAD,
        gz_dps * DEG_TO_RAD,
        temp_c,
    )
