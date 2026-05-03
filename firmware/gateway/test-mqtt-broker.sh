#!/bin/bash
# Smoke test: MQTT broker on gateway node
set -euo pipefail

BROKER_HOST="${MQTT_HOST:-127.0.0.1}"
BROKER_PORT="${MQTT_PORT:-1883}"
TEST_TOPIC="test/smoke/$$"
TEST_MSG="adas-smoke-$(date +%s)"
TIMEOUT_SECS=5

# Start broker if not already running
if ! systemctl is-active --quiet mosquitto; then
    echo "INFO: mosquitto not active; attempting to start"
    systemctl start mosquitto
    sleep 1
fi

systemctl is-active --quiet mosquitto \
    || { echo "FAIL: mosquitto service is not running"; exit 1; }

# Start subscriber in the background; wait until it is ready before publishing.
# We detect readiness by polling the broker's client list (up to 3 retries).
SUB_FIFO=$(mktemp -u /tmp/mqtt-sub-XXXXXX)
mkfifo "$SUB_FIFO"
trap 'rm -f "$SUB_FIFO"' EXIT

mosquitto_sub -h "$BROKER_HOST" -p "$BROKER_PORT" \
              -t "$TEST_TOPIC" -C 1 2>/dev/null > "$SUB_FIFO" &
SUB_PID=$!

# Give the subscriber up to 3 seconds to connect before publishing
for _i in 1 2 3; do
    sleep 1
    if kill -0 "$SUB_PID" 2>/dev/null; then
        break
    fi
done

mosquitto_pub -h "$BROKER_HOST" -p "$BROKER_PORT" \
              -t "$TEST_TOPIC" -m "$TEST_MSG"

RESPONSE=$(timeout "$TIMEOUT_SECS" cat "$SUB_FIFO" || echo "")

if [ "$RESPONSE" = "$TEST_MSG" ]; then
    echo "PASS: MQTT pub/sub round-trip succeeded"
else
    echo "FAIL: expected '$TEST_MSG', got '${RESPONSE:-<empty>}'"
    exit 1
fi
