---
id: UIR-08
title: In-match HUD 1:1 (screen-game HUD core)
slug: screen-game-hud
state: blocked
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-06]
blocks: [UIR-09, UIR-20, UIR-21, UIR-22]
gates: [plan-approval]
plan_approved: false
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-08-hud-audit.log
capture_states: [default, serving, rally, point-pause, set-tennis, drill, tournament, career, panel-open]
---

# UIR-08: In-match HUD 1:1 (screen-game HUD core)

## Worker brief (copy-paste)

> Recreate the persistent part of `screen-game` (`index.html:445-473` plus the meter stack at `:498-535`) as `godot/src/ui/Hud.gd` and `godot/src/ui/Hud.tscn`, drawn in screen space over the port's live 3D court. Values come from the real match state through a small view-model, never from duplicated logic. Implement: scoreboard (title, names, scores, VS, match info, active-player label, team tactic, combo), the game-timer box, panel/mute/controller-indicator/pause buttons, the serve banner, the mini-map panel, the special and shot meters, the immersive match-panel toggle, and the event log (collapsed by default). The action deck and touch controls are NOT built here: on the reference's own desktop presentation (`pointer: fine`) they are hidden, and the coarse-pointer layer belongs to UIR-26. Pause overlay, replay and the smash tutorial are UIR-20. This HUD is the second half of what GATE-A shows Luca.

## Why this exists

The current HUD (`godot/game/hud.gd`) is per-node hardcoded colors, a fixed 420x170 "CRONACA" box parked over the court's bottom-left corner (`:315`), and a permanent `SEED · TIER · TICK · RNG` developer strip (`:334`, filled at `:402`). The recreation replaces it with the reference's HUD language over the same live state.

## Prerequisites (Definition of Ready)

- UIR-02/03/04/05/06 landed. S2 quick-match seam available: `godot/game/match_controller.gd` publishes runner state through the existing `HudScript`/`ModeHudScript` call pattern (`_build_scene()` + per-frame updates; verified `hud.gd:379-412` `refresh(state, meta)` is the current consumer surface).

## Read allowlist

- `index.html:445-536` (whole `screen-game` markup)
- `styles.css`: `#screen-game:523-532`, `.scoreboard:553-678`, `.hud-pause:699-729`, `.game-timer`, `.special-meter`, `.shot-meter`, `.mini-map`, `.canvas-wrap`, `.match-panel`, `.match-feed`, `.event-log:1059-1072`, `.serve-banner`, `.action-deck:807-844` (read, not built), `.touch-controls:1081-1099` (read, not built), media queries `:2058, :2064, :2070`
- `js/ui.js:1276-1373` (`updateHud`, the element-by-element reference)
- `godot/game/hud.gd` (current consumer surface; read-only here; UIR-22 retires it)
- `godot/game/match_controller.gd` `apply_frame()` region and `refresh`/`bind_names` usage (read-only)
- `godot/game/mode_hud.gd` (mode overlay split; read-only)
- `GAMEPLAY_RULES.md:142-150` (player feedback contract)

## Write allowlist (you own these)

- `godot/src/ui/Hud.gd`, `godot/src/ui/Hud.tscn`
- `godot/src/ui/ViewState.gd` (new; the small view-model that maps runner state + meta to HUD fields; if you prefer, name it `HudView.gd`; keep one file)
- `.uid` sidecars for the files above
- `godot/tests/ui/hud_audit.gd`, `godot/tests/ui/hud_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-08-hud-audit.log`

No other writes. Do not edit `godot/game/**` (UIR-09/UIR-22 mount this HUD); do not edit `mode_hud.gd`.

## Required HUD content and states (each is an audit assertion)

Scoreboard (`.scoreboard`, `index.html:447-460`):
- `SCORE` title (`score` key); team row: `you` label + `playerScore`, `VS`, `opponent` label + `aiScore`;
- names resolve from athlete/ai ids exactly as `updateHud` does (`json: js/ui.js:1279-1283`: last word of the athlete name; opponent from `ai_<id>_name` or the pvp opponent athlete);
- `matchInfo` from the current mode (e.g. "Partita Rapida");
- active-player label (`activePlayerLabel`) covering the five reference branches (`js/ui.js:1288-1299`): receiving-serve (with side), manual switch flash, auto-switch flash (with `is-auto-switch` styling), receiver lock, normal control/manual labels; plus the role (back/net) from `roleBack`/`roleNet`;
- team tactic label (`teamTacticLabel`): `tacticHud_*` text, movement states split-step/sprint override (uppercased), flashing state on `tacticFlash`;
- combo (`combo`, `{n}`), with the reference's color ladder (`js/ui.js:1333-1335`) and glow at combo >= 4.

Timer (`.game-timer`): `gameTime` label + `MM:SS` formatting of elapsed time (`js/ui.js:1337-1339`).

Buttons: panel toggle (▤, `ariaTogglePanel`/`togglePanel`, pressed state), mute (🔊/🔇, `ariaMute`/`muteOn`, pressed state), controller indicator (🎮, visible only while a pad is connected), pause (Ⅱ, `ariaPause`/`pauseLbl`) which calls the match pause seam (rendered here; the overlay itself is UIR-20).

Serve banner (`#serveBanner`, `js/ui.js:1358-1366`): visible while serving or between points; between points shows `state.pointMessage` with the `serve-banner--point` style; serving shows `serveFirst` / `serveSecond` (by attempts) / `serveOpp` by side.

Special meter (`.special-meter`): `ability` label; fill width = `specialReady` percent; opacity 0.45 while `specialCooldown > 0`.

Shot meter (`.shot-meter`, `js/ui.js:1342-1357`): intent label from the eight-value map (drive, slice, lob, defensive-lob, chiquita, vibora, smash, auto→`shot`), advice label from `shotRead.advice` + `shotAdvice_*`, power fill = `shotCharge`, aim needle = `50 + shotAim * 42`, timing needle/perfect window from `shotRead` (position formula and width clamp exactly as the reference: `52 - eta*72` clamped, width `max(5, min(17, perfectWindow * 155))`).

Mini-map (`.mini-map`): `map` label + court sketch; the reference draws into `#miniMap` (108x154 canvas, `aria-hidden`); the port draws the same footprint from live positions.

Event log (`.match-feed`): toggle button (☰ + `chronicle`) with expanded/collapsed state; list refreshed from ordered state events; collapsed by default, matching the reference (`aria-expanded="false"` initially, list `hidden`).

Immersive panel: default state hides the lower `.match-panel` content row (immersive, canvas fills); panel toggle reveals the control rows and meters; expose the state for capture.

Mode variants: drill shows the four metric boxes (`Punti`, `Record`, `Precisione`, `Streak` per `drillMetrics`); tournament/career show their objective blocks via the existing `mode_hud.gd` data. This HUD provides the styled surface; the data for mode blocks may keep flowing through the mode session view-model until UIR-22 merges (`mode_hud.gd` stays functional in the interim).

## Interface (all new)

- `Hud.gd` extends Control (CanvasLayer child when mounted). Public: `refresh(state, meta: Dictionary) -> void`, `bind_names(player_name, ai_name, player_colors...) -> void`, `set_paused(bool) -> void`, `set_panel_open(bool) -> void`, `set_muted(bool) -> void`, `set_pad_connected(bool) -> void`, `apply_safe_area(frame: Vector2) -> void`, `panels() -> Array[Control]`, `capture_states()`/`apply_capture_state()` (harness contract).
- `ViewState.gd`: `static func from_state(state, meta) -> Dictionary` returning exactly the HUD's fields (one place that knows the runner's field names).

## Microsteps (do in order)

1. Read `js/ui.js:1276-1373` line by line; write the field list into the evidence log as a checklist.
2. Write `ViewState.gd`; unit-assert it inside `hud_audit.gd` against a scripted match state (the port already has scripted-input infrastructure in `godot/game/scripted_player.gd` and the slice test; drive a short rally through `apply_frame`).
3. Build `Hud.tscn` with theme variations from UIR-02; no literal colors, no literal strings.
4. Implement state updates; the five active-player branches, serve banner states, tactic/sprint, and combo ladder are the fiddly ones; assert each.
5. `apply_safe_area`: keep the no-overflow/no-overlap guarantees the current layout holds (`godot/tests/game_slice_test.gd:1796-1811` asserts "no HUD panel leaves the frame at 1280x720 or 1152x648" and "no two HUD panels overlap"): the new HUD must keep those true at the same two sizes, or UIR-22 amends the assertion with the coordinator's sign-off. Your audit asserting the same two properties on the new HUD is required either way.
6. Write `hud_audit.gd`: scripted rally default run + assertions per the state list above; also assert `capture_states()` includes the nine listed states and each returns true.
7. Run headless; save log; hand back.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/hud_audit.gd ; echo "exit=$?"
```

Captures come from UIR-24/UIR-09 (`--capture` path). Do not add capture args to the HUD ticket.

## Evidence to hand back

- `evidence/uir-08-hud-audit.log`: exit 0, tally, plus the field checklist from microstep 1 with resolved values.
- Hand-back message: state list implemented, which assertions run against a real scripted rally vs a constructed state (name them; constructed states are allowed but must be labeled).

## Definition of Done

- [ ] All listed HUD elements render with values from `ViewState` over a real scripted rally.
- [ ] Serve banner, active-player branches, tactic/sprint, combo ladder, both meters, log collapsed default, panel toggle, mute, controller indicator, timer format all asserted.
- [ ] Safe-area properties hold at 1280x720 and 1152x648.
- [ ] Zero literals; zero per-node colors outside the theme.
- [ ] Action deck and touch controls absent in desktop presentation, with the reason recorded in the evidence file.
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- A runner field is missing (for example `shotRead.perfectWindow`): read `state.shotRead` presence-checked, record the gap as a blocker note naming the field, use the reference's default constant where one exists (`0.055` for the perfect window). Do not recompute simulation values in the view.
- Overlap at 1152x648: adjust layout; if impossible without shrinking type below the reference's floor, record the constraint and raise it at GATE-A rather than shipping silently.

## Traces

`index.html:445-536`, `js/ui.js:1276-1373`, `styles.css:523-729, 1059-1072`, current defects `godot/game/hud.gd:315, :334, :402`; handoff diagnosis item 3; scout T09 acceptance (HUD half); GATE-A readiness.
