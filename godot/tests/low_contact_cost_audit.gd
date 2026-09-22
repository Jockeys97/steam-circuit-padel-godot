extends SceneTree
const Spawn = preload("res://src/character/athlete_spawn.gd")
func _initialize(): call_deferred("run")
func run():
	for id in [&"maestro",&"fiamma",&"pantera",&"colosso",&"oracolo",&"steamer"]:
		var rig = Spawn.make(id,&"base")
		root.add_child(rig)
		for clip in [&"meshy_drive",&"meshy_backhand",&"meshy_slice"]:
			var times: Array = []
			for repeat in 3:
				var start := Time.get_ticks_usec()
				rig.play_stroke_at(clip,0.34,1.0,1.0)
				times.append(float(Time.get_ticks_usec()-start)/1000.0)
			print("CLIP_COST ",id," ",clip," ms=",times)
		rig.free()
	quit()
