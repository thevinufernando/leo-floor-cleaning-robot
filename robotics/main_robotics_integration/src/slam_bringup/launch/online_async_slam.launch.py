#!/usr/bin/env python3
"""
Launch slam_toolbox in online asynchronous mapping mode.

Assumes its prerequisites are already running (start them separately, e.g.
via slam_bringup/launch/slam_prereqs.launch.py):
  * /scan          from rplidar_ros           (frame_id: laser)
  * odom->base_link TF + /odom  from mcu_bridge
  * base_link->laser TF (and rest of the robot) from robot_state_publisher

slam_toolbox adds the map->odom transform on top of that chain. This launch
starts ONLY the mapper, so the map is built the moment you run it.

IMPORTANT: slam_toolbox is a *lifecycle* node. It starts `unconfigured` and
does nothing at all -- no parameters loaded, no /map publisher, no map->odom
TF -- until it is transitioned configure -> activate. This launch performs
that transition automatically (autostart:=true, the default), mirroring
slam_toolbox's own online_async_launch.py. Launching it as a plain
`launch_ros.actions.Node` silently leaves it inactive.
"""

from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument,
    EmitEvent,
    LogInfo,
    RegisterEventHandler,
)
from launch.conditions import IfCondition
from launch.events import matches_action
from launch.substitutions import (
    AndSubstitution,
    LaunchConfiguration,
    NotSubstitution,
    PathJoinSubstitution,
)
from launch_ros.actions import LifecycleNode
from launch_ros.event_handlers import OnStateTransition
from launch_ros.events.lifecycle import ChangeState
from launch_ros.substitutions import FindPackageShare
from lifecycle_msgs.msg import Transition


def generate_launch_description():
    autostart = LaunchConfiguration('autostart')
    use_lifecycle_manager = LaunchConfiguration('use_lifecycle_manager')
    use_sim_time = LaunchConfiguration('use_sim_time')
    params_file = LaunchConfiguration('params_file')

    default_params = PathJoinSubstitution([
        FindPackageShare('slam_bringup'),
        'config',
        'mapper_params_online_async.yaml',
    ])

    slam_node = LifecycleNode(
        package='slam_toolbox',
        executable='async_slam_toolbox_node',
        name='slam_toolbox',
        namespace='',
        output='screen',
        parameters=[
            params_file,
            {
                'use_lifecycle_manager': use_lifecycle_manager,
                'use_sim_time': use_sim_time,
            },
        ],
    )

    # unconfigured -> inactive (loads parameters, creates publishers)
    configure_event = EmitEvent(
        event=ChangeState(
            lifecycle_node_matcher=matches_action(slam_node),
            transition_id=Transition.TRANSITION_CONFIGURE,
        ),
        condition=IfCondition(
            AndSubstitution(autostart, NotSubstitution(use_lifecycle_manager))
        ),
    )

    # inactive -> active (starts processing scans, publishing /map + map->odom)
    activate_event = RegisterEventHandler(
        OnStateTransition(
            target_lifecycle_node=slam_node,
            start_state='configuring',
            goal_state='inactive',
            entities=[
                LogInfo(msg='[LifecycleLaunch] slam_toolbox is activating.'),
                EmitEvent(event=ChangeState(
                    lifecycle_node_matcher=matches_action(slam_node),
                    transition_id=Transition.TRANSITION_ACTIVATE,
                )),
            ],
        ),
        condition=IfCondition(
            AndSubstitution(autostart, NotSubstitution(use_lifecycle_manager))
        ),
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            'autostart', default_value='true',
            description='Automatically configure+activate slam_toolbox. '
                        'Ignored when use_lifecycle_manager is true.'),
        DeclareLaunchArgument(
            'use_lifecycle_manager', default_value='false',
            description='Enable bond connection during node activation '
                        '(set true when an external lifecycle manager, e.g. '
                        'Nav2, drives the transitions instead)'),
        DeclareLaunchArgument(
            'use_sim_time', default_value='false',
            description='Use /clock (simulation) time'),
        DeclareLaunchArgument(
            'params_file', default_value=default_params,
            description='slam_toolbox online-async parameter YAML'),
        slam_node,
        configure_event,
        activate_event,
    ])
