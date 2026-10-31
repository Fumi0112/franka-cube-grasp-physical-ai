# Phase A Task Analysis

## Target Task

Base task: `Isaac-Lift-Cube-Franka-v0`

Working assumptions for Phase A:

- lift success is the primary goal
- state-only observations for now
- keep the task close to the upstream Isaac Lab implementation
- use existing PPO baseline before any custom task fork

## Current Control Surface

Action space:

- `arm_action`: 7 DoF joint position control for the Franka arm
- `gripper_action`: binary open/close command for the fingers
- total action dimension: 8

This is a good fit for a conservative baseline because it reuses the upstream Franka controller structure instead of introducing a new controller family.

## Current Observations

Policy observation group:

- `joint_pos` : 9
- `joint_vel` : 9
- `object_position` : 3
- `target_object_position` : 7
- `actions` : 8

Total policy observation dimension: `36`

Interpretation:

- the policy sees proprioception
- it sees the cube position in the robot frame
- it sees the command target pose
- it sees the previous action
- there is no camera input in the current Phase A path

## Current Rewards

Reward terms:

- `reaching_object`
- `lifting_object`
- `object_goal_tracking`
- `object_goal_tracking_fine_grained`
- `action_rate`
- `joint_vel`

Meaning:

- `reaching_object` pushes the end-effector toward the cube
- `lifting_object` gives a discrete reward once the cube is lifted above the threshold
- `object_goal_tracking` rewards moving the cube toward the commanded pose after lift
- `object_goal_tracking_fine_grained` is the same idea with a tighter kernel
- `action_rate` penalizes rapid action changes
- `joint_vel` penalizes excessive joint velocity

Phase A implication:

- the current task is not pure grasp-only
- it is already a lift-and-track style setup
- for Phase A, that is acceptable because it is easier to stabilize and reuses upstream design

## Current Terminations

Termination terms:

- `time_out`
- `object_dropping`

Implication:

- episodes end either by timeout or if the cube drops too low
- this is enough for baseline PPO
- custom grasp variants can tighten this later if needed

## Current PPO Baseline

Observed baseline run:

- `128` environments
- `50` iterations
- `seed=42`
- `experiment_name=franka_lift_phase_a`
- `run_name=baseline`

Artifacts:

- checkpoint: `model_49.pt`
- exported inference: `policy.pt`, `policy.onnx`
- log root: `/mnt/ai_data/experiments/isaac-lab-logs/rsl_rl/franka_lift/2026-06-07_03-10-28_baseline`

## Design Choice For A4

Keep the Phase A custom task as a minimal fork of the upstream lift task.

Recommended next modifications, in order:

1. keep the same robot, action space, and state-only observation layout
2. adjust the cube spawn and reset behavior for the grasp scenario
3. tune reward weights if lift success stalls
4. only then consider more invasive changes

Current custom task:

- task id: `Isaac-Lift-Cube-Franka-Grasp-v0`
- play id: `Isaac-Lift-Cube-Franka-Grasp-Play-v0`
- current changes: slightly closer cube reset, fingertip-to-object shaping, gripper-close shaping, smoother lift-height shaping, softened pose-tracking reward
- experiment root: `franka_grasp_phase_a`

## Why No Camera Yet

Phase A stays state-only because:

- it keeps PPO iteration fast
- it isolates reward and action design issues
- it preserves a clean baseline for later comparison
- camera can be added as a separate branch when imitation learning starts

This keeps Phase A aligned with the original goal while leaving Phase B free to introduce vision without confounding the RL baseline.
