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
extends RefCounted

const Court := preload("res://game/court.gd")
const CourtBuilder := preload("res://game/arenas/court_builder.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")

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
	#    paint rather than a lit surface.
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

	# 3. The apron: the ground beyond the cage, in this arena's own exterior tone.
	var apron := Color(String(style.get("apron", "#3a4a55")))
	CourtBuilder.unshaded(root, "BackdropApron", CourtBuilder.box_mesh(Vector3(half_x * 2.0, APRON_H, 0.08)),
		Vector3(0.0, APRON_H * 0.5, BACKDROP_Z + 0.05), apron)

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
	}
	var props: Array = style.get("props", [])
	for i in props.size():
		var prop: Dictionary = props[i]
		var kind := String(prop.get("kind", "spark"))
		var container := Node3D.new()
		container.name = "Dressing_%s%d" % [kind, i + 1]
		container.position = Vector3(float(prop.get("x", 0.0)) * x_scale, 0.0, float(prop.get("z", -7.65)) - 4.0)
		container.set_meta("kind", kind)
		root.add_child(container)
		_build_prop(container, prop, ctx)
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
			# js/render.js:719-722.
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
