extends SceneTree
## Anticipation + look layers (`src/character/athlete_pose_layer.gd`,
## `game/athletes_view.gd::_sync_anticipation/_sync_look`). Presentation only:
## the checks assert that the layers move the RENDERED pose (the skeleton
## after the modifier stack), never the clip's own bone poses, never the
## simulated paddle, and that contact still starts at the authored frame.
const Spawn = preload("res://src/character/athlete_spawn.gd")
const View = preload("res://game/athletes_view.gd")
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
const Court = preload("res://game/court.gd")

var failures := 0
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)


func _initialize() -> void:
	call_deferred("run")


## A bone as the renderer sees it (after the modifier stack). The skeleton's
## own `get_bone_global_pose` is restored after modifiers, so it cannot see
## the layer; a BoneAttachment3D is what the racket uses and what we measure.
var _probes: Dictionary = {}
func _probe(rig: Node3D, bone: String) -> BoneAttachment3D:
	var key := "%d:%s" % [rig.get_instance_id(), bone]
	if not _probes.has(key):
		var att := BoneAttachment3D.new()
		att.bone_name = rig._resolve_bone_name(bone)
		rig.get_skeleton().add_child(att)
		_probes[key] = att
	return _probes[key]

func _rendered(rig: Node3D, bone: String) -> Vector3:
	return _probe(rig, bone).global_position


func _settle(rig: Node3D) -> void:
	await process_frame
	await process_frame


func run() -> void:
	# --- Pure helpers -------------------------------------------------------
	check(is_equal_approx(View.look_yaw_towards(Vector3.ZERO, 0.0, Vector3(0, 1, 5)), 0.0), "ball dead ahead -> no look")
	check(View.look_yaw_towards(Vector3.ZERO, 0.0, Vector3(5, 1, 5)) > 40.0, "ball ahead-left (+X, facing +Z) -> positive yaw")
	check(View.look_yaw_towards(Vector3.ZERO, 0.0, Vector3(-5, 1, 5)) < -40.0, "ball ahead-right -> negative yaw")
	check(absf(View.look_yaw_towards(Vector3.ZERO, 0.0, Vector3(0.2, 1, -5))) < 1.0, "ball behind -> look fades out")
	check(is_equal_approx(View.look_yaw_towards(Vector3.ZERO, 180.0, Vector3(0, 1, -5)), 0.0), "near team facing -Z sees the net ahead")
	var avail := [&"meshy_drive", &"meshy_backhand", &"meshy_smash", &"drive"]
	check(View.anticipation_stroke(avail, "opponent", 400.0, 380.0, 20.0)["clip"] == &"meshy_drive", "low ball on the forehand side -> drive")
	check(View.anticipation_stroke(avail, "opponent", 400.0, 440.0, 20.0)["clip"] == &"meshy_backhand", "low ball on the other side -> backhand")
	check(View.anticipation_stroke(avail, "opponent", 400.0, 400.0, 95.0)["clip"] == &"meshy_smash", "high ball -> overhead")
	check(View.anticipation_stroke([&"drive"], "player", 400.0, 380.0, 20.0)["clip"] == &"drive", "rig without Meshy clips falls back to the authored drive")

	# --- Rig layers, per athlete ------------------------------------------
	for id in [&"fiamma", &"maestro", &"oracolo", &"colosso", &"fornaio"]:
		var rig = Spawn.make(id, &"base")
		if rig == null:
			check(false, "missing rig " + String(id))
			continue
		root.add_child(rig)
		rig.play_locomotion(&"ready")
		rig._anim.pause()
		for b in ["RightHand", "Head", "LeftFoot"]: _probe(rig, b)
		await _settle(rig)
		var hand0 := _rendered(rig, "RightHand")
		var head0 := _rendered(rig, "Head")
		var clip_q: Quaternion = rig.get_skeleton().get_bone_pose_rotation(rig.get_skeleton().find_bone(rig._resolve_bone_name("RightArm")))
		var stroke: StringName = &"meshy_drive" if &"meshy_drive" in rig.get_stroke_names() else &"drive"
		rig.set_anticipation(stroke, 1.0, 0.34)
		check(is_equal_approx(float(rig.get_anticipation()["weight"]), rig.ANTICIPATION_MAX), String(id) + " anticipation clamps to ANTICIPATION_MAX")
		await _settle(rig)
		var hand1 := _rendered(rig, "RightHand")
		check(hand1.distance_to(hand0) > 0.05, String(id) + " wind-up moves the racket hand (%.3f m)" % hand1.distance_to(hand0))
		check(_rendered(rig, "RightHand").distance_to(hand0) < 1.2, String(id) + " wind-up stays a backswing, not a teleport")
		var clip_q1: Quaternion = rig.get_skeleton().get_bone_pose_rotation(rig.get_skeleton().find_bone(rig._resolve_bone_name("RightArm")))
		# 0.01 rad (0.6 deg): a persisted 0.85 backswing would be tens of degrees;
		# oracolo's paused clip alone drifts ~0.001 rad between the two reads.
		check(clip_q.angle_to(clip_q1) < 0.01, String(id) + " layer does not persist into the clip's bone pose (%.5f rad)" % clip_q.angle_to(clip_q1))
		# Contact drops the anticipation on the same call.
		check(rig.play_stroke_at(stroke, 0.34, 1.0), String(id) + " stroke plays")
		check(float(rig.get_anticipation()["weight"]) == 0.0, String(id) + " contact cancels anticipation")
		rig.set_anticipation(stroke, 1.0, 0.34)
		check(float(rig.get_anticipation()["weight"]) == 0.0, String(id) + " anticipation refused while stroking")
		rig._anim.advance(2.0)
		check(not rig.is_stroking(), String(id) + " stroke finishes")
		rig.set_anticipation(&"", 0.0)
		rig.play_locomotion(&"ready")
		rig._anim.pause()
		await _settle(rig)
		var foot0 := _rendered(rig, "LeftFoot")
		rig.set_look_yaw(40.0)
		await _settle(rig)
		check(_rendered(rig, "Head").distance_to(head0) < 0.25, String(id) + " look turns the head in place")
		check(is_equal_approx(rig.get_look_yaw(), 40.0), String(id) + " look yaw reads back")
		check(_rendered(rig, "LeftFoot").distance_to(foot0) < 0.002, String(id) + " look leaves the feet planted")
		# Head forward axis should turn towards +X when yaw is positive (facing 0 = +Z).
		# Compared against -40 rather than 0: with a paused clip and an inert
		# layer the skeleton is not dirtied, so an attachment keeps its last pose.
		var fwd := _probe(rig, "Head").global_transform.basis.z
		rig.set_look_yaw(-40.0)
		await _settle(rig)
		var fwd0 := _probe(rig, "Head").global_transform.basis.z
		var turn := rad_to_deg(Vector2(fwd0.x, fwd0.z).angle_to(Vector2(fwd.x, fwd.z))) * 0.5
		check(absf(absf(turn) - 40.0) < 6.0, String(id) + " head turns by the requested yaw (%.1f deg)" % turn)
		check(Vector2(fwd.x, fwd.z).normalized().x > Vector2(fwd0.x, fwd0.z).normalized().x, String(id) + " positive yaw turns the head towards +X")
		rig.set_look_yaw(200.0)
		check(is_equal_approx(rig.get_look_yaw(), rig.LOOK_MAX_DEGREES), String(id) + " look yaw clamped")
		rig.set_look_yaw(NAN)
		check(rig.get_look_yaw() == 0.0, String(id) + " NaN look yaw is ignored")
		check(rig.position == Vector3.ZERO, String(id) + " no root motion")
		rig.free()

	# --- View bridge on a live state ---------------------------------------
	var view := View.new()
	root.add_child(view)
	view.spawn({"player": {"id": "fiamma"}, "opponent": {"id": "maestro"}}, {}, {})
	var s = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	s.serving = false
	s.pointPause = 0.0
	s.lastHitterSide = "ai"
	# Ball flying at the player, 0.2 s away, slightly to the side.
	s.ball.vy = 600.0
	s.ball.vx = 0.0
	s.ball.vz = 60.0
	s.ball.z = 30.0
	s.ball.x = s.player.x - 20.0
	s.ball.y = s.player.y - 600.0 * 0.2
	s.playerMate.x = s.player.x + 400.0
	var before := {"x": s.player.x, "y": s.player.y, "bx": s.ball.x, "by": s.ball.y}
	for i in 30:
		view.sync(s, 1.0 / 60.0)
	check(float(view._anticipation["player"]) > 0.5, "incoming ball winds the receiver up (%.2f)" % float(view._anticipation["player"]))
	check(float(view._anticipation.get("opponent", 0.0)) == 0.0, "the hitter's side does not wind up")
	check(before == {"x": s.player.x, "y": s.player.y, "bx": s.ball.x, "by": s.ball.y}, "the view never writes the simulation")
	check(absf(float(view._look["opponent"])) >= 0.0, "look tracked for every rig")
	# Partner closer to the ball: not mine.
	s.playerMate.x = s.ball.x
	for i in 30:
		view.sync(s, 1.0 / 60.0)
	check(float(view._anticipation["player"]) < 0.05, "partner's ball: no wind-up (%.3f)" % float(view._anticipation["player"]))
	s.playerMate.x = s.player.x + 400.0
	for i in 30:
		view.sync(s, 1.0 / 60.0)
	# Contact edge: the sim swings -> anticipation is dropped on that sync.
	s.player.swing = 1.0
	s.player.actionIntent = "drive"
	view.sync(s, 1.0 / 60.0)
	check(view.rigs.player.is_stroking(), "swing edge plays the stroke")
	check(float(view.rigs.player.get_anticipation()["weight"]) == 0.0, "contact frame is unblended")
	# Service resets both layers.
	s.player.swing = 0.0
	view.rigs.player._anim.advance(2.0)
	s.serving = true
	view.sync(s, 1.0 / 60.0)
	check(float(view._anticipation["player"]) == 0.0, "no wind-up during service")
	view.free()

	# --- Regression: the wind-up never folds the athlete ---------------------
	# The layer once stored the stroke clip's ABSOLUTE spine rotations and
	# slerped the locomotion pose towards them; on pantera and steamer, whose
	# stroke and locomotion clips disagree on the spine's frame, that folded the
	# torso to 82 deg from vertical mid-rally. Now it composes a bounded delta.
	# Every athlete of the roster, every locomotion clip the wind-up can ride
	# on, the strongest wind-up: the RENDERED torso (Hips->Head) may not lean
	# more than FOLD_MAX_DEG further than the very same frame without it.
	const FOLD_MAX_DEG := 8.0
	var worst_fold := 0.0
	var worst_fold_where := ""
	for id in Spawn.ids():
		var rig = Spawn.make(StringName(id), &"base")
		if rig == null:
			check(false, "missing rig " + String(id))
			continue
		root.add_child(rig)
		var names: Array = rig.get_stroke_names()
		for clip in [&"ready", &"prepare", &"shuffle_left", &"shuffle_right", &"backpedal", &"run", &"brake"]:
			for stroke in [&"meshy_drive", &"meshy_backhand", &"meshy_slice", &"meshy_smash"]:
				if not stroke in names:
					continue
				var pitches := []
				for weight in [0.0, 1.0]:
					rig.play_locomotion(clip)
					rig._anim.seek(0.09, true, true)
					rig._anim.pause()
					rig.set_anticipation(stroke, weight, 0.46 if stroke == &"meshy_smash" else 0.34)
					await _settle(rig)
					var torso: Vector3 = _rendered(rig, "Head") - _rendered(rig, "Hips")
					pitches.append(rad_to_deg(torso.normalized().angle_to(rig.global_transform.basis.y.normalized())))
				var extra: float = float(pitches[1]) - float(pitches[0])
				if extra > worst_fold:
					worst_fold = extra
					worst_fold_where = "%s %s+%s (%.0f -> %.0f deg)" % [id, clip, stroke, pitches[0], pitches[1]]
				check(extra <= FOLD_MAX_DEG, "%s: wind-up %s over %s leans the torso %.1f deg further (%.0f -> %.0f)" % [id, stroke, clip, extra, pitches[0], pitches[1]])
		rig.free()
	print("ANTICIPATION_FOLD worst_extra_deg=%.1f at %s" % [worst_fold, worst_fold_where])

	print("ANTICIPATION_LOOK ", checks - failures, "/", checks)
	quit(0 if failures == 0 else 1)
