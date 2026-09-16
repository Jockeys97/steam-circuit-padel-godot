## rig_probe.gd — read-only structural probe of the three Volpe GLBs.
##
## Prints the exact node tree, Skeleton3D bone names, AnimationPlayer clip names and
## every animation track path, so the rig scene can be designed against measured facts
## instead of assumptions. Writes nothing. Not a test; the test is
## res://tests/athlete_rig_test.gd.
##
## Run:
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://src/character/tools/rig_probe.gd
extends SceneTree

const GLBS := [
	"res://assets/athletes/volpe-rigged.glb",
	"res://assets/athletes/volpe-walking.glb",
	"res://assets/athletes/volpe-running.glb",
]


func _init() -> void:
	for path in GLBS:
		_probe(path)
	print("PROBE_DONE")
	quit(0)


func _probe(path: String) -> void:
	print("")
	print("=== GLB %s ===" % path)
	if not FileAccess.file_exists(path):
		print("  MISSING")
		return
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var t0 := Time.get_ticks_msec()
	var err := doc.append_from_file(path, st)
	print("  append err=%d (%d ms)" % [err, Time.get_ticks_msec() - t0])
	if err != OK:
		return
	var root := doc.generate_scene(st)
	if root == null:
		print("  generate_scene returned null")
		return
	print("  root class=%s name=%s" % [root.get_class(), root.name])
	_dump(root, root, "  ")
	root.free()


func _dump(n: Node, root: Node, ind: String) -> void:
	print("%s- %s [%s]" % [ind, n.name, n.get_class()])
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		var names := PackedStringArray()
		for i in sk.get_bone_count():
			names.append("%d:%s(p=%d)" % [i, sk.get_bone_name(i), sk.get_bone_parent(i)])
		print("%s  SKELETON bone_count=%d" % [ind, sk.get_bone_count()])
		print("%s  BONES %s" % [ind, ", ".join(names)])
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m := mi.mesh
		if m != null:
			print("%s  MESH surfaces=%d skin=%s" % [ind, m.get_surface_count(), str(mi.skin != null)])
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s)
				print("%s   surf%d faces=%d mat=%s(%s) fmt=%d" % [
					ind, s, m.surface_get_array_len(s) / 3,
					(mat.resource_name if mat else "<null>"),
					(mat.get_class() if mat else "-"),
					m.surface_get_format(s)])
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					var tex := sm.albedo_texture
					print("%s   surf%d STD shading_mode=%d albedo_color=%s roughness=%.4f metallic=%.4f tex=%s" % [
						ind, s, sm.shading_mode, str(sm.albedo_color), sm.roughness, sm.metallic,
						("%dx%d" % [tex.get_width(), tex.get_height()]) if tex else "<none>"])
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		print("%s  ANIMPLAYER root_node=%s libs=%s" % [ind, str(ap.root_node), str(ap.get_animation_library_list())])
		for a in ap.get_animation_list():
			var anim := ap.get_animation(a)
			print("%s   CLIP '%s' len=%.4f loop=%d step=%.4f tracks=%d" % [
				ind, a, anim.length, anim.loop_mode, anim.step, anim.get_track_count()])
			for t in mini(anim.get_track_count(), 6):
				print("%s    track%d type=%d path=%s keys=%d" % [
					ind, t, anim.track_get_type(t), str(anim.track_get_path(t)),
					anim.track_get_key_count(t)])
	for c in n.get_children():
		_dump(c, root, ind + "  ")
