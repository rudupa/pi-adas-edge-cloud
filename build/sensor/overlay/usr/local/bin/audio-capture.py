#!/usr/bin/env python3
"""
ADAS Sensor Node — Audio Capture Service
Captures audio from WM8960 via ALSA and streams to the gateway.
"""

import os
import subprocess
import time

GATEWAY_IP = os.environ.get("GATEWAY_IP", "192.168.4.1")
AUDIO_DEVICE = os.environ.get("AUDIO_DEVICE", "default")
SAMPLE_RATE = 16000
CHANNELS = 1


def capture_loop():
    """Capture audio from ALSA and forward to gateway via UDP."""
    cmd = [
        "arecord",
        "-D", AUDIO_DEVICE,
        "-r", str(SAMPLE_RATE),
        "-c", str(CHANNELS),
        "-f", "S16_LE",
        "-t", "raw",
        "-",
    ]
    # TODO: pipe raw PCM to a UDP socket targeting the gateway
    print(f"Starting audio capture from {AUDIO_DEVICE} at {SAMPLE_RATE} Hz")
    try:
        with subprocess.Popen(cmd, stdout=subprocess.PIPE) as proc:
            while True:
                chunk = proc.stdout.read(4096)
                if not chunk:
                    break
                # TODO: send chunk to GATEWAY_IP via UDP
    except FileNotFoundError:
        print("WARNING: arecord not found; audio capture disabled")
        while True:
            time.sleep(1)


def main():
    print("Audio capture service starting")
    capture_loop()


if __name__ == "__main__":
    main()
