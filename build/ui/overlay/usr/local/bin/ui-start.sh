#!/usr/bin/env bash
set -euo pipefail

# Initialize SPI framebuffer device for ST7789 display
if [ ! -e /dev/spidev0.0 ]; then
    echo "ERROR: SPI device /dev/spidev0.0 not found" >&2
    exit 1
fi

echo "SPI display device ready: /dev/spidev0.0"

# Set display backlight if GPIO is available
if [ -d /sys/class/backlight ]; then
    for bl in /sys/class/backlight/*/brightness; do
        echo 255 > "${bl}" 2>/dev/null || true
    done
fi

echo "Display initialized"
