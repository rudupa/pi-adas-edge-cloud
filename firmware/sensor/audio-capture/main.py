#!/usr/bin/env python3
"""
firmware/sensor/audio-capture/main.py

Captures audio from the default ALSA device (Voice Bonnet microphones) and
streams PCM frames to the gateway audio mixer over UDP.

Each packet layout:
  [frame_id (4 B, big-endian uint32)]
  [timestamp (4 B, big-endian uint32, samples @ 48 kHz)]
  [PCM data  (raw S16_LE stereo, 960 samples = 20 ms)]

Usage:
  python3 main.py [GATEWAY_IP] [GATEWAY_PORT]
"""

import socket
import struct
import sys
import time

import alsaaudio
import paho.mqtt.client as mqtt

GATEWAY_IP   = sys.argv[1] if len(sys.argv) > 1 else "192.168.4.1"
GATEWAY_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 5001

CHANNELS    = 2
RATE        = 48000
PERIOD_SIZE = 960   # 20 ms @ 48 kHz


def build_mqtt_client(gateway_ip: str) -> mqtt.Client:
    """Connect to MQTT for out-of-band control messages."""
    client = mqtt.Client()
    try:
        client.connect(gateway_ip, 1883, 60)
        client.loop_start()
    except OSError as exc:
        print(f"WARNING: MQTT connection failed: {exc}; continuing without it")
    return client


def open_alsa_capture() -> alsaaudio.PCM:
    inp = alsaaudio.PCM(
        alsaaudio.PCM_CAPTURE,
        alsaaudio.PCM_NONBLOCK,
        device="default",
    )
    inp.setchannels(CHANNELS)
    inp.setrate(RATE)
    inp.setformat(alsaaudio.PCM_FORMAT_S16_LE)
    inp.setperiodsize(PERIOD_SIZE)
    return inp


def main() -> None:
    print(f"Audio capture → {GATEWAY_IP}:{GATEWAY_PORT}")

    mqtt_client = build_mqtt_client(GATEWAY_IP)
    inp         = open_alsa_capture()

    udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    frame_id   = 0
    start_time = time.time()

    while True:
        try:
            length, data = inp.read()
            if length > 0:
                # 90 kHz-equivalent timestamp (scaled from wall clock)
                timestamp = int((time.time() - start_time) * RATE)
                packet    = struct.pack("!II", frame_id, timestamp) + data
                udp_sock.sendto(packet, (GATEWAY_IP, GATEWAY_PORT))
                frame_id += 1

                # Publish stream-status metadata to MQTT (every 50 frames ≈ 1 s)
                if frame_id % 50 == 0:
                    mqtt_client.publish(
                        "sensor/audio/stream",
                        f'{{"frame_id":{frame_id},"rate":{RATE}}}',
                    )
        except Exception as exc:  # noqa: BLE001
            print(f"Capture error: {exc}")

        time.sleep(0.001)  # short yield; NONBLOCK mode drives timing


if __name__ == "__main__":
    main()
