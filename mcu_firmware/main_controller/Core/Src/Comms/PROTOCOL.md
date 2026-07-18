# MCU ⇄ Raspberry Pi USB-Serial Protocol

Binary, little-endian, CRC-checked framing over the USB CDC virtual COM port.
This is the authoritative description of the wire format defined in
[`protocol.h`](../../Inc/Comms/protocol.h). The Pi opens the MCU's
`/dev/ttyACM*` port (baud rate is irrelevant for USB CDC — any value works).

## Frame layout

```
+--------+--------+--------+--------+===========+--------+--------+
| SYNC0  | SYNC1  |  TYPE  |  LEN   |  PAYLOAD   | CRC_LO | CRC_HI |
| 0xAA   | 0x55   | 1 byte | 1 byte |  LEN bytes | 1 byte | 1 byte |
+--------+--------+--------+--------+===========+--------+--------+
```

| Field   | Size | Description                                            |
|---------|------|--------------------------------------------------------|
| SYNC0   | 1    | Constant `0xAA` — frame start marker                   |
| SYNC1   | 1    | Constant `0x55` — frame start marker                   |
| TYPE    | 1    | Message type (see below)                               |
| LEN     | 1    | Payload length in bytes (0…32)                         |
| PAYLOAD | LEN  | Little-endian packed struct for TYPE                   |
| CRC16   | 2    | CRC-16/CCITT-FALSE over `[TYPE, LEN, PAYLOAD]`, LE     |

- **Endianness:** little-endian (matches the Cortex-M7 and `x86`/`aarch64` Pi).
- **CRC:** CRC-16/CCITT-FALSE — poly `0x1021`, init `0xFFFF`, no reflection,
  xor-out `0x0000`. Computed over `TYPE`, `LEN`, and `PAYLOAD` (not the sync
  bytes). Sent low byte first.

## Message types

| Name          | TYPE  | Direction   | Payload           | Size |
|---------------|-------|-------------|-------------------|------|
| `MSG_ODOMETRY`| `0x01`| MCU → Pi    | `OdometryPayload` | 20 B |
| `MSG_CMD_VEL` | `0x02`| Pi → MCU    | `CmdVelPayload`   | 8 B  |

### `MSG_ODOMETRY` (0x01) — MCU → Pi, ~50 Hz

Robot pose in the `odom` frame plus body twist. All SI units, `float32`.

| Offset | Field | Type    | Unit    |
|--------|-------|---------|---------|
| 0      | x     | float32 | m       |
| 4      | y     | float32 | m       |
| 8      | theta | float32 | rad     |
| 12     | v     | float32 | m/s     |
| 16     | omega | float32 | rad/s   |

`theta` is wrapped to (−π, π]. Heading is **encoder-only** for now (no IMU
fusion until the magnetometer is populated), so expect slow yaw drift.

### `MSG_CMD_VEL` (0x02) — Pi → MCU

Commanded body twist (ROS `geometry_msgs/Twist` reduced to a diff-drive base).
`float32`, SI units.

| Offset | Field | Type    | Unit    | Sign convention        |
|--------|-------|---------|---------|------------------------|
| 0      | v     | float32 | m/s     | + = forward            |
| 4      | omega | float32 | rad/s   | + = CCW / left turn    |

The MCU converts this to per-wheel speeds via differential-drive inverse
kinematics (wheel base 263 mm) and drives the motors open-loop. **Safety:** if
no `MSG_CMD_VEL` arrives within 500 ms the base stops automatically, so the Pi
should stream commands continuously (e.g. 20–50 Hz), publishing zero to idle.

## Python reference (Raspberry Pi side)

```python
import struct, serial

SYNC0, SYNC1 = 0xAA, 0x55
MSG_ODOMETRY, MSG_CMD_VEL = 0x01, 0x02

def crc16_ccitt(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if (crc & 0x8000) else (crc << 1) & 0xFFFF
    return crc

def encode(msg_type: int, payload: bytes) -> bytes:
    body = bytes([msg_type, len(payload)]) + payload
    crc = crc16_ccitt(body)
    return bytes([SYNC0, SYNC1]) + body + struct.pack('<H', crc)

def send_cmd_vel(ser: serial.Serial, v: float, omega: float):
    ser.write(encode(MSG_CMD_VEL, struct.pack('<ff', v, omega)))

# --- Incremental receiver ---
class Decoder:
    def __init__(self):
        self.buf = bytearray()

    def feed(self, chunk: bytes):
        """Yield (msg_type, payload_bytes) for each valid frame."""
        self.buf += chunk
        while True:
            # find sync
            i = self.buf.find(bytes([SYNC0, SYNC1]))
            if i < 0:
                if self.buf:                      # keep last byte (could be 0xAA)
                    self.buf = self.buf[-1:]
                return
            if len(self.buf) < i + 4:
                self.buf = self.buf[i:]
                return
            msg_type = self.buf[i + 2]
            length   = self.buf[i + 3]
            frame_end = i + 4 + length + 2
            if len(self.buf) < frame_end:
                self.buf = self.buf[i:]
                return
            body    = bytes(self.buf[i + 2 : i + 4 + length])
            crc_rx  = struct.unpack('<H', self.buf[i + 4 + length : frame_end])[0]
            if crc16_ccitt(body) == crc_rx:
                payload = bytes(self.buf[i + 4 : i + 4 + length])
                self.buf = self.buf[frame_end:]
                yield (msg_type, payload)
            else:
                self.buf = self.buf[i + 2:]       # drop bad sync, resync

def parse_odometry(payload: bytes):
    x, y, theta, v, omega = struct.unpack('<fffff', payload)
    return dict(x=x, y=y, theta=theta, v=v, omega=omega)

# --- Usage ---
# ser = serial.Serial('/dev/ttyACM0')
# dec = Decoder()
# while True:
#     for mtype, payload in dec.feed(ser.read(ser.in_waiting or 1)):
#         if mtype == MSG_ODOMETRY:
#             print(parse_odometry(payload))
#     send_cmd_vel(ser, 0.1, 0.0)   # stream at 20-50 Hz
```

## Notes for the ROS2 integration

- Publish `MSG_ODOMETRY` into a `nav_msgs/Odometry` message + the `odom`→
  `base_link` TF. Build the quaternion from `theta` (yaw only).
- Feed `cmd_vel` (`geometry_msgs/Twist`) from Nav2/teleop into `send_cmd_vel`
  using only `linear.x` (v) and `angular.z` (omega).
- Covariances: since this is wheel-only odometry, set a modest covariance on
  `x/y/yaw` and a larger one on yaw so slam_toolbox trusts the scan match more.
