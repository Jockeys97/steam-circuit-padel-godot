extends Node3D
## roster_review.gd — the four athlete meshes side by side, under the match camera.
##
## Why it exists: nobody had ever looked at these models in engine, and the triangle
## band in docs/art/character-standard.md (15,000-25,000) was frozen from measured
## file numbers alone. Colosso ships 8,928 triangles, Oracolo 45,406 — a factor of 5.
## This scene answers the only question that settles the band: at the framing the game
## actually uses, does the difference read?
##
## Deliberately it does NOT go through AthleteRig / athlete_spawn.gd. Fiamma and
## Oracolo are `generato` in docs/art/roster-3d.json, not game assets, and promoting
## them into ATHLETE_GLB to look at them would be exactly the shortcut the standard
## forbids. Each GLB is loaded and instantiated directly instead, so no game code path
## changes and res://prototypes/* keeps them out of every export preset.
##
## Run: godot/prototypes/roster_review/run.sh
## Writes two PNGs plus one measurement line per athlete to
## godot/prototypes/roster_review/out/.

## Camera preset "default" of game/court.gd: the provisional match camera.
const CAM_MATCH := {
	"pos": Vector3(0.0, 14.4552, 6.4000),
	"fov": 50.866,
	"look_at": Vector3.ZERO,
}
## Eye-level inspection framing. Not a game camera: it exists to show silhouette and
## texture detail the match camera is too far away to reveal.
const CAM_CLOSE := {
	"pos": Vector3(0.0, 1.5000, 5.2000),
	"fov": 40.000,
	"look_at": Vector3(0.0, 1.0000, 0.0000),
}

const BG := Color(0.2196, 0.2392, 0.2784)   # same grey as roster_render.gd
const SPACING := 1.6                        # metres between athletes, left to right
const HOLD_CLIP := "Walking"                # a moving pose reads better than a T/A-pose
const HOLD_TIME := 0.45

const SUBJECTS := [
	{"id": "colosso", "glb": "res://assets/athletes/colosso.glb"},
	{"id": "fiamma", "glb": "res://prototypes/roster_review/assets/fiamma.glb"},
	{"id": "oracolo", "glb": "res://prototypes/roster_review/assets/oracolo.glb"},
	{"id": "volpe", "glb": "res://assets/athletes/volpe-walking.glb"},
]

var _cam: Camera3D
var _out_dir := "res://prototypes/roster_review/out"


func _ready() -> void:
	print("ROSTER_REVIEW_START")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_build_world()
	await _capture("match", CAM_MATCH)
	await _capture("close", CAM_CLOSE)
	print("ROSTER_REVIEW_PASS")
	get_tree().quit(0)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.4
	add_child(sun)

	# A neutral floor, so the feet have something to stand on and the eye gets scale.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 24.0)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.18, 0.21)
	floor_mesh.material_override = mat
	add_child(floor_mesh)

	_cam = Camera3D.new()
	add_child(_cam)

	var start := -SPACING * (SUBJECTS.size() - 1) * 0.5
	for i in SUBJECTS.size():
		_place(SUBJECTS[i], start + SPACING * i)


func _place(subject: Dictionary, x: float) -> void:
	var packed: PackedScene = load(subject["glb"])
	if packed == null:
		printerr("MISSING %s (%s)" % [subject["id"], subject["glb"]])
		return
	var model: Node3D = packed.instantiate()
	add_child(model)
	model.position = Vector3(x, 0.0, 0.0)
	# These exports already face +Z, i.e. towards the camera: rotating them 180 deg
	# (the first attempt) lines up four backs instead of four faces.
	model.rotation_degrees = Vector3.ZERO

	var clip := _hold_pose(model)
	var tris := _triangles(model)
	var size := _world_size(model)
	# One line per athlete: the numbers the band decision needs, measured in engine
	# rather than read off the file.
	print("ATHLETE %s triangles=%d height_m=%.3f width_m=%.3f clip=%s" % [
		subject["id"], tris, size.y, size.x, clip])


## Freezes every model at the same moment of the same kind of clip, so the comparison
## is of meshes and not of poses. Volpe's legacy export carries one unnamed clip.
func _hold_pose(model: Node3D) -> String:
	var player: AnimationPlayer = null
	for child in model.find_children("*", "AnimationPlayer", true, false):
		player = child
		break
	if player == null:
		return "-"
	var chosen := ""
	for name in player.get_animation_list():
		if name == HOLD_CLIP or name.to_lower().contains("walk"):
			chosen = name
			break
	if chosen == "" and player.get_animation_list().size() > 0:
		chosen = player.get_animation_list()[0]
	if chosen == "":
		return "-"
	var anim := player.get_animation(chosen)
	player.play(chosen)
	player.seek(minf(HOLD_TIME, anim.length), true)
	player.pause()
	return chosen


func _triangles(model: Node3D) -> int:
	var total := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if index.size() > 0:
				total += index.size() / 3
			else:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## World-space extent, measured from the BONES.
##
## Not from MeshInstance3D.get_aabb(): on the Volpe export the mesh vertices are already
## in metres while the bone hierarchy is centimetres under an `Armature` scaled 0.01, so
## multiplying the mesh AABB by the mesh transform double-counts that 0.01 and reports a
## 1.8 cm athlete. src/character/athlete_rig.gd:get_world_extent() documents the trap and
## this walks the bones the same way. Poses are the held clip's, so this is the silhouette
## at HOLD_TIME, not the rest pose.
func _world_size(model: Node3D) -> Vector3:
	var skeleton: Skeleton3D = null
	for child in model.find_children("*", "Skeleton3D", true, false):
		skeleton = child
		break
	if skeleton == null:
		return Vector3.ZERO
	var chain := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != null and n != self:
		if n is Node3D:
			chain = (n as Node3D).transform * chain
		n = n.get_parent()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for b in skeleton.get_bone_count():
		var p: Vector3 = skeleton.get_bone_global_pose(b).origin
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var a := chain * lo
	var b2 := chain * hi
	return (Vector3(maxf(a.x, b2.x), maxf(a.y, b2.y), maxf(a.z, b2.z))
		- Vector3(minf(a.x, b2.x), minf(a.y, b2.y), minf(a.z, b2.z)))


func _capture(label: String, preset: Dictionary) -> void:
	_cam.position = preset["pos"]
	_cam.fov = preset["fov"]
	_cam.look_at(preset["look_at"], Vector3.UP)
	_cam.make_current()
	# Two full frames: the first one can still carry the previous camera.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/roster-review-%s.png" % [_out_dir, label]
	var err := image.save_png(path)
	print("CAPTURE %s -> %s err=%d size=%dx%d" % [
		label, ProjectSettings.globalize_path(path), err,
		image.get_width(), image.get_height()])
