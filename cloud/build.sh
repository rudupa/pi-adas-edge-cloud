#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-dev}"
OUT_DIR="${2:-}"

if [[ -z "${OUT_DIR}" ]]; then
  echo "Usage: $0 <version> <out-dir>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "${STAGING_DIR}"' EXIT

mkdir -p "${OUT_DIR}" "${STAGING_DIR}/meta" "${STAGING_DIR}/deploy"

# Cloud image tags produced by this release.
cat > "${STAGING_DIR}/images.txt" <<TXT
cloud-ingest:${VERSION}
cloud-ota:${VERSION}
cloud-telemetry-api:${VERSION}
cloud-dashboard:${VERSION}
TXT

# Include optional deployment manifests if present.
if [[ -d "${ROOT_DIR}/deploy" ]]; then
  cp -R "${ROOT_DIR}/deploy" "${STAGING_DIR}/deploy/source"
fi

cat > "${STAGING_DIR}/meta/release.json" <<JSON
{
  "target": "cloud",
  "version": "${VERSION}",
  "commit": "${GITHUB_SHA:-local}",
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifact_type": "cloud-release-bundle"
}
JSON

ARTIFACT_PATH="${OUT_DIR}/cloud-bundle-${VERSION}.tar.gz"
tar -czf "${ARTIFACT_PATH}" -C "${STAGING_DIR}" .
cp "${STAGING_DIR}/images.txt" "${OUT_DIR}/images.txt"

cat > "${OUT_DIR}/artifact-index.json" <<JSON
{
  "target": "cloud",
  "version": "${VERSION}",
  "bundle": "$(basename "${ARTIFACT_PATH}")",
  "images": "images.txt"
}
JSON

echo "Created ${ARTIFACT_PATH}"