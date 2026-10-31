# Robot AI Environment Setup Plan

Handover log (最優先で参照): [docs/SESSION_LOG.md](SESSION_LOG.md)
RL boundary snapshot: [docs/rl_environment_boundary.md](rl_environment_boundary.md)
Phase A ops: [docs/phase_a_experiment_management.md](phase_a_experiment_management.md)
Phase A MDP notes: [docs/phase_a_observation_reward_action.md](phase_a_observation_reward_action.md)
Phase B foundation: [docs/phase_b_foundation.md](phase_b_foundation.md)
Project purpose and task: [docs/project_purpose_and_task.md](project_purpose_and_task.md)

## Target Stable Stack

- OS: Ubuntu 24.04
- GPU: NVIDIA RTX 4070 Ti SUPER
- Driver: NVIDIA 580 production branch
- Container runtime: Docker Engine + NVIDIA Container Toolkit
- Simulator: Isaac Sim 5.1.x initially
- Learning framework: Isaac Lab stable/main compatible with Isaac Sim 5.1.x
- Deep learning: PyTorch CUDA wheel managed inside the Isaac Lab environment/container
- Middleware: ROS 2 Jazzy, enabled after base Isaac Lab validation

## Current Gate

The host setup must pass these checks before Isaac Lab is installed:

1. `groups` includes `docker`. Done in the user terminal.
2. `docker info` works without `sudo`. Done in the user terminal.
3. `nvidia-container-toolkit` packages are installed. Done.
4. `docker run --rm --runtime=nvidia --gpus all nvcr.io/nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi` works. Done.
5. `/mnt/ai_data` is a real mount, not a directory on `/`. Done.
6. `/mnt/ai_data/{datasets,checkpoints,isaac_cache,videos,experiments}` exists. Done.

The remaining host commands are documented in `docs/host_setup_commands.md`.

Run:

```bash
bash scripts/check_host_env.sh
```

## Current Status

Validated on the current machine and container:

1. Docker and NVIDIA Container Toolkit are installed and working.
2. `/mnt/ai_data` is mounted from the large NTFS SSD and used for Isaac Lab cache/log redirection.
3. Isaac Lab is cloned locally at `IsaacLab` on tag `v2.3.2`.
4. Isaac Sim launches headless inside the container with GPU acceleration.
5. PyTorch inside the Isaac Lab container reports `2.7.0+cu128` and sees the RTX 4070 Ti SUPER.
6. Franka tasks are registered, including `Isaac-Lift-Cube-Franka-v0`.
7. PPO smoke test completed for `Isaac-Lift-Cube-Franka-v0` with `--max_iterations 1`.
8. A Phase A PPO baseline run completed with `128` environments and `50` iterations.
9. The resulting checkpoint was loaded through `play.py`, and exported `policy.pt` / `policy.onnx` artifacts were generated.
10. A3 task analysis was documented for state-only Phase A progression.
11. A4 custom grasp task `Isaac-Lift-Cube-Franka-Grasp-v0` was added as a minimal fork of the upstream lift task.
12. `experiment_name` now flows through the RSL-RL CLI, so logs can be separated cleanly per run family.
13. Phase A grasp + domain randomization was trained further and the learning assets are now treated as frozen reference data for later comparison.

## Installation Direction

Use Docker first. Keep host Python/CUDA as thin as possible because the host currently has multiple CUDA toolkit packages visible. Isaac Sim, Isaac Lab, PyTorch, and ROS bridge dependencies should be isolated inside the container until the base learning workflow is stable.

Isaac Lab has been cloned at `IsaacLab` on tag `v2.3.2`. Docker storage redirection is documented in `docs/isaaclab_docker.md`.

## First Learning Milestones

1. Validate Isaac Lab container and Python import path.
2. Run a built-in Franka example or environment.
3. Inspect available manipulation tasks and select the closest cube/pick/grasp baseline.
4. Create a custom Franka cube grasp task only after the baseline task runs.
5. Train PPO headless with video/log outputs redirected to `/mnt/ai_data`.
6. Add demonstration recording and imitation learning data format.
7. Add Diffusion Policy training.
8. Initialize RL from the imitation policy and fine tune.

## Immediate Next Step

Freeze the RL workspace as the Phase A reference, then start Phase B with data collection design and schema definition.

Recommended command from the workspace root:

```bash
bash scripts/run_phase_a_baseline.sh
```

長時間学習プリセット（headless想定）:

```bash
bash scripts/run_phase_a_long.sh
```

継続学習（最新checkpointからresume）:

```bash
RUN_NAME_FILTER=long_n576_i1500 MAX_ITERATIONS=1000 NUM_ENVS=576 bash scripts/resume_phase_a_baseline.sh
```

NUM_ENVS上限探索（1 iterationずつ）:

```bash
bash scripts/tune_phase_a_num_envs.sh
```

GUIで確認したい場合は headless を無効化:

```bash
HEADLESS=0 NUM_ENVS=1 MAX_ITERATIONS=5 bash scripts/run_phase_a_baseline.sh
```

For the new custom grasp variant:

```bash
bash scripts/run_phase_a_grasp_baseline.sh
```

Long grasp training:

```bash
NUM_ENVS=576 MAX_ITERATIONS=1500 RUN_NAME=grasp_long_n576_i1500 EXPERIMENT_NAME=franka_grasp_phase_a bash scripts/run_phase_a_grasp_baseline.sh
```

Grasp + domain randomization (A5):

```bash
NUM_ENVS=576 MAX_ITERATIONS=3000 RUN_NAME=grasp_dr_n576_i3000 EXPERIMENT_NAME=franka_grasp_phase_a_dr bash scripts/run_phase_a_grasp_long.sh
```

学習済みモデルの再生（GUI確認用）:

```bash
HEADLESS=0 NUM_ENVS=1 bash scripts/play_phase_a_baseline.sh
```

The grasp baseline currently writes to:

```text
/mnt/ai_data/experiments/isaac-lab-logs/rsl_rl/franka_grasp_phase_a/<timestamp>_smoke
```

This wrapper keeps the run reproducible and writes the learning artifacts into the persisted Isaac Lab log volume on `/mnt/ai_data`.

Phase A grasp resume:

```bash
EXPERIMENT_NAME=franka_grasp_phase_a_dr RUN_NAME_FILTER=grasp_dr_n576_i3000 NUM_ENVS=576 MAX_ITERATIONS=20000 bash scripts/resume_phase_a_grasp.sh
```

Phase B foundation:

```bash
cat docs/phase_b_foundation.md
```

Phase B demo collection:

```bash
bash scripts/collect_phase_b_demos.sh
```

Phase B smoke test:

```bash
NUM_DEMOS=1 MAX_STEPS_PER_DEMO=300 bash scripts/collect_phase_b_demos.sh
```

Phase B dataset conversion:

```bash
bash scripts/convert_phase_b_dataset.sh
```

Phase B BC baseline:

```bash
EPOCHS=200 RUN_NAME=phase_b_bc_grasp bash scripts/train_phase_b_bc.sh
```

Phase B BC play:

```bash
CHECKPOINT=/workspace/isaaclab/logs/robomimic_phase_b/Isaac-Lift-Cube-Franka-Grasp-v0/<run>/<timestamp>/models/model_epoch_200.pth HEADLESS=0 bash scripts/play_phase_b_bc.sh
```

Phase B BC latest replay:

```bash
RUN_NAME_FILTER=phase_b_bc_grasp_v3 HEADLESS=1 bash scripts/play_phase_b_bc.sh
```

The latest baseline run produced artifacts under:

```text
/mnt/ai_data/experiments/isaac-lab-logs/rsl_rl/franka_lift/2026-06-07_03-10-28_baseline
```

Detailed task analysis notes live in [docs/phase_a_task_analysis.md](phase_a_task_analysis.md).
