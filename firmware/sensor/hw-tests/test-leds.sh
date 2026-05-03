#!/bin/bash
# Hardware smoke test: Voice Bonnet LEDs and buttons (Adafruit Voice Bonnet)
#
# GPIO mapping (Adafruit Voice Bonnet on Pi Zero W):
#   LED red   → GPIO 17
#   LED green → GPIO 27
#   Button 1  → GPIO 23
#   Button 2  → GPIO 24
set -euo pipefail

LED_GPIOS=(17 27)
BUTTON_GPIOS=(23 24)
BLINK_MS=200

fail() { echo "FAIL: $*" >&2; exit 1; }

# ── LED test ──────────────────────────────────────────────────────────────────
for gpio in "${LED_GPIOS[@]}"; do
    sysfs="/sys/class/gpio/gpio${gpio}"

    # Export if not already done
    if [ ! -d "$sysfs" ]; then
        echo "$gpio" > /sys/class/gpio/export 2>/dev/null \
            || fail "cannot export GPIO ${gpio}"
        sleep 0.05
    fi

    # Set direction to output
    echo out > "${sysfs}/direction" 2>/dev/null \
        || fail "cannot set GPIO ${gpio} as output"

    # Blink: on → off  (BLINK_MS expressed in seconds via awk)
    echo 1 > "${sysfs}/value" 2>/dev/null || fail "cannot write GPIO ${gpio} high"
    sleep "$(awk "BEGIN {printf \"%.3f\", ${BLINK_MS}/1000}")"
    echo 0 > "${sysfs}/value" 2>/dev/null || fail "cannot write GPIO ${gpio} low"

    echo "INFO: LED GPIO ${gpio} blink OK"
done

# ── Button test ───────────────────────────────────────────────────────────────
for gpio in "${BUTTON_GPIOS[@]}"; do
    sysfs="/sys/class/gpio/gpio${gpio}"

    if [ ! -d "$sysfs" ]; then
        echo "$gpio" > /sys/class/gpio/export 2>/dev/null \
            || fail "cannot export GPIO ${gpio}"
        sleep 0.05
    fi

    echo in > "${sysfs}/direction" 2>/dev/null \
        || fail "cannot set GPIO ${gpio} as input"

    STATE=$(cat "${sysfs}/value" 2>/dev/null || echo "?")
    echo "INFO: Button GPIO ${gpio} value=${STATE}"
done

echo "PASS: Voice Bonnet LEDs (${LED_GPIOS[*]}) and buttons (${BUTTON_GPIOS[*]}) accessible"
