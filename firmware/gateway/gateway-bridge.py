#!/usr/bin/env python3
"""
ADAS Gateway Bridge
Aggregates sensor streams via MQTT, runs TFLite inference on video frames,
and publishes AI detection results back to the fleet.
"""

import json
import threading
import time
from collections import deque

import paho.mqtt.client as mqtt

# Try to import TFLite; fall back gracefully if not available
try:
    import tflite_runtime.interpreter as tflite
    TFLITE_AVAILABLE = True
except ImportError:
    print("WARNING: tflite_runtime not available; AI inference disabled")
    TFLITE_AVAILABLE = False

MODEL_PATH = "/usr/local/share/models/mobilenet_ssd_v2_quantized.tflite"

# Buffers for aggregating sensor streams
vision_queue: deque = deque(maxlen=30)
audio_queue: deque = deque(maxlen=1024)

interpreter = None


def load_model():
    global interpreter
    if not TFLITE_AVAILABLE:
        return
    try:
        interpreter = tflite.Interpreter(model_path=MODEL_PATH)
        interpreter.allocate_tensors()
        print(f"TFLite model loaded from {MODEL_PATH}")
    except Exception as exc:
        print(f"WARNING: Failed to load TFLite model: {exc}")


def on_connect(client, userdata, flags, rc):
    print(f"MQTT connected (code={rc})")
    client.subscribe("sensor/vision/frame")
    client.subscribe("sensor/audio/stream")
    client.subscribe("ui/command/#")


def on_message(client, userdata, msg):
    if msg.topic.startswith("sensor/vision/"):
        try:
            vision_queue.append(json.loads(msg.payload))
        except json.JSONDecodeError:
            pass
    elif msg.topic.startswith("sensor/audio/"):
        audio_queue.append(msg.payload)


def inference_loop(client):
    """Periodic AI inference on aggregated vision frames."""
    while True:
        if interpreter is not None and vision_queue:
            frame_meta = vision_queue[0]
            # TODO: decode raw frame bytes, resize to 300×300, run inference
            result = {
                "timestamp": time.time(),
                "source": "tflite",
                "detections": [],
            }
            client.publish("gateway/ai/detections", json.dumps(result))
        time.sleep(0.1)


def main():
    load_model()

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect("127.0.0.1", 1883)
    client.loop_start()

    inference_thread = threading.Thread(
        target=inference_loop, args=(client,), daemon=True
    )
    inference_thread.start()

    print("Gateway bridge running")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Shutting down gateway bridge")
        client.loop_stop()


if __name__ == "__main__":
    main()
