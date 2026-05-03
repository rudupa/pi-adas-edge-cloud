#!/bin/bash
# GStreamer H.264 video streaming pipeline
# Streams camera output as RTP/H.264 over UDP to the gateway.
#
# Usage: pipeline.sh [GATEWAY_IP] [GATEWAY_PORT]
set -euo pipefail

GATEWAY_IP=${1:-192.168.4.1}
GATEWAY_PORT=${2:-5000}

echo "Starting H.264 video stream → ${GATEWAY_IP}:${GATEWAY_PORT}"

# Primary: 640×480 @ 30 fps H.264 via VideoCore hardware encoder
gst-launch-1.0 -e \
  v4l2src device=/dev/video0 \
    ! "video/x-h264, width=640, height=480, framerate=30/1" \
    ! h264parse \
    ! rtph264pay pt=96 \
    ! udpsink host="${GATEWAY_IP}" port="${GATEWAY_PORT}" auto-multicast=false \
  2>&1 | logger -t video-streamer

# ── Fallback: 320×240 @ 15 fps (uncomment if resources are constrained) ───
# gst-launch-1.0 -e \
#   v4l2src device=/dev/video0 blocksize=614400 \
#     ! "video/x-h264, width=320, height=240, framerate=15/1" \
#     ! h264parse \
#     ! rtph264pay pt=96 \
#     ! udpsink host="${GATEWAY_IP}" port="${GATEWAY_PORT}" auto-multicast=false \
#   2>&1 | logger -t video-streamer
