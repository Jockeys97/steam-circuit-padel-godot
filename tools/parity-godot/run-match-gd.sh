#!/usr/bin/env bash
# run-match-gd.sh — run the Godot half of the match-parity proof, headless and
# serialised against every other Godot user on this host.
#
#   tools/parity-godot/run-match-gd.sh --seed=12345 --ticks=24000 --every=1 \
#     --script=frozen --athlete=0 --sets=1 --stop-at-result
#
# Two rules this wrapper exists to enforce (host: 3910 MB RAM, small swap, other
# lanes working concurrently):
#   1. ONE engine at a time — `flock -w 900 /tmp/padel-godot.lock`;
#   2. always bounded — `timeout` INSIDE the lock, so a hung engine releases it.
#
# It prints the engine's stdout, which is the digest stream `compare-match.mjs`
# reads (the Godot banner line is tolerated by the parsers, as before).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT_BIN:-/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
TIMEOUT="${MATCH_GD_TIMEOUT:-300}"

exec flock -w 900 /tmp/padel-godot.lock \
	timeout "$TIMEOUT" env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" \
	--headless --path "$ROOT/godot/" \
	--script res://tests/parity/match_digest_gd.gd \
	-- "$@"
