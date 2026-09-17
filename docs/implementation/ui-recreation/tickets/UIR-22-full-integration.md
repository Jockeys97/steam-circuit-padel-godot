---
id: UIR-22
title: Full integration (router wired, dev text removed, locale unified, display scaling)
slug: full-integration
state: done
readiness: potential
owner_role: integration owner
blocked_by: [UIR-03, UIR-07, UIR-08, UIR-09, UIR-10, UIR-11, UIR-12, UIR-13, UIR-14, UIR-15, UIR-16, UIR-17, UIR-18, UIR-19, UIR-20, UIR-21]
blocks: [UIR-25, UIR-27]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-22-integration.log
  - docs/implementation/ui-recreation/evidence/uir-22-integration-journal.md
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
---

# UIR-22: Full integration (router wired, dev text removed, locale unified, display scaling)

## Worker brief (copy-paste)

> You are the single writer of `godot/game/**` for this phase. Make the router the one navigation authority: all 13 screens mount through it, the old dynamic menu/HUD construction is retired or reduced to the legacy switch from UIR-09, the debug text is gone from every player-facing surface (`main_menu.gd:110`, `:405`, `:412`; `hud.gd:334`, `:402`; the `SEED`-strip and the 420x170 CRONACA box `hud.gd:315`), one locale drives menu and HUD (drop `HUD_LANG` at `hud.gd:62`), and `project.godot` gains a `[display]` stretch configuration so the UI scales with the window. Keep `run/main_scene="res://tests/SmokeTest.tscn"` and the existing mode contracts. This ticket also reconciles `godot/tests/game_slice_test.gd`'s menu/HUD assertions with the new construction without deleting any of them.

## Why this exists

The individual screens land as components. This ticket makes the game BE the new UI: real scene flow for all 13 screens, the language unified through `Locale`, dev text gone, and the frame scaling configured. It is also the only ticket allowed to touch `godot/game/**` and `project.godot` in this phase, which keeps the async workers collision-free.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-07/UIR-08 and UIR-10 through UIR-21 landed (all screens + overlays).
- UIR-03 and UIR-09 are direct blockers, not transitivity: the router file's only later writer is this ticket (UIR-03's freeze note), and this ticket is the second phase of the single `godot/game/**` writer after UIR-09.

## Read allowlist

- Everything the port's mission owns: `godot/game/**` current state, `godot/src/ui/**`, `godot/project.godot`, `godot/tests/**`, `docs/implementation/tickets/hud-and-menu.md` (the S4 contract this supersedes; do not edit it), `docs/implementation/tickets/quick-match-slice.md`, `docs/mission/LOG.md`
- `js/ui.js:595-607`, `js/main.js:1156, :1556, :1652, :2137-2246` (reference entry points per screen)

## Write allowlist (you own these)

- `godot/game/Main.tscn`, `godot/game/ModeScreen.tscn`, `godot/game/Match.tscn`
- `godot/game/main_menu.gd`, `godot/game/mode_screen.gd`, `godot/game/match_controller.gd`, `godot/game/hud.gd`, `godot/game/mode_hud.gd`
- `godot/project.godot` (the `[display]` block only; leave `[application] run/main_scene` untouched, leave `[input]` untouched)
- `.uid` sidecars for the files above
- `godot/tests/game_slice_test.gd` (only for the assertion reconciliation in microstep 5; every edit cited in the evidence file)
- `docs/implementation/ui-recreation/evidence/uir-22-integration.md` (landed as
  `…/uir-22-integration.log` + `…/uir-22-integration-journal.md` — the `.md` name never survived;
  the drift is closed in the journal, finalize closure 2026-09-17)

No other writes. Do NOT touch `godot/src/sim/**`, `godot/src/locale/**`, `godot/src/modes/**`, `godot/src/save/**`, the frozen web reference, or other tickets' files.

## Required outcomes

1. Router authority: `Main.tscn` hosts the router with all 13 screens registered; `go_to` is the only navigation; the legacy construction stays reachable only if UIR-09's switch documented it, and defaults to NEW everywhere.
2. Mode contracts preserved exactly:
   - quick match: `Config.pending_mode = "quick"` -> `Match.tscn` (today's `start_match:450-457`);
   - drill/tournament/career: the existing `ModeScreen`/`ModeSession` route stays the bridge to `Match.tscn`; the recreated `modes`, `drill` screens feed it the same payloads;
   - `match_controller.gd` keeps the frame accumulator (`1/120`), `apply_frame()`, `_paused` semantics, `_reset_transient_input` on both pause edges, capture args (`:144-227`), and the mode-session persistence calls.
3. Pause seam: expose the public `set_match_paused(paused: bool)` seam (NEW interface; today only `is_paused()` and the action toggle exist) that flips `_paused`, clears transient input on both edges, and refreshes the HUD; UIR-20's overlay calls it. Test: no simulation tick advances while paused; first resume frame fires no stale input (mirror the existing review-2 assertions).
4. Dev text removed from every player-facing surface: `main_menu.gd:110` subtitle, `:405` arena decimals, `:412` seed line; `hud.gd:334`/`:402` SEED strip; `hud.gd:315` CRONACA box location (the reference's log is a collapsed feed button, UIR-08's node replaces it). These files are retired or reduced accordingly.
5. `game_slice_test.gd` reconciliation: the menu fit assertions (`:542-571`) and HUD panel assertions (`:1796-1811`) must keep passing against the active construction. Update their targets if needed, keep the same properties (fit at both sizes; no panel leaves the frame; no overlap), and log every changed line with the reason. Deleting an assertion is forbidden; renegotiating a property requires a coordinator note in the evidence file.
6. Locale unification: menu and HUD resolve through the same `Locale` current language; remove `HUD_LANG` (`hud.gd:62`) and the hardcoded Italian literals in the old menu path; the new screens already route through `UiStrings`. Assert: flipping language via settings changes match HUD labels too.
7. `[display]` block: add stretch configuration so the UI scales with the window while keeping the reference's composition. Proposed (PROPOSED, verify against the running window): `window/size/viewport_width=1280`, `viewport_height=720`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, and `window/size/resizable=true`. Run the legibility audit at 1280x720, 1152x648, 1920x1080, 1024x600 after the change; the menu fit assertions must still pass (they set `root.size` themselves; verify they still measure what they intend).
8. Result/rematch flow: end-match -> `result` -> rematch -> `game`; tournament/career continue -> next fixture; quit -> `menu`. Assert the three routes exist end to end in a scripted run.

## Microsteps

1. Freeze current state: `git status`, run the full local gate list once (record tallies) before edits.
2. Wire the router into `Main.tscn`; register every screen scene; migrate menu actions to router calls; verify each action.
3. Mount the overlay stack (`PauseOverlay`, `SmashTutorial`) over `Match.tscn`; wire `set_match_paused`; run `pause_audit` + a new pause-tick assertion (add to `pause_audit.gd` if owned by UIR-20 with that ticket's sign-off note, else assert inside `game_slice_test.gd` per its reconciliation rule).
4. Remove dev text; retire the old construction paths; delete dead code only within your allowlist.
5. Reconcile `game_slice_test.gd`; run it (full + demo).
6. Add the `[display]` block; re-run the four-size legibility audit and the fit assertions.
7. Full sweep: every suite from UIR-00 + router_audit + all screen audits + pause_audit + hud_audit. Save tallies.
8. Write `evidence/uir-22-integration.md`: decisions, every assertion change with its citation, dispatch counts, and the list of known gaps, each with its owning ticket (for example replay tracked by UIR-27, OSK/touch tracked by UIR-26). Nothing on this list is a silent drop; whatever remains open at the end must also appear in UIR-25's open items.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/                                   ; echo "harness exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd           ; echo "slice exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd -- --demo ; echo "demo exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/input/run_all.gd   ; echo "input exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/audits/run_all.gd  ; echo "audits exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/modes/run_all.gd   ; echo "modes exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/save_steam_test.gd ; echo "saves exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/router_audit.gd ; echo "router exit=$?"
```

## Evidence to hand back

`evidence/uir-22-integration.md` with the before/after tallies per suite, the assertion-change log, the display-block values, and the known-gap list.

## Definition of Done

- [ ] All 13 screens navigable through the router; mode contracts preserved; pause seam live and tick-asserted.
- [ ] Dev text gone; locale unified; display block added; default scene still `SmokeTest.tscn`.
- [ ] All suites green (or every red named with cause and owner); assertion changes logged with citations.
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- A screen is not mountable (missing contract method): fix the consuming side if in your allowlist; otherwise blocker note to the owning ticket; do not fork screens.
- `[display]` change breaks headless measurements: revert to the last green config, record the measurement conflict, and raise it at UIR-25 with both configurations measured.
- Fit assertions red for the new menu at 1152x648: layout fix first (the assertion encodes the reference's own constraint); amendment only per microstep 5.

## Traces

Handoff next-steps 7-9; S4 ticket sections (ownership, tests, recovery); `godot/game/match_controller.gd:47-48, :580-704, :1080-1176`; `godot/project.godot` comments.

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/uir22_integration_audit.gd` — **PASS 71/71**, exit 0, 0 `SCRIPT ERROR` line(s) (3.6s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/uir22_integration_audit.log`
- `tests/ui/uir_route_audit.gd` — **PASS 44/44**, exit 0, 0 `SCRIPT ERROR` line(s) (4.7s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/uir_route_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
