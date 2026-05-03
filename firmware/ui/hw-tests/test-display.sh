#!/bin/bash
# Hardware smoke test: display SPI interface (Pirate Audio ST7789)
set -euo pipefail

ls /dev/spidev* >/dev/null 2>&1 \
    || { echo "FAIL: no SPI device found under /dev/spidev*"; exit 1; }

echo "PASS: display SPI ready ($(ls /dev/spidev* | tr '\n' ' '))"
