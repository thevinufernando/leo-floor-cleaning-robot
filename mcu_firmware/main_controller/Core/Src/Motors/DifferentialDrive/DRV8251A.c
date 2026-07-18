#include "DRV8251A.h"
#include "odometry.h"   /* WHEEL_BASE_MM */

#include <math.h>

extern TIM_HandleTypeDef htim3;

/* Wheel base in meters (shared with odometry). */
#define WHEEL_BASE_M (WHEEL_BASE_MM / 1000.0f)

/*
 * Open-loop scaling: wheel linear speed that corresponds to full duty (255).
 * This is an approximate no-load top speed; tune once measured. Until closed-
 * loop PID is added, commanded velocities are simply clamped/scaled to this.
 */
#define MOTOR_MAX_LINEAR_SPEED_MPS 0.5f

// Enable the driver (wake)
void MotorDriver_Enable(void) {
    
    //Give some time to wake up
    HAL_Delay(10); 
}

// Disable the driver (sleep)
void MotorDriver_Disable(void) {
    
    //Give some time to sleep
    HAL_Delay(10); 
}

// Helper function to map speed (0-255) to PWM value
static inline uint16_t mapSpeedToPWM(uint8_t speed);

// ================= HELPER FUNCTIONS Declarations for Forward and Backward runs =================
static void LeftMotor_Forward(uint16_t pwm);
static void RightMotor_Forward(uint16_t pwm);
static void LeftMotor_Backward(uint16_t pwm);
static void RightMotor_Backward(uint16_t pwm);
static void LeftMotor_Stop(void);
static void RightMotor_Stop(void);

//================= END OF HELPERS =================

//Drive both motors forward at specified speeds (0-255)
void MotorForward_runSpeed(uint8_t leftspeed, uint8_t rightspeed) {

    //Check motor speed limits
    if (leftspeed > MOTOR_SPEED_MAX) leftspeed = MOTOR_SPEED_MAX;
    if (rightspeed > MOTOR_SPEED_MAX) rightspeed = MOTOR_SPEED_MAX;
    
    //Map speeds to PWM values
    uint16_t leftpwm = mapSpeedToPWM((uint8_t)leftspeed);
    uint16_t rightpwm = mapSpeedToPWM((uint8_t)rightspeed);
    
    //Drive motors
    if (leftspeed > 0 && rightspeed > 0) {
        LeftMotor_Forward(leftpwm);
        RightMotor_Forward(rightpwm);
    }
    else {
        LeftMotor_Stop();
        RightMotor_Stop();
    }
}

//Drive both motors backward at specified speeds (0-255)
void MotorBackward_runSpeed(uint8_t leftspeed, uint8_t rightspeed) {

    //Check motor speed limits
    if (leftspeed > MOTOR_SPEED_MAX) leftspeed = MOTOR_SPEED_MAX;
    if (rightspeed > MOTOR_SPEED_MAX) rightspeed = MOTOR_SPEED_MAX;
    
    //Map speeds to PWM values
    uint16_t leftpwm = mapSpeedToPWM((uint8_t)leftspeed);
    uint16_t rightpwm = mapSpeedToPWM((uint8_t)rightspeed);
    
    //Drive motors
    if (leftspeed > 0 && rightspeed > 0) {
        LeftMotor_Backward(leftpwm);
        RightMotor_Backward(rightpwm);
    }
    else {
        LeftMotor_Stop();
        RightMotor_Stop();
    }
}

//Drive left(anticlockwise) pivot turnings
void MotorLeftTurn_runSpeed(uint8_t speed) {

    //Check motor speed limits
    if (speed > MOTOR_SPEED_MAX) speed = MOTOR_SPEED_MAX;

    //Map speeds to PWM values
    uint16_t pwm = mapSpeedToPWM((uint8_t)speed);

    //Drive motors
    if (speed > 0) {
        RightMotor_Forward(pwm);
        LeftMotor_Backward(pwm);
    }
    else {
        LeftMotor_Stop();
        RightMotor_Stop();
    }
}

//Drive right(clockwise) pivot turnings
void MotorRightTurn_runSpeed(uint8_t speed) {

    //Check motor speed limits
    if (speed > MOTOR_SPEED_MAX) speed = MOTOR_SPEED_MAX;

    //Map speeds to PWM values
    uint16_t pwm = mapSpeedToPWM((uint8_t)speed);

    //Drive motors
    if (speed > 0) {
        RightMotor_Backward(pwm);
        LeftMotor_Forward(pwm);
    }
    else {
        LeftMotor_Stop();
        RightMotor_Stop();
    }
}

// Helper function to map speed (0-255) to PWM value
static inline uint16_t mapSpeedToPWM(uint8_t speed) {

    // Scale 0–255 to 0–MOTOR_PWM_MAX
    return (uint16_t)((speed * MOTOR_PWM_MAX) / MOTOR_SPEED_MAX);
}

// Convert a wheel linear speed [m/s] to a signed 0..255 magnitude + sign.
static uint8_t wheelSpeedToMagnitude(float wheel_mps) {

    float ratio = fabsf(wheel_mps) / MOTOR_MAX_LINEAR_SPEED_MPS;
    if (ratio > 1.0f) ratio = 1.0f;
    return (uint8_t)(ratio * MOTOR_SPEED_MAX);
}

// Open-loop body-twist command (diff-drive inverse kinematics).
void MotorDriver_SetTwist(float v, float omega) {

    // Per-wheel linear speeds [m/s].
    float left_mps  = v - (omega * WHEEL_BASE_M * 0.5f);
    float right_mps = v + (omega * WHEEL_BASE_M * 0.5f);

    uint16_t left_pwm  = mapSpeedToPWM(wheelSpeedToMagnitude(left_mps));
    uint16_t right_pwm = mapSpeedToPWM(wheelSpeedToMagnitude(right_mps));

    // Left wheel direction.
    if (left_pwm == 0)        LeftMotor_Stop();
    else if (left_mps >= 0.0f) LeftMotor_Forward(left_pwm);
    else                       LeftMotor_Backward(left_pwm);

    // Right wheel direction.
    if (right_pwm == 0)         RightMotor_Stop();
    else if (right_mps >= 0.0f) RightMotor_Forward(right_pwm);
    else                        RightMotor_Backward(right_pwm);
}

// ================= HELPER FUNCTIONS for Forward and Backward runs =================

static void LeftMotor_Forward(uint16_t pwm) {
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, 0);     // AIN1 = 0
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_4, pwm);   // AIN2 = PWM
}

static void RightMotor_Forward(uint16_t pwm) {
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, pwm);     // AIN1 = 0
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_2, 0);   // AIN2 = PWM
}

static void LeftMotor_Backward(uint16_t pwm) {
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, pwm);     // AIN1 = 0
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_4, 0);   // AIN2 = PWM
}

static void RightMotor_Backward(uint16_t pwm) {
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, 0);     // AIN1 = 0
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_2, pwm);   // AIN2 = PWM
}

//Braek motors (both pins HIGH)
static void LeftMotor_Stop(void) {
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_3, MOTOR_PWM_MAX);     // AIN1 = max
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_4, MOTOR_PWM_MAX);     // AIN2 = max
}

//Braek motors (both pins HIGH)
static void RightMotor_Stop(void) {
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, MOTOR_PWM_MAX);     // AIN1 = max
    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_2, MOTOR_PWM_MAX);     // AIN2 = max
}

//================= END OF HELPERS =================

