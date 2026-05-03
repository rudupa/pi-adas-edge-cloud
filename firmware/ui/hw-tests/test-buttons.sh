#!/bin/bash
# Hardware smoke test: Pirate Audio HAT button GPIO lines
set -euo pipefail

# Pirate Audio buttons are mapped to GPIO 5, 6, 16, 24
BUTTON_GPIOS=(5 6 16 24)

for gpio in "${BUTTON_GPIOS[@]}"; do
    path="/sys/class/gpio/gpio${gpio}"
    if [ ! -d "$path" ]; then
        echo "$gpio" > /sys/class/gpio/export 2>/dev/null || true
    fi
    [ -d "$path" ] \
        || { echo "FAIL: GPIO ${gpio} not accessible"; exit 1; }
done

echo "PASS: button GPIO lines (${BUTTON_GPIOS[*]}) accessible"
