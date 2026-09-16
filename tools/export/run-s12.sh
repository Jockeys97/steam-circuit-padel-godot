#!/usr/bin/env bash
# run-s12.sh — slice S12 (export presets, demo rule, packaged build) from a clean
# checkout state to green, with every command's exit code recorded.
#
# Every Godot invocation goes through the project's shared heavy-process lock and
# a `timeout`, because this host has one CPU, 3,910 MB of RAM and other lanes
# working in the same repository. Never two engines.
#
#   ./tools/export/run-s12.sh gen      regenerate the demo table from the reference
#   ./tools/export/run-s12.sh audits   the three headless audits, full and demo
#   ./tools/export/run-s12.sh export   the three exports, one at a time
#   ./tools/export/run-s12.sh verify   hash, size and run every artifact
#   ./tools/export/run-s12.sh all      gen, audits, export, verify
#
# Exit codes are the engine's own (0 pass / 1 fail). `timeout` reports 124, which
# in this harness means "hung", not "failed": a GDScript parse error aborts
# `_ready()` and the headless main loop keeps running forever.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
LOCK=/tmp/padel-godot.lock
PROJECT="$REPO/godot"
LOGS="$HERE/logs"
BUILD="$PROJECT/build"

mkdir -p "$LOGS"

engine() {  # engine <log> <timeout> [args...]
  local log="$1" secs="$2"; shift 2
  flock -w 900 "$LOCK" timeout "$secs" env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 MALLOC_ARENA_MAX=1 \
    "$GODOT" "$@" 2>&1 | tee "$log"
  local code=${PIPESTATUS[0]}
  echo "engine exit=$code" >> "$log"
  grep -E '^(PASS|FAIL) [0-9]+/[0-9]+$' "$log" | tail -1
  return "$code"
}

cmd_gen() {
  echo "=== gen: the demo table, re-generated from js/build.js ==="
  ( cd "$REPO" && node tools/export/gen-demo-content.mjs ) | tee "$LOGS/gen-demo-content.log"
  echo "gen exit=${PIPESTATUS[0]}"
}

cmd_audits() {
  local audits=(demo_audit content_filter_audit export_preset_audit)
  for a in "${audits[@]}"; do
    for mode in full demo; do
      local args=(--headless --path "$PROJECT" "res://tests/build/$a.tscn")
      [ "$mode" = demo ] && args+=(-- --demo)
      echo "=== audit $a [$mode] ==="
      D="$LOGS" engine "$LOGS/$a-$mode.log" 180 "${args[@]}"
      echo "$a [$mode] exit=$?"
    done
  done
}

cmd_export() {
  local presets=(linux-x86_64 linux-x86_64-demo linux-x86_64-demo-selfcheck)
  for p in "${presets[@]}"; do
    local out
    case "$p" in
      linux-x86_64)                  out="$BUILD/linux-x86_64/padel.x86_64" ;;
      linux-x86_64-demo)             out="$BUILD/linux-x86_64-demo/padel-demo.x86_64" ;;
      linux-x86_64-demo-selfcheck)   out="$BUILD/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.x86_64" ;;
    esac
    mkdir -p "$(dirname "$out")"
    echo "=== export $p -> $out ==="
    D="$LOGS" engine "$LOGS/export-$p.log" 900 \
      --headless --path "$PROJECT" --export-release "$p" "$out"
    echo "export $p exit=$?"
  done
}

cmd_verify() {
  bash "$HERE/verify-artifacts.sh"
}

case "${1:-}" in
  gen)    cmd_gen ;;
  audits) cmd_audits ;;
  export) cmd_export ;;
  verify) cmd_verify ;;
  all)    cmd_gen; cmd_audits; cmd_export; cmd_verify ;;
  *)      sed -n '1,25p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac
