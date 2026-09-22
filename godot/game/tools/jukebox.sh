#!/usr/bin/env bash
# godot/game/tools/jukebox.sh — Launches the interactive In-Game Jukebox & Sound Test
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/../.." && pwd)"

GODOT_BIN="${GODOT:-godot}"
if ! command -v "${GODOT_BIN}" &> /dev/null; then
    if [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
        GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
    else
        echo "Godot binary not found in PATH or /Applications/Godot.app"
        exit 1
    fi
fi

echo "Launching Steam Circuit Padel Pro — In-Game Jukebox & Sound Test..."
"${GODOT_BIN}" --path "${REPO}/godot" "res://src/ui/jukebox/JukeboxScreen.tscn" "$@"
