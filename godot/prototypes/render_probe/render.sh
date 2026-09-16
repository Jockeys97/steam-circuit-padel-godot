#!/usr/bin/env bash
# Proven headless render command for this GPU-less Linux host.
#
# Renders godot/prototypes/render_probe/Main.tscn through Xvfb with Mesa's
# llvmpipe software OpenGL (OpenGL 4.5 core) and writes a real PNG.
#
# Usage:  godot/prototypes/render_probe/render.sh [output.png] [WxH]
# Exit 0 + "PROBE_PASS" == a real PNG was written.
set -euo pipefail

GODOT=/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64
PROBE_DIR=/root/projects/steam-circuit-padel-pro/godot/prototypes/render_probe

OUT="${1:-$PROBE_DIR/probe.png}"
RES="${2:-1280x720}"

rm -f "$OUT"

env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 PROBE_PNG="$OUT" \
  timeout 180 xvfb-run -a -s "-screen 0 ${RES}x24" \
  "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$PROBE_DIR"

echo "--- written ---"
ls -l "$OUT"
file "$OUT"
