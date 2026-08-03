# Main Controller Firmware

Firmware for the custom PCB (STM32F722RET6) that handles low-level control for the Leo floor cleaning robot: motor control, IMU/magnetometer sensing, and wheel encoder odometry. Communicates with a Raspberry Pi 5 (running ROS 2 Jazzy, Nav2, slam_toolbox) over USB CDC. No micro-ROS — the Pi side owns all high-level control.

## Hardware

- **MCU**: STM32F722RET6 (Cortex-M7, LQFP64), on a custom PCB
- **IMU**: ICM-42688-P (accel + gyro), SPI1
- **Magnetometer**: ST LIS2MDL, I2C1
- **Host link**: USB CDC (vendor `0483`, product `5740`), appears as `/dev/ttyACM*` on the Pi
- **RTOS**: FreeRTOS via CMSIS-RTOS v2 (no micro-ROS)

### Pin map (from `main_controller.ioc`)

| Signal      | Pin  | Peripheral |
|-------------|------|------------|
| ICM_NCS     | PA4  | GPIO out (SPI1 soft NSS) |
| ICM_SCLK    | PA5  | SPI1 SCK |
| ICM_MISO    | PA6  | SPI1 MISO |
| ICM_MOSI    | PA7  | SPI1 MOSI |
| ICM_INT     | PC14 | EXTI (configured, not yet used) |
| MAG_SCL     | PB6  | I2C1 SCL |
| MAG_SDA     | PB7  | I2C1 SDA |
| MAG_INT     | PC13 | EXTI (configured, not yet used) |

## Build

Uses the STM32CubeIDE VS Code extension / CMake + Ninja + `arm-none-eabi-gcc`. Presets are in `CMakePresets.json` (`Debug` / `Release`). No manual toolchain setup should be required inside STM32CubeIDE.

## Project layout

```
Core/Inc/Sensors/ICM42688/   ICM42688.h
Core/Src/Sensors/ICM42688/   ICM42688.c
Core/Inc/Sensors/LIS2MDL/    LIS2MDL.h
Core/Src/Sensors/LIS2MDL/    LIS2MDL.c
Core/Src/main.c              MX_*_Init(), StartDefaultTask (the "IMU_Handler" FreeRTOS task)
```

## Development log

### 1. IMU driver (ICM-42688-P, SPI1)

Started from an existing ICM42688 driver written for another project (SPI1, register-poll based, no DMA/interrupts). Adapted for this board:

- Renamed all `IMU_*` identifiers to `ICM_*` to avoid confusion with the FreeRTOS `IMU_Handler` task name and the magnetometer.
- Moved to `Core/{Inc,Src}/Sensors/ICM42688/`.
- CS pin/port now reference the CubeMX-labeled `ICM_NCS_GPIO_Port` / `ICM_NCS_Pin` macros from `main.h` instead of hardcoding `GPIOA`/`GPIO_PIN_4` a second time.
- Fixed init ordering: `WHO_AM_I` is now read *after* the soft reset settles (previously read immediately on power-up, before reset), with a 10 ms power-on delay added first.
- Exposes `ICM42688_Init()` / `ICM42688_ReadData(ICM42688_t*)` returning accel (g), gyro (deg/s), and temperature (°C).

**CubeMX/HAL config bugs found and fixed** (SPI1 was misconfigured by default CubeMX generation for this use case):
- `SPI1.DataSize` was `4BIT` → changed to `8BIT` (register-oriented byte transfers need 8-bit frames).
- `SPI1.NSSPMode` was `PULSE` (toggles NSS between frames) → changed to `DISABLE`, since NSS is driven manually in software around each multi-byte burst read/write.
- `ICM_NCS` GPIO initial output level was `RESET` (CS asserted/active at boot, before SPI is even initialized) → changed to `SET` (CS idles high/inactive), in both `main_controller.ioc` and the generated `MX_GPIO_Init()`.

### 2. Magnetometer driver (LIS2MDL, I2C1)

Added as a **self-contained** driver (not vendoring ST's platform-independent `lis2mdl_reg.c/.h`), matching the style of the ICM42688 driver:

- `LIS2MDL_Init()` — WHO_AM_I check (`0x40`), software reset, then configures continuous mode @ 100 Hz with temperature compensation, offset cancellation, and BDU (block data update) enabled.
- `LIS2MDL_ReadData(LIS2MDL_t*)` — burst-reads X/Y/Z (auto-increment via register MSB), returns gauss (sensitivity fixed at 1.5 mG/LSB). Output registers are little-endian (opposite byte order from the SPI IMU).
- 7-bit I2C address is fixed at `0x1E` — the LIS2MDL has no SDO/SA1 address-select pin (unlike many other ST sensors).
- `LIS2MDL_LastI2CStatus` / `LIS2MDL_LastWhoAmI` globals exposed for diagnosing bring-up failures (HAL status code + actual byte read on WHO_AM_I).

### 3. FreeRTOS integration (`IMU_Handler` task / `StartDefaultTask` in `main.c`)

- Initializes USB CDC, then both sensors, then loops at 10 Hz printing `ACC[g] / GYRO[dps] / T[C]` (and `MAG[G]` when enabled) as plain text over the USB CDC serial port — for verifying wiring/register config only. **No filtering, fusion, or control logic yet** (EKF/PID come later, once odometry sources are validated individually).

### 4. Build system

- `CMakeLists.txt`: added the two driver source files and their include directories.
- Added `-u _printf_float` to the linker flags. `nano.specs` (used by the toolchain file) strips floating-point format support from `printf`/`snprintf` by default to save flash — without this flag, every `%f` field silently prints as blank while surrounding literal text prints fine. This caused an early bring-up symptom where ACC/GYRO output showed labels with no numbers.

### 5. Hardware bring-up findings

- ICM-42688-P (SPI1): brought up successfully, streaming accel/gyro/temp over USB CDC.
- LIS2MDL (I2C1): **currently non-functional on this board revision.** Every WHO_AM_I read returns `HAL_ERROR` (I2C NACK) with the read byte at `0x00` — the device never acknowledges its address on the bus. I2C1 pull-ups are confirmed populated, and CS (pin 3) is confirmed tied to 3.3V (correct — CS low would select SPI mode instead of I2C). Root cause not yet confirmed; suspected bad/unpowered IC or a solder bridge on the fine-pitch package. **Plan: desolder and replace the IC.**
- Until the magnetometer IC is replaced, it's disabled via `#define LIS2MDL_ENABLED 0` at the top of `Core/Src/main.c` — this skips `LIS2MDL_Init()` entirely (no per-boot NACK/error spam on the serial output) while keeping the driver compiled and ready. Flip to `1` and rebuild once the new IC is verified.

## Next steps

- Replace the LIS2MDL IC, re-enable (`LIS2MDL_ENABLED 1`), and verify WHO_AM_I / readings.
- Wheel encoder odometry.
- Once all three odometry sources (IMU, magnetometer, encoders) are individually verified: sensor fusion (EKF) and motor control (PID) — not started yet.
