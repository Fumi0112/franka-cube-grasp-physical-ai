#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
candidates="${CANDIDATES:-128 192 256 320 384 448 512 640}"
max_iterations="${MAX_ITERATIONS:-1}"
task_name="${TASK_NAME:-Isaac-Lift-Cube-Franka-v0}"
experiment_name="${EXPERIMENT_NAME:-franka_lift_phase_a_tune}"
seed="${SEED:-42}"

if ! docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
  printf 'ERROR: container %s is not running\n' "$container_name" >&2
  exit 1
fi

printf '== Phase A NUM_ENVS tuning ==\n'
printf 'task            : %s\n' "$task_name"
printf 'candidates      : %s\n' "$candidates"
printf 'max_iterations  : %s\n' "$max_iterations"
printf 'experiment_name : %s\n' "$experiment_name"

best=""
for n in $candidates; do
  printf '\n[TRY] NUM_ENVS=%s\n' "$n"
  if CONTAINER_NAME="$container_name" \
    TASK_NAME="$task_name" \
    NUM_ENVS="$n" \
    MAX_ITERATIONS="$max_iterations" \
    SEED="$seed" \
    EXPERIMENT_NAME="$experiment_name" \
    RUN_NAME="probe_n${n}" \
    HEADLESS=1 \
    bash scripts/run_phase_a_baseline.sh; then
    best="$n"
    printf '[OK ] NUM_ENVS=%s\n' "$n"
  else
    printf '[NG ] NUM_ENVS=%s\n' "$n" >&2
    break
  fi
done

if [ -z "$best" ]; then
  printf '\nRESULT: no candidate passed. Start from NUM_ENVS=128 and inspect logs.\n' >&2
  exit 1
fi

recommended=$(( best * 9 / 10 ))
if [ "$recommended" -lt 64 ]; then
  recommended="$best"
fi

printf '\nRESULT:\n'
printf '  best_passed       : %s\n' "$best"
printf '  recommended_train : %s (90%% of best)\n' "$recommended"
printf 'Use:\n'
printf '  NUM_ENVS=%s MAX_ITERATIONS=1500 RUN_NAME=long_n%s_i1500 bash scripts/run_phase_a_baseline.sh\n' "$recommended" "$recommended"
