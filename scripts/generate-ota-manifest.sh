#!/usr/bin/env bash
set -euo pipefail

# Generates a unified OTA/release manifest from artifact directories.
VERSION="${1:-dev}"
ARTIFACTS_ROOT="${2:-}"
OUT_FILE="${3:-}"

if [[ -z "${ARTIFACTS_ROOT}" || -z "${OUT_FILE}" ]]; then
  echo "Usage: $0 <version> <artifacts-root> <out-file>" >&2
  exit 1
fi

hash_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  else
    shasum -a 256 "${file}" | awk '{print $1}'
  fi
}

mkdir -p "$(dirname "${OUT_FILE}")"

{
  echo "{"
  echo "  \"release_id\": \"${VERSION}\"," 
  echo "  \"generated_at_utc\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," 
  echo "  \"targets\": ["

  first_target=1
  for target in sensor ui gateway cloud; do
    target_dir="${ARTIFACTS_ROOT}/${target}"
    [[ -d "${target_dir}" ]] || continue

    if [[ ${first_target} -eq 0 ]]; then
      echo "    ,"
    fi
    first_target=0

    echo "    {"
    echo "      \"name\": \"${target}\"," 
    echo "      \"artifacts\": ["

    first_file=1
    while IFS= read -r -d '' file; do
      rel_path="${file#${ARTIFACTS_ROOT}/}"
      checksum="$(hash_file "${file}")"
      if [[ ${first_file} -eq 0 ]]; then
        echo "        ,"
      fi
      first_file=0
      echo "        {\"path\": \"${rel_path}\", \"sha256\": \"${checksum}\"}"
    done < <(find "${target_dir}" -type f ! -name "sha256sums.txt" -print0 | sort -z)

    echo "      ]"
    echo "    }"
  done

  echo "  ]"
  echo "}"
} > "${OUT_FILE}"

echo "Wrote manifest to ${OUT_FILE}"