#!/usr/bin/env bash
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)/bin"
FC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)/_fc"

if [[ ! -x "$BIN/firecracker" ]]; then
  echo "Firecracker binary not found. Run: make fetch"; exit 1
fi

cat > vmconfig.json <<'JSON'
{
  "boot-source": {
    "kernel_image_path": "_fc/vmlinux.bin",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": [
    { "drive_id": "rootfs", "path_on_host": "_fc/rootfs.ext4", "is_root_device": true, "is_read_only": false }
  ],
  "machine-config": { "vcpu_count": 1, "mem_size_mib": 256 }
}
JSON

"$BIN/firecracker" --no-api --config-file vmconfig.json