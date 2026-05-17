# Developer Guide
## Build, Update, and Release Workflow

Repository: pi-adas-edge-cloud

This guide explains how to build artifacts, update the repo safely, and release versions for all nodes.

Scope:
- Edge nodes:
  - Sensor Pi Zero (Buildroot Linux)
  - Sensor Pi 4 (QNX Neutrino RTOS)
  - UI Pi Zero (Buildroot Linux)
  - Compute Pi 5 (Linux optimized for AI runtime)
- Cloud node: container/bundle artifacts (not SD card images)

---

## 1. Current Build Model

Build entry points:
- scripts/build-node.sh (Linux-based edge nodes)
- scripts/build-qnx-sensor.sh (QNX Neutrino sensor node)
- scripts/build-cloud.sh
- scripts/generate-ota-manifest.sh

Target build scripts:
- build/sensor-linux/build.sh (Pi Zero sensor node)
- build/sensor-qnx/build.sh (Pi 4 QNX sensor node)
- build/ui/build.sh
- build/gateway/build.sh
- cloud/build.sh

CI workflow:
- .github/workflows/build-all-nodes.yml

Outputs:
- Sensor-Linux/UI/Gateway Linux: <target>-linux-<version>.img and optional .img.xz; Sensor-QNX: sensor-qnx-<version> artifact
- Cloud: cloud-bundle-<version>.tar.gz and images.txt
- Release: unified manifest JSON via generate-ota-manifest.sh

---

## 2. Prerequisites (Local)

Minimum tools:
- bash
- tar
- xz (optional but recommended)
- shasum or sha256sum

For real filesystem images:
- mkfs.ext4 (for fallback image formatting)

For flashing SD cards:
- dd (macOS/Linux) or Raspberry Pi Imager

---

## 3. Local Build Commands

### 3.1 Build edge node images

#### Linux-based nodes (Pi Zero and Pi 5)
```bash
./scripts/build-node.sh sensor-linux v0.4.0 out/sensor-linux
./scripts/build-node.sh ui v0.4.0 out/ui
./scripts/build-node.sh gateway v0.4.0 out/gateway
```

#### QNX-based sensor node (Pi 4)
```bash
./scripts/build-qnx-sensor.sh v0.4.0 out/sensor-qnx
```

### 3.2 Build cloud bundle

```bash
./scripts/build-cloud.sh v0.4.0 out/cloud
```

### 3.3 Generate release/OTA manifest

```bash
mkdir -p bundle
cp -R out/sensor-linux bundle/sensor-linux
cp -R out/sensor-qnx bundle/sensor-qnx
cp -R out/ui bundle/ui
cp -R out/gateway bundle/gateway
cp -R out/cloud bundle/cloud
./scripts/generate-ota-manifest.sh v0.4.0 bundle out/release-manifest.json
```

---

## 4. CI Build and Release Flow

The workflow .github/workflows/build-all-nodes.yml performs:
1. Matrix edge build for sensor-linux, sensor-qnx, ui, and gateway
2. Cloud build
3. Artifact normalization
4. Unified release manifest generation

Trigger options:
- Push to main
- Manual workflow_dispatch

Recommended release process:
1. Merge tested build changes to main.
2. Tag release (for example v0.4.0).
3. Run workflow and verify all artifacts uploaded.
4. Validate manifest integrity and checksums.
5. Promote via OTA (canary -> ramp -> full rollout).

---

## 5. Update Workflow (Developer)

For build-system changes:
1. Edit target scripts under build/*/build.sh or cloud/build.sh.
2. Run local smoke builds for all targets.
3. Regenerate manifest and inspect output paths/checksums.
4. Open PR with:
   - changed scripts
   - expected artifact names
   - migration notes (if any)

For service/runtime changes:
1. Update firmware payload directories when introduced.
2. Build node image artifacts.
3. Test boot and service startup on actual hardware.
4. Promote release through canary group first.

---

## 6. Flashing SD Cards (Edge Nodes)

### 6.1 Identify image file
- Sensor (Pi Zero): out/sensor-linux/sensor-linux-<version>.img (or .img.xz)
- Sensor (Pi 4, QNX): out/sensor-qnx/sensor-qnx-<version>.img (or bootable artifact)
- UI (Pi Zero): out/ui/ui-linux-<version>.img (or .img.xz)
- Compute (Pi 5): out/gateway/gateway-linux-<version>.img (or .img.xz)

### 6.2 Flash with dd (example)

```bash
# macOS example: find disk first with diskutil list
# WARNING: replace /dev/rdiskN with the correct target disk

# Pi Zero Sensor Node (Linux)
sudo diskutil unmountDisk /dev/diskN
xz -dc out/sensor-linux/sensor-linux-v0.4.0.img.xz | sudo dd of=/dev/rdiskN bs=4m status=progress
sync
sudo diskutil eject /dev/diskN

# Pi 4 Sensor Node (QNX)
# Flash QNX bootable artifact (image format varies based on QNX build output)
sudo diskutil unmountDisk /dev/diskN
# Adjust command based on QNX artifact type (may be .qnx-ota, .qnx.img, etc.)
sudo dd if=out/sensor-qnx/sensor-qnx-v0.4.0.img of=/dev/rdiskN bs=4m status=progress
sync
sudo diskutil eject /dev/diskN

# UI Node (Pi Zero Linux)
sudo diskutil unmountDisk /dev/diskN
xz -dc out/ui/ui-linux-v0.4.0.img.xz | sudo dd of=/dev/rdiskN bs=4m status=progress
sync
sudo diskutil eject /dev/diskN

# Compute Node (Pi 5 Linux)
sudo diskutil unmountDisk /dev/diskN
xz -dc out/gateway/gateway-linux-v0.4.0.img.xz | sudo dd of=/dev/rdiskN bs=4m status=progress
sync
sudo diskutil eject /dev/diskN
```

---

## 7. What Is Still Pending for Fully Functional Flashable Images

The repo now produces Linux and QNX image artifacts, but several production-critical pieces are still missing.

### 7.1 Buildroot/Pi image definitions and QNX boot provisioning are not present
Missing now:
- Buildroot target defconfig files (Pi Zero and Pi 5 variants)
- QNX Neutrino board support package for Pi 4
- QNX boot partition assembly and kernel module provisioning
- board support package layout for Linux nodes
- post-build and post-image scripts
- partition layout definitions for boot/rootfs per platform

Impact:
- Current scripts can output fallback ext4 image files, but these are placeholders if no real source image exists.
- QNX sensor node builds require QNX SDK integration and boot artifact packaging.

### 7.2 Boot firmware and bootloader packaging not defined
Missing now:
- Pi boot partition contents (firmware, kernel, cmdline, config) for Pi Zero and Pi 5
- Pi Zero, Pi 4 (Linux), and Pi 4 (QNX) boot config differences
- QNX bootloader and IFS (Image FileSytem) generation
- deterministic kernel module set per node and OS

Impact:
- Linux images may not boot on hardware until boot assets are assembled correctly.
- QNX sensor node requires specialized boot provisioning not yet integrated.

### 7.3 Root filesystem composition is not defined per node
Missing now:
- Buildroot package lists per node (sensor-linux, sensor-qnx, ui, gateway)
- QNX process and service definitions for sensor node
- service unit/init scripts per node and OS
- node-specific network and MQTT config templates
- multi-node discovery and topic namespace assignment

Impact:
- Even if image boots, required services may not start or connect correctly.
- QNX sensor node integration into Linux-based MQTT mesh not yet complete.

### 7.4 First-boot provisioning pipeline is not implemented
Missing now:
- hostname and device-id provisioning (per node and OS type)
- SSH key/bootstrap policy
- static DHCP identity and topic namespace assignment
- sensor node discovery and registration with compute node (multi-node orchestration)
- QNX-Linux cross-platform provisioning

Impact:
- Multi-node fleet behavior and reproducibility are not guaranteed.
- QNX sensor node may not auto-register with Linux gateway at first boot.

### 7.5 Hardware validation and HAT bring-up scripts are not integrated
Missing now:
- camera, audio codec, display, button, and LED hardware tests in image build validation
- automated artifact acceptance checks

Impact:
- Build success does not yet guarantee hardware-functional images.

### 7.6 Signed release and OTA trust chain not yet wired
Missing now:
- artifact signing for Linux and QNX artifacts
- signature verification in gateway OTA flow (multi-node update coordination)
- rollback policy enforcement in automation
- QNX sensor node OTA capability and recovery

Impact:
- Release pipeline is functional but not yet production-secure.
- QNX sensor updates not yet safely deployable at scale.

---

## 8. Recommended Next Implementation Sequence

1. Add real image pipelines for each edge target:
- Buildroot config + board files for sensor-linux (Pi Zero) and ui (Pi Zero)
- Pi 5 image pipeline for gateway
- QNX Neutrino BSP integration and IFS generation for sensor-qnx (Pi 4)

2. Add rootfs overlays and service startup definitions per node and OS.

3. Add boot partition assembly and per-model boot config (Pi Zero, Pi 5, QNX).

4. Implement multi-node discovery and orchestration in gateway.

5. Add hardware smoke tests as build gates (Linux and QNX variants).

6. Implement QNX-Linux interoperability validation and testing.

7. Add signed artifacts and OTA policy enforcement.

8. Promote to canary hardware fleet before full deployment.

---

## 9. Definition of Done (Flashable Production Images)

Edge image generation is production-ready when all are true:
- sensor-linux-<version>.img boots on Pi Zero and starts required services
- sensor-qnx-<version> boots on Pi 4 and starts QNX services
- ui-linux-<version>.img boots on Pi Zero and starts display/audio/button services
- gateway-linux-<version>.img boots on Pi 5 and starts AP/MQTT/multi-node orchestration services
- sensor-qnx node discovers and registers with gateway at first boot
- multi-node MQTT mesh established (Linux and QNX nodes connected)
- hardware acceptance checks pass on real devices (all platforms)
- release manifest includes checksums and signed metadata
- OTA canary + rollback validated end-to-end (multi-platform)
