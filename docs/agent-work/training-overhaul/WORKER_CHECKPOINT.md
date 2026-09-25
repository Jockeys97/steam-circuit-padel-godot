# Training overhaul — worker checkpoint

Task: `/root/training_overhaul` (root/Astra owns PLAN.md, scope, acceptance).
Workspace: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`, branch
`codex/integrate-arena-11m`, HEAD `d29fd4bbc95a01c48950d38f6dfe219eb34fd1b8`.
Baseline snapshot of every file I touch (pre-touch contents + git status + git diff):
`/tmp/training-overhaul-baseline.sKaAPq/` (path also in
`/tmp/training-overhaul-baseline-path.txt`). No secrets in it.

## Landed

- `godot/src/modes/drill_extras.gd`: three new stable rows — `glass_recovery`
  (`formation: deep`), `net_play` (`formation: net`), `doubles_tactics` — each carrying
  `objective`; the frozen four-row document is untouched. Catalog is 8.
- `godot/src/modes/drill_objective.gd` (new): group (technique / defence / match play),
  goal / success / scores / watch ids, control keys, run length (default 8, max 24),
  `mismatches()` + `well_formed()`.
- `godot/src/modes/drill_hub.gd` (new): the shared hub model both UI routes read —
  `groups()`, `cards()`, `detail(id, store, difficulty, lang)` with the bounded best, the
  historical best, controls and run length, plus the difficulty list and `ai_profile()`
  (delegates to `CareerRules.ai_for_match("quick", diff)`; writes no preference).
- `godot/src/modes/drill_session.gd`: bounded run (`run_limit`, `run_done`, `summary`
  phase, `restart_run()`), per-attempt observation reset, `ATTEMPT_TIMEOUT` fail, and every
  objective branch re-graded on a FRESH human contact plus the engine's own marks
  (`ball.bounces`, `ball.postGlassSide`, `crossedNet`, `stats.pointsWon`,
  `playerTeamTactic`) — which also removes the old credit for the AI feed's own landing in
  the target exercise.
- `godot/src/modes/modes_save.gd`: `training_key` / `training_best` /
  `save_training_score` / `training_record_after` / `load_training_records` for the bounded
  `training_v1:<id>:<difficulty>:<attempts>` records. Legacy API unchanged.
- `godot/src/modes/drill_strings.json`: 80 ids x {it,en}, symmetric.
- `godot/game/mode_session.gd`: training difficulty resolved from the hub seam, bounded
  record read at start and written on a finished run (`persist_training_record`), no career
  reward / history / outfit path, and a drill HUD model with resolved objective, progress,
  last result, summary and actions.
- `godot/game/match_config.gd`: `pending_drill_difficulty` + `pending_training_return`
  transient seams (no save write).

## Evidence so far

| command | exit | result |
|---|---|---|
| `--check-only` on the 8 touched scripts | 0 | clean |
| `tests/modes/drill_audit.gd` | 0 | PASS 76/76 (`godot/out/training-logs/drill_audit.log`) |
| `tests/modes/return_drill_audit.gd` | 1 | FAIL 76/79, see below |

`return_drill_audit.gd` failures, classified:

1. `the_generated_document_is_untouched` — PRE-EXISTING: the audit hardcodes
   `b3f346f6…` while the generated document and `js/drill.js` both hash `010e6fae…`.
   Nothing in this task touched `modes.json`.
2. `the_catalog_offers_five_exercises` (5 vs 8) — expected from this task; the audit
   update is part of the pending work.
3. `at_least_one_seed_graded_a_real_return_as_success` — PRE-EXISTING under the concurrent
   sim edits: a pristine `git archive HEAD` tree in `/tmp/training-baseline-tree.Rmi6sH`
   with only the dirty `godot/src/sim/sim.gd` + `state.gd` copied in reproduces
   `0 of 3` with this task's files absent. The scripted fixture aims deep and charges, and
   under the concurrent human lob/error curves the ball now goes over the baseline in the
   air (engine point `msgWallNoBounce`, `ball.bounces` stays `{0,0}`), so the drill has no
   landing to grade. Sixteen seeds x six `aimY` values produced zero legal scripted returns.

## Shared hub, both routes (landed)

- `godot/src/ui/training/DrillHubView.gd` (new): ONE body for both routes — three families,
  compact cards, a detail panel (goal, success rule, what scores, controls, BOTH records, run
  length), the difficulty row and the start action. It emits `exercise_selected`,
  `start_requested`, `back_requested`, `difficulty_changed` and exposes `focus_rows()` so each
  host keeps its own focus model. It extends `MarginContainer` on purpose: a plain `Control`
  does not lay its children out and the detail column collapsed to its minimum rectangle.
  The active segment's theme shadow is zeroed per control (`BoxSegmentedActive.shadow_size = 16`
  is part of the stylebox's minimum size, so selecting a card used to re-measure the column).
- `godot/src/ui/screens/DrillScreen.gd`: rebuilt as the hub host — `ScreenShell` + the shared
  view + the reference's per-exercise hint, with `screen_id/back_target/enter/exit/
  capture_states/apply_capture_state`, the exercise/difficulty/record accessors and
  `start(dry_run)` preserved. `start()` now ALSO writes `Config.pending_drill_difficulty` and
  `Config.pending_training_return`, which is what makes the difficulty row real.
- `godot/game/mode_screen.gd`: the drill branch mounts the same view and keeps the preview
  `DrillSession`, `screen_report()`'s shape (`drill_phase`, `drill_target`), the `drill:<id>`
  focus actions and the `PLAY NOW` route.
- Rendered evidence: `godot/game/out/ui-drill.png`, `ui-drill-hard.png`, `ui-drill-legend.png`
  (router/hub, 1280x720, `capture_ui` PASS 5/5) and `godot/game/out/mode-drill-screen.png`
  (ported route, 1280x720) — both show the eight exercises in Technique / Defence / Match
  play, the detail panel and the difficulty row.

## Training HUD, records and the finished run (landed)

- `godot/src/modes/modes_save.gd`: bounded records under
  `training_v1:<id>:<difficulty>:<attempts>` (same improvement-only door, no schema change),
  with the legacy `<id>` record kept and shown as "Historical best". `game_slice_test.gd`'s
  legacy `drill_best`/`persisted_best` assertions still depend on the legacy write, so
  `_finish_drill` keeps writing it AND the bounded key; the hub and the summary compare the
  bounded one.
- `godot/game/mode_session.gd`: the run's AI comes from the chosen training difficulty
  (`DrillHub.ai_profile` -> `CareerRules.ai_for_match("quick", …)`); the HUD model carries the
  objective line, progress, score against the bounded record, the last verdict in words, the
  summary and the three actions — no ids, coordinates or field names reach the screen.
- `godot/game/mode_hud.gd`: the summary's three actions are real Buttons (mouse) that emit
  `training_retry_requested` / `training_choose_requested` / `training_exit_requested`.
- `godot/game/match_controller.gd`: a finished run parks in `summary`, persists once, and
  accepts A (retry) / B (choose exercise) only once a quiet tick plus `TRAINING_SUMMARY_GRACE`
  has passed, so the shot that ended the run cannot press Retry by itself. Nothing in this
  path touches the generic end-of-match rewards, the result screen or the economy.
- Controls: the objective table advertises only the reference's own legend triples, corrected
  to the port's real mapping — LS moves AND aims (`input_map.gd:245`), RS is only the
  directional switch (`:235`), and RT is NOT labelled sprint (it feeds the shot's precision,
  `sim.gd:2930/3022`, and zeroes `paddle.sprinting`, `:3055`), so no exercise lists it.

## Pending

The new-exercise runtime audit (`tests/modes/drill_training_challenge_audit.gd`: seeded
stepping for glass_recovery / net_play / doubles_tactics, success+failure+completion, no
double count, no rewards), the two UI audits (`screen_drill_audit.gd`,
`mode_training_screen_audit.gd`) updated to the hub contract, the summary capture, and
`git diff --check`. `godot/tests/modes/_probe_return_seeds.gd` is a throwaway probe and is
removed before handoff.
