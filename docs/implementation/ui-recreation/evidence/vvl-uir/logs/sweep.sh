#!/bin/bash
# VVL-UIR capture sweep — serial, one Godot process at a time, journaled.
# Produces, for each viewport: the router's full screen walk (capture_ui --capture=all),
# the in-match HUD lane (Match --capture=match) and the menu lane (Main --capture=menu).
# Files land in res://game/out/ (the harness owns that dir); this script copies each
# run's outputs into the evidence pack and restores out/ from a snapshot at the end.
set -u
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
REPO=/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
EVD="$REPO/docs/implementation/ui-recreation/evidence/vvl-uir"
OUT="$REPO/godot/game/out"
J="$EVD/logs/sweep-journal.txt"
SNAP=/tmp/vvl-uir-out-snapshot
mkdir -p "$EVD/logs" "$SNAP"

say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$J"; }

guard() {
  if pgrep -x Godot >/dev/null; then say "ABORT: another Godot process is running — refusing to start"; exit 3; fi
}

stage() { # stage <viewportDir>  — copy every PNG newer than the sweep start into the pack
  local dir="$1"
  local n=0
  for f in "$OUT"/*.png; do
    [ -f "$f" ] || continue
    if [ "$f" -nt "$EVD/logs/sweep-start.stamp" ]; then
      cp -p "$f" "$dir/$(basename "$f")"
      n=$((n+1))
    fi
  done
  say "STAGED $n PNG -> $(basename "$dir")"
}

run() { # run <label> <logfile> <godot args...>
  local label="$1"; shift
  local log="$1"; shift
  guard
  say "RUN $label"
  ( cd "$REPO" && "$GODOT" "$@" ) > "$log" 2>&1
  local rc=$?
  local tally; tally=$(grep -E '^(PASS|FAIL|CAPTURE_DONE|CAPTURE_UI_START)' "$log" | tail -3 | tr '\n' ' | ')
  local serr; serr=$(grep -c 'SCRIPT ERROR' "$log")
  say "EXIT $label rc=$rc script_errors=$serr :: $tally"
  return $rc
}

# --- snapshot the current out/ so it can be restored byte-identically -------------
rm -rf "$SNAP"; mkdir -p "$SNAP"
cp -p "$OUT"/*.png "$SNAP"/ 2>/dev/null || true
touch "$EVD/logs/sweep-start.stamp"
say "SNAPSHOT $(ls "$SNAP" | wc -l | tr -d ' ') png in $SNAP"

HARNESS=(--rendering-driver opengl3 --path godot res://tests/ui/capture_ui.tscn -- --capture=all --seed=20260916 --tier=3)
MATCH=(--rendering-driver opengl3 --path godot res://game/Match.tscn -- --ui=new --capture=match --tier=3 --seed=20260916)
MENU=(--rendering-driver opengl3 --path godot res://game/Main.tscn -- --ui=new --capture=menu --out=ui-vvl-menu)

for V in 1280x720 1710x1073; do
  VDIR="$EVD/port-$V"
  say "=== viewport $V ==="
  run "harness@$V"    "$EVD/logs/harness-$V.log" --resolution "$V" "${HARNESS[@]}"
  stage "$VDIR"
  run "match@$V"      "$EVD/logs/match-$V.log"   --resolution "$V" "${MATCH[@]}"
  stage "$VDIR"
  run "menu@$V"       "$EVD/logs/menu-$V.log"    --resolution "$V" "${MENU[@]}"
  stage "$VDIR"
done

# --- restore out/ byte-identically ------------------------------------------------
restore_n=0
for f in "$SNAP"/*.png; do
  b=$(basename "$f"); cp -p "$f" "$OUT/$b"; restore_n=$((restore_n+1))
done
# remove PNGs the sweep created that were not in the snapshot
for f in "$OUT"/*.png; do
  b=$(basename "$f")
  [ -f "$SNAP/$b" ] || { rm -f "$f"; say "REMOVED sweep-only $b"; }
done
say "RESTORED $restore_n png to out/"
say "SWEEP DONE"
echo "SWEEP DONE"
