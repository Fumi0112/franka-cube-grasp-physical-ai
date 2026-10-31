# Phase A Experiment Management

最終更新: 2026-06-07 (JST)

Phase A の実験は、学習の中身と結果を切り分けて追えることを優先する。
この文書は A2 の運用ルールの基準にする。

## Goal

- 同じ設定の再実行ができること
- 何が良くなったかを checkpoint と動画で比較できること
- 実験の系統が混ざらないこと

## Directory Convention

ランは Isaac Lab の既定ログ構造に従う。

```text
logs/rsl_rl/<experiment_name>/<timestamp>_<run_name>/
```

代表例:

```text
logs/rsl_rl/franka_lift_phase_a/2026-06-07_19-14-56_long_n576_i1500/
```

中身の標準構成:

```text
params/
  env.yaml
  agent.yaml
model_*.pt
exported/
  policy.pt
  policy.onnx
```

動画を有効にした run では `videos/` も追加される。

## Naming Rules

- `experiment_name`
  - 実験ファミリーを表す
  - 例: `franka_lift_phase_a`, `franka_grasp_phase_a`, `franka_lift_phase_a_tune`
- `run_name`
  - 同じ experiment の中での枝分かれを表す
  - 例: `baseline`, `long_n576_i1500`, `resume_2026-06-07_19-14-56_long_n576_i1500`

## Current Families

- `franka_lift_phase_a`
  - 標準の lift baseline
- `franka_lift_phase_a_tune`
  - `NUM_ENVS` 上限探索用
- `franka_grasp_phase_a`
  - grasp 寄りの fork baseline
- `franka_grasp_phase_a_dr`
  - grasp + domain randomization 検証用

## Run Workflow

1. まず headless で学習する
2. まとまった iteration ごとに checkpoint を確認する
3. GUI は replay だけに使う
4. `resume` は同じ experiment family の継続として扱う

## Recommended Comparison Metrics

- `Episode_Reward/lifting_object`
- `Episode_Reward/object_goal_tracking`
- `Episode_Reward/action_rate`
- `Episode_Reward/joint_vel`
- `Metrics/object_pose/position_error`
- `Metrics/object_pose/orientation_error`
- `Episode_Termination/object_dropping`
- `Mean episode length`

## Practical Commands

Run training:

```bash
NUM_ENVS=576 MAX_ITERATIONS=1500 RUN_NAME=long_n576_i1500 bash scripts/run_phase_a_baseline.sh
```

Resume from the latest checkpoint in a family:

```bash
RUN_NAME_FILTER=long_n576_i1500 MAX_ITERATIONS=1000 NUM_ENVS=576 bash scripts/resume_phase_a_baseline.sh
```

Resume grasp run from latest checkpoint (long continuation):

```bash
EXPERIMENT_NAME=franka_grasp_phase_a_dr RUN_NAME_FILTER=grasp_dr_n576_i3000 NUM_ENVS=576 MAX_ITERATIONS=20000 bash scripts/resume_phase_a_grasp.sh
```

Find latest checkpoint (works even when container is stopped):

```bash
EXPERIMENT_NAME=franka_grasp_phase_a_dr RUN_NAME_FILTER=grasp_dr_n576_i3000 bash scripts/find_phase_a_checkpoint.sh
```

Run grasp with domain randomization (A5):

```bash
NUM_ENVS=576 MAX_ITERATIONS=3000 EXPERIMENT_NAME=franka_grasp_phase_a_dr RUN_NAME=grasp_dr_n576_i3000 bash scripts/run_phase_a_grasp_long.sh
```

Replay with GUI:

```bash
HEADLESS=0 NUM_ENVS=1 RUN_NAME_FILTER=long_n576_i1500 bash scripts/play_phase_a_baseline.sh
```

## Notes

- If a new change affects run naming or checkpoint discovery, update this document first.
- Keep Phase B/C/D in separate experiment families.
