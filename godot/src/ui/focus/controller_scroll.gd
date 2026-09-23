## controller_scroll.gd — the right stick scrolls the live UI, once, for every screen.
##
## THE GAP THIS CLOSES. `src/input/menu_nav.gd::poll_pad()` has always modelled the
## stick (`right_stick_y` × `STICK_SCROLL_SPEED`, `js/main.js:954-957`) and
## `focus_nav.gd::scroll()` has always accumulated an abstract per-container offset.
## Nothing turned that number into `ScrollContainer.scroll_vertical`, so a player who
## pushed the right stick on a long screen saw nothing move. This helper is that one
## missing step, and only that step.
##
## IT IS NOT A SECOND INPUT MODEL. It does not decide directions, repeat, confirm or
## cancel — the focus model and `menu_nav.gd` own all of that, and the left stick
## stays theirs. This helper reads exactly one axis (`JOY_AXIS_RIGHT_Y`) and writes
## exactly one property (`ScrollContainer.scroll_vertical`). It never calls
## `grab_focus()` and never calls `ensure_control_visible()`: a manual scroll is the
## player's and is never snapped back.
##
## ONE FRAME, ONE CALL. `update(delta)` is the whole surface:
##
##   var scroll := ControllerScroll.new()
##   scroll.set_device(pad)                  # -1 = nobody connected
##   scroll.set_surface(active_screen)       # the modal that owns the stick, or null
##   scroll.set_focus_source(func(): return focus_node)
##   ...
##   scroll.update(delta)                    # once per frame
##
## `set_surface()` is the modal rule, stated by the caller: the on-screen keyboard,
## then an overlay, then the active screen. A surface that is not visible in the tree
## scrolls nothing, so the screen behind a modal is inert without a second flag.
##
## DEADZONE AND SPEED. The deadzone is the menu's own (`menu_focus.gd`'s
## `MENU_STICK_DEADZONE`, `js/main.js:146`): the stick that walks the focus is the
## stick that scrolls. The travel left above it is rescaled to `0..1` and multiplied
## by `SPEED_PX_PER_S`, so the speed is proportional to the deflection.
##
## FRACTIONAL, DELTA-TIMED. `scroll_vertical` is an `int`, so the helper holds a
## `float` of its own and advances it by `speed * delta`. The integer part is written
## to the control and the fraction carries to the next frame: a frame shorter than a
## pixel accumulates instead of vanishing, and the motion does not depend on the
## frame rate.
##
## NEVER FIGHTING THE PLAYER. The helper remembers the integer it last wrote. When
## the control's offset has moved by anything else — the wheel, a drag, the engine's
## own `follow_focus` — the helper re-reads the control and continues from there.
## That is what keeps a manual scroll from being undone on the next frame.
##
## CLAMPED. The offset is clamped to `0 .. (v_scroll_bar.max_value - v_scroll_bar.page)`.
## Past either end the stick does nothing and the fraction is dropped.
##
## STOPPED. A stick inside the deadzone stops the scroll and drops the fraction, so a
## released stick cannot coast. `reset()` stops it outright and is what a host calls
## on a screen change, a controller disconnect or a window focus loss.
##
## SUSPENDED UNTIL NEUTRAL. `suspend()` is `reset()` plus a latch: the helper stays
## inert until the stick comes back inside the deadzone, so a stick left deflected
## while the window was in the background cannot resume the moment the window returns.
## A disconnect suspends the same way, for the same reason.
extends RefCounted

## `menu_focus.gd::MENU_STICK_DEADZONE` (`js/main.js:146`): one deadzone for the menu,
## so the axis that scrolls is filtered by the same number as the axis that navigates.
const DEADZONE := 0.28
## Pixels per second at full deflection, before the deadzone rescale. The reference's
## own gesture is 24 px per frame at 60 Hz (`js/main.js:956-957`) ≈ 1440 px/s; this is
## the conservative half of that, measured on the screens themselves.
const SPEED_PX_PER_S := 900.0
## The axis this helper owns. Named once: nothing else in the file reads an axis.
const AXIS := JOY_AXIS_RIGHT_Y

var _device := -1
var _surface: Control = null
var _enabled := true
var _focus_source: Callable = Callable()
## A caller-supplied axis reading, for an audit that must drive a held stick with no
## hardware attached. Unset in the game: `_axis()` then reads the real seat.
var _axis_source: Callable = Callable()

## The float offset the helper is integrating, and the integer it last wrote. `_written`
## is the tell for "somebody else moved the control": a mismatch re-syncs from the
## control instead of from the helper's own stale fraction.
var _offset := 0.0
var _written := -1
var _container: ScrollContainer = null
var _last: Dictionary = {}
## Set by `suspend()`: inert until the axis reads neutral again, then it clears itself.
var _suspended := false


# ---------------------------------------------------------------------------
# Wiring (the host's half)
# ---------------------------------------------------------------------------

## The seat the menus read (`selectPrimaryGamepad`), or `-1` when nobody is connected.
## A disconnected seat reads as centred here as well, so an absent pad is never polled.
func set_device(device: int) -> void:
	if device != _device:
		_device = device
		_release()


## The UI that owns the stick this frame — the modal if one is up, the active screen
## otherwise. `null` (or a freed node) scrolls nothing.
func set_surface(surface: Control) -> void:
	if surface != _surface:
		_surface = surface
		_release()


## `false` while a non-UI context owns the input (the gameplay frame). The surface
## rule usually says this already; the flag is for a host that knows sooner.
func set_enabled(enabled: bool) -> void:
	if not enabled:
		_release()
	_enabled = enabled


## The focused Control, when the caller has one. Nested panels use it to pick the
## relevant scroll container; a caller without a focus model leaves it unset and the
## surface's primary container is used.
func set_focus_source(source: Callable) -> void:
	_focus_source = source


## The axis reading, supplied by the caller instead of the engine. This is the same
## shape of seam the overlays use for a pad (`PauseOverlay.handle_joypad_motion` takes
## an injected `InputEventJoypadMotion`): the audit drives a stick the machine does not
## have, and nothing else changes. A source that is not set leaves `_axis()` reading
## the selected seat, which is what the game does.
func set_axis_source(source: Callable) -> void:
	_axis_source = source


## Stop scrolling now: drop the fraction, forget the container. Called by the host on
## a screen change.
func reset() -> void:
	_release()


## Stop scrolling AND stay stopped until the stick returns to neutral. This is what a
## window focus loss and a controller disconnect call: `reset()` alone drops the
## fraction, and the very next frame would read the still-deflected axis and scroll
## again — the stick would resume the instant the window came back.
func suspend() -> void:
	_release()
	_suspended = true


## True while the helper is waiting for the stick to come back to neutral.
func is_suspended() -> bool:
	return _suspended


# ---------------------------------------------------------------------------
# The frame
# ---------------------------------------------------------------------------

## One frame. Returns the same dictionary `last_report()` keeps, so a test can read
## what happened without a second call:
##   {active, container, offset, applied, max, axis, magnitude}
func update(delta: float) -> Dictionary:
	var report := {
		"active": false, "container": null, "offset": 0.0,
		"applied": 0.0, "max": 0.0, "axis": 0.0, "magnitude": 0.0,
		"suspended": _suspended,
	}
	var axis := _axis()
	report["axis"] = axis
	if _suspended:
		# Latched: nothing moves until the player lets the stick go. Only the neutral
		# reading clears it, so a held stick cannot resume on the frame the window (or
		# the pad) comes back.
		if absf(axis) <= DEADZONE:
			_suspended = false
		_last = report
		return report
	if not _enabled or axis == 0.0:
		# A released stick stops the scroll AND drops the fraction: a coast after the
		# player let go is the one thing a menu scroll must never do.
		_release()
		_last = report
		return report
	var magnitude := (absf(axis) - DEADZONE) / (1.0 - DEADZONE)
	if magnitude <= 0.0:
		_release()
		_last = report
		return report
	magnitude = minf(1.0, magnitude)
	report["magnitude"] = magnitude
	var container := _resolve_container()
	if container == null:
		_release()
		_last = report
		return report
	var max_offset := _max_offset(container)
	if max_offset <= 0.0:
		_release()
		_last = report
		return report
	# Somebody else moved the control since the last write (the wheel, a drag,
	# `follow_focus`): continue from where it actually is, never from our own stale
	# fraction. This is the whole of "a manual scroll is not undone".
	if container != _container or container.scroll_vertical != _written:
		_offset = float(container.scroll_vertical)
	var speed := SPEED_PX_PER_S * magnitude
	var before := _offset
	_offset = clampf(_offset + speed * signf(axis) * delta, 0.0, max_offset)
	var whole := int(round(_offset))
	container.scroll_vertical = whole
	_container = container
	_written = whole
	report["active"] = true
	report["container"] = container
	report["offset"] = _offset
	report["applied"] = _offset - before
	report["max"] = max_offset
	_last = report
	return report


## The last frame's report, for a host that logs or an audit that asserts.
func last_report() -> Dictionary:
	return _last.duplicate()


## A keyboard or D-pad boundary step uses the same modal/container resolution.
## No pad is required for keyboard scrolling. The next stick frame re-syncs from
## this offset, just as it does after the mouse wheel.
func scroll_by(amount: float) -> void:
	if not _enabled or is_zero_approx(amount):
		return
	var target := _resolve_container()
	if target != null:
		target.scroll_vertical = int(round(clampf(
			float(target.scroll_vertical) + amount, 0.0, _max_offset(target))))


## The container the stick is driving right now, or null.
func container() -> ScrollContainer:
	return _container


## The offset the helper holds as a float, for an audit that wants the fraction.
func offset() -> float:
	return _offset


# ---------------------------------------------------------------------------
# Reading the axis
# ---------------------------------------------------------------------------

## `JOY_AXIS_RIGHT_Y` for the selected seat, centred when nobody is connected. The
## device is checked against the engine's own list: an absent pad is never polled.
func _axis() -> float:
	# A caller-supplied reading wins, and it is the ONLY thing the seam changes: the
	# same clamp, the same deadzone, the same container. An audit drives a stick the
	# machine does not have without touching a line of the behaviour under test.
	if _axis_source.is_valid():
		return clampf(float(_axis_source.call()), -1.0, 1.0)
	if _device < 0:
		return 0.0
	if not Input.get_connected_joypads().has(_device):
		return 0.0
	return clampf(Input.get_joy_axis(_device, AXIS), -1.0, 1.0)


# ---------------------------------------------------------------------------
# Resolving the container
# ---------------------------------------------------------------------------

## The focused control's nearest scrolling ancestor inside the surface, or the
## surface's primary container. `null` when the surface is not visible or holds no
## scrolling container at all.
func _resolve_container() -> ScrollContainer:
	var surface := _surface
	if surface == null or not is_instance_valid(surface) or not surface.is_visible_in_tree():
		return null
	var focused := _focused_control()
	# THE SURFACE IS THE BOUNDARY, and it is checked BEFORE the walk. A modal owns the
	# stick while it is up, and the focus may still name a control of the screen
	# underneath it (the jukebox over the result screen, the keyboard over the field):
	# walking from that control would climb out of the modal and scroll the background.
	# A focus that is not the surface or under it is not this surface's focus at all.
	if focused != null and (focused == surface or surface.is_ancestor_of(focused)):
		var near := _scrolling_ancestor(focused, surface)
		if near != null:
			return near
	return _primary_container(surface)


## The caller's focused Control, when it still is one.
func _focused_control() -> Control:
	if not _focus_source.is_valid():
		return null
	var node: Variant = _focus_source.call()
	if node is Control and is_instance_valid(node) and (node as Control).is_visible_in_tree():
		return node as Control
	return null


## `focus_nav.gd`'s own rule, asked of the live tree and stopped at the surface: the
## nearest ancestor that actually scrolls AND overflows — a panel with its own
## `ScrollContainer`. A panel that scrolls but has nothing to scroll is skipped, and
## the next one out is tried, which is what makes a nested card fall back to the body
## around it. `null` means the caller uses the surface's primary container.
func _scrolling_ancestor(node: Control, surface: Control) -> ScrollContainer:
	var current: Node = node
	while current != null:
		if current == surface:
			# The surface may itself be the container.
			if current is ScrollContainer and _overflows(current as ScrollContainer):
				return current as ScrollContainer
			return null
		if current is ScrollContainer:
			var scroll := current as ScrollContainer
			if _scrolls_vertically(scroll) and _overflows(scroll):
				return scroll
		current = current.get_parent()
	return null


## The surface's own body scroll: the first visible, vertically-overflowing
## `ScrollContainer` in tree order. That is the single container each screen builds
## under its shell; a screen with several (the jukebox) still gets a sensible one
## when the focus names no ancestor.
func _primary_container(surface: Control) -> ScrollContainer:
	var first_visible: ScrollContainer = null
	for found in _containers(surface):
		if first_visible == null:
			first_visible = found
		if _overflows(found):
			return found
	return first_visible


## Every visible `ScrollContainer` under the surface, depth-first, in tree order.
func _containers(surface: Control) -> Array:
	var out: Array = []
	_collect(surface, out)
	return out


func _collect(node: Node, out: Array) -> void:
	for child in node.get_children():
		var control := child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is ScrollContainer and _scrolls_vertically(control as ScrollContainer):
			out.append(control)
		_collect(child, out)


## The container may scroll on this axis at all — the same question
## `focus_nav.gd::scroll_container_id` asks of a registered container.
static func _scrolls_vertically(container: ScrollContainer) -> bool:
	return container.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


## `scrollHeight > clientHeight + 2` (`js/main.js:609`): the container has something
## to scroll. A page that fits is left alone, so the stick is inert on it.
static func _overflows(container: ScrollContainer) -> bool:
	return _max_offset(container) > 0.0


## The last reachable offset: the scrollable height minus the visible page. Zero when
## the content fits.
static func _max_offset(container: ScrollContainer) -> float:
	var bar := container.get_v_scroll_bar()
	if bar == null:
		return 0.0
	return maxf(0.0, bar.max_value - bar.page)


## Forget the container and the fraction. The next active frame re-reads the control.
func _release() -> void:
	_container = null
	_written = -1
	_offset = 0.0
