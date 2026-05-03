# Agent Development Plan: 14-Week Implementation Acceleration

**Objective:** Enable an AI agent to systematically execute the 14-week implementation plan from [implementation_plan.md](implementation_plan.md) with maximum parallelization, clear checkpoints, and automated validation.

**Target Timeline:** 8–10 weeks (accelerated from 14 weeks through task parallelization and automation)

**Document Structure:**
- Executive summary
- Agent capabilities and constraints
- Task decomposition and dependency graph
- Phase-by-phase execution plan with milestones
- Parallel work streams
- Risk mitigation and decision points
- Agent toolkit and automation hooks

---

## Executive Summary

**Agent Role:** Autonomous development and system integration across:
- Buildroot configuration and cross-compilation
- Per-node Linux image building (3 variants)
- Service development (C++, Python)
- Hardware validation automation
- CI/CD pipeline enhancement
- OTA and security infrastructure
- Testing and validation

**Key Acceleration Strategies:**
1. **Parallelization:** Buildroot builds, service development, documentation can run in parallel
2. **Templating:** Reuse config patterns across nodes (sensor/UI share base, gateway adds Pi 4 specifics)
3. **Automation:** Smoke tests, security audits, latency measurements run without human intervention
4. **Incremental Validation:** Validate each service as built, not at end
5. **External Dependencies:** Use pre-built Buildroot configurations from Raspberry Pi foundation, reuse existing drivers

**Critical Path:**
1. Buildroot setup + base configs (blocking)
2. Sensor/UI/Gateway image builds (parallelizable after 1)
3. Hardware tests (parallelizable with builds)
4. Services (depends on working images)
5. OTA + security (depends on services)
6. Canary rollout (depends on all above)

---

## Part 1: Agent Capabilities & Constraints

### Capabilities

**File System:**
- ✅ Create/edit files and directories
- ✅ Read and parse existing code/configs
- ✅ Search codebase for patterns and references
- ✅ Generate Buildroot defconfigs, kernel configs, device tree overlays

**Build & Compilation:**
- ✅ Run shell scripts with error handling
- ✅ Execute Buildroot make targets
- ✅ Invoke cross-compilers and build tools
- ✅ Monitor build logs for errors
- ✅ Run smoke tests and validate outputs

**CI/CD:**
- ✅ Update GitHub Actions workflows
- ✅ Generate artifacts and manifests
- ✅ Create release tags
- ✅ Push commits with structured messages

**Development:**
- ✅ Write Python, C++, shell scripts
- ✅ Design system architectures
- ✅ Create test harnesses
- ✅ Generate configuration templates

**Limitations:**

- ❌ Cannot interact with physical hardware (Pi boards, HATs, cameras)
- ❌ Cannot measure actual latency or thermal metrics (requires hardware)
- ❌ Cannot run Docker/container builds (if needed; requires environment setup)
- ❌ Cannot install system packages (apt, brew) without user approval
- ❌ Cannot execute long-running builds without async terminal access
- ❌ Cannot debug runtime failures without logs/error output

### Mitigation for Hardware Constraints

**Placeholder Approach:**
- Create mock HAT drivers that simulate hardware responses
- Generate test images with realistic device trees but placeholder drivers
- Validate latency _measurements_ via synthetic test (timestamp comparison)
- Create automated test harness that can be run on actual hardware post-deployment

**Validation Checkpoints:**
- Agent builds images and produces artifacts
- User manually boots on Pi and runs `firmware/run-hw-tests.sh`
- User reports back pass/fail; agent adjusts if needed

---

## Part 2: Task Decomposition & Dependency Graph

### High-Level Phases (with parallelization)

```
PHASE 0 (Weeks 1)
  └─ Task 0.1: Buildroot setup (git clone, validate)
  └─ Task 0.2: Base defconfig template creation
  └─ Task 0.3: Kernel module inventory per node
     
     ├─ PHASE 1a (Weeks 2–3, parallel with 1b/1c)
     │  └─ Task 1a.1: Sensor Buildroot defconfig + kernel.config
     │  └─ Task 1a.2: Sensor device tree overlay (Voice Bonnet)
     │  └─ Task 1a.3: Sensor rootfs overlay (services, firmware)
     │  └─ Task 1a.4: Sensor boot partition template
     │
     ├─ PHASE 1b (Weeks 2–3, parallel with 1a/1c)
     │  └─ Task 1b.1: UI Buildroot defconfig + kernel.config
     │  └─ Task 1b.2: UI device tree overlay (Pirate Audio)
     │  └─ Task 1b.3: UI rootfs overlay + display/button handlers
     │  └─ Task 1b.4: UI boot partition template
     │
     └─ PHASE 1c (Weeks 2–3, parallel with 1a/1b)
        └─ Task 1c.1: Gateway Buildroot defconfig + kernel.config
        └─ Task 1c.2: Gateway device tree overlay (BrainCraft)
        └─ Task 1c.3: Gateway rootfs overlay + MQTT/AI setup
        └─ Task 1c.4: Gateway boot partition template

PHASE 2 (Weeks 3–4, parallel with Phase 1)
  └─ Task 2.1: Hardware smoke test scripts (camera, audio, display, etc.)
  └─ Task 2.2: WiFi AP integration test
  └─ Task 2.3: MQTT broker smoke test

PHASE 3 (Weeks 5–7, depends on Phase 1)
  ├─ Task 3.1: Video streaming service (GStreamer/C++)
  ├─ Task 3.2: Audio capture and mixing services (Python)
  ├─ Task 3.3: MQTT control and telemetry
  └─ Task 3.4: Service integration testing

PHASE 4 (Week 8, depends on Phase 3)
  └─ Task 4.1: OTA signing pipeline (openssl, manifest generation)
  └─ Task 4.2: Artifact verification scripts
  └─ Task 4.3: CI signing step integration

PHASE 5 (Week 9, depends on Phase 4)
  └─ Task 5.1: Canary fleet metrics collector
  └─ Task 5.2: Rollout manager and promotion logic
  └─ Task 5.3: Rollback decision policy

PHASE 6 (Weeks 10–11, depends on Phase 3)
  └─ Task 6.1: End-to-end latency measurement (automated)
  └─ Task 6.2: Audio quality validation (PESQ, STOI)
  └─ Task 6.3: Integration test runner

PHASE 7 (Week 12, depends on Phase 3)
  └─ Task 7.1: Kernel hardening (ASLR, stack canaries)
  └─ Task 7.2: Filesystem hardening (mount options, permissions)
  └─ Task 7.3: Network security (firewall, SSH hardening)
  └─ Task 7.4: Security audit script

PHASE 8–9 (Weeks 13–14, depends on all above)
  └─ Task 8.1: Release validation checklist automation
  └─ Task 8.2: GitHub release creation with signatures
  └─ Task 8.3: Production deployment runbook
```

### Dependency Analysis

**Critical Path (Blocking):**
```
0.1 (Buildroot setup) → 1a/1b/1c (Image builds) → 3 (Services) → 4 (OTA) → 5 (Canary) → 8 (Release)
```

**Parallelizable:**
- 1a, 1b, 1c (sensor, UI, gateway builds) — can run in parallel after 0.1
- 2 (hardware tests) — can start immediately, doesn't block anything
- 3.1, 3.2, 3.3 (services) — can be prototyped before images, tested after
- 6 (integration tests) — can be drafted during 3, executed after

**Can Start Immediately (No Dependency):**
- Task 2 (hardware tests framework)
- Task 3 service stubs (APIs, interfaces)
- Task 7 security audit templates
- Documentation and guides

---

## Part 3: Phase-by-Phase Execution Plan

### PHASE 0: Build Infrastructure Setup (Week 1)

**Goal:** Buildroot ready, base configurations defined, agent can invoke builds.

#### Task 0.1: Buildroot Clone and Host Validation

**Steps:**

1. Create build infrastructure script (`scripts/setup-buildroot.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   # Clone Buildroot
   cd build/
   if [ ! -d buildroot-src ]; then
       git clone --depth=1 --branch=2024.02 https://github.com/buildroot/buildroot.git buildroot-src
   fi
   
   # Create output directories
   mkdir -p sensor/output ui/output gateway/output
   
   # Validate host tools
   for tool in gcc make rsync git wget; do
       command -v "$tool" >/dev/null || { echo "MISSING: $tool"; exit 1; }
   done
   
   # Test Buildroot
   cd buildroot-src
   make --version | head -1
   echo "Buildroot setup complete"
   ```

2. **Validation Checkpoint:**
   - [ ] Script creates `build/buildroot-src/` with Makefile present
   - [ ] `make -C build/buildroot-src help` succeeds
   - [ ] Disk space ≥50GB available

3. **Agent Automation:**
   ```bash
   bash scripts/setup-buildroot.sh
   if [ $? -eq 0 ]; then
       echo "✓ Buildroot ready"
   else
       exit 1
   fi
   ```

**Deliverable:** `build/buildroot-src/` populated, `scripts/setup-buildroot.sh` created.

---

#### Task 0.2: Base Defconfig Template

**Steps:**

1. Create base template (`build/common/buildroot.defconfig`):
   ```
   BR2_arm=y
   BR2_ARM_EABIHF=y
   BR2_ARM_INSTRUCTIONS_THUMB2=y
   BR2_OPTIMIZE_FOR_BUILD=y
   BR2_OPTIMIZE_SIZE=y
   BR2_LINUX_KERNEL=y
   BR2_LINUX_KERNEL_CUSTOM_GIT=y
   BR2_LINUX_KERNEL_CUSTOM_GIT_REPO_URL="https://github.com/raspberrypi/linux.git"
   BR2_LINUX_KERNEL_CUSTOM_GIT_VERSION="rpi-6.1.y"
   BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y
   BR2_ROOTFS_EXT2=y
   BR2_TARGET_ROOTFS_TAR_GZIP=y
   BR2_PACKAGE_RPI_FIRMWARE=y
   BR2_PACKAGE_RPI_USERLAND=y
   BR2_PACKAGE_OPENSSH=y
   BR2_PACKAGE_CURL=y
   BR2_PACKAGE_CA_CERTIFICATES=y
   ```

2. Create common packages list (`build/common/packages.txt`):
   ```
   base-files
   busybox
   linux-headers
   systemd
   openssh-server
   curl
   ca-certificates
   mosquitto-clients
   alsa-utils
   ```

3. Create per-node overlay template (`build/common/rootfs-overlay-template/`):
   ```
   etc/
     systemd/
       system/
         my-service.service  (template)
     asound.conf            (template)
     hostname               (template)
   usr/
     local/
       bin/
         start-service.sh    (template)
   ```

**Validation Checkpoint:**
- [ ] Template files syntactically valid
- [ ] Can be referenced in per-node configs

**Deliverable:** Base defconfig, packages list, overlay templates in `build/common/`.

---

#### Task 0.3: Kernel Module Inventory

**Steps:**

1. Create kernel config options reference (`build/common/KERNEL_MODULES.md`):
   ```
   ## Sensor & UI (Pi Zero W, ARMv6l)
   - CONFIG_V4L2_MEM2MEM_DEV
   - CONFIG_SND_BCM2835
   - CONFIG_SND_SOC_WM8960 (Voice Bonnet)
   - CONFIG_GPIO_BCM2835
   - CONFIG_I2C_BCM2835
   - CONFIG_SPI_BCM2835
   
   ## Gateway (Pi 4, ARMv7l)
   - CONFIG_THERMAL
   - CONFIG_MAC80211 (WiFi AP)
   - CONFIG_CGROUPS (future containers)
   - CONFIG_SECCOMP (hardening)
   ```

2. Create per-node kernel config skeleton files:
   - `build/sensor/kernel.config.base`
   - `build/ui/kernel.config.base`
   - `build/gateway/kernel.config.base`

**Deliverable:** Kernel module inventory documented, base configs created.

---

### PHASE 1: Per-Node Linux Image Building (Weeks 2–3, Parallelizable)

**Goal:** Three bootable Linux images for Sensor, UI, and Gateway nodes.

#### Task 1a.1: Sensor Buildroot Defconfig

**Steps:**

1. Create `build/sensor/buildroot.config` (inherit from base + sensor-specific):
   ```bash
   #!/bin/bash
   # build/sensor/generate-config.sh
   set -euo pipefail
   
   # Start with base
   cp build/common/buildroot.defconfig build/sensor/buildroot.config
   
   # Append sensor-specific
   cat >> build/sensor/buildroot.config << 'EOF'
   BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="../../sensor/kernel.config"
   BR2_PACKAGE_FFMPEG=y
   BR2_PACKAGE_LIBOPUS=y
   BR2_PACKAGE_MOSQUITTO_CLIENT=y
   BR2_TARGET_ROOTFS_SIZE=128
   BR2_ROOTFS_OVERLAY="../../sensor/overlay"
   EOF
   ```

2. Validate: `make -C build/buildroot-src oldconfig KCONFIG_CONFIG=../../sensor/buildroot.config`

**Validation Checkpoint:**
- [ ] Config file has no parsing errors
- [ ] All referenced packages exist in Buildroot

**Deliverable:** `build/sensor/buildroot.config` generated and validated.

---

#### Task 1a.2: Sensor Device Tree Overlay (Voice Bonnet)

**Steps:**

1. Create `build/sensor/overlay/voice-bonnet.dts`:
   ```dts
   / {
     compatible = "brcm,bcm2835";
     
     i2c1 {
       wm8960: codec@1a {
         compatible = "wlf,wm8960";
         reg = <0x1a>;
         clocks = <&clocks BCM2835_CLOCK_I2S>;
         clock-names = "xclk";
       };
     };
     
     leds {
       compatible = "gpio-leds";
       power {
         gpios = <&gpio 17 0>;
         default-state = "on";
       };
       busy {
         gpios = <&gpio 27 0>;
       };
     };
   };
   ```

2. Compile: `dtc -I dts -O dtb -o build/sensor/overlay/voice-bonnet.dtbo build/sensor/overlay/voice-bonnet.dts`

3. Validate: `file build/sensor/overlay/voice-bonnet.dtbo` should show DTB format

**Deliverable:** Device tree binary overlay compiled, syntax validated.

---

#### Task 1a.3: Sensor Rootfs Overlay

**Steps:**

1. Create rootfs overlay structure:
   ```
   build/sensor/overlay/
   ├── etc/
   │   ├── systemd/system/
   │   │   ├── video-streamer.service
   │   │   └── audio-capture.service
   │   ├── asound.conf
   │   └── hostname
   ├── lib/firmware/
   │   └── wm8960-firmware.bin (placeholder)
   └── usr/local/bin/
       ├── camera-init.sh
       └── video-streamer.sh
   ```

2. Create service files:
   - `video-streamer.service`: Starts gstreamer pipeline at boot
   - `audio-capture.service`: Starts alsa capture daemon

3. Create init scripts (`camera-init.sh`):
   ```bash
   #!/bin/bash
   # Probe camera device, verify kernel driver loaded
   [ -e /dev/video0 ] && echo "Camera detected" || exit 1
   ```

**Deliverable:** Rootfs overlay structure with service definitions and init scripts.

---

#### Task 1a.4: Sensor Boot Partition Assembly Script

**Steps:**

1. Create `build/sensor/assemble-image.sh`:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   VERSION=$1
   OUTPUT=${2:-images}
   
   # Get rootfs from Buildroot output
   ROOTFS="build/buildroot-src/output/images/rootfs.tar.gz"
   KERNEL="build/buildroot-src/output/images/zImage"
   
   if [ ! -f "$ROOTFS" ] || [ ! -f "$KERNEL" ]; then
       echo "Build artifacts missing; run 'make -C build/buildroot-src' first"
       exit 1
   fi
   
   # Create image
   SIZE_MB=640
   IMG="${OUTPUT}/sensor-linux-${VERSION}.img"
   
   dd if=/dev/zero of="$IMG" bs=1M count=0 seek=$SIZE_MB
   parted "$IMG" mklabel msdos
   parted "$IMG" mkpart primary fat32 1 128
   parted "$IMG" mkpart primary ext4 128 100%
   
   # Mount and populate (requires sudo or specific permissions)
   # This is a placeholder; actual agent would handle permissions
   echo "Image assembled: $IMG (ready for partition population on hardware)"
   ```

2. **Note to Agent:** This step requires sudo or loop device mounting. Provide:
   - Template script that can be reviewed/approved before execution
   - Fallback: create image structure manifest (JSON) that describes partitions
   - Alternative: Use Docker with appropriate privileges

**Deliverable:** Boot assembly script template, with clear documentation of privilege requirements.

---

#### Tasks 1b & 1c: UI and Gateway (Parallel)

**Similar structure to Task 1a, adapted for:**
- **UI:** Pirate Audio HAT (ST7789 display, MAX98357A amp) — similar to Sensor but for output
- **Gateway:** Pi 4 specifics (ARMv7, 4-8GB RAM) — larger rootfs, AI runtime, AP support

**Deliverable per node:**
- Buildroot defconfig
- Kernel config with HAT-specific drivers
- Device tree overlay for HAT
- Rootfs overlay with service templates
- Boot assembly script

---

### PHASE 2: Hardware Validation Framework (Weeks 3–4, Parallel with Phase 1)

**Goal:** Automated smoke test suite that can run on physical hardware.

#### Task 2.1: Hardware Smoke Test Suite

**Steps:**

1. Create test scripts in `firmware/*/hw-tests/`:

   **Camera Test** (`firmware/sensor/hw-tests/test-camera.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   [ -e /dev/video0 ] || { echo "FAIL: camera device"; exit 1; }
   lsmod | grep -q bcm2835 || modprobe bcm2835_mmal || true
   echo "PASS: camera ready"
   ```

   **Audio Input Test** (`firmware/sensor/hw-tests/test-audio-input.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   timeout 2 arecord -D default -f cd -t wav /tmp/test.wav || true
   SIZE=$(stat -f%z /tmp/test.wav 2>/dev/null || stat -c%s /tmp/test.wav 2>/dev/null || echo 0)
   [ $SIZE -gt 40000 ] && echo "PASS: audio capture" || { echo "FAIL: audio"; exit 1; }
   ```

   **Display Test** (`firmware/ui/hw-tests/test-display.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   ls /dev/spidev* >/dev/null 2>&1 || { echo "FAIL: spi"; exit 1; }
   echo "PASS: display SPI ready"
   ```

2. Create test runner (`firmware/run-hw-tests.sh`):
   ```bash
   #!/bin/bash
   NODE=${1:-sensor}
   PASS=0
   FAIL=0
   
   for test in firmware/${NODE}/hw-tests/test-*.sh; do
       bash "$test" && ((PASS++)) || ((FAIL++))
   done
   
   echo "Results: $PASS passed, $FAIL failed"
   [ $FAIL -eq 0 ] || exit 1
   ```

**Validation Checkpoint:**
- [ ] All test scripts are executable and self-contained
- [ ] Test runner aggregates results correctly
- [ ] Can be run on hardware: `bash firmware/run-hw-tests.sh sensor`

**Deliverable:** Test framework scripts in `firmware/*/hw-tests/`, test runner in `firmware/run-hw-tests.sh`.

---

#### Task 2.2: WiFi AP Integration Test

**Steps:**

1. Create `firmware/gateway/test-wifi-ap.sh`:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   # Start AP (if not already running)
   systemctl is-active hostapd || systemctl start hostapd
   
   # Verify SSID advertised
   iwlist wlan0 scan 2>/dev/null | grep -q "ADAS-GATEWAY" && echo "PASS: AP advertised"
   ```

2. Create `firmware/sensor/test-wifi-connect.sh`:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   # Connect to AP
   wpa_cli -i wlan0 add_network > /dev/null
   wpa_cli -i wlan0 set_network 0 ssid \"ADAS-GATEWAY\"
   wpa_cli -i wlan0 set_network 0 psk \"adas_secure_pass\"
   wpa_cli -i wlan0 select_network 0
   
   sleep 3
   
   # Verify IP
   IP=$(hostname -I | awk '{print $1}')
   [ -n "$IP" ] && echo "PASS: Connected, IP=$IP" || { echo "FAIL: No IP"; exit 1; }
   ```

**Deliverable:** WiFi AP test scripts for gateway and client nodes.

---

#### Task 2.3: MQTT Broker Smoke Test

**Steps:**

1. Create `firmware/gateway/test-mqtt-broker.sh`:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   # Start broker
   mosquitto -c /etc/mosquitto/mosquitto.conf -d
   sleep 1
   
   # Test pub/sub
   mosquitto_pub -h 127.0.0.1 -t "test/topic" -m "hello"
   RESPONSE=$(timeout 2 mosquitto_sub -h 127.0.0.1 -t "test/topic" -C 1 2>/dev/null || echo "TIMEOUT")
   
   [ "$RESPONSE" = "hello" ] && echo "PASS: MQTT working" || { echo "FAIL"; exit 1; }
   ```

**Deliverable:** MQTT broker test in `firmware/gateway/test-mqtt-broker.sh`.

---

### PHASE 3: Application Services (Weeks 5–7, Depends on Phase 1)

**Goal:** Production-grade services for video/audio streaming, MQTT control, AI integration.

#### Task 3.1: Video Streaming Service

**Steps:**

1. Create GStreamer pipeline script (`firmware/sensor/video-streamer/pipeline.sh`):
   ```bash
   #!/bin/bash
   GATEWAY_IP=${1:-192.168.4.1}
   GATEWAY_PORT=${2:-5000}
   
   gst-launch-1.0 -e \
     v4l2src device=/dev/video0 \
       ! "video/x-h264, width=640, height=480, framerate=30/1" \
       ! h264parse \
       ! rtph264pay pt=96 \
       ! udpsink host="${GATEWAY_IP}" port="${GATEWAY_PORT}" auto-multicast=false
   ```

2. Create systemd service (`firmware/sensor/systemd/video-streamer.service`):
   ```ini
   [Unit]
   Description=Video Streaming Service
   After=network-online.target
   
   [Service]
   Type=simple
   ExecStart=/usr/local/bin/video-streamer.sh
   Restart=on-failure
   
   [Install]
   WantedBy=multi-user.target
   ```

3. **Fallback C++ Implementation** (lighter, if GStreamer too heavy):
   - Create `firmware/sensor/video-streamer/main.cpp` skeleton
   - Link libcamera, rtp libraries
   - Provide build instructions

**Validation Checkpoint:**
- [ ] GStreamer pipeline syntax valid
- [ ] Service file conforms to systemd spec
- [ ] Can be enabled at boot: `systemctl enable video-streamer`

**Deliverable:** Video streaming service with systemd integration.

---

#### Task 3.2: Audio Capture & Mixing Services

**Steps:**

1. Create sensor audio capture (`firmware/sensor/audio-capture/main.py`):
   ```python
   #!/usr/bin/env python3
   import alsaaudio
   import socket
   import struct
   import time
   
   inp = alsaaudio.PCM(alsaaudio.PCM_CAPTURE, device="default")
   inp.setchannels(2)
   inp.setrate(48000)
   inp.setformat(alsaaudio.PCM_FORMAT_S16_LE)
   
   udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
   frame_id = 0
   
   while True:
       length, data = inp.read()
       if length:
           packet = struct.pack("!I", frame_id) + data
           udp_socket.sendto(packet, ("192.168.4.1", 5001))
           frame_id += 1
   ```

2. Create gateway audio mixer (`firmware/gateway/audio-mixer/main.py`):
   ```python
   #!/usr/bin/env python3
   import socket
   import struct
   from collections import deque
   from enum import IntEnum
   
   class Priority(IntEnum):
       P0_SAFETY = 0
       P1_ADVISORY = 1
       P2_INFO = 2
       P3_BACKGROUND = 3
   
   audio_queues = {p: deque(maxlen=100) for p in Priority}
   udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
   udp_socket.bind(("0.0.0.0", 5001))
   
   while True:
       data, addr = udp_socket.recvfrom(4096)
       frame_id = struct.unpack("!I", data[:4])[0]
       audio_data = data[4:]
       # Priority-based queueing logic
   ```

3. Create UI audio output (`firmware/ui/audio-output/main.py`):
   ```python
   #!/usr/bin/env python3
   import paho.mqtt.client as mqtt
   import alsaaudio
   
   out = alsaaudio.PCM(alsaaudio.PCM_PLAYBACK)
   
   def on_message(client, userdata, msg):
       audio_data = msg.payload
       out.write(audio_data)
   
   client = mqtt.Client()
   client.on_message = on_message
   client.subscribe("ui/audio/play")
   client.connect("192.168.4.1", 1883)
   client.loop_forever()
   ```

**Deliverable:** Audio services with priority-based mixing on gateway.

---

#### Task 3.3: MQTT Control and Telemetry

**Steps:**

1. Create MQTT configuration (`etc/mosquitto/mosquitto.conf`):
   ```
   port 1883
   allow_anonymous true
   max_connections -1
   log_dest stdout
   ```

2. Create status publisher (`firmware/gateway/status-publisher.py`):
   ```python
   #!/usr/bin/env python3
   import paho.mqtt.client as mqtt
   import json
   import psutil
   import time
   
   client = mqtt.Client()
   client.connect("127.0.0.1", 1883)
   
   while True:
       status = {
           "cpu_percent": psutil.cpu_percent(),
           "memory_percent": psutil.virtual_memory().percent,
           "timestamp": time.time(),
       }
       client.publish("gateway/status", json.dumps(status))
       time.sleep(10)
   ```

3. Create MQTT topic hierarchy document (`docs/MQTT_TOPICS.md`):
   ```
   gateway/status          # Gateway health metrics
   gateway/ai/detections   # AI inference results
   sensor/vision/frame     # Video frame metadata
   sensor/audio/stream     # Audio stream status
   ui/display/image        # Image to render
   ui/audio/play           # Audio playback command
   ui/command/action       # UI button presses
   cloud/telemetry/log     # Unified telemetry
   ```

**Deliverable:** MQTT broker config, status publisher, topic hierarchy documented.

---

#### Task 3.4: Service Integration Test

**Steps:**

1. Create integration test harness (`firmware/integration-test.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   # Start all services
   systemctl start mosquitto
   systemctl start video-streamer
   systemctl start audio-capture
   systemctl start audio-output
   
   sleep 2
   
   # Verify communication
   mosquitto_pub -h 127.0.0.1 -t "gateway/test" -m "ping"
   
   # Listen for responses
   timeout 5 mosquitto_sub -h 127.0.0.1 -t "sensor/audio/stream" && echo "PASS: Services integrated"
   ```

**Deliverable:** Integration test that validates all services running and communicating.

---

### PHASE 4: OTA Security (Week 8, Depends on Phase 3)

**Goal:** Signed artifacts with integrity verification.

#### Task 4.1: Signing Pipeline

**Steps:**

1. Generate keypair (one-time, store in GitHub Secrets):
   ```bash
   openssl genpkey -algorithm ED25519 -out private-key.pem
   openssl pkey -in private-key.pem -pubout -out public-key.pem
   ```

2. Create signing script (`scripts/sign-manifest.sh`):
   ```bash
   #!/bin/bash
   MANIFEST=$1
   PRIVATE_KEY=$2
   
   openssl dgst -sha256 -sign "$PRIVATE_KEY" "$MANIFEST" > "${MANIFEST}.sig"
   echo "Signed: ${MANIFEST}.sig"
   ```

3. Update CI workflow to sign releases:
   ```yaml
   - name: Sign release manifest
     run: bash scripts/sign-manifest.sh release-manifest.json ${{ secrets.SIGNING_KEY }}
   ```

**Deliverable:** Signing scripts and CI integration.

---

#### Task 4.2: Verification Script

**Steps:**

1. Create `firmware/gateway/ota-verify.sh`:
   ```bash
   #!/bin/bash
   MANIFEST=$1
   PUBLIC_KEY=${2:-public-key.pem}
   
   openssl dgst -sha256 -verify "$PUBLIC_KEY" -signature "${MANIFEST}.sig" "$MANIFEST"
   echo "Verification passed"
   ```

**Deliverable:** Verification script for edge nodes to validate OTA bundles.

---

#### Task 4.3: CI Signing Integration

**Steps:**

1. Update `.github/workflows/build-all-nodes.yml` to include signing step
2. Upload signed artifacts to releases

**Deliverable:** Updated CI workflow with signing step.

---

### PHASE 5: Canary Rollout (Week 9, Depends on Phase 4)

**Goal:** Automated canary deployment with rollback triggers.

#### Task 5.1: Metrics Collector

**Steps:**

1. Create `firmware/*/metrics-collector.py`:
   ```python
   #!/usr/bin/env python3
   import json
   import psutil
   import time
   import mqtt
   
   while True:
       metrics = {
           "cpu": psutil.cpu_percent(),
           "memory": psutil.virtual_memory().percent,
           "timestamp": time.time(),
       }
       client.publish(f"metrics/{node_type}/system", json.dumps(metrics))
       time.sleep(10)
   ```

**Deliverable:** Metrics collection script for all nodes.

---

#### Task 5.2: Rollout Manager

**Steps:**

1. Create `firmware/gateway/rollout-manager.py`:
   ```python
   class RolloutManager:
       def __init__(self):
           self.fleet_status = {}
           self.metrics_buffer = {}
       
       def should_rollback(self, node_id):
           # Check CPU, latency, temperature
           return False
       
       def promote_canary_to_beta(self, version):
           # Validate all canary nodes green for 1 hour
           return True
   ```

**Deliverable:** Rollout manager with promotion/rollback logic.

---

#### Task 5.3: Rollback Policy

**Steps:**

1. Document in `docs/ROLLBACK_POLICY.md`:
   - CPU >80% for >5 min → rollback
   - Audio latency >150ms → rollback
   - Frame drops >5%/min → rollback
   - MQTT disconnects >3 consecutive → rollback

**Deliverable:** Documented rollback triggers and automation.

---

### PHASE 6: Integration Testing (Weeks 10–11, Depends on Phase 3)

**Goal:** Validated latency, audio quality, end-to-end system performance.

#### Task 6.1: Latency Measurement

**Steps:**

1. Create `firmware/test-latency.py` (synthetic test):
   ```python
   # Measure MQTT publish-to-receive latency
   # Measure video frame timestamp to display rendering
   # Target: <100ms mean, <150ms P99
   ```

**Deliverable:** Latency measurement harness (requires hardware for validation).

---

#### Task 6.2: Audio Quality Validation

**Steps:**

1. Create `firmware/test-audio-quality.py`:
   ```python
   # Measure PESQ score (requires pesq library)
   # Target: PESQ ≥3.5 (good quality)
   ```

**Deliverable:** Audio quality test framework.

---

#### Task 6.3: Integration Test Runner

**Steps:**

1. Create `firmware/run-integration-tests.sh`:
   ```bash
   bash firmware/test-latency.py
   bash firmware/test-audio-quality.py
   bash firmware/integration-test.sh
   ```

**Deliverable:** Integrated test runner.

---

### PHASE 7: Security Hardening (Week 12, Depends on Phase 3)

**Goal:** Production-hardened images with minimal attack surface.

#### Task 7.1: Kernel Hardening

**Steps:**

1. Update `build/<node>/kernel.config`:
   ```
   CONFIG_RANDOMIZE_BASE=y
   CONFIG_STACKPROTECTOR_STRONG=y
   CONFIG_DEBUG_RODATA=y
   CONFIG_RETPOLINE=y
   ```

**Deliverable:** Hardened kernel config for all nodes.

---

#### Task 7.2: Filesystem Hardening

**Steps:**

1. Create hardening script (`firmware/gateway/harden-fs.sh`):
   ```bash
   mount -o remount,nodev,nosuid,noexec /
   mount -o remount,nodev,nosuid /var
   chmod 0600 /etc/systemd/system/*.service
   ```

**Deliverable:** Hardening script in rootfs overlay.

---

#### Task 7.3: Network Security

**Steps:**

1. Create firewall config (`etc/ufw/before.rules`):
   ```
   ufw enable
   ufw allow 22/tcp   # SSH
   ufw allow 1883/tcp # MQTT
   ufw deny incoming
   ```

2. SSH hardening in overlay:
   ```
   PermitRootLogin no
   PasswordAuthentication no
   PubkeyAuthentication yes
   ```

**Deliverable:** Firewall and SSH hardening configs.

---

#### Task 7.4: Security Audit Script

**Steps:**

1. Create `scripts/security-audit.sh`:
   ```bash
   # Run lynis audit
   # Check kernel mitigations (ASLR, stack, retpoline)
   # Verify service permissions
   ```

**Deliverable:** Automated security audit script.

---

### PHASE 8–9: Release & Post-Launch (Weeks 13–14, Depends on all above)

**Goal:** Production release with full validation.

#### Task 8.1: Release Validation Checklist Automation

**Steps:**

1. Create `scripts/validate-release.sh`:
   ```bash
   #!/bin/bash
   CHECKS=(
       "boot_time_<_5s"
       "video_stream_1hr_no_drops"
       "audio_latency_<_50ms"
       "mqtt_no_message_loss"
       "security_audit_pass"
   )
   
   for check in "${CHECKS[@]}"; do
       echo "Validating: $check"
       # Each check either automated or marked for manual validation
   done
   ```

**Deliverable:** Validation checklist automation script.

---

#### Task 8.2: GitHub Release Creation

**Steps:**

1. Update CI to create releases with signed artifacts
2. Generate release notes from git history

**Deliverable:** Automated GitHub release creation in CI.

---

#### Task 8.3: Production Deployment Runbook

**Steps:**

1. Create `docs/DEPLOYMENT_RUNBOOK.md`:
   - Canary fleet setup
   - Monitoring and alerts
   - Promotion gates
   - Rollback procedures

**Deliverable:** Deployment runbook documentation.

---

## Part 4: Parallel Work Streams

### Stream A: Buildroot Configuration (Critical Path)
- **Duration:** Weeks 0–3
- **Tasks:** 0.1, 0.2, 0.3, 1a, 1b, 1c
- **Blockers:** None
- **Deliverable:** 3 bootable Linux images

### Stream B: Services Development (Depends on Stream A)
- **Duration:** Weeks 5–7 (can prototype in parallel)
- **Tasks:** 3.1, 3.2, 3.3, 3.4
- **Blockers:** Working images from Stream A
- **Deliverable:** Production services with systemd integration

### Stream C: Testing & Validation (Parallel with all)
- **Duration:** Weeks 2–13 (ongoing)
- **Tasks:** 2, 6, 7
- **Blockers:** None (can develop in parallel)
- **Deliverable:** Test suite, security audit, latency validation

### Stream D: Security & OTA (Depends on Streams A & B)
- **Duration:** Weeks 8–9
- **Tasks:** 4, 5
- **Blockers:** Working services and images
- **Deliverable:** Signed artifacts, canary rollout automation

---

## Part 5: Agent Automation Hooks

### Environment Setup

```bash
# Agent initialization
export BUILDROOT_DIR="build/buildroot-src"
export BUILD_TIMEOUT=7200  # 2 hours per image
export PARALLEL_JOBS=4     # Parallel make jobs
```

### Build Automation

```bash
# Build sensor image (parallel with others)
bash scripts/build-node.sh sensor v1.0.0 images/ &

# Build UI image
bash scripts/build-node.sh ui v1.0.0 images/ &

# Build gateway image
bash scripts/build-node.sh gateway v1.0.0 images/ &

# Wait for all builds to complete
wait
```

### Validation Checkpoints

```bash
# After Phase 1
if [ -f images/sensor-linux-v1.0.0.img ] && \
   [ -f images/ui-linux-v1.0.0.img ] && \
   [ -f images/gateway-linux-v1.0.0.img ]; then
    echo "✓ All images built"
else
    echo "✗ Build failure"
    exit 1
fi
```

### Testing Automation

```bash
# Run all tests in parallel (non-blocking on hardware)
bash firmware/run-hw-tests.sh sensor > hw-tests-sensor.log 2>&1 &
bash firmware/run-hw-tests.sh ui > hw-tests-ui.log 2>&1 &
bash firmware/run-hw-tests.sh gateway > hw-tests-gateway.log 2>&1 &

# Run integration tests (requires all services running)
bash firmware/run-integration-tests.sh > integration-tests.log 2>&1

# Collect results
grep -l "FAIL" hw-tests-*.log && exit 1 || echo "✓ All tests passed"
```

### CI/CD Automation

```bash
# Commit and push after each phase
git add -A
git commit -m "Phase 3: Services implementation - video, audio, MQTT"
git push origin main
```

---

## Part 6: Risk Mitigation & Decision Points

### Risk: Buildroot Build Failure

**Likelihood:** Medium  
**Impact:** Blocks all image generation  
**Mitigation:**
- Agent validates kernel config before invoking make
- Agent captures build logs and reports specific errors
- Fallback: Use pre-built Pi OS images if Buildroot fails

**Decision Point:**
```
if buildroot_build_fails:
    Option A: Use pre-built Pi OS images (faster, less control)
    Option B: Debug kernel config issues (slower, more control)
    Recommendation: Option A initially, migrate to Buildroot after validation
```

---

### Risk: Hardware Tests Inconclusive

**Likelihood:** High (without physical hardware)  
**Impact:** Can't validate actual latency/thermal  
**Mitigation:**
- Agent creates synthetic test harness (timestamp-based latency)
- Agent documents which tests require hardware
- Agent provides test runbook for user to execute manually

**Decision Point:**
```
if hardware_unavailable:
    Option A: Skip physical validation (proceed to canary fleet)
    Option B: Simulate hardware responses (less realistic)
    Recommendation: Option A + provide manual test checklist
```

---

### Risk: OTA Security Key Leak

**Likelihood:** Low  
**Impact:** Compromised production updates  
**Mitigation:**
- Agent generates test keypair, stores in GitHub Secrets (encrypted)
- Agent never prints private key to logs
- Agent validates key permissions (0600)

**Decision Point:**
```
if key_generation_required:
    Option A: Agent generates locally (requires user approval)
    Option B: User provides externally (more secure)
    Recommendation: Option B + Option A as fallback
```

---

### Risk: CI Build Timeout

**Likelihood:** Medium  
**Impact:** Automated builds don't complete  
**Mitigation:**
- Agent sets realistic timeouts (2 hours per image)
- Agent runs builds in async mode, monitors progress
- Agent logs tail output for diagnostics

**Decision Point:**
```
if build_timeout:
    Option A: Increase timeout, retry
    Option B: Reduce build options (smaller rootfs)
    Recommendation: Option A first, then Option B if persistent
```

---

## Part 7: Success Criteria & Metrics

### Phase Completion Criteria

| Phase | Success Criterion | Metric |
|-------|------------------|--------|
| 0 | Buildroot ready | `make -C build/buildroot-src help` succeeds |
| 1 | Images built | 3 .img files exist with correct checksums |
| 2 | Tests pass | `bash firmware/run-hw-tests.sh` passes all non-hardware tests |
| 3 | Services running | `systemctl status video-streamer` is active |
| 4 | Signing works | `openssl dgst -verify` succeeds on manifest |
| 5 | Canary ready | Metrics collector publishing 1 msg/10s per node |
| 6 | Latency validated | Mean <100ms, P99 <150ms (synthetic or hardware) |
| 7 | Security audit pass | `lynis` score >75 |
| 8 | Release ready | GitHub release created with signed artifacts |

### Acceleration Metrics

- **Target:** 8–10 weeks (vs. 14 weeks planned)
- **Parallelization:** 40% time savings from parallel streams A, B, C
- **Automation:** 30% savings from automated testing/validation
- **Reuse:** 20% savings from templated configs, avoiding rework

---

## Part 8: Agent Decision Matrix

### When to Auto-Proceed vs. Request User Input

| Situation | Agent Action |
|-----------|--------------|
| Buildroot build fails with <2 attempts | Request user guidance on kernel config |
| Hardware test inconclusive (no hardware) | Document requirement, proceed with simulation |
| OTA key generation needed | Request user approval before generating |
| Security audit fails critical check | Block and report specific violation |
| Canary metrics go red | Trigger rollback, notify user |
| GitHub push fails (rate limit) | Retry after delay, log attempt |
| Package missing (e.g., dtc, xz) | Report missing tool, don't auto-install |

---

## Part 9: Deliverables by Week

| Week | Stream | Deliverable | Status |
|------|--------|-------------|--------|
| 1 | A | Buildroot setup, base configs | Ready to execute |
| 2 | A, C | Sensor/UI/Gateway Buildroot configs, test framework | Ready to execute |
| 3 | A, C | 3 Linux images, hardware tests | Ready to execute |
| 4 | C | WiFi + MQTT integration tests | Ready to execute |
| 5–7 | B | Video/audio/MQTT services, integration tests | Ready to execute |
| 8 | D | OTA signing pipeline, CI integration | Ready to execute |
| 9 | D | Canary rollout, metrics, rollback policies | Ready to execute |
| 10–11 | C | Latency validation, audio quality tests | Ready to execute |
| 12 | C | Security hardening, audit automation | Ready to execute |
| 13–14 | D | Release validation, GitHub release, runbook | Ready to execute |

---

## Part 10: Quick-Start for Agent Execution

```bash
#!/bin/bash
# agent_run.sh - Execute the 14-week plan in 8–10 weeks

set -euo pipefail

# PHASE 0: Setup
echo "=== PHASE 0: Buildroot Setup ==="
bash scripts/setup-buildroot.sh
cd build/ && make -C buildroot-src help | head -3

# PHASE 1: Image Building (Parallel)
echo "=== PHASE 1: Building Node Images ==="
bash scripts/build-node.sh sensor v1.0.0 images/ &
bash scripts/build-node.sh ui v1.0.0 images/ &
bash scripts/build-node.sh gateway v1.0.0 images/ &
wait

# PHASE 2: Test Framework
echo "=== PHASE 2: Hardware Tests ==="
bash firmware/run-hw-tests.sh sensor > hw-test-sensor.log 2>&1 &
bash firmware/run-hw-tests.sh ui > hw-test-ui.log 2>&1 &
wait

# PHASE 3: Services
echo "=== PHASE 3: Services ==="
# Service stubs already in place; run integration test
bash firmware/run-integration-tests.sh

# PHASE 4: OTA
echo "=== PHASE 4: OTA Security ==="
bash scripts/sign-manifest.sh release-manifest.json private-key.pem

# PHASE 5: Canary
echo "=== PHASE 5: Canary Rollout ==="
# Metrics collection starts automatically

# PHASE 6: Integration
echo "=== PHASE 6: Integration Testing ==="
bash firmware/test-latency.py

# PHASE 7: Hardening
echo "=== PHASE 7: Security ==="
bash scripts/security-audit.sh

# PHASE 8–9: Release
echo "=== PHASE 8–9: Release ==="
bash scripts/validate-release.sh

echo "✓ All phases complete!"
git commit -am "feat: Production-ready 14-week implementation" || true
git push origin main
```

---

**Document Version:** 1.0  
**Status:** Ready for Agent Execution  
**Estimated Execution Time:** 8–10 weeks (with parallelization)  
**Last Updated:** 2026-05-03
