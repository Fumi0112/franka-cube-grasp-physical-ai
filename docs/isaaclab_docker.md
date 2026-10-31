# Isaac Lab Docker Workflow

## Selected Version

- Isaac Lab: `v2.3.2`
- Isaac Sim container: `5.1.0`
- Reason: Isaac Lab 3.0 is currently beta and built on Isaac Sim 6.0, while the initial Franka grasp roadmap benefits from the stable Isaac Sim 5.1 / Isaac Lab 2.3 line.

## Storage Override

Use `IsaacLab/docker/docker-compose.ai-data.yaml` with every `container.py` command that creates or starts the container. It redirects Isaac Sim/Lab persistent Docker volumes to `/mnt/ai_data`.
It also binds `/tmp/isaaclab` to `/mnt/ai_data/experiments/isaaclab-tmp` so Isaac Lab runtime logs do not disappear with container-local `/tmp`.

```bash
cd <project-root>/IsaacLab
./docker/container.py start --files docker-compose.ai-data.yaml
./docker/container.py enter --files docker-compose.ai-data.yaml
```

For ROS 2 later:

```bash
./docker/container.py start ros2 --files docker-compose.ai-data.yaml
./docker/container.py enter ros2 --files docker-compose.ai-data.yaml
```

## Local Dockerfile Patch

`IsaacLab/docker/Dockerfile.base` includes one local compatibility patch before `./isaaclab.sh --install`: pre-install `flatdict==4.0.1` with `--no-build-isolation --no-deps`. Without this, the legacy `flatdict` setup can fail because `pkg_resources` is not available inside pip's isolated build environment, leaving `isaaclab` itself uninstalled even though later extensions continue.

## First Validation Commands

Inside the container:

```bash
python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
./isaaclab.sh --help
./isaaclab.sh -p scripts/list_envs.py
```

Then choose the closest built-in Franka manipulation task before creating the custom cube grasp task.

## X11

X11 forwarding is initially disabled in `IsaacLab/docker/.container.cfg`. Start with headless validation and training. Enable X11 later only when an interactive Isaac Sim viewport is needed.
