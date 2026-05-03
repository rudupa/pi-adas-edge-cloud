#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-dev}"
OUTPUT="${2:-images}"
NODE="ui"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ROOTFS="${REPO_ROOT}/build/${NODE}/output/images/rootfs.tar.gz"
KERNEL="${REPO_ROOT}/build/${NODE}/output/images/zImage"

if [ ! -f "${ROOTFS}" ] || [ ! -f "${KERNEL}" ]; then
    echo "ERROR: Build artifacts missing; run 'make -C build/buildroot-src O=../ui/output ui_defconfig && make -C build/buildroot-src O=../ui/output' first" >&2
    exit 1
fi

mkdir -p "${OUTPUT}"

SIZE_MB=640
IMG="${OUTPUT}/${NODE}-linux-${VERSION}.img"

echo "Creating ${SIZE_MB} MB disk image: ${IMG}"
dd if=/dev/zero of="${IMG}" bs=1M count=0 seek=${SIZE_MB}

parted -s "${IMG}" mklabel msdos
parted -s "${IMG}" mkpart primary fat32 1MiB 128MiB
parted -s "${IMG}" mkpart primary ext4  128MiB 100%

cat <<'NOTE'
Image skeleton created. To populate partitions:
  1. sudo losetup -P /dev/loopX <IMG>
  2. sudo mkfs.vfat /dev/loopXp1 -n BOOT
  3. sudo mkfs.ext4 /dev/loopXp2 -L ROOT
  4. Mount and copy: boot files → p1, rootfs.tar.gz → p2
  5. sudo losetup -d /dev/loopX
NOTE

echo "Image assembled: ${IMG}"
