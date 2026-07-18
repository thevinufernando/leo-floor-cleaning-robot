/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.h
  * @brief          : Header for main.c file.
  *                   This file contains the common defines of the application.
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32f7xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

void HAL_TIM_MspPostInit(TIM_HandleTypeDef *htim);

/* Exported functions prototypes ---------------------------------------------*/
void Error_Handler(void);

/* USER CODE BEGIN EFP */

/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
#define MAG_INT_Pin GPIO_PIN_13
#define MAG_INT_GPIO_Port GPIOC
#define ICM_INT_Pin GPIO_PIN_14
#define ICM_INT_GPIO_Port GPIOC
#define LDM_ENC_CHA_Pin GPIO_PIN_0
#define LDM_ENC_CHA_GPIO_Port GPIOA
#define LDM_ENC_CHB_Pin GPIO_PIN_1
#define LDM_ENC_CHB_GPIO_Port GPIOA
#define ICM_NCS_Pin GPIO_PIN_4
#define ICM_NCS_GPIO_Port GPIOA
#define ICM_SCLK_Pin GPIO_PIN_5
#define ICM_SCLK_GPIO_Port GPIOA
#define ICM_MISO_Pin GPIO_PIN_6
#define ICM_MISO_GPIO_Port GPIOA
#define ICM_MOSI_Pin GPIO_PIN_7
#define ICM_MOSI_GPIO_Port GPIOA
#define RDM_PWM_INA_Pin GPIO_PIN_6
#define RDM_PWM_INA_GPIO_Port GPIOC
#define RDM_PWM_INB_Pin GPIO_PIN_7
#define RDM_PWM_INB_GPIO_Port GPIOC
#define LDM_PWM_INA_Pin GPIO_PIN_8
#define LDM_PWM_INA_GPIO_Port GPIOC
#define LDM_PWM_INB_Pin GPIO_PIN_9
#define LDM_PWM_INB_GPIO_Port GPIOC
#define RDM_ENC_CHA_Pin GPIO_PIN_8
#define RDM_ENC_CHA_GPIO_Port GPIOA
#define RDM_ENC_CHB_Pin GPIO_PIN_9
#define RDM_ENC_CHB_GPIO_Port GPIOA
#define MAG_SCL_Pin GPIO_PIN_6
#define MAG_SCL_GPIO_Port GPIOB
#define MAG_SDA_Pin GPIO_PIN_7
#define MAG_SDA_GPIO_Port GPIOB

/* USER CODE BEGIN Private defines */

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
