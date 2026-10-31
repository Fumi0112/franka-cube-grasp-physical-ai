# Copyright (c) 2024-2026, The Isaac Lab Project Developers (https://github.com/isaac-sim/IsaacLab/blob/main/CONTRIBUTORS.md).
# All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

"""Collect successful policy rollouts as HDF5 demonstrations for Phase B imitation learning."""

"""Launch Isaac Sim Simulator first."""

import argparse
import os
import time

from isaaclab.app import AppLauncher

import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))

# local imports
from scripts.reinforcement_learning.rsl_rl import cli_args  # isort: skip

# add argparse arguments
parser = argparse.ArgumentParser(description="Collect successful policy rollouts as demonstrations.")
parser.add_argument("--task", type=str, default=None, help="Name of the task.")
parser.add_argument("--agent", type=str, default="rsl_rl_cfg_entry_point", help="RL agent config entry point.")
parser.add_argument("--num_envs", type=int, default=1, help="Number of environments to simulate.")
parser.add_argument("--seed", type=int, default=None, help="Seed used for the environment")
parser.add_argument(
    "--use_pretrained_checkpoint",
    action="store_true",
    default=False,
    help="Use the pre-trained checkpoint from Nucleus.",
)
parser.add_argument(
    "--num_demos",
    type=int,
    default=10,
    help="Number of successful demonstrations to collect.",
)
parser.add_argument(
    "--num_success_steps",
    type=int,
    default=10,
    help="Number of continuous successful steps before a demo is exported.",
)
parser.add_argument(
    "--success_height",
    type=float,
    default=0.04,
    help="Object height threshold used to determine success during demo collection.",
)
parser.add_argument(
    "--dataset_file",
    type=str,
    default="./datasets/phase_b_demos.hdf5",
    help="Path to the output HDF5 dataset.",
)
parser.add_argument(
    "--max_steps_per_demo",
    type=int,
    default=2000,
    help="Safety cap for a single rollout before resetting the environment.",
)
parser.add_argument("--real-time", action="store_true", default=False, help="Run in real-time, if possible.")
# append RSL-RL cli arguments
cli_args.add_rsl_rl_args(parser)
# append AppLauncher cli args
AppLauncher.add_app_launcher_args(parser)
args_cli, hydra_args = parser.parse_known_args()

# clear out sys.argv for Hydra
sys.argv = [sys.argv[0]] + hydra_args

# launch omniverse app
app_launcher = AppLauncher(args_cli)
simulation_app = app_launcher.app

"""Rest everything follows."""

import gymnasium as gym
import torch
from rsl_rl.runners import DistillationRunner, OnPolicyRunner

from isaaclab.envs import DirectMARLEnv, DirectMARLEnvCfg, DirectRLEnvCfg, ManagerBasedRLEnvCfg, multi_agent_to_single_agent
from isaaclab.envs.mdp.recorders.recorders_cfg import ActionStateRecorderManagerCfg
from isaaclab.managers import DatasetExportMode
from isaaclab.utils.datasets import HDF5DatasetFileHandler

from isaaclab_rl.rsl_rl import RslRlBaseRunnerCfg, RslRlVecEnvWrapper
from isaaclab_rl.utils.pretrained_checkpoint import get_published_pretrained_checkpoint
from isaaclab.utils.assets import retrieve_file_path

import isaaclab_tasks  # noqa: F401
from isaaclab_tasks.utils import get_checkpoint_path
from isaaclab_tasks.utils.hydra import hydra_task_config


@hydra_task_config(args_cli.task, args_cli.agent)
def main(env_cfg: ManagerBasedRLEnvCfg | DirectRLEnvCfg | DirectMARLEnvCfg, agent_cfg: RslRlBaseRunnerCfg):
    """Collect policy rollouts and export successful episodes as demonstrations."""
    task_name = args_cli.task.split(":")[-1]
    train_task_name = task_name.replace("-Play", "")

    agent_cfg = cli_args.update_rsl_rl_cfg(agent_cfg, args_cli)
    env_cfg.scene.num_envs = args_cli.num_envs if args_cli.num_envs is not None else env_cfg.scene.num_envs
    env_cfg.seed = agent_cfg.seed
    env_cfg.sim.device = args_cli.device if args_cli.device is not None else env_cfg.sim.device

    log_root_path = os.path.abspath(os.path.join("logs", "rsl_rl", agent_cfg.experiment_name))
    if args_cli.use_pretrained_checkpoint:
        resume_path = get_published_pretrained_checkpoint("rsl_rl", train_task_name)
        if not resume_path:
            raise FileNotFoundError(f"No published pretrained checkpoint available for {train_task_name}")
    elif args_cli.checkpoint:
        resume_path = retrieve_file_path(args_cli.checkpoint)
    else:
        resume_path = get_checkpoint_path(log_root_path, agent_cfg.load_run, agent_cfg.load_checkpoint)

    log_dir = os.path.dirname(resume_path)
    env_cfg.log_dir = log_dir

    output_dir = os.path.dirname(args_cli.dataset_file)
    output_file_name = os.path.splitext(os.path.basename(args_cli.dataset_file))[0]
    os.makedirs(output_dir, exist_ok=True)

    env_cfg.recorders = ActionStateRecorderManagerCfg()
    env_cfg.recorders.dataset_export_dir_path = output_dir
    env_cfg.recorders.dataset_filename = output_file_name
    env_cfg.recorders.dataset_export_mode = DatasetExportMode.EXPORT_SUCCEEDED_ONLY
    env_cfg.terminations.time_out = None

    raw_env = gym.make(args_cli.task, cfg=env_cfg)
    if isinstance(raw_env.unwrapped, DirectMARLEnv):
        raw_env = multi_agent_to_single_agent(raw_env)

    with torch.inference_mode(False):
        raw_env.unwrapped.sim.reset()
        raw_env.unwrapped.recorder_manager.reset()
        raw_env.reset()

    class NoResetRslRlVecEnvWrapper(RslRlVecEnvWrapper):
        def __init__(self, env, clip_actions=None):
            self.env = env
            self.clip_actions = clip_actions
            self.num_envs = self.unwrapped.num_envs
            self.device = self.unwrapped.device
            self.max_episode_length = self.unwrapped.max_episode_length
            if hasattr(self.unwrapped, "action_manager"):
                self.num_actions = self.unwrapped.action_manager.total_action_dim
            else:
                self.num_actions = gym.spaces.flatdim(self.unwrapped.single_action_space)
            self._modify_action_space()

        def reset(self):
            raise NotImplementedError("Reset is disabled for Phase B demo collection.")

    env = NoResetRslRlVecEnvWrapper(raw_env, clip_actions=agent_cfg.clip_actions)

    if agent_cfg.class_name == "OnPolicyRunner":
        runner = OnPolicyRunner(env, agent_cfg.to_dict(), log_dir=None, device=agent_cfg.device)
    elif agent_cfg.class_name == "DistillationRunner":
        runner = DistillationRunner(env, agent_cfg.to_dict(), log_dir=None, device=agent_cfg.device)
    else:
        raise ValueError(f"Unsupported runner class: {agent_cfg.class_name}")
    runner.load(resume_path)
    policy = runner.get_inference_policy(device=env.unwrapped.device)

    try:
        policy_nn = runner.alg.policy
    except AttributeError:
        policy_nn = runner.alg.actor_critic
    if hasattr(policy_nn, "actor_obs_normalizer"):
        normalizer = policy_nn.actor_obs_normalizer
    elif hasattr(policy_nn, "student_obs_normalizer"):
        normalizer = policy_nn.student_obs_normalizer
    else:
        normalizer = None

    # Save the policy artifacts beside the source checkpoint for traceability.
    export_model_dir = os.path.join(os.path.dirname(resume_path), "exported")
    from isaaclab_rl.rsl_rl import export_policy_as_jit, export_policy_as_onnx

    export_policy_as_jit(policy_nn, normalizer=normalizer, path=export_model_dir, filename="policy.pt")
    export_policy_as_onnx(policy_nn, normalizer=normalizer, path=export_model_dir, filename="policy.onnx")
    success_height = args_cli.success_height
    collected_demos = 0
    success_step_count = 0
    rollout_steps = 0
    start_time = time.time()

    while simulation_app.is_running() and collected_demos < args_cli.num_demos:
        obs = env.get_observations()
        with torch.inference_mode():
            actions = policy(obs)
        _, _, dones, _ = env.step(actions)
        rollout_steps += 1
        object_height = float(raw_env.unwrapped.scene["object"].data.root_pos_w[0, 2])
        if object_height > success_height:
            success_step_count += 1
            if success_step_count >= args_cli.num_success_steps:
                raw_env.unwrapped.recorder_manager.record_pre_reset([0], force_export_or_skip=False)
                raw_env.unwrapped.recorder_manager.set_success_to_episodes(
                    [0], torch.tensor([[True]], dtype=torch.bool, device=raw_env.unwrapped.device)
                )
                raw_env.unwrapped.recorder_manager.export_episodes([0])
                collected_demos += 1
                success_step_count = 0
                raw_env.unwrapped.sim.reset()
                raw_env.unwrapped.recorder_manager.reset()
                raw_env.reset()
        else:
            success_step_count = 0
        if bool(dones.any()):
            raw_env.unwrapped.recorder_manager.reset()

        if rollout_steps >= args_cli.max_steps_per_demo and collected_demos < args_cli.num_demos:
            is_success = object_height > success_height
            if is_success:
                raw_env.unwrapped.recorder_manager.record_pre_reset([0], force_export_or_skip=False)
                raw_env.unwrapped.recorder_manager.set_success_to_episodes(
                    [0], torch.tensor([[True]], dtype=torch.bool, device=raw_env.unwrapped.device)
                )
                raw_env.unwrapped.recorder_manager.export_episodes([0])
                collected_demos += 1
            raw_env.unwrapped.sim.reset()
            raw_env.unwrapped.recorder_manager.reset()
            raw_env.reset()
            rollout_steps = 0
            success_step_count = 0

        if args_cli.real_time:
            dt = raw_env.unwrapped.step_dt
            sleep_time = dt - (time.time() - start_time)
            if sleep_time > 0:
                time.sleep(sleep_time)
            start_time = time.time()

    raw_env.close()


if __name__ == "__main__":
    main()
    simulation_app.close()
