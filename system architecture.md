# System Architecture

## Table of Contents

- [1. Design Goals](#1-design-goals)
- [2. Software Stack by Node](#2-software-stack-by-node)
- [3. Runtime Data Flow](#3-runtime-data-flow)
- [4. Protocol and Topic Architecture](#4-protocol-and-topic-architecture)
- [5. Boot and Startup Strategy](#5-boot-and-startup-strategy)
- [6. Repository and Process Layout](#6-repository-and-process-layout)
- [7. Observability and Operations](#7-observability-and-operations)
- [8. Security Model](#8-security-model)
- [9. Delivery Plan (Implementation Phases)](#9-delivery-plan-implementation-phases)
- [10. Risk Notes and Mitigations](#10-risk-notes-and-mitigations)

---

## 1. Design Goals

- Fast boot on constrained edge nodes (Pi Zero W).
- Low-latency local media transport (video/audio).
- Deterministic local control path for buttons and actuator commands.
- Clean separation between edge real-time behavior and cloud integration.

## 2. Software Stack by Node

### Sensor Node (Pi Zero W)
- OS: Buildroot (minimal image, BusyBox init)
- Services:
  - `video_streamer`
  - `audio_streamer`
  - `device_control` (LED GPIO)
  - `mqtt_client` (status + command channel)
- Init: Auto-start via `/etc/init.d/`

### UI Node (Pi Zero W)
- OS: Buildroot (minimal image)
- Services:
  - `video_receiver` + framebuffer renderer
  - `audio_player`
  - `button_input` publisher
  - `mqtt_client`
- UI path: Framebuffer/SDL (no X11/Wayland)

### Gateway + Master Node (Pi 4)
- OS: Linux distro optimized for AI runtime
- Services:
  - hostapd
  - dnsmasq
  - Mosquitto MQTT broker
  - monitoring agent
  - cloud bridge agent
  - orchestration engine
  - voice recognition (Vosk preferred for offline)
  - decision logic
  - command publisher (MQTT)

### Cloud Node (Managed or Self-Hosted)
- Runtime: cloud VM/container platform
- Services:
  - device registry
  - telemetry ingestion API (HTTPS/MQTT over TLS)
  - centralized log store and query API
  - OTA manifest/artifact service
  - rollout controller (canary, staged rollout, rollback)
  - alerting and dashboard API

## 3. Runtime Data Flow

```text
Sensor Pi Zero:
  video_streamer  ----UDP/MJPEG---->  UI Pi Zero (display)
  audio_streamer  ----UDP/Opus----->  UI Pi Zero (speaker) / Gateway+Master Pi
  LED control     <---MQTT cmd------  Gateway+Master/UI logic

UI Pi Zero:
  button_input    ----MQTT event----> Gateway+Master Pi

Gateway+Master Pi:
  control logic   ----MQTT cmd------> Sensor/UI nodes
  cloud bridge    ----TLS MQTT/HTTPS-> Cloud Node

Cloud Node:
  telemetry ingest <----TLS---------- Gateway+Master Pi
  OTA policy       ----TLS----------> Gateway+Master Pi
  logs + metrics   <----TLS---------- Gateway+Master Pi
```

## 4. Protocol and Topic Architecture

### Media protocols
- Video: MJPEG over UDP (or GStreamer pipeline tuned for latency)
- Audio: Opus over UDP (preferred), raw PCM fallback for simplicity

### Control protocol
- MQTT topics (example namespace):
  - `sensor/led/set`
  - `sensor/led/state`
  - `ui/buttons`
  - `audio/command`
  - `system/status`
  - `cloud/telemetry/system`
  - `cloud/logs/events`
  - `cloud/ota/command`
  - `cloud/ota/status`

### Service discovery
- Start with static hostnames/IP leases for deterministic behavior.
- Add mDNS-based discovery only after baseline stability.

## 5. Boot and Startup Strategy

### Pi Zero boot optimization
- Buildroot image with only required drivers/packages.
- Disable nonessential services (HDMI, unused Bluetooth, verbose logs).
- Start only critical daemons at boot.
- Use event-driven stream activation when possible.

### Service ordering
1. Network ready
2. MQTT client connect
3. Device control service start
4. Media pipeline start on demand

## 6. Repository and Process Layout

```text
/app
  /main
  /video_streamer
  /audio_streamer
  /mqtt_client
  /device_control
```

### Language split
- C++: media path, buffering, timing-critical I/O
- Python: orchestration, state machine, business logic

## 7. Observability and Operations

- Publish heartbeat and health topics (`system/status`).
- Include metrics:
  - stream FPS
  - packet loss estimate
  - CPU and memory usage
  - audio/video queue depth
- Keep bounded local logs with rotation.

## 8. Security Model

- WPA2 on private WLAN.
- MQTT username/password authentication.
- TLS required on cloud uplink.
- Restrict cloud payload to telemetry/events/snapshots (not full live stream by default).

## 9. Delivery Plan (Implementation Phases)

1. Bring-up
- Buildroot boot on Pi Zero nodes
- GPIO LED validation
- Single frame camera capture

2. Streaming
- Video Sensor -> UI
- Audio Sensor -> UI

3. Control
- UI button event -> Gateway + Master
- Gateway + Master command -> Sensor LED action

4. Gateway core
- AP mode + DHCP + MQTT broker

5. Brain services on same node
- Voice command processing on Gateway + Master
- Decision loop and command publishing

6. Cloud
- Gateway bridge to cloud backend
- Dashboard and alerts

## 10. Risk Notes and Mitigations

- Pi Zero WLAN saturation risk:
  - keep bitrate/resolution conservative
  - apply frame skipping under load

- Startup race conditions:
  - enforce service dependencies and retries

- Codec CPU overrun:
  - prefer MJPEG/Opus presets validated on target hardware

- Field instability:
  - use watchdog restarts and health-based failover behaviors
