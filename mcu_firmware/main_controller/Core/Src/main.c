/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
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
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "cmsis_os.h"
#include "usb_device.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "ICM42688.h"
#include "usbd_cdc_if.h"
#include "encoders.h"
#include "DRV8251A.h"
#include "odometry.h"
#include "protocol.h"
#include "usb_bridge.h"
#include <stdio.h>
#include <string.h>

/* LIS2MDL is unpopulated/faulty on this board revision (I2C NACK, see PB6/PB7).
   Set to 1 once the IC is replaced and verified. */
#define LIS2MDL_ENABLED 0

/* Headless motor test: drives both wheels forward/backward on a fixed
   open-loop schedule with NO dependency on USB/cmd_vel from the Pi. Use it
   to check for a hardware/motor issue independent of the command path, and
   as the test rig for measuring left/right wheel calibration (see
   ENCODER_LEFT_SCALE / ENCODER_RIGHT_SCALE in encoders.h). Set to 0 for
   normal Pi-driven operation -- do not leave this on during SLAM runs. */
#define MOTOR_HEADLESS_TEST_ENABLED 0

#if LIS2MDL_ENABLED
#include "LIS2MDL.h"
#endif
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

I2C_HandleTypeDef hi2c1;

SPI_HandleTypeDef hspi1;

TIM_HandleTypeDef htim1;
TIM_HandleTypeDef htim2;
TIM_HandleTypeDef htim3;

/* Definitions for IMU_Handler */
osThreadId_t IMU_HandlerHandle;
const osThreadAttr_t IMU_Handler_attributes = {
  .name = "IMU_Handler",
  .stack_size = 256 * 4,
  .priority = (osPriority_t) osPriorityHigh,
};
/* Definitions for Encoder_Handler */
osThreadId_t Encoder_HandlerHandle;
const osThreadAttr_t Encoder_Handler_attributes = {
  .name = "Encoder_Handler",
  .stack_size = 256 * 4,
  .priority = (osPriority_t) osPriorityHigh,
};
/* Definitions for MainMotorDriver */
osThreadId_t MainMotorDriverHandle;
const osThreadAttr_t MainMotorDriver_attributes = {
  .name = "MainMotorDriver",
  .stack_size = 256 * 4,
  .priority = (osPriority_t) osPriorityHigh,
};
/* Definitions for OdomHandler */
osThreadId_t OdomHandlerHandle;
const osThreadAttr_t OdomHandler_attributes = {
  .name = "OdomHandler",
  .stack_size = 256 * 4,
  .priority = (osPriority_t) osPriorityHigh7,
};
/* Definitions for USBBridge */
osThreadId_t USBBridgeHandle;
const osThreadAttr_t USBBridge_attributes = {
  .name = "USBBridge",
  .stack_size = 256 * 4,
  .priority = (osPriority_t) osPriorityNormal,
};
/* Definitions for EncoderQueue */
osMessageQueueId_t EncoderQueueHandle;
const osMessageQueueAttr_t EncoderQueue_attributes = {
  .name = "EncoderQueue"
};
/* Definitions for OdomQueue */
osMessageQueueId_t OdomQueueHandle;
const osMessageQueueAttr_t OdomQueue_attributes = {
  .name = "OdomQueue"
};
/* Definitions for MotorCMDQueue */
osMessageQueueId_t MotorCMDQueueHandle;
const osMessageQueueAttr_t MotorCMDQueue_attributes = {
  .name = "MotorCMDQueue"
};
/* USER CODE BEGIN PV */

/* IMU has no inter-task queue yet (magnetometer pending), so its readings are
   still mirrored here for STM32Cube Live Watch during bring-up. Encoder and
   odometry data now flow through FreeRTOS queues instead of shared globals. */
volatile float lw_imu_ax, lw_imu_ay, lw_imu_az;
volatile float lw_imu_gx, lw_imu_gy, lw_imu_gz;
volatile float lw_imu_temp;

/* Wheel calibration Live Watch variables. Use these to measure a left/right
   distance-per-tick mismatch: command equal PWM to both wheels (e.g. via
   MotorDriver_SetTwist(v, 0) or the headless test task) and compare
   lw_left_distance_cm vs lw_right_distance_cm over the same time window.
   A steady ratio difference is the ENCODER_LEFT_SCALE / ENCODER_RIGHT_SCALE
   correction to apply in encoders.h. Remove once wheel calibration is done
   and trusted. */
volatile int32_t lw_enc_left_count, lw_enc_right_count;
volatile float   lw_enc_left_distance_cm, lw_enc_right_distance_cm;
volatile float   lw_odom_theta;   /* mirrors Odometry_t.theta, rad */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_I2C1_Init(void);
static void MX_SPI1_Init(void);
static void MX_TIM1_Init(void);
static void MX_TIM2_Init(void);
static void MX_TIM3_Init(void);
void IMUTask(void *argument);
void EncoderTask(void *argument);
void MainMotorTask(void *argument);
void OdomTask(void *argument);
void MCU_RPI_Bridge(void *argument);

/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_I2C1_Init();
  MX_SPI1_Init();
  MX_TIM1_Init();
  MX_TIM2_Init();
  MX_TIM3_Init();
  /* USER CODE BEGIN 2 */

  HAL_TIM_Encoder_Start(&htim1, TIM_CHANNEL_ALL);
  HAL_TIM_Encoder_Start(&htim2, TIM_CHANNEL_ALL);

  HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_1);
  HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_2);
  HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_3);
  HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_4);

  /* USER CODE END 2 */

  /* Init scheduler */
  osKernelInitialize();

  /* USER CODE BEGIN RTOS_MUTEX */
  /* add mutexes, ... */
  /* USER CODE END RTOS_MUTEX */

  /* USER CODE BEGIN RTOS_SEMAPHORES */
  /* add semaphores, ... */
  /* USER CODE END RTOS_SEMAPHORES */

  /* USER CODE BEGIN RTOS_TIMERS */
  /* start timers, add new ones, ... */
  /* USER CODE END RTOS_TIMERS */

  /* Create the queue(s) */
  /* creation of EncoderQueue */
  EncoderQueueHandle = osMessageQueueNew (16, sizeof(EncoderSample_t), &EncoderQueue_attributes);

  /* creation of OdomQueue */
  OdomQueueHandle = osMessageQueueNew (16, sizeof(Odometry_t), &OdomQueue_attributes);

  /* creation of MotorCMDQueue */
  MotorCMDQueueHandle = osMessageQueueNew (16, sizeof(CmdVelPayload), &MotorCMDQueue_attributes);

  /* USER CODE BEGIN RTOS_QUEUES */
  /* Guard against CubeMX regenerating the queues with the placeholder element
     type (uint16_t): if the .ioc queue types are lost, the element size no
     longer matches the structs we put/get and motor commands are silently
     corrupted. Fail loudly here instead. */
  configASSERT(EncoderQueueHandle  != NULL);
  configASSERT(OdomQueueHandle     != NULL);
  configASSERT(MotorCMDQueueHandle != NULL);
  configASSERT(osMessageQueueGetCapacity(MotorCMDQueueHandle) > 0U);
  configASSERT(osMessageQueueGetMsgSize(MotorCMDQueueHandle) == sizeof(CmdVelPayload));
  configASSERT(osMessageQueueGetMsgSize(EncoderQueueHandle)  == sizeof(EncoderSample_t));
  configASSERT(osMessageQueueGetMsgSize(OdomQueueHandle)     == sizeof(Odometry_t));
  /* USER CODE END RTOS_QUEUES */

  /* Create the thread(s) */
  /* creation of IMU_Handler */
  IMU_HandlerHandle = osThreadNew(IMUTask, NULL, &IMU_Handler_attributes);

  /* creation of Encoder_Handler */
  Encoder_HandlerHandle = osThreadNew(EncoderTask, NULL, &Encoder_Handler_attributes);

  /* creation of MainMotorDriver */
  MainMotorDriverHandle = osThreadNew(MainMotorTask, NULL, &MainMotorDriver_attributes);

  /* creation of OdomHandler */
  OdomHandlerHandle = osThreadNew(OdomTask, NULL, &OdomHandler_attributes);

  /* creation of USBBridge */
  USBBridgeHandle = osThreadNew(MCU_RPI_Bridge, NULL, &USBBridge_attributes);

  /* USER CODE BEGIN RTOS_THREADS */
  /* add threads, ... */
  /* USER CODE END RTOS_THREADS */

  /* USER CODE BEGIN RTOS_EVENTS */
  /* add events, ... */
  /* USER CODE END RTOS_EVENTS */

  /* Start scheduler */
  osKernelStart();

  /* We should never get here as control is now taken by the scheduler */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE3);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLM = 12;
  RCC_OscInitStruct.PLL.PLLN = 96;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
  RCC_OscInitStruct.PLL.PLLQ = 4;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Activate the Over-Drive mode
  */
  if (HAL_PWREx_EnableOverDrive() != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV2;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_1) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief I2C1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_I2C1_Init(void)
{

  /* USER CODE BEGIN I2C1_Init 0 */

  /* USER CODE END I2C1_Init 0 */

  /* USER CODE BEGIN I2C1_Init 1 */

  /* USER CODE END I2C1_Init 1 */
  hi2c1.Instance = I2C1;
  hi2c1.Init.Timing = 0x20303E5D;
  hi2c1.Init.OwnAddress1 = 0;
  hi2c1.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  hi2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  hi2c1.Init.OwnAddress2 = 0;
  hi2c1.Init.OwnAddress2Masks = I2C_OA2_NOMASK;
  hi2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  hi2c1.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  if (HAL_I2C_Init(&hi2c1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Analogue filter
  */
  if (HAL_I2CEx_ConfigAnalogFilter(&hi2c1, I2C_ANALOGFILTER_ENABLE) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Digital filter
  */
  if (HAL_I2CEx_ConfigDigitalFilter(&hi2c1, 0) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN I2C1_Init 2 */

  /* USER CODE END I2C1_Init 2 */

}

/**
  * @brief SPI1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI1_Init(void)
{

  /* USER CODE BEGIN SPI1_Init 0 */

  /* USER CODE END SPI1_Init 0 */

  /* USER CODE BEGIN SPI1_Init 1 */

  /* USER CODE END SPI1_Init 1 */
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_2;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 7;
  hspi1.Init.CRCLength = SPI_CRC_LENGTH_DATASIZE;
  hspi1.Init.NSSPMode = SPI_NSS_PULSE_DISABLE;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * @brief TIM1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM1_Init(void)
{

  /* USER CODE BEGIN TIM1_Init 0 */

  /* USER CODE END TIM1_Init 0 */

  TIM_Encoder_InitTypeDef sConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM1_Init 1 */

  /* USER CODE END TIM1_Init 1 */
  htim1.Instance = TIM1;
  htim1.Init.Prescaler = 0;
  htim1.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim1.Init.Period = 65535;
  htim1.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim1.Init.RepetitionCounter = 0;
  htim1.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  sConfig.EncoderMode = TIM_ENCODERMODE_TI12;
  sConfig.IC1Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC1Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC1Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC1Filter = 0;
  sConfig.IC2Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC2Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC2Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC2Filter = 0;
  if (HAL_TIM_Encoder_Init(&htim1, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterOutputTrigger2 = TIM_TRGO2_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim1, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM1_Init 2 */

  /* USER CODE END TIM1_Init 2 */

}

/**
  * @brief TIM2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM2_Init(void)
{

  /* USER CODE BEGIN TIM2_Init 0 */

  /* USER CODE END TIM2_Init 0 */

  TIM_Encoder_InitTypeDef sConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM2_Init 1 */

  /* USER CODE END TIM2_Init 1 */
  htim2.Instance = TIM2;
  htim2.Init.Prescaler = 0;
  htim2.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim2.Init.Period = 65535;
  htim2.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim2.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  sConfig.EncoderMode = TIM_ENCODERMODE_TI12;
  sConfig.IC1Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC1Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC1Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC1Filter = 0;
  sConfig.IC2Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC2Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC2Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC2Filter = 0;
  if (HAL_TIM_Encoder_Init(&htim2, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim2, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM2_Init 2 */

  /* USER CODE END TIM2_Init 2 */

}

/**
  * @brief TIM3 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM3_Init(void)
{

  /* USER CODE BEGIN TIM3_Init 0 */

  /* USER CODE END TIM3_Init 0 */

  TIM_MasterConfigTypeDef sMasterConfig = {0};
  TIM_OC_InitTypeDef sConfigOC = {0};

  /* USER CODE BEGIN TIM3_Init 1 */

  /* USER CODE END TIM3_Init 1 */
  htim3.Instance = TIM3;
  htim3.Init.Prescaler = 0;
  htim3.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim3.Init.Period = 2399;
  htim3.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim3.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  if (HAL_TIM_PWM_Init(&htim3) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim3, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sConfigOC.OCMode = TIM_OCMODE_PWM1;
  sConfigOC.Pulse = 0;
  sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
  sConfigOC.OCFastMode = TIM_OCFAST_DISABLE;
  if (HAL_TIM_PWM_ConfigChannel(&htim3, &sConfigOC, TIM_CHANNEL_1) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_TIM_PWM_ConfigChannel(&htim3, &sConfigOC, TIM_CHANNEL_2) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_TIM_PWM_ConfigChannel(&htim3, &sConfigOC, TIM_CHANNEL_3) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_TIM_PWM_ConfigChannel(&htim3, &sConfigOC, TIM_CHANNEL_4) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM3_Init 2 */

  /* USER CODE END TIM3_Init 2 */
  HAL_TIM_MspPostInit(&htim3);

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(SBM_NSLEEP_GPIO_Port, SBM_NSLEEP_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(ICM_NCS_GPIO_Port, ICM_NCS_Pin, GPIO_PIN_SET);

  /*Configure GPIO pins : MAG_INT_Pin ICM_INT_Pin */
  GPIO_InitStruct.Pin = MAG_INT_Pin|ICM_INT_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_RISING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pin : SBM_NSLEEP_Pin */
  GPIO_InitStruct.Pin = SBM_NSLEEP_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(SBM_NSLEEP_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : ICM_NCS_Pin */
  GPIO_InitStruct.Pin = ICM_NCS_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(ICM_NCS_GPIO_Port, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */

/* USER CODE END 4 */

/* USER CODE BEGIN Header_IMUTask */
/**
  * @brief  Function implementing the IMU_Handler thread.
  * @param  argument: Not used
  * @retval None
  */
/* USER CODE END Header_IMUTask */
void IMUTask(void *argument)
{
  /* init code for USB_DEVICE */
  MX_USB_DEVICE_Init();
  /* USER CODE BEGIN 5 */

  int icm_ok = (ICM42688_Init() == ICM_OK);

#if LIS2MDL_ENABLED
  int mag_ok = (LIS2MDL_Init() == MAG_OK);
  LIS2MDL_t mag_data = {0};
#endif

  ICM42688_t icm_data = {0};

  /* Infinite loop */
  for(;;)
  {
    if (icm_ok && ICM42688_ReadData(&icm_data) == ICM_OK)
    {
      /* USER CODE BEGIN Live Watch: IMU */
      lw_imu_ax = icm_data.ax;
      lw_imu_ay = icm_data.ay;
      lw_imu_az = icm_data.az;
      lw_imu_gx = icm_data.gx;
      lw_imu_gy = icm_data.gy;
      lw_imu_gz = icm_data.gz;
      lw_imu_temp = icm_data.temperature;
      /* USER CODE END Live Watch: IMU */
    }

#if LIS2MDL_ENABLED
    if (mag_ok && LIS2MDL_ReadData(&mag_data) == MAG_OK)
    {
      /* TODO: expose mag_data via Live Watch once magnetometer is enabled */
    }
#endif

    osDelay(100);
  }
  /* USER CODE END 5 */
}

/* USER CODE BEGIN Header_EncoderTask */
/**
* @brief Function implementing the Encoder_Handler thread.
* @param argument: Not used
* @retval None
*/
/* USER CODE END Header_EncoderTask */
void EncoderTask(void *argument)
{
  /* USER CODE BEGIN EncoderTask */
  Encoders_Init();

  const uint32_t ENC_PERIOD_MS = 10;   /* 100 Hz */
  uint32_t last_wake = osKernelGetTickCount();

  /* Infinite loop */
  for(;;)
  {
    Encoders_Update();

    /* Live Watch: raw counts + calibrated cm distance per wheel, for
       measuring a left/right calibration mismatch (see encoders.h). */
    lw_enc_left_count  = Encoder_getLeftCount();
    lw_enc_right_count = Encoder_getRightCount();
    lw_enc_left_distance_cm  = Encoder_getLeftDistance();
    lw_enc_right_distance_cm = Encoder_getRightDistance();

    /* Publish cumulative wheel travel (cm -> m) to the odometry task.
       Overwrite the oldest sample if the queue is somehow full so we never
       block the encoder loop. */
    EncoderSample_t sample = {
      .left_m  = Encoder_getLeftDistance()  / 100.0f,
      .right_m = Encoder_getRightDistance() / 100.0f,
    };
    if (osMessageQueuePut(EncoderQueueHandle, &sample, 0U, 0U) == osErrorResource)
    {
      EncoderSample_t drop;
      (void)osMessageQueueGet(EncoderQueueHandle, &drop, NULL, 0U);
      (void)osMessageQueuePut(EncoderQueueHandle, &sample, 0U, 0U);
    }

    last_wake += ENC_PERIOD_MS;
    osDelayUntil(last_wake);
  }
  /* USER CODE END EncoderTask */
}

/* USER CODE BEGIN Header_MainMotorTask */
/**
* @brief Function implementing the MainMotorDriver thread.
* @param argument: Not used
* @retval None
*/
/* USER CODE END Header_MainMotorTask */
void MainMotorTask(void *argument)
{
  /* USER CODE BEGIN MainMotorTask */
  MotorDriver_Enable();

#if MOTOR_HEADLESS_TEST_ENABLED
  /*
   * Headless forward/backward test -- drives both wheels open-loop with no
   * USB/Pi dependency at all, to isolate hardware/motor issues from the
   * cmd_vel command path. Also doubles as the wheel-calibration test rig:
   * both wheels get the *exact same* commanded speed (v, omega=0), so any
   * left/right difference in lw_enc_left_distance_cm vs
   * lw_enc_right_distance_cm measured over one FORWARD_MS window is a real
   * physical/encoder mismatch you can fold into ENCODER_LEFT_SCALE /
   * ENCODER_RIGHT_SCALE (encoders.h).
   *
   * Enable by setting MOTOR_HEADLESS_TEST_ENABLED to 1 below. Disable (0)
   * for normal cmd_vel-driven operation -- do not leave this on when
   * running with the Pi/SLAM.
   */
  const float    TEST_SPEED_MPS = 0.35f;
  const uint32_t FORWARD_MS     = 3000;
  const uint32_t PAUSE_MS       = 1000;
  const uint32_t BACKWARD_MS    = 3000;

  for(;;)
  {
    MotorDriver_SetTwist(+TEST_SPEED_MPS, 0.0f);
    osDelay(FORWARD_MS);

    MotorDriver_SetTwist(0.0f, 0.0f);
    osDelay(PAUSE_MS);

    MotorDriver_SetTwist(-TEST_SPEED_MPS, 0.0f);
    osDelay(BACKWARD_MS);

    MotorDriver_SetTwist(0.0f, 0.0f);
    osDelay(PAUSE_MS);
  }
#else
  /* Consume body-twist commands (cmd_vel) from the USB bridge and drive the
     motors open-loop. If no command arrives within CMD_TIMEOUT_MS the base is
     stopped as a safety measure (lost link / idle Pi). */
  const uint32_t CMD_TIMEOUT_MS = 500;

  CmdVelPayload cmd = { .v = 0.0f, .omega = 0.0f };

  /* Infinite loop */
  for(;;)
  {
    if (osMessageQueueGet(MotorCMDQueueHandle, &cmd, NULL, CMD_TIMEOUT_MS) == osOK)
    {
      MotorDriver_SetTwist(cmd.v, cmd.omega);
    }
    else
    {
      /* Timed out waiting for a command -> stop. */
      MotorDriver_SetTwist(0.0f, 0.0f);
    }
  }
#endif /* MOTOR_HEADLESS_TEST_ENABLED */
  /* USER CODE END MainMotorTask */
}

/* USER CODE BEGIN Header_OdomTask */
/**
* @brief Function implementing the OdomHandler thread.
* @param argument: Not used
* @retval None
*/
/* USER CODE END Header_OdomTask */
void OdomTask(void *argument)
{
  /* USER CODE BEGIN OdomTask */
  const float TICK_S = 1.0f / (float)osKernelGetTickFreq();

  /* Wait for the first encoder sample to seed the previous-distance state. */
  EncoderSample_t sample;
  osMessageQueueGet(EncoderQueueHandle, &sample, NULL, osWaitForever);
  Odometry_Init(sample.left_m, sample.right_m);

  uint32_t last_tick = osKernelGetTickCount();

  /* Infinite loop */
  for(;;)
  {
    /* Block until the encoder task publishes a fresh sample. */
    if (osMessageQueueGet(EncoderQueueHandle, &sample, NULL, osWaitForever) != osOK)
      continue;

    uint32_t now = osKernelGetTickCount();
    float dt_s = (float)(now - last_tick) * TICK_S;
    last_tick = now;

    Odometry_Update(sample.left_m, sample.right_m, dt_s);

    /* Publish the latest pose/twist to the USB bridge. Keep only the newest:
       drop the stale sample if the consumer fell behind. */
    const Odometry_t *o = Odometry_Get();
    lw_odom_theta = o->theta;   /* Live Watch: watch for drift during a straight-line run */
    if (osMessageQueuePut(OdomQueueHandle, o, 0U, 0U) == osErrorResource)
    {
      Odometry_t drop;
      (void)osMessageQueueGet(OdomQueueHandle, &drop, NULL, 0U);
      (void)osMessageQueuePut(OdomQueueHandle, o, 0U, 0U);
    }
  }
  /* USER CODE END OdomTask */
}

/* USER CODE BEGIN Header_MCU_RPI_Bridge */
/**
* @brief Function implementing the USBBridge thread.
* @param argument: Not used
* @retval None
*/
/* USER CODE END Header_MCU_RPI_Bridge */
void MCU_RPI_Bridge(void *argument)
{
  /* USER CODE BEGIN MCU_RPI_Bridge */
  ProtocolParser parser;
  Protocol_ParserInit(&parser);

  /* Infinite loop */
  for(;;)
  {
    /* --- TX: forward the latest odometry to the Pi (non-blocking). --- */
    Odometry_t odom;
    if (osMessageQueueGet(OdomQueueHandle, &odom, NULL, 0U) == osOK)
    {
      OdometryPayload op = {
        .x     = odom.x,
        .y     = odom.y,
        .theta = odom.theta,
        .v     = odom.v,
        .omega = odom.omega,
      };
      USBBridge_SendFrame(MSG_ODOMETRY, &op, sizeof(op));
    }

    /* --- RX: parse any bytes received from the Pi. --- */
    uint8_t byte;
    while (USBBridge_RxPop(&byte))
    {
      uint8_t type;
      uint8_t payload[PROTOCOL_MAX_PAYLOAD];
      uint8_t len;

      if (Protocol_ParseByte(&parser, byte, &type, payload, sizeof(payload), &len))
      {
        if (type == MSG_CMD_VEL && len == sizeof(CmdVelPayload))
        {
          CmdVelPayload cmd;
          memcpy(&cmd, payload, sizeof(cmd));

          /* Deliver the newest command; drop a stale one if the motor task
             hasn't consumed it yet. */
          if (osMessageQueuePut(MotorCMDQueueHandle, &cmd, 0U, 0U) == osErrorResource)
          {
            CmdVelPayload drop;
            (void)osMessageQueueGet(MotorCMDQueueHandle, &drop, NULL, 0U);
            (void)osMessageQueuePut(MotorCMDQueueHandle, &cmd, 0U, 0U);
          }
        }
      }
    }

    /* ~1 kHz service rate: fast enough to keep RX latency low while yielding. */
    osDelay(1);
  }
  /* USER CODE END MCU_RPI_Bridge */
}

/**
  * @brief  Period elapsed callback in non blocking mode
  * @note   This function is called  when TIM6 interrupt took place, inside
  * HAL_TIM_IRQHandler(). It makes a direct call to HAL_IncTick() to increment
  * a global variable "uwTick" used as application time base.
  * @param  htim : TIM handle
  * @retval None
  */
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
  /* USER CODE BEGIN Callback 0 */

  /* USER CODE END Callback 0 */
  if (htim->Instance == TIM6)
  {
    HAL_IncTick();
  }
  /* USER CODE BEGIN Callback 1 */

  /* USER CODE END Callback 1 */
}

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
