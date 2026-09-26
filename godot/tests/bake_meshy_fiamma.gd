## Offline rotation-only retarget. Args: stroke, contact seconds (or auto), athlete.
## Never replaces the target mesh/skin or imports source root motion.
extends SceneTree
const Spawn = preload("res://src/character/athlete_spawn.gd")
var _loop_start := {}
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
	var lengths := {"drive":0.62,"smash":0.62,"bandeja":0.54,"backhand":0.62,"slice":0.54,"lunge_forehand":0.80,"wall_exit_forehand":0.72,"forehand_volley":0.50,"backhand_volley":0.50,"ready_stance":3.0}
	var contacts := {"drive":0.34,"smash":0.46,"bandeja":0.38,"backhand":0.34,"slice":0.32,"lunge_forehand":0.30,"wall_exit_forehand":0.34,"forehand_volley":0.42,"backhand_volley":0.42,"ready_stance":0.0}
	if not lengths.has(stroke):
		quit(1)
		return
	var athlete := StringName(args[2]) if args.size() > 2 else &"fiamma"
	var outfit := StringName(args[3]) if args.size() > 3 else &"base"
	var output_id := String(athlete) if outfit == &"base" else "%s_%s" % [athlete, outfit]
	var source_contact: float = float(args[1]) if args.size() > 1 and args[1] != "auto" else {"drive":1.0,"smash":1.0,"bandeja":1.15,"backhand":1.25,"slice":1.1,"lunge_forehand":1.1,"wall_exit_forehand":2.05,"forehand_volley":1.0,"backhand_volley":1.1}.get(stroke,1.5)
	# Drive contact moved 1.5 -> 1.0 s (2026-09-26): measured on the rig, the racket hand
	# crosses in front of the body at source 0.95-1.05 s; at 1.5 s it is already wrapped
	# behind the left shoulder. A match starts the clip AT the contact frame, so with 1.5
	# the forward swing was never shown. The forehand volley, cut from the same source,
	# takes the same contact.
	# Volleys (2026-09-26) are cut from the Meshy drive and backhand the owner already
	# plays with: only the end of the backswing, the swing's fastest moment (measured:
	# drive 1.0-1.1 s, backhand 1.1-1.2 s) and a short follow-through, at a reduced
	# amplitude (`amplitudes`) so a full groundstroke becomes a compact punch.
	# The ready stance is a LOOP, not a stroke: sampled 1:1 and closed on its first pose.
	var source_start: float = {"forehand_volley":0.7,"backhand_volley":0.8}.get(stroke, 0.0)
	var source_end: float = {"forehand_volley":1.3,"backhand_volley":1.35}.get(stroke, -1.0)
	# [spine + racket arm, free (left) arm, legs]: how much of the source motion is kept.
	# The drive throws the free arm wide for balance; at the net it stays near the body.
	var amplitudes: Array = {"forehand_volley":[0.55, 0.2, 0.45],"backhand_volley":[0.6, 0.35, 0.45]}.get(stroke, [])
	var looping := stroke == "ready_stance"
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var source_path := ProjectSettings.globalize_path("res://../docs/agent-work/meshy-fiamma-trial/fiamma-forehand.glb")
	if stroke != "drive":
		source_path = ProjectSettings.globalize_path("res://../docs/agent-work/meshy-fiamma-strokes/%s.glb" % stroke)
	if stroke == "forehand_volley":
		source_path = ProjectSettings.globalize_path("res://../docs/agent-work/meshy-fiamma-trial/fiamma-forehand.glb")
	elif stroke == "backhand_volley":
		source_path = ProjectSettings.globalize_path("res://../docs/agent-work/meshy-fiamma-strokes/backhand.glb")
	elif stroke.begins_with("lunge") or stroke.begins_with("wall_exit") or stroke == "ready_stance":
		source_path = ProjectSettings.globalize_path("res://../docs/agent-work/meshy-lunge/%s.glb" % stroke)
	if doc.append_from_file(source_path, state) != OK:
		quit(1)
		return
	var source := doc.generate_scene(state)
	root.add_child(source)
	var src: Skeleton3D = find_type(source,"Skeleton3D")
	var player: AnimationPlayer = find_type(source,"AnimationPlayer")
	# Sources rigged on the 2026-09-24 account (meshy-lunge) share bone names with the
	# 2026-09-20 rig but not every rest pose: Hips differs by 145 deg. The 24-joint
	# targets copy source global rotations as they are, so the body came out bent over
	# (Maestro, rendered). Re-express each source pose against the OLD rig's rest:
	# pose * rest_new^-1 * rest_old. The delta path is unchanged by it.
	var rest_fix := {}
	if source_path.contains("meshy-lunge"):
		var ref_state := GLTFState.new()
		if GLTFDocument.new().append_from_file(ProjectSettings.globalize_path("res://../docs/agent-work/meshy-fiamma-strokes/smash.glb"), ref_state) == OK:
			var ref_scene: Node = GLTFDocument.new().generate_scene(ref_state)
			var ref: Skeleton3D = find_type(ref_scene, "Skeleton3D")
			for si in src.get_bone_count():
				var ri := ref.find_bone(src.get_bone_name(si))
				if ri >= 0:
					rest_fix[si] = src.get_bone_global_rest(si).basis.get_rotation_quaternion().inverse() * ref.get_bone_global_rest(ri).basis.get_rotation_quaternion()
			ref_scene.free()
	var rig = Spawn.make(athlete, outfit)
	if rig == null:
		quit(1)
		return
	root.add_child(rig)
	var dst: Skeleton3D = rig.get_skeleton()
	var neutral: Animation = rig._anim.get_animation("idle")
	var clip: Animation = neutral.duplicate(true)
	clip.length = lengths[stroke]
	clip.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
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
	# The lunge IS a pelvis drop (2026-09-24): rotation-only left the hips at standing
	# height and lifted the feet off the floor. Import the source hips' vertical offset
	# in full and 60% of its sideways step (towards the ball; the sim keeps the athlete's
	# spot, so the rest would slide the planted foot), never the forward travel.
	var hip_track := -1
	var hip_dst := -1
	var hip_src := -1
	var hip_scale := 0.0
	var hip_origin := Vector3.ZERO
	if stroke.begins_with("lunge") or stroke.ends_with("_volley"):
		for i in dst.get_bone_count():
			if dst.get_bone_name(i).ends_with("Hips"): hip_dst = i
		hip_src = src.find_bone("Hips")
		if hip_dst >= 0 and hip_src >= 0:
			var hip_path := NodePath("%s:%s" % [rig._track_prefix, dst.get_bone_name(hip_dst)])
			hip_track = clip.find_track(hip_path, Animation.TYPE_POSITION_3D)
			if hip_track < 0:
				hip_track = clip.add_track(Animation.TYPE_POSITION_3D)
				clip.track_set_path(hip_track, hip_path)
			while clip.track_get_key_count(hip_track): clip.track_remove_key(hip_track, 0)
			hip_scale = dst.get_bone_global_rest(hip_dst).origin.y / src.get_bone_global_rest(hip_src).origin.y
			player.seek(0.0, true, true)
			src.force_update_all_bone_transforms()
			hip_origin = src.get_bone_global_pose(hip_src).origin
	for frame in range(int(round(clip.length*100))+1):
		var t := frame / 100.0
		# Preserve the existing drive contact phase (.34). Source contact is the
		# forward swing at 1.5 s; compress preparation and recovery separately.
		var contact: float = clip.length * contacts[stroke]
		var source_length := player.get_animation("rigify_clip").length
		if source_end > 0.0:
			source_length = source_end
		var source_t := source_start+(t/contact)*(source_contact-source_start) if t <= contact else source_contact+(t-contact)/(clip.length-contact)*(source_length-source_contact)
		if looping:
			source_t = minf(t, source_length)
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
					target = src.get_bone_global_pose(si).basis.get_rotation_quaternion() * rest_fix.get(si, Quaternion.IDENTITY)
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
				if not amplitudes.is_empty():
					var bone_name := dst.get_bone_name(i)
					var legs := "Leg" in bone_name or "Foot" in bone_name or "Toe" in bone_name or "UpLeg" in bone_name
					var free_arm := bone_name.contains("Left") and ("Arm" in bone_name or "Hand" in bone_name or "Shoulder" in bone_name)
					var keep: float = amplitudes[2] if legs else (amplitudes[1] if free_arm else amplitudes[0])
					var calm := q
					if dst.get_bone_count() == 24:
						calm = src.get_bone_rest(si).basis.get_rotation_quaternion()
					transferred = calm.slerp(transferred, keep).normalized()
				var recovery := smoothstep(clip.length-0.15,clip.length,t)
				if looping:
					# Close the loop on its own first pose, not on the old idle.
					if t == 0.0:
						_loop_start[i] = transferred
					recovery = smoothstep(clip.length-0.6,clip.length,t)
					q = transferred.slerp(_loop_start.get(i, transferred),recovery).normalized()
				else:
					q = transferred.slerp(q,recovery).normalized()
				clip.rotation_track_insert_key(tracks[i],t,q)
			globals[i] = parent_q*q
		if hip_track >= 0:
			var moved := (src.get_bone_global_pose(hip_src).origin - hip_origin) * hip_scale
			# The volley keeps the sim's spot entirely: only its knee-bend drop comes in.
			var side := 0.6 if stroke.begins_with("lunge") else 0.0
			if not stroke.begins_with("lunge"):
				moved.y = minf(moved.y, 0.0) # its step lifts the pelvis: a rise would float the feet
			var offset := Vector3(moved.x * side, moved.y, 0.0) * (1.0 - smoothstep(clip.length-0.15,clip.length,t))
			clip.position_track_insert_key(hip_track, t, dst.get_bone_rest(hip_dst).origin + offset)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/athletes/animations"))
	var err := ResourceSaver.save(clip,"res://assets/athletes/animations/%s_meshy_%s.tres" % [output_id,stroke])
	print("MESHY_BAKE athlete=",athlete," mapped=",mapping.size()," length=",clip.length," save=",err)
	source.free()
	rig.free()
	quit(0 if err == OK else 1)
