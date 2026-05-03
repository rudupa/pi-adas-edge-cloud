#!/bin/bash
# Hardware smoke test: audio input (Voice Bonnet / WM8960)
set -euo pipefail

RECORDING=/tmp/test-audio-input.wav

timeout 2 arecord -D default -f cd -t wav "$RECORDING" 2>/dev/null || true

# Minimum expected bytes: 2s × 44100 Hz × 2 channels × 2 bytes/sample = 352,800 bytes
# (WAV header adds ~44 bytes; we use a conservative lower-bound of 40,000 bytes
#  to account for driver start-up latency shaving some samples off the beginning)
MIN_SIZE=40000
SIZE=$(stat -c%s "$RECORDING" 2>/dev/null || echo 0)
[ "$SIZE" -gt "$MIN_SIZE" ] \
    && echo "PASS: audio capture (${SIZE} bytes)" \
    || { echo "FAIL: audio capture produced too few bytes (${SIZE} < ${MIN_SIZE})"; exit 1; }

rm -f "$RECORDING"
