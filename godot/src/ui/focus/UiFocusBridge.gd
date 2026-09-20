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
##
## CARRIED METADATA (the range/OSK seam, added 2026-09-17 by the wave-3 shared contract).
## Two producers-of-record in the input lane read target fields the focus model does not
## carry, and both files belong to that lane:
##
##   - `focus_nav.gd::_adjust_range` (:239-246) steps a `kind:"range"` target from
##     `step`, `value`, `min` and `max` — the settings screen's volume/deadzone rows;
##   - `menu_nav.gd::confirm()` (:223-229) opens the OSK from `value`, `max_length` and
##     `field_label` — the feedback screen's message/contact fields.
##
## `game/menu_focus.gd::_target()` (:111-125) projects a fixed set of keys, so those
## fields never reach the model. Rather than editing either lane, the bridge carries
## them: a screen registers them with its control (through `ScreenShell.add_focus`'s
## `opts`, read by `register()`), the bridge keeps the copy that matters and merges it
## onto the focused live target immediately before the input lane consumes it
## (`carry_metadata()`, called at the top of `dispatch()`). The keys are the input lane's
## own documented descriptor fields (`focus_nav.gd:44-57`); nothing is invented here and
## nothing is re-derived.
extends RefCounted

## Emitted instead of navigating when no router is attached: the caller routes. With a
## router attached the bridge performs the navigation, which is the path the audit
## proves through the router's own `screen_changed` signal.
signal action_requested(action: String)
signal back_requested(screen_id: String)

## Emitted after a dispatch that stepped the focused range, with the model's own new
## value (`focus_nav.gd:246` writes it into the live target). Applying it to the real
## control — a Slider — and persisting it is the screen's job: the input lane never
## touches nodes, and neither does the bridge.
signal range_changed(id: String, value: float)

const MenuFocus := preload("res://game/menu_focus.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")

## What an *event* means on the stick. The stored `gamepadDeadzone` pref's wiring into
## the UI layer belongs to the settings screen's ticket; this constant only decides when
## a motion event is a direction at all.
const STICK_THRESHOLD := 0.5
const CONFIRM_ACTION := "ui_accept"
const CANCEL_ACTION := "ui_cancel"

## The target-descriptor keys the input lane reads but the focus model does not carry
## (see the header): the range keys `focus_nav.gd::_adjust_range` steps from, and the
## OSK keys `menu_nav.gd::confirm()` opens with. A registration's own `opts` supply them
## — the same dictionary that already supplies `kind` and `locked`.
const CARRIED_KEYS := ["min", "max", "step", "value", "max_length", "field_label", "input_type"]

var _focus: MenuFocus
var _shell: Control
var _router: Variant = null
var _nav: MenuNav
var _registry: Array = []              ## [{id, node, action, opts}] in registration order
var _locked: Dictionary = {}           ## id -> true, for screens that render the lock
var _last: Dictionary = {}             ## the model's own last verdict
var _last_dispatch: Dictionary = {}    ## what the bridge did with it
var _last_range: Dictionary = {}       ## {id, value} of the last range step reported
var _range_values: Dictionary = {}     ## id -> the value the bridge last noted for a range
var _last_osk: Dictionary = {}         ## the OSK model's state after the last open/close


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
	_rebind()


## Re-reads the shell's controls into the registry. `attach()` and the staleness check
## below are the only callers: the registry is the bridge's own single ordered list, so
## it is rebuilt whole rather than patched.
func _rebind() -> void:
	var controls: Array = []
	if _shell.has_method("focus_controls"):
		controls = _shell.focus_controls()
	for control in controls:
		if typeof(control) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = control
		register(_text(row.get("id")), row.get("node"), _text(row.get("action")), row.get("opts", {}))


## Re-reads the shell's controls when the ones the registry holds have been rebuilt.
##
## A screen's own view change — the character panel's athlete picker and wardrobe — frees
## and re-creates every control inside the same mounted screen, so no `screen_changed`
## fires and `attach()` never runs again. The registry kept the freed nodes, the model's
## `focus_node()` handed one back, and `apply_focus()` died on a freed instance while the
## player's focus sat on the athlete panel's own subview. The reference has no such
## moment to miss: `collectMenuTargets` re-queries the DOM on every frame
## (`js/main.js:596`), so the port's registry has to follow its shell the same way.
##
## Cheap enough for the frame loop: one validity test per registered control, no
## allocation, and a rebind only when something was actually rebuilt.
func refresh_if_rebuilt() -> bool:
	if _shell == null or _focus == null:
		return false
	for entry in _registry:
		var node: Variant = entry["node"]
		if node == null or not is_instance_valid(node):
			_registry.clear()
			_locked.clear()
			_rebind()
			return true
	return false


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
	# The model's live list is fresh from `_sync()`; the carried keys follow it.
	carry_metadata()


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


## The carried keys (`CARRIED_KEYS`) one registered control supplies, in that order.
## `{}` for an id the bridge never registered and for a control that supplies none.
func metadata_of(id: String) -> Dictionary:
	for entry in _registry:
		if String(entry["id"]) == id:
			return _carried(entry["opts"])
	return {}


## The carried keys the model's focused target holds — the merge is applied first, so the
## answer is exactly what the input lane will read at the next consumption, `{}` when the
## focused control carries none. (A context change made by the input lane itself — the OSK
## open/close, an overlay — rebuilds the live list; this call re-merges it, which is why
## it is asked of the bridge rather than of a stale target.)
func focused_metadata() -> Dictionary:
	if _nav == null:
		return {}
	carry_metadata()
	return _carried(_nav.nav.focus())


## The last range step the bridge reported: `{id, value}`. `{}` before any step.
func last_range() -> Dictionary:
	return _last_range.duplicate()


## The OSK model's state after the last open or close —
## `{id, open, value, max_length, label}`; `{}` before any. The screen reads it and
## pushes the value onto its own text control: the input lane never touches nodes, and
## neither does the bridge.
func last_osk() -> Dictionary:
	return _last_osk.duplicate()


## Merges every registered control's carried keys onto the model's live targets and
## returns how many targets took metadata. Called after every registry change (`_sync`)
## and at the top of every `dispatch()`: a context change (`open_screen`, an overlay, the
## OSK) rebuilds the model's live list, so the merge follows it instead of being a
## one-off write. The model's own selectable targets are the only ones reached — a hidden
## control cannot take the focus, so nothing is lost where it is consumed.
func carry_metadata() -> int:
	if _nav == null or _nav.nav == null:
		return 0
	var merged := 0
	for target in _nav.nav.targets():
		var meta := metadata_of(String(target["id"]))
		if meta.is_empty():
			continue
		for key in meta:
			target[key] = meta[key]
		merged += 1
	return merged


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
	carry_metadata()
	return _focus.menu.nav.focus_id() == id


## One input event. Returns whether it was handled, in which case the caller must mark
## it handled so the engine's own `ui_*` navigation does not move the same focus again.
func dispatch(event: InputEvent) -> bool:
	if _focus == null or event == null:
		return false
	# The input lane reads the carried keys off the focused target at the moment it is
	# consumed (`menu_nav.gd:223-229`, `focus_nav.gd:239-246`); the merge is re-run here
	# rather than once, because a context change rebuilds the live list.
	carry_metadata()
	if event is InputEventKey:
		_last = _focus.handle_key(event as InputEventKey)
		if not bool(_last.get("handled", false)):
			_last_dispatch = {"kind": "unhandled", "activated": false}
			return false
		var handled := _act(_last)
		_note_range_step()
		return handled
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
		var moved := _act(_nav.keyboard_direction(direction))
		_note_range_step()
		return moved
	return false


## One already-resolved verdict from the pad poll (`MenuFocus.poll_pad()`), applied
## exactly the way an event's verdict is. The mount polls the pad once per frame —
## the reference polls its gamepad in the render loop (`js/main.js:1001-1004`) — and a
## polled confirm/back is the same decision as the event's, so it must not go through
## a second translation.
func act(verdict: Dictionary) -> bool:
	if _focus == null or verdict.is_empty():
		return false
	_last = verdict
	carry_metadata()
	_note_range_step()
	return _act(verdict)


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
				_note_osk_state(target)
				return true
			return _back(verdict)
		"osk_open":
			_last_dispatch = {"kind": "osk_open", "target": target, "activated": false}
			_note_osk_state(target)
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
# The carried metadata
# ---------------------------------------------------------------------------

## One registration's carried keys, in `CARRIED_KEYS` order.
func _carried(opts: Dictionary) -> Dictionary:
	var out := {}
	for key in CARRIED_KEYS:
		if opts.has(key):
			out[key] = opts[key]
	return out


## Writes one carried key back into the registry, so the next merge follows the value
## the model last produced (a stepped range) instead of undoing it.
func _set_carried(id: String, key: String, value: Variant) -> void:
	for entry in _registry:
		if String(entry["id"]) == id:
			(entry["opts"] as Dictionary)[key] = value
			return


## The model stepped a range in place and wrote the new value into the live target
## (`focus_nav.gd:239-246`). Reported once per change, and mirrored into the registry so
## the next merge continues from it; applying it to the Slider and persisting it belongs
## to the screen, which hears `range_changed`.
func _note_range_step() -> void:
	if _nav == null:
		return
	var target := _nav.nav.focus()
	if String(target.get("kind", "")) != "range":
		return
	var id := String(target["id"])
	var value := float(target.get("value", 0.0))
	if _range_values.has(id) and is_equal_approx(value, float(_range_values[id])):
		return
	_range_values[id] = value
	_last_range = {"id": id, "value": value}
	_set_carried(id, "value", value)
	range_changed.emit(id, value)


## The OSK model's own state (`menu_nav.gd:69` exposes it), read after an open or a
## close so the screen can push the seeded/typed value onto its text control.
func _note_osk_state(field_id: String) -> void:
	if _nav == null or _nav.osk == null:
		return
	_last_osk = {
		"id": field_id,
		"open": _nav.osk.is_open(),
		"value": _nav.osk.value(),
		"max_length": _nav.osk.max_length(),
		"label": _nav.osk.label(),
	}


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
