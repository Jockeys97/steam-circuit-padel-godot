# Finalize closure — engine record (2026-09-17, integration owner, sole engine owner)

One Godot process at a time (`pgrep -x Godot` guard before every run), the real checkout,
`/Applications/Godot.app/Contents/MacOS/Godot` (v4.7.2.stable.official.ed1daf0bf). A `PASS`
line next to a `SCRIPT ERROR` is a failure, so both are counted separately below; the engine
`ERROR:` lines are classified in §2 — nothing there is unexplained. Earlier sweeps are kept,
not deleted: `superseded/` holds sweep 1 (24 green / 8 red) and sweep 2 (31 green / 1 red),
with their manifests, console logs and per-run logs.

Machine-readable manifest: `ui-audit-sweep.json` (per run: exact command, exit code, tally,
ok/FAIL counts, SCRIPT ERROR count, log path) plus `sources` — sha256[:16] of every file under
`godot/game`, `godot/src`, `godot/tests` and `project.godot` — and `tree_digest_before/after`
(equal, so no source moved while the sweep ran).

Re-run everything:

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
pgrep -x Godot || true                       # must print nothing
python3 docs/implementation/ui-recreation/evidence/uir-finalize/sweep.py \
        docs/implementation/ui-recreation/evidence/uir-finalize
```


## 1. The sweep — 32 runs, one engine at a time

| # | run | command | exit | tally | SCRIPT ERROR | engine lines | s |
|---|---|---|---|---|---|---|---|
| 1 | harness | `$GODOT --headless --path godot/` | 0 | PASS 8/8 | 0 | 0 | 0.2 |
| 2 | game_slice_test | `--script tests/game_slice_test.gd` | 0 | PASS 342/342 | 0 | 1 | 18.1 |
| 3 | game_slice_test_demo | `--script tests/game_slice_test.gd -- --demo` | 0 | PASS 293/293 | 0 | 2 | 15.1 |
| 4 | input_run_all | `--script tests/input/run_all.gd` | 0 | PASS 5/5 | 0 | 0 | 0.3 |
| 5 | audits_run_all | `--script tests/audits/run_all.gd` | 0 | PASS 10/10 | 0 | 0 | 81.0 |
| 6 | modes_run_all | `--script tests/modes/run_all.gd` | 0 | PASS 6/6 | 0 | 0 | 0.8 |
| 7 | save_steam_test | `--script tests/save_steam_test.gd` | 0 | PASS 137/137 | 0 | 0 | 0.3 |
| 8 | music_port_test | `--script tests/music_port_test.gd` | 0 | PASS 32/32 | 0 | 0 | 16.1 |
| 9 | theme_probe | `--script tests/ui/theme_probe.gd` | 0 | PASS 305/305 | 0 | 0 | 0.3 |
| 10 | router_audit | `--script tests/ui/router_audit.gd` | 0 | PASS 86/86 | 0 | 2 | 0.4 |
| 11 | data_audit | `--script tests/ui/data_audit.gd` | 0 | PASS 131/131 | 0 | 0 | 0.3 |
| 12 | fonts_assets_probe | `--script tests/ui/fonts_assets_probe.gd` | 0 | PASS 75/75 | 0 | 0 | 0.6 |
| 13 | hud_audit | `--script tests/ui/hud_audit.gd` | 0 | PASS 172/172 | 0 | 0 | 1.4 |
| 14 | pause_audit | `--script tests/ui/pause_audit.gd` | 0 | PASS 176/176 | 0 | 0 | 0.6 |
| 15 | input_a11y_audit | `--script tests/ui/input_a11y_audit.gd` | 0 | PASS 153/153 | 0 | 0 | 0.4 |
| 16 | osk_touch_audit | `--script tests/ui/osk_touch_audit.gd` | 0 | PASS 177/177 | 0 | 0 | 0.5 |
| 17 | ui_legibility_audit | `--script tests/ui/ui_legibility_audit.gd` | 0 | PASS 664/664 | 0 | 0 | 8.2 |
| 18 | uir22_integration_audit | `--script tests/ui/uir22_integration_audit.gd` | 0 | PASS 71/71 | 0 | 0 | 3.6 |
| 19 | replay_audit | `--script tests/ui/replay_audit.gd` | 0 | PASS 166/166 | 0 | 1 | 1.3 |
| 20 | screen_menu_audit | `--script tests/ui/screen_menu_audit.gd` | 0 | PASS 97/97 | 0 | 1 | 0.8 |
| 21 | screen_modes_audit | `--script tests/ui/screen_modes_audit.gd` | 0 | PASS 118/118 | 0 | 0 | 0.7 |
| 22 | screen_characters_audit | `--script tests/ui/screen_characters_audit.gd` | 0 | PASS 148/148 | 0 | 0 | 1.1 |
| 23 | screen_arena_audit | `--script tests/ui/screen_arena_audit.gd` | 0 | PASS 133/133 | 0 | 0 | 0.8 |
| 24 | screen_drill_audit | `--script tests/ui/screen_drill_audit.gd` | 0 | PASS 89/89 | 0 | 0 | 0.5 |
| 25 | screen_result_audit | `--script tests/ui/screen_result_audit.gd` | 0 | PASS 176/176 | 0 | 0 | 0.7 |
| 26 | screen_settings_audit | `--script tests/ui/screen_settings_audit.gd` | 0 | PASS 91/91 | 0 | 0 | 0.4 |
| 27 | screen_feedback_audit | `--script tests/ui/screen_feedback_audit.gd` | 0 | PASS 119/119 | 0 | 3 | 0.4 |
| 28 | screen_help_audit | `--script tests/ui/screen_help_audit.gd` | 0 | PASS 91/91 | 0 | 0 | 0.5 |
| 29 | screen_history_audit | `--script tests/ui/screen_history_audit.gd` | 0 | PASS 56/56 | 0 | 0 | 0.5 |
| 30 | screen_challenges_audit | `--script tests/ui/screen_challenges_audit.gd` | 0 | PASS 73/73 | 0 | 0 | 0.6 |
| 31 | screen_profile_audit | `--script tests/ui/screen_profile_audit.gd` | 0 | PASS 74/74 | 0 | 1 | 0.3 |
| 32 | uir_route_audit | `--script tests/ui/uir_route_audit.gd` | 0 | PASS 44/44 | 0 | 0 | 4.7 |

- **PASS runs: 32 of 32** — exit 0, no `FAIL` line, 0 `SCRIPT ERROR`.
- Red / non-clean runs: **0** — none.
- Checks passed in the green runs: **4318**.
- `SCRIPT ERROR` lines across the sweep: **0**.

## 2. Engine `ERROR:` lines, classified (11 total — none unexplained)

### game_slice_test — 1 line(s)
- `ERROR: arena_library: unknown arena id 'nope' (have: officina, locomotive, clockwork, cattedrale, forgia, tempesta, abissale, caldera, orrery)`
- classified: the arena unknown-id probe — named allowance 1 in `godot/game/check_log.sh`, flanked by `ok an unknown arena id does not build`

### game_slice_test_demo — 2 line(s)
- `ERROR: arena_library: unknown arena id 'nope' (have: officina, locomotive, clockwork, cattedrale, forgia, tempesta, abissale, caldera, orrery)`
- `ERROR: 3 resources still in use at exit (run with --verbose for details).`
- classified: the arena unknown-id probe (allowance 1) + the engine shutdown report (allowance 2, intermittent)

### router_audit — 2 line(s)
- `ERROR: ScreenRouter.register: 'nope' is not one of the thirteen reference screens`
- `ERROR: ScreenRouter.register: 'menu' was handed a null scene`
- classified: two `ScreenRouter.register` refusal probes (bad id; null scene), flanked by `ok router/register_refuses_an_id_outside_the_table`

### replay_audit — 1 line(s)
- `ERROR: 1 resources still in use at exit (run with --verbose for details).`
- classified: the engine shutdown report (allowance 2, intermittent: a `static var Shader` outlives the tree; root cause recorded in `check_log.sh`)

### screen_menu_audit — 1 line(s)
- `ERROR: ScreenRouter.register: 'nope' is not one of the thirteen reference screens`
- classified: the `ScreenRouter.register` refusal probe (bad id), flanked by the register `ok` checks

### screen_feedback_audit — 3 line(s)
- `ERROR: Clipboard is not supported by this display server.`
- `ERROR: Clipboard is not supported by this display server.`
- `ERROR: Clipboard is not supported by this display server.`
- classified: `Clipboard is not supported by this display server.` ×3 — headless has no clipboard; the feedback screen's copy path is exercised by the audit

### screen_profile_audit — 1 line(s)
- `ERROR: ProfileScreen.route_action: 'nope' is not one of this screen's actions`
- classified: the `ProfileScreen.route_action` refusal probe (bad action), flanked by `ok profile/an_unknown_action_is_refused`

## 3. Sources hashed for this record

Tree digest `1256f5f1d7200437` -> `1256f5f1d7200437` (**stable: True**), 393 files.

The files this closure moved or that its repairs executed against (hashes from `sources`):
- `godot/game/match_controller.gd` `cc6c1ce88886bd5c`
- `godot/game/main_menu.gd` `cc4d67b6c86b2b6f`
- `godot/game/match_config.gd` `b181064a5f16c38b`
- `godot/game/input_map.gd` `87dbdc1647a3ceeb`
- `godot/src/ui/screens/PauseOverlay.gd` `b2d7d4dcfb1ea0d5`
- `godot/src/ui/screens/ReplayOverlay.gd` `0d554f9698caf367`
- `godot/src/ui/screens/HistoryScreen.gd` `f7f28cda58f01866`
- `godot/src/ui/screens/ProfileScreen.gd` `cc9f43e3fbcab248`
- `godot/src/ui/screens/ArenaScreen.gd` `ed74dd9600ca273c`
- `godot/src/ui/screens/HelpScreen.gd` `db57b219faedba16`
- `godot/src/ui/screens/ChallengesScreen.gd` `247e60e2dbd8f70b`
- `godot/src/ui/screens/OskPanel.gd` `0bd8d7cf641feaea`
- `godot/src/ui/theme/padel_theme.tres` `f735bfce8ba67b2d`
- `godot/tests/ui/replay_audit.gd` `ce5ac06015a4d309`
- `godot/tests/ui/screen_history_audit.gd` `ba37b0016bbee6f1`
- `godot/tests/ui/uir_route_audit.gd` `f54b8a56fc3747d3`

Full per-file hashes: `ui-audit-sweep.json` -> `sources`.

## 4. Exact commands (verification, in order)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot

pgrep -x Godot || true    # must print nothing: one engine process at a time

# replay gate first (the seam was static-only before the closure)
"$GODOT" --headless --path godot/ --script res://tests/ui/replay_audit.gd
# pause gate (the flag split) and the repaired history gate
"$GODOT" --headless --path godot/ --script res://tests/ui/pause_audit.gd
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_history_audit.gd

# the whole pack, serially, pgrep guard + per-run watchdog + source hashes + manifest
python3 docs/implementation/ui-recreation/evidence/uir-finalize/sweep.py \
        docs/implementation/ui-recreation/evidence/uir-finalize
```

Single-suite form used throughout: `"$GODOT" --headless --path godot/ --script
res://tests/ui/<suite>.gd` — the per-run `cmd` field in `ui-audit-sweep.json` is the exact
command line each log came from. This closure's README/hashes were verified by
`gdlint` parse checks (no parse errors) and the manifest's stable tree digest.

## 5. Closure probe — the wired card entry, executed (not one of the 32)

`replay_audit` drives a standalone `PauseOverlay`; `uir_route_audit` boots the real mount but
never touches replay. The wire between them — the controller's availability feed onto the MOUNTED
card and the mounted card's `replay_requested` back into `start_replay()` — is asserted by
`_probe_replay_card.gd` (project root, outside the hashed trees above), which boots `Match.tscn`
the game's own way (node added while the tree is already iterating, `harness_mode()` after
`add_child`), ticks 150 fixed steps, and then: gate off with its reason before any frames -> the
pause echo opens the card and the availability feed enables the real `ReplayButton` -> the
button's own `pressed` -> `start_replay()` (card hides, pause lifts) -> `stop_replay()` (pause
restored, card reopens on MATCH, startable again). **PASS 18/18**, exit 0, 0 `SCRIPT ERROR`; 1
engine line (the intermittent shutdown report, allowance 2). Log
`scripts/probe-replay-card.log`; the script is preserved at `scripts/_probe_replay_card.gd`
(re-run: copy it to `godot/` and run
`"$GODOT" --headless --path godot/ --script res://_probe_replay_card.gd`). The tree digest above
was re-verified against the live tree after this probe: `1256f5f1d7200437`, 393 files, no drift.
