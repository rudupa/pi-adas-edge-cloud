# Hardware Specifications

## Table of Contents

- [1. Node Inventory](#1-node-inventory)
  - [Sensor Node](#sensor-node)
  - [UI Node](#ui-node)
  - [Gateway + Master Node](#gateway--master-node)
- [2. Connectivity and Buses](#2-connectivity-and-buses)
- [3. Performance Targets and Constraints](#3-performance-targets-and-constraints)
- [4. Power and Thermal Guidance](#4-power-and-thermal-guidance)
- [5. Storage and Boot Media](#5-storage-and-boot-media)
- [6. Recommended Bill of Materials](#6-recommended-bill-of-materials-core)
- [7. Hardware Acceptance Checklist](#7-hardware-acceptance-checklist)
- [8. Bandwidth Planning](#8-bandwidth-planning)

---

## 1. Node Inventory

### Sensor Node
- Board: Raspberry Pi Zero W v1.1 (x1)
- Pi Zero W v1.1 core specs:
  - 1GHz single-core CPU
  - 512MB RAM
  - 802.11 b/g/n 2.4GHz Wi-Fi
  - Bluetooth 4.1 + BLE
  - 40-pin HAT-compatible header, CSI camera connector
  - mini HDMI, micro-USB OTG, micro-USB power
- Camera: Raspberry Pi Camera Module (CSI via Pi Zero camera cable)
- Audio + IO HAT: Adafruit Voice Bonnet
- Voice Bonnet hardware details:
  - WM8960 I2S audio codec (stereo input/output path)
  - Two onboard microphone channels (left and right)
  - Two 1W speaker outputs
  - 3.5mm stereo headphone/line-out
  - Three onboard DotStar RGB LEDs (status/feedback)
  - Onboard push button and privacy switch
  - STEMMA QT (I2C) + 3-pin JST STEMMA expansion
- Primary roles:
  - Camera capture and low-latency video streaming
  - Microphone capture and low-latency audio streaming
  - LED status/control using 3 onboard RGB LEDs

### UI Node
- Board: Raspberry Pi Zero W v1.1 (x1)
- Pi Zero W v1.1 core specs:
  - 1GHz single-core CPU
  - 512MB RAM
  - 802.11 b/g/n 2.4GHz Wi-Fi
  - Bluetooth 4.1 + BLE
  - 40-pin HAT-compatible header, CSI camera connector
  - mini HDMI, micro-USB OTG, micro-USB power
- UI HAT: Pimoroni Pirate Audio (3W Stereo Amp variant assumed)
- Pirate Audio hardware details:
  - 1.3in IPS LCD (ST7789), 240x240 resolution
  - Four tactile buttons (active low on BCM 5, 6, 16, 24)
  - MAX98357A DAC/amplifier x2
  - Stereo 3W per channel speaker output
  - Mini HAT footprint, compatible with 40-pin Raspberry Pi headers
- Primary roles:
  - Video display output
  - Audio playback
  - Button event capture
  - Optional local voice input forwarding

### Gateway + Master Node
- Board: Raspberry Pi 4 (x1)
- AI HAT: BrainCraft HAT
- BrainCraft HAT hardware details:
  - 1.54in IPS TFT display, 240x240 resolution
  - Left + right microphone channels
  - Stereo headphone output
  - Stereo 1W speaker output terminals
  - Three RGB DotStar LEDs
  - 5-way joystick + button (local UI input)
  - Two 3-pin JST STEMMA connectors (PWM-capable expansion)
  - STEMMA QT / I2C connector (also Grove I2C compatible with adapter)
  - Audio privacy on/off switch (hardware audio disable)
  - Controllable fan for thermal support during inference workloads
- Raspberry Pi 4 hardware details:
  - Broadcom BCM2711, quad-core Cortex-A72 (64-bit) @ up to 1.8GHz
  - LPDDR4 RAM options (1GB/2GB/4GB/8GB; choose per AI workload)
  - Dual-band Wi-Fi (2.4GHz/5GHz 802.11ac), Bluetooth 5.0 + BLE
  - Gigabit Ethernet
  - 2x USB 3.0 + 2x USB 2.0
  - 2x micro-HDMI (up to 4kp60)
  - 40-pin GPIO, MIPI CSI camera, MIPI DSI display
  - USB-C power input (5V, 3A recommended)
- Primary roles:
  - Wi-Fi AP (hostapd + dnsmasq)
  - MQTT broker (Mosquitto)
  - Device discovery and message routing
  - Cloud bridge and telemetry upload
  - AI/voice inference
  - Decision logic and orchestration
  - Command and policy engine

## 2. Connectivity and Buses

### Sensor Pi Zero W
- CSI: Camera input
- I2S (via Voice Bonnet WM8960): Stereo audio input/output path
- Mic channels: Left + Right onboard microphones on Voice Bonnet
- LEDs: 3x onboard DotStar RGB LEDs on Voice Bonnet
- GPIO: optional local control inputs
- Wi-Fi 2.4 GHz: Video/audio/control transport

### UI Pi Zero W
- SPI: Pirate Audio display interface
- GPIO: Pirate Audio buttons on BCM 5/6/16/24 (active low)
- I2S/Audio codec path: Pirate Audio speaker output
- DAC control: BCM 25 enable line (Pirate Audio software flow)
- Wi-Fi 2.4 GHz: Stream reception + control uplink

### Gateway + Master Pi 4
- Wi-Fi AP mode: Infrastructure for node connectivity
- Ethernet (Gigabit): Uplink to WAN/cloud
- USB/storage (optional): Local logging buffer
- BrainCraft display: SPI-attached 240x240 local status/inference UI
- BrainCraft audio: stereo mic input + stereo headphone/speaker output
- BrainCraft local controls: 5-way joystick/button + 3x DotStar RGB LEDs
- BrainCraft expansion: 2x JST STEMMA + 1x STEMMA QT I2C port

## 3. Performance Targets and Constraints

### Pi Zero W constraints
- CPU is limited; keep codecs and pipeline simple
- Keep video resolution at 320x240 or 640x480
- Use aggressive compression and frame skipping when needed
- Avoid heavy desktop stacks and heavyweight middleware

### Latency targets (practical)
- Video glass-to-glass: sub-200 ms target, optimize toward lower
- Audio path: ~20-40 ms with Opus over UDP where feasible
- Control events (button to action): typically <100 ms on local LAN

## 4. Power and Thermal Guidance

See [power management.md](power%20management.md) for full per-node power budgets, thermal guidance, and safe shutdown requirements.

## 5. Storage and Boot Media

- OS for Pi Zero nodes: Buildroot image on microSD
- OS for Pi 4 node: Raspberry Pi OS Lite or custom Linux image
- Use high-endurance microSD where possible
- Keep logs bounded and rotate aggressively to reduce write wear

## 6. Recommended Bill of Materials (Core)

- Raspberry Pi Zero W x2
- Raspberry Pi 4 x1
- Camera module compatible with Pi Zero CSI x1
- Adafruit Voice Bonnet x1
- Pirate Audio HAT (3W Stereo Amp variant) x1
- Speakers for Pirate Audio output x1 pair
- BrainCraft HAT x1
- microSD cards x3 (size per image/logging plan)
- 5V power supplies x3
- Mechanical mounting, standoffs, and cable set

## 7. Hardware Acceptance Checklist

- All nodes boot reliably from cold power-on
- Sensor camera enumerates and captures frames
- Voice Bonnet left/right mic channels record valid stereo audio
- Voice Bonnet 3x RGB LEDs are software controllable
- Pirate Audio display/buttons/speaker are functional
- Gateway + Master node AP assigns DHCP leases to all nodes
- Gateway + Master node receives control events and sends commands

## 8. Bandwidth Planning

See [bandwidth.md](bandwidth.md) for full per-node throughput budgets, stream sizing examples, MJPEG bitrate table, and tuning rules.
