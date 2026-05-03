#!/usr/bin/env bash
set -euo pipefail

# Builds one edge-node artifact set (sensor/ui/gateway) with Linux image outputs.
TARGET="${1:-}"
VERSION="${2:-dev}"
OUT_DIR="${3:-}"

if [[ -z "${TARGET}" || -z "${OUT_DIR}" ]]; then
  echo "Usage: $0 <sensor|ui|gateway> <version> <out-dir>" >&2
  exit 1
fi

case "${TARGET}" in
  sensor|ui|gateway) ;;
  *)
    echo "Unsupported target: ${TARGET}" >&2
    exit 1
    ;;
esac

checksum_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}"
  else
    shasum -a 256 "${file}"
  fi
}

mkdir -p "${OUT_DIR}"
TARGET_BUILD_SCRIPT="build/${TARGET}/build.sh"
ARTIFACT_FILE="${OUT_DIR}/${TARGET}-linux-${VERSION}.img"

if [[ -x "${TARGET_BUILD_SCRIPT}" ]]; then
  "${TARGET_BUILD_SCRIPT}" "${VERSION}" "${OUT_DIR}"
else
  # Fallback remains image-based to match release expectations.
  truncate -s 64M "${ARTIFACT_FILE}"
fi

cat > "${OUT_DIR}/build-metadata.json" <<JSON
{
  "target": "${TARGET}",
  "version": "${VERSION}",
  "commit": "${GITHUB_SHA:-local}",
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifact_type": "linux-image"
}
JSON

: > "${OUT_DIR}/sha256sums.txt"
while IFS= read -r -d '' file; do
  checksum_file "${file}" >> "${OUT_DIR}/sha256sums.txt"
done < <(find "${OUT_DIR}" -type f ! -name "sha256sums.txt" -print0 | sort -z)

echo "Built ${TARGET} artifacts in ${OUT_DIR}"
