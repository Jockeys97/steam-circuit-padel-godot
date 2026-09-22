extends SceneTree
const View = preload("res://game/athletes_view.gd")
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
const Spawn = preload("res://src/character/athlete_spawn.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func _initialize(): call_deferred("run")
func run():
	var view := View.new()
	root.add_child(view)
	view.spawn({"player":{"id":"fiamma"}, "opponent":{"id":"maestro"}}, {}, {})
	var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.serving = false
	state.lastHitterSide = "player"
	view.sync(state, 1.0/60.0)
	var rig = view.rigs.player
	state.player.motion = 1.0
	state.player.x += 2.0
	view.sync(state, 1.0/60.0)
	check(rig.get_locomotion_state() == &"shuffle_left", "near-side shuffle")
	check(rig.rotation_degrees.z > 0.0, "start leans into lateral travel")
	var cadence: float = rig._locomotion_speed_scale
	state.player.x += 4.0
	view.sync(state, 1.0/30.0)
	check(is_equal_approx(cadence, rig._locomotion_speed_scale), "cadence independent of frame rate")
	state.player.x += 0.5
	view.sync(state, 1.0/60.0)
	check(rig._locomotion_speed_scale < cadence, "slower displacement slows feet")
	# Strong activity signal must not keep a stopped character running in place.
	view.sync(state, 1.0/60.0)
	check(rig.get_locomotion_state() == &"brake", "stop overrides smoothed motion=1")
	for i in 15:
		state.player.x -= 2.0
		view.sync(state, 1.0/60.0)
	check(rig.get_locomotion_state() == &"shuffle_right" and rig.rotation_degrees.z < 0.0, "reversal changes feet and weight")
	for i in 60: view.sync(state, 1.0/60.0)
	check(absf(rig.rotation_degrees.z) < 0.01, "braking tilt settles to neutral")
	state.opponent.motion = 1.0
	state.opponent.x += 2.0
	view.sync(state, 1.0/60.0)
	check(view.rigs.opponent.get_locomotion_state() == &"shuffle_right", "far-side directions mirrored")
	state.player.y += 2.0
	view.sync(state, 1.0/60.0)
	check(rig.get_locomotion_state() == &"backpedal", "retreat uses backpedal")
	state.opponent.y -= 2.0
	view.sync(state, 1.0/60.0)
	check(view.rigs.opponent.get_locomotion_state() == &"backpedal", "far-side retreat uses backpedal")
	rig.play_stroke_at(&"meshy_drive", 0.34)
	var shot_speed: float = rig._anim.speed_scale
	state.player.x += 2.0
	view.sync(state, 1.0/60.0)
	check(rig.is_stroking() and is_equal_approx(shot_speed, rig._anim.speed_scale), "movement leaves stroke speed intact")
	check(rig.rotation_degrees.x == 0.0 and rig.rotation_degrees.z == 0.0, "no tilt on contact pose")
	var position_before := Vector2(state.player.x, state.player.y)
	view.sync(state, 0.0)
	check(position_before == Vector2(state.player.x, state.player.y), "view never changes simulated coordinates")
	state.player.x += 100.0
	view.sync(state, 1.0/60.0)
	check(view._visual_velocity.player == Vector2.ZERO and view._visual_lean.player == Vector2.ZERO, "teleport clears inertia")
	state.serving = true
	view.sync(state, 1.0/60.0)
	check(view._visual_lean.player == Vector2.ZERO, "serve has no residual weight")
	view.free()
	# Both skeleton families and every geometry outfit, not just the main athlete.
	for id in [&"maestro", &"fiamma", &"pantera", &"steamer", &"oracolo", &"colosso"]:
		for outfit in [&"base", &"mythic"]:
			var model = Spawn.make(id, outfit)
			root.add_child(model)
			var retreat: Animation = model._anim.get_animation(&"backpedal")
			for bone in ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]:
				var path := NodePath("%s:%s" % [model._track_prefix, model._resolve_bone_name(bone)])
				var track := retreat.find_track(path, Animation.TYPE_ROTATION_3D)
				check(track >= 0, str(id)+str(outfit)+" retreat bone "+bone)
				if track < 0: continue
				var first := retreat.rotation_track_interpolate(track, 0.0)
				var last := retreat.rotation_track_interpolate(track, retreat.length)
				check(first.angle_to(last) < 0.001, "retreat seamless loop")
				var lift := retreat.rotation_track_interpolate(track, retreat.length * 0.25)
				var reach := retreat.rotation_track_interpolate(track, retreat.length * 0.75)
				check(lift.angle_to(reach) > deg_to_rad(15.0), "retreat visibly articulates leg/foot")
			for clip in [&"shuffle_left", &"shuffle_right", &"backpedal", &"brake"]:
				check(model.play_clip(clip), str(id)+str(outfit)+str(clip))
				for phase in [0.0, 0.25, 0.5, 0.75, 0.99]:
					model.sample_at(model.get_clip_length(clip)*phase)
					var finite := true
					for bone in model.get_skeleton().get_bone_count():
						finite = finite and model.get_skeleton().get_bone_pose_rotation(bone).is_finite()
					check(finite and model.position == Vector3.ZERO, "finite in-place pose")
			model.free()
	print("LOCOMOTION_WEIGHT ", checks-failures, "/", checks)
	quit(1 if failures else 0)
