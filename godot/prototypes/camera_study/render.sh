#!/usr/bin/env bash
# render.sh — renders the camera study at one resolution, in ONE Godot process.
#
# Host rules (3,910 MB RAM, 0 swap, other lanes working in this repo):
#   * every engine invocation goes through the shared lock, `timeout` inside;
#   * never two engines at once;
#   * rendering is Xvfb + Mesa llvmpipe software GL (`--rendering-driver opengl3`),
#     because plain `--headless` installs the dummy driver and captures blank.
#     These frames are COMPOSITION evidence only. They are not a frame-rate claim.
#
# Usage:  render.sh [WxH] [bodies]
#   WxH     default 1280x720
#   bodies  game (default: whatever match_controller.build_athletes() itself
#           builds - since the athletes-view integration that is the shipping
#           rig) | rig (force the athlete_spawn seam on top of it)
#
# Exit 0 + STUDY_PASS in the log == every option was rendered.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
LOCK=/tmp/padel-godot.lock

RES="${1:-1280x720}"
BODIES="${2:-game}"
LOG="$HERE/out/render_${RES}.log"
mkdir -p "$HERE/out"

echo "=== camera_study render res=$RES bodies=$BODIES log=$LOG ==="
flock -w 900 "$LOCK" timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 ${RES}x24" \
  "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$PROJECT" \
    res://prototypes/camera_study/CameraStudy.tscn -- \
    --bodies="$BODIES" --tier=3 --seed=20260916 --camera=default \
  2>&1 | tee "$LOG"
code=${PIPESTATUS[0]}
echo "render exit=$code"
grep -q 'STUDY_PASS' "$LOG" && echo "RESULT: STUDY_PASS" || echo "RESULT: NO STUDY_PASS"
exit "$code"
