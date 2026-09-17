## arena_catalog.gd — the one arena catalog: the nine frozen arenas and the five
## world arenas, with the display and availability facts BOTH UI paths read.
##
## WHY THIS FILE EXISTS. The port grew two arena UI paths (the ported menu column in
## `game/main_menu.gd`, the recreated arena screen in `src/ui/screens/ArenaScreen.gd`)
## and the arena questions were answered in four places: the display rows were built
## in `src/ui/data/UiData.gd`, the frozen index was re-derived in `ArenaScreen.gd` and
## in `match_config.gd`, the frozen-vs-world seat rule was re-decided in
## `match_config.gd::set_arena_id`, and the world set was offered by
## `content_gate.gd::world_arenas()`. The world five were therefore reachable in the
## ported column and NOT in the recreated screen — recorded as a gap in
## `docs/mission/world-arenas/integrator.md` §9.1. This module is that one owner.
##
## WHAT IT OWNS (one answer each, for both paths)
##
##     ids() / world_ids() / all_ids()   the three lists, in the tables' own order
##     is_world(id)                      is this a world arena (a port addition)
##     index_of(id)                      the frozen roster index, or -1
##     frozen_rows(career)               the nine display rows, with both walls
##     world_rows()                      the world display rows THIS BUILD offers
##     rows(career)                      frozen then world: the whole catalog
##     seat(id)                          what selecting this id means:
##                                       {index, world, offered}
##
## WHAT IT DOES NOT OWN, and must not: the build's own content rule. `demo` and the
## exposed frozen rows are handed in by `content_gate.gd`, which is the only place in
## `game/**` that knows where the export lane's tables live (`js/build.js` ported into
## `tests/build/`). The career wall is `CareerRules.is_unlocked`, read here, never
## re-derived. Nothing physical lives here either: `wallBounce`/`floorGrip` are read
## from the arena library, never written (`src/sim/` owns the simulation).
##
## WORLD ARENAS. The five port additions have no row in `js/data.js`, so they can
## never appear in the frozen roster's order, and they do not exist in a DEMO build —
## the reference's own `DEMO_CONTENT` cannot list an addition, which is exactly how
## the frozen nine's demo subset stays unchanged. Their display facts (name, desc) are
## the deck's own text from `game/arenas/arena_style.gd`: a port addition has no
## locale key, so a screen shows the row (never a literal in code).
extends RefCounted

const Arena := preload("res://game/arenas/arena_library.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Art := preload("res://src/ui/data/UiArtPaths.gd")

## The build's own answers, handed in by `content_gate.gd::arena_catalog()`.
var _demo := false
var _exposed: Array = []


func _init(demo: bool, exposed: Array) -> void:
	_demo = demo
	_exposed = exposed


## The frozen arena rows this build lists as a choice (`content_gate.gd::arenas()`).
func exposed_ids() -> Array:
	var out: Array = []
	for row in _exposed:
		out.append(String((row as Dictionary).get("id", "")))
	return out


func ids() -> PackedStringArray:
	return Arena.ids()


func world_ids() -> PackedStringArray:
	return Arena.world_ids()


func all_ids() -> PackedStringArray:
	return Arena.all_ids()


func is_world(id: String) -> bool:
	return Arena.is_world(id)


## The frozen roster index of an id, or -1. One answer, so `match_config.gd` and
## `src/ui/screens/ArenaScreen.gd` stop each carrying their own copy.
func index_of(id: String) -> int:
	var list := Arena.ids()
	for i in list.size():
		if String(list[i]) == id:
			return i
	return -1


## The nine frozen display rows for this build: the arena's own locale keys and art,
## the build's wall (`demo_locked` in a demo, exactly what `js/build.js:73` locks)
## and the career's (`CareerRules.is_unlocked`). `selectable` is the build's half
## alone — the reference asks the two questions separately (`js/ui.js:485-487`).
func frozen_rows(career: Dictionary) -> Array:
	var exposed := exposed_ids()
	var out: Array = []
	for arena in Frozen.arenas():
		var row: Dictionary = arena
		var id := String(row.get("id", ""))
		var listed := exposed.has(id)
		var demo_locked := _demo and not listed
		out.append({
			"id": id,
			"name_key": "arena_%s_name" % id,
			"desc_key": "arena_%s_desc" % id,
			"art_path": Art.path_for("arenas", id),
			"demo_locked": demo_locked,
			"locked": demo_locked or not CareerRules.is_unlocked(row, career),
			"selectable": listed,
		})
	return out


## The world display rows this build offers: the five in a full build, NONE in a
## demo (the set does not exist there — see this file's header). The rows carry the
## deck's own name, desc and palette, plus the PROVISIONAL physics the match needs
## (`arena_library.gd::world_info()`), which is the same row the ported column reads.
func world_rows() -> Array:
	if _demo:
		return []
	return Arena.world_rows()


## Every display row this build lists: the frozen nine, then the world set.
func rows(career: Dictionary) -> Array:
	var out: Array = frozen_rows(career)
	out.append_array(world_rows())
	return out


## What selecting this id means, for both paths and both seats:
##
##     index     the frozen roster index, or -1 when the id is not a frozen arena
##     world     is this a world arena (its seat is the id itself)
##     offered   does THIS BUILD offer it as a choice
##
## A frozen id keeps `match_config.gd`'s own rule (any frozen id has a seat — a demo
## simply never offers one it withholds, which `offered` reports); a world id is
## offered only by a full build.
func seat(id: String) -> Dictionary:
	var index := index_of(id)
	if index >= 0:
		return {"index": index, "world": false, "offered": exposed_ids().has(id)}
	if is_world(id):
		return {"index": -1, "world": true, "offered": not _demo}
	return {"index": -1, "world": false, "offered": false}
