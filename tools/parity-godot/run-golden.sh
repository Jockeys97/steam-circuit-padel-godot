#!/usr/bin/env bash
# run-golden.sh — the 3D simulation checked against ITSELF.
#
# Since 2026-09-23 the Godot build is the authority on the rules. The browser build
# (js/game.js) is an archive: the 3D sim has already moved past it on purpose (e.g.
# the AI's low-drive "containment" block of commit 067584e exists only in sim.gd),
# so `run-match-matrix.sh` (JS vs Godot) is expected to diverge and is no longer the
# gate. This script is: it replays the same three scripted matches through the
# Godot sim and compares them with the recording in `golden/`.
#
# What a golden file holds (a few KB, not the 8 MB trace): the final digest line,
# every event line, and one full sample line every CHECKPOINT ticks. A mismatch is
# therefore located to within CHECKPOINT ticks, and the event diff says which shot.
# Determinism was measured before recording: two runs of m1 are byte-identical.
#
# Usage:
#   bash tools/parity-godot/run-golden.sh            # check (exit 1 on any drift)
#   bash tools/parity-godot/run-golden.sh --record   # re-record after an INTENDED
#                                                    # rule change; commit the diff
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
GOLDEN="$ROOT/tools/parity-godot/golden"
OUT="$ROOT/tools/parity-godot/out/golden"
CHECKPOINT=250
RECORD=0
[ "${1:-}" = "--record" ] && RECORD=1
mkdir -p "$GOLDEN" "$OUT"

# Same three matches as run-match-matrix.sh: id, ticks, seed, script, athlete, sets.
SCENARIOS=(
	"m1-plain 30000 12345 frozen 0 1"
	"m2-double-fault 14000 999 full-charge 1 1"
	"m3-wall-glass-netcord 30000 11 frozen 0 1"
)

# The recorded subset of a full trace. Messages are kept: they are the rules'
# own words (a changed message is a changed rule, or a changed translation).
extract() {
	awk -v every="$CHECKPOINT" '
		/^PARITY-DIGEST/ { print; next }
		/^# ev / { print; next }
		/^tick=/ { t = substr($1, 6) + 0; if (t % every == 0) print }
	' "$1"
}

status=0
for row in "${SCENARIOS[@]}"; do
	read -r id ticks seed script athlete sets <<< "$row"
	trace="$OUT/$id-gd.txt"
	"$GODOT" --headless --path "$ROOT/godot/" --script res://tests/parity/match_digest_gd.gd -- \
		--seed="$seed" --ticks="$ticks" --every=1 --script="$script" \
		--athlete="$athlete" --sets="$sets" --stop-at-result > "$trace" 2> "$OUT/$id-gd.stderr"
	if grep -q "SCRIPT ERROR" "$trace" "$OUT/$id-gd.stderr"; then
		echo "GOLDEN $id ERROR: the Godot run raised a script error (see $OUT/$id-gd.stderr)"
		status=1
		continue
	fi
	extract "$trace" > "$OUT/$id.golden"
	if [ "$RECORD" = 1 ]; then
		cp "$OUT/$id.golden" "$GOLDEN/$id.golden"
		echo "GOLDEN $id RECORDED $(grep -o 'digestSha256=[0-9a-f]*' "$GOLDEN/$id.golden")"
	elif [ ! -f "$GOLDEN/$id.golden" ]; then
		echo "GOLDEN $id MISSING: run with --record first"
		status=1
	elif cmp -s "$GOLDEN/$id.golden" "$OUT/$id.golden"; then
		echo "GOLDEN $id IDENTICAL $(grep -o 'digestSha256=[0-9a-f]*' "$OUT/$id.golden")"
	else
		echo "GOLDEN $id DRIFTED — first difference (< recorded, > now):"
		diff "$GOLDEN/$id.golden" "$OUT/$id.golden" | head -6 | cut -c1-200
		status=1
	fi
done
[ "$status" = 0 ] && echo "GOLDEN PASS" || echo "GOLDEN FAIL"
exit "$status"
