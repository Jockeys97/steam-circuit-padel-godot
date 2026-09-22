extends SceneTree
## Where does the racket hand END UP in each candidate preparation frame?
## Forward kinematics from the animation tracks only (no playback, no mutation),
## in the rig's local frame: +Z = towards the net, so a real take-back has the
## hand at z < 0 and/or raised (y above the hip). "Protecting himself with the
## racket" is the hand in FRONT of the chest: z > 0 at chest height.
##
##   $GODOT --headless --path godot/ --script res://game/tools/prep_pose_probe.gd
const Spawn = preload("res://src/character/athlete_spawn.gd")
const CHAIN := ["Hips", "Spine", "Spine01", "Spine02", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]
const CONTACTS := {
	&"meshy_drive": 0.34, &"meshy_backhand": 0.34, &"meshy_smash": 0.46, &"meshy_bandeja": 0.38,
	&"meshy_slice": 0.32, &"drive": 0.34, &"slice": 0.32, &"lob": 0.40, &"serve": 0.30, &"volley": 0.5,
}


## Local transform of every chain bone at time t, from the clip's rotation tracks
## (rest positions), then the hand's origin in the rig's local frame.
func hand_local(rig: Node3D, anim: Animation, t: float) -> Vector3:
	var sk: Skeleton3D = rig.get_skeleton()
	var xform := {}
	for name in CHAIN:
		var idx: int = sk.find_bone(rig._resolve_bone_name(name))
		if idx < 0:
			continue
		var local := sk.get_bone_rest(idx)
		var track := anim.find_track(NodePath("%s:%s" % [rig._track_prefix, sk.get_bone_name(idx)]), Animation.TYPE_ROTATION_3D)
		if track >= 0:
			var q: Quaternion = anim.rotation_track_interpolate(track, t)
			local.basis = Basis(q).scaled(local.basis.get_scale())
		xform[idx] = {"local": local, "parent": sk.get_bone_parent(idx)}
	# Accumulate to the hand.
	var hand: int = sk.find_bone(rig._resolve_bone_name("RightHand"))
	if not xform.has(hand):
		return Vector3.ZERO
	var chain: Array = []
	var cur := hand
	while cur >= 0 and xform.has(cur):
		chain.push_front(cur)
		cur = int(xform[cur]["parent"])
	var acc := Transform3D.IDENTITY
	for idx in chain:
		acc = acc * (xform[idx]["local"] as Transform3D)
	return acc.origin


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for id in [&"fiamma", &"maestro", &"colosso"]:
		var rig = Spawn.make(id, &"base")
		if rig == null:
			continue
		root.add_child(rig)
		var sk: Skeleton3D = rig.get_skeleton()
		var ready_anim: Animation = rig._anim.get_animation(&"ready")
		print("PREP %-9s ready_hand_local=%s" % [String(id), str(hand_local(rig, ready_anim, 0.6))])
		for stroke in rig.get_stroke_names():
			var anim: Animation = rig._anim.get_animation(stroke)
			if anim == null:
				continue
			var contact_phase: float = float(CONTACTS.get(stroke, 0.5))
			var contact := anim.length * contact_phase
			# Same rule the rig uses: furthest from frame 0 over the pre-contact window.
			var best_t := 0.0
			var best := -1.0
			for step in range(1, 25):
				var t := contact * float(step) / 24.0
				var score := 0.0
				for name in CHAIN:
					var idx: int = sk.find_bone(rig._resolve_bone_name(name))
					if idx < 0:
						continue
					var track := anim.find_track(NodePath("%s:%s" % [rig._track_prefix, sk.get_bone_name(idx)]), Animation.TYPE_ROTATION_3D)
					if track >= 0:
						score += anim.rotation_track_interpolate(track, 0.0).angle_to(anim.rotation_track_interpolate(track, t))
				if score > best:
					best = score
					best_t = t
			var hand := hand_local(rig, anim, best_t)
			# Best PREPARATION frame in the same window: hand behind the torso
			# plane and/or raised, normalised by the athlete's own torso length.
			var hips := hand_local(rig, anim, 0.0)
			var head_scale: float = maxf(0.2, absf(hand.y - hips.y))
			var score_t := 0.0
			var score := -INF
			for step in range(3, 25):
				var t := contact * float(step) / 24.0
				var h := hand_local(rig, anim, t)
				var s: float = (-h.z + 0.5 * (h.y - hips.y)) / head_scale
				if s > score:
					score = s
					score_t = t
			var sh := hand_local(rig, anim, score_t)
			print("PREP %-9s %-15s maxdev t=%.2f z=%+.3f | bestscore t=%.2f z=%+.3f y=%.3f score=%+.2f  %s" % [
				String(id), String(stroke), best_t, hand.z, score_t, sh.z, sh.y, score,
				"SCUDO" if sh.z > 0.02 else "dietro"])
		rig.free()
	print("PREP_DONE")
	quit(0)
