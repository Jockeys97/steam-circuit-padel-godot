# Right-stick vertical scrolling — implementation report

Task: `right_stick_scroll`. Branch `codex/integrate-arena-11m` (unchanged), checkout
`/Users/alessiofantini/Documents/steam-circuit-padel-11m`. Nothing committed, staged,
pushed, reset or branched. Engine: `/opt/homebrew/bin/godot` (4.7.2.stable.official).

## Status

Ready for review, after one bounded correction cycle (below). New shared helper + two
host hooks; no screen refactored; the two files another task is editing
(`ScreenShell.gd`, `ScreenRouter.gd`) were not touched.

## Correction cycle (3 findings, all closed)

**C1 — surface ancestry before the walk.** `_scrolling_ancestor` climbed from the
focused control without first proving it descends from the active surface, so a modal
whose focus still named a control of the screen underneath could scroll the background.
`_resolve_container()` now checks `focused == surface or surface.is_ancestor_of(focused)`
before the walk, `_scrolling_ancestor` treats the surface itself as a possible
container, and it now takes the nearest ancestor that scrolls **and overflows**, falling
back to the next one out (so a nested card with nothing to scroll gives the stick to the
body around it).

Negative control, run and recorded: with only that ancestry check reverted, the new
tests fail exactly as the review predicted —
`FAIL modal/the_modal_owns_the_stick_not_the_focus_owners_screen: expected ModalScroll, got BackgroundScroll`,
`FAIL modal/the_background_did_not_scroll: expected 0, got 45`, and 90 px on the second.
Restored, `PASS 68/68`. New checks: `nesting/*` (nested card owns the stick; a card with
nothing to scroll hands it back) and `modal/*` (the modal owns the stick while the focus
names a background control; the background stays at 0; a modal with nothing to scroll is
inert and the background still stays at 0).

**C2 — suspended until neutral.** `reset()` alone dropped the fraction and the very next
frame read the still-deflected axis and carried on. The helper now has `suspend()` /
`is_suspended()`: latched inert until the axis reads neutral, which is what the host's
window-focus-loss and disconnect handlers call. The tests assert the **frames after** the
event, not the immediate `container == null`: `a_held_stick_does_not_resume_when_the_window_returns`,
`a_held_stick_does_not_resume_after_a_disconnect`, `neutral_rearms_the_helper`, then
`and_the_next_push_scrolls_again`.

**C3 — no hardware claim, and absent vs neutral kept apart.** The docs and the test's own
report line now say the engine's joypad list is printed for the record and physical
interaction is untested; no claim in either direction. Two different facts are now
separate checks, asked of the helper directly (the host overwrites the seat every frame
from the engine's list): `an_absent_seat_is_inert` / `and_reads_as_centred`
(`set_device(-1)`) versus `a_connected_neutral_seat_is_inert` / `and_a_neutral_seat_scrolls_nothing`.

## What was wrong

The right stick was already modelled and never applied. `src/input/menu_nav.gd::poll_pad()`
reads `right_stick_y`, multiplies it by `STICK_SCROLL_SPEED` and calls
`focus_nav.gd::scroll()`, which only advances an abstract per-container offset float.
Nothing in the runtime wrote `ScrollContainer.scroll_vertical`, and `game/menu_focus.gd`
discarded the model's `scrolled` value. Result: the stick did nothing on a long screen.

## Changed paths

New:

- `godot/src/ui/focus/controller_scroll.gd` — the shared helper. One axis
  (`JOY_AXIS_RIGHT_Y`), one write (`ScrollContainer.scroll_vertical`). Menu deadzone
  `0.28`, proportional speed `900 px/s` at full deflection, `float` offset with an
  integer write (sub-pixel frames accumulate), clamp `0 .. max_value - page`, container
  resolved from the focused control's nearest scrolling ancestor with the surface's
  primary container as fallback, release drops the fraction, `reset()` stops outright,
  a manual write elsewhere is where the stick continues from. It never calls
  `grab_focus()` or `ensure_control_visible()`.
- `godot/tests/ui/controller_scroll_test.gd` — the regression, 51 checks (run with
  `--script`, like the other `SceneTree` audits here, so it needs no scene file).
- `godot/tests/ui/_probe_pause_overflow.gd` — the measurement behind the pause
  exclusion below.
- `docs/agent-work/right-stick-scroll/DESIGN.md`, this report, `evidence/*.log`.

Modified (both clean files, minimal hooks):

- `godot/game/main_menu.gd` — preload + `_controller_scroll` field, `_setup_controller_scroll()`
  called in both `_ready()` paths, `_process(delta)` now passes `delta` to
  `_playable_process(delta)`, one `_update_controller_scroll(delta)` per frame in each
  path (before the "no pad" early return, so the helper owns that decision), surface
  chosen as OSK > jukebox > active screen, `reset()` on `ScreenRouter.screen_changed`,
  on `Input.joy_connection_changed(…, false)` and on the root window's `focus_exited`,
  plus the public `controller_scroll()` door the test uses.

Not modified: `ScreenShell.gd` and `ScreenRouter.gd` (dirty by the back-signal task),
`ResultScreen.gd` and `tests/ui/result_coach_audit.gd` (the completed controller-activate
fix is preserved untouched), and every screen file — they are covered generically because
the helper walks the live tree.

## Coexistence with the existing abstract scroll model

Checked, not assumed. `focus_nav.gd::_page_scroll` / per-container `offset`, and
`menu_nav.gd`'s `scrolled` field, have **no consumer that paints**: the only readers are
`focus_nav.gd::scroll_offset()`/`page_scroll()`, which nothing in `godot/game` or
`godot/src` calls. The model keeps accumulating its own number harmlessly; the helper is
the only writer of `scroll_vertical`. Two checks pin it:

- `host/the_abstract_model_scroll_paints_nothing` — a `step_pad` with `right_stick_y: 1.0`
  leaves the mounted container's offset unchanged.
- `host/and_by_speed_times_time_once` — three host frames move the real screen by
  3 × 45 px = 135 px (±2), and `host/the_control_carries_the_helpers_own_offset` ties the
  control to the helper's own offset. A second application would show as a doubled delta.

No snap-back: `host/a_manual_scroll_is_not_snapped_back` writes the control between two
frames (what the wheel, a drag or `follow_focus` does) and the stick continues from there.

## Pause overlay — excluded, with evidence

`PauseOverlay` has **no `ScrollContainer`** and does not overflow at either shipped frame,
so there is no scrollable content to drive and nothing was added to it.
`evidence/pause-overflow-probe.log`:

```
PAUSE_PROBE frame=(1280.0, 720.0) open=true card=true
  card min=(880.0, 520.0) size=(880.0, 520.0) viewport=(1280.0, 720.0)
  card overflows=false
  scroll_containers=0 []
PAUSE_PROBE frame=(1152.0, 648.0) open=true card=true
  card overflows=false
  scroll_containers=0 []
```

The helper is container-driven, so a `ScrollContainer` added to that card later would be
scrolled by the same code without another change.

## Verification (all commands, exit 0)

| Command | Exit | Result |
| --- | --- | --- |
| `/opt/homebrew/bin/godot --headless --path godot/ --script res://tests/ui/controller_scroll_test.gd` | 0 | `PASS 68/68` (after the correction cycle) |
| `/opt/homebrew/bin/godot --headless --path godot/ --script res://tests/ui/result_coach_audit.gd` | 0 | `PASS 129/129` (pre-correction tree; not re-run — the correction touched no coach path) |
| `/opt/homebrew/bin/godot --headless --path godot/ --script res://tests/ui/controller_cards_test.gd` | 0 | `CONTROLLER_CARDS PASS` (re-run after the correction, since it mounts the same host) |
| `/opt/homebrew/bin/godot --headless --path godot/ --script res://tests/ui/_probe_pause_overflow.gd` | 0 | measurement, above |

Logs: `evidence/controller-scroll-test.log`, `evidence/result-coach-audit.log`,
`evidence/controller-cards-test.log`, `evidence/pause-overflow-probe.log`.

### What the 68 checks cover

- helper: held stick moves every frame (continuous, not one repeat step); five frames move
  `speed × time`; half deflection is proportionally slower and slower than full; the
  deadzone is inert and drops the fraction; a released stick stops at once; clamps at both
  ends; a sub-pixel frame accumulates and reaches a pixel; a manual write is where the
  stick continues; `reset()` forgets container and fraction.
- host, real `Main.tscn` + real router: the scene owns a helper; the result screen's body
  really overflows (measured 207 px room) and the host's own `_process` moves it by
  `speed × time` once; it clamps at the screen's own end; up moves back; a manual scroll is
  not snapped back; the help screen's body moves by the same rule; the abstract model
  paints nothing; the left stick still moves the focus and scrolls nothing.
- boundaries: a hidden surface scrolls nothing and the helper reports itself inert; it
  resumes when shown; a screen change resets the helper and drops the fraction; a
  controller disconnect resets it; a window focus loss resets it; with no injected axis and
  the real seat, no pad means nothing scrolls.

## Limits of this evidence

No claim is made about a physical pad in either direction: the engine's own joypad list
is printed for the record (it has read both `[]` and `[0]` across runs) and physical
interaction is untested. The axis is supplied through the helper's documented seam (the
same shape `PauseOverlay` uses for its injected `InputEventJoypadMotion`), and the host's
own `_process` is the code under test. This proves the engine path, never a hand on
hardware. An absent seat and a connected-but-neutral seat are separate checks, because
they are separate facts.
Mouse behaviour is untouched by construction (the helper only writes `scroll_vertical`
while the stick is deflected) and is pinned by the manual-write check, not by a wheel event.

## Outstanding

- Gameplay right stick (aim / teammate switching) is untouched: the helper lives in the UI
  scene, and the match's own right-stick reader is a different scene and a different code
  path.
- `godot/game/main_menu.gd`'s legacy column builds no `ScrollContainer`, so the helper is
  inert there by construction rather than by a flag.
- Decision for Astra, not taken here: `menu_nav.gd::poll_pad()` still multiplies the right
  stick by `STICK_SCROLL_SPEED` and advances the abstract offset. It paints nothing and is
  pinned inert by two checks above, so it is harmless; removing it would edit an audited
  input-lane file and its own tests, which this brief did not ask for.
