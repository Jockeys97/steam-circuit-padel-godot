#!/usr/bin/env bash
# run/tmp/arena-kit/evidence/run_battery.sh — run the frozen suites this lane must not
# break, one after another through the serialized runner (ONE Godot process at a time),
# against either the working tree or the pristine `--path` tree, and print the tally table.
#
#   run_battery.sh <label> <project-path> [suite…]
#     <label>         journal phase (before | after | kit …)
#     <project-path>  godot/  or  run/tmp/arena-kit/pristine
#
# Suites (the runner paths are the repo's own: `tools/world-arenas/run_proof.sh` for the
# world-arena four, `docs/implementation/ui-recreation/tickets/UIR-12-screen-arena.md:76`
# for the screen audit):
#   slice_full        res://tests/game_slice_test.gd
#   slice_demo        res://tests/game_slice_test.gd -- --demo
#   field_law         res://tests/world_arenas_field_law_test.gd
#   frame             res://tests/world_arenas_frame_test.gd
#   selection         res://tests/world_arenas_selection_test.gd
#   selection_demo    res://tests/world_arenas_selection_test.gd -- --demo
#   selector_contract res://tests/ui/arena_selector_contract_test.gd
#   screen_audit      res://tests/ui/screen_arena_audit.gd
set -uo pipefail

ROOT="/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
STEP="$ROOT/run/tmp/arena-kit/evidence/run_step.sh"
label="$1"
project="$2"
shift 2
suites=("$@")
if [ "${#suites[@]}" = "0" ]; then
  suites=(slice_full slice_demo field_law frame selection selection_demo selector_contract screen_audit)
fi

secs_for() {
  case "$1" in
    slice_full|slice_demo|selection) echo 900 ;;
    *) echo 400 ;;
  esac
}

for suite in "${suites[@]}"; do
  case "$suite" in
    slice_full)        args=(--headless --path "$project" --script res://tests/game_slice_test.gd) ;;
    slice_demo)        args=(--headless --path "$project" --script res://tests/game_slice_test.gd -- --demo) ;;
    field_law)         args=(--headless --path "$project" --script res://tests/world_arenas_field_law_test.gd) ;;
    frame)             args=(--headless --path "$project" --script res://tests/world_arenas_frame_test.gd) ;;
    selection)         args=(--headless --path "$project" --script res://tests/world_arenas_selection_test.gd) ;;
    selection_demo)    args=(--headless --path "$project" --script res://tests/world_arenas_selection_test.gd -- --demo) ;;
    selector_contract) args=(--headless --path "$project" --script res://tests/ui/arena_selector_contract_test.gd) ;;
    screen_audit)      args=(--headless --path "$project" --script res://tests/ui/screen_arena_audit.gd) ;;
    *) echo "unknown suite '$suite'"; exit 2 ;;
  esac
  bash "$STEP" "$label" "$suite" "$(secs_for "$suite")" "$GODOT" "${args[@]}" || echo "    ^^ step reported NOT green"
done

echo
echo "=== $label tallies (project: $project) ==="
awk -F'\t' -v lbl="$label" '$1==lbl {printf "  %-20s exit=%-4s %-12s script_errors=%-3s %s\n", $2, $3, ($4==""?"<none>":$4), $5, $6}' \
  "$ROOT/run/tmp/arena-kit/evidence/results.tsv"
