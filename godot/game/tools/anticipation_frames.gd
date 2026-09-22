extends SceneTree
## Renders the anticipation + look layers on a real match frame, A/B:
## the same tick, camera and pose, once with the layers and once with them
## switched off. Writes to --out=<dir> (default user://anticipation), never to
## game/out (shared with the capture harness).
##
##   $GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ \
##     --script res://game/tools/anticipation_frames.gd -- --out=/tmp/ant
const Sim := preload("res://src/sim/sim.gd")
const Config := preload("res://game/match_config.gd")
const Scripted := preload("res://game/scripted_player.gd")
const TICK := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("run")


func _save(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("FRAME ", path)


func _layers(view, on: bool, saved: Dictionary) -> void:
	for role in view.rigs:
		var lay = view.rigs[role]._pose_layer
		if not on:
			saved[role] = [lay.prep_weight, lay.look_yaw_degrees]
			lay.prep_weight = 0.0
			lay.look_yaw_degrees = 0.0
		else:
			lay.prep_weight = saved[role][0]
			lay.look_yaw_degrees = saved[role][1]


func run() -> void:
	var out := ProjectSettings.globalize_path("user://anticipation")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 2
	Config.seed_value = 20260916
	var node: Node = (load("res://game/Match.tscn") as PackedScene).instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	await process_frame
	var view = node._athletes
	if view == null or view.rigs.is_empty():
		print("ANTICIPATION_FRAMES no rigs (models off?)")
		quit(1)
		return
	var human = Scripted.new()
	var shots := 0
	for i in 20000:
		node.tick_fixed(TICK, human.decide(node.state), Sim.empty_input())
		node._sync_views()
		for role in view.rigs:
			view.rigs[role]._anim.advance(TICK)
		var s = node.state
		if s.result != null or shots >= 3:
			break
		for role in view.rigs:
			var w: float = float(view.rigs[role].get_anticipation()["weight"])
			if w > 0.75 and int(s.rallyHits) >= 2 + shots * 3:
				var tag := "%d-%s" % [shots, role]
				var saved := {}
				for r in view.rigs:
					var rr = view.rigs[r]
					print("POSE %s role=%s ant=%.2f stroke=%s look=%.1f" % [tag, r, rr.get_anticipation()["weight"], rr.get_anticipation()["stroke"], rr.get_look_yaw()])
				var cam: Camera3D = root.get_viewport().get_camera_3d()
				if cam != null:
					var p: Vector2 = cam.unproject_position(view.rigs[role].global_position + Vector3(0, 1.0, 0))
					print("SUBJECT %s px=(%.0f,%.0f)" % [tag, p.x, p.y])
				view.rigs[role]._anim.pause()
				await _save("%s/ant-%s-on.png" % [out, tag])
				_layers(view, false, saved)
				await _save("%s/ant-%s-off.png" % [out, tag])
				_layers(view, true, saved)
				view.rigs[role]._anim.play()
				shots += 1
				break
	print("ANTICIPATION_FRAMES shots=%d" % shots)
	quit(0)
