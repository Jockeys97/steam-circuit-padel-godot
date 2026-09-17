# UIR finalize — small-gates finish (OSK/touch + help/challenges), 2026-09-17

The targeted repair run that closed the OSK/touch suite and the last help/challenges
reds. One engine process at a time (`pgrep -x Godot` guard before every run), the real
checkout, `/Applications/Godot.app/Contents/MacOS/Godot` (v4.7.2.stable.official.ed1daf0bf).
The replay/controller lane was NOT touched (another worker owns it); no full sweep was
run; no commits, pushes or deletions.

Machine-readable companion: this directory's eight `.log` files. The finalize sweep's
own record (`../runs/`, `../ui-audit-sweep.json`) is untouched.

## 1. Final runs (serial, after the edits below)

| suite | exit | tally | SCRIPT ERROR | other engine lines | was |
|---|---|---|---|---|---|
| osk_touch_audit | 0 | **PASS 177/177** | 0 | 0 | FAIL 171/177, 6 FAIL (sweep) |
| screen_help_audit | 0 | **PASS 91/91** | 0 | 0 | FAIL 88/90 (2 FAIL) |
| screen_challenges_audit | 0 | **PASS 73/73** | 0 | 0 | PASS 68/68 **+1 SCRIPT ERROR**, 4 checks aborted |
| uir22_integration_audit | 0 | PASS 71/71 | 0 | 0 | regression (OSK contract change) |
| uir_route_audit | 0 | PASS 44/44 | 0 | 0 | regression (host + panel mount) |
| screen_feedback_audit | 0 | PASS 119/119 | 0 | 3 | regression; the 3 lines are `ERROR: Clipboard is not supported by this display server.`, this suite's known pre-existing lines (the finalize sweep recorded engine_lines=3, SCRIPT ERROR 0 for it) |

Command per suite:
`"$GODOT" --headless --path godot/ --script res://tests/ui/<suite>.gd`

## 2. What changed, and why

- `godot/src/ui/screens/OskPanel.gd` `0bd8d7cf641feaea`
  - `osk_key_targets()` returns `[]` while the model is closed: the grid is not
    navigable closed, and the mount registers targets only on open
    (`main_menu._sync_osk` sets `[]` back on close).
  - `press_char()`/`press()` capture `target_id()` **before** the press and pass it to
    `_after_press(accepted, field)`: `done` closes the model and `close()` clears the
    target id (`osk.gd:85-94`), so the `closed` signal used to name `""`.
- `godot/tests/ui/osk_touch_audit.gd` `01695cfb2d108c66`
  - the key-count check computes 47 + 4 from `GRID_ROWS`/`ACTION_IDS` (the hard-coded
    52 was wrong; the reference grid is 51 keys);
  - waits two frames after the keyboard opens before reading key rects — the grid
    lays out on the frame after the visibility flip (evidence:
    `probe_osk_layout_readiness.log`: key rects P(0,0) in that frame, P(278,384) /
    P(871,634) two frames later);
  - re-asserts `root.size` immediately before the touch press **and** the lift — in
    headless the window extent reverts to 64x64 and a touch outside the window rect
    never reaches the GUI (evidence: `probe_touch_window_extent.log`: with the
    re-assert the identical `InputEventScreenTouch` at the button centre records
    `button_down`; without it the audit recorded nothing);
  - header 52 → 51; the stale "the theme does not parse" note corrected (the theme
    parses and carries every key this ticket names — `touch/the_default_instance_
    finds_its_palette` is ok in this run).
- `godot/tests/ui/screen_help_audit.gd` `f9aaa06c861099a9`
  - the language flip flips to the other table of the pair instead of a hard-coded
    "en": the runtime default locale is `en` (`locale_rules.json`), so the old flip
    was a no-op and the two checks could not pass. +1 guard check
    (`help/there_is_a_second_locale_to_flip_to`).
- `godot/tests/ui/screen_challenges_audit.gd` `f3c3f74297d231d3`
  - the `Section0/SectionTitle` read walks the live structure
    (`Section0 -> head -> SectionTitle`, `find_child`) instead of demanding a direct
    child — that `get_node` was the suite's SCRIPT ERROR, and its abort hid four
    checks that now run and pass. **Layout untouched.**
  - same other-locale flip pattern. +1 guard check.
- `godot/tests/ui/uir22_integration_audit.gd` `81d47522d48c847b`
  - reads the panel's targets with the model open (open → read → close) since the
    panel now offers none while closed; same check count, still 71/71.

## 3. Evidence probes (preserved, untracked)

`godot/tests/ui/_probe_osk2.gd` and `_probe_touch.gd` are the generated probes whose
runs are copied here as `probe_osk_layout_readiness.log` and
`probe_touch_window_extent.log`. The probe sources were not edited and remain in
`godot/tests/ui/` for staging-time exclusion, not deletion.

## 4. Honest limits

- No touchscreen on this host (`DisplayServer.is_touchscreen_available()` false); the
  touch path is exercised through `InputEventScreenTouch` + the engine's own
  touch→mouse emulation, never a finger (`not_ported` entries stay in the audit).
- The touch test needs the headless window extent re-asserted at injection time (see
  change list); this is an audit-side accommodation of the dummy display server, not
  a source change.
- Full sweep still owed until the replay/controller writer returns; this run covers
  only the six suites above.
