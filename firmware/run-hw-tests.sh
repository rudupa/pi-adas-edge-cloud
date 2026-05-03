#!/bin/bash
# firmware/run-hw-tests.sh
#
# Run hardware smoke tests for a given node type.
#
# Usage:
#   bash firmware/run-hw-tests.sh [sensor|ui|gateway]
#
# Exit code:
#   0  — all tests passed
#   1  — one or more tests failed
#   2  — invalid arguments / no tests found

set -euo pipefail

NODE="${1:-sensor}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="${REPO_ROOT}/firmware/${NODE}/hw-tests"

if [ ! -d "$TEST_DIR" ]; then
    echo "ERROR: No hw-tests directory found for node '${NODE}' (expected: ${TEST_DIR})" >&2
    exit 2
fi

TESTS=("$TEST_DIR"/test-*.sh)
if [ ${#TESTS[@]} -eq 0 ] || [ ! -f "${TESTS[0]}" ]; then
    echo "ERROR: No test-*.sh scripts found in ${TEST_DIR}" >&2
    exit 2
fi

PASS=0
FAIL=0
RESULTS=()

for test_script in "${TESTS[@]}"; do
    name="$(basename "$test_script")"
    if bash "$test_script"; then
        PASS=$((PASS + 1))
        RESULTS+=("  PASS  $name")
    else
        FAIL=$((FAIL + 1))
        RESULTS+=("  FAIL  $name")
    fi
done

echo ""
echo "=== hw-test results for node: ${NODE} ==="
for line in "${RESULTS[@]}"; do
    echo "$line"
done
echo ""
echo "Summary: ${PASS} passed, ${FAIL} failed"

[ "$FAIL" -eq 0 ] || exit 1
