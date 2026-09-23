## ScreenRouter.gd — the port's router: exactly the thirteen reference screens, one
## active at a time.
##
## WHAT IT REPLACES. The web build has no router class either: `showScreen(name)`
## (`js/ui.js:595-607`) toggles a class across the `screens` table
## (`js/ui.js:444-458`), which chooses between exactly thirteen `<section>`s. The
## port's `godot/game/main_menu.gd` and `godot/game/ModeScreen.tscn` mount their
## screens by hand. The recreation needs one place that owns "which screen is up",
## so thirteen screen tickets can land without editing each other's files.
##
## THE TABLE IS COMPARED, NOT SHARED. `godot/src/input/nav_routes.gd` is the
## reference's own inventory — generated from `index.html`/`js/ui.js` by
## `tools/input-port/nav-routes.mjs` and byte-verified by its `--verify` mode — and
## stays read-only. The thirteen ids, the DOM anchors and the declared back edges
## below are this router's own copy; `godot/tests/ui/router_audit.gd` cross-checks
## the two. That is the same shape the reference uses when
## `scripts/reachability-audit.mjs` compares the markup against `js/ui.js`'s
## registry: two copies that must agree, never one file that two lanes edit.
##
## FREEZE NOTE: after UIR-03 lands this file is frozen. Screens add themselves
## through `register()`; only the integration owner (UIR-22) or a
## coordinator-approved change edits this file.
##
## ON THE TYPE: the ticket's interface says "extends Node, added to a scene root by
## UIR-09". It extends `Control`, because the router owns a Control subtree
## (`ScreenHost`) that has to lay out inside the Control the mount scene provides
## (`godot/game/Main.tscn`'s root is a Control): a plain Node would anchor the host
## to the viewport, which has no size under `--headless` and would collapse every
## screen to its minimum size.
extends Control

const ScreenContract := preload("res://src/ui/screens/ScreenContract.gd")

## `screen_changed(from_id, to_id)`: the reference's own moment (`showScreen`),
## emitted after the swap. `from_id` is `""` on the first mount.
signal screen_changed(from_id: String, to_id: String)

## The root of the navigation, from `godot/src/input/nav_routes.gd::ROOT_SCREEN`.
const ROOT_ID := "menu"

## The thirteen screens in document order: the registry of `js/ui.js:444-458`, its
## markup anchors in `index.html`, the declared `data-back` return
## (`js/main.js:708-733`) and the `to-*` actions the screen's own markup carries.
##
##   id     the router id — `showScreen("menu")`, the registry's key
##   dom    the markup anchor (`index.html:31` …). Kept because the ported focus
##          model speaks DOM ids (`nav_routes.gd`) and this table is the only
##          bridge between the two spellings
##   back   the declared return as a router id; `""` where the reference declares
##          none (menu, game, result — `nav_routes.gd:82`)
##   to     the `to-*` actions in the screen's own markup, verbatim
const SCREENS: Array = [
	{"id": "menu", "dom": "screen-menu", "back": "", "to": ["to-challenges", "to-drill", "to-feedback", "to-help", "to-history", "to-modes", "to-profile", "to-settings"]},
	{"id": "characters", "dom": "screen-characters", "back": "modes", "to": ["to-modes"]},
	{"id": "modes", "dom": "screen-modes", "back": "menu", "to": ["to-menu"]},
	{"id": "arena", "dom": "screen-arena", "back": "characters", "to": ["to-characters"]},
	{"id": "help", "dom": "screen-help", "back": "menu", "to": ["to-menu"]},
	{"id": "history", "dom": "screen-history", "back": "menu", "to": ["to-menu"]},
	{"id": "challenges", "dom": "screen-challenges", "back": "menu", "to": ["to-menu"]},
	{"id": "profile", "dom": "screen-profile", "back": "menu", "to": ["to-menu"]},
	{"id": "feedback", "dom": "screen-feedback", "back": "menu", "to": ["to-menu"]},
	{"id": "drill", "dom": "screen-drill", "back": "menu", "to": ["to-menu"]},
	{"id": "settings", "dom": "screen-settings", "back": "menu", "to": ["to-menu"]},
	{"id": "game", "dom": "screen-game", "back": "", "to": []},
	{"id": "result", "dom": "screen-result", "back": "", "to": ["to-menu"]},
]

var _scenes: Dictionary = {}
var _host: Control
var _active_id: String = ""
var _active: Node = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host = Control.new()
	_host.name = "ScreenHost"
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)


# ---------------------------------------------------------------------------
# The table (static: a caller can ask about a screen before one is mounted)
# ---------------------------------------------------------------------------

static func ids() -> Array:
	var out: Array = []
	for row_in in SCREENS:
		out.append(String(row_in["id"]))
	return out


static func row(id: String) -> Dictionary:
	for row_in in SCREENS:
		if String(row_in["id"]) == id:
			return row_in
	return {}


static func has_id(id: String) -> bool:
	return not row(id).is_empty()


## The DOM anchor (`screen-modes`) for a router id, or `""`. UIR-05's focus bridge
## is the caller: `godot/src/input/**` speaks DOM ids and the router speaks
## registry ids.
static func dom_id_of(id: String) -> String:
	var found := row(id)
	return "" if found.is_empty() else String(found["dom"])


## The router id for a DOM anchor, or `""` (the inverse of `dom_id_of`).
static func id_of_dom(dom_id: String) -> String:
	for row_in in SCREENS:
		if String(row_in["dom"]) == dom_id:
			return String(row_in["id"])
	return ""


## The declared back target as a router id; `""` for the root, the field and the
## result — the reference's own three (`nav_routes.gd::BACKLESS_SCREENS`).
static func back_target_of(id: String) -> String:
	var found := row(id)
	return "" if found.is_empty() else String(found["back"])


## The `to-*` actions the screen's markup carries, verbatim from the reference.
static func to_actions_of(id: String) -> Array:
	var found := row(id)
	return [] if found.is_empty() else (found["to"] as Array).duplicate()


# ---------------------------------------------------------------------------
# Registration and mounting
# ---------------------------------------------------------------------------

## Registers the scene a screen id mounts. Refuses an id outside the table: the
## thirteen are the reference's, and a caller cannot widen them (`ScreenRouter`
## would otherwise become a second registry to keep in step with `js/ui.js`).
func register(id: String, scene: PackedScene) -> bool:
	if not has_id(id):
		push_error("ScreenRouter.register: '%s' is not one of the thirteen reference screens" % id)
		return false
	if scene == null:
		push_error("ScreenRouter.register: '%s' was handed a null scene" % id)
		return false
	_scenes[id] = scene
	return true


func registered_ids() -> Array:
	var out: Array = []
	for id in ids():
		if _scenes.has(id):
			out.append(id)
	return out


## `showScreen(name)` (`js/ui.js:595-607`). An id with no registered scene warns and
## leaves the player where they are — the reference's own behaviour, and the reason
## the port does not "helpfully" mount a blank placeholder: an empty page is the
## defect that fix closed.
##
## The payload a screen receives is the caller's dictionary plus the router's own
## facts (`router_id`, `back_target`); a caller's key of the same name wins, so the
## router never overwrites an argument a screen actually asked for.
func go_to(id: String, payload: Dictionary = {}) -> bool:
	if not _scenes.has(id):
		push_warning("ScreenRouter.go_to: screen \"%s\" is not registered; staying on \"%s\"" % [id, _active_id])
		return false
	var from_id := _active_id
	var previous := _active
	if previous != null:
		if previous.has_method("exit"):
			previous.exit()
		# Out of the tree first, then freed: "exactly one screen exists" is true
		# from this line on. `queue_free()` alone would leave the outgoing screen
		# mounted until the frame ends, which is precisely the moment a capture or
		# a focus walk would see two.
		_host.remove_child(previous)
		previous.queue_free()
		_active = null
		_active_id = ""
	var scene: PackedScene = _scenes[id]
	var node: Node = scene.instantiate()
	_host.add_child(node)
	_active = node
	_active_id = id
	var handed := payload.duplicate()
	if not handed.has("router_id"):
		handed["router_id"] = id
	if not handed.has("back_target"):
		handed["back_target"] = back_target_of(id)
	if node.has_method("enter"):
		node.enter(handed)
	_connect_shell_back_signals(node, id)
	screen_changed.emit(from_id, id)
	return true


## ScreenShell reports the target configured by its screen; transitions remain owned
## here alongside the keyboard/controller bridge. The source id prevents a queued
## signal from an outgoing screen from navigating after another screen was mounted.
func _connect_shell_back_signals(node: Node, source_id: String) -> void:
	if node.has_signal("back_requested"):
		var callback: Callable = _on_shell_back_requested.bind(source_id)
		if not node.is_connected("back_requested", callback):
			node.connect("back_requested", callback)
	for child in node.get_children():
		_connect_shell_back_signals(child, source_id)


func _on_shell_back_requested(target_id: String, source_id: String) -> void:
	if source_id != _active_id or target_id == "" or not _scenes.has(target_id):
		return
	go_to(target_id)


func active_id() -> String:
	return _active_id


func active_screen() -> Node:
	return _active


## The Control the screens are mounted under. UIR-09 parents this router into the
## game's scene root; UIR-24's capture harness asks for the host when it needs the
## live screen's rect.
func screen_host() -> Control:
	return _host


## How many nodes are mounted under the host. The router's own invariant is 1 after
## any successful `go_to`; the audit asserts it after every transition instead of
## trusting this comment.
func screen_count() -> int:
	return _host.get_child_count()
