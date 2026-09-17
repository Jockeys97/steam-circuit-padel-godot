# Final playability closeout — journal (subagent lane, sole engine runner)

Started 2026-09-17 ~12:26 CEST. Repo: steam-circuit-padel-godot, unpushed HEAD 6343312 +
large uncommitted UI wave. Mandate: reconcile the independent reviewer's F0-F8 findings
(/tmp/uir-final-integration-review.md, snapshot 12:00) against the live disk, close the
ones still real at the production seam, make the false-positive audits drive production
paths (settings range step, osk metadata injection, feedback write-back, arena payload),
run replay_audit for the first time, and return a serial engine sweep with honest tallies.

## Live-tree caveat (recorded first, before any of my edits)
- The working tree is being written by another lane RIGHT NOW. mtimes observed:
  12:09 UiFocusBridge.gd · 12:11 main_menu.gd + PauseOverlay.gd · 12:12 hud.gd ·
  12:13 SettingsScreen.gd · 12:15 CharactersScreen.gd · 12:16 ControlLegend.gd ·
  12:17 replay_audit.gd · 12:18 uir22_integration_audit.gd + ReplayOverlay.gd ·
  12:20 pause_audit.gd + osk_touch_audit.gd · 12:22 screen_profile_audit.gd ·
  12:24 uir-22-integration-journal.md · 12:26 ArenaScreen.gd ·
  12:27:51 match_config.gd + input_map.gd · 12:27:56 match_controller.gd.
- Consequence: match_config.gd gained `pending_player_mode` (F1's carrier) between two of
  my own reads (12:26 vs 12:27). The uir-22 evidence log (12:23:58) predates it, so the
  log does not describe the tree's latest seam work. Every finding verdict below is
  against a hash I will re-record right before the final sweep, and my start-of-work
  baseline sweep is run after writer quiescence so regressions are attributable.

## Recon status per finding (against disk as read 12:26-12:28)
- F0: main_menu.gd::_mount_ui_prototype registers all twelve Control screens by loop
  (SCREEN_SCENES, 12 ids); `game` is documented as not-a-router-screen and reached via
  Config.pending_mode; default is `--ui=new` (ui_prototype = not ui_legacy and ...).
  uir22_integration_audit asserts the twelve-id walk, one-screen-at-a-time, a real confirm
  landing on `modes`. Verdict: largely closed; re-verify in engine, `game` decision recorded.
- F1: match_config.pending_player_mode + ArenaScreen.start_match write + match_controller
  quick-path read landed at ~12:27. Needs engine proof (state.humanMode/coop/pvp + solo
  elsewhere) and the arena audit's payload-only false positive replaced with a selection-
  driven assertion.
- F2: match_controller.set_match_paused(bool) exists (explicit, echo, _reset_transient_input
  on both edges); ESC routes through _pause_overlay.back() (five-step hierarchy). Needs the
  tutorial-open / quit-armed / event-count checks in engine.
- F3: menu_nav push_overlay/set_in_match still have no game/** callers; the new path uses
  match_controller._pause_focus over PauseOverlay.focus_controls() + poll_pad. Needs an
  in-engine pad-proof on the card (confirm activates overlay control; range step-write;
  no menu focus while playing) or an equivalent production-path assertion.
- F4: SettingsScreen._register_focus carries min/max/step/value; host consumes range_changed
  (main_menu._on_range_changed). screen_settings_audit._focus() still performs the step it
  asserts (false positive) — to be rewritten to assert the dispatch's own result.
- F5: FeedbackScreen registers {"kind": "text_field"} only (no value/max_length/field_label);
  osk_seed() door exists. main_menu._sync_osk write-back exists (apply_osk_value). Reopen
  re-seed needs the live field text at merge time. osk_touch_audit + screen_feedback_audit
  false positives to be made to drive the production registration.
- F6: hud.gd forcing removed (comment documents it); deadzone still `const DEADZONE := 0.15`
  (input_map.gd just changed at 12:27:51 — re-read); volume/vibration consumers to verify;
  main_menu applies stored lang at boot.
- F7: Config.pending_result + take_pending_result; match_controller.result_payload()/
  finish_route(); host mounts result from payload; rematch_requested consumed by host
  (rematch_route -> Match.tscn). Tournament label/demo-continue to verify.
- F8: DrillScreen.start()/start_payload() still bypass ModeSession.can_start; controller
  refuses drill in demo and falls back to quick (MODE_REFUSED). Decision to make + record;
  screen must not start a different mode than it showed.

## Next
- Wait for writer quiescence (mtime + pgrep), then baseline serial sweep (pre-edit tallies).

## Engine-run incident (12:30) — guard refusal, attribution
- My baseline sweep (launched 12:30:06, session proc_996ea5918a9c) REFUSED at its own
  pgrep guard: "REFUSED: a Godot process is already running: 74775". No suite ran; the
  run wrote no log and no tally (baseline dir empty). Verified via process log.
- PID 74775 (slice run, started 12:30:02) was NOT one of my launches. Attribution: a
  second lane is active on this checkout — `zsh` pid 74691 (started 12:30:01) runs
  `python3 /tmp/uir-finalize/sweep.py` with console at
  `evidence/uir-finalize/sweep-console.log`, currently sweeping the same suites
  (observed: harness PASS 8/8; game_slice_test PASS 342/342; then a `game_slice_test
  -- --demo` child pid 75367, parent 74717). That lane's sweep serialises its own runs;
  it and my lane must not overlap (one engine at a time, shared checkout).
- Consequence for MY evidence: zero sweep output exists from before this point, so no
  earlier tally of mine can be unreliable. Plan: wait for the uir-finalize sweep's
  Godot children to clear (do not kill any of them), then apply my edits, then run the
  full serial sweep with per-suite tallies + a separate engine-error count.
- No kill was issued; Main.tscn runs untouched.
