#!/usr/bin/env bash
# run-parity-matrix.sh — re-run the 12-scenario parity matrix and re-compare.
#
#   tools/sim-port/run-parity-matrix.sh <out.jsonl>
#
# The scenario list is the one recorded in `tools/sim-port/out/coverage-matrix.jsonl`
# (the "before" run). Streams go to `tools/sim-port/out/after-<side>-<seed>-<ticks>-<every>.txt`
# so the frozen "before" streams are never overwritten.
#
# Each scenario is run the way the "before" matrix was run:
#   * `node scripts/parity-digest.mjs … --json=<path>` writes the JavaScript
#     reference the Godot harness itself reads;
#   * the Godot digest is given the same file with `--js=<path>`, so
#     `parity_digest_gd.gd`'s own comparator runs as well as this script's
#     independent `compare-digests.py` pass. Two comparators, not one.
#
# ONE engine process at a time, always under `timeout 300`, never holding engine
# output in a shell variable: this host has ~450 MB free and no swap.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_JSONL="${1:?usage: run-parity-matrix.sh <out.jsonl>}"
OUT_DIR="$ROOT/tools/sim-port/out"
GODOT="${GODOT_BIN:-/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"

SCENARIOS=(
  "12345 1440 60"
  "12345 1440 120"
  "999 1440 60"
  "999 28800 120"
  "7 4320 60"
  "7 14400 60"
  "2024 14400 120"
  "2024 720 7"
  "999983 28800 60"
  "2024 28800 120"
  "999983 4320 60"
  "12345 28800 60"
)

: > "$OUT_JSONL"
cd "$ROOT"
for scenario in "${SCENARIOS[@]}"; do
  read -r seed ticks every <<<"$scenario"
  js="$OUT_DIR/after-js-$seed-$ticks-$every.txt"
  gd="$OUT_DIR/after-gd-$seed-$ticks-$every.txt"
  jsjson="$OUT_DIR/after-js-$seed-$ticks-$every.json"
  start=$SECONDS

  node scripts/parity-digest.mjs --seed="$seed" --ticks="$ticks" --every="$every" \
    --json="$jsjson" >"$js" 2>/dev/null
  js_exit=$?

  timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" \
    --headless --path "$ROOT/godot/" --script res://src/sim/parity_digest_gd.gd \
    -- "--seed=$seed" "--ticks=$ticks" "--every=$every" "--js=$jsjson" >"$gd" 2>/dev/null
  gd_exit=$?

  verdict_line="$(python3 tools/sim-port/compare-digests.py "$js" "$gd")"
  cmp_exit=$?
  secs=$((SECONDS - start))

  VERDICT="$verdict_line" SEED="$seed" TICKS="$ticks" EVERY="$every" \
    JS="$js" GD="$gd" JSJSON="$jsjson" JS_EXIT="$js_exit" GD_EXIT="$gd_exit" CMP_EXIT="$cmp_exit" SECS="$secs" \
    python3 - "$OUT_DIR" <<'PY' >> "$OUT_JSONL"
import hashlib, json, os, sys

out_dir = sys.argv[1]


def digest_body(path):
    """sha256 of the tick lines joined by "\\n" plus a trailing newline —
    the convention `scripts/parity-digest.mjs` hashes with."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        ticks = [ln.strip() for ln in fh if ln.strip().startswith("tick=")]
    return hashlib.sha256(("\n".join(ticks) + "\n").encode()).hexdigest()


line = os.environ["VERDICT"]
print(json.dumps({
    "seed": int(os.environ["SEED"]),
    "ticks": int(os.environ["TICKS"]),
    "every": int(os.environ["EVERY"]),
    "verdict": "IDENTICAL" if line.startswith("IDENTICAL") else "DIVERGED",
    "comparator_exit": int(os.environ["CMP_EXIT"]),
    "comparator_line": line,
    "digest_js": digest_body(os.environ["JS"]),
    "digest_gd": digest_body(os.environ["GD"]),
    "js_stream": os.path.relpath(os.environ["JS"]),
    "gd_stream": os.path.relpath(os.environ["GD"]),
    "json_js": os.path.relpath(os.environ["JSJSON"]),
    "js_exit": int(os.environ["JS_EXIT"]),
    "gd_exit": int(os.environ["GD_EXIT"]),
    "seconds": int(os.environ["SECS"]),
}), flush=True)
PY
  echo "[$seed $ticks $every] $verdict_line (${secs}s)" >&2
done
echo "wrote $OUT_JSONL" >&2
