#!/usr/bin/env bash
set -euo pipefail

AI_DATA_UUID="${AI_DATA_UUID:-A0F46E72F46E4B1C}"
AI_DATA_MOUNT="${AI_DATA_MOUNT:-/mnt/ai_data}"
AI_DATA_FSTAB_OPTIONS="${AI_DATA_FSTAB_OPTIONS:-uid=1000,gid=1000,umask=0022,windows_names,nofail,x-systemd.automount}"

section() {
  printf '\n== %s ==\n' "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

section "Preflight"
require_cmd curl
require_cmd gpg
require_cmd sudo
require_cmd docker
require_cmd findmnt
require_cmd lsblk

echo "This script will:"
echo "  - disable known broken Ubuntu Noble PPAs if present"
echo "  - install/configure NVIDIA Container Toolkit"
echo "  - restart Docker"
echo "  - mount UUID=${AI_DATA_UUID} at ${AI_DATA_MOUNT}"
echo "  - add an /etc/fstab entry if one does not already exist"
echo
read -r -p "Continue? [y/N] " answer
case "$answer" in
  y|Y|yes|YES) ;;
  *) echo "Aborted."; exit 0 ;;
esac

section "Disable Broken Apt Sources"
for source_file in \
  /etc/apt/sources.list.d/aplattner-ubuntu-ppa-noble.sources \
  /etc/apt/sources.list.d/oguzhaninan-ubuntu-stacer-noble.sources
do
  if [ -f "$source_file" ]; then
    disabled_file="${source_file}.disabled"
    echo "Disabling unsupported Noble PPA: $source_file"
    sudo mv "$source_file" "$disabled_file"
  fi
done

section "NVIDIA Container Toolkit"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

section "AI Data Mount"
if ! lsblk -f | grep -q "$AI_DATA_UUID"; then
  echo "ERROR: UUID=${AI_DATA_UUID} was not found by lsblk." >&2
  echo "Check the target NTFS volume before editing fstab." >&2
  exit 1
fi

sudo mkdir -p "$AI_DATA_MOUNT"

if ! findmnt "$AI_DATA_MOUNT" >/dev/null 2>&1; then
  sudo mount -t ntfs3 -o "uid=$(id -u),gid=$(id -g),umask=0022,windows_names" "UUID=${AI_DATA_UUID}" "$AI_DATA_MOUNT"
fi

fstab_line="UUID=${AI_DATA_UUID} ${AI_DATA_MOUNT} ntfs3 ${AI_DATA_FSTAB_OPTIONS} 0 0"
if ! grep -Eq "^[^#]*UUID=${AI_DATA_UUID}[[:space:]]+${AI_DATA_MOUNT}[[:space:]]" /etc/fstab; then
  printf '%s\n' "$fstab_line" | sudo tee -a /etc/fstab >/dev/null
fi

sudo systemctl daemon-reload
sudo mount -a
mkdir -p \
  "$AI_DATA_MOUNT/datasets" \
  "$AI_DATA_MOUNT/checkpoints" \
  "$AI_DATA_MOUNT/isaac_cache" \
  "$AI_DATA_MOUNT/videos" \
  "$AI_DATA_MOUNT/experiments"

section "Verification"
docker info | grep -E 'Runtimes|Default Runtime'
docker run --rm --runtime=nvidia --gpus all nvcr.io/nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
findmnt "$AI_DATA_MOUNT"
df -h "$AI_DATA_MOUNT"

echo
echo "Done. Now run: ./scripts/check_host_env.sh"
