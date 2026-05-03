#!/usr/bin/env python3
"""
ADAS UI Node — Audio Output Service
Subscribes to MQTT audio commands from the gateway and plays them via ALSA.
"""

import os
import subprocess
import time

# Try to import paho; fall back gracefully if not available
try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    print("WARNING: paho-mqtt not available; MQTT audio playback disabled")
    MQTT_AVAILABLE = False

GATEWAY_IP = os.environ.get("GATEWAY_IP", "192.168.4.1")
MQTT_PORT = 1883


def on_connect(client, userdata, flags, rc):
    print(f"MQTT connected (code={rc})")
    client.subscribe("gateway/audio/play")


def on_message(client, userdata, msg):
    if msg.topic == "gateway/audio/play":
        # TODO: decode audio payload and pipe to ALSA via aplay
        pass


def main():
    if not MQTT_AVAILABLE:
        print("Audio output service running in stub mode (no MQTT)")
        while True:
            time.sleep(1)
        return

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(GATEWAY_IP, MQTT_PORT)
    client.loop_start()

    print("Audio output service running")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Shutting down audio output service")
        client.loop_stop()


if __name__ == "__main__":
    main()
