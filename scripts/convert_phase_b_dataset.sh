#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
input_file="${INPUT_FILE:-/mnt/ai_data/datasets/phase_b/grasp_state_demos.hdf5}"
output_file="${OUTPUT_FILE:-/mnt/ai_data/datasets/phase_b/grasp_state_demos_robomimic.hdf5}"
train_ratio="${TRAIN_RATIO:-0.9}"

if ! docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
  printf 'ERROR: container %s is not running\n' "$container_name" >&2
  exit 1
fi

printf '== Phase B dataset conversion ==\n'
printf 'input_file  : %s\n' "$input_file"
printf 'output_file : %s\n' "$output_file"
printf 'train_ratio : %s\n' "$train_ratio"

docker exec -t \
  -e HDF5_USE_FILE_LOCKING=FALSE \
  "$container_name" bash -lc "
    cd '$workspace_dir' &&
    ./isaaclab.sh -p scripts/imitation_learning/phase_b/convert_policy_demos_to_robomimic.py \
      --input '$input_file' \
      --output '$output_file' \
      --train_ratio '$train_ratio'
  "
