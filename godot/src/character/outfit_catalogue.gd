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
##     OutfitCatalogue.profile(athlete_id) -> Dictionary  # the athlete's masked profile, or {}
##     OutfitCatalogue.has_profile(athlete_id) -> bool
##
##   PROVENANCE
##     OutfitCatalogue.load_error() -> int               # OK (0) when the JSON parsed
##     OutfitCatalogue.source_info() -> Dictionary
##
## ===========================================================================
## WHERE THE NUMBERS COME FROM
## ===========================================================================
## The legacy palette is extracted from `res://assets/athletes/
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
## per-outfit tuning exists in the legacy lane. Dedicated profiles below have
## explicitly authored region targets based on the outfit artwork.
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
## TWO PATHS, ONE DOOR (`apply`)
## The colour-inferred shader above only ever fit the Volpe placeholder. A Meshy
## human needs a real garment mask, because their skin is as saturated as their kit.
## So `apply()` now has three outcomes, in this order:
##   1. the athlete has an entry in `OUTFIT_PROFILES` (today: fiamma only) -> the
##      masked path: a region mask authored from the skeleton gates the recolour and
##      `base` hands the surface back to the rig's own material, untouched;
##   2. otherwise the rig recolours itself (Volpe) -> the shader above, unchanged;
##   3. otherwise a dedicated athlete with no profile -> the selection is recorded
##      and the rig is left exactly as it looks, which is the pre-existing behaviour.
## Everything `resolve()` returns is identical on all three paths; the catalogue's
## ids, unlocks and entries are untouched by this.
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
const REGION_SHADER_PATH := "res://src/character/outfit_region_recolour.gdshader"

## ATHLETE PROFILES — the masked path, for athletes whose body is not the Volpe fox.
##
## One entry per athlete, keyed by roster id, and each entry owns:
##   mask      the explicit UV region mask (R torso, G hip, B foot, A coverage),
##             authored from the skeleton by tools/character/build_fiamma_outfit_mask.py;
##   shader    the shader that reads it;
##   anchor_a  the baked atlas's family A, measured *inside* the mask (lime kit);
##   anchor_b  the baked atlas's family B, measured inside the mask (navy trim);
##   outfits   outfit id -> the six targets, one per (region x family). An outfit
##             absent from this table is `base`: the rig restores its own material.
##
## WHERE THE NUMBERS COME FROM, AND WHAT IS A CHOICE
##   * `anchor_a` / `anchor_b` are MEASURED, not chosen: they are the modal colours
##     of the two families inside the garment regions, reported by the mask tool in
##     `docs/agent-work/outfits-3d/evidence/fiamma-mask-report.json` (#b8e828 and
##     #081838; see the reproducible mask tool's report).
##   * `circuit` and `signature` are the reference's own two colours for those
##     entries (`js/data.js` ATHLETE_OUTFITS), placed on the garment piece the 2D
##     sprite paints them on. Circuit: blue kit, pale-cyan trim. Signature: petrol
##     kit, lime trim - the "flame" accents of the sprite live in the hem and the
##     shoe trim, which are exactly the two lower-garment slots.
##   * `legend` is the one entry the reference cannot express: its record is gold
##     (#f2a72b) plus ivory (#fff0a7) and the 2D card is black/ivory/gold. The black
##     is the user-approved third colour for this outfit and is marked `port_only`
##     below, so nobody later mistakes it for a reference value.
##   * `base` is absent by design. Restoring the rig's own material is the only way
##     for base to be parameter-equivalent to the original rather than merely close.
##
## Athletes NOT listed here are untouched: the masked path is opt-in per athlete, and
## a dedicated athlete without a profile keeps its baked look and says so.
const OUTFIT_PROFILES := {
	&"fiamma": {
		"mask": "res://assets/athletes/outfits/fiamma/fiamma_region_mask.png",
		"shader": REGION_SHADER_PATH,
		"anchor_a": "#b8e828",
		"anchor_b": "#081838",
		"mask_sha256_prefix": "f176618b03f92216",
		"outfits": {
			# Reference colors: ["#326dff", "#c8ecff"]. Blue kit, pale-cyan trim; the
			# skirt stays the navy the model already wears, as the sprite does.
			&"circuit": {
				"torso_a": "#326dff", "torso_b": "#c8ecff",
				"hip_a": "#c8ecff", "hip_b": "#1b2c52",
				"foot_a": "#2f66e0", "foot_b": "#c8ecff",
			},
			# Reference colors: ["#f2a72b", "#fff0a7"]. Gold trim, ivory accents, and
			# the approved charcoal that the two-colour record has nowhere to put.
			&"legend": {
				"torso_a": "#1b1d22", "torso_b": "#f2a72b",
				"hip_a": "#fff0a7", "hip_b": "#23252b",
				"foot_a": "#e6a92b", "foot_b": "#fff0a7",
				"port_only": ["torso_a", "hip_b"],
			},
			# Reference colors: ["#087a75", "#adf51e"]. Petrol kit, lime flame accents.
			&"signature": {
				"torso_a": "#0b6b62", "torso_b": "#adf51e",
				"hip_a": "#adf51e", "hip_b": "#0f5f57",
				"foot_a": "#0b6b62", "foot_b": "#adf51e",
			},
		},
	},
}

## The six uniform names a profile entry fills, in (region, family) order. Named so
## the shader and the table cannot drift apart silently.
const PROFILE_TARGET_UNIFORMS := {
	"torso_a": "target_torso_a", "torso_b": "target_torso_b",
	"hip_a": "target_hip_a", "hip_b": "target_hip_b",
	"foot_a": "target_foot_a", "foot_b": "target_foot_b",
}

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
static var _region_shader: Shader = null
static var _mask_cache: Dictionary = {}     # mask path -> Texture2D (immutable, shared)


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
	if has_profile(athlete_id) and rig.has_method("get_athlete_asset") and rig.get_athlete_asset() != athlete_id:
		return false
	# PATH 1 — the athlete has a mask and a profile. Fiamma, today.
	if has_profile(athlete_id):
		return _apply_profile(rig, athlete_id, entry)
	# PATH 3 — a dedicated athlete with no mask yet. Its baked material is left
	# exactly as it looks: applying the Volpe atlas to a different texture would
	# visibly corrupt it, and that is still the honest answer for every athlete
	# that has not been authored a profile. The selection is recorded either way.
	# The recolour shader's anchor/mask values were measured against the legacy
	# Volpe atlas. New Meshy athletes keep their baked material until a dedicated
	# mask is authored; silently applying the old atlas would damage their look.
	if rig.has_method("uses_catalogue_recolour") and not rig.uses_catalogue_recolour():
		if rig.has_method("note_catalogue_outfit"):
			rig.note_catalogue_outfit(athlete_id, outfit_id)
		return true
	# PATH 2 — Volpe, through the colour-inferred shader, unchanged.
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


# =========================================================================
# The masked path (athlete profiles)
# =========================================================================

## The profile an athlete's masked path is driven by, or {} when it has none.
## A copy, so a caller cannot edit the table through the returned dictionary.
static func profile(athlete_id: StringName) -> Dictionary:
	if not OUTFIT_PROFILES.has(athlete_id):
		return {}
	return (OUTFIT_PROFILES[athlete_id] as Dictionary).duplicate(true)


static func has_profile(athlete_id: StringName) -> bool:
	return OUTFIT_PROFILES.has(athlete_id)


static func region_shader() -> Shader:
	if _region_shader == null:
		_region_shader = load(REGION_SHADER_PATH) as Shader
	return _region_shader


## The mask texture a profile names, or null when the file is missing.
##
## Read straight off disk with FileAccess + Image, the same way AthleteRig loads an
## outfit texture: the mask is a data asset, so it must not depend on Godot's
## importer having run (a headless `--script` run never imports, and a mask that only
## loads after someone opens the editor is a mask that silently does nothing).
## Mipmaps are generated here so the shader's `filter_linear_mipmap` hint has them.
##
## Cached by path: the mask is immutable and shared by every rig, so two Fiamma rigs
## cost one texture, not two. The *materials* stay per-rig (see `_apply_profile`).
static func profile_mask(athlete_id: StringName) -> Texture2D:
	var prof := profile(athlete_id)
	if prof.is_empty():
		return null
	var path := String(prof.get("mask", ""))
	if path == "":
		return null
	if _mask_cache.has(path):
		return _mask_cache[path]
	# Exported games retain imported resources, not necessarily the source PNG.
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			_mask_cache[path] = imported
			return imported
	if not FileAccess.file_exists(path):
		push_error("OutfitCatalogue: profile mask missing: %s" % path)
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		push_error("OutfitCatalogue: profile mask is not a readable PNG: %s" % path)
		return null
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	tex.resource_path = path
	_mask_cache[path] = tex
	return tex


## The six targets one outfit puts on the profile's shader, keyed by the uniform
## names in PROFILE_TARGET_UNIFORMS. `{}` for `base` (which restores instead) and for
## an outfit the profile does not list.
static func profile_targets(athlete_id: StringName, outfit_id: StringName) -> Dictionary:
	var prof := profile(athlete_id)
	if prof.is_empty():
		return {}
	var outfits: Dictionary = prof.get("outfits", {})
	if not outfits.has(outfit_id):
		return {}
	var record: Dictionary = outfits[outfit_id]
	var out := {}
	for key in PROFILE_TARGET_UNIFORMS:
		var hex := String(record.get(key, ""))
		if hex == "":
			push_error("OutfitCatalogue: profile '%s/%s' is missing '%s'" % [athlete_id, outfit_id, key])
			return {}
		out[PROFILE_TARGET_UNIFORMS[key]] = _hex(hex)
	return out


## Which of an outfit's targets are port additions rather than reference colours.
## Reported so a reviewer can tell the two apart without reading this file's history.
static func profile_port_only(athlete_id: StringName, outfit_id: StringName) -> Array:
	var prof := profile(athlete_id)
	var outfits: Dictionary = prof.get("outfits", {})
	if not outfits.has(outfit_id):
		return []
	return (outfits[outfit_id] as Dictionary).get("port_only", []).duplicate()


static func _apply_profile(rig: Node, athlete_id: StringName, entry: Dictionary) -> bool:
	var outfit_id: StringName = entry["outfit_id"]
	# `base` is not a target set: it is the absence of one. Handing surface 0 back to
	# the rig's own material is what makes base round-trip exactly, and the masked
	# material stays cached on the rig so switching back reuses it.
	if outfit_id == &"base" or profile_targets(athlete_id, outfit_id).is_empty():
		if not rig.has_method("restore_base_surface") or not rig.restore_base_surface():
			return false
		if rig.has_method("note_catalogue_outfit"):
			rig.note_catalogue_outfit(athlete_id, outfit_id)
		return true
	var mask := profile_mask(athlete_id)
	if mask == null:
		return false
	var targets := profile_targets(athlete_id, outfit_id)
	if targets.is_empty():
		push_error("OutfitCatalogue: profile has no targets for '%s/%s'" % [athlete_id, outfit_id])
		return false
	var mi: MeshInstance3D = rig.get_mesh_instance()
	if mi == null:
		return false
	var mat: ShaderMaterial = null
	if rig.has_method("get_catalogue_surface"):
		mat = rig.get_catalogue_surface()
	if mat == null or mat.shader != region_shader():
		var src: Texture2D = null
		if rig.has_method("get_base_material"):
			var bm: StandardMaterial3D = rig.get_base_material()
			if bm != null:
				src = bm.albedo_texture
		if src == null:
			push_error("OutfitCatalogue: rig has no base albedo texture to mask")
			return false
		mat = ShaderMaterial.new()
		mat.shader = region_shader()
		mat.set_shader_parameter("source_tex", src)
		mat.set_shader_parameter("region_mask", mask)
		var prof := profile(athlete_id)
		mat.set_shader_parameter("anchor_a", _srgb_vec(_hex(String(prof["anchor_a"]))))
		mat.set_shader_parameter("anchor_b", _srgb_vec(_hex(String(prof["anchor_b"]))))
		mat.set_shader_parameter("pbr_metallic", DEFAULT_METALLIC)
		mat.set_shader_parameter("pbr_roughness", DEFAULT_ROUGHNESS)
		var original: StandardMaterial3D = rig.get_base_material()
		mat.set_shader_parameter("normal_enabled", original.normal_enabled and original.normal_texture != null)
		mat.set_shader_parameter("normal_tex", original.normal_texture)
		mat.set_shader_parameter("normal_scale", original.normal_scale)
		mat.set_shader_parameter("roughness_enabled", original.roughness_texture != null)
		mat.set_shader_parameter("roughness_tex", original.roughness_texture)
		mat.set_shader_parameter("roughness_channel", int(original.roughness_texture_channel))
	mat.resource_name = "Outfit_%s" % entry["unlock_key"]
	for uniform in targets:
		mat.set_shader_parameter(uniform, _srgb_vec(targets[uniform]))
	# Reinstalls the cached material if something else (a previous `base`) owns the
	# surface right now. One material per rig, no matter how often it is switched.
	if rig.has_method("set_catalogue_surface"):
		rig.set_catalogue_surface(mat)
	else:
		mi.set_surface_override_material(0, mat)
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
	var catalogue_outfit: Dictionary = {}
	if rig.has_method("get_catalogue_outfit"):
		catalogue_outfit = rig.get_catalogue_outfit()
	var profile_id := StringName(catalogue_outfit.get("athlete_id", &""))
	var selected_id := StringName(catalogue_outfit.get("outfit_id", &"base"))
	var mat := mi.get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		# No shader on the surface: either a rig that was never put into an outfit, or
		# `base` on a profiled athlete, where the rig's own StandardMaterial3D is the
		# correct answer rather than a missing one.
		var plain := mi.get_surface_override_material(0)
		return {
			"material_class": plain.get_class() if plain != null else "none",
			"resource_name": plain.resource_name if plain != null else "",
			"shader_path": "",
			"profile": String(profile_id) if has_profile(profile_id) else "",
			"mask": "none",
			"is_base_surface": rig.is_base_surface() if rig.has_method("is_base_surface") else false,
			"visual_status": "base" if selected_id == &"base" else "unsupported_preserved_base",
		}
	return {
		"material_class": mat.get_class(),
		"resource_name": mat.resource_name,
		"shader_path": mat.shader.resource_path if mat.shader else "",
		"profile": String(profile_id) if has_profile(profile_id) else "",
		"mask": "set" if mat.get_shader_parameter("region_mask") != null else "none",
		"is_base_surface": false,
		"visual_status": "applied",
		"target_primary": mat.get_shader_parameter("target_primary"),
		"target_trim": mat.get_shader_parameter("target_trim"),
		"anchor_primary": mat.get_shader_parameter("anchor_primary"),
		"anchor_trim": mat.get_shader_parameter("anchor_trim"),
		"protect_sat": mat.get_shader_parameter("protect_sat"),
		"metallic": mat.get_shader_parameter("pbr_metallic"),
		"roughness": mat.get_shader_parameter("pbr_roughness"),
		"source_tex": "set" if mat.get_shader_parameter("source_tex") != null else "none",
	}
