# Cloud Node
## Logging, OTA, and Telemetry Architecture

This document defines a dedicated Cloud Node for the distributed Pi-based ADAS/AV system.

The Cloud Node is not a physical Raspberry Pi device. It is a cloud-side service plane that receives data from the Gateway + Master Pi 4 and provides fleet-level control.

---

## 1. Cloud Node Goals

- Centralized telemetry ingestion and storage
- Structured logging for fleet diagnostics and incident analysis
- Secure OTA update orchestration for Sensor/UI/Gateway nodes
- Device registry, version tracking, and rollout management
- Alerting and dashboarding for operational visibility

---

## 2. Role in Overall Architecture

```text
Sensor Pi Zero + UI Pi Zero  <----local LAN---->  Gateway + Master Pi 4  <----TLS---->  Cloud Node
```

Responsibilities split:
- Edge nodes (Pi Zero): real-time media and control
- Gateway + Master (Pi 4): aggregation, local decision logic, cloud bridge
- Cloud Node: long-term storage, OTA policy, telemetry analytics, fleet ops

Design rule:
- Local safety behavior must continue even if Cloud Node is unreachable.

---

## 3. Functional Modules

### 3.1 Device Registry

Stores per-device metadata:
- device_id, node_type, hardware_revision
- current firmware/software version
- last seen timestamp
- assigned deployment group (canary, beta, production)

### 3.2 Telemetry Ingestion

Receives from Pi 4 cloud bridge:
- system health heartbeat
- perception events (lane, motion, object detections)
- audio event statistics
- performance KPIs (latency, CPU, memory, packet loss)

### 3.3 Logging Service

Collects structured logs from gateway and selected edge summaries:
- service lifecycle logs
- watchdog restarts and crash signatures
- network and broker health
- OTA update lifecycle events

Retention policy recommendation:
- Hot logs: 7-14 days
- Aggregated metrics: 90 days
- Critical incident logs: 180+ days

### 3.4 OTA Orchestrator

Manages software/firmware updates with staged rollout:
- Update package manifest
- Compatibility checks (node type, version, free space)
- Canary rollout to small subset
- Progressive ramp to fleet
- Automatic rollback on failure thresholds

### 3.5 Alerting and Dashboard

- Rule-based alerting for P0/P1 safety events and platform faults
- Fleet dashboard with node online/offline status
- Release dashboard for OTA progress and failure rates

---

## 4. Data Model and Topics

### 4.1 Telemetry Topic Namespace (Cloud-facing)

- cloud/telemetry/system
- cloud/telemetry/perception
- cloud/telemetry/audio
- cloud/telemetry/network
- cloud/logs/events

### 4.2 OTA Control Topics

- cloud/ota/manifest
- cloud/ota/command
- cloud/ota/status
- cloud/ota/rollback

### 4.3 Suggested Telemetry Payload Fields

- ts (UTC epoch ms)
- gateway_id
- node_id
- node_type
- sw_version
- metric_name
- metric_value
- severity
- trace_id

### 4.4 Suggested OTA Payload Fields

- campaign_id
- target_group
- target_version
- artifact_uri
- artifact_sha256
- min_required_space_mb
- reboot_required
- rollout_percent
- rollback_on_error_rate

---

## 5. OTA Workflow

1. Publish signed manifest to cloud/ota/manifest.
2. Gateway + Master fetches and validates signature/checksum.
3. Gateway applies preflight checks on each target node.
4. Deploy to canary group first.
5. Collect cloud/ota/status and error metrics.
6. If healthy, ramp rollout to wider groups.
7. On threshold breach, trigger cloud/ota/rollback.

Preflight checks:
- Battery/power stable
- Free storage threshold met
- Node not in critical active operation
- Network link quality above minimum

---

## 6. Logging Strategy

### 6.1 Structured Logging Schema

Recommended fields:
- ts, level, node_id, service, event_code
- message, context_json, trace_id

### 6.2 Log Levels

- DEBUG: development diagnostics only
- INFO: normal lifecycle and state changes
- WARN: recoverable anomalies
- ERROR: operation failed, service degraded
- CRITICAL: safety-impacting or persistent failure

### 6.3 Cost and Bandwidth Controls

- Edge-side log sampling for high-frequency events
- Compress batched uploads from Pi 4
- Send summaries by default, full dump on demand

---

## 7. Telemetry KPIs (Cloud-Side)

Track and visualize:
- Video latency P50/P95/P99
- Audio alert latency P50/P95/P99
- Packet loss and jitter trends
- CPU and memory usage by node
- Service restart counts per day
- OTA success/failure/rollback rates
- Device online ratio and mean reconnect time

Alert thresholds (example):
- P0 alert latency P95 > 100 ms for 5 minutes
- Node offline > 60 seconds
- OTA failure rate > 5% in active campaign

---

## 8. Security Requirements

- Mutual TLS between Pi 4 cloud bridge and Cloud Node
- Signed OTA artifacts and manifest verification
- Least-privilege service accounts per gateway
- Immutable audit log for OTA and critical control actions
- Secret rotation policy for keys and tokens

Security boundary:
- Only Gateway + Master Pi 4 communicates directly with Cloud Node.
- Pi Zero nodes remain inside local WLAN control domain.

---

## 9. Recommended Deployment Stack (Reference)

Minimal production-ready pattern:
- API ingress: HTTPS endpoint + MQTT broker over TLS
- Telemetry store: time-series database
- Log store: centralized log index
- Object storage: OTA artifacts and snapshots
- Rule engine: alerts and rollout automation
- Dashboard: fleet status and KPI visualization

Vendor-neutral options:
- Self-hosted: EMQX/Mosquitto + Timescale/Influx + Loki/ELK + MinIO
- Managed cloud: AWS IoT Core / Azure IoT Hub / GCP IoT-equivalent stack

---

## 10. Integration Plan for This Project

### Step 1: Baseline Telemetry
- Send system/status heartbeat from Pi 4 every 2-5 seconds
- Store CPU, memory, stream FPS, packet loss

### Step 2: Structured Logging
- Add trace_id across gateway services
- Upload rotated log bundles every 1-5 minutes

### Step 3: OTA MVP
- Implement manifest fetch + checksum verify on Pi 4
- Roll updates to one canary node first, then full rollout

### Step 4: Dashboard + Alerts
- Build operations dashboard for node health and KPI trends
- Add P0/P1 alert notification hooks

### Step 5: Hardening
- mTLS, signed artifacts, rollback automation, audit trails

---

## 11. Acceptance Criteria

Cloud Node is considered operational when:
- Telemetry from all active gateways is visible within 5 seconds
- Structured logs are searchable by node_id and trace_id
- OTA canary rollout and rollback both work end-to-end
- OTA campaign success rate >= 95% under normal network conditions
- Local ADAS/audio safety behavior remains functional during cloud outage
