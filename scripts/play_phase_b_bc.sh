#!/usr/bin/env bash
set -euo pipefail

container_name="${CONTAINER_NAME:-isaac-lab-base}"
workspace_dir="${WORKSPACE_DIR:-/workspace/isaaclab}"
task_name="${TASK_NAME:-Isaac-Lift-Cube-Franka-Grasp-Play-v0}"
checkpoint="${CHECKPOINT:-}"
run_name_filter="${RUN_NAME_FILTER:-}"
num_rollouts="${NUM_ROLLOUTS:-3}"
horizon="${HORIZON:-500}"
headless="${HEADLESS:-0}"
success_height="${SUCCESS_HEIGHT:-0.04}"
success_hold_steps="${SUCCESS_HOLD_STEPS:-10}"

if ! docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
  printf 'ERROR: container %s is not running\n' "$container_name" >&2
  exit 1
fi

if [ -z "$checkpoint" ]; then
  checkpoint="$(
    DOCKER_TTY=0 CONTAINER_NAME="$container_name" WORKSPACE_DIR="$workspace_dir" \
      TASK_NAME="${TASK_NAME:-Isaac-Lift-Cube-Franka-Grasp-v0}" RUN_NAME_FILTER="$run_name_filter" \
      bash scripts/find_phase_b_bc_checkpoint.sh 2>/dev/null || true
  )"
fi

if [ -z "$checkpoint" ]; then
  printf 'ERROR: CHECKPOINT is required and no latest Phase B BC checkpoint was found.\n' >&2
  printf 'example: CHECKPOINT=/workspace/isaaclab/logs/robomimic_phase_b/Isaac-Lift-Cube-Franka-Grasp-v0/<run>/<timestamp>/models/model_epoch_200.pth bash scripts/play_phase_b_bc.sh\n' >&2
  exit 1
fi

printf '== Phase B BC play ==\n'
printf 'task         : %s\n' "$task_name"
printf 'run_filter   : %s\n' "${run_name_filter:-<none>}"
printf 'checkpoint   : %s\n' "$checkpoint"
printf 'num_rollouts : %s\n' "$num_rollouts"
printf 'horizon      : %s\n' "$horizon"
printf 'headless     : %s\n' "$headless"
printf 'success_hgt  : %s\n' "$success_height"
printf 'success_hold : %s\n' "$success_hold_steps"

headless_arg=""
if [ "$headless" = "1" ]; then
  headless_arg="--headless"
fi

if [ "$headless" = "0" ]; then
  if [ -z "${DISPLAY:-}" ]; then
    printf 'ERROR: HEADLESS=0 requires DISPLAY to be set.\n' >&2
    exit 1
  fi
  if [ ! -S /tmp/.X11-unix/X0 ]; then
    printf 'WARNING: /tmp/.X11-unix/X0 not found. X11 forwarding may fail.\n' >&2
  fi
fi

docker_exec_args=(-t)
if [ "$headless" = "0" ]; then
  docker_exec_args+=(-e "DISPLAY=${DISPLAY:-}")
  # Use xhost-based local access control for GUI mode.
  # Host XAUTHORITY paths (e.g. /run/user/1000/gdm/Xauthority) are often not mounted in the container.
  docker_exec_args+=(-e "XAUTHORITY=")
fi

docker exec "${docker_exec_args[@]}" "$container_name" bash -lc "
  cd '$workspace_dir' &&
  ./isaaclab.sh -p scripts/imitation_learning/robomimic/play.py \
    --task '$task_name' \
    --checkpoint '$checkpoint' \
    --num_rollouts '$num_rollouts' \
    --horizon '$horizon' \
    --success_height '$success_height' \
    --success_hold_steps '$success_hold_steps' \
    $headless_arg
"
