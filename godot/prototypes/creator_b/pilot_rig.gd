extends "res://src/character/athlete_rig.gd"
## Opt-in B prototype. Existing saved characters and the roster are unchanged.
const SOURCE_DIR := "res://../art/character-creator/proposte-qualita/B-produzione/meshy-pilot/"
const DONOR_PATH := "res://assets/custom_character/corpo_uomo_medio-rigged.glb"
var donor: Node3D
var donor_skeleton: Skeleton3D

func _init() -> void:
	_athlete_id = &"cc_uomo_medio"
	_motion_id = "cc_b_pilot"
	_glb_base_path = ProjectSettings.globalize_path(SOURCE_DIR + "body-rigged.glb")
	_glb_walk_path = ProjectSettings.globalize_path(SOURCE_DIR + "walk.glb")
	_glb_run_path = "res://assets/custom_character/corpo_uomo_medio-running.tres"
	_glb_idle_path = ""

func _build() -> int:
	donor = _load_glb(DONOR_PATH)
	if donor == null:
		return ERR_FILE_NOT_FOUND
	donor_skeleton = _find_first(donor, "Skeleton3D") as Skeleton3D
	if donor_skeleton == null:
		donor.free()
		return ERR_FILE_CORRUPT
	var result := super._build()
	if result == OK:
		attach_hair()
	donor.free()
	donor = null
	donor_skeleton = null
	return result

func _adopt_clip(lib: AnimationLibrary, path: String, clip_name: StringName) -> bool:
	if not path.ends_with(".tres"):
		return super._adopt_clip(lib, path, clip_name)
	var source := load(path) as Animation
	if source == null:
		return false
	var clip := retarget(source)
	clip.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation(clip_name, clip)
	return true

func _author_strokes(lib: AnimationLibrary) -> void:
	super._author_strokes(lib)
	for shot in ["drive", "smash", "bandeja", "backhand", "slice", "lunge_forehand", "wall_exit_forehand", "forehand_volley", "backhand_volley", "forehand_lob", "backhand_lob"]:
		var path := "res://assets/athletes/animations/cc_uomo_medio_meshy_%s.tres" % shot
		if not ResourceLoader.exists(path):
			continue
		var source := load(path) as Animation
		var clip := retarget(source)
		var key := StringName("meshy_" + shot)
		lib.add_animation(key, clip)
		_strokes[key] = clip.length

func retarget(source: Animation) -> Animation:
	var clip: Animation = source.duplicate(true)
	# Retarget global rest-space deltas, not local rotations: the two Meshy rigs
	# can share names while their bone axes differ substantially.
	var tracks := {}
	for track in range(clip.get_track_count() - 1, -1, -1):
		var raw := String(clip.track_get_path(track))
		var name := raw.substr(raw.find(":") + 1)
		var from := donor_skeleton.find_bone(name)
		var to := _skeleton.find_bone(name)
		if from < 0 or to < 0:
			clip.remove_track(track)
			continue
		clip.track_set_path(track, NodePath(_track_prefix + ":" + name))
		var src := donor_skeleton.get_bone_rest(from)
		var dst := _skeleton.get_bone_rest(to)
		var ratio := dst.origin.length() / maxf(src.origin.length(), 0.0001)
		for key in clip.track_get_key_count(track):
			match clip.track_get_type(track):
				Animation.TYPE_ROTATION_3D:
					pass
				Animation.TYPE_POSITION_3D:
					# Preserve limb lengths; only the pelvis imports translational motion.
					var value: Vector3 = clip.track_get_key_value(track, key)
					clip.track_set_key_value(track, key, dst.origin + (value - src.origin) * ratio if name == "Hips" else dst.origin)
				Animation.TYPE_SCALE_3D:
					clip.track_set_key_value(track, key, dst.basis.get_scale())
	for track in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			var name := String(clip.track_get_path(track)).get_slice(":", 1)
			tracks[_skeleton.find_bone(name)] = track
			while clip.track_get_key_count(track):
				clip.track_remove_key(track, 0)
	for frame in range(int(ceil(source.length * 60)) + 1):
		var t := minf(frame / 60.0, source.length)
		donor_skeleton.reset_bone_poses()
		for track in source.get_track_count():
			var name := String(source.track_get_path(track)).get_slice(":", 1)
			var index := donor_skeleton.find_bone(name)
			if index >= 0 and source.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				donor_skeleton.set_bone_pose_rotation(index, source.rotation_track_interpolate(track, t))
		# The donor is intentionally outside the scene tree: compute its hierarchy
		# explicitly instead of relying on Skeleton3D's frame-dependent pose cache.
		var source_globals := {}
		for bone in donor_skeleton.get_bone_count():
			var parent := donor_skeleton.get_bone_parent(bone)
			var pose := donor_skeleton.get_bone_pose(bone)
			source_globals[bone] = source_globals[parent] * pose if parent >= 0 else pose
		var globals := {}
		for index in _skeleton.get_bone_count():
			var from := donor_skeleton.find_bone(_skeleton.get_bone_name(index))
			var target_rest := _skeleton.get_bone_global_rest(index).basis.get_rotation_quaternion()
			var rotation := target_rest
			if from >= 0:
				rotation = source_globals[from].basis.get_rotation_quaternion() * donor_skeleton.get_bone_global_rest(from).basis.get_rotation_quaternion().inverse() * target_rest
			globals[index] = rotation
			if tracks.has(index):
				var parent := _skeleton.get_bone_parent(index)
				var local: Quaternion = globals[parent].inverse() * rotation if parent >= 0 else rotation
				clip.rotation_track_insert_key(tracks[index], t, local.normalized())
	return clip

func attach_hair() -> void:
	var head := _skeleton.find_bone("Head")
	var top := _skeleton.find_bone("head_end")
	if head < 0 or top < 0:
		return
	var hair := _load_glb(ProjectSettings.globalize_path(SOURCE_DIR + "hair.glb"))
	if hair == null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "PilotHair"
	attachment.bone_name = "Head"
	_skeleton.add_child(attachment)
	var rest := _skeleton.get_bone_global_rest(head)
	var tip := _skeleton.get_bone_global_rest(top).origin
	var length := rest.origin.distance_to(tip)
	# Generated hair is 1.90 units wide. Fit to a 1.15 head-length skull width.
	var size := length * 1.15 / 1.898894
	var centre := tip + Vector3(0, -length * 0.30, -length * 0.23)
	hair.transform = rest.affine_inverse() * Transform3D(Basis.from_scale(Vector3(1, 1.1, 1.6) * size), centre)
	attachment.add_child(hair)
	for mesh in hair.find_children("*", "MeshInstance3D", true, false):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("493126")
		material.roughness = 0.8
		mesh.material_override = material
