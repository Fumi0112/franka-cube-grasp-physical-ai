#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
experiment_name="${EXPERIMENT_NAME:-franka_grasp_phase_a_dr}"
run_name_filter="${RUN_NAME_FILTER:-}"
dataset_file="${DATASET_FILE:-/mnt/ai_data/datasets/phase_b/grasp_state_demos.hdf5}"
num_envs="${NUM_ENVS:-1}"
num_demos="${NUM_DEMOS:-10}"
max_steps_per_demo="${MAX_STEPS_PER_DEMO:-600}"
success_height="${SUCCESS_HEIGHT:-0.04}"
success_hold_steps="${SUCCESS_HOLD_STEPS:-10}"
checkpoint="${CHECKPOINT:-}"

if ! docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
  printf 'ERROR: container %s is not running\n' "$container_name" >&2
  exit 1
fi

if [ -z "$checkpoint" ]; then
  checkpoint="$(
    DOCKER_TTY=0 CONTAINER_NAME="$container_name" WORKSPACE_DIR="$workspace_dir" \
      EXPERIMENT_NAME="$experiment_name" RUN_NAME_FILTER="$run_name_filter" \
      bash scripts/find_phase_a_checkpoint.sh 2>/dev/null || true
  )"
fi

if [ -z "$checkpoint" ]; then
  printf 'ERROR: no checkpoint found for policy demo collection.\n' >&2
  printf '  experiment_name : %s\n' "$experiment_name" >&2
  printf '  run_name_filter : %s\n' "${run_name_filter:-<none>}" >&2
  exit 1
fi

dataset_dir="$(dirname "$dataset_file")"
mkdir -p "$dataset_dir"

printf '== Phase B demo collection ==\n'
printf 'experiment_name : %s\n' "$experiment_name"
printf 'checkpoint      : %s\n' "$checkpoint"
printf 'dataset_file    : %s\n' "$dataset_file"
printf 'num_envs        : %s\n' "$num_envs"
printf 'num_demos       : %s\n' "$num_demos"
printf 'max_steps/demo  : %s\n' "$max_steps_per_demo"
printf 'success_height  : %s\n' "$success_height"
printf 'success_hold    : %s\n' "$success_hold_steps"

docker exec -t \
  -e HDF5_USE_FILE_LOCKING=FALSE \
  "$container_name" bash -lc "
    cd '$workspace_dir' &&
    ./isaaclab.sh -p scripts/imitation_learning/phase_b/collect_policy_demos.py \
      --task '${TASK_NAME:-Isaac-Lift-Cube-Franka-Grasp-v0}' \
      --num_envs '$num_envs' \
      --num_demos '$num_demos' \
      --max_steps_per_demo '$max_steps_per_demo' \
      --success_height '$success_height' \
      --num_success_steps '$success_hold_steps' \
      --dataset_file '$dataset_file' \
      --experiment_name '$experiment_name' \
      --checkpoint '$checkpoint' \
      --headless
  "
