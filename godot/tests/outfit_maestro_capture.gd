extends SceneTree
## Render harness for the Maestro outfit trial (docs/agent-work/outfits-3d/MAESTRO-RENDER.md).
##
## Modelled line-for-line on `res://tests/outfit_fiamma_capture.gd`, the harness that
## produced the Fiamma evidence, because every correction that lane paid for is
## already encoded there:
##
##   * ALL other rigs are hidden before every render. Four live rigs at the same
##     origin, all visible, render four coincident meshes and nothing else.
##   * the framebuffer is set square (`window_set_size` + `root.size` +
##     `root.content_scale_size`), because the capture IS the window.
##   * the animation clips are paused and sampled at normalized phases of each clip
##     (`sample_at`), so a pose is a value, never a race with a frame loop.
##   * colour space is the region shader's problem (`OUTPUT_IS_SRGB`), not this
##     harness's; nothing here post-processes the image.
##
## Renders the four states (base + circuit + legend + signature) across the four
## named poses and both sides, at two camera scales:
##   * `close` - a menu-style framing of the upper body, for garment close-ups;
##   * `match` - the full-figure framing, for "does it read on court".
## That is 4 x 4 x 2 x 2 = 64 captures, plus one labelled four-column comparison.
##
## Real rendering only: run WITHOUT `--headless`, because a headless Godot has no
## framebuffer for `root.get_texture()`.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path godot \
##     --script res://tests/outfit_maestro_capture.gd -- \
##     --out=docs/agent-work/outfits-3d/evidence/renders-maestro
##
## PROFILE GATE. Maestro's profile in `OUTFIT_PROFILES` (src/character/
## outfit_catalogue.gd) is authored by another lane. Without it, all four states
## fall back to the same baked material and the capture is 64 identical frames of
## the base look - an empty result dressed as evidence. So the harness REFUSES to
## run without the profile (exit 1, before any render) unless
## `--allow-missing-profile` is passed, which exists only to smoke-test the
## harness itself.
##
## Args (all optional):
##   --out=DIR                  output directory, relative to the repo root or absolute
##   --states=a,b,c             subset of base,circuit,legend,signature
##   --poses=a,b,c              subset of idle,run,backhand,smash
##   --views=front,back         subset of front,back
##   --scales=close,match       subset of close,match
##   --size=N                   square framebuffer edge in pixels (default 640)
##   --allow-missing-profile    render anyway (harness smoke test only)

const RigScene := preload("res://src/character/AthleteRig.tscn")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")

const ATHLETE := &"maestro"
const ALL_STATES := ["base", "circuit", "legend", "signature"]
const ALL_POSES := ["idle", "run", "backhand", "smash"]
const ALL_VIEWS := ["front", "back"]
const ALL_SCALES := ["close", "match"]

## Pose -> (clip, phase). Phases are chosen at a readable point of each clip:
## idle breathing mid-cycle, run mid-stride, and the stroke's own contact phase.
## Identical to the Fiamma harness, so the two athletes' frames are comparable.
const POSE_CLIP := {
	"idle": ["idle", 0.45],
	"run": ["run", 0.35],
	"backhand": ["meshy_backhand", 0.5],
	"smash": ["meshy_smash", 0.5],
}

var out_dir := "docs/agent-work/outfits-3d/evidence/renders-maestro"
var states: Array = ALL_STATES
var poses: Array = ALL_POSES
var views: Array = ALL_VIEWS
var scales: Array = ALL_SCALES
var size := 640
var allow_missing_profile := false
var failures := 0
var written := 0
var _state_targets := {}


func _initialize() -> void:
	call_deferred("run")


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
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
		elif arg == "--allow-missing-profile":
			allow_missing_profile = true


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("outfit_maestro_capture: " + message)


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
## whole figure at the in-match camera scale, derived from the rig's measured extent.
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


## The profile uniforms currently on the rig's surface, or {} when the surface is the
## rig's own material (`base`, or an athlete with no profile). Read off the live
## material rather than from a cached variable, the same reason
## `OutfitCatalogue.read_back()` does.
##
## Every non-texture uniform is dumped, not just the six `target_*` names: the Maestro
## profile also drives the shader's value gate (`value_gate_enabled`, `value_band_a/b`,
## `value_band_feather`), and a check that only looked at the six targets would call
## two states different while the family split they depend on was identical. Texture
## uniforms are skipped because they are per-rig objects, so their string form would
## differ between two rigs even when the materials are parameter-identical.
const TEXTURE_UNIFORMS := ["source_tex", "region_mask", "normal_tex", "roughness_tex"]


func _targets_of(rig: Node) -> Dictionary:
	var mi: MeshInstance3D = rig.get_mesh_instance()
	if mi == null:
		return {}
	var mat := mi.get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		return {}
	var out := {}
	for uniform in mat.shader.get_shader_uniform_list():
		var uniform_name: String = uniform["name"]
		if uniform_name in TEXTURE_UNIFORMS:
			continue
		if int(uniform["type"]) == TYPE_OBJECT:
			continue
		var value: Variant = mat.get_shader_parameter(uniform_name)
		out[uniform_name] = "none" if value == null else str(value)
	return out


func _targets_signature(targets: Dictionary) -> String:
	var keys := targets.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s=%s" % [k, targets[k]])
	return ",".join(parts)


func run() -> void:
	_parse_args()
	# The capture reads the window framebuffer, so the window IS the output size.
	DisplayServer.window_set_size(Vector2i(size, size))
	root.size = Vector2i(size, size)
	root.content_scale_size = Vector2i(size, size)
	var dir := _absolute_dir()

	# PROFILE GATE - see the header. Exit before writing anything, so a profile-less
	# run cannot leave 64 all-base frames in the evidence directory.
	var has_profile: bool = Catalogue.has_profile(ATHLETE)
	print("OUTFIT_MAESTRO_PROFILE present=%s athlete=%s" % [str(has_profile), ATHLETE])
	if not has_profile and not allow_missing_profile:
		push_error("outfit_maestro_capture: no OUTFIT_PROFILES entry for &\"%s\" - all four "
			% ATHLETE + "states would render the baked look. Refusing to write evidence.")
		print("OUTFIT_MAESTRO_CAPTURE_FAIL profile_absent written=0 failures=1")
		quit(1)
		return
	if not has_profile:
		push_warning("outfit_maestro_capture: profile absent, continuing because "
			+ "--allow-missing-profile was passed (smoke test only)")
	var load_err: int = Catalogue.load_error()
	check(load_err == OK, "catalogue failed to load (error %d)" % load_err)

	DirAccess.make_dir_recursive_absolute(dir)
	_stage()
	var camera: Camera3D = null
	for child in root.get_children():
		if child is Camera3D:
			camera = child
	check(camera != null, "no camera in the stage")

	# One rig per state, kept alive together, the same shape as the Fiamma harness:
	# two rigs must be able to show two different outfits at once, and this capture
	# proves it by rendering each of the four in one session.
	var rigs := {}
	for state in states:
		var rig: Node3D = RigScene.instantiate()
		# The asset must be selected BEFORE the rig enters the tree: `_ready()` builds
		# it, and `set_athlete_asset()` refuses once construction has started.
		check(rig.set_athlete_asset(ATHLETE), "asset select failed for " + state)
		check(rig.get_load_error() == OK, "rig failed to load for " + state)
		root.add_child(rig)
		check(Catalogue.apply(rig, ATHLETE, StringName(state)), "outfit apply failed for " + state)
		var targets := _targets_of(rig)
		_state_targets[state] = targets
		print("OUTFIT_STATE %s targets=%s" % [state, _targets_signature(targets)])
		rigs[state] = rig

	# The known risk of this athlete, checked at the material level before any pixel
	# is looked at: circuit and signature must not be the same target set. Whether
	# they also differ ON SCREEN is what tools/character/compare_maestro_renders.py
	# measures; this only catches the "the two entries are literally the same" case.
	# Skipped without a profile: there the four states are identical by construction,
	# so the check would fail on a fact that is already stated out loud above.
	if has_profile:
		if states.has("circuit") and states.has("signature"):
			check(_targets_signature(_state_targets["circuit"])
				!= _targets_signature(_state_targets["signature"]),
				"circuit and signature carry identical shader targets on this rig")
		if states.has("base"):
			check(_state_targets["base"].is_empty(),
				"base did not hand the surface back to the rig material")

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
					var name := "%s_%s_%s_%s_%s.png" % [ATHLETE, state, pose, view, scale_name]
					var path := dir.path_join(name)
					var err := img.save_png(path)
					check(err == OK, "could not write " + path)
					if err == OK:
						written += 1
						print("OUTFIT_CAPTURE %s %dx%d" % [name, img.get_width(), img.get_height()])

	# One labelled, simultaneous four-column comparison for review. The camera size is
	# derived from the same measured extent the `match` framing uses, so the lineup
	# cannot crop the figure if the athlete is a different height than Fiamma's.
	DisplayServer.window_set_size(Vector2i(1280, 512))
	root.size = Vector2i(1280, 512)
	root.content_scale_size = Vector2i(1280, 512)
	var first: Node3D = rigs[states[0]]
	var extent: AABB = first.get_world_extent()
	var column_width := 1280.0 / float(rigs.size())
	camera.size = maxf(extent.size.y, 1.4) * 1.28
	camera.position = Vector3(0, extent.get_center().y, 4)
	camera.look_at(Vector3(0, extent.get_center().y, 0))
	var title := Label.new()
	title.text = "%s - base / circuit / legend / signature" % String(ATHLETE).to_upper()
	title.position = Vector2(20, 8)
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)
	var column := 0
	for state in rigs:
		var rig: Node3D = rigs[state]
		rig.visible = true
		## 1.15 m apart: wide enough that four figures never overlap in a 1280 px frame.
		rig.position.x = (column - (rigs.size() - 1) * 0.5) * 1.15
		rig.play_clip(&"idle")
		rig.sample_at(0.45 * rig.get_clip_length(&"idle"))
		rig._anim.pause()
		var label := Label.new()
		label.text = String(state).to_upper()
		label.position = Vector2(column * column_width, 34)
		label.size = Vector2(column_width, 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		root.add_child(label)
		column += 1
	await process_frame
	await RenderingServer.frame_post_draw
	var lineup := "%s-lineup.png" % ATHLETE
	check(root.get_texture().get_image().save_png(dir.path_join(lineup)) == OK, "comparison save")
	print("OUTFIT_LINEUP %s" % dir.path_join(lineup))
	for state in rigs:
		(rigs[state] as Node).free()
	print("OUTFIT_MAESTRO_CAPTURE_%s written=%d failures=%d" %
		["PASS" if failures == 0 else "FAIL", written, failures])
	quit(0 if failures == 0 else 1)
