# Playable route — what was verified end to end (2026-09-17, finalize wave)

Ticket: `UIR-22`. Arbiter: `godot/tests/ui/uir_route_audit.gd` (new this wave) plus the
pre-existing `godot/tests/ui/uir22_integration_audit.gd`. Both run in the real engine,
headless, one process at a time; records in `ui-audit-sweep.json` and `runs/*.log`.

## The route, in order, with what proves each hop

| hop | what the run does | check names (all green) |
|---|---|---|
| menu | `game/Main.tscn` mounts; the router's active id is `menu` | `route/the_route_starts_on_the_menu` |
| menu -> modes | a REAL `InputEventKey(KEY_ENTER)` is dispatched through the host's own bridge on the menu's `PlayButton` (not a direct `go_to`) | `route/the_play_button_takes_the_focus`, `route/the_confirm_is_handled`, `route/a_real_confirm_on_play_lands_on_modes` |
| characters, arena, drill | each mounted by `ScreenRouter.go_to`, exactly one screen at a time, and the live screen reports the id the route asked for | `route/characters_arena_and_drill_mount_one_at_a_time` |
| drill -> match | the drill screen's own gate grants it, its start writes `Config.pending_mode`/`pending_exercise`, and a `Match.tscn` booted on those fields adopts a REAL drill session that ticks | `route/the_drill_is_granted_in_this_build`, `route/the_drill_start_*`, `drill/the_match_adopts_a_session`, `drill/and_it_is_the_drill_the_screen_asked_for`, `drill/and_it_ticks` |
| match -> pause | ESC through the controller's own `_unhandled_input` pauses, the card opens, a second ESC resumes and closes it | `pause/escape_on_a_running_match_pauses`, `pause/and_the_card_is_open`, `pause/a_second_escape_resumes`, `pause/and_closes_the_card` |
| match -> result | a quick match played out by the scripted player reaches `state.result`; `finish_route(true)` leaves the live payload in `Config.pending_result` | `result/the_scripted_match_reaches_a_result`, `result/the_finish_route_is_the_result`, `result/the_payload_waits_for_the_host` |
| result screen | a host booted on that payload mounts `result` and prints the match's own two numbers; the payload is consumed exactly once | `result/the_host_boots_straight_onto_the_result`, `result/and_shows_the_matches_own_numbers`, `result/the_payload_is_consumed_once` |
| rematch | the result screen's own `rematch_requested` fires through the host's handler; the route points back at `res://game/Match.tscn` with the run's mode | `rematch/rematch_goes_back_to_the_match_scene`, `rematch/and_keeps_the_run_mode` |
| settings | a real right-press on the volume row through the bridge steps the slider, lands in the save, AND reaches the audio module's master gain | `settings/the_press_steps_the_row`, `settings/the_step_lands_in_the_save`, `settings/the_stepped_value_is_APPLIED_to_the_mixer (F6)` |
| human modes (F1) | a stored `playerMode` of `coop`/`pvp` reaches `create_match_state` on a quick match; a non-quick mode stays `solo` | `human/coop_reaches_the_state`, `human/pvp_reaches_the_state`, `human/a_non_quick_mode_stays_solo` |

`uir_route_audit` — **PASS 44/44**, exit 0, 0 `SCRIPT ERROR`, 4.3 s.
`uir22_integration_audit` — **PASS 71/71**, exit 0, 0 `SCRIPT ERROR`, 3.5 s.
One engine `WARNING` in the route audit's log (14 `ObjectDB` instances leaked at exit — the same
class of exit-time warning `music_port_test` prints; no `ERROR:` line, no `SCRIPT ERROR`).

## The seams this wave closed (integration-owned)

- **F1 — quick-match player mode.** `match_config.pending_player_mode` (new) is written by
  `ArenaScreen.start_match()` (quick only; every other mode forced to `solo`, the reference's
  own rule at `js/main.js:1156`) and read by `match_controller.start_match()`, which now passes
  `{"humanMode": …}` into `Sim.create_match_state`; the value is validated against the
  reference's three ids (`HUMAN_MODES`). Before this, `coop`/`pvp` was carried in the arena
  screen's payload and dropped at the controller — a quick match always ran `solo`.
- **F6 — stored settings applied, not only stored.** `input_map.DEADZONE` is a static var with
  `set_deadzone()` clamped to the reference's 0.08-0.30 band (`js/main.js:2276`);
  `match_config.stored_prefs()` reads the same `prefs` group the settings screen writes;
  `main_menu._apply_stored_audio_prefs()` runs at boot (volume -> the audio module's
  `set_master_gain`, deadzone -> the pad reader) and again on every `range_changed`;
  `match_controller._apply_stored_audio_prefs()` runs on both match-boot paths and on the pause
  card's Volume/Deadzone rows. Still open: nothing in the port rumbles, so `prefs.vibration` has
  no consumer to gate — recorded, not hidden (the reference gates `navigator.vibrate`,
  `js/main.js:320-321`).
- **F8 — the drill respects the build gate.** `DrillScreen.start()` asks
  `ModeSession.can_start("drill")` first; a refused build writes no config, changes no scene,
  and shows the lock (start action disabled + dimmed at 0.55, caption swapped for
  `Gate.locked_key()`, tooltip carrying the refusal). Before this, a demo build accepted the
  press, changed scene, and the controller answered `MODE_REFUSED` with a silent quick match.

## F3 — recorded divergence, not a silent one

`menu_nav.push_overlay()` / `set_in_match()` still have no production caller. In the landed
architecture the in-match pause card is driven by the controller's OWN `MenuFocus` instance
(`match_controller._rebuild_pause_focus()`), built when the card opens and polled only while it
is open — the menu host's router/bridge is not in the match scene at all, so the review's
"pad B/A operates the last screen's targets" scenario cannot arise. Left as-is, on the record.

## Play it (owner's command; the feel verdict is the owner's)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path godot res://game/Main.tscn -- --seed=20260916 --tier=3 --camera=default
```

The recreated UI is the DEFAULT path (`--ui=new`); `--ui=legacy` keeps the ported column for
the diagnostic route. Controls: WASD/arrows, Space charge-and-release, Meta slice, Alt special,
Tab/Z switch player, Esc pause (the card's five-step hierarchy), Q quit.
