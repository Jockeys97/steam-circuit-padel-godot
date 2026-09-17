#!/usr/bin/env bash
# See slice_cue_probe.gd. macOS: the real renderer, never --headless (the dummy
# driver captures blank frames). A window opens for a few seconds.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
mkdir -p "$HERE/out"
godot --path "$PROJECT" --resolution "${1:-1600x900}" \
  --script res://game/tools/slice_cue_probe.gd 2>&1 | tee "$HERE/out/slice_cue.log"
grep -q 'SLICE_CUE_PASS' "$HERE/out/slice_cue.log" && echo "RESULT: SLICE_CUE_PASS"
