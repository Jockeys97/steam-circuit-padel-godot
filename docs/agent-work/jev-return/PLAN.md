# Jev serve-return training — implementation contract

## Objective

Turn the currently truthful but unhelpful `uncertain` result for matches dominated by
opponent aces into a measured, actionable path: Jev may select a new `serve_return`
focus and open a real `return` training exercise in the Godot 3D build.

## User-visible contract

- The coach may offer `serve_return` only from measured match counters. Opponent aces
  are direct evidence that serves were not returned; the copy may quote that count and
  recommend training the return, but must not claim an unmeasured cause such as poor
  positioning, timing, reaction, or technique.
- A confident `serve_return` answer links to a fifth drill named `Risposta` / `Return`.
- The drill starts each attempt with a legal opponent serve toward the human side. An
  attempt succeeds only when the human side makes a legal return that crosses into the
  opponent half; quality may reward a controlled/deep return using values already
  measured by the simulation. A missed return, ace, net/out response, or point ending
  before a valid return is a failed attempt.
- The drill is selectable from the existing training screen, saves its own best score,
  works with keyboard/pad focus, and is reachable from the result coach without mutating
  pending career/tournament state.
- Italian and English UI copy must resolve without raw localization ids.

## Architecture and boundaries

- Preserve the coach trust boundary: the model chooses only among declared categories;
  code owns advice wording, quoted numbers, and drill id.
- Extend the single coach contract rather than adding a parallel category list. Keep
  `insufficient_data`, the confidence gate, request lifecycle, retry policy, local bridge
  security, and disclosure unchanged.
- Prefer direct evidence already present (`aces.ai`) for coach eligibility. Do not invent
  historical counters or infer court position. Add match telemetry only if the drill or
  a truthful displayed sentence genuinely requires it.
- Extend the existing drill session/table/screen conventions. Do not rewrite unrelated
  gameplay, AI, menus, save schema, or the in-progress UI styling work.
- The repository is dirty and shared. Preserve all pre-existing edits, especially in
  `sim.gd`, `DrillScreen.gd`, `ResultScreen.gd`, generated assets, and other agent work.
- No commit, staging, push, deployment, paid TypeSafe call, secret access, or process
  management.

## Acceptance criteria

1. Contract, snapshot support, bridge validation, advice mapping, and both locale tables
   recognize `serve_return`; a fixture with enough points/rallies and a high opponent-ace
   count offers it, while zero/too-few opponent aces do not.
2. A high-confidence valid answer renders measured wording that quotes opponent aces and
   links to drill id `return`; low confidence and invalid answers remain advice-free.
3. The training screen lists five usable exercises and `return` starts an opponent serve,
   grades a valid human return as success, grades a non-return as failure, exposes useful
   metrics, and persists a record independently.
4. The result screen route selects `return`; pending-continuation protection remains.
5. Layout remains usable at the existing 1280x720 evidence size; five exercise selectors
   must not clip or overflow.
6. Focused coach, bridge, drill, save, screen-drill, result-coach, and route tests pass.
   Existing unrelated red baselines must be reported, not hidden or “fixed”.

## Verification target

- `node scripts/coach/jev_bridge_test.mjs`
- `node scripts/coach/jev_bridge_integration_test.mjs`
- Godot headless: `tests/coach_test.gd`, `tests/coach_client_test.gd`,
  `tests/modes/drill_audit.gd`, `tests/ui/screen_drill_audit.gd`,
  `tests/ui/result_coach_audit.gd`, plus any new focused return-drill test.
- A rendered training-screen or focused probe at 1280x720 showing all five selectors and
  the selected Return exercise.

## Non-goals

- Diagnosing why a return failed, measuring player position, adapting difficulty from
  history, changing the confidence gate, deploying the bridge, or altering the 2D game.
