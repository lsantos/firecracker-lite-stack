#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
FC_DIR="$ROOT/_fc"
IMG="$FC_DIR/custom-rootfs.ext4"
SIZE_MB=256
ALPINE_VER="3.20.2"
MINIROOT_URL="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-${ALPINE_VER}-x86_64.tar.gz"

mkdir -p "$FC_DIR" "$ROOT/bin"
rm -f "$IMG"

# Create empty ext4 image
truncate -s ${SIZE_MB}M "$IMG"
mkfs.ext4 -F "$IMG"

# Mount loop
MNT=$(mktemp -d)
sudo mount -o loop "$IMG" "$MNT"

# Bootstrap Alpine
curl -L "$MINIROOT_URL" | sudo tar -xz -C "$MNT"

# Copy app + configs
sudo mkdir -p "$MNT/app" "$MNT/etc/litefs" "$MNT/etc/litestream" /tmp/litebins
[[ -f "$ROOT/bin/demo-app" ]] || { echo "Build the app first: make build"; exit 1; }

sudo cp "$ROOT/bin/demo-app" "$MNT/usr/local/bin/"
# LiteFS (download latest static)
LITEFS_URL=$(curl -s https://api.github.com/repos/superfly/litefs/releases/latest | jq -r '.assets[] | select(.name | test("linux-amd64")) | .browser_download_url' | head -n1)
curl -L "$LITEFS_URL" -o /tmp/litebins/litefs.tgz
sudo tar -xzf /tmp/litebins/litefs.tgz -C /tmp/litebins
sudo mv /tmp/litebins/litefs "$MNT/usr/local/bin/"

# Optional: Litestream binary (DR only)
LS_URL=$(curl -s https://api.github.com/repos/benbjohnson/litestream/releases/latest | jq -r '.assets[] | select(.name | test("linux-amd64")) | .browser_download_url' | head -n1)
curl -L "$LS_URL" -o /tmp/litebins/litestream.tar.gz
sudo tar -xzf /tmp/litebins/litestream.tar.gz -C /tmp/litebins
if [[ -f /tmp/litebins/litestream ]]; then sudo mv /tmp/litebins/litestream "$MNT/usr/local/bin/"; fi

# Configs
sudo cp "$ROOT/litefs/litefs.yml" "$MNT/etc/litefs/litefs.yml"
if [[ -f "$ROOT/litestream/litestream.yml.example" ]]; then sudo cp "$ROOT/litestream/litestream.yml.example" "$MNT/etc/litestream/litestream.yml"; fi

# Minimal /init
cat <<'INIT' | sudo tee "$MNT/init" >/dev/null
#!/bin/sh
set -eux
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev || true

# ensure paths
mkdir -p /litefs /var/lib/litefs /app

# start LiteFS (optional: comment this block if using Litestream only)
if [ -x /usr/local/bin/litefs ] && [ -f /etc/litefs/litefs.yml ]; then
  /usr/local/bin/litefs mount -config /etc/litefs/litefs.yml &
  sleep 1
  export DB_PATH=/litefs/app.db
fi

# start Litestream replicate if configured (DR)
if [ -x /usr/local/bin/litestream ] && [ -f /etc/litestream/litestream.yml ]; then
  /usr/local/bin/litestream replicate -config /etc/litestream/litestream.yml &
fi

# start app
if [ -x /usr/local/bin/demo-app ]; then
  exec /usr/local/bin/demo-app
else
  exec sh
fi
INIT

sudo chmod +x "$MNT/init"

# Set /sbin/init symlink for kernels expecting it
sudo mkdir -p "$MNT/sbin"
sudo ln -sf /init "$MNT/sbin/init"

# Networking inside guest is left minimal; you can add /etc/network/interfaces or busybox ip config later.

# Cleanup
sudo umount "$MNT"
rmdir "$MNT"
echo "Built $IMG"