## arena_library.gd — the nine arenas of slice S6, as data plus one builder.
##
## THE API (this is what other code may call; nothing else in `game/arenas/` needs
## to be imported to use the library):
##
##     Arena.ids()                  -> the nine arena ids, in the frozen roster's
##                                     order (`js/data.js`'s `ARENAS`)
##     Arena.info(id)               -> everything known about one arena: its
##                                     frozen row (name, desc, image, wallBounce,
##                                     floorGrip, unlock, palette) plus the
##                                     presentation keys this slice adds (family,
##                                     glow, sky, artwork, props, backdrop band,
##                                     rear-glass alpha)
##     Arena.build(id, preset)      -> Node3D: a complete 3D court environment for
##                                     that arena, ready to `add_child()`. `null`
##                                     only if the id is not in the table.
##     Arena.build_into(p, id, pre) -> the same, added to `p` for you
##     Arena.rear_alpha(id)         -> the arena's rear-glass alpha (wallBounce-wired)
##     Arena.band(preset, z)        -> the scenery band the camera can see at z
##     Arena.default_id()           -> roster order 0, the slice's default arena
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
	return ids().has(id)


## The frozen row for an id, or an empty Dictionary when the id is unknown.
static func row(id: String) -> Dictionary:
	for r in rows():
		if String(r["id"]) == id:
			return r
	return {}


## Everything known about one arena: the frozen row first, then the presentation
## the library adds. Unknown ids fall back to the roster's first arena, which is
## the same rule `match_config.gd` uses for its index.
static func info(id: String) -> Dictionary:
	var r := row(id)
	if r.is_empty():
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


static func signature(id: String) -> String:
	return ArenaStyle.signature(id)


## The scenery kinds this arena builds, in table order — the arena's own visual
## vocabulary, and what the slice test reads back off the built tree.
static func prop_kinds(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for prop in (ArenaStyle.style(id).get("props", []) as Array):
		out.append(String(prop.get("kind", "")))
	return out


## The arena's rear-glass alpha, wired to its frozen `wallBounce`.
static func rear_alpha(id: String) -> float:
	var r := row(id)
	var bounce := float(r.get("wallBounce", 0.89))
	return CourtBuilder.rear_alpha(bounce)


## The band of the frame the scenery can occupy for a camera preset at world z.
static func band(preset: String, z: float) -> Dictionary:
	return ArenaScenery.band(preset, z)


## A complete 3D environment for one arena. Returns null for an unknown id: a
## missing arena is a caller bug, not something to paper over with a default.
static func build(id: String, preset := "default") -> Node3D:
	if not has(id):
		push_error("arena_library: unknown arena id '%s' (have: %s)" % [id, ", ".join(ids())])
		return null
	var arena := info(id)
	var root := Node3D.new()
	root.name = "Arena"
	root.set_meta("arena_id", id)
	root.set_meta("family", String(arena["family"]))
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
