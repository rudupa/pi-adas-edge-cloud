#!/usr/bin/env bash
set -euo pipefail

# Simple thermal fan controller using sysfs
FAN_GPIO="/sys/class/gpio/gpio4"
TEMP_FILE="/sys/class/thermal/thermal_zone0/temp"
THRESHOLD=60000  # 60°C in millidegrees

# Export GPIO if not already done
if [ ! -d "${FAN_GPIO}" ]; then
    echo 4 > /sys/class/gpio/export 2>/dev/null || true
    echo out > "${FAN_GPIO}/direction" 2>/dev/null || true
fi

while true; do
    TEMP=$(cat "${TEMP_FILE}" 2>/dev/null || echo 0)
    if [ "${TEMP}" -gt "${THRESHOLD}" ]; then
        echo 1 > "${FAN_GPIO}/value" 2>/dev/null || true
    else
        echo 0 > "${FAN_GPIO}/value" 2>/dev/null || true
    fi
    sleep 10
done
