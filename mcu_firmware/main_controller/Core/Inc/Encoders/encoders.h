#ifndef ENCODERS_H
#define ENCODERS_H

#include "main.h"
#include "stm32f7xx_hal.h"
#include <stdint.h>

#define LEFT_ENCODER_TIMER TIM2
#define RIGHT_ENCODER_TIMER TIM1

// Parameters to calculate traveled distance
#define ENCODER_PPR 11.0f
#define MOTOR_GEAR_RATIO 37.0f
#define WHEEL_DIAMETER_MM 68.0f

#define PI 3.14159265358979323846f

// Encoder data structure
typedef struct {

    // Required variables
    float distance;
    int32_t count;
    int16_t prev_count;
    int16_t delta_count;

    int8_t encoder_polarity; // Direction polarity: 1 or -1
} Encoder_t;

// Cumulative wheel travel sample passed from Encoder_Handler -> OdomHandler
// via EncoderQueue. Distances are in meters.
typedef struct {
    float left_m;
    float right_m;
} EncoderSample_t;

// Function prototypes
void Encoders_Init(void);
void Encoders_Reset(void);
void Encoders_Update(void);

int32_t Encoder_getLeftCount(void);
int32_t Encoder_getRightCount(void);
int16_t Encoder_getLeftDeltaCount(void);
int16_t Encoder_getRightDeltaCount(void);
float Encoder_getLeftDistance(void);
float Encoder_getRightDistance(void);

float Encoder_getAverageDistance(void);

#endif // ENCODERS_H