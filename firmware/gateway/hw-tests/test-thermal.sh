#!/bin/bash
# Hardware smoke test: Pi 4 CPU thermal management
#
# Checks:
#   1. CPU temperature is readable and within safe range (<80°C warning, <90°C hard limit).
#   2. Thermal zone sysfs node is present.
#   3. PWM chip (used for fan control) is enumerated (non-fatal if absent on
#      boot before first access).
set -euo pipefail

TEMP_FILE="/sys/class/thermal/thermal_zone0/temp"
WARN_THRESHOLD_C=80
FAIL_THRESHOLD_C=90

fail() { echo "FAIL: $*" >&2; exit 1; }

# ── Thermal zone readability ──────────────────────────────────────────────────
[ -r "$TEMP_FILE" ] \
    || fail "thermal zone not found at ${TEMP_FILE}"

RAW=$(cat "$TEMP_FILE" 2>/dev/null || echo "0")
TEMP_C=$((RAW / 1000))

echo "INFO: CPU temperature: ${TEMP_C}°C"

if [ "$TEMP_C" -ge "$FAIL_THRESHOLD_C" ]; then
    fail "CPU temperature critically high (${TEMP_C}°C ≥ ${FAIL_THRESHOLD_C}°C) — check cooling"
fi

if [ "$TEMP_C" -ge "$WARN_THRESHOLD_C" ]; then
    echo "WARN: CPU temperature elevated (${TEMP_C}°C ≥ ${WARN_THRESHOLD_C}°C) — verify fan"
fi

# ── PWM chip for fan ──────────────────────────────────────────────────────────
PWM_LIST=$(find /sys/class/pwm -name 'pwm*' -maxdepth 2 2>/dev/null | tr '\n' ' ')
if [ -n "$PWM_LIST" ]; then
    echo "INFO: PWM fan channel(s) present: ${PWM_LIST}"
else
    echo "WARN: PWM channel not yet enumerated (may appear after first access — non-fatal)"
fi

echo "PASS: thermal check OK (${TEMP_C}°C)"
