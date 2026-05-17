# Real ADAS Perception Stack (Mini, Pi-Class)
## Practical Design for Pi Zero + Pi 4 QNX + Pi 5

This document defines a realistic, embedded ADAS-style perception pipeline for the current multi-node Raspberry Pi architecture.

Scope:
- Build a feasible mini perception stack on Pi Zero class hardware
- Split heavy AI between Sensor Pi 4 (QNX) and Compute Pi 5 (brain/compute)
- Tune camera streaming for 50-100 ms end-to-end latency where possible

---

## 1) Reality Check and Goal

A Pi Zero W cannot run modern full-scale ADAS DNN workloads at production frame rates. The correct approach is a compressed pipeline:

- Pi Zero Sensor: capture + lightweight CV + encode + transmit
- Pi 4 QNX Sensor: deterministic preprocessing and local fusion
- Pi 5 Gateway: heavy inference + decision logic
- Pi Zero UI: decode + render + operator interaction

This mirrors early automotive ECU partitioning: sensor front-end, central compute, and HMI node.

---

## 2) Mini ADAS Pipeline (Feasible on Pi Zero)

Pipeline:

```text
Camera -> ISP -> Frame Grab -> Preprocess -> Lightweight Inference -> Overlay -> H.264 Stream
```

### Stage A: Camera Input

Targets:
- 640x480 at 15-25 fps when CV/inference is active
- 30 fps only for low-CV or pure streaming mode

Why:
- Pi Zero CPU and memory bandwidth are limited
- Stable frame timing matters more than peak fps bursts

### Stage B: Preprocessing (CPU-Light)

Recommended operations:
- Downscale to 320x240 for detection/classification
- Optional grayscale conversion for lane/motion tasks
- Region-of-interest crop (road region) to reduce per-frame cost
- Basic normalization if model requires it

### Stage C: Lightweight Perception

Use one of:
- Quantized MobileNet-SSD class detector
- Tiny YOLO variant (very small model only)
- Classical OpenCV pipelines for lane/motion fallback

Do not target large modern detectors on Pi Zero.

### Stage D: Output Signals

Publish only compact outputs:
- Bounding boxes (object class + confidence + ROI coordinates)
- Lane edges or lane line parameters
- Motion triggers (binary + confidence/window)

Avoid transmitting heavy intermediate tensors.

### Stage E: Overlay and Transport

On Sensor node:
- Draw minimal overlays locally if needed
- Encode with hardware H.264
- Send over UDP/RTP to UI and/or Pi 5 consumers

---

## 3) ECU-Style Task Split (Recommended)

| Task | Node |
|------|------|
| Camera capture | Pi Zero Sensor |
| Lightweight CV (lane, motion, small detector) | Pi Zero Sensor |
| Heavy AI inference | Pi 5 Gateway + Sensor Pi 4 QNX |
| Decision logic and event fusion | Pi 5 Gateway |
| Display and controls | Pi Zero UI |

This split improves determinism, keeps the sensor loop lean, and aligns with embedded ADAS design practice.

---

## 4) Features You Can Realistically Run

### Lane Detection (Classical CV)
- Canny edge detection
- ROI mask (lower image trapezoid)
- Hough line transform
- Temporal smoothing over recent frames

### Motion Detection
- Frame differencing
- Threshold + morphology
- Contour filtering by area/aspect

### Lightweight Object Detection
- Quantized MobileNet-SSD or equivalent tiny detector
- Run at reduced resolution and lower frequency (for example every N frames)

---

## 5) Latency Goal: 50-100 ms End-to-End

Target budget:

| Stage | Budget |
|------|--------|
| Capture | 10-20 ms |
| Encode | 10-30 ms |
| Network | 10-30 ms |
| Decode | 10-20 ms |
| Render | 5-10 ms |

Total target:
- Typical tuned path: 50-100 ms

Note:
- Wi-Fi interference and queue buildup can move this toward 120+ ms if not controlled.

---

## 6) H.264 Low-Latency Tuning Checklist

### 6.1 Hardware Encode Only

Use the camera stack with hardware H.264 encode; avoid software codecs.

Example:

```bash
libcamera-vid --codec h264 --inline --nopreview
```

### 6.2 Short GOP / Frequent IDR

Set keyframe interval around 10-15 frames.

Benefits:
- Faster decoder recovery
- Lower startup and drift latency

Tradeoff:
- Slight bitrate overhead

### 6.3 Remove Hidden Buffers

Sender and receiver should avoid deep queues:
- No disk writes in the live path
- Minimal app-level frame queues
- No unnecessary pipeline batching

### 6.4 Prefer UDP/RTP Over TCP

- TCP adds retransmission delay and head-of-line blocking
- UDP/RTP keeps real-time behavior under packet loss

### 6.5 Keep Receiver Jitter Buffer Small

Set receiver latency to approximately 20-50 ms.

Example concept:

```bash
gst-launch-1.0 ... latency=30 ...
```

### 6.6 Fixed Bitrate Strategy

Use stable bitrate (for example 1.5-2 Mbps at VGA profile).

Why:
- Reduces burst-induced queue spikes
- Improves timing consistency

### 6.7 Baseline Profile + No B-Frames

- Baseline profile lowers decode complexity
- Disable B-frames to remove reordering delay

---

## 7) Expected Latency by Configuration

| Setup | Typical End-to-End Latency |
|------|-----------------------------|
| MJPEG path | 150-400 ms |
| H.264 (untuned) | 120-250 ms |
| H.264 (tuned, this doc) | 50-100 ms |

These are practical field ranges for Pi-class systems over Wi-Fi under moderate load.

---

## 8) Automotive-Style Notes

Real production ADAS stacks achieve low latency through:
- Hardware ISP and encoder pipelines
- Zero-copy memory paths
- Deterministic scheduling
- Automotive links (for example GMSL/FPD-Link) instead of shared Wi-Fi

In this project, tuned Wi-Fi with strict buffering discipline can still provide automotive-like responsiveness for a mini stack.

---

## 9) Recommended Final Project Mapping

### Pi Zero Sensor
- Camera capture
- Lightweight CV/lane/motion
- Hardware H.264 encode
- UDP/RTP video transmit

### Pi Zero UI
- Stream decode and display
- Button input and local UI feedback
- MQTT event publish/subscribe

### Pi 5 Gateway + Sensor Pi 4 QNX
- Heavy inference workloads
- Decision logic/state machine on Pi 5
- Deterministic preprocessing/fusion on Sensor Pi 4 QNX
- Wi-Fi AP + DHCP + MQTT broker (Pi 5)
- Cloud synchronization/telemetry bridge

---

## 10) Acceptance Criteria

Minimum for milestone completion:
- Stable capture and stream at 640x480 with tuned H.264
- Measured end-to-end latency <= 100 ms in controlled Wi-Fi conditions
- Lane or motion feature running continuously on Sensor node
- Heavy AI path executed on Pi 5/Sensor QNX without stalling Sensor stream loop
- UI node shows live stream and can emit control events via MQTT
