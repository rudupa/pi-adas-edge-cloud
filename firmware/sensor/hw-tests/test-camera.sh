#!/bin/bash
# Hardware smoke test: camera device
set -euo pipefail

[ -e /dev/video0 ] || { echo "FAIL: camera device /dev/video0 not found"; exit 1; }

lsmod | grep -q bcm2835 || modprobe bcm2835_mmal 2>/dev/null || true

# Attempt a single-frame capture to confirm the device is readable
v4l2-ctl --device=/dev/video0 --stream-mmap --stream-count=1 \
    --stream-to=/tmp/camera-test.raw 2>/dev/null \
    && echo "PASS: camera capture succeeded" \
    || { echo "FAIL: camera capture failed"; exit 1; }
