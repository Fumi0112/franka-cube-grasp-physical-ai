#!/usr/bin/env bash
set -u

section() {
  printf '\n== %s ==\n' "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@"
  local status=$?
  if [ "$status" -ne 0 ]; then
    printf 'WARN: command failed with exit code %s\n' "$status"
  fi
  return 0
}

section "OS"
run lsb_release -a
run uname -a

section "User Groups"
run id
run groups
if groups | tr ' ' '\n' | grep -qx docker; then
  echo "OK: current shell has docker group membership"
else
  echo "WARN: current shell does not have docker group membership"
  echo "      log out/in or reboot, then re-run this script"
fi

section "NVIDIA Driver"
run nvidia-smi

section "CUDA Compiler"
run which nvcc
run nvcc --version

section "Docker"
run docker --version
run docker compose version
run docker info
if docker info 2>/dev/null | grep -q 'Runtimes:.*nvidia'; then
  echo "OK: Docker has the nvidia runtime registered"
else
  echo "WARN: Docker does not show the nvidia runtime"
  echo "      install NVIDIA Container Toolkit and run: sudo nvidia-ctk runtime configure --runtime=docker"
fi

section "NVIDIA Container Toolkit Packages"
run dpkg -l nvidia-container-toolkit nvidia-container-toolkit-base libnvidia-container1 libnvidia-container-tools

section "GPU Container Smoke Test"
run docker run --rm --runtime=nvidia --gpus all nvcr.io/nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
run docker run --rm --gpus all nvcr.io/nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi

section "AI Data Mount"
run findmnt /mnt/ai_data
run df -h /mnt/ai_data
run ls -ld /mnt/ai_data
if findmnt /mnt/ai_data >/dev/null 2>&1; then
  echo "OK: /mnt/ai_data is mounted"
else
  echo "WARN: /mnt/ai_data is not a mount point"
  echo "      large datasets/caches would currently land on the root filesystem"
fi

section "Expected Data Directories"
for dir in datasets checkpoints isaac_cache videos experiments; do
  path="/mnt/ai_data/${dir}"
  if [ -d "$path" ]; then
    printf 'OK: %s\n' "$path"
  else
    printf 'WARN: missing %s\n' "$path"
  fi
done
