extends Node3D
## rig_render.gd — the render evidence for the athlete slice.
##
## Executes the diagnostic the "Character pipeline economics" ticket asked for by
## name: ONE copy at x = 0, ONE frame per outfit. That removes the +-0.75 m
## off-axis placement of the earlier two-copy render, so `FRAMING_SHIFT_PX` is 0,
## the two view vectors are identical, and the frames are pixel-comparable with no
## disparity and no view-dependent shading term mixed in.
##
## It also renders the one variable the earlier run never isolated: the GLB's
## material imports at `metallic = 1.0` (glTF default for an unauthored
## `pbrMetallicRoughness`), and a fully metallic surface has no diffuse term, so
## albedo — the outfit colour — barely reaches the frame. Each strong outfit is
## therefore rendered twice, once at the rig's default `metallic = 0` and once at
## the GLB's own `metallic = 1`, same camera, same pose, same light.
##
## Extra frames: a background-only frame (exact body mask by difference), an
## 8-frame run strip and an 8-frame drive strip (motion across frames), and one
## arena-composition frame using the playable camera from the arena spike.
##
## Run: godot/src/character/render.sh  (xvfb-run + --rendering-driver opengl3;
## NOT --headless, which installs the dummy driver and captures a blank frame).

const RigScene := preload("res://src/character/AthleteRig.tscn")

## Held pose for every outfit frame. Identical across outfits by construction.
const HOLD_CLIP := &"idle"
const HOLD_TIME := 0.15
const FACING_DEG := 180.0
const BG := Color(0.2196, 0.2392, 0.2784)   # (56, 61, 71), same flat bg as the earlier render
const STRIP_FRAMES := 8

## Variant C of the arena spike (godot/prototypes/arena_spike/arena_spike.gd),
## quoted so the composition frame is comparable with what that lane rendered.
const CAM_PLAYABLE := {
	"pos": Vector3(0.0, 3.2000, 5.8000),
	"fov": 60.000,
	"look_at": Vector3(0.0, 0.900, -1.000),
}

var _rig: Node3D
var _cam: Camera3D
var _out_dir: String = "res://src/character/out"
var _res: String = "1280x720"
var _log_lines: PackedStringArray = []


func _log(s: String) -> void:
	print(s)
	_log_lines.append(s)


func _ready() -> void:
	_log("RIG_RENDER_START")
	var d := OS.get_environment("RIG_OUT_DIR")
	if d != "":
		_out_dir = d
	_res = "%dx%d" % [
		int(get_viewport().get_visible_rect().size.x),
		int(get_viewport().get_visible_rect().size.y),
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	_build_world()
	await _render_all()

	var f := FileAccess.open("%s/render_%s.log" % [_out_dir, _res], FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log_lines) + "\n")
		f.close()
	_log("RIG_RENDER_PASS")
	get_tree().quit(0)


# ------------------------------------------------------------------ world

func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.46, 0.55)
	env.ambient_light_energy = 0.75
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-38.0, -18.0, 0.0)
	# Shadows off on purpose: nothing about hiding or swapping one thing may change
	# another thing's pixels, so every cross-frame delta is attributable.
	sun.shadow_enabled = false
	add_child(sun)

	_rig = RigScene.instantiate()
	add_child(_rig)
	_rig.position = Vector3.ZERO                       # the ticket's step 1: x = 0
	_rig.set_facing_degrees(FACING_DEG)
	_log("RIG load_error=%d bones=%d tris=%d surfaces=%d facing=%.1f pos=%s" % [
		_rig.get_load_error(),
		_rig.get_skeleton().get_bone_count() if _rig.get_skeleton() else -1,
		_rig.get_triangle_count(), _rig.get_surface_count(),
		_rig.get_facing_degrees(), str(_rig.position)])
	_log("RIG clips=%s strokes=%s outfits=%s" % [
		str(_rig.get_locomotion_states()), str(_rig.get_stroke_names()), str(_rig.get_outfit_ids())])

	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_frame_camera()


## Frames the camera from the rig's measured world extent, straight on, at x = 0, so
## the framing is derived from the model rather than hand-tuned per run.
##
## `AthleteRig.get_world_extent()` is used deliberately instead of
## `MeshInstance3D.get_aabb()`: the latter under-reports this skinned mesh by the
## Armature's 0.01 bone-unit scale (0.018 m against a true 1.678 m) and put the camera
## 0.37 m from a full-size athlete on the first render attempt.
##
## MARGIN: 1.35x the standing height, so a run stride or a serve reach stays in frame.
func _frame_camera() -> void:
	var world: AABB = _rig.get_world_extent()
	var centre := world.get_center()
	var height := maxf(world.size.y, 0.1) * 1.35
	var dist := (height * 0.5) / tan(deg_to_rad(_cam.fov * 0.5))
	_cam.position = Vector3(0.0, centre.y, centre.z + dist)
	_cam.look_at(Vector3(0.0, centre.y, centre.z), Vector3.UP)
	_log("EXTENT world pos=%s size=%s centre=%s (framed height %.4f m)" % [
		str(world.position), str(world.size), str(centre), height])
	_log("CAM pos=%s fov=%.3f look_at=(0,%.4f,%.4f) FRAMING_SHIFT_PX dx=0.0000 dy=0.0000" % [
		str(_cam.position), _cam.fov, centre.y, centre.z])


func _hold() -> void:
	_rig.play_clip(HOLD_CLIP)
	_rig.sample_at(HOLD_TIME)


# ------------------------------------------------------------------ renders

func _render_all() -> void:
	# (1) background only — gives the offline stage an EXACT body mask by difference.
	_rig.visible = false
	await _capture("background_only")
	_rig.visible = true

	# (2) the ticket's diagnostic: one copy at x=0, one frame per outfit.
	_hold()
	for id in _rig.get_outfit_ids():
		_rig.set_outfit(id)
		_hold()
		_log("FRAME outfit=%s state=%s" % [id, str(_rig.get_material_state())])
		await _capture("outfit_%s_x0" % id)

	# (3) the isolated variable: the GLB's own metallic=1 vs the rig's metallic=0.
	_rig.use_glb_pbr(true)
	for id in [&"glacier", &"vermilion", &"base"]:
		if not _rig.set_outfit(id):
			continue
		_hold()
		_log("FRAME_GLBPBR outfit=%s state=%s" % [id, str(_rig.get_material_state())])
		await _capture("pbrglb_outfit_%s_x0" % id)
	_rig.use_glb_pbr(false)

	# (4) motion across frames: the run clip and the authored drive stroke.
	_rig.set_outfit(&"glacier")
	await _strip(&"run", "anim_run")
	await _strip(&"drive", "anim_drive")

	# (5) arena composition, playable camera from the arena spike.
	_cam.fov = float(CAM_PLAYABLE["fov"])
	_cam.position = CAM_PLAYABLE["pos"]
	_cam.look_at(CAM_PLAYABLE["look_at"], Vector3.UP)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.34, 0.30)
	floor_mi.material_override = fm
	floor_mi.position = Vector3(0.0, -0.02, 0.0)
	add_child(floor_mi)
	_rig.play_clip(&"run")
	_rig.sample_at(0.25)
	_log("FRAME_ARENA cam=%s fov=%.3f" % [str(_cam.position), _cam.fov])
	await _capture("arena_composition")


func _strip(clip: StringName, prefix: String) -> void:
	var length: float = _rig.get_clip_length(clip)
	if length <= 0.0:
		_log("STRIP skipped clip=%s (length=%.4f)" % [clip, length])
		return
	_rig.play_clip(clip)
	for i in STRIP_FRAMES:
		var t := length * float(i) / float(STRIP_FRAMES)
		_rig.sample_at(t)
		var pose: Dictionary = _rig.get_pose()
		var hips: Quaternion = (pose["bones"][0] as Dictionary)["rotation"]
		var rfa_i: int = _rig.get_skeleton().find_bone("RightForeArm")
		var rfa: Quaternion = _rig.get_skeleton().get_bone_pose_rotation(rfa_i)
		_log("STRIP clip=%s f=%d t=%.4f Hips=(%.5f,%.5f,%.5f,%.5f) RightForeArm=(%.5f,%.5f,%.5f,%.5f)" % [
			clip, i, t, hips.x, hips.y, hips.z, hips.w, rfa.x, rfa.y, rfa.z, rfa.w])
		await _capture("%s_f%d" % [prefix, i])


func _capture(stem: String) -> bool:
	var path := "%s/%s_%s.png" % [_out_dir, stem, _res]
	# Two settle frames before the grab: the pose/material change made just before this
	# call must reach a drawn frame, otherwise the capture returns the PREVIOUS state.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("RIG_RENDER_FAIL: viewport texture null for %s" % path)
		return false
	var img: Image = tex.get_image()
	if img == null:
		push_error("RIG_RENDER_FAIL: viewport image null for %s" % path)
		return false
	var err := img.save_png(path)
	_log("SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])
	return err == OK
