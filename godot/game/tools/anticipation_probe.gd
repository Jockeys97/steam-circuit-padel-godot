extends SceneTree
## Measures the anticipation layer on a real match: plays one match headless
## (the human side is `game/scripted_player.gd`, the same stand-in the slice
## run uses; the opponents are the sim's AI), syncs the rigs every tick, and on every stroke records how
## wound-up the hitter was on the tick before contact and which clip the
## wind-up predicted. Out-of-band instrument; writes nothing to the game.
##
##   $GODOT --headless --path godot/ --script res://game/tools/anticipation_probe.gd -- --ticks=12000
const Sim := preload("res://src/sim/sim.gd")
const Config := preload("res://game/match_config.gd")
const Scripted := preload("res://game/scripted_player.gd")

const TICK := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var ticks := 12000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			ticks = int(a.substr(8))
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 2
	var node: Node = (load("res://game/Match.tscn") as PackedScene).instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	var rigs: int = node.build_athletes()
	var view = node._athletes
	var strokes := 0
	var wound := 0          # weight >= 0.3 on the tick before contact
	var weights: Array = []
	var clip_match := 0
	var clip_known := 0
	var last_weight := {}
	var last_pred := {}
	var look_max := 0.0
	var swing_prev := {}
	var pairs := {}
	var jumps_on: Array = []
	var jumps_off: Array = []
	var human = Scripted.new()
	for i in ticks:
		node.tick_fixed(TICK, human.decide(node.state), Sim.empty_input())
		if node.state == null or node.state.result != null:
			break
		# Rendered upper-body pose of each rig BEFORE this tick's sync, and the same
		# pose without the layer: the pose jump at contact is measured against both.
		var before_rendered := {}
		var before_clip := {}
		for role in view.rigs:
			var r = view.rigs[role]
			var sk: Skeleton3D = r.get_skeleton()
			var lay = r._pose_layer
			var rendered := {}
			var clip := {}
			for bone in _prep_indices(r):
				var q: Quaternion = sk.get_bone_pose_rotation(bone)
				clip[bone] = q
				rendered[bone] = (q * Quaternion.IDENTITY.slerp(lay.prep_pose[bone], lay.prep_weight)).normalized() if lay.prep_pose.has(bone) and lay.prep_weight > 0.0 else q
			before_rendered[role] = rendered
			before_clip[role] = clip
		view.sync(node.state, TICK)
		for role in view.rigs:
			var r = view.rigs[role]
			var sw2 := float(node.state.paddle(role).swing)
			if sw2 > 0.0 and not bool(swing_prev.get(role, false)) and not node.state.serving:
				var sk: Skeleton3D = r.get_skeleton()
				var j_on := 0.0
				var j_off := 0.0
				for bone in before_clip[role]:
					var contact: Quaternion = sk.get_bone_pose_rotation(bone)
					j_on += rad_to_deg(before_rendered[role][bone].angle_to(contact))
					j_off += rad_to_deg(before_clip[role][bone].angle_to(contact))
				jumps_on.append(j_on)
				jumps_off.append(j_off)
		# The whole run happens inside one engine frame, so the AnimationPlayers
		# would never advance: step them by the tick, as the render loop would.
		for role in view.rigs:
			view.rigs[role]._anim.advance(TICK)
		for role in view.rigs:
			var rig = view.rigs[role]
			var sw := float(node.state.paddle(role).swing)
			var edge: bool = sw > 0.0 and not bool(swing_prev.get(role, false))
			swing_prev[role] = sw > 0.0
			look_max = maxf(look_max, absf(rig.get_look_yaw()))
			if edge and not node.state.serving and String(node.state.paddle(role).actionIntent) != "serve":
				strokes += 1
				var w: float = float(last_weight.get(role, 0.0))
				weights.append(w)
				if w >= 0.3:
					wound += 1
					clip_known += 1
					if StringName(last_pred.get(role, &"")) == StringName(view._last_stroke[role]):
						clip_match += 1
					var pair := "%s->%s" % [last_pred.get(role, &""), view._last_stroke[role]]
					pairs[pair] = int(pairs.get(pair, 0)) + 1
			var ant: Dictionary = rig.get_anticipation()
			last_weight[role] = float(ant["weight"]) if not rig.is_stroking() else 0.0
			last_pred[role] = ant["stroke"]
	weights.sort()
	var median: float = weights[weights.size() / 2] if not weights.is_empty() else 0.0
	print("ANTICIPATION_PROBE rigs=%d ticks=%d strokes=%d wound_before_contact=%d (%.0f%%) median_weight=%.2f predicted_clip_matches=%d/%d look_max_deg=%.1f" % [
		rigs, i_or(ticks), strokes, wound, 100.0 * wound / maxf(1.0, strokes), median, clip_match, clip_known, look_max])
	print("ANTICIPATION_PAIRS ", pairs)
	jumps_on.sort()
	jumps_off.sort()
	if not jumps_on.is_empty():
		print("CONTACT_JUMP_DEG (sum over upper-body bones, contact tick) n=%d  with_layer: median=%.0f p90=%.0f   without_layer: median=%.0f p90=%.0f" % [
			jumps_on.size(), jumps_on[jumps_on.size() / 2], jumps_on[int(jumps_on.size() * 0.9)],
			jumps_off[jumps_off.size() / 2], jumps_off[int(jumps_off.size() * 0.9)]])
	quit(0)


func _prep_indices(rig) -> Array:
	var out := []
	for name in rig.PREP_BONES:
		var i: int = rig.get_skeleton().find_bone(rig._resolve_bone_name(name))
		if i >= 0 and not i in out:
			out.append(i)
	return out


func i_or(v: int) -> int:
	return v
