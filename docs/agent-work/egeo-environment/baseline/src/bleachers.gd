## bleachers.gd — the owner's tribunes, along the TWO side lines of the court.
##
## THE VERDICT THIS IMPLEMENTS (owner, 2026-09-17): *"li metterei qui ai lati del
## campo"* — one stand on each side, **outside the side glass**, rows rising away
## from the glass, seats facing the court, filling the empty floor strip between
## the side glass and the hall wall. NOT behind the rear backdrop, where the rest
## of the hall dressing stands.
##
## WHY THE SIDES WORK AT ALL. The side glass is 3.0 m tall and the camera looks
## down at ~36 deg, so it hides only about a metre of floor beyond it: everything
## past `x = +-6.5` is seen OVER the glass panes, on the open floor. A stand whose
## front face sits `CORRIDOR_M` behind the glass therefore reads as a tribune
## beyond the glass, without standing in front of it.
##
## THE ASSET. One Meshy unit, `Meshy_AI_Blue_Canopy_Bleachers_..._texture.glb`:
## one node, one mesh, no skins, no animations, **459,928 triangles** / 271,287
## vertices, 3 JPEG textures (4096^2 base colour, 2048^2 metallic-roughness,
## 4096^2 normal), 31.1 MB. As authored it is a bench with a canopy, 1.903 m wide
## (x) x 0.957 m tall (y) x 0.961 m deep (z), and it sits **half a metre below its
## own origin** (`min_y = -0.4868`): it is lifted by its own measured box, never by
## a hand-copied offset.
##
## Facing: measured off the mesh's own height field, the seating deck slopes down
## towards local +z and the canopy stands at local -z. So the unit faces **+Z** and
## a copy on the right-hand side is yawed -90 deg (local +Z -> world -X, towards the
## court), one on the left +90 deg.
##
## COST. Every copy is a full 459,928-triangle draw and this is the OpenGL
## (`gl_compatibility`) renderer, so the number of copies is the whole cost model:
## see `docs/wayfinder/evidence/arena-bleachers.md` for the measured frame times.
## The scene is loaded ONCE (`_base`) and duplicated per copy, so the mesh and its
## textures are shared — the copies cost draw calls, not memory.
##
## PRESENTATION ONLY. Nothing here is read by the simulation: it is geometry placed
## from `Court.half_len()` and the model's own box.
extends RefCounted

const Court := preload("res://game/court.gd")

## The owner's model, copied verbatim into the tracked runtime tree.
const GLB_PATH := "res://assets/bleachers/Meshy_AI_Blue_Canopy_Bleachers_0917000231_texture.glb"

## One copy as authored, measured from the file itself (one mesh, one primitive).
const TRIANGLES := 459928
const VERTICES := 271287

## The unit's own width along its local X, in metres, as authored (the box the
## loaded mesh reports; `span_z()` multiplies it by the scale and the copy count so
## the neighbours can place themselves without a second GLB read).
const UNIT_WIDTH_M := 1.903
## The unit's own height and depth along its local Y and Z, same source and same
## reason: whatever sits ON the stands (`arena_props.gd` beside them, `crowd.gd` on
## their seating) needs the raked box without loading the GLB a second time.
const UNIT_HEIGHT_M := 0.957
const UNIT_DEPTH_M := 0.961

## Uniform scale of one copy. The unit is 1.9 m wide as authored — a bench, not a
## tribune — and the camera reads the stands from ~30 m away at ~36 px/m, where a
## 2048-4096 px texture is already two decades past what the frame can resolve:
## stretching texels 3x costs nothing the eye can find, and one SCALED copy is
## three copies' worth of triangles cheaper than three unscaled ones.
##
## `scale` and `copies_per_side` are the PROPOSAL's two knobs — the placement and
## the size are the owner's verdict, and `game/tools/bleachers_probe.gd` varies both
## to measure what each costs. `static var`, not `const`, for exactly that reason.
static var scale := 3.15
## Copies per side, laid end to end along the court's length. One at scale 3.15
## covers 6.0 m of each 20 m side line, centred on the net; two cover 11.9 m and
## cost another 459,928 triangles EACH. The file rests on ONE — the measured
## frame-time and triangle table in `docs/wayfinder/evidence/arena-bleachers.md`
## is what put it there, and it is one line to overrule.
static var copies_per_side := 1
## How many side lines carry stands: 2 (both sides, the owner's ask) or 1 (the
## single-sided alternative, measured and shown in the evidence in case the
## symmetric hall reads as a doubled arena).
static var sides := 2
## Clear floor between the side glass and the stand's front edge. A service
## corridor has to exist to walk the outside of the cage; 1.2 m also puts the
## stand's foot just past the metre of floor the side glass hides.
const CORRIDOR_M := 1.2
## Shadow casting: OFF by measurement, after the owner said the frame rate felt
## worse and was right.
##
## A contact shadow is what makes a prop look grounded, so this was switched ON once
## on the strength of a 1.4 fps reading. That reading was noise: it came from
## separate processes on a loaded machine, where repeating the SAME configuration
## swung between 35 and 64 fps. Re-measured by alternating the shadow pass inside one
## process — both arms then meet the same background load, so the difference survives
## a busy machine even when the absolute number does not — it costs 15.6 fps of 94.6,
## just under 20%, consistent across three runs (-16.7, -13.2, -15.0).
##
## Twenty percent of the frame rate is not what a contact shadow is worth. The
## grounding problem is real and wants a cheaper answer (a blob decal under each
## footprint costs one quad, not a shadow pass over 919,856 triangles).
##
## Re-price it with `--ab=shadow` on `game/tools/bleachers_probe.gd`, which is the
## only form of this measurement that can be trusted on a machine doing other work.
static var cast_shadow := false
## The material every copy draws with. `"imported"` is the model's own glTF PBR
## material (base colour + metallic-roughness + normal, the textures the owner
## paid for); `"plain"` replaces it with the base colour alone, which is the
## cheapest thing that still looks like the model. Measured, not assumed: see the
## evidence's cost table.
static var material_mode := "imported"
static var _plain_material: StandardMaterial3D = null

## A/B switch for the cost measurement (`game/tools/bleachers_probe.gd`): the game
## never writes it. With it off the stands are not built at all — no load, no draw.
static var enabled := true
## What the last `build()` loaded and placed, for the boot log and the evidence.
## A Dictionary of plain values only: nothing here may hold a Resource or a Node, or
## a static var would outlive the scene tree and the engine would report the
## stands' textures as leaked at exit — the defect `check_log.sh` names for
## `outfit_catalogue.gd`'s cached Shader. The loaded scene is duplicated per copy
## and freed here (the copies share its Mesh and textures, which die with the
## arena), so the stands own no state outside the tree.
static var report: Dictionary = {}


## Adds the stands to an arena root. Returns the group node (always non-null: an
## unreadable GLB leaves the arena exactly as it was and is reported, not raised).
static func build(parent: Node3D) -> Node3D:
	var group := Node3D.new()
	group.name = "Bleachers"
	parent.add_child(group)
	report = {"instances": 0, "glb_loads": 0, "load_ms": 0, "error": ""}
	if not enabled or copies_per_side <= 0:
		report["error"] = "disabled" if not enabled else "no copies"
		return group
	var started := Time.get_ticks_msec()
	var base := _load_scene()
	report["glb_loads"] = 1
	if base == null:
		report["error"] = "load failed: " + GLB_PATH
		return group
	var box := unit_box(base)
	report["load_ms"] = Time.get_ticks_msec() - started
	report["box"] = box
	var plain: StandardMaterial3D = null
	if material_mode == "plain":
		plain = plain_material(base)
	var width := box.size.x * scale
	var depth := box.size.z * scale
	var height := box.size.y * scale
	# The stand's front face stands CORRIDOR_M clear of the glass; its own box says
	# how far the seating reaches back from there.
	var front_x := Court.half_len() + CORRIDOR_M
	var centre_x := front_x + depth * 0.5
	var copy := 0
	for side in ([1.0, -1.0] as Array).slice(0, sides):
		for i in copies_per_side:
			var z := (float(i) - float(copies_per_side - 1) * 0.5) * width
			var stack := Node3D.new()
			stack.name = "Bleacher%s%d" % ["R" if side > 0.0 else "L", i + 1]
			stack.position = Vector3(centre_x * side, 0.0, z)
			# local +Z (the seating) faces the court on both sides.
			stack.rotation_degrees = Vector3(0.0, -90.0 * side, 0.0)
			stack.scale = Vector3(scale, scale, scale)
			# The copy shares the loaded scene's Mesh and textures: one 31 MB read,
			# N draws. The loaded scene itself is freed right after the last copy.
			var body: Node = base.duplicate()
			# the unit's own min_y is negative: lift it onto the floor it stands on.
			body.position = Vector3(0.0, -box.position.y, 0.0)
			_prepare(body, plain)
			stack.add_child(body)
			group.add_child(stack)
			copy += 1
	base.free()
	report["instances"] = copy
	report["triangles"] = copy * TRIANGLES
	report["side_x"] = centre_x
	report["front_x"] = front_x
	report["span_z"] = (float(copies_per_side) * width)
	report["height_m"] = height
	print("BLEACHERS glb=%s glb_loads=1 load_ms=%d instances=%d tris_per_copy=%d tris_total=%d scale=%.2f corridor_m=%.2f glass_x=%.2f front_x=%.2f side_x=%.2f height_m=%.2f span_z=%.2f box=(%.4f,%.4f,%.4f)+(%.4f,%.4f,%.4f)" % [
		GLB_PATH, int(report["load_ms"]), copy, TRIANGLES, copy * TRIANGLES, scale, CORRIDOR_M,
		Court.half_len(), front_x, centre_x, height, float(report["span_z"]),
		box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z,
	])
	return group


## How far the stands reach along the side line, in metres. Whatever stands NEXT to
## them (`arena_props.gd` puts the shelters there) needs this to know where their
## span ends, and reading it from the loaded box every time would mean a second GLB
## read for a number the scale and the unit width already decide.
static func span_z() -> float:
	return float(copies_per_side) * UNIT_WIDTH_M * scale


## The unit's own box, in the scene root's local space, measured off the loaded
## scene (the glTF root node is identity, so this is the mesh's box).
static func unit_box(scene: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := mi as MeshInstance3D
		var b: AABB = instance.transform * instance.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## How many triangles one copy of the loaded scene draws — measured off the loaded
## mesh, not off the file's table (the evidence quotes this number).
static func triangle_count(scene: Node) -> int:
	var tris := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		tris += mesh.get_faces().size() / 3
	return tris


## Marks every mesh of a copy: shadow casting decides whether the copy pays for a
## second draw pass, `plain` (when the measurement asks for it) replaces the model's
## own PBR material with the base colour alone. The material is built by `build()`
## and passed in: a material cached in a `static var` would hold its texture past
## the scene tree and be reported as leaked at exit.
static func _prepare(node: Node, plain: StandardMaterial3D) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mi as MeshInstance3D
		if not cast_shadow:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if plain != null:
			instance.material_override = plain


## The base colour of the model's own material, worn without the normal map and
## the metallic-roughness samplers. Built per build and shared by that build's
## copies.
static func plain_material(scene: Node) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.85
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var src := mesh.surface_get_material(0) as StandardMaterial3D
		if src != null:
			m.albedo_texture = src.albedo_texture
			m.albedo_color = src.albedo_color
			break
	return m


## Reads the GLB the way the athlete rigs are read (`court.gd::load_athlete_scene`):
## `GLTFDocument` + `GLTFState` at runtime, which is also what makes the load show
## up in the boot log's `glb_loads` count.
static func _load_scene() -> Node:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(GLB_PATH, st)
	if err != OK:
		push_error("bleachers.gd: GLB append failed err=%d path=%s" % [err, GLB_PATH])
		return null
	var scene: Node = doc.generate_scene(st)
	if scene == null:
		push_error("bleachers.gd: GLB generate_scene returned null")
		return null
	return scene
