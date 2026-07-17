#include "LIS2MDL.h"

extern I2C_HandleTypeDef MAG_I2C;

// ================= LOW LEVEL ===================

static uint8_t LIS2MDL_ReadReg(uint8_t reg)
{
    uint8_t val = 0;
    HAL_I2C_Mem_Read(&MAG_I2C, LIS2MDL_I2C_ADDR, reg, I2C_MEMADD_SIZE_8BIT, &val, 1, HAL_MAX_DELAY);
    return val;
}

static void LIS2MDL_WriteReg(uint8_t reg, uint8_t value)
{
    HAL_I2C_Mem_Write(&MAG_I2C, LIS2MDL_I2C_ADDR, reg, I2C_MEMADD_SIZE_8BIT, &value, 1, HAL_MAX_DELAY);
}

static void LIS2MDL_ReadBurst(uint8_t reg, uint8_t *buf, uint16_t len)
{
    // MSB of the register address enables auto-increment for multi-byte reads
    HAL_I2C_Mem_Read(&MAG_I2C, LIS2MDL_I2C_ADDR, reg | 0x80, I2C_MEMADD_SIZE_8BIT, buf, len, HAL_MAX_DELAY);
}

// =============== HIGH LEVEL ====================

int LIS2MDL_Init(void)
{
    uint8_t who = LIS2MDL_ReadReg(LIS2MDL_WHO_AM_I);
    if (who != LIS2MDL_ID)
        return MAG_ERROR;

    // Software reset
    LIS2MDL_WriteReg(LIS2MDL_CFG_REG_A, 0x20);
    HAL_Delay(20);

    // CFG_REG_A: temperature compensation on, ODR = 100 Hz, continuous mode
    // COMP_TEMP_EN=1 (0x80) | ODR<1:0>=11 (0x0C) | MD<1:0>=00 (continuous)
    LIS2MDL_WriteReg(LIS2MDL_CFG_REG_A, 0x8C);

    // CFG_REG_B: enable offset cancellation
    LIS2MDL_WriteReg(LIS2MDL_CFG_REG_B, 0x02);

    // CFG_REG_C: BDU=1, so a read of L then H always returns a consistent sample
    LIS2MDL_WriteReg(LIS2MDL_CFG_REG_C, 0x10);

    HAL_Delay(20);

    return MAG_OK;
}

int LIS2MDL_DataReady(void)
{
    return (LIS2MDL_ReadReg(LIS2MDL_STATUS_REG) & 0x08) ? 1 : 0; // ZYXDA bit
}

static int16_t make_int16(uint8_t high, uint8_t low)
{
    return (int16_t)((high << 8) | low);
}

int LIS2MDL_ReadData(LIS2MDL_t *data)
{
    uint8_t rx[6];

    LIS2MDL_ReadBurst(LIS2MDL_OUTX_L_REG, rx, 6);

    int16_t mx_raw = make_int16(rx[1], rx[0]);
    int16_t my_raw = make_int16(rx[3], rx[2]);
    int16_t mz_raw = make_int16(rx[5], rx[4]);

    // ===== SCALE FACTORS =====
    // 1.5 mG/LSB -> gauss
    data->mx = mx_raw * LIS2MDL_SENSITIVITY_MGAUSS / 1000.0f;
    data->my = my_raw * LIS2MDL_SENSITIVITY_MGAUSS / 1000.0f;
    data->mz = mz_raw * LIS2MDL_SENSITIVITY_MGAUSS / 1000.0f;

    return MAG_OK;
}
