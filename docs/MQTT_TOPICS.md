# MQTT Topic Hierarchy

All nodes in the ADAS edge-cloud system communicate over the gateway's Mosquitto
broker (`192.168.4.1:1883`).

## Topic Reference

| Topic | Direction | Description |
|---|---|---|
| `gateway/status` | gateway → all | Gateway health metrics (CPU, memory, temperature, uptime) |
| `gateway/ai/detections` | gateway → ui/cloud | AI inference results (objects detected, lane data) |
| `sensor/vision/frame` | sensor → gateway | Raw H.264 frame metadata (timestamp, sequence number) |
| `sensor/audio/stream` | sensor → gateway | Audio stream status and PCM frames |
| `ui/display/image` | gateway → ui | JPEG/PNG image to render on the ST7789 display |
| `ui/audio/play` | gateway → ui | Audio playback command (base64 PCM + priority) |
| `ui/command/action` | ui → gateway | UI button press → named action |
| `ui/event/button/<X>` | ui → gateway | Raw GPIO button event (A/B/X/Y) |
| `cloud/telemetry/log` | gateway → cloud | Unified telemetry forwarded to cloud backend |

## Priority Classes (audio)

| Class | Max Latency | Example |
|---|---|---|
| P0 — Safety Critical | < 100 ms | "Lane departure warning" |
| P1 — Advisory | < 500 ms | "Slow traffic detected" |
| P2 — Info | < 2 s | "Route updated" |
| P3 — Background | best-effort | Background audio / music |

## QoS Guidelines

- `gateway/status` — QoS 1 (at-least-once, infrequent)
- `gateway/ai/detections` — QoS 0 (fire-and-forget, high frequency)
- `sensor/vision/frame` — QoS 0 (high frequency, loss acceptable)
- `sensor/audio/stream` — QoS 0 (real-time, loss acceptable)
- `ui/command/action` — QoS 1 (commands must not be lost)
- `cloud/telemetry/log` — QoS 1 (reliable delivery to cloud)
