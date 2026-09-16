## extent_probe.gd — the real world-space extent of the posed athlete, and the scale
## chain that produces it.
##
## MeshInstance3D.get_aabb() on a SKINNED mesh returns mesh-space (bind) bounds and is
## NOT the posed silhouette. Bone global poses are. Everything here is read from local
## transforms so it works in a headless SceneTree where global transforms are unset.
extends SceneTree

const RigScene := preload("res://src/character/AthleteRig.tscn")


func _initialize() -> void:
	var rig: Node3D = RigScene.instantiate()
	root.add_child(rig)
	var sk: Skeleton3D = rig.get_skeleton()
	var mi: MeshInstance3D = rig.get_mesh_instance()

	print("mesh-space aabb pos=%s size=%s" % [str(mi.get_aabb().position), str(mi.get_aabb().size)])
	var chain := Transform3D.IDENTITY
	var n: Node = mi
	var names := PackedStringArray()
	while n != null and n != rig.get_parent():
		if n is Node3D:
			chain = (n as Node3D).transform * chain
			names.append("%s scale=%s origin=%s" % [
				n.name, str((n as Node3D).transform.basis.get_scale()), str((n as Node3D).transform.origin)])
		n = n.get_parent()
	print("scale chain (leaf->root): %s" % ", ".join(names))
	print("accumulated transform scale=%s origin=%s" % [
		str(chain.basis.get_scale()), str(chain.origin)])

	# Skeleton-local bone extent per clip, then the same extent through the chain.
	for clip in [&"idle", &"walk", &"run", &"drive", &"serve"]:
		if not rig.play_clip(clip):
			continue
		var length: float = rig.get_clip_length(clip)
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for i in 17:
			rig.sample_at(length * float(i) / 16.0)
			for b in sk.get_bone_count():
				var p: Vector3 = sk.get_bone_global_pose(b).origin
				lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
				hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
		var wlo := chain * lo
		var whi := chain * hi
		print("%-6s bone-local size=%s  ->  world lo=%s hi=%s size=%s" % [
			clip, str(hi - lo), str(wlo), str(whi), str((whi - wlo).abs())])
	print("PROBE_DONE")
	quit(0)
