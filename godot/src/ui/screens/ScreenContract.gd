## ScreenContract.gd — the base class every router screen extends.
##
## THE CONTRACT, TAKEN FROM THE REFERENCE. The web build keeps exactly one screen
## active at a time: `showScreen(name)` (`js/ui.js:595-607`) toggles
## `screen--active` across the `screens` table (`js/ui.js:444-458`) and, for a name
## that is not registered, warns and stays where it is — the reference's own fix
## for a blank page: "un nome non registrato spegneva tutte le schermate senza
## accenderne nessuna: pagina bianca, nessun errore, e nulla che dicesse dove
## guardare" (`js/ui.js:596-598`). The port keeps that behaviour in exactly one
## place, `godot/src/ui/ScreenRouter.gd`; this class is what a screen declares TO
## it.
##
## A screen declares, it does not navigate:
##
##   screen_id()                  the router id (`menu`, `characters`, …) — the
##                                registry key, never the `screen-` DOM anchor
##   back_target()                the declared return as a router id, `""` where
##                                the reference declares none (menu, game, result:
##                                `godot/src/input/nav_routes.gd::BACKLESS_SCREENS`)
##   enter(payload)               the router moved here; the payload carries the
##                                router's own facts (see `ScreenRouter.go_to`)
##   exit()                       the router is about to drop this screen
##   capture_states()             the states UIR-24's capture harness may ask for;
##                                `["default"]` until a screen ticket declares more
##   apply_capture_state(state_id) -> bool
##                                true when the state was applied; the default
##                                refuses, so a harness can tell "not declared"
##                                from "applied" instead of guessing
##
## Nothing here paints and nothing here decides where the player goes next: that is
## the router's (and, for the reference's declared-back rule, `MenuNav`'s, which
## UIR-05's bridge drives).
extends Control


## The router id of this screen. Abstract: every concrete screen overrides it, and
## the base says so out loud instead of answering with an empty string a router
## could mistake for a name.
func screen_id() -> String:
	push_error("ScreenContract.screen_id() is abstract — %s must implement it" % _script_path())
	return ""


## The declared back target, as a router id. `""` means the reference declares no
## return from here (the root, the field, the result — `nav_routes.gd:82`).
func back_target() -> String:
	return ""


## The router was moved here. `payload` is the router's own dictionary: it carries
## `router_id` and `back_target` for this screen, plus whatever the caller asked
## for. Screens read it in `_ready()`-safe ways only; the router mounts first.
func enter(_payload: Dictionary) -> void:
	pass


## The router is about to drop this screen (its node is removed from the tree and
## freed). Anything holding a reference should let go here.
func exit() -> void:
	pass


## The capture states UIR-24 may ask this screen for. A screen that declares more
## states overrides this; the default is the one every screen has.
func capture_states() -> Array[String]:
	return ["default"]


## Applies one capture state. The default returns false — "this screen declares no
## such state" — which the harness records rather than treating as a success.
func apply_capture_state(_state_id: String) -> bool:
	return false


func _script_path() -> String:
	var script: Script = get_script()
	return script.resource_path if script != null else "<script-less>"
