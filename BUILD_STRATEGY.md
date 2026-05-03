# Build Strategy

## Init System

All nodes use **systemd** (lightweight configuration).

**Rationale:**
- Provides service supervision, dependency ordering, socket activation
- Compatible with familiar `systemctl` operations
- Acceptable RAM overhead (~4–8 MB) on Pi Zero W (512 MB RAM)

Alternative considered: OpenRC — lighter, but less ADAS-service management support.

---

## C Library

All nodes use **glibc** (GNU C Library).

**Rationale:**
- Broader binary compatibility with pre-built Python/TFLite wheels
- Required by TensorFlow Lite on Gateway
- musl would require full recompile of all native packages

---

## Filesystem Layout

| Partition | Filesystem | Size |
|-----------|-----------|------|
| `/boot`   | FAT32     | 128 MB (Pi Zero) / 512 MB (Pi 4) |
| `/`       | ext4      | 512 MB (Sensor/UI) / 2 GB (Gateway) |

**Rationale:** ext4 provides journaling (reduces SD corruption risk on power loss).

---

## Storage Footprint Estimates

| Node    | Root FS | Packages                        |
|---------|---------|---------------------------------|
| Sensor  | ~200 MB | base + alsa + ffmpeg + mosquitto |
| UI      | ~250 MB | base + drm/sdl + alsa + mosquitto |
| Gateway | ~800 MB | base + mosquitto + nginx + tflite + numpy |

---

## Build Optimization

1. **ccache**: Enable `BR2_CCACHE=y` in Buildroot — reduces rebuild time by ~80%
2. **Parallel jobs**: Set `BR2_JLEVEL=0` to use all CPU cores
3. **Shared DL dir**: Set `BR2_DL_DIR` to a common location to avoid re-downloading

---

## Per-Node Image Summary

| Node    | Hardware            | Kernel Config              | Overlay                         |
|---------|---------------------|----------------------------|----------------------------------|
| Sensor  | Pi Zero W + Voice Bonnet | `build/sensor/kernel.config` | `build/sensor/overlay/`         |
| UI      | Pi Zero W + Pirate Audio | `build/ui/kernel.config`     | `build/ui/overlay/`             |
| Gateway | Pi 4 + BrainCraft HAT    | `build/gateway/kernel.config`| `build/gateway/overlay/`        |
