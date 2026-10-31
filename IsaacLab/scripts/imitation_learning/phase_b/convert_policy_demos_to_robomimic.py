#!/usr/bin/env python3

"""Convert Phase B policy demos into a robomimic-compatible HDF5 layout."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import h5py
import numpy as np


JOINT_POS_DIM = 9
JOINT_VEL_DIM = 9
OBJECT_POS_DIM = 3
TARGET_OBJECT_POS_DIM = 7
REQUIRED_OBS_DIM = JOINT_POS_DIM + JOINT_VEL_DIM + OBJECT_POS_DIM + TARGET_OBJECT_POS_DIM


def _copy_attributes(src_obj: h5py.Group | h5py.Dataset, dst_obj: h5py.Group | h5py.Dataset) -> None:
    for key, value in src_obj.attrs.items():
        dst_obj.attrs[key] = value


def _safe_string_array(values: list[str]) -> np.ndarray:
    return np.array(values, dtype="S")


def _split_obs(flat_obs: np.ndarray) -> dict[str, np.ndarray]:
    if flat_obs.ndim != 2:
        raise ValueError(f"Expected 2D obs array, got shape={flat_obs.shape}")
    if flat_obs.shape[1] < REQUIRED_OBS_DIM:
        raise ValueError(
            f"Observation dim is too small: got {flat_obs.shape[1]}, required at least {REQUIRED_OBS_DIM}"
        )
    return {
        "joint_pos": flat_obs[:, 0:JOINT_POS_DIM],
        "joint_vel": flat_obs[:, JOINT_POS_DIM : JOINT_POS_DIM + JOINT_VEL_DIM],
        "object_position": flat_obs[:, JOINT_POS_DIM + JOINT_VEL_DIM : JOINT_POS_DIM + JOINT_VEL_DIM + OBJECT_POS_DIM],
        "target_object_position": flat_obs[
            :,
            JOINT_POS_DIM
            + JOINT_VEL_DIM
            + OBJECT_POS_DIM : JOINT_POS_DIM
            + JOINT_VEL_DIM
            + OBJECT_POS_DIM
            + TARGET_OBJECT_POS_DIM,
        ],
    }


def _create_next_obs(obs_dict: dict[str, np.ndarray]) -> dict[str, np.ndarray]:
    next_obs = {}
    for key, value in obs_dict.items():
        shifted = np.zeros_like(value)
        shifted[:-1] = value[1:]
        shifted[-1] = value[-1]
        next_obs[key] = shifted
    return next_obs


def convert(input_path: Path, output_path: Path, train_ratio: float) -> dict[str, int]:
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with h5py.File(input_path, "r") as src, h5py.File(output_path, "w") as dst:
        _copy_attributes(src, dst)
        src_data = src["data"]
        dst_data = dst.create_group("data")
        _copy_attributes(src_data, dst_data)

        demo_keys = sorted(src_data.keys())
        if not demo_keys:
            raise RuntimeError("No demos found under '/data' in source HDF5.")

        total_samples = 0
        copied_demos: list[str] = []
        for key in demo_keys:
            src_demo = src_data[key]
            if "obs" not in src_demo or "actions" not in src_demo:
                continue

            flat_obs = np.asarray(src_demo["obs"], dtype=np.float32)
            actions = np.asarray(src_demo["actions"], dtype=np.float32)
            if flat_obs.shape[0] != actions.shape[0]:
                raise ValueError(f"Length mismatch in {key}: obs={flat_obs.shape[0]}, actions={actions.shape[0]}")
            if flat_obs.shape[0] < 2:
                continue

            obs_dict = _split_obs(flat_obs)
            next_obs_dict = _create_next_obs(obs_dict)

            steps = actions.shape[0]
            rewards = np.zeros((steps,), dtype=np.float32)
            dones = np.zeros((steps,), dtype=np.bool_)
            dones[-1] = True

            dst_demo = dst_data.create_group(key)
            _copy_attributes(src_demo, dst_demo)
            dst_demo.attrs["num_samples"] = steps

            dst_demo.create_dataset("actions", data=actions, compression="gzip")
            dst_demo.create_dataset("rewards", data=rewards, compression="gzip")
            dst_demo.create_dataset("dones", data=dones, compression="gzip")

            dst_obs = dst_demo.create_group("obs")
            dst_next_obs = dst_demo.create_group("next_obs")
            for obs_key, obs_value in obs_dict.items():
                dst_obs.create_dataset(obs_key, data=obs_value, compression="gzip")
                dst_next_obs.create_dataset(obs_key, data=next_obs_dict[obs_key], compression="gzip")

            total_samples += steps
            copied_demos.append(key)

        if not copied_demos:
            raise RuntimeError("No valid demos copied. Check source dataset content.")

        dst_data.attrs["total"] = total_samples

        # Optional masks for compatibility with existing robomimic tooling.
        n_train = int(round(len(copied_demos) * train_ratio))
        n_train = max(1, min(n_train, len(copied_demos)))
        train_keys = copied_demos[:n_train]
        valid_keys = copied_demos[n_train:]
        if not valid_keys and len(copied_demos) > 1:
            valid_keys = [copied_demos[-1]]
            train_keys = copied_demos[:-1]

        mask = dst.create_group("mask")
        mask.create_dataset("train", data=_safe_string_array(train_keys))
        mask.create_dataset("valid", data=_safe_string_array(valid_keys))

        summary = {
            "source": str(input_path),
            "output": str(output_path),
            "num_demos": len(copied_demos),
            "train_demos": len(train_keys),
            "valid_demos": len(valid_keys),
            "total_samples": int(total_samples),
        }
        dst.attrs["phase_b_converter_summary"] = json.dumps(summary)
        return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert policy rollout demos to robomimic schema.")
    parser.add_argument("--input", required=True, type=Path, help="Input HDF5 from collect_policy_demos.py")
    parser.add_argument("--output", required=True, type=Path, help="Output HDF5 path for robomimic training")
    parser.add_argument(
        "--train_ratio",
        type=float,
        default=0.9,
        help="Fraction of demos assigned to mask/train. Remaining go to mask/valid.",
    )
    args = parser.parse_args()

    if not (0.0 < args.train_ratio <= 1.0):
        raise ValueError(f"--train_ratio must be in (0, 1], got {args.train_ratio}")

    summary = convert(args.input, args.output, args.train_ratio)
    print(json.dumps(summary, indent=2, ensure_ascii=True))


if __name__ == "__main__":
    main()
