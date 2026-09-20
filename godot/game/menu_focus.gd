## menu_focus.gd — a screen's navigation, driven by `godot/src/input/**`.
##
## THE PROBLEM THIS SOLVES. `godot/game/main_menu.gd` used to carry its own
## navigation: explicit `focus_neighbor_*` paths per button plus Godot's built-in
## `ui_*` actions. That is a private copy of rules the input lane had already
## ported and verified (`docs/wayfinder/evidence/input-accessibility-port.md`,
## `PASS 4/4`, 308 checks): the reference's geometric "next target in this
## direction", the no-wrap rule, the wide-target rule, the confirm/cancel split and
## the declared-back rules. Two navigators over one screen also means two answers to
## "where does the focus go", and the screen could not inherit any of the audited
## behaviour.
##
## WHAT THIS FILE IS. A thin adapter, not a second model. It holds
## `FocusNav` + `MenuNav` (`godot/src/input/`), registers each Control as a focus
## target with its own rectangle, and translates Godot's `InputEventKey` /
## gamepad state into the model's calls. It decides NOTHING about navigation:
##
##   - `menu.keyboard_direction(dir)` (`js/main.js:2551-2569`) moves the focus and
##     reports whether it moved, so the screen knows when to scroll instead;
##   - `menu.poll_pad({…})` (`pollGamepadMenu`, `js/main.js:931-999`) handles the
##     direction, the repeat timings, the right-stick scroll and the confirm/back
##     edges;
##   - `menu.back()` (`menuBack`, `js/main.js:708-733`) is the declared-back rule:
##     the active screen's own return, and on the root it leads NOWHERE — the
##     reference's own defect (`scripts/gamepad-nav-audit.mjs:67-82`) that the model
##     refuses to reproduce.
##
## The screen supplies ids, actions and the locked/disabled flags; it receives the
## model's result dictionaries and acts on them. Focus PAINTING (`grab_focus()`) is
## the screen's too: the model owns the decision, the Control tree owns the look.
##
## The rectangle the model reasons about is `Control.get_global_rect()` in the same
## pixels the reference's thresholds (`8 px`, `+3/px`, `+600`) are written in.
extends RefCounted

const FocusNav := preload("res://src/input/focus_nav.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")

## The model, reachable so a screen (or a test) can ask it directly.
var menu
var screen_id: String = NavRoutes.ROOT_SCREEN

var _specs: Array = []                 # {id, action, node, kind, locked, disabled, hidden}
var _nodes: Dictionary = {}            # id -> Control
var _focus_dirty: bool = true
var _last_result: Dictionary = {}


func _init(initial_screen: String = NavRoutes.ROOT_SCREEN) -> void:
	menu = MenuNav.new()
	screen_id = initial_screen
	menu.open_screen(initial_screen)


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

## Registers one focusable Control. `opts`: `kind` ("button" | "text_field" |
## "range" | "card"), `locked` (the reference's `.mode-card--locked`), `disabled`,
## `action` (the menu action the model reports on confirm), `contains_buttons`.
func add(id: String, node: Control, action: String, opts: Dictionary = {}) -> void:
	if node == null:
		return
	# A registered Control IS a focus target — the screen declared it by naming it
	# here — and `apply_focus()` paints the model's focus with `grab_focus()`. A
	# `PanelContainer` card defaults to `FOCUS_NONE`, so `grab_focus()` refused it
	# with the engine's own warning and the focus ring never landed on a mode,
	# arena or athlete card: the model moved, the player saw nothing. Making the
	# declaration true is what fixes the visible focus on every screen at once; the
	# painting itself stays in this one place.
	if node.focus_mode == Control.FOCUS_NONE:
		node.focus_mode = Control.FOCUS_ALL
	var spec := {
		"id": id,
		"action": action,
		"node": node,
		"kind": String(opts.get("kind", "button")),
		"locked": bool(opts.get("locked", false)),
		"disabled": bool(opts.get("disabled", false)),
		"contains_buttons": bool(opts.get("contains_buttons", false)),
	}
	_specs.append(spec)
	_nodes[id] = node
	_focus_dirty = true


func clear() -> void:
	_specs.clear()
	_nodes.clear()
	_focus_dirty = true


func has(id: String) -> bool:
	return _nodes.has(id)


func node_of(id: String) -> Control:
	return _nodes.get(id, null)


func ids() -> Array:
	var out: Array = []
	for spec in _specs:
		out.append(String(spec["id"]))
	return out


func action_of(id: String) -> String:
	for spec in _specs:
		if String(spec["id"]) == id:
			return String(spec["action"])
	return ""


## A control that is hidden, disabled or locked cannot take the focus — the model's
## own filter (`focus_nav.gd::_selectable`), fed from the live Control state instead
## of being restated. `is_visible_in_tree()` is the port's `offsetParent !== null`.
func _target(spec: Dictionary) -> Dictionary:
	var node: Control = spec["node"]
	# A screen that rebuilt its view (the athlete picker, the wardrobe) frees the
	# controls it replaced. Reading a freed Control is an engine error, not a `false`,
	# so a dead node is answered here as what it is: not a target. The bridge re-reads
	# the shell's controls on the same frame (`UiFocusBridge.refresh_if_rebuilt`), so
	# this is the guard that keeps the frame between the two from throwing.
	if node == null or not is_instance_valid(node):
		return {
			"id": String(spec["id"]), "rect": Rect2(), "kind": String(spec["kind"]),
			"action": String(spec["action"]), "locked": bool(spec["locked"]),
			"disabled": true, "hidden": true, "drawn": false,
			"contains_buttons": bool(spec["contains_buttons"]),
		}
	var visible_now := node.is_visible_in_tree()
	var disabled := bool(spec["disabled"]) or (node is BaseButton and (node as BaseButton).disabled)
	return {
		"id": String(spec["id"]),
		"rect": node.get_global_rect(),
		"kind": String(spec["kind"]),
		"action": String(spec["action"]),
		"locked": bool(spec["locked"]),
		"disabled": disabled,
		"hidden": not visible_now,
		"drawn": visible_now,
		"contains_buttons": bool(spec["contains_buttons"]),
	}


## Recomputes the model's target list from the live Controls. Cheap; call it after
## a layout pass and after anything that changes visibility.
func refresh() -> void:
	var targets: Array = []
	for spec in _specs:
		targets.append(_target(spec))
	menu.set_screen_targets(targets)
	_focus_dirty = false


func _ensure() -> void:
	if _focus_dirty:
		refresh()


# ---------------------------------------------------------------------------
# Keyboard
# ---------------------------------------------------------------------------

const KEY_DIRECTIONS := {
	KEY_UP: "up", KEY_W: "up",
	KEY_DOWN: "down", KEY_S: "down",
	KEY_LEFT: "left", KEY_A: "left",
	KEY_RIGHT: "right", KEY_D: "right",
}
const KEY_CONFIRM := [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const KEY_BACK := [KEY_ESCAPE]

## `GAMEPAD_MENU_DEADZONE` (`js/main.js:146`), applied per axis by `gamepadAxis`
## (`js/main.js:243-246`). It is the MENU's own deadzone, not the gameplay one:
## `menu_nav.direction()` reads any non-zero stick value as a direction, so a stick
## left un-filtered walks the focus on its own drift and on its own repeat clock.
const MENU_STICK_DEADZONE := 0.28


## One keyboard event through the model. Returns
## `{handled, kind, action, target, moved}`; `handled` is true for the keys the
## model owns, so the caller can mark them handled and stop Godot's built-in
## `ui_*` navigation from moving the same focus a second time.
##
## The arrow keys are the reference's keyboard branch (`js/main.js:2551-2569`):
## move, and where the focus cannot go, scroll. Confirm and cancel are
## `activateMenuFocus` / `menuBack` (`js/main.js:2552-2560`).
func handle_key(event: InputEventKey) -> Dictionary:
	if not event.pressed or event.echo:
		return _nothing()
	_ensure()
	var code := event.keycode
	if KEY_DIRECTIONS.has(code):
		var moved: Dictionary = menu.keyboard_direction(String(KEY_DIRECTIONS[code]))
		_focus_dirty = false
		return {"handled": true, "kind": "", "action": "", "target": menu.focus_id(),
			"moved": bool(moved["moved"]), "scrolled": float(moved["scrolled"])}
	if KEY_CONFIRM.has(code):
		var result: Dictionary = menu.confirm()
		result["handled"] = true
		result["moved"] = false
		return result
	if KEY_BACK.has(code):
		var result: Dictionary = menu.back()
		result["handled"] = true
		result["moved"] = false
		return result
	return _nothing()


func _nothing() -> Dictionary:
	return {"handled": false, "kind": "", "action": "", "target": "", "moved": false}


# ---------------------------------------------------------------------------
# Gamepad
# ---------------------------------------------------------------------------

## One frame of pad navigation, exactly `pollGamepadMenu` (`js/main.js:931-999`):
## read the stick and the buttons, hand them to the model, get back what happened.
## `{dir, focus_moved, scrolled, confirm, back}` plus the model's own verdicts,
## already resolved into `{kind, action, target}` where a confirm/back happened.
##
## `device` is the joypad the CALLER selected (`selectPrimaryGamepad`,
## `js/main.js:259-272`): the first entry of the host's list is not necessarily the
## pad in the player's hands, so the device is named from the outside rather than
## assumed here — the gameplay samplers already pick their own seat the same way
## (`match_controller._refresh_pads`).
func poll_pad(device: int = 0) -> Dictionary:
	_ensure()
	return step_pad(_pad_state(device))


## A physical pad event reaches the focused screen before the next rendered frame.
## On macOS that event can arrive a frame before `Input` exposes the same value through
## `get_joy_axis` / `is_joy_button_pressed`; feeding it into this very model makes the
## menu respond immediately, while the later poll sees the same held state and cannot
## produce a second confirm or move. This is deliberately NOT UiFocusBridge.dispatch:
## that owns a separate keyboard-style navigator and was the source of double moves.
func handle_pad_event(event: InputEvent, device: int = 0) -> Dictionary:
	_ensure()
	var state := _pad_state(device)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		match motion.axis:
			JOY_AXIS_LEFT_X:
				state["stick_x"] = _menu_value(motion.axis_value)
			JOY_AXIS_LEFT_Y:
				state["stick_y"] = _menu_value(motion.axis_value)
			JOY_AXIS_RIGHT_Y:
				state["right_stick_y"] = _menu_value(motion.axis_value)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		var key := _menu_button_key(button.button_index)
		if key != "":
			(state["buttons"] as Dictionary)[key] = button.pressed
	return step_pad(state)


func _pad_state(device: int) -> Dictionary:
	return {
		"stick_x": _menu_axis(device, JOY_AXIS_LEFT_X),
		"stick_y": _menu_axis(device, JOY_AXIS_LEFT_Y),
		"right_stick_y": _menu_axis(device, JOY_AXIS_RIGHT_Y),
		# The buttons are the model's own names, not Godot's: 0/1/2 are A/B/X and
		# 12/13/14/15 are the D-pad (`js/main.js:940-951`). Godot's `JoyButton` enum
		# is one behind the browser's from UP on (11..14) — the trap `project.godot`
		# spells out at the top of its `[input]` block — so the D-pad is translated
		# here instead of being renamed in the model.
		"buttons": {
			"0": _menu_button(device, JOY_BUTTON_A),
			"1": _menu_button(device, JOY_BUTTON_B),
			"2": _menu_button(device, JOY_BUTTON_X),
			"12": _menu_button(device, JOY_BUTTON_DPAD_UP),
			"13": _menu_button(device, JOY_BUTTON_DPAD_DOWN),
			"14": _menu_button(device, JOY_BUTTON_DPAD_LEFT),
			"15": _menu_button(device, JOY_BUTTON_DPAD_RIGHT),
		},
		"now_ms": float(Time.get_ticks_msec()),
	}


static func _menu_value(value: float) -> float:
	return 0.0 if absf(value) < MENU_STICK_DEADZONE else value


## `gamepadAxis` (`js/main.js:243-246`): one axis, centred by the menu's own
## deadzone before the model ever sees it. `NO_DEVICE` — the seat the caller selected
## when nobody is connected — reads as centred, so a caller may pass its own seat
## through without asking twice whether a pad exists.
static func _menu_axis(device: int, axis: JoyAxis) -> float:
	if device < 0:
		return 0.0
	return _menu_value(Input.get_joy_axis(device, axis))


## The same for a button: no pad means every button reads released, which is what
## keeps the model's confirm/back edges quiet rather than stuck down.
static func _menu_button(device: int, button: JoyButton) -> bool:
	return device >= 0 and Input.is_joy_button_pressed(device, button)


static func _menu_button_key(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_A:
			return "0"
		JOY_BUTTON_B:
			return "1"
		JOY_BUTTON_X:
			return "2"
		JOY_BUTTON_DPAD_UP:
			return "12"
		JOY_BUTTON_DPAD_DOWN:
			return "13"
		JOY_BUTTON_DPAD_LEFT:
			return "14"
		JOY_BUTTON_DPAD_RIGHT:
			return "15"
	return ""


## The same, with a caller-supplied frame: the slice test drives the pad with
## synthetic sticks and buttons, and a screen with a real pad calls `poll_pad()`.
func step_pad(state: Dictionary) -> Dictionary:
	_ensure()
	var result: Dictionary = menu.poll_pad(state)
	result["kind"] = ""
	result["action"] = ""
	result["target"] = menu.focus_id()
	if bool(result.get("back", false)):
		var back: Dictionary = menu.back()
		result["kind"] = String(back.get("kind", ""))
		result["action"] = String(back.get("action", ""))
		result["target"] = String(back.get("target", result["target"]))
	elif bool(result.get("confirm", false)):
		var confirm: Dictionary = menu.confirm()
		result["kind"] = String(confirm.get("kind", ""))
		result["action"] = String(confirm.get("action", ""))
		result["target"] = String(confirm.get("target", result["target"]))
	return result


func pad_connected(connected: bool) -> void:
	menu.set_pad_connected(connected)


# ---------------------------------------------------------------------------
# Focus presentation (the screen's half)
# ---------------------------------------------------------------------------

## The Control the model's focus currently names, or null.
func focus_node() -> Control:
	_ensure()
	var node: Control = _nodes.get(menu.focus_id(), null)
	# The same guard `_target()` states: a freed Control is not a node to paint on, and
	# returning it is the engine error a rebuilt view used to raise.
	return node if node != null and is_instance_valid(node) else null


## The id of the target the model's focus is on, or "". The screen's own report
## prints it (`main_menu.gd::screen_report`) and a test reads it back; it was
## missing, and the screen's report aborted on every call because of it — a
## `SCRIPT ERROR` that a log reader has to notice, which is exactly the shape the
## independent review's M-1 describes.
func focus_id() -> String:
	_ensure()
	return menu.focus_id()


## Paints the model's focus onto the Control tree. Returns the node that took it,
## or null when the model has no focus (an empty screen) — the caller decides
## whether that matters.
func apply_focus() -> Control:
	var node := focus_node()
	if node != null and node.is_visible_in_tree():
		node.grab_focus()
	return node


func ensure_focus() -> String:
	_ensure()
	return menu.ensure_focus()


## `ensureMenuFocus` after a screen rebuild (`js/main.js:592-599`): the focus is
## cleared and the FIRST target takes it. Exposed so a caller — and a test — can put
## the focus back on a known row instead of guessing where the last navigation left
## it. Returns the target that took it.
func reset_focus() -> String:
	menu.nav.clear_focus()
	_ensure()
	return menu.ensure_focus()


# ---------------------------------------------------------------------------
# Reachability (what the reference's audit asserts over the DOM)
# ---------------------------------------------------------------------------

## Every target this screen's own navigation can reach from its first focusable
## Control, following the model's own rules (no wrapping, wide targets win). This is
## the port of `scripts/gamepad-nav-audit.mjs`'s reachability question — "the focus
## can get everywhere the player can click" — asked of the model instead of the DOM.
##
## Breadth-first over the four directions, so a control that is only reachable by
## going right then down is still counted.
func reachable_ids() -> Array:
	_ensure()
	var targets: Array = menu.nav.targets()
	if targets.is_empty():
		return []
	# The walk MOVES the model's focus to ask "can I get there from here", so the
	# focus the player had is saved first and put back at the end. Without this the
	# walk left the focus on whatever it visited last: a report or an audit that
	# asked the reachability question silently teleported the player across the
	# screen, and `set_focus(menu.nav.focus_id())` restored the value the walk had
	# already overwritten — a no-op dressed as a restore.
	var restore: String = menu.nav.focus_id()
	var start := String(targets[0]["id"])
	var seen := {start: true}
	var queue: Array = [start]
	while queue.size() > 0:
		var current: String = queue.pop_front()
		menu.nav.set_focus(current)
		for dir in FocusNav.DIRECTIONS:
			var next: Dictionary = menu.nav.find_target(String(dir))
			if next.is_empty():
				continue
			var next_id := String(next["id"])
			if not seen.has(next_id):
				seen[next_id] = true
				queue.append(next_id)
	menu.nav.set_focus(restore)
	menu.nav.ensure_focus()
	var out: Array = seen.keys()
	out.sort()
	return out


## The ids the model can actually land on (what `reachable_ids()` is measured
## against): a locked or hidden control is not in this list.
func focusable_ids() -> Array:
	_ensure()
	var out: Array = []
	for target in menu.nav.targets():
		out.append(String(target["id"]))
	out.sort()
	return out


## The last result dictionary the model produced, for a screen that wants to log it.
func last_result() -> Dictionary:
	return _last_result.duplicate()
