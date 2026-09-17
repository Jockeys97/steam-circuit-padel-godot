---
id: UIR-20
title: Pause overlay, replay entry and smash tutorial (screen-game overlays)
slug: game-overlays
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07, UIR-08, UIR-13, UIR-19]
blocks: [UIR-22, UIR-27]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-20-overlays.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
capture_states: [pause-match, pause-controller, pause-controls, quit-confirm, smash-tutorial]
---

# UIR-20: Pause overlay, replay entry and smash tutorial (screen-game overlays)

## Worker brief (copy-paste)

> Recreate the pause overlay (`index.html:566-688`), its three tabs, the quit confirmation, and the nested smash tutorial (`index.html:642-685`) as `godot/src/ui/screens/PauseOverlay.gd/.tscn` plus `SmashTutorial.gd/.tscn`, mounted over the match by UIR-22. Wire the pause/resume calls to the match's existing pause seam (never `SceneTree.paused`), the RIGUARDA PUNTO button to the replay entry point (buffer + overlay are UIR-27), and the ESC hierarchy: close OSK, close smash tutorial, return to pause Match tab, resume match, pause match. Consume `ControlLegend` from UIR-13 and `SettingsRows` from UIR-19 read-only; you do not edit them.

## Why this exists

The pause card is the reference's second-biggest UI surface: three tabs (PARTITA with continue/replay/rematch/exit-2-step, CONTROLLER with control mode + deadzone + stick monitors + vibration + volume, COMANDI with the full legend + tutorial link), and the smash tutorial with its own back behavior. The port's pause today is a text toggle in `hud.gd` (`set_paused:494`) with match_controller's `_paused` flag and `_reset_transient_input` on both edges (`:1080-1113`). Preserve that seam; this ticket adds the visuals over it.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-08 (HUD) landed; UIR-13 (legend) and UIR-19 (settings rows) landed; UIR-05 (OSK model path) landed.

## Read allowlist

- `index.html:566-688` (pause card, tabs, panels, actions; quit button behavior comment; smash tutorial block)
- `styles.css`: `.pause-overlay`, `.pause-card`, `.pause-tabs`, `.pause-panel`, `.pause-match-status`, `.pause-actions`, `.controller-settings`, `.control-mode-toggle`, `.stick-monitor`, `.controls-guide__legend`, `.smash-tutorial*`, `.smash-steps`, `.smash-stick-guide`, `.smash-results`, `.smash-ready`, media queries `:1970` (760px), `:2003` (470px)
- `js/main.js`: pause handlers (`pauseGame:1584`, `resumeGame:1593`, `quitMatch:1602`), quit-confirm state (`quitConfirmArmed:201, :1615-1628`), pause tab switching, replay button handler, `drawReplayOverlay:1362` + replay loop `:1243-1324` (read for UIR-27's contract), smash tutorial open/close handlers, `updateStickMonitor` (~`:445-455`)
- `js/i18n.js`: `pause`, `tabMatch`, `tabController`, `commands`, `pauseInProgress`, `continue`, `replayBtn`, `rematch`, `quit`, `quitConfirm`, `controlPlayers`, `auto`, `semi`, `manual`, `deadzone`, `stickMove`, `stickAimSwitch`, `vibration`, `volume`, `xboxLayout`, `smashLbl`, `padSmashDesc`, `pauseLbl`, `padPauseDesc`, `smashTutorialEyebrow`, `smashTutorialTitle`, `smashTutorialIntro`, `smashStep1-4Title/Desc`, `smashX2/X3/Flat/BandejaTitle/Desc`, `smashReadyTitle`, `smashConditionNet/High/Charge/Timing`, `smashTutorialTry`, `smashTutorialBack`, `ariaPauseMenu`, `ariaControllerSettings`, `ariaControlMode`, `ariaStickTest`, `bandejaShort`
- `godot/game/match_controller.gd` pause seam region `:1080-1176` (read-only; UIR-22 is the writer)
- `godot/src/ui/components/ControlLegend.gd` (UIR-13), `godot/src/ui/components/SettingsRows.gd` (UIR-19), `godot/src/input/osk.gd`, `godot/src/input/menu_nav.gd` overlay API (`push_overlay:118`, `pop_overlay:123`)

## Write allowlist (you own these)

- `godot/src/ui/screens/PauseOverlay.gd`, `godot/src/ui/screens/PauseOverlay.tscn`
- `godot/src/ui/screens/SmashTutorial.gd`, `godot/src/ui/screens/SmashTutorial.tscn`
- `.uid` sidecars for the files above
- `godot/tests/ui/pause_audit.gd`, `godot/tests/ui/pause_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-20-overlays.log`

No other writes.

## The pause contract (read this twice)

- The overlay calls a match-seam method to pause/resume. Today the public surface is `match_controller.gd`'s `is_paused()` and the `padel_pause` action path; there is NO `set_match_paused(bool)` today. If UIR-22 has landed and exposes one, call it. Until then, request it from the integration owner as a one-line seam and wire the overlay to `is_paused()` + the action route for tests. NEVER set `SceneTree.paused` and never bypass `_reset_transient_input` (both edges; `js/main.js:1532,1543` semantics).
- Quit: first activation arms (`ESCI` -> `CONFERMI?` text swap, `quitConfirm` key), second activation leaves the match (menu returns via the existing route); leaving the overlay disarms. Assert both steps.
- Resume = continue button and ESC hierarchy step 4; ESC step 5 pauses. The five-step hierarchy from the scout: 1 close OSK, 2 close smash tutorial, 3 return to pause Match tab, 4 resume match, 5 pause match.
- Rematch routes to the existing rematch path; replay routes to UIR-27's entry point (until UIR-27 exists, the button must be disabled with a recorded reason visible in the log, NOT silently dead: add a disabled state and record it as the UIR-27 dependency. Do not fake a replay).

## Behavior rules (each becomes an audit assertion)

- Tabs: PARTITA active initially; CONTROLLER and COMANDI swap panels; tab state keyboard/pad navigable.
- CONTROLLER tab: control mode AUTO/SEMI/MANUALE (persist via the existing control-mode setting), deadzone row (shared `SettingsRows`), two stick monitors updating from live pad axes (visual dots; the audit asserts the binding input exists by injecting a fake axis event), vibration toggle (shared), volume row (shared). Settings and pause stay synchronized (same keys).
- COMANDI tab: full `ControlLegend` (13 rows) with the smash tutorial link row (`A+A` + chevron) opening the tutorial.
- Smash tutorial: eyebrow/title/intro; four steps; stick guide diagram labels (X2/X3 left/right + BANDEJA); four result rows; the readiness strip (four conditions); RIPRENDI E PROVA button; back/close returns to the CONTROLS tab without closing pause (assert the pause remains open).
- Stick monitor movement math mirrors the reference offsets (17px range, `updateStickMonitor`); reproduce proportionally in Control space and note any scale conversion.

## Microsteps

1. Row/state table first (tabs, actions, tutorial parts, keys).
2. `PauseOverlay.tscn` static tree; tabs; panels; consume shared components.
3. Wire pause/resume/quit-2-step/rematch; replay button to the UIR-27 seam name (documented as a forward reference) with the disabled-until-landed behavior.
4. `SmashTutorial.tscn` + show/hide + ESC ordering.
5. `pause_audit.gd`: tab switching; quit 2-step; ESC hierarchy (five steps, simulating OSK open and tutorial open states); legend/tutorial wiring; controller rows sync with settings values; stick monitor binding; capture states; language flip.
6. Run; save log. Note in the hand-back exactly what UIR-22 must call to mount/show this overlay.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/pause_audit.gd ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-20-overlays.log`; hand-back names: the pause seam used (with the exact call UIR-22 must preserve), the replay forward-reference, the ESC hierarchy proof lines.

## Definition of Done

- [ ] Overlay + tutorial render per reference; the five-step ESC hierarchy asserted; quit 2-step asserted; shared components consumed without edits; zero literals; audit green.
- [ ] No `SceneTree.paused` anywhere in this ticket's files (grep-assert in the audit).
- [ ] Replay button disabled with the UIR-27 dependency recorded (or wired if UIR-27 landed).
- [ ] Hand-back names command and tally.

## Failure and recovery

- No pause seam reachable from the overlay: the integration owner adds one line; do not work around by freezing the tree.
- Stick monitor test needs a pad: inject `InputEventJoypadMotion` in the audit; record that real-hardware behavior was not checked on this Mac.

## Traces

`index.html:566-688`, `js/main.js:1584-1628, :1243-1362`, `godot/game/match_controller.gd:1080-1176, :494`, `styles.css` pause block + `:1970, :2003`; scout T09 acceptance (states half).

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/pause_audit.gd` — **PASS 176/176**, exit 0, 0 `SCRIPT ERROR` line(s) (0.6s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/pause_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
