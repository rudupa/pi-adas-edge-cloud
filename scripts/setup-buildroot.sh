#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"

echo "=== Setting up Buildroot ==="

cd "${BUILD_DIR}"

# Clone Buildroot if not already present
if [ ! -d buildroot-src ]; then
    echo "Cloning Buildroot 2024.02..."
    git clone --depth=1 --branch=2024.02 \
        https://github.com/buildroot/buildroot.git buildroot-src
else
    echo "buildroot-src already present, skipping clone"
fi

# Create per-node output directories
for node in sensor ui gateway; do
    mkdir -p "${node}/output"
    echo "Created ${node}/output"
done

# Validate host tools
echo ""
echo "Validating required build tools..."
for tool in gcc make rsync git wget; do
    command -v "${tool}" >/dev/null || { echo "MISSING: ${tool}"; exit 1; }
    echo "  [OK] ${tool}"
done

# Quick Buildroot sanity check
echo ""
echo "Checking Buildroot..."
make --version | head -1
echo "Buildroot setup complete."
