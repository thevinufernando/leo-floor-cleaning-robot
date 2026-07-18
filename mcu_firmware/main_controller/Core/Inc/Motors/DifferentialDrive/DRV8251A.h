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

#endif /* DRV8251A_H_ */