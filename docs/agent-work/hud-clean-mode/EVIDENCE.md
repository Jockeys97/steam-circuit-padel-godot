# Arena clean mode - implementation evidence

Bundle: implement the approved clean-mode plan (`PLAN.md`).
Repo: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`, branch `codex/integrate-arena-11m`.

## Changed paths

- `godot/game/match_controller.gd` - the toggle, its seams and its surfaces.
- `godot/tests/ui/clean_mode_audit.gd` - the focused audit (new).

No other file was edited. `godot/game/court_timing_marks.gd` was NOT changed: its
existing `set_muted(bool)` seam already suppresses the ring, the window, the advice
word, the precision bar and the energy bar (`update()` forces `live`/`charging`
false), so the contract is met through the seam the plan intended.

## What the controller now does

- `_hud_hidden: bool = false`, with `is_hud_hidden()`, `set_hud_hidden(bool)` and
  `toggle_hud_hidden()` as the deterministic seams.
- `_apply_hud_visibility()` writes the flag onto:
  - `_ui_hud` (shipping HUD: score, timer, actions, mini-map, serve banner, mode
    strip, match panel, event log),
  - `_hud` (legacy HUD, when that column is the one built),
  - `_mode_hud`, as `(not _hud_hidden) and (not _ui_new)` - a shipping run keeps the
    ported strip hidden, so ending clean mode cannot reveal it,
  - `_timing_marks.set_muted(_hud_hidden)`.
- `_sync_views()` gates its own every-frame rewrites with the flag: `_active_ring`,
  `_active_pin` and `_target_ring`. This is what makes the hidden state survive the
  refresh instead of being undone one frame later.
- `_clean_mode_event()` + one rung at the top of `_input`, before the pause-overlay
  early return and gated by `state != null`: a pressed left double-click,
  `JOY_BUTTON_START`, or `JOY_BUTTON_BACK`, only while the pause card is closed, each
  consumed with `get_viewport().set_input_as_handled()`. `_input` is the viewport's
  first, PRE-GUI phase: a HUD control with `MOUSE_FILTER_STOP` consumes a click
  before `_unhandled_input`, so the gesture must be answered there. Start is
  `padel_pause`'s own pad binding in `project.godot`, so consuming it before the
  InputMap walk is exactly what stops the toggle from also pausing.
  `project.godot` was not touched. There is no clean-mode rung in
  `_unhandled_input`.
- `start_match()` and `_adopt_session()` clear `_hud_hidden` and re-apply the
  visibility, so every new match and rematch starts with the informational UI shown.

Untouched by clean mode: the pause card, the replay overlay, the touch layer, the
court, the players, the ball and its gameplay cues (trail, spin ring, land ring).

## Verification

All commands run headless on this host with
`/opt/homebrew/bin/godot --headless --path godot --script <script>`; each log was
then passed through the repo's strict gate, `godot/game/check_log.sh`.

| suite | script | result | gate |
| --- | --- | --- | --- |
| clean mode (new) | `res://tests/ui/clean_mode_audit.gd` | `PASS 52/52`, exit 0 | `ok clean_mode` 0 script errors, 1 engine error (the documented static-shader shutdown line), 0 fails |
| pause (UIR-20) | `res://tests/ui/pause_audit.gd` | `PASS 176/176`, exit 0 | `ok pause_audit` 0 script errors, 0 engine errors, 0 fails |
| HUD (UIR-08) | `res://tests/ui/hud_audit.gd` | `PASS 172/172`, exit 0 | `ok hud_audit` 0 script errors, 0 engine errors, 0 fails |
| court timing marks | `res://tests/court_timing_marks_test.gd` | `PASS 87/87`, exit 0 | `ok timing` 0 script errors, 0 engine errors, 0 fails |
| UI integration (UIR-22: mount, pause seam, rematch) | `res://tests/ui/uir22_integration_audit.gd` | `PASS 75/75`, exit 0 | `ok uir22` 0 script errors, 0 engine errors, 0 fails |

Full logs are the `*.log` files in this directory.

### What the new audit covers

1. The three seams exist; `is_hud_hidden() == false` and the HUD is visible at start.
2. A left double-click hides and a second shows; a single left press does not toggle.
   The gesture is delivered through `Viewport.push_input` (so the pre-GUI `_input`
   phase answers it) and, as a deliberate negative, the same event sent to
   `_unhandled_input` does NOT toggle: the rung lives on the pre-GUI path.
3. `JOY_BUTTON_START` and `JOY_BUTTON_BACK` each hide and show, and neither press
   pauses or opens the card (the consumption contract). A press while the card is
   open is left to the card.
4. The active ring, the active pin and the timing energy bar follow the flag; the
   touch layer and the replay overlay are untouched; the pause card still opens
   (and the HUD stays hidden under it) while clean mode is on.
5. The flag survives `apply_frame` refreshes, i.e. the `_sync_views` rewrite.
6. ESC still pauses and resumes, with clean mode on, and leaves the flag alone.
7. `rematch()` clears the flag and shows the HUD, the ring and the marks again.
8. Shipping: the ported `ModeHud` stays hidden when clean mode ends. Legacy
   (`ui_legacy`): the ported column and its strip follow the flag both ways.
9. A drill match: the session's target ring follows the flag.

### Not asserted

- No hardware pad was attached to this host: the two pad presses are injected
  `InputEventJoypadButton` values, not hardware events. The two button indices are
  the contract's own (`JOY_BUTTON_START`, `JOY_BUTTON_BACK`).
- No visual/human capture verdict was taken. The plan's acceptance list is the
  synthetic audit above; the engine warnings in the logs
  (`ReplayOverlay.gd` anchor/size warnings) are pre-existing and unrelated.
- The engine dispatches no GUI phase under this headless harness, so the
  "a `MOUSE_FILTER_STOP` button eats the click" scenario is pinned by the
  `_input`-versus-`_unhandled_input` pair rather than reproduced against a real
  button.
