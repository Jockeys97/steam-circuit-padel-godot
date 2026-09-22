extends SceneTree
const Spawn = preload("res://src/character/athlete_spawn.gd")
func _initialize():
	var rig = Spawn.make(&"maestro", &"mythic")
	for name in ["idle", "walk", "run"]:
		var clip: Animation = rig._anim.get_animation(name)
		print("CLIP ",name," prefix=",rig._track_prefix)
		for i in clip.get_track_count():
			if "Arm" in str(clip.track_get_path(i)) and clip.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				print(clip.track_get_path(i), " ",clip.rotation_track_interpolate(i,clip.length*0.25).get_euler())
	rig.free()
	quit()
