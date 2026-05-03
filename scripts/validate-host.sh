#!/usr/bin/env bash
set -euo pipefail

ERRORS=0

check_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "  [OK]  $1"
    else
        echo "  [MISSING] $1"
        ERRORS=$((ERRORS + 1))
    fi
}

check_optional_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "  [OK]  $1"
    else
        echo "  [OPTIONAL] $1 — not found (non-fatal)"
    fi
}

echo "=== Host Validation for pi-adas-edge-cloud Build ==="
echo ""

echo "Required build tools:"
for tool in gcc make rsync git wget bc; do
    check_tool "$tool"
done

echo ""
echo "Optional cross-compiler (needed for non-ARM host):"
check_optional_tool gcc-arm-linux-gnueabihf

echo ""
echo "Checking disk space..."
AVAIL_GB=$(df -BG . | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
if [ "${AVAIL_GB}" -ge 50 ]; then
    echo "  [OK]  ${AVAIL_GB} GB available (≥50 GB required)"
else
    echo "  [WARN] Only ${AVAIL_GB} GB available; recommend ≥50 GB per node build"
fi

echo ""
if [ "${ERRORS}" -eq 0 ]; then
    echo "Host validation PASSED"
else
    echo "Host validation FAILED: ${ERRORS} missing tool(s)"
    exit 1
fi
