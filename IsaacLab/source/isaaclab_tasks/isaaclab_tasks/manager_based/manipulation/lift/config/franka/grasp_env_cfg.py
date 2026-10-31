# Copyright (c) 2022-2026, The Isaac Lab Project Developers (https://github.com/isaac-sim/IsaacLab/blob/main/CONTRIBUTORS.md).
# All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

from isaaclab.managers import EventTermCfg as EventTerm
from isaaclab.managers import RewardTermCfg as RewTerm
from isaaclab.managers import SceneEntityCfg
from isaaclab.sensors import FrameTransformerCfg
from isaaclab.sensors.frame_transformer.frame_transformer_cfg import OffsetCfg
from isaaclab.utils import configclass

from isaaclab_tasks.manager_based.manipulation.lift import mdp
from . import joint_pos_env_cfg


@configclass
class FrankaCubeGraspEnvCfg(joint_pos_env_cfg.FrankaCubeLiftEnvCfg):
    def __post_init__(self):
        super().__post_init__()

        # Make the cube start in a slightly more reachable grasp corridor.
        self.events.reset_object_position.params["pose_range"] = {
            "x": (-0.12, 0.12),
            "y": (-0.18, 0.18),
            "z": (0.0, 0.0),
        }

        # Keep the initial object placement a bit closer to the hand than the lift baseline.
        self.scene.object.init_state.pos = [0.48, 0.0, 0.055]

        # Expose fingertip frames so grasp-specific shaping can be expressed without adding cameras.
        self.scene.ee_frame.target_frames.append(
            FrameTransformerCfg.FrameCfg(
                prim_path="{ENV_REGEX_NS}/Robot/panda_rightfinger",
                name="tool_rightfinger",
                offset=OffsetCfg(pos=(0.0, 0.0, 0.046)),
            )
        )
        self.scene.ee_frame.target_frames.append(
            FrameTransformerCfg.FrameCfg(
                prim_path="{ENV_REGEX_NS}/Robot/panda_leftfinger",
                name="tool_leftfinger",
                offset=OffsetCfg(pos=(0.0, 0.0, 0.046)),
            )
        )

        # Domain randomization (A5): keep ranges moderate to preserve stability.
        self.events.robot_physics_material = EventTerm(
            func=mdp.randomize_rigid_body_material,
            mode="startup",
            params={
                "asset_cfg": SceneEntityCfg("robot", body_names=".*"),
                "static_friction_range": (0.7, 1.3),
                "dynamic_friction_range": (0.6, 1.2),
                "restitution_range": (0.0, 0.05),
                "num_buckets": 16,
            },
        )
        self.events.object_physics_material = EventTerm(
            func=mdp.randomize_rigid_body_material,
            mode="startup",
            params={
                "asset_cfg": SceneEntityCfg("object", body_names="Object"),
                "static_friction_range": (0.6, 1.2),
                "dynamic_friction_range": (0.5, 1.1),
                "restitution_range": (0.0, 0.05),
                "num_buckets": 16,
            },
        )
        self.events.reset_robot_joints = EventTerm(
            func=mdp.reset_joints_by_offset,
            mode="reset",
            params={
                "position_range": (-0.03, 0.03),
                "velocity_range": (0.0, 0.0),
            },
        )

        # Reward shaping for grasp-first lifting.
        self.rewards.reaching_object.weight = 1.0
        self.rewards.fingertips_to_object = RewTerm(
            func=mdp.fingertips_to_object, params={"std": 0.06}, weight=2.0
        )
        self.rewards.gripper_closed = RewTerm(
            func=mdp.gripper_closed, params={"open_joint_pos": 0.04}, weight=0.5
        )
        self.rewards.object_height_above_minimum = RewTerm(
            func=mdp.object_height_above_minimum,
            params={"minimal_height": 0.04, "std": 0.03},
            weight=8.0,
        )
        self.rewards.lifting_object.weight = 10.0
        self.rewards.object_goal_tracking.weight = 2.0
        self.rewards.object_goal_tracking_fine_grained.weight = 0.5


@configclass
class FrankaCubeGraspEnvCfg_PLAY(FrankaCubeGraspEnvCfg):
    def __post_init__(self):
        super().__post_init__()
        self.scene.num_envs = 50
        self.scene.env_spacing = 2.5
        self.observations.policy.enable_corruption = False
        # Keep PLAY deterministic for debugging/replay.
        self.events.robot_physics_material = None
        self.events.object_physics_material = None
        self.events.reset_robot_joints = None
