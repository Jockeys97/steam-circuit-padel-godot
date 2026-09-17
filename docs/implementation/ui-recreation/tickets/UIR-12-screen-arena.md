---
id: UIR-12
title: ArenaScreen 1:1 (screen-arena, nine arenas + player mode)
slug: screen-arena
state: blocked
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07, UIR-11]
blocks: [UIR-22, UIR-23]
gates: [plan-approval, gate-a]
plan_approved: false
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-12-screen-arena.log
capture_states: [default, career-calendar, tournament-bracket, demo-locked, player-mode-coop]
---

# UIR-12: ArenaScreen 1:1 (screen-arena, nine arenas + player mode)

## Worker brief (copy-paste)

> Recreate `screen-arena` (`index.html:157-178`) as `godot/src/ui/screens/ArenaScreen.gd/.tscn`, registered as `arena`, back target `characters`. Render the arena grid from `UiData.arena_rows()` (nine in a full build), the locked/demo presentation, the career-calendar state ("in program" highlight for the fixture arena, other arenas visible but disabled with the explanatory text) and the tournament wording (bracket language instead of calendar), plus the player-mode panel (solo/co-op/local versus segmented + hint). Selecting an eligible arena starts the match through the existing quick-match contract (`Config.pending_mode = "quick"` semantics preserved; for tournament/career the existing `ModeScreen`/`ModeSession` route stays, bridged in the payload). No mode logic here.

## Why this exists

This is the last screen before the field and the only place where demo locks, career fixture locks and mode-specific wording overlap. The reference logic lives across `renderArenas` (`js/ui.js:1220`), `currentFixture:500`, `currentTournamentFixture:505`, `applyDemoLimits:737` and the player-mode block in the markup.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-07 and UIR-11 landed (characters routes here).

## Read allowlist

- `index.html:157-178` (grid container, player-mode panel, hint text)
- `styles.css`: `.arena-grid:306`, `.arena-card:323-345, :1280-1293`, `.arena-card__preview:508-522`, `.player-mode-panel`, `.setup-group__hint`, media query `:2033` (1050px one column)
- `js/ui.js:490-497` (`selectableArenas`), `:500-530` (fixture), `:737-770` (`applyDemoLimits`), `:1220-1275` (`renderArenas`)
- `js/main.js` mode selection guards (`ui.tournamentRound`, career match index) around `:1545-1583`
- i18n keys: `arenaTitle`, `arenaSub`, `playerMode`, `pmSolo`, `pmCoop`, `pmPvp`, `pmHint`, plus the renderer's arena-card and locked keys (locate; do not invent)
- `godot/game/match_config.gd` (`selectable_arenas`, `apply_cli_selection` pattern at `:212`), `godot/src/modes/career_rules.gd`, `godot/src/modes/tournament_rules.gd`, `godot/game/content_gate.gd` (`arenas`, `is_locked`)
- UIR-06 reference captures for `screen-arena`

## Write allowlist (you own these)

- `godot/src/ui/screens/ArenaScreen.gd`, `godot/src/ui/screens/ArenaScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_arena_audit.gd`, `godot/tests/ui/screen_arena_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-12-screen-arena.log`

No other writes.

## Reference behavior rules (each becomes an audit assertion)

- Full build lists all nine arenas; demo lists the same catalog with unavailable ones visibly locked, preview dimmed/desaturated (`styles.css:1280-1293`).
- Career mode: the calendar's arena is highlighted as "in program"; other arenas stay visible but disabled with the explanatory text; the career wording is calendar wording.
- Tournament: bracket wording instead of calendar wording.
- Selecting an eligible arena starts the match: quick via the preserved `Config.pending_mode = "quick"` + scene change contract; tournament/career through the existing session route (record which payload key carries the choice; do not change `ModeSession`).
- Player-mode panel: solo/co-op/local versus; options appear only where applicable (reference shows the panel on this screen; keep its visibility rules from the markup/styles; the hint text matches the selected mode).
- Arena card preview uses the correct accent and image (`js/ui.js:1220+`; accents from the card art rules).

## Microsteps

1. Field table first (arena id, name key, art path, locked flag, accent, calendar/bracket state) into the log.
2. Static tree; grid built from `UiData.arena_rows()`.
3. Lock presentation: locked class + explanatory text + disabled activation; demo run proof.
4. Career/tournament fixture states: highlight + disable non-program arenas; wording swap.
5. Player-mode seg + hint; on select, start the match through the preserved contract (wire in the payload the mode + arena + lineup so UIR-22's router honors it; until UIR-22 the quick path is `Config.pending_mode` + `change_scene_to_file("res://game/Match.tscn")`, exactly today's contract).
6. `screen_arena_audit.gd`: card count/order, lock states (full/demo/career/tournament states via constructed fixtures), disabled activation attempts, player-mode options and hints, start-path payload recorded, language flip, capture states.
7. Run full + demo; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_arena_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_arena_audit.gd -- --demo ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-12-screen-arena.log`; hand-back names: the start payload keys, the career/tournament wording keys used, the disabled-state proof lines.

## Definition of Done

- [ ] Nine-card catalog (full), demo lock presentation, career calendar + tournament bracket states, player-mode panel, correct start routing per mode, zero literals.
- [ ] No simulation or mode-rule reimplementation.
- [ ] Audits green full + demo; hand-back names commands and tallies.

## Failure and recovery

- Career fixture seam missing a field for the "in program" text: construct the label from ids you have; if a key is missing, blocker note naming it; do not write new prose.
- Quick-start contract diverges from `Config.pending_mode`: stop and record; the contract is frozen, the screen adapts.

## Traces

`index.html:157-178`, `js/ui.js:490-530, :737-770, :1220-1275`, `styles.css:306, :508-522, :1280-1293`; scout T04 acceptance list.
