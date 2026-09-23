# Right-stick vertical scrolling for the Godot3D UI

## The request

A controller player expects the right analog stick to scroll a long screen up and
down, continuously, while the left stick keeps moving the focus. The screens that
can overflow today are the router screens that already ride a `ScrollContainer`
(result, roster/outfits, arena selector, help, history, profile, challenges,
feedback, settings) plus the jukebox overlay, which has two scroll columns of its
own.

## What already exists (and what was missing)

The ported input lane already *models* the right stick:
`godot/src/input/menu_nav.gd::poll_pad()` reads `right_stick_y`, multiplies it by
`STICK_SCROLL_SPEED` and calls `nav.scroll(delta)` — but `focus_nav.gd::scroll()`
only moves an abstract per-container *offset number*. Nothing in the runtime ever
turned that number into `ScrollContainer.scroll_vertical`, so the stick did nothing
on screen. `game/menu_focus.gd` reads `JOY_AXIS_RIGHT_Y` into the model and drops
the model's `scrolled` field on the floor.

So the gap is exactly one thing: a single place that maps "the right stick is
deflected this much, for this long" onto the *live* `ScrollContainer` the player is
looking at.

## The design

One new shared helper, `godot/src/ui/focus/controller_scroll.gd`
(`RefCounted`, no scene, no node ownership), plus minimal host hooks. No screen
file is refactored and the input lane is not re-implemented: the helper consumes
the live Control tree, which is the layer the screens already own.

**Proportional speed with a deadzone.** The raw axis is filtered by the menu's own
deadzone (`0.28`, the same number `MenuFocus.MENU_STICK_DEADZONE` already uses, so
the stick that walks the focus is the stick that scrolls the page). The remaining
travel is rescaled to `0..1` and multiplied by `SPEED_PX_PER_S`; a stick at half
deflection scrolls at half speed, and a stick inside the deadzone does nothing.

**Delta-time integration, fractional scroll.** `ScrollContainer.scroll_vertical` is
an `int`, so the helper keeps a `float` offset of its own and advances it by
`speed * delta`. Only the integer part is written to the control, and the fraction
carries into the next frame. A frame shorter than a pixel still accumulates instead
of being lost, and the motion is frame-rate independent.

**Clamped limits.** The offset is clamped to `0 .. (v_scroll_bar.max_value -
v_scroll_bar.page)`, so the stick cannot push the page past either end.

**Visible, active UI only.** `update()` refuses to act unless the surface is
visible in the tree, a `ScrollContainer` is actually visible under it and the
container really overflows. A hidden screen, a screen swapped out behind another
one, and the gameplay frame (no UI surface at all) scroll nothing.

**Modal ownership.** The host names one surface per frame, in the reference's own
order: the on-screen keyboard, then the jukebox overlay, then the router's active
screen. Whichever modal is up owns the stick; the screen under it does not scroll.

**Nested panels.** The target container is resolved from the *focused* control
first: the nearest visible scrolling ancestor inside the surface wins. Only when
the focus names no scrolling ancestor does the helper fall back to the surface's
primary container (the first visible, vertically-overflowing `ScrollContainer` in
tree order) — which is the single body scroll every screen builds under its shell.

**No fighting the player.** The helper remembers the integer it last wrote. If the
container's offset has moved by any other means since then — the mouse wheel, a
touch drag, Godot's own `follow_focus` bringing a row into view — the helper
re-reads the control and continues from *there* instead of snapping back to its own
stale fraction. Manual scrolling is never undone each frame.

**Stopping.** The helper stops the moment the stick returns inside the deadzone
(and drops its fraction, so a released stick cannot coast), and `reset()` stops it
outright. The host calls `reset()` on a screen change, a controller disconnect and
a window focus loss, and the helper also refuses to run while the axis reads
centred.

**What it does not touch.** It reads `JOY_AXIS_RIGHT_Y` and nothing else: the left
stick, the D-pad, confirm, cancel and the mouse are all untouched, and the helper
never calls `grab_focus()` or `ensure_control_visible()`. It is inert for a device
that is not connected, so an absent controller is never polled.

## Host hooks (the whole integration surface)

- `godot/game/main_menu.gd` — the UI scene. One helper instance, one `update()`
  call per frame in both the ported-column path and the playable router path, with
  the surface chosen as OSK > jukebox > active screen. `reset()` on
  `ScreenRouter.screen_changed`, on `Input.joy_connection_changed` and on the root
  window's `focus_exited`.
- `godot/src/ui/screens/PauseOverlay.gd` — the match's pause modal. One helper
  instance, driven from the overlay's own frame only while the overlay is open, so
  the right stick scrolls the pause card's panel when it overflows and the
  gameplay right stick (aim / teammate switching) is never touched, because the
  overlay is the only thing reading the stick while it is up.

No other screen file is edited. Every screen that already builds a
`ScrollContainer` under its shell is covered by the generic resolution above.
