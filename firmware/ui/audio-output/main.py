#!/usr/bin/env python3
"""
firmware/ui/audio-output/main.py

Subscribes to MQTT topic ``ui/audio/play/#`` and plays received audio through
the Pirate Audio amplifier (ALSA PCM playback).

Expected MQTT payload (JSON):
  {
    "priority": 0,          # 0-3 (P0=safety critical … P3=background)
    "audio_b64": "<base64>",# base64-encoded S16_LE PCM at 16 kHz mono
    "source": "gateway"
  }

Usage:
  python3 main.py [GATEWAY_IP]
"""

import base64
import json
import sys
import threading
from collections import deque
from dataclasses import dataclass, field
from enum import IntEnum
from typing import Deque, Dict

import alsaaudio
import paho.mqtt.client as mqtt

GATEWAY_IP = sys.argv[1] if len(sys.argv) > 1 else "192.168.4.1"

CHANNELS    = 1
RATE        = 16000
PERIOD_SIZE = 160   # 10 ms @ 16 kHz


class Priority(IntEnum):
    P0_SAFETY    = 0
    P1_ADVISORY  = 1
    P2_INFO      = 2
    P3_BACKGROUND = 3


@dataclass(order=True)
class AudioJob:
    priority: int
    audio_bytes: bytes = field(compare=False)


# One bounded deque per priority level
_queues: Dict[Priority, Deque[AudioJob]] = {
    p: deque(maxlen=20) for p in Priority
}
_queue_event = threading.Event()


def _open_playback() -> alsaaudio.PCM:
    out = alsaaudio.PCM(alsaaudio.PCM_PLAYBACK, device="default")
    out.setchannels(CHANNELS)
    out.setrate(RATE)
    out.setformat(alsaaudio.PCM_FORMAT_S16_LE)
    out.setperiodsize(PERIOD_SIZE)
    return out


def _playback_thread() -> None:
    out = _open_playback()
    while True:
        _queue_event.wait()
        _queue_event.clear()

        for p in Priority:
            if _queues[p]:
                job = _queues[p].popleft()
                try:
                    out.write(job.audio_bytes)
                except Exception as exc:  # noqa: BLE001
                    print(f"Playback error (P{p}): {exc}")
                break  # re-evaluate priorities after each frame


def on_message(client: mqtt.Client, userdata: None, msg: mqtt.MQTTMessage) -> None:
    try:
        payload   = json.loads(msg.payload.decode())
        priority  = int(payload.get("priority", Priority.P2_INFO))
        audio_b64 = payload.get("audio_b64", "")
        audio_bytes = base64.b64decode(audio_b64)

        p = Priority(min(priority, int(Priority.P3_BACKGROUND)))
        _queues[p].append(AudioJob(priority=p, audio_bytes=audio_bytes))

        # P0 safety-critical: flush lower-priority queues immediately
        if p == Priority.P0_SAFETY:
            for lp in [Priority.P1_ADVISORY, Priority.P2_INFO, Priority.P3_BACKGROUND]:
                _queues[lp].clear()

        _queue_event.set()
    except Exception as exc:  # noqa: BLE001
        print(f"Message handling error: {exc}")


def main() -> None:
    print(f"Audio output service connecting to {GATEWAY_IP}:1883")

    pb_thread = threading.Thread(target=_playback_thread, daemon=True)
    pb_thread.start()

    client = mqtt.Client()
    client.on_message = on_message
    client.connect(GATEWAY_IP, 1883, 60)
    client.subscribe("ui/audio/play/#")
    client.loop_forever()


if __name__ == "__main__":
    main()
