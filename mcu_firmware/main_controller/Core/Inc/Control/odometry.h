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

/* Reset pose/twist to zero and re-sync with the encoder driver. */
void Odometry_Init(void);
void Odometry_Reset(void);

/*
 * Advance the odometry by one step.
 *   dt_s: elapsed time since the previous update, in seconds.
 * Reads the latest encoder distances internally, so Encoders_Update() must be
 * called (by the encoder task) at a rate >= the odometry update rate.
 */
void Odometry_Update(float dt_s);

/* Read-only accessor to the latest computed odometry. */
const Odometry_t *Odometry_Get(void);

#endif /* ODOMETRY_H */
