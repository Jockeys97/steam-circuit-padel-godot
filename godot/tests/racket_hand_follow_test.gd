extends SceneTree
const View = preload("res://game/athletes_view.gd")
var failures := 0
func _initialize():
	call_deferred("run")
func run():
	var cases := []
	for id in ["maestro", "fiamma", "oracolo", "colosso", "fornaio", "pantera"]:
		cases.append([id, "base"])
	cases.append(["maestro", "mythic"])
	var poses := 0
	for entry in cases:
		var id: String = entry[0]
		var view = View.new()
		root.add_child(view)
		view.spawn({"player": {"id": id}}, {"player":StringName(entry[1])}, {})
		var rig = view.rigs["player"]
		var racket: Node3D = view.rackets["player"]
		var anchor = racket.get_parent()
		if not anchor is BoneAttachment3D:
			failures += 1
		for clip in ["idle", "run", "drive", "volley", "smash"]:
			poses += 1
			if clip in ["idle", "run"]:
				rig.play_locomotion(StringName(clip))
			else:
				rig.play_stroke_at(StringName(clip), 0.5)
			for frame in 3:
				await process_frame
			var grip := racket.to_global(Vector3(0, -0.24, 0))
			var distance := grip.distance_to(anchor.global_position)
			var size := racket.global_basis.get_scale().x
			# Some legacy clips include bone scale (~1.18): preserve that motion,
			# but reject centimetre/metre mistakes and a detached grip.
			if distance < 0.045 or distance > 0.08 or size < 0.85 or size > 1.30:
				push_error("Bad grip %s %s distance=%s scale=%s" % [id, clip, distance, size])
				failures += 1
		view.free()
	print("RACKET_HAND_FOLLOW ", poses, " poses failures=", failures)
	quit(1 if failures else 0)
