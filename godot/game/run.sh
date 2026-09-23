#!/usr/bin/env bash
# run.sh — the documented entry points for the S2 quick-match slice.
#
# Everything here runs through the project's shared heavy-process lock. This host
# has 3,910 MB RAM / 0 swap and several lanes working on the same repository, so
# AT MOST ONE Godot process may exist at a time across the whole mission:
#
#     flock -w 900 /tmp/padel-godot.lock <command>
#
# Rendering uses `xvfb-run` + `--rendering-driver opengl3` (Mesa llvmpipe,
# software GL, no GPU). Plain `--headless` installs the dummy rendering driver
# and every capture comes out blank — the recipe proven in
# docs/wayfinder/evidence/character-material-render.md.
#
# Usage:
#   ./run.sh harness     the project's own smoke harness (must print PASS 8/8)
#   ./run.sh test        headless scripted playthrough of the real match scene
#   ./run.sh play        open the playable window (needs a display; on this host
#                        add `xvfb` -> ./run.sh play-xvfb, which is a software
#                        slide-show, not a frame-rate statement)
#   ./run.sh shots       render the captures into godot/game/out/
#   ./run.sh shots-arenas  render one frame per arena (nine) into godot/game/out/,
#                          in ONE engine process: the same scene, the same camera and
#                          the same tick for all nine, so the only difference between
#                          two frames is the arena. Also re-renders the menu.
#   ./run.sh all         test, then shots
#
# Exit codes are the engine's own: the harness and the slice test exit 0 on PASS.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
GODOT="${GODOT:-/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
LOCK=/tmp/padel-godot.lock
RES="${RES:-1280x720}"
OUT="$HERE/out"
LOG_DIR="${LOG_DIR:-/tmp}"

# `-- ` separates engine arguments from the user arguments the game reads.
run_harness() {
  # The project's main scene is the game menu (`game/Main.tscn`) since 2026-09-23,
  # so the harness names its scene explicitly instead of relying on the default.
  echo "=== harness: --headless --path godot/ res://tests/SmokeTest.tscn ==="
  flock -w 900 "$LOCK" timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    "$GODOT" --headless --path "$PROJECT" res://tests/SmokeTest.tscn 2>&1 | tee "$LOG_DIR/padel-harness.log"
  echo "harness exit=${PIPESTATUS[0]}"
}

run_test() {
  echo "=== slice test: --headless --script res://tests/game_slice_test.gd ==="
  flock -w 900 "$LOCK" timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    "$GODOT" --headless --path "$PROJECT" --script res://tests/game_slice_test.gd \
    2>&1 | tee "$LOG_DIR/padel-slice-test.log"
  echo "slice test exit=${PIPESTATUS[0]}"
}

run_play() {
  echo "=== playable window (main menu -> quick match) ==="
  echo "    seed ${SEED:-20260916}, tier ${TIER:-3}, camera ${CAMERA:-default}"
  flock -w 900 "$LOCK" env -u GODOT_SILENCE_ROOT_WARNING=1 \
    "$GODOT" --path "$PROJECT" res://game/Main.tscn -- \
      --seed="${SEED:-20260916}" --tier="${TIER:-3}" --camera="${CAMERA:-default}"
}

run_play_xvfb() {
  echo "=== playable window under Xvfb (software GL: correctness only) ==="
  flock -w 900 "$LOCK" timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    xvfb-run -a -s "-screen 0 ${RES}x24" \
    "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$PROJECT" \
      res://game/Main.tscn -- --seed="${SEED:-20260916}" --tier="${TIER:-3}"
}

run_shots() {
  mkdir -p "$OUT"

  echo "=== capture: main menu -> $OUT/menu.png ==="
  flock -w 900 "$LOCK" timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    xvfb-run -a -s "-screen 0 ${RES}x24" \
    "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$PROJECT" \
      res://game/Main.tscn -- --capture=menu 2>&1 | tee "$LOG_DIR/padel-capture-menu.log"
  echo "menu capture exit=${PIPESTATUS[0]}"

  echo "=== capture: in-match frames -> $OUT/quickmatch-serve.png, rally.png, hud.png, result.png ==="
  flock -w 900 "$LOCK" timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    xvfb-run -a -s "-screen 0 ${RES}x24" \
    "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$PROJECT" \
      res://game/Match.tscn -- --capture=match --camera="${CAMERA:-default}" \
      --tier="${TIER:-3}" --seed="${SEED:-20260916}" \
      2>&1 | tee "$LOG_DIR/padel-capture-match.log"
  echo "match capture exit=${PIPESTATUS[0]}"

  echo "--- written ---"
  ls -l "$OUT"
  file "$OUT"/*.png 2>/dev/null || true
}

run_arena_shots() {
  mkdir -p "$OUT"

  echo "=== capture: menu with the arena row -> $OUT/menu.png ==="
  flock -w 900 "$LOCK" timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    xvfb-run -a -s "-screen 0 ${RES}x24" \
    "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$PROJECT" \
      res://game/Main.tscn -- --capture=menu 2>&1 | tee "$LOG_DIR/padel-capture-menu.log"
  echo "menu capture exit=${PIPESTATUS[0]}"

  echo "=== capture: one frame per arena -> $OUT/arena-<id>.png ==="
  flock -w 900 "$LOCK" timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    xvfb-run -a -s "-screen 0 ${RES}x24" \
    "$GODOT" --rendering-driver opengl3 --resolution "$RES" --path "$PROJECT" \
      res://game/Match.tscn -- --capture=arenas --camera="${CAMERA:-default}" \
      --tier="${TIER:-3}" --seed="${SEED:-20260916}" \
      2>&1 | tee "$LOG_DIR/padel-capture-arenas.log"
  echo "arena capture exit=${PIPESTATUS[0]}"

  echo "--- written ---"
  ls -l "$OUT"/arena-*.png
  file "$OUT"/arena-*.png 2>/dev/null || true
}

case "${1:-}" in
  harness) run_harness ;;
  test) run_test ;;
  play) run_play ;;
  play-xvfb) run_play_xvfb ;;
  shots) run_shots ;;
  shots-arenas) run_arena_shots ;;
  all) run_test; run_shots ;;
  *)
    sed -n '1,30p' "${BASH_SOURCE[0]}"
    exit 2
    ;;
esac
