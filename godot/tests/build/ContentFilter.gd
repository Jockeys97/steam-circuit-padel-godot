## ContentFilter.gd — the two answers the reference gives about demo content.
##
## `js/build.js` answers two separate questions and the port keeps both separate,
## because conflating them is a defect the reference already paid for
## (`js/build.js:63-75`: athletes and arenas used to disappear, and the demo
## contradicted itself — the objectives screen listed nine arenas and six
## athletes while the match fielded unplayable ones):
##
##   filter(items, allowed)   — what this build lists at all
##   is_locked(item, allowed) — whether a listed item is offered or shown locked
##
## "Show what is missing rather than hide it" is the rule; `is_locked` exists so
## a screen can render the exclusion without lying about the size of the game.
##
## The demo limit is a no-op in a full build: `filter` returns the list untouched
## (`js/build.js:59`) and `is_locked` returns false (`js/build.js:74`), so the
## full build exposes everything and the same code path serves both builds.
##
## Placement note: the ticket plans this at `res://src/build/ContentFilter.gd`;
## this slice's allowlist excludes `godot/src/**`, so it lives here and the
## relocation is a recorded request, not a change made to another lane's files.
extends RefCounted

const BuildFlag := preload("res://tests/build/BuildFlag.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const Frozen := preload("res://src/sim/frozen.gd")


## `demoFilter` (`js/build.js:58-61`). A no-op outside the demo — it is the
## build's answer, not the content's.
static func filter(items: Array, allowed: Array) -> Array:
	if not BuildFlag.is_demo():
		return items
	var kept: Array = []
	for item in items:
		if allowed.has(_id_of(item)):
			kept.append(item)
	return kept


## `demoLocked` (`js/build.js:73-75`). True only inside the demo, and only for
## something the demo does not grant: outside the demo it must stay silent or it
## would lock the full game.
static func is_locked(item: Variant, allowed: Array) -> bool:
	return BuildFlag.is_demo() and not allowed.has(_id_of(item))


## The roster this build exposes, sliced from the frozen tables (`frozen.gd`),
## which are a mechanical serialisation of `js/data.js` `ATHLETES`.
static func roster() -> Array:
	return filter(Frozen.athletes(), DemoContent.allowed_athlete_ids())


static func arenas() -> Array:
	return filter(Frozen.arenas(), DemoContent.allowed_arena_ids())


## Modes, as `{id}` dictionaries so one filter serves every content kind. The
## full set is the reference's own menu (`index.html`), not a list invented here.
static func modes() -> Array:
	return filter(_all_modes(), DemoContent.allowed_mode_ids())


static func mode_ids() -> Array:
	var ids: Array = []
	for mode in modes():
		ids.append(mode.get("id", ""))
	return ids


## The difficulty this build runs at. The reference fixes the demo's difficulty
## (`js/build.js:47`); a full build leaves the choice to the player, so the fixed
## value is only imposed when the demo flag is on.
static func difficulty() -> String:
	if BuildFlag.is_demo():
		return DemoContent.difficulty()
	return ""


## Everything the demo does not grant, in the order the frozen tables hold it —
## the list a screen renders locked.
static func locked_athletes() -> Array:
	var out: Array = []
	for athlete in Frozen.athletes():
		if is_locked(athlete, DemoContent.allowed_athlete_ids()):
			out.append(athlete)
	return out


static func locked_arenas() -> Array:
	var out: Array = []
	for arena in Frozen.arenas():
		if is_locked(arena, DemoContent.allowed_arena_ids()):
			out.append(arena)
	return out


static func locked_modes() -> Array:
	var out: Array = []
	for mode in _all_modes():
		if is_locked(mode, DemoContent.allowed_mode_ids()):
			out.append(mode)
	return out


static func _all_modes() -> Array:
	var out: Array = []
	for id in DemoContent.all_mode_ids():
		out.append({"id": id})
	return out


static func _id_of(item: Variant) -> String:
	if typeof(item) == TYPE_DICTIONARY:
		return str(item.get("id", ""))
	return ""
