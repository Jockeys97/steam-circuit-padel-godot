#!/usr/bin/env bash
# capture-artifact.sh — run a packaged build in a real window and photograph it.
#
#   ./tools/export/capture-artifact.sh <build-dir> <binary> <out.png>
#
# The host has no GPU: Xvfb plus the `opengl3` driver is Mesa llvmpipe, software
# GL. That is valid proof that the exported binary starts, opens a window and
# renders a frame; it is NOT a frame-rate measurement and no such claim is made
# from it (the same caveat `godot/game/run.sh` records).
#
# `--headless` installs the dummy rendering driver and every capture comes out
# blank; the windowed path is the only one that paints.

set -uo pipefail

DIR="$1"; BIN="$2"; OUT="$3"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
RES="${RES:-1280x720}"
# Absolute: the game is launched from inside `$DIR`, so a relative log path would
# be resolved against the build directory and the redirect would fail before the
# binary ever starts (observed once — a black capture and no log).
OUT="$(realpath -m "$OUT")"
LOG="${OUT%.png}.log"
mkdir -p "$(dirname "$OUT")"

Xvfb ":$DISPLAY_NUM" -screen 0 "${RES}x24" -nolisten tcp > "$LOG.xvfb" 2>&1 &
XVFB_PID=$!
sleep 3

( cd "$DIR" && DISPLAY=":$DISPLAY_NUM" flock -w 900 /tmp/padel-godot.lock timeout 90 \
    env GODOT_SILENCE_ROOT_WARNING=1 \
    "./$BIN" --rendering-driver opengl3 --resolution "$RES" > "$LOG" 2>&1 ) &
GAME_PID=$!
sleep 30

DISPLAY=":$DISPLAY_NUM" ffmpeg -y -loglevel error -f x11grab -video_size "$RES" \
  -i ":$DISPLAY_NUM" -frames:v 1 "$OUT"
CAPTURE_EXIT=$?

kill "$GAME_PID" 2>/dev/null
sleep 2
kill "$XVFB_PID" 2>/dev/null
wait "$GAME_PID" 2>/dev/null

echo "capture exit=$CAPTURE_EXIT"
ls -l "$OUT" 2>/dev/null
file "$OUT" 2>/dev/null
echo "--- game stdout ---"
cat "$LOG"
