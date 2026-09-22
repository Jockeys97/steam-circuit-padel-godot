extends SceneTree
const View = preload("res://game/athletes_view.gd")
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize(): call_deferred("run")
func run():
	var athlete := "fiamma"
	var outfit := "base"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--athlete="): athlete = arg.trim_prefix("--athlete=")
		if arg.begins_with("--outfit="): outfit = arg.trim_prefix("--outfit=")
	var view := View.new()
	root.add_child(view)
	view.spawn({"player":{"id":athlete},"opponent":{"id":"maestro"}}, {"player":StringName(outfit)}, {})
	var rig = view.rigs.player
	if outfit == "mythic":
		rig.play_locomotion(&"idle")
		rig.sample_at(0.45)
		var idle_skeleton: Skeleton3D = rig.get_skeleton()
		idle_skeleton.force_update_all_bone_transforms()
		for side in ["Left", "Right"]:
			var hand_index := idle_skeleton.find_bone(side + "Hand")
			var shoulder_index := idle_skeleton.find_bone(side + "Shoulder")
			var hand_y := idle_skeleton.to_global(idle_skeleton.get_bone_global_pose(hand_index).origin).y
			var shoulder_y := idle_skeleton.to_global(idle_skeleton.get_bone_global_pose(shoulder_index).origin).y
			check(shoulder_y - hand_y > 0.30, "Mythic idle lowers " + side + " arm below A-pose")
	var state = Sim.create_match_state("quick",Frozen.athletes()[0],Frozen.arenas()[0],Frozen.ai_opponents()[0])
	for entry in [["smash","smash",20.0],["bandeja","bandeja",20.0],["drive","backhand",-20.0],["slice","slice",20.0],["drive","drive",20.0]]:
		state.player.swing = 0
		view._sync_stroke("player",rig,state.player)
		state.player.swing = 1
		state.player.actionIntent = entry[0]
		view._sync_stroke("player",rig,state.player,float(state.player.x)+entry[2])
		var name := "meshy_"+String(entry[1])
		check(rig._anim.current_animation==name,"Live dispatch "+name)
		var clip: Animation = rig._anim.get_animation(name)
		var phase: float = View.stroke_recipe(entry[0]).contact_phase
		check(absf(rig.get_pose().time-clip.length*phase)<0.001,"Contact timing "+name)
		if entry[1] == "smash":
			var skeleton: Skeleton3D = rig.get_skeleton()
			skeleton.force_update_all_bone_transforms()
			var hand := skeleton.find_bone(rig._resolve_bone_name("RightHand"))
			var head := skeleton.find_bone(rig._resolve_bone_name("Head"))
			var hand_world := skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
			var head_world := skeleton.to_global(skeleton.get_bone_global_pose(head).origin)
			check(hand_world.y > head_world.y,"Smash contact hand is above head, no doubled bind-pose bend")
		for track in clip.get_track_count():
			if clip.track_get_type(track)==Animation.TYPE_POSITION_3D:
				check(clip.position_track_interpolate(track,0).distance_to(clip.position_track_interpolate(track,clip.length*0.5))<0.0001,"No root translation "+name)
		for time in [0.0,clip.length*phase,clip.length]:
			rig.sample_at(time)
			var sk: Skeleton3D = rig.get_skeleton()
			sk.force_update_all_bone_transforms()
			var head_index := sk.find_bone(rig._resolve_bone_name("Head"))
			var hips_index := sk.find_bone(rig._resolve_bone_name("Hips"))
			check(sk.to_global(sk.get_bone_global_pose(head_index).origin).y > sk.to_global(sk.get_bone_global_pose(hips_index).origin).y,"Body remains upright "+name)
			for bone in rig.get_skeleton().get_bone_count():
				check(rig.get_skeleton().get_bone_pose_rotation(bone).is_finite(),"Finite bone pose")
		check(view.rackets.player.get_parent() is BoneAttachment3D,"Racket still follows hand")
		rig.play_stroke_at(StringName(name),phase,1.0)
		rig.play_locomotion(&"run")
		rig._anim.advance(1.0)
		check(not rig.is_stroking(),"Stroke finishes "+name)
		check(rig._anim.current_animation=="run","Recovery "+name)
	check(View.meshy_stroke_for("drive","opponent",0,20)==&"meshy_backhand","Far side reverses handedness")
	check(View.meshy_stroke_for("drive","opponent",0,-20)==&"meshy_drive","Far side forehand")
	for word in ["serve","volley","cut-volley","lob","vibora","wall-angle"]:
		check(View.meshy_stroke_for(word,"player",0,20)==&"","Unchanged other intent "+word)
	check(&"meshy_smash" in view.rigs.opponent.get_stroke_names(),"Maestro has its own retarget")
	# Simulate an unavailable imported clip in memory; no asset files touched.
	rig._strokes.erase(&"meshy_slice")
	state.player.swing = 0
	view._sync_stroke("player",rig,state.player)
	state.player.swing = 1
	state.player.actionIntent = "slice"
	view._sync_stroke("player",rig,state.player)
	check(rig._anim.current_animation == "slice","Missing imported stroke retains procedural fallback")
	view.free()
	if "--capture" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 9.5
		camera.position = Vector3(0,4.0,10)
		camera.look_at(Vector3(0,4.0,0))
		camera.current = true
		var light := DirectionalLight3D.new()
		root.add_child(light)
		light.rotation_degrees = Vector3(-30,-20,0)
		var shots := ["smash","bandeja","backhand","slice"]
		for row in 4:
			for col in 3:
				var sample := View.new()
				root.add_child(sample)
				sample.spawn({"player":{"id":athlete}}, {"player":StringName(outfit)}, {})
				sample.position = Vector3((col-1)*1.7,(3-row)*2.0,0)
				var r = sample.rigs.player
				r.set_facing_degrees(0)
				var phase: float = [0.0,0.38,0.78][col]
				if col==1: phase=View.stroke_recipe("drive" if shots[row]=="backhand" else shots[row]).contact_phase
				r.play_stroke_at(StringName("meshy_"+shots[row]),phase,1)
				r._anim.pause()
				var label := Label3D.new()
				label.text = shots[row]+" "+str(col)
				label.font_size = 26
				label.position = Vector3(0,1.9,0)
				sample.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://../docs/agent-work/meshy-roster-retarget")
		DirAccess.make_dir_recursive_absolute(output)
		var capture_id := athlete if outfit == "base" else athlete + "-" + outfit
		root.get_texture().get_image().save_png(output+"/%s-poses.png" % capture_id)
	print("MESHY_STROKES ",athlete," ",checks-failures,"/",checks)
	quit(1 if failures else 0)
