extends RefCounted
class_name OutfitCatalogue
## OutfitCatalogue — the six athletes and their 26 outfits, resolved onto the rig.
##
## ===========================================================================
## PUBLIC API  (static; nothing here needs instancing)
## ===========================================================================
##   ROSTER
##     OutfitCatalogue.athlete_ids() -> Array[StringName]
##     OutfitCatalogue.athlete(id) -> Dictionary         # {} if unknown
##     OutfitCatalogue.outfit_ids(athlete_id) -> Array[StringName]
##     OutfitCatalogue.has_outfit(athlete_id, outfit_id) -> bool
##     OutfitCatalogue.unlock_key(athlete_id, outfit_id) -> String   # "pantera:mythic"
##     OutfitCatalogue.entries() -> Array[Dictionary]    # all 26, flat, ordered
##
##   RESOLUTION (what the rig must be put into)
##     OutfitCatalogue.resolve(athlete_id, outfit_id) -> Dictionary  # {} if unknown
##     OutfitCatalogue.make_material(source_texture) -> ShaderMaterial
##     OutfitCatalogue.apply(rig, athlete_id, outfit_id) -> bool
##     OutfitCatalogue.read_back(rig) -> Dictionary      # what is on the rig now
##
##   PROVENANCE
##     OutfitCatalogue.load_error() -> int               # OK (0) when the JSON parsed
##     OutfitCatalogue.source_info() -> Dictionary
##
## ===========================================================================
## WHERE THE NUMBERS COME FROM
## ===========================================================================
## Nothing in this file is a hand-typed colour. `res://assets/athletes/
## reference_catalogue.json` is produced by
## `tools/character/extract_reference_catalogue.py`, which parses the frozen
## browser reference `js/data.js` — ATHLETES[] for the roster and ATHLETE_OUTFITS{}
## for the outfits. Run that tool with `--check` to prove the JSON still matches the
## reference; it exits 1 on drift.
##
## THE MAPPING, AND WHY IT IS A DERIVATION AND NOT AN INVENTION
## The reference defines each outfit as exactly two colours, `colors: [a, b]`, plus
## six 2D sprite sheets. The rig is a single mesh with a single baked atlas whose
## only garment-shaped texel families are the navy body panels (#22304a) and the gold
## trim (#ffc94a) — measured by the previous slice, see
## `tools/character/outfits-strong.json`. So:
##
##     colors[0] -> the #22304a family  (top, shorts, sneaker panels)
##     colors[1] -> the #ffc94a family  (trim, collar, wristbands)
##
## That is the whole mapping. It is positional and uniform across all 26 entries; no
## per-outfit tuning exists anywhere in this lane.
##
## NOT EXPRESSIBLE ON THIS RIG (reported per entry by `resolve()`, and listed in the
## evidence file as owner decisions, rather than quietly faked):
##   * `visual.skin` / `visual.hair` — the placeholder model is a furred spitz, not a
##     human, and the fur is what the saturation guard deliberately protects.
##   * `visual.kitStyle` ("diagonal" / "side" / "raglan"), `visual.frame`,
##     `visual.hairStyle`, `visual.beard` — 2D sprite-generator hints with no
##     counterpart on one baked atlas.
##   * `visual.secondary` — the atlas exposes two recolourable families, and the
##     reference's outfit record supplies exactly two colours for them. A third
##     colour has nowhere to go.
##   * The six per-outfit sprite sheets — the unlockable outfits' real visual identity
##     in the browser build is ARTWORK, not colour. Two outfits of one athlete that
##     differ mostly by artwork collapse onto near-identical 3D garments here. That is
##     the honest limit of this rig, and it is why `resolve()` returns
##     `art_dependent = true` for every non-base entry.
##
## DERIVED, NOT FROM THE REFERENCE:
##   * `protect_sat`, `hue_tol_deg`, `sat_min/val_min/val_max`, `luma_clamp` — the
##     measured mask constants of the previous slice, reused unchanged.
##   * The reference's own `visual.kit`/`visual.accent` and the `base` outfit's
##     `colors` agree for five athletes and DISAGREE for `oracolo`
##     (visual #6b3df0/#e3c6ff vs base colors #6d42b8/#a96cff). The outfit record
##     wins here, because the outfit record is what an outfit is.

const DATA_PATH := "res://assets/athletes/reference_catalogue.json"
const SHADER_PATH := "res://src/character/outfit_recolour.gdshader"

## GODOT-ONLY SPECIALS (port additions). `reference_catalogue.json` is generated
## from the frozen browser reference and holds exactly the six athletes; a special
## (see `src/character/specials.gd`) is not in it and never will be. The roster
## readers below therefore FALL BACK to the specials overlay for an id the frozen
## file does not know. What must NOT change: `athlete_ids()` and `entries()` stay
## the reference's six, and `resolve()`'s shape is untouched — a special's colors
## arrive through the same `colors[0] -> primary, colors[1] -> trim` mapping.
const Specials := preload("res://src/character/specials.gd")

## Measured mask constants, carried over verbatim from the previous slice's
## tools/character/outfits-strong.json `defaults`. Not re-tuned in this lane.
const MASK_DEFAULTS := {
	"protect_sat": 0.22,
	"hue_tol_deg": 45.0,
	"sat_min": 0.18,
	"val_min": 0.02,
	"val_max": 0.98,
	"strength": 1.0,
	"luma_clamp_lo": 0.45,
	"luma_clamp_hi": 1.7,
}

## Reversible non-glTF PBR defaults; identical to AthleteRig's, see its owner decision 1.
const DEFAULT_METALLIC := 0.0
const DEFAULT_ROUGHNESS := 0.85

static var _data: Dictionary = {}
static var _error: int = ERR_UNCONFIGURED
static var _shader: Shader = null


# =========================================================================
# Loading
# =========================================================================

static func _ensure_loaded() -> void:
	if _error != ERR_UNCONFIGURED:
		return
	_error = ERR_CANT_OPEN
	if not FileAccess.file_exists(DATA_PATH):
		push_error("OutfitCatalogue: missing %s (run tools/character/extract_reference_catalogue.py)"
			% DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("OutfitCatalogue: %s is not a JSON object" % DATA_PATH)
		_error = ERR_FILE_CORRUPT
		return
	_data = parsed as Dictionary
	if not _data.has("athletes") or not _data.has("outfits"):
		push_error("OutfitCatalogue: %s has no athletes/outfits" % DATA_PATH)
		_error = ERR_FILE_CORRUPT
		return
	_error = OK


static func load_error() -> int:
	_ensure_loaded()
	return _error


static func source_info() -> Dictionary:
	_ensure_loaded()
	if _error != OK:
		return {"error": _error}
	return {
		"source": _data.get("_source", ""),
		"source_sha256": _data.get("_source_sha256", ""),
		"tool": _data.get("_tool", ""),
		"athletes": athlete_ids().size(),
		"outfit_entries": entries().size(),
		"anchor_primary": _data.get("anchors", {}).get("primary", ""),
		"anchor_trim": _data.get("anchors", {}).get("trim", ""),
	}


# =========================================================================
# Roster
# =========================================================================

## The reference's six ids, in reference order. A special athlete is NOT in this
## list (the roster is the frozen file's, and the slice pins its size): the
## specials are reachable by name through the roster readers below, which consult
## the overlay when the frozen file has no entry.
static func athlete_ids() -> Array:
	_ensure_loaded()
	var out := []
	if _error != OK:
		return out
	for a in (_data["athletes"] as Array):
		out.append(StringName((a as Dictionary)["id"]))
	return out


## The frozen record for one of the six, or a special's record when the id is a
## Godot-only addition (`specials.gd::athlete()`, marked `special_athlete: true`).
## {} for anything else.
static func athlete(athlete_id: StringName) -> Dictionary:
	_ensure_loaded()
	if _error == OK:
		for a in (_data["athletes"] as Array):
			if StringName((a as Dictionary)["id"]) == athlete_id:
				return a as Dictionary
	return Specials.athlete(athlete_id)


static func outfit_ids(athlete_id: StringName) -> Array:
	_ensure_loaded()
	var out := []
	if _error == OK:
		var lists: Dictionary = _data["outfits"]
		if lists.has(String(athlete_id)):
			for e in (lists[String(athlete_id)] as Array):
				out.append(StringName((e as Dictionary)["id"]))
			return out
	return Specials.outfit_ids(athlete_id)


static func has_outfit(athlete_id: StringName, outfit_id: StringName) -> bool:
	return outfit_id in outfit_ids(athlete_id)


static func unlock_key(athlete_id: StringName, outfit_id: StringName) -> String:
	var e := _outfit_record(athlete_id, outfit_id)
	return String(e.get("unlock_key", "")) if not e.is_empty() else ""


## Every (athlete, outfit) pair in reference order. This is the contact-sheet order
## and the order the tests and the renderer iterate.
static func entries() -> Array:
	_ensure_loaded()
	var out := []
	if _error != OK:
		return out
	for a in (_data["athletes"] as Array):
		var aid := StringName((a as Dictionary)["id"])
		for oid in outfit_ids(aid):
			out.append(resolve(aid, oid))
	return out


static func _outfit_record(athlete_id: StringName, outfit_id: StringName) -> Dictionary:
	_ensure_loaded()
	if _error == OK:
		var lists: Dictionary = _data["outfits"]
		if lists.has(String(athlete_id)):
			for e in (lists[String(athlete_id)] as Array):
				if StringName((e as Dictionary)["id"]) == outfit_id:
					return e as Dictionary
	return Specials.outfit_record(athlete_id, outfit_id)


# =========================================================================
# Resolution
# =========================================================================

## Everything the rig needs for one (athlete, outfit), plus the honesty fields.
## Returns {} for an unknown athlete or an outfit that athlete does not own.
static func resolve(athlete_id: StringName, outfit_id: StringName) -> Dictionary:
	var rec := _outfit_record(athlete_id, outfit_id)
	if rec.is_empty():
		return {}
	var ath := athlete(athlete_id)
	var colors: Array = rec["colors"]
	var anchors: Dictionary = _data.get("anchors", {})
	var visual: Dictionary = ath.get("visual", {})
	return {
		"athlete_id": athlete_id,
		"athlete_name": ath.get("name", ""),
		"athlete_role": ath.get("role", ""),
		"outfit_id": outfit_id,
		"unlock_key": rec.get("unlock_key", ""),
		"name_key": rec.get("name_key", ""),
		"is_base": outfit_id == &"base",
		"locked_by_challenge": bool(rec.get("has_challenge", false)),
		# What the shader is actually put into.
		"primary": _hex(String(colors[0])),
		"trim": _hex(String(colors[1])),
		"primary_hex": String(colors[0]),
		"trim_hex": String(colors[1]),
		"anchor_primary": _hex(String(anchors.get("primary", "#22304a"))),
		"anchor_trim": _hex(String(anchors.get("trim", "#ffc94a"))),
		# Honesty fields — see the header.
		"art_dependent": bool(rec.get("has_sprites", false)),
		"not_expressible": _not_expressible(visual),
	}


static func _not_expressible(visual: Dictionary) -> Array:
	var out := []
	for key in ["skin", "hair", "hairStyle", "kitStyle", "frame", "beard", "secondary"]:
		if visual.has(key) and visual[key] != null:
			out.append("%s=%s" % [key, str(visual[key])])
	return out


static func _hex(h: String) -> Color:
	return Color.from_string(h, Color.MAGENTA)


## sRGB components in [0,1], as the shader expects (see the uniform comments there:
## the target/anchor uniforms are deliberately NOT `source_color`-hinted).
static func _srgb_vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


## A ShaderMaterial wired to `source_texture` with the mask defaults applied and the
## anchors at identity (target == anchor), i.e. the atlas as baked. Call
## `apply_to_material()` or `apply()` to put an outfit into it.
static func make_material(source_texture: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader()
	mat.set_shader_parameter("source_tex", source_texture)
	for key in MASK_DEFAULTS:
		mat.set_shader_parameter(key, MASK_DEFAULTS[key])
	mat.set_shader_parameter("pbr_metallic", DEFAULT_METALLIC)
	mat.set_shader_parameter("pbr_roughness", DEFAULT_ROUGHNESS)
	return mat


static func apply_to_material(mat: ShaderMaterial, entry: Dictionary) -> bool:
	if mat == null or entry.is_empty():
		return false
	mat.resource_name = "Outfit_%s" % entry["unlock_key"]
	mat.set_shader_parameter("anchor_primary", _srgb_vec(entry["anchor_primary"]))
	mat.set_shader_parameter("anchor_trim", _srgb_vec(entry["anchor_trim"]))
	mat.set_shader_parameter("target_primary", _srgb_vec(entry["primary"]))
	mat.set_shader_parameter("target_trim", _srgb_vec(entry["trim"]))
	return true


## Puts `rig` (an AthleteRig) into (athlete_id, outfit_id). False for unknown ids or
## a rig that failed to load. Reuses the rig's existing ShaderMaterial when there is
## one, so switching outfits allocates nothing.
static func apply(rig: Node, athlete_id: StringName, outfit_id: StringName) -> bool:
	var entry := resolve(athlete_id, outfit_id)
	if entry.is_empty():
		return false
	if rig == null or not rig.has_method("get_mesh_instance"):
		return false
	# The recolour shader's anchor/mask values were measured against the legacy
	# Volpe atlas. New Meshy athletes keep their baked material until a dedicated
	# mask is authored; silently applying the old atlas would damage their look.
	if rig.has_method("uses_catalogue_recolour") and not rig.uses_catalogue_recolour():
		if rig.has_method("note_catalogue_outfit"):
			rig.note_catalogue_outfit(athlete_id, outfit_id)
		return true
	var mi: MeshInstance3D = rig.get_mesh_instance()
	if mi == null:
		return false
	var mat := mi.get_surface_override_material(0) as ShaderMaterial
	if mat == null or mat.shader != shader():
		var src: Texture2D = null
		if rig.has_method("get_base_material"):
			var bm: StandardMaterial3D = rig.get_base_material()
			if bm != null:
				src = bm.albedo_texture
		if src == null:
			push_error("OutfitCatalogue: rig has no base albedo texture to recolour")
			return false
		mat = make_material(src)
		mi.set_surface_override_material(0, mat)
	if not apply_to_material(mat, entry):
		return false
	if rig.has_method("note_catalogue_outfit"):
		rig.note_catalogue_outfit(athlete_id, outfit_id)
	return true


## What is on the rig right now, read back off the GPU material rather than from a
## cached variable — a test that trusts a cached variable proves nothing.
static func read_back(rig: Node) -> Dictionary:
	if rig == null or not rig.has_method("get_mesh_instance"):
		return {}
	var mi: MeshInstance3D = rig.get_mesh_instance()
	if mi == null:
		return {}
	var mat := mi.get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		return {"material_class": "none"}
	return {
		"material_class": mat.get_class(),
		"resource_name": mat.resource_name,
		"shader_path": mat.shader.resource_path if mat.shader else "",
		"target_primary": mat.get_shader_parameter("target_primary"),
		"target_trim": mat.get_shader_parameter("target_trim"),
		"anchor_primary": mat.get_shader_parameter("anchor_primary"),
		"anchor_trim": mat.get_shader_parameter("anchor_trim"),
		"protect_sat": mat.get_shader_parameter("protect_sat"),
		"metallic": mat.get_shader_parameter("pbr_metallic"),
		"roughness": mat.get_shader_parameter("pbr_roughness"),
		"source_tex": "set" if mat.get_shader_parameter("source_tex") != null else "none",
	}
