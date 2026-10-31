#!/usr/bin/env bash
set -euo pipefail

num_envs="${NUM_ENVS:-576}"
max_iterations="${MAX_ITERATIONS:-1500}"
run_name="${RUN_NAME:-long_n${num_envs}_i${max_iterations}}"
experiment_name="${EXPERIMENT_NAME:-franka_lift_phase_a}"
log_path="${LOG_PATH:-/tmp/phase_a_long_${run_name}.log}"
pid_path="${PID_PATH:-/tmp/phase_a_long_${run_name}.pid}"

if [ -f "$pid_path" ]; then
  old_pid="$(cat "$pid_path" || true)"
  if [ -n "${old_pid:-}" ] && kill -0 "$old_pid" 2>/dev/null; then
    printf 'ERROR: job already running with PID=%s (pid file: %s)\n' "$old_pid" "$pid_path" >&2
    exit 1
  fi
fi

printf '== Start Phase A long training (background) ==\n'
printf 'num_envs        : %s\n' "$num_envs"
printf 'max_iterations  : %s\n' "$max_iterations"
printf 'experiment_name : %s\n' "$experiment_name"
printf 'run_name        : %s\n' "$run_name"
printf 'log_path        : %s\n' "$log_path"
printf 'pid_path        : %s\n' "$pid_path"

nohup env \
  NUM_ENVS="$num_envs" \
  MAX_ITERATIONS="$max_iterations" \
  EXPERIMENT_NAME="$experiment_name" \
  RUN_NAME="$run_name" \
  DOCKER_TTY=0 \
  HEADLESS=1 \
  bash scripts/run_phase_a_baseline.sh >"$log_path" 2>&1 &

pid="$!"
echo "$pid" >"$pid_path"

printf 'Started. PID=%s\n' "$pid"
printf 'Follow log: tail -f %s\n' "$log_path"
