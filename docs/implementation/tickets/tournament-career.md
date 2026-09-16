# Tournament and career presentation (slice S9)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Drill as a 3D session](drill-3d.md) and [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md): the presentation this slice builds is made of screens and reuses the session plumbing both of those establish. Acceptance is additionally blocked by [UI port approach](../../wayfinder/tickets/ui-port-approach.md) (open, HITL, owner Luca), which decides whether the Control tree carries this interface at all — the tournament and career screens are four more of the eleven the UI decision covers — and by [Product scope and platforms](../../wayfinder/tickets/product-scope-and-platforms.md) for the platform and input surface. The progression model and the fixture resolver may be ported now; the slice may not be called done while those stay open.

This ticket implements row S9 of `docs/implementation/PLAN.md` ("Tournament and career presentation"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S10 through S13.

## Objective

Bring the tournament and the career out of the browser and into the Godot build as a progression model ported from the existing data plus four screens that present it. Nothing about the progression is invented: the season count, the promotion rule, the objective definitions, the metric aggregation, the rival ramp and both fixture resolvers already exist as pure functions in `js/data.js`, and the presentation logic exists in `js/ui.js`. The slice ports both halves, wires them to the screens the UI slice can host, and keeps the persistence question where it belongs — the career payload is saved through the save interface owned by [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md), not by a storage call inside a presentation script.

The two audits that already hold these promises in the web build are `career-audit.mjs` and `tournament-audit.mjs`. They are executable specifications, and the ported versions assert the same properties against the same frozen tables.

## Existing source anchors

Progression data and pure functions:

| Anchor | What it is |
|---|---|
| `js/data.js:765, 766, 767` | `CAREER_MATCHES = 3`, `CAREER_POINTS_TO_WIN = 11`, `CAREER_PROMOTION_WINS = 2` — the season shape |
| `js/data.js:775` | `SEASON_METRIC_AGG` — how each season metric accumulates. `career-audit.mjs:123` fails if an objective's metric has no aggregation rule, and `:134` fails if a metric accumulates but no objective reads it |
| `js/data.js:785` | `emptySeasonProgress()` — the zero state, the shape a save must round-trip |
| `js/data.js:806` | `OBJECTIVE_DEFS` — every season objective |
| `js/data.js:816` | `seasonObjectives(season, { pointsToWin, matches })` |
| `js/data.js:838` | `matchObjective(season, matchIndex)` |
| `js/data.js:853` | `CAREER_FINAL_SEASON = 6` |
| `js/data.js:860` | `careerRival(season)` — the rival for a season |
| `js/data.js:872` | `CAREER_RAMP` — the growth rates and the three caps (`skillCap`, `speedCap`, `powerCap`) |
| `js/data.js:885` | `careerAiProfile(season, matchIndex)` — the AI profile for a career match; `career-audit.mjs:216-218` asserts it never exceeds a cap |
| `js/data.js:916` | `tournamentFixture(round, availableArenas = ARENAS)` — the three-round path with a prestige ordering |
| `js/data.js:932` | `careerFixture(season, matchIndex, availableArenas)` |
| `js/data.js:700, 702, 730` | `UNLOCK_CODE`, `isUnlocked(item, career)`, `outfitChallengeMet(challenge, contesto)` — the unlock and outfit-challenge rules the career screen presents |
| `js/data.js:515-555, 556` | `ATHLETE_OUTFITS` (26 entries) and `outfitsForAthlete` — what the challenges screen lists |

Presentation and wiring:

| Anchor | What it is |
|---|---|
| `js/ui.js:38, 48` | `loadCareer()` / `saveCareer(career)` — the career payload's persistence boundary |
| `js/ui.js:62` | `ensureSeasonObjectives()` — objectives are generated into storage and were previously only regenerated on some paths |
| `js/ui.js:91, 106, 120` | `matchProgress(stats)`, `accumulateSeasonProgress(stats)`, `seasonProgress()` |
| `js/ui.js:131, 144, 186` | `objectiveStatus`, `awardObjectives`, `resetSeasonObjectives` |
| `js/ui.js:485, 490, 500, 505, 531, 548` | `selectableAthletes`, `selectableArenas`, `currentFixture`, `currentTournamentFixture`, `dictatedRivals`, `resolveLineup` — the selection surface the tournament and career screens read |
| `js/ui.js:625, 650` | `awardOutfitChallenges(state, won)`, `athleteWithOutfit(athlete, career)` — the unlock path |
| `js/ui.js:1116, 1375, 1422, 1477, 1529, 1563` | `renderChallenges`, `renderMatchStats`, `renderObjectives`, `showResult`, `getAiForMatch`, `renderHistory` — the DOM renderers this slice replaces with Control nodes |
| `js/main.js:1111, 1124, 1140` | `getAiForMatch(ui.selectedMode, ui.tournamentRound, ui.aiDifficulty)`, the round handed to `createMatchState`, and `matchState.careerSeason = ui.career.season` — the wiring the 3D session must reproduce |
| `js/main.js:1396-1412` | The result handling: the season is won when `careerWin && seasonWins + 1 >= CAREER_MATCHES`, the tournament trophy is the third round won, and both feed the history entry's `trophy` field |
| `js/main.js:1454-1464` | The four career outcomes: `finale`, `trophy`, `promoted`, `repeat` |
| `js/main.js:1479-1488` | The tournament round advance and its reset |
| `index.html:264, 277, 289, 535` | `screen-history`, `screen-challenges`, `screen-profile`, `screen-result` — the four screens this slice's presentation replaces |
| `index.html:99` | `screen-modes` — where tournament and career are chosen; the mode selection surface |
| `scripts/career-audit.mjs:77-134` | Objective definitions are positive, achievable within the season count, and every declared objective and metric is actually used (`:115` fails an objective that never appears in the seasons; `:123`, `:134` cross-check aggregation) |
| `scripts/career-audit.mjs:195-218` | Repeating a season pays season stars once, advancing pays more than staying (`.stars` comparisons), and the AI ramp never exceeds its caps |
| `scripts/tournament-audit.mjs:26-73` | The three rounds use distinct arenas, prestige is non-decreasing and maximal at the final (`:30`, `:36`), the resolution degrades correctly as fewer arenas are available (`:45-49`), a round outside the range is handled (`:56-63`), and the AI tier rises with the round (`:70-73`) |
| `GAMEPLAY_RULES.md:146` | "Il punteggio resta tennis: 0, 15, 30, 40, vantaggio, game, set e tie-break" — the result presentation stays tennis |
| `godot/src/sim/sim.gd` | `create_match_state(mode, athlete, arena, ai_profile, tournament_round, options)` — the `tournament_round` parameter the tournament path needs |
| `godot/src/sim/frozen.gd` | The frozen tables the fixtures resolve against: `arenas()`, `athletes()`, `ai_opponents()`, `roster_average()` |

The seams this slice sits next to, each with one owner: the screen router, the shared theme and `UiStrings.gd` belong to [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md) — this slice replaces placeholder shells and registers by data, and never edits the router; the save schema and the career payload's file format belong to [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md); strings belong to `godot/src/locale/**`; input belongs to [Quick-match vertical slice in 3D](quick-match-slice.md).

## File ownership / allowlist

New files this ticket creates:

- `godot/src/career/CareerTables.gd` — `CAREER_MATCHES`, `CAREER_POINTS_TO_WIN`, `CAREER_PROMOTION_WINS`, `CAREER_FINAL_SEASON`, `CAREER_RAMP`, `SEASON_METRIC_AGG`, `OBJECTIVE_DEFS`, generated from `js/data.js`, not re-typed
- `godot/src/career/CareerRules.gd` — the pure port of `seasonObjectives`, `matchObjective`, `careerRival`, `careerAiProfile`, `tournamentFixture`, `careerFixture`, `emptySeasonProgress`, `isUnlocked`, `outfitChallengeMet`
- `godot/src/career/CareerState.gd` — the live career: season, match index, season wins, stars, objectives, outfits won, history. It holds no storage call
- `godot/src/career/CareerProgress.gd` — the port of `matchProgress`, `accumulateSeasonProgress`, `seasonProgress`, `objectiveStatus`, `awardObjectives`, `resetSeasonObjectives`, `awardOutfitChallenges`
- `godot/src/ui/screens/ResultScreen.gd`, `ResultScreen.tscn` — the result screen, including the four career outcomes
- `godot/src/ui/screens/HistoryScreen.gd`, `HistoryScreen.tscn`
- `godot/src/ui/screens/ChallengesScreen.gd`, `ChallengesScreen.tscn`
- `godot/src/ui/screens/ProfileScreen.gd`, `ProfileScreen.tscn`
- `godot/tests/career_audit.gd` and `godot/tests/career_audit.tscn` — the ported career audit
- `godot/tests/tournament_audit.gd` and `godot/tests/tournament_audit.tscn` — the ported tournament audit
- `godot/tests/career_screens_audit.gd` and `.tscn` — the four screens reachable, each reading the model rather than recomputing it
- `godot/tests/capture_career.gd` — the capture harness
- `godot/shots/career-profile.png`, `godot/shots/tournament-result.png`, `godot/shots/challenges.png`, `godot/shots/history.png` and an append to `godot/shots/README.md`
- `docs/implementation/evidence/s9-*` — the evidence files listed below

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/` (owned by [Sim core parity](sim-core-parity.md)), `godot/src/ui/ScreenRouter.gd`, `godot/src/ui/theme/`, `godot/src/ui/UiStrings.gd`, `godot/src/ui/Hud.gd` (owned by [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md)), `godot/src/ui/screens/MenuScreen.*` and `PlaceholderScreen.gd`, the save interface files (owned by [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md)), `godot/src/locale/**`, `godot/src/audio/**`, `godot/src/input/**`, and `godot/prototypes/`.

## Inputs and outputs

Inputs:

- The frozen tables from `godot/src/sim/frozen.gd`. The career and tournament functions are pure functions of those tables, so they are testable headless before any screen exists.
- The career payload, read and written only through the save interface owned by [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md). This slice defines the payload's **shape** — the fields `emptySeasonProgress()` and the history entries imply — and hands that shape to the save slice rather than inventing a file of its own.
- The match result from the 3D session, as a small result record: winner, the stats the progression reads, the mode, the round, the season.
- The selected mode and the selected arena and athletes, from the selection surface.

Outputs:

- A career that can be started, played through a season of three matches, promoted, repeated and completed through the final season, all asserted headless.
- A tournament of three rounds with a non-decreasing prestige path, ending in a trophy entry, asserted headless.
- Four screens presenting the profile, the objectives, the challenges and the history, plus the result screen with its four career outcomes.
- The career payload's shape, handed to the save slice, with a round-trip requirement stated rather than implemented here.
- Rendered captures of four screens.

Explicitly not output: new modes, new objectives, new unlock rules, any change to `CAREER_RAMP` or the objective definitions, any storage call inside a presentation script, and any claim that the career is complete before the UI verdict lands.

## Tests

The web audits that bear on this slice, by real file name under `scripts/`:

- `scripts/career-audit.mjs` — the primary model gate, ported promise for promise: every objective is achievable inside the season count and every declared objective and metric is used by something (`:77-134`); repeating a season pays season stars once while advancing pays more (`:195-200`); the AI ramp never exceeds `CAREER_RAMP`'s three caps and does not fall within a season (`:216-218`).
- `scripts/tournament-audit.mjs` — the fixture gate, ported: three distinct arenas, prestige non-decreasing and maximal at the final (`:26-36`), correct degradation when fewer arenas are available (`:45-49`), out-of-range rounds handled (`:56-63`), AI tiers rising with the round (`:70-73`).
- `scripts/reachability-audit.mjs` — the four new screens must have doors and the router must see them; the check is `godot/tests/reachability_audit.gd`, owned by [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md), which this slice registers with by data.
- `scripts/i18n-audit.mjs` — every string on the four screens is a key. The key-set claims belong to the locale seam; this slice's contribution is that no presentation script holds a literal.
- `scripts/outfit-challenges-audit.mjs` — the 20 unlockable challenges the challenges screen lists; the counts are asserted in the career audit, not re-declared in the screen.
- `scripts/assets-audit.mjs` — the Godot equivalent is load-time resolution of the four screens' resources.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` — the replacement stays the headless load with zero script errors.

Godot-side equivalents, keeping the original name stems:

- `godot/tests/career_audit.gd` — the model checks above, printed as `ok`/`FAIL` with a `PASS n/n` summary.
- `godot/tests/tournament_audit.gd` — the fixture checks above, with the same arena-count sweep the JavaScript audit performs.
- `godot/tests/career_screens_audit.gd` — instantiates the four screens against a populated model and asserts each displays values read from the model, never recomputed locally, and that no screen module references a storage API.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host; every invocation is wrapped in the shared lock. `timeout` is the CI bound, not `--quit-after`.

The three headless audits:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in career_audit tournament_audit career_screens_audit; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}.tscn > docs/implementation/evidence/s9-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s9-${a//_/-}.log; \
done
```

The JavaScript audits this slice ports, run as the reference they are:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  node scripts/career-audit.mjs > docs/implementation/evidence/s9-web-career.log 2>&1; echo "career exit=$?"; \
  node scripts/tournament-audit.mjs > docs/implementation/evidence/s9-web-tournament.log 2>&1; echo "tournament exit=$?"
```

Captures under software GL — `--headless` installs the dummy driver and the frame is blank, so this route is `xvfb-run` with an explicit rendering driver:

```sh
cd /root/projects/steam-circuit-padel-pro && for s in career-profile tournament-result challenges history; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 xvfb-run -a \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ --rendering-driver opengl3 \
    res://tests/capture_career.tscn -- --screen=${s} \
    >> docs/implementation/evidence/s9-capture.log 2>&1 || echo "CAPTURE FAILED: ${s}"; \
done; echo done
```

The frozen tables the model is written against, printed for the record:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  sed -n '765,767p;853p;872,884p' js/data.js
```

Web control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s9-web-baseline.log 2>&1; echo "exit=$?"
```

## Expected evidence

- `docs/implementation/evidence/s9-career-audit.log`, `s9-tournament-audit.log`, `s9-career-screens-audit.log` — each with an exit code and a `PASS n/n` line.
- `docs/implementation/evidence/s9-web-career.log` and `s9-web-tournament.log` — the JavaScript audits this slice ports, for the comparison.
- `docs/implementation/evidence/s9-capture.log` — four capture runs with their exit codes and the screen each wrote.
- `godot/shots/career-profile.png`, `godot/shots/tournament-result.png`, `godot/shots/challenges.png`, `godot/shots/history.png` — 1280x720.
- `godot/shots/README.md` — appended: preset, scale, software-GL caveat.
- `docs/implementation/evidence/s9-career-notes.md` — the career payload shape this slice hands to the save slice, field by field, with the round-trip requirement stated as the save slice's test; the four outcomes and where each is decided; the objectives table as ported; the star arithmetic; and the explicit statement of which screens are real and which remain placeholder shells.
- `docs/implementation/evidence/s9-web-baseline.log` — the untouched web suite, `27/27 audit passano`, exit 0.

What does not count as proof: a screenshot of a screen whose values were recomputed locally rather than read from the model; a career or tournament claim without the headless audit line; a payload shape asserted by prose instead of by the save slice's round-trip test; and any claim that the screens match the web layout before the UI verdict.

## Failure and recovery criteria

Red means any of these:

- Any audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- The career or tournament model diverges from a JavaScript audit's promise, including the star arithmetic, the promotion rule, the caps and the prestige ordering.
- A presentation script recomputes a value the model owns, or calls a storage API instead of the save interface.
- A frozen table is re-declared rather than generated from `js/data.js`, or the objective set, the ramp, the caps or the season count changes.
- A screen holds a user-facing literal instead of a key.
- A capture run exits non-zero or writes a blank frame because it went through the dummy driver.
- The slice edits the router or the shared theme, which belong to another lane.
- A file outside the allowlist changes, or `js/` or `scripts/` changes at all.
- The slice resolves a platform, input or save-migration question by assuming an answer.

What stops the slice: a red audit after the retry rule below; a UI-approach verdict that rejects the Control tree, in which case the four screens are re-planned rather than patched; or the save slice's schema not landing, in which case the model is delivered and the persistence half is recorded as blocked rather than worked around with a private file.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the model reads the ramp and the caps from the generated table and not from literals; confirm the fixture resolver receives the same arena list the JavaScript audit passes at each sweep step; confirm the screens instantiate against a populated model rather than an empty one; confirm the capture run passed `--rendering-driver opengl3` under `xvfb-run`.

## Human gates that block this slice (open, owner Luca)

- **UI port approach** — the four screens are four of the eleven the decision covers. This slice builds them against the approved components from the earlier slice and stops if the approach is rejected.
- **Product scope and platforms** — OS targets, input scope and whether any current feature is dropped. The career and tournament screens are presentation only; what they are played on is not this slice's to assume.
- **Save and cloud format** — the career payload's field set is proposed here and owned there, together with the migration question for browser saves. This slice does not decide a file format and does not write one.
