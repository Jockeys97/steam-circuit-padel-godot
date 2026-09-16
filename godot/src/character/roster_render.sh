#!/usr/bin/env bash
# Render evidence for the roster + outfit catalogue slice.
#
# Same proven recipe as godot/src/character/render.sh: Xvfb + Mesa llvmpipe software
# OpenGL, --rendering-driver opengl3. NOT --headless: --headless installs the dummy
# rendering driver and every capture comes out blank.
#
# The scene is passed as an explicit positional argument, so godot/project.godot
# (another lane's file) is not touched and `run/main_scene` stays as it is.
#
# Software GL: valid for correctness screenshots, INVALID for any frame-rate claim.
#
# Host has 3910 MB RAM, 0 swap and other agents running, so the caller MUST hold the
# shared engine lock:
#   flock -w 900 /tmp/padel-godot.lock godot/src/character/roster_render.sh 512x512
#
# Usage:  roster_render.sh [WxH]
# Exit 0 + "ROSTER_RENDER_PASS" in the log == the frames were written.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
GODOT=/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64

RES="${1:-512x512}"
OUT="$HERE/out"
LOG="$OUT/roster_render_shell_${RES}.log"

mkdir -p "$OUT"
echo "=== roster_render.sh res=$RES project=$PROJECT out=$OUT ==="
env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 RIG_OUT_DIR="res://src/character/out" \
  timeout 600 xvfb-run -a -s "-screen 0 ${RES}x24" \
  "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$PROJECT" \
  res://src/character/RosterRender.tscn \
  2>&1 | tee "$LOG"

echo "--- written ---"
ls -1 "$OUT"/roster_*.png 2>/dev/null | wc -l
grep -q 'ROSTER_RENDER_PASS' "$LOG" && echo "RESULT: ROSTER_RENDER_PASS"
