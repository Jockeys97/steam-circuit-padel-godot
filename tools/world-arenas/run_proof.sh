#!/usr/bin/env bash
# tools/world-arenas/run_proof.sh — the serialized world-arena proof runner.
#
# ONE GODOT PROCESS AT A TIME. Every step is guarded by `pgrep -x Godot` before it
# starts and by a per-process watchdog (macOS has no `timeout`; the watchdog kills
# only the PID this script started, never a `pkill`). Every run is journaled to
# its own log with: the exact command, the exit code, the `PASS n/n` tally, the
# `SCRIPT ERROR` count and the log's SHA-256 — `build_manifest.py` folds that into
# MANIFEST.json / MANIFEST.md.
#
# USAGE
#   tools/world-arenas/run_proof.sh                       # the four steps, five world arenas
#   tools/world-arenas/run_proof.sh --baseline            # + the slice suite, once
#   tools/world-arenas/run_proof.sh --arenas=officina,orrery   # probe existing arenas
#   tools/world-arenas/run_proof.sh --run-id=freeze-01 --baseline
#   tools/world-arenas/run_proof.sh --skip-capture
#
# STEPS, in order:
#   import          --headless --import (prerequisites for a fresh engine state)
#   baseline        --headless res://tests/game_slice_test.gd        (only with --baseline)
#   baseline_demo   --headless res://tests/game_slice_test.gd -- --demo (only with --baseline)
#   field_law       --headless res://tests/world_arenas_field_law_test.gd
#   frame           --headless res://tests/world_arenas_frame_test.gd
#   selection       --headless res://tests/world_arenas_selection_test.gd
#   selection_demo  --headless res://tests/world_arenas_selection_test.gd -- --demo
#   capture         --rendering-driver opengl3 res://tests/world_arenas_capture.tscn
#   menu_capture    --rendering-driver opengl3 res://tests/world_arenas_menu_capture.tscn
#                   (the real menu showing the world chooser; round-2 review item)
#
# Nothing here edits the repo. Outputs land in tools/world-arenas/out/<run-id>/
# (`tools/*/out/` is gitignored).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ARENAS=""
RUN_ID=""
WITH_BASELINE=0
WITH_CAPTURE=1

for a in "$@"; do
  case "$a" in
    --baseline) WITH_BASELINE=1 ;;
    --skip-capture) WITH_CAPTURE=0 ;;
    --arenas=*) ARENAS="${a#--arenas=}" ;;
    --run-id=*) RUN_ID="${a#--run-id=}" ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done
[ -n "$RUN_ID" ] || RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$ROOT/tools/world-arenas/out/$RUN_ID"
LOGS="$RUN_DIR/logs"
mkdir -p "$LOGS"
: > "$RUN_DIR/results.tsv"

if [ ! -x "$GODOT" ]; then
  echo "FAIL: no Godot at $GODOT (set GODOT=...)" >&2
  exit 2
fi

guard() {
  local pids
  pids="$(pgrep -x Godot || true)"
  if [ -n "$pids" ]; then
    echo "REFUSING to run: another Godot process is live (pids: $(echo $pids | tr '\n' ' '))" | tee -a "$RUN_DIR/results.tsv"
    return 1
  fi
  return 0
}

# run_step <name> <watchdog-seconds> <command...>
run_step() {
  local name="$1" secs="$2"
  shift 2
  if ! guard; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "guard-refused" "" "" "" "$*" >> "$RUN_DIR/results.tsv"
    return 1
  fi
  local log="$LOGS/$name.log"
  local cmd_file="$LOGS/$name.cmd"
  printf '%s' "$*" > "$cmd_file"
  echo "--- step $name: $* (watchdog ${secs}s, log $log)"
  "$@" > "$log" 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) &
  local wd=$!
  wait "$pid"
  local code=$?
  kill "$wd" 2>/dev/null
  wait "$wd" 2>/dev/null
  echo "$code" > "$LOGS/$name.exit"
  local tally script_errs sha
  tally="$(grep -m1 -E '^(PASS|FAIL) [0-9]+/[0-9]+' "$log" || true)"
  script_errs="$(grep -c 'SCRIPT ERROR' "$log" || true)"
  sha="$(shasum -a 256 "$log" | cut -d' ' -f1)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$code" "$tally" "$script_errs" "$sha" "$*" >> "$RUN_DIR/results.tsv"
  echo "    exit=$code tally='${tally:-<none>}' script_errors=$script_errs log_sha256=$(printf '%s' "$sha" | cut -c1-16)…"
  return 0
}

cd "$ROOT" || exit 2
echo "=== world-arena proof run $RUN_ID ==="
echo "    repo  $ROOT"
echo "    godot $GODOT"
echo "    dir   $RUN_DIR"

python3 "$HERE/tree_digest.py" > "$RUN_DIR/tree_before.json"

run_step import 600 "$GODOT" --headless --path godot --import
if [ "$WITH_BASELINE" = "1" ]; then
  run_step baseline_slice 900 "$GODOT" --headless --path godot --script res://tests/game_slice_test.gd
  run_step baseline_demo 900 "$GODOT" --headless --path godot --script res://tests/game_slice_test.gd -- --demo
fi
if [ -n "$ARENAS" ]; then
  run_step field_law 300 "$GODOT" --headless --path godot --script res://tests/world_arenas_field_law_test.gd -- --arenas="$ARENAS"
  run_step frame 300 "$GODOT" --headless --path godot --script res://tests/world_arenas_frame_test.gd -- --arenas="$ARENAS"
  run_step selection 900 "$GODOT" --headless --path godot --script res://tests/world_arenas_selection_test.gd -- --arenas="$ARENAS"
  run_step selection_demo 300 "$GODOT" --headless --path godot --script res://tests/world_arenas_selection_test.gd -- --arenas="$ARENAS" --demo
  if [ "$WITH_CAPTURE" = "1" ]; then
    run_step capture 900 "$GODOT" --path godot --rendering-driver opengl3 --resolution 1280x720 \
      res://tests/world_arenas_capture.tscn -- --arenas="$ARENAS" --out="$RUN_DIR/captures"
    run_step menu_capture 300 "$GODOT" --path godot --rendering-driver opengl3 --resolution 1280x720 \
      res://tests/world_arenas_menu_capture.tscn -- --out="$RUN_DIR/captures"
  fi
else
  run_step field_law 300 "$GODOT" --headless --path godot --script res://tests/world_arenas_field_law_test.gd
  run_step frame 300 "$GODOT" --headless --path godot --script res://tests/world_arenas_frame_test.gd
  run_step selection 900 "$GODOT" --headless --path godot --script res://tests/world_arenas_selection_test.gd
  run_step selection_demo 300 "$GODOT" --headless --path godot --script res://tests/world_arenas_selection_test.gd -- --demo
  if [ "$WITH_CAPTURE" = "1" ]; then
    run_step capture 900 "$GODOT" --path godot --rendering-driver opengl3 --resolution 1280x720 \
      res://tests/world_arenas_capture.tscn -- --out="$RUN_DIR/captures"
    run_step menu_capture 300 "$GODOT" --path godot --rendering-driver opengl3 --resolution 1280x720 \
      res://tests/world_arenas_menu_capture.tscn -- --out="$RUN_DIR/captures"
  fi
fi

python3 "$HERE/tree_digest.py" > "$RUN_DIR/tree_after.json"
python3 "$HERE/build_manifest.py" "$RUN_DIR" || echo "manifest build failed (kept the raw run dir)"

# Overall status: every step that ran must be exit 0, no SCRIPT ERRORs, tree stable.
python3 - "$RUN_DIR" <<'PY'
import json, sys, pathlib
run = pathlib.Path(sys.argv[1])
bad = []
for line in (run / "results.tsv").read_text().splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    name, code, tally, errs = parts[0], parts[1], parts[2], parts[3]
    if code != "0":
        bad.append(f"{name}: exit {code}")
    if errs not in ("0", ""):
        bad.append(f"{name}: {errs} SCRIPT ERROR line(s)")
    if tally.startswith("FAIL"):
        bad.append(f"{name}: {tally}")
before = json.loads((run / "tree_before.json").read_text())
after = json.loads((run / "tree_after.json").read_text())
if before.get("digest") != after.get("digest"):
    bad.append("tree digest changed during the run (concurrent writer?) — the manifest says so")
print("RUN " + ("OK" if not bad else "NOT-ALL-GREEN") + f" dir={run}")
for b in bad:
    print("  - " + b)
sys.exit(0 if not bad else 1)
PY
