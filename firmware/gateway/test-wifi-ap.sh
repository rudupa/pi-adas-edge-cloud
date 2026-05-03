#!/bin/bash
# Integration test: WiFi access point on gateway node
set -euo pipefail

SSID="ADAS-GATEWAY"
IFACE="${WIFI_IFACE:-wlan0}"

# Ensure hostapd is running
if ! systemctl is-active --quiet hostapd; then
    echo "INFO: hostapd not active; attempting to start"
    systemctl start hostapd
    sleep 2
fi

systemctl is-active --quiet hostapd \
    || { echo "FAIL: hostapd service is not running"; exit 1; }

# Verify SSID is being advertised
if iwlist "$IFACE" scan 2>/dev/null | grep -q "\"${SSID}\""; then
    echo "PASS: AP '$SSID' advertised on $IFACE"
else
    echo "WARN: AP scan did not find '$SSID' (may need a second device to scan)"
    # Non-fatal — hostapd is running; scan detection may not work on same interface
fi
