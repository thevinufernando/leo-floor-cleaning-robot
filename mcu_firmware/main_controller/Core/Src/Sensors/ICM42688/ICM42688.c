#include "ICM42688.h"

extern SPI_HandleTypeDef ICM_SPI;

// ================= LOW LEVEL ===================

static void ICM_CS_Low(void)
{
    HAL_GPIO_WritePin(ICM_CS_GPIO_Port, ICM_CS_Pin, GPIO_PIN_RESET);
}

static void ICM_CS_High(void)
{
    HAL_GPIO_WritePin(ICM_CS_GPIO_Port, ICM_CS_Pin, GPIO_PIN_SET);
}

static uint8_t ICM42688_ReadReg(uint8_t reg)
{
    uint8_t tx = reg | 0x80;
    uint8_t rx;

    ICM_CS_Low();
    HAL_SPI_Transmit(&ICM_SPI, &tx, 1, HAL_MAX_DELAY);
    HAL_SPI_Receive(&ICM_SPI, &rx, 1, HAL_MAX_DELAY);
    ICM_CS_High();

    return rx;
}

static void ICM42688_WriteReg(uint8_t reg, uint8_t value)
{
    uint8_t tx[2];
    tx[0] = reg & 0x7F;
    tx[1] = value;

    ICM_CS_Low();
    HAL_SPI_Transmit(&ICM_SPI, tx, 2, HAL_MAX_DELAY);
    ICM_CS_High();
}

// =============== HIGH LEVEL ====================

int ICM42688_Init(void)
{
    // Let the device finish power-on before the first register access
    HAL_Delay(10);

    // Soft reset
    ICM42688_WriteReg(ICM42688_DEVICE_CONFIG, 0x01);
    HAL_Delay(100);

    uint8_t who = ICM42688_ReadReg(ICM42688_WHO_AM_I);
    if (who != ICM42688_ID)
        return ICM_ERROR;

    // Enable gyro + accel in LOW NOISE mode, temp on
    // 0b00001111 = 0x0F
    ICM42688_WriteReg(ICM42688_PWR_MGMT0, 0x0F);
    HAL_Delay(50);

    // Gyro: ±2000 dps, ODR = 1 kHz
    //0b00000110 = 0x06
    ICM42688_WriteReg(ICM42688_GYRO_CONFIG0, 0x06);

    // Accel: ±4g, ODR = 1 kHz
    //0b01000110 = 0x46
    ICM42688_WriteReg(ICM42688_ACCEL_CONFIG0, 0x46);

    HAL_Delay(20);

    return ICM_OK;
}

static int16_t make_int16(uint8_t high, uint8_t low)
{
    return (int16_t)((high << 8) | low);
}

int ICM42688_ReadData(ICM42688_t *data)
{
    uint8_t tx = ICM42688_ACCEL_DATA_X1 | 0x80;
    uint8_t rx[14];

    ICM_CS_Low();
    HAL_SPI_Transmit(&ICM_SPI, &tx, 1, HAL_MAX_DELAY);
    HAL_SPI_Receive(&ICM_SPI, rx, 14, HAL_MAX_DELAY);
    ICM_CS_High();

    int16_t ax_raw  = make_int16(rx[0], rx[1]);
    int16_t ay_raw  = make_int16(rx[2], rx[3]);
    int16_t az_raw  = make_int16(rx[4], rx[5]);
    int16_t gx_raw  = make_int16(rx[6], rx[7]);
    int16_t gy_raw  = make_int16(rx[8], rx[9]);
    int16_t gz_raw  = make_int16(rx[10], rx[11]);
    int16_t temp_raw  = make_int16(rx[12], rx[13]);

    // ===== SCALE FACTORS =====
    // Gyro ±2000 dps => 16.384 LSB/(°/s)
    data->gx = gx_raw / 16.384f;
    data->gy = gy_raw / 16.384f;
    data->gz = gz_raw / 16.384f;

    // Accel ±4g => 8192 LSB/g
    data->ax = ax_raw / 8192.0f;
    data->ay = ay_raw / 8192.0f;
    data->az = az_raw / 8192.0f;

    // Temperature (rough formula, per ICM-42688-P datasheet)
    data->temperature = (float)temp_raw / 132.48f + 25.0f;

    return ICM_OK;
}
