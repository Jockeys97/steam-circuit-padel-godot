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
##   PRESENTATION LAYERS  (applied after the clip; never persisted into bone poses)
##     set_anticipation(stroke, weight, contact_phase) # 0..1 towards that stroke's backswing
##     get_anticipation() -> Dictionary                # {stroke, weight}
##     set_look_yaw(degrees) / get_look_yaw()          # chest+head turn, clamped +-55
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
const LOCOMOTION := [CLIP_IDLE, CLIP_WALK, CLIP_RUN, &"shuffle_left", &"shuffle_right", &"backpedal", &"prepare", &"ready", &"brake", &"split_step", &"recover_left", &"recover_right", &"cheer", &"dejected", &"serve_bounce"]
## Dead-ball body language, authored by `_author_ceremonies`: point won, point lost
## (also the match result) and the server's ball bounce while waiting to serve.
const CEREMONIES := [&"cheer", &"dejected", &"serve_bounce"]

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
var _stroke_contact_time: float = 0.0
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
const AthletePoseLayer := preload("res://src/character/athlete_pose_layer.gd")
var _pose_layer: SkeletonModifier3D = null
var _anticipation_stroke: StringName = &""
var _anticipation_phase: float = 0.34
var _anticipation_weight: float = 0.0
var _prep_cache: Dictionary = {}            # "stroke|phase" -> {bone index -> Quaternion}
var _prep_meta: Dictionary = {}             # same key -> {t, z, y, raised, score, bones}
var _ready_hand := Vector3.ZERO             # racket hand in the ready stance
var _ready_hand_set := false
var _look_yaw: float = 0.0
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
	# Presentation layers over the clip (anticipation + look). Inert at weight 0.
	_pose_layer = AthletePoseLayer.new()
	_pose_layer.name = "PoseLayer"
	_pose_layer.rig = self
	_skeleton.add_child(_pose_layer)
	_pose_layer.look_chain = _look_chain()

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

	if _athlete_id in [&"fiamma", &"colosso", &"oracolo"] or _glb_base_path == GLB_BASE or _geometry_outfit != &"base":
		_author_ready_idle(lib)
	_complete_idle_tracks(lib)
	_author_footwork(lib)
	_author_ceremonies(lib)
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
	for name in [&"shuffle_left", &"shuffle_right", &"backpedal", &"prepare", &"ready", &"brake", &"split_step", &"recover_left", &"recover_right"]:
		var anim: Animation = idle.duplicate(true)
		anim.length = 0.64 if name != &"prepare" else 1.2
		if name == &"backpedal": anim.length = 0.80
		if name == &"ready": anim.length = 2.8
		if name == &"brake": anim.length = 0.38
		if name == &"split_step": anim.length = 0.28
		if name in [&"recover_left", &"recover_right"]: anim.length = 0.34
		anim.loop_mode = Animation.LOOP_LINEAR
		if name == &"brake": anim.loop_mode = Animation.LOOP_NONE
		if name in [&"split_step", &"recover_left", &"recover_right"]: anim.loop_mode = Animation.LOOP_NONE
		# Freeze the underlying idle, including any imported hip translation.
		for track in anim.get_track_count():
			var value: Variant = anim.track_get_key_value(track, 0)
			while anim.track_get_key_count(track) > 0:
				anim.track_remove_key(track, 0)
			anim.track_insert_key(track, 0.0, value)
			anim.track_insert_key(track, anim.length, value)
		for bone in ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "Spine", "LeftArm", "RightArm", "RightForeArm"]:
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
				if name == &"split_step":
					# Two knee compressions: take-off and soft landing, then neutral.
					var compress := absf(sin(phase * TAU))
					if bone.ends_with("UpLeg"):
						offset.x = deg_to_rad(-9.0 * compress)
						offset.z = deg_to_rad(sin(phase * PI) * (4.0 if bone.begins_with("Left") else -4.0))
					elif bone.ends_with("Leg"): offset.x = deg_to_rad(18.0 * compress)
					elif bone.ends_with("Foot"): offset.x = deg_to_rad(-6.0 * compress)
					elif bone == "Spine": offset.x = deg_to_rad(-3.0 * compress)
				elif name in [&"recover_left", &"recover_right"]:
					# A small alternating balance step, not a second shot or root move.
					var weight := sin(phase * TAU) * sin(phase * PI)
					var side := 1.0 if name == &"recover_left" else -1.0
					var step_weight := maxf(0.0, weight * (1.0 if bone.begins_with("Left") else -1.0))
					if bone.ends_with("UpLeg"):
						offset = Vector3(deg_to_rad(-7.0 * step_weight), 0, deg_to_rad(weight * side * 4.0))
					elif bone.ends_with("Leg"): offset.x = deg_to_rad(16.0 * step_weight)
					elif bone.ends_with("Foot"): offset.x = deg_to_rad(-5.0 * step_weight)
					elif bone == "Spine": offset.z = deg_to_rad(-weight * side * 3.0)
				elif name == &"brake":
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
				elif name == &"backpedal":
					# Reach behind with an extended leg; bend the opposite knee
					# for recovery. Keep the chest facing play, without root motion.
					var recovery := maxf(0.0, wave)
					if bone.ends_with("UpLeg"):
						offset.x = deg_to_rad(-8.0 - wave * 30.0)
					elif bone.ends_with("Leg"):
						offset.x = deg_to_rad(10.0 + recovery * 42.0)
					elif bone.ends_with("Foot"):
						offset.x = deg_to_rad(-5.0 - recovery * 17.0 + maxf(0.0, -wave) * 9.0)
					elif bone == "Spine":
						offset = Vector3(deg_to_rad(-5.0), deg_to_rad(wave * 3.0), deg_to_rad(wave * 2.0))
					elif bone == "RightForeArm": offset.z = deg_to_rad(-12.0)
					elif bone.ends_with("Arm"): offset.x = deg_to_rad(-wave * 10.0)
				elif bone.ends_with("UpLeg"):
					offset.z = deg_to_rad(wave * (10.0 if name == &"shuffle_left" else -10.0))
					offset.x = deg_to_rad(-5.0 - maxf(0.0, wave) * 5.0)
				elif bone.ends_with("Leg"):
					offset.x = deg_to_rad(8.0 + maxf(0.0, wave) * 20.0)
				elif bone.ends_with("Foot"):
					offset.x = deg_to_rad(-maxf(0.0, wave) * 7.0)
				elif bone == "Spine":
					offset.z = deg_to_rad(wave * 2.0)
					offset.x = deg_to_rad(-3.0)
				elif bone == "RightForeArm":
					offset.z = deg_to_rad(-12.0)
				elif bone.ends_with("Arm"):
					offset.x = deg_to_rad(wave * 4.0)
				anim.rotation_track_insert_key(track, phase * anim.length, (neutral * Quaternion.from_euler(offset)).normalized())
		lib.add_animation(name, anim)


## Between-point body language. Same contract as the footwork: in place,
## rotation-only, no root motion, no authority over the simulation.
##
## Unlike the footwork these are NOT fixed angles. The imported rigs disagree on
## bone axes (measured: the right arm rises with -Z on Colosso and +Z on Maestro)
## and on the starting pose (Colosso's ready hand sits at 1.33 m, Maestro's at the
## hip), so one fixed angle cheers on one athlete and dislocates the other. Each
## clip asks this skeleton, once at build time, which rotation really puts the hand
## up or down (`_solve_limb`), and keys that.
func _author_ceremonies(lib: AnimationLibrary) -> void:
	if _skeleton == null or not lib.has_animation(CLIP_IDLE):
		return
	var idle := lib.get_animation(CLIP_IDLE)
	var saved := _pose_like(idle, 0.0)
	var raise_right := _solve_limb("RightArm", "RightHand", 1.0)
	var drop_right := _solve_limb("RightArm", "RightHand", -1.0)
	var drop_left := _solve_limb("LeftArm", "LeftHand", -1.0)
	# The ball hand: out in front of the body at the waist, where a bounce is seen;
	# the forearm then beats downwards from there.
	var bounce_left := _solve_limb("LeftArm", "LeftHand", -0.35, 1.0)
	var bounce_fore := _solve_limb("LeftForeArm", "LeftHand", -1.0)
	_restore_pose(saved)
	for name in CEREMONIES:
		var anim: Animation = idle.duplicate(true)
		anim.length = {&"cheer": 0.9, &"dejected": 2.4, &"serve_bounce": 0.62}[name]
		anim.loop_mode = Animation.LOOP_LINEAR
		# Freeze the underlying idle, exactly as the footwork does.
		for track in anim.get_track_count():
			var value: Variant = anim.track_get_key_value(track, 0)
			while anim.track_get_key_count(track) > 0:
				anim.track_remove_key(track, 0)
			anim.track_insert_key(track, 0.0, value)
			anim.track_insert_key(track, anim.length, value)
		for step in range(13):
			var phase := float(step) / 12.0
			var at := phase * anim.length
			var pose := {}
			if name == &"cheer":
				# Racket arm up, pumped twice per loop; knees give a small bounce.
				var pump := 0.82 + 0.18 * absf(sin(phase * TAU))
				pose["RightArm"] = Quaternion.IDENTITY.slerp(raise_right, pump)
				pose["LeftArm"] = Quaternion.IDENTITY.slerp(drop_left, 0.6)
				pose["Spine"] = Quaternion.from_euler(Vector3(deg_to_rad(-4.0), 0, 0))
				var dip := absf(sin(phase * TAU))
				pose["LeftUpLeg"] = Quaternion.from_euler(Vector3(deg_to_rad(-6.0 * dip), 0, 0))
				pose["RightUpLeg"] = pose["LeftUpLeg"]
				pose["LeftLeg"] = Quaternion.from_euler(Vector3(deg_to_rad(11.0 * dip), 0, 0))
				pose["RightLeg"] = pose["LeftLeg"]
			elif name == &"dejected":
				# Chest and head drop, arms hang, a slow shake of the head.
				# Sized for the match camera, not a close-up: at 14 degrees the drop
				# measured 10-14 cm at the head and did not read at 34 m.
				pose["Spine"] = Quaternion.from_euler(Vector3(deg_to_rad(24.0), 0, 0))
				pose["neck"] = Quaternion.from_euler(Vector3(deg_to_rad(26.0), deg_to_rad(sin(phase * TAU) * 12.0), 0))
				pose["RightArm"] = Quaternion.IDENTITY.slerp(drop_right, 0.85)
				pose["LeftArm"] = Quaternion.IDENTITY.slerp(drop_left, 0.85)
				pose["LeftUpLeg"] = Quaternion.from_euler(Vector3(deg_to_rad(-6.0), 0, 0))
				pose["RightUpLeg"] = pose["LeftUpLeg"]
				pose["LeftLeg"] = Quaternion.from_euler(Vector3(deg_to_rad(10.0), 0, 0))
				pose["RightLeg"] = pose["LeftLeg"]
			else:
				# One bounce per loop: the hand goes down with the ball and comes
				# back up to meet it; the knees follow the hand.
				var down := 0.5 - 0.5 * cos(phase * TAU)
				pose["LeftArm"] = Quaternion.IDENTITY.slerp(bounce_left, 0.85)
				pose["LeftForeArm"] = Quaternion.IDENTITY.slerp(bounce_fore, 0.05 + 0.45 * down)
				pose["RightArm"] = Quaternion.IDENTITY.slerp(drop_right, 0.5)
				pose["Spine"] = Quaternion.from_euler(Vector3(deg_to_rad(6.0 + 3.0 * down), 0, 0))
				pose["LeftUpLeg"] = Quaternion.from_euler(Vector3(deg_to_rad(-5.0 * down), 0, 0))
				pose["RightUpLeg"] = pose["LeftUpLeg"]
				pose["LeftLeg"] = Quaternion.from_euler(Vector3(deg_to_rad(9.0 * down), 0, 0))
				pose["RightLeg"] = pose["LeftLeg"]
			for bone in pose:
				var path := NodePath("%s:%s" % [_track_prefix, _resolve_bone_name(bone)])
				var track := anim.find_track(path, Animation.TYPE_ROTATION_3D)
				if track < 0:
					continue
				var neutral: Quaternion = idle.rotation_track_interpolate(track, 0.0)
				if step == 0:
					while anim.track_get_key_count(track) > 0:
						anim.track_remove_key(track, 0)
				anim.rotation_track_insert_key(track, at, (neutral * pose[bone]).normalized())
		lib.add_animation(name, anim)


## Poses the live skeleton like `anim` at `time` (rotation tracks only) and returns
## what it overwrote, so `_restore_pose` can put the rest pose back afterwards.
func _pose_like(anim: Animation, time: float) -> Dictionary:
	var saved := {}
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := _skeleton.find_bone(String(anim.track_get_path(track).get_concatenated_subnames()))
		if bone < 0:
			continue
		saved[bone] = _skeleton.get_bone_pose_rotation(bone)
		_skeleton.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(track, time))
	return saved


func _restore_pose(saved: Dictionary) -> void:
	for bone in saved:
		_skeleton.set_bone_pose_rotation(bone, saved[bone])


## Forward kinematics from the bone POSES, parent by parent. Not
## `get_bone_global_pose()`: the rig is built before it enters the tree
## (`AthleteSpawn.make` builds, then the caller adds it), and out of the tree the
## skeleton never refreshes its global-pose cache — every trial rotation measured
## the same and the solver kept "no rotation". Measured, not assumed.
func _bone_in_skeleton(bone: int) -> Transform3D:
	var out := Transform3D.IDENTITY
	var b := bone
	while b >= 0:
		var basis := Basis(_skeleton.get_bone_pose_rotation(b)) * Basis.from_scale(_skeleton.get_bone_pose_scale(b))
		out = Transform3D(basis, _skeleton.get_bone_pose_position(b)) * out
		b = _skeleton.get_bone_parent(b)
	return out


## The rotation of `bone` about one of its own axes (at most 170 degrees) that moves
## `end` highest (`direction` > 0) or lowest (< 0), measured in the athlete's own
## space (+Y up, +Z facing) on the skeleton as `_pose_like` left it. `forward` > 0
## also rewards `end` coming out in front of the body. Returned as an OFFSET to
## post-multiply onto the idle rotation — the footwork's own key convention. A small
## cost per degree keeps the smallest rotation that does the job.
func _solve_limb(bone: String, end: String, direction: float, forward := 0.0) -> Quaternion:
	var b := _skeleton.find_bone(_resolve_bone_name(bone))
	var e := _skeleton.find_bone(_resolve_bone_name(end))
	if b < 0 or e < 0:
		return Quaternion.IDENTITY
	# Skeleton space -> athlete space, walking the node chain like get_world_extent.
	var chain := Transform3D.IDENTITY
	var n: Node = _skeleton
	while n != null and n != self:
		if n is Node3D:
			chain = (n as Node3D).transform * chain
		n = n.get_parent()
	var neutral := _skeleton.get_bone_pose_rotation(b)
	var best := Quaternion.IDENTITY
	var best_score := -INF
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		for deg in range(-170, 171, 10):
			var offset := Quaternion(axis, deg_to_rad(float(deg)))
			_skeleton.set_bone_pose_rotation(b, neutral * offset)
			var p: Vector3 = chain * _bone_in_skeleton(e).origin
			var score := p.y * direction + p.z * forward - absf(float(deg)) * 0.0004
			if score > best_score:
				best_score = score
				best = offset
	_skeleton.set_bone_pose_rotation(b, neutral)
	return best


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
	var ready_bones := ["LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "Spine", "Spine1"]
	var relax_shoulders := _geometry_outfit != &"base" or _glb_base_path == GLB_BASE or _athlete_id in [&"colosso", &"oracolo"]
	if relax_shoulders:
		# This bind pose also raises the shoulder joints. Arms alone leave the
		# silhouette in an A-pose despite valid forearm animation.
		ready_bones.append_array(["LeftShoulder", "RightShoulder", "LeftHand", "RightHand"])
	for bone in ready_bones:
		var path := NodePath("%s:%s" % [_track_prefix, _resolve_bone_name(bone)])
		var ti := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		if ti < 0:
			continue
		var neutral: Quaternion = idle.rotation_track_interpolate(ti, 0.0)
		var wi := walk.find_track(path, Animation.TYPE_ROTATION_3D)
		if ("Arm" in bone or (relax_shoulders and ("Shoulder" in bone or "Hand" in bone))) and wi >= 0:
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


## Whole visual rig (including hand attachments), never the simulated player.
## Yaw remains owned by facing. Do not layer this tilt onto shot contact poses.
func set_movement_lean(local_degrees: Vector2) -> void:
	var lean := local_degrees.limit_length(6.0) if not is_stroking() else Vector2.ZERO
	rotation_degrees.x = lean.y
	rotation_degrees.z = -lean.x


func set_split_step_lift(metres: float) -> void:
	if _model_root != null:
		_model_root.position.y = clampf(metres, 0.0, 0.025)


func face_towards(target: Vector3) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length_squared() > 1e-8:
		set_facing_degrees(rad_to_deg(atan2(d.x, d.z)))


# =========================================================================
# Presentation layers: anticipation and look (athlete_pose_layer.gd)
# =========================================================================

## Upper-body bones the anticipation may move. Legs and hips stay with the
## footwork clip so a backswing never slides the feet.
const PREP_BONES := ["Spine", "Spine01", "Spine02", "RightShoulder", "RightArm", "RightForeArm",
	"RightHand", "LeftShoulder", "LeftArm", "LeftForeArm"]
## Spine chain + head carrying the look yaw, parent first, with each bone's share.
const LOOK_BONES := [["Spine", 0.18], ["Spine01", 0.18], ["Spine02", 0.18], ["neck", 0.18], ["Head", 0.28]]
## Hard limit of the look yaw, degrees either side of the rig's facing.
const LOOK_MAX_DEGREES := 55.0
## Most of a backswing: the contact frame still has a pose to swing into.
const ANTICIPATION_MAX := 0.60
## How far the racket must go, in body lengths, for a clip frame to count as a
## preparation: behind the torso plane (PREP_MIN_BACK) or above the shoulder
## (PREP_MIN_ABOVE, and then it must not sit further forward than PREP_MAX_FRONT,
## which is what makes an arm held out at chest height a shield, not a wind-up).
const PREP_MIN_BACK := 0.10
const PREP_MIN_ABOVE := 0.10
const PREP_MAX_FRONT := 0.10
## The knee flexion a low-contact adaptation may reach in total (the clip's own
## stance plus what this adds). A padel player on a low ball bends to roughly
## 50-60 deg; measured before this bound: 100-110 deg on every groundstroke.
const LOW_CONTACT_MAX_KNEE_DEG := 58.0
## How far the wind-up may take each joint from the clip's own neutral pose, in
## degrees. A padel preparation is compact — the racket hand travels ~0.2-0.3 m
## (measured: 0.6-1.1 m before these caps, `evidence/anticipation-look-layers.md`),
## which is what "the wind-up is exaggerated" was describing. The cap is per
## joint, so it bounds the hand's travel through the whole arm chain.
const PREP_LIMIT_DEG := {
	"Spine": 6.0, "Spine01": 5.0, "Spine02": 5.0,
	"RightShoulder": 8.0, "LeftShoulder": 6.0,
	"RightArm": 16.0, "LeftArm": 11.0,
	"RightForeArm": 13.0, "LeftForeArm": 9.0, "RightHand": 8.0,
}


## Blends the upper body towards `stroke`'s own backswing pose. `weight` 0..1;
## ignored (forced to 0) while a stroke is playing, because contact is the
## simulation's and must never be blended away.
func set_anticipation(stroke: StringName, weight: float, contact_phase: float = 0.5) -> void:
	_ensure_built()
	if _pose_layer == null:
		return
	if stroke == &"" or not _strokes.has(stroke) or is_stroking():
		weight = 0.0
	elif _prep_pose_for(stroke, contact_phase).is_empty():
		weight = 0.0 # the clip holds no frame that reads as a preparation
	_anticipation_weight = clampf(weight, 0.0, ANTICIPATION_MAX)
	if _anticipation_weight <= 0.0:
		_pose_layer.prep_weight = 0.0
		return
	if stroke != _anticipation_stroke or not is_equal_approx(contact_phase, _anticipation_phase):
		_anticipation_stroke = stroke
		_anticipation_phase = contact_phase
		_pose_layer.prep_pose = _prep_pose_for(stroke, contact_phase)
	_pose_layer.prep_weight = _anticipation_weight


func get_anticipation() -> Dictionary:
	return {"stroke": _anticipation_stroke, "weight": _anticipation_weight, "contact_phase": _anticipation_phase}


## Turns chest and head by `degrees` about the rig's up axis (positive = the
## rig's own left, same sign as `set_facing_degrees`). Clamped to LOOK_MAX_DEGREES.
func set_look_yaw(degrees: float) -> void:
	_ensure_built()
	_look_yaw = clampf(degrees if is_finite(degrees) else 0.0, -LOOK_MAX_DEGREES, LOOK_MAX_DEGREES)
	if _pose_layer != null:
		_pose_layer.look_yaw_degrees = _look_yaw


func get_look_yaw() -> float:
	return _look_yaw


func _look_chain() -> Array:
	var out := []
	var total := 0.0
	for entry in LOOK_BONES:
		var index := _skeleton.find_bone(_resolve_bone_name(String(entry[0])))
		if index >= 0:
			out.append([index, float(entry[1])])
			total += float(entry[1])
	if total > 0.0:
		for entry in out:
			entry[1] = float(entry[1]) / total
	return out


## The backswing is the frame, before contact, where the racket hand is furthest
## BEHIND the athlete and/or raised — not the frame furthest from the clip's first
## pose. The old rule picked the pose that reads as the athlete protecting himself
## with the racket (hand in front of the chest: measured z = +0.31 m on the
## backhand clip, while the same clip holds a real take-back at z = -0.41 m).
## The hand is placed by forward kinematics from the clip's own rotation tracks,
## so nothing is played or mutated here, and an authored and a Meshy clip
## calibrate alike. Returns {} when the clip has no frame that reads as a
## preparation: no wind-up beats a wrong one.
func _prep_pose_for(stroke: StringName, contact_phase: float = 0.5) -> Dictionary:
	var key := "%s|%.2f" % [stroke, contact_phase]
	if _prep_cache.has(key):
		return _prep_cache[key]
	var pose := {}
	var anim: Animation = _anim.get_animation(stroke) if _anim != null and _anim.has_animation(stroke) else null
	if anim == null:
		return pose
	var tracks := {}
	for bone_name in PREP_BONES:
		var resolved := _resolve_bone_name(bone_name)
		var index := _skeleton.find_bone(resolved)
		if index < 0:
			continue
		var track := anim.find_track(NodePath("%s:%s" % [_track_prefix, resolved]), Animation.TYPE_ROTATION_3D)
		if track >= 0 and not tracks.has(index):
			tracks[index] = track
	if tracks.is_empty():
		return pose
	var contact := anim.length * clampf(contact_phase, 0.1, 0.9)
	var hand0 := _hand_local_at(anim, 0.0)
	var scale := maxf(0.2, hand0.length())
	# "Raised" is measured against the athlete's READY hand, not against the
	# clip's own first frame: an overhead clip (the smash) starts with the racket
	# already at 1.50 m, so its own frame 0 made every later frame look flat and
	# the smash silently lost its wind-up.
	var ready_hand := _ready_hand_local()
	if ready_hand == Vector3.ZERO:
		ready_hand = hand0
	# A frame only counts as a preparation if it does one of two things, measured
	# on the athlete's own skeleton:
	#   * takes the racket BEHIND the torso plane (z <= -PREP_MIN_BACK), or
	#   * lifts it ABOVE THE SHOULDER without pushing it in front of the torso
	#     (an overhead wind-up). The second condition is what rejects the arm
	#     extended forward at chest height — the pose that reads as the athlete
	#     protecting himself with the racket, which the authored placeholder
	#     clips hold on every frame.
	var best_t := 0.0
	var best_score := -INF
	for step in 25:
		var t := contact * float(step) / 24.0
		var hand := _hand_local_at(anim, t)
		var behind: float = -hand.z / scale
		var score := -INF
		if behind >= PREP_MIN_BACK:
			score = behind
		if hand.z <= PREP_MAX_FRONT:
			var above: float = (hand.y - _bone_local_at(anim, t, "RightShoulder").y) / scale
			if above >= PREP_MIN_ABOVE:
				score = maxf(score, 0.6 * above)
		if score > best_score:
			best_score = score
			best_t = t
	if best_score <= 0.0:
		_prep_cache[key] = pose
		_prep_meta[key] = {"t": best_t, "z": 0.0, "y": 0.0, "raised": 0.0, "score": best_score, "bones": 0}
		return pose
	for index in tracks:
		var track: int = tracks[index]
		var neutral: Quaternion = anim.rotation_track_interpolate(track, 0.0)
		var target: Quaternion = anim.rotation_track_interpolate(track, best_t)
		# Stored as a DELTA from the clip's own first frame, not as an absolute
		# rotation: the layer composes it on top of whatever the athlete is doing
		# (shuffle, run, prepare). An absolute target was transplanting the
		# stroke clip's spine onto the locomotion clip's, and on rigs whose two
		# clips disagree on the spine's frame that folded the athlete in half
		# (measured in a match: torso 80-94 deg from vertical on shuffle/prepare/
		# run with the wind-up on, 0-10 deg with it off).
		pose[index] = (neutral.inverse() * _clamp_to_neutral(neutral, target, index)).normalized()
	var chosen := _hand_local_at(anim, best_t)
	_prep_meta[key] = {"t": best_t, "z": chosen.z / scale, "y": chosen.y / scale,
		"raised": (chosen.y - ready_hand.y) / scale, "score": best_score, "bones": pose.size()}
	_prep_cache[key] = pose
	return pose


## What the wind-up chose for this stroke, in body lengths: `z` negative means
## the racket is behind the athlete (a take-back), positive means in front of the
## chest (the pose that reads as shielding). `bones` 0 means no preparation was
## available, so no wind-up is shown. For the probes and the evidence file.
func get_prep_readout(stroke: StringName, contact_phase: float = 0.34) -> Dictionary:
	_ensure_built()
	_prep_pose_for(stroke, contact_phase)
	return _prep_meta.get("%s|%.2f" % [stroke, contact_phase], {})


## Where the racket hand sits in the athlete's ready stance, for the "raised"
## comparison above. Cached: it never changes for a given rig.
func _ready_hand_local() -> Vector3:
	if _ready_hand_set:
		return _ready_hand
	var ready: Animation = _anim.get_animation(&"ready") if _anim != null and _anim.has_animation(&"ready") else null
	if ready == null:
		return Vector3.ZERO
	var hand := _hand_local_at(ready, ready.length * 0.5)
	if hand == Vector3.ZERO:
		return Vector3.ZERO
	_ready_hand = hand
	_ready_hand_set = true
	return _ready_hand


## The racket hand's origin in the rig's LOCAL frame at time `t`, by forward
## kinematics over the clip's rotation tracks and the skeleton's rest positions.
## Local +Z points at the net for every rig (the near pair is yawed 180), so a
## take-back is z < 0 and "in front of the chest" is z > 0. Units are the rig's
## own (metres on a Meshy export, centimetres on the legacy Volpe one), which is
## why every use of it normalises by `_hand_local_at(anim, 0.0).length()`.
func _hand_local_at(anim: Animation, t: float) -> Vector3:
	return _bone_local_at(anim, t, "RightHand")


## Same forward kinematics, for any bone of the arm chain (the shoulder line is
## what tells an overhead wind-up from an arm held out in front of the chest).
func _bone_local_at(anim: Animation, t: float, bone_name: String) -> Vector3:
	if _skeleton == null:
		return Vector3.ZERO
	var hand := _skeleton.find_bone(_resolve_bone_name(bone_name))
	if hand < 0:
		return Vector3.ZERO
	var chain: Array[int] = []
	var cursor := hand
	while cursor >= 0 and chain.size() < 32:
		chain.push_front(cursor)
		cursor = _skeleton.get_bone_parent(cursor)
	var acc := Transform3D.IDENTITY
	for index in chain:
		var local := _skeleton.get_bone_rest(index)
		var track := anim.find_track(NodePath("%s:%s" % [_track_prefix, _skeleton.get_bone_name(index)]), Animation.TYPE_ROTATION_3D)
		if track >= 0:
			local.basis = Basis(anim.rotation_track_interpolate(track, t)).scaled(local.basis.get_scale())
		acc = acc * local
	return acc.origin


## Bounds one joint's wind-up: `target` is pulled back along its own arc from
## `neutral` until it is no further than PREP_LIMIT_DEG from it.
func _clamp_to_neutral(neutral: Quaternion, target: Quaternion, bone_index: int) -> Quaternion:
	var limit := float(PREP_LIMIT_DEG.get(_skeleton.get_bone_name(bone_index).replace("mixamorig_", "").replace("mixamorig:", ""), 10.0))
	var angle := rad_to_deg(neutral.angle_to(target))
	if angle <= limit or angle <= 0.001:
		return target
	return neutral.slerp(target, limit / angle).normalized()


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
		speed_scale: float = 1.0, low_contact: float = 0.0) -> bool:
	_ensure_built()
	if not _strokes.has(stroke):
		return false
	if _anim == null or not _anim.has_animation(stroke):
		return false
	_stroke = stroke
	# The contact pose is the simulation's: drop any anticipation this frame.
	_anticipation_weight = 0.0
	if _pose_layer != null:
		_pose_layer.prep_weight = 0.0
	_stroke_speed_scale = maxf(speed_scale, 0.05)
	_anim.speed_scale = _stroke_speed_scale
	var visual_clip := _low_contact_clip(stroke, contact_phase, low_contact)
	_anim.play(visual_clip, 0.0) # Contact is authoritative: never blend away its first pose.
	var length: float = float(_strokes[stroke])
	_stroke_contact_time = clampf(contact_phase, 0.0, 1.0) * length
	_anim.seek(_stroke_contact_time, true, true)
	return true


## Per-instance baked adaptation: preserve the source wrist/torso animation,
## flex the legs and compensate the pelvis to retain the mean foot anchor.
## Three strengths bound cache size; no cumulative bone overrides each frame.
##
## The added flexion is BOUNDED: the clip's own stance already carries 15-72 deg
## of knee flexion, and a flat +36 deg took the total to 100-110 deg — a deep
## squat, which is what "they bend too much" was describing. The weight backs off
## per sample until the knee stays under LOW_CONTACT_MAX_KNEE_DEG, so a clip that
## already crouches is left alone and a straight-legged one still gets a dip.
func _low_contact_clip(stroke: StringName, contact: float, amount: float) -> StringName:
	var level := clampi(roundi(amount * 3.0), 0, 3)
	if level == 0: return stroke
	var name := StringName("low_contact_%s_%d_%d" % [stroke, level, roundi(contact * 100.0)])
	if _anim.has_animation(name): return name
	var bones: Array[int] = []
	for bone in ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "Hips"]:
		var index := _skeleton.find_bone(_resolve_bone_name(bone))
		if index < 0: return stroke
		bones.append(index)
	var source := _anim.get_animation(stroke)
	var adapted: Animation = source.duplicate(true)
	var tracks: Array[int] = []
	for i in bones.size():
		var path := NodePath("%s:%s" % [_track_prefix, _skeleton.get_bone_name(bones[i])])
		var type := Animation.TYPE_POSITION_3D if i == 6 else Animation.TYPE_ROTATION_3D
		var track := adapted.find_track(path, type)
		if track < 0:
			track = adapted.add_track(type)
			adapted.track_set_path(track, path)
		while adapted.track_get_key_count(track): adapted.track_remove_key(track, 0)
		tracks.append(track)
	_anim.play(stroke)
	for step in 25:
		var phase := float(step) / 24.0
		var time := phase * source.length
		_anim.seek(time, true, true)
		_skeleton.force_update_all_bone_transforms()
		var originals: Array[Quaternion] = []
		for i in 6:
			originals.append(_skeleton.get_bone_pose_rotation(bones[i]))
		var feet := (_skeleton.get_bone_global_pose(bones[4]).origin + _skeleton.get_bone_global_pose(bones[5]).origin) * 0.5
		var weight := smoothstep(0.0, maxf(contact, 0.05), phase) if phase <= contact else 1.0 - smoothstep(contact, 1.0, phase)
		weight *= float(level) / 3.0
		# Back the added flexion off until the knee is inside a padel range.
		for attempt in 5:
			for i in 6:
				var degrees := -18.0 if i < 2 else (36.0 if i < 4 else -18.0)
				var rotation := (originals[i] * Quaternion(Vector3.RIGHT, deg_to_rad(degrees) * weight)).normalized()
				_skeleton.set_bone_pose_rotation(bones[i], rotation)
			_skeleton.force_update_all_bone_transforms()
			if _knee_flexion(bones) <= LOW_CONTACT_MAX_KNEE_DEG or weight <= 0.02:
				break
			weight *= 0.55
		for i in 6:
			adapted.rotation_track_insert_key(tracks[i], time, _skeleton.get_bone_pose_rotation(bones[i]))
		_skeleton.force_update_all_bone_transforms()
		var moved_feet := (_skeleton.get_bone_global_pose(bones[4]).origin + _skeleton.get_bone_global_pose(bones[5]).origin) * 0.5
		var parent := _skeleton.get_bone_parent(bones[6])
		var parent_basis := _skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var pelvis := _skeleton.get_bone_pose_position(bones[6]) + parent_basis.inverse() * (feet - moved_feet)
		adapted.position_track_insert_key(tracks[6], time, pelvis)
	_anim.get_animation_library(&"").add_animation(name, adapted)
	return name


## Knee flexion in degrees at the CURRENT bone poses: 0 = straight leg. Measured
## between the thigh and the shin, in skeleton space (angles are scale-free).
## `bones` is the seven-bone list `_low_contact_clip` builds.
func _knee_flexion(bones: Array[int]) -> float:
	var worst := 0.0
	for side in 2:
		var thigh: Vector3 = _skeleton.get_bone_global_pose(bones[2 + side]).origin - _skeleton.get_bone_global_pose(bones[side]).origin
		var shin: Vector3 = _skeleton.get_bone_global_pose(bones[4 + side]).origin - _skeleton.get_bone_global_pose(bones[2 + side]).origin
		if thigh.length_squared() > 1e-9 and shin.length_squared() > 1e-9:
			worst = maxf(worst, rad_to_deg(thigh.angle_to(shin)))
	return worst


func clear_low_contact() -> void:
	if _anim != null and String(_anim.current_animation).begins_with("low_contact_") and _stroke != &"":
		var time := _anim.current_animation_position
		_anim.play(_stroke, 0.0)
		_anim.seek(time, true, true)


## Presentation-only recovery. Preserve impact and most follow-through, then
## blend into the already requested gait instead of sliding through a long tail.
func recover_to_movement() -> bool:
	if _stroke == &"" or _anim == null or not _locomotion in [&"walk", &"run", &"shuffle_left", &"shuffle_right", &"backpedal"]:
		return false
	var length: float = float(_strokes[_stroke])
	var recovery_time := maxf(length * 0.75, _stroke_contact_time + 0.12 * _stroke_speed_scale)
	if _anim.current_animation_position < recovery_time:
		return false
	_on_animation_finished(_stroke)
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
	if String(anim_name).begins_with("low_contact_"):
		anim_name = _stroke
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
