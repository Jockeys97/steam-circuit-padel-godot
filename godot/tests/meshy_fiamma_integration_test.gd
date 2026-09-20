extends SceneTree
const View = preload("res://game/athletes_view.gd")
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
var failures := 0
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func _initialize(): call_deferred("run")
func run():
	var view := View.new()
	root.add_child(view)
	view.spawn({"player":{"id":"fiamma"},"opponent":{"id":"maestro"}}, {}, {})
	var rig = view.rigs.player
	check(&"meshy_drive" in rig.get_stroke_names(),"Fiamma has Meshy clip")
	check(&"meshy_drive" in view.rigs.opponent.get_stroke_names(),"Maestro has its dedicated retarget")
	var state = Sim.create_match_state("quick",Frozen.athletes()[0],Frozen.arenas()[0],Frozen.ai_opponents()[0])
	state.player.actionIntent = "drive"
	state.player.swing = 1.0
	view._sync_stroke("player",rig,state.player)
	check(rig._anim.current_animation == "meshy_drive","Live bridge selects imported forehand")
	check(absf(rig.get_pose().time-0.62*0.34)<0.001,"Same immediate contact phase")
	var clip: Animation = rig._anim.get_animation("meshy_drive")
	for track in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			check(clip.position_track_interpolate(track,0).distance_to(clip.position_track_interpolate(track,0.3))<0.0001,"No imported root/limb translation")
	rig.play_locomotion(&"run")
	rig._anim.advance(1.0)
	check(not rig.is_stroking() and rig._anim.current_animation == "run","Returns to locomotion")
	state.player.swing = 0
	view._sync_stroke("player",rig,state.player)
	state.player.swing = 1
	state.player.actionIntent = "smash"
	view._sync_stroke("player",rig,state.player)
	check(rig._anim.current_animation == "meshy_smash","Smash selects its dedicated approved clip")
	view.free()
	print("MESHY_FIAMMA_INTEGRATION failures=",failures)
	quit(1 if failures else 0)
