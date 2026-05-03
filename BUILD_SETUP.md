# Build Setup Guide

## Overview

This guide covers setting up the build host for generating Linux images for all
three edge nodes in the pi-adas-edge-cloud system:

| Node    | Hardware              | Architecture |
|---------|----------------------|--------------|
| Sensor  | Raspberry Pi Zero W  | ARMv6l / BCM2835 |
| UI      | Raspberry Pi Zero W  | ARMv6l / BCM2835 |
| Gateway | Raspberry Pi 4 Model B | ARMv7l / BCM2711 |

---

## Supported Build Hosts

| OS                 | Status  |
|--------------------|---------|
| Ubuntu 22.04 LTS   | ✅ Tested |
| Ubuntu 20.04 LTS   | ✅ Compatible |
| macOS 13+ (Ventura)| ⚠️  Requires Docker or cross-compile toolchain |
| Debian 11+         | ✅ Compatible |

---

## Prerequisites

### Required packages (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install -y \
    build-essential gcc make rsync git wget bc \
    libncurses-dev libssl-dev libelf-dev \
    python3 python3-pip \
    gcc-arm-linux-gnueabihf \
    device-tree-compiler \
    xz-utils
```

### Disk Space

- **Minimum**: 50 GB free per node build (Buildroot output can be large)
- **Recommended**: 200+ GB for all 3 nodes simultaneously

---

## Initial Setup

### 1. Validate Host

```bash
bash scripts/validate-host.sh
```

### 2. Setup Buildroot

```bash
bash scripts/setup-buildroot.sh
```

This will:
- Clone Buildroot 2024.02 into `build/buildroot-src/`
- Create output directories for each node

---

## Build Commands

### Per-node build

```bash
bash scripts/build-node.sh sensor  v0.1.0 out/sensor
bash scripts/build-node.sh ui      v0.1.0 out/ui
bash scripts/build-node.sh gateway v0.1.0 out/gateway
```

### All nodes (via CI)

The GitHub Actions workflow `.github/workflows/build-all-nodes.yml` runs builds
in parallel for all three nodes.

---

## Toolchain

- **Pi Zero W (sensor/ui):** `arm-linux-gnueabihf` (ARMv6 + hard-float ABI)
- **Pi 4 (gateway):** `arm-linux-gnueabihf` (ARMv7 compatible)
- Both use the Buildroot-managed internal toolchain from `build/buildroot-src/`

### Build Time Estimates

| Node    | Buildroot (first) | Incremental |
|---------|--------------------|-------------|
| Sensor  | ~60–90 min         | ~10–15 min  |
| UI      | ~60–90 min         | ~10–15 min  |
| Gateway | ~75–120 min        | ~15–20 min  |

### ccache

Enable ccache to dramatically speed up incremental builds:

```bash
export BR2_CCACHE=y
export BR2_CCACHE_DIR="${HOME}/.buildroot-ccache"
```

---

## External Sources

Buildroot fetches the following during the first build:

- **Raspberry Pi Kernel**: https://github.com/raspberrypi/linux/  (branch `rpi-6.1.y`)
- **RPi Firmware**: https://github.com/raspberrypi/firmware/
- **RPi Userland**: https://github.com/raspberrypi/userland/

For air-gapped builds, pre-download into `build/external-sources/` and configure
`BR2_PRIMARY_SITE` in the defconfig.
