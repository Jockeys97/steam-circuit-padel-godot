# Pace integration — completion report

STATUS: **ready_for_review** (Astra owns acceptance).

## Workspace

- Repo: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`
- Branch: `codex/integrate-arena-11m`, HEAD `7b4dc561ac262555649ea0ec3f184466c382126c`
- Source: Luca commits `9ea56e5` + `e2be431` (available locally on
  `origin/luca-game-mechanics`), ported selectively — no branch merge, no
  whole-file overwrite. Both commits' parents are ancestors of HEAD for every
  file except the ones noted below, so each pace hunk was applied at its own
  anchor.

## Changed paths and behaviour

New (untracked, awaiting Astra's staging decision):

- `godot/src/sim/pace.gd` — the ladder as a time rate. Byte-identical to
  `9ea56e5:godot/src/sim/pace.gd` (sha256 `1f1e2a92…`).
- `godot/tests/pace_presets_test.gd` — byte-identical to the source commit.
- `godot/tests/pace_screen_test.gd` — byte-identical to `e2be431`.

Modified (exact unified diff in `DIFF-vs-baseline.patch`):

| file | delta |
| --- | --- |
| `godot/game/match_config.gd` | `+16`: `Pace` preload, `pace_id()`, `pace_factor()` |
| `godot/game/match_controller.gd` | `+42/-4` total; the pace part is `pace_factor` var, two `Config.pace_factor()` latches (`_adopt_session`, `start_match`), and `advance_frame` scaling `dt` and the catch-up clamp |
| `godot/src/save/save_schema.gd` | `+9`: `Pace` preload + `PREFS_DEFAULTS["pacePreset"] = Pace.DEFAULT_ID` |
| `godot/src/ui/data/UiData.gd` | `+1`: `pace_preset` in `settings_snapshot` |
| `godot/src/ui/screens/SettingsScreen.gd` | `+80`: pace group, `pace()`, `set_pace()`, `_refresh_pace()`, focus rows |
| `godot/src/ui/screens/ModesScreen.gd` | `+130`: pace group, `active_pace()`, `select_pace()`, `_refresh_pace()`, aria, focus |
| `godot/src/ui/screens/ModesScreen.tscn` | `+26/-2`: `MatchSetup` → `HFlowContainer`, new `PaceGroup` subtree |
| `godot/tests/save_steam_test.gd` | `+17/-3` (port-addition pref key + split default count) |
| `godot/tests/ui/screen_modes_audit.gd` | `+17/-3` (focusables 14→19, pace-rung actions) |

`match_controller.gd` was already dirty with unrelated quick-match outfit work
(`_quick_outfit_award`, `_finish_quick_outfits`) and `mode_session.gd` with
tournament outfit awards. The `DIFF-vs-baseline.patch` hunk for
`match_controller.gd` contains **only** the pace lines: the pre-existing dirty
hunks are untouched.

### Baseline capture (pre-edit)

- `baseline/manifest.txt` — branch, HEAD, UTC timestamp, sha256 of the nine
  affected files, `PRESENT/ABSENT` for the three new files, `git status` of the
  affected paths (only `match_controller.gd` was dirty among them).
- `baseline/files/**` — verbatim pre-edit copies of the nine affected files.
- `final-manifest.txt` — post-edit sha256 for the same twelve paths.

## Verification (exact commands)

Prefix: `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path godot --script res://<test>`.
All saves are isolated (`user://save_test`, `user://pace-screen-test`, audit temp
dirs); the live `user://save` is never written. Logs in `logs/`, baseline logs in
`baseline-logs/`.

| command | exit | salient result |
| --- | --- | --- |
| `tests/pace_presets_test.gd` | 0 | `PASS pace presets: 59 checks, 0 failures` |
| `tests/pace_screen_test.gd` | 0 | `PASS 101/101`; tick table `{"realistic":180,"brisk":120,"standard":90,"relaxed":72,"learning":60}` over 60 real frames |
| `tests/save_steam_test.gd` | 0 | `PASS 138/138` (baseline 137/137; +1 = the port-addition default check) |
| `tests/ui/screen_modes_audit.gd` | 0 | `PASS 119/119` (baseline 118/118; +1 pace-rung action) |
| `tests/ui/screen_settings_audit.gd` | 0 | `PASS 91/91` (unchanged) |
| `tests/audits/court_speed_audit.gd` | 0 | `PASS 25/25` |
| `tests/rally_stamina_test.gd` | 0 | `PASS 262/262` |
| `tests/athlete_stroke_bridge_test.gd` | 0 | `PASS 75/75` |
| `tests/ui/ui_legibility_audit.gd` | 0 | `PASS 676/676` (baseline 676/676) |
| `tests/ui/router_audit.gd` | 0 | `PASS 86/86` (literal scan over the new panel) |
| `tests/ui/hud_audit.gd` | 0 | `PASS 172/172` |
| `tests/modes/save_progression_audit.gd` | 0 | `PASS 46/46` |
| `tests/ui/screen_characters_audit.gd` | 0 | `PASS 170/170` |
| `tests/modes/run_all.gd` | 0 | `PASS 6/6` |
| `tests/ui/demo_matrix_audit.gd` | 0 | `PASS 133/133` |
| `tests/ui/uir22_integration_audit.gd` | 0 | `PASS 75/75` |
| `tests/audits/run_all.gd` | 1 | `FAIL 9/10` — sole red is `lineup` (pre-existing, see below) |
| `tests/audits/lineup_audit.gd` | 1 | `FAIL 22/23` — `lineup/resistant_partner_leaves_more_team_energy` |
| `tests/ui/data_audit.gd` | 1 | `FAIL 130/131` — `data/one_drill_row_per_frozen_exercise` (pre-existing, see below) |

### Pre-existing failures, proven not regressions

- `lineup/resistant_partner_leaves_more_team_energy`: expected `> 0.740000`, got
  `0.740000`; report line `energy(resistant=0.740 fragile=0.740)` against the
  reference's `0.529/0.440`. `lineup_audit.gd` preloads only
  `sim.gd/frozen.gd/state.gd/audit_base.gd/audit_support.gd` — none of the files
  this bundle touches. `docs/agent-work/jev-coach/logs/run_all_audits.log:179`
  shows it passing before the concurrent rally-stamina work landed. Not fixed
  (out of scope, per root).
- `data/one_drill_row_per_frozen_exercise`: expected 4, got 5, from
  `Tables.drill_catalog()` (4 frozen + 1 Godot-only) vs `Tables.drill_exercises()`
  (4) — pre-existing concurrent drill work. Re-ran with my single `UiData.gd`
  line temporarily removed: identical `FAIL 130/131`
  (`baseline-logs/tests_ui_data_audit_without_pace_key.log`), then restored.

## Acceptance mapping

- Five presets selectable in Settings and on match setup: `SettingsScreen`
  `Pace_<id>` buttons and `ModesScreen` `PaceButton_<id>` rungs, both driven by
  `Pace.ids()`.
- Persisted through isolated test saves and applied at the next match:
  `pace_screen_test` presses each rung's own `pressed` signal and reads the value
  back three ways (payload, the prefs group file on disk, `Config.pace_id()`),
  then boots one `Match.tscn` per rung.
- Measured ticks per 60 real frames = 180/120/90/72/60 for factors 1.50/1.00/0.75/
  0.60/0.50 — the ladder, measured on the real `advance_frame`.
- Missing/invalid preference preserves old behaviour: `brisk` factor is exactly
  `1.0`; an unknown stored id and a save without the key both read back as the
  default, and `pace_factor()` stays `1.0`.
- Scaling happens once, on the clock, never on a BALANCE constant; `court_speed_audit`
  is unchanged at 25/25.
- Stamina/animation compatibility: `rally_stamina` integrates on the sim tick's
  own `dt` (`FIXED_STEP`) and `athletes_view.sync(state)` is state-driven, so the
  rate change is applied once and no double-scaling occurs; both suites pass.
- Narrow supported size: `pace_screen_test` asserts containment at 1024x600 and
  1280x720 (row inside area, group inside row, every rung inside its box) in
  default and `demo-locked` states.

## Visual QA

`shots/` (captured with the port's own `tests/ui/capture_ui.gd`, outputs moved
here so `godot/game/out/` is left as found):

- `ui-modes.png` — the three-group setup row; `GAME PACE` with `Brisk (1.5:1)`
  selected.
- `ui-modes-demo-locked.png` — the demo view wraps the third group onto a second
  line instead of overflowing the frame.

## Limits and decisions for Astra

1. `.uid` sidecars for the three new scripts are **not** generated (headless
   `--script` runs do not emit them; the source commits left them untracked too).
   Godot creates them on the next editor open. Nothing references these files by
   uid.
2. The narrow-size check is programmatic, not a PNG: `--resolution` is overridden
   by the project's window setting, so the capture harness renders 1280x720
   regardless.
3. The two source commits also carried `docs/mission/LOG.md`, `docs/wayfinder/evidence/*`,
   and top-level probes `godot/_probe_pace_clock.gd` / `_probe_pace_row.gd`. Those
   are outside the plan's owned scope and were deliberately not ported; say the
   word if Astra wants them.
4. `lineup` (audits) and `data_audit` are red on unrelated concurrent work; not
   touched.

Nothing here is committed, staged, pushed, or deployed.
