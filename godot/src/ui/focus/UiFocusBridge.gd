## UiFocusBridge.gd — the router's screens on the port's existing input model.
##
## THE BOUNDARY, STATED SO IT CAN BE CHECKED. Nothing here implements geometry, key
## repeat, deadzones or screen routing: those are `focus_nav.gd` (the focus model),
## `menu_nav.gd` (contexts, confirm, cancel, the declared-return rule), `osk.gd` (the
## keyboard model) and `ScreenRouter.gd` (the screens), all already audited. What the
## bridge adds is the one thing that did not exist:
##
##   ScreenShell's controls  --register-->  MenuFocus  (id, node, action, locked)
##   InputEventKey           --dispatch-->  MenuFocus.handle_key   (arrows, Enter, Esc)
##   InputEventJoypadButton  --dispatch-->  MenuNav.confirm()/back()  (ui_accept/ui_cancel)
##   InputEventJoypadMotion  --dispatch-->  MenuNav.keyboard_direction (the geometry move)
##   the model's verdict     --act-->       ScreenRouter.go_to(...)
##
## A locked control is registered, shown, reported (`locked_ids()`) and inert: the
## bridge does not re-decide that rule, because the model already has it
## (`focus_nav.gd::_selectable` refuses a `locked` target), and re-stating it would be
## the second focus model this ticket exists to avoid. It stays inert even when it takes
## the focus first and is locked afterwards, because `refresh()` pushes the live lock
## state and the model then refuses to land on it.
##
## The model's filtered list is the authority for "may the focus be here":
## `focus_nav.set_focus()` is permissive and returns whether the focus *changed*
## (`focus_nav.gd:140-144`), so `set_focus()` below asks `MenuFocus.focusable_ids()`
## first and answers "is the focus on this id now" — the question a caller has.
##
## NO DUPLICATE IDS. `MenuFocus.add()` appends (`game/menu_focus.gd:75`), so a bridge
## that re-registered an id would hand the model two targets with one id. The bridge
## keeps the single ordered registry and re-pushes it whole on every change, which is
## what makes `register()` idempotent.
##
## HANDLED MEANS HANDLED. `dispatch()` returns true exactly for the events the model
## owns, so the caller can mark them handled and stop Godot's built-in `ui_*` navigation
## from moving the same focus a second time — the contract `menu_focus.gd:157-160`
## already states for the menu scene.
##
## WHICH SHELL IS CURRENT IS NOT THIS FILE'S QUESTION. The bridge binds one shell; the
## mount scene (UIR-09) re-attaches it on `ScreenRouter.screen_changed`. It does not
## follow the router itself, because the router owns which screen is mounted.
extends RefCounted

const MenuFocus := preload("res://game/menu_focus.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")

## Emitted instead of navigating when no router is attached: the caller routes. With a
## router attached the bridge performs the navigation, which is the path the audit
## proves through the router's own `screen_changed` signal.
signal action_requested(action: String)
signal back_requested(screen_id: String)

## What an *event* means on the stick. The stored `gamepadDeadzone` pref's wiring into
## the UI layer belongs to the settings screen's ticket; this constant only decides when
## a motion event is a direction at all.
const STICK_THRESHOLD := 0.5
const CONFIRM_ACTION := "ui_accept"
const CANCEL_ACTION := "ui_cancel"

var _focus: MenuFocus
var _shell: Control
var _router: Variant = null
var _nav: MenuNav
var _registry: Array = []              ## [{id, node, action, opts}] in registration order
var _locked: Dictionary = {}           ## id -> true, for screens that render the lock
var _last: Dictionary = {}             ## the model's own last verdict
var _last_dispatch: Dictionary = {}    ## what the bridge did with it


## Binds one screen shell to one focus model. `router` is optional: with one, a back or
## activate decision is performed (`ScreenRouter.go_to`); without one it is only reported
## through the two signals above. Attaching also re-reads the shell's registered controls.
func attach(shell: Control, focus: MenuFocus, router: Variant = null) -> void:
	_shell = shell
	_focus = focus
	_router = router
	_registry.clear()
	_locked.clear()
	if _focus == null:
		return
	_nav = _focus.menu
	if _shell == null:
		return
	# The model speaks the reference's DOM anchor (`screen-modes`); the router and the
	# shell speak the short id (`modes`). The bridge translates once, here.
	var dom := NavRoutes.ROOT_SCREEN
	var screen := _shell_screen_id()
	if screen != "":
		var mapped := _dom_of(screen)
		if mapped != "":
			dom = mapped
	_nav.open_screen(dom)
	var controls: Array = []
	if _shell.has_method("focus_controls"):
		controls = _shell.focus_controls()
	for control in controls:
		if typeof(control) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = control
		register(_text(row.get("id")), row.get("node"), _text(row.get("action")), row.get("opts", {}))


## Registers one control into the bridge's registry and the model's. `opts` are the
## model's own names, passed through rather than reinterpreted: `kind`, `locked`,
## `disabled`, `contains_buttons` (`game/menu_focus.gd:60-77`).
func register(id: String, node: Control, action: String, opts: Dictionary = {}) -> void:
	if id == "" or node == null:
		return
	_drop(id)
	var copy: Dictionary = opts.duplicate()
	_registry.append({"id": id, "node": node, "action": action, "opts": copy})
	if bool(copy.get("locked", false)):
		_locked[id] = true
	_sync()


## The registered ids, in registration order.
func ids() -> Array:
	var out: Array = []
	for entry in _registry:
		out.append(String(entry["id"]))
	return out


## The registered ids this build or this career shows as locked.
func locked_ids() -> Array:
	var out: Array = []
	for id in ids():
		if _locked.has(id):
			out.append(id)
	return out


func has(id: String) -> bool:
	return ids().has(id)


## The shell this bridge is attached to (`null` before `attach`).
func shell() -> Control:
	return _shell


## The focus model this bridge drives.
func focus_model() -> MenuFocus:
	return _focus


## The model's own last verdict, untouched.
func last_result() -> Dictionary:
	return _last.duplicate()


## What the bridge did with the last dispatched event: `kind` is the model's verdict,
## `activated` says whether a control actually fired.
func last_dispatch() -> Dictionary:
	return _last_dispatch.duplicate()


func focus_id() -> String:
	if _focus == null:
		return ""
	return _focus.focus_id()


## Puts the focus on a registered id and answers "is the focus on it now": `false` for an
## id the bridge never registered, and for one the model will not land on (locked, hidden
## or disabled). The model's own selectable list is the authority, not the setter: 
## `focus_nav.set_focus()` accepts any id and reports whether the focus *changed*, so a
## locked target it was handed would still read as a success.
func set_focus(id: String) -> bool:
	if _focus == null or not has(id):
		return false
	_focus.refresh()
	if not _focus.focusable_ids().has(id):
		return false
	_focus.menu.nav.set_focus(id)
	return _focus.menu.nav.focus_id() == id


## One input event. Returns whether it was handled, in which case the caller must mark
## it handled so the engine's own `ui_*` navigation does not move the same focus again.
func dispatch(event: InputEvent) -> bool:
	if _focus == null or event == null:
		return false
	if event is InputEventKey:
		_last = _focus.handle_key(event as InputEventKey)
		if not bool(_last.get("handled", false)):
			_last_dispatch = {"kind": "unhandled", "activated": false}
			return false
		return _act(_last)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed:
			return false
		if button.is_action_pressed(CONFIRM_ACTION):
			return _act(_nav.confirm())
		if button.is_action_pressed(CANCEL_ACTION):
			return _act(_nav.back())
		return false
	if event is InputEventJoypadMotion:
		var direction := _stick_direction(event as InputEventJoypadMotion)
		if direction == "":
			return false
		return _act(_nav.keyboard_direction(direction))
	return false


# ---------------------------------------------------------------------------
# What the model's verdict means for the router
# ---------------------------------------------------------------------------

func _act(verdict: Dictionary) -> bool:
	var kind := _text(verdict.get("kind"))
	var target := _text(verdict.get("target"))
	match kind:
		"activate":
			var action := _text(verdict.get("action"))
			if action == "back":
				return _back(verdict)
			var screen := _screen_of_action(action)
			_last_dispatch = {
				"kind": "activate", "target": target, "action": action,
				"screen": screen, "activated": true,
			}
			if screen == "":
				action_requested.emit(action)
				return true
			return _route(screen, action)
		"back", "osk_close":
			if kind == "osk_close":
				_last_dispatch = {"kind": kind, "target": target, "activated": false}
				return true
			return _back(verdict)
		"osk_open":
			_last_dispatch = {"kind": "osk_open", "target": target, "activated": false}
			return true
		"overlay":
			# The overlay owns back while it is up (`menu_nav.gd:260-261`); the bridge
			# reports it and lets the mount scene pop it.
			_last_dispatch = {"kind": "overlay", "target": _text(verdict.get("context")), "activated": false}
			return true
		_:
			_last_dispatch = {"kind": kind, "target": target, "activated": false}
			return kind != "unhandled"


## The declared return: the shell's own target wins (`scripts/gamepad-nav-audit.mjs:67-82`
## — the screen's declaration beats any positional fallback), then the model's action.
## A screen that declares nothing has nowhere to go back to, and neither has the root
## (`menu_nav.gd:271-272`): both are refusals, not navigation.
func _back(verdict: Dictionary) -> bool:
	var target := _shell_back_target()
	if target == "":
		target = _screen_of_action(_text(verdict.get("action")))
	var here := _shell_screen_id()
	if target == "" or target == here:
		_last_dispatch = {"kind": "back", "target": target, "activated": false, "root": target == ""}
		back_requested.emit("")
		return true
	_last_dispatch = {"kind": "back", "target": target, "activated": true}
	return _route(target, "back")


func _route(screen_id: String, action: String) -> bool:
	if _router == null or not _router.has_method("go_to"):
		if screen_id == "":
			action_requested.emit(action)
		else:
			back_requested.emit(screen_id)
		return true
	_router.go_to(screen_id)
	return true


func _sync() -> void:
	if _focus == null:
		return
	_focus.clear()
	for entry in _registry:
		_focus.add(String(entry["id"]), entry["node"], String(entry["action"]), entry["opts"])
	_focus.refresh()


func _drop(id: String) -> void:
	var kept: Array = []
	for entry in _registry:
		if String(entry["id"]) != id:
			kept.append(entry)
	_registry = kept
	_locked.erase(id)


# ---------------------------------------------------------------------------
# Translation between the model's vocabulary and the router's
# ---------------------------------------------------------------------------

func _screen_of_action(action: String) -> String:
	if action == "":
		return ""
	var dom := NavRoutes.screen_of_action(action)
	if dom == "":
		return ""
	return _router_id_of(dom)


func _router_id_of(dom: String) -> String:
	if _router != null and _router.has_method("id_of_dom"):
		return _text(_router.id_of_dom(dom))
	return dom.trim_prefix("screen-")


func _dom_of(screen_id: String) -> String:
	if _router != null and _router.has_method("dom_id_of"):
		return _text(_router.dom_id_of(screen_id))
	return "screen-" + screen_id


func _shell_screen_id() -> String:
	if _shell == null:
		return ""
	# The shell carries its screen id as a property (`ScreenShell.screen_id`), while a
	# screen answers with a method of the same name (`ScreenContract.screen_id()`): the
	# bridge reads whichever the node in front of it has, and never assumes both.
	if _shell.has_method("screen_id"):
		return _text(_shell.screen_id())
	return _text(_shell.get("screen_id"))


func _shell_back_target() -> String:
	if _shell == null:
		return ""
	if _shell.has_method("back_target"):
		return _text(_shell.back_target())
	return ""


func _stick_direction(event: InputEventJoypadMotion) -> String:
	var value := event.axis_value
	if absf(value) < STICK_THRESHOLD:
		return ""
	match event.axis:
		JOY_AXIS_LEFT_X:
			return "right" if value > 0.0 else "left"
		JOY_AXIS_LEFT_Y:
			return "down" if value > 0.0 else "up"
	return ""


static func _text(value: Variant) -> String:
	return "" if value == null else str(value)
