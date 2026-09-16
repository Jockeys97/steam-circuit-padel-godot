#!/usr/bin/env bash
# verify-artifacts.sh — what the packaged builds are, and what they actually do.
#
# Records, per artifact: bytes and sha256, then runs it and records the exit code
# and the lines that matter. A build that exists is not a build that runs.
#
#   ./tools/export/verify-artifacts.sh
#
# The self-check build is the demo rule proved by the built thing: it boots its own
# content report, prints the content set it has and exits 0 only if the demo's rule
# holds inside the artifact.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/../../godot" && pwd)"
BUILD="$PROJECT/build"
LOGS="$HERE/logs"
LOCK=/tmp/padel-godot.lock
mkdir -p "$LOGS"

run_build() {  # run_build <label> <dir> <binary> <log> [args...]
  local label="$1" dir="$2" bin="$3" log="$4"; shift 4
  echo "=== $label ==="
  ( cd "$dir" && flock -w 900 "$LOCK" timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
      "./$bin" --headless "$@" 2>&1 | tee "$log" | tail -6 )
  echo "$label exit=${PIPESTATUS[0]}"
}

inventory() {
  echo "=== artifact inventory ==="
  for d in linux-x86_64 linux-x86_64-demo linux-x86_64-demo-selfcheck; do
    for f in "$BUILD/$d"/*; do
      [ -f "$f" ] || continue
      printf '%s  %12s bytes  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"
    done
  done
}

inventory | tee "$LOGS/artifact-inventory.txt"

run_build "demo-selfcheck (the demo asserting on itself)" \
  "$BUILD/linux-x86_64-demo-selfcheck" padel-demo-selfcheck.x86_64 "$LOGS/run-demo-selfcheck.log"
run_build "linux-x86_64 (the desktop build, headless boot check)" \
  "$BUILD/linux-x86_64" padel.x86_64 "$LOGS/run-full-headless.log"
run_build "linux-x86_64-demo (boot check)" \
  "$BUILD/linux-x86_64-demo" padel-demo.x86_64 "$LOGS/run-demo-headless.log"
