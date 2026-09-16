# modes-playable — evidence

Lane: **crew-modes-play** (integration owner, `godot/game/**`). The three non-quick-match modes —
**drill, tournament, career** — are playable end to end from the menu, with mode HUDs, bracket and
season progression persisted through `godot/src/modes/modes_save.gd` → `godot/src/save/**`, all three
refused in the demo build, and the three Italian text defects found in the rendered UI fixed.

Frozen reference: `js/**` at commit `2979588`, read-only and unchanged. `godot/src/**`,
`scripts/**`, `godot/export_presets.cfg` and `godot/project.godot` were read and not edited. Nothing
was committed, pushed or deployed; zero paid spend; max two attempts per gate, and every gate passed
on the attempts recorded below.

Status: **green.** `slice-full PASS 280/280`, `slice-demo PASS 229/229`, engine harness `PASS 8/8`,
ten rules audits `PASS 10/10`; the input suite is `82/83` with the one failure caused by another
lane's file (§7).

The narrative section that goes with this file is appended to
`docs/wayfinder/evidence/quick-match-playable.md` as §13.

## 1. The counts, before and after

| Suite | Command | Before | After | Exit |
|---|---|---|---|---|
| `slice-full` | `--headless --path godot/ --script res://tests/game_slice_test.gd` | `PASS 211/211` | **`PASS 280/280`** | 0 |
| `slice-demo` | same + `-- --demo` | `PASS 211/211` | **`PASS 229/229`** | 0 |
| engine harness | `--headless --path godot/` (main scene `SmokeTest.tscn`) | `PASS 8/8` | `PASS 8/8` | 0 |
| ten rules audits | `--script res://tests/audits/run_all.gd` | `PASS 10/10` | `PASS 10/10` | 0 |
| input suite | `--script res://tests/input/run_all.gd` | 4/4 audits | `82/83` — §7 | 1 |

```
ok slice-full: PASS 280/280 exit=0 script-errors=0 errors=1(allowed=1+0) fails=0(allowed=0) /tmp/final-full.log (godot/build/logs/2026-09-16-slice-full-final.log)
ok slice-demo: PASS 229/229 exit=0 script-errors=0 errors=2(allowed=1+1) fails=0(allowed=0) /tmp/final-demo.log (godot/build/logs/2026-09-16-slice-demo-final.log)
```

Both lines are `godot/game/check_log.sh`'s verdict, so they carry the strict gate's own condition:
zero `SCRIPT ERROR` lines and no unexplained `ERROR:` line, whatever the check counts say. The only
allowed lines are the two the gate's header names (the deliberate bad-arena probe and the engine's
shutdown `resources still in use at exit`).

## 2. Items 1–3 — the modes are PLAYED

Every mode session is started the way a player starts one — `Config.pending_mode` plus
`res://game/Match.tscn`, i.e. the mode screen's own start button — and every tick goes through
`tick_fixed`, the same entry point a rendered frame uses. Nothing calls `Sim.update_match` twice and
there is no second physics path: the drill's ticks go through `DrillSession.step`, everything else
through `MatchController`'s single tick.

### 2.1 Drill (`_modes_playable`, `slice-full`)

```
ok the drill starts from the menu's own options as a real DrillSession
ok the drill runs the exercise the screen selected
ok the drill matches the quick match's own court and rival tables
ok the drill HUD carries the phase, the target and the live score the tick loop will move
ok the drill HUD draws the reference's four metrics
ok the tick loop advances the drill out of `ready` and places a target
ok the HUD's target is the drill's own target, not a copy
ok an untouched feed closes the attempt as the reference's own miss
ok a miss pays the reference's zero: attemptPoints(0, grade)
ok the miss is shown on the mode HUD before and after the attempt closes
ok a HIT: the rally exercise grades a held exchange with the reference's own points
ok the hit's points are the reference's formula: round(10 * tier * gradeMult)
ok the hit carries one of the reference's own rally diagnoses
ok the HUD's live score is the session's score
ok ending the drill persists the record through ModesSave
ok the drill save round-trips: a second store reads the same best
ok a drill ends once: ending it again writes nothing new
ok a drill that scored nothing does not overwrite the record (improvement only)
```

Session starts from `Config.mode_options()` (what the mode screen hands the match scene), the
exercise from the screen's own row (`Config.pending_exercise`), the arena and the AI table from the
same sources the quick match uses. `# DRILL session=rally score=7 best=7 attempts=1 hits=1 streak=1
grade=late line=shot:late · 7`. The miss and the hit are graded by the reference's own
`drill_scoring.gd`, recomputed in the assertion (`attempt_points(0.0, grade)` and
`attempt_points(min(1.5, 0.25 + rally_hits * 0.18), grade)`), so the test cannot agree with itself.
Persistence: `ModesSave.drill_best` read back through a SECOND `Config.save_store()`; the
improvement-only rule exercised by a session that scored nothing (`skipped` in the record, best
unmoved).

### 2.2 Tournament (`_modes_playable`, `slice-full`)

```
ok a tournament round starts on the bracket's own fixture
ok the round played is the one the save holds (tournament_round)
ok the round's court is the fixture's own
ok the round's AI is the reference's tier for that round
ok the round's rivals are the dictated pair (dictatedRivals)
ok a tournament round keeps the reference's own scoring (a full tennis match, not points)
ok the tournament HUD shows the round, the court and the rival
ok the tournament round reaches a real result inside the tick budget
ok the round is scored by `tournament_rules.gd::advance`
ok the advanced round is persisted through ModesSave.save_tournament_round
ok the trophy flag is the reference's own (final round won)
ok the match reaches the history albo through ModesSave.record_match
ok the tournament screen shows the round the save holds
ok the tournament screen shows the next fixture's court and marks the round in corso
ok a WON round advances the bracket and persists round+1 through save_tournament_round
ok the advanced round's next fixture is the reference's fixture for that round
ok winning a round is recorded in the history albo too
```

Played for 52 288 ticks to a real result: `winner=ai`, so `advance(0, false)` →
`{"round": 0, "reset": true, "continuing": false}`, and the round the save holds afterwards is what
`advance` returned — asserted against `tournament_rules.gd`, not against a literal. The screen then
reads the same save and marks `TURNO 0 … IN CORSO`, with the next fixture's court. The WIN branch is
exercised with a FORCED result (`state.result = {"winner": "player"}`, the field `Sim.update_match`
writes itself) and the file says so: `# TOURNAMENT_WIN round=0 -> next=1 fixture=abissale`. That is
the branch that gives `ModesSave.save_tournament_round` its first caller.

### 2.3 Career (`_modes_playable`, `slice-full`)

```
ok a career match starts from the calendar the save holds
ok the career match plays the saved season and calendar position
ok the career court is the season's own fixture
ok the rival is the season's AI profile (careerAiProfile)
ok the career match scores in points at the reference's own target
ok the season's bonus objective is `matchObjective(season, matchIndex)`
ok the career HUD carries the match objective as one line
ok the mode HUD panel draws the objective line it modelled
ok the mode HUD is visible in a mode match (and was not in a quick one)
ok the career match reaches a real result inside the tick budget
ok the career match advances the calendar through `apply_career_match`
ok the outcome is one of the reference's own four (or "" mid-season)
ok the objectives are awarded by `CareerProgress.awardObjectives`
ok the bonus objective is measured on THIS match (`matchObjective`)
ok the career payload is persisted through ModesSave.save_career
ok the career history entry reaches the albo with the season it was played in
ok the objective line on the HUD is read back from the same state the match ended in
ok the career screen shows the season and calendar the save holds
ok the career screen lists the season's objectives as the save holds them
ok the career screen reports the stars the match earned
```

Played for 10 262 ticks (points to the reference's own target). Persisted payload, read back through
a second store: `matchIndex 1`, `stars 2`, `seasonStars 2`, `losses 1`, `seasonObjectives` with
`winRally … done`, and a history entry carrying its own season. The season's objective is a HUD line
DURING the match (`OBIETTIVO  noDoubleFault 0/0  ·  FATTO`) and the season state is on the screen the
player comes back to (`# CAREER_SCREEN season=1 match=1 wins=0 stars=2`, three objective rows).

## 3. Item 4 — the demo rule, on every route

```
ok a DEMO build grants exactly one mode (js/build.js DEMO_CONTENT.modes)
ok a locked drill screen refuses to start and says why
ok a locked tournament screen refuses to start and says why
ok a locked career screen refuses to start and says why
ok a DEMO build refuses all three modes at the seal (ModeSession.can_start)
ok a DEMO build's mode screens refuse all three (ModeScreen.start_mode)
ok a DEMO build's match scene refuses a mode route and falls back to quick match
```

Four independent routes, all refused BEFORE any state or save byte exists:

1. the gate — `ModeSession.can_start(mode)` is false for all three;
2. the session — `ModeSession.start` returns `null` and reports why:
   `MODE_REFUSED mode=drill reason=drill is not in this DEMO build's granted modes ["quick"]`;
3. the screen — `ModeScreen.start_mode(true)` returns `{"started": false, "reason": …}` for all three;
4. the match scene — the route no screen can bypass: `Config.pending_mode = "drill"` set by hand and
   `res://game/Match.tscn` instantiated → `session == null`, `pending_mode` back to `quick`, and the
   state is a quick match.

`can_start` asks the build flag AND the granted list, which is exactly the rule the menu's own mode
row already used (`Gate.is_demo() and not Config.mode_ids().has(mode_id)`), so the menu, the screen
and the session cannot disagree. The one deliberate divergence from the browser is named in
`quick-match-playable.md` §13.6: the browser's training entry is a header button rather than a mode
card, so `DEMO_CONTENT.modes`/`allModes` cannot answer "is the drill playable"; this port renders all
three modes from one row and one gate and applies the build's granted list uniformly.

## 4. Item 5(a) — the accented letters

```
ok the UI font carries the Italian accented glyphs (font coverage, not a fallback)
ok the locale table's own title is the reference's, accents included
ok the reference's Italian title has no ASCII apostrophe standing in for a vowel
ok no string literal in godot/game/** spells an accented Italian word with an apostrophe
ok the menu's mode-row title is the reference's own `modesTitle` string
ok the mode-row title is laid out above the mode row, not below it
```

**Why the glyph was "missing", answered as two separate questions.** The source string was the
defect, not the font: the port typed `MODALITA'` and `gia'` as literals where the reference has
`MODALITÀ DI GIOCO` in Italian, `GAME MODES` in English, both `js/i18n.js`) and `già`. The shipped Godot font
DOES carry `à è é ì ò ù À È Ì Ò Ù ·` — asserted with `Font.has_char` in the suite, so the answer is a
measurement, not a guess. Two glyphs that WERE on screen and were NOT covered: `▸` (U+25B8) in the
outfit button and `◂` (U+25C2) on the mode screens' back button, both in the Geometric Shapes block,
both rendering as a missing-glyph box. Both were replaced with Latin-1 characters (`»`, `<`) and the
coverage check now names what the screens actually use.

**What changed.** The mode-row title reads the reference's own key instead of a literal; the port's
own Italian strings were fixed where they were typed with an apostrophe (`gia'` → `già`,
`difficolta'` → `difficoltà` in `main_menu.gd`; `piu'` → `più` in `hud.gd` and in
`content_gate.gd`'s quoted comment). The last check is structural: every double-quoted string literal
in every `.gd` file under `godot/game/**` is scanned for the accented-Italian words spelled with an
apostrophe (`piu' gia' puo' perche' difficolta' modalita' velocita' qualita' attivita' citta'
verita' meta' liberta' unita'`), so the defect cannot return in a file this lane owns without failing
the suite. `godot/src/locale/locale_data.gd` is NOT scanned: it is generated from `js/i18n.js` and the
reference itself spells some short strings with an apostrophe (`drillWhyTooBouncy`, "serve piu'
taglio"); that file is another lane's and is out of this lane's write scope.

## 5. Item 5(b) — the clipped `In the full game`

The check measures the label with the engine's own font metrics against the width the layout actually
gives the button, at 1280x720 AND 1152x648, in the Italian locale the defect was reported in:

```
before:  "TORNEO CAMPIONATO — Nella versione completa" needs 365+8 but the row is 349 (1280x720)
         "TORNEO CAMPIONATO — Nella versione completa" needs 373 but the row is 307 (1152x648)
after:   # MODE_ROW_FIT 1280x720: "TORNEO CAMPIONATO — Nella versione completa" needs 340 + 8 pad, has 391
         # MODE_ROW_FIT 1152x648: "TORNEO CAMPIONATO — Nella versione completa" needs 316 + 8 pad, has 348
ok every locked-mode row shows its whole sentence at 1280x720 and 1152x648
```

Two causes, both in `godot/game/main_menu.gd`: the section title sat INSIDE the row and reserved
118 px of the width the three mode buttons had to share (24 px too narrow at 1280x720, 66 px at
1152x648 — which is what trimmed `Nella versione completa` to `Nella versione complet`), and the
buttons carried `clip_text = true`, which is what made the overflow silent instead of visible. The
title now has its own line above the row, the clip is gone and the font is 13 px:
`menu-demo.png` shows `TRAINING — In the full game`, `CHAMPIONSHIP TOURNAMENT — In the full game`
and `CAREER — In the full game`, all three complete. A companion check asserts the title is laid out
ABOVE the row — that defect was caught in a render first, and is now asserted as a position.

## 6. Item 5(c) — the mixed-language stat labels

```
ok the reference's Italian stat labels are the ones this UI prints          (VEL, CTR, POT)
ok the English table carries the reference's other spelling, not a third one (SPD, CTL, PWR)
ok no stat label on the menu speaks English while its neighbour speaks Italian
ok every stat label on the menu is one of the reference's own ids
ok no mode screen row and no mode HUD line speaks a stat language of its own
```

The reference prints exactly three stat ids — `statSpeed`/`statControl`/`statPower`, `VEL`/`CTR`/`POT`
in Italian and `SPD`/`CTL`/`PWR` in English — and an AI tier's accuracy has **no** stat id at all
(`js/ui.js:636` feeds it as `state.ai.skill`), which is why the tier row said `skill … speed … power`
while the athlete row said `vel … pot … ctrl`. Both rows, both mode screens and the mode HUD lines now
resolve their labels from the locale table, and the accuracy figure prints the reference's own
`ability` key (`Abilità` / `Ability`) — the closest thing the reference has, named here rather than
invented. The guard is a word-boundary scan for `skill|speed|power|control` over every Button on the
menu, every open mode screen's rows and every mode HUD line; the same scan runs on the mode screens,
because a `skill 0.46` next to a `VEL` is the same defect one screen later. Rendered proof:
`menu-demo.png` → `LO STEAMER · VEL 0.92 · POT 1.24 · CTR 0.96` and
`Leggenda del Circuito · Abilità 0.90 · VEL 398 · PWR 1.14`.

## 7. One failing check that is NOT this lane's

`tests/input/run_all.gd` → 82/83, exit 1:

```
FAIL a11y/every_motion_mention_in_audio_is_a_false_diagnostic:
     expected [], got ["res://src/audio/music.gd:328"]
FAIL 82/83
```

Line 328 is the English prose word **"reduces"** in a comment another lane added
("the reference immediately reduces it"); the audit's `MOTION_WORDS` list is a substring match for
`reduce`. `godot/src/audio/music.gd` has mtime `2026-09-16 16:31:14` (a concurrent lane working in
this repository), it is under `godot/src/**` and therefore outside this lane's write scope, and no
edit in this lane touches `godot/src/audio/**` or the audit. Reported with the evidence, not
"fixed" by editing another lane's file or by weakening the check.

## 8. Artifacts (path, bytes, sha256)

| Path | Bytes | sha256 |
|---|---|---|
| `godot/game/mode_session.gd` (new) | 23772 | `9ffb4e605ad15706594932e432e0ce29ba6a92e00f3321db68daf9f329a8eb56` |
| `godot/game/mode_hud.gd` (new) | 6050 | `4703b04bc16fda0ee21f06ae40a99d4112cb65a9b5af74089717d71268eaaccf` |
| `godot/game/mode_screen.gd` | 24810 | `c4feaedde9dec42813349dadb354a58cda56fc8906e04262c8b66a623bfe4e1b` |
| `godot/game/match_controller.gd` | 47956 | `c8ad6081e0b6a39a09efccae80c439c7da8cf704419298ba62ea2bb429737bdf` |
| `godot/game/match_config.gd` | 7819 | `f56c9ee917c08bbeee1e496b44348107fdd3bcc041439e44a1c50e8ecbba9adc` |
| `godot/game/lineup.gd` | 6063 | `3132662d6594c310f49b71fcb1bd734eadc480c679874835e7dc3e9542bda50b` |
| `godot/game/main_menu.gd` | 25884 | `4851a8bfe347dbd40574c5b3f75c02822f28cefe8d84ae8d032ba1467ff4b437` |
| `godot/game/hud.gd` | 30006 | `07940213f5472a784adcc41516a6094a00f5e761c89a0d3cda26235d1b95cf16` |
| `godot/game/content_gate.gd` | 5247 | `3709bf2bef355e0538d1fcf9b90ed175dc5599b92722bf3a55c3ed3b847dcf8a` |
| `godot/tests/game_slice_test.gd` | 137071 | `ebf0e3dbd020d6d2018757561d9de6ac8883a87d6817bc548f6e47bc977b06aa` |
| `godot/game/out/mode-drill.png` | 225193 | `d63451473923cb729e9efe4094735d75e13a802428a0a4d77f0c15c08e6ec9f2` |
| `godot/game/out/mode-tournament.png` | 202375 | `72b0e866f127cd97420792df4086c82ffa6917aed601d1cdce24c1e435383740` |
| `godot/game/out/mode-career.png` | 207862 | `d901f4c50ed7a62adebafc1d8289f700e47e37b84eb6033eec8202c06a3279da` |
| `godot/game/out/mode-career-screen.png` | 72785 | `8d410f8c65d083b8237c5a34f653879a0ddbccf27b86c1844d4f19311a504b04` |
| `godot/game/out/menu-demo.png` | 120951 | `d9a93c0075109e6d22e5a341adf7486dc68403fa100dda85ebe61fb369d1619f` |
| `docs/wayfinder/evidence/modes-playable.md` (this file) | 23204 | `efa12f4b7a3420f62bc38040ca8d8c534ffecaabbe780d31ab72512c07f3a270` |
| `docs/wayfinder/evidence/quick-match-playable.md` (§13 appended) | 107660 | `1fd3fa2d5f56bd45370b668df943ecf27583f8d39399510df34ebac17e550338` |

The two document hashes are the versions measured at hand-off — measured before this table's own
last edit, because a document cannot contain its own final hash.

Run logs are copied out of `/tmp` into `godot/build/logs/` (never committed):
`2026-09-16-{baseline-full,slice-full,slice-demo,engine-harness,rules-audits,input-suite,capture-mode-huds,capture-career-screen,capture-demo-menu}.log`.

Exact commands, as run (every Godot invocation under the shared lock, with the timeout inside it):

```
GODOT=/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64
flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $GODOT --headless --path godot/ --script res://tests/game_slice_test.gd            # full,  exit 0
flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $GODOT --headless --path godot/ --script res://tests/game_slice_test.gd -- --demo  # demo,  exit 0
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $GODOT --headless --path godot/                                                   # harness, exit 0
flock -w 900 /tmp/padel-godot.lock timeout 1200 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $GODOT --headless --path godot/ --script res://tests/audits/run_all.gd             # audits, exit 0
flock -w 900 /tmp/padel-godot.lock timeout 600 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $GODOT --headless --path godot/ --script res://tests/input/run_all.gd              # input,  exit 1 (§7)
# renders (software GL: correctness frames only, no frame-rate claim)
flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 \
  --resolution 1280x720 --path godot/ res://game/Match.tscn -- --capture=modes
flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 \
  --resolution 1280x720 --path godot/ res://game/ModeScreen.tscn -- \
  --capture=1 --mode=career --save-dir=user://slice-modes-test
flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 \
  --resolution 1280x720 --path godot/ res://game/Main.tscn -- --capture=menu --demo --out=menu-demo
```

## 9. What the new modules expose (API, so the next lane does not have to read them)

`godot/game/mode_session.gd` — `ModeSession.can_start(mode)`, `ModeSession.refusal(mode)`,
`ModeSession.start(mode, store, opts := {}) -> ModeSession | null`, `session.mode/.arena/.ai/.fixture/
.round/.season/.match_index`, `session.state` (the real sim state), `session.phase`
(`ready|live|done`), `session.step(dt, input, input2 := {})`, `session.is_done()`,
`session.finish() -> Dictionary` (award + persist, ONCE and idempotent), `session.hud()`,
`session.report()`.

`godot/game/mode_hud.gd` — `bind_session(session)`, `refresh()`, `report()`; hidden unless a session
exists.

`godot/game/match_config.gd` — `pending_mode`, `pending_exercise`, `pending_round` (`-1` = "the
save's"), `save_dir`, `save_store()`, `mode_options()`; the capture-only arguments `--mode=`,
`--save-dir=` (mode screen) and `--capture=modes` (match scene) exist so a render can show the screen
a player sees.

`godot/game/mode_screen.gd` — `start_mode(dry_run := false) -> Dictionary`, `saved_state()`,
`screen_report()` (rows, lock state, `startable`, the save's own numbers).

## 10. What is NOT done

* **No human playthrough in a rendered window.** Modes are played by the scripted player through
  `tick_fixed` and rendered in three correctness frames; no interactive `xvfb` session was played.
* **The tournament round that is PLAYED ends in a loss** at the pinned seed — the bracket-RESET
  branch. The WIN branch (`advance(round, true)` → `save_tournament_round`) is exercised with a
  FORCED result and is labelled as such in the check's own comment and in §2.2. The scripted player
  was not re-tuned to win, and no win was dressed up as a played match.
* **Career: season 1, first match only.** Later seasons, the finale and the promotion path are the
  modes lane's own audits (`modes-port.md`, 3 603 checks), not a played match here.
* **The demo build is proven by the build flag in the project (`-- --demo`), not by a fresh export.**
  No preset was re-exported; the packaged demo binary was not rebuilt or re-run.
* **`godot/src/**` untouched.** Where a rule needed a different input, the CALLER changed:
  `Lineup.resolve` learned to take the dictated rival pair and `modes_save.gd::save_tournament_round`
  got its first caller.
* **The input-suite failure in §7 is left failing**, with its cause named, because it belongs to
  another lane's file.
* **The `resources still in use at exit` allowance is unchanged** — its cause is a `static var
  Shader` in `godot/src/character/outfit_catalogue.gd:95`, outside this lane's write scope.
