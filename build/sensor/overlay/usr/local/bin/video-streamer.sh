#!/usr/bin/env bash
set -euo pipefail

GATEWAY_IP="${GATEWAY_IP:-192.168.4.1}"
GATEWAY_PORT="${GATEWAY_PORT:-5000}"

exec gst-launch-1.0 -e \
    v4l2src device=/dev/video0 \
        ! "video/x-h264, width=640, height=480, framerate=30/1" \
        ! h264parse \
        ! rtph264pay pt=96 \
        ! udpsink host="${GATEWAY_IP}" port="${GATEWAY_PORT}" auto-multicast=false
