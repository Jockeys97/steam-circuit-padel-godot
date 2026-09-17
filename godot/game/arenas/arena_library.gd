## arena_library.gd — the nine arenas of slice S6, as data plus one builder.
##
## THE API (this is what other code may call; nothing else in `game/arenas/` needs
## to be imported to use the library):
##
##     Arena.ids()                  -> the nine arena ids, in the frozen roster's
##                                     order (`js/data.js`'s `ARENAS`)
##     Arena.world_ids()            -> the five world arenas (port additions,
##                                     `family: "world"`, with no frozen row)
##     Arena.all_ids()              -> the frozen nine, then the world five
##     Arena.is_world(id)           -> is this id a world arena?
##     Arena.info(id)               -> everything known about one arena: its
##                                     frozen row (name, desc, image, wallBounce,
##                                     floorGrip, unlock, palette) plus the
##                                     presentation keys this slice adds (family,
##                                     glow, sky, artwork, props, backdrop band,
##                                     rear-glass alpha); for a world arena, its
##                                     deck name/desc, `palette` and its own
##                                     PROVISIONAL physics (marked `provisional`)
##                                     instead of a frozen row, and `world: true`
##     Arena.build(id, preset)      -> Node3D: a complete 3D court environment for
##                                     that arena, ready to `add_child()`. `null`
##                                     only if the id is not in the table.
##     Arena.build_into(p, id, pre) -> the same, added to `p` for you
##     Arena.rear_alpha(id)         -> the arena's rear-glass alpha (wallBounce-wired)
##     Arena.band(preset, z)        -> the scenery band the camera can see at z
##     Arena.default_id()           -> roster order 0, the slice's default arena
##
## FROZEN ROSTER vs WORLD SET. `ids()` is the frozen nine and stays exactly that:
## the world arenas are port additions with no row in `js/data.js`, so they can
## never appear in the roster's order, and no caller that means "the reference's
## arenas" ever gets one. They are buildable AND playable: `has()` accepts them,
## `build()` returns a full environment, and `world_info()` carries the documented
## provisional physics (`world_rows()`, and see the `WORLD_WALL_BOUNCE` block
## below) so a world arena can be selected and played — a later owner decision on
## tuning replaces those, not the frozen rows. Selection itself is not this
## library's job: `content_gate.gd::world_arenas()` and `match_config.gd`'s world
## seat are the seams the game reads.
##
## WHAT `build()` RETURNS. One `Node3D` named "Arena" holding:
##
##     WorldEnvironment, Sun, Fill      the environment and lights
##     Surround, Court, Line*, Service* the ground and the court surface
##     Net, NetPost*                    the net lattice
##     GlassFar, GlassFar2..6, ...      the glass cage (rear wall detailed)
##     AccentPostL/R, GearRing          the cage's outside dressing
##     Scenery/                         Backdrop, BackdropArtwork, BackdropVeil,
##                                      BackdropApron and one `Dressing_*` node
##                                      per scenery object
##
## The nine arenas all get the same court, net and cage geometry — the reference
## says so itself ("il campo e la cassa sono comuni", js/render.js:704) — and
## differ in: their own painted backdrop (gradient and, where the reference has
## one, its own artwork), their scenery objects, the ground colour from their own
## palette, the exterior tone beyond the cage, and the brightness of the glass
## (wired to `wallBounce`). `signature()` digests exactly that, and the slice test
## asserts the nine signatures are distinct and that every arena builds.
##
## NOTHING PHYSICAL LIVES HERE. The simulation's frozen values are read, never
## written: `wallBounce` and `floorGrip` enter colours and sizes only. Physics is
## `src/sim/`.
extends RefCounted

const Frozen := preload("res://src/sim/frozen.gd")
const Court := preload("res://game/court.gd")
const CourtBuilder := preload("res://game/arenas/court_builder.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")

## PROVISIONAL PHYSICS for the five world arenas. There is NO row for them in
## `js/data.js`, so no reference balance number exists and none is invented: both
## values below are the library's own documented NEUTRAL defaults, the same ones
## the frozen path already falls back to, and they are flagged `provisional` in
## `world_info()` so nobody mistakes them for tuning. They exist so a world arena
## is not merely buildable but PLAYABLE — `Sim.update_match` reads
## `state.arena["wallBounce"]` (sim.gd:2158) with no default of its own.
##
##   wallBounce 0.89 — `rear_alpha()` / `build()` / `court.gd` /
##                     `court_builder.gd`'s own fallback, identical to `officina`'s
##                     frozen row (the reference's first arena) and the exact
##                     midpoint of the frozen table's drift (0.83 .. 0.95).
##   floorGrip  1.00 — `officina`'s frozen value: the identity multiplier. No
##                     simulation code reads it (the reference itself never does;
##                     it reaches the menu's own tooltip line only).
##   unlock     none — the world set is ungated, which is what "no unlock row"
##                     means for `officina` in the frozen table too.
##
## Owner decision pending: replacing these two numbers is the only edit a
## re-tuning needs, and it belongs in `arena_style.gd`'s world entries (see that
## file's header), not here.
const WORLD_WALL_BOUNCE := 0.89
const WORLD_FLOOR_GRIP := 1.0


## The arena rows from the frozen data layer, in roster order.
static func rows() -> Array:
	return Frozen.arenas()


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for row in rows():
		out.append(String(row["id"]))
	return out


static func default_id() -> String:
	var list := ids()
	return String(list[0]) if list.size() > 0 else "officina"


static func has(id: String) -> bool:
	return ids().has(id) or ArenaStyle.is_world(id)


## The five world arenas, in `arena_style.gd`'s table order.
static func world_ids() -> PackedStringArray:
	return ArenaStyle.world_ids()


## Every arena this library can build: the frozen roster first, then the world set.
static func all_ids() -> PackedStringArray:
	var out := ids()
	out.append_array(world_ids())
	return out


static func is_world(id: String) -> bool:
	return ArenaStyle.is_world(id)


## The frozen row for an id, or an empty Dictionary when the id is unknown.
static func row(id: String) -> Dictionary:
	for r in rows():
		if String(r["id"]) == id:
			return r
	return {}


## Everything known about one arena: the frozen row first, then the presentation
## the library adds. A world arena has no frozen row, so `world_info()` answers for
## it. Any other unknown id falls back to the roster's first arena — the same rule
## `match_config.gd` uses for its index.
static func info(id: String) -> Dictionary:
	var r := row(id)
	if r.is_empty():
		if ArenaStyle.is_world(id):
			return world_info(id)
		r = row(default_id())
	var arena_id := String(r["id"])
	var style := ArenaStyle.style(arena_id)
	var arena := r.duplicate(true)
	arena["family"] = String(style.get("family", "open"))
	arena["glow"] = Color(String(style.get("glow", "#ffffff")))
	arena["sky"] = (style.get("sky", []) as Array).duplicate(true)
	arena["apron"] = Color(String(style.get("apron", "#303030")))
	arena["artwork"] = ArenaStyle.artwork_path(arena_id)
	arena["props"] = (style.get("props", []) as Array).duplicate(true)
	arena["prop_kinds"] = prop_kinds(arena_id)
	arena["rear_alpha"] = rear_alpha(arena_id)
	arena["backdrop_z"] = ArenaScenery.BACKDROP_Z
	return arena


## Everything known about one world arena: the deck's own name and description
## (`art/concepts/world-arenas-r1/`, transcribed in `arena_style.gd`) plus the
## same presentation keys `info()` adds for a frozen arena, plus the PROVISIONAL
## physics documented above `WORLD_WALL_BOUNCE`. `provisional: true` marks them
## as the neutral default rather than reference tuning: they exist so a selection
## can be PLAYED (the sim reads `wallBounce`, the menu tooltip reads `floorGrip`),
## and the owner replaces them when the tuning decision is made. `rear_alpha` uses
## the same neutral 0.89 the frozen path already falls back to for a missing value.
static func world_info(id: String) -> Dictionary:
	var style := ArenaStyle.style(id)
	return {
		"id": id,
		"name": String(style.get("name", id)),
		"desc": String(style.get("desc", "")),
		"image": "",
		"world": true,
		"family": String(style.get("family", "world")),
		"wallBounce": WORLD_WALL_BOUNCE,
		"floorGrip": WORLD_FLOOR_GRIP,
		"unlock": null,
		"provisional": true,
		"glow": Color(String(style.get("glow", "#ffffff"))),
		"sky": (style.get("sky", []) as Array).duplicate(true),
		"apron": Color(String(style.get("apron", "#303030"))),
		"palette": (style.get("palette", {}) as Dictionary).duplicate(true),
		"artwork": "",
		"props": (style.get("props", []) as Array).duplicate(true),
		"prop_kinds": prop_kinds(id),
		"rear_alpha": rear_alpha(id),
		"backdrop_z": ArenaScenery.BACKDROP_Z,
	}


## The five world arenas as `info()`-shaped records, in table order — what
## `content_gate.gd::world_arenas()` offers and what `match_config.gd` hands the
## match when a world seat is selected.
static func world_rows() -> Array:
	var out: Array = []
	for id in world_ids():
		out.append(world_info(String(id)))
	return out


static func signature(id: String) -> String:
	return ArenaStyle.signature(id)


## The scenery kinds this arena builds, in table order — the arena's own visual
## vocabulary, and what the slice test reads back off the built tree.
static func prop_kinds(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for prop in (ArenaStyle.style(id).get("props", []) as Array):
		out.append(String(prop.get("kind", "")))
	return out


## The arena's rear-glass alpha, wired to its `wallBounce` (a world arena's is the
## provisional neutral documented above `WORLD_WALL_BOUNCE`).
static func rear_alpha(id: String) -> float:
	var r := row(id)
	var bounce := float(r.get("wallBounce", 0.89))
	return CourtBuilder.rear_alpha(bounce)


## The band of the frame the scenery can occupy for a camera preset at world z.
static func band(preset: String, z: float) -> Dictionary:
	return ArenaScenery.band(preset, z)


## A complete 3D environment for one arena. Returns null for an unknown id: a
## missing arena is a caller bug, not something to paper over with a default.
##
## The environment is identical for both kinds — court, net and cage are common to
## every arena — and the arena's own values only ever enter colours, sizes and the
## glass alpha. A world arena gets no `wallBounce` from anywhere but the library's
## documented neutral default, and is marked `world` in its meta so a caller can
## tell it apart from a frozen one.
static func build(id: String, preset := "default") -> Node3D:
	if not has(id):
		push_error("arena_library: unknown arena id '%s' (have: %s)" % [id, ", ".join(all_ids())])
		return null
	var arena := info(id)
	var root := Node3D.new()
	root.name = "Arena"
	root.set_meta("arena_id", id)
	root.set_meta("family", String(arena["family"]))
	root.set_meta("world", is_world(id))
	root.set_meta("wallBounce", float(arena.get("wallBounce", 0.89)))
	CourtBuilder.build_world(root, arena)
	CourtBuilder.build_court(root, arena, float(arena.get("wallBounce", 0.89)))
	ArenaScenery.build(root, id, arena, preset)
	return root


static func build_into(parent: Node3D, id: String, preset := "default") -> Node3D:
	var root := build(id, preset)
	if root == null:
		return null
	parent.add_child(root)
	return root
