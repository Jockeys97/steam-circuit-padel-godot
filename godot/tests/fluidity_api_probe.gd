extends SceneTree
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for id in [&"colosso", &"maestro", &"fornaio", &"fiamma"]:
		var rig = AthleteSpawn.make(id, &"base")
		if rig == null:
			print(id, " -> NULL")
			continue
		print("=== ", id, " glb=", rig.get_athlete_glb_path(), " tri=", rig.get_triangle_count())
		for clip in [&"idle", &"walk", &"run"]:
			if not rig._anim.has_animation(clip):
				print("  ", clip, " MISSING")
				continue
			var a: Animation = rig._anim.get_animation(clip)
			var types := {}
			for i in a.get_track_count():
				var t: int = a.track_get_type(i)
				types[t] = int(types.get(t, 0)) + 1
			var hips_pos := a.find_track(NodePath("%s:%s" % [rig._track_prefix, rig._resolve_bone_name("Hips")]), Animation.TYPE_POSITION_3D)
			var hips_rot := a.find_track(NodePath("%s:%s" % [rig._track_prefix, rig._resolve_bone_name("Hips")]), Animation.TYPE_ROTATION_3D)
			print("  ", clip, " len=%.3f loop=%d tracks=%d types=%s hi_pos=%d hi_rot=%d" % [a.length, a.loop_mode, a.get_track_count(), str(types), hips_pos, hips_rot])
		rig.free()
	quit(0)
