# SESSION LOG (Codex Handover)

最終更新: 2026-06-13 (JST)

このファイルは「次の Codex が 1 分で状況把握する」ための引き継ぎログです。  
以後、状態変更があったらこのファイルに追記します。

## 運用ルール

1. 変更・実行・検証をしたら、同日に 1 エントリ追記する。
2. 1 エントリは `Date / What / Evidence / Next` の 4 行で簡潔に書く。
3. 実験ログや成果物は絶対パスで残す。
4. 迷ったら `docs/setup_plan.md` より先にこのファイルを更新する。

## Current Snapshot

- 目標フェーズ: `Phase B (Diffusion imitation)` の設計と土台作成
- 現在の環境: `RL workspace` は凍結済み、学習資産は `/mnt/ai_data` に隔離
- 現在の作業焦点: `A5` の成果を確定し、`B1 + B2` に進む
- 基本運用: headless (`HEADLESS=1`, デフォルト)
- GUI確認: 必要時だけ `HEADLESS=0`
- ベースタスク: `Isaac-Lift-Cube-Franka-v0`
- カスタムタスク: `Isaac-Lift-Cube-Franka-Grasp-v0`
- コンテナ: `isaac-lab-base`

## Latest Commands

- headless baseline:
  - `bash scripts/run_phase_a_baseline.sh`
- GUI quick check:
  - `HEADLESS=0 NUM_ENVS=1 MAX_ITERATIONS=5 bash scripts/run_phase_a_baseline.sh`
- grasp baseline:
  - `bash scripts/run_phase_a_grasp_baseline.sh`
- grasp long training:
  - `bash scripts/run_phase_a_long.sh`
- grasp resume:
  - `bash scripts/resume_phase_a_grasp.sh`
- environment boundary:
  - `docs/rl_environment_boundary.md`
- experiment management:
  - `docs/phase_a_experiment_management.md`
- obs/reward/action notes:
  - `docs/phase_a_observation_reward_action.md`

## Timeline

### 2026-06-07 / Entry 01

- What:
  - Docker + NVIDIA Container Toolkit + Isaac Lab 基盤を整備。
  - Phase 0（環境構築）相当は完了扱い。
- Evidence:
  - `docs/setup_plan.md`
  - `docs/isaaclab_docker.md`
- Next:
  - Phase A1 baseline を再現可能な形で運用継続。

### 2026-06-07 / Entry 02

- What:
  - `experiment_name` が RSL-RL CLI に流れない問題を修正し、run 系列を分離可能にした。
  - A4 用に `Isaac-Lift-Cube-Franka-Grasp-v0` を追加（Lift の最小fork）。
- Evidence:
  - `IsaacLab/scripts/reinforcement_learning/rsl_rl/cli_args.py`
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/config/franka/grasp_env_cfg.py`
- Next:
  - grasp 側 PPO baseline の反復実行。

### 2026-06-07 / Entry 03

- What:
  - `scripts/run_phase_a_baseline.sh` / `scripts/run_phase_a_grasp_baseline.sh` に
    `HEADLESS` 切替を実装（デフォルト headless）。
  - GUI で確認可能なように X11 経路を有効化済み。
- Evidence:
  - `IsaacLab/docker/.container.cfg` (`x11_forwarding_enabled = 1`)
  - `scripts/run_phase_a_baseline.sh`
  - `scripts/run_phase_a_grasp_baseline.sh`
- Next:
  - 通常は headless で学習を進め、必要時だけ GUI 実行。

### 2026-06-07 / Entry 04

- What:
  - GUI実行時に `tabs: terminal type 'dumb'` で停止する問題を解消。
  - run スクリプトで `docker exec` 時の `TERM` を補正（`dumb` 回避）し、TTY 前提を整備。
  - `HEADLESS=0 NUM_ENVS=1 MAX_ITERATIONS=1` で起動〜学習1iteration完了を確認。
- Evidence:
  - 実行ログに `Creating window for environment.` と `Learning iteration 0/1`
  - `scripts/run_phase_a_baseline.sh` (TERM補正)
- Next:
  - A1 を headless 本実行へ移行（反復 run / メトリクス比較）。

### 2026-06-07 / Entry 05

- What:
  - headless学習とGUI確認を分離するため、再生ラッパーを追加。
  - `scripts/play_phase_a_baseline.sh` は最新 checkpoint を自動探索して `play.py` を実行可能。
- Evidence:
  - `scripts/play_phase_a_baseline.sh`
  - `docs/setup_plan.md` (GUI再生コマンド追記)
- Next:
  - A1学習は headless 継続、要所で GUI replay で挙動確認。

### 2026-06-07 / Entry 06

- What:
  - 1ジョブ並列を攻めるため `NUM_ENVS` チューナーを追加。
  - 長時間学習プリセット `run_phase_a_long.sh` を追加（既定 1500 iter）。
- Evidence:
  - `scripts/tune_phase_a_num_envs.sh`
  - `scripts/run_phase_a_long.sh`
  - `docs/setup_plan.md` 更新
- Next:
  - `tune_phase_a_num_envs.sh` 実行後、推奨 `NUM_ENVS` で long run を回す。

### 2026-06-07 / Entry 07

- What:
  - `tune_phase_a_num_envs.sh` を実行し、`NUM_ENVS=640` まで通過を確認。
  - 安全側推奨を `NUM_ENVS=576` (bestの90%) に確定。
  - `NUM_ENVS=576` で 1-iteration 前景実行が正常完了することを確認。
- Evidence:
  - tuning結果: `best_passed: 640`, `recommended_train: 576`
  - 前景確認 run: `RUN_NAME=probe_n576_fg`
- Next:
  - 本学習: `NUM_ENVS=576 MAX_ITERATIONS=1500 RUN_NAME=long_n576_i1500`
  - GUI確認: `RUN_NAME_FILTER=long_n576_i1500` 指定で再生。

### 2026-06-07 / Entry 08

- What:
  - 既存checkpointからの追加学習を行うため、resumeフローを実装。
  - `run_phase_a_baseline.sh` に `RESUME/LOAD_RUN/CHECKPOINT` を追加。
  - `find_phase_a_checkpoint.sh` と `resume_phase_a_baseline.sh` を新規追加。
- Evidence:
  - `scripts/run_phase_a_baseline.sh`
  - `scripts/find_phase_a_checkpoint.sh`
  - `scripts/resume_phase_a_baseline.sh`
  - 検出例: `.../2026-06-07_19-14-56_long_n576_i1500/model_950.pt`
- Next:
  - `MAX_ITERATIONS=1000` 単位でresumeを繰り返し、GUI replayで成功率を確認。

### 2026-06-07 / Entry 09

- What:
  - 現在の環境を RL 用に固定した境界文書を追加。
  - Phase B/C/D を Phase A の基盤の上に積む運用方針を明文化。
- Evidence:
  - `docs/rl_environment_boundary.md`
- Next:
  - Phase A の継続学習を進めつつ、Phase B の設計に入る前にこの境界を崩さない。

### 2026-06-07 / Entry 10

- What:
  - A2 のための実験管理文書を追加。
  - A3 のための observation / reward / action 分解メモを追加。
- Evidence:
  - `docs/phase_a_experiment_management.md`
  - `docs/phase_a_observation_reward_action.md`
- Next:
  - A2/A3 を基準に、今後の run を比較可能な形で記録する。

### 2026-06-07 / Entry 11

- What:
  - A4 を前に進めるため、grasp fork に指先接近・gripper閉鎖・連続 lift 報酬を追加。
  - cube reset を少し grasp 寄りに調整し、初期配置も手前に寄せた。
- Evidence:
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/config/franka/grasp_env_cfg.py`
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/mdp/rewards.py`
  - コンテナ内 `py_compile` 検証通過
- Next:
  - grasp PPO を再学習して、lift 成立率と保持安定性を確認する。

### 2026-06-07 / Entry 12

- What:
  - grasp long-run 用の起動スクリプトを追加し、lift と同じ運用パターンで回せるようにした。
- Evidence:
  - `scripts/run_phase_a_grasp_long.sh`
- Next:
  - `NUM_ENVS=576 MAX_ITERATIONS=1500 EXPERIMENT_NAME=franka_grasp_phase_a RUN_NAME=grasp_long_n576_i1500 bash scripts/run_phase_a_grasp_long.sh`

### 2026-06-07 / Entry 13

- What:
  - grasp fork の reward 定義で `mdp.RewTerm` を誤参照していた不具合を修正。
  - これにより grasp long-run 起動時の即時終了を解消。
- Evidence:
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/config/franka/grasp_env_cfg.py`
  - コンテナ内 `py_compile` 検証通過
- Next:
  - grasp long-run を再実行して学習継続を確認する。

### 2026-06-13 / Entry 14

- What:
  - `franka_grasp_phase_a / grasp_long_n576_i18000` が完走。
  - 最終 checkpoint は `model_17999.pt`。
- Evidence:
  - `logs/rsl_rl/franka_grasp_phase_a/2026-06-07_23-02-43_grasp_long_n576_i18000/model_17999.pt`
  - `params/agent.yaml` の `max_iterations: 18000`
- Next:
  - GUI replay で最終方針を確認し、Phase A の最終整理へ進む。

### 2026-06-13 / Entry 15

- What:
  - A5 を開始し、grasp task に domain randomization を導入。
  - 対象は robot/object の material randomization（startup）と robot joint reset randomization（reset）。
  - `smoke_a5` で 1-iteration 起動確認済み。
- Evidence:
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/config/franka/grasp_env_cfg.py`
  - Event Manager に startup/reset randomization terms が表示されることを確認
- Next:
  - `franka_grasp_phase_a_dr` で中時間学習を回し、DR無し run と成功率/安定性を比較する。

### 2026-06-13 / Entry 16

- What:
  - `find_phase_a_checkpoint.sh` を改善し、`isaac-lab-base` 停止中でも host 側ログから最新 checkpoint を探索できるようにした。
  - checkpoint 探索時の並び順を `sort -V` に変更し、`model_950.pt` / `model_17999.pt` などの番号比較が自然順で正しくなるようにした。
- Evidence:
  - `scripts/find_phase_a_checkpoint.sh`
  - `docs/phase_a_experiment_management.md`
- Next:
  - `franka_grasp_phase_a_dr / grasp_dr_n576_i3000` の最新 checkpoint を確認し、GUI replay とメトリクス比較へ進む。

### 2026-06-13 / Entry 17

- What:
  - grasp 用の継続学習スクリプト `scripts/resume_phase_a_grasp.sh` を追加。
  - 既存 checkpoint の自動検出 (`find_phase_a_checkpoint.sh`) と `--resume --load_run --checkpoint` 連携を一本化。
- Evidence:
  - `scripts/resume_phase_a_grasp.sh`
  - `docs/phase_a_experiment_management.md`
- Next:
  - `MAX_ITERATIONS=20000` の overnight 継続学習を実施し、翌日 GUI replay とメトリクス比較。

### 2026-06-13 / Entry 18

- What:
  - `franka_grasp_phase_a_dr` の継続学習を完了し、grasp 挙動は「つかめるがまだ荒削り」から次段階へ進める状態になった。
  - Phase A の学習資産を `RL workspace` から切り離し、以後は記録済み checkpoint と `/mnt/ai_data` を基準に扱う方針へ切り替えた。
- Evidence:
  - `scripts/resume_phase_a_grasp.sh`
  - `scripts/find_phase_a_checkpoint.sh`
  - `docs/phase_a_experiment_management.md`
- Next:
  - Phase B の入口を決めるため、デモ収集方法と observation/action schema を先に固定する。

### 2026-06-13 / Entry 19

- What:
  - Phase B の土台文書 `docs/phase_b_foundation.md` を追加し、`state-only` 先行・camera 後段の方針を固定した。
  - 既存の `robomimic` low-dim 設定と `record_demos.py` / `replay_demos.py` を再利用する前提を明文化し、B1 は scripted rollout を主経路に固定した。
- Evidence:
  - `docs/phase_b_foundation.md`
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/config/franka/agents/robomimic/bc.json`
  - `IsaacLab/scripts/tools/record_demos.py`
- Next:
  - B1 の最初の実装として、grasp policy からのデモ出力経路を HDF5 に落とす。

### 2026-06-14 / Entry 20

- What:
  - Phase B の最初の実装として、grasp policy から成功 rollout を HDF5 に書き出す `scripts/imitation_learning/phase_b/collect_policy_demos.py` を追加した。
  - 併せて host 側の起動ラッパー `scripts/collect_phase_b_demos.sh` を追加し、checkpoint 自動検出からデモ収集までを一段で回せる形にした。
- Evidence:
  - `IsaacLab/scripts/imitation_learning/phase_b/collect_policy_demos.py`
  - `scripts/collect_phase_b_demos.sh`
  - `docs/phase_b_foundation.md`
- Next:
  - 実機起動前に `bash -n` と最初の短時間収集で、dataset が `/mnt/ai_data` に生成されることを確認する。

### 2026-06-14 / Entry 21

- What:
  - `collect_policy_demos.py` の `cli_args` import 経路を修正し、`scripts.reinforcement_learning.rsl_rl` を参照するようにした。
  - これで Phase B demo collection が Isaac Lab の既存 RSL-RL helper と同じ流れで起動できるようになった。
- Evidence:
  - `IsaacLab/scripts/imitation_learning/phase_b/collect_policy_demos.py`
- Next:
  - `NUM_DEMOS=1` で再実行し、`/mnt/ai_data/datasets/phase_b/grasp_state_demos.hdf5` が生成されることを確認する。

### 2026-06-14 / Entry 22

- What:
  - Phase B demo collection の smoke test が通り、`grasp_state_demos.hdf5` を生成できた。
  - HDF5 の file locking 問題に対して `HDF5_USE_FILE_LOCKING=FALSE` を収集ラッパーへ追加した。
- Evidence:
  - `/mnt/ai_data/datasets/phase_b/grasp_state_demos.hdf5`
  - `scripts/collect_phase_b_demos.sh`
- Next:
  - B2: dataset schema を low-dim で固定し、BC baseline にそのまま渡せる形に整える。

### 2026-06-14 / Entry 23

- What:
  - B2 対応として `collect_policy_demos.py` 出力を robomimic 形式へ変換するスクリプトを追加した。
  - `scripts/convert_phase_b_dataset.sh` を追加し、host から一段で変換実行できるようにした。
  - 変換後 HDF5 が `obs/next_obs/actions/rewards/dones/mask` を持つことを確認した。
- Evidence:
  - `IsaacLab/scripts/imitation_learning/phase_b/convert_policy_demos_to_robomimic.py`
  - `scripts/convert_phase_b_dataset.sh`
  - `/mnt/ai_data/datasets/phase_b/grasp_state_demos_robomimic.hdf5`
- Next:
  - B5 に向けて BC 学習ラッパーを追加し、smoke 学習を通す。

### 2026-06-14 / Entry 24

- What:
  - `Isaac-Lift-Cube-Franka-Grasp-v0` に `robomimic_bc_cfg_entry_point` を追加した。
  - grasp 用 BC 設定 `bc_grasp_phase_b.json` を追加し、`validate=false` / `filter_key=null` の少量データ向け設定にした。
  - `scripts/train_phase_b_bc.sh` を追加し、`robomimic/train.py` の実行導線を固定した。
  - `batch_size=100` だと 1 demo (39 samples) で `StopIteration` になるため `batch_size=32` に調整した。
  - `EPOCHS=1` の BC smoke 学習が成功し、`model_epoch_1.pth` を保存できることを確認した。
- Evidence:
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/config/franka/__init__.py`
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/config/franka/agents/robomimic/bc_grasp_phase_b.json`
  - `scripts/train_phase_b_bc.sh`
  - `/workspace/isaaclab/logs/robomimic_phase_b/Isaac-Lift-Cube-Franka-Grasp-v0/phase_b_bc_smoke_20260614_2/20260614190922/models/model_epoch_1.pth`
- Next:
  - BC replay を通し、run が end-to-end で実行できることを確認する。

### 2026-06-14 / Entry 25

- What:
  - `robomimic/play.py` は success termination が無い環境で落ちるため、`success` が未定義なら成功判定をスキップする互換修正を入れた。
  - `scripts/play_phase_b_bc.sh` を追加し、BC checkpoint の再生を簡単にした。
  - `HEADLESS=1 NUM_ROLLOUTS=1` で replay が最後まで動くことを確認した（成功率 0.0 は 1 epoch smoke 相当として妥当）。
- Evidence:
  - `IsaacLab/scripts/imitation_learning/robomimic/play.py`
  - `scripts/play_phase_b_bc.sh`
- Next:
  - 実運用は `NUM_DEMOS>=50` で再収集し、`EPOCHS=200` 以上の BC 本学習を実行する。

### 2026-06-14 / Entry 26

- What:
  - `play_phase_b_bc.sh` を修正し、`HEADLESS=0` 時に `DISPLAY` / `XAUTHORITY` を `docker exec` へ渡すようにした。
  - Phase B デモ収集を `EXPORT_SUCCEEDED_ONLY` に戻し、`max_steps_per_demo` 到達時は成功時のみ export するように変更した。
  - これにより失敗デモ混入を抑え、BC 学習データの品質を改善した。
- Evidence:
  - `scripts/play_phase_b_bc.sh`
  - `IsaacLab/scripts/imitation_learning/phase_b/collect_policy_demos.py`
- Next:
  - 成功のみデモを再収集 (`NUM_DEMOS=100`) して再変換・再学習し、BC replay の成功率を再評価する。

### 2026-06-14 / Entry 27

- What:
  - GUI replay 失敗 (`Authorization required`, `GLFW initialization failed`) に対し、`play_phase_b_bc.sh` の GUI 実行時に container 内 `XAUTHORITY` を空にするよう修正した。
  - host 側の `xhost` 許可を使う前提に揃え、未マウントの host Xauthority パスを渡して失敗する経路を除去した。
- Evidence:
  - `scripts/play_phase_b_bc.sh`
- Next:
  - `xhost +SI:localuser:root` を実行後、`HEADLESS=0` replay を再確認する。

### 2026-06-14 / Entry 28

- What:
  - `robomimic/play.py` に fallback success 判定を追加した。
  - grasp のように `success` termination が無い環境でも、`object_height > 0.04` を一定ステップ維持したら成功扱いにする。
  - `scripts/play_phase_b_bc.sh` から `SUCCESS_HEIGHT` / `SUCCESS_HOLD_STEPS` を調整できるようにした。
- Evidence:
  - `IsaacLab/scripts/imitation_learning/robomimic/play.py`
  - `scripts/play_phase_b_bc.sh`
- Next:
  - 同じ checkpoint を headless で再評価し、成功判定が意味を持つか確認する。

### 2026-06-20 / Entry 29

- What:
  - Phase B のデモ収集条件を外から調整できるようにし、`SUCCESS_HEIGHT` / `SUCCESS_HOLD_STEPS` を host wrapper から渡せるようにした。
  - これで teacher policy が小さめの lift を作れた時でも、デモ収集の入り口を広げられるようにした。
- Evidence:
  - `IsaacLab/scripts/imitation_learning/phase_b/collect_policy_demos.py`
  - `scripts/collect_phase_b_demos.sh`
- Next:
  - 成功デモを増やして dataset を再生成し、BC を再学習する。

### 2026-06-20 / Entry 30

- What:
  - `grasp_state_demos.hdf5` を 30 デモまで追加収集した。
  - 既存の robomimic 変換ファイルを再生成し、`num_demos=30 / total_samples=939` の dataset へ更新した。
  - その dataset で BC を再学習し、`phase_b_bc_grasp_v3` を保存した。
  - 収集時と同じく高さベースの fallback success 判定で再評価し、`2/20` 成功まで改善した。
- Evidence:
  - `/mnt/ai_data/datasets/phase_b/grasp_state_demos.hdf5`
  - `/mnt/ai_data/datasets/phase_b/grasp_state_demos_robomimic.hdf5`
  - `/workspace/isaaclab/logs/robomimic_phase_b/Isaac-Lift-Cube-Franka-Grasp-v0/phase_b_bc_grasp_v3/20260620120840/models/model_epoch_200.pth`
- Next:
  - さらに成功率を上げるなら、追加デモ収集か Diffusion Policy へ進む判断をする。

### 2026-06-20 / Entry 31

- What:
  - Phase B BC の最新 checkpoint を自動探索する `scripts/find_phase_b_bc_checkpoint.sh` を追加した。
  - `scripts/play_phase_b_bc.sh` が `CHECKPOINT` 未指定でも最新 Phase B BC checkpoint を拾って再生できるようにした。
  - `docs/phase_b_foundation.md` と `docs/setup_plan.md` に最新 replay の導線を追記した。
- Evidence:
  - `scripts/find_phase_b_bc_checkpoint.sh`
  - `scripts/play_phase_b_bc.sh`
  - `docs/phase_b_foundation.md`
  - `docs/setup_plan.md`
- Next:
  - 以後は `RUN_NAME_FILTER=phase_b_bc_grasp_v3 HEADLESS=1 bash scripts/play_phase_b_bc.sh` で簡易再評価できる。

### 2026-06-20 / Entry 32

- What:
  - `phase_b_bc_grasp_v3` を fallback success 条件で 20 rollouts 再評価したが、厳密な成功率は `0/20` だった。
  - つまり、30デモ再学習で挙動は改善したものの、まだ安定成功には届いていない。
- Evidence:
  - `scripts/play_phase_b_bc.sh`
  - `IsaacLab/scripts/imitation_learning/robomimic/play.py`
- Next:
  - `SUCCESS_HEIGHT` を少し下げるか、デモ本数をさらに増やして `v4` を作る。

### 2026-06-20 / Entry 33

- What:
  - `grasp_state_demos_v2.hdf5` として 50 demos を追加収集し、`grasp_state_demos_v2_robomimic.hdf5` (1560 samples) に変換した。
  - `phase_b_bc_grasp_v4` を 200 epoch 学習し、`model_epoch_200.pth` を保存した。
  - v4 を評価した結果:
    - 緩め条件 (`SUCCESS_HEIGHT=0.03`, `SUCCESS_HOLD_STEPS=5`): `1/20`
    - 厳しめ条件 (`0.04`, `10`): `0/20`
  - v3 の緩め条件 `2/20` と比較して改善は見られず、BC 単体では安定成功が難しい状況を再確認。
- Evidence:
  - `/mnt/ai_data/datasets/phase_b/grasp_state_demos_v2.hdf5`
  - `/mnt/ai_data/datasets/phase_b/grasp_state_demos_v2_robomimic.hdf5`
  - `/workspace/isaaclab/logs/robomimic_phase_b/Isaac-Lift-Cube-Franka-Grasp-v0/phase_b_bc_grasp_v4/20260620143149/models/model_epoch_200.pth`
- Next:
  - Phase B の次段として Diffusion Policy 学習（B6）へ進み、BC を超える成功率を狙う。

### 2026-10-31 / Entry 34

- What:
  - 最終課題提出に向けた到達度評価文書を追加し、課題要件に対して現状を整理した。
  - 提出直前の漏れを防ぐチェックリストを追加した。
- Evidence:
  - `docs/final_assignment_readiness_2026-10-31.md`
  - `docs/final_submission_checklist_2026-11-02.md`
- Next:
  - RL 本線の最終動画撮影と、PDF/README の提出物整備を優先する。

### 2026-10-31 / Entry 35

- What:
  - プロジェクトの目的、Franka Panda cube grasp/lift のタスク設定、RL/BC/Diffusion の役割、現在の到達点を1文書に整理した。
  - `setup_plan.md` から参照できるようにした。
- Evidence:
  - `docs/project_purpose_and_task.md`
  - `docs/setup_plan.md`
- Next:
  - この文書を最終課題レポートの概要・目的・工夫点の下書きとして利用する。

### 2026-10-31 / Entry 36

- What:
  - タスク表記を「cubeを一定高さまで持ち上げる」から「cubeを把持して持ち上げ、目標位置へ運ぶ lift-and-place 系タスク」へ修正した。
  - 現行報酬はcubeの位置距離を評価し、cube自身の回転姿勢は直接評価していないことも明記した。
- Evidence:
  - `docs/project_purpose_and_task.md`
  - `IsaacLab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/lift/mdp/rewards.py`
- Next:
  - 最終課題の動画・レポートでは、現行成果を「把持・持ち上げ・目標位置への運搬」と説明する。

## Open Work (Priority)

1. B3/B4: デモ本数を増やした dataset の再生成と品質確認
2. B5: BC 本学習 (200 epoch+) と checkpoint 選定
3. B6: Diffusion Policy 学習導線の追加
4. B7: Isaac Lab 上で policy rollout 比較 (RL vs BC vs Diffusion)
