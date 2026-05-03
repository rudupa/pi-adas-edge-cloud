#!/usr/bin/env python3
"""
firmware/gateway/audio-mixer/main.py

Priority-based audio mixer for the ADAS gateway.

Receives raw PCM frames from sensor nodes via UDP (port 5001) and from
cloud/TTS sources, then forwards them to the UI node via MQTT using a
four-level priority queue:

  P0 – Safety Critical  (<100 ms): e.g. "Lane departure warning"
  P1 – Advisory         (<500 ms): e.g. "Slow traffic ahead"
  P2 – Info             (<2 s)   : e.g. "Route updated"
  P3 – Background       (best-effort): music / ambient audio

Usage:
  python3 main.py
"""

import base64
import json
import socket
import struct
import threading
import time
from collections import deque
from dataclasses import dataclass, field
from enum import IntEnum
from typing import Deque, Dict

import paho.mqtt.client as mqtt

UDP_BIND_IP   = "0.0.0.0"
UDP_BIND_PORT = 5001
MQTT_BROKER   = "127.0.0.1"
MQTT_PORT     = 1883
MIXER_INTERVAL = 0.01  # seconds between mixer ticks


class Priority(IntEnum):
    P0_SAFETY     = 0
    P1_ADVISORY   = 1
    P2_INFO       = 2
    P3_BACKGROUND = 3


@dataclass(order=True)
class AudioFrame:
    priority: int
    frame_id: int       = field(compare=False)
    timestamp: int      = field(compare=False)
    data: bytes         = field(compare=False)
    source: str         = field(compare=False)


# One bounded deque per priority level
audio_queues: Dict[Priority, Deque[AudioFrame]] = {
    p: deque(maxlen=100) for p in Priority
}

_queue_lock = threading.Lock()


def _parse_source_priority(source_ip: str) -> Priority:
    """Heuristic: cloud sources (not 192.168.4.x) use P1; local sensor P2."""
    if source_ip.startswith("192.168.4."):
        return Priority.P2_INFO
    return Priority.P1_ADVISORY


def udp_listener() -> None:
    """Background thread: receive UDP audio frames and enqueue them."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((UDP_BIND_IP, UDP_BIND_PORT))
    sock.settimeout(1.0)
    print(f"UDP listener bound to {UDP_BIND_IP}:{UDP_BIND_PORT}")

    while True:
        try:
            data, addr = sock.recvfrom(65535)
        except socket.timeout:
            continue
        except Exception as exc:  # noqa: BLE001
            print(f"UDP receive error: {exc}")
            continue

        if len(data) < 8:
            continue  # header too short

        frame_id, timestamp = struct.unpack("!II", data[:8])
        audio_data          = data[8:]
        source_ip           = addr[0]
        priority            = _parse_source_priority(source_ip)

        frame = AudioFrame(
            priority=int(priority),
            frame_id=frame_id,
            timestamp=timestamp,
            data=audio_data,
            source=source_ip,
        )
        with _queue_lock:
            audio_queues[priority].append(frame)


def mixer_thread(mqtt_client: mqtt.Client) -> None:
    """Background thread: pop highest-priority frame and publish to UI."""
    while True:
        frame: AudioFrame | None = None
        with _queue_lock:
            for p in Priority:
                if audio_queues[p]:
                    frame = audio_queues[p].popleft()
                    break

        if frame is not None:
            payload = json.dumps({
                "priority": frame.priority,
                "audio_b64": base64.b64encode(frame.data).decode(),
                "source": frame.source,
            })
            # Route to priority-specific sub-topic for flexible UI subscriptions
            topic = f"ui/audio/play/{frame.priority}"
            mqtt_client.publish(topic, payload, qos=0)

        time.sleep(MIXER_INTERVAL)


def main() -> None:
    mqtt_client = mqtt.Client()
    mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
    mqtt_client.loop_start()

    # Start UDP listener
    t_udp = threading.Thread(target=udp_listener, daemon=True)
    t_udp.start()

    # Start mixer
    t_mix = threading.Thread(target=mixer_thread, args=(mqtt_client,), daemon=True)
    t_mix.start()

    print("Audio mixer running (UDP → priority queues → MQTT ui/audio/play)")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Audio mixer shutting down")
        mqtt_client.loop_stop()


if __name__ == "__main__":
    main()
