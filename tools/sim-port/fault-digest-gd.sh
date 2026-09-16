#!/usr/bin/env bash
# Headless Godot full-charge serve digest (fault / second serve scenario).
#
# The Godot half of `tools/sim-port/fault-digest.mjs`: runs the ported simulation
# core under godot/src/sim/ with the same full-charge serve trigger and prints the
# same digest lines, so `tools/parity/parity-compare.mjs` can compare the two
# streams unchanged.
#
#   tools/sim-port/fault-digest-gd.sh --seed=999 --ticks=600 --every=60
#
# Exit 0 = the harness ran; non-zero = it did not. Override the binary with
# GODOT_BIN. `set -e` is deliberately absent: the Godot exit code is propagated
# as the script's own, and a timeout must be visible as such.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT_BIN:-/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"

# ONE engine process at a time, always bounded: this host has ~350 MB free and no
# swap, and a runaway Godot has OOM-killed earlier ticks.
exec timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" \
	--headless --path "$ROOT/godot/" \
	--script res://src/sim/fault_digest_gd.gd \
	-- "$@"
