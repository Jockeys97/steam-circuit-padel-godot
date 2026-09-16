#!/usr/bin/env bash
# Headless render for character_material on this GPU-less Linux host.
#
# Same proven recipe as godot/prototypes/render_probe/render.sh and
# godot/prototypes/arena_spike/render.sh: Xvfb + Mesa llvmpipe software OpenGL,
# opengl3 driver. NOT --headless: --headless installs the dummy rendering
# driver, so the viewport texture would be blank; xvfb-run gives a real GL
# context with no display attached.
#
# Usage:  render.sh [WxH]
# Exit 0 + "CM_PASS" in the log == three real PNGs were written.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT=/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64

RES="${1:-1280x720}"
AB="$HERE/outfit_ab_side_by_side_${RES}.png"
A="$HERE/outfit_a_only_${RES}.png"
B="$HERE/outfit_b_only_${RES}.png"
LOG="$HERE/render_${RES}.log"

rm -f "$AB" "$A" "$B" "$LOG"

echo "=== render.sh res=$RES ab=$AB a=$A b=$B log=$LOG ==="
env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    CM_PNG_AB="$AB" CM_PNG_A="$A" CM_PNG_B="$B" \
  timeout 300 xvfb-run -a -s "-screen 0 ${RES}x24" \
  "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$HERE" \
  2>&1 | tee "$LOG"

echo "--- written ---"
ls -l "$AB" "$A" "$B" 2>/dev/null || echo "MISSING one or more PNGs"
file "$AB" "$A" "$B" 2>/dev/null || true
grep -c 'CM_PASS' "$LOG" >/dev/null && echo "RESULT: CM_PASS"
