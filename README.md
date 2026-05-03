# Distributed Embedded Vision + Audio System
## Master Index

Pi Zero W × 2 + Pi 4 × 1 — edge vision, audio, AI, and cloud gateway.

---

## System at a Glance

```text
                     +-------------------------------------+
                     |     Gateway + Master Pi 4          |
                     | AP + DHCP + MQTT + Cloud + AI/CTL  |
                     |            BrainCraft HAT           |
                     +------------------+------------------+
                                        |
                             Private 2.4 GHz WLAN
             +--------------------------+--------------------------+
             |                                                     |
+------------+------------+                           +------------+------------+
|      Sensor Pi Zero W   |                           |        UI Pi Zero W     |
|    Camera + VoiceHat    |                           |     Pirate Audio HAT    |
|   H.264 TX + Opus TX    |                           |  Display/Buttons/Speaker|
+-------------------------+                           +-------------------------+
```

| Node | Board | HAT | Key Role |
|------|-------|-----|----------|
| Sensor | Pi Zero W v1.1 | Adafruit Voice Bonnet | Camera + stereo mic + RGB LEDs |
| UI | Pi Zero W v1.1 | Pimoroni Pirate Audio | Display + buttons + speaker |
| Gateway + Master | Raspberry Pi 4 | Adafruit BrainCraft HAT | AP + MQTT + AI + cloud |

---

## Documents

### [HW specs.md](HW%20specs.md)
Hardware specifications for all three nodes.
- Node inventory with board-level specs (CPU, RAM, wireless)
- Per-HAT hardware details (Voice Bonnet, Pirate Audio, BrainCraft)
- Connectivity and bus mappings
- Performance targets and constraints
- Bill of materials and acceptance checklist
- Cross-references to Power Management and Bandwidth docs

### [HW architecture.md](HW%20architecture.md)
Physical topology and hardware interconnect design.
- Node roles and wiring responsibilities
- Wireless fabric and data plane separation
- Deployment zones
- Architecture diagram
- Reliability, serviceability, and security boundaries

### [system architecture.md](system%20architecture.md)
Software stack, protocols, and delivery plan.
- OS and service stack per node
- Runtime data flow diagram
- MQTT topic namespace
- Boot and startup strategy
- Repository and process layout
- Observability, security model
- Phased implementation plan (6 phases)
- Risk notes and mitigations

### [power management.md](power%20management.md)
Per-node power budgets, thermal guidance, and safe shutdown.
- Voltage and current requirements per node
- Power budget summary table
- Thermal management notes
- Storage wear and power-safe shutdown requirements

### [bandwidth.md](bandwidth.md)
Bandwidth planning, codec selection, and stream sizing.
- MJPEG vs H.264 comparison and recommendation (start here)
- Per-node throughput budgets and stream profiles at 30fps
- H.264 and MJPEG bitrate quick-reference tables
- Capture command examples (`libcamera-vid`, `raspivid`)
- Tuning rules and monitoring commands

### [real adas perception stack.md](real%20adas%20perception%20stack.md)
Mini ADAS perception pipeline and low-latency streaming strategy.
- Feasible Pi Zero perception stages and constraints
- ECU-style split across Sensor, UI, and Pi 4 Brain nodes
- 50-100 ms H.264 latency budget and tuning checklist
- Deployment mapping and acceptance criteria

### [audio in adas av system.md](audio%20in%20adas%20av%20system.md)
Audio usage model for ADAS and AV behavior in this project.
- Safety-first audio roles, priorities, and latency classes
- Audio data plane (UDP/Opus) and event plane (MQTT)
- Node mapping, buffering policy, and fallback behavior
- KPIs and phased implementation checklist

### [project plan.md](project%20plan.md)
Full project plan with technical details, timeline, and Gantt chart.
- 9-phase delivery plan over 16 weeks
- Per-phase technical scope, tasks, and acceptance criteria
- Dependency map and hardware/software constraints
- Milestone table, risk register, and open decisions
- Mermaid Gantt chart (renders in GitHub, VS Code preview)

### [cloud node.md](cloud%20node.md)
Dedicated cloud node design for logging, OTA, and telemetry.
- Cloud control plane modules (registry, ingestion, alerting)
- OTA rollout, canary strategy, and rollback workflow
- Telemetry and logging schemas with KPI tracking
- Security model (mTLS, signed artifacts, audit trail)

### [repo blueprint.md](repo%20blueprint.md)
Unified monorepo strategy for building all 4 nodes from one repository.
- Recommended repo name and target monorepo layout
- Build matrix for sensor, UI, gateway, and cloud targets
- Release/versioning and OTA manifest strategy
- CI/CD flow with artifact and checksum expectations

### [developer guide.md](developer%20guide.md)
Developer build/update/release guide with flashing workflow and readiness gaps.
- Local and CI commands for edge and cloud artifacts
- Release and OTA manifest flow
- SD card flashing process for Pi Zero and Pi 4
- Pending work checklist for truly functional production images

### [implementation_plan.md](implementation_plan.md)
Detailed 14-week roadmap to close all production-readiness gaps.
- Phase 0–9 breakdown: Buildroot setup, per-node configs, services, validation, OTA security, canary rollout, integration testing, hardening, release
- Buildroot defconfigs and kernel configurations for all 3 nodes
- Root filesystem overlays, device tree bindings, boot partition assembly
- Hardware smoke tests (camera, audio, display, LEDs, thermal)
- Video streaming (H.264) and audio mixing services (priority-based)
- MQTT control and telemetry architecture
- OTA signing pipeline and canary rollout policies
- End-to-end latency and audio quality validation
- Security hardening checklist and production deployment checklist
- Resource estimates and references

### [agent_development_plan.md](agent_development_plan.md)
Autonomous agent execution plan for implementing the 14-week roadmap in 8–10 weeks.
- Agent capabilities and constraints (parallelization, automation, hardware limitations)
- Task decomposition with dependency graph and critical path analysis
- Phase-by-phase execution plan with concrete checkpoints and deliverables
- Parallel work streams (Buildroot configs, services development, testing, security/OTA)
- Risk mitigation strategies and decision points (Buildroot failures, hardware unavailability, key management)
- Automation hooks for CI/CD, build verification, and testing
- Success criteria per phase and acceleration metrics
- Agent decision matrix (when to auto-proceed vs. request user input)
- Quick-start bash script for executing all phases sequentially

---

## Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| OS (Pi Zero W) | Buildroot | 2–5s boot, minimal footprint |
| Video codec | H.264 (VideoCore HW) | ~1–3 Mbps at 30fps vs ~8–14 Mbps MJPEG |
| Audio codec | Opus over UDP | ~32–128 kbps, ~20–40ms latency |
| Messaging | MQTT (Mosquitto) | Lightweight pub/sub, tiny overhead |
| UI rendering | Framebuffer / SDL | No X11/Wayland overhead |
| AI / voice | Vosk (offline) | No cloud dependency for inference |
| Video resolution | 640×480 primary | Balances quality and Pi Zero W budget |
| Target FPS | 30fps | Achievable with H.264 HW encoder |

---

## Implementation Phases

| Phase | Goal |
|-------|------|
| 1 | Buildroot boot, LED blink, camera frame capture |
| 2 | Video + audio streaming Sensor → UI |
| 3 | Button events → Gateway+Master, LED remote control |
| 4 | Wi-Fi AP + DHCP + MQTT broker on Pi 4 |
| 5 | Voice commands + decision logic on Gateway+Master |
| 6 | Cloud node integration (logging, OTA, telemetry) |

---

## Quick Reference — Bandwidth Targets

| Stream | Codec | Bitrate | Notes |
|--------|-------|---------|-------|
| Video 640×480 / 30fps | H.264 | ~1–3 Mbps | Primary target |
| Video 320×240 / 30fps | H.264 | ~0.3–0.8 Mbps | Fallback |
| Audio stereo | Opus | ~32–128 kbps | UDP |
| MQTT control | — | <0.05 Mbps | TCP |
| Cloud telemetry | — | ~0.2–2 Mbps | Snapshots + logs only |

---

## Quick Reference — Power Budgets

| Node | Idle | Peak | Supply |
|------|------|------|--------|
| Sensor Pi Zero W | ~200 mA | ~600 mA | 5V / 2A |
| UI Pi Zero W | ~200 mA | ~900 mA | 5V / 2A |
| Gateway+Master Pi 4 | ~600 mA | ~3 A | 5V / 3A |
