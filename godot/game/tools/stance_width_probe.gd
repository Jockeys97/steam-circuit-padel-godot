extends SceneTree
## stance_width_probe.gd — how wide the feet are while the athletes shuffle, in a real match.
## Same harness as foot_slip_probe.gd (scripted player, fixed 60 fps, rendered feet).
## Reports, over every frame an athlete is on a planted footwork clip: the horizontal
## distance between the feet, split into its lateral part (along the athlete's X) and
## its fore-aft part, as median / p90 / max.
##
## Run: godot --headless --fixed-fps 60 --path godot --script res://game/tools/stance_width_probe.gd
const Config := preload("res://game/match_config.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const CLIPS := [&"shuffle_left", &"shuffle_right", &"backpedal", &"brake", &"prepare", &"ready"]

var _attach := {}


func _initialize() -> void:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	# PACE=<preset id> plays at that pace on a throwaway profile (the real one untouched).
	if OS.get_environment("PACE") != "":
		Config.save_dir = "user://probe-pace-%d" % Time.get_ticks_usec()
		var store = Config.save_store()
		store.write_group("prefs", {"pacePreset": OS.get_environment("PACE")})
		print("PACE ", OS.get_environment("PACE"), " factor ", Config.pace_factor())
	call_deferred("run")


func _rigs(node: Node, out: Array) -> void:
	if node.has_method("get_skeleton") and node.has_method("is_stroking"):
		out.append(node)
		return
	for c in node.get_children():
		_rigs(c, out)


func _foot(rig, side: String) -> Vector3:
	var key := "%d%s" % [rig.get_instance_id(), side]
	if not _attach.has(key):
		var att := BoneAttachment3D.new()
		att.bone_name = rig._resolve_bone_name(side + "Foot")
		rig.get_skeleton().add_child(att)
		_attach[key] = att
	return (_attach[key] as BoneAttachment3D).global_position


func _stats(vals: Array) -> String:
	if vals.is_empty():
		return "-"
	vals.sort()
	return "median=%.2f p90=%.2f max=%.2f" % [vals[int(vals.size() * 0.5)], vals[int(vals.size() * 0.9)], vals[vals.size() - 1]]


func run() -> void:
	var game: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(game)
	game.use_scripted_input = true
	game.build_athletes()
	for i in 30:
		await process_frame
	var rigs: Array = []
	_rigs(game, rigs)
	var lat := {}
	var fore := {}
	var total := {}
	var frames := int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 3600
	for f in frames:
		await process_frame
		if f < 120:
			continue
		for rig in rigs:
			if rig.is_stroking() or not rig._locomotion in CLIPS:
				continue
			var d: Vector3 = _foot(rig, "Left") - _foot(rig, "Right")
			d.y = 0.0
			var x: Vector3 = rig.global_transform.basis.x
			x.y = 0.0
			x = x.normalized()
			var clip := String(rig._locomotion)
			(lat.get_or_add(clip, []) as Array).append(absf(d.dot(x)))
			(fore.get_or_add(clip, []) as Array).append(absf(d.dot(Vector3.UP.cross(x).normalized())))
			(total.get_or_add(clip, []) as Array).append(d.length())
	for clip in total:
		print("STANCE %-14s n=%5d  total %s | lateral %s | fore-aft %s" % [clip, (total[clip] as Array).size(), _stats(total[clip]), _stats(lat[clip]), _stats(fore[clip])])
	quit()
