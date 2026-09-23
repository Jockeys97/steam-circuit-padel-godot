extends SceneTree
## Hunts the "folded in half" pose on a real match: plays a match headless
## (scripted human vs sim AI, same stand-in as anticipation_probe), advances the
## rigs every tick and measures on every rig
##   torso pitch = angle(Hips->Neck, rig up)          0 = upright
##   knee flexion = 180 - angle(thigh, shin), worst leg
## and records, per clip, the worst frame: which clip, at what clip time, and
## whether the pitch comes from the clip itself or from the pose layer.
## Out-of-band instrument; writes nothing to the game.
##
##   $GODOT --headless --path godot/ --script res://game/tools/fold_probe.gd -- --ticks=12000 [--tier=3]
const Sim := preload("res://src/sim/sim.gd")
const Config := preload("res://game/match_config.gd")
const Scripted := preload("res://game/scripted_player.gd")

const TICK := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("run")


## World-space bone position (the skeleton node itself is rotated/scaled on
## some exports, so skeleton-local "up" is not the world's).
func _gpos(sk: Skeleton3D, rig, name: String) -> Vector3:
	var i: int = sk.find_bone(rig._resolve_bone_name(name))
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO


## Hips->Head against the RIG's own up (in a match the rig sits under the court
## node, whose frame is not the world's). Head, not Neck: the Volpe/Maestro
## skeleton has no Neck bone.
func _pitch(sk: Skeleton3D, rig) -> float:
	var t := _gpos(sk, rig, "Head") - _gpos(sk, rig, "Hips")
	var up: Vector3 = (rig.global_transform.basis.y).normalized()
	return rad_to_deg(t.normalized().angle_to(up)) if t.length() > 0.0001 else 0.0


func _knee(sk: Skeleton3D, rig, side: String) -> float:
	var hip := _gpos(sk, rig, side + "UpLeg")
	var knee := _gpos(sk, rig, side + "Leg")
	var foot := _gpos(sk, rig, side + "Foot")
	var a := (hip - knee).normalized()
	var b := (foot - knee).normalized()
	return 180.0 - rad_to_deg(a.angle_to(b))


## Same pitch with the pose layer's rotations composed in (what is RENDERED).
func _pitch_layered(sk: Skeleton3D, rig) -> float:
	var lay = rig._pose_layer
	if lay == null:
		return _pitch(sk, rig)
	var saved := {}
	for i in sk.get_bone_count():
		saved[i] = sk.get_bone_pose_rotation(i)
	if lay.has_method("_process_modification"):
		lay._process_modification()
	elif lay.has_method("_process_modification_with_delta"):
		lay._process_modification_with_delta(TICK)
	sk.force_update_all_bone_transforms()
	var p := _pitch(sk, rig)
	for i in saved:
		sk.set_bone_pose_rotation(i, saved[i])
	sk.force_update_all_bone_transforms()
	return p


func run() -> void:
	var ticks := 12000
	var tier := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			ticks = int(a.substr(8))
		elif a.begins_with("--tier="):
			tier = int(a.substr(7))
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = tier
	var node: Node = (load("res://game/Match.tscn") as PackedScene).instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	var rigs: int = node.build_athletes()
	var view = node._athletes
	var human = Scripted.new()
	var worst := {}      # clip -> {pitch, layered, knee, t, role, athlete, tick}
	var hist := {}       # pitch bucket (10 deg) -> count
	var samples := 0
	for tick in ticks:
		node.tick_fixed(TICK, human.decide(node.state), Sim.empty_input())
		if node.state == null or node.state.result != null:
			break
		view.sync(node.state, TICK)
		for role in view.rigs:
			view.rigs[role]._anim.advance(TICK)
		for role in view.rigs:
			var rig = view.rigs[role]
			var sk: Skeleton3D = rig.get_skeleton()
			sk.force_update_all_bone_transforms()
			var clip := String(rig._anim.current_animation)
			var p := _pitch(sk, rig)
			var k := maxf(_knee(sk, rig, "Left"), _knee(sk, rig, "Right"))
			samples += 1
			var bucket := int(p / 10.0) * 10
			hist[bucket] = int(hist.get(bucket, 0)) + 1
			var w: Dictionary = worst.get(clip, {"pitch": -1.0})
			if p > float(w["pitch"]):
				worst[clip] = {"pitch": p, "layered": _pitch_layered(sk, rig), "knee": k,
					"t": rig._anim.current_animation_position, "len": rig._anim.current_animation_length,
					"role": role, "athlete": String(rig.name), "tick": tick,
					"stroking": rig.is_stroking(), "ant": rig.get_anticipation()}
	print("FOLD samples=%d rigs=%d" % [samples, rigs])
	var keys := hist.keys()
	keys.sort()
	for b in keys:
		print("FOLD_HIST pitch %3d-%3d deg: %6d  (%.1f%%)" % [b, b + 10, hist[b], 100.0 * hist[b] / maxf(1, samples)])
	var clips := worst.keys()
	clips.sort_custom(func(a, b): return float(worst[a]["pitch"]) > float(worst[b]["pitch"]))
	for c in clips:
		var w: Dictionary = worst[c]
		print("FOLD_WORST %-26s pitch=%5.1f layered=%5.1f knee=%5.1f t=%.2f/%.2f role=%s rig=%s tick=%d stroking=%s ant=%s" % [
			c, w["pitch"], w["layered"], w["knee"], w["t"], w["len"], w["role"], w["athlete"], w["tick"], w["stroking"], w["ant"]])
	quit(0)
