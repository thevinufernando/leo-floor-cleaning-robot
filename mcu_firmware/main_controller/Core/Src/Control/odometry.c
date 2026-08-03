#include "odometry.h"

#include <math.h>

/* WHEEL_BASE_MM is in mm; work in meters internally. */
#define WHEEL_BASE_M (WHEEL_BASE_MM / 1000.0f)

/* Latest computed odometry state. */
static Odometry_t odom;

/*
 * Previous cumulative wheel distances (in meters). Kept to form the per-step
 * increment from successive EncoderQueue samples.
 */
static float prev_left_m;
static float prev_right_m;

/* Wrap an angle to (-pi, pi]. */
static float wrap_pi(float angle)
{
    while (angle > (float)M_PI)  angle -= 2.0f * (float)M_PI;
    while (angle <= -(float)M_PI) angle += 2.0f * (float)M_PI;
    return angle;
}

void Odometry_Reset(float left_m, float right_m)
{
    odom.x     = 0.0f;
    odom.y     = 0.0f;
    odom.theta = 0.0f;
    odom.v     = 0.0f;
    odom.omega = 0.0f;

    prev_left_m  = left_m;
    prev_right_m = right_m;
}

void Odometry_Init(float left_m, float right_m)
{
    Odometry_Reset(left_m, right_m);
}

void Odometry_Update(float left_m, float right_m, float dt_s)
{
    /* Per-step increments. */
    const float d_left  = left_m  - prev_left_m;
    const float d_right = right_m - prev_right_m;

    prev_left_m  = left_m;
    prev_right_m = right_m;

    /* Differential-drive kinematics. */
    const float d_center = 0.5f * (d_right + d_left);          /* linear step [m]   */
    const float d_theta  = (d_right - d_left) / WHEEL_BASE_M;  /* heading step [rad] */

    /*
     * Integrate pose. Use the exact arc solution when the robot is turning,
     * and the straight-line approximation otherwise to avoid dividing by a
     * near-zero d_theta.
     */
    if (fabsf(d_theta) < 1e-6f)
    {
        odom.x += d_center * cosf(odom.theta);
        odom.y += d_center * sinf(odom.theta);
    }
    else
    {
        const float radius       = d_center / d_theta;
        const float theta_new    = odom.theta + d_theta;
        odom.x += radius * (sinf(theta_new) - sinf(odom.theta));
        odom.y -= radius * (cosf(theta_new) - cosf(odom.theta));
    }

    odom.theta = wrap_pi(odom.theta + d_theta);

    /* Body-frame twist. Guard against a zero/negative dt. */
    if (dt_s > 0.0f)
    {
        odom.v     = d_center / dt_s;
        odom.omega = d_theta  / dt_s;
    }
    else
    {
        odom.v     = 0.0f;
        odom.omega = 0.0f;
    }
}

const Odometry_t *Odometry_Get(void)
{
    return &odom;
}
