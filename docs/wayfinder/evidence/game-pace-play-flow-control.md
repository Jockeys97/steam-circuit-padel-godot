# The game-pace rung on the play-flow screen, and the setup row it needed

Date: 2026-09-19 · Repo `steam-circuit-padel-godot`, worktree `luca-game-mechanics`, branch
`luca-game-mechanics`, HEAD `9ea56e53` (`feat(pace): selectable game-pace presets …`).

**What this adds.** The pace ladder that shipped in `godot/src/sim/pace.gd` was reachable only from
Settings. It is now also on the screen a match is actually started from: a third group inside
`#matchSetup` on `screen-modes`, next to the reference's difficulty rungs and match-length formats.
Pressing a rung writes the stored preference through the reference's own carrier and the
simulation's clock follows it — both shown below with engine output, not inference.

**Nothing is committed.** All changes are uncommitted/untracked for the owner; generated
`*.gd.uid` sidecars stay untracked. One engine process at a time throughout (`pgrep -x Godot` guard
in the sweep script); engine `4.7.2.stable.official.ed1daf0bf`.

---

## 1. The control

| What | Where |
|---|---|
| The group | `Frame/ScreenScroll/Body/SetupArea/MatchSetup/PaceGroup` (`PanelContainer`) |
| Its stack | `…/PaceGroup/PaceStack` (`VBoxContainer`), title `…/PaceStack/PaceLabel` |
| The segmented box | `…/PaceStack/PaceSegmentedBox` (`PanelContainer`, theme variation `SegmentedContainer`) |
| The rungs | `…/PaceSegmentedBox/PaceSegmented` (`GridContainer`, `columns = 1`), one `Button` per `Pace.ids()` entry, named `PaceButton_<id>` in ladder order |
| The write | `ModesScreen.select_pace(id) -> bool` — `ModesSave.save_pref(Config.save_store(), "pacePreset", id)`, refused for an id outside the ladder |
| The read-back | `ModesScreen.active_pace() -> String` — `Config.pace_id()` |
| The strings | `ModesScreen._refresh_pace()` — rung labels and group title through `Pace.text(key, lang)`, so a language flip re-labels them; **no new literal** in the screen or the scene (the UI lane's scan is unchanged and clean) |
| The wire | `PaceButton_<id>.pressed -> select_pace(<id>)`; the focus bridge reports `pace:<id>`, and `activate("pace:<id>")` is the same door the other segments use |

The ladder is `Pace.ids()`, not a copy: the screen renders five rungs because the module has five,
and its labels come from the module's own `label_key`s. `Pace.factor`, `Pace.default_id()` and the
`Pace` tables are untouched; nothing was scaled anywhere but `match_controller.advance_frame`.

**Where this differs from Settings, deliberately.** The Settings screen keeps its own pace row
(`PaceGroup`/`PaceSeg`/`Pace_<id>`, with the blurb under the rungs). The play-flow group carries the
title and the rungs, not the blurbs: the setup row is a compact three-up row and the two reference
groups carry no hint text either. Both groups write and read the same `pacePreset` key, so the two
screens cannot disagree.

---

## 2. The press changes the stored preference (and the file on disk)

`tests/pace_screen_test.gd`, section 3, presses each rung's own `pressed` signal and reads the
pref back three ways — the raw `prefs` payload, the group file on disk, and the match's own reader:

```
ok pace/a_press_on_realistic_stores_the_rung        ok pace/a_press_on_realistic_reaches_the_file
ok pace/the_matchs_own_reader_sees_realistic        ok pace/the_screen_reads_realistic_back
… one set per rung, 5 rungs …
ok pace/the_door_refuses_an_unknown_rung            ok pace/a_refused_rung_leaves_the_stored_one_alone
ok pace/the_rung_lands_in_the_reference_carrier_not_a_second_field
```

"Reaches the file" is `JSON.parse_string(FileAccess.get_file_as_string(store.group_path("prefs")))`
— not a second read of the same in-memory dictionary. A save from a build without the key, and a
stored id outside the ladder (`no_such_pace`), both read back as `Pace.default_id()` with factor
`1.0`, and the screen shows the default rung rather than no rung at all.

## 3. The press changes the simulation clock

Measured, not inferred: one `Match.tscn` booted per rung in harness mode, driven by the real
`advance_frame(1/60)` for 60 frames, counting whole `FIXED_STEP` ticks. 60 frames at 1/60 is exactly
120 ticks at factor 1.0, so the expectations are exact integers:

| Rung | factor | expected ticks / 60 frames | measured (screen press → clock) | measured (`_probe_pace_clock.gd`) |
|---|---|---|---|---|
| `realistic` | 1.50 | 180 | 180 | 180 |
| `brisk` *(default)* | 1.00 | 120 | 120 | 120 |
| `standard` | 0.75 | 90 | 90 | 90 |
| `relaxed` | 0.60 | 72 | 72 | 72 |
| `learning` | 0.50 | 60 | 60 | 60 |

```
# report ticks over 60 frames: {"brisk":120,"learning":60,"realistic":180,"relaxed":72,"standard":90}
```

The difference between this and `_probe_pace_clock.gd` is the whole point of the new test: the probe
writes the pref itself, this one presses the rung on the play-flow screen and then boots the match,
so the chain UI → prefs → clock is the thing under measurement. Each boot also asserts the
controller latched the right factor (`PaceButton_<id>` → `Config.pace_factor()` →
`match_controller.pace_factor`, `pace/<id>_match_latched_the_rungs_factor`, 5 checks). The default
rung reproduces the pre-feature clock exactly (`the_default_rung_reproduces_the_pre_change_clock`),
and the whole table is asserted against the ladder in one check.

---

## 4. The regression this change caused, and the layout fix

The first post-change sweep put `ui_legibility_audit` at **FAIL 660/664** — four containment
failures, all `modes/demo-locked`, one per audited frame size:

```
FAIL legibility/1280x720/modes/demo-locked/containment: expected [], got
  ["Frame [P: (-32.5, 0.0), S: (1345.0, 720.0)] outside ModesScreen [P: (0.0, 0.0), S: (1280.0, 720.0)]"]
FAIL legibility/1152x648/modes/demo-locked/containment  … S: (1217.0, 648.0) outside S: (1152.0, 648.0)
FAIL legibility/1920x1080/modes/demo-locked/containment … S: (1977.0, 1080.0) outside S: (1920.0, 1080.0)
FAIL legibility/1024x600/modes/demo-locked/containment  … S: (1089.0, 600.0) outside S: (1024.0, 600.0)
```

**Root cause, measured** (`_probe_pace_row.gd`, run before the fix): `SetupArea` centres the
reference's own content box with two margins, `side = max(0, (size.x - 760) / 2) + 24`, so the box
it holds is `760 - 2 * 24 = 712` px — and a `MarginContainer`'s minimum size *includes* its margins,
so a row whose minimum exceeds 712 px overflows the screen at every width (the margins grow with the
frame, the box does not). The binding state is the demo view: the three un-granted difficulty rungs
are `disabled` there, and the theme's disabled segmented box is far wider than its normal one —

```
diff easy    disabled=false min=36.0      diff easy    disabled=true  min=80.0
diff hard    disabled=false min=38.0      diff hard    disabled=true  min=82.0
diff legend  disabled=false min=51.0      diff legend  disabled=true  min=95.0
```

which takes `DifficultyGroup` from 235 to 367 px and the row (637 px with the pace group, 483 px with
the original two) to **769 px**. The two-group row survived that (615 px ≤ 712); the third group did
not. So the third group is not itself the defect — it is what made a latent 769 px state reachable.

**The fix is in the layout, not the assertion.** `MatchSetup` is now a wrapping `HFlowContainer`
(was `HBoxContainer`), `h_separation`/`v_separation` 18 — the row's own minimum becomes its widest
child instead of the sum of its children:

| | before the fix (row = HBox) | after (row = HFlow) |
|---|---|---|
| row minimum, live view | 637 px | **235 px** |
| row minimum, demo view | 769 px | **367 px** |
| `Frame` minimum, demo view | 1345 px (> 1280) | **943 px** |
| three groups at 1280 / 1024 | one line, equal height | one line, equal height (unchanged look) |
| three groups in the demo view | clipped past the right edge | wraps: difficulty + length on line 1, pace at `y = 183` on line 2 |

The `SetupArea` width rule, the two reference groups' own content, the theme and the screen's
`GRID_BREAKPOINT` handling are all untouched. The wrap only happens in the state that needed it
(`HFlowContainer` packs greedily: 367 + 18 + 230 = 615 ≤ 704 on line 1, then the pace group). The
step cost is that the leftover space in the row is now shared equally by the three groups
(257 / 252 / 158 px) instead of landing on the last child as it did with the `HBoxContainer`
(235 / 230 / 203 px); the groups' frames, padding and buttons are unchanged.

## 5. Gates

Every command below was run serially, one engine process at a time, journaled to
`/tmp/pace-sweep.<phase>.log`; `before` is HEAD `9ea56e5` without this change, `after` is this tree.
`SCRIPT ERROR` counts are the strict gate (`godot/game/check_log.sh`: a `PASS n/n` beside a
`SCRIPT ERROR` is a failure).

| # | Command | before (exit / tally / SCRIPT ERROR) | after (exit / tally / SCRIPT ERROR) |
|---|---|---|---|
| 1 | `tests/pace_presets_test.gd` | 0 / `PASS pace presets: 59 checks, 0 failures` / 0 | 0 / `PASS pace presets: 59 checks, 0 failures` / 0 |
| 2 | `tests/pace_screen_test.gd` **(new)** | absent (file not found) | **0 / `PASS 101/101` / 0** |
| 3 | `tests/ui/screen_settings_audit.gd` | 0 / `PASS 91/91` / 0 | 0 / `PASS 91/91` / 0 |
| 4 | `tests/ui/screen_modes_audit.gd` | 0 / `PASS 118/118` / 0 | 0 / `PASS 119/119` / 0 |
| 5 | `tests/ui/ui_legibility_audit.gd` | 0 / `PASS 664/664` / 0 | **0 / `PASS 664/664` / 0** (660/664 mid-change, §4) |
| 6 | `tests/save_steam_test.gd` | 0 / `PASS 138/138` / 0 | 0 / `PASS 138/138` / 0 |
| 7 | `tests/audits/court_speed_audit.gd` | 0 / `PASS 25/25` / 0 | 0 / `PASS 25/25` / 0 |
| 8 | `tests/game_slice_test.gd` | 1 / `FAIL 342/343` / 0 | 1 / `FAIL 342/343` / 0 |
| 9 | `node tools/i18n-port/hud-coverage.mjs --fail-on-leak` | 0 / (108 ids, 0 print the id) / — | 0 / (108 ids, 0 print the id) / — |
| 10 | `_probe_pace_clock.gd` | 0 / `PASS 16/16` / 0 | 0 / `PASS 16/16` / 0 |
| 11 | `_probe_pace_row.gd` **(new, ad-hoc)** | — | 0 / `PASS pace row: 9 checks, 0 failures` / 0 |

`tests/game_slice_test.gd`'s single red is the absent export pack, run for run:
`FAIL the shipping pack exists (export it before running this test): expected true, got
res://build/linux-x86_64/padel.pck`. Nothing else in that log fails. Its engine `ERROR:` line is the
named `arena_library` guard allowance (the slice provokes it on purpose); the second allowance
(`N resources still in use at exit`) is intermittent and did not appear in this run. `WARNING:`
counts are unchanged between the two phases (47 → 46 in the slice, 10 in the two probes'
match boots — pre-existing anchor chatter, zero `ERROR:` lines in either probe).

### Counts changed in an existing audit

`godot/tests/ui/screen_modes_audit.gd` is the only existing audit touched, and only where the
screen's own shape is recorded:

| Where | Before | After |
|---|---|---|
| `_bridge`: `specs.size()` | `14`, `the_screen_registers_fourteen_focusables` | `19`, `the_screen_registers_nineteen_focusables` |
| `_bridge`: `bridge.ids().size()` | `14`, `the_bridge_reads_the_fourteen_controls` | `19`, `the_bridge_reads_the_nineteen_controls` |
| `_bridge`: new check | — | `modes/every_pace_rung_reports_its_own_action` (every `Pace.ids()` rung reports `pace:<id>`) |
| audit tally | `PASS 118/118` | `PASS 119/119` |

`ui_legibility_audit.gd` was **not** edited: its 664 checks are the same 664, and the layout was
changed until they passed again.

---

## 6. Files

| File | Change |
|---|---|
| `godot/src/ui/screens/ModesScreen.tscn` | +`PaceGroup`/`PaceStack`/`PaceLabel`/`PaceSegmentedBox`/`PaceSegmented` under `MatchSetup`; `MatchSetup` retyped `HBoxContainer` → `HFlowContainer` with `h_separation`/`v_separation` 18 |
| `godot/src/ui/screens/ModesScreen.gd` | +`Pace`/`Locale` preloads, `PACE_*` constants, `_pace_buttons`, the segment build, `_pace_button`, `active_pace()`, `select_pace()`, `_refresh_pace()`, the `pace:` action, the focus specs, the aria slot, the chrome list entries, and two header notes (the group is a port addition; why the row wraps) |
| `godot/tests/pace_screen_test.gd` | new — 101 checks (§2, §3, §4) |
| `godot/tests/ui/screen_modes_audit.gd` | the two counts above + one new focus check + a header sentence |
| `godot/_probe_pace_row.gd` | new ad-hoc probe — the row's minimum width in both states, self-checking (9 checks) |
| `godot/src/ui/screens/ModesScreen.gd.uid`, `godot/tests/pace_screen_test.gd.uid`, `godot/_probe_pace_row.gd.uid` | generated by the engine, left untracked as the convention requires |

Untouched: `js/**`, `index.html`, `styles.css`, `godot/src/sim/frozen/**`,
`godot/src/locale/**`, `godot/src/sim/pace.gd`, `godot/game/match_controller.gd`,
`godot/game/match_config.gd`, `godot/src/save/save_schema.gd`, `tools/i18n-port/**`. `git status`
on those paths is empty. `tools/i18n-port/verify-i18n-port.mjs` is still red as it was found at this
lineage (`resolve-rules.json`'s recorded reference hash vs the live `js/i18n.js`; four reference keys
the port lacks, including `betaCareerNote` and `storeFollow`) — not this change, and provably so:
`git status` on `godot/src/locale/`, `tools/i18n-port/` and `js/` is empty.

---

## 7. Limitations, stated plainly

- **The pace group hides with the row.** `#matchSetup`'s stated rule is quick-only
  (`syncMatchSetup`, kept by `setup_visible()`), so on a tournament/career session the play-flow
  group is not on screen even though the preset still applies to every mode
  (`match_controller` latches it in both start paths). The Settings screen's identical control is
  reachable in every mode, so nothing is unreachable — but the same control now lives in a
  quick-scoped container. Recorded, not silently resolved; the placement was the mission's call.
- **The wrap's second line is full-width.** In the demo view the pace group takes the whole 704 px
  row on its own line, so its five rungs are 660 px wide there. That state is a port-side
  reconstruction of a demo build (the reference never renders three setup groups), and the
  alternative was clipping.
- **`-- --demo` was not run.** `pace_screen_test.gd` exercises the demo presentation through the
  declared `demo-locked` capture state in a full build (as `screen_modes_audit` does), not through
  a demo build of the game; `DemoContent`'s table is what that state reads.
- **Mid-match changes cannot retune a running match.** The factor is latched at match start; a
  rung pressed during a match takes effect on the next one. That is the feature's own seam, and this
  change does not move it.
- **`Pace.scaled_dt()` still has no production caller** (the controller spells the multiplication
  inline). Pre-existing, noted in the sibling parity document, not touched here.
- **The four audited frame sizes are not every frame size.** The containment property is asserted at
  1280×720, 1152×648, 1920×1080 and 1024×600 plus the two the pace test measures; the *invariant*
  the fix rests on — the row's minimum never exceeding the 712 px content box — is asserted in both
  states at both of those frames, but not proven for arbitrary widths.
