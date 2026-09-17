---
id: UIR-00
title: Baseline freeze and evidence register
slug: baseline-freeze
state: done
readiness: potential
owner_role: coordinator
blocked_by: []
blocks: []
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-00-baseline-gates.log
  - docs/implementation/ui-recreation/evidence/uir-00-before-set.md
---

# UIR-00: Baseline freeze and evidence register

## Worker brief (copy-paste)

> Read-only session, no product code. Re-run the local gate baseline on this Mac (serial, one Godot process at a time, native commands in this file), record exit codes and tally lines into `evidence/uir-00-baseline-gates.log`, and register the existing "before" capture set with sizes, timestamps and sha256 into `evidence/uir-00-before-set.md`. Do not touch `js/`, `index.html`, `styles.css`, `godot/src/sim/**`, or any file outside the two evidence files in the write allowlist. Hand back: log path, tally table, any red surface with its exact failing line.

## Why this exists

Every later ticket compares against a recorded baseline. The handoff numbers come from earlier sessions and were not re-run in the planning session that wrote this pack; this ticket turns them into measured numbers, on this machine, at the commit the work starts from. It also freezes the "before" UI captures so the recreation has a dated starting point.

## Prerequisites (Definition of Ready)

- The pack is approved by Luca (plan frontmatter `approved` flips to true), or the coordinator explicitly starts this ticket as read-only reconnaissance.
- The repo is clean: `git status --short` prints nothing.
- Head commit recorded in the log (expected at pack authoring time: `74195c4`).

## Read allowlist

- `docs/mission/LOG.md`, `docs/mission/BOARD.md`, `docs/wayfinder/evidence/local-macos-gate-sweep.md`
- `godot/game/run.sh`, `godot/project.godot`
- `godot/game/out/*.png` (inspect via `file` and `shasum`; do not edit)

## Write allowlist

- `docs/implementation/ui-recreation/evidence/uir-00-baseline-gates.log`
- `docs/implementation/ui-recreation/evidence/uir-00-before-set.md`

No other writes. No commits. No pushes.

## Do not touch

`js/**`, `index.html`, `styles.css`, `godot/**` (any file), `docs/implementation/PLAN.md`, any existing ticket.

## Microsteps (do in order)

1. Record context into the log: `date`, `git log --oneline -1`, `git status --short`, engine hash check `"$GODOT" --version` (expect `4.7.2.stable.official.ed1daf0bf`).
2. Acquire the serial lock (PROPOSED protocol, since `flock` is not installed on this Mac):
   ```bash
   LOCK=/tmp/padel-godot.lock.d
   until mkdir "$LOCK" 2>/dev/null; do sleep 5; done
   trap 'rmdir "$LOCK"' EXIT
   ```
3. Run each suite serially, appending command, exit code and the tally line (`PASS n/n` or `FAIL n/n`) to the log. Native macOS form (no `flock`, no `timeout`, no `xvfb-run` on this host; all three were checked absent):
   ```bash
   export REPO=/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
   cd "$REPO"
   "$GODOT" --headless --path godot/                                              # harness, expect PASS 8/8
   "$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd      # slice, full
   "$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd -- --demo
   "$GODOT" --headless --path godot/ --script res://tests/input/run_all.gd
   "$GODOT" --headless --path godot/ --script res://tests/audits/run_all.gd
   "$GODOT" --headless --path godot/ --script res://tests/modes/run_all.gd
   "$GODOT" --headless --path godot/ --script res://tests/save_steam_test.gd
   "$GODOT" --headless --path godot/ --script res://tests/music_port_test.gd
   ```
   Count `SCRIPT ERROR` occurrences separately: a `PASS` line next to a `SCRIPT ERROR` is a failure.
4. Known expectations to compare against (historical, from `docs/mission/LOG.md`; differences are recorded, not "fixed"): harness 8/8; slice full 280 and demo 229 are the modes lane's numbers, with the fresh-clone caveat that a missing `godot/build/linux-x86_64/padel.pck` (gitignored) skips two checks and reads 278 / 227; input 4/4 (308 checks, 7 not-ported); rules audits 10/10 (221 checks); saves 137/137; music 32/32 claimed (the macOS sweep measured FAIL 30/32 before the provenance repair in `42aafa5`; confirm which it is at this commit and record it, do not repair it here).
5. Register the before-set: for every `godot/game/out/*.png`, record path, byte size, mtime and sha256 (`shasum -a 256`), plus `file` dimensions. Note which files carry the 2026-09-16 19:14-19:21 regeneration timestamps (menu, hud, rally, quickmatch-serve, result, arena-*) and which are the older 18:08 batch (menu-full, menu-demo, mode-*). The handoff (line 64) says the set was regenerated tonight 19:14-19:21; the register records what exists. Re-running captures is optional here and counts only with the exact command recorded (the handoff's `./run.sh shots` shape cannot run on this Mac; UIR-24 validates the native capture command).
6. Write both evidence files. If any suite is red, record the exact failing line and stop; a red baseline is a finding for Luca and the board, not something to repair inside this ticket.

## Acceptance commands (native macOS)

The eight commands in microstep 3, each with `echo "exit=$?"` after it, in one serialized session.

## Acceptance commands (Linux CI form, existing, for the host agents only)

```bash
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ --script res://tests/game_slice_test.gd
```
This is the shape `godot/game/run.sh` uses; it does not run on this Mac.

## Evidence to hand back

- `evidence/uir-00-baseline-gates.log`: one block per suite with command, exit code, tally line, `SCRIPT ERROR` count.
- `evidence/uir-00-before-set.md`: the capture register table plus the commit hash the register belongs to.

## Definition of Done

- [ ] All eight suites ran serially on this Mac; each has exit code and tally recorded.
- [ ] Any mismatch against the historical numbers is named with the failing line, not smoothed over.
- [ ] Before-set register complete for all 20 PNGs.
- [ ] `git status --short` shows only the two new evidence files plus, if newly generated, `.uid`/`.import` noise noted (never committed by this ticket).
- [ ] Hand-back message lists both file paths and the tally table.

## Failure and recovery

- Suite hangs: kill the process, record it as a hang (the harness contract says an aborted `_ready()` hangs instead of going red); retry once; a second hang is a blocker for the board.
- Red demo slice: record as measured; the handoff claims 42aafa5 fixed the demo guard, so a red demo at this commit is news. Do not edit tests to make it green.
- Pack-missing skips (278/227): record the caveat; exporting `godot/build/linux-x86_64/padel.pck` is out of scope here.

## Traces

`docs/mission/LOG.md` ticks 19/20; `docs/wayfinder/evidence/local-macos-gate-sweep.md` (environment + suite table); `godot/game/run.sh` header (one-engine-at-a-time rule, xvfb recipe); handoff `74195c4` record.
