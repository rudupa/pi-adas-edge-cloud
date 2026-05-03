#!/usr/bin/env bash
set -euo pipefail

# Probe V4L2 camera device and verify driver is loaded
if [ ! -e /dev/video0 ]; then
    echo "ERROR: /dev/video0 not found; camera not detected" >&2
    exit 1
fi

# Try to load kernel module if not loaded
lsmod | grep -q bcm2835_mmal || modprobe bcm2835-v4l2 2>/dev/null || true

echo "Camera detected: /dev/video0"
