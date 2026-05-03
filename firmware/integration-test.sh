#!/bin/bash
# firmware/integration-test.sh
#
# Phase 3 integration test harness.
# Validates that all ADAS services are running and able to communicate via
# the local Mosquitto MQTT broker.
#
# Usage (run as root or with appropriate sudo rights):
#   bash firmware/integration-test.sh
#
# Exit code: 0 = all tests passed, non-zero = failure.

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
BROKER="127.0.0.1"

_pass() { echo "PASS: $*"; (( PASS_COUNT++ )) || true; }
_fail() { echo "FAIL: $*"; (( FAIL_COUNT++ )) || true; }

# ── 1. Start core services ─────────────────────────────────────────────────

echo "=== Starting services ==="
for svc in mosquitto video-streamer audio-capture audio-output; do
    if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
        systemctl start "${svc}" 2>/dev/null && echo "  started: ${svc}" \
            || echo "  WARNING: could not start ${svc} (may already be running)"
    else
        echo "  SKIP: ${svc}.service not installed"
    fi
done

sleep 2

# ── 2. Mosquitto broker reachability ──────────────────────────────────────

echo ""
echo "=== MQTT broker ==="
if mosquitto_pub -h "${BROKER}" -t "gateway/test" -m "ping" 2>/dev/null; then
    _pass "Mosquitto broker reachable at ${BROKER}:1883"
else
    _fail "Mosquitto broker NOT reachable"
fi

# ── 3. gateway/status topic ───────────────────────────────────────────────

echo ""
echo "=== gateway/status ==="
STATUS_MSG=$(timeout 12 mosquitto_sub -h "${BROKER}" -t "gateway/status" \
    -C 1 2>/dev/null || true)
if [ -n "${STATUS_MSG}" ]; then
    _pass "Received gateway/status: ${STATUS_MSG}"
else
    _fail "No message received on gateway/status within 12 s"
fi

# ── 4. sensor/audio/stream topic ─────────────────────────────────────────

echo ""
echo "=== sensor/audio/stream ==="
AUDIO_MSG=$(timeout 10 mosquitto_sub -h "${BROKER}" -t "sensor/audio/stream" \
    -C 1 2>/dev/null || true)
if [ -n "${AUDIO_MSG}" ]; then
    _pass "Received sensor/audio/stream: ${AUDIO_MSG}"
else
    _fail "No message received on sensor/audio/stream within 10 s"
fi

# ── 5. Round-trip: publish a command and verify echo ─────────────────────

echo ""
echo "=== MQTT round-trip ==="
REPLY=$(
    ( timeout 5 mosquitto_sub -h "${BROKER}" -t "gateway/test/echo" -C 1 & )
    sleep 0.2
    mosquitto_pub -h "${BROKER}" -t "gateway/test/echo" -m "hello"
    wait
)
if echo "${REPLY}" | grep -q "hello"; then
    _pass "MQTT round-trip echo succeeded"
else
    _fail "MQTT round-trip echo failed"
fi

# ── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "======================================="
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "======================================="

if [ "${FAIL_COUNT}" -gt 0 ]; then
    exit 1
fi
exit 0
