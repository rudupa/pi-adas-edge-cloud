# Bandwidth Planning

## Table of Contents

- [0. Codec Choice: MJPEG vs H.264 (Read This First)](#0-codec-choice-mjpeg-vs-h264-read-this-first)
- [1. Sensor Node](#1-sensor-node-pi-zero-w-v11)
- [2. UI Node](#2-ui-node-pi-zero-w-v11)
- [3. Gateway + Master Node](#3-gateway--master-node-pi-4)
- [4. Codec + Resolution Bitrate Quick-Reference Table](#4-codec--resolution-bitrate-quick-reference-table)
- [5. Practical Rules of Thumb](#5-practical-rules-of-thumb)
- [6. H.264 Frame Drop Behaviour and Recovery](#6-h264-frame-drop-behaviour-and-recovery)

---

Bandwidth numbers below are practical planning values for stable operation, not peak PHY rates.

---

## 0. Codec Choice: MJPEG vs H.264 (Read This First)

Codec choice is the single biggest lever on both bandwidth and CPU usage for Pi Zero W streaming.

### How MJPEG works
- Every frame is a full independent JPEG image
- No relationship between frames
- Encoding cost per second: full image compression × FPS
- Runs entirely on the CPU — no hardware acceleration on Pi Zero
- High bandwidth: more Wi-Fi load → more CPU interrupts → compounding CPU pressure

### How H.264 works
- First frame is a full image (I-frame)
- Subsequent frames encode only differences from the previous frame (P/B frames)
- Motion estimation + residuals only — reuses prior frame data
- Uses the Pi Zero's **VideoCore IV hardware encoder block**
- CPU feeds frames and sets parameters; the GPU block handles compression
- Result: CPU is mostly idle during encoding

### Why H.264 uses less CPU than MJPEG on Pi Zero W

MJPEG runs full DCT + quantization + Huffman encode on every frame, 30× per second, entirely in software.
H.264 offloads motion estimation, DCT, and entropy coding to hardware. The CPU cost does not scale with FPS the same way.

Mental model:
- MJPEG = photocopy every page of a document, 30 times per second
- H.264 = write down only what changed on each page

### Practical comparison at 640x480 / 30fps on Pi Zero W

| Feature          | MJPEG            | H.264                    |
|------------------|-----------------|-------------------------|
| CPU load         | High (software)  | Low (hardware encoder)   |
| Bandwidth        | ~8 to 14 Mbps    | ~1 to 3 Mbps             |
| Latency          | Low              | Very low (when tuned)    |
| Quality per bit  | Poor             | Excellent                |
| Wi-Fi stress     | High             | Low                      |
| Decoder cost     | Trivial          | Moderate (hw-assisted)   |

### H.264 tradeoffs
- Decoder on receiver is more complex than MJPEG (handled fine by Pi Zero/Pi 4 via hardware decode)
- GOP structure means slight buffering latency; keep GOP size small (e.g. 15–30 frames) to minimise this
- More complex pipeline to set up initially

### Recommendation for this system
Use **H.264 via the VideoCore hardware encoder** (`raspivid` or `libcamera-vid --codec h264`) as the primary codec.
MJPEG is acceptable as a fallback for debugging or extremely latency-sensitive use only.

---

## 1. Sensor Node (Pi Zero W v1.1)

- Radio class: 2.4GHz 802.11n
- Typical usable throughput (real-world):
  - UDP: ~15 to 35 Mbps
  - TCP: ~10 to 30 Mbps
- Recommended easy/safe sustained payload budget:
  - 6 to 12 Mbps total continuous payload

Target transmission profile (30fps, H.264 recommended):
- Video stream: H.264 640x480 at 30 fps, ~1–3 Mbps (hardware encoder)
- Audio stream: Opus 48 kHz stereo: ~0.032 to 0.128 Mbps
- MQTT control/status overhead: <0.05 Mbps
- Total: ~1.1 to 3.2 Mbps (well inside safe budget)

Alternative — MJPEG if H.264 pipeline not yet set up:
- Video stream: MJPEG 640x480 at 30 fps: ~8 to 14 Mbps
- Total: ~8.1 to 14.2 Mbps
- ⚠️ Exceeds the Pi Zero W safe budget of 6–12 Mbps. Expect frame drops and CPU pressure.

MJPEG mitigation options if you must use it:
1. Drop to 320x240 at 30 fps: ~1.5 to 2.5 Mbps — comfortable budget, keeps 30fps
2. 640x480 at 30 fps with reduced Q factor: ~5 to 8 Mbps — marginal
3. Use event-driven streaming to reduce sustained link load

## 2. UI Node (Pi Zero W v1.1)

- Radio class: 2.4GHz 802.11n
- Typical usable throughput (real-world):
  - UDP: ~15 to 35 Mbps
  - TCP: ~10 to 30 Mbps
- Recommended easy/safe sustained payload budget:
  - 6 to 12 Mbps total continuous payload

Target reception/transmission profile (30fps, H.264):
- Receive Sensor video H.264 640x480/30fps: ~1 to 3 Mbps
- Receive Sensor audio Opus: ~0.032 to 0.128 Mbps
- Send button events + status (MQTT): <0.05 Mbps
- Total link usage on UI node: ~1.1 to 3.2 Mbps (comfortably inside budget)

With H.264, Pi Zero W receive + decode is hardware-assisted and manageable at 640x480/30fps.
If using MJPEG instead: same ⚠️ constraint applies — total rises to ~8–14 Mbps and
decode CPU load is high. Use 320x240/30fps MJPEG as fallback in that case.

If optional upstream voice command capture is enabled:
- Add uplink Opus voice: ~0.024 to 0.064 Mbps
- New total remains within easy range in most deployments

## 3. Gateway + Master Node (Pi 4)

- WLAN backhaul to nodes:
  - 2.4/5GHz Wi-Fi (802.11ac capable)
  - Typical usable throughput varies strongly by band, channel width, and interference
- Wired uplink:
  - Gigabit Ethernet practical payload commonly ~900+ Mbps on clean LAN paths
- Recommended easy/safe sustained payload budget for this project:
  - Local WLAN aggregation: 20 to 80 Mbps (conservative, stable design target)
  - Cloud uplink for telemetry/snapshots: 1 to 10 Mbps is usually sufficient

Whole-system data load at 30fps (H.264 primary codec):
- Sensor -> UI video+audio H.264/Opus: ~1.1 to 3.2 Mbps
- UI -> Gateway+Master control/events: <0.05 Mbps
- Sensor -> Gateway+Master status/commands: <0.05 Mbps
- Optional Sensor -> Gateway+Master duplicate audio tap: ~0.032 to 0.128 Mbps
- Cloud telemetry (status/logs/snapshots): ~0.2 to 2 Mbps typical
- Aggregate on Gateway+Master: ~1.4 to 5.5 Mbps (well within Pi 4 headroom)

With MJPEG instead: aggregate rises to ~8.3 to 16.5 Mbps — still within Pi 4 headroom
but puts both Pi Zero W nodes under significant pressure.

## 4. Codec + Resolution Bitrate Quick-Reference Table

### H.264 (hardware encoder — recommended)
| Resolution | FPS | Estimated Bitrate  | CPU load on Pi Zero W |
|------------|-----|--------------------|----------------------|
| 320x240    | 30  | ~0.3 to 0.8 Mbps   | Very low             |
| 640x480    | 30  | ~1 to 3 Mbps       | Low                  |
| 640x480    | 30  | ~0.5 to 1.5 Mbps   | Low (lower bitrate)  |
| 1280x720   | 30  | ~2 to 5 Mbps       | Low-medium           |

Capture command example (Pi Zero W):
```bash
libcamera-vid --codec h264 --width 640 --height 480 --framerate 30 --bitrate 2000000 -o -
```
Or with raspivid (legacy):
```bash
raspivid -w 640 -h 480 -fps 30 -b 2000000 -t 0 -o -
```

### MJPEG (software — fallback/debug only)
| Resolution | FPS | Quality  | Estimated Bitrate  | CPU load on Pi Zero W |
|------------|-----|----------|--------------------|-----------------------|
| 320x240    | 30  | medium   | ~1.5 to 2.5 Mbps  | Medium                |
| 640x480    | 15  | medium   | ~3 to 6 Mbps      | High                  |
| 640x480    | 20  | medium   | ~4 to 8 Mbps      | High                  |
| 640x480    | 30  | medium   | ~8 to 14 Mbps     | Very high ⚠️          |
| 800x600    | 15  | medium   | ~5 to 9 Mbps      | Very high ⚠️          |

Capture command example (MJPEG via GStreamer):
```bash
libcamera-vid --codec mjpeg --width 640 --height 480 --framerate 30 -o -
```

## 5. Practical Rules of Thumb

- Use H.264 hardware encoding as the default codec — it gives 30fps at ~1–3 Mbps with low CPU load.
- Plan continuous traffic to stay below ~50% of measured real throughput on each wireless node.
- For Pi Zero W links on H.264, treat 3 to 6 Mbps as an easy long-run budget (plenty of headroom).
- If problems arise at 30fps, tune in this order:
  1. Reduce H.264 bitrate target (e.g. from 2 Mbps to 1 Mbps) — quality drops slightly, FPS stays
  2. Drop resolution to 320x240 — keeps 30fps, bitrate falls to ~0.3–0.8 Mbps
  3. Reduce fps to 20 only as a last resort
  4. Do NOT switch to MJPEG as a fix — it will make CPU and bandwidth worse, not better
- Keep H.264 GOP size small (15–30 frames) to minimise end-to-end latency.
- Prefer UDP for media streams; TCP retransmits add latency spikes on congested Wi-Fi.
- Monitor with `iw dev wlan0 station dump` (signal/retransmit) and `vcgencmd measure_temp` (thermal) on each node.

---

## 6. H.264 Frame Drop Behaviour and Recovery

Unlike MJPEG (where each frame is independent), H.264 frames depend on each other.
Dropping a frame has consequences that extend well beyond the single lost frame.

### Frame types and what dropping each one means

**I-frame (keyframe) dropped:**
- The decoder has no reference image to build on
- Every P/B frame until the next I-frame decodes as garbage — green blocks, macroblocking, or a frozen image
- Corruption lasts for the entire GOP length

**P-frame dropped:**
- All subsequent P-frames in the GOP that reference it also corrupt, cascading forward
- Clears only when the next I-frame arrives

**B-frame dropped:**
- Less severe — B-frames reference both past and future frames so impact is more localised
- Still causes visible artifacts in the affected region

### Why GOP size is the most important tuning parameter

```
GOP = 30 frames @ 30fps = up to 1 second of corruption per dropped I-frame
GOP = 15 frames @ 30fps = up to 0.5 seconds
GOP =  5 frames @ 30fps = up to ~167ms  ← safest for streaming over Wi-Fi
```

Smaller GOP = faster recovery after packet loss, but slightly more bandwidth (more I-frames per second).
For a local 2.4GHz AP with low baseline loss, GOP of 15 is a good starting point.

### Mitigations

| Mitigation | How | Effect |
|---|---|---|
| Small GOP size | `--intra 15` or `-g 15` | Limits corruption window to ~0.5s |
| Inline headers | `--inline` | Embeds SPS/PPS in every I-frame; decoder can recover immediately |
| Intra-refresh | spread I-frame data across many frames | No single vulnerable keyframe; gradual refresh |
| RTP PLI | Picture Loss Indication via RTP | Receiver requests a fresh I-frame on detected loss |
| FEC | Forward Error Correction in GStreamer RTP | Recovers lost packets before decoder sees them |
| Reliable local AP | Short-range 2.4GHz, good signal | Minimises loss in the first place |

### Recommended capture command for this system

```bash
# raspivid — GOP 15, inline headers, 2 Mbps, 640x480/30fps
raspivid -w 640 -h 480 -fps 30 -b 2000000 -g 15 --inline -t 0 -o -
```

```bash
# libcamera-vid equivalent
libcamera-vid --codec h264 --width 640 --height 480 --framerate 30 \
  --bitrate 2000000 --intra 15 --inline -o -
```

`--inline` is important: without it, a decoder joining mid-stream or recovering after loss
cannot start decoding until it receives the next out-of-band SPS/PPS. With `--inline` every
I-frame is self-sufficient.

### Comparison: MJPEG vs H.264 on frame loss

| Scenario | MJPEG | H.264 (GOP=30) | H.264 (GOP=15, inline) |
|---|---|---|---|
| 1 frame lost | 1 frame missing | Up to 1s corrupted | Up to 0.5s corrupted |
| Recovery | Instant (next frame) | Next I-frame | Next I-frame (~0.5s) |
| Bandwidth cost | High always | Low | Slightly higher than GOP=30 |
| Best for low-loss LAN | Wastes bandwidth | Good | Recommended |
| Best for lossy link | Tolerant | Poor | Acceptable |
