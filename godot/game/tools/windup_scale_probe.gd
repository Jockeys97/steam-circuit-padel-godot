extends SceneTree
## How big is the wind-up, per athlete and per stroke, at several weights?
## Measures the RENDERED pose (post-modifier) through bone attachments, so the
## numbers describe what the frame draws. Read-only.
##
##   $GODOT --headless --path godot/ --script res://game/tools/windup_scale_probe.gd
const Spawn = preload("res://src/character/athlete_spawn.gd")
const WEIGHTS := [0.3, 0.5, 0.7, 0.85]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for id in [&"fiamma", &"maestro", &"oracolo", &"colosso"]:
		var rig = Spawn.make(id, &"base")
		if rig == null:
			print("WINDUP missing rig ", id)
			continue
		root.add_child(rig)
		var prob := {}
		for bone in ["RightHand", "Head"]:
			var att := BoneAttachment3D.new()
			att.bone_name = rig._resolve_bone_name(bone)
			rig.get_skeleton().add_child(att)
			prob[bone] = att
		rig.play_locomotion(&"ready")
		rig._anim.pause()
		for i in 3:
			await process_frame
		var names: Array = rig.get_stroke_names()
		var want: Array = []
		for n in ["meshy_drive", "meshy_backhand", "meshy_smash", "meshy_slice", "drive", "serve"]:
			if n in names:
				want.append(StringName(n))
		for stroke in want:
			var line := []
			rig.set_anticipation(stroke, 0.0)
			await process_frame
			var hand0: Vector3 = prob["RightHand"].global_position
			var head0: Vector3 = prob["Head"].global_position
			for w in WEIGHTS:
				rig.set_anticipation(stroke, w, 0.34)
				await process_frame
				line.append("w%.2f hand=%.3fm head=%.3fm" % [
					w, prob["RightHand"].global_position.distance_to(hand0),
					prob["Head"].global_position.distance_to(head0)])
			print("WINDUP %-9s %-15s %s" % [String(id), String(stroke), "  ".join(line)])
		rig.free()
	print("WINDUP_DONE")
	quit(0)
