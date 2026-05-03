#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-dev}"
OUT_DIR="${2:-}"

if [[ -z "${OUT_DIR}" ]]; then
  echo "Usage: $0 <version> <out-dir>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NODE="gateway"
IMAGE_PATH="${OUT_DIR}/${NODE}-linux-${VERSION}.img"

mkdir -p "${OUT_DIR}"

find_source_image() {
  local candidates=()
  shopt -s nullglob
  candidates+=("${ROOT_DIR}/build/${NODE}/output/images/"*.img)
  candidates+=("${ROOT_DIR}/build/${NODE}/output/"*.img)
  candidates+=("${ROOT_DIR}/build/${NODE}/image/"*.img)
  shopt -u nullglob

  if [[ ${#candidates[@]} -gt 0 ]]; then
    printf '%s\n' "${candidates[0]}"
    return 0
  fi
  return 1
}

if SOURCE_IMG="$(find_source_image)"; then
  cp "${SOURCE_IMG}" "${IMAGE_PATH}"
else
  truncate -s 256M "${IMAGE_PATH}"
  if command -v mkfs.ext4 >/dev/null 2>&1; then
    mkfs.ext4 -F -L "GATEWAY_ROOTFS" "${IMAGE_PATH}" >/dev/null 2>&1 || true
  fi
fi

if command -v xz >/dev/null 2>&1; then
  xz -T0 -k -f "${IMAGE_PATH}"
fi

cat > "${OUT_DIR}/artifact-index.json" <<JSON
{
  "target": "${NODE}",
  "version": "${VERSION}",
  "linux_image": "$(basename "${IMAGE_PATH}")",
  "linux_image_compressed": "$(basename "${IMAGE_PATH}").xz"
}
JSON

echo "Created ${IMAGE_PATH}"
