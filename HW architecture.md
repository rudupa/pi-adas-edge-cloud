# Hardware Architecture

## Table of Contents

- [1. Physical Node Topology](#1-physical-node-topology)
- [2. Interconnect Model](#2-interconnect-model)
- [3. Node-Level Hardware Responsibilities](#3-node-level-hardware-responsibilities)
- [4. Deployment Zones](#4-deployment-zones)
- [5. Hardware Architecture Diagram](#5-hardware-architecture-diagram)
- [6. Reliability and Serviceability Notes](#6-reliability-and-serviceability-notes)
- [7. Security Boundaries](#7-security-boundaries)

---

## 1. Physical Node Topology

- Sensor Node (Pi Zero W + Camera + Voice Bonnet) handles sensing and edge media generation.
- UI Node (Pi Zero W + Pirate Audio) handles local human interaction (display, buttons, speaker).
- Gateway + Master Node (Pi 4 + BrainCraft) provides local wireless infrastructure, edge-to-cloud bridge, coordination logic, and AI processing.
- Cloud Node (managed or self-hosted) provides telemetry storage, centralized logging, OTA rollout control, and fleet dashboards.

## 2. Interconnect Model

### Wireless fabric
- All nodes join a private WLAN created by the Gateway + Master Node.
- Gateway + Master node provides:
  - DHCP
  - Local DNS (optional)
  - Service endpoints for MQTT and API

### Data plane separation
- Media traffic (video/audio) uses low-latency unicast streams (primarily UDP-based).
- Control and telemetry use MQTT topics over TCP.
- Gateway bridges selected telemetry/logging streams to Cloud Node over TLS.
- OTA commands and manifests flow from Cloud Node to Gateway, then to edge nodes.

## 3. Node-Level Hardware Responsibilities

### Sensor Node wiring and role
- CSI camera connected directly to Pi Zero camera interface.
- Voice Bonnet attached to Pi Zero GPIO header for audio I/O.
- LED outputs mapped to GPIO pins for remote control.
- Captures media and transmits to UI/Gateway+Master endpoints.

### UI Node wiring and role
- Pirate Audio HAT mounted on Pi Zero GPIO header.
- Display receives decoded stream for local visualization.
- Buttons generate event messages to Gateway + Master via MQTT.
- Speaker renders incoming audio stream/commands.

### Gateway + Master Node wiring and role
- Onboard Wi-Fi runs AP mode for isolated local network.
- Optional Ethernet uplink for internet/cloud.
- BrainCraft HAT attached to Pi 4 for accelerated/structured AI tasks.
- Hosts Mosquitto, network services, and monitoring agents.
- Receives events (buttons, sensor status), performs inference, publishes commands.
- Reports summarized state to cloud via gateway services.

## 4. Deployment Zones

- Zone A: Real-time edge media
  - Sensor and UI nodes
  - Prioritize low latency over perfect reliability

- Zone B: Edge control intelligence + gateway boundary
  - Gateway + Master node
  - Prioritize security, observability, and connectivity resilience

## 5. Hardware Architecture Diagram

```text
                     +-------------------------------------+
                     |     Gateway + Master Pi 4          |
                     | AP + DHCP + MQTT + Cloud + AI/CTL  |
                     |            BrainCraft HAT           |
                     +------------------+------------------+
                                        |
                             Private 2.4 GHz WLAN
             +--------------------------+--------------------------+
             |                                                     |
+------------+------------+                           +------------+------------+
|      Sensor Pi Zero     |                           |        UI Pi Zero       |
|    Camera + VoiceHat    |                           |     Pirate Audio HAT    |
|   Video/Audio TX + LED  |                           |  Display/Buttons/Speaker|
+-------------------------+                           +-------------------------+
```

## 6. Reliability and Serviceability Notes

- Keep node services independent so one failure does not cascade.
- Use watchdogs on each node to restart failed media/control services.
- Ensure hardware access paths (SSH/serial) for recovery.
- Reserve static DHCP leases for easier diagnostics.

## 7. Security Boundaries

- WLAN protected with WPA2 passphrase.
- MQTT broker requires authentication.
- Only the Gateway + Master node communicates with Cloud Node over TLS/mTLS.
- OTA artifacts and manifests must be signed and verified before install.
- Limit inbound firewall exposure to maintenance channels.
