# Training overhaul — design and execution brief

Status: implementation in progress. On 2026-09-23 the authenticated read-only local catalog returned HTTP 200 and the exact Flash route. The skill doctor's unauthenticated request returned 401; this was a check authentication problem. Router activity then confirmed successful HTTP 200 implementation requests for native agent `training_overhaul`, provider `opencode-go`, model `opencode-go/deepseek-v4.1-flash`; root activity confirmed `gpt-6-astra`. Child thread: `01a0d03a-c3b8-7a41-9185-5cc598635c92`. Work only in `/Users/alessiofantini/Documents/steam-circuit-padel-11m` on `codex/integrate-arena-11m`.

## Outcome

Turn Training from five endless score drills into a guided practice mode for the current game. A player should understand what to practise, play a bounded challenge using normal match physics and controls, receive actionable feedback after each attempt, see progress and a summary, then retry or choose another exercise with the controller.

## Evidence and boundaries

- `godot/game/mode_screen.gd` currently renders five text rows, description, saved best and Play Now; `godot/tests/ui/mode_training_screen_audit.gd` asserts controller navigation and 1280×720 fit.
- `godot/src/modes/drill_session.gd` already calls `Sim.update_match` and supports precision, smash, rally, serve and Godot-only return. Attempts are unbounded until leaving the match. Only a numeric best is persisted through `ModesSave`.
- The present simulation emits shot type, shot feedback, glass contact state, stamina, active player and team tactics. Extend observation of those events, never clone ball physics or bypass legal point outcomes.
- Keep the generated four-row reference in `ModeTables.drill_exercises()` and `src/modes/data/modes.json` untouched. Godot-specific content belongs in `drill_extras.gd`/`drill_strings.json` and is exposed through `drill_catalog()`.
- Preserve existing best-score keys and all unrelated dirty edits, particularly in `match_controller.gd`, save/audio, and concurrent arena files. Do not commit or push.

## Product contract

1. Organize the training hub around **Technique**, **Defence**, and **Match play**. Keep the existing five exercises accessible and add at least three genuinely playable challenges: back-glass recovery, net play (volley/bandeja/vibora), and doubles decision-making (switch/tactic + legal point). No menu-only placeholder exercises.
2. Every challenge shows: a one-sentence goal, success rule, what is scored, existing personal best, relevant controls, and an estimated bounded run (e.g. 8 attempts). Display contextual text rather than raw `feed`, `targets` or code identifiers. Respect Italian and English locale.
3. Each attempt must end once, from an observable simulation event or point boundary, with distinct success/failure feedback. Avoid crediting an AI action as the player's. Time out or safely fail a stalled attempt. Resets must clear per-attempt observations without losing run totals.
4. A run has a fixed attempt limit, progress HUD, and a final summary with accuracy/score and best. The player may replay, return to the exercise picker, or exit. Back/pause never silently discards an improved record; saving remains compatible with current numeric records.
5. D-pad/left stick can reach every card and action, A confirms, B returns; focus is obvious and scroll follows it. Mouse still works. The screen fits 1280×720 and scales to larger viewports.
6. Training difficulty may reuse the existing match AI profile but must not alter global match difficulty or silently award career/tournament rewards. Avoid new unlocks and economy changes in this phase.

### Integration refinements from runtime evidence

- Endless-run historical bests cannot be compared with an eight-attempt run. Preserve legacy `<exercise>` numeric keys and use new numeric `training_v1:<exercise>:<difficulty>:<attempts>` keys for comparable bounded records; no shared schema change required.
- Return success includes a controlled human return followed by a legal opponent volley, as well as a legal bounce. A seeded normal-input root probe produced a perfect human contact (quality 0.932) then an opponent volley and the old drill incorrectly reported a net failure. Use a distinct diagnosis for that valid return; depth bonuses still require measured landing. Probe: `/tmp/training-return-review.5C0Y3C/probe.gd`.
- `lastHitterSide == player` identifies a team, not necessarily a human action. New contact detection must distinguish an uncontrolled partner from the actively controlled hitter and reject stale feedback.

## Implementation phases and acceptance

### Phase 1 — Training contracts and gameplay loop

Own `src/modes/drill_extras.gd`, `drill_session.gd`, `drill_scoring.gd`, `drill_strings.json`, and focused tests. Define extra exercise rows with stable IDs and typed/validated objective metadata. Add bounded-run state and observable event tracking for the new challenges. Preserve the old four reference rows and current `return` behavior. Use engine outcomes for grading; no duplicate collision, flight, or scoring physics. Verify all exercises can start, terminate an attempt, and finish a run deterministically with a seeded simulation; negative tests must cover misses, AI-only contact, stale observations, and double close.

### Phase 2 — Presentation and navigation

Own the drill branch of `game/mode_screen.gd`, the default UI's `src/ui/screens/DrillScreen.gd/.tscn`, and their related UI tests. Both entry routes must show the improved hub and start the same run contract. Build a compact categorized selection grid and detail panel with goal, criteria, controls and best. Ensure 1280×720 fit, visible focus, D-pad/LS navigation, A/B and mouse parity, and no regressions to tournament/career. Update the existing training-screen audits to assert the new contract instead of their exact old five-row layouts. Preserve ScreenContract/router/back interfaces. The old DrillScreen difficulty selector is unwired: wire it through transient training configuration without changing global preferences, or remove the unused selector and display the actual profile; no misleading visual-only control.

### Phase 3 — In-match progress and integration

Own only drill-specific hunks in `game/match_controller.gd`, plus mode/session wiring and focused tests. Show objective/progress during the attempt and concise result feedback, then a run summary and replay/choose/exit controls. Preserve existing pause and soundtrack paths. Verify saved best compatibility, back/quit behavior, no rewards, and that the new exercises use the actual selected arena/athlete/AI.

If a phase exposes a missing observable event, establish it as a narrow read-only signal from the simulation state. Do not change shared match physics or save schema by default. Record any unavoidable shared-contract change before editing it.

## Named checks

- Direct Godot headless focused scripts: `res://tests/modes/drill_audit.gd`, `res://tests/modes/return_drill_audit.gd`, and new training challenge/session tests.
- UI: `res://tests/ui/mode_training_screen_audit.gd` and a training capture inspected at 1280×720 and a larger size.
- Integration: one playable seeded run per new challenge, including failure and success paths, controller navigation, pause/back, and best-score persistence.
- `git diff --check` plus a final scoped diff review against the initial dirty-tree baseline. Existing unrelated failures must be named, not described as a green overall suite.

## Stop conditions

Stop for a material change to match physics, save format, unlock economy, or provider/data-sharing permissions; do not improvise those changes. If route confirmation fails, keep this plan and report the blocked execution rather than silently using a different model or provider.
