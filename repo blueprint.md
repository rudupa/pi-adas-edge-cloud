# Repo Blueprint
## Unified Monorepo for 4-Node System

Recommended repository name:
**pi-adas-edge-cloud**

Why this name:
- Includes both edge and cloud scope
- Maps cleanly to your 4-node architecture
- Short, searchable, and release-friendly

---

## 1. Can One Repo Build All 4 Nodes?

Yes. A single monorepo should produce all deployables with target-specific pipelines.

Artifacts by node:
- Sensor node: bootable image (Buildroot output)
- UI node: bootable image (Buildroot output)
- Gateway node: bootable image (Pi 4 OS image)
- Cloud node: container image(s) + deployment manifests

Important:
- Cloud node is typically not an SD-card image.
- Keep one version tag across all artifacts for traceability.

---

## 2. Recommended Monorepo Layout

```text
pi-adas-edge-cloud/
  docs/
    README.md
    HW specs.md
    HW architecture.md
    system architecture.md
    project plan.md
    cloud node.md

  build/
    sensor/
      buildroot/
      output/
    ui/
      buildroot/
      output/
    gateway/
      image/
      output/
    cloud/
      manifests/

  firmware/
    sensor/
      services/
      config/
    ui/
      services/
      config/
    gateway/
      services/
      config/

  cloud/
    api/
    ingest/
    ota/
    dashboards/

  shared/
    schemas/
      telemetry/
      ota/
      events/
    libs/
      mqtt/
      logging/

  deploy/
    ota/
      manifests/
      signing/
    environments/
      dev/
      staging/
      prod/

  scripts/
    build-node.sh
    build-cloud.sh
    package-release.sh
    generate-ota-manifest.sh

  .github/
    workflows/
      build-all-nodes.yml
      release-all-nodes.yml
```

---

## 3. Build Matrix Strategy

Use CI matrix dimensions:
- target: sensor, ui, gateway, cloud
- environment: dev, staging, prod
- architecture:
  - sensor/ui: armv6
  - gateway: arm64
  - cloud: amd64 + arm64 (multi-arch)

Build outputs:
- sensor/ui/gateway: image artifacts + checksums
- cloud: container image digest + deployment bundle
- all targets: SBOM + version metadata

---

## 4. Versioning and Release Semantics

Single release tag per fleet release:
- Example: v0.9.0

Per-target artifact naming:
- sensor-image-v0.9.0.img.xz
- ui-image-v0.9.0.img.xz
- gateway-image-v0.9.0.img.xz
- cloud-ingest-v0.9.0 (container image)
- cloud-ota-v0.9.0 (container image)

Manifest contract:
- release_id
- target
- artifact_uri
- sha256
- compatible_hardware
- rollback_version

---

## 5. OTA Integration Model

OTA control remains gateway-mediated:
- Cloud node publishes campaign intent and signed manifest
- Gateway validates signature/checksum
- Gateway orchestrates local rollout to Sensor/UI/Gateway nodes
- Gateway reports status to cloud

Rollout policy:
1. canary (5%)
2. ramp (25%)
3. broad (100%)
4. rollback on threshold breach

---

## 6. Telemetry and Logging Packaging

Keep schemas in shared folder and version them:
- shared/schemas/telemetry/v1/*.json
- shared/schemas/events/v1/*.json
- shared/schemas/ota/v1/*.json

Every artifact build should embed:
- git commit SHA
- build timestamp
- schema version
- release tag

---

## 7. CI/CD Flow (Recommended)

1. Pull request:
- lint + unit tests + schema validation
- target-specific smoke builds

2. Main branch merge:
- full matrix build for all 4 targets
- signed artifacts and checksums
- internal registry upload

3. Release tag:
- publish images and container tags
- generate fleet release manifest
- create OTA campaign payload

4. Post-release:
- canary telemetry watch
- automated rollback if failure threshold exceeded

---

## 8. Initial Action Plan

1. Create target configs:
- build/sensor/buildroot/
- build/ui/buildroot/
- build/gateway/image/
- cloud/* services

2. Add reusable build scripts in scripts/.

3. Enable build-all-nodes CI workflow with matrix targets.

4. Add release workflow that emits one release manifest for all artifacts.

5. Wire OTA controller to read signed release manifest.

---

## 9. Decision Record

Chosen repo name: **pi-adas-edge-cloud**

Alternative acceptable names:
- pi-fleet-adas-platform
- adas-edge-cloud-fleet
- pi-ecu-vision-audio-cloud
