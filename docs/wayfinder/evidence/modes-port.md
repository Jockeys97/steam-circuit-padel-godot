# modes-port — evidence

Lane: **game modes** (drill, tournament, career progression) ported from the frozen
browser reference (commit `2979588`, `js/**` read-only) into headless-testable
Godot modules, with tests that assert the reference audits' own expectations,
persisted through the existing save module (`godot/src/save/**`, unedited).

Status: **green.** Six audits, 3 603 checks, 0 failures, 1 named not-ported check;
the engine harness is still `PASS 8/8`; `js/**` and `scripts/**` are unchanged.

## 1. What exists

| Path | What it is |
|---|---|
| `godot/src/modes/mode_tables.gd` | Generated tables: career shape, ramp, caps, metric aggregation, objective pool, 26 outfits, the four drill exercises, the drill's numeric constants |
| `godot/src/modes/career_rules.gd` | Pure rules: `seasonObjectives`, `matchObjective`, `careerRival`, `careerAiProfile`, `careerFixture`, `tournamentFixture`, `emptySeasonProgress`, `isUnlocked`, `outfitChallengeMet`, `metricValue`, `presto…`/`prestigio`, `ai_for_match`, `dictated_rivals` |
| `godot/src/modes/career_progress.gd` | The live career: season total, objective evaluation, star arithmetic, the four season outcomes, outfit awards |
| `godot/src/modes/tournament_rules.gd` | Board (`fixture`, `path`), AI tiers, round advance, trophy round, `match_config` |
| `godot/src/modes/drill_session.gd` | `DrillSession`: exercises, phases, attempts, `step(dt, input)` delegating to `godot/src/sim/sim.gd` |
| `godot/src/modes/drill_target.gd` | Seeded target placement, kind alternation, squash quality, zone grading |
| `godot/src/modes/drill_scoring.gd` | Attempt points, grade multiplier, score line, the four HUD metrics, record policy |
| `godot/src/modes/drill_seed.gd` | The seeded generator that replaces the reference's unseeded placement, with the defect and its anchors |
| `godot/src/modes/modes_save.gd` | Persistence: career, drill records, history, tournament round — all through `SaveStore` |
| `godot/src/modes/README.md` | The API map a UI lane reads |
| `godot/src/modes/data/modes.json` | GENERATED tables (runtime payload) |
| `godot/tests/modes/{tournament,outfit_challenges,save_progression,reference_grid,career,drill}_audit.gd` | The six audits |
| `godot/tests/modes/run_all.gd` | Aggregate runner (combined `PASS n/n`) |
| `godot/tests/modes/bench_step.gd` | Cost probe (no assertions; not in the runner) |
| `godot/tests/modes/data/reference-grid.json` | GENERATED: the reference functions' own outputs |
| `tools/modes-port/extract-modes.mjs` | The table/grid generator (reads `js/**`, writes the two JSON files) |
| `tools/modes-port/probe-drill.mjs` | Reads the reference drill's own §7/§8 values for the comparison |
| `tools/modes-port/run-modes-audits.sh` | The whole gate in one command |

## 2. Commands, exit codes, key lines

The gate, one command (scripts and logs are in `tools/modes-port/`):

```sh
cd /root/projects/steam-circuit-padel-pro && bash tools/modes-port/run-modes-audits.sh
```

```
tournament_audit           exit=0 PASS 48/48
outfit_challenges_audit    exit=0 PASS 89/89
save_progression_audit     exit=0 PASS 35/35
reference_grid_audit       exit=0 PASS 3130/3130
career_audit               exit=0 PASS 225/225
drill_audit                exit=0 PASS 76/76
modes-run-all              exit=0 PASS 6/6
bench_step                 exit=0
harness                    exit=0 PASS 8/8
```

Verbatim, the five invocations (run from the repo root; `$G` is the pinned binary):

```sh
$G=; # /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/modes/career_audit.gd          # exit 0, PASS 225/225
  --script res://tests/modes/drill_audit.gd           # exit 0, PASS 76/76
  --script res://tests/modes/tournament_audit.gd      # exit 0, PASS 48/48
  --script res://tests/modes/outfit_challenges_audit.gd   # exit 0, PASS 89/89
  --script res://tests/modes/reference_grid_audit.gd  # exit 0, PASS 3130/3130
  --script res://tests/modes/save_progression_audit.gd    # exit 0, PASS 35/35
  --script res://tests/modes/run_all.gd               # exit 0, PASS 6/6
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/   # exit 0, PASS 8/8
```

Key lines, verbatim:

```
# totals checks=3603 failures=0 not-ported=1 elapsed_ms=6699
ok tournament (48 checks, 3 ms)
ok outfit_challenges (89 checks, 4 ms)
ok save_progression (35 checks, 70 ms)
ok reference_grid (3130 checks, 73 ms)
ok career (225 checks, 22 ms)
ok drill (76 checks, 5414 ms)
# report max_float_diff=0.000000000000000222
# not-ported outfit_challenges/no_presentation_filter_selects_by_unlock: the port has no presentation script yet (UI lane owns them); checking js/ui.js would audit the reference, not the port
```

No `SCRIPT ERROR`, no engine `ERROR:` in any log (`grep -c "SCRIPT ERROR\|ERROR:" tools/modes-port/out/*.log` → all zero).

### The generator

```sh
node tools/modes-port/extract-modes.mjs
# js/data.js sha256=c63c496cd967663a5ec9f708e77b6f6948e4b523ba5b0e4280a40af642ec6403
# js/drill.js sha256=b3f346f65029e0a402eda2f6e73a1fd7897b0c1ee0c812e701eee911a89c8703
# wrote godot/src/modes/data/modes.json sha256=8dccc342d1665e7bce62e1fa6dae871706b4760eac01b62754f5e3d91334d68d
# wrote godot/tests/modes/data/reference-grid.json sha256=cfc1d2bedefdef76fedc47b69a6eb84aad434d7c49186e8056e18c223ef825e5
# seasons=3 objectives=6 outfits=26 exercises=4 exercisesById=precision,smash,rally,serve
```

### Cross-engine comparison (the reference side, run as the reference)

```sh
node scripts/drill-audit.mjs            # exit 0
node scripts/career-audit.mjs           # exit 0
node scripts/tournament-audit.mjs       # exit 0
node scripts/outfit-challenges-audit.mjs  # exit 0
node tools/modes-port/probe-drill.mjs   # exit 0
```

The reference drill's own report and the port's, side by side — identical, and
these are the target-independent observables (§3 of the audit):

```
precision tentativi=1 centrati=0 punti=2 voto=perfect colpi=1 energia=1.00
smash     tentativi=1 centrati=0 punti=2 voto=perfect colpi=2 energia=1.00
rally     tentativi=1 centrati=0 punti=6 voto=perfect colpi=2 energia=1.00
serve     tentativi=1 centrati=1 punti=10 voto=perfect colpi=5 energia=1.00
```

§7 diagnoses: reference `{precision: drillWhyOwnHalf, smash: drillWhyNoSmash,
rally: drillWhyRallyShort, serve: drillWhyFirstServe}` — the port's line is
`# report diagnosi=["drillWhyOwnHalf","drillWhyNoSmash","drillWhyRallyShort","drillWhyFirstServe"]`.
§8 samples: reference `[{vz:269.36094013769383,q:0},{vz:325.68027572024926,q:0},{vz:260.9394357494314,q:0}×4]`
— the port's `# report squash_samples=` line carries the same six values to the
last printed digit.

Tournament board: reference `percorso ["officina","abissale","orrery"], finale
"orrery", areneTotali 9`; port `# report rounds=["officina","abissale","orrery"],
finale=orrery arene=9`. Outfit audit: reference `completiConSfida 20, tettoPunti
11`; port `# report completiConSfida=20 outfits=26 tettoPunti=11`, same six metrics.

### Cost (host limit: 3 910 MB, 0 swap, one engine at a time)

`godot/tests/modes/bench_step.gd -- 20000` → `# bench steps=20000 elapsed_ms=2496.5
us_per_step=124.8`. The drill audit steps the engine ~45 000 ticks and costs
5.4 s of engine time; the whole aggregate is 6.7 s. Every invocation is
`flock`-wrapped with a `timeout` inside; no run held the lock for more than 40 s
wall clock (the longest gap was lock contention, not work).

## 3. Reference assertions: ported / not ported

### `scripts/drill-audit.mjs` → `godot/tests/modes/drill_audit.gd` (76 checks)

| Reference | Ported as | Note |
|---|---|---|
| `:52-61` no self-integrated ball flight, engine imported | `drill/step_delegates_to_the_engine_*`, `drill/no_self_integrated_ball_flight_in_the_drill_sources` | Structural: reads the port's own drill sources for the same four forbidden expressions |
| `:63-76` state is a match state | `drill/state_has_*`, `athlete_carries_its_stats`, `arena_carries_the_glass_physics`, `state_declares_its_mode`, `a_point_cannot_close_the_session` | Same seven fields, `pointsToWin > 1000` (the port uses the reference's own `Number.MAX_SAFE_INTEGER`, `js/drill.js:97`) |
| `:78-135` every exercise closes an attempt | 14 checks per exercise (`first_command_starts_the_attempt`, `the_engine_put_the_ball_in_play`, `a_target_was_placed`, `the_target_sits_in_the_opponents_half`, `an_attempt_closes_within_20_simulated_seconds`, `the_attempt_was_counted_once`, `points_are_valid`, `the_score_is_numeric`, `the_hud_wants_four_metrics`, `every_metric_is_populated`) | Same seeds (1234), same 2 400-frame budget, same `vicina` heuristic |
| `:137-147` target exercise keeps opponents frozen | `drill/precision/opponents_stay_frozen_or_they_intercept` | seed 99, tier 3, 400 frames |
| `:149-159` rival exercises let them play | `drill/{smash,rally}/the_opponent_must_be_able_to_play` | seed 55, 240 frames |
| `:161-165` exercise lookup and fallback | `drill/exercise_*_resolves`, `an_unknown_id_falls_back_to_the_first_exercise` | all four ids asserted, not three |
| `:168-196` every attempt carries a diagnosis, in both languages | `a_closed_attempt_carries_a_diagnosis`, `every_diagnosis_resolves_in_both_languages` | the language half reads the PORT's locale layer (`Locale.is_resolvable`, the port's equivalent of `t(key) !== key`) instead of `js/i18n.js` |
| `:198-227` squash scale continuous and monotone | `the_squash_scale_needs_three_landings`, `squash_quality_stays_in_scale`, `the_squash_scale_is_monotone` | six seeds, ≥3 samples, 1e-9 tolerance — see finding F2 |
| `:229-241` serve uses engine rules | `the_state_is_in_the_serve`, `the_player_serves_not_the_opponent`, `the_double_faults_are_shown` | seed 777 |

Port-only additions in the same audit: same-seed determinism (§10: identical
targets and identical attempt outcomes across two runs, a different seed places
different targets), and the exercise-table count (4).

### `scripts/career-audit.mjs` → `godot/tests/modes/career_audit.gd` (225 checks)

Ported: objective achievability inside its ceiling for 12 seasons × 3 objectives
(24 checks) and every match bonus (36 checks); `max` objectives not free
(`target < cap`) and counting ones reachable; every declared objective appears in
12 seasons (6); every metric has an aggregation rule, no objective declares its own
`agg`, every aggregated metric is read (12); the star rule — repeating a season
pays `10 × 3` bonus plus 3 season stars and advancing pays more (7, driving the
SHIPPED `award_objectives`/`apply_career_match` rather than the reference's local
model); the ramp's three caps, the monotone-in-season and monotone-between-seasons
rules and the speed-cap-vs-Legend bound (60 checks); every AI tier is a rung and
the final season is not before the last rival (5); the season calendar changes
court, survives one arena, falls back on an empty list (17).

Port-only additions (the progression the reference audit does not reach, because
it lives in `main.js`): the four season outcomes `trophy` / `promoted` / `repeat` /
`finale` with `finaleSeen`, `bestSeason` and the trophy count (18), the history
entry's pre-mutation trophy flag for all three modes (5), the outfit award path
(never pays the same outfit twice, counts athlete wins) (4), and the objectives
signature / regeneration rules (5).

### `scripts/tournament-audit.mjs` → `godot/tests/modes/tournament_audit.gd` (48 checks)

Ported: three distinct courts with the full table; prestige non-decreasing; the
final maximal; the 1/2/3-arena sweep with the `min(n, 3)` distinct rule (15); the
empty pool falling back to `ARENAS`; out-of-range rounds 3/4/10 resolving; at least
three AI tiers and each round harder than the previous. Port-only: `advance` for
won/lost rounds, the trophy round at `js/main.js:1398`, and one `match_config`
end-to-end.

### `scripts/outfit-challenges-audit.mjs` → `godot/tests/modes/outfit_challenges_audit.gd` (89 checks, 1 not-ported)

Ported: ≥20 challenged outfits (20 found); nothing behind the stars/trophies wall;
unique unlock keys; every points-derived trial winnable and every `at most` ceiling
below the cap; no two outfits with the same trial; ≥2 metrics per athlete with
three or more outfits; strict difficulty growth along
`circuit < legend < signature < mythic` (using the reference's own weight
function); the first rung needing neither a win nor a difficulty; the evaluator
(perfect match wins all 20, empty lost match wins none); `isUnlocked` reading the
won challenge rather than the wallet.

NOT PORTED — `scripts/outfit-challenges-audit.mjs:145-148` reads the TEXT of
`js/ui.js` with a regex to prove no presentation filter still selects outfits by
`unlock`. The port has no presentation script yet (that is the UI lane's slice), so
the check has no subject; auditing `js/ui.js` would audit the reference. Printed as
`# not-ported`, never counted as a pass.

### Not ported, named

| Reference | Why not |
|---|---|
| `scripts/unlockable-animation-audit.mjs` (whole file) | It decodes sprite sheets with `sharp` and asserts frame-strip geometry, alpha and luma for `oracolo` / `colosso`. No drill/tournament/career rule is involved; the Godot equivalent belongs to the character/assets lane. Its rule that every non-`base` outfit declares `sprites` is satisfied by the generated table (all 26 carry them), but it is an asset assertion, not a modes one. |
| `scripts/career-audit.mjs:140-181` as written | The reference's local `simulateCareer` re-implements the star machine. The port asserts the same two numbers (`30 + 3`, advancing > staying) through the shipped module instead — a stronger check of the same promise, stated in the audit header. |
| The drill loop's accumulator (`js/main.js:2111` unclamped vs `js/main.js:1196` clamped) and the mode entry points (`js/main.js:1096-1162`) | Session-loop and wiring rules, not modes rules; the port has no loop yet. Named here so the session lane inherits both anchors and does not "unify" them. |
| `matchState.careerSeason` / `careerMatch` / `careerRival` / `matchObjective` (`js/main.js:1140-1143`) | The port's `SimState` (`godot/src/sim/state.gd`) has no such fields and this lane may not edit it. The career context is passed alongside the state instead (`CareerRules.career_fixture`, `CareerProgress.award_objectives`). Recorded rather than worked around silently. |
| Drill display athletes `playerMateAthlete` / `opponentAthlete` / `opponentMateAthlete` (`js/drill.js:105-107`) | Same reason: the port reads them from `state.lineup` via `DrillSession.athletes_for_display()`. |

## 4. Findings (no core file was edited)

**F1 — the reference's drill placement is unseeded; cross-engine drill digests are
therefore not comparable.** `js/drill.js:155`, `:159`, `:160` draw from global
`Math.random`; `grep -c 'nextRandom(' js/drill.js` is 0. The port places targets
from an injected seed (`godot/src/modes/drill_seed.gd`) and proves reproducibility
in two runs. Measured consequence: everything that does not depend on the target
matches the reference exactly (the report above, the diagnoses, the six impact
velocities to 13+ significant digits), and the target positions do not — no
cross-engine digest is claimed. `js/**` may not be edited by this lane, so this
stays a finding.

**F2 — the reference audit's squash claim is currently vacuous, in the reference
as well.** `scripts/drill-audit.mjs:198-227` asserts the scale slides between the
two measured references (`SQUASH_FLAT` 255, `SQUASH_LOW` 185, `js/drill.js:38-39`),
but every landing the scenario produces has `|vz| ≥ 260.9394357494314`, above
`SQUASH_FLAT`, so `squashQuality` clamps to `0` in all six samples and
"non-increasing" is satisfied by six zeros. `tools/modes-port/probe-drill.mjs`
prints the same six values from the reference. The port reproduces the values, the
clamp and the vacuity; the monotonicity assertion is ported as written and
protects nothing today. No code change was made on either side.

**F3 — the career payload the save module has to carry.** `SaveSchema.CAREER_DEFAULTS`
(`godot/src/save/save_schema.gd:83-107`) lists the 16 fields of `js/ui.js:12-36`;
`outfitsWon` and `athleteWins` are created lazily by `awardOutfitChallenges`
(`js/ui.js:629-630`) and are therefore absent from the defaults. The round trip
works anyway because the store's merge only supplies missing keys and never drops
stored ones — verified by `save_progression/every_career_field_reloads`,
`career_round_trips_byte_for_byte`, `outfits_won_survives_the_round_trip`,
`athlete_wins_survives_the_round_trip`. No schema change is requested; the exact
field list (18 fields, `ModesSave.CAREER_FIELDS`) is reported for the save lane.

**F4 — a presentation-only divergence, deliberate.** The reference's
`drillScoreLine` (`js/drill.js:466-472`) builds its line from display literals
(`"PERFECT ⭐"`, `"GOOD"`, `"EARLY"`, `"LATE"`) and is never called —
`grep -rn drillScoreLine js/` finds the definition only. The port keeps the
function and returns `shot:<grade> · <points>`, the message id the simulation
already emits for the same grade (`sim.gd`'s `showShotFeedback`), so no literal
enters a presentation module. Same for the history entry: `js/ui.js:1399-1414`
stores `t()`-resolved names, the port stores ids.

**F5 — engine gotcha, fixed and recorded.** Godot 4 has no `String` constructor for
an int: `String(objective["target"])` is a runtime error, not a conversion. It was
reached in `career_progress.gd`'s `objectives_signature` while porting
`js/ui.js:58-60`, where the target is a number; the fix is `str(...)`. Before the
fix the error was swallowed by the audit (the signature came back empty, the
objectives were regenerated on every call, and the star numbers still happened to
come out right) — which is exactly why `career/objectives_signature_matches_the_reference_triple`,
`a_matching_triple_is_not_regenerated` and `regeneration_restarts_the_season_stars`
are now explicit checks. No `SCRIPT ERROR` line remains in any log.

## 5. NOT DONE

- **No mode UI exists.** Drill, tournament, career, profile, challenges and history
  screens are a separate lane's slice; this lane delivers the rules those screens
  read, and `godot/src/modes/README.md` is written for that consumer.
- **No mode-entry wiring.** `startMatch`'s per-mode assignment (`js/main.js:1096-1162`),
  the drill's own loop and accumulator (`js/main.js:2105-2121`) and the screen
  router are not ported here (see the named exclusions in §3).
- **No captures, no screenshots, no frame-rate claim.** Nothing in this lane
  renders.
- **No claim of cross-engine drill digest parity** — impossible while the
  reference's placement is unseeded (F1).
- **`unlockable-animation-audit.mjs` not ported** (assets lane, §3).
- **`js/ui.js`'s dead-filter source check not ported** (no port presentation
  script yet, §3).
- **History/profile/tournament screens' string coverage** (i18n lane) not touched:
  no literal was introduced, and `Locale.is_resolvable` is used read-only.
- The tournament round's persistence is exposed
  (`ModesSave.save_tournament_round`) but nothing calls it yet — the caller is the
  session lane.

## 6. File inventory (bytes, sha256)

```
   15893  e7b93ea454f2c6424f1ca6baf9aeb79ff171b7caabc24b06c79f8a42e5eadcae  godot/src/modes/career_progress.gd
   14820  e3861d8e910a6fbd61d77a9ca24f5188cbcf380cb5f36857d7060c874ea7de39  godot/src/modes/career_rules.gd
    4378  52581c09017d5db15c2150dab295bb3d33e13083903888e9f796bf780ce46d4b  godot/src/modes/drill_scoring.gd
    2757  0726112757e06345bcba9d54451f3872f0b14ee20f3fb91772d7dd2079ee640d  godot/src/modes/drill_seed.gd
   15015  81f03e467420c2912eb9e63bcec2cc98238ca67150946355cbce108258bdfddc  godot/src/modes/drill_session.gd
    5070  2c1b900d46ccc5a7fa25cb67f68c4795923721675324cf7118eb4d29ea32ccbe  godot/src/modes/drill_target.gd
    6377  d0b4dbf79983eac41a52042e821eb07ce5d94a045a40bbd2ed7cddf90a3bda7b  godot/src/modes/mode_tables.gd
    9315  cdf7db879e4fb776ae640c05f370f45cf2649eb1095de56d89c8e78494fc7c97  godot/src/modes/modes_save.gd
    4013  91b16567a9e67af4b7b65e2184a3923a7aae49e3dbbec1932699d024b2440715  godot/src/modes/tournament_rules.gd
    4989  9256ce32c97916063d80558791b8a814eb4cd1c633c84df1fc6e7667d35b2d1b  godot/src/modes/README.md
   11624  8dccc342d1665e7bce62e1fa6dae871706b4760eac01b62754f5e3d91334d68d  godot/src/modes/data/modes.json
    1689  7707e551a2eef256a387a9ada648bcd52565807776562914c673494313d39e4e  godot/tests/modes/bench_step.gd
   20216  1e8356291e3954a1f344c77f9f9c613f76d7207ab290956607575d2588604093  godot/tests/modes/career_audit.gd
   17180  ca4457c125bbb6546b0a91f2f8ecfbde47bc53dba845a937d9f909fba8dd708c  godot/tests/modes/drill_audit.gd
   10412  e05fe5d0de63b8f3f5465ef3248551620211c8fa82bee31912a78a2140396e0a  godot/tests/modes/outfit_challenges_audit.gd
    8298  00bda54069787903a560cc67a7fcce937ea2631c085d5650f129aa229e6aacec  godot/tests/modes/reference_grid_audit.gd
    3304  0b335794322740f5a3523e48d3fba7984f3698ea64a361ca7fd2f9e5f177c227  godot/tests/modes/run_all.gd
    9808  9f4849bc929217d191ebf74e548d66efd778f1596a558d6e459e95162a004952  godot/tests/modes/save_progression_audit.gd
    6898  3d74d4a5f5db0e8edfd1188a82c278141fb0a6eff465d790012901572c527fbf  godot/tests/modes/tournament_audit.gd
  178753  cfc1d2bedefdef76fedc47b69a6eb84aad434d7c49186e8056e18c223ef825e5  godot/tests/modes/data/reference-grid.json
    9159  241c5a17f2d1b473bf97cf39d1c2976cdacb302e9867b8338d6ab40a7af2f9ad  tools/modes-port/extract-modes.mjs
    3458  9b133be895684a08b2a283d9d3b451d2419c2569040d66ca0966fd609fa88de5  tools/modes-port/probe-drill.mjs
    1486  110eb8600dce02e05b2af9e06b13e68557ad2a7824d7ecce541e7e37306a8b21  tools/modes-port/run-modes-audits.sh
   22954  (this file is self-referential — its hash is captured only in the
          generated inventory above; see `tools/modes-port/out/gate-table.txt`
          for the run that produced the rest)
```

Logs kept under `tools/modes-port/out/`: `gate-table.txt`, `modes-run-all.log`,
the six per-audit logs, `bench_step.log`, `harness.log`, `extract-modes.log`,
`probe-drill.log`, and the four reference-side logs `web-{drill,career,tournament,outfit-challenges}-audit.log`.

## 7. Boundary

- Written only inside: `godot/src/modes/**`, `godot/tests/modes/**`,
  `tools/modes-port/**`, `docs/wayfinder/evidence/modes-port.md`.
- `js/**` and `scripts/**` unchanged (`git status --porcelain js scripts` shows only
  another lane's untracked `scripts/parity-digest.mjs`). `godot/src/sim/**`,
  `godot/src/save/**`, `godot/project.godot` and `godot/tests/audits/**` were read,
  never written; running the engine touches `.uid` sidecars in other directories,
  which is the engine's own import bookkeeping, not a source edit.
- No commit, no push, no deploy, no paid spend.
