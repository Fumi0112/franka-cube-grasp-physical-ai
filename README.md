# Franka Panda Cube Grasp with Isaac Sim and Isaac Lab

This project studies a Physical AI manipulation task in simulation: a Franka Panda approaches a randomly placed cube, grasps it, lifts it, and moves it toward a commanded target position.

The project uses PPO as the primary policy and reuses the trained RL policy as a teacher for imitation learning. Behavior Cloning is implemented as the first imitation baseline, with Diffusion Policy planned as the next stage.

## Task

1. Move the Franka end effector toward the cube.
2. Align the fingertips around the cube.
3. Close the gripper.
4. Lift the cube above the minimum height.
5. Move the grasped cube toward the commanded target position.

The current state-only observation contains joint position, joint velocity, cube position, commanded target pose, and the previous action. The action has 8 dimensions: 7 arm joint-position commands and 1 gripper command.

## Stack

- Ubuntu 24.04
- Docker and NVIDIA Container Toolkit
- NVIDIA Isaac Sim 5.1.x
- Isaac Lab v2.3.2
- PyTorch CUDA container environment
- Franka Panda
- ROS 2 Jazzy (prepared for later integration)

## Repository layout

- `scripts/`: host-side commands for environment checks, PPO runs, demo collection, dataset conversion, BC training, and evaluation
- `docs/`: task description, experiment notes, handover log, and final-assignment material
- `IsaacLab/`: Isaac Lab source tree used by this project, including the project-specific task and learning changes

Large datasets, checkpoints, videos, caches, and runtime logs are intentionally excluded from Git. They are stored under `/mnt/ai_data` locally.

## Quick start

Start the existing container:

```bash
docker start isaac-lab-base
```

Run a PPO headless smoke test:

```bash
bash scripts/run_phase_a_grasp_baseline.sh
```

Replay the trained RL policy with GUI:

```bash
HEADLESS=0 TASK_NAME=Isaac-Lift-Cube-Franka-Grasp-Play-v0 \
EXPERIMENT_NAME=franka_grasp_phase_a_dr NUM_ENVS=1 REAL_TIME=1 \
bash scripts/play_phase_a_baseline.sh
```

Collect and train the Phase B BC baseline:

```bash
NUM_DEMOS=50 bash scripts/collect_phase_b_demos.sh
INPUT_FILE=/mnt/ai_data/datasets/phase_b/grasp_state_demos_v2.hdf5 \
OUTPUT_FILE=/mnt/ai_data/datasets/phase_b/grasp_state_demos_v2_robomimic.hdf5 \
bash scripts/convert_phase_b_dataset.sh
DATASET_FILE=/mnt/ai_data/datasets/phase_b/grasp_state_demos_v2_robomimic.hdf5 \
EPOCHS=200 RUN_NAME=phase_b_bc_grasp bash scripts/train_phase_b_bc.sh
```

Replay the latest BC checkpoint:

```bash
RUN_NAME_FILTER=phase_b_bc_grasp_v4 HEADLESS=1 \
SUCCESS_HEIGHT=0.03 SUCCESS_HOLD_STEPS=5 \
bash scripts/play_phase_b_bc.sh
```

## Current result

The PPO teacher policy can perform the grasp/lift behavior in Isaac Sim. The BC pipeline is complete from teacher rollout to HDF5 conversion, training, and evaluation, but the current BC success rate is not stable. The 50-demo experiment achieved 1/20 under a relaxed height-based success condition and 0/20 under a stricter condition.

This result is included intentionally: it documents the transfer gap between an RL policy and a one-step Behavior Cloning policy and motivates the next Diffusion Policy stage.

## Documentation

- [Project purpose and task](docs/project_purpose_and_task.md)
- [Phase B foundation](docs/phase_b_foundation.md)
- [Final assignment readiness](docs/final_assignment_readiness_2026-10-31.md)
- [Session log](docs/SESSION_LOG.md)
- [GitHub submission policy](docs/github_submission.md)

## Upstream attribution

The `IsaacLab/` directory is based on the upstream Isaac Lab project. See its included license and attribution files. This repository documents the project-specific task, scripts, configuration, and modifications used for the experiment.
