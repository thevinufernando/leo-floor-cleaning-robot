#ifndef DRV8251A_H_
#define DRV8251A_H_

#include "main.h"

#define MOTOR_PWM_MAX 2399
#define MOTOR_SPEED_MAX 255

void MotorDriver_Enable(void);
void MotorDriver_Disable(void);

//Functions prototypes for Forward and Backward movement
void MotorForward_runSpeed(uint8_t leftspeed, uint8_t rightspeed);
void MotorBackward_runSpeed(uint8_t leftspeed, uint8_t rightspeed);
void MotorLeftTurn_runSpeed(uint8_t speed);
void MotorRightTurn_runSpeed(uint8_t speed);

/*
 * Open-loop body-twist command (ROS cmd_vel style).
 *   v     : linear velocity  [m/s]   (+forward)
 *   omega : angular velocity [rad/s] (+CCW / left turn)
 * Converts the twist to per-wheel linear speeds via differential-drive inverse
 * kinematics, maps them to signed PWM, and drives each motor with the correct
 * direction. No feedback/PID yet -- this is a direct velocity->duty mapping.
 */
void MotorDriver_SetTwist(float v, float omega);

#endif /* DRV8251A_H_ */