#!/bin/bash
# Integration test: sensor node connects to ADAS-GATEWAY WiFi AP
set -euo pipefail

SSID="ADAS-GATEWAY"
IFACE="${WIFI_IFACE:-wlan0}"
TIMEOUT_SECS=10

# WiFi passphrase — override via WIFI_PASSWORD environment variable
# or store it in /etc/adas/wifi.conf (chmod 600, readable only by root)
WIFI_PASSWORD="${WIFI_PASSWORD:-}"
if [ -z "$WIFI_PASSWORD" ] && [ -r /etc/adas/wifi.conf ]; then
    # shellcheck source=/dev/null
    WIFI_PASSWORD=$(grep -m1 '^WIFI_PASSWORD=' /etc/adas/wifi.conf | cut -d= -f2-)
fi
if [ -z "$WIFI_PASSWORD" ]; then
    echo "ERROR: WIFI_PASSWORD is not set. Export it or put it in /etc/adas/wifi.conf" >&2
    exit 1
fi

# Add and configure network entry
NID=$(wpa_cli -i "$IFACE" add_network | tail -1)
wpa_cli -i "$IFACE" set_network "$NID" ssid "\"${SSID}\"" > /dev/null
wpa_cli -i "$IFACE" set_network "$NID" psk "\"${WIFI_PASSWORD}\"" > /dev/null
wpa_cli -i "$IFACE" enable_network "$NID" > /dev/null
wpa_cli -i "$IFACE" select_network "$NID" > /dev/null

echo "INFO: waiting up to ${TIMEOUT_SECS}s for IP assignment on $IFACE ..."
for _ in $(seq 1 "$TIMEOUT_SECS"); do
    IP=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)
    if [ -n "$IP" ]; then
        echo "PASS: connected to '${SSID}', IP=${IP}"
        exit 0
    fi
    sleep 1
done

echo "FAIL: no IP address obtained on $IFACE after ${TIMEOUT_SECS}s"
exit 1
