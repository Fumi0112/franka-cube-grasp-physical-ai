#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
task_name="${TASK_NAME:-Isaac-Lift-Cube-Franka-Grasp-v0}"
num_envs="${NUM_ENVS:-128}"
max_iterations="${MAX_ITERATIONS:-50}"
seed="${SEED:-42}"
experiment_name="${EXPERIMENT_NAME:-franka_grasp_phase_a}"
run_name="${RUN_NAME:-baseline}"
logger="${LOGGER:-tensorboard}"
headless="${HEADLESS:-1}"
docker_tty="${DOCKER_TTY:-1}"
resume="${RESUME:-0}"
load_run="${LOAD_RUN:-}"
checkpoint="${CHECKPOINT:-}"

if ! docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
  printf 'ERROR: container %s is not running\n' "$container_name" >&2
  exit 1
fi

printf '== Phase A grasp PPO baseline ==\n'
printf 'container       : %s\n' "$container_name"
printf 'task            : %s\n' "$task_name"
printf 'num_envs        : %s\n' "$num_envs"
printf 'max_iterations   : %s\n' "$max_iterations"
printf 'seed            : %s\n' "$seed"
printf 'experiment_name : %s\n' "$experiment_name"
printf 'run_name        : %s\n' "$run_name"
printf 'headless        : %s\n' "$headless"
printf 'resume          : %s\n' "$resume"
printf 'load_run        : %s\n' "${load_run:-<none>}"
printf 'checkpoint      : %s\n' "${checkpoint:-<none>}"

train_args=(
  --task "$task_name"
  --num_envs "$num_envs"
  --seed "$seed"
  --max_iterations "$max_iterations"
  --experiment_name "$experiment_name"
  --run_name "$run_name"
  --logger "$logger"
)

if [ "$headless" != "0" ]; then
  train_args+=(--headless)
fi
if [ "$resume" = "1" ]; then
  train_args+=(--resume)
fi
if [ -n "$load_run" ]; then
  train_args+=(--load_run "$load_run")
fi
if [ -n "$checkpoint" ]; then
  train_args+=(--checkpoint "$checkpoint")
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
  -e DISPLAY="${DISPLAY:-}" \
  -e TERM="$term_value" \
  "$container_name" bash -c "
  cd '$workspace_dir' &&
  ./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py ${train_args[*]}
"
