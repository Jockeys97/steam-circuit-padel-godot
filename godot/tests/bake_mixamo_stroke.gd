extends SceneTree
## bake_mixamo_stroke.gd — retarget a Mixamo FBX motion onto a game athlete (2026-09-26).
##
## Why: Meshy's text-to-motion could not produce a backhand (two tries, both came out
## as forehand paths: racket back on the right, left shoulder to the net, swing right
## to left). Mixamo's "Slash Advance" is a right-handed backhand slash: the hand goes
## across to the LEFT, the RIGHT shoulder turns to the net, then a fast left-to-right
## swing (measured, docs/agent-work/mixamo/). Only its body/arm motion is used; the
## racket is the game's own.
##
## Retarget, per mapped bone, in WORLD space (independent of each file's armature axes
## and units): the source's rotation away from its own rest (a T-pose) is applied to the
## destination AFTER aligning the destination's rest bone direction onto the source's,
## so a T-pose source does not tilt an A-pose rig's arms. Unmapped bones keep the
## athlete's idle. The pelvis takes only the source's vertical DROP (never a rise, never
## the travel: the simulation owns the position). Same stroke contract as
## `bake_meshy_fiamma.gd`: a source window [start, contact, end] is mapped onto the
## clip so contact lands on CONTACT_PHASE, and the last 0.15 s blend back to idle.
##
## Run: godot --headless --path godot --script res://tests/bake_mixamo_stroke.gd -- <stroke> <athlete> [outfit]

const Spawn = preload("res://src/character/athlete_spawn.gd")

## stroke -> [source fbx, clip length s, contact phase, source start, source contact,
##            source end, upper-body amplitude, free-arm amplitude, leg amplitude]
const STROKES := {
	# Only the torso turn and the racket arm are a backhand; the slash's guard (free arm
	# up by the face) and fighting stance read as martial arts, so they stay near idle.
	"backhand": ["res://../docs/agent-work/mixamo/slash_advance.fbx", 0.62, 0.34, 0.2, 0.70, 1.1, 1.0, 0.0, 0.0],
	"backhand_volley": ["res://../docs/agent-work/mixamo/slash_advance.fbx", 0.50, 0.42, 0.45, 0.70, 0.95, 0.6, 0.0, 0.0],
	"backhand_lob": ["res://../docs/agent-work/mixamo/slash_advance.fbx", 0.60, 0.36, 0.3, 0.70, 1.0, 0.8, 0.0, 0.0],
}

## Meshy-style (24-joint) bone name -> Mixamo name, where they differ. The Meshy family
## numbers its spine top-down (`Spine02` is the lowest), Mixamo bottom-up.
const MESHY_TO_MIXAMO := {"Spine02": "Spine", "Spine01": "Spine1", "Spine": "Spine2", "neck": "Neck"}


func find_type(node: Node, type: String):
	if node.is_class(type): return node
	for c in node.get_children():
		var r = find_type(c, type)
		if r != null: return r
	return null


func _initialize() -> void:
	call_deferred("run")


func _mixamo_name(dst_name: String) -> String:
	var base := dst_name.replace("mixamorig_", "").replace("mixamorig:", "")
	if not dst_name.begins_with("mixamorig"):
		base = MESHY_TO_MIXAMO.get(base, base)
	return "mixamorig_" + base


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var stroke := args[0] if args.size() > 0 else "backhand"
	var athlete := StringName(args[1]) if args.size() > 1 else &"fiamma"
	var outfit := StringName(args[2]) if args.size() > 2 else &"base"
	if not STROKES.has(stroke):
		printerr("unknown stroke ", stroke); quit(1); return
	var spec: Array = STROKES[stroke]
	var output_id := String(athlete) if outfit == &"base" else "%s_%s" % [athlete, outfit]

	var doc := FBXDocument.new()
	var state := FBXState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(spec[0]), state) != OK:
		printerr("cannot read ", spec[0]); quit(1); return
	var source: Node = doc.generate_scene(state)
	root.add_child(source)
	var src: Skeleton3D = find_type(source, "Skeleton3D")
	var player: AnimationPlayer = find_type(source, "AnimationPlayer")
	var take := "mixamo_com" if player.has_animation("mixamo_com") else String(player.get_animation_list()[0])
	player.play(take)

	# Custom "Crea atleta" bodies are not in the frozen catalogue: build their rig directly.
	var rig = Spawn.make(athlete, outfit) if not String(athlete).begins_with("cc_") else _raw_rig(athlete)
	if rig == null:
		printerr("no rig ", athlete); quit(1); return
	root.add_child(rig)
	var dst: Skeleton3D = rig.get_skeleton()
	var neutral: Animation = rig._anim.get_animation("idle")
	var clip: Animation = neutral.duplicate(true)
	var length: float = spec[1]
	clip.length = length
	clip.loop_mode = Animation.LOOP_NONE
	for track in clip.get_track_count():
		var value: Variant = clip.track_get_key_value(track, 0)
		while clip.track_get_key_count(track): clip.track_remove_key(track, 0)
		clip.track_insert_key(track, 0, value)
		clip.track_insert_key(track, length, value)

	var src_rot := src.global_transform.basis.get_rotation_quaternion()
	var dst_rot := dst.global_transform.basis.get_rotation_quaternion()
	var mapping := {}
	var tracks := {}
	var align := {}
	for i in dst.get_bone_count():
		var si := src.find_bone(_mixamo_name(dst.get_bone_name(i)))
		if si < 0:
			continue
		# An amplitude of 0 means "the athlete's own": the bone is not transferred at all
		# (reducing towards the source's window-start pose kept the slash's guard/stance).
		var sbn := src.get_bone_name(si)
		# The pelvis goes with the legs: its rest twist differs between the two skeleton
		# families, and turning it tipped the 24-joint rigs' legs (a knee lifted). The
		# spine chain alone carries the shoulder turn.
		var is_leg := "Leg" in sbn or "Foot" in sbn or "Toe" in sbn or sbn.ends_with("Hips")
		var is_free := sbn.contains("Left") and ("Arm" in sbn or "Hand" in sbn or "Shoulder" in sbn)
		if (is_leg and float(spec[8]) <= 0.0) or (is_free and float(spec[7]) <= 0.0):
			continue
		var path := NodePath("%s:%s" % [rig._track_prefix, dst.get_bone_name(i)])
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			continue
		mapping[i] = si
		tracks[i] = track
		while clip.track_get_key_count(track): clip.track_remove_key(track, 0)
		# Rest alignment: the rotation taking this destination bone's rest direction
		# (towards its first mapped child) onto the source's, in world space.
		align[i] = Quaternion.IDENTITY
		for c in dst.get_bone_children(i):
			var sc := src.find_bone(_mixamo_name(dst.get_bone_name(c)))
			if sc < 0:
				continue
			var d_dir := (dst.global_transform.basis * (dst.get_bone_global_rest(c).origin - dst.get_bone_global_rest(i).origin)).normalized()
			var s_dir := (src.global_transform.basis * (src.get_bone_global_rest(sc).origin - src.get_bone_global_rest(si).origin)).normalized()
			if d_dir.is_finite() and s_dir.is_finite() and d_dir.dot(s_dir) < 0.9999:
				align[i] = Quaternion(d_dir.cross(s_dir).normalized(), acos(clampf(d_dir.dot(s_dir), -1.0, 1.0)))
			break

	# Pelvis: vertical drop only.
	var hip_dst := dst.find_bone(rig._resolve_bone_name("Hips"))
	var hip_src := src.find_bone("mixamorig_Hips")
	var hip_track := -1
	var hip_scale := 0.0
	var hip_y0 := 0.0
	# Only when the legs are transferred: with the athlete's own legs, a lowered pelvis
	# would push the feet into the court (and the stroke test forbids root motion).
	if hip_dst >= 0 and hip_src >= 0 and float(spec[8]) > 0.0:
		var hip_path := NodePath("%s:%s" % [rig._track_prefix, dst.get_bone_name(hip_dst)])
		hip_track = clip.find_track(hip_path, Animation.TYPE_POSITION_3D)
		if hip_track < 0:
			hip_track = clip.add_track(Animation.TYPE_POSITION_3D)
			clip.track_set_path(hip_track, hip_path)
		while clip.track_get_key_count(hip_track): clip.track_remove_key(hip_track, 0)
		hip_scale = dst.get_bone_global_rest(hip_dst).origin.y / src.get_bone_global_rest(hip_src).origin.y
		player.seek(float(spec[3]), true, true)
		src.force_update_all_bone_transforms()
		hip_y0 = src.get_bone_global_pose(hip_src).origin.y

	# Amplitude, in source space, towards the source's own pose at the window start.
	var amp_upper: float = spec[6]
	var amp_free: float = spec[7]
	var amp_legs: float = spec[8]
	var calm := {}
	player.seek(float(spec[3]), true, true)
	src.force_update_all_bone_transforms()
	for si in src.get_bone_count():
		calm[si] = src.get_bone_global_pose(si).basis.get_rotation_quaternion()

	var contact: float = length * float(spec[2])
	var s_start: float = spec[3]
	var s_contact: float = spec[4]
	var s_end: float = spec[5]
	for frame in range(int(round(length * 100)) + 1):
		var t := frame / 100.0
		var source_t := s_start + (t / contact) * (s_contact - s_start) if t <= contact else s_contact + (t - contact) / (length - contact) * (s_end - s_contact)
		player.seek(source_t, true, true)
		src.force_update_all_bone_transforms()
		var globals := {}
		for i in dst.get_bone_count():
			var parent := dst.get_bone_parent(i)
			var parent_q: Quaternion = globals.get(parent, dst.get_bone_global_rest(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY)
			var path := NodePath("%s:%s" % [rig._track_prefix, dst.get_bone_name(i)])
			var nt := neutral.find_track(path, Animation.TYPE_ROTATION_3D)
			var q: Quaternion = neutral.rotation_track_interpolate(nt, 0.0) if nt >= 0 else dst.get_bone_rest(i).basis.get_rotation_quaternion()
			if mapping.has(i):
				var si: int = mapping[i]
				var bn := src.get_bone_name(si)
				var keep := amp_upper
				if "Leg" in bn or "Foot" in bn or "Toe" in bn: keep = amp_legs
				elif bn.contains("Left") and ("Arm" in bn or "Hand" in bn or "Shoulder" in bn): keep = amp_free
				var s_now := src.get_bone_global_pose(si).basis.get_rotation_quaternion()
				s_now = (calm[si] as Quaternion).slerp(s_now, keep).normalized()
				# World-space delta from the source rest, onto the aligned destination rest.
				var s_rest_w := src_rot * src.get_bone_global_rest(si).basis.get_rotation_quaternion()
				var s_now_w := src_rot * s_now
				var delta_w := s_now_w * s_rest_w.inverse()
				var d_rest_w := dst_rot * dst.get_bone_global_rest(i).basis.get_rotation_quaternion()
				var d_now_w: Quaternion = delta_w * (align[i] as Quaternion) * d_rest_w
				var d_now_skel := dst_rot.inverse() * d_now_w
				var transferred := (parent_q.inverse() * d_now_skel).normalized()
				var recovery := smoothstep(length - 0.15, length, t)
				q = transferred.slerp(q, recovery).normalized()
				clip.rotation_track_insert_key(tracks[i], t, q)
			globals[i] = parent_q * q
		if hip_track >= 0:
			var drop := minf(0.0, src.get_bone_global_pose(hip_src).origin.y - hip_y0) * hip_scale
			drop *= 1.0 - smoothstep(length - 0.15, length, t)
			clip.position_track_insert_key(hip_track, t, dst.get_bone_rest(hip_dst).origin + Vector3(0, drop, 0))
	var out := "res://assets/athletes/animations/%s_meshy_%s.tres" % [output_id, stroke]
	var err := ResourceSaver.save(clip, out)
	print("MIXAMO_BAKE athlete=", output_id, " stroke=", stroke, " mapped=", mapping.size(), " save=", err)
	source.free()
	rig.free()
	quit(0 if err == OK else 1)


func _raw_rig(athlete: StringName) -> Node3D:
	var rig = preload("res://src/character/AthleteRig.tscn").instantiate()
	if not rig.set_athlete_asset(athlete) or rig.get_load_error() != OK:
		rig.free()
		return null
	return rig
