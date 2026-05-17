# NVIDIA DRIVE OS Detailed Architecture

## Table of Contents

- [NVIDIA DRIVE OS Detailed Architecture](#nvidia-drive-os-detailed-architecture)
  - [Table of Contents](#table-of-contents)
  - [1. Scope and Context](#1-scope-and-context)
  - [2. Platform Overview](#2-platform-overview)
  - [3. System-on-Chip Architecture](#3-system-on-chip-architecture)
  - [4. Hardware Safety Architecture](#4-hardware-safety-architecture)
  - [5. Boot and Chain of Trust](#5-boot-and-chain-of-trust)
  - [6. OS and Runtime Layers](#6-os-and-runtime-layers)
  - [7. Hypervisor and Virtualization Model](#7-hypervisor-and-virtualization-model)
  - [8. Memory Architecture and Isolation](#8-memory-architecture-and-isolation)
  - [9. Compute Stack (CPU/GPU/DLA/PVA)](#9-compute-stack-cpugpudlapva)
    - [CPU](#cpu)
    - [GPU](#gpu)
    - [DLA](#dla)
    - [PVA / Vision accelerators](#pva--vision-accelerators)
  - [10. Sensor and I/O Architecture](#10-sensor-and-io-architecture)
  - [11. Middleware and Service Architecture](#11-middleware-and-service-architecture)
  - [12. Safety Concept and Freedom from Interference](#12-safety-concept-and-freedom-from-interference)
  - [13. Security Architecture](#13-security-architecture)
  - [14. Networking Architecture](#14-networking-architecture)
  - [15. Storage and Data Lifecycle](#15-storage-and-data-lifecycle)
  - [16. Time Synchronization and Determinism](#16-time-synchronization-and-determinism)
  - [17. Logging, Tracing, and Diagnostics](#17-logging-tracing-and-diagnostics)
  - [18. OTA, Fleet Ops, and Update Strategy](#18-ota-fleet-ops-and-update-strategy)
  - [19. Deployment Topologies](#19-deployment-topologies)
  - [20. Failure Modes and Recovery Paths](#20-failure-modes-and-recovery-paths)
  - [21. Recommended Partitioning Blueprint](#21-recommended-partitioning-blueprint)
  - [22. Architecture Review Checklist](#22-architecture-review-checklist)
  - [23. Notes and Versioning Caveats](#23-notes-and-versioning-caveats)
  - [24. Version-Specific Architecture Template](#24-version-specific-architecture-template)
    - [24.1 Program Baseline](#241-program-baseline)
    - [24.2 Partition Matrix (Filled Per Release)](#242-partition-matrix-filled-per-release)
    - [24.3 Release Delta Log](#243-release-delta-log)
    - [24.4 Evidence Bundle Index](#244-evidence-bundle-index)
  - [25. Deployment-Ready Block Diagram](#25-deployment-ready-block-diagram)
    - [25.1 Data Path Contracts](#251-data-path-contracts)
    - [25.2 Control Plane Contracts](#252-control-plane-contracts)
  - [26. ISO 26262 and ASIL Work-Product Mapping](#26-iso-26262-and-asil-work-product-mapping)
    - [26.1 ASIL-Aware Partition Guidance](#261-asil-aware-partition-guidance)
    - [26.2 Recommended Traceability Keys](#262-recommended-traceability-keys)

---

## 1. Scope and Context

This document describes a practical reference architecture for NVIDIA DRIVE OS based autonomous vehicle compute nodes. It focuses on:

- Safety-critical and non-safety mixed workloads
- Linux and QNX coexistence on a single vehicle compute platform
- Isolation, scheduling, and determinism requirements
- Sensor-to-actuator data paths
- Security and updateability for production fleets

The architecture is intentionally implementation-oriented so teams can map it to program-level design reviews and safety cases.

---

## 2. Platform Overview

At a high level, a DRIVE platform combines:

- Heterogeneous compute: CPU clusters, GPU, DLA, PVA, ISP and hardware accelerators
- Multi-OS runtime: safety RTOS workloads and high-throughput Linux workloads
- Hardware-enforced isolation: memory, interrupt, DMA and device partitioning
- Safety and security mechanisms: watchdogs, secure boot, attestation, monitored execution

Typical AV functions mapped on top:

- Perception (camera/radar/lidar ingest + inference)
- Localization and mapping
- Planning and control
- Driver/HMI and telemetry services
- Safety monitor, guardian, and fallback control

---

## 3. System-on-Chip Architecture

A simplified compute topology:

```text
+--------------------------------------------------------------------------------+
|                                NVIDIA DRIVE SoC                                |
|                                                                                |
|  +-------------------+    +-------------------+    +------------------------+  |
|  | CPU Cluster (A)   |    | CPU Cluster (B)   |    | Safety/Management MCU |  |
|  | Linux workloads   |    | RT/QNX workloads  |    | watchdog/monitoring    |  |
|  +-------------------+    +-------------------+    +------------------------+  |
|                                                                                |
|  +-------------------+    +-------------------+    +------------------------+  |
|  | GPU               |    | DLA               |    | PVA / Vision Engines  |  |
|  | DNN + CUDA        |    | low-power AI      |    | CV acceleration        |  |
|  +-------------------+    +-------------------+    +------------------------+  |
|                                                                                |
|  +-------------------+    +-------------------+    +------------------------+  |
|  | ISP / CSI         |    | NVENC/NVDEC       |    | Memory + Interconnect |  |
|  | camera ingest     |    | media paths       |    | QoS/NoC               |  |
|  +-------------------+    +-------------------+    +------------------------+  |
+--------------------------------------------------------------------------------+
```

Design implications:

- CPU clusters should be role-segregated (control vs compute-heavy services)
- AI workloads should be placed by latency, power, and determinism profile
- DMA-capable peripherals require strict IOMMU policy and ownership boundaries
- Interconnect QoS must be configured to prevent sensor-path starvation

---

## 4. Hardware Safety Architecture

Key safety-oriented hardware building blocks:

- Safety islands / lockstep-capable controllers for supervisory tasks
- ECC and error reporting across memory and critical fabrics
- Watchdog hierarchy: local watchdogs, system watchdog, external safety MCU watchdog
- Fault collection channels and hardware error signaling
- Redundant clock/voltage monitoring paths

Safety usage pattern:

- Primary autonomy stack runs high-performance path
- Independent monitor checks heartbeat, plausibility, and deadline adherence
- On violation, transition to degraded mode or minimum risk maneuver pipeline

---

## 5. Boot and Chain of Trust

A production boot chain should look like:

```text
ROM Boot -> First Stage Bootloader -> Verified Firmware -> Hypervisor -> Guest OSs
      |               |                    |                    |
      +---- signature/keys verification ---+--------------------+
```

Core principles:

- Hardware root-of-trust anchored in fused device identity
- Signed boot components with anti-rollback protections
- Measured boot where possible for attestation workflows
- Immutable early-boot policy for device partition/security setup

Recommended controls:

- Enforce secure boot in production lifecycle state
- Lock debug interfaces for production SKUs
- Maintain strict key rotation and revocation process

---

## 6. OS and Runtime Layers

A practical layered model:

```text
+-------------------------------------------------------------------+
| Application Layer                                                  |
| Perception | Localization | Planning | Control | Telemetry | HMI  |
+-------------------------------------------------------------------+
| Middleware Layer                                                   |
| DDS/IPC | Time Sync | Service Discovery | Health Manager          |
+-------------------------------------------------------------------+
| OS Services                                                        |
| Linux user space / QNX user space / system daemons               |
+-------------------------------------------------------------------+
| Kernel/RTOS + Drivers                                              |
| Linux kernel | QNX Neutrino | device/resource managers           |
+-------------------------------------------------------------------+
| Hypervisor + Isolation + Secure Monitor                            |
+-------------------------------------------------------------------+
| SoC Hardware                                                       |
+-------------------------------------------------------------------+
```

Guideline:

- Put hard real-time control and safety supervisor on RTOS partition
- Keep high-throughput AI/data pipelines on Linux partitions
- Define explicit ownership of each hardware engine per partition

---

## 7. Hypervisor and Virtualization Model

Virtualization is used for mixed-criticality containment.

Typical partition goals:

- Safety VM/partition: deterministic loop, limited device set
- Autonomy VM/partition: GPU-heavy workloads, broader networking/storage
- Infotainment/diagnostic VM/partition: strictly separated from safety path

Isolation dimensions:

- CPU core pinning
- Dedicated memory regions
- Device passthrough or mediated access
- Virtual interrupt routing
- Controlled inter-partition IPC channels

Common anti-patterns:

- Sharing latency-sensitive devices among unrelated partitions
- Allowing dynamic overcommit on safety partitions
- Unbounded IPC between low and high criticality domains

---

## 8. Memory Architecture and Isolation

Memory architecture requirements:

- Static reservation for safety partitions
- DMA remapping via IOMMU/SMMU
- ECC error handling and scrubbing strategy
- Bounded allocator behavior for real-time components

Partitioning pattern:

- Region A: RT control + safety monitor (locked/limited)
- Region B: perception buffers and model runtime
- Region C: logging/ring buffers and non-critical services
- Region D: update staging and persistent metadata

Recommendations:

- Prefer preallocated pools in deterministic paths
- Avoid runtime heap growth in hard real-time threads
- Separate high-bandwidth sensor buffers from control-plane memory

---

## 9. Compute Stack (CPU/GPU/DLA/PVA)

### CPU

- Best for control logic, orchestration, IPC, and safety policy engines
- Use fixed-priority scheduling and core pinning where determinism is required

### GPU

- Best for large DNN workloads and dense parallel operations
- Use stream priorities and bounded queue depth for predictable latency

### DLA

- Best for power-efficient inference with stable latency envelopes
- Ideal for always-on perception subgraphs when model compatibility allows

### PVA / Vision accelerators

- Best for classical CV primitives and pre/post-processing offload
- Reduces CPU jitter from image pipeline stages

Design strategy:

- Keep critical path short and explicit
- Assign each stage to a compute target by worst-case latency, not only average throughput
- Track contention from shared memory fabric and copy engines

---

## 10. Sensor and I/O Architecture

Main ingress paths:

- Camera over CSI/serializer links
- Radar/LiDAR via Ethernet, CAN-FD, or dedicated interfaces
- Vehicle bus via CAN/CAN-FD and automotive Ethernet
- GNSS/IMU through serial, SPI, or dedicated sensor hub paths

Pipeline model:

```text
Sensor Ingress -> Driver/ISP -> Timestamping -> Preprocess -> Inference/Fusion -> Planning
```

Requirements:

- Hardware timestamping close to ingress
- Clock alignment across sensor domains
- Backpressure handling and frame-drop policy under overload
- Per-sensor health and plausibility monitoring

---

## 11. Middleware and Service Architecture

Typical middleware elements:

- DDS or equivalent pub/sub with QoS profiles per topic criticality
- Low-latency shared-memory IPC for intra-node high-rate data
- Service registry and lifecycle manager
- Health manager and heartbeat supervision

QoS profile pattern:

- Safety/control topics: reliable, bounded history, strict deadline, low jitter
- Perception high-rate topics: often best-effort with controlled queue depth
- Telemetry topics: lower priority, compressible, lossy-tolerant

Governance rules:

- Enforce topic-level budget (rate, payload, history)
- Use explicit ownership and schema versioning
- Block dynamic schema drift in safety-critical interfaces

---

## 12. Safety Concept and Freedom from Interference

A practical mixed-criticality strategy:

- Spatial isolation: memory and device ownership boundaries
- Temporal isolation: core pinning + scheduling budgets + deadline checks
- Communication isolation: filtered, audited IPC contracts
- Fault containment regions with independent escalation paths

Safety mechanisms to include:

- End-to-end timing monitors
- Sensor plausibility and cross-check logic
- Actuation command sanity filters
- Guardian state machine with deterministic override path

Evidence expected in safety reviews:

- Interference analysis between critical and non-critical partitions
- Worst-case execution time (WCET) rationale for critical loops
- Proven fault reaction timing within hazard analysis assumptions

---

## 13. Security Architecture

Security architecture baseline:

- Secure boot + signed images + anti-rollback
- Partition hardening and least-privilege service identities
- Device attestation and certificate lifecycle
- Encrypted storage for credentials and sensitive logs
- Runtime integrity and anomaly monitoring

Operational controls:

- Separate manufacturing, development, and production key domains
- Strict OTA signing and staged rollout policy
- Secure debug unlock with audit trail and expiration

---

## 14. Networking Architecture

Vehicle node networking layers:

- Deterministic in-vehicle control channels
- High-bandwidth sensor backbone
- Service and telemetry network planes
- Secure external connectivity (fleet backend)

Segmentation policy:

- Separate safety control plane from telemetry plane
- Firewall and ACL policy per interface and partition
- Rate limiting and admission control for non-critical traffic

Time-aware networking considerations:

- PTP-based synchronization where required
- Priority queues for control and time-sensitive traffic
- Bounded retries and loss handling rules

---

## 15. Storage and Data Lifecycle

Storage tiers:

- Boot-critical immutable partitions
- Runtime persistent state (configs/calibration)
- High-rate logging ring buffers
- OTA staging partitions

Data lifecycle guidance:

- Define retention windows by data class
- Rotate and compress non-critical logs
- Preserve minimal forensic bundle for safety incidents
- Enforce schema and checksum on all persisted metadata

---

## 16. Time Synchronization and Determinism

Deterministic autonomy requires a unified time base:

- Monotonic local clocks for scheduling
- Sensor timestamp normalization to common epoch
- Bounded skew across partitions and ECUs

Implementation points:

- Hardware-assisted timestamping where possible
- PTP/clock servo monitoring with drift alarms
- Deterministic timer APIs in control/safety partitions

Key metric budget examples:

- Sensor timestamp skew budget
- End-to-end perception latency budget
- Control loop jitter budget

---

## 17. Logging, Tracing, and Diagnostics

Architecture-level observability:

- Multi-layer logs: boot, kernel, middleware, app, safety monitor
- Cross-domain trace correlation by common timestamps
- Fault snapshot capture for watchdog resets and deadline misses

Recommended channels:

- Structured logs with severity and component identity
- High-rate trace ring buffer with drop accounting
- Health counters exposed via diagnostics interface

Diagnostics policy:

- Ensure diagnostics cannot starve real-time execution
- Keep production-safe debug mode with bounded overhead
- Define incident extraction workflow before SOP

---

## 18. OTA, Fleet Ops, and Update Strategy

Robust OTA architecture:

- A/B or equivalent safe update strategy
- Signed artifacts and dependency-aware rollout plans
- Health-check gates before commit to new slot
- Automatic rollback on boot/runtime verification failure

Fleet rollout model:

- Canary subset -> phased cohort expansion -> full rollout
- Version compatibility matrix for app/runtime/firmware
- Telemetry-driven abort thresholds

---

## 19. Deployment Topologies

Common AV compute topologies:

- Single high-performance central compute node
- Redundant dual-node fail-operational design
- Domain split (perception compute + safety/control compute)

Selection drivers:

- ASIL target and fail-operational requirements
- Thermal and power envelope
- Cost, serviceability, and harness complexity

---

## 20. Failure Modes and Recovery Paths

Define clear failure classes:

- Transient overload (recoverable with degraded mode)
- Persistent partition failure (requires function migration or restart)
- Sensor degradation (graceful behavior with reduced ODD)
- Security integrity failure (isolate, rollback, safe state)

Recovery path design:

- Fast local restart for non-critical services
- Partition-level restart for contained failures
- Safe-state transition under safety monitor control
- Forensic snapshot before reset if timing permits

---

## 21. Recommended Partitioning Blueprint

Example mapping for mixed Linux + QNX deployment:

```text
Partition A (QNX Safety):
- Guardian monitor
- Actuation safety gate
- Health supervision
- Hard RT scheduler, dedicated CPU cores

Partition B (Linux Autonomy):
- Sensor ingest + perception graph
- Localization + planning
- GPU/DLA/PVA intensive services

Partition C (Linux Services):
- Telemetry, diagnostics, OTA agent
- Logging and fleet communication
- Non-critical UI and maintenance apps
```

Resource policy example:

- Dedicated cores for Partition A, no overcommit
- Isolated memory for Partition A with locked pages
- Strict DMA/IOMMU device ownership per partition
- Bounded IPC bridges from B/C into A through validated interfaces

---

## 22. Architecture Review Checklist

Use this before integration freeze:

- Boot chain verifies every executable stage
- Partition resource budgets are defined and enforced
- Safety-critical loops have WCET and jitter evidence
- Interference analysis completed across all partitions
- Sensor timestamp and synchronization strategy validated
- OTA rollback path tested on hardware
- Diagnostic overhead profiled under worst-case load
- Recovery state machine tested for key fault injections

---

## 23. Notes and Versioning Caveats

- Exact component names and capabilities vary by DRIVE SoC generation and DRIVE OS release.
- Some features are configuration-dependent and may require NVIDIA partner access, licensing, or board support package options.
- Always align this architecture with the specific DRIVE OS release notes, safety manual, and platform adaptation guide used by your program.

---

## 24. Version-Specific Architecture Template

Use this section to instantiate the architecture for a specific DRIVE OS release and SoC program baseline.

### 24.1 Program Baseline

- Program name: Atlas-AD-01
- Vehicle line: Mid-size EV SUV
- SoC: NVIDIA DRIVE AGX Orin (single-node central compute)
- DRIVE OS release: 6.x production branch (project-frozen baseline)
- Hypervisor release: Project-qualified hypervisor package aligned with DRIVE OS 6.x
- Linux guest version: Ubuntu 20.04 based guest image (vendor-qualified)
- QNX guest version: QNX SDP 7.1 based guest image (vendor-qualified)
- Safety package baseline: Safety Case Bundle Rev C (internal baseline ID: SCB-ATLAS-C)

Note:

- Replace the above values with the exact approved release tuple from your program configuration index before SOP.

### 24.2 Partition Matrix (Filled Per Release)

| Partition | OS | Criticality | CPU Set | Memory Budget | Device Ownership | Restart Policy |
|-----------|----|-------------|---------|---------------|------------------|----------------|
| A-Safety | QNX | ASIL-D | 0-3 | 8 GB static reserved | CAN-FD, safety GPIO, watchdog, actuation gateway | warm restart + safe fallback |
| B-Autonomy | Linux | QM/ASIL-B | 4-11 | 24 GB with bounded pools | GPU, DLA, PVA, CSI/ISP ingest path | local restart with degradation |
| C-Services | Linux | QM | 12-15 | 8 GB capped | Ethernet telemetry, storage, OTA channels | rolling service restart |

Partition policy profile:

- Partition A is non-overcommitted and page-locked for deterministic safety loops.
- Partition B uses bounded queue depths and per-pipeline memory pools to avoid burst collapse.
- Partition C is preemptible and rate-limited during high criticality windows.

### 24.3 Release Delta Log

Track architecture-impacting deltas between program drops:

- Delta 6.0 -> 6.0.1: updated secure boot certificate chain and anti-rollback counters.
- Delta 6.0.1 -> 6.0.2: tightened hypervisor device assignment for CSI and CAN domains.
- Delta 6.0.2 -> 6.0.3: moved lidar preprocessing from CPU to PVA path to reduce jitter.
- Delta 6.0.3 -> 6.0.4: revised planning-topic DDS history depth from 8 to 4 for bounded latency.
- Delta 6.0.4 -> 6.0.5: safety heartbeat timeout reduced from 80 ms to 50 ms after fault-injection findings.

### 24.4 Evidence Bundle Index

Maintain links or IDs to evidence used in design/safety reviews:

- Performance and timing test reports: PERF-ATLAS-112, PERF-ATLAS-140
- Fault-injection reports: FAULT-ATLAS-031, FAULT-ATLAS-044
- Security verification reports: SEC-ATLAS-018, SEC-ATLAS-023
- Interference analysis reports: INTF-ATLAS-007
- OTA rollback validation reports: OTA-ATLAS-015

---

## 25. Deployment-Ready Block Diagram

The following diagram is suitable as a baseline for node-level design reviews.

```text
                                      +----------------------------------+
                                      |      Fleet / OEM Backend        |
                                      | OTA, PKI, Telemetry, Analytics  |
                                      +----------------+-----------------+
                                                       |
                                         Secure TLS / mTLS Gateway
                                                       |
+-----------------------------------------------------------------------------------------------+
|                                  NVIDIA DRIVE Compute Node                                    |
|                                                                                               |
|  +---------------------------------------+   +---------------------------------------------+  |
|  | Partition A - Safety (QNX)            |   | Partition B - Autonomy (Linux)            |  |
|  |---------------------------------------|   |---------------------------------------------|  |
|  | Guardian Monitor                      |   | Sensor Ingest (camera/radar/lidar)         |  |
|  | Actuation Safety Gate                 |   | Perception + Fusion                         |  |
|  | Health Supervision                    |   | Localization + Planning                     |  |
|  | Deterministic Control Loop            |   | Runtime Orchestrator                        |  |
|  +-------------------+-------------------+   +--------------------------+------------------+  |
|                      |                                              |                        |
|      Validated IPC Bridge (bounded rate, schema, watchdog)         |                        |
|                      |                                              |                        |
|  +-------------------v-------------------+   +----------------------v---------------------+  |
|  | Partition C - Services (Linux)        |   | Hypervisor / Isolation Layer              |  |
|  |---------------------------------------|   |--------------------------------------------|  |
|  | Diagnostics + Logging                 |   | CPU pinning, memory isolation, IOMMU      |  |
|  | OTA Agent + Policy                    |   | virtual interrupts, device assignment      |  |
|  | Telemetry + Remote Ops                |   | secure monitor and boot policy             |  |
|  +-------------------+-------------------+   +----------------------+---------------------+  |
|                      |                                          |                             |
|  +-------------------v-------------------+   +------------------v------------------------+   |
|  | Vehicle Networks                        |   | SoC Hardware                               |   |
|  | CAN/CAN-FD, Automotive Ethernet         |   | CPU, GPU, DLA, PVA, ISP, Memory, CSI, IO |   |
|  +-----------------------------------------+   +-------------------------------------------+   |
+-----------------------------------------------------------------------------------------------+
```

### 25.1 Data Path Contracts

- Sensor-to-perception path: bounded queue depth and timestamp propagation
- Perception-to-planning path: deterministic frame selection policy
- Planning-to-control path: deadline-enforced command interface
- Control-to-actuation path: sanity and range checks before output

### 25.2 Control Plane Contracts

- OTA and diagnostics are rate-limited and preemptible by critical workloads
- Health monitor heartbeats are independent of non-critical middleware
- Any bridge into the safety partition is schema-validated and budget-limited

---

## 26. ISO 26262 and ASIL Work-Product Mapping

This table maps architecture artifacts to common ISO 26262 work products. Adapt names to your process and tooling.

| Architecture Area | ISO 26262 Intent | Typical Work Product | Evidence Source |
|-------------------|------------------|----------------------|-----------------|
| Item boundary and interfaces | Item definition and context | Item Definition (ID) | System architecture spec |
| Hazard handling assumptions | Hazard/risk rationale | HARA and safety goals | Safety analysis reports |
| Functional decomposition | Functional safety concept | FSC document | Function and interface models |
| Technical allocation to partitions | Technical safety concept | TSC document | Partition and resource matrix |
| Freedom from interference | Independence of critical elements | Interference Analysis Report | CPU/memory/device isolation tests |
| Timing and deadlines | Safety requirement timing feasibility | Timing Analysis / WCET dossier | Trace logs, WCET measurements |
| Safety mechanisms (monitor/guardian) | Fault detection and control | Safety Mechanism Spec and FMEA/FMEDA | Fault-injection results |
| Secure boot and image control | Protection against unauthorized changes | Cybersecurity/Safety interface note | Boot verification and attestation logs |
| Verification strategy | Confirmation of requirements | Verification and Validation Plan | Test matrix and coverage report |
| Tool and software qualification context | Confidence in toolchain and SW integration | Tool qualification argument / SW integration plan | Toolchain records, CI artifacts |
| Production, operation, and OTA controls | Sustained safety in lifecycle | Safety case operation annex | OTA rollback tests, incident procedures |

### 26.1 ASIL-Aware Partition Guidance

- ASIL-D functions: isolate by core, memory, device path, and watchdog channel
- ASIL-B/C functions: constrained sharing permitted with interference evidence
- QM services: never form a single-point dependency for ASIL control path

### 26.2 Recommended Traceability Keys

Use consistent IDs to link architecture to safety artifacts:

- ARCH-<id>: architecture requirement
- SAFE-<id>: safety requirement
- SEC-<id>: security requirement
- TEST-<id>: verification artifact
- FAULT-<id>: fault-injection campaign entry
