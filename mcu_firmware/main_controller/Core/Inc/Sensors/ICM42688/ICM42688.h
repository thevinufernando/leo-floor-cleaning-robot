#ifndef ICM42688_H
#define ICM42688_H

#include "main.h"
#include <stdint.h>

// ================= USER CONFIG =================
#define ICM_SPI              hspi1
#define ICM_CS_GPIO_Port     ICM_NCS_GPIO_Port
#define ICM_CS_Pin           ICM_NCS_Pin
// ===============================================

#define ICM_OK                0
#define ICM_ERROR            -1

// Register Map
#define ICM42688_DEVICE_CONFIG   0x11
#define ICM42688_WHO_AM_I        0x75
#define ICM42688_PWR_MGMT0       0x4E
#define ICM42688_GYRO_CONFIG0    0x4F
#define ICM42688_ACCEL_CONFIG0   0x50

#define ICM42688_TEMP_DATA1      0x1D
#define ICM42688_GYRO_DATA1      0x25
#define ICM42688_ACCEL_DATA_X1   0x1F

// WHO_AM_I expected value
#define ICM42688_ID              0x47

typedef struct
{
    float ax;   // g
    float ay;
    float az;

    float gx;   // deg/s
    float gy;
    float gz;

    float temperature; // degC
} ICM42688_t;

// Public API
int ICM42688_Init(void);
int ICM42688_ReadData(ICM42688_t *data);

#endif
