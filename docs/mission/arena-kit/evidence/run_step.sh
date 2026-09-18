#!/usr/bin/env bash
# run/tmp/arena-kit/evidence/run_step.sh — the serialized, journalled engine runner for
# the arena-kit lane. Same discipline as tools/world-arenas/run_proof.sh:
#   * ONE Godot process at a time: the whole step runs under
#     `flock -w 900 /tmp/padel-godot.lock` and refuses to start when `pgrep -x Godot`
#     already shows a live process. macOS ships no util-linux `flock`, so `FLOCK` points
#     at `run/tmp/arena-kit/bin/flock`, a shim with the same semantics (fcntl LOCK_EX,
#     `-w` wait, then exec) on the same lock file;
#   * a per-process watchdog (macOS has no `timeout`);
#   * every run journaled with the exact command, the exit code, the `PASS n/n` tally,
#     the `SCRIPT ERROR` count and the log's SHA-256.
#
# A STEP IS GREEN ONLY WHEN ALL THREE HOLD: exit code 0, zero `SCRIPT ERROR` lines, and a
# `PASS n/n` tally (or `ALLOW_NO_TALLY=1` for a probe that prints its own marker). A
# missing tally is a FAILURE, never a pass: a parse error exits 0 with no tally and
# `exit=0 tally='<none>'` in the journal is a false green — this script exits 1 on it.
#
# USAGE  run_step.sh <phase> <name> <watchdog-seconds> <godot-args…>
#   <phase> groups the journal: baseline | after | kit
#   ALLOW_NO_TALLY=1 run_step.sh …   for the evidence probe (no PASS line by design)
set -uo pipefail

ROOT="/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
FLOCK="$ROOT/run/tmp/arena-kit/bin/flock"
HERE="$ROOT/run/tmp/arena-kit/evidence"
LOG_DIR="$HERE/logs"
JOURNAL="$HERE/results.tsv"
mkdir -p "$LOG_DIR"
[ -f "$JOURNAL" ] || printf 'phase\tname\texit\ttally\tscript_errors\tverdict\tsha256\tcommand\n' > "$JOURNAL"

phase="$1"; name="$2"; secs="$3"; shift 3
log="$LOG_DIR/$phase-$name.log"
printf '%s' "$*" > "$LOG_DIR/$phase-$name.cmd"
ALLOW_NO_TALLY="${ALLOW_NO_TALLY:-0}"

guard() {
  local pids
  pids="$(pgrep -x Godot || true)"
  if [ -n "$pids" ]; then
    echo "REFUSING to run: another Godot process is live (pids: $(echo $pids | tr '\n' ' '))"
    return 1
  fi
  return 0
}

run() {
  cd "$ROOT" || return 2
  if ! guard; then
    printf '%s\t%s\t%s\t\t\t%s\t\t%s\n' "$phase" "$name" "guard-refused" "" "guard-refused" "$*" >> "$JOURNAL"
    return 1
  fi
  echo "--- [$phase/$name] $* (watchdog ${secs}s)"
  "$@" > "$log" 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) &
  local wd=$!
  wait "$pid"
  local code=$?
  kill "$wd" 2>/dev/null
  wait "$wd" 2>/dev/null
  local tally errs sha verdict why=""
  tally="$(grep -m1 -E '^(PASS|FAIL) [0-9]+/[0-9]+' "$log" || true)"
  errs="$(grep -c 'SCRIPT ERROR' "$log" || true)"
  sha="$(shasum -a 256 "$log" | cut -d' ' -f1)"
  [ "$code" = "0" ] || why="$why exit=$code;"
  [ "$errs" = "0" ] || why="$why $errs SCRIPT ERROR;"
  case "$tally" in
    PASS*) ;;
    FAIL*) why="$why $tally;" ;;
    *) [ "$ALLOW_NO_TALLY" = "1" ] || why="$why no PASS tally;" ;;
  esac
  if [ -z "$why" ]; then verdict="green"; else verdict="red:$(printf '%s' "$why")"; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$phase" "$name" "$code" "$tally" "$errs" "$verdict" "$sha" "$*" >> "$JOURNAL"
  echo "    exit=$code tally='${tally:-<none>}' script_errors=$errs verdict=$verdict log_sha256=$(printf '%s' "$sha" | cut -c1-16)… log=$log"
  [ "$verdict" = "green" ] || return 1
  return 0
}

"$FLOCK" -w 900 /tmp/padel-godot.lock bash -c "$(declare -f run); $(declare -f guard); phase='$phase'; name='$name'; secs='$secs'; log='$log'; JOURNAL='$JOURNAL'; ROOT='$ROOT'; ALLOW_NO_TALLY='$ALLOW_NO_TALLY'; run \"\$@\"" -- "$@"
