## trees.gd — the arena's trees, as a generated model instead of a cone and two balls.
##
## WHY THIS EXISTS. The reference draws its trees as flat canvas shapes
## (`js/render.js:719-722`), and the port transcribed them literally: a cylinder
## trunk plus two spheres (`arena_scenery.gd`'s `"tree"` branch). The owner asked
## for a real model in their place.
##
## WHY THIS MODEL AND NOT HIS DOWNLOADS. The two trees he downloaded from Meshy's
## public library measured **4,460,372** and **9,995,757** triangles (203 MB and
## 402 MB). Neither would simplify: `gltf-transform weld + simplify` bottomed out at
## 1,226,252 and 2,130,290 triangles at every ratio from 2% down to 0.08% and every
## error up to 0.5, with borders unlocked. The reason is structural — a tree is
## thousands of separate leaf islands, and an edge-collapse simplifier has no
## interior edges to collapse on a two-triangle island. Draco cut the FILE to 15-20 MB
## but the triangles are what the GPU draws, and two trees would have been 2.45M of
## them against the whole scene's 1.11M.
##
## So the tree was generated instead, in Meshy's **smart-topology** mode, where
## `target_polycount` is the generation's own budget rather than a decimation target:
## **9,164 triangles**, 4.4 MB, one 2048² base-colour texture, 15 credits
## (`assets/trees/stylized-tree.meshy-task.json` holds the task ids). Two trees now
## cost 18,328 triangles — 0.75% of what his download would have cost.
##
## THE TRAP THIS FILE HANDLES. Meshy does not put the origin at the feet: this model
## is centred on its own middle (`min_y = -0.5` of a 1.0 m box), so a copy placed at
## `y = 0` is buried to half its height. The lift is measured off the loaded scene
## (`unit_box`), never a hand-copied constant — the same rule `bleachers.gd` follows.
##
## PRESENTATION ONLY. Nothing here is read by the simulation.
extends RefCounted

const Court := preload("res://game/court.gd")

const GLB_PATH := "res://assets/trees/stylized-tree.glb"

## One copy as loaded, measured with `scripts/glb_report.py` and re-measured off the
## loaded mesh by `triangle_count()`.
const TRIANGLES := 9164

## Off switch for the A/B cost measurement; the game never writes it. With it off the
## trees are not built at all — no load, no draw.
static var enabled := true

## What the last `build()` placed, for the boot log and the evidence. Plain values
## only: a Resource or Node held in a `static var` would outlive the scene tree and
## the engine would report the texture as leaked at exit.
static var report: Dictionary = {}


## Places ONE tree inside a prop container that the scenery has already positioned
## (`Dressing_treeN`, carrying the table's x scaled to the camera's frame and the
## band's z). Returns false when the model cannot be loaded, so the caller can draw
## the reference's flat version instead and leave no arena undressed.
##
## `target_h` is the height the reference's own prop table asked for: the model is
## 1.0 m tall as authored, so it is scaled to that and the art direction is unchanged.
static func place_one(container: Node3D, target_h: float) -> bool:
	var base := _shared_scene()
	if base == null:
		return false
	var box := _shared_box
	if box.size.y <= 0.0:
		return false
	var body: Node3D = base.duplicate() as Node3D
	var s := target_h / box.size.y
	body.scale = Vector3(s, s, s)
	# Meshy centres this model on its own middle (`min_y = -0.5` of a 1.0 m box), so a
	# copy dropped at y = 0 is buried to half its height. The lift is measured off the
	# loaded scene, never a hand-copied constant.
	body.position = Vector3(0.0, -box.position.y * s, 0.0)
	body.name = "TreeModel"
	container.add_child(body)
	_placed += 1
	report = {
		"instances": _placed,
		"glb_loads": _loads,
		"triangles": _placed * TRIANGLES,
		"load_ms": _load_ms,
		"box": box,
		"error": "",
	}
	return true


## Drops the cached scene. Called by the scenery when an arena finishes building, so
## no Resource outlives the arena in a `static var` (the engine reports that as a leak
## at exit — the defect `check_log.sh` names for `outfit_catalogue.gd`).
static func release() -> void:
	if _shared != null:
		_shared.free()
		_shared = null
	if _placed > 0:
		print("TREES glb=%s glb_loads=%d load_ms=%d instances=%d tris_per_copy=%d tris_total=%d box=(%.4f,%.4f,%.4f)+(%.4f,%.4f,%.4f)" % [
			GLB_PATH, _loads, _load_ms, _placed, TRIANGLES, _placed * TRIANGLES,
			_shared_box.position.x, _shared_box.position.y, _shared_box.position.z,
			_shared_box.size.x, _shared_box.size.y, _shared_box.size.z,
		])
	_placed = 0


static var _shared: Node3D = null
static var _shared_box := AABB()
static var _loads := 0
static var _load_ms := 0
static var _placed := 0


## The one loaded copy every tree duplicates: one read, N draws, mesh and texture
## shared. Not a `preload`: the arena decides whether trees are wanted at all.
static func _shared_scene() -> Node3D:
	if not enabled:
		return null
	if _shared != null:
		return _shared
	if not ResourceLoader.exists(GLB_PATH):
		report = {"instances": 0, "glb_loads": 0, "triangles": 0, "error": "missing: " + GLB_PATH}
		return null
	var started := Time.get_ticks_msec()
	var packed := load(GLB_PATH) as PackedScene
	if packed == null:
		report = {"instances": 0, "glb_loads": 0, "triangles": 0, "error": "not a scene: " + GLB_PATH}
		return null
	_shared = packed.instantiate() as Node3D
	_load_ms = Time.get_ticks_msec() - started
	_loads += 1
	_shared_box = unit_box(_shared)
	return _shared


## The unit's own box in the loaded scene's local space.
static func unit_box(scene: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := mi as MeshInstance3D
		if instance.mesh == null:
			continue
		var b: AABB = instance.transform * instance.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## How many triangles one copy draws — measured off the loaded mesh, not the file's
## table. The evidence quotes this number.
static func triangle_count(scene: Node) -> int:
	var tris := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		tris += mesh.get_faces().size() / 3
	return tris
