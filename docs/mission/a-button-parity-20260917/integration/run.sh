#!/usr/bin/env bash
# run.sh — single bounded rerun of the cross-engine A-button differential proof.
# Runs ONLY in the isolated copy (/tmp/padel-a-button-20260917-port/godot),
# never the user's checkout. The Python runner owns real subprocess timeouts,
# completion-marker / SCRIPT ERROR / ERROR checks, determinism, red-control and
# truncation control.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/run_integration.py"
