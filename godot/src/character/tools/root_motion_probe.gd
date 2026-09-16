## root_motion_probe.gd — measures how far each clip translates the Hips bone.
## Read-only diagnostic for the blank/undersized frames in the first render.
extends SceneTree

const RigScene := preload("res://src/character/AthleteRig.tscn")


func _initialize() -> void:
	var rig: Node3D = RigScene.instantiate()
	root.add_child(rig)
	var sk: Skeleton3D = rig.get_skeleton()
	var hips := sk.find_bone("Hips")
	print("rest Hips position = %s" % str(sk.get_bone_rest(hips).origin))
	for clip in [&"idle", &"walk", &"run", &"drive"]:
		if not rig.play_clip(clip):
			print("%s: not registered" % clip)
			continue
		var length: float = rig.get_clip_length(clip)
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for i in 33:
			rig.sample_at(length * float(i) / 32.0)
			var p: Vector3 = sk.get_bone_pose_position(hips)
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
		print("%-6s len=%.4f Hips pos min=%s max=%s span=%s" % [
			clip, length, str(lo), str(hi), str(hi - lo)])
	# What the drive stroke inherits when it follows `run` (no Hips position track):
	rig.play_clip(&"run")
	rig.sample_at(rig.get_clip_length(&"run") * 0.75)
	var after_run: Vector3 = sk.get_bone_pose_position(hips)
	rig.play_clip(&"drive")
	rig.sample_at(0.1)
	print("after run@0.75 Hips=%s -> during drive@0.1 Hips=%s (drive has no Hips position track)"
		% [str(after_run), str(sk.get_bone_pose_position(hips))])
	print("PROBE_DONE")
	quit(0)
