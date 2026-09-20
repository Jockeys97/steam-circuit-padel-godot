## menu_nav.gd — the reference's menu navigation as one testable object: which
## context owns the focus, what confirming and cancelling do, how the pad's
## directions and the stick's scrolling drive it, and how the on-screen keyboard
## takes the focus over and gives it back.
##
## Port of, function for function:
##   `menuContext`        (`js/main.js:551-557`)  which surface owns the focus
##   `ensureMenuFocus`    (`js/main.js:592-599`)  a focus always exists (via focus_nav.gd)
##   `activateMenuFocus`  (`js/main.js:697-706`)  confirm, and the OSK hand-off
##   `menuBack`           (`js/main.js:708-733`)  cancel: OSK, then the overlay, then
##                                                the screen's *declared* return
##   `pollGamepadMenu`    (`js/main.js:931-999`)  direction, repeat, stick scroll,
##                                                the confirm/back edges
##   the arrow-key branch (`js/main.js:2551-2569`) the keyboard path, same rules
##
## The model owns the ORDER and the DECISIONS, not the presentation: what a
## confirmed target does, which tab the pause overlay opens on and how the focus
## is drawn are the caller's. Where the reference's own behaviour belongs to
## another surface, the result says so by name instead of guessing:
##
##   {"kind": "osk_open",  "target": "fbMessage"}
##   {"kind": "activate",  "target": "start", "action": "to-modes"}
##   {"kind": "osk_close", "target": "fbMessage"}    back closed the keyboard
##   {"kind": "overlay",   "context": "pause"}       back is the overlay's, not the screen's
##   {"kind": "back",      "action": "to-menu", "target": "screen-menu"}
##   {"kind": "none"}                                nothing consumes it (the root)
##
## API for the UI lane:
##
##   var menu := MenuNav.new()
##   menu.set_pad_connected(true)
##   menu.set_screen_targets([…])          # the active screen's focus targets
##   menu.set_osk_targets([…])             # the on-screen keyboard's keys
##   menu.open_screen("screen-menu")       # the reference's showScreen
##   menu.ensure_focus()                   # -> "to-modes"
##   menu.keyboard_direction("down")       # -> {"moved": true, "scrolled": 0.0}
##   menu.confirm()                        # -> {"kind": "activate", "target": …}
##   menu.back()                           # -> {"kind": "back", "action": "to-menu"}
##   menu.poll_pad({"stick_x": 0.0, "stick_y": -1.0, "right_stick_y": 0.0,
##                  "buttons": {"0": false, "1": false}, "now_ms": 1000.0})
##
## `poll_pad` is a per-frame call: the reference calls `pollGamepadMenu` from the
## render loop (`js/main.js:1001-1004`), and the repeat timings and the
## "scroll when the focus cannot move" rule only make sense per frame.
extends RefCounted

const FocusNav := preload("res://src/input/focus_nav.gd")
const Osk := preload("res://src/input/osk.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")

## `gamepadAxis(pad, 3)` × 24 (`js/main.js:956-957`): the right stick scrolls.
const STICK_SCROLL_SPEED := 24.0
## The left stick / D-pad scrolls 15 px per frame when nothing can take the focus
## in that direction (`js/main.js:968`).
const FOCUS_SCROLL_SPEED := 15.0
## The arrows scroll 90 px, up/down only (`js/main.js:2555-2557`).
const KEY_SCROLL_STEP := 90.0
## First repeat after 400 ms, then every 150 ms (`js/main.js:973-977`).
const REPEAT_FIRST_MS := 400.0
const REPEAT_MS := 150.0

## The reference's contexts (`menuContext`, `js/main.js:551-557`).
const CONTEXT_OSK := "osk"
const CONTEXT_NONE := "none"
const CONTEXT_OVERLAY := "overlay"
const CONTEXT_SCREEN := "screen"

var nav: FocusNav
var osk: Osk

var _screen_id := NavRoutes.ROOT_SCREEN
var _overlay_id := ""
var _in_match := false
var _paused := false
var _pad_connected := false

var _screen_targets: Array = []
var _overlay_targets: Array = []
var _osk_targets: Array = []

var _menu_dir := ""
var _repeat_at := 0.0
var _prev_confirm := false
var _prev_back := false


func _init() -> void:
	nav = FocusNav.new()
	osk = Osk.new()
	_activate_context()


# ---------------------------------------------------------------------------
# Context (menuContext, js/main.js:551-557)
# ---------------------------------------------------------------------------

func set_pad_connected(connected: bool) -> void:
	_pad_connected = connected


func pad_connected() -> bool:
	return _pad_connected


## `showScreen(name)` (`js/ui.js:595-605`): one screen is active, the overlay is
## not. The reference then lets the next frame's `ensureMenuFocus` pick the first
## target of the new context.
func open_screen(screen_id: String) -> void:
	_screen_id = screen_id
	_overlay_id = ""
	_activate_context()


func screen_id() -> String:
	return _screen_id


func push_overlay(overlay_id: String) -> void:
	_overlay_id = overlay_id
	_activate_context()


func pop_overlay() -> void:
	_overlay_id = ""
	_activate_context()


func overlay_id() -> String:
	return _overlay_id


func set_in_match(running: bool, paused: bool) -> void:
	_in_match = running
	_paused = paused
	_activate_context()


func set_screen_targets(targets: Array) -> void:
	_screen_targets = targets
	_activate_context()


func set_overlay_targets(targets: Array) -> void:
	_overlay_targets = targets
	_activate_context()


func set_osk_targets(targets: Array) -> void:
	_osk_targets = targets
	_activate_context()


## A scrolling container for `focus_nav.gd`'s scroll resolution
## (`js/main.js:605-613`), registered through the menu so a caller has one seam.
func register_scroll_container(container: Dictionary) -> void:
	nav.register_container(container)


## `menuContext` (`js/main.js:551-557`): the keyboard comes first, then the field
## (an in-match screen has no menu focus at all), then the overlay, then the
## active screen.
func context_kind() -> String:
	if osk.is_open():
		return CONTEXT_OSK
	if _in_match and not _paused:
		return CONTEXT_NONE
	if _overlay_id != "":
		return CONTEXT_OVERLAY
	return CONTEXT_SCREEN


func context_id() -> String:
	match context_kind():
		CONTEXT_OSK:
			return "osk"
		CONTEXT_OVERLAY:
			return _overlay_id
		CONTEXT_SCREEN:
			return _screen_id
	return ""


## The context's targets become the focus's targets, and the focus is cleared
## first — `openOsk`/`closeOsk` both call `setMenuFocus(null)` before
## `ensureMenuFocus()` (`js/main.js:529-539`) so the first target of the new
## context takes the focus.
func _activate_context() -> void:
	nav.clear_targets()
	var targets: Array = []
	match context_kind():
		CONTEXT_OSK:
			targets = _osk_targets
		CONTEXT_OVERLAY:
			targets = _overlay_targets
		CONTEXT_SCREEN:
			targets = _screen_targets
	for target in targets:
		nav.add_target(target)
	nav.ensure_focus()


## `ensureMenuFocus` (`js/main.js:592-599`).
func ensure_focus() -> String:
	return nav.ensure_focus()


func focus_id() -> String:
	return nav.focus_id()


# ---------------------------------------------------------------------------
# Confirm (activateMenuFocus, js/main.js:697-706)
# ---------------------------------------------------------------------------

## Confirming: with the focus on a text field and a pad connected, the on-screen
## keyboard opens — a pad player cannot type into a text field any other way
## (`activateMenuFocus` in the reference). Otherwise the focused target is activated
## and the caller runs the action. "Text field" means a target that *declares* one
## (`FocusNav.is_text_field`: `kind == "text_field"`, or an explicit `input_type`):
## a menu row declares neither, so confirming it activates it.
func confirm() -> Dictionary:
	var target := nav.focus()
	if target.is_empty():
		return {"kind": "none", "target": ""}
	if FocusNav.is_text_field(target) and _pad_connected and not osk.is_open():
		osk.open_for(
			String(target["id"]),
			String(target.get("value", "")),
			int(target.get("max_length", Osk.UNBOUNDED)),
			String(target.get("field_label", "")),
		)
		_activate_context()
		return {"kind": "osk_open", "target": String(target["id"]), "label": osk.label()}
	return {
		"kind": "activate",
		"target": String(target["id"]),
		"action": String(target.get("action", "")),
	}


# ---------------------------------------------------------------------------
# Cancel (menuBack, js/main.js:708-733)
# ---------------------------------------------------------------------------

## Cancelling, in the reference's order: an open keyboard closes and gives the
## field back (`js/main.js:709-712`), then the overlay owns "back" while it is up
## (`:713-724`), then the active screen's **declared** return fires.
##
## The declared return is the fix the reference audit guards
## (`scripts/gamepad-nav-audit.mjs:67-82`): "back" used to take the first
## `[data-action^="to-"]` on the screen, which on the menu is the top bar and
## opened the Profile — going forward, not back. So the declared `data-back`
## target wins, and the positional criterion survives only as the fallback for a
## screen that declares nothing (`js/main.js:731`).
func back() -> Dictionary:
	if osk.is_open():
		var field := osk.close()
		_activate_context()
		if field != "" and nav.has_target(field):
			nav.set_focus(field)
		return {"kind": "osk_close", "target": field}
	if context_kind() == CONTEXT_OVERLAY:
		return {"kind": "overlay", "context": _overlay_id}
	if context_kind() == CONTEXT_NONE:
		return {"kind": "none", "target": ""}
	# The root is the root: the reference audit asserts that the menu declares no
	# return — "e' la radice della navigazione", back from here must lead nowhere
	# (`scripts/gamepad-nav-audit.mjs:67-82`). The reference's *code* would still
	# take the positional fallback below and click the top bar's first `to-*`
	# action, i.e. open the Profile (`js/main.js:731`, the very defect that audit
	# describes); the model refuses that path on the declared root and the audit
	# reports the difference instead of hiding it.
	if _screen_id == NavRoutes.ROOT_SCREEN:
		return {"kind": "none", "target": "", "root": true}
	var action := context_back_action()
	if action == "":
		return {"kind": "none", "target": ""}
	var target := NavRoutes.screen_of_action(action)
	if target != "" and target != _screen_id:
		_screen_id = target
		_activate_context()
	return {"kind": "back", "action": action, "target": target}


## The declared return of the active screen, with the reference's legacy fallback.
func context_back_action() -> String:
	var declared := NavRoutes.back_action(_screen_id)
	if declared != "":
		return declared
	return legacy_back_action()


## The pre-fix criterion (`js/main.js:731`): the first `to-*` action of the screen.
## Kept because the reference keeps it, and unreachable from every shipped screen
## that declares a return — the audit asserts exactly that.
func legacy_back_action() -> String:
	var row := NavRoutes.row(_screen_id)
	if row.is_empty():
		return ""
	var to: Array = row["to"]
	return "" if to.is_empty() else String(to[0])


# ---------------------------------------------------------------------------
# Directions: the pad (pollGamepadMenu) and the keyboard (the arrow branch)
# ---------------------------------------------------------------------------

## The direction the pad's stick and D-pad resolve to, in the reference's order:
## the D-pad or the stick, up before down before left before right
## (`js/main.js:940-952`). `""` means neutral. The stick value is expected to have
## been through the radial deadzone already (`input_map.gd:_radial`).
static func direction(state: Dictionary) -> String:
	var stick_x := float(state.get("stick_x", 0.0))
	var stick_y := float(state.get("stick_y", 0.0))
	var buttons: Dictionary = state.get("buttons", {})
	var pressed := func(button: String) -> bool: return bool(buttons.get(button, false))
	if pressed.call("12") or stick_y < 0.0:
		return "up"
	if pressed.call("13") or stick_y > 0.0:
		return "down"
	if pressed.call("14") or stick_x < 0.0:
		return "left"
	if pressed.call("15") or stick_x > 0.0:
		return "right"
	return ""


## One frame of pad navigation (`pollGamepadMenu`, `js/main.js:931-999`). Returns
## what happened, so a caller can render or log it:
##   {"dir": …, "focus_moved": bool, "scrolled": float, "confirm": bool, "back": bool}
func poll_pad(state: Dictionary) -> Dictionary:
	var result := {"dir": "", "focus_moved": false, "scrolled": 0.0, "confirm": false, "back": false}
	nav.ensure_focus()
	if context_kind() == CONTEXT_NONE:
		return result

	var dir := direction(state)
	result["dir"] = dir

	# The right stick always scrolls (`js/main.js:954-957`): the first gesture a
	# player tries on a long page.
	var stick_scroll := float(state.get("right_stick_y", 0.0))
	if stick_scroll != 0.0:
		var stick_delta := stick_scroll * STICK_SCROLL_SPEED
		nav.scroll(stick_delta)
		result["scrolled"] += stick_delta

	var now := float(state.get("now_ms", 0.0))
	if dir != "":
		var vertical := dir == "up" or dir == "down"
		var nothing_to_focus := vertical and nav.find_target(dir).is_empty()
		if nothing_to_focus:
			# Continuous, every frame — not in steps (`js/main.js:966-969`).
			var delta := FOCUS_SCROLL_SPEED if dir == "down" else -FOCUS_SCROLL_SPEED
			nav.scroll(delta)
			result["scrolled"] += delta
			_menu_dir = dir
		elif dir != _menu_dir:
			_menu_dir = dir
			_repeat_at = now + REPEAT_FIRST_MS
			result["focus_moved"] = nav.move_focus(dir)
		elif now >= _repeat_at:
			_repeat_at = now + REPEAT_MS
			result["focus_moved"] = nav.move_focus(dir)
	else:
		_menu_dir = ""

	var buttons: Dictionary = state.get("buttons", {})
	var confirm := bool(buttons.get("0", false))
	if confirm and not _prev_confirm:
		result["confirm"] = true
	_prev_confirm = confirm
	var back := bool(buttons.get("1", false)) or bool(buttons.get("2", false))
	if back and not _prev_back:
		result["back"] = true
	_prev_back = back
	return result


## The arrow keys (`js/main.js:2551-2559`): move the focus, and where the focus
## cannot go, scroll — the same rule as the pad, a different step.
func keyboard_direction(dir: String) -> Dictionary:
	var moved := nav.move_focus(dir)
	var scrolled := 0.0
	if not moved and (dir == "up" or dir == "down"):
		scrolled = KEY_SCROLL_STEP if dir == "down" else -KEY_SCROLL_STEP
		nav.scroll(scrolled)
	return {"moved": moved, "scrolled": scrolled}


## The pad's repeat state, exposed for the audit: `{"dir":…, "repeat_at":…}`.
func repeat_state() -> Dictionary:
	return {"dir": _menu_dir, "repeat_at": _repeat_at}
