## Offline rotation-only retarget. Args: stroke, contact seconds (or auto), athlete.
## Never replaces the target mesh/skin or imports source root motion.
extends SceneTree
const Spawn = preload("res://src/character/athlete_spawn.gd")
func _initialize(): call_deferred("run")
func find_type(node: Node, type: String):
	if node.is_class(type): return node
	for child in node.get_children():
		var found = find_type(child, type)
		if found != null: return found
	return null
func run():
	var args := OS.get_cmdline_user_args()
	var stroke := args[0] if args.size() > 0 else "drive"
	var lengths := {"drive":0.62,"smash":0.62,"bandeja":0.54,"backhand":0.62,"slice":0.54}
	var contacts := {"drive":0.34,"smash":0.46,"bandeja":0.38,"backhand":0.34,"slice":0.32}
	if not lengths.has(stroke):
		quit(1)
		return
	var athlete := StringName(args[2]) if args.size() > 2 else &"fiamma"
	var outfit := StringName(args[3]) if args.size() > 3 else &"base"
	var output_id := String(athlete) if outfit == &"base" else "%s_%s" % [athlete, outfit]
	var source_contact: float = float(args[1]) if args.size() > 1 and args[1] != "auto" else {"smash":1.0,"bandeja":1.15,"backhand":1.25,"slice":1.1}.get(stroke,1.5)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var source_path := ProjectSettings.globalize_path("res://../docs/agent-work/meshy-fiamma-trial/fiamma-forehand.glb")
	if stroke != "drive":
		source_path = ProjectSettings.globalize_path("res://../docs/agent-work/meshy-fiamma-strokes/%s.glb" % stroke)
	if doc.append_from_file(source_path, state) != OK:
		quit(1)
		return
	var source := doc.generate_scene(state)
	root.add_child(source)
	var src: Skeleton3D = find_type(source,"Skeleton3D")
	var player: AnimationPlayer = find_type(source,"AnimationPlayer")
	var rig = Spawn.make(athlete, outfit)
	if rig == null:
		quit(1)
		return
	root.add_child(rig)
	var dst: Skeleton3D = rig.get_skeleton()
	var neutral: Animation = rig._anim.get_animation("idle")
	var clip: Animation = neutral.duplicate(true)
	clip.length = lengths[stroke]
	clip.loop_mode = Animation.LOOP_NONE
	for track in clip.get_track_count():
		var value: Variant = clip.track_get_key_value(track,0)
		while clip.track_get_key_count(track): clip.track_remove_key(track,0)
		clip.track_insert_key(track,0,value)
		clip.track_insert_key(track,clip.length,value)
	var mapping := {}
	var tracks := {}
	for i in dst.get_bone_count():
		var name := dst.get_bone_name(i).replace("mixamorig_", "").replace("mixamorig:", "")
		var source_name: String = name
		if dst.get_bone_name(i).begins_with("mixamorig"):
			source_name = {"Spine":"Spine02", "Spine1":"Spine01", "Spine2":"Spine", "Neck":"neck"}.get(name,name)
		var si := src.find_bone(source_name)
		if si < 0: continue
		mapping[i] = si
		var path := NodePath("%s:%s" % [rig._track_prefix,dst.get_bone_name(i)])
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		tracks[i] = track
		while clip.track_get_key_count(track): clip.track_remove_key(track,0)
	player.play("rigify_clip")
	for frame in range(int(round(clip.length*100))+1):
		var t := frame / 100.0
		# Preserve the existing drive contact phase (.34). Source contact is the
		# forward swing at 1.5 s; compress preparation and recovery separately.
		var contact: float = clip.length * contacts[stroke]
		var source_length := player.get_animation("rigify_clip").length
		var source_t := (t/contact)*source_contact if t <= contact else source_contact+(t-contact)/(clip.length-contact)*(source_length-source_contact)
		player.seek(source_t,true,true)
		src.force_update_all_bone_transforms()
		var globals := {}
		for i in dst.get_bone_count():
			var parent := dst.get_bone_parent(i)
			var parent_q: Quaternion = globals.get(parent,Quaternion.IDENTITY)
			var path := NodePath("%s:%s" % [rig._track_prefix,dst.get_bone_name(i)])
			var nt := neutral.find_track(path,Animation.TYPE_ROTATION_3D)
			var q := neutral.rotation_track_interpolate(nt,0.0)
			if mapping.has(i):
				var si: int = mapping[i]
				var delta := src.get_bone_global_pose(si).basis.get_rotation_quaternion() * src.get_bone_global_rest(si).basis.get_rotation_quaternion().inverse()
				var target := delta * dst.get_bone_global_rest(i).basis.get_rotation_quaternion()
				# The 24-joint family shares the source's bone axes, but its bind
				# arm pose is lowered. Reapplying that bind tilt doubles the bend.
				if dst.get_bone_count() == 24:
					target = src.get_bone_global_pose(si).basis.get_rotation_quaternion()
				var transferred := (parent_q.inverse()*target).normalized()
				# Meshy's bandeja includes an exaggerated bow/crouch. Keep the
				# generated arm sweep but constrain the body to an athletic base.
				if stroke == "bandeja":
					var bone_name := dst.get_bone_name(i)
					var constraint_neutral := q
					if dst.get_bone_count() == 24:
						constraint_neutral = src.get_bone_rest(si).basis.get_rotation_quaternion()
					if "Leg" in bone_name or "Foot" in bone_name or "Toe" in bone_name:
						transferred = constraint_neutral.slerp(transferred,0.2)
					elif "Hips" in bone_name or "Spine" in bone_name:
						var angles := (constraint_neutral.inverse()*transferred).get_euler()
						angles.x = clampf(angles.x,-0.12,0.12)
						angles.z = clampf(angles.z,-0.15,0.15)
						transferred = (constraint_neutral*Quaternion.from_euler(angles)).normalized()
				var recovery := smoothstep(clip.length-0.15,clip.length,t)
				q = transferred.slerp(q,recovery).normalized()
				clip.rotation_track_insert_key(tracks[i],t,q)
			globals[i] = parent_q*q
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/athletes/animations"))
	var err := ResourceSaver.save(clip,"res://assets/athletes/animations/%s_meshy_%s.tres" % [output_id,stroke])
	print("MESHY_BAKE athlete=",athlete," mapped=",mapping.size()," length=",clip.length," save=",err)
	source.free()
	rig.free()
	quit(0 if err == OK else 1)
