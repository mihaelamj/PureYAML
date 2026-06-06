#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/.build/pureyaml-artifacts/performance"

mkdir -p "$ARTIFACT_DIR"

PUREYAML_RUN_PHASE_PROFILER=1 \
PUREYAML_PHASE_PROFILER_ARTIFACT="$ARTIFACT_DIR/phase-profile.json" \
swift test \
    -c release \
    --package-path "$ROOT_DIR" \
    --filter PerformancePhaseTests
