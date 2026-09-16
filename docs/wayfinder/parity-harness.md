# Parity harness: the Node audits and their Godot future

Inventory of the **27** audits in `scripts/`, run by `scripts/run-audits.mjs` under `npm run audit`.
The runner spawns each `*-audit.mjs` sorted by name, prints the failing assertion per file, and exits 1 if
any of them is red. The CI workflow badge in `README.md` reflects the same command, and the "27" count is
confirmed by the runner's own output, not by counting files by eye.

**Caveat on what this document is and is not.** The list below was assembled from the runner output and the
audit file names, with the "Asserts / Reads" columns read from the scripts — it is a map of the suite, **not
an exhaustive, assertion-level inventory**, and it was not produced by executing every assertion in
isolation. Treat each row as a pointer to the script, which remains authoritative for what it checks. Where a
row's description and the script disagree, the script wins.

**Baseline status is NOT green.** On this host `npm run audit` scores **25/27**: red on `outfit-assets`
(assertion error, still undiagnosed) and `unlockable-animation` (cannot import the `sharp` package). Neither
red should be reclassified as a dependency problem without evidence. Raw log:
`evidence/baseline-audit.log`.

Why this matters: this suite is the only executable statement of what "the same game" means. Every ported
behaviour should arrive with the audit that proves it, and a ported audit keeps its original file name so a
red test in Godot points at the same promise as a red test in Node.

## The audits, by area

### Simulation and rules

| Audit | Asserts | Reads |
|---|---|---|
| `wall-rules-audit.mjs` | The glass rules of padel rule 13, played out: when the ball may hit the walls of your own half, the double bounce that closes the point | `game.js` createMatchState, updateMatch; `data.js` ATHLETES, ARENAS, AI_OPPONENTS, COURT |
| `determinism-audit.mjs` | The same seeded point resolves identically at any frame rate, because the loop is fixed-step | `game.js` createMatchState, prepareServe, performServe, updateMatch |
| `match-format-audit.mjs` | The formats as played: games per set, margin, sets to win, tennis scoring to advantage | `game.js` createMatchState, updateMatch; `data.js` MATCH_FORMATS |
| `court-speed-audit.mjs` | Ball speed against the speed of the player chasing it, the ratio that decides whether it feels like a sport | `game.js` createMatchState, updateMatch, hitBall; `data.js` BALANCE, COURT |
| `shot-quality-audit.mjs` | The timing and quality labels, and the thresholds behind them | `game.js` createMatchState, hitBall |
| `shot-balance-audit.mjs` | The shot mix stays balanced, including the early interception of the smash | same as above plus updateMatch |
| `smash-input-audit.mjs` | Smash x2 and x3 conditions and the double-tap input window | `game.js` hitBall; `data.js` BALANCE, COURT |
| `difficulty-audit.mjs` | The x3 threshold and the constraints that keep the four AI levels honest | `game.js` hitBall, performServe; `data.js` AI_OPPONENTS |
| `ai-attack-audit.mjs` | The AI punishes a bad lob and leaves a good one alone | `game.js` createMatchState, updateMatch, hitBall |
| `lineup-audit.mjs` | Doubles lineup: the partner does not inherit the player's stats | `game.js` createMatchState, hitBall, updateMatch; `data.js` ROSTER_AVERAGE |
| `controller-tactics-audit.mjs` | The D-pad tactics and the translated labels they raise | `game.js`, `data.js`, reads repository files |

### Career and progression

| Audit | Asserts | Reads |
|---|---|---|
| `career-audit.mjs` | Progression holds: every star reachable, stars taken once, the ramp capped | `data.js` CAREER_*, AI_OPPONENTS, ARENAS |
| `outfit-challenges-audit.mjs` | Every outfit challenge is winnable, and winning one means something | `data.js` ATHLETE_OUTFITS, isUnlocked, outfitChallengeMet |
| `tournament-audit.mjs` | The bracket: three rounds, arenas travelling by prestige, no rematch shortcut | `data.js` ARENAS, AI_OPPONENTS, tournamentFixture |

### Drill

| Audit | Asserts | Reads |
|---|---|---|
| `drill-audit.mjs` | The drill is the same engine, not a second one: it trains the physics that the match actually uses | `drill.js` createDrill, updateDrill, metrics; `data.js`; `i18n.js` |

### Interface, navigation and reachability

| Audit | Asserts | Reads |
|---|---|---|
| `gamepad-nav-audit.mjs` | Controller navigation works, since a Steam release is played on a pad | reads repository files |
| `reachability-audit.mjs` | Every screen has a door and every door leads somewhere | reads repository files |
| `unlockable-animation-audit.mjs` | Sprite sheets behind the unlockable content are real and correctly shaped | `data.js`, `sharp` |

### Content integrity

| Audit | Asserts | Reads |
|---|---|---|
| `assets-audit.mjs` | Every image named in code exists, and no active image is orphaned | filesystem, `data.js` |
| `outfit-assets-audit.mjs` | Outfit previews exist for every outfit | `data.js` ATHLETE_OUTFITS |
| `i18n-audit.mjs` | Italian and English say the same things, key for key | `i18n.js`, `data.js` |
| `arena-scenery-audit.mjs` | Scenery outside the cage never intrudes on the play surface | reads files |

### Build, demo and feedback

| Audit | Asserts | Reads |
|---|---|---|
| `demo-audit.mjs` | The demo filter really limits the build: two athletes, one arena, quick match only | `build.js` IS_DEMO, demoFilter, demoLocked; `data.js` |
| `feedback-audit.mjs` | A written message is never lost: offline, without an endpoint, without storage | self-contained |
| `api-feedback-audit.mjs` | The serverless endpoint rejects what it should, before it is public | `api/feedback.js` handleFeedback |

### Code contracts

| Audit | Asserts | Reads |
|---|---|---|
| `module-contract-audit.mjs` | Every imported name exists in the module that exports it, and version queries match | reads sources as text |
| `modules-audit.mjs` | Every module can be evaluated without throwing | dynamic import of every module |

## What ports, and what has to exist first

Ports as a headless GDScript or Node-side check, once the pure core exists: every simulation and rules audit
(wall rules, determinism, match formats, court speed, shot quality, shot balance, smash input, difficulty, AI
attack, lineup, controller tactics), every career audit, the drill audit, the content integrity checks, the
demo gate, and the feedback queue. These depend on a pure simulation core in GDScript, the constant tables
ported from `data.js`, and the same seeded generator, none of which exist yet. That dependency is
`tickets/simulation-port-boundary.md` and `tickets/godot-headless-harness.md`.

Replacements, not ports: `module-contract-audit` and `modules-audit` check JavaScript import graph and text
alignment. In Godot the equivalents are that the project loads without script errors and that every scene and
script instantiates in a headless run. `unlockable-animation-audit` inspects sprite sheets with `sharp`; in 3D
the assertion changes shape entirely and belongs to the art pipeline ticket.

Stays in the web repository: `api-feedback-audit.mjs` tests the Vercel function, which the Godot build does not
contain. Its contract still matters, since the Godot client posts to the same endpoint.

## The strongest gates for the first spike

1. `determinism-audit.mjs`, because a fixed-step port that drifts is not a port, and this is the cheapest way to
   find out early.
2. `wall-rules-audit.mjs`, because the glass is the rule that separates padel from tennis and the one most
   likely to be broken by 3D collision work.
3. `court-speed-audit.mjs`, because ball speed against chaser speed is the ratio behind the whole feel.
4. `match-format-audit.mjs`, because scoring is the outcome every other test reads.
5. `shot-quality-audit.mjs`, because the timing windows are what a human calls feel, and the audit is the only
   proxy available before a play test.

## Gaps in the suite

The audits say nothing about rendering, camera framing, audio, save files, Steam achievements and cloud saves,
or frame time. Those become new tests in the port, and two of them, framing and feel, can only be signed off by
playing. See `tickets/parity-gate-definition.md`.
