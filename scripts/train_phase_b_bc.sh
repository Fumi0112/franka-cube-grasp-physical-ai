#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
task_name="${TASK_NAME:-Isaac-Lift-Cube-Franka-Grasp-v0}"
algo_name="${ALGO_NAME:-bc}"
dataset_file="${DATASET_FILE:-/mnt/ai_data/datasets/phase_b/grasp_state_demos_robomimic.hdf5}"
run_name="${RUN_NAME:-phase_b_bc_grasp}"
log_dir="${LOG_DIR:-robomimic_phase_b}"
epochs="${EPOCHS:-200}"

if ! docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
  printf 'ERROR: container %s is not running\n' "$container_name" >&2
  exit 1
fi

printf '== Phase B BC training ==\n'
printf 'task         : %s\n' "$task_name"
printf 'algo         : %s\n' "$algo_name"
printf 'dataset_file : %s\n' "$dataset_file"
printf 'run_name     : %s\n' "$run_name"
printf 'log_dir      : %s\n' "$log_dir"
printf 'epochs       : %s\n' "$epochs"

docker exec -t \
  -e HDF5_USE_FILE_LOCKING=FALSE \
  "$container_name" bash -lc "
    cd '$workspace_dir' &&
    ./isaaclab.sh -p scripts/imitation_learning/robomimic/train.py \
      --task '$task_name' \
      --algo '$algo_name' \
      --dataset '$dataset_file' \
      --name '$run_name' \
      --log_dir '$log_dir' \
      --epochs '$epochs'
  "
