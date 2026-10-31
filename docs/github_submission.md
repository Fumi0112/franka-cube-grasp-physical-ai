# GitHub submission policy

This repository contains the project-specific scripts, task configuration, documentation, and experiment procedure for the final assignment.

## Excluded from the public repository

- Isaac Sim caches and generated runtime output
- PPO/BC checkpoints, datasets, and videos
- Docker volumes and host-specific mount contents
- Personal credentials, tokens, and local editor metadata

The public repository includes the Isaac Lab source tree used for this project. The nested upstream Git metadata is excluded; the source snapshot and the project-specific modifications are submitted as ordinary files.

## Reproduction assumptions

- Ubuntu 24.04
- NVIDIA GPU with a working driver and Container Toolkit
- Isaac Sim / Isaac Lab versions recorded in `README.md`
- Docker container named `isaac-lab-base`
- External data mount at `/mnt/ai_data`

Use the commands in `README.md` after adapting the project root and data mount to the local machine.
