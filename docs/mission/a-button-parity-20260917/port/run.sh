#!/usr/bin/env bash
# run.sh — rerunnable isolated replay of the ACTUAL Godot A-button input path.
#
# Runs ONLY in the isolated copy /tmp/padel-a-button-20260917-port/godot
# (own .godot cache, no shared cache, never the user's checkout). Headless,
# serial, with a --quit-after guard because this macOS host has no `timeout`.
#
# Steps:
#   1. import warm-up (`--import`) so the audio/.sample cache exists — idempotent;
#   2. the replay script (`--script res://port/port_replay.gd`).
#
# The log carries the REPLAY/SAMPLER trace lines, a final PASS n/n or FAIL n/n,
# the process exit code, and the SCRIPT ERROR / ERROR counts.
#
# Usage: LOG=/tmp/x.log ./run.sh

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJ="/tmp/padel-a-button-20260917-port/godot"
SCRATCH="/tmp/padel-a-button-20260917-port"
LOG="${LOG:-$SCRATCH/run.log}"
QUIT_AFTER="${QUIT_AFTER:-4000}"

# Guard: the user's live game (its PID moves) must be the ONLY engine process
# already running. We never touch it; we only refuse to pile a diagnostic run
# on top of a second diagnostic engine.
OTHER="$(ps -axo pid,command | grep -i '[G]odot.app/Contents/MacOS/Godot' | grep -v 'res://game/Main.tscn' || true)"
if [ -n "$OTHER" ]; then
  echo "BLOCKER: another diagnostic Godot engine is already running:" >&2
  echo "$OTHER" >&2
  exit 125
fi

mkdir -p "$SCRATCH"

echo "=== isolated A-button replay (headless, serial) ==="
echo "engine: $GODOT"
echo "project: $PROJ (isolated copy; user checkout untouched)"

echo "--- import warm-up ---"
env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  "$GODOT" --headless --path "$PROJ" --import > "$SCRATCH/import.log" 2>&1 || true

echo "--- replay ---"
env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  "$GODOT" --headless --path "$PROJ" --quit-after "$QUIT_AFTER" \
  --script res://port/port_replay.gd > "$LOG" 2>&1
code=$?

echo "exit_code=$code"
echo "SCRIPT_ERROR_count=$(grep -c 'SCRIPT ERROR' "$LOG" || true)"
echo "ERROR_count=$(grep -c 'ERROR:' "$LOG" || true)"
echo "verdict=$(grep -E '^(PASS|FAIL) ' "$LOG" | tail -1 || true)"

echo "--- trace (tail) ---"
grep -E '^(# |SAMPLER |REPLAY |PASS |FAIL |ok )' "$LOG" | tail -n 45 || true
exit "$code"
