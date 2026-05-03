# Developer Guide
## Build, Update, and Release Workflow

Repository: pi-adas-edge-cloud

This guide explains how to build artifacts, update the repo safely, and release versions for all nodes.

Scope:
- Edge nodes (Sensor Pi Zero, UI Pi Zero, Gateway Pi 4): Linux image artifacts
- Cloud node: container/bundle artifacts (not SD card images)

---

## 1. Current Build Model

Build entry points:
- scripts/build-node.sh
- scripts/build-cloud.sh
- scripts/generate-ota-manifest.sh

Target build scripts:
- build/sensor/build.sh
- build/ui/build.sh
- build/gateway/build.sh
- cloud/build.sh

CI workflow:
- .github/workflows/build-all-nodes.yml

Outputs:
- Sensor/UI/Gateway: <target>-linux-<version>.img and optional .img.xz
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

### 3.1 Build one edge node image

```bash
./scripts/build-node.sh sensor v0.4.0 out/sensor
./scripts/build-node.sh ui v0.4.0 out/ui
./scripts/build-node.sh gateway v0.4.0 out/gateway
```

### 3.2 Build cloud bundle

```bash
./scripts/build-cloud.sh v0.4.0 out/cloud
```

### 3.3 Generate release/OTA manifest

```bash
mkdir -p bundle
cp -R out/sensor bundle/sensor
cp -R out/ui bundle/ui
cp -R out/gateway bundle/gateway
cp -R out/cloud bundle/cloud
./scripts/generate-ota-manifest.sh v0.4.0 bundle out/release-manifest.json
```

---

## 4. CI Build and Release Flow

The workflow .github/workflows/build-all-nodes.yml performs:
1. Matrix edge build for sensor/ui/gateway
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
- Sensor: out/sensor/sensor-linux-<version>.img (or .img.xz)
- UI: out/ui/ui-linux-<version>.img (or .img.xz)
- Gateway: out/gateway/gateway-linux-<version>.img (or .img.xz)

### 6.2 Flash with dd (example)

```bash
# macOS example: find disk first with diskutil list
# WARNING: replace /dev/rdiskN with the correct target disk
sudo diskutil unmountDisk /dev/diskN
xz -dc out/sensor/sensor-linux-v0.4.0.img.xz | sudo dd of=/dev/rdiskN bs=4m status=progress
sync
sudo diskutil eject /dev/diskN
```

Repeat per node with the correct image.

---

## 7. What Is Still Pending for Fully Functional Flashable Images

The repo now produces Linux image artifacts, but several production-critical pieces are still missing.

### 7.1 Buildroot/Pi image definitions are not present
Missing now:
- target defconfig files
- board support package layout
- post-build and post-image scripts
- partition layout definitions for boot/rootfs

Impact:
- Current scripts can output fallback ext4 image files, but these are placeholders if no real source image exists.

### 7.2 Boot firmware and bootloader packaging not defined
Missing now:
- Pi boot partition contents (firmware, kernel, cmdline, config)
- Pi Zero vs Pi 4 boot config differences
- deterministic kernel module set per node

Impact:
- Images may not boot on hardware until boot assets are assembled correctly.

### 7.3 Root filesystem composition is not defined per node
Missing now:
- package lists per node
- service unit/init scripts per node
- node-specific network and MQTT config templates

Impact:
- Even if image boots, required services may not start or connect correctly.

### 7.4 First-boot provisioning pipeline is not implemented
Missing now:
- hostname and device-id provisioning
- SSH key/bootstrap policy
- static DHCP identity and topic namespace assignment

Impact:
- Multi-node fleet behavior and reproducibility are not guaranteed.

### 7.5 Hardware validation and HAT bring-up scripts are not integrated
Missing now:
- camera, audio codec, display, button, and LED hardware tests in image build validation
- automated artifact acceptance checks

Impact:
- Build success does not yet guarantee hardware-functional images.

### 7.6 Signed release and OTA trust chain not yet wired
Missing now:
- artifact signing
- signature verification in gateway OTA flow
- rollback policy enforcement in automation

Impact:
- Release pipeline is functional but not yet production-secure.

---

## 8. Recommended Next Implementation Sequence

1. Add real image pipelines for each edge target:
- Buildroot config + board files for sensor/ui
- Pi 4 image pipeline for gateway

2. Add rootfs overlays and service startup definitions per node.

3. Add boot partition assembly and per-model boot config.

4. Add hardware smoke tests as build gates.

5. Add signed artifacts and OTA policy enforcement.

6. Promote to canary hardware fleet before full deployment.

---

## 9. Definition of Done (Flashable Production Images)

Edge image generation is production-ready when all are true:
- sensor-linux-<version>.img boots on Pi Zero and starts required services
- ui-linux-<version>.img boots on Pi Zero and starts display/audio/button services
- gateway-linux-<version>.img boots on Pi 4 and starts AP/MQTT/bridge services
- hardware acceptance checks pass on real devices
- release manifest includes checksums and signed metadata
- OTA canary + rollback validated end-to-end
