extends SceneTree
## Render harness for the Fiamma outfit trial (docs/agent-work/outfits-3d/PLAN-FIAMMA.md).
##
## Renders the four states (base + circuit + legend + signature) across the four
## named poses and both sides, at two camera scales:
##   * `close` - a menu-style framing of the upper body, for garment close-ups;
##   * `match` - the native match-camera scale, for "does it read on court".
##
## Real rendering only: run WITHOUT `--headless`, because a headless Godot has no
## framebuffer for `root.get_texture()`. Every image is deterministic: the rig is
## posed with `sample_at()`, never advanced by a frame loop.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path godot \
##     --script res://tests/outfit_fiamma_capture.gd -- \
##     --out=docs/agent-work/outfits-3d/evidence/renders
##
## Args (all optional):
##   --out=DIR            output directory, relative to the repo root or absolute
##   --states=a,b,c       subset of base,circuit,legend,signature
##   --poses=a,b,c        subset of idle,run,backhand,smash
##   --views=front,back   subset of front,back
##   --scales=close,match subset of close,match
##   --size=N             square framebuffer edge in pixels (default 640)

const RigScene := preload("res://src/character/AthleteRig.tscn")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")

const ATHLETE := &"fiamma"
const ALL_STATES := ["base", "circuit", "legend", "signature"]
const ALL_POSES := ["idle", "run", "backhand", "smash"]
const ALL_VIEWS := ["front", "back"]
const ALL_SCALES := ["close", "match"]

## Pose -> (clip, phase). Phases are chosen at a readable point of each clip:
## idle breathing mid-cycle, run mid-stride, and the stroke's own contact phase.
const POSE_CLIP := {
	"idle": ["idle", 0.45],
	"run": ["run", 0.35],
	"backhand": ["meshy_backhand", 0.5],
	"smash": ["meshy_smash", 0.5],
}

var out_dir := "docs/agent-work/outfits-3d/evidence/renders"
var athlete: StringName = ATHLETE
var states: Array = ALL_STATES
var poses: Array = ALL_POSES
var views: Array = ALL_VIEWS
var scales: Array = ALL_SCALES
var size := 640
var failures := 0
var written := 0


func _initialize() -> void:
	call_deferred("run")


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--athlete="):
			athlete = StringName(arg.trim_prefix("--athlete="))
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--states="):
			states = arg.trim_prefix("--states=").split(",", false)
		elif arg.begins_with("--poses="):
			poses = arg.trim_prefix("--poses=").split(",", false)
		elif arg.begins_with("--views="):
			views = arg.trim_prefix("--views=").split(",", false)
		elif arg.begins_with("--scales="):
			scales = arg.trim_prefix("--scales=").split(",", false)
		elif arg.begins_with("--size="):
			size = int(arg.trim_prefix("--size="))


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("outfit_fiamma_capture: " + message)


func _absolute_dir() -> String:
	if out_dir.begins_with("/"):
		return out_dir
	return ProjectSettings.globalize_path("res://../" + out_dir)


func _stage() -> void:
	# A dark neutral studio: the same background for every state, so a colour
	# difference between two renders is the outfit and nothing else.
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.09, 0.11)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -28, 0)
	key.light_energy = 1.25
	root.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, 150, 0)
	fill.light_energy = 0.5
	root.add_child(fill)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	root.add_child(camera)


## `close` frames the upper body (menu-scale read of the garment); `match` frames the
## whole figure the way the in-match camera sees it.
func _frame_camera(camera: Camera3D, scale_name: String, view: String, extent: AABB) -> void:
	var centre := extent.get_center()
	var dir := 1.0 if view == "front" else -1.0
	if scale_name == "close":
		var focus_y := extent.position.y + extent.size.y * 0.78
		camera.size = 0.62
		camera.position = Vector3(centre.x, focus_y, dir * 2.0)
		camera.look_at(Vector3(centre.x, focus_y, 0.0))
	else:
		camera.size = maxf(extent.size.y, 1.4) * 1.28
		camera.position = Vector3(centre.x, centre.y, dir * 4.0)
		camera.look_at(Vector3(centre.x, centre.y, 0.0))


func run() -> void:
	_parse_args()
	# The capture reads the window framebuffer, so the window IS the output size.
	DisplayServer.window_set_size(Vector2i(size, size))
	root.size = Vector2i(size, size)
	root.content_scale_size = Vector2i(size, size)
	var dir := _absolute_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	_stage()
	var camera: Camera3D = null
	for child in root.get_children():
		if child is Camera3D:
			camera = child
	check(camera != null, "no camera in the stage")

	# One rig per state, kept alive together: two Fiamma rigs must be able to show two
	# different outfits at once (plan acceptance 4), and the capture proves it by
	# rendering each rig in the same session.
	var rigs := {}
	for state in states:
		var rig: Node3D = RigScene.instantiate()
		# The asset must be selected BEFORE the rig enters the tree: `_ready()` builds
		# it, and `set_athlete_asset()` refuses once construction has started.
		check(rig.set_athlete_asset(athlete, StringName(state)), "asset select failed for " + state)
		check(rig.get_load_error() == OK, "rig failed to load for " + state)
		root.add_child(rig)
		check(Catalogue.apply(rig, athlete, StringName(state)), "outfit apply failed for " + state)
		rigs[state] = rig

	for state in states:
		var rig: Node3D = rigs[state]
		for other in rigs:
			(rigs[other] as Node3D).visible = other == state
		for pose in poses:
			var spec: Array = POSE_CLIP[pose]
			check(rig.play_clip(StringName(spec[0])), "clip missing: " + String(spec[0]))
			rig.sample_at(float(spec[1]) * rig.get_clip_length(StringName(spec[0])))
			rig._anim.pause()
			for view in views:
				for scale_name in scales:
					_frame_camera(camera, scale_name, view, rig.get_world_extent())
					await process_frame
					await RenderingServer.frame_post_draw
					var img := root.get_texture().get_image()
					var name := "%s_%s_%s_%s_%s.png" % [athlete, state, pose, view, scale_name]
					var path := dir.path_join(name)
					var err := img.save_png(path)
					check(err == OK, "could not write " + path)
					if err == OK:
						written += 1
						print("OUTFIT_CAPTURE %s %dx%d" % [name, img.get_width(), img.get_height()])

	# One labelled, simultaneous comparison for review.
	DisplayServer.window_set_size(Vector2i(1280, 512))
	root.size = Vector2i(1280, 512)
	root.content_scale_size = Vector2i(1280, 512)
	camera.size = 2.2
	camera.position = Vector3(0, 0.85, 4)
	camera.look_at(Vector3(0, 0.85, 0))
	var column := 0
	for state in rigs:
		var rig: Node3D = rigs[state]
		rig.visible = true
		rig.position.x = (column - (rigs.size() - 1) * 0.5) * 1.15
		rig.play_clip(&"idle")
		rig.sample_at(0.45)
		rig._anim.pause()
		var label := Label.new()
		label.text = String(state).to_upper()
		label.position = Vector2(20 + column * 320, 15)
		label.add_theme_font_size_override("font_size", 22)
		root.add_child(label)
		column += 1
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(dir.path_join("%s-lineup.png" % athlete)) == OK, "comparison save")
	for state in rigs:
		(rigs[state] as Node).free()
	print("OUTFIT_FIAMMA_CAPTURE_%s written=%d failures=%d" %
		["PASS" if failures == 0 else "FAIL", written, failures])
	quit(0 if failures == 0 else 1)
