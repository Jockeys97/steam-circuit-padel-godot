extends Node3D
## AthleteRig — the 3D athlete for Steam Circuit Padel Pro.
##
## ===========================================================================
## PUBLIC API  (this header is the contract; you should not need to read below)
## ===========================================================================
## Drop `res://src/character/AthleteRig.tscn` into a scene and call:
##
##   OUTFIT
##     set_outfit(id: StringName) -> bool        # false if `id` is unknown
##     get_outfit() -> StringName
##     get_outfit_ids() -> Array[StringName]     # &"base", &"glacier", &"vermilion", ...
##
##   FACING
##     set_facing_degrees(yaw: float) -> void    # 0 = +Z, CCW about +Y, degrees
##     get_facing_degrees() -> float
##     face_towards(target: Vector3) -> void     # yaw only; pitch/roll untouched
##
##   LOCOMOTION
##     play_locomotion(state: StringName) -> bool   # &"idle" | &"walk" | &"run"
##     get_locomotion_states() -> Array[StringName]
##     get_locomotion_state() -> StringName
##     set_locomotion_speed_scale(s: float) -> void
##
##   PADEL STROKES  (one-shot; locomotion resumes automatically)
##     play_stroke(stroke: StringName) -> bool      # &"drive" | &"slice" | &"lob" | &"serve"
##     play_stroke_at(stroke, contact_phase, speed_scale) -> bool
##                                                    # start at the sim contact frame
##     get_stroke_names() -> Array[StringName]
##     is_stroking() -> bool
##     signal stroke_finished(stroke: StringName)
##
##   CATALOGUE OUTFITS  (the reference's own six athletes x 26 outfits)
##     get_base_material() -> StandardMaterial3D   # the GLB's own material, for recolour
##     note_catalogue_outfit(athlete_id, outfit_id) -> void
##     get_catalogue_outfit() -> Dictionary        # {athlete_id, outfit_id} or {}
##     get_catalogue_surface() -> ShaderMaterial   # the catalogue's masked override, or null
##     set_catalogue_surface(mat) -> void          # install it on surface 0
##     restore_base_surface() -> bool              # hand surface 0 back to the GLB look
##     is_base_surface() -> bool                   # is surface 0 the rig's own base look?
##     Do not mix with set_outfit(): both own surface override 0. See
##     `src/character/outfit_catalogue.gd`, which drives this path.
##
##   POSE READOUT
##     get_pose() -> Dictionary                  # {clip, time, length, facing_degrees, bones[*]}
##     get_skeleton() -> Skeleton3D              # escape hatch; prefer get_pose()
##     make_standard_bone_attachment(bone, name) # null on a legacy/non-Mixamo rig
##     get_world_extent() -> AABB                # posed bounds in world units
##
##   RENDER / TEST HOOKS (deterministic, no frame loop required)
##     play_clip(name: StringName) -> bool       # any registered clip, no state machine
##     sample_at(t: float) -> void               # force the pose at time t, immediately
##     get_clip_length(name: StringName) -> float
##     get_load_error() -> int                   # OK (0) when the rig loaded
##     get_triangle_count() -> int
##     get_surface_count() -> int
##     get_material_state() -> Dictionary        # what the surface override currently carries
##
## ===========================================================================
## HOW IT IS BUILT, AND THE TWO CHOICES THAT ARE THE OWNER'S TO MAKE
## ===========================================================================
## The GLBs are loaded at RUNTIME through GLTFDocument, not through Godot's
## import pipeline, so this scene needs no `.import` cache and no `project.godot`
## change. The original Volpe fallback is a 24-joint rig. The first real athlete,
## Colosso, uses a self-contained Meshy Mixamo export with 28 joints and all three
## locomotion clips in one file; aliases below keep the public API stable while
## preserving the exported skeleton.
##
## OWNER DECISION 1 — PBR defaults. The GLB's single material imports with
## `metallic = 1.0, roughness = 1.0` (measured, rig_probe). Those are the glTF
## defaults for a file that never authored `pbrMetallicRoughness`, and at
## metallic = 1 a surface has no diffuse term at all, so albedo (i.e. the outfit
## colour) barely reaches the frame. This rig therefore defaults to
## `metallic = 0.0, roughness = 0.85`, which is the technically-correct
## description of cloth and fur. It is fully reversible: call
## `use_glb_pbr(true)` to render exactly what the GLB asks for. Which of the two
## ships is an art-direction call, not this script's.
##
## OWNER DECISION 2 — outfit colours. The registered outfits are the offline
## recolour outputs that already exist on disk; `glacier`/`vermilion` come from
## `tools/character/outfits-strong.json`. They are diagnostic targets chosen to
## make the recolour path measurable, NOT a proposed palette.

signal stroke_finished(stroke: StringName)

## The original Volpe files remain the safe default and are part of the public
## compatibility contract. New athlete assets opt in before the rig is built.
const GLB_BASE := "res://assets/athletes/volpe-rigged.glb"
const GLB_WALK := "res://assets/athletes/volpe-walking.glb"
const GLB_RUN := "res://assets/athletes/volpe-running.glb"

## One self-contained GLB per athlete. Keep this table deliberately small while
## the new models are introduced one at a time; every unknown id falls back to
## the proven Volpe rig below.
##
## File names are roster ids by rule, and the authority on which asset belongs to
## which athlete is docs/art/roster-3d.json (frozen in docs/art/character-standard.md).
## `python3 tools/character/validate_standard.py` checks the GLBs against it without
## needing Godot.
##
## `fornaio` IS A GODOT-ONLY SPECIAL ATHLETE AND HAS NO GLB. Character-standard
## forbids a GLB whose name is not a roster id, so nothing new was copied into
## `godot/assets/athletes/`: the id is mapped onto MAESTRO'S EXISTING MESH as a
## TEMPORARY HUMAN STAND-IN until the owner drops a Meshy export. The on-court
## body is therefore the maestro mesh, not the baker — recorded in
## `docs/wayfinder/evidence/fornaio-special.md` and in the overlay's
## `stand_in_note` (`assets/athletes/specials_catalogue.json`). The Volpe fox is
## never what a player gets: an unknown id still falls back to it, so a special
## MUST have an entry here the day it is offered.
const ATHLETE_GLB := {
	&"colosso": "res://assets/athletes/colosso.glb",
	&"maestro": "res://assets/athletes/maestro.glb",
	&"fiamma": "res://assets/athletes/fiamma.glb",
	&"oracolo": "res://assets/athletes/oracolo.glb",
	&"fornaio": "res://assets/athletes/maestro-rigged.glb",
}

const CLIP_IDLE := &"idle"
const CLIP_WALK := &"walk"
const CLIP_RUN := &"run"
const LOCOMOTION := [CLIP_IDLE, CLIP_WALK, CLIP_RUN, &"shuffle_left", &"shuffle_right", &"backpedal", &"prepare", &"ready", &"brake"]

## Athletes whose rigged base does not carry every locomotion clip: athlete id ->
## { clip name -> res:// path of a single-clip companion GLB }. Maestro's rigged
## export is a bind/rest file — its idle / walking / running live in three
## companion GLBs that each duplicate the mesh and skin; `_adopt_clip` lifts the
## clip against this one body and frees the rest. The Volpe fallback keeps its own
## GLB_WALK / GLB_RUN constants above and needs no entry here.
const COMPANION_CLIPS := {
	&"maestro": {
		CLIP_IDLE: "res://assets/athletes/maestro-idle.glb",
		CLIP_WALK: "res://assets/athletes/maestro-walking.glb",
		CLIP_RUN: "res://assets/athletes/maestro-running.glb",
	},
	## The stand-in special rides the maestro mesh, so it adopts the same three
	## single-clip companions (see `ATHLETE_GLB`'s note above).
	&"fornaio": {
		CLIP_IDLE: "res://assets/athletes/maestro-idle.glb",
		CLIP_WALK: "res://assets/athletes/maestro-walking.glb",
		CLIP_RUN: "res://assets/athletes/maestro-running.glb",
	},
}

## id -> res:// path of a 2048x2048 recoloured atlas, or "" for the GLB's own texture.
## Paths are copies of the offline recolour outputs; see the header, owner decision 2.
const OUTFITS := {
	&"base": "",
	&"glacier": "res://assets/athletes/outfits/strong-outfit-a.png",
	&"vermilion": "res://assets/athletes/outfits/strong-outfit-b.png",
	&"midnight_violet": "res://assets/athletes/outfits/weak-outfit-a.png",
	&"ember": "res://assets/athletes/outfits/weak-outfit-b.png",
}

## Reversible non-glTF PBR defaults. See owner decision 1 in the header.
const DEFAULT_METALLIC := 0.0
const DEFAULT_ROUGHNESS := 0.85

var _load_error: int = ERR_UNCONFIGURED
var _skeleton: Skeleton3D = null
var _mesh_instance: MeshInstance3D = null
var _anim: AnimationPlayer = null
var _model_root: Node3D = null

var _facing_degrees: float = 0.0
var _outfit: StringName = &"base"
var _locomotion: StringName = CLIP_IDLE
var _stroke: StringName = &""
var _locomotion_speed_scale: float = 1.0
var _stroke_speed_scale: float = 1.0
var _use_glb_pbr: bool = false
var _building: bool = false
var _athlete_id: StringName = &""
const OutfitGeometry := preload("res://src/character/outfit_geometry.gd")
var _geometry_outfit: StringName = &"base"
var _motion_id: String = ""
var _glb_base_path: String = GLB_BASE
var _glb_walk_path: String = GLB_WALK
var _glb_run_path: String = GLB_RUN
var _glb_idle_path: String = ""
var _track_prefix: String = "Armature/Skeleton3D"

var _base_material: StandardMaterial3D = null
var _override: StandardMaterial3D = null
## The catalogue's own surface override for the masked (per-athlete profile) path.
## Held here, not rebuilt per selection, so switching outfits reuses one material
## per rig instead of allocating one each time.
var _catalogue_surface: ShaderMaterial = null
var _outfit_cache: Dictionary = {}          # id -> {texture: Texture2D, digest: String}
var _strokes: Dictionary = {}               # StringName -> length (float)
var _catalogue_outfit: Dictionary = {}      # {athlete_id, outfit_id}, set by the catalogue


func _ready() -> void:
	_ensure_built()


## Selects an athlete-specific, self-contained GLB before first use. This is
## intentionally a pre-build operation: changing the mesh of a live rig would
## invalidate its Skeleton3D, racket anchor and animation library. Returning false
## after construction prevents an accidental mid-match model swap.
func set_athlete_asset(athlete_id: StringName, outfit_id: StringName = &"base") -> bool:
	if _load_error != ERR_UNCONFIGURED or _building:
		return false
	_athlete_id = athlete_id
	_geometry_outfit = &"base"
	_motion_id = String(athlete_id)
	var variant := OutfitGeometry.variant(athlete_id, outfit_id)
	if not variant.is_empty():
		_geometry_outfit = outfit_id
		_glb_base_path = variant.base
		_glb_walk_path = variant.walk
		_glb_run_path = ""
		_glb_idle_path = ""
		_motion_id = variant.motion_id
		return true
	_glb_base_path = String(ATHLETE_GLB.get(athlete_id, GLB_BASE))
	var companions: Dictionary = COMPANION_CLIPS.get(athlete_id, {})
	_glb_idle_path = String(companions.get(CLIP_IDLE, ""))
	if _glb_base_path == GLB_BASE:
		# The fallback rig still uses its original walk/run companion files.
		_glb_walk_path = GLB_WALK
		_glb_run_path = GLB_RUN
	else:
		# A Meshy base may carry its clips itself (Colosso: empty paths) or point at
		# single-clip companion files (Maestro, via COMPANION_CLIPS).
		_glb_walk_path = String(companions.get(CLIP_WALK, ""))
		_glb_run_path = String(companions.get(CLIP_RUN, ""))
	return true


func get_athlete_asset() -> StringName:
	return _athlete_id

func get_geometry_outfit() -> StringName:
	return _geometry_outfit


## The res:// path of the mesh this rig actually loads. For a special athlete with
## no Meshy export of its own this is the STAND-IN mesh (`ATHLETE_GLB`), which is
## why it is readable rather than private: an evidence file and a test both have to
## be able to say which body a special got.
func get_athlete_glb_path() -> String:
	return _glb_base_path


## The legacy catalogue shader is authored for the Volpe atlas. A Meshy athlete
## keeps its own baked PBR material until a matching recolour mask is authored;
## applying the Volpe mask to a different texture would visibly corrupt it.
func uses_catalogue_recolour() -> bool:
	return _glb_base_path == GLB_BASE


## The rig builds itself on first use, not on the first frame. `_ready()` is not a
## reliable construction point for every host (a `SceneTree` script that adds the
## rig inside `_initialize()` never sees it fire), and every public entry point
## below funnels through here, so the scene is usable the instant it is
## instantiated -- no frame loop, no `await`.
func _ensure_built() -> void:
	if _load_error != ERR_UNCONFIGURED or _building:
		return
	_building = true
	_load_error = _build()
	_building = false
	if _load_error == OK:
		set_outfit(&"base")
		play_locomotion(CLIP_IDLE)


# =========================================================================
# Construction
# =========================================================================

func _build() -> int:
	var base_root := _load_glb(_glb_base_path)
	if base_root == null:
		push_error("AthleteRig: could not load %s" % _glb_base_path)
		return ERR_CANT_OPEN
	_model_root = base_root
	add_child(_model_root)

	_skeleton = _find_first(_model_root, "Skeleton3D") as Skeleton3D
	_mesh_instance = _find_first(_model_root, "MeshInstance3D") as MeshInstance3D
	_anim = _find_first(_model_root, "AnimationPlayer") as AnimationPlayer
	if _skeleton == null or _mesh_instance == null or _anim == null:
		push_error("AthleteRig: GLB is missing Skeleton3D / MeshInstance3D / AnimationPlayer")
		return ERR_FILE_CORRUPT

	# Deterministic sampling: nothing advances unless we ask it to.
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_anim.animation_finished.connect(_on_animation_finished)
	_track_prefix = _discover_track_prefix()

	# A skinned pose can push geometry outside the cached AABB and get the whole
	# instance frustum-culled (observed: two render frames came out empty). A generous
	# cull margin costs nothing here and makes captures unconditional.
	_mesh_instance.extra_cull_margin = 4.0

	var mesh := _mesh_instance.mesh
	if mesh != null and mesh.get_surface_count() > 0:
		var m := mesh.surface_get_material(0)
		if m is StandardMaterial3D:
			_base_material = m as StandardMaterial3D

	var lib := _anim.get_animation_library(&"")
	if lib == null:
		lib = AnimationLibrary.new()
		_anim.add_animation_library(&"", lib)

	# A Meshy "All Animations" export is self-contained. Lift its named clips
	# (restpose/Walking/Running) into the stable API names. The Volpe fallback has
	# one base clip and keeps adopting walk/run from its companion GLBs.
	var embedded := _animation_names()
	if _geometry_outfit != &"base":
		# This export contains running, not a resting pose. Build a planted idle
		# from this skeleton's own rest transforms, then relax arms from its walk.
		var idle := Animation.new()
		idle.length = 3.2
		idle.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(CLIP_IDLE, idle)
		_complete_idle_tracks(lib)
		for source_name in _anim.get_animation_list():
			if "running" in String(source_name).to_lower():
				_alias_clip(lib, source_name, CLIP_RUN)
				break
	if embedded.has("restpose"):
		_alias_clip(lib, embedded["restpose"], CLIP_IDLE)
	if embedded.has("walking"):
		_alias_clip(lib, embedded["walking"], CLIP_WALK)
	if embedded.has("running"):
		_alias_clip(lib, embedded["running"], CLIP_RUN)
	# Maestro's base export carries only a 0.30 s single-key bind hold, not an idle.
	# Adopt its real idle from the companion file BEFORE the first-embedded-clip
	# fallback below, so the bind hold can never be aliased into the idle slot.
	if not lib.has_animation(CLIP_IDLE) and _glb_idle_path != "":
		_adopt_clip(lib, _glb_idle_path, CLIP_IDLE)
	if not lib.has_animation(CLIP_IDLE):
		var base_clip := ""
		for a in _anim.get_animation_list():
			base_clip = a
			break
		if base_clip != "":
			_alias_clip(lib, base_clip, CLIP_IDLE)
	if not lib.has_animation(CLIP_WALK) and _glb_walk_path != "":
		_adopt_clip(lib, _glb_walk_path, CLIP_WALK)
	if not lib.has_animation(CLIP_RUN) and _glb_run_path != "":
		_adopt_clip(lib, _glb_run_path, CLIP_RUN)

	if _athlete_id == &"fiamma" or _geometry_outfit != &"base":
		_author_ready_idle(lib)
	_complete_idle_tracks(lib)
	_author_footwork(lib)
	_author_strokes(lib)
	if _athlete_id in [&"fiamma", &"colosso", &"oracolo", &"maestro", &"fornaio", &"pantera", &"steamer"]:
		for shot in ["drive", "smash", "bandeja", "backhand", "slice"]:
			var motion_path := "res://assets/athletes/animations/%s_meshy_%s.tres" % [_motion_id,shot]
			if ResourceLoader.exists(motion_path):
				var motion := load(motion_path) as Animation
				if motion != null:
					var clip_name := StringName("meshy_" + shot)
					lib.add_animation(clip_name, motion)
					_strokes[clip_name] = motion.length
	return OK


## Imported holds omit constant tracks. Fill those so any stroke can recover
## to idle without leaving the last shoulder/leg rotation behind.
func _complete_idle_tracks(lib: AnimationLibrary) -> void:
	var idle: Animation = lib.get_animation(CLIP_IDLE).duplicate(true)
	for index in _skeleton.get_bone_count():
		var path := NodePath("%s:%s" % [_track_prefix, _skeleton.get_bone_name(index)])
		var rest := _skeleton.get_bone_rest(index)
		for type in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
			if idle.find_track(path, type) >= 0:
				continue
			var track := idle.add_track(type)
			idle.track_set_path(track, path)
			for time in [0.0, idle.length]:
				if type == Animation.TYPE_ROTATION_3D:
					idle.rotation_track_insert_key(track, time, rest.basis.get_rotation_quaternion())
				elif type == Animation.TYPE_POSITION_3D:
					idle.position_track_insert_key(track, time, rest.origin)
				else:
					idle.scale_track_insert_key(track, time, rest.basis.get_scale())
	lib.remove_animation(CLIP_IDLE)
	lib.add_animation(CLIP_IDLE, idle)


## In-place footwork. Feet/hips remain animation-only; no root-motion authority.
func _author_footwork(lib: AnimationLibrary) -> void:
	var idle := lib.get_animation(CLIP_IDLE)
	for name in [&"shuffle_left", &"shuffle_right", &"backpedal", &"prepare", &"ready", &"brake"]:
		var anim: Animation = idle.duplicate(true)
		anim.length = 0.64 if name != &"prepare" else 1.2
		if name == &"ready": anim.length = 2.8
		if name == &"brake": anim.length = 0.38
		anim.loop_mode = Animation.LOOP_LINEAR
		if name == &"brake": anim.loop_mode = Animation.LOOP_NONE
		# Freeze the underlying idle, including any imported hip translation.
		for track in anim.get_track_count():
			var value: Variant = anim.track_get_key_value(track, 0)
			while anim.track_get_key_count(track) > 0:
				anim.track_remove_key(track, 0)
			anim.track_insert_key(track, 0.0, value)
			anim.track_insert_key(track, anim.length, value)
		for bone in ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "Spine", "LeftArm", "RightArm", "RightForeArm"]:
			var path := NodePath("%s:%s" % [_track_prefix, _resolve_bone_name(bone)])
			var track := anim.find_track(path, Animation.TYPE_ROTATION_3D)
			if track < 0:
				continue
			var neutral: Quaternion = idle.rotation_track_interpolate(track, 0.0)
			while anim.track_get_key_count(track) > 0:
				anim.track_remove_key(track, 0)
			for step in range(9):
				var phase := float(step) / 8.0
				var wave := sin(phase * TAU) * (-1.0 if bone.begins_with("Right") else 1.0)
				var offset := Vector3.ZERO
				if name == &"brake":
					var settle := sin(phase * PI)
					if bone.ends_with("UpLeg"): offset.x = deg_to_rad(-8.0 * settle)
					elif bone.ends_with("Leg"): offset.x = deg_to_rad(14.0 * settle)
					elif bone == "Spine": offset.x = deg_to_rad(5.0 * settle)
					elif bone.ends_with("Arm"): offset.x = deg_to_rad(-4.0 * settle)
				elif name == &"ready":
					if bone == "Spine": offset = Vector3(deg_to_rad(sin(phase * TAU) * 1.2), 0, deg_to_rad(wave * 1.5))
					elif bone.ends_with("UpLeg"): offset.x = deg_to_rad(-3.0 + wave)
					elif bone.ends_with("Leg"): offset.x = deg_to_rad(5.0 - wave)
					elif bone == "RightForeArm": offset.z = deg_to_rad(-8.0 + wave)
				elif name == &"prepare":
					if bone == "RightArm": offset.x = deg_to_rad(-12.0)
					if bone == "RightForeArm": offset.z = deg_to_rad(-16.0)
					if bone == "Spine": offset.x = deg_to_rad(-3.0 + sin(phase * TAU))
					if bone.ends_with("UpLeg"): offset.x = deg_to_rad(-6.0)
					elif bone.ends_with("Leg"): offset.x = deg_to_rad(10.0)
				elif bone.ends_with("UpLeg"):
					if name == &"backpedal": offset.x = deg_to_rad(-wave * 18.0)
					else: offset.z = deg_to_rad(wave * (10.0 if name == &"shuffle_left" else -10.0))
				elif bone.ends_with("Leg"):
					offset.x = deg_to_rad(maxf(0.0, wave) * 16.0)
				elif bone == "Spine":
					offset.z = deg_to_rad(wave * 2.0)
					offset.x = deg_to_rad(-3.0)
				elif bone == "RightForeArm":
					offset.z = deg_to_rad(-12.0)
				elif bone.ends_with("Arm"):
					offset.x = deg_to_rad(wave * 4.0)
				anim.rotation_track_insert_key(track, phase * anim.length, (neutral * Quaternion.from_euler(offset)).normalized())
		lib.add_animation(name, anim)


## The exported restpose is a T-pose, not an idle. Keep its planted lower body
## and use the athlete's own walking arm rotations for a relaxed ready stance.
## Breathing is cyclic; no translation/root motion is introduced.
func _author_ready_idle(lib: AnimationLibrary) -> void:
	if not lib.has_animation(CLIP_IDLE) or not lib.has_animation(CLIP_WALK):
		return
	var idle: Animation = lib.get_animation(CLIP_IDLE).duplicate(true)
	var walk := lib.get_animation(CLIP_WALK)
	idle.length = 3.2
	idle.loop_mode = Animation.LOOP_LINEAR
	# GLTF import drops constant rest tracks. Explicitly key every bone so idle
	# also clears rotations/positions left by the preceding run or stroke.
	for index in _skeleton.get_bone_count():
		var bone_path := NodePath("%s:%s" % [_track_prefix, _skeleton.get_bone_name(index)])
		var rest := _skeleton.get_bone_rest(index)
		for type in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
			if idle.find_track(bone_path, type) >= 0:
				continue
			var track := idle.add_track(type)
			idle.track_set_path(track, bone_path)
			for time in [0.0, idle.length]:
				if type == Animation.TYPE_ROTATION_3D:
					idle.rotation_track_insert_key(track, time, rest.basis.get_rotation_quaternion())
				elif type == Animation.TYPE_POSITION_3D:
					idle.position_track_insert_key(track, time, rest.origin)
				else:
					idle.scale_track_insert_key(track, time, rest.basis.get_scale())
	for bone in ["LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "Spine", "Spine1"]:
		var path := NodePath("%s:%s" % [_track_prefix, _resolve_bone_name(bone)])
		var ti := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		if ti < 0:
			continue
		var neutral: Quaternion = idle.rotation_track_interpolate(ti, 0.0)
		var wi := walk.find_track(path, Animation.TYPE_ROTATION_3D)
		if "Arm" in bone and wi >= 0:
			neutral = walk.rotation_track_interpolate(wi, 0.0).slerp(
				walk.rotation_track_interpolate(wi, walk.length * 0.5), 0.5)
		while idle.track_get_key_count(ti) > 0:
			idle.track_remove_key(ti, 0)
		for step in range(9):
			var phase := float(step) / 8.0
			var breath := sin(phase * TAU) * deg_to_rad(0.8 if bone.begins_with("Spine") else 0.5)
			idle.rotation_track_insert_key(ti, phase * idle.length,
				(neutral * Quaternion(Vector3.RIGHT, breath)).normalized())
	lib.remove_animation(CLIP_IDLE)
	lib.add_animation(CLIP_IDLE, idle)


## Loads `path`, lifts its single animation into `lib` under `clip_name`, frees the
## rest. Only one extra GLB is resident at a time (host has 0 swap).
func _adopt_clip(lib: AnimationLibrary, path: String, clip_name: StringName) -> bool:
	var root := _load_glb(path)
	if root == null:
		push_warning("AthleteRig: could not load %s; clip '%s' not registered" % [path, clip_name])
		return false
	var ap := _find_first(root, "AnimationPlayer") as AnimationPlayer
	var ok := false
	if ap != null:
		for a in ap.get_animation_list():
			var anim: Animation = ap.get_animation(a).duplicate(true)
			anim.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(clip_name, anim)
			ok = true
			break
	root.free()
	if not ok:
		push_warning("AthleteRig: %s carries no animation; clip '%s' not registered" % [path, clip_name])
	return ok


func _alias_clip(lib: AnimationLibrary, source_name: String, clip_name: StringName) -> bool:
	if _anim == null or not _anim.has_animation(source_name):
		return false
	var clip: Animation = _anim.get_animation(source_name).duplicate(true)
	clip.loop_mode = Animation.LOOP_LINEAR if clip_name in LOCOMOTION else Animation.LOOP_NONE
	if lib.has_animation(clip_name):
		lib.remove_animation(clip_name)
	lib.add_animation(clip_name, clip)
	return true


func _animation_names() -> Dictionary:
	var names := {}
	if _anim == null:
		return names
	for source_name in _anim.get_animation_list():
		names[String(source_name).to_lower()] = source_name
	return names


## Returns the path prefix used by the imported GLB tracks. Meshy exports use a
## Mixamo bone name containing a colon (for example
## `Skeleton3D:mixamorig:Hips`), so splitting at the first colon is deliberate.
func _discover_track_prefix() -> String:
	if _anim == null:
		return "Armature/Skeleton3D"
	for source_name in _anim.get_animation_list():
		var clip: Animation = _anim.get_animation(source_name)
		for i in clip.get_track_count():
			var raw := String(clip.track_get_path(i))
			var colon := raw.find(":")
			if colon > 0:
				return raw.substr(0, colon)
	return "Armature/Skeleton3D"


func _load_glb(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		return null
	return doc.generate_scene(st) as Node3D


func _find_first(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var hit := _find_first(c, cls)
		if hit != null:
			return hit
	return null


# =========================================================================
# Padel strokes, authored here in Godot (no new paid assets)
# =========================================================================
#
# Each stroke is a plain Animation of TYPE_ROTATION_3D tracks on the GLB's own
# bones. A key is `bone_rest_rotation * offset`, so offset = identity is exactly
# the rest pose and every stroke starts and ends there. Angles are in degrees,
# (x, y, z) Euler, applied in the bone's parent space.
#
# Right-handed athlete (the GLB's rig has no handedness of its own). The poses are
# functional placeholders chosen so the motion is large enough to read on camera
# and to measure in a test — they are not a proposed animation style.

const STROKE_SPECS := {
	&"volley": {
		"length": 0.36,
		"keys": {
			"Spine": [[0.0, [0, 0, 0]], [0.10, [-3, 10, 0]], [0.18, [2, -8, 0]], [0.36, [0, 0, 0]]],
			"RightArm": [[0.0, [0, 0, 0]], [0.10, [-15, 12, -12]], [0.18, [5, -14, 10]], [0.36, [0, 0, 0]]],
			"RightForeArm": [[0.0, [0, 0, 0]], [0.10, [0, 0, -20]], [0.18, [0, 0, -8]], [0.36, [0, 0, 0]]],
		},
	},
	&"drive": {
		"length": 0.62,
		"keys": {
			"Hips":          [[0.0, [0, 0, 0]], [0.18, [0, 34, 0]], [0.36, [0, -26, 0]], [0.62, [0, 0, 0]]],
			"Spine":         [[0.0, [0, 0, 0]], [0.18, [-8, 40, 0]], [0.36, [6, -34, 0]], [0.62, [0, 0, 0]]],
			"RightShoulder": [[0.0, [0, 0, 0]], [0.18, [0, 26, -18]], [0.36, [0, -30, 22]], [0.62, [0, 0, 0]]],
			"RightArm":      [[0.0, [0, 0, 0]], [0.18, [-34, 52, -40]], [0.36, [22, -58, 46]], [0.62, [0, 0, 0]]],
			"RightForeArm":  [[0.0, [0, 0, 0]], [0.18, [0, 0, -54]], [0.36, [0, 0, -12]], [0.62, [0, 0, 0]]],
			"RightHand":     [[0.0, [0, 0, 0]], [0.18, [0, 0, -26]], [0.36, [0, 0, 30]], [0.62, [0, 0, 0]]],
			"LeftArm":       [[0.0, [0, 0, 0]], [0.18, [0, -24, 26]], [0.36, [0, 18, -14]], [0.62, [0, 0, 0]]],
		},
	},
	&"slice": {
		"length": 0.54,
		"keys": {
			"Hips":          [[0.0, [0, 0, 0]], [0.16, [0, 24, 0]], [0.32, [0, -18, 0]], [0.54, [0, 0, 0]]],
			"Spine":         [[0.0, [0, 0, 0]], [0.16, [-14, 28, 0]], [0.32, [10, -22, 0]], [0.54, [0, 0, 0]]],
			"RightShoulder": [[0.0, [0, 0, 0]], [0.16, [0, 16, -34]], [0.32, [0, -20, 10]], [0.54, [0, 0, 0]]],
			"RightArm":      [[0.0, [0, 0, 0]], [0.16, [-52, 34, -56]], [0.32, [34, -40, 24]], [0.54, [0, 0, 0]]],
			"RightForeArm":  [[0.0, [0, 0, 0]], [0.16, [0, 0, -38]], [0.32, [0, 0, -20]], [0.54, [0, 0, 0]]],
			"RightHand":     [[0.0, [0, 0, 0]], [0.16, [0, 0, 34]], [0.32, [0, 0, -18]], [0.54, [0, 0, 0]]],
		},
	},
	&"lob": {
		"length": 0.70,
		"keys": {
			"Hips":          [[0.0, [0, 0, 0]], [0.22, [0, 18, 0]], [0.44, [0, -14, 0]], [0.70, [0, 0, 0]]],
			"Spine":         [[0.0, [0, 0, 0]], [0.22, [-18, 22, 0]], [0.44, [-6, -18, 0]], [0.70, [0, 0, 0]]],
			"RightShoulder": [[0.0, [0, 0, 0]], [0.22, [0, 14, -26]], [0.44, [0, -16, 40]], [0.70, [0, 0, 0]]],
			"RightArm":      [[0.0, [0, 0, 0]], [0.22, [-46, 30, -34]], [0.44, [-34, -30, 62]], [0.70, [0, 0, 0]]],
			"RightForeArm":  [[0.0, [0, 0, 0]], [0.22, [0, 0, -46]], [0.44, [0, 0, -8]], [0.70, [0, 0, 0]]],
			"LeftArm":       [[0.0, [0, 0, 0]], [0.22, [0, -18, 34]], [0.44, [0, 12, -10]], [0.70, [0, 0, 0]]],
		},
	},
	&"serve": {
		"length": 0.86,
		"keys": {
			"Hips":          [[0.0, [0, 0, 0]], [0.26, [0, 20, 0]], [0.52, [0, -22, 0]], [0.86, [0, 0, 0]]],
			"Spine":         [[0.0, [0, 0, 0]], [0.26, [-22, 24, 0]], [0.52, [14, -26, 0]], [0.86, [0, 0, 0]]],
			"RightShoulder": [[0.0, [0, 0, 0]], [0.26, [0, 10, -46]], [0.52, [0, -18, 28]], [0.86, [0, 0, 0]]],
			"RightArm":      [[0.0, [0, 0, 0]], [0.26, [-70, 24, -62]], [0.52, [40, -44, 38]], [0.86, [0, 0, 0]]],
			"RightForeArm":  [[0.0, [0, 0, 0]], [0.26, [0, 0, -72]], [0.52, [0, 0, -10]], [0.86, [0, 0, 0]]],
			"RightHand":     [[0.0, [0, 0, 0]], [0.26, [0, 0, -30]], [0.52, [0, 0, 26]], [0.86, [0, 0, 0]]],
			"LeftArm":       [[0.0, [0, 0, 0]], [0.26, [0, -46, 30]], [0.52, [0, 10, -16]], [0.86, [0, 0, 0]]],
		},
	},
}


func _author_strokes(lib: AnimationLibrary) -> void:
	for name in STROKE_SPECS:
		var spec: Dictionary = STROKE_SPECS[name]
		var anim: Animation = lib.get_animation(CLIP_IDLE).duplicate(true)
		anim.length = float(spec["length"])
		anim.loop_mode = Animation.LOOP_NONE
		anim.step = 0.0
		# Own a full neutral pose: sparse clips otherwise reset unkeyed limbs to
		# the imported T-pose when the mixer switches from locomotion.
		for track in anim.get_track_count():
			var value: Variant = anim.track_get_key_value(track, 0)
			while anim.track_get_key_count(track) > 0:
				anim.track_remove_key(track, 0)
			anim.track_insert_key(track, 0.0, value)
			anim.track_insert_key(track, anim.length, value)
		var tracks := 0
		for bone_name in (spec["keys"] as Dictionary):
			var resolved_bone := _resolve_bone_name(String(bone_name))
			var bone_idx := _skeleton.find_bone(resolved_bone)
			if bone_idx < 0:
				push_warning("AthleteRig: stroke '%s' references missing bone '%s'" % [name, bone_name])
				continue
			var rest_q: Quaternion = _skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion()
			if lib.has_animation(CLIP_IDLE):
				var idle := lib.get_animation(CLIP_IDLE)
				var idle_track := idle.find_track(NodePath("%s:%s" % [_track_prefix, resolved_bone]), Animation.TYPE_ROTATION_3D)
				if idle_track >= 0:
					rest_q = idle.rotation_track_interpolate(idle_track, 0.0)
			var path := NodePath("%s:%s" % [_track_prefix, resolved_bone])
			var ti := anim.find_track(path, Animation.TYPE_ROTATION_3D)
			if ti < 0:
				ti = anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(ti, path)
			while anim.track_get_key_count(ti) > 0:
				anim.track_remove_key(ti, 0)
			anim.track_set_interpolation_type(ti, Animation.INTERPOLATION_CUBIC)
			for key in (spec["keys"] as Dictionary)[bone_name]:
				var t := float(key[0])
				var e: Array = key[1]
				var offset := Quaternion.from_euler(
					Vector3(deg_to_rad(float(e[0])), deg_to_rad(float(e[1])), deg_to_rad(float(e[2])))
				)
				anim.rotation_track_insert_key(ti, t, (rest_q * offset).normalized())
			tracks += 1
		if tracks > 0:
			lib.add_animation(name, anim)
			_strokes[name] = anim.length


func _resolve_bone_name(requested: String) -> String:
	if _skeleton == null:
		return requested
	var candidates := [
		requested,
		"mixamorig:" + requested,
		"mixamorig:" + requested.capitalize(),
		# Godot sanitizes the colon in Mixamo names during GLTFDocument import.
		"mixamorig_" + requested,
		"mixamorig_" + requested.capitalize(),
	]
	# Mixamo spells Spine01/02 as Spine1/2. The original Volpe rig uses the
	# zero-padded form, so both exports can share the same authored stroke specs.
	if requested == "Spine01":
		candidates.append("mixamorig:Spine1")
		candidates.append("mixamorig_Spine1")
	if requested == "Spine02":
		candidates.append("mixamorig:Spine2")
		candidates.append("mixamorig_Spine2")
	if requested == "neck":
		candidates.append("mixamorig:Neck")
		candidates.append("mixamorig_Neck")
	if requested == "Head":
		candidates.append("mixamorig:Head")
		candidates.append("mixamorig_Head")
	if requested == "head_end":
		candidates.append("mixamorig:HeadTop_End")
		candidates.append("mixamorig_HeadTop_End")
	if requested == "headfront":
		candidates.append("headfront")
	for candidate in candidates:
		if _skeleton.find_bone(candidate) >= 0:
			return candidate
	return requested


# =========================================================================
# Outfits (per-instance surface override on the single GLB material)
# =========================================================================

func set_outfit(id: StringName) -> bool:
	_ensure_built()
	if not OUTFITS.has(id):
		return false
	if _mesh_instance == null or _base_material == null:
		return false
	var entry := _outfit_entry(id)
	if entry.is_empty():
		return false

	_override = _base_material.duplicate() as StandardMaterial3D
	_override.resource_name = "Outfit_%s" % id
	_override.albedo_color = Color(1, 1, 1, 1)
	if entry["texture"] != null:
		_override.albedo_texture = entry["texture"]
	if not _use_glb_pbr:
		_override.metallic = DEFAULT_METALLIC
		_override.roughness = DEFAULT_ROUGHNESS
		# The Meshy exports carry emissiveFactor (1,1,1) with the base-colour texture
		# wired in as the emissive map; left on, that floods the athlete with its own
		# albedo. Emission off is part of the same non-glTF override block, so
		# `use_glb_pbr(true)` still renders exactly what the GLB asks for.
		_override.emission_enabled = false
	_mesh_instance.set_surface_override_material(0, _override)
	_outfit = id
	return true


func get_outfit() -> StringName:
	return _outfit


## Only outfits whose texture is actually on disk are offered. The registry is a
## superset; a missing PNG is a missing outfit, not a silently white athlete.
func get_outfit_ids() -> Array:
	_ensure_built()
	var out := []
	for id in OUTFITS:
		if OUTFITS[id] == "" or FileAccess.file_exists(OUTFITS[id]):
			out.append(id)
	return out


## Reverts to (or leaves) the GLB's own metallic/roughness. See owner decision 1.
func use_glb_pbr(enabled: bool) -> void:
	_use_glb_pbr = enabled
	set_outfit(_outfit)


func get_material_state() -> Dictionary:
	_ensure_built()
	if _override == null:
		return {"override_present": false, "outfit": _outfit}
	var tex := _override.albedo_texture
	return {
		"override_present": _mesh_instance.get_surface_override_material(0) == _override,
		"outfit": _outfit,
		"material_class": _override.get_class(),
		"resource_name": _override.resource_name,
		"albedo_texture_digest": _outfit_cache.get(_outfit, {}).get("digest", ""),
		"albedo_texture_size": ("%dx%d" % [tex.get_width(), tex.get_height()]) if tex else "none",
		"albedo_color": str(_override.albedo_color),
		"metallic": "%.4f" % _override.metallic,
		"roughness": "%.4f" % _override.roughness,
		"emission": _override.emission_enabled,
		"shading_mode": _override.shading_mode,
		"glb_pbr": _use_glb_pbr,
	}


## Lazily loads (and caches) an outfit's texture. A digest of the actual image bytes
## is recorded so a test can prove two outfits really carry different pixels.
func _md5_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


func _outfit_entry(id: StringName) -> Dictionary:
	if _outfit_cache.has(id):
		return _outfit_cache[id]
	var path: String = OUTFITS[id]
	var entry := {}
	if path == "":
		var tex := _base_material.albedo_texture
		var digest := ""
		if tex != null:
			var img := tex.get_image()
			if img != null:
				digest = _md5_hex(img.get_data()).substr(0, 16)
		entry = {"texture": tex, "digest": digest, "source": "<glb embedded>"}
	else:
		if not FileAccess.file_exists(path):
			push_warning("AthleteRig: outfit '%s' texture missing: %s" % [id, path])
			return {}
		var bytes := FileAccess.get_file_as_bytes(path)
		var img := Image.new()
		if img.load_png_from_buffer(bytes) != OK:
			push_warning("AthleteRig: outfit '%s' texture is not a readable PNG: %s" % [id, path])
			return {}
		entry = {
			"texture": ImageTexture.create_from_image(img),
			"digest": _md5_hex(bytes).substr(0, 16),
			"source": path,
		}
	_outfit_cache[id] = entry
	return entry


# =========================================================================
# Facing
# =========================================================================

func set_facing_degrees(yaw: float) -> void:
	_facing_degrees = yaw
	rotation_degrees = Vector3(rotation_degrees.x, yaw, rotation_degrees.z)


func get_facing_degrees() -> float:
	return _facing_degrees


func set_split_step_lift(metres: float) -> void:
	if _model_root != null:
		_model_root.position.y = clampf(metres, 0.0, 0.025)


func face_towards(target: Vector3) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length_squared() > 1e-8:
		set_facing_degrees(rad_to_deg(atan2(d.x, d.z)))


# =========================================================================
# Clips
# =========================================================================

func play_locomotion(state: StringName) -> bool:
	_ensure_built()
	if not state in LOCOMOTION:
		return false
	_locomotion = state
	if _stroke != &"":
		return true          # a stroke is in flight; it resumes into the new state
	if _anim == null or not _anim.has_animation(state):
		return false
	_anim.play(state, 0.10)
	return true


func get_locomotion_state() -> StringName:
	return _locomotion


func get_locomotion_states() -> Array:
	_ensure_built()
	var out := []
	for s in LOCOMOTION:
		if _anim != null and _anim.has_animation(s):
			out.append(s)
	return out


func set_locomotion_speed_scale(s: float) -> void:
	_locomotion_speed_scale = maxf(s, 0.0)
	# A locomotion speed must never slow a stroke. The sim's `motion` is normally
	# zero on the exact tick of contact, which used to make every stroke play at
	# 0.25x and visibly miss the ball. Keep the value for the resume path instead.
	if _anim != null and _stroke == &"":
		_anim.speed_scale = _locomotion_speed_scale


func play_stroke(stroke: StringName) -> bool:
	return play_stroke_at(stroke, 0.0, 1.0)


## Starts a stroke at the normalized contact phase supplied by the simulation
## presentation bridge. The browser sets `paddle.swing = 1` only after the hit;
## starting the authored clip at its wind-up would therefore show the racket
## arriving late. Seeking to the contact phase makes the first rendered pose the
## same semantic instant as `hit_ball`, while the authored follow-through keeps
## playing normally afterwards.
func play_stroke_at(stroke: StringName, contact_phase: float = 0.0,
		speed_scale: float = 1.0) -> bool:
	_ensure_built()
	if not _strokes.has(stroke):
		return false
	if _anim == null or not _anim.has_animation(stroke):
		return false
	_stroke = stroke
	_stroke_speed_scale = maxf(speed_scale, 0.05)
	_anim.speed_scale = _stroke_speed_scale
	_anim.play(stroke, 0.0) # Contact is authoritative: never blend away its first pose.
	var length: float = float(_strokes[stroke])
	_anim.seek(clampf(contact_phase, 0.0, 1.0) * length, true, true)
	return true


func get_stroke_names() -> Array:
	_ensure_built()
	return _strokes.keys()


func is_stroking() -> bool:
	return _stroke != &""


func play_clip(name: StringName) -> bool:
	_ensure_built()
	if _anim == null or not _anim.has_animation(name):
		return false
	_anim.play(name)
	return true


func get_clip_length(name: StringName) -> float:
	_ensure_built()
	if _anim == null or not _anim.has_animation(name):
		return -1.0
	return _anim.get_animation(name).length


## Forces the current clip's pose at time `t` and applies it to the skeleton
## immediately — no frame loop, no delta accumulation. This is what makes both the
## headless test and the offline render deterministic.
func sample_at(t: float) -> void:
	_ensure_built()
	if _anim == null:
		return
	_anim.seek(t, true, true)


func _on_animation_finished(anim_name: StringName) -> void:
	if _strokes.has(anim_name):
		_stroke = &""
		stroke_finished.emit(anim_name)
		if _anim != null:
			_anim.speed_scale = _locomotion_speed_scale
		_anim.play(_locomotion, 0.10)


# =========================================================================
# Readout
# =========================================================================

func get_pose() -> Dictionary:
	_ensure_built()
	var bones := []
	if _skeleton != null:
		for i in _skeleton.get_bone_count():
			bones.append({
				"name": _skeleton.get_bone_name(i),
				"parent": _skeleton.get_bone_parent(i),
				"rotation": _skeleton.get_bone_pose_rotation(i),
				"position": _skeleton.get_bone_pose_position(i),
			})
	return {
		"clip": _anim.current_animation if _anim != null else "",
		"time": _anim.current_animation_position if _anim != null else 0.0,
		"length": _anim.current_animation_length if _anim != null else 0.0,
		"locomotion": _locomotion,
		"stroke": _stroke,
		"outfit": _outfit,
		"catalogue_outfit": _catalogue_outfit,
		"facing_degrees": _facing_degrees,
		"bones": bones,
	}


func get_skeleton() -> Skeleton3D:
	_ensure_built()
	return _skeleton


## All shipped rigs expose a right wrist, including the centimetre-based legacy
## exports. The caller must compensate the skeleton's unit scale for metre props.
func make_hand_attachment(attachment_name: StringName = &"RacketAnchor") -> BoneAttachment3D:
	_ensure_built()
	if _skeleton == null:
		return null
	var resolved := _resolve_bone_name("RightHand")
	if _skeleton.find_bone(resolved) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = String(attachment_name)
	attachment.bone_name = resolved
	_skeleton.add_child(attachment)
	return attachment


## Creates a mount that follows one bone on the frozen 28-joint Mixamo standard.
##
## This intentionally rejects the 24-joint Volpe fallback even though it also has
## a `RightHand`: that export lives under an Armature scaled 0.01 and uses different
## bone axes. Silently applying the same racket offset there would make the racket
## 100x too small. Kept for standard-only callers; the match uses
## make_hand_attachment and explicitly compensates the exported unit scale.
func make_standard_bone_attachment(requested_bone: StringName,
		attachment_name: StringName = &"BoneAttachment") -> BoneAttachment3D:
	_ensure_built()
	if _skeleton == null:
		return null
	var resolved := _resolve_bone_name(String(requested_bone))
	if not resolved.begins_with("mixamorig:") and not resolved.begins_with("mixamorig_"):
		return null
	if _skeleton.find_bone(resolved) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = String(attachment_name)
	attachment.bone_name = resolved
	_skeleton.add_child(attachment)
	return attachment


## World-space bounds of the athlete.
##
## Do NOT use `MeshInstance3D.get_aabb()` for this. On this GLB the mesh vertices are
## already in metres (mesh-space AABB 1.276 x 1.800 x 0.541), while the bone hierarchy
## is in centimetres under an `Armature` node scaled 0.01. Multiplying the mesh AABB by
## the mesh's global transform therefore double-counts that 0.01 and reports the athlete
## as 0.018 m tall. Measured, and it cost this lane a wasted render.
##
## This walks the bone poses instead and applies only the node chain above the skeleton,
## giving the real figure: about 1.04 x 1.68 x 0.27 m. In a headless tree with no frames
## the skeleton's global-pose cache is not refreshed, so the result is the REST extent —
## correct for camera framing, not a per-frame silhouette.
func get_world_extent() -> AABB:
	_ensure_built()
	if _skeleton == null:
		return AABB()
	var chain := Transform3D.IDENTITY
	var n: Node = _skeleton
	while n != null and n != get_parent():
		if n is Node3D:
			chain = (n as Node3D).transform * chain
		n = n.get_parent()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for b in _skeleton.get_bone_count():
		var p: Vector3 = _skeleton.get_bone_global_pose(b).origin
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var a := chain * lo
	var b2 := chain * hi
	var mn := Vector3(minf(a.x, b2.x), minf(a.y, b2.y), minf(a.z, b2.z))
	var mx := Vector3(maxf(a.x, b2.x), maxf(a.y, b2.y), maxf(a.z, b2.z))
	return AABB(mn, mx - mn)


func get_mesh_instance() -> MeshInstance3D:
	_ensure_built()
	return _mesh_instance


## The GLB's own material, so a caller can recolour its baked atlas without this
## script having to know how. `src/character/outfit_catalogue.gd` reads
## `albedo_texture` off it and feeds that into the outfit shader.
func get_base_material() -> StandardMaterial3D:
	_ensure_built()
	return _base_material


## Bookkeeping only — the catalogue sets the surface override itself, and this just
## records which (athlete, outfit) it put there so `get_pose()` can report it.
## Deliberately does not touch the material: one owner per surface.
func note_catalogue_outfit(athlete_id: StringName, outfit_id: StringName) -> void:
	_catalogue_outfit = {"athlete_id": athlete_id, "outfit_id": outfit_id}


func get_catalogue_outfit() -> Dictionary:
	return _catalogue_outfit


## The catalogue's masked override for this rig, or null while it has never
## installed one. The catalogue owns that material; the rig only holds it so a
## second selection reuses it rather than allocating another (plan acceptance 4:
## repeated switching must not accumulate materials).
func get_catalogue_surface() -> ShaderMaterial:
	return _catalogue_surface


## Installs `mat` on surface 0 and remembers it. Passing null forgets it without
## touching the surface, so `restore_base_surface()` stays the only way back.
func set_catalogue_surface(mat: ShaderMaterial) -> void:
	_ensure_built()
	_catalogue_surface = mat
	if mat != null and _mesh_instance != null:
		_mesh_instance.set_surface_override_material(0, mat)


## Hands surface 0 back to the rig's own base material — the duplicate of the GLB's
## material that `set_outfit(&"base")` installs, with the non-glTF metallic/roughness
## defaults of owner decision 1. This is what makes `base` round-trip: the masked
## shader is never left on the surface pretending to be a no-op.
func restore_base_surface() -> bool:
	_ensure_built()
	if _mesh_instance == null or _override == null:
		return false
	_mesh_instance.set_surface_override_material(0, _override)
	_outfit = &"base"
	return true


## True when surface 0 carries the rig's own base override, i.e. no catalogue
## material is in force. The catalogue reads this to prove `base` really restored
## rather than merely looking restored.
func is_base_surface() -> bool:
	_ensure_built()
	if _mesh_instance == null or _override == null:
		return false
	return _mesh_instance.get_surface_override_material(0) == _override


func get_load_error() -> int:
	_ensure_built()
	return _load_error


func get_surface_count() -> int:
	_ensure_built()
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return 0
	return _mesh_instance.mesh.get_surface_count()


func get_triangle_count() -> int:
	if get_surface_count() == 0:
		return 0
	var mesh := _mesh_instance.mesh
	var total := 0
	for s in mesh.get_surface_count():
		var idx: int = mesh.surface_get_array_index_len(s)
		total += (idx if idx > 0 else mesh.surface_get_array_len(s)) / 3
	return total
