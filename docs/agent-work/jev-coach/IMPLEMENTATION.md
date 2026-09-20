# Jev post-match coach — implementation report

**STATUS: ready_for_review** (no commits, no pushes, no deploys, no paid API calls)

- Task: `jev_coach` — implement `PLAN.md` (this directory) in the
  `steam-circuit-padel-11m` checkout, branch `codex/integrate-arena-11m`.
- Workspace: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`.
- Baseline of the files I touched (outside the repository):
  `/Users/alessiofantini/Documents/steam-circuit-padel-11m.baseline-jev-coach/`
  — `git-status.txt`, `head.txt`, and `ResultScreen.gd`, `ResultScreen.tscn`,
  `DrillScreen.gd`, `ScreenRouter.gd`, `mode_tables.gd` as they were before my edits.
- `PLAN.md` was not modified. This file is the report.

## What was built

| Path | What it is |
| --- | --- |
| `godot/src/coach/coach_contract.json` | The one contract both sides read: wire version/path/bounds, the counter allowlist, sufficiency floors, the provisional gate, the fixed TypeSafe endpoint/model, and the Choice question's id, instructions and criteria. |
| `godot/src/coach/coach_strings.json` | The coach's player-facing strings, Italian first with an English table, plus the advice and evidence templates. |
| `godot/src/coach/coach_contract.gd` | Loads and reports the contract; fails loudly (empty + `push_error`) when it cannot. |
| `godot/src/coach/coach_stats.gd` | The snapshot: allowlisted counters from the result payload, bounded and normalized, the two documented derived readings, and the "is there enough, and which categories have their own evidence" verdict. |
| `godot/src/coach/coach_advice.gd` | Validates the bridge's answer (type, offered category, finite confidence, a real distribution), applies the gate, and owns the advice sentence, the numbers it quotes and the existing drill it links. |
| `godot/src/coach/coach_text.gd` | Resolves the coach's own ids with the port's chain: requested locale, then `it`, then the id itself. |
| `godot/src/coach/coach_client.gd` | The only door to the bridge: one request at a time, a bounded timeout, a generation token so a stale reply cannot paint, and a test seam (`set_poster`) that is not a second transport. |
| `godot/src/ui/coach/CoachPanel.gd` | The result screen's coach block: disclosure, analyze button, and the states it can be in. Literal-free (the UI lane's own scan reads it). |
| `godot/src/ui/screens/ResultScreen.gd` | Additive only: mounts the block under the card's own content, registers its two controls with the shell's focus model, renders it on every `render()`, cancels it on `exit()`, and owns the one route. |
| `scripts/coach/jev_bridge.mjs` | The loopback bridge (Node stdlib): owns `TYPESAFE_API_KEY`, validates the wire field by field, refuses browser requests, calls the fixed endpoint once, returns a bounded answer. |
| `scripts/coach/jev_bridge_test.mjs` | Its contract test: 103 checks against loopback fake upstreams. No key, no charge. |
| `scripts/coach/jev_bridge_integration_test.mjs` | The end-to-end test: the real Godot client, the real `createBridge`, a fake upstream — fail/retry/advice, the visible path, and an unreachable upstream. |
| `scripts/coach/README.md` | Start/test commands and the boundary, in short. |
| `godot/tests/coach_test.gd` | 124 checks: contract, sentences, snapshot refusals, support rules, advice mapping, answer validation, and a match the simulation itself stepped. |
| `godot/tests/coach_client_test.gd` | 74 checks: address, request body, one-at-a-time, stale replies, every transport outcome, and the engine's real `HTTPRequest` against a loopback stub. |
| `godot/tests/ui/result_coach_audit.gd` | 81 checks: the block on the real screen in the real router — nothing on its own, the press, the advice, the route, the continuation rule, the weak states, the exit, the language flip. |
| `godot/tests/ui/_probe_coach.gd` | The visual probe that draws the block (idle / advice / pending) into `evidence/`. Not an audit. |
| `godot/tests/coach_integration_probe.gd` | The Godot half of the integration test: `client`, `ui` and `offline` modes, driven by the Node test above. |

### The contracts, as implemented

- **No invented telemetry.** The snapshot copies exactly the counters the ported simulation
  writes (`godot/src/sim/sim.gd:1972-1987`) and the result screen already renders. Shot
  placement, court position and error causes are not measured, have no name in the
  contract, and cannot reach the bridge.
- **A missing counter is not a measured zero.** Every declared group, side and counter must
  be present and well-shaped; an absent or malformed one is a `blocker` and the block
  refuses to advise (`coach_stats.gd::_count`). An unknown extra counter is recorded and
  ignored, so a future build that measures more does not silence the coach.
- **The player's numbers are the side's.** `player` is the aggregate of both humans on that
  side; `rallyCount`/`totalRallyHits`/`longestRally` count the WHOLE match. The criteria and
  the evidence line say which is which ("Your side: … The match: …"), and the model's state
  carries both notes.
- **No cause is claimed.** The criteria and every sentence are measurement-framed: no
  "unforced", no missed chance, no court position, no serve "costing" points, and
  `smashWinners` is never added to `winners` (a smash winner and a winner are separate
  measured endings — `sim.gd:2406-2413`). The coach test fails if any of those words
  reappear in a table or a criterion.
- **The model picks a category; code owns everything else.** The bridge assembles the
  model-facing `state` and the question from the contract, so no client text reaches
  upstream; the sentence, the numbers and the drill id come from `coach_advice.gd`.
- **The gate.** TypeSafe's own Choice confidence, compared against the contract's
  provisional `0.5`: under it the block shows the match's numbers and no recommendation.
- **The offer.** A category is only offered when its own measured evidence exists, and a
  call needs at least `minCandidates` DRILLABLE categories (the contract's number, counted
  exactly as its note says) beside `insufficient_data`; one drillable option alone is
  refused and the call is not made at all.
- **An answer must be internally consistent.** The chosen category has to be one that was
  offered, the distribution has to be a distribution over exactly those categories, and the
  chosen category has to be at the peak of it (a tie is a peak). Both sides check this: the
  bridge refuses such an answer with `upstream_invalid`, and `coach_advice.gd` refuses it
  again before anything is shown.
- **Lifecycle.** No request on render, on a capture state or on a language flip; one request
  at a time; the screen's `exit()` cancels and a late reply is dropped. A reading — advice,
  an uncertain reading, or a measured refusal — is reused for the rest of that result's
  session, and so is a request still in flight: re-rendering the SAME result keeps both. A
  DIFFERENT result cancels the request it left and starts over.
- **A failure may be retried; an answer may not.** The bridge being unreachable, or its
  answer failing its own contract, says nothing about the match, so the button offers
  `coachRetry` and a press clears the failed reading before it asks again. Advice, an
  uncertain reading and a measured refusal are not re-asked.
- **The route.** The exercise button opens the existing drill screen with the recommended
  exercise selected and writes nothing — no `Config.pending_mode`, no
  `Config.pending_exercise`. When the run behind the result is one press from continuing,
  the button is not offered at all: the block names the exercise and says the full training
  opens from the menu.
- **Read-only result.** The block never touches the store, the score, the save lane or the
  rematch/menu actions; `screen_result_audit.gd` (including its byte-compared "a render
  writes nothing" check) still passes untouched.

## Commands, exit codes, results

Godot is `/Applications/Godot.app/Contents/MacOS/Godot` (4.7.2, the version this branch
uses); every run is `--path godot/`. Full logs are in `logs/` next to this file.

| Command | Exit | Salient result |
| --- | --- | --- |
| `node scripts/coach/jev_bridge_test.mjs` | 0 | `PASS 123/123` — fake upstreams only, no key, no charge |
| `node scripts/coach/jev_bridge_integration_test.mjs` | 0 | `PASS 27/27` — the real Godot client against the real `createBridge` with a fake upstream, three scenarios |
| `GODOT --headless --script res://tests/coach_test.gd` | 0 | `PASS 146/146`, 0 `SCRIPT ERROR` |
| `GODOT --headless --script res://tests/coach_client_test.gd` | 0 | `PASS 79/79`, real `HTTPRequest` over loopback, handler accounting included |
| `GODOT --headless --script res://tests/ui/result_coach_audit.gd` | 0 | `PASS 111/111` (retry, same-result reuse, changed-result staleness) |
| `GODOT --headless --script res://tests/ui/screen_result_audit.gd` | 0 | `PASS 176/176` (regression: unchanged) |
| `GODOT --headless --script res://tests/ui/screen_drill_audit.gd` | 0 | `PASS 89/89` (the route's destination) |
| `GODOT --headless --script res://tests/ui/router_audit.gd` | 0 | `PASS 86/86` (includes the `res://src/ui/**` literal scan over the new panel) |
| `GODOT --headless --script res://tests/ui/demo_matrix_audit.gd` | 0 | `PASS 133/133` |
| `GODOT --headless --script res://tests/audits/run_all.gd` | 0 | `PASS 10/10` in 115 s (the ported rules/simulation suite) |
| `GODOT --rendering-driver opengl3 --script res://tests/ui/_probe_coach.gd -- --out=<evidence>` | 0 | 3 non-blank PNGs in `evidence/` |
| `node tools/i18n-port/verify-i18n-port.mjs` | 1 | 4 findings — **identical to the pre-change baseline** (`logs/i18n_verify_before.log` vs `_after.log`): that lane is already red on this branch and untouched by this work |
| `npm run audit` | 1 | `27/28` — the one failure is `assets-audit.mjs` (`assets/arenas/officina-vapore.webp` unreferenced by `js/**`), an asset-lane mismatch outside this task; that audit reads only `index.html` and `js/**`, so nothing here is in its scope |
| `GODOT --headless --script res://tests/ui/uir22_integration_audit.gd` | 1 | `74/75`, `bridge/confirm_on_play_lands_on_modes` — **pre-existing**: the same single failure at `HEAD` in an isolated worktree with none of this work present (`logs/uir22_integration_head_only.log`) |

The correction cycle re-ran the focused set (the first five rows) plus the four UI
regressions; the last three rows are the round-1 evidence for lanes this work does not
reach, and were not re-run on purpose.

### Live-tested vs not

- **Live-tested:** the whole client path in-engine over a real loopback socket (the engine's
  own `HTTPRequest` against a stub server, `coach_client_test.gd` section 3); the truthful
  offline state with no server on the port; the block on the real screen in the real router;
  the route into the real drill screen; and a match the simulation itself stepped
  (`coach_test.gd` section 7 — 11-9 over 9 926 ticks, three drillable candidates offered).
- **Not live-tested:** any call to the real TypeSafe endpoint. The brief forbids paid smoke
  calls, so the upstream is exercised only against fake upstreams: the *contract* of a valid
  Jev answer is proven rather than a live model's answer. The first live run needs the key
  exported and the bridge started; nothing else is missing.
- **The client-to-bridge seam IS driven end to end** since this correction cycle:
  `scripts/coach/jev_bridge_integration_test.mjs` runs the engine's own `HTTPRequest`
  through the real `CoachClient` against the real `createBridge`, with a fake upstream, in
  three scenarios (fail/retry/advice, the visible path plus the route into the drill screen,
  and an unreachable upstream). What remains unexercised is only the real TypeSafe service
  behind that bridge.

### Evidence

- `evidence/coach-idle.png`, `evidence/coach-advice.png`, `evidence/coach-pending.png` —
  the three layouts at 1280x720, from constructed fixtures (they are layouts, not claims
  about a played match). The idle block fits the card without a scrollbar; the advice state
  is taller and rides the card's existing scroll container.
- `logs/` — the full output of every command above.

## Local commands

```bash
# the bridge (development integration, loopback only)
export TYPESAFE_API_KEY="$(cat ~/.hermes/secrets/typesafe.apikey)"
node scripts/coach/jev_bridge.mjs                  # 127.0.0.1:8787
COACH_PORT=9000 node scripts/coach/jev_bridge.mjs  # another port (the game reads COACH_PORT)
node scripts/coach/jev_bridge_test.mjs             # no key needed, no charge

# the game's own tests
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path godot/ --script res://tests/coach_test.gd
$GODOT --headless --path godot/ --script res://tests/coach_client_test.gd
$GODOT --headless --path godot/ --script res://tests/ui/result_coach_audit.gd

# the layout probe (writes PNGs; needs a rendering driver, not --headless)
$GODOT --rendering-driver opengl3 --path godot/ --script res://tests/ui/_probe_coach.gd \
  -- --out=/absolute/evidence/dir
```

In the game: play a match to its result, press **Analyze with Jev** (the only thing that
ever calls the bridge), read the advice, and press the exercise button to open the training
screen with that exercise selected.

## Production boundary

This is a development integration, not a deployed service: the bridge is loopback-only and
unauthenticated (anything running as you on this machine can call it), it exists so the
coach can be built and tested locally, and the key never leaves its process. A public
distribution needs an authenticated backend (per-account keys, rate limiting, abuse
controls); the game's side of the contract — a bounded snapshot in, a bounded Choice out,
nothing else — is what such a backend would keep.

## Known limits

- The advice covers four focuses (serve, shot accuracy, rally consistency, net finishing)
  plus `insufficient_data`, and each focus quotes only counters this build measures. A
  richer coach needs richer measurement first: the contract is where a new counter would be
  declared, and the bridge refuses anything else.
- The criteria and the sentences are measurement-framed on purpose: the coach says what the
  counters are, never why a ball was missed, where a player stood, or that a serve "cost"
  points. A coach that could say more would need measurement that does not exist yet
  (placement, position, error cause).
- `pointsPlayed` and `averageHitsPerRally` are derived readings (documented formulas, the
  result screen's own average), not new measurements.
- A failure is retryable and an answer is not; a retry re-asks the same bridge with the same
  snapshot, so a bridge that stays down keeps saying so rather than being re-tried behind
  the player's back.
- The coach keeps no history: nothing is stored, so a reading is reused only within the
  result screen it was asked on.
- The confidence gate is provisional and conservative, meant to be re-derived from the
  player's own accepted/rejected outcomes; until then it errs towards saying less.
- The block adds height to the result card. At 1280x720 the idle state still fits; the
  advice state scrolls, as the promotion card already did.

## Decisions for Astra

1. **The coach's strings are a coach-owned table** (`godot/src/coach/coach_strings.json` +
   `coach_text.gd`), not keys hand-written into `godot/src/locale/locale_data.gd`: that file
   is generated from the frozen browser reference and drift-verified, and the reference has
   no coach, so a hand-added key would be dropped by the next regeneration. If the locale
   lane is ever regenerated from the live `js/i18n.js`, promoting these ids there is the
   cleaner long-term home.
2. **`minCandidates: 3`** (at least two drillable categories beside `insufficient_data`) is
   the anti-coin-toss rule; a real match in this build offers three or four.
3. **`confidenceGate: 0.5`**, applied to TypeSafe's own Choice confidence, with its
   derivation documented in the contract.
4. **The drill route is offered only when nothing is pending.** With a career or tournament
   continuation pending, opening the training screen would let the player replace the run
   they are one press from continuing (`Config.pending_mode`), so the block names the
   exercise and says the training opens from the menu instead.
5. **The result screen is otherwise untouched** — one additive block, two focus
   registrations, one `exit()` cancel.

## Correction cycle (round 2)

Six findings were resolved in one pass. Files touched in this cycle, and what changed:

| File | Change |
| --- | --- |
| `godot/src/ui/coach/CoachPanel.gd` | `retryable()` (unavailable/invalid only); `press_analyze` clears a failed reading before it asks again; `show_result` keeps the reading or the request in flight for the SAME result (canonical fingerprint of score + counters, sorted keys) and cancels + resets for a different one. |
| `godot/src/coach/coach_client.gd` | The request's one-shot completion callable is tracked, disconnected on cancel and on an immediate request failure, and cleared when it fires; `open_completion_handlers()` exposes the count to the test. |
| `godot/src/coach/coach_stats.gd` | Missing or wrong-shaped groups/sides/counters are `missing:`/`malformed:` blockers, never a measured zero; `minCandidates` compares the DRILLABLE count; `net_finishing` no longer sums `smashWinners` into `winners` and needs a winners-to-points-won ratio. |
| `godot/src/coach/coach_advice.gd` | The chosen category must be at the peak of the distribution (ties allowed); the advice params quote only measured, non-summed counters (`pointsWon`, never `pointsPlayed`/`smashWinners`). |
| `godot/src/coach/coach_contract.json` | `minCandidates: 2` with the note aligned to "drillable only"; criteria and instructions reworded to measurement-only language; `matchWide` and the `smashWinners` note added to the state. |
| `godot/src/coach/coach_strings.json` | Evidence line split into "your side" and "the match"; every advice sentence reworded to measured-only (it + en); the standing note explains the two scopes. |
| `scripts/coach/jev_bridge.mjs` | Log line carries the canonical route and a known verb only (`(other-route)`/`(other-method)` markers, no query strings, no raw path); the chosen category must be the peak, with a tie accepted. |
| `scripts/coach/jev_bridge_integration_test.mjs` (new) | The real client -> real bridge -> fake upstream test, three scenarios. |
| `godot/tests/coach_integration_probe.gd` (new) | The Godot half of that test: `client`, `ui` and `offline` modes. |
| `godot/tests/coach_test.gd` | Boundary cases for missing/malformed counters, the two-drillable boundary, the smash-winner rule, the peak/tie rule, and a forbidden-word scan over both tables and every criterion. |
| `godot/tests/coach_client_test.gd` | Completion-handler accounting (one in flight, none after success or cancel). |
| `godot/tests/ui/result_coach_audit.gd` | Fail -> retry -> success, double click while reading, same-result re-render while in flight and after a reading, and a changed result whose late reply paints nothing. |
| `scripts/coach/README.md` | The log promise, and the integration test's command. |

No gameplay, sim, score, save, menu or other worker's file was touched; `ResultScreen.gd`
kept its additive shape (the only change since round 1 is none — the panel owns the new
rules).

## Checkpoint (if this run is interrupted)

Everything above is on disk in the working tree: the coach modules, the bridge and its
tests, the three Godot tests, the probe, the evidence and these logs. Nothing is committed.
To resume, re-run the four commands that cover this work
(`jev_bridge_test.mjs`, `coach_test.gd`, `coach_client_test.gd`,
`tests/ui/result_coach_audit.gd`); they are independent of the rest of the suite.
