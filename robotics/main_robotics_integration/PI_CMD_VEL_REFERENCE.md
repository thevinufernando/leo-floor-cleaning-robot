# Reference: how the Pi generates v/omega, and what the MCU must do with them

## Symptom to fix

On this robot, driving with `j` / `l` (pure in-place rotation) tracks
accurately — the robot spins about its own center with no noticeable drift.
But driving with `i` / `,` (pure straight-line translation) drifts: the
robot moves straight for a while and then develops a growing, noticeable
heading error / curve.

Odometry is **encoder-only** — there is no IMU/magnetometer fusion (the
PCB's magnetometer is unpopulated/faulty), so nothing corrects heading
downstream. Whatever heading the MCU computes from encoder ticks is
authoritative and is what the Pi displays/uses for SLAM. This document
exists so the MCU-side investigation has full, accurate context on how the
commands it receives are generated, and isn't guessing at the Pi side.

**Working hypothesis:** a left/right encoder-to-distance calibration
mismatch (unequal ticks-per-metre, gear ratio, or effective wheel radius
between the two wheels). See "Why this points at wheel calibration" below
for the reasoning, and the fix checklist at the end.

---

## 1. How v/omega are generated on the Pi (teleop_twist_keyboard)

The Pi runs `ros2 run teleop_twist_keyboard teleop_twist_keyboard`
(ROS 2 Jazzy, package version 2.4.1), which publishes
`geometry_msgs/msg/Twist` on `/cmd_vel` — **not** `TwistStamped` (this robot
uses the default `stamped:=false`).

Key bindings (`x` = forward/back sign, `th` = rotation sign):

| Key | x | th | Meaning |
|---|---|---|---|
| `i` | +1 | 0 | forward, straight |
| `,` | -1 | 0 | backward, straight |
| `j` | 0 | +1 | rotate left (CCW) in place |
| `l` | 0 | -1 | rotate right (CW) in place |
| `u` | +1 | +1 | forward + left arc |
| `o` | +1 | -1 | forward + right arc |
| `m` | -1 | -1 | backward + right arc |
| `.` | -1 | +1 | backward + left arc |

Every keypress publishes one `Twist` message computed as:

```python
speed = 0.5   # m/s,   default param, adjustable with q/z/w/x at runtime
turn  = 1.0   # rad/s, default param, adjustable with q/z/e/c at runtime

twist.linear.x  = x  * speed   # commanded v      (m/s,   + = forward)
twist.linear.y  = 0.0
twist.linear.z  = 0.0
twist.angular.x = 0.0
twist.angular.y = 0.0
twist.angular.z = th * turn    # commanded omega  (rad/s, + = CCW / left)
```

So for the two symptom cases specifically:

- **`i` (straight forward):** `linear.x = +0.5`, `angular.z = 0.0` — the Pi
  sends **zero** commanded angular velocity. Any rotation the robot
  develops while driving straight is NOT because the Pi asked for it.
- **`j` (rotate in place):** `linear.x = 0.0`, `angular.z = +1.0` — the Pi
  sends **zero** commanded linear velocity.

There is no ramping, smoothing, or acceleration limiting anywhere in
teleop_twist_keyboard — each keypress publishes the full target speed
immediately. Releasing all keys (or pressing an unbound key) publishes
`linear.x = 0, angular.z = 0` on the very next loop iteration.

**Safety note:** teleop_twist_keyboard publishes one message per keypress
(when a key is held with OS key-repeat, that repeats the publish), not a
continuous fixed-rate stream. Combined with the MCU's 500 ms cmd_vel
watchdog (see PROTOCOL.md), gaps between repeated keypresses can cause the
base to stop and restart. This is a separate, already-understood behavior
and is not the cause of the straight-line drift (the drift is a *heading*
error while the robot is actively moving, not a stop/start artifact).

## 2. How the Pi encodes and sends v/omega to the MCU (mcu_bridge)

`mcu_bridge` (`src/mcu_bridge/mcu_bridge/bridge_node.py`) subscribes to
`/cmd_vel` and forwards every message to the MCU **as-is**, with no
modification, mixing, or per-wheel computation of any kind:

```python
def _on_cmd_vel(self, msg: Twist):
    self._serial.write(encode_cmd_vel(msg.linear.x, msg.angular.z))
```

`encode_cmd_vel` (`src/mcu_bridge/mcu_bridge/protocol.py`) just packs the
two floats into the wire frame:

```python
def encode_cmd_vel(linear_x: float, angular_z: float) -> bytes:
    payload = struct.pack('<ff', linear_x, angular_z)
    return encode_frame(MsgType.CMD_VEL, payload)   # TYPE = 0x02
```

Wire format (see PROTOCOL.md for the full spec, already confirmed correct
and working end-to-end in earlier testing — frame reception, CRC, and
motor response are NOT in question here):

```
AA 55 | TYPE=0x02 | LEN=8 | v:float32 LE | omega:float32 LE | CRC16_LO CRC16_HI
```

**The Pi does zero diff-drive kinematics.** It never computes per-wheel
speeds, never knows the wheel base or wheel radius, and never touches
encoder data on the way out. `v` and `omega` arrive at the MCU exactly as
teleop published them. This means:

- The Pi cannot be the source of a left/right wheel speed asymmetry during
  straight-line driving, because it only ever sends a single scalar `v`
  (not separate left/right values) with `omega = 0.0` for `i`/`,`.
- Any left/right asymmetry that produces the observed drift **must** be
  introduced on the MCU side, either in the inverse-kinematics mixing
  (v, omega) → (v_left, v_right), or in the encoder-to-distance calibration
  used by the MCU's own odometry integration.

## 3. What the MCU is expected to do with (v, omega)

Per PROTOCOL.md, the MCU applies diff-drive inverse kinematics itself using
its own wheel base constant (**263 mm**, confirmed consistent with the
Pi-side URDF `wheel_separation`):

```
v_left  = v - (omega * wheel_base / 2)
v_right = v + (omega * wheel_base / 2)
```

For `i` (`v=+0.5, omega=0`): `v_left = v_right = +0.5` — both wheels
commanded to *exactly* the same speed.

For `j` (`v=0, omega=+1.0`): `v_left = -0.1315`, `v_right = +0.1315` —
wheels commanded to equal-and-opposite speed.

The MCU then drives each wheel open-loop (per PROTOCOL.md, no closed-loop
PID — this was confirmed in an earlier round of firmware debugging) and
separately integrates each wheel's own encoder ticks into the odometry
pose (`x, y, theta`) that gets sent back to the Pi as `MSG_ODOMETRY`.

## 4. Why this points at a left/right encoder or wheel-radius mismatch

Given that the Pi sends an exactly-equal `v_left = v_right` command for
`i`/`,`, and an exactly-equal-magnitude-opposite command for `j`/`l`:

- **Pure rotation (`j`/`l`)** doesn't reveal a *scale* mismatch between the
  two wheels' odometry math as a heading error — a small left/right
  calibration difference here only makes the rotation slightly
  faster/slower than commanded (e.g. 95°/s instead of 100°/s), which is not
  visible without precise timing/measurement.
- **Pure translation (`i`/`,`)** is exactly the case where a small,
  systematic difference between how left-wheel ticks and right-wheel ticks
  are converted to distance integrates into a steadily growing heading
  error over time/distance — matching "straight for a while, then a
  noticeable rotation appears" precisely. If the wheels are actually
  turning at very slightly different real-world speeds for the "same"
  commanded `v`, the robot physically curves, and if only the odometry
  calibration is off (wheels are fine, math isn't), the *reported* heading
  drifts away from the *true* heading — either way, this symmetric-command
  case is where a per-wheel calibration bug shows up.

This is the classic signature of unequal effective wheel radius
(manufacturing tolerance, tire compression) or unequal
ticks-per-revolution / ticks-per-metre constants between the left and right
encoder channels — either in the physical motor response or in the
odometry integration math (possibly both).

## 5. What to check/fix on the MCU

1. **Confirm both wheels use the same distance-per-tick constant, and that
   it's correct for the real hardware.** Find wherever raw encoder deltas
   are converted into per-wheel distance traveled. If there's a single
   shared constant (e.g. `TICKS_PER_METER`, or `encoder_cpr` +
   `wheel_radius`), verify the assumption that both wheels are physically
   identical actually holds (see #3). If there are separate left/right
   constants, confirm they were genuinely calibrated per-wheel, not
   copy-pasted placeholders.

2. **Confirm the encoder resolution/gear ratio constant matches actual
   hardware on both channels** — a wrong CPR or gear ratio on just one
   wheel's timer/encoder input produces exactly this symptom.

3. **Empirically calibrate rather than trust nominal wheel radius.** Real
   wheel radius often differs slightly between two "identical" wheels due
   to tolerance or tire compression. Suggested procedure:
   - Command equal PWM/target speed to both wheels for a fixed duration
     (bypass the normal v/omega mixing with a test/debug command if
     needed).
   - Compare actual encoder tick counts accumulated on each wheel over that
     window. A difference here directly indicates the wheels aren't
     physically equivalent (or one encoder channel is miscounting).
   - Field-calibration alternative: drive the real robot in a straight line
     over a measured distance (2-3 m) with equal `v_left`/`v_right`
     commands, measure the resulting lateral/heading error, and
     back-calculate a per-wheel scale correction to fold into the
     distance-per-tick constant for one or both wheels, iterating until
     repeated straight-line runs stop drifting.

4. **Rule out mechanical asymmetry**: uneven bearing friction, a
   partially-slipping wheel, or a wheel not fully seated can produce this
   symptom and won't be fixed by a software calibration change alone —
   check motor current draw left-vs-right under equal PWM if current
   sensing is available.

## Not the issue (already ruled out / out of scope here)

- **cmd_vel wire framing/CRC/PWM output** — confirmed correct and working
  in prior debugging; frames reach the MCU intact and motors respond.
- **Wheel base (263 mm)** — affects rotation *radius* calibration (how fast
  the robot turns for a given omega), not straight-line drift, and is
  already confirmed consistent between the firmware and the Pi-side URDF.
- **IMU fusion** — not available on this hardware revision (magnetometer
  unpopulated); the fix must be in the wheel odometry math/calibration
  itself, not sensor fusion.
- **Pi-side kinematics** — as shown in section 2, the Pi never computes
  per-wheel values; it forwards a single scalar `v`/`omega` pair unchanged.
  There is no code path on the Pi that could introduce a left/right
  asymmetry.

## How to verify the fix

1. Place the robot on the floor next to a straight reference line (tape,
   floor seam, etc.).
2. Drive forward with `i` held for a fixed, repeatable duration or
   distance.
3. Compare the robot's final heading/position against the reference line —
   before the fix it should visibly curve; after correcting the per-wheel
   calibration, it should track straight within a small, non-growing
   tolerance.
4. Cross-check against the MCU's own reported `theta` in `MSG_ODOMETRY`: it
   should stay near zero during a straight-line run once fixed, instead of
   steadily increasing/decreasing.
5. Re-verify `j`/`l` (pure rotation) still behaves correctly afterward — a
   per-wheel distance calibration fix should not need to touch the
   wheel-base/rotation-radius constant, but confirm nothing regressed.

Report back which wheel (left or right) had the calibration error, the
magnitude of the correction, and the final calibrated constants.
