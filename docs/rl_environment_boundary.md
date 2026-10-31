# RL Environment Boundary

最終更新: 2026-06-07 (JST)

この文書は、現在の環境を「強化学習用に一旦固定したスナップショット」として扱うための境界定義です。  
Phase B 以降は、この基盤を壊さずに上積みしていきます。

## Frozen Scope

- OS: Ubuntu 24.04
- GPU: RTX 4070 Ti SUPER 16GB
- Container runtime: Docker + NVIDIA Container Toolkit
- Simulator: Isaac Sim 5.1.x
- Learning framework: Isaac Lab 2.3.2 系
- RL: RSL-RL PPO
- Base task: `Isaac-Lift-Cube-Franka-v0`
- Custom fork task: `Isaac-Lift-Cube-Franka-Grasp-v0`
- Default execution: `HEADLESS=1`

## Stable Conventions

- 学習は headless を標準にする。
- GUI は確認用にだけ `HEADLESS=0` で使う。
- 実験は `experiment_name` と `run_name` で分離する。
- 継続学習は `resume` を使い、ゼロからの再実行と混ぜない。
- ログと成果物は `/mnt/ai_data` 配下に集約する。

## Confirmed Working Pieces

- Docker / NVIDIA Container Toolkit
- Isaac Lab container
- Franka lift PPO smoke test
- GUI replay path
- `NUM_ENVS` tuning up to 640 passes
- `NUM_ENVS=576` long-run preset
- resume path from existing checkpoints

## Current Learning State

- Phase A is in progress.
- The policy is already learning meaningful lift behavior.
- The current task is to push from "near grasp / lift hints" toward consistent grasp and lift success.

## Boundaries

- Do not mix Phase B/C/D work into Phase A baseline scripts.
- Keep new features behind separate scripts or tasks.
- If a change affects Phase A reproducibility, record it in `docs/SESSION_LOG.md` first.

## Entry Points

- `scripts/run_phase_a_baseline.sh`
- `scripts/run_phase_a_long.sh`
- `scripts/resume_phase_a_baseline.sh`
- `scripts/play_phase_a_baseline.sh`
- `scripts/tune_phase_a_num_envs.sh`

