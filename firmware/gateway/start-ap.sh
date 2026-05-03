#!/bin/bash
# firmware/gateway/start-ap.sh
#
# Configure and bring up the ADAS-GATEWAY WiFi Access Point on the Pi 4.
# Starts hostapd, assigns a static IP to wlan0, launches dnsmasq for DHCP,
# and sets up NAT so sensor/UI nodes can reach the internet via eth0.
#
# Usage:
#   sudo bash firmware/gateway/start-ap.sh [--no-nat]
#
# Options:
#   --no-nat   Skip iptables NAT rules (useful when eth0 uplink is absent)
#
# Environment:
#   WIFI_IFACE   Wireless interface name  (default: wlan0)
#   ETH_IFACE    Ethernet interface name  (default: eth0)
#   AP_IP        Static IP for AP iface   (default: 192.168.4.1)
#   HOSTAPD_CONF Path to hostapd config   (default: /etc/hostapd/hostapd.conf)
#   DNSMASQ_CONF Path to dnsmasq config   (default: /etc/dnsmasq.conf)

set -euo pipefail

WIFI_IFACE="${WIFI_IFACE:-wlan0}"
ETH_IFACE="${ETH_IFACE:-eth0}"
AP_IP="${AP_IP:-192.168.4.1}"
HOSTAPD_CONF="${HOSTAPD_CONF:-/etc/hostapd/hostapd.conf}"
DNSMASQ_CONF="${DNSMASQ_CONF:-/etc/dnsmasq.conf}"

ENABLE_NAT=1
for arg in "$@"; do
    [ "$arg" = "--no-nat" ] && ENABLE_NAT=0
done

fail() { echo "ERROR: $*" >&2; exit 1; }

# ── Prerequisites ─────────────────────────────────────────────────────────────
command -v hostapd  >/dev/null 2>&1 || fail "hostapd not installed"
command -v dnsmasq  >/dev/null 2>&1 || fail "dnsmasq not installed"
command -v ip       >/dev/null 2>&1 || fail "iproute2 not installed"
[ -r "$HOSTAPD_CONF" ]              || fail "hostapd config not found: ${HOSTAPD_CONF}"
[ -r "$DNSMASQ_CONF" ]              || fail "dnsmasq config not found: ${DNSMASQ_CONF}"

# ── Bring interface up ────────────────────────────────────────────────────────
ip link set "$WIFI_IFACE" up 2>/dev/null \
    || fail "cannot bring up interface ${WIFI_IFACE}"

# ── Enable IP forwarding ──────────────────────────────────────────────────────
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "INFO: IP forwarding enabled"

# ── Assign static IP to AP interface ─────────────────────────────────────────
# Remove any existing address on this interface first to avoid duplicates
ip addr flush dev "$WIFI_IFACE" 2>/dev/null || true
ip addr add "${AP_IP}/24" dev "$WIFI_IFACE" \
    || fail "cannot assign ${AP_IP}/24 to ${WIFI_IFACE}"
echo "INFO: Assigned ${AP_IP}/24 to ${WIFI_IFACE}"

# ── Start hostapd (Access Point daemon) ───────────────────────────────────────
if systemctl is-active --quiet hostapd 2>/dev/null; then
    echo "INFO: hostapd already running; reloading config"
    systemctl reload hostapd
else
    hostapd -B "$HOSTAPD_CONF" \
        || fail "hostapd failed to start (check ${HOSTAPD_CONF})"
    echo "INFO: hostapd started"
fi

# ── Start dnsmasq (DHCP server) ───────────────────────────────────────────────
# Kill any previous instance bound to wlan0 to avoid port conflicts
pkill -f "dnsmasq.*${WIFI_IFACE}" 2>/dev/null || true
sleep 0.2
dnsmasq -C "$DNSMASQ_CONF" \
    || fail "dnsmasq failed to start (check ${DNSMASQ_CONF})"
echo "INFO: dnsmasq DHCP server started"

# ── NAT / masquerade (optional, for internet uplink via eth0) ─────────────────
if [ "$ENABLE_NAT" -eq 1 ] && ip link show "$ETH_IFACE" >/dev/null 2>&1; then
    iptables -t nat -C POSTROUTING -o "$ETH_IFACE" -j MASQUERADE 2>/dev/null \
        || iptables -t nat -A POSTROUTING -o "$ETH_IFACE" -j MASQUERADE
    iptables -C FORWARD -i "$WIFI_IFACE" -o "$ETH_IFACE" -j ACCEPT 2>/dev/null \
        || iptables -A FORWARD -i "$WIFI_IFACE" -o "$ETH_IFACE" -j ACCEPT
    iptables -C FORWARD -i "$ETH_IFACE" -o "$WIFI_IFACE" \
        -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \
        || iptables -A FORWARD -i "$ETH_IFACE" -o "$WIFI_IFACE" \
        -m state --state RELATED,ESTABLISHED -j ACCEPT
    echo "INFO: NAT masquerade via ${ETH_IFACE} configured"
else
    echo "INFO: NAT skipped (--no-nat or ${ETH_IFACE} not present)"
fi

echo ""
echo "AP ready — SSID: $(grep '^ssid=' "${HOSTAPD_CONF}" | cut -d= -f2-), IP: ${AP_IP}"
