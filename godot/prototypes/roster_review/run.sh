#!/usr/bin/env bash
# Render the four athlete meshes side by side, at the match camera and up close.
#
# macOS recipe: the real renderer, NOT --headless (--headless installs the dummy
# driver and every capture comes out blank). A window opens for a few seconds.
# Godot 4.7.2 lives at /Applications/Godot.app (symlinked as `godot`).
#
# Close the editor first: this run imports two 25-30 MB GLBs and two processes
# writing godot/.godot/imported at once is asking for a corrupt cache.
#
# Usage:  godot/prototypes/roster_review/run.sh [WxH]
# Exit 0 + "ROSTER_REVIEW_PASS" in the log == both frames were written.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
RES="${1:-1600x900}"
OUT="$HERE/out"
mkdir -p "$OUT"

godot --path "$PROJECT" --resolution "$RES" \
  res://prototypes/roster_review/RosterReview.tscn 2>&1 | tee "$OUT/run.log"

grep -q 'ROSTER_REVIEW_PASS' "$OUT/run.log" && echo "RESULT: ROSTER_REVIEW_PASS"
ls -1 "$OUT"/*.png
