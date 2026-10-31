# Host Setup Commands

Run these commands in a normal terminal. They require `sudo`, so Codex cannot reliably run them from the sandbox.

The shortest path is:

```bash
cd <project-root>
./scripts/install_host_prereqs.sh
./scripts/check_host_env.sh
```

The manual commands below are kept for inspection and troubleshooting.

## 0. If `apt-get update` Fails on Old PPAs

The host has previously shown these Ubuntu Noble-incompatible PPAs:

```text
/etc/apt/sources.list.d/aplattner-ubuntu-ppa-noble.sources
/etc/apt/sources.list.d/oguzhaninan-ubuntu-stacer-noble.sources
```

`scripts/install_host_prereqs.sh` disables them automatically by renaming each file to `.disabled`. Manual equivalent:

```bash
sudo mv /etc/apt/sources.list.d/aplattner-ubuntu-ppa-noble.sources \
  /etc/apt/sources.list.d/aplattner-ubuntu-ppa-noble.sources.disabled

sudo mv /etc/apt/sources.list.d/oguzhaninan-ubuntu-stacer-noble.sources \
  /etc/apt/sources.list.d/oguzhaninan-ubuntu-stacer-noble.sources.disabled
```

## 1. Install NVIDIA Container Toolkit

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Verify:

```bash
docker run --rm --runtime=nvidia --gpus all \
  nvcr.io/nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
```

## 2. Mount `/mnt/ai_data`

Current large NTFS candidate observed by `lsblk -f`:

```text
/dev/nvme1n1p2  ntfs  UUID=A0F46E72F46E4B1C
```

Prefer UUID over device path because NVMe numbering can change.

Create the mount point and test a manual mount:

```bash
sudo mkdir -p /mnt/ai_data
sudo mount -t ntfs3 -o uid=$(id -u),gid=$(id -g),umask=0022,windows_names UUID=A0F46E72F46E4B1C /mnt/ai_data
findmnt /mnt/ai_data
df -h /mnt/ai_data
```

If the mount fails because the NTFS volume is hibernated or dirty, fully shut down Windows and disable Fast Startup before trying again.

After the manual mount works, add this line to `/etc/fstab`:

```fstab
UUID=A0F46E72F46E4B1C /mnt/ai_data ntfs3 uid=1000,gid=1000,umask=0022,windows_names,nofail,x-systemd.automount 0 0
```

Apply and create data directories:

```bash
sudo systemctl daemon-reload
sudo mount -a
mkdir -p /mnt/ai_data/{datasets,checkpoints,isaac_cache,videos,experiments}
```

## 3. Re-run the Host Check

```bash
cd <project-root>
./scripts/check_host_env.sh
```
