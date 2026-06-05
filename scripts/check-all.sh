#!/usr/bin/env bash
# Full local verification gate for PureYAML.
#
# Runs the checks required before completion, including the Claw Mini Linux
# check when executed from macOS and the WASM SDK build check.

set -euo pipefail

run_gate() {
  name="$1"
  shift
  printf '\n==> %s\n' "$name"
  "$@"
}

run_gate "style" bash scripts/check-style.sh
run_gate "namespacing" bash scripts/check-namespacing.sh
run_gate "changelog" bash scripts/check-changelog-touched.sh
run_gate "roadmap" bash scripts/check-roadmap.sh
run_gate "swiftformat" swiftformat . --config .swiftformat --lint
run_gate "swiftlint" swiftlint --config .swiftlint.yml --strict
run_gate "swift build" swift build
run_gate "swift test" swift test
run_gate "linux" bash scripts/check-linux.sh
run_gate "wasm" bash scripts/check-wasm.sh
