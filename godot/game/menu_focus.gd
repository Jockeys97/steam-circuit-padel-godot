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
##
## THE STICK HAS ONE CONSUMER. `poll_pad()` is the only place the pad's stick becomes a
## direction: it reads the pad once per frame (`read_pad_values()`), puts that frame through
## the reference's menu deadzone and its button numbering (`pad_frame()`), and hands it to the
## model. A stick EVENT must not move the focus: a real push arrives as a burst of axis events
## and moving on each of them stepped the focus several times per push, past the model's
## repeat timings and with the keyboard's 90 px edge scroll. `UiFocusBridge.dispatch()`
## swallows the event and the frame decides. The keyboard's own branch (`handle_key` below) is
## untouched: a discrete key moves at once, which is what the reference does.
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

## `GAMEPAD_MENU_DEADZONE` (`js/main.js:146`): a menu stick under this reads as neutral,
## BEFORE the direction test (`gamepadAxis`, `js/main.js:243-246`). It is not the gameplay
## deadzone (`input_map.gd`'s `DEADZONE`, 0.15): that one shapes a shot, this one decides
## whether the menu walks at all.
const MENU_DEADZONE := 0.28


## The pad the menu listens to, resolved from the pads the system actually enumerates the way
## the reference resolves its primary pad (`selectPrimaryGamepad`, `js/main.js:775-783`): a pad
## the system numbers 3 must drive the menu exactly like the one it numbers 0, because
## `_pad_connected()` (`game/main_menu.gd`) already accepts any pad. `-1` = no pad.
static func resolve_pad_index(connected: Array) -> int:
	if connected.is_empty():
		return -1
	return int(connected[0])


## Godot's D-pad numbers in the model's up/down/left/right order — the legend is
## `project.godot:19-23`, and in Godot the D-pad is 11..14, not the browser's 12..15.
static func dpad_order() -> Array:
	return [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]


## Godot's face-button numbers in the order the model reads them (`project.godot:14-18`):
## the reference's keys `"0"`/`"1"`/`"2"` are A/B/X.
static func letter_order() -> Array:
	return [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]


## The pad's own values for one frame — the ONLY read of `Input`'s pad in this file, so the
## frame the model sees has one producer. With no pad the frame is neutral, which also
## releases the model's confirm/back edges instead of leaving one held.
func read_pad_values() -> Dictionary:
	var pad := resolve_pad_index(Input.get_connected_joypads())
	var letters: Array = []
	var dpad: Array = []
	for button in letter_order():
		letters.append(pad >= 0 and Input.is_joy_button_pressed(pad, button))
	for button in dpad_order():
		dpad.append(pad >= 0 and Input.is_joy_button_pressed(pad, button))
	if pad < 0:
		return {"pad": -1, "lx": 0.0, "ly": 0.0, "ry": 0.0, "letters": letters, "dpad": dpad,
			"now_ms": float(Time.get_ticks_msec())}
	return {
		"pad": pad,
		"lx": Input.get_joy_axis(pad, JOY_AXIS_LEFT_X),
		"ly": Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y),
		"ry": Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y),
		"letters": letters,
		"dpad": dpad,
		"now_ms": float(Time.get_ticks_msec()),
	}


## `gamepadAxis` (`js/main.js:243-246`): under `MENU_DEADZONE` the axis IS zero.
static func menu_deadzone(value: float) -> float:
	return 0.0 if absf(value) < MENU_DEADZONE else value


## One frame of the pad's own values -> the frame the model reads, in the reference's order:
## the deadzone on every stick first, then the buttons under the numbers the model speaks
## (`js/main.js:981-993` tests `b(12)`..`b(15)` for the D-pad, so Godot's 11..14 and the
## class="menu-focus" buttons are translated here, once).
static func pad_frame(values: Dictionary) -> Dictionary:
	var letters: Array = values.get("letters", [])
	var dpad: Array = values.get("dpad", [])
	var letter := func(i: int) -> bool: return i < letters.size() and bool(letters[i])
	var pad_button := func(i: int) -> bool: return i < dpad.size() and bool(dpad[i])
	return {
		"stick_x": menu_deadzone(float(values.get("lx", 0.0))),
		"stick_y": menu_deadzone(float(values.get("ly", 0.0))),
		"right_stick_y": menu_deadzone(float(values.get("ry", 0.0))),
		"buttons": {
			"0": letter.call(0), "1": letter.call(1), "2": letter.call(2),
			"12": pad_button.call(0), "13": pad_button.call(1),
			"14": pad_button.call(2), "15": pad_button.call(3),
		},
		"now_ms": float(values.get("now_ms", 0.0)),
	}


## One frame of pad navigation, exactly `pollGamepadMenu` (`js/main.js:931-999`): the pad's
## values, the deadzone, the button legend, the model. `values` lets a caller that already
## knows this frame's pad values (a test, a replay) drive the SAME seam without touching the
## hardware — the frame the model sees is built in one place, `pad_frame()`, for both.
func poll_pad(values: Dictionary = {}) -> Dictionary:
	_ensure()
	var source := read_pad_values() if values.is_empty() else values
	return step_pad(pad_frame(source))


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
	return _nodes.get(menu.focus_id(), null)


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
	menu.nav.set_focus(menu.nav.focus_id())
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
