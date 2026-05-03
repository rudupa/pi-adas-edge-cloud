#!/usr/bin/env bash
set -euo pipefail

# Builds cloud artifacts bundle (container metadata by default).
VERSION="${1:-dev}"
OUT_DIR="${2:-}"

if [[ -z "${OUT_DIR}" ]]; then
  echo "Usage: $0 <version> <out-dir>" >&2
  exit 1
fi

checksum_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}"
  else
    shasum -a 256 "${file}"
  fi
}

mkdir -p "${OUT_DIR}"
CLOUD_BUILD_SCRIPT="cloud/build.sh"

if [[ -x "${CLOUD_BUILD_SCRIPT}" ]]; then
  "${CLOUD_BUILD_SCRIPT}" "${VERSION}" "${OUT_DIR}"
else
  cat > "${OUT_DIR}/images.txt" <<TXT
cloud-ingest:${VERSION}
cloud-ota:${VERSION}
cloud-telemetry-api:${VERSION}
cloud-dashboard:${VERSION}
TXT
fi

cat > "${OUT_DIR}/build-metadata.json" <<JSON
{
  "target": "cloud",
  "version": "${VERSION}",
  "commit": "${GITHUB_SHA:-local}",
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

: > "${OUT_DIR}/sha256sums.txt"
while IFS= read -r -d '' file; do
  checksum_file "${file}" >> "${OUT_DIR}/sha256sums.txt"
done < <(find "${OUT_DIR}" -type f ! -name "sha256sums.txt" -print0 | sort -z)

echo "Built cloud artifacts in ${OUT_DIR}"
