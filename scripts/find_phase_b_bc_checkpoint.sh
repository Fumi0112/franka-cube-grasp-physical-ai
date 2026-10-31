#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
task_name="${TASK_NAME:-Isaac-Lift-Cube-Franka-Grasp-v0}"
run_name_filter="${RUN_NAME_FILTER:-}"
docker_tty="${DOCKER_TTY:-1}"

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container_name"; then
  printf 'ERROR: container %s is not running\n' "$container_name" >&2
  exit 1
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
  "$container_name" bash -lc "
    set -euo pipefail
    cd '$workspace_dir'
    base='logs/robomimic_phase_b/$task_name'
    if [ ! -d \"\$base\" ]; then exit 0; fi
    if [ -n '$run_name_filter' ]; then
      find \"\$base\" -type f -path \"*/${run_name_filter}/*/models/model_epoch_*.pth\" -printf '%T@ %p\n'
    else
      find \"\$base\" -type f -path '*/models/model_epoch_*.pth' -printf '%T@ %p\n'
    fi
  " | tr -d '\r' | sort -n | tail -n 1 | cut -d' ' -f2-
