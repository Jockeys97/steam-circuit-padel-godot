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
	view.spawn({"player":{"id":"fiamma"},"opponent":{"id":"maestro"}}, {}, {})
	var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.serving = false
	state.lastHitterSide = "ai"
	view.sync(state, 1.0/60.0)
	var rig = view.rigs.player
	check(rig.get_locomotion_state() == &"split_step", "receiver bends knees for split")
	check(view.rigs.opponent.get_locomotion_state() != &"split_step", "hitter does not hop")
	check(rig._model_root.position.y > 0.0, "small visible lift")
	state.player.x += 1.0
	view.sync(state, 1.0/60.0)
	check(rig.get_locomotion_state() == &"shuffle_left" and rig._model_root.position.y == 0.0, "movement cancels hop immediately")
	state.player.swing = 1.0
	state.player.actionIntent = "smash"
	view.sync(state, 1.0/60.0)
	check(rig.is_stroking(), "shot begins immediately")
	state.player.swing = 0.0
	for i in 60: rig._anim.advance(1.0/60.0)
	view.sync(state, 1.0/60.0)
	check(rig.get_locomotion_state() == &"recover_right", "finished shot gets balance step")
	var remaining: float = view._recovery_remaining.player
	view.sync(state, 1.0/60.0)
	check(view._recovery_remaining.player < remaining, "recovery is not retriggered every frame")
	state.player.x -= 1.0
	view.sync(state, 1.0/60.0)
	check(rig.get_locomotion_state() == &"shuffle_right", "input overrides recovery immediately")
	state.player.swing = 1.0
	view.sync(state, 1.0/60.0)
	check(rig.is_stroking(), "next shot never blocked")
	state.serving = true
	view.sync(state, 1.0/60.0)
	check(view._recovery_remaining.player == 0.0 and view._split_remaining.player == 0.0, "point reset clears transients")
	view.free()
	for id in [&"maestro", &"fiamma", &"pantera", &"steamer", &"oracolo", &"colosso"]:
		for outfit in [&"base", &"mythic"]:
			var model = Spawn.make(id, outfit)
			root.add_child(model)
			for clip in [&"split_step", &"recover_left", &"recover_right"]:
				check(model.play_clip(clip), str(id)+str(outfit)+str(clip))
				for phase in [0.0, 0.25, 0.5, 0.75, 1.0]:
					model.sample_at(model.get_clip_length(clip)*phase)
					var valid: bool = model.position == Vector3.ZERO
					for bone in model.get_skeleton().get_bone_count():
						valid = valid and model.get_skeleton().get_bone_pose_rotation(bone).is_finite()
					check(valid, "finite pose without root movement")
			model.free()
	print("SPLIT_RECOVERY ",checks-failures,"/",checks)
	quit(1 if failures else 0)
