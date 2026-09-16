# Ported simulation and rules audits (slice S3)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Sim core parity](sim-core-parity.md) technically — there is no sim to test until it lands. Acceptance is additionally blocked by [Parity gate definition](../../wayfinder/tickets/parity-gate-definition.md) (open, owner Luca) for the audits whose promise is numeric rather than discrete, and by [Web build strangler policy](../../wayfinder/tickets/web-build-strangler-policy.md) for which commit the JavaScript side of each comparison is measured against. The audits may be written and run now; the slice may not be called done while those stay open.

This ticket implements row S3 of `docs/implementation/PLAN.md` ("Port the remaining simulation and rules audits one per name"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S4 through S13.

## Objective

Take the ten rules-and-simulation promises that the web build proves by script and re-prove each one inside the Godot port, under its original audit name, against the ported simulation core that [Sim core parity](sim-core-parity.md) delivers. The web suite is the executable specification: a Godot audit is the same promise expressed against `godot/src/sim/`, never a weaker one and never a new promise. Nothing is rendered, no scene is entered and no audio is played; every check runs on the headless simulation through the same fixed `1/120` s tick the port already uses. The slice ends when ten Godot audits exist under ten original name stems, each green on the frozen web baseline's own scenario values, and the web suite is untouched and still green.

The tenth audit in the list below — controller tactics — reads a Godot input path that [Quick-match vertical slice in 3D](quick-match-slice.md) owns. That audit is written here and its input half is not; the ticket names the seam and stops there rather than duplicating another lane's input map.

## Existing source anchors

Anchors were re-read while writing this ticket. Every one is a real file and line at the frozen baseline. The audit columns give the promise being ported and the exact assertion that carries it; the rule columns give the simulation code the audit is testing, so a red Godot test can be traced back to a `js/game.js` region.

| Audit under `scripts/` | Promise it asserts (verified line) | Simulation code under test |
|---|---|---|
| `wall-rules-audit.mjs` | A ball that reaches the opponent's glass with zero bounces on that side gives the point to the side owning the wall (`:105-111`), the same rule on the player's own glass (`:126-130`), a legal glass continuation, and the serve case (`:137-154`) | `js/game.js:2214` `handleWalls`, `:2236` and `:2332` the defender `.sort(...)[0]`, `:2272` and `:2284` `arena.wallBounce` scaling, `js/game.js:2150` `handleGroundBounce`, `js/game.js:2372` `handleNetCollision` |
| `court-speed-audit.mjs` | A full drive crosses the court in a readable window and stays faster than the fastest athlete (`:63-96`): `drivePieno / mediano >= 1.35`, `smash / mediano >= 1.5`, `smash > drivePieno`, `piuVeloce < drivePieno`, `drivePiano < piuLento` | `js/data.js:81-323` `BALANCE`, `BALANCE.basePaddleSpeed` and every athlete's `stats.speed`; `js/data.js:1-8` `COURT` |
| `match-format-audit.mjs` | Winning every point wins the match for every format (`:73-83`), a set closes at the configured game count (`:101-102`), 6-6 starts the tie-break (`:114-120`) | `js/game.js:2078` `scorePoint`, `js/data.js:662-670` `MATCH_FORMATS` |
| `shot-quality-audit.mjs` | Timing grades are `perfect` / `early` / `late` for the three timings, a perfect timing has strictly better quality, and the intent mode reads `CONTROLLO` at low charge (`:62-72`) | `js/game.js:928` `evaluateShotQuality`, `js/game.js:1468` `hitBall` |
| `shot-balance-audit.mjs` | Charge increases lob depth (`:102-106`), the Pantera lob error rate stays inside a band (`:120-121`), a deep lob can reach the glass and the AI can answer after its own glass (`:125-135`), X2 is strong but defendable (`:151-153`), interception rises with difficulty (`:155`) | `js/game.js:1468` `hitBall`, `js/game.js:2431` `moveComputerPaddle` |
| `smash-input-audit.mjs` | A second A on a high ball at the net produces `smash-x2`, a lateral stick produces `smash-x3` (`:35-36`), the flat and bandeja conversions (`:37-47`), the primed/confirmed two-tap state (`:89-98`), and the return-of-serve case (`:151-152`) | `js/game.js:1923` `applySpecial`, `js/game.js:1978` `trySpecial`, the smash branch inside `js/game.js:1468` `hitBall` |
| `difficulty-audit.mjs` | The hardest tier keeps the player's X3 winner rate at or below 0.35 and the easy-to-hard spread is at least 0.45 (`:139-148`), and skill, effective speed, reaction time, aim error and long-rally error all move monotonically (`:159-171`) | `js/data.js:673-685` `AI_OPPONENTS`, `js/game.js:2431` `moveComputerPaddle` |
| `ai-attack-audit.mjs` | A short lob is replayed almost always and provokes attack (`:76-89`), a deep lob suppresses attack (`:94-97`), and the hardest tier is measured at the net (`:129-130`) | `js/game.js:2431` `moveComputerPaddle`, `js/game.js:1468` `hitBall` |
| `lineup-audit.mjs` | An empty lineup copies the player's own stats while a chosen partner changes width, speed and control (`:24-37`), read against `ROSTER_AVERAGE` | `js/data.js:484-497` `ROSTER_AVERAGE`, `js/game.js:184-186` `createMatchState` `options.lineup`, `js/game.js:173-183` `statRatio`/`paddleRatio` |
| `controller-tactics-audit.mjs` | The three technical variants set their `shotType` (`:35-45`), and charge reduces movement distance versus a normal step (`:56-57`) | `js/game.js:1468` `hitBall`, the charge branch inside `js/game.js:2416-2542` paddle motion |

Contract anchors the ten ports share:

| Anchor | What it is |
|---|---|
| `js/main.js:1164` | `FIXED_STEP = 1 / 120`, the tick every audit drives. The port holds no tick constant of its own |
| `js/game.js:2712-2734` | `EMPTY_INPUT`, the 22-field per-tick input struct each audit's scripted input must fill |
| `js/game.js:2973` | `updateMatch(state, dt, input, input2 = null)`, the single tick entry point |
| `js/game.js:184-186` | `createMatchState(mode, athlete, arena, aiProfile, tournamentRound, options)` — tests inject the seed by assignment after construction, per `scripts/determinism-audit.mjs:24` |
| `godot/src/sim/sim.gd` | The ported core: `static func create_match_state(...)`, `static func update_match(state, dt, input, input2)`, `static func hit_ball(...)`, `static func evaluate_shot_quality(...)`, `static func move_computer_paddle(...)`, `static func add_event(state, message_id)` — snake_case, one file, per its own header note on module granularity |
| `godot/src/sim/frozen.gd` | `balance()`, `court()`, `athletes()`, `arenas()`, `ai_opponents()`, `roster_average()`, `event_lines()`, `bal(name)`, `has_bal(name)`, backed by `godot/src/sim/frozen/data.json`. `MATCH_FORMATS` has no accessor yet — the table is the `matchFormats` key that `Frozen.all()` returns (six entries), and the `match-format` audit reads it from there rather than adding a function to a file this ticket does not own |
| `godot/src/sim/rng.gd` | The bit-exact `nextRandom`, the seam every audit's seed injection goes through |
| `GAMEPLAY_RULES.md:102-111` | The glass and point-assignment rule in design prose, the thing `wall-rules-audit` executes |
| `GAMEPLAY_RULES.md:133-140` | The five balancing parameters the `court-speed` and `difficulty` audits read; frozen for the port, not re-tuned here |
| `GAMEPLAY_RULES.md:69-100` | AI decision priority, target zones and the controlled-error rule, the design half of `difficulty` and `ai-attack` |
| `GAMEPLAY_RULES.md:152-180` | The controller map, the design half of `controller-tactics` and of the input map [Quick-match vertical slice in 3D](quick-match-slice.md) owns |

Two of the rules under test depend on iteration order rather than arithmetic: the wall defender choice at `js/game.js:2236` and `:2332` sorts two defenders in JavaScript where V8's sort is stable, and `js/game.js:2597` sorts two AI paddles the same way. `godot/src/sim/sim.gd` must compare explicitly where the reference sorts a two-element tie, and the `wall-rules` port is the audit that catches it if it does not.

## File ownership / allowlist

New files this ticket creates, one writer at a time:

- `godot/tests/wall_rules_audit.gd` and `godot/tests/wall_rules_audit.tscn`
- `godot/tests/court_speed_audit.gd` and `godot/tests/court_speed_audit.tscn`
- `godot/tests/match_format_audit.gd` and `godot/tests/match_format_audit.tscn`
- `godot/tests/shot_quality_audit.gd` and `godot/tests/shot_quality_audit.tscn`
- `godot/tests/shot_balance_audit.gd` and `godot/tests/shot_balance_audit.tscn`
- `godot/tests/smash_input_audit.gd` and `godot/tests/smash_input_audit.tscn`
- `godot/tests/difficulty_audit.gd` and `godot/tests/difficulty_audit.tscn`
- `godot/tests/ai_attack_audit.gd` and `godot/tests/ai_attack_audit.tscn`
- `godot/tests/lineup_audit.gd` and `godot/tests/lineup_audit.tscn`
- `godot/tests/controller_tactics_audit.gd` and `godot/tests/controller_tactics_audit.tscn`
- `godot/tests/sim_audits_runner.gd` and `godot/tests/sim_audits_runner.tscn` — one runner that invokes the ten, prints one `ok`/`FAIL` line per audit and one `PASS n/n` summary, so CI runs one command and gets one exit code
- `godot/tests/audit_support.gd` — the shared scenario builders the JS audits hold locally (`VUOTO`/`EMPTY_INPUT` literals, seed injection, the scripted tick loop). This file is a support module, not an audit; it has no `-audit` name and the runner does not report it
- `docs/implementation/evidence/s3-*` — the evidence files listed below

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file, including `run-audits.mjs`), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/` (owned by [Sim core parity](sim-core-parity.md); this ticket reads it and reports a defect rather than editing it), `godot/src/input/` (on the [Quick-match vertical slice in 3D](quick-match-slice.md) side of the seam), `godot/tests/determinism_audit.gd`, `godot/tests/parity_digest.gd`, `godot/tests/smoke_test.gd`, `godot/tests/SmokeTest.tscn`, and `godot/project.godot` beyond nothing at all — the audits are launched by scene path or by `--script`, so no project edit is required.

The ported simulation core is a single file (`godot/src/sim/sim.gd`), and it is not this ticket's to re-split. If an audit proves a rule wrong, the finding is recorded as a divergence and raised against the sim core's own ticket; the audit file is not allowed to work around it.

## Inputs and outputs

Inputs:

- The ported core, called exactly as [Sim core parity](sim-core-parity.md) publishes it: `create_match_state(mode, athlete, arena, ai_profile, tournament_round, options)`, `update_match(state, dt, input, input2)`, `hit_ball(...)`, `evaluate_shot_quality(...)`, `prepare_serve(state)`, `perform_serve(state, requested_charge, slice)`, `move_computer_paddle(...)`, plus `frozen.gd` for every table.
- The seed, an explicit integer per audit. The JavaScript audits inject it after construction; the Godot audits do the same, at the same lifecycle point, so the two scripts stay comparable.
- The scripted per-tick input: one 22-field dictionary per tick, matching `js/game.js:2712-2734` and the `EMPTY_INPUT` literal each JavaScript audit carries.
- The scenario values copied from the JavaScript audit itself, not re-derived: court positions, charge fractions, timing ages and sample counts are the same numbers, so a red Godot audit means the port differs, not that the scenario was re-invented.

Outputs, per audit, on stdout:

- one `ok <check name>` line per passed assertion and one `FAIL <check name>: expected <x>, got <y>` line per failed one, the same machine-readable contract `godot/tests/smoke_test.gd` already prints;
- one final `PASS <n>/<n>` summary line;
- exit code `0` when every check passed and `1` when any did not, so the shell sees the result without parsing prose.

No audit renders, loads a scene tree of its own, plays audio, reads a clock or writes to `user://`. Each is a pure function of the frozen data, one seed and its own tick script.

The seam with the input lane is stated once and is not crossed here: the `controller-tactics` port drives the simulation directly with a per-tick dictionary, the way every other audit does. Whether a real gamepad reaches those fields is the input map's question, owned by [Quick-match vertical slice in 3D](quick-match-slice.md). That seam has one owner and this ticket is not it.

## Tests

The audits ported, by real file name under `scripts/`, with the Godot file that replaces each:

| JavaScript audit | Godot audit | Extra Godot check the JavaScript cannot make |
|---|---|---|
| `scripts/wall-rules-audit.mjs` | `godot/tests/wall_rules_audit.gd` | the defender choice is asserted to be order-independent with a deliberate distance tie |
| `scripts/court-speed-audit.mjs` | `godot/tests/court_speed_audit.gd` | `basePaddleSpeed` and every `stats.speed` are read back from `frozen.gd` and asserted against the JSON, so a silently re-tuned table fails here |
| `scripts/match-format-audit.mjs` | `godot/tests/match_format_audit.gd` | every `MATCH_FORMATS` key is exercised, not only the default |
| `scripts/shot-quality-audit.mjs` | `godot/tests/shot_quality_audit.gd` | the grade is read as an event/enum, never as localized text |
| `scripts/shot-balance-audit.mjs` | `godot/tests/shot_balance_audit.gd` | the lob-depth ordering is asserted with the same charge triple |
| `scripts/smash-input-audit.mjs` | `godot/tests/smash_input_audit.gd` | the primed/confirmed two-tap state is asserted across two ticks, not one call |
| `scripts/difficulty-audit.mjs` | `godot/tests/difficulty_audit.gd` | the four tiers come from `frozen.gd`, with the `reactionSkill` value asserted at 0.78 as the JavaScript comment at `js/data.js:678-684` intends |
| `scripts/ai-attack-audit.mjs` | `godot/tests/ai_attack_audit.gd` | the attack-rate comparison is reproduced for the two lob depths |
| `scripts/lineup-audit.mjs` | `godot/tests/lineup_audit.gd` | the empty lineup is asserted against `ROSTER_AVERAGE`, not against a hardcoded number |
| `scripts/controller-tactics-audit.mjs` | `godot/tests/controller_tactics_audit.gd` | the three technical variants are asserted as `shotType` values, and charge is asserted to reduce movement distance |

The web suite is not this slice's to change and is re-run only as a control: `npm run audit` must still print `27/27 audit passano`, exit 0. The two audits that do not port literally — `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs`, which read the repository's file shape rather than the game — stay the replacement named in [Sim core parity](sim-core-parity.md): the project loads headless with zero script errors and every audit scene instantiates. They are not re-implemented here.

Numeric promises and the parity gate. Four of the ten — `court-speed`, `shot-balance`, `difficulty`, `ai-attack` — are statistical over sampled rallies. Godot's `cos`, `sin`, `pow`, `hypot` and `atan2` are not V8's, and one float difference can flip a `nextRandom(state) < chance` gate, so an exact sample-for-sample match is not promised by anything on disk. What this ticket can assert is the direction and the band each JavaScript audit asserts, computed inside the Godot engine over the same sample count. Whether the port must instead be sample-identical is part of [Parity gate definition](../../wayfinder/tickets/parity-gate-definition.md), which is open; the tolerance is not this ticket's to invent, and a band failure is reported as a divergence finding rather than tuned away.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host and every invocation below is wrapped in the shared lock; `timeout` is the CI bound, not `--quit-after`, because a runtime error that aborts `_ready()` hangs the loop instead of going red.

The whole slice in one command, one summary line, one exit code:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 600 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/sim_audits_runner.tscn > docs/implementation/evidence/s3-sim-audits.log 2>&1; \
  echo "exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s3-sim-audits.log | tail -20
```

One audit on its own, for the two-attempts rule and for bisecting a red:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in wall_rules court_speed match_format shot_quality shot_balance smash_input difficulty ai_attack lineup controller_tactics; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}_audit.tscn > docs/implementation/evidence/s3-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; \
done
```

The JavaScript control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s3-web-baseline.log 2>&1; echo "exit=$?"
```

The one-line anchor re-check this ticket's own claims are written against:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  grep -c '^assert' scripts/wall-rules-audit.mjs scripts/court-speed-audit.mjs \
    scripts/match-format-audit.mjs scripts/shot-quality-audit.mjs \
    scripts/shot-balance-audit.mjs scripts/smash-input-audit.mjs \
    scripts/difficulty-audit.mjs scripts/ai-attack-audit.mjs \
    scripts/lineup-audit.mjs scripts/controller-tactics-audit.mjs; \
  sed -n '2236p;2332p;2597p' js/game.js
```

## Expected evidence

- `docs/implementation/evidence/s3-sim-audits.log` — the runner's output: one line per audit, then `PASS 10/10`, with the exit code recorded beside it. This is the machine-readable half.
- `docs/implementation/evidence/s3-wall-rules.log`, `s3-court-speed.log`, `s3-match-format.log`, `s3-shot-quality.log`, `s3-shot-balance.log`, `s3-smash-input.log`, `s3-difficulty.log`, `s3-ai-attack.log`, `s3-lineup.log`, `s3-controller-tactics.log` — the ten individual runs, each with its own exit code, so a red can be bisected without re-running the rest.
- `docs/implementation/evidence/s3-web-baseline.log` — `npm run audit` on the untouched web build: `27/27 audit passano`, exit 0, the control that proves nothing under `js/` or `scripts/` moved.
- `docs/implementation/evidence/s3-divergences.md` — for any audit that reports a band failure instead of a pass: the audit name, the Godot value, the JavaScript value, the sample count and the seed. An empty file is itself evidence, and an empty file is not allowed to be written before all ten audits have run at least once.

What counts as proof: the runner's `PASS 10/10` line plus a recorded exit code of 0, and each individual log's own summary line. An audit whose name no longer matches the web audit it replaces does not count, and neither does a band widened to make a red go green — a widened band is a re-tune and needs the sim core's ticket, not this one.

## Failure and recovery criteria

Red means any of these:

- The runner exits non-zero, or hangs and `timeout` kills it (exit 124). A hang is a red, not a slow green.
- A Godot audit's name or promise is weaker than the JavaScript audit it replaces, or a check is dropped rather than ported.
- An audit re-implements a physics or scoring rule locally instead of calling `godot/src/sim/sim.gd`. A second physics path is a red for the same reason `scripts/drill-audit.mjs` gives about `js/game.js`.
- The Godot run and the JavaScript run disagree on a discrete promise — a grade, a `shotType`, a winner, a score field — as opposed to a band.
- Any audit needs a change to `COURT`, `BALANCE`, `SERVICE_LINE_OFFSET`, `WIN_SCORE`, `MATCH_FORMATS`, an athlete's `stats`, `AI_OPPONENTS` `skill` / `speed` / `power` or an arena's `wallBounce` in order to pass. That is re-tuning, not porting: stop, revert the number and raise it with the `VERSION.balance` consequence stated (`js/data.js:20`).
- A file outside the allowlist changes, or `js/` or `scripts/` changes at all.
- The audit writes a localized string into compared state. The port stores message ids (`godot/src/sim/sim.gd` `add_event`), and a text comparison is not a parity signal.

What stops the slice: a red audit after the retry rule below; a sim-core defect that the audit exposes and the sim core's owner has not yet fixed, which is recorded as a blocker against [Sim core parity](sim-core-parity.md) rather than patched around inside a test; or the parity gate definition landing in a form that requires sample-identical statistics, which re-scopes the four statistical audits instead of widening them.

Retry rule: two attempts per failing audit, then a blocker is recorded with the audit name, the failing check line and both attempts. No identical third retry, and unrelated unblocked audits continue while one is blocked.

Recovery paths worth trying before declaring a blocker: confirm each audit drives the tick through `update_match(state, 1.0 / 120.0, input)` and not through a frame delta; confirm the seed is injected at the same lifecycle point the JavaScript audit uses; confirm the shared `audit_support.gd` scenario literals are byte-equal to the audit's own `VUOTO`/`EMPTY_INPUT`; for `wall-rules`, assert the defender choice directly on a constructed distance tie before involving the physics.

## Human gates that block this slice (open, owner Luca)

- **Parity gate definition** — decides what "at parity" means for anything numeric that cannot match exactly, and therefore whether the four statistical audits gate on a band or on sample identity. This ticket ports the bands as the JavaScript audits state them and marks the question open; it does not answer it. The recommended default in `PLAN.md` — gate on discrete state and treat positions as a smoke check — is a proposal, and no slice is declared complete on it.
- **Web build strangler policy** — decides which commit the JavaScript side of every comparison is measured against. This ticket measures against the frozen baseline and re-freezes if the decision names a different commit; it does not choose.
