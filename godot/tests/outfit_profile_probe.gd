extends SceneTree
## Throwaway smoke probe while wiring the masked outfit path. Kept out of the
## acceptance set; the real regression test is outfit_fiamma_profile_test.gd.
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var C := load("res://src/character/outfit_catalogue.gd")
	var rig = load("res://src/character/athlete_spawn.gd").make(&"fiamma", &"base")
	print("PROBE base read_back=", C.read_back(rig))
	print("PROBE apply circuit=", C.apply(rig, &"fiamma", &"circuit"))
	print("PROBE circuit read_back=", C.read_back(rig))
	print("PROBE apply base=", C.apply(rig, &"fiamma", &"base"))
	print("PROBE base2 read_back=", C.read_back(rig))
	print("PROBE profile keys=", C.profile(&"fiamma").keys())
	print("PROBE volpe=", C.has_profile(&"maestro"), C.has_profile(&"colosso"))
	rig.free()
	print("OUTFIT_PROFILE_PROBE_DONE")
	quit()
