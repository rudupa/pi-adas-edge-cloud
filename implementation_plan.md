# Implementation Plan: pi-adas-edge-cloud Production Deployment

**Objective:** Transform the pi-adas-edge-cloud repository from placeholder build scaffolding to production-ready Linux images for all 4 nodes (Sensor Pi Zero W, UI Pi Zero W, Gateway Pi 4, Cloud runtime) with validated hardware integration, secure OTA, and end-to-end testing.

**Timeline:** 14 weeks (approximate, parallelizable phases)  
**Success Criteria:** All 4 nodes boot in <5s, pass hardware validation, stream latency <100ms, audio quality ≥4/5, OTA rollback functional, canary fleet metrics passing gates.

---

## Phase 0: Build Infrastructure Setup (Week 1)

### 0.1 Buildroot Clone and Toolchain Bootstrap

**Deliverable:** Buildroot source tree with cross-compiler and build host validated.

**Steps:**

1. Clone Buildroot stable branch:
   ```bash
   cd build/
   git clone --depth=1 --branch=2024.02 https://github.com/buildroot/buildroot.git buildroot-src
   ```

2. Create toolchain directory:
   ```bash
   mkdir -p toolchain/{sensor,ui,gateway}
   ```

3. Build host validation script (`scripts/validate-host.sh`):
   - Check for required packages: `build-essential`, `libncurses-dev`, `bc`, `rsync`, `git`, `wget`, `gcc-arm-linux-gnueabihf` (if cross-compiling on non-ARM host)
   - Verify disk space ≥50 GB per node build (Buildroot output can be large)
   - Test Buildroot source by running `make menuconfig` on a minimal config

4. Download and cache Buildroot external trees:
   - Raspberry Pi kernel patches from: https://github.com/raspberrypi/linux/
   - Adafruit HAT kernel module sources (Voice Bonnet WM8960, etc.)
   - Download into `build/external-sources/` for offline builds

5. Document in `BUILD_SETUP.md`:
   - Host OS and version tested (e.g., Ubuntu 22.04 LTS, macOS 13+)
   - Estimated build time per node (45–90 min Buildroot builds)
   - Toolchain cache strategy and size estimates

**Validation:**
- `./scripts/validate-host.sh` passes all checks
- Buildroot `make help` works without errors
- External sources downloaded to cache

---

### 0.2 Define Base Buildroot Configuration Strategy

**Deliverable:** Base `.config` fragments and common rootfs packages list.

**Steps:**

1. Create base defconfig directory structure:
   ```
   build/
   ├── sensor/
   │   ├── buildroot.config
   │   ├── kernel.config
   │   ├── packages.txt
   │   └── overlay/
   ├── ui/
   │   ├── buildroot.config
   │   ├── kernel.config
   │   ├── packages.txt
   │   └── overlay/
   ├── gateway/
   │   ├── buildroot.config
   │   ├── kernel.config
   │   ├── packages.txt
   │   └── overlay/
   ```

2. Base Buildroot configuration template (`build/common/buildroot.defconfig`):
   - Enable: `BR2_arm=y`, `BR2_cortex_a8=y` (Pi Zero)
   - Kernel version: 6.1+ (for driver stability)
   - Init system: OpenRC (lightweight) or systemd (if ≥512 MB available)
   - C library: musl (lighter) or glibc (standard)
   - Package format: tar.gz (for SD card flashing)
   - Filesystem: ext4 (standard)
   - Compression: gzip (balance speed/ratio)

3. Common packages list (`build/common/packages.txt`):
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
   v4l-utils (camera control)
   ```

4. Per-node specific packages:
   - **Sensor:** libcamera or raspberrypi-userland, ffmpeg (h.264 encoding), gstreamer, libopus
   - **UI:** libdrm (display), python3, bluez (BT speakers), pirate-audio-driver (if available)
   - **Gateway:** apache2 or nginx (admin console), mosquitto (MQTT broker), tensorflow-lite, nodejs (alternative runtime)

5. Document strategy in `BUILD_STRATEGY.md`:
   - Rationale for init system choice
   - Storage footprint estimates (root partition size per node)
   - Build time optimization (ccache, parallel jobs)

**Validation:**
- Buildroot configuration files parse without errors: `make -C build/buildroot-src defconfig DEFCONFIG=../sensor/buildroot.config`
- Packages list cross-checked against Buildroot available packages

---

## Phase 1: Per-Node Linux Image Building (Weeks 2–3)

### 1.1 Sensor Node Buildroot Configuration

**Deliverable:** Bootable Linux image for Sensor Pi Zero W with camera and audio HAT support.

**Hardware Target:**
- Raspberry Pi Zero W v1.1 (ARMv6l, 512 MB RAM)
- Adafruit Voice Bonnet (WM8960 audio codec, 2× mics, 1× speaker output, RGB LEDs, 4× buttons)
- CSI camera connection

**Steps:**

1. **Kernel Configuration** (`build/sensor/kernel.config`):
   ```
   # Device Drivers
   CONFIG_BCM2835_MBOX=y                   # Raspberry Pi mailbox
   CONFIG_BCM2835_VCHIQ=y                  # VCHI queue (firmware communication)
   CONFIG_I2C_BCM2835=y                    # I2C for codec/sensor control
   CONFIG_SND_BCM2835=y                    # Built-in audio (fallback)
   CONFIG_SND_SOC_WM8960=m                 # Voice Bonnet codec
   CONFIG_SND_SOC_SIMPLE_CARD=m            # ASoC simple card
   CONFIG_V4L2_MEM2MEM_DEV=y               # Video4Linux memory-to-memory
   CONFIG_VIDEO_V4L2=y                     # Camera video device
   CONFIG_USB_GADGET=y                     # USB OTG (optional, for flashing)
   CONFIG_GPIO_BCM2835=y                   # GPIO for LEDs/buttons
   CONFIG_GPIOLIB_IRQCHIP=y                # GPIO interrupt support
   
   # Networking
   CONFIG_WIRELESS=y
   CONFIG_CFG80211=y
   CONFIG_MAC80211=y                       # 802.11 stack for WiFi
   CONFIG_NL80211_TESTMODE=y
   ```

2. **Buildroot Defconfig** (`build/sensor/buildroot.config`):
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
   BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="../sensor/kernel.config"
   BR2_ROOTFS_EXT2=y
   BR2_TARGET_ROOTFS_TAR_GZIP=y
   BR2_TARGET_ROOTFS_TAR_PACKDIR="images"
   BR2_PACKAGE_RPI_FIRMWARE=y
   BR2_PACKAGE_RPI_USERLAND=y
   BR2_PACKAGE_ALSA_LIB=y
   BR2_PACKAGE_ALSA_UTILS=y
   BR2_PACKAGE_FFMPEG=y
   BR2_PACKAGE_FFMPEG_ENCODERS="libx264 libopus"
   BR2_PACKAGE_LIBOPUS=y
   BR2_PACKAGE_MOSQUITTO_CLIENT=y
   BR2_PACKAGE_OPENSSH=y
   BR2_PACKAGE_CURL=y
   BR2_PACKAGE_PYTHON3=y
   BR2_ROOTFS_OVERLAY="../sensor/overlay"
   BR2_TARGET_ROOTFS_SIZE=128
   BR2_TARGET_ROOTFS_SIZE_PERCENTAGE=20
   ```

3. **Root Filesystem Overlay** (`build/sensor/overlay/`):
   - `etc/config/network/interfaces` – WiFi SSID/PSK or DHCP client
   - `etc/systemd/network/` – systemd-networkd config if using systemd
   - `etc/systemd/system/video-streamer.service` – Video capture/stream service
   - `etc/systemd/system/audio-capture.service` – Audio capture service
   - `lib/firmware/` – Audio codec firmware
   - `usr/local/bin/camera-init.sh` – Camera device probe and test
   - `etc/asound.conf` – ALSA device mapping for Voice Bonnet

4. **Camera and Audio Device Tree Binding** (`build/sensor/overlay/etc/device-tree-patch.dts`):
   ```
   / {
     compatible = "brcm,bcm2835";
     
     // Voice Bonnet I2C audio codec
     i2c1 {
       wm8960: codec@1a {
         compatible = "wlf,wm8960";
         reg = <0x1a>;
         clocks = <&clocks BCM2835_CLOCK_I2S>;
         clock-names = "xclk";
         wlf,shared-lrclk;
       };
     };
     
     // GPIO LEDs on Voice Bonnet
     leds {
       compatible = "gpio-leds";
       power {
         gpios = <&gpio 17 0>; // Pin 17 -> Red LED
         default-state = "on";
       };
       busy {
         gpios = <&gpio 27 0>; // Pin 27 -> Green LED
       };
     };
   };
   ```

5. **Device Tree Overlay Compilation** (in build script):
   ```bash
   cd build/sensor/
   dtc -I dts -O dtb -o overlay/voice-bonnet.dtbo overlay/voice-bonnet.dts
   ```

6. **Buildroot Build Command** (`build/sensor/build.sh` update):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   BUILD_DIR="${BUILDROOT_DIR:-build/buildroot-src}"
   CONFIG_FILE="$(cd "$(dirname "$0")" && pwd)/buildroot.config"
   OUTPUT_DIR="${BUILD_DIR}/output"
   
   # Copy defconfig
   cp "${CONFIG_FILE}" "${BUILD_DIR}/.config"
   
   # Build Buildroot
   make -C "${BUILD_DIR}" all
   
   # Copy image artifacts
   cp "${OUTPUT_DIR}/images/rootfs.tar.gz" "images/sensor-rootfs-${VERSION}.tar.gz"
   cp "${OUTPUT_DIR}/images/zImage" "images/sensor-kernel-${VERSION}"
   ```

**Validation:**
- `make -C build/buildroot-src sensor_config` produces `build/sensor/buildroot.config`
- Buildroot build completes: check `build/buildroot-src/output/images/` for `zImage`, `rootfs.tar.gz`
- Device tree overlay compiles without dtc errors
- Run smoke test: extract rootfs, verify `/lib/modules/$(uname -r)/` has audio drivers

---

### 1.2 UI Node Buildroot Configuration

**Deliverable:** Bootable Linux image for UI Pi Zero W with display and audio output support.

**Hardware Target:**
- Raspberry Pi Zero W v1.1 (ARMv6l, 512 MB RAM)
- Pimoroni Pirate Audio HAT (ST7789 SPI TFT display, MAX98357A amplifier, buttons)
- No camera

**Steps:**

1. **Kernel Configuration** (`build/ui/kernel.config` – differences from sensor):
   ```
   # No camera/CSI (or minimal V4L2)
   # No CONFIG_VIDEO_RASPBERRYPI_ISP
   
   # SPI for display
   CONFIG_SPI_BCM2835=y
   CONFIG_SPI_BCM2835_DMA=y
   CONFIG_PINCTRL_BCM2835=y
   CONFIG_GPIO_SYSFS=y                     # User-space GPIO control
   
   # Display drivers
   CONFIG_BACKLIGHT_CLASS_DEVICE=y
   CONFIG_LCD_CLASS_DEVICE=y
   CONFIG_FB_SPI=m                         # SPI framebuffer
   CONFIG_DRM=y                            # Direct Rendering Manager
   CONFIG_DRM_MIPI_DSI=y                   # DSI display support
   CONFIG_DRM_VC4=y                        # VideoCore IV (GPU display)
   
   # Audio (I2S amplifier)
   CONFIG_SND_SOC_MAX98357A=m              # Pirate Audio amp
   CONFIG_SND_SOC_SIMPLE_CARD_UTILS=m
   ```

2. **Buildroot Defconfig** (`build/ui/buildroot.config` – inherit from sensor + display packages):
   ```
   # Inherit all base configs from sensor
   # Additional packages:
   BR2_PACKAGE_LIBDRM=y                    # DRM library
   BR2_PACKAGE_LIBPNG=y                    # PNG graphics
   BR2_PACKAGE_FREETYPE=y                  # Font rendering
   BR2_PACKAGE_SDL2=y                      # Simple DirectMedia Layer
   BR2_PACKAGE_PYTHON3_PYGAME=y            # Python game/graphics lib
   BR2_PACKAGE_LIGHTDM=y                   # Display manager (optional, lightweight UI)
   BR2_PACKAGE_XORG=n                      # No X11 (too heavy)
   ```

3. **Root Filesystem Overlay** (`build/ui/overlay/`):
   - `etc/systemd/system/ui-display.service` – Display initialization and UI renderer
   - `etc/systemd/system/audio-output.service` – Audio playback from MQTT events
   - `etc/asound.conf` – ALSA device mapping for Pirate Audio (MAX98357A)
   - `usr/local/bin/ui-start.sh` – Framebuffer init, splash screen display
   - `usr/local/bin/button-handler.sh` – GPIO button event capture

4. **Device Tree Overlay** (`build/ui/overlay/pirate-audio.dts`):
   ```
   / {
     compatible = "brcm,bcm2835";
     
     spi@7e204000 {
       st7789_display: display@0 {
         compatible = "sitronix,st7789v";
         reg = <0>;
         spi-max-frequency = <80000000>;
         dc-gpios = <&gpio 25 0>;           // Data/Command on GPIO 25
         reset-gpios = <&gpio 27 0>;        // Reset on GPIO 27
         rotation = <90>;
         backlight = <&backlight>;
       };
     };
     
     gpio-keys {
       compatible = "gpio-keys";
       button_a {
         label = "Button A";
         gpios = <&gpio 6 1>;               // GPIO 6, active low
         linux,code = <BTN_A>;
       };
       button_b {
         label = "Button B";
         gpios = <&gpio 12 1>;
         linux,code = <BTN_B>;
       };
     };
     
     // I2S audio for amplifier
     i2s: i2s@7e203000 {
       status = "okay";
       max98357a: codec@30 {
         compatible = "maxim,max98357a";
         reg = <0x30>;
         mute-gpios = <&gpio 7 0>;          // Mute on GPIO 7
       };
     };
   };
   ```

5. **UI Application** (`firmware/ui/main.py` – placeholder):
   ```python
   #!/usr/bin/env python3
   import sys
   import subprocess
   import signal
   
   # Initialize framebuffer
   subprocess.run(['/usr/local/bin/ui-start.sh'], check=True)
   
   # TODO: Implement UI rendering (via PyGame or direct framebuffer)
   # Display ADAS status: lane detection, object alerts, voice commands
   
   def signal_handler(sig, frame):
       print("UI shutdown")
       sys.exit(0)
   
   signal.signal(signal.SIGTERM, signal_handler)
   
   while True:
       # Poll MQTT for updates
       # Render to framebuffer
       pass
   ```

**Validation:**
- Display boots and renders framebuffer (check `/dev/fb0`)
- Button GPIO events trigger via `gpiod` or `sysfs`
- Audio output via I2S to MAX98357A (test with `aplay`)

---

### 1.3 Gateway Node (Pi 4) Buildroot Configuration

**Deliverable:** Bootable Linux image for Gateway Pi 4 with MQTT broker, WiFi AP, AI runtime.

**Hardware Target:**
- Raspberry Pi 4 Model B (ARMv7l, 4–8 GB RAM)
- Adafruit BrainCraft HAT (ST7789 display, PDM mics, speaker, thermal fan)
- Onboard WiFi (as AP) and Ethernet

**Steps:**

1. **Kernel Configuration** (`build/gateway/kernel.config` – Pi 4 specific):
   ```
   # Pi 4 specific features
   CONFIG_ARCH_BCM2835=y
   CONFIG_SOC_BCM2711=y                    # Pi 4 SoC
   CONFIG_ARM_ARCH_TIMER=y
   CONFIG_GENERIC_CLOCKEVENTS=y
   
   # GPIO USB Power Control
   CONFIG_GPIO_RASPBERRYPI=y
   
   # Wireless AP
   CONFIG_MAC80211=y
   CONFIG_CFG80211=y
   CONFIG_NL80211_TESTMODE=y
   CONFIG_WPA_SUPPLICANT=y
   CONFIG_HOSTAPD=y                        # WiFi Access Point daemon
   
   # Thermal management
   CONFIG_THERMAL=y
   CONFIG_THERMAL_OF=y
   CONFIG_RASPBERRYPI_HWMON=y              # Temperature monitoring
   CONFIG_PWM_BCM2835=y                    # PWM for fan control
   
   # Hardware video encoder/decoder
   CONFIG_MEDIA_SUPPORT=y
   CONFIG_VIDEO_V4L2_MEM2MEM=y
   CONFIG_VIDEO_RPIVID=m                   # H.264 hardware decoder
   
   # Container support (optional, for future cloud-native)
   CONFIG_CGROUPS=y
   CONFIG_NAMESPACES=y
   CONFIG_SECCOMP=y
   ```

2. **Buildroot Defconfig** (`build/gateway/buildroot.config`):
   ```
   # Larger root for services
   BR2_TARGET_ROOTFS_SIZE=512               # 512 MB root partition
   BR2_TARGET_ROOTFS_SIZE_PERCENTAGE=30
   
   # AI/ML runtime
   BR2_PACKAGE_TENSORFLOW_LITE=y
   BR2_PACKAGE_TFLITE_PYTHON=y
   BR2_PACKAGE_NUMPY=y
   BR2_PACKAGE_SCIPY=y
   
   # MQTT Broker
   BR2_PACKAGE_MOSQUITTO=y
   BR2_PACKAGE_MOSQUITTO_CLIENTS=y
   
   # Web server for admin console
   BR2_PACKAGE_NGINX=y
   
   # Container runtime (optional)
   BR2_PACKAGE_DOCKER=n                    # Too heavy; use lighter alternative if needed
   
   # Development tools (remove from production image)
   BR2_PACKAGE_GDB=y                       # Debugging (optional)
   BR2_PACKAGE_STRACE=y                    # Tracing (optional)
   ```

3. **Root Filesystem Overlay** (`build/gateway/overlay/`):
   - `etc/systemd/system/mosquitto.service` – MQTT broker service
   - `etc/systemd/system/gateway-bridge.service` – Aggregation/AI service
   - `etc/systemd/system/fan-controller.service` – Thermal management
   - `etc/nginx/nginx.conf` – Admin web console config
   - `etc/hostapd/hostapd.conf` – WiFi AP settings:
     ```
     interface=wlan0
     driver=nl80211
     ssid=ADAS-GATEWAY
     hw_mode=g
     channel=6
     wpa=2
     wpa_passphrase=adas_secure_pass
     wpa_key_mgmt=WPA-PSK
     wpa_pairwise=CCMP
     ```
   - `etc/dnsmasq.conf` – DHCP for connected nodes:
     ```
     interface=wlan0
     dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,12h
     ```

4. **AI Model Deployment** (`firmware/gateway/models/`):
   - Download MobileNet-SSD v2 quantized (COCO dataset) from TensorFlow Hub
   - Store in: `firmware/gateway/models/mobilenet_ssd_v2_quantized.tflite` (~5–10 MB)
   - Checksum in manifest for integrity verification

5. **Gateway Bridge Service** (`firmware/gateway/gateway-bridge.py`):
   ```python
   #!/usr/bin/env python3
   import paho.mqtt.client as mqtt
   import tflite_runtime.interpreter as tflite
   import json
   import threading
   from collections import deque
   
   # Load TFLite model
   interpreter = tflite.Interpreter(
       model_path="/firmware/models/mobilenet_ssd_v2_quantized.tflite"
   )
   interpreter.allocate_tensors()
   
   # MQTT client
   client = mqtt.Client()
   
   # Buffers for aggregating sensor streams
   vision_queue = deque(maxlen=30)          # Last 30 frames for inference
   audio_queue = deque(maxlen=1024)         # Audio buffer
   
   def on_connect(client, userdata, flags, rc):
       print(f"Connected with code {rc}")
       client.subscribe("sensor/vision/frame")
       client.subscribe("sensor/audio/stream")
       client.subscribe("ui/command/#")
   
   def on_message(client, userdata, msg):
       if msg.topic.startswith("sensor/vision/"):
           # Aggregate frame for AI inference
           vision_queue.append(json.loads(msg.payload))
       elif msg.topic.startswith("sensor/audio/"):
           # Buffer audio for speech processing
           audio_queue.append(msg.payload)
   
   def inference_thread():
       """Periodic AI inference on aggregated frames"""
       while True:
           if len(vision_queue) > 0:
               frame = vision_queue[0]
               # Run TFLite inference
               # Publish results back to topic "gateway/ai/detections"
           time.sleep(0.1)
   
   client.on_connect = on_connect
   client.on_message = on_message
   client.connect("127.0.0.1", 1883)
   client.loop_start()
   
   threading.Thread(target=inference_thread, daemon=True).start()
   
   # Keep running
   while True:
       time.sleep(1)
   ```

**Validation:**
- Pi 4 Kernel builds without Pi 3 errors (separate defconfig for ARMv7 vs ARMv6)
- Buildroot build produces `zImage` and `rootfs.tar.gz` for Pi 4
- MQTT broker starts: `mosquitto -c /etc/mosquitto/mosquitto.conf`
- WiFi AP appears in scan: `iwlist wlan0 scan`
- TensorFlow Lite model loads and runs: Python inference script executes

---

### 1.4 Assemble Boot Images (SD Card Image Generation)

**Deliverable:** Flushable `.img` files for all 3 nodes + checksum validation.

**Steps:**

1. **Raspberry Pi Boot Firmware** (shared for all Pi nodes):
   - Download from: https://github.com/raspberrypi/firmware/tree/master/boot
   - Required files:
     - `bootcode.bin` – First-stage bootloader (Pi Zero)
     - `start.elf`, `start_x.elf` – GPU firmware
     - `fixup.dat`, `fixup_x.dat` – GPU memory split
     - `LICENCE.broadcom` – License file

2. **Boot Partition Layout** per node:
   ```
   build/<node>/assemble-image.sh:
   
   #!/bin/bash
   set -euo pipefail
   
   NODE=$1
   VERSION=$2
   OUTPUT="${3:-images}"
   
   # Create empty image file (size = boot partition + root partition)
   # Pi Zero: 128 MB boot + 512 MB root = 640 MB
   # Pi 4: 512 MB boot + 2 GB root = 2.5 GB
   
   BOOT_SIZE_MB=128
   ROOT_SIZE_MB=$(get_root_size_for_node ${NODE})
   IMAGE_SIZE_MB=$((BOOT_SIZE_MB + ROOT_SIZE_MB))
   
   # Create sparse image
   dd if=/dev/zero of="${OUTPUT}/${NODE}-linux-${VERSION}.img" \
      bs=1M count=0 seek=${IMAGE_SIZE_MB}
   
   # Create partition table
   parted "${OUTPUT}/${NODE}-linux-${VERSION}.img" mklabel msdos
   parted "${OUTPUT}/${NODE}-linux-${VERSION}.img" mkpart primary fat32 1 ${BOOT_SIZE_MB}
   parted "${OUTPUT}/${NODE}-linux-${VERSION}.img" mkpart primary ext4 ${BOOT_SIZE_MB} 100%
   
   # Format partitions
   LOOPDEV=$(losetup -f)
   losetup -P "${LOOPDEV}" "${OUTPUT}/${NODE}-linux-${VERSION}.img"
   mkfs.vfat "${LOOPDEV}p1" -n "BOOT"
   mkfs.ext4 "${LOOPDEV}p2" -L "ROOT"
   
   # Mount and populate
   mkdir -p /mnt/boot /mnt/root
   mount "${LOOPDEV}p1" /mnt/boot
   mount "${LOOPDEV}p2" /mnt/root
   
   # Copy boot files
   cp build/firmware/bootcode.bin /mnt/boot/
   cp build/firmware/start.elf /mnt/boot/
   cp build/firmware/fixup.dat /mnt/boot/
   cp build/${NODE}/boot/config.txt /mnt/boot/
   cp build/${NODE}/boot/cmdline.txt /mnt/boot/
   cp build/buildroot-src/output/images/zImage /mnt/boot/kernel.img
   
   # Copy rootfs
   tar -C /mnt/root -xzf build/buildroot-src/output/images/rootfs.tar.gz
   
   # Unmount
   umount /mnt/boot /mnt/root
   losetup -d "${LOOPDEV}"
   
   # Compress and checksum
   xz -9 "${OUTPUT}/${NODE}-linux-${VERSION}.img"
   sha256sum "${OUTPUT}/${NODE}-linux-${VERSION}.img.xz" > "${OUTPUT}/${NODE}-linux-${VERSION}.img.xz.sha256"
   ```

3. **Boot Configuration Files per Node:**

   **Sensor** (`build/sensor/boot/config.txt`):
   ```
   [pi0w]
   kernel=kernel.img
   arm_freq=1000
   over_voltage=4
   dtoverlay=disable-bt
   dtoverlay=disable-wifi
   dtparam=i2c_arm=on
   dtparam=spi=on
   enable_uart=1
   ```

   **UI** (`build/ui/boot/config.txt`):
   ```
   [pi0w]
   kernel=kernel.img
   arm_freq=1000
   gpu_mem=64
   dtoverlay=spi1-3cs
   dtparam=i2c_arm=on
   enable_uart=1
   ```

   **Gateway** (`build/gateway/boot/config.txt`):
   ```
   [pi4]
   kernel=kernel.img
   arm_freq=1800
   gpu_mem=256
   enable_gic=1
   armstub=armstub8-gic.bin
   dtoverlay=disable-bt
   dtparam=i2c_arm=on
   dtparam=spi=on
   dtoverlay=gpio-fan,gpiopin=4
   ```

   **Kernel Command Line** (`build/<node>/boot/cmdline.txt`):
   ```
   console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet
   ```

4. **Update Build Scripts** to call `assemble-image.sh`:
   ```bash
   # build/sensor/build.sh (updated)
   #!/bin/bash
   set -euo pipefail
   
   VERSION=${1:-0.0.1}
   OUTPUT_DIR=${2:-images}
   
   # Build Buildroot
   make -C build/buildroot-src all
   
   # Assemble image
   bash build/sensor/assemble-image.sh sensor "${VERSION}" "${OUTPUT_DIR}"
   
   # Generate checksums
   sha256sum "${OUTPUT_DIR}/sensor-linux-${VERSION}.img.xz" > "${OUTPUT_DIR}/sensor-checksums.txt"
   ```

**Validation:**
- `file` command on assembled `.img` shows MBR partition table
- `fdisk -l` shows two partitions (boot FAT32, root ext4)
- Image can be written to USB stick: `dd if=sensor-linux-v0.1.0.img of=/dev/sdX bs=4M`
- Pi Zero boots from written image (manual test with hardware)

---

## Phase 2: Hardware Validation and Bring-Up (Weeks 3–4)

### 2.1 Camera and Audio Hardware Testing

**Deliverable:** Automated hardware smoke tests (camera, audio, display, LEDs, buttons) callable before deployment.

**Steps:**

1. **Camera Test Script** (`firmware/sensor/hw-tests/camera-test.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Testing CSI camera..."
   
   # Verify device enumeration
   if ! [ -e /dev/video0 ]; then
       echo "FAIL: /dev/video0 not found"
       exit 1
   fi
   
   # Verify kernel driver loaded
   if ! lsmod | grep -q "bcm2835_mmal"; then
       echo "WARN: bcm2835_mmal not loaded, loading..."
       modprobe bcm2835_mmal || echo "WARN: modprobe failed, may be built-in"
   fi
   
   # Capture single frame to /tmp and check file size
   v4l2-ctl -d /dev/video0 --set-fmt-video=width=640,height=480,pixelformat=H264
   timeout 2 ffmpeg -f v4l2 -input_format h264 -i /dev/video0 -t 1 -f null - 2>&1 || true
   
   echo "PASS: Camera detected and responding"
   ```

2. **Audio Input Test** (`firmware/sensor/hw-tests/audio-input-test.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Testing audio input (Voice Bonnet microphones)..."
   
   # Verify ALSA devices
   arecord -l | grep -q "Voice Bonnet" || echo "WARN: Voice Bonnet not in arecord -l"
   
   # Capture 2 seconds of audio
   arecord -D default -f cd -t wav /tmp/test-audio.wav -d 2 || true
   
   # Check file was created and has reasonable size (>40KB for 2s stereo @ 48kHz)
   SIZE=$(stat -f%z /tmp/test-audio.wav 2>/dev/null || stat -c%s /tmp/test-audio.wav 2>/dev/null || echo 0)
   if [ "$SIZE" -lt 40000 ]; then
       echo "FAIL: Audio recording too small ($SIZE bytes)"
       exit 1
   fi
   
   echo "PASS: Audio input working ($SIZE bytes captured)"
   ```

3. **Audio Output Test** (`firmware/ui/hw-tests/audio-output-test.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Testing audio output (Pirate Audio MAX98357A)..."
   
   # Generate 1kHz sine wave, 2 seconds
   ffmpeg -f lavfi -i "sine=frequency=1000:duration=2" -acodec libopus -b:a 128k /tmp/test-tone.opus -y 2>/dev/null
   
   # Play through default speaker
   aplay /tmp/test-tone.opus || opusplay /tmp/test-tone.opus || true
   
   echo "PASS: Audio output routed to amplifier"
   ```

4. **Display Test** (`firmware/ui/hw-tests/display-test.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Testing ST7789 display (Pirate Audio)..."
   
   # Verify device enumeration
   ls /dev/spidev* || { echo "FAIL: No SPI device"; exit 1; }
   
   # Generate test pattern: red, green, blue, white
   python3 << 'EOF'
   import time
   try:
       # Attempt to import display driver (Pimoroni ST7789 or generic DRM)
       # from PIL import Image, ImageDraw
       # or use /dev/fb0 directly
       
       # For now, just verify GPIO pins are accessible
       import gpiod
       chip = gpiod.Chip("/dev/gpiochip0")
       dc_line = chip.get_line(25)  # Data/Command GPIO
       dc_line.request(consumer="display-test", type=gpiod.LINE_REQ_DIR_OUT, default_val=0)
       dc_line.set_value(1)
       time.sleep(0.1)
       print("PASS: Display SPI and GPIO accessible")
   except Exception as e:
       print(f"WARN: Display test inconclusive: {e}")
   EOF
   ```

5. **LED and Button Test** (`firmware/sensor/hw-tests/led-button-test.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Testing Voice Bonnet LEDs and buttons..."
   
   # Set GPIO direction and test LED blink
   for led in 17 27; do
       echo "in" > /sys/class/gpio/gpio${led}/direction 2>/dev/null || \
       echo "Testing GPIO ${led}..."
   done
   
   # Button test (GPIO 23, 24)
   for btn in 23 24; do
       STATE=$(cat /sys/class/gpio/gpio${btn}/value 2>/dev/null || echo "?")
       echo "Button GPIO ${btn}: ${STATE}"
   done
   
   echo "PASS: LEDs and buttons accessible"
   ```

6. **Thermal Test** (`firmware/gateway/hw-tests/thermal-test.sh` for Pi 4):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Testing Pi 4 thermal management..."
   
   # Read CPU temperature
   TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
   TEMP_C=$((TEMP / 1000))
   
   echo "CPU temperature: ${TEMP_C}°C"
   
   if [ "$TEMP_C" -gt 80 ]; then
       echo "WARN: High temperature, check thermal paste and fan"
   fi
   
   # Verify fan PWM available
   ls /sys/class/pwm/pwmchip*/pwm* 2>/dev/null && echo "PASS: PWM fan control available" || \
   echo "WARN: PWM not enumerated (may load after first access)"
   ```

7. **Integration Test Runner** (`firmware/run-hw-tests.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   NODE=${1:-sensor}
   TEST_DIR="firmware/${NODE}/hw-tests"
   
   echo "Running hardware tests for ${NODE}..."
   
   for test in "${TEST_DIR}"/*.sh; do
       echo ""
       echo "=== $(basename "$test") ==="
       bash "$test" || { echo "FAIL: $test"; exit 1; }
   done
   
   echo ""
   echo "All hardware tests passed!"
   ```

**Validation:**
- Run on physical hardware: `bash firmware/sensor/run-hw-tests.sh sensor`
- All smoke tests return exit code 0
- Camera produces H.264 frames, audio captures >40KB in 2s, display renders, LEDs respond

---

### 2.2 Network and MQTT Integration Test

**Deliverable:** Validated WiFi AP + MQTT broker + sensor/UI connectivity.

**Steps:**

1. **WiFi AP Startup** (`firmware/gateway/start-ap.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Starting WiFi Access Point..."
   
   # Enable IP forwarding (for potential bridging to Ethernet)
   echo 1 > /proc/sys/net/ipv4/ip_forward
   
   # Start hostapd
   hostapd -B /etc/hostapd/hostapd.conf
   
   # Configure AP interface IP
   ip addr add 192.168.4.1/24 dev wlan0
   
   # Start DHCP server
   dnsmasq -C /etc/dnsmasq.conf
   
   # Enable NAT (optional, for cloud uplink)
   iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
   iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
   
   echo "AP ready at 192.168.4.1, SSID: ADAS-GATEWAY"
   ```

2. **MQTT Broker Test** (`firmware/gateway/test-mqtt.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Testing MQTT broker..."
   
   # Start Mosquitto in background
   mosquitto -c /etc/mosquitto/mosquitto.conf -d
   sleep 1
   
   # Publish test message
   mosquitto_pub -h 127.0.0.1 -t "gateway/test" -m "hello"
   
   # Subscribe and timeout if no response
   RESPONSE=$(timeout 2 mosquitto_sub -h 127.0.0.1 -t "gateway/test" -C 1 2>/dev/null || echo "TIMEOUT")
   
   if [ "$RESPONSE" = "hello" ]; then
       echo "PASS: MQTT broker operational"
   else
       echo "FAIL: MQTT test message not received"
       exit 1
   fi
   ```

3. **Sensor-to-Gateway Connection** (`firmware/sensor/test-connection.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Testing Sensor → Gateway connection..."
   
   # Connect to AP
   wpa_cli -i wlan0 add_network > /dev/null
   wpa_cli -i wlan0 set_network 0 ssid \"ADAS-GATEWAY\"
   wpa_cli -i wlan0 set_network 0 psk \"adas_secure_pass\"
   wpa_cli -i wlan0 select_network 0
   
   # Wait for DHCP
   sleep 3
   
   # Check connectivity
   GATEWAY_IP=$(ip route | grep default | awk '{print $3}')
   echo "Gateway IP: ${GATEWAY_IP}"
   
   # Publish test frame
   mosquitto_pub -h "${GATEWAY_IP}" -t "sensor/vision/frame" -m "{\"frame_id\": 1, \"timestamp\": $(date +%s)}"
   
   echo "PASS: Sensor connected to Gateway"
   ```

**Validation:**
- Manual test: Connect UI Pi Zero to gateway AP via `wpa_cli`
- Observe DHCP lease in `dnsmasq` logs
- Publish/subscribe test message via MQTT succeeds

---

## Phase 3: Application Services Development (Weeks 5–7)

### 3.1 Video Streaming Service (H.264 Hardware Encoder)

**Deliverable:** `firmware/sensor/video-streamer` service running on boot, streaming H.264 @ 30fps to gateway via RTP/UDP.

**Architecture:**
```
CSI Camera → H.264 encoder (VideoCore) → RTP packetizer → UDP/MQTT → Gateway → Display/Cloud
```

**Steps:**

1. **GStreamer Pipelines** (`firmware/sensor/video-streamer/pipeline.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   GATEWAY_IP=${1:-192.168.4.1}
   GATEWAY_PORT=${2:-5000}
   
   # Primary 640x480 @ 30fps H.264
   gst-launch-1.0 -e \
     v4l2src device=/dev/video0 \
       ! "video/x-h264, width=640, height=480, framerate=30/1" \
       ! h264parse \
       ! rtph264pay pt=96 \
       ! udpsink host="${GATEWAY_IP}" port="${GATEWAY_PORT}" auto-multicast=false \
     2>&1 | logger -t video-streamer
   
   # Fallback 320x240 if resource constrained
   # gst-launch-1.0 -e \
   #   v4l2src device=/dev/video0 blocksize=614400 \
   #     ! "video/x-h264, width=320, height=240, framerate=15/1" \
   #     ! ... (same as above)
   ```

2. **Systemd Service** (`firmware/sensor/systemd/video-streamer.service`):
   ```ini
   [Unit]
   Description=Video Streaming Service (H.264 to Gateway)
   After=network-online.target
   Wants=network-online.target
   
   [Service]
   Type=simple
   ExecStart=/usr/local/bin/video-streamer.sh
   Restart=on-failure
   RestartSec=5
   StandardOutput=journal
   StandardError=journal
   ```

3. **C++ Alternative (Lighter)** (`firmware/sensor/video-streamer/main.cpp`):
   ```cpp
   #include <stdio.h>
   #include <stdlib.h>
   #include <string.h>
   #include <unistd.h>
   #include <thread>
   #include <queue>
   
   #include <libcamera/libcamera.h>
   #include <rtp/rtplib.h>
   
   // Simplified: Use libcamera to capture, encode via mmal/v4l2, send RTP packets
   
   int main(int argc, char *argv[]) {
       const char *gateway_ip = argc > 1 ? argv[1] : "192.168.4.1";
       int gateway_port = argc > 2 ? atoi(argv[2]) : 5000;
       
       printf("Video Streamer: target %s:%d\n", gateway_ip, gateway_port);
       
       // Open camera
       auto &camera_mgr = libcamera::CameraManager::instance();
       camera_mgr.start();
       
       std::vector<std::shared_ptr<libcamera::Camera>> cameras = camera_mgr.cameras();
       if (cameras.empty()) {
           fprintf(stderr, "No cameras found\n");
           return 1;
       }
       
       auto camera = cameras[0];
       camera->acquire();
       
       // Create configuration
       auto config = camera->generateConfiguration({libcamera::StreamRole::VideoRecording});
       config->at(0).pixelFormat = libcamera::formats::H264;
       config->at(0).size = {640, 480};
       config->at(0).frameRate = {30, 1};
       
       camera->configure(config.get());
       
       // Allocate buffers, start streaming, encode and send RTP packets...
       // (Full implementation requires libcamera, rtp, and encoder integration)
       
       camera->release();
       return 0;
   }
   ```

**Validation:**
- On Gateway, listen for RTP: `gst-launch-1.0 udpsrc port=5000 ! application/x-rtp, payload=96 ! rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! autovideosink`
- Observe H.264 frames arriving, <100ms latency (measure with timestamp in frame metadata)

---

### 3.2 Audio Streaming and Mixing Service

**Deliverable:** `firmware/sensor/audio-capture` and `firmware/ui/audio-output` services with priority-based mixing on gateway.

**Priority Classes:**
- P0 (Safety Critical): <100ms latency (e.g., "Lane departure warning")
- P1 (Advisory): <500ms latency (e.g., "Slow traffic detected")
- P2 (Info): <2s latency (e.g., "Route updated")
- P3 (Background): best-effort (e.g., "Music playback")

**Steps:**

1. **Sensor Audio Capture Service** (`firmware/sensor/audio-capture/main.py`):
   ```python
   #!/usr/bin/env python3
   import alsaaudio
   import socket
   import struct
   import time
   import paho.mqtt.client as mqtt
   
   GATEWAY_IP = "192.168.4.1"
   GATEWAY_PORT = 5001
   
   # ALSA input from Voice Bonnet microphones
   inp = alsaaudio.PCM(
       alsaaudio.PCM_CAPTURE,
       alsaaudio.PCM_NONBLOCK,
       device="default"
   )
   inp.setchannels(2)
   inp.setrate(48000)
   inp.setformat(alsaaudio.PCM_FORMAT_S16_LE)
   inp.setperiodsize(960)  # 20ms @ 48kHz
   
   # MQTT for out-of-band control
   mqtt_client = mqtt.Client()
   mqtt_client.connect(GATEWAY_IP, 1883, 60)
   mqtt_client.loop_start()
   
   # UDP socket for audio frames
   udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
   
   frame_id = 0
   start_time = time.time()
   
   while True:
       try:
           length, data = inp.read()
           if length:
               # Encode with Opus (or send raw PCM for now)
               # opus_encoded = opusenc.encode(data)
               
               # Wrap in RTP-like header: [frame_id (4B), timestamp (4B), data]
               timestamp = int((time.time() - start_time) * 48000)
               packet = struct.pack("!II", frame_id, timestamp) + data
               
               udp_socket.sendto(packet, (GATEWAY_IP, GATEWAY_PORT))
               frame_id += 1
       except:
           pass
       
       time.sleep(0.01)  # Async capture loop
   ```

2. **UI Audio Output Service** (`firmware/ui/audio-output/main.py`):
   ```python
   #!/usr/bin/env python3
   import paho.mqtt.client as mqtt
   import alsaaudio
   import json
   import time
   
   GATEWAY_IP = "192.168.4.1"
   
   # ALSA output to Pirate Audio amplifier
   out = alsaaudio.PCM(
       alsaaudio.PCM_PLAYBACK,
       device="default"
   )
   out.setchannels(1)
   out.setrate(16000)
   out.setformat(alsaaudio.PCM_FORMAT_S16_LE)
   out.setperiodsize(160)  # 10ms @ 16kHz
   
   mqtt_client = mqtt.Client()
   
   def on_message(client, userdata, msg):
       """Receive audio playback commands from gateway"""
       try:
           payload = json.loads(msg.payload.decode())
           priority = payload.get("priority", 2)
           audio_data = payload.get("audio_b64", "")
           
           # Decode base64 audio
           import base64
           audio_bytes = base64.b64decode(audio_data)
           
           # Play with priority queue handling
           if priority == 0:
               # Preempt current playback
               pass
           
           out.write(audio_bytes)
       except Exception as e:
           print(f"Error: {e}")
   
   mqtt_client.on_message = on_message
   mqtt_client.connect(GATEWAY_IP, 1883, 60)
   mqtt_client.subscribe("ui/audio/play/#")
   mqtt_client.loop_forever()
   ```

3. **Gateway Audio Mixer** (`firmware/gateway/audio-mixer/main.py`):
   ```python
   #!/usr/bin/env python3
   import socket
   import struct
   import threading
   import time
   from collections import deque
   from dataclasses import dataclass
   from enum import IntEnum
   import paho.mqtt.client as mqtt
   
   class Priority(IntEnum):
       P0_SAFETY = 0
       P1_ADVISORY = 1
       P2_INFO = 2
       P3_BACKGROUND = 3
   
   @dataclass
   class AudioFrame:
       priority: Priority
       timestamp: int
       frame_id: int
       data: bytes
       source: str  # "sensor", "cloud", etc.
   
   # Priority queues
   audio_queues = {p: deque(maxlen=100) for p in Priority}
   current_priority = Priority.P3_BACKGROUND
   
   # UDP listener for incoming audio
   udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
   udp_socket.bind(("0.0.0.0", 5001))
   
   def listen_for_audio():
       while True:
           data, addr = udp_socket.recvfrom(4096)
           frame_id, timestamp = struct.unpack("!II", data[:8])
           audio_data = data[8:]
           
           # Determine priority from metadata or source
           source = addr[0]  # IP address
           priority = Priority.P2_INFO  # Default
           
           frame = AudioFrame(
               priority=priority,
               timestamp=timestamp,
               frame_id=frame_id,
               data=audio_data,
               source=source
           )
           audio_queues[priority].append(frame)
   
   def mixer_thread():
       """Mix and forward audio to UI node"""
       mqtt_client = mqtt.Client()
       mqtt_client.connect("127.0.0.1", 1883)
       
       while True:
           # Check priority queues in order (P0 first)
           frame = None
           for priority in [Priority.P0_SAFETY, Priority.P1_ADVISORY, Priority.P2_INFO, Priority.P3_BACKGROUND]:
               if audio_queues[priority]:
                   frame = audio_queues[priority].popleft()
                   break
           
           if frame:
               # Publish to UI
               import base64
               payload = {
                   "priority": int(frame.priority),
                   "audio_b64": base64.b64encode(frame.data).decode(),
                   "source": frame.source
               }
               mqtt_client.publish("ui/audio/play", json.dumps(payload))
           
           time.sleep(0.01)
   
   # Start threads
   threading.Thread(target=listen_for_audio, daemon=True).start()
   threading.Thread(target=mixer_thread, daemon=True).start()
   
   print("Audio mixer running...")
   while True:
       time.sleep(1)
   ```

**Validation:**
- Record audio on Sensor, verify on UI display via MQTT
- Measure latency: send timestamped frame, measure arrival at UI
- Priority test: send P0 while P3 playing, verify P0 preempts

---

### 3.3 MQTT Control and Command Service

**Deliverable:** Standardized MQTT topic hierarchy for all node control and status reporting.

**Topic Hierarchy:**
```
gateway/status                      # Gateway health (CPU, temp, uptime)
gateway/ai/detections               # AI inference results (objects, lanes)
sensor/vision/frame                 # Raw H.264 frame metadata
sensor/audio/stream                 # Audio stream status
ui/display/image                    # Image to render on UI
ui/audio/play                       # Audio playback command
ui/command/action                   # UI button press → action
cloud/telemetry/log                 # Unified telemetry to cloud
```

**Steps:**

1. **MQTT Configuration** (`etc/mosquitto/mosquitto.conf`):
   ```
   port 1883
   listener 8883
   protocol mqtt
   allow_anonymous true
   
   # Logging
   log_dest file /var/log/mosquitto/mosquitto.log
   log_dest stdout
   log_type all
   
   # Performance
   max_connections -1
   max_queued_messages 1000
   message_size_limit 0
   ```

2. **Gateway Status Publisher** (`firmware/gateway/status-publisher.py`):
   ```python
   #!/usr/bin/env python3
   import paho.mqtt.client as mqtt
   import json
   import psutil
   import os
   import time
   
   client = mqtt.Client()
   client.connect("127.0.0.1", 1883, 60)
   
   while True:
       status = {
           "timestamp": time.time(),
           "cpu_percent": psutil.cpu_percent(interval=1),
           "memory_percent": psutil.virtual_memory().percent,
           "temperature": int(open("/sys/class/thermal/thermal_zone0/temp").read()) / 1000,
           "uptime": int(open("/proc/uptime").read().split()[0]),
       }
       
       client.publish("gateway/status", json.dumps(status), qos=1)
       time.sleep(10)
   ```

3. **UI Command Handler** (`firmware/ui/command-handler.py`):
   ```python
   #!/usr/bin/env python3
   import paho.mqtt.client as mqtt
   import RPi.GPIO as GPIO
   import json
   
   client = mqtt.Client()
   
   # GPIO button mappings for Pirate Audio
   BUTTON_MAP = {
       6: "A",
       12: "B",
       13: "X",
       5: "Y",
   }
   
   def on_message(client, userdata, msg):
       try:
           command = json.loads(msg.payload.decode())
           action = command.get("action")
           
           if action == "brightness_up":
               # Increase display brightness
               pass
           elif action == "volume_up":
               # Increase audio volume
               os.system("amixer set PCM 5%+")
       except:
           pass
   
   # Listen for commands
   client.on_message = on_message
   client.connect("192.168.4.1", 1883, 60)
   client.subscribe("ui/command/#")
   
   # Also handle local button presses
   GPIO.setmode(GPIO.BCM)
   for pin in BUTTON_MAP:
       GPIO.setup(pin, GPIO.IN)
   
   def button_callback(pin):
       button = BUTTON_MAP.get(pin)
       client.publish(f"ui/event/button/{button}", json.dumps({"timestamp": time.time()}))
   
   for pin in BUTTON_MAP:
       GPIO.add_event_detect(pin, GPIO.FALLING, callback=button_callback)
   
   client.loop_forever()
   ```

**Validation:**
- Subscribe to all topics: `mosquitto_sub -h 192.168.4.1 -t "#" -v`
- Publish test: `mosquitto_pub -h 192.168.4.1 -t "ui/command/action" -m '{"action":"volume_up"}'`
- Observe messages flowing between nodes

---

## Phase 4: OTA Security and Signing (Week 8)

### 4.1 Artifact Signing Pipeline

**Deliverable:** CI generates signed manifests, edge nodes verify before applying updates.

**Steps:**

1. **Generate Signing Keys** (one-time setup):
   ```bash
   # Create ED25519 keypair for production
   openssl genpkey -algorithm ED25519 -out private-key.pem
   openssl pkey -in private-key.pem -pubout -out public-key.pem
   
   # Store private key in GitHub Secrets (encrypted)
   # Store public key in repo for verification
   ```

2. **CI Signing Step** (`.github/workflows/build-all-nodes.yml` update):
   ```yaml
   - name: Sign release manifest
     run: |
       openssl dgst -sha256 -sign ${{ secrets.SIGNING_KEY }} \
         release-manifest.json > release-manifest.json.sig
       
       # Append public key for verification
       cat public-key.pem >> release-manifest-bundle.tar
       tar rf release-manifest-bundle.tar release-manifest.json release-manifest.json.sig
       
   - name: Upload signed bundle
     uses: actions/upload-artifact@v3
     with:
       name: release-bundle
       path: release-manifest-bundle.tar
   ```

3. **Verification Script** (`firmware/gateway/ota-verify.sh`):
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   BUNDLE="$1"
   PUBLIC_KEY="public-key.pem"
   
   # Extract bundle
   tar xf "${BUNDLE}" release-manifest.json release-manifest.json.sig "${PUBLIC_KEY}"
   
   # Verify signature
   openssl dgst -sha256 -verify "${PUBLIC_KEY}" -signature release-manifest.json.sig release-manifest.json
   
   if [ $? -ne 0 ]; then
       echo "FAIL: Signature verification failed"
       exit 1
   fi
   
   echo "PASS: Manifest signature verified"
   ```

4. **Gateway OTA Update Daemon** (`firmware/gateway/ota-updater.py`):
   ```python
   #!/usr/bin/env python3
   import json
   import requests
   import subprocess
   import time
   from pathlib import Path
   
   OTA_CHECK_INTERVAL = 3600  # 1 hour
   
   def check_for_updates(repo_url="https://github.com/owner/pi-adas-edge-cloud"):
       """Poll GitHub releases for new artifacts"""
       try:
           response = requests.get(f"{repo_url}/releases/latest", timeout=10)
           release = response.json()
           
           current_version = open("/etc/adas-version").read().strip()
           latest_version = release["tag_name"]
           
           if latest_version > current_version:
               return release
       except:
           return None
   
   def apply_update(release):
       """Download, verify, and apply update"""
       for asset in release["assets"]:
           if asset["name"].endswith(".tar"):
               # Download signed bundle
               url = asset["browser_download_url"]
               subprocess.run(["wget", "-O", "/tmp/ota-bundle.tar", url], check=True)
               
               # Verify signature
               result = subprocess.run(
                   ["bash", "firmware/gateway/ota-verify.sh", "/tmp/ota-bundle.tar"],
                   capture_output=True
               )
               
               if result.returncode != 0:
                   print("OTA verification failed")
                   return False
               
               # Extract and apply (node-specific images)
               subprocess.run(["tar", "-xf", "/tmp/ota-bundle.tar", "-C", "/tmp/"], check=True)
               
               # Reflash nodes via USB or network (placeholder)
               print(f"OTA bundle verified, ready for staged rollout")
               return True
       
       return False
   
   # Background daemon
   while True:
       release = check_for_updates()
       if release:
           print(f"Update available: {release['tag_name']}")
           # Trigger canary rollout (see Phase 5)
       
       time.sleep(OTA_CHECK_INTERVAL)
   ```

**Validation:**
- Generate test manifest, sign with private key
- Verify with public key: `openssl dgst -sha256 -verify public-key.pem -signature manifest.json.sig manifest.json`
- Negative test: modify manifest, verification should fail

---

## Phase 5: Canary Deployment and Rollout (Week 9)

### 5.1 Staged Rollout Policy

**Deliverable:** Canary fleet monitoring, automatic promotion to beta/production with rollback triggers.

**Stages:**
1. **Canary (10%):** 1 Pi Zero W (sensor or UI) on latest build
2. **Beta (30%):** 3 nodes (mix of sensor/UI/gateway)
3. **Production (100%):** All nodes

**Rollback Triggers:**
- CPU usage >80% for >5 min
- Audio latency >150ms (measured frame-to-speaker)
- Video frame drops >5% per min
- MQTT connection loss >3 consecutive restarts
- Thermal throttling detected (Pi 4 >85°C sustained)

**Steps:**

1. **Metrics Collection** (`firmware/*/metrics-collector.py`):
   ```python
   #!/usr/bin/env python3
   import paho.mqtt.client as mqtt
   import psutil
   import json
   import time
   import os
   
   node_type = os.environ.get("NODE_TYPE", "sensor")
   mqtt_client = mqtt.Client()
   mqtt_client.connect("192.168.4.1", 1883, 60)
   
   def collect_metrics():
       return {
           "node_type": node_type,
           "timestamp": time.time(),
           "cpu_percent": psutil.cpu_percent(),
           "memory_mb": psutil.virtual_memory().used / 1024 / 1024,
           "disk_percent": psutil.disk_usage("/").percent,
           "temperature_c": int(open("/sys/class/thermal/thermal_zone0/temp").read()) / 1000,
           "network_packets_in": psutil.net_io_counters().packets_in,
           "network_packets_out": psutil.net_io_counters().packets_out,
       }
   
   while True:
       metrics = collect_metrics()
       mqtt_client.publish(f"metrics/{node_type}/system", json.dumps(metrics), qos=0)
       time.sleep(10)
   ```

2. **Rollout Manager** (`firmware/gateway/rollout-manager.py`):
   ```python
   #!/usr/bin/env python3
   import json
   import time
   from collections import defaultdict
   
   CANARY_THRESHOLD = 0.10       # 10% of fleet
   BETA_THRESHOLD = 0.30         # 30% of fleet
   
   class RolloutManager:
       def __init__(self):
           self.fleet_status = defaultdict(lambda: {
               "version": None,
               "stage": "unknown",
               "metrics": {},
               "last_seen": 0,
           })
           self.metrics_buffer = defaultdict(list)
       
       def update_node(self, node_id, metrics):
           """Record metrics for a node"""
           self.metrics_buffer[node_id].append(metrics)
           if len(self.metrics_buffer[node_id]) > 60:  # Keep 10 min history
               self.metrics_buffer[node_id].pop(0)
       
       def should_rollback(self, node_id):
           """Check if node violates rollback triggers"""
           if node_id not in self.metrics_buffer:
               return False
           
           recent = self.metrics_buffer[node_id][-10:]  # Last ~100 sec
           
           # CPU usage >80% for duration
           cpu_high = sum(1 for m in recent if m.get("cpu_percent", 0) > 80) > 8
           if cpu_high:
               return True
           
           # Temperature >85°C
           temp_high = any(m.get("temperature_c", 0) > 85 for m in recent)
           if temp_high:
               return True
           
           return False
       
       def promote_canary_to_beta(self, version):
           """Promote 10% → 30% if metrics good"""
           canary_nodes = [n for n, s in self.fleet_status.items() if s["stage"] == "canary" and s["version"] == version]
           
           # Check if all canary nodes have good metrics
           for node_id in canary_nodes:
               if self.should_rollback(node_id):
                   print(f"Rollback triggered for {node_id}")
                   return False
           
           # Promote
           print(f"Promoting {version} to beta")
           return True
   
   manager = RolloutManager()
   
   # MQTT subscriber for metrics
   import paho.mqtt.client as mqtt
   
   def on_message(client, userdata, msg):
       node_id = msg.topic.split("/")[1]  # metrics/{node_id}/system
       metrics = json.loads(msg.payload)
       manager.update_node(node_id, metrics)
   
   mqtt_client = mqtt.Client()
   mqtt_client.on_message = on_message
   mqtt_client.subscribe("metrics/+/system")
   mqtt_client.connect("127.0.0.1", 1883, 60)
   mqtt_client.loop_forever()
   ```

**Validation:**
- Deploy v0.2.0 to 1 canary node
- Monitor metrics for 1 hour: CPU, latency, thermal OK
- Approve promotion to beta
- Deploy to 3 nodes, observe healthy metrics
- Promote to production

---

## Phase 6: Integration and System Testing (Weeks 10–11)

### 6.1 End-to-End Latency Measurement

**Deliverable:** Validated <100ms perception-to-decision latency from camera frame to UI display.

**Test Setup:**
1. Display high-contrast pattern on external monitor
2. Sensor Pi Zero W captures frame via CSI camera
3. Gateway processes and renders to UI Pi Zero W display
4. Measure camera sensor to rendered display time

**Steps:**

1. **Latency Test Script** (`firmware/test-latency.py`):
   ```python
   #!/usr/bin/env python3
   import cv2
   import paho.mqtt.client as mqtt
   import numpy as np
   import time
   from threading import Thread, Lock
   
   class LatencyTester:
       def __init__(self):
           self.frame_timestamps = {}
           self.received_timestamps = {}
           self.lock = Lock()
       
       def capture_frames(self):
           """Sensor: capture frames, add timestamp, publish"""
           mqtt_client = mqtt.Client()
           mqtt_client.connect("192.168.4.1", 1883, 60)
           
           cap = cv2.VideoCapture(0)
           frame_id = 0
           
           while True:
               ret, frame = cap.read()
               if ret:
                   ts = time.time()
                   with self.lock:
                       self.frame_timestamps[frame_id] = ts
                   
                   # Encode and publish (with frame_id in EXIF or header)
                   mqtt_client.publish(f"test/frame/{frame_id}", str(ts).encode())
                   frame_id += 1
                   time.sleep(0.033)  # ~30fps
       
       def display_frames(self):
           """UI: receive frames, record reception time, display"""
           mqtt_client = mqtt.Client()
           
           def on_message(client, userdata, msg):
               frame_id = int(msg.topic.split("/")[2])
               ts_received = time.time()
               
               with self.lock:
                   self.received_timestamps[frame_id] = ts_received
               
               # Simulate display (just record time for now)
               if frame_id in self.frame_timestamps:
                   latency = (ts_received - self.frame_timestamps[frame_id]) * 1000
                   print(f"Frame {frame_id}: {latency:.1f}ms latency")
           
           mqtt_client.on_message = on_message
           mqtt_client.connect("192.168.4.1", 1883, 60)
           mqtt_client.subscribe("test/frame/#")
           mqtt_client.loop_forever()
       
       def run_test(self, duration=60):
           """Run latency test for N seconds"""
           Thread(target=self.capture_frames, daemon=True).start()
           Thread(target=self.display_frames, daemon=True).start()
           
           time.sleep(duration)
           
           # Analyze results
           latencies = []
           for frame_id, ts_recv in self.received_timestamps.items():
               if frame_id in self.frame_timestamps:
                   latency_ms = (ts_recv - self.frame_timestamps[frame_id]) * 1000
                   latencies.append(latency_ms)
           
           if latencies:
               print(f"Latency stats (ms):")
               print(f"  Min: {min(latencies):.1f}")
               print(f"  Max: {max(latencies):.1f}")
               print(f"  Mean: {np.mean(latencies):.1f}")
               print(f"  P95: {np.percentile(latencies, 95):.1f}")
               print(f"  P99: {np.percentile(latencies, 99):.1f}")
               
               return np.mean(latencies) < 100
           
           return False
   
   tester = LatencyTester()
   result = tester.run_test(60)
   print(f"PASS" if result else "FAIL")
   ```

**Validation:**
- Mean latency <100ms
- P99 latency <150ms
- Zero frame drops

---

### 6.2 Audio Quality and Synchronization Test

**Deliverable:** Validated audio delay <50ms, quality score ≥4/5 (MOS scale).

**Steps:**

1. **Audio Quality Test** (`firmware/test-audio.py`):
   ```python
   #!/usr/bin/env python3
   import numpy as np
   import librosa
   import soundfile as sf
   
   def measure_audio_quality(original_wav, transmitted_wav):
       """Compare audio before/after transmission"""
       
       # Load waveforms
       y_original, sr = librosa.load(original_wav, sr=48000)
       y_transmitted, _ = librosa.load(transmitted_wav, sr=48000)
       
       # Ensure same length
       min_len = min(len(y_original), len(y_transmitted))
       y_original = y_original[:min_len]
       y_transmitted = y_transmitted[:min_len]
       
       # Compute PESQ (Perceptual Evaluation of Speech Quality)
       # Requires pesq package: pip install pesq
       from pesq import pesq
       score = pesq(sr, y_original, y_transmitted, 'wb')  # wideband
       
       print(f"PESQ Score: {score:.2f} (0-4.5, higher is better)")
       print(f"Quality: {'Excellent' if score > 4 else 'Good' if score > 3 else 'Fair' if score > 2 else 'Poor'}")
       
       # STOI (Short-Time Objective Intelligibility)
       from mir_eval.separation import bss_eval_sources
       sdr, sir, sar, _ = bss_eval_sources(y_original[np.newaxis, :], y_transmitted[np.newaxis, :])
       print(f"SDR: {sdr:.2f} dB")
       
       return score
   ```

2. **Synchronization Test** (`firmware/test-audio-sync.py`):
   ```python
   #!/usr/bin/env python3
   import paho.mqtt.client as mqtt
   import time
   import json
   
   # Sensor: capture audio with frame timestamp
   # Gateway: intercept frame and audio events, measure time delta
   
   class AudioSyncTester:
       def __init__(self):
           self.frame_times = {}
           self.audio_times = {}
       
       def on_frame(self, frame_id, timestamp):
           self.frame_times[frame_id] = timestamp
       
       def on_audio(self, frame_id, audio_timestamp):
           self.audio_times[frame_id] = audio_timestamp
           
           if frame_id in self.frame_times:
               delta_ms = (audio_timestamp - self.frame_times[frame_id]) * 1000
               print(f"Frame {frame_id}: audio {delta_ms:.1f}ms after video")
       
       def results(self):
           deltas = []
           for frame_id, audio_ts in self.audio_times.items():
               if frame_id in self.frame_times:
                   delta_ms = (audio_ts - self.frame_times[frame_id]) * 1000
                   deltas.append(delta_ms)
           
           if deltas:
               print(f"Audio-video sync: {np.mean(deltas):.1f}±{np.std(deltas):.1f}ms")
               return abs(np.mean(deltas)) < 50  # <50ms acceptable
           return False
   ```

**Validation:**
- PESQ ≥3.5 (good quality)
- Audio-video sync < ±50ms

---

## Phase 7: Production Hardening (Week 12)

### 7.1 Security Hardening Checklist

**Deliverable:** Hardened images with minimal attack surface.

**Steps:**

1. **Disable Unnecessary Services:**
   ```bash
   systemctl disable avahi-daemon
   systemctl disable bluetooth
   systemctl disable cups
   # Keep only essential: ssh, mqtt, video, audio, ui services
   ```

2. **Kernel Hardening** (`build/<node>/kernel.config` additions):
   ```
   CONFIG_RANDOMIZE_BASE=y                 # ASLR
   CONFIG_STACKPROTECTOR_STRONG=y          # Stack canaries
   CONFIG_DEBUG_RODATA=y                   # RO data segment
   CONFIG_RETPOLINE=y                      # Spectre mitigation
   CONFIG_CFI=y                            # Control flow integrity
   ```

3. **Filesystem Hardening:**
   ```bash
   # Mount root with nodev, nosuid, noexec where possible
   mount -o remount,nodev,nosuid,noexec /
   mount -o remount,nodev,nosuid /var
   mount -o remount,nodev,noexec /tmp
   ```

4. **User/Permission Hardening:**
   ```bash
   # Run services as unprivileged user
   useradd -r -s /bin/false video-streamer
   useradd -r -s /bin/false mqtt-client
   
   # Restrict file permissions
   chmod 0600 /etc/systemd/system/*.service
   chmod 0600 /etc/mosquitto/mosquitto.conf
   ```

5. **Network Security:**
   ```bash
   # Enable firewall (ufw or iptables)
   ufw enable
   ufw allow 22/tcp    # SSH
   ufw allow 1883/tcp  # MQTT
   ufw deny incoming
   
   # SSH hardening
   sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
   sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
   ```

6. **Secure Boot (Pi 4 only):**
   - Generate signing key: `openssl req -newkey rsa:2048 -nodes -keyout boot.key -x509 -days 365 -out boot.crt`
   - Sign kernel: `sbsign --key boot.key --cert boot.crt --output vmlinuz-signed vmlinuz`
   - Update bootloader config to verify signature (firmware-dependent)

**Validation:**
- Security audit: `lynis audit system --quick`
- Kernel mitigation check: `grep -E "ASLR|Stack|Retpoline|CFI" /boot/config-*`
- Port scan: `nmap 192.168.4.2` should show only expected ports open

---

## Phase 8: Final Validation and Release (Week 13–14)

### 8.1 Release Validation Checklist

**Deliverable:** Production-ready images signed and released.

**Checklist:**

- [ ] All 3 nodes boot in <5 seconds (measure 5 consecutive boots, avg)
- [ ] Camera H.264 stream stable for 1 hour without frame drops
- [ ] Audio round-trip latency <50ms (P95 <75ms)
- [ ] MQTT broker handles 3 simultaneous publishers, zero message loss
- [ ] WiFi AP maintains 3 concurrent connections for 1 hour
- [ ] OTA manifest signs/verifies correctly
- [ ] Canary rollout metrics green for 2 hours before promotion
- [ ] Gateway AI model inference runs at >1 FPS on Pi 4
- [ ] Thermal management: Pi 4 fans cycle properly, Pi Zeros <60°C sustained
- [ ] Security audit: no critical vulnerabilities (Lynis score >75)
- [ ] All services auto-restart on failure (systemd Restart=on-failure)
- [ ] Logs rotate and don't fill disk (logrotate configured)
- [ ] SSH key authentication only (no password login)
- [ ] Production image size <512MB (uncompressed, per node)

**Steps:**

1. **Automated Release Pipeline** (`.github/workflows/release.yml`):
   ```yaml
   name: Production Release
   on:
     push:
       tags:
         - 'v*'
   
   jobs:
     release:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         
         - name: Run all validations
           run: |
             # Boot time test (simulated)
             bash scripts/validate-boot-time.sh
             
             # Latency test (requires hardware; skip in CI)
             # bash firmware/test-latency.py
             
             # Security audit
             bash scripts/security-audit.sh
         
         - name: Sign and package
           run: |
             # Sign manifest
             openssl dgst -sha256 -sign ${{ secrets.SIGNING_KEY }} \
               release-manifest.json > release-manifest.json.sig
             
             # Create GitHub release
             tar czf release.tar.gz \
               bundle/sensor/sensor-linux-*.img.xz* \
               bundle/ui/ui-linux-*.img.xz* \
               bundle/gateway/gateway-linux-*.img.xz* \
               release-manifest.json release-manifest.json.sig \
               public-key.pem
         
         - name: Upload release
           uses: softprops/action-gh-release@v1
           with:
             files: release.tar.gz
   ```

2. **Version Tagging and Release Notes** (`RELEASE_NOTES_v1.0.0.md`):
   ```markdown
   # Release v1.0.0: Production-Ready ADAS Edge-Cloud System
   
   ## Overview
   Fully functional ADAS perception system with:
   - Real-time H.264 video streaming (<100ms latency)
   - Multi-priority audio mixing and transport
   - Offline AI inference (MobileNet-SSD on Pi 4)
   - Secure OTA with staged rollout (canary → beta → production)
   - Validated hardware integration (all 3 Pi nodes + HATs)
   
   ## Changes
   - [ ] Buildroot images generated for Sensor, UI, Gateway
   - [ ] All services (video, audio, MQTT) functional
   - [ ] OTA signing and verification implemented
   - [ ] Security hardening applied (SELinux, ASLR, signed boot)
   - [ ] End-to-end latency <100ms validated on hardware
   - [ ] Canary fleet metrics green for 2+ hours
   
   ## Known Limitations
   - [ ] Cloud node placeholder only (requires K8s or Docker setup)
   - [ ] AI model inference single-threaded (no real-time guarantees)
   - [ ] WiFi AP range ~10m (expected for Pi Zero W antenna)
   - [ ] No cellular uplink (future: 4G modem integration)
   
   ## Installation
   1. Download images from release
   2. Verify signatures: `bash firmware/gateway/ota-verify.sh release.tar.gz`
   3. Flash to SD cards: `dd if=sensor-linux-v1.0.0.img of=/dev/sdX bs=4M`
   4. Boot all 3 nodes, verify AP appears on WiFi scan
   5. SSH into gateway, check metrics: `curl http://localhost:8080/api/metrics`
   
   ## Support
   - Issues: https://github.com/owner/pi-adas-edge-cloud/issues
   - Documentation: See docs/ folder
   ```

**Validation:**
- All checklist items pass
- Release artifacts on GitHub with signatures
- Canary fleet running v1.0.0 for >6 hours with green metrics

---

## Phase 9: Post-Launch Operations and Iteration (Ongoing)

### 9.1 Monitoring and Alerting

**Deliverable:** Dashboard and alerts for production fleet health.

**Components:**
- **Prometheus** (metrics scraper): Collect CPU, memory, latency, frame drops
- **Grafana** (visualization): Real-time dashboards per node
- **AlertManager**: Trigger on SLO violations (e.g., latency >150ms, uptime <99.9%)

**Steps:**

1. **Prometheus Configuration** (`firmware/gateway/prometheus.yml`):
   ```yaml
   global:
     scrape_interval: 15s
     evaluation_interval: 15s
   
   scrape_configs:
     - job_name: 'adas-nodes'
       static_configs:
         - targets: ['192.168.4.2:9100', '192.168.4.3:9100', '192.168.4.4:9100']
   
     - job_name: 'gateway-mqtt'
       static_configs:
         - targets: ['192.168.4.1:1883']
   ```

2. **Alert Rules** (`firmware/gateway/alert-rules.yml`):
   ```yaml
   groups:
     - name: adas-alerts
       rules:
         - alert: HighCPU
           expr: node_cpu_usage > 80
           for: 5m
           annotations:
             summary: "High CPU on {{ $labels.instance }}"
         
         - alert: HighLatency
           expr: stream_latency_ms > 150
           for: 1m
           annotations:
             summary: "Latency exceeds 150ms: {{ $value }}ms"
         
         - alert: HighTemperature
           expr: node_temperature_celsius > 80
           for: 5m
           annotations:
             summary: "Temperature critical: {{ $value }}°C"
   ```

**Validation:**
- Deploy Prometheus + Grafana on Pi 4 or cloud
- Monitor fleet for 24 hours, verify alerts trigger

---

## Appendix: Resource Estimates

| Phase | Duration | Hardware Needed | Cost (approx) |
|-------|----------|-----------------|---------------|
| 0: Infrastructure | 1 week | 1× Pi 4 (build host) | $75 |
| 1: Build System | 2 weeks | 2× Pi Zero + HATs | $50 |
| 2: Hardware Validation | 2 weeks | All 3 nodes + HATs | +$75 |
| 3: Services | 3 weeks | Pi 4 8GB for inference | +$100 |
| 4: OTA Security | 1 week | - | - |
| 5: Canary Rollout | 1 week | Production fleet | - |
| 6: Integration | 2 weeks | Test lab with display | +$50 |
| 7: Hardening | 1 week | - | - |
| 8–9: Release + Ops | 2 weeks | Cloud node (VM) | +$20/mo |
| **Total** | **14 weeks** | **~$370 one-time** | **+$20/mo cloud** |

---

## Appendix: Useful References

- **Buildroot Documentation:** https://buildroot.org/docs.html
- **Raspberry Pi Linux Kernel:** https://github.com/raspberrypi/linux/tree/rpi-6.1.y
- **Adafruit Voice Bonnet:** https://learn.adafruit.com/adafruit-voice-bonnet-a-raspberry-pi-voice-hat
- **Pimoroni Pirate Audio:** https://github.com/pimoroni/pirate-audio
- **GStreamer Pipelines:** https://gstreamer.freedesktop.org/documentation/
- **MQTT Specification:** https://mqtt.org/mqtt-specification
- **TensorFlow Lite on Raspberry Pi:** https://www.tensorflow.org/lite/guide/python
- **OTA Update Best Practices:** https://android.googlesource.com/platform/system/update_engine/+/master/docs/
- **Linux Security Hardening:** https://wiki.debian.org/Hardening

---

**Document Version:** 1.0  
**Last Updated:** 2026-05-03  
**Status:** Ready for Phase 0 execution
