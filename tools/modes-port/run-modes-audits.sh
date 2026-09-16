#!/usr/bin/env bash
# run-modes-audits.sh — the modes lane's whole gate, in one place.
#
#   bash tools/modes-port/run-modes-audits.sh
#
# Runs the six ported audits individually, the aggregate runner, and the engine
# harness that must stay green. Every Godot invocation is wrapped in the shared
# lock with a `timeout` inside, and one engine runs at a time.
#
# Writes one log per audit under `tools/modes-port/out/`, then prints a table of
# `name exit pass_line`. The default `user://` profile is never touched (the
# progression audit points its store at `user://modes-port-audit/` and removes it).
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

GODOT="${GODOT:-/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
OUT="tools/modes-port/out"
mkdir -p "$OUT"

run() {
  local name="$1"; shift
  flock -w 900 /tmp/padel-godot.lock timeout "$TIMEOUT" \
    env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" --headless --path godot/ "$@" \
    > "$OUT/$name.log" 2>&1
  local code=$?
  printf '%-26s exit=%d %s\n' "$name" "$code" "$(grep -E '^(PASS|FAIL)' "$OUT/$name.log" | head -1)"
  return 0
}

TIMEOUT=300
for audit in tournament_audit outfit_challenges_audit save_progression_audit \
             reference_grid_audit career_audit drill_audit; do
  run "$audit" --script "res://tests/modes/$audit.gd"
done

TIMEOUT=900
run modes-run-all --script res://tests/modes/run_all.gd

TIMEOUT=300
run bench_step --script res://tests/modes/bench_step.gd -- 20000
run harness
