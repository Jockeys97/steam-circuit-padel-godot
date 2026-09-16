extends Node3D

# arena_spike — smallest real in-engine prototype for the camera/feel spike.
#
# Everything is built in code so the numbers that matter are readable in one
# place and traceable to their source:
#
#   COURT (js/data.js lines 1-8)          left=80 right=880 top=56 bottom=564
#                                         netY=310 netHeight=38
#   SERVICE_LINE_OFFSET (js/game.js:30)   126  (px, from netY)
#   web match-camera composition (js/render.js, scene setup before point()):
#     topLeft=(210,100) topRight=(750,100)
#     bottomLeft=(48, canvas.height-13=687) bottomRight=(912, 687)
#     depth warp:  v <= 0.5 ? v*0.88 : 0.44 + (v-0.5)*1.12
#   canvas: index.html line 472 -> <canvas id="game" width="960" height="700">
#
# PX_TO_M: one uniform scale for both COURT axes. 0.025 m/px is the value that
# makes COURT's 800 px span exactly the FIP padel length, 20.00 m. Under that
# single scale COURT's 508 px depth is 12.70 m, i.e. COURT's aspect (800:508 =
# 1.575) is NOT 20:10 = 2.0. That is a finding, not a mistake — see the evidence
# file. No COURT number is invented here; the mapping is one constant.

const PX_TO_M := 0.025

# --- COURT, verbatim from js/data.js -----------------------------------------
const C_LEFT := 80.0
const C_RIGHT := 880.0
const C_TOP := 56.0
const C_BOTTOM := 564.0
const C_NET_Y := 310.0
const C_NET_H := 38.0
const SERVICE_LINE_OFFSET_PX := 126.0  # js/game.js:30

# --- derived world sizes ------------------------------------------------------
const COURT_LEN := (C_RIGHT - C_LEFT) * PX_TO_M      # 20.000 m  (screen X  -> world X)
const COURT_DEPTH := (C_BOTTOM - C_TOP) * PX_TO_M    # 12.700 m  (screen Y  -> world Z)
const NET_H := C_NET_H * PX_TO_M                     #  0.950 m
const SERVICE_Z := SERVICE_LINE_OFFSET_PX * PX_TO_M  #  3.150 m from the net
const HALF_DEPTH := COURT_DEPTH * 0.5                #  6.350 m
const HALF_LEN := COURT_LEN * 0.5                    # 10.000 m
# Not in COURT: spike default for the cage height (FIP padel: 3 m). Flagged.
const GLASS_H := 3.0
# Not in COURT and not in BALANCE (js/data.js has ballGravity only, no radius):
# 0.10 m is deliberately larger than a real padel ball (r ~= 0.033 m) so it is
# readable in a whole-court render. Spike-only value, flagged.
const BALL_R := 0.10

const ATHLETE_POS := Vector3(2.6, 0.0, 2.4)   # near half (COURT.bottom side)
const BALL_POS := Vector3(1.2, 0.4, 3.5)      # near half, in the air

# --- camera: fitted to the web composition (see evidence file for the solve) --
# Web targets, in the web's own 960x700 frame:
#   far baseline  y = 100   -> frac 0.14286 ; half-width 270 px -> 0.28125
#   near baseline y = 687   -> frac 0.98143 ; half-width 432 px -> 0.45000
# A true pinhole camera at the required 16:9 output cannot reproduce that
# hand-tuned 2.5D trapezoid exactly (the exact solve needs sin(pitch) > 1). The
# best fit that holds the near (player) baseline exactly lands here:
const CAM_DEFAULT := {
	"pos": Vector3(0.0, 14.4552, 6.4000),
	"pitch_deg": -65.2000,
	"fov": 50.866,
	"look_at": Vector3(0.0, 0.0, 0.0),
}
# Variant B: the same composition, slightly wider and higher.
const CAM_WIDE := {
	"pos": Vector3(0.0, 16.6235, 7.4000),
	"pitch_deg": -68.0000,
	"fov": 60.000,
	"look_at": Vector3(0.0, 0.0, 0.0),
}
# Variant C: a camera that is NOT the web composition — a playable 3D view
# behind the player's baseline. Rendered only to show what the web framing
# costs when turned into a real 3D match camera.
const CAM_PLAYABLE := {
	"pos": Vector3(0.0, 3.2000, 5.8000),
	"pitch_deg": 0.0,
	"fov": 60.000,
	"look_at": Vector3(0.0, 0.900, -1.000),
}

const GLB_PATH := "res://assets/volpe-rigged.glb"
const FRAMES := 12

var _cam: Camera3D
var _athlete_roots: Array[Node] = []

func _log(s: String) -> void:
	print(s)

func _mat(c: Color, rough := 0.85, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _box(name: String, size: Vector3, pos: Vector3, color: Color, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color, 0.8, alpha)
	add_child(mi)
	return mi

func _build_lights_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.10, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.46, 0.55)
	env.ambient_light_energy = 0.75
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-62.0, -38.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

func _build_court() -> void:
	# Surrounding floor, so the frame is not empty around the cage.
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0.0, -0.02, 0.0)
	floor_mi.material_override = _mat(Color(0.10, 0.22, 0.18))
	add_child(floor_mi)

	# Court surface, exactly COURT_LEN x COURT_DEPTH.
	var bed := MeshInstance3D.new()
	var bed_mesh := PlaneMesh.new()
	bed_mesh.size = Vector2(COURT_LEN, COURT_DEPTH)
	bed.mesh = bed_mesh
	bed.material_override = _mat(Color(0.16, 0.30, 0.58))
	add_child(bed)

	# Lines (painted as thin boxes).
	var lw := 0.05
	_box("LineFar", Vector3(COURT_LEN, 0.012, lw), Vector3(0.0, 0.006, -HALF_DEPTH), Color(0.95, 0.96, 0.98))
	_box("LineNear", Vector3(COURT_LEN, 0.012, lw), Vector3(0.0, 0.006, HALF_DEPTH), Color(0.95, 0.96, 0.98))
	_box("LineLeft", Vector3(lw, 0.012, COURT_DEPTH), Vector3(-HALF_LEN, 0.006, 0.0), Color(0.95, 0.96, 0.98))
	_box("LineRight", Vector3(lw, 0.012, COURT_DEPTH), Vector3(HALF_LEN, 0.006, 0.0), Color(0.95, 0.96, 0.98))
	_box("CenterLine", Vector3(lw, 0.012, COURT_DEPTH), Vector3(0.0, 0.006, 0.0), Color(0.95, 0.96, 0.98))
	# Service lines at SERVICE_LINE_OFFSET (js/game.js:30) = 3.150 m from the net.
	_box("ServiceFar", Vector3(COURT_LEN, 0.012, lw), Vector3(0.0, 0.006, -SERVICE_Z), Color(0.95, 0.96, 0.98))
	_box("ServiceNear", Vector3(COURT_LEN, 0.012, lw), Vector3(0.0, 0.006, SERVICE_Z), Color(0.95, 0.96, 0.98))

	# Net: COURT netHeight (38 px -> 0.950 m), centred on COURT netY (mid-court).
	_box("Net", Vector3(COURT_LEN, NET_H - 0.07, 0.04), Vector3(0.0, (NET_H - 0.07) * 0.5, 0.0), Color(0.20, 0.24, 0.30), 0.45)
	# Net tape (the white band along the top of a padel net).
	_box("NetTape", Vector3(COURT_LEN, 0.07, 0.05), Vector3(0.0, NET_H - 0.035, 0.0), Color(0.95, 0.96, 0.98))
	_box("NetPostL", Vector3(0.10, NET_H + 0.05, 0.10), Vector3(-HALF_LEN, (NET_H + 0.05) * 0.5, 0.0), Color(0.75, 0.78, 0.82))
	_box("NetPostR", Vector3(0.10, NET_H + 0.05, 0.10), Vector3(HALF_LEN, (NET_H + 0.05) * 0.5, 0.0), Color(0.75, 0.78, 0.82))

	# Glass cage: 3 m walls on all four sides (height is a spike default).
	var g := Color(0.62, 0.84, 0.95)
	_box("GlassFar", Vector3(COURT_LEN, GLASS_H, 0.04), Vector3(0.0, GLASS_H * 0.5, -HALF_DEPTH), g, 0.14)
	_box("GlassNear", Vector3(COURT_LEN, GLASS_H, 0.04), Vector3(0.0, GLASS_H * 0.5, HALF_DEPTH), g, 0.14)
	_box("GlassLeft", Vector3(0.04, GLASS_H, COURT_DEPTH), Vector3(-HALF_LEN, GLASS_H * 0.5, 0.0), g, 0.14)
	_box("GlassRight", Vector3(0.04, GLASS_H, COURT_DEPTH), Vector3(HALF_LEN, GLASS_H * 0.5, 0.0), g, 0.14)

	# Ball.
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	ball.mesh = sm
	ball.position = BALL_POS
	ball.material_override = _mat(Color(0.98, 0.90, 0.16), 0.4)
	add_child(ball)

func _load_athlete() -> void:
	var t0 := Time.get_ticks_msec()
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(GLB_PATH, st)
	_log("GLB_APPEND err=%d path=%s" % [err, GLB_PATH])
	if err != OK:
		return
	var scene: Node = doc.generate_scene(st)
	if scene == null:
		_log("GLB_FAIL: generate_scene returned null")
		return
	_log("GLB_LOADED in %d ms" % (Time.get_ticks_msec() - t0))
	var root := Node3D.new()
	root.name = "Athlete"
	root.add_child(scene)
	root.position = ATHLETE_POS
	root.rotation_degrees = Vector3(0.0, 180.0, 0.0)  # assumed facing; unverified
	add_child(root)
	_athlete_roots.append(root)

	# Base pose: the rig is a single key at t=0.30 s, duration 0.0 (no idle clip).
	for p in scene.find_children("*", "AnimationPlayer", true, false):
		var ap := p as AnimationPlayer
		var names := ap.get_animation_list()
		_log("ATHLETE_ANIMATIONS=%s" % [names])
		if names.size() > 0:
			var a: Animation = ap.get_animation(names[0])
			_log("ATHLETE_ANIM '%s' length=%.3f tracks=%d" % [names[0], a.length, a.get_track_count()])
			ap.play(names[0])
			if a.length > 0.0:
				ap.seek(a.length, true)
			ap.pause()
			_log("ATHLETE_POSE held at t=%.3f (base pose; NO idle clip exists)" % (a.length))

	# Measured extent of the loaded athlete, as evidence of scale.
	# NOTE: the mesh-space AABB times the node transform IGNORES skinning and is
	# wrong for a skinned mesh (it reports ~1.8 cm here). The honest measure of a
	# skinned rig is the world-space extent of its bones in the current pose.
	var aabb := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var local := (mi as MeshInstance3D).global_transform * m.get_aabb()
		aabb = local if first else aabb.merge(local)
		first = false
	if not first:
		_log("ATHLETE_MESH_AABB_UNSKINNED size=%s (misses skinning; see BONE_EXTENT)" % [aabb.size])
	for sk in scene.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		var lo := INF
		var hi := -INF
		for b in skel.get_bone_count():
			var wp: Vector3 = skel.global_transform * skel.get_bone_global_pose(b).origin
			lo = min(lo, wp.y)
			hi = max(hi, wp.y)
		_log("ATHLETE_BONE_EXTENT bones=%d world_y=%.4f..%.4f -> height %.4f m at %s" % [
			skel.get_bone_count(), lo, hi, hi - lo, ATHLETE_POS])

func _setup_camera(view: String) -> void:
	var cfg: Dictionary = CAM_DEFAULT
	if view == "wide":
		cfg = CAM_WIDE
	elif view == "playable":
		cfg = CAM_PLAYABLE
	var cam := Camera3D.new()
	cam.name = "MatchCam"
	cam.fov = float(cfg["fov"])
	add_child(cam)
	cam.position = cfg["pos"]
	if view == "playable":
		cam.look_at(cfg["look_at"], Vector3.UP)
	else:
		cam.rotation_degrees = Vector3(float(cfg["pitch_deg"]), 0.0, 0.0)
	cam.current = true
	_cam = cam

func _report_framing() -> void:
	var vp := get_viewport().get_visible_rect().size
	_log("CAM view=%s pos=%s pitch=%.3f deg fov_v=%.3f deg viewport=%.0fx%.0f" % [
		OS.get_environment("ARENA_VIEW"), _cam.global_position,
		_cam.global_rotation_degrees.x, _cam.fov, vp.x, vp.y])
	var pts := {
		"near_left": Vector3(-HALF_LEN, 0.0, HALF_DEPTH),
		"near_centre": Vector3(0.0, 0.0, HALF_DEPTH),
		"near_right": Vector3(HALF_LEN, 0.0, HALF_DEPTH),
		"far_left": Vector3(-HALF_LEN, 0.0, -HALF_DEPTH),
		"far_centre": Vector3(0.0, 0.0, -HALF_DEPTH),
		"far_right": Vector3(HALF_LEN, 0.0, -HALF_DEPTH),
		"net_top_centre": Vector3(0.0, NET_H, 0.0),
		"ball": BALL_POS,
		"athlete_feet": ATHLETE_POS,
	}
	for k in pts:
		var sp := _cam.unproject_position(pts[k])
		_log("FRAMING %-15s px=(%7.1f,%7.1f) frac=(%.4f,%.4f)" % [k, sp.x, sp.y, sp.x / vp.x, sp.y / vp.y])
	_log("FRAMING_TARGETS web 960x700 frame: near_y_frac=0.98143 far_y_frac=0.14286 near_x_frac=0.05..0.95 far_x_frac=0.21875..0.78125 net_y_frac=0.51183")

func _ready() -> void:
	var view := OS.get_environment("ARENA_VIEW")
	if view.is_empty():
		view = "default"
	_log("ARENA_SPIKE_START view=%s" % view)
	_log("COURT source js/data.js: left=%.1f right=%.1f top=%.1f bottom=%.1f netY=%.1f netHeight=%.1f" % [
		C_LEFT, C_RIGHT, C_TOP, C_BOTTOM, C_NET_Y, C_NET_H])
	_log("COURT derived with PX_TO_M=%.3f: length=%.3f m across X, depth=%.3f m along Z, net=%.3f m, service line=%.3f m" % [
		PX_TO_M, COURT_LEN, COURT_DEPTH, NET_H, SERVICE_Z])
	_log("COURT aspect check: COURT %dx%d px -> %.3f ; real padel 20x10 -> 2.000 (mismatch is a finding)" % [
		int(C_RIGHT - C_LEFT), int(C_BOTTOM - C_TOP), COURT_LEN / COURT_DEPTH])
	_log("RENDERER=%s ADAPTER=%s API=%s" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version()])

	_build_lights_world()
	_build_court()
	_load_athlete()
	_setup_camera(view)

	for _i in FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_report_framing()

	var path := OS.get_environment("ARENA_PNG")
	if path.is_empty():
		path = "user://arena_spike.png"
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("ARENA_FAIL: viewport texture null")
		get_tree().quit(3)
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("ARENA_FAIL: viewport image null")
		get_tree().quit(4)
		return
	var err := img.save_png(path)
	_log("ARENA_SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])
	if err != OK:
		push_error("ARENA_FAIL: save_png %d" % err)
		get_tree().quit(5)
		return
	_log("ARENA_PASS")
	get_tree().quit(0)
