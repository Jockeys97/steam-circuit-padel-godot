extends Node3D
## roster_render.gd — render evidence for the roster + outfit catalogue slice.
##
## Renders, at one fixed camera and one fixed held pose, ONE frame per (athlete,
## outfit) pair the reference defines — 26 of them — plus a background-only frame
## that gives the offline stage an exact body mask by difference.
##
## Everything that could confound a cross-frame pixel delta is held constant by
## construction: the rig sits at x = 0 (no off-axis parallax), the camera is derived
## once from the rig's measured world extent and never moved, the pose is the same
## clip sampled at the same time, shadows are off, and only four shader uniforms
## change between frames. So every measured delta is attributable to outfit colour.
##
## Run: godot/src/character/roster_render.sh  (xvfb-run + --rendering-driver opengl3;
## NOT --headless, which installs the dummy driver and captures a blank frame).
## Software GL: valid for correctness screenshots, INVALID for any frame-rate claim.

const RigScene := preload("res://src/character/AthleteRig.tscn")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

## Same held pose and background as the previous slice's rig_render.gd, so the two
## runs' frames stay comparable.
const HOLD_CLIP := &"idle"
const HOLD_TIME := 0.15
const FACING_DEG := 180.0
const BG := Color(0.2196, 0.2392, 0.2784)   # (56, 61, 71)

var _rig: Node3D
var _cam: Camera3D
var _out_dir: String = "res://src/character/out"
var _res: String = "512x512"
var _log_lines: PackedStringArray = []
var _manifest: Array = []


func _log(s: String) -> void:
	print(s)
	_log_lines.append(s)


func _ready() -> void:
	_log("ROSTER_RENDER_START")
	var d := OS.get_environment("RIG_OUT_DIR")
	if d != "":
		_out_dir = d
	_res = "%dx%d" % [
		int(get_viewport().get_visible_rect().size.x),
		int(get_viewport().get_visible_rect().size.y),
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	var info: Dictionary = Catalogue.source_info()
	_log("CATALOGUE %s" % str(info))
	if Catalogue.load_error() != OK:
		push_error("ROSTER_RENDER_FAIL: catalogue load_error=%d" % Catalogue.load_error())
		get_tree().quit(1)
		return

	_build_world()
	await _render_all()
	_write_sidecars(info)
	_log("ROSTER_RENDER_PASS frames=%d" % _manifest.size())
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
	sun.shadow_enabled = false   # nothing may change another thing's pixels
	add_child(sun)

	# Spawned through the seam under test, not hand-built: if the factory is broken the
	# render is broken, and that is the point.
	_rig = AthleteSpawn.make(AthleteSpawn.ids()[0], &"base", {
		"facing_degrees": FACING_DEG,
		"name": "RosterSubject",
	})
	if _rig == null:
		push_error("ROSTER_RENDER_FAIL: AthleteSpawn.make returned null")
		get_tree().quit(1)
		return
	add_child(_rig)
	_log("RIG %s" % str(AthleteSpawn.describe(_rig)))

	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_frame_camera()


## Camera derived once from the rig's measured world extent (see AthleteRig's
## get_world_extent() note on why MeshInstance3D.get_aabb() is wrong here), then frozen.
func _frame_camera() -> void:
	var world: AABB = _rig.get_world_extent()
	var centre := world.get_center()
	var height := maxf(world.size.y, 0.1) * 1.20
	var dist := (height * 0.5) / tan(deg_to_rad(_cam.fov * 0.5))
	_cam.position = Vector3(0.0, centre.y, centre.z + dist)
	_cam.look_at(Vector3(0.0, centre.y, centre.z), Vector3.UP)
	_log("EXTENT world pos=%s size=%s centre=%s (framed height %.4f m)" % [
		str(world.position), str(world.size), str(centre), height])
	_log("CAM pos=%s fov=%.3f FRAMING_SHIFT_PX dx=0.0000 dy=0.0000" % [str(_cam.position), _cam.fov])


func _hold() -> void:
	_rig.play_clip(HOLD_CLIP)
	_rig.sample_at(HOLD_TIME)


# ------------------------------------------------------------------ renders

func _render_all() -> void:
	# (1) background only — exact body mask by difference for the offline stage.
	_rig.visible = false
	await _capture("roster_background_only", {"kind": "background"})
	_rig.visible = true

	# (2) one frame per reference (athlete, outfit) pair, in reference order.
	for athlete_id in AthleteSpawn.ids():
		for outfit_id in AthleteSpawn.outfit_ids(athlete_id):
			if not AthleteSpawn.set_outfit(_rig, athlete_id, outfit_id):
				push_error("ROSTER_RENDER_FAIL: set_outfit(%s,%s)" % [athlete_id, outfit_id])
				continue
			_hold()
			var entry: Dictionary = Catalogue.resolve(athlete_id, outfit_id)
			_log("FRAME %s:%s primary=%s trim=%s art_dependent=%s" % [
				athlete_id, outfit_id, entry["primary_hex"], entry["trim_hex"],
				str(entry["art_dependent"])])
			await _capture("roster_%s_%s_x0" % [athlete_id, outfit_id], {
				"kind": "outfit",
				"athlete_id": String(athlete_id),
				"outfit_id": String(outfit_id),
				"unlock_key": entry["unlock_key"],
				"primary_hex": entry["primary_hex"],
				"trim_hex": entry["trim_hex"],
				"art_dependent": entry["art_dependent"],
				"material": str(Catalogue.read_back(_rig)),
			})

			# The brief asks for one x=0 frame per athlete in its base outfit under its
			# own name, so the per-athlete evidence is findable without decoding ids.
			if outfit_id == &"base":
				await _capture("athlete_%s_base_x0" % athlete_id, {
					"kind": "athlete_base",
					"athlete_id": String(athlete_id),
					"outfit_id": String(outfit_id),
				})


func _capture(stem: String, meta: Dictionary) -> bool:
	var path := "%s/%s_%s.png" % [_out_dir, stem, _res]
	# Two settle frames: the uniform change made just before this call must reach a
	# drawn frame, otherwise the capture returns the PREVIOUS outfit.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("ROSTER_RENDER_FAIL: viewport texture null for %s" % path)
		return false
	var img: Image = tex.get_image()
	if img == null:
		push_error("ROSTER_RENDER_FAIL: viewport image null for %s" % path)
		return false
	var err := img.save_png(path)
	_log("SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])
	var row := meta.duplicate()
	row["file"] = "%s_%s.png" % [stem, _res]
	row["save_error"] = err
	_manifest.append(row)
	return err == OK


func _write_sidecars(info: Dictionary) -> void:
	var manifest := {
		"resolution": _res,
		"hold_clip": String(HOLD_CLIP),
		"hold_time": HOLD_TIME,
		"facing_degrees": FACING_DEG,
		"background_rgb8": [int(round(BG.r * 255.0)), int(round(BG.g * 255.0)),
			int(round(BG.b * 255.0))],
		"catalogue": info,
		"frames": _manifest,
	}
	var f := FileAccess.open("%s/roster_manifest_%s.json" % [_out_dir, _res], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(manifest, "  ") + "\n")
		f.close()
	var g := FileAccess.open("%s/roster_render_%s.log" % [_out_dir, _res], FileAccess.WRITE)
	if g != null:
		g.store_string("\n".join(_log_lines) + "\n")
		g.close()
