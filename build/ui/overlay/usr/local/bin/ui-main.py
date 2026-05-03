#!/usr/bin/env python3
"""
ADAS UI Node — Main application
Renders ADAS status on the Pirate Audio ST7789 display and publishes
button events to MQTT.
"""

import sys
import signal
import subprocess
import time


def signal_handler(sig, frame):
    print("UI shutdown signal received, exiting cleanly")
    sys.exit(0)


signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)


def init_display():
    """Initialize the SPI framebuffer display."""
    result = subprocess.run(
        ["/usr/local/bin/ui-start.sh"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: Display init failed: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    print("Display initialized")


def main():
    init_display()

    # TODO: Implement full UI rendering via pygame or direct framebuffer.
    # Display ADAS status: lane detection alerts, object detections,
    # voice command feedback, system health.
    print("UI main loop started — awaiting MQTT messages from gateway")

    while True:
        # Poll MQTT for display/audio updates from gateway
        # Render received data to framebuffer
        time.sleep(0.1)


if __name__ == "__main__":
    main()
