#!/usr/bin/env bash
# run-match-matrix.sh — the three-match cross-engine parity proof, sequential and
# incremental (lane crew-parity).
#
# Per scenario, in this order, never two engines alive at once:
#   1. JS reference            -> <id>-js.txt            (node, headless)
#   2. JS reference AGAIN      -> <id>-js-rerun.txt      (reference reproducibility)
#   3. cmp 1 vs 2              -> the reference is its own control
#   4. Godot ported core       -> <id>-gd.txt            (flock + timeout, headless)
#   5. compare-match.mjs       -> <id>-compare.txt + .json
#   6. one row appended to matrix.jsonl, immediately
#
# Usage: bash tools/parity-godot/run-match-matrix.sh [scenario-id …]
# Scenario ids: m1-plain m2-double-fault m3-wall-glass-netcord
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/tools/parity-godot/out"
mkdir -p "$OUT"
cd "$ROOT"

run_js() { # run_js <out-path> <args…>
	local out="$1"; shift
	node tools/parity-godot/ref-match.mjs --quiet --out="$out" "$@"
}

scenario() { # scenario <id> <require> <ticks> <seed> <script> <athlete> <sets>
	local id="$1" require="$2" ticks="$3" seed="$4" script="$5" athlete="$6" sets="$7"
	local js="$OUT/$id-js.txt" js2="$OUT/$id-js-rerun.txt" gd="$OUT/$id-gd.txt"
	local common=(--seed="$seed" --ticks="$ticks" --every=1 --script="$script"
	              --athlete="$athlete" --sets="$sets" --stop-at-result)

	echo "=== $id seed=$seed ticks=$ticks script=$script athlete=$athlete sets=$sets require=$require"

	echo "--- [1/6] JS reference"
	run_js "$js" "${common[@]}"; local js_rc=$?
	echo "    exit=$js_rc"

	echo "--- [2/6] JS reference, second run (reproducibility control)"
	run_js "$js2" "${common[@]}"; local js2_rc=$?
	echo "    exit=$js2_rc"

	echo "--- [3/6] cmp js vs js-rerun"
	if cmp -s "$js" "$js2"; then rerun="identical"; else rerun="DIFFERENT"; fi
	echo "    js_rerun=$rerun"

	echo "--- [4/6] Godot ported core (flock + timeout, headless)"
	bash tools/parity-godot/run-match-gd.sh "${common[@]}" > "$gd" 2> "$OUT/$id-gd.stderr"
	local gd_rc=$?
	echo "    exit=$gd_rc"

	local script_errors unexplained
	script_errors=$(grep -c "SCRIPT ERROR" "$gd" "$OUT/$id-gd.stderr" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
	unexplained=$(grep -E "^(ERROR|USER ERROR|USER SCRIPT ERROR):" "$gd" "$OUT/$id-gd.stderr" 2>/dev/null | wc -l)
	echo "    script_errors=$script_errors unexpected_engine_errors=$unexplained"

	echo "--- [5/6] compare-match.mjs (digest gate + event gate + coverage)"
	node tools/parity-godot/compare-match.mjs "$js" "$gd" \
		--require="$require" --json="$OUT/$id-compare.json" > "$OUT/$id-compare.txt" 2>&1
	local cmp_rc=$?
	echo "    exit=$cmp_rc"
	grep -E "^(# event-counts|# required-families|# engine-parity|# event-parity|# first-event-divergence|#   |MATCH-COMPARE RESULT)" \
		"$OUT/$id-compare.txt" | sed 's/^/    /'
	local verdict
	verdict=$(grep -o "MATCH-COMPARE RESULT=[A-Z-]*" "$OUT/$id-compare.txt" | head -1)
	local sha_js sha_gd
	sha_js=$(grep -o "digestSha256=[0-9a-f]*" "$js" | tail -1 | cut -d= -f2)
	sha_gd=$(grep -o "digestSha256=[0-9a-f]*" "$gd" | tail -1 | cut -d= -f2)

	echo "--- [6/6] record"
	python3 - "$id" "$seed" "$ticks" "$script" "$athlete" "$sets" "$require" \
		"$js_rc" "$js2_rc" "$rerun" "$gd_rc" "$script_errors" "$unexplained" \
		"${verdict:-MATCH-COMPARE RESULT=?}" "$sha_js" "$sha_gd" "$cmp_rc" >> "$OUT/matrix.jsonl" <<'PY'
import json, sys
(a, seed, ticks, script, athlete, sets, require, js_rc, js2_rc, rerun, gd_rc,
 script_errors, unexplained, verdict, sha_js, sha_gd, cmp_rc) = sys.argv[1:18]
print(json.dumps({
    "id": a, "seed": int(seed), "ticks": int(ticks), "every": 1, "script": script,
    "athlete": int(athlete), "setsToWin": int(sets), "require": require.split(",") if require else [],
    "js_exit": int(js_rc), "js_rerun_exit": int(js2_rc), "js_rerun": rerun,
    "gd_exit": int(gd_rc), "gd_script_errors": int(script_errors),
    "gd_unexpected_errors": int(unexplained),
    "verdict": verdict, "digest_js": sha_js, "digest_gd": sha_gd,
    "digest_equal": sha_js == sha_gd, "compare_exit": int(cmp_rc),
}, sort_keys=True))
PY
	echo "    row appended to $OUT/matrix.jsonl"
}

ALL=(m1-plain m2-double-fault m3-wall-glass-netcord)
want=("$@")
selected=()
if [ ${#want[@]} -eq 0 ]; then
	selected=("${ALL[@]}")
else
	for w in "${want[@]}"; do
		for a in "${ALL[@]}"; do [ "$a" = "$w" ] && selected+=("$a"); done
	done
fi

for id in "${selected[@]}"; do
	case "$id" in
	m1-plain)
		# The frozen harness's own scenario (`scripts/parity-digest.mjs:89-98`), athlete
		# maestro, one set, played to the match result.
		scenario m1-plain "net-cord,glass" 30000 12345 frozen 0 1
		;;
	m2-double-fault)
		# `tools/sim-port/fault-digest.mjs` recipe: full-charge serve trigger + athlete 1
		# ("pantera", control 0.96 — the only athlete whose full-charge SECOND serve can
		# fault, `fault-double-fault-set-parity.md` §1.3).
		scenario m2-double-fault "double-fault,glass" 14000 999 full-charge 1 1
		;;
	m3-wall-glass-netcord)
		# Frozen script, seed 11 — the richest wall/glass + net-cord seed measured in the
		# seed probe (see docs/wayfinder/evidence/match-parity.md §2).
		scenario m3-wall-glass-netcord "net-cord,glass,wall" 30000 11 frozen 0 1
		;;
	esac
done

echo "=== matrix complete; rows: $OUT/matrix.jsonl"
wc -l "$OUT/matrix.jsonl"
