extends RefCounted
class_name AthleteSpawn
## AthleteSpawn — the one call the match scene makes to get an athlete.
##
## ===========================================================================
## INTEGRATION RECIPE  (this is the whole thing; you do not need to read below)
## ===========================================================================
## In the match scene, where a player is created:
##
##     const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
##     ...
##     var rig := AthleteSpawn.make(&"pantera", &"legend", {
##         "position": Vector3(-1.5, 0.0, 4.0),
##         "facing_degrees": 180.0,
##     })
##     add_child(rig)                      # rig is a configured, animatable Node3D
##
## Then drive it each frame / each event with the rig's own API:
##
##     rig.play_locomotion(&"run")         # &"idle" | &"walk" | &"run"
##     rig.play_stroke(&"drive")           # one-shot; locomotion resumes by itself
##     rig.face_towards(ball_position)
##     rig.set_locomotion_speed_scale(speed / WALK_SPEED)
##
## For menus:
##
##     AthleteSpawn.ids()                  # [&"maestro", ..., &"colosso"] reference order
##     AthleteSpawn.outfit_ids(&"pantera") # [&"base", &"circuit", ...] reference order
##     AthleteSpawn.display_name(&"pantera")             # "LA PANTERA"
##     AthleteSpawn.outfit_name_key(&"pantera", &"legend")  # "outfitLegend" for i18n
##
## To change outfit on an already-spawned rig (no reallocation, no respawn):
##
##     AthleteSpawn.set_outfit(rig, &"pantera", &"mythic")
##
## `make()` returns `null` — never a half-built node — for an unknown athlete id, an
## outfit that athlete does not own, or a rig whose GLBs failed to load. Pass
## `{"strict": false}` to fall back to that athlete's `base` outfit instead of
## failing on an unknown outfit id.
##
## ===========================================================================
## WHAT YOU GET BACK
## ===========================================================================
## A fresh instance of `res://src/character/AthleteRig.tscn`: one Node3D with the
## selected athlete's Meshy skeleton under it, locomotion clips and four authored
## padel strokes, and surface override 0 already carrying the outfit shader for
## (athlete_id, outfit_id). It is ready the instant `make()` returns — the
## rig builds itself on first use, not on its first frame, so you may query it before
## `add_child()` and before any frame has been drawn.
##
## Each call builds its own rig from the selected GLB (plus the two Volpe companion
## files for the fallback). That cost is paid at scene setup; do NOT call `make()`
## per frame.
##
## ===========================================================================
## LIMITS YOU SHOULD KNOW ABOUT AT THE CALL SITE
## ===========================================================================
## * Athletes without a registered 3D asset still use the Volpe placeholder model.
##   Colosso is the first opt-in real Meshy model. Body frame, skin, hair and the
##   per-outfit sprite artwork of the browser build remain separate art work.
## * The rig has no collision shape, no hitbox and no root motion. Movement is the
##   caller's; this seam only poses and colours.
## * `opts` is applied in a fixed order: position, facing, outfit, locomotion, speed.

const RigScene := preload("res://src/character/AthleteRig.tscn")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")

## Reference order, so a menu that just walks this list matches the browser build.
const DEFAULT_OUTFIT := &"base"


# =========================================================================
# Menus
# =========================================================================

static func ids() -> Array:
	return Catalogue.athlete_ids()


static func outfit_ids(athlete_id: StringName) -> Array:
	return Catalogue.outfit_ids(athlete_id)


static func display_name(athlete_id: StringName) -> String:
	return String(Catalogue.athlete(athlete_id).get("name", ""))


## The reference's i18n key for the outfit's display name ("outfitLegend", ...), so a
## menu never has to hard-code a label. "" for an unknown pair.
static func outfit_name_key(athlete_id: StringName, outfit_id: StringName) -> String:
	var e := Catalogue.resolve(athlete_id, outfit_id)
	return String(e.get("name_key", "")) if not e.is_empty() else ""


## True when the browser build gates this outfit behind a career challenge. The match
## scene does not need this; the outfit-select menu does.
static func outfit_is_locked_by_default(athlete_id: StringName, outfit_id: StringName) -> bool:
	var e := Catalogue.resolve(athlete_id, outfit_id)
	return bool(e.get("locked_by_challenge", false)) if not e.is_empty() else false


static func is_known(athlete_id: StringName, outfit_id: StringName = DEFAULT_OUTFIT) -> bool:
	return Catalogue.has_outfit(athlete_id, outfit_id)


# =========================================================================
# The factory
# =========================================================================

## Builds and configures one athlete. See the recipe in the header.
##
## opts (all optional):
##   "position"        Vector3   where to put it (default: origin)
##   "facing_degrees"  float     yaw, 0 = +Z, CCW about +Y (default: 0)
##   "locomotion"      StringName  &"idle" | &"walk" | &"run" (default: &"idle")
##   "speed_scale"     float     animation speed multiplier (default: 1.0)
##   "glb_pbr"         bool      render the GLB's own metallic=1 (default: false)
##   "strict"          bool      false = fall back to `base` on an unknown outfit id
##   "name"            String    node name, handy when debugging a scene tree
static func make(athlete_id: StringName, outfit_id: StringName = DEFAULT_OUTFIT,
		opts: Dictionary = {}) -> Node3D:
	var strict := bool(opts.get("strict", true))
	if not Catalogue.has_outfit(athlete_id, outfit_id):
		if strict or not Catalogue.has_outfit(athlete_id, DEFAULT_OUTFIT):
			push_error("AthleteSpawn.make: unknown athlete/outfit '%s/%s'" % [athlete_id, outfit_id])
			return null
		outfit_id = DEFAULT_OUTFIT

	var rig: Node3D = RigScene.instantiate()
	# Select the concrete mesh before get_load_error() builds the rig. Existing
	# athletes keep the Volpe fallback; currently only Colosso opts into its own
	# export (source model: solar-titan, see docs/art/roster-3d.json).
	if not rig.set_athlete_asset(athlete_id):
		push_error("AthleteSpawn.make: athlete asset '%s' was already built or unavailable" % athlete_id)
		rig.free()
		return null
	if rig.get_load_error() != OK:
		push_error("AthleteSpawn.make: rig failed to load (error %d)" % rig.get_load_error())
		rig.free()
		return null

	rig.name = String(opts.get("name", "Athlete_%s_%s" % [athlete_id, outfit_id]))
	rig.position = opts.get("position", Vector3.ZERO)
	rig.set_facing_degrees(float(opts.get("facing_degrees", 0.0)))

	if bool(opts.get("glb_pbr", false)):
		rig.use_glb_pbr(true)
	if not Catalogue.apply(rig, athlete_id, outfit_id):
		push_error("AthleteSpawn.make: could not apply outfit '%s/%s'" % [athlete_id, outfit_id])
		rig.free()
		return null

	var locomotion := StringName(opts.get("locomotion", &"idle"))
	if not rig.play_locomotion(locomotion):
		push_warning("AthleteSpawn.make: unknown locomotion '%s'; staying idle" % locomotion)
		rig.play_locomotion(&"idle")
	rig.set_locomotion_speed_scale(float(opts.get("speed_scale", 1.0)))
	return rig


## Re-colours an already-spawned rig in place. Cheaper than respawning: it writes four
## shader uniforms and allocates nothing. False for unknown ids or a foreign node.
static func set_outfit(rig: Node3D, athlete_id: StringName, outfit_id: StringName) -> bool:
	return Catalogue.apply(rig, athlete_id, outfit_id)


## What a spawned rig actually is, read back off the node and its GPU material rather
## than from anything this factory remembers. Intended for tests and for the evidence
## dump, not for the hot path.
static func describe(rig: Node3D) -> Dictionary:
	if rig == null:
		return {}
	var skel: Skeleton3D = rig.get_skeleton()
	return {
		"name": rig.name,
		"athlete_asset": rig.get_athlete_asset(),
		"load_error": rig.get_load_error(),
		"joints": skel.get_bone_count() if skel != null else -1,
		"triangles": rig.get_triangle_count(),
		"surfaces": rig.get_surface_count(),
		"position": rig.position,
		"facing_degrees": rig.get_facing_degrees(),
		"locomotion": rig.get_locomotion_state(),
		"locomotion_states": rig.get_locomotion_states(),
		"strokes": rig.get_stroke_names(),
		"catalogue_outfit": rig.get_catalogue_outfit(),
		"material": Catalogue.read_back(rig),
	}
