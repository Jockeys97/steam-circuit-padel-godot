extends SceneTree
## Anatomical bend readout, in degrees, on a real match with rigs:
##   knee  = 180 - angle(thigh, shin)         (0 = straight leg)
##   hip   = angle(thigh, world down)         (0 = thigh vertical)
##   lean  = angle(spine axis, world up)      (0 = upright torso)
## Aggregated per stance, so "they bend too much" has a number and an owner.
## Also reports what the ANTICIPATION layer alone adds, by measuring the same
## rig with the layer at weight 0 and at its full weight in one call.
##
##   $GODOT --headless --path godot/ --script res://game/tools/bend_probe.gd -- --ticks=12000
const Sim := preload("res://src/sim/sim.gd")
const Config := preload("res://game/match_config.gd")
const Scripted := preload("res://game/scripted_player.gd")
const Spawn := preload("res://src/character/athlete_spawn.gd")
const TICK := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("run")


func angles(rig: Node3D) -> Dictionary:
	var sk: Skeleton3D = rig.get_skeleton()
	var out := {}
	for side in ["Left", "Right"]:
		var up_i := sk.find_bone(rig._resolve_bone_name(side + "UpLeg"))
		var leg_i := sk.find_bone(rig._resolve_bone_name(side + "Leg"))
		var foot_i := sk.find_bone(rig._resolve_bone_name(side + "Foot"))
		if up_i < 0 or leg_i < 0 or foot_i < 0:
			continue
		var hip: Vector3 = sk.get_bone_global_pose(up_i).origin
		var knee: Vector3 = sk.get_bone_global_pose(leg_i).origin
		var ankle: Vector3 = sk.get_bone_global_pose(foot_i).origin
		var thigh := knee - hip
		var shin := ankle - knee
		out[side + "_knee"] = 180.0 - rad_to_deg(thigh.angle_to(shin))
		var down := -sk.global_transform.basis.y.normalized()
		var world_thigh := sk.global_transform.basis * thigh
		out[side + "_hip"] = rad_to_deg(world_thigh.normalized().angle_to(down))
	var sp_i := sk.find_bone(rig._resolve_bone_name("Spine"))
	var s2_i := sk.find_bone(rig._resolve_bone_name("Spine02"))
	if sp_i >= 0 and s2_i >= 0:
		var a: Vector3 = sk.get_bone_global_pose(sp_i).origin
		var b: Vector3 = sk.get_bone_global_pose(s2_i).origin
		var axis := (sk.global_transform.basis * (b - a)).normalized()
		out["lean"] = rad_to_deg(axis.angle_to(sk.global_transform.basis.y.normalized()))
	return out


## The layer's own contribution, isolated: same rig, same clip, same time.
func layer_delta(rig: Node3D) -> Dictionary:
	var sk: Skeleton3D = rig.get_skeleton()
	var lay = rig._pose_layer
	var base := angles(rig)
	if lay.look_chain.is_empty() and lay.prep_pose.is_empty():
		return {}
	# Force one modification pass synchronously by calling the modifier's method.
	var before_prep: float = lay.prep_weight
	var before_look: float = lay.look_yaw_degrees
	lay._process_modification_with_delta(TICK)
	# The modifier does not persist, so re-run it after reading the clip pose.
	rig._anim.seek(rig._anim.current_animation_position, true, true)
	var with_layer := angles(rig)
	lay._process_modification_with_delta(TICK)
	var after := angles(rig)
	var out := {}
	for k in base:
		if before_prep > 0.0:
			out["prep_" + k] = with_layer.get(k, 0.0) - base.get(k, 0.0)
		if absf(before_look) > 1.0:
			out["look_" + k] = after.get(k, 0.0) - base.get(k, 0.0)
	lay.prep_weight = before_prep
	lay.look_yaw_degrees = before_look
	return out


func run() -> void:
	var ticks := 12000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			ticks = int(a.substr(8))
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 2
	Config.seed_value = 20260916
	var node: Node = (load("res://game/Match.tscn") as PackedScene).instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	node.build_athletes()
	var view = node._athletes
	var human = Scripted.new()
	var stats := {}
	var deltas := {}
	for i in ticks:
		node.tick_fixed(TICK, human.decide(node.state), Sim.empty_input())
		if node.state.result != null:
			break
		view.sync(node.state, TICK)
		for role in view.rigs:
			var r = view.rigs[role]
			r._anim.advance(TICK)
			if i % 5 != 0:
				continue
			var stance := String(r.get_locomotion_state())
			if r.is_stroking():
				stance = "STROKE"
			var a := angles(r)
			if not stats.has(stance):
				stats[stance] = {}
			for k in a:
				var slot: Array = stats[stance].get(k, [0.0, 0.0, 0])
				slot[0] = maxf(slot[0], a[k])
				slot[1] += a[k]
				slot[2] += 1
				stats[stance][k] = slot
			if i > 200:
				var d := layer_delta(r)
				var key := "prep" if float(r.get_anticipation()["weight"]) > 0.5 else ("look" if absf(r.get_look_yaw()) > 1.0 else "")
				if key != "":
					var lab := "%s@%s" % [key, stance]
					if not deltas.has(lab):
						deltas[lab] = {}
					for k in d:
						if k.begins_with(key + "_"):
							var s2: Array = deltas[lab].get(k, [0.0, 0])
							s2[0] = maxf(absf(s2[0]), absf(d[k])) * signf(d[k]) if absf(d[k]) > absf(s2[0]) else s2[0]
							s2[1] += 1
							deltas[lab][k] = s2
	print("ANGLES (degrees, max over sampled ticks / mean)   knee 0=straight, lean 0=upright")
	for stance in stats:
		var s: Dictionary = stats[stance]
		var n: int = int(s.get("Left_knee", [0, 0, 0])[2])
		if n < 20:
			continue
		var parts := []
		for k in ["Left_knee", "Right_knee", "Left_hip", "Right_hip", "lean"]:
			if s.has(k):
				parts.append("%s=%.0f/%.0f" % [k, float(s[k][0]), float(s[k][1]) / maxf(1.0, float(s[k][2]))])
		print("ANGLES %-14s n=%-5d %s" % [stance, n, "  ".join(parts)])
	print("LAYER_DELTA (degrees added by the layer alone, max signed)")
	for lab in deltas:
		var parts := []
		for k in ["Left_knee", "Right_knee", "Left_hip", "Right_hip", "lean"]:
			var kk: String = ("prep_" if lab.begins_with("prep") else "look_") + k
			if deltas[lab].has(kk):
				parts.append("%s=%+.1f" % [k, float(deltas[lab][kk][0])])
		if not parts.is_empty():
			print("LAYER_DELTA %-22s %s" % [lab, "  ".join(parts)])
	quit(0)
