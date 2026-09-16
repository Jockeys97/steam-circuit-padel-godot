#!/usr/bin/env bash
# Headless Godot parity digest (Steam Circuit Padel Pro, slice S1 / crew-xray).
#
# Runs the ported simulation core under godot/src/sim/ and prints the same
# digest lines as scripts/parity-digest.mjs, then compares them against the
# frozen JavaScript reference.
#
#   tools/sim-port/parity-digest-gd.sh --seed=12345 --ticks=1440 --every=60
#
# Exit 0 = the Godot digest matches the JavaScript reference; 1 = it does not
# (or the reference was not found). Override the binary with GODOT_BIN.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT_BIN:-/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"

exec env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" \
	--headless --path "$ROOT/godot/" \
	--script res://src/sim/parity_digest_gd.gd \
	-- "$@"
