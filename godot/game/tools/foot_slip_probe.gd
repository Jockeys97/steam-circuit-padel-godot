extends SceneTree
## foot_slip_probe.gd — how much a PLANTED foot slides, measured in a real match.
##
## Plays a quick match with the scripted player (`use_scripted_input`, the controller's
## own harness path) at a fixed 60 fps, so the simulation and the animation advance by
## the same delta. Every frame, for every athlete, each foot (ankle bone) counts as
## planted when it is within PLANT_M of the lowest height that foot reaches; a foot
## planted in two consecutive frames should not move, so its horizontal travel between
## them is SLIP. Reported per clip the rig was playing (locomotion state or stroke):
## support-foot frames, median and 90th-percentile slip speed (m/s), and the share of planted
## frames sliding faster than VISIBLE_MPS.
##
## Run:  godot --headless --fixed-fps 60 --path godot --script res://game/tools/foot_slip_probe.gd
## Env:  FRAMES=3600 (1 minute)
const Config := preload("res://game/match_config.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const PLANT_M := 0.035
const VISIBLE_MPS := 0.25
const TELEPORT_MPS := 20.0

var _min_y := {}
var _prev := {}
var _stats := {}


func _initialize() -> void:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	call_deferred("run")


func _rigs(node: Node, out: Array) -> void:
	if node.has_method("get_skeleton") and node.has_method("is_stroking"):
		out.append(node)
		return
	for c in node.get_children():
		_rigs(c, out)


## The RENDERED foot: a BoneAttachment3D follows the pose after the skeleton
## modifiers (the pose layer, the foot planter); `get_bone_global_pose` would read
## the clip underneath, which the modifiers never persist into.
var _attach := {}
func _foot(rig, side: String) -> Vector3:
	var key := "%d%s" % [rig.get_instance_id(), side]
	if not _attach.has(key):
		var att := BoneAttachment3D.new()
		att.bone_name = rig._resolve_bone_name(side + "Foot")
		rig.get_skeleton().add_child(att)
		_attach[key] = att
	return (_attach[key] as BoneAttachment3D).global_position


func run() -> void:
	var game: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(game)
	game.use_scripted_input = true
	# A headless run skips the rigs on purpose (`harness_mode`); this probe needs them.
	if game.has_method("build_athletes"):
		print("BUILT ", game.build_athletes())
	var frames := int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 3600
	for i in 30:
		await process_frame
	var rigs: Array = []
	_rigs(game, rigs)
	print("RIGS ", rigs.size())
	# Calibrate each foot's floor height over the first seconds.
	for f in frames:
		await process_frame
		for r in rigs.size():
			var rig = rigs[r]
			if not is_instance_valid(rig) or not rig.visible:
				continue
			var clip: String = String(rig._stroke) if rig.is_stroking() else String(rig._locomotion)
			# The SUPPORT foot: of the feet on the floor this frame and the last, the
			# slower one. With a perfect clip it stands still while the other swings.
			var support := INF
			for side in ["Left", "Right"]:
				var key := "%d%s" % [r, side]
				var p := _foot(rig, side)
				_min_y[key] = minf(float(_min_y.get(key, p.y)), p.y)
				var planted := p.y <= float(_min_y[key]) + PLANT_M
				if f > 120 and planted and _prev.has(key) and bool(_prev[key]["planted"]):
					support = minf(support, Vector2(p.x - _prev[key]["p"].x, p.z - _prev[key]["p"].z).length() * 60.0)
				_prev[key] = {"p": p, "planted": planted}
			# Point resets move athletes by metres in one frame: not a slide.
			if support < TELEPORT_MPS:
				var s: Dictionary = _stats.get_or_add(clip, {"n": 0, "sum": 0.0, "vals": []})
				s["n"] += 1
				s["sum"] += support
				(s["vals"] as Array).append(support)
	var total_n := 0
	var total_fast := 0
	var rows: Array = []
	for clip in _stats:
		var s: Dictionary = _stats[clip]
		var vals: Array = s["vals"]
		vals.sort()
		var fast := 0
		for v in vals:
			if v > VISIBLE_MPS: fast += 1
		total_n += int(s["n"]); total_fast += fast
		rows.append([int(s["n"]), "SLIP %-26s planted_frames=%5d median=%.2f p90=%.2f visible=%3.0f%%" % [clip, int(s["n"]), float(vals[int(vals.size() * 0.5)]) if vals.size() > 0 else 0.0, float(vals[int(vals.size() * 0.9)]) if vals.size() > 0 else 0.0, 100.0 * fast / maxf(1.0, float(vals.size()))]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows:
		print(r[1])
	print("SLIP_TOTAL planted_frames=%d visible=%.0f%%" % [total_n, 100.0 * total_fast / maxf(1.0, float(total_n))])
	quit()
