#ifndef LIS2MDL_H
#define LIS2MDL_H

#include "main.h"
#include <stdint.h>

// ================= USER CONFIG =================
#define MAG_I2C               hi2c1
// 7-bit address 0x1E, HAL wants it pre-shifted for the R/W bit
#define LIS2MDL_I2C_ADDR      (0x1E << 1)
// ===============================================

#define MAG_OK                 0
#define MAG_ERROR             -1

// Register Map
#define LIS2MDL_OFFSET_X_REG_L   0x45
#define LIS2MDL_WHO_AM_I         0x4F
#define LIS2MDL_CFG_REG_A        0x60
#define LIS2MDL_CFG_REG_B        0x61
#define LIS2MDL_CFG_REG_C        0x62
#define LIS2MDL_STATUS_REG       0x67
#define LIS2MDL_OUTX_L_REG       0x68

// WHO_AM_I expected value
#define LIS2MDL_ID               0x40

// Sensitivity: 1.5 mG/LSB (fixed full scale of ±50 gauss)
#define LIS2MDL_SENSITIVITY_MGAUSS  1.5f

typedef struct
{
    float mx;   // gauss
    float my;
    float mz;
} LIS2MDL_t;

// Public API
int LIS2MDL_Init(void);
int LIS2MDL_ReadData(LIS2MDL_t *data);
int LIS2MDL_DataReady(void);

// Diagnostics for the last WHO_AM_I read done by LIS2MDL_Init()
// (valid to read right after a failed init call)
extern uint8_t LIS2MDL_LastWhoAmI;
extern int32_t LIS2MDL_LastI2CStatus;

#endif
