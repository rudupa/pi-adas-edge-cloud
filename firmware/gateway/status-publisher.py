#!/usr/bin/env python3
"""
firmware/gateway/status-publisher.py

Publishes gateway health metrics to MQTT topic ``gateway/status`` every 10 s.

Payload (JSON):
  {
    "timestamp":        <unix float>,
    "cpu_percent":      <float>,
    "memory_percent":   <float>,
    "temperature":      <float, °C>,
    "uptime":           <int, seconds>
  }
"""

import json
import sys
import time

import psutil
import paho.mqtt.client as mqtt

MQTT_BROKER = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
MQTT_PORT   = 1883
INTERVAL    = 10  # seconds between publishes


def _read_temperature() -> float:
    """Read SoC temperature from the Linux thermal zone."""
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            return int(f.read().strip()) / 1000.0
    except OSError:
        return 0.0


def _read_uptime() -> int:
    """Return system uptime in whole seconds."""
    try:
        with open("/proc/uptime") as f:
            return int(float(f.read().split()[0]))
    except OSError:
        return 0


def main() -> None:
    client = mqtt.Client()
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    client.loop_start()
    print(f"Status publisher connected to {MQTT_BROKER}:{MQTT_PORT}")

    while True:
        status = {
            "timestamp":      time.time(),
            "cpu_percent":    psutil.cpu_percent(interval=1),
            "memory_percent": psutil.virtual_memory().percent,
            "temperature":    _read_temperature(),
            "uptime":         _read_uptime(),
        }
        client.publish("gateway/status", json.dumps(status), qos=1)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
