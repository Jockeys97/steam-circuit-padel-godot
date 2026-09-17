# Mission state

Status: RUNNING (NOT complete, NOT waiting — unblocked technical work remains)
Phase: **tick 19 — three lanes dispatched 2026-09-16 15:20 CEST** (mode playability + UI
text repair; a second independent review of the tick-18 changes; Opus 5 on cross-engine
match parity). The quick-match slice is green in BOTH builds at `PASS 211/211` by my own
runs, with the three HIGH defects from the first review fixed and each one covered by a
test. The scheduled job stays paused; this interactive session is the single live driver.

## Tick 19 outcome (in progress) — cross-engine MATCH parity proved: IDENTICAL

The strongest correctness claim of the mission, and I reproduced it with my own run of the lane's
driver (`bash tools/parity-godot/run-match-matrix.sh`):

| match | seed | ticks compared | digest (both engines) | verdict |
|---|---|---|---|---|
| M1 plain, to result | 12345 | 22,210 | `69a10a20…` | IDENTICAL |
| M2 double fault | 999 | 12,813 | `c2cd281d…` | IDENTICAL |
| M3 wall/glass + net-cord | 11 | 16,858 | `6917dfdf…` | IDENTICAL |

**My own run's key lines:** `PARITY-COMPARE RESULT=IDENTICAL firstTick=- field=- comparedSamples=16858 comparedFields=21 digestSha256-identical`;
`MATCH-COMPARE RESULT=IDENTICAL digest=IDENTICAL events=IDENTICAL coverage=OK sampledTicks=16858/16858`;
`# event-counts js: glass=25 message=144 net-cord=9 result=1 set-closed=1 strike=26 wall=13` vs
`# event-counts gd:` the same; a JS-to-JS reproducibility control was byte-identical.

Coverage is machine-checked rather than assumed (the run fails as NOT-DONE unless net-cord, glass
and wall events actually occur), and the comparison was mutation-tested on real artifacts — a
float mutation turns it red with `FIRST-DIVERGENCE tick=012812 field=ball.x`, and an event
mutation turns it red while the digest stays identical, so the gate is not vacuous.

**What this does NOT prove** (the lane recorded it; I agree): three matches are not all matches
(other seeds, tie-breaks — all three sets were won 0-6, tournament rounds, human input, and any
field the digest does not print are outside the gate); "identical" means agreement at the digest's
six printed decimals, not bit-identical float64; no frame-rate, latency or feel claim follows.


## Tick 18 outcome — CEO-verified: review highs fixed, demo rule on screen, modes navigable

The integration lane died mid-flight and was resumed by a continuation lane; I verified every
number below with my own runs, and the lane was steered twice (once to stop it recording a
`PASS` next to a runtime error, once to make its gate fail on runtime errors at all).

| Item | Verdict | CEO verification (my own runs) |
|---|---|---|
| Slice test, full build | DELIVERED | **My own run**: `PASS 211/211` (was `FAIL 130/131` when the lane died), exit 0. |
| Slice test, demo build | DELIVERED | **My own run**: `PASS 211/211` with `-- --demo`, exit 0. |
| Engine harness + input suite | GREEN | **My own runs**: harness `PASS 8/8`; input `PASS 4/4`, 308 checks, 0 failures. |
| Ten rules audits under the new strict runner | DELIVERED | **My own run**: `PASS 10/10`, exit 0, `# totals checks=221 failures=0 not-ported=0 expected-checks=221 mismatched=[] audits_failed=0` — the new pinned per-audit counts agree, so the aggregate is now computed from results rather than a constant. |
| HIGH-1 packaged athletes | FIXED + TESTED | Load path moved to `res://assets/athletes/volpe-rigged.glb`; the lane added an excluded-path scan over `godot/game/**` + `godot/src/**` and a byte-search of both real packs. I reproduced the finding myself before the fix (pack contains `res://prototypes: 0` files). |
| HIGH-2 frame-rate dependence | FIXED + TESTED | `# FRAME_CLOCK 30fps=120 60fps=120 240fps=120` — one wall second of three different frame patterns yields the same 120 fixed ticks. |
| HIGH-3 dropped input edges | FIXED + TESTED | press+release inside one rendered frame still fires the shot (7 named checks). |
| Demo rule ON SCREEN | DELIVERED | **My own run**: `menu-full.png` 137,938 B vs `menu-demo.png` 119,601 B, 281,168/921,600 px differ (30.51 %). **My own visual inspection**: the demo menu lists exactly 2 athletes and 1 arena, with the three modes locked and labelled "In the full game"; the full menu lists 6 athletes, 9 arenas, 4 opponents. |
| Two false-green generators | FIXED | `audit_base.gd` fails `checks == 0`; `run_all.gd` verdicts from results and pins per-audit counts; permuting the count table turned the aggregate RED, as intended. |
| UI text defects I found by reading the renders | OPEN, handed to tick 19 | The demo mode row clips "In the full game" → "In the full ga"; accented Italian renders as ASCII (`MODALITA'`, `gia'`); stat labels mix languages (`skill/speed/power` next to `vel/pot/ctrl`). |

**Honest limits recorded by that lane:** no fresh export pair was rebuilt (the capture switch writes
into `res://game/out/`, unwritable inside a packed build), so the demo-vs-full diff is a
project run one build flag apart — the export-internal rule was already proven separately by the
packaged self-check (`PASS 18/18`). The engine's `ERROR: 7 resources still in use at exit` is
allowed *by name, once* by the gate, with its cause named (`static var _shader` in
`godot/src/character/outfit_catalogue.gd:95`) and left unfixed because it is outside that lane's
scope.


## Tick 17 outcome — CEO-verified: nine arenas, modes, packaged builds, input models

| Item | Verdict | CEO verification (my own runs) |
|---|---|---|
| crew-arena: arena library + arena selection in the menu + the two remaining visual defects | DELIVERED | **My own run**: slice test `PASS 136/136` (was 106/106), harness `PASS 8/8`. Nine per-arena renders exist in `godot/game/out/arena-<id>.png`, all 1280×720, real bytes (185–190 KB each). **My own visual inspection**: `arena-abissale` is a complete court — net, side glass, and a **rear glass wall that now reads as a wall**, not a void (the defect I reported is fixed there). `arena-clockwork` renders with opaque grey side barriers, a yellow ring motif and a magenta gradient backdrop — clearly a different arena, but its enclosure does not read as glass; flagged for the next lane to check against that arena's reference scenery spec. |
| crew-modes: drill / tournament / career rules in `godot/src/modes/**` + six audits | DELIVERED | **My own run**: `res://tests/modes/run_all.gd` → `PASS 6/6`, `# totals checks=3603 failures=0 not-ported=1`, 1.2 s. Evidence `modes-port.md` 23,156 B. The lane also found that the **reference's own** drill uniqueness assertion is vacuous (all six landings share `|vz| ≥ 2`), recorded as a finding rather than papered over. |
| crew-export: export presets, demo content rule, packaged builds | DELIVERED (artifact-level verified) | Three exports produced with exit 0: `godot/build/linux-x86_64/padel.x86_64`, `.../linux-x86_64-demo/padel-demo.x86_64` (+ 55,371,740 B `.pck`), and a demo self-check build. The binary is a real stripped ELF x86-64 (73,519,416 B). Evidence `demo-and-export.md` 28,212 B. My own run of the exported artifact is still owed (see next action). |
| crew-input: focus navigation, remapping, accessibility models + locale-resolution of input strings | DELIVERED | **My own run**: `res://tests/input/run_all.gd` → `PASS 4/4`, `# totals checks=308 failures=0 not-ported=7`; the 7 unported lines are DOM-only assertions (documented, never counted as passes). sha256 reproduced for `focus_nav.gd`, `accessibility_settings.gd`, evidence file. |
| No drift | GREEN | `git status --porcelain --untracked-files=no` empty throughout; HEAD `2979588`; no commits/pushes; zero paid spend, 0 Meshy credits. |

**Standing caveats, unchanged:** nothing here is a visual or feel approval; software-GL renders
cannot support any frame-rate claim; the Steam path is a mock with an unverified swap point; the
near-half framing still clips the athletes' legs (owner gate).

## Tick 18 addendum — the independent review found two real highs the self-reports missed

`docs/wayfinder/evidence/independent-review.md` (crew-review, read-only; I reproduced its
top claims myself). It confirmed every suite's green line **and** found defects that all the
green suites were blind to — which is the point of spending a lane on review:

- **HIGH — the packaged build loses the athletes.** `godot/game/court.gd:96` loaded the athlete
  model from `res://prototypes/…`, a path every export preset excludes, so the shipped build
  silently fell back to capsules while the editor-side assertion (`ResourceLoader.exists`) stayed
  true. The export evidence's claim that the exclusion "cannot remove game content" was false; I
  appended a dated correction to `demo-and-export.md` rather than leaving it standing.
- **HIGH — frame-rate dependence.** `match_controller.gd:285-295` advanced the simulation once per
  *rendered frame* instead of the reference's fixed 120 Hz accumulator (`js/main.js:1196-1205`),
  and the declared `MAX_SIM_STEPS` was never read.
- **HIGH — dropped input edges** when render fps exceeds the 120 Hz tick (`match_controller.gd:298-313`),
  where the browser keeps the hit queued until a substep consumes it.
- **MEDIUM ×6**, including two false-green generators: `game_slice_test.gd` lacks the
  section-completion guard, and `godot/tests/audits/audit_base.gd:104-108` counts an aborted audit
  as green while `run_all.gd` prints its total from a constant.

All three highs are in the integration lane's files; it has been steered with the reproduction
requirement and the allowlist extension for the audit-runner fix. The claim table in the review
also flags two stale numbers (`quick-match-playable.md` says 106/106 while its own §11.3 says 136;
the slice-test count in the review's own table) — fixed or listed by that lane.

## Tick 15 — INTERACTIVE SESSION, claim written BEFORE dispatch (2026-09-16 11:45 CEST)

**Ownership transfer.** `hermes --profile h-dev-work cron list` shows the Padel job
absent from the active list; `cron/jobs.json` confirms `f796600cf451` is
`"state": "paused"`, `enabled: false`, paused 10:08:53, last run 09:57:22 `ok`,
`fire_claim: null` — no live execution and no survivor to coordinate with. Overlap
check at 11:43 (`ps aux --sort=-%mem`, `pgrep -af Godot`): **no Godot, node or python
process of this repository is alive**; the only Godot-family match was this session's
own bash wrapper. Unrelated live work was left alone (DemonPet's cron worker and its
20-minute job `71b2c5a9de89`, the Scrappy servers, the two Hermes gateways, the two
desktop `serve` sessions). Host memory at claim: 3,910 MB total, **0 swap, 778 MB
available** — the one-heavy-process rule stays in force. Routing re-verified from the
profile `delegation:` block: provider `opencode-go`, model `deepseek-v4.1-flash`,
matching the charter and the user's explicit request; no credential, provider or
profile setting touched.

**Doctrine change for this session (recorded, reversible).** Previous ticks ran one
engine lane per *tick* because parallel heavy lanes OOM-killed the host. That cost a
whole tick per engine job. This session keeps the memory rule but removes the
throughput penalty with a **mutex instead of a wait**: every heavy process (any Godot
binary, any full-resolution Python imaging run) must be invoked as
`flock -w 900 /tmp/padel-godot.lock <command>`. Lanes may therefore run in parallel;
the engine is used by exactly one process at a time by construction. The lock is a
host resource, not a repository file.

**Lanes, disjoint write allowlists, four crews.** The CEO keeps `docs/mission/**`,
`docs/wayfinder/map.md` and every tracked file. `godot/project.godot` has exactly one
owner (crew-papa) because it is the only shared file in the set.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-papa (INTEGRATOR) | **S2 tracer bullet: a runnable quick match in Godot 3D.** `godot/game/**` (new): court/glass/net mesh from the arena-spike geometry, ball + four paddles driven by `godot/src/sim/sim.gd::update_match` on the fixed 120 Hz tick, provisional camera preset, keyboard+gamepad input, HUD (score, energy, shot feedback, point log), a main menu that starts a quick match, and a headless scripted playthrough that exits non-zero unless points are scored through the real ported core. Owns `godot/project.godot` (additive input map only). | `godot/game/**` (new dir), `godot/project.godot` (additive only), `godot/tests/game_slice_test.gd` (new), `docs/wayfinder/evidence/quick-match-playable.md` |
| crew-quebec | Gate 2 completion: the remaining dependency-linked build tickets (S3–S13) so no slice is left as an intention. | `docs/implementation/tickets/**` (new files only), `docs/implementation/PLAN.md` (ticket links only) |
| crew-romeo | S10 first buildable item: the Godot audio module consuming the verified `tools/audio-port/event-map.json` — bus/mixer data, the 10 baked WAVs wired as streams, an event→stream resolver, and a headless test that fails on drift. | `godot/src/audio/**` (new), `godot/tests/audio_port_test.gd` (new), `tools/audio-port/**` (new files only), `docs/wayfinder/evidence/audio-module-godot.md` |
| crew-sierra | S13 first item, engine-free: the locale port contract from `js/i18n.js` — key set, reference strings, message-id coverage, and a drift test against the live `js/i18n.js`. | `godot/src/locale/**` (new), `tools/i18n-port/**` (new), `docs/wayfinder/evidence/i18n-port-contract.md` |

Constraints in force for every lane: `flock` around every heavy process; no two heavy
processes ever, one Godot instance at a time; `js/**` and `scripts/**` untouched
(frozen harness `scripts/parity-digest.mjs` must stay byte-identical, sha256
`2b24dd26…`); no commits, pushes, deployments; zero paid spend, zero Meshy credits;
two attempts per gate maximum; write evidence to disk incrementally so an OOM kill
still leaves useful partial artifacts. `run/main_scene` in `godot/project.godot` must
NOT change — `timeout 120 env -u DISPLAY … --headless --path godot/` must keep
printing `PASS 8/8`, so the game scene is launched by explicit scene argument.

**Success bar for this session:** a launchable Godot build that plays a quick match
against the AI using the ported deterministic core, with audio and localization wired
to the verified contracts, evidence on disk, and every claim re-run by the CEO. Luca's
feel/camera/gameplay verdict remains an open human gate, as does the parity gate.

## Tick 15 outcome — CEO-verified: the port PLAYS and RENDERS a full quick match

Four lanes dispatched; every claim below was re-run or re-read by the CEO from disk,
never taken from self-report.

| Item | Verdict | CEO verification (my own runs) |
|---|---|---|
| crew-papa: playable slice `godot/game/**` (28 files: `Main.tscn` menu, `Match.tscn` match, `match_controller.gd`, `court.gd`, `hud.gd`, `input_map.gd`, `main_menu.gd`, `scripted_player.gd`, `run.sh`, 5 captures in `godot/game/out/`) + `godot/tests/game_slice_test.gd` | DELIVERED (lane status was recorded `unknown` — the delegation owner exited before writing a terminal result, but the work is on disk and green) | I ran the slice test myself: **`PASS 62/62`, exit 0**, on the real match scene through the ported core (checks include serve/bounce/point events, HUD score/game/result/log rendering, seed+tier debug line). I re-ran the harness: **`PASS 8/8`, exit 0**. `run/main_scene` unchanged. A capture log shows a full scripted match reaching a real result (25,962 ticks, 24 points, winner set, 305 MB peak, 33 s wall). I decoded the five PNGs myself: all **1280×720**, real bytes, not blank. |
| crew-papa's evidence file `docs/wayfinder/evidence/quick-match-playable.md` | **MISSING** | Not on disk. Folded into the tick-16 repair lane as an owed deliverable. |
| crew-quebec: Gate 2 completion — 11 new build tickets (S3–S13) in `docs/implementation/tickets/**`, plus ticket links in `PLAN.md` | DELIVERED | **13/13 tickets carry all 8 required sections** (my own grep count: `sim-rules-audits`, `hud-and-menu`, `camera-feel-integration`, `nine-arenas`, `athlete-models`, `drill-3d`, `tournament-career`, `audio-port`, `saves-steam-cloud`, `demo-export-presets`, `accessibility-locales-performance`, plus the two pre-existing). sha256 spot-check reproduced. The lane also reported fixing 3 real off-by-one source anchors it had written. |
| crew-romeo: Godot audio module (`godot/src/audio/audio_port.gd` 16,711 B sha `39de40cb…`, `godot/assets/audio/**` 10 WAVs + `.import` + `padel_audio_bus.tres`, `godot/tests/audio_port_test.gd` 44,409 B sha `f8f6fbb0…`, `tools/audio-port/sync-godot-audio.mjs`, evidence 23,769 B) | DELIVERED | sha256 reproduced. **My own runs**: `node tools/audio-port/sync-godot-audio.mjs --check` → exit 0, `RESULT: PASS — contract and engine copies agree`; `node tools/audio-port/verify-event-map.mjs` → exit 0, 7/7 injected drifts caught. |
| crew-sierra: locale contract (`godot/src/locale/locale_data.gd` 68,954 B `5f16413e…`, `locale.gd` `c20be759…`, `tools/i18n-port/**` incl. the drift test `61ccbef1…`, evidence 25,784 B) | DELIVERED | sha256 reproduced. **My own run**: `node tools/i18n-port/verify-i18n-port.mjs` → exit 0, `OK — the port's locale data matches js/i18n.js byte for byte … all 11 injected drifts were caught. Ledger: 10 entries`; 688 keys in both `it` and `en`. |
| No drift | GREEN | `git status --porcelain --untracked-files=no` empty throughout; HEAD still `2979588`; no commits, pushes or deployments; zero paid spend and 0 Meshy credits; no human gate self-approved. |

**Defects I found by inspecting the renders myself (independent visual verification, not a
lane's claim).** The menu is legible (title, four opponent tiers, six athletes, arena line,
play/exit, control legends) but has no visible selected-state affordance; the in-match frame
really shows a 3D court, net, two athletes, ball, side glass, scoreboard, energy bar, shot
feedback and an event log — plus these concrete defects: the players' rackets render as
oversized pink bars clipping the scene; two stray cyan bars lie unattached on the court; the
rear glass walls are missing; the net has no mesh; the top-left debug line overlaps the
athlete name; and the event log prints raw message ids (`controlMsg:roleBackPos`). The locale
lane independently found the same id-leak class from the data side (**22 of 108 ids would
print raw**, exit 1 under `node tools/i18n-port/hud-coverage.mjs --fail-on-leak`) — the
cross-lane agreement is why this is treated as a real defect and not a rendering artefact.

**What this changes.** The port is no longer a simulation with prototypes: it is a runnable
3D game loop — menu → quick match → rally → points → result — driven by the parity-verified
core, with audio and localization implemented underneath it. Still absent, stated rather than
smoothed: nothing is wired (HUD still prints raw ids, no sound is requested by the match),
no athlete animation, no second arena, no drill/tournament/career, no export or packaged
artifact, and Luca's feel/camera/gameplay verdict is untouched.

## Tick 16 — claim written BEFORE dispatch (2026-09-16 12:55 CEST)

Ownership unchanged (scheduled job still paused; this session is the single live driver;
no other process of this repository was alive at claim). Host memory at claim: 3,910 MB
total, 0 swap, **432 MB available** — the one-heavy-process rule stands, enforced by the
shared `flock -w 900 /tmp/padel-godot.lock` mutex so lanes parallelise without ever running
two engines. Routing unchanged: `opencode-go` / `deepseek-v4.1-flash` for native lanes; the
Claude Code (Opus 5) lane runs on the granted Claude subscription. Recorded pitfall:
`--permission-mode bypassPermissions` is **refused as root**, so Claude print-mode runs must
use `--permission-mode auto`.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-papa-2 (INTEGRATOR) | Repair and finish the playable slice: route the HUD through the verified locale module so **zero** raw message ids reach the screen (`node tools/i18n-port/hud-coverage.mjs --fail-on-leak` must exit 0; 22 leaks today), wire the verified audio module into the match (asserted on engine state, since the host has no sound device), fix the visual defects listed in the tick-15 outcome (broken rackets, stray court bars, missing rear glass, untextured net, overlapping HUD text), re-render captures and write the slice's missing evidence file. | `godot/game/**`, `godot/tests/game_slice_test.gd`, `docs/wayfinder/evidence/quick-match-playable.md` |
| crew-audits | Slice S3: port the reference's rules audits to Godot under their original names (wall rules, court speed, match format, shot quality, shot balance, smash input, difficulty, AI attack, lineup, controller tactics) as headless tests asserting the reference's own expectations. A real divergence found is a *finding* (the parity-verified core is not theirs to edit). | `godot/tests/audits/**` (new), `godot/src/audits/**` (new), `tools/audit-port/**` (new), `docs/wayfinder/evidence/rules-audits-port.md` |
| crew-save | Slice S11 seam: versioned corruption-safe `user://` saves matching the reference's real persisted model, plus narrow achievement/cloud interfaces over an honest mock backend with the exact GodotSteam swap point and its unverified API assumptions documented. No live Steam claim, no credential use. | `godot/src/save/**` (new), `godot/src/steam/**` (new), `godot/tests/save_steam_test.gd` (new), `docs/wayfinder/evidence/saves-steam-seam.md` |

**Open human gates carried forward (unchanged, not self-approved):** camera/feel verdict,
UI approach verdict, parity gate definition, court aspect (800×508 px = 1.575, not 20:10),
roster order, arena art direction, product scope/platforms, demo gate, live Steam App ID,
and Luca's play verdict on the build itself.

## Tick 16 outcome — CEO-verified: the slice is repaired, wired, and the audits are ported

| Item | Verdict | CEO verification (my own runs) |
|---|---|---|
| crew-papa-2: repair + wiring in `godot/game/**` (`match_audio.gd` new 11,966 B, `court.gd` 17,443 B, `hud.gd` 26,251 B, `match_controller.gd` 18,413 B, `tools/gen_hud_labels.py`, `tests/game_slice_test.gd` 36,787 B) and the missing evidence file | DELIVERED | **My own runs**: slice test **`PASS 106/106`** exit 0 (was 62/62); harness **`PASS 8/8`**; `node tools/i18n-port/hud-coverage.mjs --fail-on-leak` → exit 0, `108 ids — 108 get a readable line, 0 print the id` (was 22 leaks, exit 1). **My own visual inspection of the re-rendered frames**: rackets are normal-sized, no stray court bars, net has a real lattice, top-left HUD no longer overlaps, event log shows Italian sentences instead of `controlMsg:roleBackPos` — five of the six defects I reported are gone. |
| crew-audits: slice S3 — ten rules audits ported (`godot/tests/audits/*.gd` + `run_all.gd`, `godot/src/audits/**`, `tools/audit-port/**`, evidence `rules-audits-port.md` 12,900 B `ba44f176…`) | DELIVERED | My own run of `res://tests/audits/run_all.gd` under the engine lock: **`PASS 10/10`, 221 checks, 0 failures, 0 not-ported, exit 0** (3 m 13 s). The four statistical audits reproduce the reference's printed numbers (difficulty 280.9/313.7/352.9/378.1 px/s, shot-balance lob depths 210.283/172.117/119.304, court-speed 211.6/520.4/580.2, lineup 428.2/0.529), not just its bands. Zero divergences found; nothing in `js/**` or `scripts/**` touched. |
| crew-save: slice S11 seam (`godot/src/save/**` 4 files, `godot/src/steam/**` 7 files, `godot/tests/save_steam_test.gd` 35,499 B, evidence 21,349 B) | DELIVERED | **My own run**: `res://tests/save_steam_test.gd` → **`PASS 137/137`** exit 0. Save format mirrors the reference's five browser storage keys, refuses unknown schema versions, quarantines corrupt files; the Steam backend is a mock with the real GodotSteam swap point at `steam_backend_factory.gd::create()` and 7 explicitly unverified API assumptions. No live Steam claim anywhere. |
| No drift | GREEN | `git status --porcelain --untracked-files=no` empty; HEAD `2979588`; no commits/pushes/deployments; zero paid spend, 0 Meshy credits. |

**Still open after tick 16 (stated, not smoothed):** the rear glass wall still does not read as
glass in the rendered frame even though the alpha path was fixed — so that is now a *visual
outcome* problem, not a material-flag problem; a HUD gauge is clipped by the left screen edge;
the near-half framing cuts the athletes at the waist (owner-frozen composition, not an agent
decision); no arena other than the default exists; no mode UI; no packaged build.

## Tick 17 — claim written BEFORE dispatch (2026-09-16 13:25 CEST)

Ownership unchanged (scheduled job paused; single live driver; no other repository process
alive at claim). Host at claim: 3,910 MB total, 0 swap, **466 MB available**; one heavy
process at a time, enforced by the shared `flock` mutex. Routing unchanged
(`opencode-go` / `deepseek-v4.1-flash` for native lanes). The Claude Code (Opus 5) athlete
lane finished its run on the granted Claude subscription; its artifacts are verified separately.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-arena (INTEGRATOR) | Slice S6 first tranche: a data-driven arena library building all **nine** arenas from `js/data.js`'s `ARENAS` table, arena selection in the existing menu, and the two remaining HUD/court visual defects (rear glass must actually read as glass, proven by sampled pixels; HUD gauge clipped at the screen edge, with safe-area assertions). Camera composition stays untouched (owner gate). | `godot/game/**`, `godot/tests/game_slice_test.gd`, `docs/wayfinder/evidence/quick-match-playable.md` (append) |
| crew-modes | Slices S8/S9 logic: drill, tournament and career progression rules ported from the reference into plain headless-testable modules under `godot/src/modes/**`, persisted through the existing save module, with tests asserting the reference audits' own expectations. UI is a later lane's slice. | `godot/src/modes/**`, `godot/tests/modes/**`, `tools/modes-port/**`, `docs/wayfinder/evidence/modes-port.md` |
| crew-export | Slice S12: export presets for a desktop build plus a demo build enforcing the reference's demo content rule (two athletes, one arena, quick match only) with a proven filter, and an **actual packaged Linux build** as the first launchable artifact. Export-template download for exactly 4.7.2 is permitted toolchain acquisition. | `godot/export_presets.cfg`, `godot/build/**`, `godot/tests/build/**`, `tools/export/**`, `docs/wayfinder/evidence/demo-and-export.md` |

## Tick 14 — claim written BEFORE dispatch (2026-09-16 09:40 CEST)

Overlap check at 09:39 (`ps -eo pid,ppid,lstart,rss,cmd --sort=-rss`): **no Godot,
node or python process of this repository is alive**, so this run is the only live
driver and no tick-13 crew survived. The only other live work is unrelated
(DemonPet's two cron worker processes, the Scrappy servers, the two Hermes
gateways, desktop `serve` sessions) and was left alone. Host memory at claim:
3,910 MB total, 0 swap, **818 MB available** — better than the 496 MB of tick 13
but still tight, so the one-heavy-process rule stands and the software-GL render
lane stays withheld a second tick. Routing re-verified from the profile
`delegation:` block: provider `opencode-go`, model `deepseek-v4.1-flash` —
unchanged; no config, credential, profile or provider setting touched.

Two lanes, disjoint allowlists, exactly **one** engine slot:

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-golf | A3 + D2 of the fault-scenario spec in `evidence/parity-coverage-frontier.md` §4: extend the tick-13 full-charge runner to the **double fault** (second serve also struck at full charge, ~4,000 ticks, `doubleFaults` printed) and the **completed set** (`setsToWin=3`, 28,800 ticks) on **both** engines, cross-compared with `tools/parity/parity-compare.mjs`. Closes the last two unexercised branches of the S1 parity claim. | `tools/sim-port/**`, `godot/src/sim/fault_digest_gd.gd`, `godot/src/sim/fault_digest2_gd.gd` (new), `godot/tests/**` (new files only), `docs/wayfinder/evidence/fault-double-fault-set-parity.md` (new) |
| crew-hotel | Engine-free audio port contract: the authoritative **event → sound mapping** derived from the reference call sites plus the 10 verified baked WAVs, mixer/mute semantics as data, and a runnable test that fails on drift (including a deliberately injected-removal red case). First buildable Gate-5 item whose route is already resolved and that needs no engine and no human verdict. | `tools/audio-port/**` (new dir), `docs/wayfinder/evidence/audio-event-contract.md` (new), `docs/wayfinder/tickets/audio-port-route.md` (only for a real correction, header fields kept valid) |

crew-golf holds the single engine slot: headless Godot only, one instance at a
time, always under the existing `timeout 120 env -u DISPLAY` wrapper, never
xvfb, never rendering. crew-hotel is forbidden from launching Godot at all and may
run at most one node/python process at a time. Neither lane may touch
`docs/mission/**`, `docs/wayfinder/map.md`, `js/**`, `scripts/**` (the frozen
harness `scripts/parity-digest.mjs` must stay byte-identical, sha256 `2b24dd26…`),
`tools/character/**`, `godot/prototypes/**` or any tracked file. No commits, no
pushes, zero paid spend, two attempts per gate maximum.

## Tick 14 outcome — both lanes DELIVERED; the port now reproduces a FULL POINT SEQUENCE

Verified by the CEO from disk and by re-running both engines and the new test
myself, never from self-report. One engine slot (crew-golf), one engine-free lane
(crew-hotel).

| Item | Verdict | CEO verification |
|---|---|---|
| crew-golf: `tools/sim-port/fault-digest.mjs` extended (19,362 B, sha256 `365b1082…`), `godot/src/sim/fault_digest_gd.gd` extended (11,810 B, `a1aa5078…`), `tools/sim-port/double-fault-probe.mjs` (7,454 B, `b07f2c88…`), `tools/sim-port/trace-compare.py` (5,209 B, `98ac5373…`), evidence `docs/wayfinder/evidence/fault-double-fault-set-parity.md` (23,377 B, `7c53ddb9…`) | DELIVERED | Hashes reproduced. **My own A3 run**: both engines exit 0 and the strict comparator prints `PARITY-COMPARE IDENTICAL sampledTicks=4001 digestSha256=23f5fb15…` — exactly the lane's digest. **The double fault really fires on both engines at the same tick**: `# double-fault tick=000377 server=player total=1` and `# doubleFaults=1/0` on the JS and the Godot stream alike. **My own D2 run**: seed 12345 / 28,800 ticks / `--sets=3` → `IDENTICAL sampledTicks=481 digestSha256=568a5290…38236ff`, with `# set-closed tick=012691 sets=0-1 games=0-0` and `# set-closed tick=025537 sets=0-2`, `resultTick=none` on both engines. **Non-regression**: the tick-13 baseline seed 999 / 600 ticks still `IDENTICAL` with digest `bfc73441…` byte-identical. Frozen harness sha256 still `2b24dd26…`; `js/**` untouched. |
| crew-hotel: `tools/audio-port/event-map.json` (18,555 B, `a17ccf9d…`), `tools/audio-port/verify-event-map.mjs` (24,527 B, `7266d2de…`), evidence `docs/wayfinder/evidence/audio-event-contract.md` (19,022 B, `c8846778…`) | DELIVERED | Hashes reproduced. **My own run**: `node tools/audio-port/verify-event-map.mjs` → exit 0, `RESULT: PASS — 8 green checks, 0 failures; all 7 injected drift cases caught` (10 events, 10/10 anchors resolving verbatim, 9/9 `sfx` call sites, 10/10 baked WAVs reached with sha256 verified, 15 port event-id anchors over 9 distinct ids). **The red control**: `--drift=remove-event` → exit 1 with three failures naming the exact unmapped call site and the orphaned WAV, so the test is not a rubber stamp. The `audio-port-route` ticket was **not** touched (mtime still 05:03); map validator re-run by me: `PASS: 0 errors, 0 warnings`. |
| No drift | GREEN | `git status --porcelain --untracked-files=no` empty, HEAD still `2979588`; only allowlisted paths written (evidence files, `tools/sim-port/**`, `tools/audio-port/**`, `fault_digest_gd.gd`); no commits, pushes or deployments; zero paid spend, 0 Meshy credits; no human gate self-approved. |

**What this changes.** The S1 parity claim no longer stops at the healthy window: it now
covers a **full point sequence** — first-serve fault, second serve, double fault,
completed game and completed set — byte-identical between the reference and the port on
the strict (exact-text) comparator, at tick resolution.

**Honest residuals, stated rather than smoothed over.** (1) The double fault is only
reachable with `--athlete=1` (pantera): with the frozen harness's own athlete the second
serve cannot fault (spread factor 0.34 aims at worst 112.2 px against a 126 px-deep
service line, 0/300 isolated second serves faulting), which is a property of the
reference's athlete tuning, not a port defect — the lane labelled it that way and the
default behaviour is unchanged. (2) Under the full-charge driver the first set closes at
tick 12,691, not the ~22,260 the frozen-input estimate predicted. (3) The tail after
`state.result` remains outside the runners' scope (a harness artefact; both engines still
agree there). (4) Agreement is text-exact at the digest's printed 6-decimal precision,
not bit-exact float64. (5) Audio is a **contract, not an implementation**: no Godot audio
module, node or bus exists, nothing has been played by the engine, there is no listening
test (the host has no sound device), and the reference defines no target loudness, ducking
or panning — recorded as unknown instead of invented. The port's event ids are strings
(message ids), not numeric as the lane brief assumed; corrected in its evidence.

**Next action (tick 15):** two unblocked items, one heavy lane per tick under the memory
rule — (a) the first Godot-side audio module consuming the verified event map, with a
headless test in the port, which spends the single engine slot; (b) the deferred character
render diagnostic (one copy at x=0, one frame per outfit) on the prescribed
`tools/character/outfits-strong.json`, which needs the software-GL slot. If the window is
too short for either, the engine-free fallback is the locale port contract from
`js/i18n.js` (Gate 5 "locales", no engine, no human verdict; the port already emits 56
string message-id sites).

---
Phase reference for tick 13: **tick 13 completed 2026-09-16 09:26 CEST** (both
lanes delivered and CEO-verified). Overlap check at 09:05: no process of this repository was alive, no tick-12 crew survived,
and the only Godot on the host belonged to the unrelated DemonPet job (which the
kernel OOM-killed in its own cgroup at 09:04:45). Unrelated live work left alone
(DemonPet's cron worker and Godot run, Scrappy servers, the h-dev-work gateway,
the desktop `serve` sessions). Exactly one live driver, no duplicate owner.

## Tick 12 — claim written BEFORE dispatch (2026-09-16 08:28 CEST)

Overlap check at 08:26 (`ps -eo pid,ppid,lstart,rss,cmd`): **no Godot, node or
python process of this repository is alive**, so this run is the only live driver
and no tick-11 crew survived. The only Godot on the host was the unrelated
DemonPet job's process (pid 774335), which the kernel OOM-killed at 08:01:39
inside *that* job's own cgroup — evidence that the host is still memory-starved
and that the tick-11 rule (one heavy process at a time) stays in force. Memory at
claim: 3,910 MB total, 0 swap, **970 MB available**. Routing re-verified from the
profile `delegation:` block: provider `opencode-go`, model `deepseek-v4.1-flash`
— unchanged, no config or credential touched.

CEO baseline re-verification this tick (my own runs, taken before dispatch):
`node scripts/parity-digest.mjs --seed=12345 --ticks=1440 --every=60` →
`PASS … digestSha256=a7136682…`; `tools/sim-port/parity-digest-gd.sh` with the
same args → `PASS … digestSha256=a7136682…` with `discrete=OK floats(max
abs)=0.000000000` on every sampled line. `coverage-matrix-after.jsonl` re-parsed
from disk: **12 scenarios, 12 IDENTICAL** (was 4/12 before the tick-11 fix). The
tick-11 root cause and fix therefore stand as delivered.

Two lanes, one heavy one read-only, disjoint allowlists; the CEO keeps
`docs/mission/**`, `docs/wayfinder/map.md` and every tracked file.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-alfa | The one owed artifact of the *Character pipeline economics* ticket: an in-engine Godot render of the SAME rigged model wearing two distinct outfits (`godot/prototypes/character_material/`, new dir), with PNG evidence and honest colour measurements | `godot/prototypes/character_material/**` (new dir), `docs/wayfinder/evidence/character-material-render.md`, `docs/wayfinder/tickets/character-pipeline-economics.md` |
| crew-echo | Coverage frontier analysis, read-only: why `serveAttempts` stays 0, why the long runs leave the healthy regime (`ball.z → −1e5`), and the exact scenario spec that would reach faults, second serves, a completed game and a set | `tools/sim-port/**` (new files only), `docs/wayfinder/evidence/parity-coverage-frontier.md` |

crew-alfa holds the single heavy slot (Godot render, llvmpipe); crew-echo is
forbidden from launching Godot at all and may run at most one `node` process at a
time for reading existing artifacts. Neither lane may touch `docs/mission/**`,
`docs/wayfinder/map.md`, `js/**`, `scripts/**`, `godot/src/sim/**`,
`godot/prototypes/arena_spike/**` or any tracked file. No commits, no pushes,
zero paid spend, two attempts per gate maximum.

## Tick 12 outcome — both lanes DELIVERED; verification re-run by the CEO

| Item | Verdict | CEO verification |
|---|---|---|
| crew-alfa, `godot/prototypes/character_material/**` (new project, `character_material.gd` 11,594 B, `render.sh`, 3 render PNGs) + `docs/wayfinder/evidence/character-material-render.md` (14,281 B, sha256 `2e5ccbbc…`) | DELIVERED | **I re-ran `./render.sh 1280x720` myself**: exit 0, `RESULT: CM_PASS`, and all three regenerated PNGs are **byte-identical** to the lane's (sha256 `a5797073…`, `47d9586f…`, `aca8dcdd…`). Dimensions 1280×720 RGBA; distinct sampled colours 13,587 / 7,858 / 7,744 — real renders, not blank. |
| crew-echo, `docs/wayfinder/evidence/parity-coverage-frontier.md` (23,146 B, sha256 `fb3453fe…`) + `tools/sim-port/out/fault-scenarios.json` (16,319 B) + two new read-only tools | DELIVERED | Independent re-run of the frozen reference myself at seed 12345 / 28,800 ticks: `serveAttempts=0` on all 13 sampled lines, and from tick ~24,000 the counters explode (`sets=0-57`, `pointsWon=7-1377`, `ball.z=-24551`) — exactly the degenerate tail the lane describes. Source anchors read directly by me: the AI serve charge really is the fixed literal `0.62` in `performServe` (`js/game.js`), and the real browser loop really does stop on the match result (`if (result) break;` / `endMatch(...); return;` in `js/main.js`). |
| No drift | GREEN | Scope audit by mtime: the only files touched during the tick are inside the two allowlists (the new `character_material/` dir, the two evidence files, the new `tools/sim-port/` files, the character ticket). `git status --porcelain --untracked-files=no` empty; HEAD still `2979588`; no commits, pushes or deployments; zero paid spend and 0 Meshy credits. |

**What the character lane actually proved, and what it did not.** The *mechanism*
works: one GLB, one surface, material duplicated and only `albedo_texture`
replaced, applied per copy, logged in engine; the two copies are provably not
interfering (null control exactly 0.0000 mean-abs between the single-outfit frame
and the matching region of the side-by-side frame). The *outcome* does not: the
mean rendered model colour moves only **1.2/255** between outfits (largest
garment window ≈ 6/255 on the shorts), because the two authored textures
themselves differ by only ~14.5 % of atlas texels. The ticket therefore **stays
open**, and the next diagnostic is named and payable at 0 credits: render one
copy at x=0 (one frame per outfit, removing the ±0.75 m off-axis perspective and
view-vector confound), then raise the target-colour delta in the recolour input
and re-render; if the visible delta scales with the atlas delta the limit is
authoring strength, if not it is the override path. Also corrected there: the
previously recorded `--headless` render command produces a blank capture — the
working invocation is `xvfb-run` + `--rendering-driver opengl3`.

**What the coverage lane actually settled (both answers verified by me).**
(1) `serveAttempts` is 0 in every scenario because of the *scenario*, not a port
defect: the frozen harness strikes every serve at charge ≤ 0.3254, while a
service fault only becomes possible above ≈ 0.90 of charge against a 126 px-deep
box, and the AI's serve charge is a fixed literal 0.62 — the AI can structurally
never fault, which matches the measured 0 faults in 103 AI serves. The reference
source itself says dispersion was added precisely so second serves and double
faults became reachable, so the uncovered branch is reachable in the real game
and merely unreached by the harness. (2) The `ball.z → −1e5` runaway is a
**harness artefact**: it begins on the exact tick the match result is set, because
the frozen script keeps stepping past the point where the real browser loop
breaks out, and a double-bounce branch returns before the z-clamp so each tick
awards another point. Consequence to keep visible: the 28,800-tick scenarios are
not valid parity evidence beyond the match end, even though both engines still
agree there.

**Next action (tick 13):** build the charging runner the spec calls for (new file
under `tools/sim-port/**`, never touching the frozen harness) so serves are struck
at full charge, then run it through **both** engines and cross-compare — the first
scenario where faults and second serves actually fire, taking the S1 claim from
"the healthy window" to a full point sequence. Second lane of the same tick: the
character ticket's named 0-credit diagnostic (one copy at x=0, one frame per
outfit). Both unblocked, one heavy engine lane per tick under the memory rule.

## Tick 13 — claim written BEFORE dispatch (2026-09-16 09:06 CEST)

Overlap check at 09:05 (`ps -eo pid,ppid,lstart,rss,cmd --sort=-rss`): **no Godot,
node or python process of this repository is alive**, so this run is the only live
driver and no tick-12 crew survived its run. Unrelated live work left alone
(DemonPet's own cron worker and its vulkan Godot run, the Scrappy servers, the two
desktop `serve` sessions). Host memory at claim: 3,910 MB total, 0 swap, **496 MB
available**, and `dmesg` shows a global OOM kill at **09:04:45** inside the
DemonPet job's own cgroup — so the one-heavy-process-at-a-time rule stays in force
and the software-GL render lane (character diagnostic step 1) is **deliberately not
dispatched this tick**. Routing re-verified from the profile `delegation:` block:
provider `opencode-go`, model `deepseek-v4.1-flash` — unchanged, no config,
credential, profile or provider setting touched.

Two lanes, disjoint allowlists, exactly **one** engine slot, both deliverable inside
this tick:

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-delta-lima | A1/A2 of the fault-scenario spec in `evidence/parity-coverage-frontier.md` §4: the full-charge charging runner on **both** engines — a new JS runner and a new GDScript harness that strike serves at full charge, seed 999 and 12345, ~600-tick budgets — cross-compared through `tools/parity/parity-compare.mjs`, so the port is exercised across a first-serve fault and a second serve for the first time | `tools/sim-port/**` (new files only), `godot/src/sim/fault_digest_gd.gd` (new), `godot/tests/**` (new files only), `docs/wayfinder/evidence/fault-second-serve-parity.md`; `godot/src/sim/**` only if a real diagnosed divergence is found |
| crew-east | The offline half of the frontier ticket *Character pipeline economics*' named 0-credit diagnostic: measure the visible-delta ceiling the authored textures can actually carry (mask coverage × target-colour separation), validate that model against sampled pixels, and prescribe the exact stronger `outfits.json` target colours a later render would use — **no render, no full recolour re-run** | `tools/character/**` (new files only), `docs/wayfinder/evidence/character-recolour-delta-ceiling.md` |

crew-delta-lima holds the single engine slot (headless Godot, never rendering, one
instance at a time, always under `timeout`); crew-east is forbidden from launching
Godot at all and from any full-resolution recolour run (sampled reads, at most two
images in memory, one process at a time). Neither lane may touch `docs/mission/**`,
`docs/wayfinder/map.md`, `js/**`, `scripts/**` (the frozen harness
`scripts/parity-digest.mjs` must stay byte-identical, sha256 `2b24dd26…`),
`godot/prototypes/**` or any tracked file. No commits, no pushes, zero paid spend,
two attempts per gate maximum.

## Tick 13 outcome — both lanes DELIVERED; the port now reproduces a FAULT and a SECOND SERVE

Verified by the CEO from disk and by re-running both engines, never from self-report.

| Item | Verdict | CEO verification |
|---|---|---|
| crew-delta-lima: `tools/sim-port/fault-digest.mjs` (14,832 B, sha256 `9dacf30e…`), `tools/sim-port/fault-digest-gd.sh` (1,108 B, `3cf8f588…`), `godot/src/sim/fault_digest_gd.gd` (7,387 B, `1f2fc06a…`), `tools/sim-port/trace-compare.py` (4,294 B, `9769dccc…`), evidence `docs/wayfinder/evidence/fault-second-serve-parity.md` (16,895 B, `f839003a…`) | DELIVERED | **I re-ran both engines myself**: `node tools/sim-port/fault-digest.mjs --seed=999 --ticks=600 --every=1` exit 0 (624 lines) and `tools/sim-port/fault-digest-gd.sh --seed=999 --ticks=600 --every=1` exit 0 (626 lines); `node tools/parity/parity-compare.mjs <js> <gd>` (strict) → **RESULT=IDENTICAL, 601 samples × 21 fields, digestSha256 `bfc73441…` on both streams**; seed 12345 / every 60 → IDENTICAL, 11 samples, digest `45cebcff…`. Both digests match the lane's table exactly. All five file hashes reproduced. |
| crew-east: evidence `docs/wayfinder/evidence/character-recolour-delta-ceiling.md` (22,432 B, sha256 `dc21ea64…`), `tools/character/analyse_recolour_delta.py` (15,477 B, `7b50c6e7…`), `tools/character/outfits-strong.json` (2,129 B, `f4c4687d…`) | DELIVERED | Hashes reproduced. **My own re-run**: `--stage predict --stride 4` exit 0 → residual 0.0506/255, Pearson r 0.99999, changed-fraction measured 0.145599 vs predicted 0.146034; `--stage strong` exit 0 → predicted rendered-model mean abs **3.7415/255** (3.12× today's 1.2/255), garment window 25.2227/255, legal ceiling at the current mask 36.3457/255 atlas → 8.9503/255 rendered. Source texture sha `6cd22f86…` re-matched; the existing PNGs, `outfits.json`, `PROVENANCE.md` and `diff-report.json` still carry their pre-tick mtimes. |
| No drift | GREEN | `git status --porcelain --untracked-files=no` empty, HEAD still `2979588`; the frozen harness `scripts/parity-digest.mjs` sha256 `2b24dd26…` **byte-identical before and after**; `godot/src/sim/**` was NOT modified (no divergence was found, so the conditional-fix permission never fired); no commits, pushes or deployments; zero paid spend, 0 Meshy credits. |

**The fault sequence, from my own streams (not the lane's summary):** JS
`ev tick=000251 events0="Serve out of the diagonal box. Second serve."`, Godot
`ev tick=000251 events0="serveOutBox secondServe"` — the same tick, the same event;
the second serve is struck at `rngCalls=3` on `tick=000254`; `serveAttempts` goes to 1
on the first sampled line after the fault. The only differences between the two
streams are Godot's two banner lines and the event text being a message id rather
than the localized JS string (`state.gd:18`) — disclosed by the lane, verified by me.

**What this changes, and what it does not.** Parity is now proven across the branch
that had never been exercised: a first-serve fault, the second serve and the point
that follows, compared at tick resolution on 601 ticks with the strict (exact-text)
comparator. Still open, stated honestly: the **double fault** (A3) remains
unexercised (`doubleFaults=0/0`), no completed game or set is reached in this 600-tick
scenario (`resultTick=none`), and the gate is text-exact on the digest line at printed
6-decimal precision, as the frozen harness defines it — not bit-exact float64.

**Next action (tick 14):** two unblocked items, one heavy lane per tick under the
memory rule — (a) extend the charging runner to the double-fault scenario (A3, ~4,000
ticks) and the healthy completed-set run D2 (`setsToWin=3`, 28,800 ticks) through both
engines, which are the last two uncovered branches; (b) the deferred character render
diagnostic (one copy at x=0, one frame per outfit) using the prescribed
`tools/character/outfits-strong.json`, which trades today's 1.2/255 whole-model
difference for a predicted 3.74/255 and turns the ±0.75 m view-vector confound into a
measurement.

## ROOT CAUSE FOUND: the lost dispatches are OOM kills, not crew failures

Ticks 5, 6, 7, 9 and 10 all ended as "unknown" executions in
`~/.hermes/profiles/h-dev-work/cron/executions.db` with the same error text
("Scheduler restarted after this execution's owner exited before a durable
terminal state"). This tick read the kernel log instead of guessing:

- `dmesg -T | grep -i oom` shows a **global OOM kill inside this mission's own
  cgroup** on each of the last two failed ticks:
  `task_memcg=…/hermes-worker-cron-f796600cf451-exec-…sc(ope)`,
  `Out of memory: Killed process 746899 (python3) … anon-rss:879272kB` at
  **07:29:41** (tick 10, killed 90 s after dispatch) and process 745022 with
  `anon-rss:752644kB` at **07:10:18** (tick 9, killed 126 s after dispatch).
  A DemonPet Godot process was OOM-killed at 06:45:21 for the same reason.
- Host budget: **3,910 MB RAM, 0 MB swap**, ~3,450 MB already in use by other
  long-lived work (Scrappy, gateways, desktop sessions, the DemonPet mission
  job which runs every 20 minutes on the same profile). `free -m` at 07:48:
  available ≈ 456 MB.
- The mission's lanes are the largest single processes in the system and carry
  `oom_score_adj=100`, so **the kernel picks this mission's own worker and crew
  first** when memory runs out.

**Consequence for operating doctrine (this is the lesson, not an excuse):** two
heavy lanes at once (Godot render/headless ≈ 450 MB, Python texture work ≈ 880 MB)
plus two child agents plus this parent exceed what the host can hold. Every tick
that dispatched that combination died mid-flight and wrote nothing. Corrective
rules now in force for every subsequent tick:

1. **At most one memory-heavy process at a time** across the whole mission
   (Godot or Python imaging); the second lane must be read-only/documentation.
2. **Every lane writes to disk incrementally** (append per result, not a single
   final dump), so an OOM kill still leaves usable partial evidence.
3. **State is saved before dispatch**, never after (this section is the proof).
4. Export `GODOT_SILENCE_ROOT_WARNING=1` and run headless Godot with
   `timeout`, one instance only; never two Godot processes concurrently.

This is recorded in `LOG.md` and reported to Luca in the tick-11 board report.
It is an environment constraint, not a mission blocker: the work still advances,
just one heavy lane per tick.

## Live crew (tick 11, claimed 2026-09-16 07:50 CEST before dispatch)

Two lanes on the carried-forward tick-9 next action, sized to respect the memory
rule above: one memory-heavy lane, one read-only lane, disjoint write allowlists.
The CEO keeps `docs/mission/**`, `docs/wayfinder/map.md` and every tracked file.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-november | S1 coverage widening: bounded scenario matrix (more seeds, larger tick budgets, finer sampling) through the frozen JS reference and the ported GDScript core, live cross-compared, first divergence reported; fix a real divergence only if the matrix finds one | `tools/sim-port/**` (new files only), `godot/src/sim/**` (only if a real divergence is found), `godot/tests/**`, `docs/wayfinder/evidence/parity-coverage.md` |
| crew-oscar | Frontier ticket *Character pipeline economics*: measured per-athlete cost/perf numbers and the in-engine material step, read from existing artifacts only (no recolour re-run, no new Meshy call), then close the ticket or state exactly what remains open | `tools/character/**` (new files only), `docs/wayfinder/evidence/character-pipeline-economics.md`, `docs/wayfinder/tickets/character-pipeline-economics.md` |

Neither lane may touch `docs/mission/**`, `docs/wayfinder/map.md`, `js/**`,
`scripts/**`, or any tracked file. No commits, no pushes, zero paid spend.

## Tick 11 continuation — the divergence is ROOT-CAUSED and FIXED (lane crew-foxtrot)

A third lane was opened on the confirmed divergence after the first two returned.
Its claim was verified by the CEO independently; the numbers below are the CEO's
own command output, not the lane's.

**Root cause: a mistranslated nullish-coalescing operator.**
`js/game.js:942` (and `:844`) compute
`clamp(paddle.moveRatio ?? paddle.motion ?? 0, 0, 1)`. In the reference the `??`
fallback is dead code: `moveRatio` is numeric by construction (`js/game.js:54`
initialises it to `0`, `:2448` assigns a clamped number). The port instead wrote a
**zero test** — `paddle.moveRatio if paddle.moveRatio != 0.0 else paddle.motion`
at `godot/src/sim/sim.gd:1114` and `:1011`. `motion` is a separate decaying
animation echo (`js/game.js:2445-2447`), so every time a paddle stood still while
the echo was still non-zero the port invented a movement penalty the reference
never applied: at the tick-2207 contact `moveRatio = 0`, `motion = 0.8833333` →
penalty `0.1943333` against the reference's `0` → `balance` → `quality` → `risk` →
`executionSpread` → smash `target.x` → `v.x`. Closed arithmetically end to end,
and `spin = clamp(v.x*0.04)` follows as a consequence.

**Fix:** two lines in `godot/src/sim/sim.gd` (drop the zero test, use `moveRatio`
directly, matching the reference). File now md5 `b0779b6e…`, 141,741 B; pre-fix
backup `/tmp/sim.gd.bak` (md5 `d1365b33…`). No debug prints remain (`grep -c DBG`
= 0). `js/**` and `scripts/**` are untouched — harness sha256 still `2b24dd26…`.

| CEO verification (my own runs) | Result |
|---|---|
| `--seed=2024 --ticks=2215 --every=1` both engines | **2,216 common ticks, first differing tick: none** (was tick 2207) |
| Previously DIVERGED scenario seed 7 / 4,320 / every 60 | 73 ticks, **no difference** |
| Previously DIVERGED long scenario seed 999 / 28,800 / every 120 | 241 ticks, **no difference** |
| Regression: seed 12345 / 1,440 / every 60 | both engines still `PASS`, digest still `a7136682…` → the fix is additive, it re-tuned nothing |
| Source semantics | Checked in `js/game.js` myself, not taken on report: `??` fallback really is unreachable there |

**Scope caveat stated honestly:** `godot/` and `tools/` are untracked in this
repository, so `git status` cannot prove the edit's scope. Scope was verified by
reading the two changed lines and by the absence of any other modification
(no debug prints, no new writes into `godot/src/sim/**` beyond them).

**Still not exercised (unchanged by this fix):** `serveAttempts` is 0 in every
scenario, so faults and second serves are untouched; no game, set point or
tie-break is reached in the frozen harness; the long scenarios remain sampled at
60/120 ticks. Parity is now proven across the full 18 s+ window at four seeds and
the 12-scenario matrix, not across a complete match.

**Next action (tick 12):** two unblocked items, one heavy lane per tick under the
memory rule — (a) the in-engine material render the character ticket still owes
(`godot/prototypes/character_material/`, headless, two outfits, PNG evidence), and
(b) exercise faults, second serves and game/set transitions so the coverage claim
stops at nothing less than a full point sequence.

## Tick 11 outcome — both lanes DELIVERED; the parity proof now shows a REAL divergence

Verified by the CEO from disk and by re-running the tools, never from self-report.

| Item | Verdict | CEO verification |
|---|---|---|
| crew-november, S1 coverage matrix (`tools/sim-port/out/coverage-matrix.jsonl`, 7,009 B, sha256 `14a92df0…`; `docs/wayfinder/evidence/parity-coverage.md`, 20,964 B, sha256 `1761c55c…`) | DELIVERED | Re-ran the baseline myself: `node scripts/parity-digest.mjs --seed=12345 --ticks=1440 --every=60` → `PARITY-DIGEST JS PASS … digestSha256=a7136682…`; `tools/sim-port/parity-digest-gd.sh --seed=12345 --ticks=1440 --every=60` → `PARITY-DIGEST GD PASS … digestSha256=a7136682…`; the 25 tick lines diff **empty** between engines. Frozen harness sha256 unchanged (`2b24dd26…`). Matrix file re-parsed: **12 scenarios, 4 IDENTICAL / 8 DIVERGED**, as claimed. |
| Divergence anatomy (the finding) | CONFIRMED by independent re-run | My own `--every=1` probe, seed 2024, 2,215 ticks, in both engines: **first differing tick = 2207** (≈18.4 s of match time). `rngState`, `rngCalls`, `ball`, `v.y`, `v.z` identical at that tick; `v.x` differs by **1.398015** and `spin` by **0.055920** (spin is `clamp(v.x*0.04)`, so it is a consequence, not a second cause). That is ~1,000× the `1e-3` comparison tolerance — a real port divergence, not float noise. |
| crew-oscar, character pipeline economics (`docs/wayfinder/evidence/character-pipeline-economics.md`, 13,982 B; `tools/character/out/tri-count.json`, 2,155 B; ticket updated to 5,405 B) | DELIVERED | Numbers read from artifacts, not invented: 31,325 triangles per GLB × 3 GLBs (same mesh three times), 40 Meshy credits for the trial athlete (30+5+5, balance corroborated), 14.6 min of API time, 25.48 MiB per athlete, 260.14 MiB projected for 6 athletes + 20 unlocked outfits, recolour diff numbers matching `PROVENANCE.md`. Ticket **stays open** with Owner `crew-oscar` and one named owed item (see below) — the right call, since its own `Resolved when` demands a Godot render that does not exist yet. |
| No drift | GREEN | `git status --porcelain --untracked-files=no` empty; no commit, no push; `godot/src/sim/**` untouched; `npm`/Meshy/paid spend 0. |

**Path correction (evidence-based, from crew-oscar's audit):** the tick-4 record
in this file named `assets/volpe-rigged.glb` as the byte-identical rig copy. There
is no such file; the real copy is `godot/prototypes/arena_spike/assets/volpe-rigged.glb`
(sha256 `ab6b3086…`, identical to `meshy/rigged/volpe/volpe-rigged.glb`). Fixed below.

**Coverage limit that must not be blurred:** `serveAttempts` is 0 in all 12
scenarios, so faults and second serves are still unexercised; no completed set or
tie-break appears; the longest sane rally is 14 and the frozen JS reference itself
leaves the healthy regime in the long runs (ball.z → −1e5 runaway tail after the
divergence). Parity is therefore proven for the healthy tracer window only, and
the divergence means the port is **not** parity-correct beyond ~18 s.

**Next action (tick 11 continuation, then tick 12):** root-cause the tick-2207
divergence with the diagnostic the lane specified — print `target.x`,
`executionSpread` and `assessment.risk` at `godot/src/sim/sim.gd:1493-1495`
against `js/game.js:1443-1445` on the 3-line repro — then, with the engine free,
produce the one in-engine material render the character ticket still owes
(`godot/prototypes/character_material/`, headless orthographic camera, two
outfits, PNG evidence). Both are unblocked; both remain one heavy lane per tick
under the memory rule.

## Live crew (tick 9 — historical: LOST DISPATCH, superseded by tick 11)

Two lanes on the tick-9 next action: widen the S1 parity proof, and close the
frontier map ticket whose evidence is now real. Disjoint write allowlists; the
CEO keeps `docs/mission/**`, `docs/wayfinder/map.md` and every tracked file.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-zulu | S1 coverage widening: a bounded scenario matrix (more seeds, longer tick budgets, finer sampling) through the frozen JS harness and the Godot core, with first-divergence reporting; fix a real port divergence only if the matrix finds one | `tools/sim-port/**` (new files), `godot/src/sim/**`, `godot/tests/**`, `docs/wayfinder/evidence/parity-coverage.md` |
| crew-oscar | Frontier ticket *Character pipeline economics*: re-run the recolour path, read the real provenance and diff numbers, record measured cost/limits, close the ticket or state honestly why it cannot close without Luca | `tools/character/**`, `docs/wayfinder/evidence/character-pipeline-economics.md`, `docs/wayfinder/tickets/character-pipeline-economics.md` |

Neither lane may touch `docs/mission/**`, `docs/wayfinder/map.md`, `js/**`,
`scripts/**`, `godot/prototypes/**` or any tracked file. No commits, no pushes.

## Tick 9 outcome — LOST DISPATCH (audited from disk by tick 10)

The tick-9 run (worker pid 744301, started 07:08:10) terminated without writing an
artifact for either claimed lane. Audited from disk at 07:28, not from self-report:
`docs/wayfinder/evidence/parity-coverage.md` and
`docs/wayfinder/evidence/character-pipeline-economics.md` do not exist (evidence
directory mtime 06:45), `docs/wayfinder/tickets/character-pipeline-economics.md`
still reads `Status: open / Owner: unassigned` (file mtime 02:33), `LOG.md` carries
no tick-9 entry, and `ps` shows no surviving crew. One trace of partial execution:
`tools/character/out/mask-chromatic.png` was rewritten at 07:10 (225,726 B) while
`PROVENANCE.md` and `diff-report.json` still date from 06:35 — crew-oscar started a
recolour run and was killed before it finished. Recorded as a LOST DISPATCH, not a
failed gate: nothing is claimed on its behalf, no test regressed, no tracked file
changed. Tick 10 re-dispatches both realms under new lane names (india, juliet) so
tick-9 ownership is never conflated with tick-10 work.

## Live crew (tick 10, claimed 2026-09-16 07:30 CEST before dispatch)

Two lanes on the tick-9 next action, re-scoped so each lands disk evidence within a
few minutes. Disjoint write allowlists; the CEO keeps `docs/mission/**`,
`docs/wayfinder/map.md` and every tracked file.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-india | S1 coverage widening: a bounded scenario matrix (more seeds, longer tick budgets, finer sampling) run through the frozen JS harness and the Godot core, cross-checked live with the comparator, with first-divergence reporting; fix a real port divergence only if the matrix finds one | `tools/sim-port/**` (new files), `godot/src/sim/**`, `godot/tests/**`, `docs/wayfinder/evidence/parity-coverage.md` |
| crew-juliet | Frontier ticket *Character pipeline economics*: produce measured per-athlete cost/perf numbers and a two-outfit recolour proof from the one Volpe rig, then close the ticket or state honestly why it cannot close | `tools/character/**`, `godot/prototypes/character_recolour/**` (new dir), `docs/wayfinder/evidence/character-pipeline-economics.md`, `docs/wayfinder/tickets/character-pipeline-economics.md` |

Neither lane may touch `docs/mission/**`, `docs/wayfinder/map.md`, `js/**`,
`scripts/**`, `godot/prototypes/render_probe/**` or any tracked file. No commits,
no pushes, zero paid spend.

## Tick 6 outcome — audited from disk by tick 7 (not from self-report)

| Lane | Verdict | Evidence on disk |
|---|---|---|
| crew-sierra (Gate 2 plan) | DELIVERED | `docs/implementation/PLAN.md`, 144 lines, written 05:36:49. CEO read it: outcome, scope boundaries, 13 ordered slices, the open-decision table, evidence/verification model, budget. Slice table names two build tickets — `tickets/sim-core-parity.md` and `tickets/quick-match-slice.md` — which **do not exist on disk**, so Gate 2 is incomplete. |
| crew-tango (recolour crash + character economics) | PARTIAL, unproven | `tools/character/recolour_outfits.py` modified 05:36:46, `tools/character/out/mask-chromatic.png` written 05:54:49. `out/PROVENANCE.md` still absent, no evidence file, no ticket update. Claim unverified pending a CEO re-run this tick. |
| crew-uniform (arena spike motion pass) | NOTHING | `godot/prototypes/arena_spike/**` untouched since 05:06. This is the **second** dead attempt at that realm (tick-5 crew-romeo, tick-6 crew-uniform), so per the charter's two-attempts rule the motion pass is frozen as a blocker and the realm takes no third identical attempt. |

## Tick 7 outcome — audited from disk by tick 8, both lanes DELIVERED

| Lane | Verdict | Evidence on disk | CEO verification |
|---|---|---|---|
| crew-victor (Gate 2 completion) | DELIVERED | `docs/implementation/tickets/sim-core-parity.md` (26,002 B, 06:16:56) and `quick-match-slice.md` (20,666 B, 06:16:21); both carry all eight required sections (Objective, Existing source anchors, File ownership/allowlist, Inputs and outputs, Tests, Execution commands, Expected evidence, Failure and recovery criteria); `PLAN.md` still 13 slices, 12020 B, unchanged | CEO read both headers and section maps, grepped the section list, confirmed the blocker lines point at the real open human tickets. **Gate 2 is now complete at the documentation level.** |
| crew-whiskey (Gate 4 S1, JS half) | DELIVERED and VERIFIED | `scripts/parity-digest.mjs` (12,627 B, sha256 `2b24dd26…`), `tools/parity/parity-digest-seed12345.json` (27,775 B, sha256 `1032fb20…`), `docs/wayfinder/evidence/parity-digest-js.md` (8,865 B) | CEO re-ran the harness twice: `PARITY-DIGEST JS PASS seed=12345 ticks=1440 sampledTicks=25 finalRngState=-319693640 digestSha256=a7136682…` both times, byte-identical JSON, seed 999 gives a different digest, `determinism-audit.mjs` still `strayMathRandom: 0`, both sha256s match the evidence table exactly. |

Carried forward unresolved: the recolour tool's `PROVENANCE.md` write (tick-6
crew-tango, partial) — CEO re-run started this tick; see the tick-8 outcome row.

## Live crew (tick 8, claimed 2026-09-16 06:38 CEST before dispatch)

Two lanes on the next unblocked build frontier — Gate 4 slice S1 (deterministic
simulation parity), split into its two separable halves. This tick runs inside a
~20-minute window before the next scheduler dispatch, so both lanes are told to
land a runnable artifact on disk early and improve it in place, never to hold
work in memory until the end.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-xray | S1 producer half: a headless GDScript simulation core tracer that reproduces the frozen JS digest line format for the seed-12345 / 1440-tick script, plus the first-divergence report | `godot/src/sim/**` (new), `godot/tests/parity_digest.gd` (new), `docs/wayfinder/evidence/parity-digest-gd.md` |
| crew-yankee | S1 consumer half: a cross-engine digest comparator with a scenario corpus and a self-test that proves it detects injected differences | `tools/parity/**` (new files only) |

The seam contract is frozen and already verified this tick: the digest line
format of `scripts/parity-digest.mjs` at sha256 `2b24dd26…`, documented in
`docs/wayfinder/evidence/parity-digest-js.md`. crew-xray produces lines in that
format, crew-yankee consumes it; neither writes the other's files, and neither
re-implements the other's half. Neither lane may touch `docs/mission/**`,
`docs/wayfinder/map.md`, `js/**`, `scripts/**` or `godot/prototypes/**`.

## Tick 8 outcome — both lanes DELIVERED, verified by the CEO, plus the recolour gate settled

| Item | Verdict | CEO verification |
|---|---|---|
| S1 producer: headless GDScript simulation core (`godot/src/sim/**`, `tools/sim-port/**`, `docs/wayfinder/evidence/parity-digest-gd.md`) | DELIVERED | CEO ran `tools/sim-port/parity-digest-gd.sh --seed=12345 --ticks=1440 --every=60` → `PARITY-DIGEST GD PASS … digestSha256=a7136682…`, exit 0. Byte-for-byte line diff against a **live** JS run: `diff` empty, 25/25 lines, identical sha256 on both sides. **Anti-echo control: with `tools/parity/parity-digest-seed12345.json` moved out of the tree the digest lines and hash are unchanged** (only the PASS/FAIL word flips), so the values are computed, not copied; grep shows no hardcoded hash and no `OS.execute`/node call in `godot/src/sim/`. |
| S1 consumer: cross-engine comparator (`tools/parity/parity-compare*.mjs`, `parity-stream.mjs`, README, fixtures, `docs/wayfinder/evidence/parity-compare-consumer.md`) | DELIVERED | CEO ran the comparator on its own two live streams → `PARITY-COMPARE IDENTICAL sampledTicks=25`, exit 0. Self-test suite (34 cases: green, 23 injected reds, usage, contract violations) is the lane's own; its red cases assert exact tick+field. |
| Regression guard | GREEN | `env -u DISPLAY … --headless --path godot/` still prints `PASS 8/8`, exit 0. `git status --porcelain --untracked-files=no` empty: no tracked file changed, no commit, no push. |
| Carried-forward character recolour claim (tick-6 crew-tango) | RESOLVED, gate now green | CEO re-ran `python3 tools/character/recolour_outfits.py` itself: completed with **no traceback**, wrote `tools/character/out/PROVENANCE.md` (3,297 B) and `diff-report.json`. The tick-6 crash really was fixed; the missing file was the run being killed, not a live bug. |

**Limit that stays visible:** parity is proven at 25 sampled ticks over 12 s of
match time at two seeds (12345, 999), on the quick/solo configuration. Games,
sets, tie-breaks, faults, second serves and the special are not exercised by the
frozen script, and agreement is at printed 6-decimal precision, not bit-exact
float64. Slice S1 is therefore **proven for the tracer scenario, not closed** —
and its done verdict is additionally blocked by the open human parity-gate
decision, exactly as the ticket says.

---

## Earlier tick record Tick 5's run was
killed by the next scheduler tick (05:33:52) while its three lanes were still
working; it wrote no artifact at all — `docs/implementation/` was empty, the arena
spike folder was untouched since 05:06, and no character evidence file existed.
Tick 5 is recorded as a LOST DISPATCH, not as a failed gate: nothing was claimed on
its behalf and no test regressed. Tick-4 hands stay verified green (renders
reproduced, audio 54/54 and 11/11, Steamworks page fetched, map validator PASS).
Driver: scheduled OpenCode Go / deepseek-v4.1-flash, job `f796600cf451`, Padel Godot port mission, every 20 minutes.
Pause command: `hermes --profile h-dev-work cron pause f796600cf451`.
Resume command: `hermes --profile h-dev-work cron resume f796600cf451`.

## Routing (re-verified 2026-09-16 05:15 CEST, unchanged)

- Parent + native crew: provider `opencode-go`, model `deepseek-v4.1-flash`.
  Confirmed from the profile `delegation:` block (provider `opencode-go`, model
  `deepseek-v4.1-flash`); the session banner matches. No config, provider, model,
  credential or profile setting was changed this tick or any earlier tick.
- Godot on host: `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`,
  `4.7.2.stable.official.ed1daf0bf`.
- No mission process alive at claim time (05:14): the tick-4 children died with
  their run. Unrelated live work left alone (DemonPet three-d node job, Scrappy
  servers).

## Live crew (tick 6, claimed 2026-09-16 05:36 CEST before dispatch)

Same three realms as tick 5, re-scoped smaller so each lane lands disk evidence
early. New lane names so tick-5 ownership is never conflated with tick-6 work.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-sierra | Gate 2: implementation plan + named, dependency-linked build tickets for the two unblocked slices (simulation parity core, quick match) | `docs/implementation/**` |
| crew-tango | Character pipeline: fix the real crash in the recolour tool, finish the run, then the character-pipeline-economics research ticket | `tools/character/**`, `docs/wayfinder/evidence/character-pipeline-economics.md`, `docs/wayfinder/tickets/character-pipeline-economics.md` |
| crew-uniform | Arena spike motion pass: ball x/y/z motion from `BALANCE`, diagonal serve, camera presets, new rendered PNG evidence | `godot/prototypes/arena_spike/**`, `docs/wayfinder/evidence/camera-spike-render.md`, `docs/wayfinder/tickets/camera-and-feel-spike.md` |

No write allowlist overlaps; no lane may edit `STATE.md`, `LOG.md`, `BOARD.md`
or `map.md` (CEO-owned).

## Tick 4 returns — independently verified by the CEO (tick 5)

| Item | Evidence | Verified how |
|---|---|---|
| Camera/feel spike: real in-engine Godot scene (court 20.000 x 12.700 m, net 0.950 m, 4 glass walls, ball, one rigged athlete in base pose) | `godot/prototypes/arena_spike/**`, `evidence/camera-spike-render.md`, `tickets/camera-and-feel-spike.md` | CEO re-ran `render.sh playable /tmp/ceo_arena.png 1280x720` → `ARENA_PASS`, exit 0, real 1280x720 RGBA PNG (65,316 B, same size as the crew's). Decoded all three crew PNGs: 1280x720 each, 199 / 278 / 99 distinct sampled colours — not blank. sha256 of all three match the evidence table exactly. `assets/volpe-rigged.glb` byte-identical to `meshy/rigged/volpe/volpe-rigged.glb` (sha `ab6b3086…`). |
| Audio port route | `tools/audio-audition/**`, `evidence/audio-port-route.md`, `tickets/audio-port-route.md` | CEO re-ran both verifiers: `node verify-stub.mjs` → **54/54, exit 0**; `python3 verify_browser.py` → **11/11 renders, exit 0** (10 real mono 44.1 kHz WAVs baked, muted path silent, mixer ratio exactly 0.5000). |
| Steamworks integration route | `evidence/steamworks-integration-route.md`, `tickets/steamworks-integration-route.md` | CEO fetched the cited release page live: the Codeberg GodotSteam release really carries both releases with the quoted text ("In Godot 4.7.2 and 4.5.2 variants", "Works on any Godot version 4.4 and up") and the named artifacts (`linux64-g472-s165-gs4221-editor.tar.xz`, `godotsteam-4.22.1-gdextension-plugin-4.4.zip`). Chosen route: GodotSteam GDExtension, with the honest limit that 4.7.2 is a *module* variant, not a declared GDExtension certification. |
| Map validator | `docs/wayfinder/validation.md` | CEO re-ran `python3 docs/wayfinder/validate.py` → PASS, 0 errors, 0 warnings, exit 0. |
| No drift | `git status --short` | Only untracked `docs/`, `godot/`, `meshy/`, `tools/`; no tracked file changed; no commits, pushes or deployments; no secrets in the new files. |

CEO judgement on tick-4 quality: the three returns are real, source-anchored and
honest about gaps (the camera evidence lists eight explicit "not done" items
including the unresolved 20x10 vs 1.575 court-aspect mismatch). None of them
self-certifies a human gate.

## Completed and independently verified (carried forward)

| Item | Evidence | Verified how |
|---|---|---|
| Baseline audit green | `evidence/baseline-audit-diagnosis.md` + raw log | CEO re-ran `npm run audit` → 27/27, exit 0 |
| Godot 4.7.2 pinned + headless harness | `tickets/godot-headless-harness.md`, `evidence/godot-harness-smoke.log`, `godot/` | CEO re-ran headless command → `PASS 8/8`, exit 0 |
| Simulation port boundary | `tickets/simulation-port-boundary.md` | CEO spot-checked anchors in `js/main.js` / `js/game.js` |
| Render capability on this GPU-less host | `godot/prototypes/render_probe/**` | CEO reproduced a real render (llvmpipe / Mesa 26.0.8) |
| Character recolour tool runs, with one real crash bug | `tools/character/out/{outfit-a,outfit-b}.png`, `diff-report.json` | CEO ran the tool: textures written (2048x2048), mask 0.1422, mean diff 9.982/255 over 14.6 % of texels; then `TypeError: not all arguments converted during string formatting` at `recolour_outfits.py:309` while writing `PROVENANCE.md`. Bounded fix handed to crew-quebec. |

## Blockers (real; none of them stop unrelated work)

- Human decisions still open and never self-approved: camera/feel, UI approach,
  parity gate, roster order, arena direction, strangler policy, product scope,
  demo gate, Steam App ID, and the newly surfaced **court aspect** question
  (COURT is 800x508 px = 1.575, not 2.0 — the web layout either compresses depth
  or is not a scale plan; the port cannot lock a court mesh until Luca says which).
- Rendering is software GL (llvmpipe) on this host: valid for evidence PNGs, but
  no frame-rate or target-hardware claim can be made from it.
- `npm run assets:outfits` cannot run here (reads git-ignored source masters that
  are absent). Recorded, not fixed, not a red.
- Spend: 0 Meshy credits and $0 used. No metered inference spend; the existing
  OpenCode Go subscription only.

## Next action (tick 9)

Widen the parity proof before building on it: run the new GDScript core and the
JS harness over denser and longer scenarios (more seeds, larger tick budgets,
finer sampling, longer rallies so games/sets/faults are reached), compare live
with `tools/parity/parity-compare.mjs`, and record the coverage evidence. In
parallel, close the open `Character pipeline economics` map ticket now that the
recolour path has real PROVENANCE and diff numbers. The arena-spike motion pass
stays frozen until Luca rules on camera/feel.

## Slice S14 — shot logic parity + timing presentation (claimed 2026-09-17 01:05 CEST)

Owner's words: *"se i colpi corrispondono come logica a quelle della versione 2d,
inoltre vorrei mettere anche qui le scritte e le logiche del timing con Perfetto...
che c'erano nel 2d"*. Budget: no cap. Two attempts per gate, then a blocker.

| Lane | Realm | Allowed writes |
|---|---|---|
| crew-shotlogic | S14a — every shot intent, anchor to anchor | `docs/wayfinder/evidence/shot-logic-parity.md`, `godot/tests/shot_logic_parity_test.gd`, `tools/sim-port/intent-trace/**` |
| crew-timinglogic | S14b — the numbers behind PERFETTO | `docs/wayfinder/evidence/timing-logic-parity.md`, `godot/tests/timing_feedback_test.gd`, `tools/sim-port/timing-trace/**` |
| crew-timinghud | S14c — the ring, the words, the bars on the field | `godot/game/hud.gd`, `godot/game/match_controller.gd`, one new section `_timing_presentation` in `godot/tests/game_slice_test.gd`, `docs/wayfinder/evidence/timing-presentation-3d.md`, `godot/game/out/*.png` |

No allowlist overlaps; no lane may edit `STATE.md`, `LOG.md`, `BOARD.md`, `map.md` or
any tracked file outside its allowlist (CEO-owned). `godot/src/sim/**` is frozen
except for a divergence proven by the ticket's own reproduction.

## Slice S14 — returned, verified, certified (2026-09-17 02:15 CEST)

| Lane | Delivered | Verified by the CEO |
|---|---|---|
| crew-shotlogic (S14a) | `docs/wayfinder/evidence/shot-logic-parity.md`, `godot/tests/shot_logic_parity_test.gd`, `tools/sim-port/{shot-intent-probe,shot-intent-compare}.mjs` | PASS 675/675; comparator IDENTICAL 35/35 (657 fields, tol=0) with my own regenerated reference trace; my mutation → DIVERGED, exit 1 |
| crew-timinglogic (S14b) | `docs/wayfinder/evidence/timing-logic-parity.md`, `godot/tests/timing_feedback_test.gd`, `tools/sim-port/{timing-trace.mjs,timing-compare.py}` | PASS 100/100; injected failure FAIL 96/100 exit 1; IDENTICAL on both scenarios; 1e-6 mutant → exit 1; `godot/src/sim/**` untouched |
| crew-timinghud (S14c) | `godot/game/{match_controller,hud}.gd`, one `_timing_presentation` section in `godot/tests/game_slice_test.gd` (36 checks), `docs/wayfinder/evidence/timing-presentation-3d.md`, frames | slice 324/325 with the new section, 23/23 sections; A/B frame measurements reproduced in the evidence; steer delivered mid-flight (the verdict over the striker) |

Open after S14: the owner's feel verdict; `run.sh`'s capture list and the `out/*.png`
gitignore question; co-op/PvP and other tiers outside all three gates.

## Ticket reconciliation — wayfinder map and mission cabinet (2026-09-17 11:25 CEST)

Five ticket Status headers flipped to `resolved` (map table matching): shot-logic-parity,
timing-logic-parity, timing-presentation-3d, court-width-render, and timing-label-scale
(resolved as superseded by timing-presentation-3d). The stands (arena-bleachers) stays
open — its evidence file is not on disk yet. Map validator PASS 0 errors / 0 warnings.
