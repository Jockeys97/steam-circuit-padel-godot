---
id: UIR-24
title: Capture harness and UI legibility audit
slug: capture-harness
state: done
readiness: potential
owner_role: verification worker
blocked_by: [UIR-03, UIR-09]
blocks: [UIR-25]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-24-capture.log
  - docs/implementation/ui-recreation/evidence/uir-24-legibility.log
  - docs/implementation/ui-recreation/evidence/uir-pre-gate-a-legibility.log
  - docs/implementation/ui-recreation/evidence/uir-pre-gate-a-captures.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
---

# UIR-24: Capture harness and UI legibility audit

## Worker brief (copy-paste)

> Build `godot/tests/ui/capture_ui.tscn` + `capture_ui.gd` (renders one PNG per registered screen and per declared capture state into `godot/game/out/ui-<screen>[-<state>].png`) and `godot/tests/ui/ui_legibility_audit.gd/.tscn` (no Control overflows at 1280x720, 1152x648, 1920x1080, 1024x600; contrast checks on text pairs). The harness walks the router and asks each screen for `capture_states()`; it never needs edits when a screen is added (auto-discovery), which is what keeps every screen ticket collision-free. You own the harness and the `ui-*.png` namespace; nobody else writes those paths.

## Why this exists

Every screen ticket's acceptance references captures at 1280x720 and one narrow size. One harness, auto-discovering states from the screens themselves (the `ScreenContract` hooks from UIR-03), means no per-screen shared-file edits. The legibility audit is the executable form of the reference's overflow rules (the web build's layout was tuned for a 960-wide canvas and the port's probes must assert at the widths the mission already checks).

## Prerequisites (Definition of Ready)

- UIR-03 landed (router + ScreenContract capture hooks); UIR-09 landed (something mounted to walk). Later screens light up automatically.

## Read allowlist

- `godot/src/ui/ScreenRouter.gd`, `ScreenContract.gd` (capture hooks), `godot/src/ui/screens/*.gd` (`capture_states` declarations)
- `godot/game/main_menu.gd:576-600` (`_run_capture` viewport capture pattern), `godot/game/match_controller.gd:930-970` (`_run_capture` tick-based pattern, `_capture_plan:913`)
- `godot/tests/game_slice_test.gd` safe-area assertions (`:1796-1811`), `godot/game/tools/hud_probe.gd` (the probe precedent)
- `docs/wayfinder/evidence/character-material-render.md` (the xvfb/opengl capture recipe note: plain `--headless` renders blank)

## Write allowlist (you own these)

- `godot/tests/ui/capture_ui.gd`, `godot/tests/ui/capture_ui.tscn`
- `godot/tests/ui/ui_legibility_audit.gd`, `godot/tests/ui/ui_legibility_audit.tscn`
- `.uid` sidecars for the four files
- `godot/game/out/ui-*.png` (this prefix is yours; never touch `menu.png`, `hud.png`, `rally.png`, `quickmatch-serve.png`, `result.png`, `arena-*.png`, `mode-*.png`, `menu-full.png`, `menu-demo.png`, `ui-prototype-*.png`)
- `docs/implementation/ui-recreation/evidence/uir-24-capture.log`, `uir-24-legibility.log`

No other writes.

## Harness design (fixed; screens adapt to it, not the reverse)

- Entry: `res://tests/ui/capture_ui.tscn` run with `-- --capture=all` (all screens) or `-- --capture=<screen-id>` (one screen; UIR-25 uses this for spot checks). The port's existing args parser style is `_arg(args, prefix, fallback)` (`match_controller.gd:156`); follow it.
- A screen's captures are producible as soon as that screen ticket lands: the harness depends only on UIR-03 and UIR-09, never on UIR-22 or on any screen's completion. The screen ticket requests the capture run from the coordinator (engine queue) and never blocks on this ticket; this ticket never blocks on a screen.
- Walk: read the router's registered ids in order; for each screen: `go_to(id)`, wait 2 rendered frames, for each state in `capture_states()`: `apply_capture_state(state)`, wait 2 frames, capture viewport to `res://game/out/ui-<id>[-<state>].png` via the `get_viewport().get_texture().get_image().save_png()` pattern.
- Capture states named `default` produce `ui-<id>.png`; others `ui-<id>-<state>.png`.
- A screen whose `apply_capture_state` returns false for a declared state: record it in the log as a finding, continue.
- The harness prints one `ok`/`FAIL` line per capture and a `PASS n/n` summary, exit 0/1 per the port's contract.
- Rendering: run with `--rendering-driver opengl3` (run.sh's driver choice) under a real window session on this Mac, NOT `--headless` (the dummy driver captures blank PNGs). Validate the exact command on first use and record it in the log; the command in microstep 4 is PROPOSED-MAC until then.

## Microsteps

1. Write `capture_ui.gd` per the design; keep the state walk deterministic (fixed seed/tier via existing args like `--seed`, `--tier`; default 20260916/tier 3 as the mission does).
2. Write `ui_legibility_audit.gd`: for each registered screen: mount, apply each state, and assert (a) no visible Control's rect exceeds its parent/container (reuse the geometric walk from `hud_probe.gd`/slice assertions), (b) text nodes' fore/background pairs meet the reference contrast floor (compute luminance ratio; store the floor constant with its source note), (c) at 1280x720 and 1152x648 nothing overlaps where the reference forbids it (the HUD family specifically; screens are single-column flows). Run at four sizes by setting `root.size` as the slice does.
3. First run on what exists (menu + HUD + placeholders at first landing); record coverage counts; state "coverage grows as screens land" in the log.
4. On this Mac, captures run like this (PROPOSED-MAC; derived from `run.sh` minus the xvfb wrapper which does not exist on macOS; the out/ PNGs were regenerated on this Mac on 2026-09-16 19:14-19:21, which proves the mechanism):
   ```bash
   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
   cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
   "$GODOT" --rendering-driver opengl3 --path godot res://tests/ui/capture_ui.tscn -- --capture=all --seed=20260916 --tier=3
   ```
   Hold the serial lock; one engine at a time.
5. Verify PNGs: `file godot/game/out/ui-*.png` shows real dimensions; for each new PNG, check non-blank (a 5-line Python PIL/image check if PIL exists, else `file` + byte size sanity recorded).
6. Save both logs. Re-run discipline: this harness re-runs at UIR-25 for the final set.

## Acceptance commands (native macOS)

```bash
"$GODOT" --rendering-driver opengl3 --path godot res://tests/ui/capture_ui.tscn -- --capture=all --seed=20260916 --tier=3 ; echo "capture exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/ui_legibility_audit.gd ; echo "legibility exit=$?"
```

## Acceptance commands (Linux CI form, existing, host agents only)

The run.sh-shaped xvfb form, which works there:
```bash
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 1280x720x24" <linux-godot> --rendering-driver opengl3 \
  --resolution 1280x720 --path godot/ res://tests/ui/capture_ui.tscn -- --capture=all
```

## Evidence to hand back

`uir-24-capture.log` (per-screen per-state results, PNG paths, blank-check results), `uir-24-legibility.log` (exit 0, tally, list of screens covered vs pending). Hand-back notes: the exact commands used, and which states each landed screen declares.

## Definition of Done

- [ ] Harness auto-discovers states; no screen edits needed to add coverage; PNG namespace respected.
- [ ] Legibility audit runs clean on all landed screens at four sizes (pending screens reported, not failed).
- [ ] Blank-PNG check performed; every produced PNG real.
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- Blank PNGs: you are on the dummy driver; use the real-window command above.
- A screen's state walk hangs: it must apply states without frames of simulation beyond 2; fix in the harness by bounding waits and record the screen as the cause if it stalls.
- Harness needs a state the screen doesn't declare: the screen ticket owns its states; file the finding, don't widen the contract.

## Traces

S4 ticket capture sections (`docs/implementation/tickets/hud-and-menu.md:120-128`); `godot/game/run.sh` header (blank-capture warning); `docs/wayfinder/evidence/character-material-render.md`; scout UI-10; task pack requirement "capture-based acceptance at 1280x720".

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/ui_legibility_audit.gd` — **PASS 664/664**, exit 0, 0 `SCRIPT ERROR` line(s) (8.2s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/ui_legibility_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
