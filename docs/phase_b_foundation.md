# Phase B Foundation

最終更新: 2026-06-13 (JST)

Phase B は `Diffusion imitation` の土台づくりです。  
ここでは、Phase A の RL 資産を壊さずに、まず `state-only` のデモ収集と学習ループを固定します。

## Decision

### 1. デモ収集方法

Phase B の最初は、`current grasp policy` を教師にした scripted / rollout ベースを優先します。

理由:

- Phase A で既に「つかめる」方針がある
- human teleop より再現性が高い
- camera を増やさずに low-dim で回せる
- まず BC と Diffusion Policy の学習管を通すことが先

teleop は後で比較用の追加経路にします。

### 2. 観測と行動

最初の schema は `state-only` に固定します。

Observation:

- `joint_pos`
- `joint_vel`
- `object_position`
- `target_object_position`

Action:

- 8D policy action
- `arm_action` 7D
- `gripper_action` 1D

### 3. Camera 方針

Phase B の初回は camera を入れません。

理由:

- render / throughput / storage が増える
- まず low-dim で imitation の学習経路を安定化したい
- camera branch は後から別実験系列で足せる

camera は BC が回るようになってから、別 branch として追加します。

## Existing Assets To Reuse

- Phase A grasp policy
- `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/config/franka/agents/robomimic/bc.json`
- `IsaacLab/scripts/tools/record_demos.py`
- `IsaacLab/scripts/tools/replay_demos.py`
- `IsaacLab/scripts/imitation_learning/robomimic/train.py`
- `IsaacLab/scripts/imitation_learning/robomimic/play.py`
- `IsaacLab/scripts/imitation_learning/isaaclab_mimic/*`

## Immediate Phase B Steps

1. B1: `scripted rollout` を主経路にしてデモ生成経路を作る
2. B2: dataset schema を low-dim で固定する
3. B3: 1 本のデモを HDF5 に出力して確認する
4. B4: dataset 保存と可視化を確認する
5. B5: BC baseline を回す
6. B6: Diffusion Policy に置き換える

## Practical Rule

Phase B では、迷ったら camera を増やすより先に state-only で通す。  
これは将来 camera を否定するものではなく、最初の成功率を上げるための順序です。

## First Collection Command

```bash
NUM_DEMOS=10 DATASET_FILE=/mnt/ai_data/datasets/phase_b/grasp_state_demos.hdf5 bash scripts/collect_phase_b_demos.sh
```

The wrapper sets `HDF5_USE_FILE_LOCKING=FALSE` because the dataset lives on `/mnt/ai_data`.

For a quick smoke test:

```bash
NUM_DEMOS=1 MAX_STEPS_PER_DEMO=300 bash scripts/collect_phase_b_demos.sh
```

## B2 Converter (collector -> robomimic)

collector 出力 (`obs: [T, 36]`) を robomimic 用の辞書形式へ変換する。

```bash
bash scripts/convert_phase_b_dataset.sh
```

既定入出力:

- input: `/mnt/ai_data/datasets/phase_b/grasp_state_demos.hdf5`
- output: `/mnt/ai_data/datasets/phase_b/grasp_state_demos_robomimic.hdf5`

変換後は以下を含む:

- `data/demo_i/obs/{joint_pos,joint_vel,object_position,target_object_position}`
- `data/demo_i/next_obs/...`
- `actions`, `rewards`, `dones`
- `mask/train`, `mask/valid`

## B5 BC Baseline Command

```bash
EPOCHS=200 RUN_NAME=phase_b_bc_grasp bash scripts/train_phase_b_bc.sh
```

短時間確認:

```bash
EPOCHS=1 RUN_NAME=phase_b_bc_smoke bash scripts/train_phase_b_bc.sh
```

## BC Policy Play

```bash
CHECKPOINT=/workspace/isaaclab/logs/robomimic_phase_b/Isaac-Lift-Cube-Franka-Grasp-v0/<run>/<timestamp>/models/model_epoch_200.pth \
HEADLESS=0 NUM_ROLLOUTS=3 HORIZON=500 \
bash scripts/play_phase_b_bc.sh
```

Latest checkpoint auto-discovery:

```bash
RUN_NAME_FILTER=phase_b_bc_grasp_v3 HEADLESS=1 bash scripts/play_phase_b_bc.sh
```
