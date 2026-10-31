#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
task_name="${TASK_NAME:-Isaac-Lift-Cube-Franka-v0}"
experiment_name="${EXPERIMENT_NAME:-franka_lift_phase_a}"
run_name_filter="${RUN_NAME_FILTER:-}"
num_envs="${NUM_ENVS:-1}"
headless="${HEADLESS:-1}"
checkpoint_path="${CHECKPOINT:-}"
real_time="${REAL_TIME:-1}"
docker_tty="${DOCKER_TTY:-1}"

if ! docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
  printf 'ERROR: container %s is not running\n' "$container_name" >&2
  exit 1
fi

printf '== Phase A PPO play ==\n'
printf 'container       : %s\n' "$container_name"
printf 'task            : %s\n' "$task_name"
printf 'experiment_name : %s\n' "$experiment_name"
printf 'run_name_filter : %s\n' "${run_name_filter:-<none>}"
printf 'num_envs        : %s\n' "$num_envs"
printf 'headless        : %s\n' "$headless"

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

if [ -z "$checkpoint_path" ]; then
  checkpoint_path="$(docker exec "${docker_exec_args[@]}" \
    -e TERM="$term_value" \
    "$container_name" bash -c "
      set -euo pipefail
      cd '$workspace_dir'
      base='logs/rsl_rl/$experiment_name'
      if [ ! -d \"\$base\" ]; then
        exit 0
      fi
      if [ -n '$run_name_filter' ]; then
        find \"\$base\" -maxdepth 2 -type f -name 'model_*.pt' | grep '/[^/]*_${run_name_filter}/' | sort | tail -n 1
      else
        find \"\$base\" -maxdepth 2 -type f -name 'model_*.pt' | sort | tail -n 1
      fi
    " | tr -d '\r')"
fi

if [ -z "$checkpoint_path" ]; then
  printf 'ERROR: checkpoint not found. Set CHECKPOINT=/abs/path/to/model_x.pt or train first.\n' >&2
  exit 1
fi

printf 'checkpoint      : %s\n' "$checkpoint_path"

play_args=(
  --task "$task_name"
  --num_envs "$num_envs"
  --experiment_name "$experiment_name"
  --checkpoint "$checkpoint_path"
)

if [ "$headless" != "0" ]; then
  play_args+=(--headless)
fi

if [ "$real_time" = "1" ]; then
  play_args+=(--real-time)
fi

docker exec "${docker_exec_args[@]}" \
  -e DISPLAY="${DISPLAY:-}" \
  -e TERM="$term_value" \
  "$container_name" bash -c "
  cd '$workspace_dir' &&
  ./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/play.py ${play_args[*]}
"
