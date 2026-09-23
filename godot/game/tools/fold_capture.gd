extends SceneTree
## Reproduces the "folded in half" athlete in the REAL match scene (models on,
## rendered), scripted human input like fluidity_match_capture. Every synced
## tick it measures, per rig, torso pitch = angle(Hips->Head, rig up) on the
## POST-modifier pose (BoneAttachment3D on Hips/Head), and saves a PNG of the
## worst moments with what each rig was doing.
##
##   $GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ \
##     --script res://game/tools/fold_capture.gd -- --out=<dir> [--ticks=6000] [--tier=3]
const Sim = preload("res://src/sim/sim.gd")
const Config = preload("res://game/match_config.gd")
const Scripted = preload("res://game/scripted_player.gd")

var _att := {}


func _initialize() -> void:
	call_deferred("run")


func _attach(rig) -> Dictionary:
	var sk: Skeleton3D = rig.get_skeleton()
	var out := {}
	for n in ["Hips", "Head", "LeftFoot", "RightFoot"]:
		var a := BoneAttachment3D.new()
		a.bone_name = rig._resolve_bone_name(n)
		sk.add_child(a)
		out[n] = a
	return out


func run() -> void:
	var out := "/tmp/fold"
	var at_ticks: Array = []   # --at=<tick> (repeatable): always save this tick
	var ticks := 6000
	var tier := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--ticks="): ticks = int(a.substr(8))
		elif a.begins_with("--tier="): tier = int(a.substr(7))
		elif a.begins_with("--at="): at_ticks.append(int(a.substr(5)))
	DirAccess.make_dir_recursive_absolute(out)
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = tier
	var game = load("res://game/Match.tscn").instantiate()
	game.engine_driven = false
	root.add_child(game)
	await process_frame
	var human = Scripted.new()
	var view = game._athletes
	var saved := 0
	var worst_all := 0.0
	var hist := {}
	var per_clip := {}
	for tick in ticks:
		game.tick_fixed(1.0 / 120.0, human.decide(game.state), {})
		if game.state == null or game.state.result != null:
			break
		if tick % 2 != 0:
			continue
		game._sync_views()
		await process_frame
		if view == null:
			view = game._athletes
		for role in view.rigs:
			var rig = view.rigs[role]
			if not _att.has(role):
				_att[role] = _attach(rig)
				print("FOLD_RIG %s athlete=%s outfit=%s bones=%d" % [role, rig._athlete_id, rig.get("_outfit_id") if rig.get("_outfit_id") != null else "?", rig.get_skeleton().get_bone_count()])
		await process_frame   # attachments read the post-modifier pose next frame
		var line := []
		var frame_worst := 0.0
		for role in view.rigs:
			var rig = view.rigs[role]
			var at: Dictionary = _att[role]
			var torso: Vector3 = (at["Head"] as Node3D).global_position - (at["Hips"] as Node3D).global_position
			var up: Vector3 = rig.global_transform.basis.y.normalized()
			var p := rad_to_deg(torso.normalized().angle_to(up))
			var head_over_hips: float = torso.dot(up)
			var clip := String(rig._anim.current_animation)
			var b := int(p / 10.0) * 10
			hist[b] = int(hist.get(b, 0)) + 1
			var pc: Dictionary = per_clip.get(clip, {"max": 0.0, "n": 0})
			pc["n"] = int(pc["n"]) + 1
			if p > float(pc["max"]):
				pc["max"] = p
				pc["role"] = role
				pc["t"] = rig._anim.current_animation_position
				pc["ant"] = rig.get_anticipation()
				pc["intent"] = String(game.state.paddle(role).actionIntent)
			per_clip[clip] = pc
			frame_worst = maxf(frame_worst, p)
			line.append("%s:%s@%.2f pitch=%.0f headUp=%.2f ant=%.2f" % [role, clip, rig._anim.current_animation_position, p, head_over_hips, float(rig.get_anticipation()["weight"])])
		if tick in at_ticks or (frame_worst > 55.0 and saved < 8 and frame_worst > worst_all - 5.0):
			worst_all = maxf(worst_all, frame_worst)
			await RenderingServer.frame_post_draw
			var path := "%s/fold-%05d-%02d.png" % [out, tick, int(frame_worst)]
			root.get_texture().get_image().save_png(path)
			saved += 1
			print("FOLD_FRAME ", path, "  ", " | ".join(line))
	var keys := hist.keys()
	keys.sort()
	for b in keys:
		print("FOLD_HIST %3d-%3d deg: %d" % [b, b + 10, hist[b]])
	for c in per_clip:
		var pc: Dictionary = per_clip[c]
		print("FOLD_CLIP %-34s max=%5.1f n=%5d role=%s t=%s intent=%s ant=%s" % [c, pc["max"], pc["n"], pc.get("role", ""), pc.get("t", ""), pc.get("intent", ""), pc.get("ant", {})])
	print("FOLD_CAPTURE_DONE saved=%d" % saved)
	game.free()
	quit()
