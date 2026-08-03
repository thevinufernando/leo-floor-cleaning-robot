# MCU not enumerating on USB after reflash — debugging reference

## Evidence gathered on the Pi (2026-07-21, kernel uptime ~2526s at time of
## writing)

`lsusb` on the Raspberry Pi currently shows only the RPLIDAR's CP210x
bridge. The STM32 is **completely absent**:

```
Bus 004 Device 003: ID 10c4:ea60 Silicon Labs CP210x UART Bridge   <- RPLIDAR, fine
```

No `0483:xxxx` (STMicroelectronics) device present at all.

`sudo dmesg` shows the STM32's *only* USB appearance since boot:

```
[  725.954626] usb 4-1: new full-speed USB device number 2 using xhci-hcd
[  726.108931] usb 4-1: New USB device found, idVendor=0483, idProduct=df11, bcdDevice=22.00
[  726.108942] usb 4-1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[  726.108947] usb 4-1: Product: STM32  BOOTLOADER
[  726.108950] usb 4-1: Manufacturer: STMicroelectronics
[  726.108954] usb 4-1: SerialNumber: STM32FxSTM32
[  737.501690] usb 4-1: USB disconnect, device number 2
```

Key facts from this:

- `idProduct=df11` is ST's **built-in USB DFU bootloader**
  (`System Memory` boot, ROM bootloader) — NOT the application firmware,
  and NOT the custom CDC-ACM VCP device (`idVendor=0483, idProduct=5740`)
  the ROS 2 `mcu_bridge` node expects at `/dev/mcu`. `df11` only appears
  when BOOT0 was high at reset time.
- This DFU enumeration happened once, then the device **disconnected 11
  seconds later** and has not re-enumerated since — not as DFU, not as the
  application CDC device, not as anything.
- **No dmesg lines at all appear after that**, even after BOOT0 was pulled
  back low and the board was reset. A working reset that boots into flash
  (or even back into DFU) would produce a fresh `usb 4-1: New USB device
  found ...` line. The total absence of any new USB event means the chip
  is very likely not completing a USB-capable boot/reset cycle at all right
  now — this is upstream of anything a udev rule, protocol fix, or ROS
  config can address.

## What this rules out

This is **not**:
- A udev rule / `/dev/mcu` symlink problem (confirmed: `/etc/udev/rules.d/`
  already has the correct rule installed and working — it matches
  `idVendor=0483, idProduct=5740`, which simply never appears because the
  device isn't the application device right now).
- A `mcu_bridge` / ROS 2 bug (the node correctly reports
  `FileNotFoundError: /dev/mcu` because the file genuinely doesn't exist —
  this is the expected, correct failure mode when the underlying USB device
  isn't there).
- A cmd_vel / protocol / kinematics issue — that's a separate, already
  in-progress investigation (see `PI_CMD_VEL_REFERENCE.md`) and doesn't
  apply until the MCU is enumerating and running firmware again.

## Physical checklist (work through in order)

1. **Confirm BOOT0 is solidly LOW, not floating.**
   - Measure BOOT0 pin directly with a multimeter against GND while the
     board is powered. It should read a firm ~0 V, not an intermediate
     voltage.
   - If BOOT0 relies on an external pull-down resistor or jumper, verify
     the jumper is actually seated / the resistor is actually populated —
     a floating BOOT0 can read low with a meter under light load but still
     drift high at the instant of reset due to noise, especially on
     hand-wired prototype boards.

2. **Confirm NRST is actually being toggled by whatever "reset" you're
   using.**
   - If using a physical reset button: verify continuity from the button
     through to the NRST pin with a multimeter (button contacts on
     perfboard/breadboard prototypes are a common failure point).
   - If using ST-Link/STM32CubeProgrammer's "reset" function instead of a
     physical button: confirm the ST-Link's NRST line is actually wired to
     the MCU (not left unconnected, which some minimal ST-Link breakout
     wiring omits).
   - Try a **full power-cycle** instead of just asserting reset: physically
     unplug the USB cable (and any separate power supply, if the board
     isn't purely USB-powered) for a few seconds, then reconnect. This
     guarantees a real power-on-reset (POR) and re-samples BOOT0 fresh,
     ruling out any reset-controller/NRST wiring issue.

3. **Check power rails while attempting to boot.**
   - Confirm 3V3 (and 5V if the board has a separate regulator input) is
     present and stable at the MCU's VDD pins with a multimeter during the
     power-up attempt — a brown-out during the reflash could have left a
     regulator, decoupling cap, or connector in a bad state.
   - Check the board isn't drawing abnormal current (a dead short or a
     damaged component from the reflash session would prevent it from
     completing boot).

4. **Verify the flash write actually completed and verified successfully**,
   not just that the programmer reported "done":
   - Re-run the flash with STM32CubeProgrammer (or your tool of choice) and
     explicitly use its **read-back/verify** step, not just "program".
   - Check the programmer's log for any warnings during erase/program
     (partial writes from a USB dropout or a power blip during flashing are
     a common cause of a chip that then fails to boot cleanly).
   - If comfortable doing so, use the programmer to read out and inspect
     the reset/interrupt vector table at the start of flash — a corrupted
     vector table (e.g. all `0xFF` from a failed erase-then-write) will
     produce a hard fault or lockup before your code ever reaches USB
     initialization, which matches "no USB event at all" exactly.

5. **Only after 1-4 look correct**, suspect the application firmware
   itself:
   - Does `main()` (or your FreeRTOS startup task) actually reach USB CDC
     `MX_USB_DEVICE_Init()` (or equivalent) before any code that could hang
     or fault (e.g. a peripheral init that blocks forever waiting on
     hardware that isn't present/wired, a FreeRTOS assertion failure before
     the scheduler starts, a hard fault handler that spins silently)?
   - Add the earliest possible visible sign of life you can — a GPIO/LED
     toggle right at the top of `main()`, before any peripheral init — to
     distinguish "chip never reaches user code" from "chip reaches user
     code but hangs before USB init".

## How to recover to DFU deliberately, if you want a clean re-flash attempt

If you want to rule out a bad flash by simply reflashing again:

1. Hold BOOT0 high, then power-cycle (unplug/replug USB) — do not rely on
   a reset button/line whose wiring you haven't verified per step 2 above.
2. Confirm DFU mode on the Pi: `lsusb` should show
   `ID 0483:df11 STMicroelectronics STM Device in DFU Mode` (or use
   `dfu-util -l` if installed).
3. Reflash with STM32CubeProgrammer or `dfu-util`, using its verify step.
4. Pull BOOT0 back low, power-cycle again (full unplug/replug, not just
   reset), and check `lsusb` for `ID 0483:5740` (the application CDC
   device) and `dmesg` for a fresh enumeration line.

## How to confirm the fix from the Pi side once the board boots correctly

```bash
# 1. Watch for the device appearing live while you power-cycle the board:
sudo dmesg -w
# (in another terminal / after) power-cycle the STM32, watch for a NEW
# "usb X-Y: New USB device found, idVendor=0483, idProduct=5740" line

# 2. Confirm the udev symlink resolves once the device is present:
ls -l /dev/mcu

# 3. Only then re-launch the stack:
ros2 launch slam_bringup mapping.launch.py
```

The `mcu_bridge` node needs no changes — it will work as soon as
`/dev/mcu` exists again, exactly as it did in earlier verified sessions.
