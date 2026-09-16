## nav_routes.gd — the reference's screen and route inventory, as data the ported
## navigation audits assert over.
##
## This file is what the browser build's `index.html` gives the reference audits:
## `scripts/gamepad-nav-audit.mjs` reads the markup to learn which screens exist,
## which of them *declare* a return (`data-back`, `:73-80`), and which `to-*`
## actions each one carries; `scripts/reachability-audit.mjs` reads
## `js/main.js` / `js/ui.js` to learn which screens the code ever opens (`:68-97`)
## and cross-checks that list against the `screens` registry of `js/ui.js:444`.
## The port has no markup, so the same inventory is extracted from the reference
## and shipped here, with the source hashes it was extracted from.
##
## The block between the GENERATED markers is written by
## `tools/input-port/nav-routes.mjs`; the header is not. `--verify` re-extracts
## from the frozen reference and fails on a single byte of drift, which is the
## port's form of "the audit reads the source, not an import".
##
## This is NOT the game's router and must not become one: the router belongs to
## the HUD/menu slice (`godot/src/ui/**`), owns its own screen list, and this file
## is consumed by `godot/tests/input/reachability_audit.gd` as the reference's
## expectation — a second, independent copy exists so the two can be compared,
## exactly as the reference compares markup against the registry.
extends RefCounted

# --- BEGIN GENERATED (tools/input-port/nav-routes.mjs)
## Derived from the frozen reference (commit 2979588). Regenerate:
##   node tools/input-port/nav-routes.mjs
const ROUTE_PROVENANCE := {"index.html": {"sha256": "c1060116462db0b96efe40a235262f1a804588375081bfaeb50d43b24058c13b", "bytes": 49575}, "js/ui.js": {"sha256": "3f439f378ebe6ac0bc332de91df4e811df756e02bba502fc1946cff218829405", "bytes": 73322}, "js/main.js": {"sha256": "f4d24f7c0bad20971b70e31b86c2cd835b82bdc63134d5c2527109e3fdf25529", "bytes": 95899}}

## <section ... id="screen-X">, document order. `back` is the action on
## the button that declares `data-back`; null means the screen declares no
## return (the root and the field). `to` are the `to-*` actions in the
## screen's own markup.
const ROUTE_SCREENS := [
	{"id": "screen-menu", "back": null, "to": ["to-challenges", "to-drill", "to-feedback", "to-help", "to-history", "to-modes", "to-profile", "to-settings"]},
	{"id": "screen-characters", "back": "to-modes", "to": ["to-modes"]},
	{"id": "screen-modes", "back": "to-menu", "to": ["to-menu"]},
	{"id": "screen-arena", "back": "to-characters", "to": ["to-characters"]},
	{"id": "screen-help", "back": "to-menu", "to": ["to-menu"]},
	{"id": "screen-history", "back": "to-menu", "to": ["to-menu"]},
	{"id": "screen-challenges", "back": "to-menu", "to": ["to-menu"]},
	{"id": "screen-profile", "back": "to-menu", "to": ["to-menu"]},
	{"id": "screen-feedback", "back": "to-menu", "to": ["to-menu"]},
	{"id": "screen-drill", "back": "to-menu", "to": ["to-menu"]},
	{"id": "screen-settings", "back": "to-menu", "to": ["to-menu"]},
	{"id": "screen-game", "back": null, "to": []},
	{"id": "screen-result", "back": null, "to": ["to-menu"]},
]

## The `screens` registry of `js/ui.js:444-458`, sorted: the audit's
## cross-check between the markup and the router's own table.
const ROUTE_REGISTRY := ["arena", "challenges", "characters", "drill", "feedback", "game", "help", "history", "menu", "modes", "profile", "result", "settings"]

## Every `showScreen("X")` call site: screen, file, line, enclosing function.
const ROUTE_OPENERS := [
	{"screen": "screen-game", "file": "js/main.js", "line": 1156, "fn": "startMatch"},
	{"screen": "screen-menu", "file": "js/main.js", "line": 1556, "fn": "quitMatch"},
	{"screen": "screen-drill", "file": "js/main.js", "line": 1652, "fn": "startDrill"},
	{"screen": "screen-menu", "file": "js/main.js", "line": 2137, "fn": "(callback)"},
	{"screen": "screen-characters", "file": "js/main.js", "line": 2139, "fn": "(callback)"},
	{"screen": "screen-modes", "file": "js/main.js", "line": 2142, "fn": "(callback)"},
	{"screen": "screen-help", "file": "js/main.js", "line": 2144, "fn": "(callback)"},
	{"screen": "screen-history", "file": "js/main.js", "line": 2146, "fn": "(callback)"},
	{"screen": "screen-feedback", "file": "js/main.js", "line": 2150, "fn": "(callback)"},
	{"screen": "screen-challenges", "file": "js/main.js", "line": 2154, "fn": "(callback)"},
	{"screen": "screen-profile", "file": "js/main.js", "line": 2159, "fn": "(callback)"},
	{"screen": "screen-settings", "file": "js/main.js", "line": 2163, "fn": "(callback)"},
	{"screen": "screen-characters", "file": "js/main.js", "line": 2171, "fn": "(callback)"},
	{"screen": "screen-arena", "file": "js/main.js", "line": 2346, "fn": "(callback)"},
	{"screen": "screen-arena", "file": "js/main.js", "line": 2480, "fn": "(callback)"},
	{"screen": "screen-menu", "file": "js/main.js", "line": 2546, "fn": "(callback)"},
	{"screen": "screen-result", "file": "js/ui.js", "line": 1526, "fn": "unSetSolo"},
]
# --- END GENERATED

## The root of the navigation (`scripts/gamepad-nav-audit.mjs:67-77`): the menu
## declares no return, and "back" from here must lead nowhere.
const ROOT_SCREEN := "screen-menu"

## The root and the field: a screen here is *not* expected to declare a return
## (`scripts/gamepad-nav-audit.mjs:56`).
const BACKLESS_SCREENS := ["screen-menu", "screen-game", "screen-result"]

## The screen a `to-<name>` action opens: the reference's own naming convention
## (`to-modes` → `screen-modes`), used by the audit to check that every declared
## return leads to a screen that exists.
static func screen_of_action(action: String) -> String:
	if not action.begins_with("to-"):
		return ""
	return "screen-%s" % action.substr(3)


static func ids() -> Array:
	return ROUTE_SCREENS.map(func(row: Dictionary) -> String: return String(row["id"]))


static func row(screen_id: String) -> Dictionary:
	for row_in in ROUTE_SCREENS:
		if String(row_in["id"]) == screen_id:
			return row_in
	return {}


static func back_action(screen_id: String) -> String:
	var found := row(screen_id)
	return "" if found.is_empty() or found["back"] == null else String(found["back"])


## The screens some `showScreen("X")` call site opens, from `ROUTE_OPENERS`.
static func opened_screens() -> Array:
	var out: Array = []
	for opener in ROUTE_OPENERS:
		var screen_id := String(opener["screen"])
		if not out.has(screen_id):
			out.append(screen_id)
	return out


## Markup-edge reachability from the root: `to-<x>` inside a reachable screen
## opens `screen-<x>`. Code-origin edges carry no static origin — a `showScreen`
## inside a callback does not say which screen it was called from — so this is a
## lower bound, and the audit reports it rather than asserting it.
static func markup_reachable_from_root() -> Array:
	var edges := {}
	for row_in in ROUTE_SCREENS:
		var targets: Array = []
		for action in row_in["to"]:
			targets.append(screen_of_action(String(action)))
		edges[String(row_in["id"])] = targets
	var seen := {ROOT_SCREEN: true}
	var queue: Array = [ROOT_SCREEN]
	while not queue.is_empty():
		var at: String = queue.pop_front()
		for target in edges.get(at, []):
			if not edges.has(target) or seen.has(target):
				continue
			seen[target] = true
			queue.append(target)
	var out: Array = seen.keys()
	out.sort()
	return out
