# Jev serve-return training — implementation and acceptance

Status: accepted in the current shared worktree. Nothing was committed, staged, pushed,
deployed, or sent to the live TypeSafe service.

## What changed

- The coach contract now declares `serve_return`. It is eligible only when the measured
  opponent-ace count reaches the explicit conservative floor of three. The advice quotes
  that count and names no unmeasured cause.
- `coach_advice.gd` maps the category to the real drill id `return`; Italian and English
  coach copy resolve `coachAdviceReturn`.
- The Godot build has a fifth training exercise, `return`, added through
  `drill_extras.gd` instead of altering the generated four-row browser-reference table.
  `ModeTables.drill_catalog()` is the player-facing union; `drill_exercises()` remains the
  frozen reference for its drift audits.
- The opponent serves through the existing simulation. A legal human return that clears
  the net and bounces inside the opponent court succeeds; a non-return, net response, or
  out response fails. Metrics reuse the existing score/best/in/streak labels and the save
  layer stores an independent `return` record.
- The training screen lists five exercises, resolves the Godot-only strings from
  `drill_strings.json`, and accepts the same result-screen route as the original four.
  Pending career/tournament state remains protected by the existing coach route policy.

Primary feature files:

- `godot/src/coach/coach_contract.json`
- `godot/src/coach/coach_stats.gd`
- `godot/src/coach/coach_advice.gd`
- `godot/src/coach/coach_strings.json`
- `godot/src/modes/drill_extras.gd`
- `godot/src/modes/drill_strings.json`
- `godot/src/modes/drill_text.gd`
- `godot/src/modes/mode_tables.gd`
- `godot/src/modes/drill_session.gd`
- `godot/src/modes/drill_scoring.gd`
- `godot/src/modes/drill_target.gd`
- `godot/src/ui/screens/DrillScreen.gd`
- `godot/src/ui/coach/CoachPanel.gd`
- `godot/src/ui/screens/ResultScreen.gd`
- focused coach, drill, screen, route, and bridge tests under `godot/tests/**` and
  `scripts/coach/jev_bridge_test.mjs`

The repository was actively shared during implementation. Unrelated current edits in
gameplay, arenas, menus, localization sources, JS, assets, and other agent-work folders
were preserved and are not attributed to this ticket.

## Acceptance evidence

All commands below were run from
`/Users/alessiofantini/Documents/steam-circuit-padel-11m` on
`codex/integrate-arena-11m` with Godot 4.7.2.

| Check | Exit | Result |
| --- | ---: | --- |
| `node scripts/coach/jev_bridge_test.mjs` | 0 | `PASS 124/124` |
| `node scripts/coach/jev_bridge_integration_test.mjs` | 0 | `PASS 27/27` |
| `godot --headless --script res://tests/coach_test.gd` | 0 | `PASS 165/165` |
| `godot --headless --script res://tests/coach_client_test.gd` | 0 | `PASS 79/79` |
| `godot --headless --script res://tests/modes/return_drill_audit.gd` | 0 | `PASS 83/83`; real opponent serve, live success/non-return, explicit net/out failures, records and deterministic reset |
| `godot --headless --script res://tests/modes/drill_audit.gd` | 0 | `PASS 76/76`; original four drills unchanged |
| `godot --headless --script res://tests/ui/screen_drill_audit.gd` | 0 | `PASS 120/120` |
| `godot --headless --script res://tests/ui/result_coach_audit.gd` | 0 | `PASS 120/120`; `serve_return -> return` route |
| `godot --headless --script res://tests/ui/uir_route_audit.gd` | 0 | `PASS 51/51` |
| 1280x720 drill capture (`--capture=drill`) | 0 | `PASS 10/10`; no refused or blank state |

Visual evidence: `godot/game/out/ui-drill-return.png` (1280x720). Direct inspection shows
all five exercise selectors on one row, `Return` selected, and no clipping or overflow.

## Limits

- The coach still decides conservatively: making `serve_return` eligible does not force
  TypeSafe to select it or bypass the 0.5 confidence gate.
- The recommendation is supported by opponent aces only. The game still does not measure
  the cause of a missed return or the player's starting position, so the coach does not
  claim either.
- The bridge remains loopback-only development infrastructure. No live TypeSafe request
  was made during this work.
