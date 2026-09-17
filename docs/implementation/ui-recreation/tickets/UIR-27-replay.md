---
id: UIR-27
title: Replay point (buffer + overlay)
slug: replay
state: done
readiness: potential
owner_role: integration owner + screen worker pair
blocked_by: [UIR-20, UIR-22]
blocks: [UIR-25]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-27-replay.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
---

# UIR-27: Replay point (buffer + overlay)

## Worker brief (copy-paste)

> The reference lets a player rewatch the last point from pause (RIGUARDA PUNTO) and via the `r` key, with a replay overlay (top banner, exit hint, progress bar) drawn over the court (`js/main.js:1243-1324` replay loop, `:1362` `drawReplayOverlay`, key at `:2532`). The port has NO replay: `match_controller.gd` documents that `r` restarts the match instead ("there is no replay in this slice"). Build the replay for real: a bounded snapshot ring of match frames captured during play (the reference's own `replayFrames` buffer semantics), and the overlay UI. This ticket touches the integration layer (`match_controller.gd`) by its named writer and the UI by the screen worker; coordinate the write order (integration first: buffer + playback state; UI second: overlay chrome).

## Why this exists

Replay is traced by the handoff and both scouts as a reference feature that must not vanish: the pause card's RIGUARDA PUNTO button, the canvas-drawn overlay states and the `r` key binding. UIR-20 wires the button and the key to a forward-referenced entry point; this ticket is that entry point's implementation.

## Prerequisites (Definition of Ready)

- UIR-20 landed (button + key wiring to the forward reference); UIR-22 landed (pause seam + integration ownership established).

## Read allowlist

- `js/main.js:1243-1324` (stepReplay, applyReplayFrame, restoreReplayFrame), `:1362-1400` (`drawReplayOverlay` contents: banner text, exit hint, progress bar), `:2532` (`r` key), `resetReplayBuffer` (imported at `js/main.js:4`; find its module and read the buffer semantics: size, frame cadence)
- `godot/game/match_controller.gd` (frame accumulator `:645-704`, `apply_frame`, the `r` key branch `:1105-1110`, capture plan patterns for deterministic ticking)
- `js/render.js` `drawArena` context only as needed for the overlay's contrast

## Write allowlist

Integration writer (same person as UIR-22's owner, or an explicit handoff recorded on the board):

- `godot/game/match_controller.gd` (the replay buffer + state machine; keep every existing contract)
- `.uid` handled by the repo's rules

UI writer:

- `godot/src/ui/screens/ReplayOverlay.gd`, `godot/src/ui/screens/ReplayOverlay.tscn`
- `.uid` sidecars for those two files

Tests:

- `godot/tests/ui/replay_audit.gd`, `godot/tests/ui/replay_audit.tscn`
- `godot/tests/game_slice_test.gd` (only if it encodes the retired `r`-restarts behavior; amend that assertion with a citation per UIR-22's reconciliation rule, or hand back a blocker naming it)
- evidence `docs/implementation/ui-recreation/evidence/uir-27-replay.log`

No other writes. Sequence: integration lands first with a headless-testable API; UI second. UIR-22 is a blocker because `godot/game/**` has one writer at a time and UIR-22 is the phase before this one.

## Required behavior (each becomes an audit assertion)

- Buffer: frames captured during play (bounded, reference semantics; record the reference's own capacity/cadence numbers from its source). No cost when disabled beyond the reference's own.
- Playback: entering replay pauses normal simulation (existing `_paused` behavior or a replay state on top; never `SceneTree.paused`), replays the last point, restores exactly (state after replay equals state before, assert on field digests), and returns control.
- Overlay: top banner, exit hint, progress bar per `drawReplayOverlay`; exit returns to pause Match tab (ESC hierarchy step 3-4 interplay per UIR-20).
- Key `r` starts replay during play, matching the reference; the port's current `r`-restarts behavior is retired (record this as a behavior change from the port's interim state, not from the reference).
- UIR-20's button becomes enabled; its disabled-state note is removed.

## Microsteps

1. Extract the reference buffer semantics into the evidence log (capacity, cadence, what a frame holds).
2. Integration: implement capture + playback in `match_controller.gd` with a small public API (PROPOSED: `start_replay() -> bool`, `replay_active() -> bool`, `replay_progress() -> float`, signal `replay_finished`), documented in its header and handed to the UI writer.
3. UI: overlay scene reading the API; wire ESC exit.
4. `replay_audit.gd`: run a scripted point headless; assert buffer bounds, playback completes, restore-equality digest, overlay state walk, `r` key path, pause-button enablement.
5. Run; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/replay_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd ; echo "slice exit=$?"   # must stay green
```

## Definition of Done

- [ ] Replay works end to end with restore-equality proven; overlay per reference; `r` and the button both reach it; no simulation semantics change beyond the buffer.
- [ ] Slice test stays green; if it asserts anything about `r`, its amendment goes through UIR-22's reconciliation rules with a citation.
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- Restore is not exact (mutable references shared): fix the snapshot to copy the fields the simulation mutates; the digest assertion is the arbiter.
- Buffer memory: bound per the reference; record peak byte estimate in the log.

## Traces

`js/main.js:4, :1243-1324, :1362, :1602-1628, :2532`; `godot/game/match_controller.gd:1105-1110` (the current `r` behavior and its comment); scout T09 (replay acceptance); handoff (overlays/replay traceability).

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/replay_audit.gd` — **PASS 166/166**, exit 0, 0 `SCRIPT ERROR` line(s) (1.3s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/replay_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
