#!/bin/bash
# Hardware smoke test: MQTT broker (gateway node)
#
# Delegates to the standalone test script at the gateway firmware root so that
# both `run-hw-tests.sh gateway` and direct invocation work without duplication.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "${SCRIPT_DIR}/test-mqtt-broker.sh" "$@"
