#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Start from base defconfig
cp "${REPO_ROOT}/build/common/buildroot.defconfig" "${SCRIPT_DIR}/buildroot.config"

# Append sensor-specific overrides
cat >> "${SCRIPT_DIR}/buildroot.config" << 'EOF'

# --- Sensor-specific overrides ---
BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="../sensor/kernel.config"
BR2_PACKAGE_FFMPEG=y
BR2_PACKAGE_FFMPEG_ENCODERS="libx264 libopus"
BR2_PACKAGE_LIBOPUS=y
BR2_TARGET_ROOTFS_SIZE=128
BR2_ROOTFS_OVERLAY="../../sensor/overlay"
EOF

echo "Generated build/sensor/buildroot.config"
