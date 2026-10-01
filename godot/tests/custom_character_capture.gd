## custom_character_capture.gd — writes the generated athlete out as PNGs.
##
## Evidence, not a gate: it renders the custom rig for a few appearances and saves
## both the 3D frame and the renderer-free portrait, so a reviewer can see what the
## player sees and which path produced it.
##
## Run:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##     --script res://tests/custom_character_capture.gd
##   (drop --headless for a real 3D frame, when a rendering device is available)
extends SceneTree

const CustomCharacter := preload("res://src/character/custom_character.gd")
const Portrait := preload("res://src/character/custom_character_portrait.gd")
const CustomCharacterRig := preload("res://src/character/custom_character_rig.gd")

const OUT := "res://../docs/agent-work/character-creator/evidence"
const SIZE := Vector2i(360, 460)
## Frames to let the renderer settle before the frame is read: the first draw of a
## fresh viewport is not guaranteed to have the rig in it.
const SETTLE_FRAMES := 4

const APPEARANCES := [
	{"name": "alba", "skin": "tan", "hair": "ponytail", "hair_color": "brown", "outfit": "circuit", "outfit_color": "coral"},
	{"name": "riva", "skin": "porcelain", "hair": "buzz", "hair_color": "blonde", "outfit": "varsity", "outfit_color": "azure"},
	{"name": "kai", "skin": "deep", "hair": "crop", "hair_color": "violet", "outfit": "training", "outfit_color": "lime"},
]

var _index: int = -1
var _frames: int = 0
var _viewport: SubViewport = null


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("rendering device: %s" % ("yes" if RenderingServer.get_rendering_device() != null else "no"))
	_next()


## One appearance at a time: mount the rig, let the renderer draw it, read the frame,
## tear it down. A coroutine, so the frames really happen between the steps.
func _next() -> void:
	if _viewport != null:
		_viewport.queue_free()
		_viewport = null
	_index += 1
	if _index >= APPEARANCES.size():
		quit(0)
		return
	var spec: Dictionary = APPEARANCES[_index]
	var record := CustomCharacter.defaults()
	record["display_name"] = String(spec["name"]).to_upper()
	record["skin_id"] = spec["skin"]
	record["hair_id"] = spec["hair"]
	record["hair_color_id"] = spec["hair_color"]
	record["outfit_id"] = spec["outfit"]
	record["outfit_color_id"] = spec["outfit_color"]
	_viewport = _mount(record)
	for _i in SETTLE_FRAMES:
		await process_frame
	var frame: Image = null
	if _viewport != null:
		frame = _viewport.get_texture().get_image()
	if frame != null:
		# The raw frame is kept whatever it holds: it is what a reviewer has to look at
		# when the content test says "not an athlete".
		frame.save_png(ProjectSettings.globalize_path("%s/raw_%s%s.png" % [OUT, spec["name"], suffix_for_raw()]))
	var source := "render"
	if frame == null or not Portrait._has_content(frame):
		frame = Portrait.paint(record, SIZE)
		source = "paint"
	var suffix := suffix_for_raw()
	var path := "%s/avatar_%s%s.png" % [OUT, spec["name"], suffix]
	var err := frame.save_png(ProjectSettings.globalize_path(path))
	print("capture %s -> %s (%s %dx%d, err=%d)" % [
		spec["name"], path, source, frame.get_width(), frame.get_height(), err])
	_next()


func suffix_for_raw() -> String:
	return "_rest" if "--rest" in OS.get_cmdline_user_args() else ""


func _mount(record: Dictionary) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("141821")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5dbe8")
	environment.ambient_light_energy = 1.15
	env.environment = environment
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.light_energy = 1.2
	viewport.add_child(sun)
	var rig := CustomCharacterRig.make(record, {"name": "CaptureRig"})
	if rig == null:
		viewport.free()
		return null
	viewport.add_child(rig)
	var rest := "--rest" in OS.get_cmdline_user_args()
	if not rest:
		rig.play_locomotion(&"idle")
	var skinless := "--skinless" in OS.get_cmdline_user_args()
	if skinless:
		var kit_mesh: MeshInstance3D = rig.custom_mesh()
		if kit_mesh != null:
			kit_mesh.skin = null
			# Without a skin the vertices render in this node's own space, so the node has
			# to stand where the skeleton does.
			kit_mesh.transform = Transform3D.IDENTITY
	var custom: MeshInstance3D = rig.custom_mesh()
	if custom != null and custom.mesh != null:
		var aabb := custom.mesh.get_aabb()
		var skel: Skeleton3D = rig.get_skeleton()
		print("diag skin=%s aabb_pos=%s aabb_size=%s bones=%d skel_xform=%s" % [
			("none" if skinless else "bound"), str(aabb.position), str(aabb.size),
			skel.get_bone_count() if skel != null else -1,
			str(skel.transform) if skel != null else "-"])
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.current = true
	var bounds: AABB = rig.world_bounds()
	var centre: Vector3 = bounds.get_center()
	var height := maxf(bounds.size.y, 0.5)
	# `look_at` needs the node to be in the tree; this one aims before mounting.
	camera.look_at_from_position(
		centre + Vector3(height * 0.10, height * 0.05, height * 1.8), centre, Vector3.UP)
	viewport.add_child(camera)
	root.add_child(viewport)
	return viewport
