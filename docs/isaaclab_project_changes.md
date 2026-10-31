# Isaac Lab project changes

The `IsaacLab/` directory is based on the upstream Isaac Lab checkout. The following project-specific changes were made for this assignment:

- Added the `Isaac-Lift-Cube-Franka-Grasp-v0` task and its play variant.
- Added grasp/lift/place reward terms and task registration.
- Added the Phase B policy-demo collector and dataset conversion scripts.
- Added the robomimic BC configuration and replay path.
- Added project Docker configuration for the external `/mnt/ai_data` mount.
- Added CLI options used by the Phase A and Phase B runners.

The public submission includes the Isaac Lab source snapshot as ordinary files. The nested upstream Git metadata is excluded. Do not commit runtime output, checkpoints, HDF5 datasets, or Isaac Sim caches.
