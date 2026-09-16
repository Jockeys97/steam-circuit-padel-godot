## athlete_roster_test.gd — headless gate for the roster + outfit catalogue slice.
##
## Contract (same shape as res://tests/athlete_rig_test.gd and res://tests/smoke_test.gd):
## every check prints one machine-readable line
##     ok <name>
##     FAIL <name>: expected <x>, got <y>
## and the run ends with exactly one of
##     PASS <n>/<n>
##     FAIL <n>/<n>
## exiting 0 on PASS and 1 on FAIL, so a runner needs no output parser.
##
## It goes red if: the catalogue does not resolve every athlete and every outfit entry
## the browser reference defines, an unknown id is accepted, an outfit does not move
## the rig's material parameters away from the atlas as baked, the spawn factory hands
## back something that is not a complete animatable rig, or the measured pairwise
## outfit separation drifts across the stated floor in either direction.
##
## Run (verified invocation, from the repo root):
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 \
##     /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
##     --script res://tests/athlete_roster_test.gd
##   flock ... --script res://tests/athlete_roster_test.gd -- --inject-failure
extends SceneTree

const Catalogue := preload("res://src/character/outfit_catalogue.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

## The reference's own roster, as a literal, so a silently truncated parse of
## js/data.js cannot pass by agreeing with itself. Athlete order and outfit order are
## the reference's; `tools/character/extract_reference_catalogue.py --check` proves the
## colours behind them still match.
const EXPECTED_ROSTER := {
	"maestro": ["base", "circuit", "legend", "signature", "mythic"],
	"pantera": ["base", "circuit", "legend", "signature", "mythic"],
	"steamer": ["base", "circuit", "legend", "signature", "mythic"],
	"fiamma": ["base", "circuit", "legend", "signature", "mythic"],
	"oracolo": ["base", "signature", "mythic"],
	"colosso": ["base", "signature", "mythic"],
}
const EXPECTED_ENTRIES := 26
const EXPECTED_BONES := 24

## ---------------------------------------------------------------------------
## THE SEPARATION FLOOR
## ---------------------------------------------------------------------------
## Two outfits of the same athlete are "visibly distinct" here when the mean absolute
## per-channel difference between their two rendered frames, measured over the GARMENT
## MASK — every pixel any outfit change moves at all, derived from the 26 frames
## themselves by tools/character/measure_roster_outfits.py — is at least this many /255.
##
## Why 8.0/255: the repo's own recolour tool (tools/character/recolour_outfits.py)
## already treats 2/255 as the threshold for "this texel changed at all" and 10/255
## euclidean as "this texel changed visibly". 8.0/255 mean-abs per channel is ~13.9
## euclidean over three channels, i.e. above that visible-change threshold, applied as
## an AVERAGE over the whole garment window rather than to a lucky texel. It also sits
## an order of magnitude above the previous slice's failing pair (1.93/255 whole-model)
## and well below its succeeding pair (21.73/255 in the shorts window), so it separates
## the two outcomes that run actually observed.
const SEPARATION_FLOOR := 8.0

## Same-athlete pairs the REFERENCE'S OWN COLOURS cannot push over the floor. These are
## not tuning failures: in the browser build these outfits differ mainly by their six
## dedicated sprite sheets, and their `colors: [a, b]` records are near-identical
## (pantera signature #d20d43/#17151e vs mythic #bd174a/#11131c is 24.3 + 6.6 apart in
## raw sRGB distance). On a rig whose only lever is those two colours they collapse to
## a tint. Raising them would mean inventing an art direction, which is the owner's
## call, not this lane's — so they are quarantined here, in the open, and listed as an
## open owner decision in the evidence file.
##
## The list is asserted to be EXACT: a new pair falling below the floor turns this red,
## and a quarantined pair rising above it turns this red too.
const BELOW_FLOOR_PAIRS := [
	"pantera:signature|pantera:mythic",
	"steamer:signature|steamer:mythic",
]

const MEASUREMENTS := "res://src/character/out/roster_pixel_measurements.json"

var _checks: int = 0
var _failures: int = 0
var _inject_failure: bool = false


func _initialize() -> void:
	_inject_failure = "--inject-failure" in OS.get_cmdline_user_args()

	_check_catalogue()
	_check_resolution()
	_check_rejects_unknown()
	_check_material_differs()
	_check_spawn()
	_check_separation()

	_finish()


# =========================================================================
# 1. The catalogue resolves the whole reference
# =========================================================================

func _check_catalogue() -> void:
	check_eq(Catalogue.load_error(), OK, "catalogue loads reference_catalogue.json")

	var ids: Array = Catalogue.athlete_ids()
	var want_ids := EXPECTED_ROSTER.keys()
	check_eq(_as_strings(ids), want_ids, "catalogue lists the reference's six athletes in order")

	var total := 0
	for athlete_id in want_ids:
		var got: Array = _as_strings(Catalogue.outfit_ids(StringName(athlete_id)))
		check_eq(got, EXPECTED_ROSTER[athlete_id], "outfit_ids('%s') matches the reference" % athlete_id)
		total += got.size()
	check_eq(total, EXPECTED_ENTRIES, "the reference defines %d outfit entries" % EXPECTED_ENTRIES)
	check_eq(Catalogue.entries().size(), EXPECTED_ENTRIES, "entries() is flat and complete")

	var info: Dictionary = Catalogue.source_info()
	check_eq(info.get("source", ""), "js/data.js", "catalogue records its reference source")
	check_true(String(info.get("source_sha256", "")).length() == 64,
		"catalogue records the reference's sha256")


func _check_resolution() -> void:
	var seen_keys := {}
	var bad := 0
	for athlete_id in EXPECTED_ROSTER:
		for outfit_id in EXPECTED_ROSTER[athlete_id]:
			var e: Dictionary = Catalogue.resolve(StringName(athlete_id), StringName(outfit_id))
			if e.is_empty():
				bad += 1
				continue
			seen_keys[e["unlock_key"]] = true
			# Every entry must carry a usable pair of 3D colours; Color.from_string()
			# falls back to magenta, so a bad hex would show up as exactly magenta.
			if e["primary"] == Color.MAGENTA or e["trim"] == Color.MAGENTA:
				bad += 1
			if String(e["name_key"]) == "":
				bad += 1
			if e["anchor_primary"] == e["anchor_trim"]:
				bad += 1
	check_eq(bad, 0, "every reference outfit entry resolves to a usable colour pair")
	check_eq(seen_keys.size(), EXPECTED_ENTRIES, "every entry has a distinct unlock key")

	# Base outfits are the reference's own kit colours and carry no sprite sheets;
	# unlockables do. That is the fact that makes them art-dependent, so it is asserted.
	var base_art: bool = Catalogue.resolve(&"pantera", &"base")["art_dependent"]
	var unlock_art: bool = Catalogue.resolve(&"pantera", &"mythic")["art_dependent"]
	check_eq(base_art, false, "the base outfit is colour-only in the reference")
	check_eq(unlock_art, true, "an unlockable outfit is sprite-backed in the reference")
	check_true(Catalogue.resolve(&"pantera", &"mythic")["not_expressible"].size() > 0,
		"resolve() reports the visual fields this rig cannot express")


func _check_rejects_unknown() -> void:
	check_true(Catalogue.resolve(&"no-such-athlete", &"base").is_empty(),
		"an unknown athlete id resolves to nothing")
	check_true(Catalogue.resolve(&"pantera", &"no-such-outfit").is_empty(),
		"an unknown outfit id resolves to nothing")
	# "circuit" exists, but not for oracolo — a per-athlete lookup, not a global one.
	check_true(Catalogue.resolve(&"oracolo", &"circuit").is_empty(),
		"an outfit another athlete owns is rejected for this one")
	check_true(not Catalogue.has_outfit(&"oracolo", &"circuit"), "has_outfit() agrees")
	check_true(Catalogue.outfit_ids(&"no-such-athlete").is_empty(),
		"outfit_ids() of an unknown athlete is empty")
	check_true(AthleteSpawn.make(&"no-such-athlete", &"base") == null,
		"spawning an unknown athlete returns null")
	check_true(AthleteSpawn.make(&"pantera", &"no-such-outfit") == null,
		"spawning an unknown outfit returns null")
	var lenient: Node3D = AthleteSpawn.make(&"pantera", &"no-such-outfit", {"strict": false})
	check_true(lenient != null, "strict=false falls back instead of failing")
	if lenient != null:
		check_eq(lenient.get_catalogue_outfit().get("outfit_id", &""), &"base",
			"the fallback is that athlete's base outfit")
		lenient.free()


# =========================================================================
# 2. Each entry actually moves the rig's material parameters
# =========================================================================

func _check_material_differs() -> void:
	var rig: Node3D = AthleteSpawn.make(&"maestro", &"base")
	if rig == null:
		check_true(false, "a rig could be spawned for the material check")
		return
	root.add_child(rig)

	var baked_primary := Catalogue.resolve(&"maestro", &"base")["anchor_primary"] as Color
	var baked_trim := Catalogue.resolve(&"maestro", &"base")["anchor_trim"] as Color

	var signatures := {}
	var moved := 0
	var applied := 0
	for athlete_id in EXPECTED_ROSTER:
		for outfit_id in EXPECTED_ROSTER[athlete_id]:
			if not AthleteSpawn.set_outfit(rig, StringName(athlete_id), StringName(outfit_id)):
				continue
			applied += 1
			var st: Dictionary = Catalogue.read_back(rig)
			var tp: Vector3 = st["target_primary"]
			var tt: Vector3 = st["target_trim"]
			signatures["%s|%s" % [str(tp), str(tt)]] = true
			# "Differs from the base" means: the shader is no longer asked to paint the
			# atlas as baked. Both anchors must have moved off their source colour.
			if tp.distance_to(_vec(baked_primary)) > 0.01 and tt.distance_to(_vec(baked_trim)) > 0.01:
				moved += 1
			if _inject_failure:
				moved = 0

	check_eq(applied, EXPECTED_ENTRIES, "every catalogue entry applies to a live rig")
	check_eq(moved, EXPECTED_ENTRIES,
		"every entry moves BOTH garment anchors off the atlas as baked")
	check_eq(signatures.size(), EXPECTED_ENTRIES,
		"the %d entries produce %d distinct material parameter sets"
			% [EXPECTED_ENTRIES, EXPECTED_ENTRIES])

	var st_final: Dictionary = Catalogue.read_back(rig)
	check_eq(st_final.get("material_class", ""), "ShaderMaterial",
		"outfits go through a per-instance ShaderMaterial override")
	check_eq(st_final.get("source_tex", ""), "set",
		"the override still samples the GLB's own baked atlas")
	check_eq(st_final.get("shader_path", ""), Catalogue.SHADER_PATH,
		"the override runs the outfit recolour shader")
	check_true(float(st_final.get("protect_sat", -1.0)) == Catalogue.MASK_DEFAULTS["protect_sat"],
		"the measured fur guard is carried through unchanged")

	rig.queue_free()


# =========================================================================
# 3. The spawn seam
# =========================================================================

func _check_spawn() -> void:
	var rig: Node3D = AthleteSpawn.make(&"colosso", &"mythic", {
		"position": Vector3(1.25, 0.0, -2.0),
		"facing_degrees": 135.0,
		"locomotion": &"run",
		"speed_scale": 1.5,
	})
	check_true(rig != null, "AthleteSpawn.make() returns a rig")
	if rig == null:
		return
	root.add_child(rig)

	var d: Dictionary = AthleteSpawn.describe(rig)
	check_eq(d["load_error"], OK, "the spawned rig loaded cleanly")
	check_eq(d["joints"], EXPECTED_BONES, "the spawned rig has the expected joint count")
	check_eq(d["surfaces"], 1, "the spawned rig has the GLB's single surface")
	check_eq(d["position"], Vector3(1.25, 0.0, -2.0), "opts.position is applied")
	check_eq(d["facing_degrees"], 135.0, "opts.facing_degrees is applied")
	check_eq(d["catalogue_outfit"].get("athlete_id", &""), &"colosso", "the rig records its athlete")
	check_eq(d["catalogue_outfit"].get("outfit_id", &""), &"mythic", "the rig records its outfit")

	# "Playable animation state": the requested locomotion is the clip that is running,
	# all three locomotion states are registered, and the strokes are there too.
	check_eq(d["locomotion"], &"run", "opts.locomotion is the live locomotion state")
	check_eq(_as_strings(d["locomotion_states"]), ["idle", "walk", "run"],
		"all three locomotion clips are registered")
	check_eq(_as_strings(d["strokes"]).size(), 4, "all four padel strokes are registered")
	var pose: Dictionary = rig.get_pose()
	check_eq(pose["clip"], "run", "the animation player is actually playing the run clip")
	check_true(float(rig.get_clip_length(&"run")) > 0.0, "the running clip has a real length")
	check_eq(pose["bones"].size(), EXPECTED_BONES, "the pose readout covers every joint")

	# The rig must animate, not just report a clip name.
	check_true(_max_motion(rig, &"run") > 0.01, "the spawned rig's run clip moves the skeleton")
	check_true(rig.play_stroke(&"drive"), "a spawned rig can play a stroke")
	check_true(rig.is_stroking(), "the stroke is in flight")

	# Menus.
	check_eq(_as_strings(AthleteSpawn.ids()), EXPECTED_ROSTER.keys(), "ids() feeds an athlete menu")
	check_eq(_as_strings(AthleteSpawn.outfit_ids(&"colosso")), EXPECTED_ROSTER["colosso"],
		"outfit_ids() feeds an outfit menu")
	check_eq(AthleteSpawn.display_name(&"colosso"), "IL COLOSSO", "display_name() is the reference's")
	check_eq(AthleteSpawn.outfit_name_key(&"colosso", &"mythic"), "outfitMythicColosso",
		"outfit_name_key() hands the menu an i18n key, not a literal")
	check_true(AthleteSpawn.outfit_is_locked_by_default(&"colosso", &"mythic"),
		"an unlockable outfit is reported as challenge-gated")
	check_true(not AthleteSpawn.outfit_is_locked_by_default(&"colosso", &"base"),
		"a base outfit is not challenge-gated")

	# Switching outfit in place must not disturb the animation state.
	check_true(AthleteSpawn.set_outfit(rig, &"colosso", &"base"), "set_outfit() on a live rig")
	check_eq(rig.get_pose()["locomotion"], &"run", "switching outfit leaves locomotion alone")

	rig.queue_free()


# =========================================================================
# 4. The measured separation floor
# =========================================================================

func _check_separation() -> void:
	if not FileAccess.file_exists(MEASUREMENTS):
		check_true(false, "the rendered pixel measurements exist (%s)" % MEASUREMENTS)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MEASUREMENTS))
	if typeof(parsed) != TYPE_DICTIONARY:
		check_true(false, "the rendered pixel measurements parse")
		return
	var m: Dictionary = parsed

	check_eq(float(m.get("floor", -1.0)), SEPARATION_FLOOR,
		"the measurement run used this test's floor")
	check_eq(int(m.get("outfit_frames", -1)), EXPECTED_ENTRIES,
		"one rendered frame per reference outfit entry was measured")

	var pairs: Array = m.get("same_athlete_pairs", [])
	var expected_pairs := 0
	for athlete_id in EXPECTED_ROSTER:
		var n: int = EXPECTED_ROSTER[athlete_id].size()
		expected_pairs += n * (n - 1) / 2
	check_eq(pairs.size(), expected_pairs, "every same-athlete outfit pair was measured")

	var below := []
	var worst_ok := INF
	var best_below := -INF
	for p in pairs:
		var key: String = "%s|%s" % [p["a"], p["b"]]
		var value := float(p["garment_mask_mean_abs_255"])
		if _inject_failure:
			value = 0.0
		if value < SEPARATION_FLOOR:
			below.append(key)
			best_below = maxf(best_below, value)
		else:
			worst_ok = minf(worst_ok, value)
	below.sort()
	var quarantine := BELOW_FLOOR_PAIRS.duplicate()
	quarantine.sort()

	check_eq(below, quarantine,
		"exactly the documented pairs fall below the %.1f/255 floor" % SEPARATION_FLOOR)
	check_true(worst_ok >= SEPARATION_FLOOR,
		"min separation outside the quarantine is >= %.1f/255 (measured %.3f)"
			% [SEPARATION_FLOOR, worst_ok])
	# The quarantined pairs must still be honestly reported as a tint, not silently zero.
	check_true(best_below < SEPARATION_FLOOR,
		"the quarantined pairs are still measured, at %.3f/255" % best_below)
	check_eq(String(m.get("floor_metric", "")), "garment_mask_mean_abs_255",
		"the floor is stated against the garment mask, not a cherry-picked window")
	check_true(float(m.get("whole_model_min_255", -1.0)) >= 0.0,
		"a whole-model delta is reported alongside the garment mask")
	check_true(float(m.get("cross_athlete_min_255", -1.0)) >= 0.0,
		"cross-athlete pairs are measured too (informational; see the evidence file)")


# =========================================================================
# Helpers
# =========================================================================

func _vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _as_strings(a) -> Array:
	var out := []
	for v in a:
		out.append(String(v))
	return out


## Largest per-bone quaternion-component swing across 8 samples of `clip`.
func _max_motion(rig: Node3D, clip: StringName) -> float:
	var sk: Skeleton3D = rig.get_skeleton()
	var length: float = rig.get_clip_length(clip)
	if sk == null or length <= 0.0:
		return -1.0
	rig.play_clip(clip)
	rig.sample_at(0.0)
	var base := []
	for i in sk.get_bone_count():
		base.append(sk.get_bone_pose_rotation(i))
	var worst := 0.0
	for step in range(1, 9):
		rig.sample_at(length * float(step) / 8.0)
		for i in sk.get_bone_count():
			var q: Quaternion = sk.get_bone_pose_rotation(i)
			var b: Quaternion = base[i]
			worst = maxf(worst, maxf(
				maxf(absf(q.x - b.x), absf(q.y - b.y)),
				maxf(absf(q.z - b.z), absf(q.w - b.w))))
	return worst


func check_eq(got, expected, name: String) -> void:
	_checks += 1
	if got == expected:
		print("ok %s" % name)
	else:
		_failures += 1
		var line := "FAIL %s: expected %s, got %s" % [name, str(expected), str(got)]
		print(line)
		printerr(line)


func check_true(got: bool, name: String) -> void:
	check_eq(got, true, name)


func _finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		var line := "FAIL %d/%d" % [_checks - _failures, _checks]
		print(line)
		printerr(line)
		quit(1)
