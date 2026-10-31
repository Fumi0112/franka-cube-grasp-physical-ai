#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
experiment_name="${EXPERIMENT_NAME:-franka_lift_phase_a}"
run_name_filter="${RUN_NAME_FILTER:-}"
docker_tty="${DOCKER_TTY:-1}"
host_log_root="${HOST_LOG_ROOT:-/mnt/ai_data/experiments/isaac-lab-logs}"

find_latest_checkpoint() {
  local base_dir="$1"
  local filter="$2"
  if [ ! -d "$base_dir" ]; then
    return 0
  fi
  if [ -n "$filter" ]; then
    find "$base_dir" -maxdepth 2 -type f -name 'model_*.pt' | grep '/[^/]*_'"$filter"'/'
  else
    find "$base_dir" -maxdepth 2 -type f -name 'model_*.pt'
  fi
}

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container_name"; then
  find_latest_checkpoint "$host_log_root/rsl_rl/$experiment_name" "$run_name_filter" | sort -V | tail -n 1
  exit 0
fi

docker_exec_args=()
if [ "$docker_tty" = "1" ]; then
  docker_exec_args+=(-t)
  if [ -t 0 ] && [ -t 1 ]; then
    docker_exec_args+=(-i)
  fi
fi

term_value="${TERM:-}"
if [ -z "$term_value" ] || [ "$term_value" = "dumb" ]; then
  term_value="xterm-256color"
fi

docker exec "${docker_exec_args[@]}" \
  -e TERM="$term_value" \
  "$container_name" bash -c "
    set -euo pipefail
    cd '$workspace_dir'
    base='logs/rsl_rl/$experiment_name'
    if [ ! -d \"\$base\" ]; then exit 0; fi
    if [ -n '$run_name_filter' ]; then find \"\$base\" -maxdepth 2 -type f -name 'model_*.pt' | grep '/[^/]*_${run_name_filter}/'
    else find \"\$base\" -maxdepth 2 -type f -name 'model_*.pt'; fi
  " | tr -d '\r' | sort -V | tail -n 1
