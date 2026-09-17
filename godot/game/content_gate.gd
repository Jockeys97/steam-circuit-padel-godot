## content_gate.gd — the seam `godot/game/**` asks about the build's content rule.
##
## WHY THIS FILE EXISTS. `docs/wayfinder/evidence/demo-and-export.md` §6 names the
## defect this closes: the demo rule was enforced in the data layer and proved on
## the artifact (`DemoSelfReport`, `PASS 18/18`, inside the exported binary), but no
## screen asked it. `godot/game/main_menu.gd` enumerated `Config.athletes()` /
## `Config.arenas()` straight from the frozen tables, so the packaged demo listed six
## athletes and nine arenas on screen while its own filter answered two and one.
## Two captures, byte-identical, is what exposed it.
##
## The rule is not restated here and not re-derived: it is the reference's own
## `js/build.js` (`IS_DEMO`, `DEMO_CONTENT`, `demoFilter`, `demoLocked`), ported by
## the export lane into `godot/tests/build/` — `BuildFlag.gd` (the one flag),
## `DemoContent.gd` (the generated table) and `ContentFilter.gd` (the two answers).
## This file is only the seam the screens call, so there is exactly one place in
## `godot/game/**` that knows where those modules live. If they move to
## `res://src/build/` (the placement the export lane requested), this is the only
## file that changes.
##
## The reference answers TWO questions and the port keeps them apart:
##   `roster()` / `arenas()` — what this build lists as a choice (a no-op in a full
##                             build, `js/build.js:58`);
##   `is_locked(item)`       — a listed item this build does not grant, which a
##                             screen renders locked instead of hiding
##                             ("vedere cosa manca vende più che nasconderlo",
##                             `js/ui.js:734`).
extends RefCounted

const BuildFlag := preload("res://tests/build/BuildFlag.gd")
const ContentFilter := preload("res://tests/build/ContentFilter.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Arena := preload("res://game/arenas/arena_library.gd")

## The reference's four difficulty rungs ARE this port's four AI tiers
## (`js/ui.js:1531`: `{easy:0, medium:1, hard:2, legend:3}[difficulty]`), so the
## demo's declared fixed `"medium"` is tier index 1. A table, not arithmetic: the
## mapping is the reference's own and a re-ordering must be visible here.
const DIFFICULTY_TIERS := {"easy": 0, "medium": 1, "hard": 2, "legend": 3}


static func is_demo() -> bool:
	return BuildFlag.is_demo()


static func label() -> String:
	return BuildFlag.label()


## The athletes this build offers as a choice — the full roster in a full build.
static func roster() -> Array:
	return ContentFilter.roster()


## The arenas this build offers as a choice.
static func arenas() -> Array:
	return ContentFilter.arenas()


## The five world arenas (port additions, `arena_library.gd::world_rows()`): a
## FULL build offers them as a further choice; a DEMO build offers none of them.
## The demo's content rule is the reference's own table (`js/build.js`
## `DEMO_CONTENT`), which cannot list port additions — preserving the demo means
## the world set simply does not exist there, exactly as the frozen nine's demo
## subset is unchanged. This is the gate seam only: `Config.selectable_arenas()`
## stays the frozen roster's list (the slice pins its counts), and
## `Config.selectable_world_arenas()` is where this answer reaches the selection.
static func world_arenas() -> Array:
	if is_demo():
		return []
	return Arena.world_rows()


## `demoLocked` (`js/build.js:73`): true only in the demo, and only for something
## the demo does not grant. `kind` is "athlete" or "arena".
static func is_locked(item: Variant, kind: String) -> bool:
	if not is_demo():
		return false
	var allowed: Array = []
	if kind == "athlete":
		allowed = ContentFilter.roster()
	else:
		allowed = ContentFilter.arenas()
	for candidate in allowed:
		if String((candidate as Dictionary)["id"]) == _id_of(item):
			return false
	return true


## The modes this build offers: `["quick"]` in the demo, all three in the full
## build (`js/ui.js:737-750` renders the others locked rather than removing them).
static func modes() -> Array:
	return ContentFilter.mode_ids()


## `demoLockedMode` (`js/i18n.js:147,839`) is the reference's own tag for something
## the build does not grant: "Nella versione completa" / "In the full game". The
## menu renders it; it does not invent a sentence.
static func locked_key() -> String:
	return "demoLockedMode"


## The tier index the demo pins the difficulty to, or -1 in a full build.
static func fixed_tier_index() -> int:
	return int(DIFFICULTY_TIERS.get(ContentFilter.difficulty(), -1))


## Every athlete the frozen roster holds that this build does not grant — the list
## a screen shows locked. Report-only: the menu lists the exposed set.
static func locked_athletes() -> Array:
	return ContentFilter.locked_athletes()


static func locked_arenas() -> Array:
	return ContentFilter.locked_arenas()


## The frozen-roster index of the first exposed athlete/arena: where a demo must
## start, since roster order 0 need not be exposed (`officina` is, but nothing
## guarantees it). `-1` only if the exposed list is empty, which cannot happen —
## `DemoContent` carries at least one of each and the full build carries all.
static func first_exposed_athlete_index() -> int:
	return _index_of(roster(), Frozen.athletes())


static func first_exposed_arena_index() -> int:
	return _index_of(arenas(), Frozen.arenas())


static func _index_of(exposed: Array, full: Array) -> int:
	if exposed.is_empty():
		return -1
	var wanted := _id_of(exposed[0])
	for i in full.size():
		if String((full[i] as Dictionary)["id"]) == wanted:
			return i
	return -1


static func index_in(full: Array, item: Variant) -> int:
	var wanted := _id_of(item)
	for i in full.size():
		if String((full[i] as Dictionary)["id"]) == wanted:
			return i
	return -1


static func _id_of(item: Variant) -> String:
	if typeof(item) != TYPE_DICTIONARY:
		return ""
	return String((item as Dictionary).get("id", ""))
