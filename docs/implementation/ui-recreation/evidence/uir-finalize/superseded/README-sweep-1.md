# Finalize wave — engine record (2026-09-17, integration captain, sole engine owner)

One Godot process at a time (`pgrep -x Godot` guard before every run), the real checkout,
`/Applications/Godot.app/Contents/MacOS/Godot` (v4.7.2.stable.official.ed1daf0bf). A `PASS`
line next to a `SCRIPT ERROR` is a failure, so both are counted separately below; `engine_lines`
is the count of `SCRIPT ERROR` / `Parse Error` / `^ERROR:` lines, and the two lines named in
`godot/game/check_log.sh` (the arena unknown-id probe and the engine shutdown report) are called
out where they occur.

Machine-readable manifest: `ui-audit-sweep.json` (per run: exact command, exit code, tally,
ok/FAIL counts, SCRIPT ERROR count, log path) plus `sources` — sha256[:16] of every file under
`godot/game`, `godot/src`, `godot/tests` and `project.godot` — and `tree_digest_before/after`
(equal, so no source moved while the sweep ran).

Re-run everything:

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
pgrep -x Godot || true                       # must print nothing
python3 /tmp/uir-finalize/sweep.py docs/implementation/ui-recreation/evidence/uir-finalize
```


## 1. The sweep — 32 runs, one engine at a time

| # | run | command | exit | tally | SCRIPT ERROR | engine lines | s |
|---|---|---|---|---|---|---|---|
| 1 | harness | `$GODOT --headless --path godot/` | 0 | PASS 8/8 | 0 | 0 | 0.2 |
| 2 | game_slice_test | `--script tests/game_slice_test.gd` | 0 | PASS 342/342 | 0 | 2 | 18.3 |
| 3 | game_slice_test_demo | `--script tests/game_slice_test.gd -- --demo` | 0 | PASS 293/293 | 0 | 1 | 15.1 |
| 4 | input_run_all | `--script tests/input/run_all.gd` | 0 | PASS 5/5 | 0 | 0 | 0.4 |
| 5 | audits_run_all | `--script tests/audits/run_all.gd` | 0 | PASS 10/10 | 0 | 0 | 79.6 |
| 6 | modes_run_all | `--script tests/modes/run_all.gd` | 0 | PASS 6/6 | 0 | 0 | 0.8 |
| 7 | save_steam_test | `--script tests/save_steam_test.gd` | 0 | PASS 137/137 | 0 | 0 | 0.2 |
| 8 | music_port_test | `--script tests/music_port_test.gd` | 0 | PASS 32/32 | 0 | 0 | 15.5 |
| 9 | theme_probe | `--script tests/ui/theme_probe.gd` | 0 | PASS 305/305 | 0 | 0 | 0.3 |
| 10 | router_audit | `--script tests/ui/router_audit.gd` | 0 | PASS 86/86 | 0 | 2 | 0.5 |
| 11 | data_audit | `--script tests/ui/data_audit.gd` | 0 | PASS 131/131 | 0 | 0 | 0.3 |
| 12 | fonts_assets_probe | `--script tests/ui/fonts_assets_probe.gd` | 0 | PASS 75/75 | 0 | 0 | 0.6 |
| 13 | hud_audit | `--script tests/ui/hud_audit.gd` | 0 | PASS 172/172 | 0 | 0 | 1.3 |
| 14 | pause_audit | `--script tests/ui/pause_audit.gd` | 0 | PASS 176/176 | 0 | 0 | 0.6 |
| 15 | input_a11y_audit | `--script tests/ui/input_a11y_audit.gd` | 0 | PASS 153/153 | 0 | 0 | 0.4 |
| 16 | osk_touch_audit | `--script tests/ui/osk_touch_audit.gd` | 1 | FAIL 171/177 | 0 | 0 | 0.5 |
| 17 | ui_legibility_audit | `--script tests/ui/ui_legibility_audit.gd` | 1 | FAIL 572/664 | 4 | 4 | 8.1 |
| 18 | uir22_integration_audit | `--script tests/ui/uir22_integration_audit.gd` | 0 | PASS 71/71 | 0 | 0 | 3.5 |
| 19 | replay_audit | `--script tests/ui/replay_audit.gd` | 1 | FAIL 95/103 | 2 | 2 | 0.7 |
| 20 | screen_menu_audit | `--script tests/ui/screen_menu_audit.gd` | 0 | PASS 97/97 | 0 | 1 | 0.8 |
| 21 | screen_modes_audit | `--script tests/ui/screen_modes_audit.gd` | 0 | PASS 118/118 | 0 | 0 | 0.7 |
| 22 | screen_characters_audit | `--script tests/ui/screen_characters_audit.gd` | 1 | FAIL 147/148 | 0 | 0 | 1.2 |
| 23 | screen_arena_audit | `--script tests/ui/screen_arena_audit.gd` | 0 | PASS 133/133 | 0 | 0 | 0.8 |
| 24 | screen_drill_audit | `--script tests/ui/screen_drill_audit.gd` | 0 | PASS 89/89 | 0 | 0 | 0.4 |
| 25 | screen_result_audit | `--script tests/ui/screen_result_audit.gd` | 0 | PASS 176/176 | 0 | 0 | 0.7 |
| 26 | screen_settings_audit | `--script tests/ui/screen_settings_audit.gd` | 0 | PASS 91/91 | 0 | 0 | 0.4 |
| 27 | screen_feedback_audit | `--script tests/ui/screen_feedback_audit.gd` | 0 | PASS 119/119 | 0 | 3 | 0.5 |
| 28 | screen_help_audit | `--script tests/ui/screen_help_audit.gd` | 1 | FAIL 73/75 | 2 | 3 | 0.4 |
| 29 | screen_history_audit | `--script tests/ui/screen_history_audit.gd` | 1 | FAIL 37/42 | 4 | 6 | 0.5 |
| 30 | screen_challenges_audit | `--script tests/ui/screen_challenges_audit.gd` | 1 | FAIL 64/68 | 1 | 2 | 0.5 |
| 31 | screen_profile_audit | `--script tests/ui/screen_profile_audit.gd` | 1 | FAIL 44/60 | 3 | 4 | 0.3 |
| 32 | uir_route_audit | `--script tests/ui/uir_route_audit.gd` | 0 | PASS 44/44 | 0 | 0 | 4.3 |

- **PASS runs: 24 of 32** — exit 0, no `FAIL` line, 0 `SCRIPT ERROR`.
- **Red / non-clean runs: 8** — osk_touch_audit, ui_legibility_audit, replay_audit, screen_characters_audit, screen_help_audit, screen_history_audit, screen_challenges_audit, screen_profile_audit.
- Total checks passed in the green runs: **2869**.
- Total `SCRIPT ERROR` lines across the sweep: **16**.

## 2. The reds, with their cause (no ticket is done off a partial green)

### osk_touch_audit — FAIL 171/177, exit 1, 0 SCRIPT ERROR
- `FAIL osk/no_targets_while_closed: expected 0, got 51`
- `FAIL osk/every_key_of_the_grid_is_a_target: expected 52, got 51`
- `FAIL osk/the_first_row_sits_above_the_action_row: expected "< 0.000000", got 0.000000`
- `FAIL osk/the_closed_signal_names_the_field: expected "pause/fb-message", got ""`
- `FAIL touch/the_default_instance_finds_its_palette: expected true, got false`
- `FAIL touch/a_screen_touch_press_on_the_deck_drives_the_action: expected true, got false`

### ui_legibility_audit — FAIL 572/664, exit 1, 4 SCRIPT ERROR
- `FAIL legibility/1280x720/arena/default/contrast: expected [], got ["PlayerModeButton_solo '1 player' ratio=2.66 fg=f6f7fb bg=999999","PlayerModeButton_coop 'Co-op 2' ratio=2.66 fg=f6f7fb bg=999999","PlayerModeButton_pvp  …`
- `FAIL legibility/1280x720/arena/player-mode-coop/contrast: expected [], got ["PlayerModeButton_solo '1 player' ratio=2.66 fg=f6f7fb bg=999999","PlayerModeButton_coop 'Co-op 2' ratio=2.66 fg=f6f7fb bg=999999","PlayerModeBu …`
- `FAIL legibility/1280x720/help/controller-tab/contrast: expected [], got ["Label 'Drive' ratio=1.09 fg=e6f8ff bg=ffffff","Desc 'Hold and release t' ratio=2.56 fg=8aa5bc bg=ffffff","Label 'Slice' ratio=1.09 fg=e6f8ff bg=ff …`
- `FAIL legibility/1280x720/challenges/default/contrast: expected [], got ["GroupName 'THE STEAMER' ratio=2.33 fg=ff8c00 bg=ffffff","Mark '🎯' ratio=3.32 fg=f6f7fb bg=848896","Name 'Night Circuit' ratio=3.32 fg=f6f7fb bg=848 …`
- `FAIL legibility/1280x720/challenges/some-complete/contrast: expected [], got ["GroupName 'THE STEAMER' ratio=2.33 fg=ff8c00 bg=ffffff","Mark '🏅' ratio=1.63 fg=f6f7fb bg=c8c3ba","Name 'Night Circuit' ratio=1.63 fg=f6f7fb  …`
- `FAIL legibility/1280x720/challenges/all-complete/contrast: expected [], got ["GroupName 'THE STEAMER' ratio=2.33 fg=ff8c00 bg=ffffff","Mark '🏅' ratio=1.63 fg=f6f7fb bg=c8c3ba","Name 'Night Circuit' ratio=1.63 fg=f6f7fb b …`
- `FAIL legibility/1280x720/challenges/demo-limited/contrast: expected [], got ["Mark '🏅' ratio=1.63 fg=f6f7fb bg=c8c3ba","Name 'Crimson Claw' ratio=1.63 fg=f6f7fb bg=c8c3ba","State 'WON' ratio=1.29 fg=ffd98a bg=c8c3ba","Ma …`
- `FAIL legibility/1280x720/profile/default/contrast: expected [], got ["Label 'Win 4 points with ' ratio=2.85 fg=ffffff bg=999999","Progress '0/4' ratio=2.85 fg=ffffff bg=999999","Label '10 winning shots t' ratio=2.85 fg=f …`
- … 84 more (`docs/implementation/ui-recreation/evidence/uir-finalize/runs/ui_legibility_audit.log`)

### replay_audit — FAIL 95/103, exit 1, 2 SCRIPT ERROR
- `FAIL replay/recording_group_can_run: expected "", got "match_controller misses ["start_replay","replay_active"]"`
- `FAIL replay/playback_group_can_run: expected "", got "match_controller misses ["start_replay","stop_replay","replay_active","replay_progress"]"`
- `FAIL replay/stop_group_can_run: expected "", got "match_controller misses ["start_replay","stop_replay","replay_active","replay_progress"]"`
- `FAIL replay/keys_group_can_run: expected "", got "match_controller misses ["start_replay","stop_replay","replay_active","replay_progress"]"`
- `FAIL replay/a_seam_that_turns_on_moves_the_view: expected true, got false`
- `FAIL replay/unbinding_the_seam_hides_the_chrome: expected false, got true`
- `FAIL replay/the_banner_follows_the_language: expected "RIPRODUZIONE", got "▶ RIPRODUZIONE"`
- `FAIL replay/the_banner_key_is_a_miss_exactly_when_the_theme_lacks_it: expected true, got false`

### screen_characters_audit — FAIL 147/148, exit 1, 0 SCRIPT ERROR
- `FAIL characters/every_unlocked_picker_card_carries_the_same_strip: expected [], got ["maestro"]`

### screen_help_audit — FAIL 73/75, exit 1, 2 SCRIPT ERROR
- `FAIL help/and_swaps_every_cap: expected ["L3","R3","✕","□","△","○","L1","L2","R2","R1","D-PAD","✕+✕","OPTIONS"], got ["LS","RS","A","X","Y","B","LB","LT","RT","RB","D-PAD","A+A","☰"]`
- `FAIL help/nothing_is_wider_than_the_narrow_frame: expected true, got false`

### screen_history_audit — FAIL 37/42, exit 1, 4 SCRIPT ERROR
- `FAIL history/the_three_boxes_read_zero: expected ["0","0","0"], got ["","",""]`
- `FAIL history/the_boxes_carry_the_reference_s_own_labels: expected ["Wins","Losses","Trophies"], got ["","",""]`
- `FAIL history/the_boxes_are_the_adapter_s_own_counts: expected ["2","1","0"], got ["","",""]`
- `FAIL history/and_hides_the_rows: expected 0, got 20`
- `FAIL history/and_shows_the_empty_line: expected true, got false`

### screen_challenges_audit — FAIL 64/68, exit 1, 1 SCRIPT ERROR
- `FAIL challenges/the_arena_rows_carry_the_frozen_ids: expected true, got false`
- `FAIL challenges/a_done_row_carries_the_theme_s_done_border: expected true, got false`
- `FAIL challenges/the_rows_are_four_columns_at_1280: expected false, got true`
- `FAIL challenges/the_rows_are_still_four_columns_at_1024: expected false, got true`

### screen_profile_audit — FAIL 44/60, exit 1, 3 SCRIPT ERROR
- `FAIL profile/the_wins_box_is_the_career_s_own: expected "7", got ""`
- `FAIL profile/the_wins_box_is_the_adapter_s_own: expected "7", got ""`
- `FAIL profile/the_trophies_box_is_the_career_s_own: expected "2", got ""`
- `FAIL profile/the_trophies_box_matches_the_adapter: expected "2", got ""`
- `FAIL profile/the_stars_box_is_the_career_s_own: expected "5", got ""`
- `FAIL profile/the_stars_box_matches_the_adapter: expected "5", got ""`
- `FAIL profile/the_win_rate_is_seventy_per_cent_for_seven_of_ten: expected "70%", got ""`
- `FAIL profile/and_it_is_the_adapter_s_own_rounding: expected "70", got ""`
- … 8 more (`docs/implementation/ui-recreation/evidence/uir-finalize/runs/screen_profile_audit.log`)

## 3. Sources hashed for this record

Tree digest `30820ee3dddaf826` -> `30820ee3dddaf826` (**stable: True**), 382 files.

The files the finalize wave changed (integration-owned), each hashed in the manifest:
- `godot/game/main_menu.gd` `cc4d67b6c86b2b6f`
- `godot/game/match_controller.gd` `6e00c1a779d96174`
- `godot/game/match_config.gd` `b181064a5f16c38b`
- `godot/game/input_map.gd` `87dbdc1647a3ceeb`
- `godot/src/ui/screens/ArenaScreen.gd` `9c4812802e8fac08`
- `godot/src/ui/screens/DrillScreen.gd` `e300f9d99ff76963`
- `godot/tests/ui/uir_route_audit.gd` `f54b8a56fc3747d3`

Full per-file hashes: `ui-audit-sweep.json` -> `sources`.

## 4. Exact commands (verification, in order)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot

pgrep -x Godot || true    # must print nothing: one engine process at a time

# the playable route (menu -> modes -> characters -> arena -> drill -> match -> pause
# -> result -> rematch -> settings), real screens, real bridge, a real played-out match
"$GODOT" --headless --path godot/ --script res://tests/ui/uir_route_audit.gd

# UIR-22's integration audit and the headless slice
"$GODOT" --headless --path godot/ --script res://tests/ui/uir22_integration_audit.gd
"$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd

# the whole pack, serially, with the pgrep guard, the per-run watchdog, the source hashes
# and the machine-readable manifest (this is the sweep that produced ui-audit-sweep.json)
python3 docs/implementation/ui-recreation/evidence/uir-finalize/sweep.py \
        docs/implementation/ui-recreation/evidence/uir-finalize
```

Single-suite form used throughout the sweep: `"$GODOT" --headless --path godot/ --script
res://tests/ui/<suite>.gd` — the per-run `cmd` field in `ui-audit-sweep.json` is the exact
command line each log came from.

`superseded/` holds the earlier partial-run artefacts (`ui-audit-subset.json`,
`sweep-1-pre-route.json`, `runs---only.json`, the first `sweep-console.log`) — kept, not deleted;
`ui-audit-sweep.json` and `runs/` are the record of the final sweep.
