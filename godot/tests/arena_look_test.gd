## arena_look_test.gd — the LOOK lane's suite: the per-arena sky/atmosphere/lighting rig is
## REAL, per-arena, Compatibility-legal, a no-op for the frozen nine, and the ground-texture
## slot is wired with the kit's own fallback discipline.
##
##   flock -w 900 /tmp/padel-godot.lock /Applications/Godot.app/Contents/MacOS/Godot \
##     --headless --path godot/ --script res://tests/arena_look_test.gd
##
## WHAT IT PROVES, in five parts:
##
##   1. THE RIG TABLE IS COMPLETE AND IN RANGE. `arena_look.gd::LOOKS` covers exactly the five
##      world arenas (no frozen id, no missing one); every entry carries every key the applier
##      reads; every number sits inside the band the scan's recipe states (key energy, shadow
##      opacity below 1 for the documented GI fake, fog begin < end, saturation/contrast inside
##      the no-clipping range, the LDR glow threshold below 1.0 — the 1.0 default blooms NOTHING
##      on Compatibility's RGBA8 buffer); and the five rigs are five different rigs.
##
##   2. THE BUILT ARENA CARRIES IT. For each of the five, the nodes `build_world()` has always
##      created — `WorldEnvironment`, `Sun`, `Fill`, same names, same count — now hold exactly
##      the table's values: BG_SKY with a real generated `PanoramaSkyMaterial` panorama,
##      sky-sourced ambient, depth fog, SSAO, glow, AgX tonemap, adjustments, and the per-arena
##      light rig. Nothing is asked of the node names or structures the frozen suites pin, and
##      no node is added (`tests/arena_kit_test.gd`'s recorded-baseline digest is the authority
##      on that; this suite does not duplicate it).
##
##   3. IT IS LEGAL GL COMPATIBILITY. Every feature `stylized-look-godot.md` Table B proves is
##      unavailable in this renderer is asserted OFF on the built environment: volumetric fog,
##      SSIL, SSR, SDFGI. Those properties exist, so a well-meaning look pass CAN switch them
##      on; here they stay off.
##
##   4. THE FROZEN NINE DID NOT MOVE. Built with the same call the slice suite uses, all nine
##      arenas still carry the exact environment `build_world()` wrote before this lane:
##      BG_COLOR, no sky, colour ambient, no fog, no glow, no SSAO, no adjustments, and the
##      original sun/fill rig. Their committed captures stay valid.
##
##   5. THE GROUND TEXTURE IS WIRED, AND ABSENT IS SAFE. With no file — today's repo — the slot
##      reports absent, `apply_ground_texture()` returns false having touched nothing, and the
##      built ground keeps its palette colour with unit UVs. A fixture PNG dropped at
##      `res://assets/arenas/<arena>/ground_texture.png` is then picked up by a rebuild: the
##      ground and the apron wear it, tiled, while every material fact the built-tree digest
##      records (albedo colour, metallic, roughness, transparency, shading) is UNCHANGED. The
##      fixture is removed again, the absent state is re-asserted byte for byte, and the kit
##      folder is required to hold no stray PNG — the empty slot is not a one-way door.
##
## Machine-readable contract, same as the other suites: `ok <name>` / `FAIL <name>: expected …,
## got …` / `PASS n/n` | `FAIL n/n`, exit 0 on PASS, 1 on FAIL. A `SCRIPT ERROR` anywhere in the
## log is a failure even next to a green tally.
extends SceneTree

const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaLook := preload("res://game/arenas/arena_look.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")

const ARENAS := ["torii", "medina", "carioca", "aurora", "egeo"]
## The nine frozen decks, in the frozen roster's order.
const FROZEN := ["officina", "locomotive", "clockwork", "cattedrale", "forgia",
	"tempesta", "abissale", "caldera", "orrery"]
## Where the ground-texture fixture is dropped, and what proves the wiring.
const FIXTURE_ARENA := "torii"
const FIXTURE_SIZE := 64
const FIXTURE_PATH := "res://assets/arenas/torii/ground_texture.png"
const ALPHA_TOLERANCE := 0.001

var checks := 0
var failures := 0
var fail_lines: Array[String] = []
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


# ---------------------------------------------------------------------------
# Harness (same contract as tests/arena_kit_test.gd)
# ---------------------------------------------------------------------------

func check(name: String, condition: bool, got: Variant = "") -> void:
	checks += 1
	if condition:
		print("ok %s" % name)
		return
	failures += 1
	var line := "FAIL %s: expected true, got %s" % [name, str(got)]
	print(line)
	fail_lines.append(line)


func check_eq(name: String, actual: Variant, expected: Variant) -> void:
	checks += 1
	if actual == expected:
		print("ok %s" % name)
		return
	failures += 1
	var line := "FAIL %s: expected %s, got %s" % [name, str(expected), str(actual)]
	print(line)
	fail_lines.append(line)


func check_close(name: String, actual: float, expected: float, tol := 0.0001) -> void:
	checks += 1
	if absf(actual - expected) <= tol:
		print("ok %s" % name)
		return
	failures += 1
	var line := "FAIL %s: expected %.4f, got %.4f" % [name, expected, actual]
	print(line)
	fail_lines.append(line)


## Angles go through a Basis and back, so `rotation_degrees` round-trips with float dust on it
## (the frozen rig's -62.0 reads back as -61.99999). Compare with a tolerance, never exactly.
func check_close_vec3(name: String, actual: Vector3, expected: Vector3, tol := 0.01) -> void:
	checks += 1
	if absf(actual.x - expected.x) <= tol and absf(actual.y - expected.y) <= tol \
			and absf(actual.z - expected.z) <= tol:
		print("ok %s" % name)
		return
	failures += 1
	var line := "FAIL %s: expected %s, got %s" % [name, str(expected), str(actual)]
	print(line)
	fail_lines.append(line)


func verdict() -> void:
	if failures == 0:
		print("PASS %d/%d" % [checks, checks])
	else:
		print("FAIL %d/%d first=%s" % [checks - failures, checks,
			fail_lines[0] if not fail_lines.is_empty() else ""])


func _run() -> void:
	print("# ARENA_LOOK arena_look_test godot=%s" % Engine.get_version_info()["string"])
	print("# rendering_method=%s msaa_3d=%s" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
		str(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", "?"))])
	_table()
	_built_rig()
	_compatibility_legal()
	_frozen_nine_untouched()
	_ground_texture()
	verdict()
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------
# 1. The table
# ---------------------------------------------------------------------------

func _table() -> void:
	check_eq("look/table_covers_exactly_the_five_world_arenas",
		str(ArenaLook.ids()), str(ARENAS))
	for id in ARENAS:
		check("look/%s_is_a_world_arena_in_the_style_table" % id, ArenaStyle.is_world(id))
		var rig: Dictionary = ArenaLook.look(id)
		check("look/%s_entry_is_not_empty" % id, not rig.is_empty())
		if rig.is_empty():
			continue
		var missing: Array[String] = []
		for key in ["sun_rotation", "sun_color", "sun_energy", "shadow_opacity", "fill_color",
				"fill_energy", "fill_rotation", "ambient_color", "ambient_energy",
				"ambient_sky_contribution", "exposure", "saturation", "adjust_contrast", "agx_contrast",
				"fog_depth", "fog_color", "fog_energy", "fog_sun_scatter", "fog_aerial",
				"fog_sky_affect", "glow_threshold", "glow_bloom", "glow_intensity",
				"ssao_radius", "ssao_intensity", "shadow_mode", "shadow_max_distance",
				"sky_process_mode", "sky_radiance_size"]:
			if not rig.has(key) or rig[key] == null:
				missing.append(key)
		check("look/%s_every_key_the_applier_reads_is_present" % id, missing.is_empty(), str(missing))

		var sun_rot: Vector3 = rig["sun_rotation"]
		check("look/%s_sun_is_above_the_horizon_and_below_zenith" % id,
			sun_rot.x < -5.0 and sun_rot.x > -70.0, str(sun_rot))
		check("look/%s_key_energy_is_in_the_golden_hour_band" % id,
			float(rig["sun_energy"]) >= 0.5 and float(rig["sun_energy"]) <= 2.0, str(rig["sun_energy"]))
		check("look/%s_shadow_opacity_fakes_bounce_light_without_killing_the_shadow" % id,
			float(rig["shadow_opacity"]) >= 0.5 and float(rig["shadow_opacity"]) < 1.0, str(rig["shadow_opacity"]))
		check("look/%s_fill_is_cooler_than_the_key_and_weaker" % id,
			(rig["fill_color"] as Color).b > (rig["fill_color"] as Color).r
			and float(rig["fill_energy"]) > 0.0 and float(rig["fill_energy"]) < float(rig["sun_energy"]),
			str(rig["fill_color"]))
		check("look/%s_ambient_sky_contribution_is_a_real_mix" % id,
			float(rig["ambient_sky_contribution"]) > 0.0 and float(rig["ambient_sky_contribution"]) <= 1.0,
			str(rig["ambient_sky_contribution"]))
		var fd: Vector3 = rig["fog_depth"]
		check("look/%s_fog_band_is_ordered_and_its_curve_positive" % id,
			fd.x > 0.0 and fd.y > fd.x and fd.z > 0.0, str(fd))
		check("look/%s_aerial_perspective_is_in_range" % id,
			float(rig["fog_aerial"]) >= 0.0 and float(rig["fog_aerial"]) <= 1.0, str(rig["fog_aerial"]))
		# The LDR rule: Compatibility renders to RGBA8 with no internal HDR, so a 1.0 threshold
		# blooms nothing at all (the scan's first `[unverified]` item, settled here).
		check("look/%s_glow_threshold_is_below_1_0_for_an_LDR_buffer" % id,
			float(rig["glow_threshold"]) > 0.4 and float(rig["glow_threshold"]) < 1.0, str(rig["glow_threshold"]))
		check("look/%s_bloom_and_intensity_are_conservative" % id,
			float(rig["glow_bloom"]) >= 0.0 and float(rig["glow_bloom"]) <= 0.25
			and float(rig["glow_intensity"]) >= 0.5 and float(rig["glow_intensity"]) <= 2.0,
			"%s/%s" % [str(rig["glow_bloom"]), str(rig["glow_intensity"])])
		check("look/%s_saturation_and_contrast_do_not_clip" % id,
			float(rig["saturation"]) >= 1.0 and float(rig["saturation"]) <= 1.3
			and float(rig["adjust_contrast"]) >= 1.0 and float(rig["adjust_contrast"]) <= 1.1,
			"%s/%s" % [str(rig["saturation"]), str(rig["adjust_contrast"])])
		check("look/%s_ssao_uses_only_the_two_knobs_compatibility_has" % id,
			float(rig["ssao_radius"]) >= 1.0 and float(rig["ssao_radius"]) <= 4.0
			and float(rig["ssao_intensity"]) >= 0.5 and float(rig["ssao_intensity"]) <= 2.0,
			"%s/%s" % [str(rig["ssao_radius"]), str(rig["ssao_intensity"])])
		check("look/%s_shadows_use_the_two_split_budget" % id,
			int(rig["shadow_mode"]) == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, str(rig["shadow_mode"]))
		check("look/%s_fill_rotation_is_the_shared_counter_direction" % id,
			rig["fill_rotation"] == Vector3(-28.0, 148.0, 0.0), str(rig["fill_rotation"]))
		check("look/%s_sky_process_mode_is_quality" % id,
			int(rig["sky_process_mode"]) == Sky.PROCESS_MODE_QUALITY, str(rig["sky_process_mode"]))

	# The five rigs are five rigs: a digest per arena, all distinct.
	var digests := {}
	for id in ARENAS:
		var rig: Dictionary = ArenaLook.look(id)
		var digest := "%s|%s|%.3f|%.3f|%s|%.3f|%.3f|%.3f|%s|%.3f|%.3f|%.3f" % [
			str(rig["sun_rotation"]), str(rig["sun_color"]), float(rig["sun_energy"]), float(rig["shadow_opacity"]),
			str(rig["fog_color"]), float(rig["fog_energy"]), float(rig["glow_threshold"]), float(rig["glow_intensity"]),
			str(rig["ambient_color"]), float(rig["ambient_energy"]), float(rig["saturation"]), float(rig["exposure"])]
		digests[digest] = id
	check_eq("look/the_five_rigs_are_five_different_rigs", digests.size(), ARENAS.size())
	check("look/an_unknown_id_has_no_rig", ArenaLook.look("officina").is_empty()
		and ArenaLook.look("nope").is_empty())
	check("look/a_frozen_arena_record_is_not_a_world_arena",
		not ArenaLook.is_world(Arena.info("officina")) and ArenaLook.is_world(Arena.info("torii")))

	# The generated sky is the arena's OWN gradient: the top of the panorama is the first style
	# stop, the horizon row is the last, and no two arenas render the same panorama.
	var pixels: Array[PackedByteArray] = []
	for id in ARENAS:
		var rig: Dictionary = ArenaLook.look(id)
		var img := ArenaLook.panorama_image(rig["sky_stops"], rig["apron"], 64, 64, id)
		var stops := rig["sky_stops"] as Array
		var top := Color(String(stops[0][1]))
		var horizon := Color(String(stops[stops.size() - 1][1]))
		var hy := int(round(0.5 * float(img.get_height() - 1)))
		check("sky/%s_panorama_top_is_the_first_style_stop" % id,
			_close_color(img.get_pixel(32, 0), top, 0.03),
			"%s vs %s" % [str(img.get_pixel(32, 0)), str(top)])
		check("sky/%s_panorama_horizon_row_is_at_the_last_style_stop" % id,
			_close_color(img.get_pixel(32, hy), horizon, 0.08),
			"%s vs %s" % [str(img.get_pixel(32, hy)), str(horizon)])
		check("sky/%s_panorama_is_dithered_not_flat" % id,
			_panorama_is_dithered(img), "one colour per row")
		pixels.append(img.get_data())
	var same: Array[String] = []
	for i in ARENAS.size():
		for j in range(i + 1, ARENAS.size()):
			if pixels[i] == pixels[j]:
				same.append("%s == %s" % [ARENAS[i], ARENAS[j]])
	check("sky/the_five_panoramas_are_five_different_skies", same.is_empty(), str(same))
	check("sky/the_same_arena_renders_the_same_panorama_twice",
		pixels[0] == ArenaLook.panorama_image(ArenaLook.look(ARENAS[0])["sky_stops"],
			ArenaLook.look(ARENAS[0])["apron"], 64, 64, ARENAS[0]).get_data())


# ---------------------------------------------------------------------------
# 2. The built arena
# ---------------------------------------------------------------------------

func _built_rig() -> void:
	for id in ARENAS:
		var built: Node3D = Arena.build(id, "default")
		if built == null:
			check("built/%s_builds" % id, false, "null")
			continue
		var we := built.get_node_or_null("WorldEnvironment") as WorldEnvironment
		var sun := built.get_node_or_null("Sun") as DirectionalLight3D
		var fill := built.get_node_or_null("Fill") as DirectionalLight3D
		check("built/%s_keeps_the_three_pinned_nodes_named_as_they_were" % id,
			we != null and sun != null and fill != null, "WorldEnvironment/Sun/Fill")
		if we == null or sun == null or fill == null:
			built.free()
			continue
		var env: Environment = we.environment
		var rig: Dictionary = ArenaLook.look(id)
		check("built/%s_has_an_environment" % id, env != null)
		if env == null:
			built.free()
			continue

		check_eq("built/%s_background_is_the_sky" % id, env.background_mode, Environment.BG_SKY)
		check("built/%s_has_a_sky_resource" % id, env.sky != null)
		if env.sky != null:
			check("built/%s_sky_is_a_panorama_material" % id,
				env.sky.sky_material is PanoramaSkyMaterial, str(env.sky.sky_material))
			if env.sky.sky_material is PanoramaSkyMaterial:
				var pano := env.sky.sky_material as PanoramaSkyMaterial
				check("built/%s_panorama_is_generated_and_assigned" % id, pano.panorama != null)
				if pano.panorama != null:
					check_eq("built/%s_panorama_size" % id,
						Vector2i(pano.panorama.get_width(), pano.panorama.get_height()),
						Vector2i(ArenaLook.PANORAMA_W, ArenaLook.PANORAMA_H))
			check_eq("built/%s_sky_process_mode_is_quality" % id,
				env.sky.process_mode, Sky.PROCESS_MODE_QUALITY)
			check_eq("built/%s_sky_radiance_size" % id,
				env.sky.radiance_size, Sky.RADIANCE_SIZE_256)

		check_eq("built/%s_ambient_comes_from_the_sky" % id,
			env.ambient_light_source, Environment.AMBIENT_SOURCE_SKY)
		check_close("built/%s_ambient_sky_contribution" % id,
			env.ambient_light_sky_contribution, float(rig["ambient_sky_contribution"]))
		check_eq("built/%s_ambient_color" % id, env.ambient_light_color, rig["ambient_color"])
		check_close("built/%s_ambient_energy" % id, env.ambient_light_energy, float(rig["ambient_energy"]))

		check("built/%s_has_depth_fog" % id,
			env.fog_enabled and env.fog_mode == Environment.FOG_MODE_DEPTH, str(env.fog_mode))
		var fd: Vector3 = rig["fog_depth"]
		check_close("built/%s_fog_depth_begin" % id, env.fog_depth_begin, fd.x)
		check_close("built/%s_fog_depth_end" % id, env.fog_depth_end, fd.y)
		check_close("built/%s_fog_depth_curve" % id, env.fog_depth_curve, fd.z)
		check_eq("built/%s_fog_color" % id, env.fog_light_color, rig["fog_color"])
		check_close("built/%s_fog_sun_scatter" % id, env.fog_sun_scatter, float(rig["fog_sun_scatter"]))
		check_close("built/%s_fog_aerial_perspective" % id, env.fog_aerial_perspective, float(rig["fog_aerial"]))
		check_close("built/%s_fog_sky_affect" % id, env.fog_sky_affect, float(rig["fog_sky_affect"]))

		check("built/%s_has_ssao" % id, env.ssao_enabled)
		check_close("built/%s_ssao_radius" % id, env.ssao_radius, float(rig["ssao_radius"]))
		check_close("built/%s_ssao_intensity" % id, env.ssao_intensity, float(rig["ssao_intensity"]))

		check("built/%s_has_glow" % id, env.glow_enabled)
		check_close("built/%s_glow_hdr_threshold" % id, env.glow_hdr_threshold, float(rig["glow_threshold"]))
		check_close("built/%s_glow_bloom" % id, env.glow_bloom, float(rig["glow_bloom"]))
		check_close("built/%s_glow_intensity" % id, env.glow_intensity, float(rig["glow_intensity"]))

		check_eq("built/%s_tonemaps_with_agx" % id, env.tonemap_mode, Environment.TONE_MAPPER_AGX)
		check_close("built/%s_exposure" % id, env.tonemap_exposure, float(rig["exposure"]))
		check("built/%s_grades_through_adjustments" % id, env.adjustment_enabled)
		check_close("built/%s_adjustment_saturation" % id, env.adjustment_saturation, float(rig["saturation"]))
		check_close("built/%s_adjustment_contrast" % id, env.adjustment_contrast, float(rig["adjust_contrast"]))

		check_close_vec3("built/%s_sun_angle" % id, sun.rotation_degrees, rig["sun_rotation"])
		check_eq("built/%s_sun_color" % id, sun.light_color, rig["sun_color"])
		check_close("built/%s_sun_energy" % id, sun.light_energy, float(rig["sun_energy"]))
		check("built/%s_sun_casts_shadows" % id, sun.shadow_enabled)
		check_close("built/%s_sun_shadow_opacity" % id, sun.shadow_opacity, float(rig["shadow_opacity"]))
		check_eq("built/%s_sun_shadow_splits" % id, sun.directional_shadow_mode, int(rig["shadow_mode"]))
		check_eq("built/%s_fill_color" % id, fill.light_color, rig["fill_color"])
		check_close("built/%s_fill_energy" % id, fill.light_energy, float(rig["fill_energy"]))
		check_close_vec3("built/%s_fill_rotation" % id, fill.rotation_degrees, rig["fill_rotation"])
		check("built/%s_fill_casts_no_shadows" % id, not fill.shadow_enabled)
		built.free()


# ---------------------------------------------------------------------------
# 3. Compatibility legality — Table B features must be off
# ---------------------------------------------------------------------------

func _compatibility_legal() -> void:
	for id in ARENAS:
		var built: Node3D = Arena.build(id, "default")
		var we := built.get_node_or_null("WorldEnvironment") as WorldEnvironment if built != null else null
		check("compat/%s_builds_an_environment" % id, built != null and we != null)
		if built == null or we == null:
			continue
		var env: Environment = we.environment
		check("compat/%s_volumetric_fog_is_off (Forward+ only)" % id, not env.volumetric_fog_enabled)
		check("compat/%s_ssil_is_off (Forward+ only)" % id, not env.ssil_enabled)
		check("compat/%s_ssr_is_off (Forward+ only)" % id, not env.ssr_enabled)
		check("compat/%s_sdfgi_is_off (Forward+ only)" % id, not env.sdfgi_enabled)
		built.free()


# ---------------------------------------------------------------------------
# 4. The nine frozen decks keep the environment their captures were made with
# ---------------------------------------------------------------------------

func _frozen_nine_untouched() -> void:
	var drifted: Array[String] = []
	for id in FROZEN:
		var built: Node3D = Arena.build(id, "default")
		if built == null:
			drifted.append("%s: no build" % id)
			continue
		var we := built.get_node_or_null("WorldEnvironment") as WorldEnvironment
		var sun := built.get_node_or_null("Sun") as DirectionalLight3D
		var fill := built.get_node_or_null("Fill") as DirectionalLight3D
		if we == null or sun == null or fill == null:
			drifted.append("%s: missing env/light node" % id)
			built.free()
			continue
		var env: Environment = we.environment
		var reasons: Array[String] = []
		if env.background_mode != Environment.BG_COLOR:
			reasons.append("background_mode=%d" % env.background_mode)
		if env.sky != null:
			reasons.append("sky set")
		if env.ambient_light_source != Environment.AMBIENT_SOURCE_COLOR:
			reasons.append("ambient_source=%d" % env.ambient_light_source)
		if env.ambient_light_color != Color(0.42, 0.46, 0.55):
			reasons.append("ambient_color=%s" % str(env.ambient_light_color))
		if absf(env.ambient_light_energy - 0.75) > ALPHA_TOLERANCE:
			reasons.append("ambient_energy=%.3f" % env.ambient_light_energy)
		if env.background_color != Color(0.07, 0.10, 0.16):
			reasons.append("background_color=%s" % str(env.background_color))
		if env.fog_enabled:
			reasons.append("fog on")
		if env.glow_enabled:
			reasons.append("glow on")
		if env.ssao_enabled:
			reasons.append("ssao on")
		if env.adjustment_enabled:
			reasons.append("adjustments on")
		if env.tonemap_mode != Environment.TONE_MAPPER_LINEAR:
			reasons.append("tonemap=%d" % env.tonemap_mode)
		if not _vec3_close(sun.rotation_degrees, Vector3(-62.0, -38.0, 0.0)):
			reasons.append("sun_rot=%s" % str(sun.rotation_degrees))
		if absf(sun.light_energy - 1.5) > ALPHA_TOLERANCE:
			reasons.append("sun_energy=%.3f" % sun.light_energy)
		if absf(sun.shadow_opacity - 1.0) > ALPHA_TOLERANCE:
			reasons.append("sun_shadow_opacity=%.3f" % sun.shadow_opacity)
		if absf(fill.light_energy - 0.35) > ALPHA_TOLERANCE:
			reasons.append("fill_energy=%.3f" % fill.light_energy)
		if not _vec3_close(fill.rotation_degrees, Vector3(-28.0, 148.0, 0.0)):
			reasons.append("fill_rot=%s" % str(fill.rotation_degrees))
		var surround := built.get_node_or_null("Surround") as MeshInstance3D
		if surround != null and (surround.material_override as StandardMaterial3D).albedo_texture != null:
			reasons.append("surround textured")
		if not reasons.is_empty():
			drifted.append("%s: %s" % [id, ", ".join(reasons)])
		built.free()
	check("frozen/the_nine_keep_the_environment_their_captures_were_made_with",
		drifted.is_empty(), str(drifted))


# ---------------------------------------------------------------------------
# 5. The ground texture slot, and its fallback
# ---------------------------------------------------------------------------

func _ground_texture() -> void:
	var path := ArenaLook.ground_texture_path(FIXTURE_ARENA)
	check_eq("ground/the_slot_path_is_the_arenas_kit_folder", path, FIXTURE_PATH)
	check("ground/the_slot_is_inside_the_kit_dir",
		path.begins_with("res://assets/arenas/") and path.ends_with("/ground_texture.png"))

	# --- ABSENT (today's repo) ---
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_PATH))
	ArenaLook.forget_ground_texture(FIXTURE_ARENA)
	check("ground/absent_the_slot_reports_no_texture", ArenaLook.ground_texture(FIXTURE_ARENA) == null)
	var probe := StandardMaterial3D.new()
	var probe_state := _mat_state(probe)
	check("ground/absent_applying_reports_nothing_to_do",
		not ArenaLook.apply_ground_texture(probe, FIXTURE_ARENA, Vector2(80.0, 80.0)))
	check_eq("ground/absent_the_material_is_untouched", _mat_state(probe), probe_state)
	var absent := _ground_state()
	check("ground/absent_the_built_ground_keeps_its_palette_and_unit_uvs",
		absent[1] == "null" and absent[2] == str(Vector3.ONE), str(absent))
	check("ground/a_frozen_arena_never_gets_a_ground_texture",
		not ArenaLook.apply_ground_texture(StandardMaterial3D.new(), "officina", Vector2(80.0, 80.0)))

	# --- PRESENT: a fixture PNG, dropped the way a real swatch arrives ---
	var img := Image.create_empty(FIXTURE_SIZE, FIXTURE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.62, 0.58, 0.52))
	for x in FIXTURE_SIZE:
		img.set_pixel(x, 0, Color(1.0, 0.2, 0.1))
	check_eq("ground/present_fixture_written", img.save_png(ProjectSettings.globalize_path(FIXTURE_PATH)), OK)
	check("ground/present_the_file_is_there", FileAccess.file_exists(FIXTURE_PATH))

	var tex := ArenaLook.ground_texture(FIXTURE_ARENA)
	check("ground/present_the_slot_loads_the_texture", tex != null)
	if tex != null:
		check_eq("ground/present_the_texture_is_the_fixture",
			Vector2i(tex.get_width(), tex.get_height()), Vector2i(FIXTURE_SIZE, FIXTURE_SIZE))
	var probe_on := StandardMaterial3D.new()
	probe_on.albedo_color = Color(0.11, 0.24, 0.18, 1.0)
	probe_on.roughness = 0.85
	var probe_digest := _digest_fields(probe_on)
	check("ground/present_applying_reports_success",
		ArenaLook.apply_ground_texture(probe_on, FIXTURE_ARENA, Vector2(80.0, 80.0)))
	check("ground/present_the_material_wears_the_texture", probe_on.albedo_texture == tex,
		str(probe_on.albedo_texture))
	check_eq("ground/present_uvs_tile_at_the_ground_tile_metres", probe_on.uv1_scale,
		Vector3(80.0 / ArenaLook.GROUND_TILE_M, 80.0 / ArenaLook.GROUND_TILE_M, 1.0))
	check_eq("ground/present_the_digested_material_facts_are_untouched",
		_digest_fields(probe_on), probe_digest)
	check_eq("ground/present_a_tiled_floor_filters_with_mipmaps", probe_on.texture_filter,
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)

	var present := _ground_state()
	check("ground/present_the_built_ground_wears_the_texture", present[1] != "null", str(present))
	check_eq("ground/present_the_surrounds_digested_facts_did_not_move", present[0], absent[0])
	check_eq("ground/present_the_aprons_digested_facts_did_not_move", present[3], absent[3])
	check("ground/present_the_uvs_are_tiled_not_unit", present[2] != absent[2], str(present[2]))
	var built: Node3D = Arena.build(FIXTURE_ARENA, "default")
	var apron := built.get_node_or_null("Scenery/BackdropApron") as MeshInstance3D
	check("ground/present_the_apron_wears_the_texture",
		apron != null and (apron.material_override as StandardMaterial3D).albedo_texture != null)
	built.free()

	# --- REMOVED: the empty slot comes back, byte for byte ---
	check_eq("ground/removed_fixture_deleted",
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_PATH)), OK)
	check("ground/removed_the_file_is_gone", not FileAccess.file_exists(FIXTURE_PATH))
	ArenaLook.forget_ground_texture(FIXTURE_ARENA)
	check("ground/removed_the_slot_reports_absent_again", ArenaLook.ground_texture(FIXTURE_ARENA) == null)
	check_eq("ground/removed_the_built_ground_is_exactly_what_it_was", _ground_state(), absent)
	check("ground/removed_no_stray_png_is_left_in_the_kit_folder", not _kit_folder_has_png())


## The state that has to be identical with and without the fixture: the digested material facts
## of the built ground (`Surround`) and of the apron, plus their texture and UV scaling.
## `[surround_digest, surround_texture, surround_uv, apron_digest, apron_uv]`.
func _ground_state() -> Array:
	var built: Node3D = Arena.build(FIXTURE_ARENA, "default")
	var out: Array = []
	var surround := built.get_node_or_null("Surround") as MeshInstance3D
	var sm := surround.material_override as StandardMaterial3D
	out.append(_digest_fields(sm))
	out.append(str(sm.albedo_texture if sm.albedo_texture != null else "null"))
	out.append(str(sm.uv1_scale))
	var apron := built.get_node_or_null("Scenery/BackdropApron") as MeshInstance3D
	var am := apron.material_override as StandardMaterial3D
	out.append(_digest_fields(am))
	out.append(str(am.uv1_scale))
	built.free()
	return out


## The facts `run/tmp/arena-kit/baseline_probe.gd` records for a mesh's override material —
## the ones the ground-texture wiring must never move (only the texture and its scaling move).
func _digest_fields(mat: StandardMaterial3D) -> String:
	return "albedo=%s metallic=%.3f roughness=%.3f transparency=%d shading=%d" % [
		str(mat.albedo_color), mat.metallic, mat.roughness, mat.transparency, mat.shading_mode]


func _mat_state(mat: StandardMaterial3D) -> Array:
	return [str(mat.albedo_color), str(mat.albedo_texture), str(mat.uv1_scale), mat.texture_filter,
		mat.metallic, mat.roughness, mat.transparency, mat.shading_mode]


func _close_color(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


func _vec3_close(a: Vector3, b: Vector3, tol := 0.01) -> bool:
	return absf(a.x - b.x) <= tol and absf(a.y - b.y) <= tol and absf(a.z - b.z) <= tol


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## A gradient row with the debanding noise baked in is not one flat colour: sample a row and
## require it to vary, which is what proves the dither actually landed in the image.
func _panorama_is_dithered(img: Image) -> bool:
	var first := img.get_pixel(0, 40)
	for x in img.get_width():
		if img.get_pixel(x, 40) != first:
			return true
	return false


func _kit_folder_has_png() -> bool:
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://assets/arenas/%s/" % FIXTURE_ARENA))
	if dir == null:
		return false
	for f in dir.get_files():
		if String(f).ends_with(".png"):
			return true
	return false
