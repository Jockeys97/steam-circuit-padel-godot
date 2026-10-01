extends SceneTree
const Pilot := preload("res://prototypes/creator_b/pilot_rig.gd")
func _initialize() -> void:
	var rig := Pilot.new()
	if rig.get_load_error() != OK:
		rig.free()
		quit(1)
		return
	var failed := false
	for name in rig._anim.get_animation_list():
		var destination := ""
		if name in [&"walk", &"run"]:
			destination = "res://assets/custom_character/corpo_uomo_b-%s.tres" % name
		elif String(name).begins_with("meshy_"):
			destination = "res://assets/athletes/animations/cc_uomo_b_%s.tres" % name
		if destination != "":
			var err := ResourceSaver.save(rig._anim.get_animation(name), destination)
			failed = failed or err != OK
			print(destination, " ", err)
	rig.free()
	quit(1 if failed else 0)
