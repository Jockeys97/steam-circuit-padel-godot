## arena_scenery.gd — every arena's own backdrop and scenery objects.
##
## THE BAND. The reference keeps scenery out of the playable trapezoid with
## `clipArenaScenery` (`js/render.js:481-499`): positive safe zones only — the
## upper proscenium (`ctx.rect(0, 0, 960, 96)`, i.e. the band above the rear
## glass) and the two wedges outside the glass cage. Arena scenery lives there and
## nowhere else; the audit `scripts/arena-scenery-audit.mjs` fails if those zones
## disappear.
##
## In this port the camera looks down the court much more steeply than the
## reference's painted view, so the two side wedges are only ~80 px wide at the
## cage's outside edge (measured: the frame spans world x ±14.3 m at the backdrop,
## but the cage outer edge is x = ±10 m, which projects to ±100 px from the
## frame's own edge). A padel back-wall-sized object cannot stand in an 80 px
## wedge without half of it leaving the frame — which is exactly the defect the
## previous lane's frame showed: the arena's gear ring was built at world
## x = -12.4, which projects to screen x = -14, so half of it was cut off by the
## left border.
##
## So every scenery object in this port stands in the proscenium band, behind the
## rear glass, on the ground, inside the frame: it is the reference's own primary
## safe zone, and it is the band that reads as "beyond the glass". Nothing is ever
## placed over the playable trapezoid — the court, the cage and the athletes are
## all nearer the camera than the backdrop.
##
## ONE EXCEPTION, and it is the owner's call (2026-09-17): the tribunes
## (`game/arenas/bleachers.gd`) stand along the TWO SIDE LINES, outside the side
## glass, seats facing the court — not in this band. They sit on the open floor
## the side glass does not hide (it is 3 m tall and the camera looks down at 36
## deg, so the panes cover about a metre of floor and the stands stand just past
## it), because the empty strip beside the court is exactly where their place is.
##
## WHY THERE IS SOMETHING TO SEE AT ALL. A glass wall only reads as glass when
## there is something behind it. The ground plane (`COURT`-sized surround) is
## 80 x 80 m and covers the whole upper frame with dark floor, so before this
## slice the band above the far line was flat dark ground: the "open dark void".
## The backdrop wall now stands in that band, and the glass panes are between it
## and the camera, so the panes are seen against the arena's own painted backdrop.
##
## WHAT THE OBJECTS ARE. One prop table per arena in `arena_style.gd`, whose
## kinds and colours come from the reference's own scenery code
## (`drawFantasyArenaProps`, `drawLocomotiveDepotBackdrop`,
## `drawClockworkFactoryBackdrop` and the default open scene). The shapes are
## primitives — boxes, cylinders, tori, spheres — because the reference's scenery
## is flat 2D paint and no 3D asset of it exists; nothing is imported and nothing
## is generated.
##
## THE FIVE WORLD ARENAS (`family: "world"`, port additions — see
## `arena_style.gd`'s header for why they are not frozen rows). Their decks
## (`art/concepts/world-arenas-r1/`) are read-only: no still is loaded, imported
## or regenerated, and their backdrops are built from the arena's own sky
## gradient plus geometry. The vocabulary they add, all of it native:
##
##   sky       `moon` (a disc cut by an occluder painted the exact sky colour
##             behind it), `sun` (disc + two halo rings), `star`, `aurora`
##             (procedural gradient ribbons with their own alpha).
##   torii     `torii` (pillars + nuki + doubled kasagi), `pagoda` (five tapering
##             roofs), `lantern` (paper/brass, hanging), `petal`.
##   medina    `wall` (capped, merlons), `arch` (horseshoe ring on jambs),
##             `zellige` (diamond tiles, geometry), `minaret`, `palm`.
##   carioca   `ridge` / `peak` (`_peak`: triangular prisms turned to face the
##             camera), `foam`, `cable`.
##   aurora    `basalt` (hexagonal prisms), `snowridge`, `steam`.
##   egeo      `island` (whitewashed cubes + cobalt domes on a cliff), `windmill`,
##             `bougainvillea`, `sea` (gradient band).
##
## Everything is measured in the same metres as the frozen tables and lands in the
## same band: authored x ∈ [-11, 11] (scaled by `x_scale` into the frame's own
## width), tops ≤ ~4.3 m, z ≥ -7.9 so nothing ends up behind the backdrop wall.

extends RefCounted

const Court := preload("res://game/court.gd")
const CourtBuilder := preload("res://game/arenas/court_builder.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")
const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const ArenaLook := preload("res://game/arenas/arena_look.gd")
const Bleachers := preload("res://game/arenas/bleachers.gd")
const ArenaProps := preload("res://game/arenas/arena_props.gd")
const Crowd := preload("res://game/arenas/crowd.gd")
const Trees := preload("res://game/arenas/trees.gd")

## The backdrop wall's world z. Behind `COURT`'s rear line (-6.35 m at this
## scale) and in front of the point where the ground plane leaves the frame, so
## the wall is visible above the far line and through the rear glass.
const BACKDROP_Z := -12.0
## How much of the reference's own arena artwork is shown. The reference paints the
## artwork over its whole canvas and its proscenium is the canvas' top 96 of 540 px
## (18%), so the top 18% of the artwork is what its proscenium shows. Cropping to
## the same band keeps the horizontal mapping identical and avoids showing the
## artwork's own painted court behind ours.
const ARTWORK_BAND := 0.178
## The reference's veil over the artwork (js/render.js:470-479), alpha stops.
const VEIL := [
	[0.00, Color(0.008, 0.027, 0.086, 0.08)],
	[0.52, Color(0.008, 0.027, 0.086, 0.20)],
	[1.00, Color(0.008, 0.027, 0.086, 0.52)],
]
## The apron: the band of `exteriorFloor` colour at the foot of the wall, drawn
## from the reference's own per-scene exterior floor colour.
const APRON_H := 0.42

## FIELD LAW. The deck's own framing mandate: every player-facing frame shows the
## whole court — both baselines, both side walls, and the rear glass the ball
## bounces off — so no scenery may stand over the court, in front of the glass or
## in front of this line. `field_law_report()` proves it on a built tree.
##
## The line is -8.0 m. The band this module actually builds in is at
## `BACKDROP_Z` (-12.0 since the court became a real 10 x 20 m, `a1e10f04`) and at
## the props' own z (`-7.65 - 4.0 = -11.65` by default): every object is at least
## 3.65 m behind this line and 1.65 m behind the rear glass (z = -10.0). Nothing
## here moves `BACKDROP_Z`: it is shared with the nine frozen arenas and their
## evidence.
const FIELD_LAW_Z := -8.0


## Builds one arena's scenery under `parent` and returns its root node.
##
## `preset` is the camera preset in use: the band's extent is derived from it, so
## the backdrop always covers the frame's upper rows and the objects always stay
## inside it.
static func build(parent: Node3D, id: String, arena: Dictionary, preset: String) -> Node3D:
	var style := ArenaStyle.style(id)
	var root := Node3D.new()
	root.name = "Scenery"
	root.set_meta("arena_id", id)
	root.set_meta("family", String(style.get("family", "open")))
	parent.add_child(root)

	var extent := band(preset, BACKDROP_Z)
	var half_x: float = float(extent["half_x"])
	var top: float = float(extent["top"])

	# 1. The backdrop wall: the arena's sky gradient, drawn unshaded so it reads as
	#    paint rather than a lit surface. (Its 128-row gradient is deliberately left
	#    alone: see `arena_look.gd`'s note on where the debanding dither is spent.)
	var sky_tex := CourtBuilder.gradient_texture(style.get("sky", [["0.0", "#0a1420"], ["1.0", "#20344a"]]), 128)
	CourtBuilder.textured_quad(root, "Backdrop", Vector2(half_x * 2.0, top), Vector3(0.0, top * 0.5, BACKDROP_Z), sky_tex)

	# 2. The arena's own painted artwork, where the reference has one: the top band
	#    of it, veiled by the reference's own veil.
	var art := _load_artwork(id)
	if art != null:
		CourtBuilder.textured_quad(root, "BackdropArtwork", Vector2(half_x * 2.0, top), Vector3(0.0, top * 0.5, BACKDROP_Z + 0.02), art)
		var veil_tex := _veil_texture()
		CourtBuilder.textured_quad(root, "BackdropVeil", Vector2(half_x * 2.0, top), Vector3(0.0, top * 0.5, BACKDROP_Z + 0.04), veil_tex)
	root.set_meta("artwork", art != null)

	# 3. The apron: the ground beyond the cage, in this arena's own exterior tone — and, for a
	#    world deck whose `ground_texture` kit slot has a file in it, wearing that texture.
	var apron := Color(String(style.get("apron", "#3a4a55")))
	var apron_mi := CourtBuilder.unshaded(root, "BackdropApron", CourtBuilder.box_mesh(Vector3(half_x * 2.0, APRON_H, 0.08)),
		Vector3(0.0, APRON_H * 0.5, BACKDROP_Z + 0.05), apron)
	ArenaLook.apply_ground_texture(apron_mi.material_override as StandardMaterial3D, id,
		Vector2(half_x * 2.0, APRON_H))

	# 4. Scenery objects. Their x is scaled by the frame's top-row half-width so the
	#    same table stays inside the frame under any camera preset (the tables are
	#    authored for the default preset, whose top row spans +-14.35 m).
	var x_scale := float(extent["prop_half_x"]) / 14.35
	var ctx := {
		"accent": Court.palette_color(arena, "accent", Color(0.0, 0.898, 1.0)),
		"gear": Court.palette_color(arena, "gear", Color(0.784, 0.565, 0.0)),
		"floor": Court.palette_color(arena, "floor", Color(0.10, 0.22, 0.18)),
		"glow": Color(String(style.get("glow", "#ffffff"))),
		"frame": CourtBuilder.FRAME_DIVIDER,
		"top": top,
		# The world family's own inputs: the arena's sky stops (sampled by `moon`,
		# which has to paint the sky it stands in), its apron/ground colour and the
		# frame-width scale the props are placed with. The nine frozen tables read
		# none of them.
		"sky": (style.get("sky", []) as Array).duplicate(true),
		"apron": apron,
		"x_scale": x_scale,
	}
	var props: Array = style.get("props", [])
	# 4b. The arena kit's suppression seam (KIT-STANDARD §5). A slot that has BOTH a GLB
	#     in place (`res://assets/arenas/<id>/<slot>.glb`) and `suppress = true` in the
	#     kit's spec table stands INSTEAD OF the procedural prop it maps to, so
	#     `_build_prop` is skipped for that kind. The container is still built, so "one
	#     `Dressing_*` per authored prop" — the invariant the frozen suites pin — does
	#     not move. Empty today: every slot ships with the flag off (asserted by
	#     `tests/arena_kit_test.gd`), and with no GLB in place the list is empty anyway.
	var skipped := ArenaKit.suppressed_kinds(id)
	for i in props.size():
		var prop: Dictionary = props[i]
		var kind := String(prop.get("kind", "spark"))
		var container := Node3D.new()
		container.name = "Dressing_%s%d" % [kind, i + 1]
		container.position = Vector3(float(prop.get("x", 0.0)) * x_scale, 0.0, float(prop.get("z", -7.65)) - 4.0)
		container.set_meta("kind", kind)
		root.add_child(container)
		if skipped.has(kind):
			continue
		_build_prop(container, prop, ctx)

	# 4c. The arena kit (KIT-STANDARD §5). GLBs dropped at
	#     `res://assets/arenas/<id>/<slot>.glb` mount at their spec anchor under
	#     `Scenery/Kit/Slot_<slot>`, ADDITIVE to the props above and silent when the
	#     arena has no file at all: `mount()` returns null and adds no node, which is
	#     what keeps an empty-kit build identical to the pre-kit tree (proved against
	#     the recorded baseline by `tests/arena_kit_test.gd`).
	ArenaKit.mount(root, id, ctx)

	# 5. The owner's tribunes, along the two side lines. Built after the kit so the
	#    stands are the arena's own geometry rather than a scenery prop: they are
	#    placed from the court's width, not from this band.
	Bleachers.build(root)

	# 6. The furniture that shares the stands' corridor and the rear band: the
	#    players' shelters beside the stands, the sponsor boards behind the rear
	#    glass. After the stands because the shelters place themselves from
	#    `Bleachers.span_z()`.
	ArenaProps.build(root)

	# 7. The people on the stands, placed from `Bleachers.span_z()` and the stands'
	#    own raked box, so they sit on the seating rather than beside it.
	Crowd.build(root)

	# The trees' shared scene is cached across the prop loop (one read, N draws);
	# drop it now so no Resource outlives this arena in a `static var`.
	Trees.release()
	return root


# ---------------------------------------------------------------------------
# The band: where the frame's upper rows are, in world coordinates
# ---------------------------------------------------------------------------

## The proscenium band for a camera preset at a given world z:
##   top     — the world y of the frame's top row (plus a small overscan), i.e. how
##             tall the backdrop has to be to reach the top of the frame;
##   half_x  — the world half-width needed to cover the frame's widest visible row;
##   horizon — the screen row where the ground meets the wall.
##
## Closed form from the preset's own numbers (position, pitch, fov), not from a
## live camera node: the band is needed while the scene is being built, and the
## math is the same projection `Camera3D` performs for a pitched camera with no
## roll (see the evidence file for the derivation and the round-trip check).
static func band(preset: String, z: float, aspect := 16.0 / 9.0) -> Dictionary:
	var cfg: Dictionary = Court.CAMERAS.get(preset, Court.CAMERAS["default"])
	var cam_pos: Vector3 = cfg["pos"]
	var th := deg_to_rad(float(cfg["pitch_deg"]))
	var t := tan(deg_to_rad(float(cfg["fov"]) * 0.5))
	var top := _world_y(cam_pos, th, t, z, 1.06)
	# The frame is widest at its lowest visible row of the band; sample a couple.
	var half_x := 0.0
	for ny in [1.06, 0.80, 0.55]:
		var d := _depth(cam_pos, th, t, z, float(ny))
		half_x = maxf(half_x, d * t * aspect)
	half_x = maxf(half_x * 1.12, 6.0)
	# `prop_half_x` is the frame's half-width at its TOP row instead: the scenery
	# tables are authored for the default preset's top row (±14.35 m), and objects
	# are scaled by this value so they stay inside the frame under any preset. The
	# wall uses the wider `half_x`, because the wall has to cover every row.
	var prop_half_x := _depth(cam_pos, th, t, z, 1.06) * t * aspect
	return {
		"z": z,
		"top": maxf(top, 1.6),
		"half_x": half_x,
		"prop_half_x": maxf(prop_half_x, 6.0),
	}


static func _depth(cam_pos: Vector3, th: float, t: float, z: float, ny: float) -> float:
	var denom := ny * t * sin(th) - cos(th)
	if absf(denom) < 0.000001:
		return 1.0
	return (z - cam_pos.z) / denom


static func _world_y(cam_pos: Vector3, th: float, t: float, z: float, ny: float) -> float:
	var d := _depth(cam_pos, th, t, z, ny)
	return cam_pos.y + d * (ny * t * cos(th) + sin(th))


# ---------------------------------------------------------------------------
# Field law
# ---------------------------------------------------------------------------

## The field law, checked on a built arena: the court is complete — both
## baselines, both side walls, the rear glass with its rail and foot band — and
## nothing the scenery built crosses `FIELD_LAW_Z` towards the camera. Returns one
## string per violation, empty when the law holds, so a caller can print it, count
## it or fail on it; a node that cannot be measured is reported too. Never hides a
## violation.
##
## Positions are read in the frame of `arena_root` (the `Arena` node
## `arena_library.gd::build()` returns), not in world space: an arena placed
## somewhere in a scene carries its scenery with it, and the law is about the
## arena's own frame.
static func field_law_report(arena_root: Node3D) -> Array[String]:
	var out: Array[String] = []
	if arena_root == null:
		out.append("field law: no arena to check")
		return out
	for node_name in ["LineFar", "LineNear", "LineLeft", "LineRight",
			"GlassLeft", "GlassRight", "GlassNear", "GlassFar", "GlassFar2",
			"GlassFar6", "GlassFarRail", "GlassFarBottom"]:
		if arena_root.find_child(node_name, true, false) == null:
			out.append("field law: %s is missing" % node_name)
	var scenery: Node = arena_root.get_node_or_null("Scenery")
	if scenery == null:
		out.append("field law: no Scenery node")
		return out
	for child in scenery.get_children():
		var holder := child as Node3D
		if holder == null:
			out.append("field law: %s is not a Node3D" % child.name)
			continue
		var meshes := _meshes_of(holder)
		if meshes.is_empty():
			# Nothing this child draws: a prop container whose prop the arena kit
			# suppressed, or the kit's grouping node with no slot filled. Its origin is
			# not a place any geometry stands, so it is not a violation — the law is
			# about what is on screen. (Every container built today carries geometry,
			# so this pass is unreachable until a kit GLB is mounted.)
			continue
		for mi in meshes:
			var mesh := (mi as MeshInstance3D).mesh
			if mesh == null:
				continue
			# The FULL chain to the arena root, not the holder's transform times the
			# mesh's own transform: a mounted kit GLB sits at `Kit/Slot_<slot>/Piece/
			# <mesh>`, and the one-level product was blind to everything between — a
			# nested piece standing in front of the plane went unreported (measured on
			# the first fixture mount: `Kit reaches z -0.25`, the piece read as if it
			# stood at the kit node's own origin). For today's trees — one
			# `MeshInstance3D` directly under each `Dressing_*` container — the two
			# products are the same number, so this changes no measured value.
			var mxf := _xform_to(mi, arena_root)
			var aabb := mesh.get_aabb()
			for corner in 8:
				var corner_z := (mxf * aabb.get_endpoint(corner)).z
				if corner_z > FIELD_LAW_Z:
					out.append("field law: %s/%s reaches z %.2f" % [holder.name, mi.name, corner_z])
					break
	return out


## A node's transform in the frame of `ancestor` (the arena root), walked up the
## parent chain, so the answer does not depend on where the arena was added.
static func _xform_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != ancestor:
		xf = cur.transform * xf
		cur = cur.get_parent() as Node3D
	return xf


## Every mesh under a node, including the node itself when it is one.
static func _meshes_of(node: Node3D) -> Array:
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	return meshes


# ---------------------------------------------------------------------------
# Artwork
# ---------------------------------------------------------------------------

## The arena's own painted artwork, cropped to the band the reference's
## proscenium shows, or null when this arena has none / the file is unreadable.
## Read at runtime (`Image.load_from_file`), so nothing depends on the editor's
## import step; the file is the reference's own, copied verbatim under
## `res://game/arenas/art/`.
static func _load_artwork(id: String) -> Texture2D:
	var path := ArenaStyle.artwork_path(id)
	if path == "":
		return null
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.load_from_file(abs_path)
	if img == null or img.get_width() <= 0:
		return null
	var band_h := maxi(1, int(float(img.get_height()) * ARTWORK_BAND))
	var crop := img.get_region(Rect2i(0, 0, img.get_width(), band_h))
	return ImageTexture.create_from_image(crop)


static func _veil_texture() -> GradientTexture2D:
	return CourtBuilder.gradient_texture(VEIL, 64)


# ---------------------------------------------------------------------------
# Scenery objects
# ---------------------------------------------------------------------------

static func _part(parent: Node3D, name: String, mesh: Mesh, pos: Vector3, color: Color,
		alpha := 1.0, unshaded := true, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	if unshaded:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color.r, color.g, color.b, alpha)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
	else:
		mi.material_override = Court.material(color, 0.85, alpha)
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	parent.add_child(mi)
	return mi


## The arena's own sky gradient, sampled at a world height. The backdrop quad's
## texture runs its first stop at the top of the band (world y = `top`) and its
## last stop at the foot (y = 0), so a prop that has to vanish into the sky — the
## moon's occluder disc — is painted exactly the colour standing behind it, out of
## the arena's own stop list. No image file is read.
static func _sky_color(ctx: Dictionary, y: float) -> Color:
	var stops: Array = ctx.get("sky", [])
	if stops.is_empty():
		return Color(0.03, 0.05, 0.10)
	var top := maxf(float(ctx.get("top", 1.0)), 0.001)
	var t := clampf(1.0 - y / top, 0.0, 1.0)
	var lo := Color(String((stops[0] as Array)[1]))
	var lo_t := float((stops[0] as Array)[0])
	var hi := lo
	var hi_t := lo_t
	for stop in stops:
		var s: Array = stop
		if float(s[0]) <= t:
			lo = Color(String(s[1]))
			lo_t = float(s[0])
		if float(s[0]) >= t:
			hi = Color(String(s[1]))
			hi_t = float(s[0])
			break
	if hi_t <= lo_t:
		return lo
	return lo.lerp(hi, (t - lo_t) / (hi_t - lo_t))


## A textured quad whose TEXTURE carries the alpha (the aurora ribbons).
## `CourtBuilder.textured_quad` switches transparency on only when the tint
## carries alpha, and an albedo texture's own alpha is ignored without that mode —
## the quad would draw opaque over the sky.
static func _alpha_quad(parent: Node3D, name: String, size: Vector2, pos: Vector3,
		texture: Texture2D, alpha := 1.0) -> MeshInstance3D:
	var mi := CourtBuilder.textured_quad(parent, name, size, pos, texture)
	var mat := mi.material_override as StandardMaterial3D
	if mat != null:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	return mi


## A triangular prism standing on its base with one face towards the camera: the
## low-poly ridge/mountain unit. `half_w` is the triangle's own radius (its
## silhouette reaches 0.866 * half_w to each side), `height` the apex above
## `pos.y`. The mesh is a 3-sided cylinder: under the -90 deg X rotation its local
## +Z becomes the apex (so the apex scales in local Z) and its length becomes the
## prism's depth. The -height/3 offset puts the triangle's base on `pos.y`.
static func _peak(parent: Node3D, name: String, pos: Vector3, half_w: float, height: float,
		color: Color, alpha := 1.0, depth := 0.7) -> MeshInstance3D:
	var wz := height / maxf(half_w * 1.5, 0.001)
	return _part(parent, name, CourtBuilder.cyl_mesh(half_w, depth, 3),
		Vector3(pos.x, pos.y + height / 3.0, pos.z), color, alpha, true,
		Vector3(-90.0, 0.0, 0.0), Vector3(1.0, 1.0, wz))


static func _tint(prop: Dictionary, ctx: Dictionary, fallback: Color) -> Color:
	var key := String(prop.get("tint", ""))
	if key == "":
		return fallback
	if key == "accent" or key == "gear" or key == "floor":
		return ctx[key]
	if key == "glow":
		return ctx["glow"]
	return Color(key)


static func _size(prop: Dictionary, key: String, fallback: float) -> float:
	return float(prop.get(key, fallback))


static func _build_prop(parent: Node3D, prop: Dictionary, ctx: Dictionary) -> void:
	var kind := String(prop.get("kind", "spark"))
	var x := 0.0
	var y := _size(prop, "y", 0.0)
	var r := _size(prop, "r", 0.4)
	var h := _size(prop, "h", 1.2)
	# A cross-court span, for the widths the world family builds (the frozen tables
	# carry no `w` and are unaffected).
	var w := _size(prop, "w", 6.0)
	var tint := _tint(prop, ctx, ctx["gear"])
	match kind:
		"floodlight":
			# js/render.js:723-724: two floodlight masts on the two sides.
			_part(parent, "Mast", CourtBuilder.box_mesh(Vector3(0.07, h, 0.07)), Vector3(x, h * 0.5, 0.0), Color(0.78, 0.82, 0.86))
			_part(parent, "Head", CourtBuilder.box_mesh(Vector3(0.46, 0.22, 0.16)), Vector3(x, h - 0.08, 0.0), Color(0.86, 0.89, 0.93))
			_part(parent, "Lamp", CourtBuilder.box_mesh(Vector3(0.34, 0.10, 0.12)), Vector3(x, h - 0.22, 0.02), ctx["glow"], 0.95)
		"cloud":
			# js/render.js:716-718: three clouds over the court.
			_part(parent, name_of(kind, 1), CourtBuilder.ball_mesh(r), Vector3(x, y, 0.0), Color(0.96, 0.98, 1.0), 0.92)
			_part(parent, name_of(kind, 2), CourtBuilder.ball_mesh(r * 0.72), Vector3(x - r * 0.9, y + r * 0.18, 0.0), Color(0.96, 0.98, 1.0), 0.88)
			_part(parent, name_of(kind, 3), CourtBuilder.ball_mesh(r * 0.6), Vector3(x + r, y - r * 0.1, 0.0), Color(0.96, 0.98, 1.0), 0.88)
		"tree":
			# js/render.js:719-722 drew the tree as a cylinder trunk plus two balls;
			# the owner replaced it with a generated model. `trees.gd` carries the
			# measurements and the reason (his downloads were 4.5M and 10M triangles
			# and would not simplify; this one is 9,164 by generation). The flat
			# fallback stays: an unreadable GLB must leave the arena dressed, not
			# empty, and the slice asserts one node per prop.
			if not Trees.place_one(parent, h):
				_part(parent, "Trunk", CourtBuilder.cyl_mesh(0.055, h * 0.5), Vector3(x, h * 0.25, 0.0), Color(0.35, 0.26, 0.18))
				_part(parent, "Crown", CourtBuilder.ball_mesh(h * 0.3), Vector3(x, h * 0.72, 0.0), Color(0.42, 0.68, 0.33))
				_part(parent, "Crown2", CourtBuilder.ball_mesh(h * 0.22), Vector3(x + h * 0.18, h * 0.62, 0.0), Color(0.52, 0.74, 0.31))
		"gearring":
			_gear(parent, kind, Vector3(x, y, 0.0), r, tint)
		"gear":
			_gear(parent, kind, Vector3(x, y, 0.0), r, tint)
		"signal":
			# js/render.js:262-... the depot's two signal lamps.
			_part(parent, "Mast", CourtBuilder.box_mesh(Vector3(0.09, h, 0.09)), Vector3(x, h * 0.5, 0.0), ctx["frame"].lightened(0.1))
			_part(parent, "Lamp", CourtBuilder.ball_mesh(0.11), Vector3(x, h - 0.16, 0.0), tint, 1.0)
			_part(parent, "Hood", CourtBuilder.box_mesh(Vector3(0.2, 0.08, 0.2)), Vector3(x, h - 0.01, 0.0), ctx["frame"].lightened(0.2))
		"lamp":
			_part(parent, "Mast", CourtBuilder.box_mesh(Vector3(0.06, y, 0.06)), Vector3(x, y * 0.5, 0.0), ctx["frame"].lightened(0.15))
			_part(parent, "Lamp", CourtBuilder.ball_mesh(r), Vector3(x, y + 0.1, 0.0), tint, 1.0)
		"girder":
			# The depot's heavy slanted girders (js/render.js:266-276).
			var lean := _size(prop, "lean", 1.0) * 11.0
			_part(parent, "Beam", CourtBuilder.box_mesh(Vector3(0.2, h, 0.2)), Vector3(x, h * 0.5, 0.0), tint if String(prop.get("tint", "")) != "" else Color(0.09, 0.17, 0.24), 1.0, true, Vector3(0.0, 0.0, lean))
		"rail":
			var lean2 := _size(prop, "lean", 1.0) * 16.0
			_part(parent, "Beam", CourtBuilder.box_mesh(Vector3(1.0, 0.05, 0.05)), Vector3(x, y, 0.0), tint if String(prop.get("tint", "")) != "" else Color(0.11, 0.16, 0.20), 1.0, true, Vector3(0.0, 0.0, lean2))
		"loco":
			# js/render.js:280-305: the locomotive behind the glass.
			_part(parent, "Hull", CourtBuilder.box_mesh(Vector3(5.0, 0.5, 0.5)), Vector3(x, 0.62, 0.0), Color(0.07, 0.25, 0.27), 1.0, false)
			_part(parent, "Boiler", CourtBuilder.box_mesh(Vector3(1.7, 0.5, 0.5)), Vector3(x - 1.2, 0.85, 0.0), tint, 1.0, false)
			_part(parent, "Cab", CourtBuilder.box_mesh(Vector3(1.5, 0.42, 0.46)), Vector3(x + 1.5, 1.05, 0.0), Color(0.11, 0.41, 0.44), 1.0, false)
			_part(parent, "Chimney", CourtBuilder.cyl_mesh(0.09, 0.28), Vector3(x - 1.9, 1.2, 0.0), Color(0.09, 0.19, 0.23), 1.0, false)
			_part(parent, "Window", CourtBuilder.box_mesh(Vector3(0.5, 0.2, 0.05)), Vector3(x + 1.5, 1.1, 0.26), Color(0.92, 0.96, 0.96), 0.75)
			for i in 4:
				_part(parent, "Wheel%d" % (i + 1), CourtBuilder.ring_mesh(0.13, 0.19, 14),
					Vector3(x - 1.7 + float(i) * 1.13, 0.3, 0.28), tint, 1.0, true, Vector3(90.0, 0.0, 0.0))
		"clock":
			# js/render.js:290-306: the factory's big clock face.
			_part(parent, "Rim", CourtBuilder.cyl_mesh(r, 0.12, 24), Vector3(x, y, 0.0), tint, 1.0, true, Vector3(90.0, 0.0, 0.0))
			_part(parent, "Face", CourtBuilder.cyl_mesh(r * 0.82, 0.14, 24), Vector3(x, y, 0.02), Color(0.96, 0.85, 0.55), 1.0, true, Vector3(90.0, 0.0, 0.0))
			_part(parent, "HandLong", CourtBuilder.box_mesh(Vector3(0.05, r * 0.72, 0.03)), Vector3(x, y + r * 0.3, 0.05), Color(0.28, 0.18, 0.22))
			_part(parent, "HandShort", CourtBuilder.box_mesh(Vector3(0.05, r * 0.45, 0.03)), Vector3(x + r * 0.2, y, 0.05), Color(0.28, 0.18, 0.22), 1.0, true, Vector3(0.0, 0.0, 90.0))
			for i in 6:
				var ang := deg_to_rad(float(i) * 60.0)
				_part(parent, "Tick%d" % i, CourtBuilder.box_mesh(Vector3(0.05, 0.14, 0.03)),
					Vector3(x + sin(ang) * r * 0.68, y + cos(ang) * r * 0.68, 0.04), Color(0.28, 0.18, 0.22))
		"piston":
			# js/render.js:308-312.
			_part(parent, "Body", CourtBuilder.box_mesh(Vector3(0.34, y, 0.26)), Vector3(x, y * 0.5, 0.0), ctx["frame"].lightened(0.25), 1.0, false)
			_part(parent, "Rod", CourtBuilder.box_mesh(Vector3(0.5, 0.06, 0.06)), Vector3(x, y + 0.12, 0.0), Color(0.82, 0.64, 0.29))
			_part(parent, "Head", CourtBuilder.ball_mesh(0.16), Vector3(x, y + 0.24, 0.0), Color(0.82, 0.64, 0.29))
		"airship":
			# js/render.js:565-583: airship hulls beyond the side glass.
			_part(parent, "Hull", CourtBuilder.ball_mesh(r), Vector3(x, y, 0.0), Color(0.09, 0.13, 0.20), 0.9, true, Vector3.ZERO, Vector3(2.2, 0.78, 1.0))
			_part(parent, "Keel", CourtBuilder.box_mesh(Vector3(r * 3.6, 0.06, 0.06)), Vector3(x, y - r * 0.6, 0.0), tint, 0.95)
			for i in 3:
				_part(parent, "Port%d" % i, CourtBuilder.ball_mesh(0.09),
					Vector3(x - r * 0.9 + float(i) * r * 0.9, y, 0.06), Color(0.36, 0.86, 1.0), 0.85)
			_part(parent, "Prop", CourtBuilder.box_mesh(Vector3(0.04, r * 1.1, 0.04)), Vector3(x + r * 2.15, y, 0.0), tint, 1.0)
		"bolt":
			# js/render.js:523-530: the storm's lightning.
			for i in 3:
				var bx := x + float(i % 2) * 0.22 - 0.11
				_part(parent, "Arc%d" % i, CourtBuilder.box_mesh(Vector3(0.06, h * 0.42, 0.05)),
					Vector3(bx, y - float(i) * h * 0.36, 0.05), ctx["glow"], 0.85, true,
					Vector3(0.0, 0.0, 22.0 if i % 2 == 0 else -26.0))
		"chain":
			for i in 4:
				_part(parent, "Link%d" % i, CourtBuilder.ring_mesh(0.06, 0.1, 10),
					Vector3(x + float(i) * 0.12, y - float(i) * h * 0.22, 0.0), tint, 0.95,
					true, Vector3(0.0, 0.0, 30.0))
		"dome":
			# js/render.js:588-591: the abyssal dome's arc, drawn as a wide shallow
			# arc across the whole band (the reference's arc spans 91% of the width
			# and 45% of the height; the band is only ~2.7 m tall here, so the arc is
			# squashed to the same WIDTH and as much of the height as the frame has).
			_part(parent, "Arc", CourtBuilder.ring_mesh(r * 0.97, r, 30), Vector3(x, y, 0.0), tint, 1.0, true,
				Vector3(90.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.13))
		"porthole":
			# js/render.js:592-600: pressurised columns with lit portholes.
			_part(parent, "Column", CourtBuilder.box_mesh(Vector3(0.6, y * 2.0, 0.34)), Vector3(x, y, 0.0), Color(0.24, 0.16, 0.10), 1.0, false)
			for i in 3:
				var py := y - 0.5 + float(i) * 0.5
				_part(parent, "Rim%d" % i, CourtBuilder.ring_mesh(0.16, 0.22, 14), Vector3(x, py, 0.18), tint, 1.0, true, Vector3(0.0, 0.0, 0.0))
				_part(parent, "Glass%d" % i, CourtBuilder.cyl_mesh(0.16, 0.04, 14), Vector3(x, py, 0.2), Color(0.22, 0.92, 0.90), 0.45)
		"bubble":
			_part(parent, "Bubble", CourtBuilder.ball_mesh(r), Vector3(x, y, 0.0), ctx["glow"], 0.42)
		"titan":
			# js/render.js:610-620: the Titan heads' silhouettes with a burning eye.
			_part(parent, "Head", CourtBuilder.cyl_mesh(r, 0.14, 20), Vector3(x, y, 0.0), Color(0.13, 0.10, 0.10), 1.0, true, Vector3(90.0, 0.0, 0.0))
			_part(parent, "Rim", CourtBuilder.ring_mesh(r * 0.9, r, 20), Vector3(x, y, 0.03), tint, 1.0, true, Vector3(90.0, 0.0, 0.0))
			_part(parent, "Eye", CourtBuilder.box_mesh(Vector3(r * 0.6, 0.1, 0.05)), Vector3(x, y - r * 0.1, 0.06), ctx["glow"], 0.9)
		"lava":
			# js/render.js:622-631: the lava channels at the two sides.
			_part(parent, "Channel", CourtBuilder.box_mesh(Vector3(r * 1.5, r * 0.7, 0.08)), Vector3(x, y, 0.0), ctx["glow"], 0.5, true, Vector3(0.0, 0.0, 14.0))
			_part(parent, "Core", CourtBuilder.box_mesh(Vector3(r * 1.0, r * 0.28, 0.06)), Vector3(x, y - r * 0.05, 0.06), Color(1.0, 0.78, 0.3), 0.75, true, Vector3(0.0, 0.0, 14.0))
		"rock":
			_part(parent, "Spire", CourtBuilder.cone_mesh(_size(prop, "h", 0.9) * 0.45, _size(prop, "h", 0.9)), Vector3(x, _size(prop, "h", 0.9) * 0.5, 0.0), tint, 1.0, false)
		"orbit":
			# js/render.js:640-644: the orrery's orbital rings (wide and flat: the
			# reference draws them 1.75 x 0.48, so the squash keeps their shape).
			_part(parent, "Orbit", CourtBuilder.ring_mesh(r * 0.94, r, 28), Vector3(x, y, 0.0), tint, 0.9, true,
				Vector3(90.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.28))
		"planet":
			# js/render.js:646-660.
			_part(parent, "Globe", CourtBuilder.ball_mesh(r), Vector3(x, y, 0.0), tint, 1.0)
			_part(parent, "Ring", CourtBuilder.ring_mesh(r * 1.35, r * 1.6, 20), Vector3(x, y, 0.0), Color(0.89, 0.75, 0.41), 0.9, true,
				Vector3(90.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.42))
		"column":
			# js/render.js:662-670: the observatory's two columns.
			_part(parent, "Shaft", CourtBuilder.box_mesh(Vector3(0.62, h, 0.36)), Vector3(x, h * 0.5, 0.0), Color(0.17, 0.14, 0.27), 1.0, false)
			_part(parent, "Cap", CourtBuilder.box_mesh(Vector3(0.76, 0.1, 0.46)), Vector3(x, h, 0.0), tint, 1.0, true)
			_part(parent, "Base", CourtBuilder.box_mesh(Vector3(0.76, 0.1, 0.46)), Vector3(x, 0.05, 0.0), tint, 1.0, true)
			_gear(parent, "Gear", Vector3(x, h * 0.62, 0.22), 0.3, Color(0.61, 0.44, 0.22))
		# --- the world family's own kinds (see the file header) --------------
		"torii":
			# The deck's gate: two pillars, the tie beam (nuki) and the doubled
			# top beam (shimaki + kasagi) that overhangs them.
			var gate_w := _size(prop, "w", 3.0)
			var post := maxf(gate_w * 0.055, 0.05)
			_part(parent, "PillarL", CourtBuilder.box_mesh(Vector3(post, h, post)), Vector3(x - gate_w * 0.5, h * 0.5, 0.0), tint.darkened(0.10))
			_part(parent, "PillarR", CourtBuilder.box_mesh(Vector3(post, h, post)), Vector3(x + gate_w * 0.5, h * 0.5, 0.0), tint.darkened(0.10))
			_part(parent, "Nuki", CourtBuilder.box_mesh(Vector3(gate_w * 1.14, h * 0.06, post * 1.6)), Vector3(x, h * 0.70, 0.0), tint)
			_part(parent, "Shimaki", CourtBuilder.box_mesh(Vector3(gate_w * 1.24, h * 0.05, post * 2.0)), Vector3(x, h * 0.92, 0.0), tint.darkened(0.06))
			_part(parent, "Kasagi", CourtBuilder.box_mesh(Vector3(gate_w * 1.34, h * 0.06, post * 2.3)), Vector3(x, h, 0.0), tint.darkened(0.14))
			_part(parent, "Gakuzuka", CourtBuilder.box_mesh(Vector3(gate_w * 0.10, h * 0.20, post * 1.4)), Vector3(x, h - h * 0.10, 0.0), tint)
		"pagoda":
			# Five tapering roofs over a plinth: the deck's pagoda silhouette.
			var plinth := r * 1.7
			var tiers := 5
			var tier_h := (h - 0.36) / float(tiers)
			_part(parent, "Plinth", CourtBuilder.box_mesh(Vector3(plinth, 0.18, r * 1.1)), Vector3(x, 0.09, 0.0), tint.darkened(0.30))
			for i in tiers:
				var tier := float(i)
				var body_w := r * (1.02 - 0.5 * tier / float(tiers))
				_part(parent, "Body%d" % i, CourtBuilder.box_mesh(Vector3(body_w, tier_h * 0.62, body_w * 0.8)),
					Vector3(x, 0.18 + tier_h * (tier + 0.5), 0.0), tint)
				_part(parent, "Roof%d" % i, CourtBuilder.cone_mesh(body_w * 0.82, tier_h * 0.44),
					Vector3(x, 0.18 + tier_h * (tier + 0.92), 0.0), tint.lightened(0.08))
			_part(parent, "Spire", CourtBuilder.cyl_mesh(0.03, 0.26), Vector3(x, h + 0.05, 0.0), tint.lightened(0.20))
			_part(parent, "Finial", CourtBuilder.ball_mesh(0.055), Vector3(x, h + 0.18, 0.0), tint.lightened(0.30))
		"lantern":
			# A round hanging lantern — paper for torii, brass for medina: the
			# deck's own kind, rounder and warmer than the frozen `lamp`.
			var hang := _size(prop, "hang", 0.45)
			if hang > 0.0:
				_part(parent, "Cord", CourtBuilder.box_mesh(Vector3(0.014, hang, 0.014)), Vector3(x, y + r + hang * 0.5, 0.0), tint.darkened(0.55))
			_part(parent, "Paper", CourtBuilder.ball_mesh(r, 14), Vector3(x, y, 0.0), tint, 0.95)
			_part(parent, "CapTop", CourtBuilder.cyl_mesh(r * 0.44, 0.04, 12), Vector3(x, y + r * 0.88, 0.0), tint.darkened(0.50))
			_part(parent, "CapBottom", CourtBuilder.cyl_mesh(r * 0.34, 0.036, 12), Vector3(x, y - r * 0.88, 0.0), tint.darkened(0.50))
		"petal":
			# Drifting petals: the deck's small pink `spark`, six tilted quads.
			for i in 6:
				var petal_a := float(i) * 0.7
				_part(parent, "Petal%d" % i, CourtBuilder.quad_mesh(0.10, 0.05),
					Vector3(x + sin(petal_a) * (0.20 + 0.05 * float(i)), y + float(i) * 0.09 - 0.22, 0.0),
					tint, 0.90, true, Vector3(0.0, 0.0, rad_to_deg(petal_a)))
		"moon":
			# The deck's crescent: a disc cut by a second disc painted the exact
			# sky colour standing behind it (the gradient is smooth over the
			# occluder's few centimetres, so the patch is invisible).
			_part(parent, "Disc", CourtBuilder.cyl_mesh(r, 0.05, 24), Vector3(x, y, 0.0), tint, 1.0, true, Vector3(90.0, 0.0, 0.0))
			_part(parent, "Occluder", CourtBuilder.cyl_mesh(r * 0.88, 0.04, 24), Vector3(x + r * 0.40, y + r * 0.10, 0.05), _sky_color(ctx, y), 1.0, true, Vector3(90.0, 0.0, 0.0))
		"sun":
			# The arena's sun: the disc and two halo rings.
			_part(parent, "Disc", CourtBuilder.cyl_mesh(r, 0.05, 24), Vector3(x, y, 0.0), tint, 1.0, true, Vector3(90.0, 0.0, 0.0))
			_part(parent, "Halo", CourtBuilder.ring_mesh(r * 1.06, r * 1.40, 24), Vector3(x, y, 0.02), tint, 0.30, true, Vector3(90.0, 0.0, 0.0))
			_part(parent, "HaloWide", CourtBuilder.ring_mesh(r * 1.50, r * 2.00, 24), Vector3(x, y, 0.01), tint, 0.14, true, Vector3(90.0, 0.0, 0.0))
		"star":
			# A small constellation: four points, the deck's sparse night sky.
			var star_offs := [Vector2(0.0, 0.0), Vector2(0.22, -0.11), Vector2(-0.16, 0.12), Vector2(0.34, 0.08)]
			for i in star_offs.size():
				var so: Vector2 = star_offs[i]
				_part(parent, "Star%d" % i, CourtBuilder.ball_mesh(r * (1.0 - 0.16 * float(i)), 8),
					Vector3(x + so.x, y + so.y, 0.0), tint, _size(prop, "alpha", 0.95))
		"aurora":
			# The night sky's ribbons: procedural green -> violet gradients that
			# carry their own alpha, two stacked quads per ribbon.
			var ribbon := CourtBuilder.gradient_texture([
				[0.00, Color(0.08, 0.26, 0.30, 0.00)],
				[0.30, Color(ctx["glow"].r, ctx["glow"].g, ctx["glow"].b, 0.55)],
				[0.62, Color(tint.r, tint.g, tint.b, 0.42)],
				[1.00, Color(0.10, 0.08, 0.22, 0.00)],
			], 64)
			var ribbon_alpha := _size(prop, "alpha", 0.90)
			_alpha_quad(parent, "Ribbon", Vector2(w, h), Vector3(x, y, 0.04), ribbon, ribbon_alpha)
			_alpha_quad(parent, "RibbonCore", Vector2(w * 0.72, h * 0.5), Vector3(x - w * 0.14, y + h * 0.22, 0.05), ribbon, ribbon_alpha * 0.8)
		"wall":
			# The medina's clay wall: a capped band with merlons.
			var crenels := int(maxf(1.0, floor(w / 0.9)))
			_part(parent, "Wall", CourtBuilder.box_mesh(Vector3(w, h, 0.24)), Vector3(x, h * 0.5, 0.0), tint)
			_part(parent, "Cap", CourtBuilder.box_mesh(Vector3(w, 0.07, 0.30)), Vector3(x, h + 0.035, 0.0), tint.lightened(0.12))
			for i in crenels:
				_part(parent, "Merlon%d" % i, CourtBuilder.box_mesh(Vector3(w / float(crenels) * 0.5, 0.17, 0.28)),
					Vector3(x - w * 0.5 + w / float(crenels) * (float(i) + 0.5), h + 0.15, 0.0), tint.darkened(0.08))
		"zellige":
			# The tiled band: flat diamonds alternating the arena's turquoise with
			# whitewash, over a dark grout band. Native geometry, no image file.
			var tile_w := _size(prop, "w", 6.0)
			var tiles := int(maxf(1.0, floor(tile_w / 0.38)))
			var tile_d := h * 0.62
			_part(parent, "Grout", CourtBuilder.box_mesh(Vector3(tile_w, h * 0.70, 0.10)), Vector3(x, y, 0.10), ctx["gear"].darkened(0.35))
			for i in tiles:
				_part(parent, "Tile%d" % i, CourtBuilder.box_mesh(Vector3(tile_d, tile_d, 0.05)),
					Vector3(x - tile_w * 0.5 + tile_w / float(tiles) * (float(i) + 0.5), y, 0.14),
					tint if i % 2 == 0 else Color(0.95, 0.96, 0.98), 1.0, true, Vector3(0.0, 0.0, 45.0))
		"arch":
			# A horseshoe gate: two jambs, the ring that springs below the impost,
			# and the shaded opening behind it.
			var opening := _size(prop, "w", 2.2)
			var arc_r := opening * 0.5
			_part(parent, "Opening", CourtBuilder.box_mesh(Vector3(opening, h + arc_r, 0.10)), Vector3(x, (h + arc_r) * 0.5, -0.08), ctx["gear"].darkened(0.55))
			_part(parent, "JambL", CourtBuilder.box_mesh(Vector3(0.34, h, 0.36)), Vector3(x - arc_r - 0.17, h * 0.5, 0.0), tint)
			_part(parent, "JambR", CourtBuilder.box_mesh(Vector3(0.34, h, 0.36)), Vector3(x + arc_r + 0.17, h * 0.5, 0.0), tint)
			_part(parent, "Arch", CourtBuilder.ring_mesh(arc_r, arc_r + 0.20, 24), Vector3(x, h + arc_r * 0.72, 0.02), tint.lightened(0.08), 1.0, true, Vector3(90.0, 0.0, 0.0))
			_part(parent, "Keystone", CourtBuilder.box_mesh(Vector3(0.24, 0.30, 0.30)), Vector3(x, h + arc_r * 1.62, 0.0), tint.lightened(0.16))
		"minaret":
			# The slim tower: base, shaft, balcony, crown and a small dome.
			var shaft := maxf(h - 0.60, 0.30)
			_part(parent, "Base", CourtBuilder.box_mesh(Vector3(r * 2.6, 0.16, r * 2.6)), Vector3(x, 0.08, 0.0), tint.darkened(0.22))
			_part(parent, "Shaft", CourtBuilder.box_mesh(Vector3(r * 1.5, shaft, r * 1.5)), Vector3(x, 0.16 + shaft * 0.5, 0.0), tint)
			_part(parent, "Balcony", CourtBuilder.box_mesh(Vector3(r * 2.3, 0.08, r * 2.3)), Vector3(x, 0.16 + shaft * 0.66, 0.0), tint.lightened(0.10))
			_part(parent, "Crown", CourtBuilder.box_mesh(Vector3(r * 1.9, 0.12, r * 1.9)), Vector3(x, h - 0.40, 0.0), tint.lightened(0.14))
			_part(parent, "Dome", CourtBuilder.ball_mesh(r * 0.85, 12), Vector3(x, h - 0.22, 0.0), tint.lightened(0.05), 1.0, true, Vector3.ZERO, Vector3(1.0, 0.75, 1.0))
			_part(parent, "Spire", CourtBuilder.cyl_mesh(0.02, 0.20), Vector3(x, h + 0.14, 0.0), tint.lightened(0.30))
		"palm":
			# A date palm: trunk plus a fan of flattened cones, alternating shades.
			var frond_l := h * 0.55
			var frond_angles := [-118.0, -88.0, -60.0, -32.0, 32.0, 60.0, 88.0, 118.0]
			_part(parent, "Trunk", CourtBuilder.cyl_mesh(maxf(h * 0.045, 0.03), h, 10), Vector3(x, h * 0.5, 0.0), tint.darkened(0.50))
			for i in frond_angles.size():
				var frond_a := deg_to_rad(float(frond_angles[i]))
				var fl := frond_l * (0.86 + 0.03 * float(i % 3))
				_part(parent, "Frond%d" % i, CourtBuilder.cone_mesh(fl * 0.42, fl),
					Vector3(x + cos(frond_a) * fl * 0.45, h + sin(frond_a) * fl * 0.42, 0.02 * float(i % 2) - 0.01),
					tint if i % 2 == 0 else tint.lightened(0.08), 1.0, false,
					Vector3(0.0, 0.0, rad_to_deg(frond_a) - 90.0), Vector3(1.0, 1.0, 0.22))
		"ridge":
			# A low-poly ridge: a chain of prisms tapering to both sides, optionally
			# hazed (the deck's far blue-green ridgeline).
			var peaks := int(_size(prop, "count", 4.0))
			var spread := _size(prop, "spread", 1.5)
			var haze := _size(prop, "alpha", 1.0)
			for i in peaks:
				var pk := float(i) - float(peaks - 1) * 0.5
				var pr := r * (1.0 - 0.20 * absf(pk))
				_peak(parent, "Peak%d" % i, Vector3(x + pk * spread * r, 0.0, 0.0), pr, pr * 1.65, tint, haze)
		"peak":
			# Sugarloaf: a rounded granite dome on a skirt, with an optional twin.
			_part(parent, "Skirt", CourtBuilder.cone_mesh(r * 1.12, r * 0.90, 10), Vector3(x, r * 0.45, 0.0), tint.darkened(0.18))
			_part(parent, "Dome", CourtBuilder.ball_mesh(r, 14), Vector3(x, r * 1.30, 0.0), tint, 1.0, true, Vector3.ZERO, Vector3(1.0, 1.20, 1.0))
			var twin := _size(prop, "twin", 0.0)
			if twin > 0.0:
				var twin_x := _size(prop, "twin_x", r * 2.4)
				_part(parent, "TwinSkirt", CourtBuilder.cone_mesh(r * twin, r * twin * 0.90, 9), Vector3(x + twin_x, r * twin * 0.45, 0.0), tint.lightened(0.05))
				_part(parent, "TwinDome", CourtBuilder.ball_mesh(r * twin, 12), Vector3(x + twin_x, r * twin * 1.30, 0.0), tint.lightened(0.08), 1.0, true, Vector3.ZERO, Vector3(1.0, 1.15, 1.0))
		"foam":
			# Wave foam: flattened rings lying on the sand. A full ring, not the
			# deck's half-crescent: the ground cannot occlude half of it cleanly
			# (the ground is lit, an occluder would not match it). Recorded, not
			# hidden — see the evidence note in `docs/mission/world-arenas/`.
			var rings := int(_size(prop, "count", 3.0))
			for i in rings:
				var ring_r := r * (1.0 - 0.24 * float(i))
				_part(parent, "Foam%d" % i, CourtBuilder.ring_mesh(ring_r * 0.84, ring_r, 24),
					Vector3(x + r * 0.55 * float(i), 0.03, 0.0), tint, 0.85, true, Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
		"cable":
			# The cable-car line: a thin span and its car.
			var span := _size(prop, "w", 3.6)
			var sag := _size(prop, "lean", 2.0)
			_part(parent, "Cable", CourtBuilder.box_mesh(Vector3(span, 0.03, 0.03)), Vector3(x, y, 0.0), tint, 1.0, true, Vector3(0.0, 0.0, sag))
			_part(parent, "Hanger", CourtBuilder.box_mesh(Vector3(0.02, 0.14, 0.02)), Vector3(x, y - 0.07, 0.0), tint)
			_part(parent, "Car", CourtBuilder.box_mesh(Vector3(0.30, 0.18, 0.16)), Vector3(x, y - 0.22, 0.0), ctx["glow"], 1.0)
		"basalt":
			# A basalt colonnade: hexagonal prisms of varying heights with pale caps.
			var columns := int(_size(prop, "count", 7.0))
			var heights := [1.0, 0.72, 0.90, 0.62, 0.96, 0.78, 0.68, 0.86]
			var cap_col := Color(0.80, 0.86, 0.93)
			for i in columns:
				var col_hf := float(heights[i % heights.size()])
				var col_r := r * (0.85 + 0.08 * float((i * 3) % 4))
				var col_x := x + (float(i) - float(columns - 1) * 0.5) * r * 0.92
				_part(parent, "Column%d" % i, CourtBuilder.cyl_mesh(col_r, h * col_hf, 6), Vector3(col_x, h * col_hf * 0.5, 0.0), tint)
				_part(parent, "Cap%d" % i, CourtBuilder.cyl_mesh(col_r * 0.94, 0.05, 6), Vector3(col_x, h * col_hf + 0.02, 0.0), cap_col, 0.95)
		"snowridge":
			# A ridge with snow on its crests: the deck's snow-capped line.
			# REFINEMENT (round-2 review, aurora only): at capture size the old caps
			# read as barely-lit specks against the night sky. LOCAL change only —
			# the rock is lifted one step, the caps cover more of each crest and are
			# brighter. No z change (the container stays behind the rear glass at
			# its table z), no camera edit, and `_peak` — shared with carioca's
			# `ridge` — is untouched, so carioca's frame is byte-identical.
			var crests := int(_size(prop, "count", 4.0))
			for i in crests:
				var crest := float(i) - float(crests - 1) * 0.5
				var crest_r := r * (0.90 - 0.15 * absf(crest))
				var crest_h := crest_r * 1.70
				var crest_x := x + crest * 1.5 * r
				_peak(parent, "Ridge%d" % i, Vector3(crest_x, 0.0, 0.0), crest_r, crest_h, tint.lightened(0.06))
				_peak(parent, "Snow%d" % i, Vector3(crest_x, crest_h * 0.56, 0.03), crest_r * 0.52, crest_h * 0.46, Color(0.90, 0.94, 0.98))
		"steam":
			# A geyser plume: translucent puffs rising and fading.
			for i in 4:
				var puff := float(i)
				_part(parent, "Puff%d" % i, CourtBuilder.ball_mesh(r * (0.70 + 0.26 * puff), 12),
					Vector3(x + 0.42 * r * puff * (1.0 if i % 2 == 0 else -1.0), y + puff * r * 0.90, 0.02 * puff),
					tint, 0.50 - 0.08 * puff)
		"island":
			# Whitewashed cubes cascading down a dark cliff, with cobalt domes.
			var steps := 5
			_part(parent, "Cliff", CourtBuilder.box_mesh(Vector3(r * 6.2, h * 0.50, r * 0.90)), Vector3(x, h * 0.25, -0.30), tint.darkened(0.55))
			for i in steps:
				var step := float(i)
				var block_x := x + (step - float(steps - 1) * 0.5) * r * 1.05
				var block_h := h * (1.0 - 0.15 * step)
				var block_w := r * (0.95 - 0.09 * step)
				_part(parent, "House%d" % i, CourtBuilder.box_mesh(Vector3(block_w, block_h, r * 0.70)),
					Vector3(block_x, block_h * 0.5, 0.0), tint.darkened(0.04 * float(i % 2)))
				if i % 2 == 0:
					_part(parent, "Dome%d" % i, CourtBuilder.ball_mesh(block_w * 0.30, 12),
						Vector3(block_x, block_h + block_w * 0.06, 0.0), ctx["accent"], 1.0, true, Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
		"windmill":
			# The deck's windmill: a white tower, a dark cap and two crossed sails.
			_part(parent, "Tower", CourtBuilder.cyl_mesh(r, h, 12), Vector3(x, h * 0.5, 0.0), tint)
			_part(parent, "Cap", CourtBuilder.cone_mesh(r * 1.16, r * 0.90, 12), Vector3(x, h + r * 0.45, 0.0), Color(0.23, 0.29, 0.42))
			_part(parent, "Hub", CourtBuilder.ball_mesh(r * 0.20, 10), Vector3(x, h * 0.86, r * 0.55), ctx["accent"])
			for i in 2:
				var sail := 25.0 + float(i) * 90.0
				var sail_a := deg_to_rad(sail)
				_part(parent, "Sail%d" % i, CourtBuilder.box_mesh(Vector3(0.05, r * 1.80, 0.03)),
					Vector3(x + sin(sail_a) * r * 1.05, h * 0.86 + cos(sail_a) * r * 1.05, r * 0.55),
					Color(0.95, 0.96, 0.98), 1.0, true, Vector3(0.0, 0.0, -sail))
		"bougainvillea":
			# Magenta bloom spilling over a whitewashed block.
			var blooms := [[-1.15, 1.45], [-0.55, 1.75], [0.10, 1.60], [0.70, 1.80], [1.15, 1.40], [0.35, 1.35]]
			_part(parent, "Block", CourtBuilder.box_mesh(Vector3(r * 3.0, r * 1.8, r * 1.1)), Vector3(x, r * 0.9, -0.06), Color(0.93, 0.95, 0.98))
			for i in blooms.size():
				var bloom: Array = blooms[i]
				_part(parent, "Bloom%d" % i, CourtBuilder.ball_mesh(r * (0.34 + 0.05 * float(i % 3)), 10),
					Vector3(x + float(bloom[0]) * r, float(bloom[1]) * r, 0.12), tint)
		"sea":
			# The caldera: a band that fades from the horizon light to deep water,
			# with three flat wave strokes in front of it.
			var water := CourtBuilder.gradient_texture([
				[0.00, Color(0.81, 0.89, 0.96)],
				[0.28, Color(0.44, 0.62, 0.85)],
				[1.00, Color(0.11, 0.25, 0.49)],
			], 64)
			CourtBuilder.textured_quad(parent, "Sea", Vector2(w, h), Vector3(x, y, 0.0), water)
			for i in 3:
				_part(parent, "Wave%d" % i, CourtBuilder.box_mesh(Vector3(w * 0.42, 0.02, 0.05)),
					Vector3(x + w * 0.14 * (float(i) - 1.0), y + h * (0.18 + 0.20 * float(i)), 0.06), Color(0.91, 0.95, 0.98), 0.55)
		_:
			_part(parent, "Spark", CourtBuilder.box_mesh(Vector3(0.07, 0.07, 0.07)), Vector3(x, y, 0.0), ctx["glow"], 0.9)


static func name_of(kind: String, index: int) -> String:
	return "%s%d" % [kind.capitalize(), index]


## A gear: a ring with teeth and a hub, facing the camera (the reference's
## `drawGear`, used by four arenas).
static func _gear(parent: Node3D, kind: String, pos: Vector3, r: float, tint: Color) -> void:
	_part(parent, name_of(kind, 1), CourtBuilder.ring_mesh(r * 0.55, r, 22), pos, tint, 1.0, true, Vector3(90.0, 0.0, 0.0))
	_part(parent, name_of(kind, 2), CourtBuilder.cyl_mesh(r * 0.34, 0.1, 14), pos, tint, 1.0, true, Vector3(90.0, 0.0, 0.0))
	for i in 8:
		var ang := deg_to_rad(float(i) * 45.0)
		_part(parent, "%sTooth%d" % [kind, i], CourtBuilder.box_mesh(Vector3(0.1, r * 0.22, 0.09)),
			pos + Vector3(sin(ang) * r * 1.02, cos(ang) * r * 1.02, 0.0), tint, 1.0, true, Vector3(0.0, 0.0, rad_to_deg(ang)))
