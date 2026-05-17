# System Architecture

## Table of Contents

- [System Architecture](#system-architecture)
  - [Table of Contents](#table-of-contents)
  - [1. Design Goals](#1-design-goals)
  - [2. Software Stack by Node](#2-software-stack-by-node)
    - [Sensor Node - Pi Zero W (Linux)](#sensor-node---pi-zero-w-linux)
    - [Sensor Node - Pi 4 (QNX Neutrino RTOS)](#sensor-node---pi-4-qnx-neutrino-rtos)
    - [UI Node (Pi Zero W)](#ui-node-pi-zero-w)
    - [Compute Node (Pi 5)](#compute-node-pi-5)
    - [Cloud Node (Managed or Self-Hosted)](#cloud-node-managed-or-self-hosted)
  - [3. Runtime Data Flow](#3-runtime-data-flow)
  - [4. Protocol and Topic Architecture](#4-protocol-and-topic-architecture)
    - [Media protocols](#media-protocols)
    - [Control protocol](#control-protocol)
    - [Service discovery](#service-discovery)
  - [5. Boot and Startup Strategy](#5-boot-and-startup-strategy)
    - [Pi Zero boot optimization](#pi-zero-boot-optimization)
    - [Service ordering](#service-ordering)
  - [6. Repository and Process Layout](#6-repository-and-process-layout)
    - [Language split](#language-split)
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

### Sensor Node - Pi Zero W (Linux)
- OS: Buildroot (minimal image, BusyBox init)
- Services:
  - `video_streamer`
  - `audio_streamer`
  - `device_control` (LED GPIO)
  - `mqtt_client` (status + command channel)
- Init: Auto-start via `/etc/init.d/`

### Sensor Node - Pi 4 (QNX Neutrino RTOS)
- OS: QNX Neutrino RTOS (deterministic, real-time scheduling)
- Services:
  - `audio_capture` (real-time audio acquisition, hard guarantees)
  - `sensor_fusion` (deterministic sensor aggregation with QNX scheduling)
  - `local_policy_engine` (hard real-time decision-making)
  - `mqtt_client` (status + command uplink to gateway)
  - Hardware monitoring (thermal, CPU, watchdog)
- Init: QNX init via procnto startup script
- Key advantage: Deterministic real-time behavior with microsecond-level latency guarantees

### UI Node (Pi Zero W)
- OS: Buildroot (minimal image)
- Services:
  - `video_receiver` + framebuffer renderer
  - `audio_player`
  - `button_input` publisher
  - `mqtt_client`
- UI path: Framebuffer/SDL (no X11/Wayland)

### Compute Node (Pi 5)
- OS: Linux distro optimized for AI runtime
- Services:
  - hostapd (Wi-Fi AP for multi-node mesh)
  - dnsmasq (DNS/DHCP for sensor node discovery)
  - Mosquitto MQTT broker (multi-node message broker)
  - monitoring agent (fleet-wide telemetry)
  - cloud bridge agent
  - multi-node orchestration engine (Linux + QNX node management)
  - voice recognition (Vosk preferred for offline)
  - decision logic and coordination
  - command publisher (MQTT to all nodes)
  - QNX sensor node integration layer (cross-platform messaging)
- Key upgrade: Pi 5 provides additional CPU cores and memory for managing multiple sensor nodes concurrently

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
Sensor Pi Zero (Linux):
  video_streamer  ----UDP/MJPEG---->  UI Pi Zero (display)
  audio_streamer  ----UDP/Opus----->  UI Pi Zero (speaker) / Compute Pi 5
  LED control     <---MQTT cmd------  Compute Pi 5 orchestration logic
  status telemetry ----MQTT pub------> Compute Pi 5 broker

Sensor Pi 4 (QNX):
  audio_capture   ----MQTT pub------> Compute Pi 5 broker (sensor fusion input)
  local_policy    ----MQTT events---> Compute Pi 5 coordination
  hard RT decisions <---MQTT cmd-----  Compute Pi 5 orchestration (if needed)
  sensor_fusion output ----MQTT-----> Compute Pi 5 decision engine

UI Pi Zero:
  button_input    ----MQTT event----> Compute Pi 5

Compute Pi 5:
  multi-node coordination <---MQTT pub--- (all sensor/UI nodes)
  control logic   ----MQTT cmd------> Sensor (Linux) / UI nodes
  QNX integration ----MQTT/IPC-----> Sensor Pi 4 (QNX) cross-platform mesh
  cloud uplink    ----HTTPS/MQTT TLS-> Cloud node

Cloud Node:
  telemetry ingest <----TLS---------- Compute Pi 5
  OTA policy       ----TLS----------> Compute Pi 5
  logs + metrics   <----TLS---------- Compute Pi 5
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
- UI button event -> Compute Node
- Compute Node command -> Sensor LED action

4. Gateway core
- AP mode + DHCP + MQTT broker

5. Brain services on same node
- Voice command processing on Compute Node
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
