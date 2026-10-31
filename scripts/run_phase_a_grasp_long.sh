#!/usr/bin/env bash
set -euo pipefail

num_envs="${NUM_ENVS:-576}"
max_iterations="${MAX_ITERATIONS:-1500}"
run_name="${RUN_NAME:-grasp_long_n${num_envs}_i${max_iterations}}"
experiment_name="${EXPERIMENT_NAME:-franka_grasp_phase_a}"

CONTAINER_NAME="${CONTAINER_NAME:-isaac-lab-base}" \
TASK_NAME="${TASK_NAME:-Isaac-Lift-Cube-Franka-Grasp-v0}" \
NUM_ENVS="$num_envs" \
MAX_ITERATIONS="$max_iterations" \
EXPERIMENT_NAME="$experiment_name" \
RUN_NAME="$run_name" \
HEADLESS="${HEADLESS:-1}" \
bash scripts/run_phase_a_grasp_baseline.sh
