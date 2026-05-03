#!/usr/bin/env bash
set -euo pipefail

# Read GPIO button events from input device and publish to MQTT
GATEWAY_IP="${GATEWAY_IP:-192.168.4.1}"
MQTT_PORT="${MQTT_PORT:-1883}"

INPUT_DEV=$(find /dev/input -name "event*" | head -1)
if [ -z "${INPUT_DEV}" ]; then
    echo "ERROR: No input device found for buttons" >&2
    exit 1
fi

echo "Listening for button events on ${INPUT_DEV}"

# Use evtest (or fallback to gpiod) to capture button presses
# and publish to MQTT topic ui/command/button
evtest "${INPUT_DEV}" 2>/dev/null | while IFS= read -r line; do
    if echo "${line}" | grep -q "BTN"; then
        BTN=$(echo "${line}" | grep -oP 'BTN_\w+')
        mosquitto_pub -h "${GATEWAY_IP}" -p "${MQTT_PORT}" \
            -t "ui/command/button" -m "{\"button\":\"${BTN}\"}"
    fi
done
