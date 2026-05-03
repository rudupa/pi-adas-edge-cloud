# Audio Usage in ADAS and AV Systems
## Practical Guide for Pi Zero + Pi 4 Architecture

This document explains how audio is used in ADAS and autonomous vehicle (AV) style systems, and maps those patterns to this project.

---

## 1. Why Audio Matters in ADAS/AV

Audio is not only infotainment. In safety-oriented systems, audio provides:
- Immediate hazard warnings when visual attention is overloaded
- Redundant feedback channel for critical events
- Voice interface for hands-free control
- Human-machine trust cues (status tones, confirmations, degradations)

For low-cost embedded stacks, audio is often the fastest way to communicate urgency.

---

## 2. Audio Functions by System Type

### ADAS-focused systems
Primary audio roles:
- Forward collision warning tones
- Lane departure warning beeps
- Blind spot warning tones
- Driver prompts (slow down, check surroundings)

Characteristics:
- Short, deterministic cues
- High priority and low latency
- Mostly local generation (do not depend on cloud)

### AV-focused systems
Primary audio roles:
- System state announcements (engaged, disengaged, takeover required)
- Passenger interaction via voice assistant
- External awareness cues in some platforms
- Service and diagnostic notifications

Characteristics:
- Broader audio catalog
- Multi-level priority and scheduling
- More context-aware voice content

---

## 3. Audio Signal Categories

Use a strict priority model to avoid unsafe behavior.

| Priority | Category | Examples | Latency Target |
|----------|----------|----------|----------------|
| P0 | Safety critical | Collision, immediate takeover | less than 100 ms |
| P1 | Safety advisory | Lane drift, proximity caution | 100-200 ms |
| P2 | Operational status | Recording active, degraded mode | 200-500 ms |
| P3 | Informational | Startup chime, noncritical logs | best effort |

Rules:
- P0 can preempt all lower priority audio
- P1 can duck P2/P3 volume
- P2/P3 must never block P0/P1 output

---

## 4. End-to-End Audio Pipeline (Generic)

```text
Mic/Input -> Capture -> Preprocess -> Detect/Classify -> Event Decision -> Audio Renderer -> Speaker
```

Optional branch for distributed systems:

```text
Capture -> Encode (Opus) -> UDP transport -> Decode -> Render
```

Design goals:
- Keep safety cues local when possible
- Avoid deep jitter buffers in warning path
- Separate media streaming from control events

---

## 5. Mapping to This Project

### Sensor Pi Zero
- Captures mic input (Voice Bonnet path)
- Streams encoded audio to UI and/or Pi 4
- Can run lightweight trigger logic (for example threshold/event gating)

### Gateway + Master Pi 4
- Performs heavier analysis (speech recognition, context logic)
- Converts detections/state to audio event commands
- Publishes event commands over MQTT

### UI Pi Zero
- Acts as the in-car dashboard HMI endpoint
- Hosts the voice assistant interaction loop (wake, listen, confirm, playback)
- Receives and decodes audio stream
- Mixes safety tones, assistant prompts, and media audio by priority
- Drives the local speaker system (Pirate Audio path)

Dashboard-oriented behavior:
- Safety alerts always preempt assistant/media playback
- Assistant responses are short, deterministic, and state-aware
- UI events (button press, mute, push-to-talk) directly affect audio policy

---

## 6. Recommended Split: Audio Data vs Audio Events

### Audio data plane (real-time media)
- Protocol: UDP with Opus
- Purpose: low-latency streaming voice/audio
- Typical bitrate: 32-128 kbps depending on quality mode

### Audio event plane (control)
- Protocol: MQTT
- Purpose: trigger and manage warnings/prompts
- Payload: compact JSON with event id, priority, timeout, and optional text id

This separation improves resilience: even if media quality dips, safety events still propagate.

---

## 7. Suggested MQTT Topic Model

Suggested topics:
- audio/event/request
- audio/event/active
- audio/event/clear
- audio/tts/request
- audio/tts/state
- system/audio/health

Suggested event payload fields:
- event_id
- priority
- source_node
- created_ts
- expires_ms
- debounce_ms
- ack_required

---

## 8. Timing and Buffering Guidelines

### Alert path (P0/P1)
- Keep total path under 100-200 ms
- Use minimal queue depth
- Avoid blocking operations in callback path

### Voice and noncritical prompts (P2/P3)
- Allow modest buffering for smooth playback
- Can use queueing and retry behavior

### Network behavior
- Prefer fixed packetization intervals
- Monitor packet loss and jitter continuously
- Under congestion, degrade gracefully:
  - lower bitrate
  - reduce noncritical stream activity
  - preserve P0/P1 alerts first

---

## 9. Safety and Human Factors

Audio policy should include:
- Distinct tones per hazard class (no ambiguous sounds)
- Rate limiting for repeated alerts
- Escalation profile (advisory -> warning -> critical)
- Cooldown and suppression logic to prevent alarm fatigue
- Spoken prompts only when they do not mask critical tones

Fail-safe behavior:
- If voice pipeline fails, fallback to deterministic tone alerts
- If speaker path fails, publish fault and raise visual backup cue
- Log all P0/P1 misses and late alerts for post-analysis

---

## 10. KPIs for Validation

Track these metrics during testing:
- Alert trigger-to-sound latency (P50/P95/P99)
- Audio packet loss and jitter
- Decoder underrun/overrun counts
- Event miss rate and duplicate rate
- CPU load on Sensor/UI nodes
- Mean time to audio recovery after network drop

Acceptance suggestions:
- P0 latency P95 under 100 ms in controlled Wi-Fi
- P1 latency P95 under 200 ms
- No dropped P0 alerts during 30-minute stress test

---

## 11. Implementation Plan for This Repo

1. Define audio event schema and topic contracts.
2. Implement priority mixer on UI node.
3. Add preemption and ducking rules.
4. Instrument latency timestamps at each stage.
5. Add watchdog/fallback tone path.
6. Run stress tests with induced packet loss and verify KPI thresholds.

---

## 12. Summary

For ADAS/AV behavior, audio should be designed as a safety channel first and a media channel second. In this Pi-based architecture, the best approach is:
- Opus over UDP for low-latency audio transport
- MQTT for robust event control
- Strict priority and preemption for safety cues
- Local fallback tones when higher-level logic is degraded
