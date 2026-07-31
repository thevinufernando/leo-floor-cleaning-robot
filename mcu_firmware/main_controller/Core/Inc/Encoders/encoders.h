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

/*
 * Per-wheel distance calibration trim.
 *
 * Both wheels share the same nominal geometry (ENCODER_PPR / MOTOR_GEAR_RATIO
 * / WHEEL_DIAMETER_MM), but real wheels/gearboxes are never perfectly
 * identical (manufacturing tolerance, tire compression, bearing friction).
 * A small left/right mismatch here is invisible during pure rotation but
 * integrates into a steadily growing heading error during straight-line
 * driving, because Odometry_Update() derives theta from (right - left)
 * distance. If a straight-line run curves, empirically calibrate these:
 *
 *   1. Drive both wheels at the same open-loop PWM for a fixed duration.
 *   2. Compare Encoder_getLeftDistance() vs Encoder_getRightDistance().
 *   3. Scale down whichever wheel travelled further, e.g. if left reads 5%
 *      more than right: ENCODER_LEFT_SCALE = 1.0f, ENCODER_RIGHT_SCALE =
 *      1.05f (or normalize both against a taped-floor measured distance).
 *
 * 1.0f on both means "no correction applied yet" (current default).
 */
#define ENCODER_LEFT_SCALE  1.0f
#define ENCODER_RIGHT_SCALE 1.0f

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