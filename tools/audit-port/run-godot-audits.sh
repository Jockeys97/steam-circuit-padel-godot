#!/usr/bin/env bash
# run-godot-audits.sh — run each ported rules/simulation audit on its own, one
# log and one exit code per audit, then the combined runner.
#
#   bash tools/audit-port/run-godot-audits.sh
#
# Serialised by the shared Godot lock (/tmp/padel-godot.lock) and bounded by
# `timeout` inside the lock, because a script error that aborts the callback
# hangs the process instead of going red — the same contract the engine harness
# uses (docs/wayfinder/evidence/godot-harness-smoke.log).
set -u
cd "$(dirname "$0")/../.." || exit 1

GODOT=/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64
LOGS=tools/audit-port/logs
mkdir -p "$LOGS"

# name:timeout — the heavy statistical audits get the bound their sample counts
# need; the rest run inside 180 s.
AUDITS=(
  "wall_rules:180"
  "court_speed:180"
  "match_format:180"
  "shot_quality:180"
  "smash_input:180"
  "lineup:300"
  "controller_tactics:180"
  "ai_attack:600"
  "difficulty:600"
  "shot_balance:600"
)

status=0
for entry in "${AUDITS[@]}"; do
  name="${entry%%:*}"
  bound="${entry##*:}"
  flock -w 900 /tmp/padel-godot.lock \
    timeout "$bound" env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    "$GODOT" --headless --path godot/ --script "res://tests/audits/${name}_audit.gd" \
    > "$LOGS/${name}_audit.log" 2>&1
  code=$?
  line=$(grep -E '^(PASS|FAIL) ' "$LOGS/${name}_audit.log" | tail -1)
  echo "${name} exit=${code} ${line}"
  [ "$code" -ne 0 ] && status=1
done

flock -w 900 /tmp/padel-godot.lock \
  timeout 1800 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  "$GODOT" --headless --path godot/ --script res://tests/audits/run_all.gd \
  > "$LOGS/run_all.log" 2>&1
code=$?
echo "run_all exit=${code} $(grep -E '^PASS ' "$LOGS/run_all.log" | tail -1)"
[ "$code" -ne 0 ] && status=1

exit "$status"
