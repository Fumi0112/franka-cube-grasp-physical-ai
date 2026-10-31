# Phase A Observation, Reward, and Action Notes

最終更新: 2026-06-07 (JST)

この文書は A3 の基準メモで、Phase A の policy が何を見て何を最適化しているかを固定する。

## Action Space

Total dimension: `8`

- `arm_action`: 7 DoF joint position control
- `gripper_action`: binary open/close command

Meaning:

- arm は位置制御で安定させる
- gripper は離散的に開閉する
- 低レベルトルク制御ではなく、上位の操作方針に集中する設計

## Observation Space

Policy observation dimension: `36`

- `joint_pos` : 9
- `joint_vel` : 9
- `object_position` : 3
- `target_object_position` : 7
- `actions` : 8

Interpretation:

- `joint_pos` / `joint_vel`
  - proprioception
  - 手先を安定して動かすための基本情報
- `object_position`
  - cube の位置を robot root frame で見る
  - grasp への接近を支える
- `target_object_position`
  - command target pose
  - lift 後の追従を学ぶための目標
- `actions`
  - 直前の操作の履歴
  - ガタつき抑制に少し効く

## Reward Terms

### Positive

- `reaching_object`
  - EE を cube に近づける
  - baseline の初動を作る
- `fingertips_to_object`
  - 指先 2 点を cube に寄せる
  - grasp 成立の前段を作る
- `gripper_closed`
  - 指を閉じる方向へ寄せる
  - cube に近い時の把持を後押しする
- `object_height_above_minimum`
  - lift threshold を超えた分だけ連続的に報酬を返す
  - `lifting_object` の sparse 信号を補強する
- `lifting_object`
  - cube が `0.04m` を超えて持ち上がると強く効く
  - grasp 成立の最初の分岐点
- `object_goal_tracking`
  - 持ち上げた後に target pose に近づく
  - lift-and-place 系に寄る
- `object_goal_tracking_fine_grained`
  - 同じ目的のより細かい形
  - 収束局面の精密化に効く

### Penalty

- `action_rate`
  - 急激な操作変化を罰する
  - 滑らかな制御を促す
- `joint_vel`
  - 過大な関節速度を罰する
  - 物理的に落ち着いた挙動を作る

## Curriculum

- `action_rate`: `-1e-4` から `-1e-1` へ
- `joint_vel`: `-1e-4` から `-1e-1` へ
- 切替スケール: `10000 steps`

Meaning:

- 学習初期は探索を止めすぎない
- 学習が進んだらガタつきを強く抑える

## Terminations

- `time_out`
- `object_dropping`

Meaning:

- 失敗し続ける軌道を長く引き延ばさない
- cube を落としたら即学習信号を整理できる

## Current Diagnosis

今の Phase A は以下の状態だった。

- 近づく挙動は出ている
- 乱れは少ない
- grasp 成立と保持を押す信号を追加した
- これで lift への到達率が上がるかを見ている

この状態は、A3 の観点ではむしろ有益で、reward と action のどこが効いているかを見やすい。

## What To Watch

- `Episode_Reward/lifting_object`
- `Episode_Reward/reaching_object`
- `Episode_Reward/action_rate`
- `Episode_Reward/joint_vel`
- `Episode_Termination/object_dropping`

## Next Implication

grasp 成立を強めたいなら、A4 で次のどれかを足す余地がある。

- contact / lift sustain の報酬
- reset range の見直し
- cube spawn と初期姿勢のばらつき調整

## A5 Domain Randomization (Current)

`Isaac-Lift-Cube-Franka-Grasp-v0` では次を追加済み。

- startup:
  - robot rigid-body material randomization
  - object rigid-body material randomization
- reset:
  - robot joint position randomization (`reset_joints_by_offset`)

意図:

- 摩擦・初期姿勢の軽いずれに対する頑健性を上げる
- ただし収束を壊さないようにレンジは中程度に固定
