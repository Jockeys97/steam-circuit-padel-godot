extends SceneTree
## bleacher_lod_probe.gd — how far Godot's own LOD generator can lighten the bleacher
## unit (2026-10-01). The import has `generate_lods=false`, so every copy draws all
## 459,928 triangles at any distance. This builds the LODs at runtime from the same
## mesh (ImporterMesh.generate_lods, the importer's own code path) and prints each
## level's triangle count, then saves the levels near TARGETS as .res meshes for the
## visual comparison (`bleacher_lod_capture.gd`).
##
## Needs a renderer (mesh arrays are empty under --headless):
##   godot --path godot --script res://game/tools/bleacher_lod_probe.gd

var GLB := "res://assets/bleachers/Meshy_AI_Blue_Canopy_Bleachers_0917000231_texture.glb"
## `-- --glb=res://... --tag=shelter --ship=0` bakes the levels of another model and
## skips the shipped bleacher mesh.
var TAG := "bleacher"
var SHIP := true
const OUT_DIR := "user://bleacher_lod/"
var TARGETS := [120000, 50000, 20000]
## The level shipped to the game (`bleachers.gd`): compacted to the vertices it uses.
var SHIP_LEVEL := 3
var SHIP_PATH := "res://assets/bleachers/bleachers_light.res"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--glb="):
			GLB = a.substr(6)
		elif a.begins_with("--tag="):
			TAG = a.substr(6)
		elif a.begins_with("--targets="):
			TARGETS = []
			for t in a.substr(10).split(","):
				TARGETS.append(int(t))
		elif a.begins_with("--ship-level="):
			SHIP_LEVEL = int(a.substr(13))
		elif a.begins_with("--ship-path="):
			SHIP_PATH = a.substr(12)
		elif a.begins_with("--ship="):
			SHIP = a.substr(7) != "0"
	var scene := (load(GLB) as PackedScene).instantiate()
	var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var src := mi.mesh as ArrayMesh
	var arrays := src.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	print("BLEACHER_LOD original triangles=%d vertices=%d" % [indices.size() / 3, (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, src.surface_get_material(0))
	im.generate_lods(60.0, 25.0, [])
	var lods := im.get_surface_lod_count(0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var levels := []
	for i in lods:
		var tri := im.get_surface_lod_indices(0, i).size() / 3
		print("BLEACHER_LOD level %d size=%.4f triangles=%d" % [i, im.get_surface_lod_size(0, i), tri])
		levels.append([i, tri])
	for target in TARGETS:
		var best := -1
		for l in levels:
			if best < 0 or absi(int(l[1]) - target) < absi(int(levels[best][1]) - target):
				best = int(l[0])
		if best < 0:
			continue
		var a := arrays.duplicate()
		a[Mesh.ARRAY_INDEX] = im.get_surface_lod_indices(0, best)
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(0, src.surface_get_material(0))
		var path := OUT_DIR + "%s_%dk.res" % [TAG, target / 1000]
		ResourceSaver.save(m, path)
		print("BLEACHER_LOD saved target=%d -> level %d (%d triangles) %s" % [target, best, int(levels[best][1]), ProjectSettings.globalize_path(path)])
	if SHIP:
		_ship(arrays, im.get_surface_lod_indices(0, SHIP_LEVEL), src.surface_get_material(0))
	quit(0)


## Keeps only the vertices the level's triangles use, so the shipped mesh carries
## ~1/10 of the original vertex data instead of all 271,287 vertices.
func _ship(arrays: Array, lod_indices: PackedInt32Array, material: Material) -> void:
	var remap := {}
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	new_idx.resize(lod_indices.size())
	for i in lod_indices.size():
		var old := lod_indices[i]
		if not remap.has(old):
			remap[old] = order.size()
			order.append(old)
		new_idx[i] = remap[old]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for t in Mesh.ARRAY_MAX:
		var a = arrays[t]
		if a == null or t == Mesh.ARRAY_INDEX:
			continue
		var per := 4 if t == Mesh.ARRAY_TANGENT else 1
		var n := order.size() * per
		var b = a.duplicate()
		b.resize(n)
		for v in order.size():
			for k in per:
				b[v * per + k] = a[order[v] * per + k]
		out[t] = b
	out[Mesh.ARRAY_INDEX] = new_idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	m.surface_set_material(0, material)
	ResourceSaver.save(m, SHIP_PATH, ResourceSaver.FLAG_COMPRESS)
	print("BLEACHER_LOD shipped level %d: %d triangles, %d vertices -> %s" % [SHIP_LEVEL, new_idx.size() / 3, order.size(), SHIP_PATH])
