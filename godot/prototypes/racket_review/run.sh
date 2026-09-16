#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/opt/homebrew/bin/godot}"

"$GODOT_BIN" --path "$ROOT" --editor --quit-after 1 >/dev/null 2>&1 || true
"$GODOT_BIN" --path "$ROOT" --scene res://prototypes/racket_review/RacketReview.tscn
