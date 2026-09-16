#!/usr/bin/env bash
# check_log.sh — the strict gate for the suites in this slice.
#
# WHY A PRINTED `PASS n/n` IS NOT ENOUGH. A GDScript runtime error aborts only the
# function it happens in; Godot keeps running, the caller continues, and the suite
# still prints its green line over a run that threw (independent-review.md, M-1 and
# M-4). In this slice that happened for real: `PASS 209/209, exit 0` alongside
# `SCRIPT ERROR: Invalid type in function 'step' … Cannot convert argument 2 from Nil
# to Dictionary`. This gate refuses that combination — exit code, check counts AND a
# clean error stream are all required.
#
#   ok   <name>                        → exit 0
#   FAIL <name> <one-line reason>      → exit 1
#
# `SCRIPT ERROR` IS NEVER ALLOWED. The two engine `ERROR:` lines below are named,
# counted and justified — anything else fails the suite.
#
#   1. `ERROR: arena_library: unknown arena id '<id>' (have: …)` — the arena
#      library's own guard against a caller bug. The slice test provokes it ON
#      PURPOSE (`Arena.build("nope")` must return null, through the library's real
#      guard rather than around it). Exactly one per run.
#
#   2. `ERROR: <n> resources still in use at exit` — the engine's shutdown report.
#      Root cause, established by measurement and NOT by this lane's code: the port
#      caches a `Shader` in a `static var`
#      (`godot/src/character/outfit_catalogue.gd:95`), and a static var outlives the
#      scene tree, so that resource is still referenced when the engine tears down.
#      That file belongs to the character slice and is outside this lane's write
#      scope, so it is reported rather than edited. The line is also INTERMITTENT
#      (absent in 4 of 7 runs, including both `--verbose` runs), and the test's own
#      footprint at the end of a run is 1 node / 0 orphan nodes, printed every run as
#      `# OBJECTS … nodes=… orphans=…`. The in-suite guard for a real leak is the
#      object-count check in `tests/game_slice_test.gd`; this allowance covers the
#      engine's own shutdown line, once, and nothing else.
#
# Usage: check_log.sh <suite name> <suite exit code> <log file> [expected FAIL lines]
#
# The fourth argument exists for the failure-path PROBE
# (`tests/build/audit_base_abort_probe.gd`): it drives `AuditBase.finish()` through
# the aborted and the failed case on purpose, and those two calls write `FAIL …` to
# stderr by design. A suite whose subject is failure has to be allowed to print one;
# every other suite runs with the default 0.
set -uo pipefail

name="${1:?suite name}"
code="${2:?exit code}"
log="${3:?log path}"

if [ ! -f "$log" ]; then
  echo "FAIL $name: no log at $log"
  exit 1
fi

ALLOW_ARENA='^ERROR: arena_library: unknown arena id'
ALLOW_ARENA_MAX=1
ALLOW_SHUTDOWN='^ERROR: [0-9]+ resources still in use at exit'
ALLOW_SHUTDOWN_MAX=1

if [ "$code" != "0" ]; then
  echo "FAIL $name: exit $code (log $log)"
  grep -m3 "^FAIL " "$log" || true
  exit 1
fi

allowed_fails="${4:-0}"
passes=$(grep -c "^PASS " "$log" || true)
fails=$(grep -c "^FAIL " "$log" || true)
script_errs=$(grep -c "SCRIPT ERROR" "$log" || true)
allowed_arena=$(grep -c -E "$ALLOW_ARENA" "$log" || true)
allowed_shutdown=$(grep -c -E "$ALLOW_SHUTDOWN" "$log" || true)
errs=$(grep -c -E "^ERROR:|USER ERROR" "$log" || true)
unexplained=$((errs - allowed_arena - allowed_shutdown))

if [ "$script_errs" != "0" ]; then
  echo "FAIL $name: $script_errs SCRIPT ERROR line(s) despite exit 0 (log $log)"
  grep -n "SCRIPT ERROR" "$log" | head -5
  exit 1
fi

if [ "$unexplained" != "0" ] \
   || [ "$allowed_arena" -gt "$ALLOW_ARENA_MAX" ] \
   || [ "$allowed_shutdown" -gt "$ALLOW_SHUTDOWN_MAX" ]; then
  echo "FAIL $name: $errs engine error line(s) — $allowed_arena arena-guard (max $ALLOW_ARENA_MAX), $allowed_shutdown shutdown (max $ALLOW_SHUTDOWN_MAX), $unexplained unexplained (log $log)"
  grep -n -E "^ERROR:|USER ERROR" "$log" | head -5
  exit 1
fi

if [ "$fails" != "$allowed_fails" ] || [ "$passes" -lt 1 ]; then
  echo "FAIL $name: $passes PASS line(s), $fails FAIL line(s) (allowed $allowed_fails) (log $log)"
  exit 1
fi

echo "ok $name: $(grep -m1 "^PASS " "$log") exit=0 script-errors=0 errors=$errs(allowed=$allowed_arena+$allowed_shutdown) fails=$fails(allowed=$allowed_fails) $log"
