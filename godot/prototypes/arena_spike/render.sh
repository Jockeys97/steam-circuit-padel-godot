#!/usr/bin/env bash
# Headless render for the camera/feel spike on this GPU-less Linux host.
#
# Same proven recipe as godot/prototypes/render_probe/render.sh: Xvfb + Mesa
# llvmpipe software OpenGL, opengl3 driver. Writes a real PNG and a raw log.
#
# Usage:  render.sh [view] [out.png] [WxH]
#   view: default | wide | playable      (default: default)
# Exit 0 + "ARENA_PASS" in the log == a real PNG was written.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT=/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64

VIEW="${1:-default}"
OUT="${2:-$HERE/arena_${VIEW}_1280x720.png}"
RES="${3:-1280x720}"
LOG="${OUT%.png}.log"

rm -f "$OUT" "$LOG"

echo "=== render.sh view=$VIEW res=$RES out=$OUT log=$LOG ==="
env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    ARENA_VIEW="$VIEW" ARENA_PNG="$OUT" \
  timeout 180 xvfb-run -a -s "-screen 0 ${RES}x24" \
  "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$HERE" \
  2>&1 | tee "$LOG"

echo "--- written ---"
ls -l "$OUT" 2>/dev/null || echo "MISSING $OUT"
file "$OUT" 2>/dev/null || true
grep -c 'ARENA_PASS' "$LOG" >/dev/null && echo "RESULT: ARENA_PASS"
