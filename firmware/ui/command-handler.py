#!/usr/bin/env python3
"""
firmware/ui/command-handler.py

Handles UI input and MQTT command routing for the ADAS UI node.

Responsibilities:
  1. Listen for GPIO button presses on the Pirate Audio HAT (A/B/X/Y buttons)
     and publish them as MQTT events.
  2. Subscribe to ``ui/command/#`` for inbound action commands from the gateway
     and execute the corresponding local operation (brightness, volume, etc.).

GPIO → MQTT mapping (BCM pin numbers):
  6  → A button
  12 → B button
  13 → X button
  5  → Y button

Usage:
  python3 command-handler.py [GATEWAY_IP]
"""

import json
import os
import sys
import time

import paho.mqtt.client as mqtt

GATEWAY_IP = sys.argv[1] if len(sys.argv) > 1 else "192.168.4.1"

# GPIO BCM pin → button label
BUTTON_MAP = {
    6:  "A",
    12: "B",
    13: "X",
    5:  "Y",
}

# Try to import RPi.GPIO; fall back gracefully on non-Pi hosts
try:
    import RPi.GPIO as GPIO
    GPIO_AVAILABLE = True
except ImportError:
    print("WARNING: RPi.GPIO not available; button input disabled")
    GPIO_AVAILABLE = False

mqtt_client = mqtt.Client()


# ── Action handlers ────────────────────────────────────────────────────────

def _action_brightness_up() -> None:
    os.system("brightnessctl set 10%+")


def _action_brightness_down() -> None:
    os.system("brightnessctl set 10%-")


def _action_volume_up() -> None:
    os.system("amixer set PCM 5%+")


def _action_volume_down() -> None:
    os.system("amixer set PCM 5%-")


_ACTION_MAP = {
    "brightness_up":   _action_brightness_up,
    "brightness_down": _action_brightness_down,
    "volume_up":       _action_volume_up,
    "volume_down":     _action_volume_down,
}


# ── MQTT callbacks ─────────────────────────────────────────────────────────

def on_connect(client: mqtt.Client, userdata, flags, rc: int) -> None:
    print(f"MQTT connected (code={rc})")
    client.subscribe("ui/command/#")


def on_message(client: mqtt.Client, userdata, msg: mqtt.MQTTMessage) -> None:
    try:
        command = json.loads(msg.payload.decode())
        action  = command.get("action", "")
        handler = _ACTION_MAP.get(action)
        if handler:
            handler()
        else:
            print(f"Unknown action: {action!r}")
    except Exception as exc:  # noqa: BLE001
        print(f"Command handling error: {exc}")


# ── GPIO button callbacks ──────────────────────────────────────────────────

def _make_button_callback(pin: int):
    def callback(ch: int) -> None:
        button = BUTTON_MAP.get(pin, str(pin))
        mqtt_client.publish(
            f"ui/event/button/{button}",
            json.dumps({"timestamp": time.time(), "pin": pin}),
        )
    return callback


def _setup_gpio() -> None:
    if not GPIO_AVAILABLE:
        return
    GPIO.setmode(GPIO.BCM)
    for pin in BUTTON_MAP:
        GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.add_event_detect(
            pin,
            GPIO.FALLING,
            callback=_make_button_callback(pin),
            bouncetime=200,
        )


# ── Entry point ────────────────────────────────────────────────────────────

def main() -> None:
    _setup_gpio()

    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    mqtt_client.connect(GATEWAY_IP, 1883, 60)

    print(f"UI command handler running, gateway={GATEWAY_IP}")
    try:
        mqtt_client.loop_forever()
    finally:
        if GPIO_AVAILABLE:
            GPIO.cleanup()


if __name__ == "__main__":
    main()
