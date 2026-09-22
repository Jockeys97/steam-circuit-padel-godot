extends SceneTree
const Spawn = preload("res://src/character/athlete_spawn.gd")
const PHASES := {"meshy_smash":0.46,"meshy_bandeja":0.38,"meshy_slice":0.32,"slice":0.32,"serve":0.30,"lob":0.40,"volley":0.5}
func _initialize(): call_deferred("run")
func run():
	for id in [&"fiamma",&"maestro",&"oracolo",&"colosso"]:
		var rig = Spawn.make(id, &"base")
		root.add_child(rig)
		for stroke in rig.get_stroke_names():
			var r: Dictionary = rig.get_prep_readout(StringName(stroke), float(PHASES.get(stroke, 0.34)))
			if r.is_empty(): continue
			var z := float(r["z"]); var raised := float(r["raised"]); var bones := int(r["bones"])
			print("PREPCHK %-9s %-15s bones=%-3d z=%+.2f raised=%+.2f score=%+.2f  %s" % [String(id), String(stroke), bones, z, raised, float(r["score"]), "nessuno" if bones == 0 else ("SCUDO" if z > 0.05 else "dietro/alto")])
		rig.free()
	print("PREPCHK_DONE")
	quit(0)
