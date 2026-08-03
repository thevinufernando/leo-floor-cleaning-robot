#ifndef ODOMETRY_H
#define ODOMETRY_H

#include <stdint.h>

/*
 * Differential-drive wheel odometry.
 *
 * Integrates the pose (x, y, theta) of the robot in the odom frame using only
 * the motor encoder readings. All outputs are in SI units (meters, radians,
 * m/s, rad/s) so they can be published directly to ROS2 / slam_toolbox.
 *
 * NOTE: Heading (theta) here comes purely from the wheel encoders. Once the
 * magnetometer is populated and the IMU is fused in, theta should be improved
 * with a complementary/EKF filter for better long-run accuracy.
 */

/* Distance between the left and right wheel contact points, in millimeters. */
#define WHEEL_BASE_MM 263.0f

/* Pose + twist in the odom frame (SI units). */
typedef struct {

    /* Pose */
    float x;        /* meters   */
    float y;        /* meters   */
    float theta;    /* radians, wrapped to (-pi, pi] */

    /* Body-frame twist (as expected by ROS Twist for a diff-drive base) */
    float v;        /* linear velocity  [m/s]   */
    float omega;    /* angular velocity [rad/s] */

} Odometry_t;

/*
 * Reset pose/twist to zero and seed the previous wheel distances.
 *   left_m, right_m: current cumulative wheel travel, in meters.
 */
void Odometry_Init(float left_m, float right_m);
void Odometry_Reset(float left_m, float right_m);

/*
 * Advance the odometry by one step.
 *   left_m, right_m: latest cumulative wheel travel, in meters (from the
 *                    EncoderQueue sample).
 *   dt_s:            elapsed time since the previous update, in seconds.
 */
void Odometry_Update(float left_m, float right_m, float dt_s);

/* Read-only accessor to the latest computed odometry. */
const Odometry_t *Odometry_Get(void);

#endif /* ODOMETRY_H */
