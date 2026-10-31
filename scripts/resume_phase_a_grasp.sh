#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
experiment_name="${EXPERIMENT_NAME:-franka_grasp_phase_a_dr}"
run_name_filter="${RUN_NAME_FILTER:-}"
checkpoint="${CHECKPOINT:-}"
num_envs="${NUM_ENVS:-576}"
max_iterations="${MAX_ITERATIONS:-20000}"

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
  printf 'ERROR: no checkpoint found to resume.\n' >&2
  printf '  experiment_name : %s\n' "$experiment_name" >&2
  printf '  run_name_filter : %s\n' "${run_name_filter:-<none>}" >&2
  printf '  hint: remove RUN_NAME_FILTER to resume latest, or set CHECKPOINT explicitly.\n' >&2
  exit 1
fi

load_run="$(basename "$(dirname "$checkpoint")")"
checkpoint_file="$(basename "$checkpoint")"

printf '== Phase A grasp resume ==\n'
printf 'experiment_name : %s\n' "$experiment_name"
printf 'load_run        : %s\n' "$load_run"
printf 'checkpoint      : %s\n' "$checkpoint_file"
printf 'num_envs        : %s\n' "$num_envs"
printf 'max_iterations  : %s\n' "$max_iterations"

CONTAINER_NAME="$container_name" \
WORKSPACE_DIR="$workspace_dir" \
EXPERIMENT_NAME="$experiment_name" \
RUN_NAME="resume_${load_run}" \
NUM_ENVS="$num_envs" \
MAX_ITERATIONS="$max_iterations" \
RESUME=1 \
LOAD_RUN="$load_run" \
CHECKPOINT="$checkpoint_file" \
HEADLESS="${HEADLESS:-1}" \
bash scripts/run_phase_a_grasp_baseline.sh
