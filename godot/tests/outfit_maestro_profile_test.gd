extends SceneTree
## outfit_maestro_profile_test.gd — the gate for Maestro's masked outfit profile.
##
## Same shape as res://tests/outfit_fiamma_profile_test.gd: one line per check, a
## `MEASURED` line for every number a reviewer would otherwise have to take on trust,
## and exit 0 only when every check passes.
##
##   GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" --path godot --headless \
##     --script res://tests/outfit_maestro_profile_test.gd
##
## WHAT THIS PROVES, AND WHAT IT CANNOT
## ------------------------------------
## Maestro is the first profile that needs the shader's OPTIONAL VALUE GATE: its two
## atlas families (#102040 navy, #68a8c8 sky) are 20.0 deg apart in hue under a 42 deg
## tolerance, so the hue test alone answers "both families" for most of the mask and
## the six targets collapse onto one colour per region. The measurement that says so,
## and the value bands that fix it, live in
## docs/agent-work/outfits-3d/evidence/maestro-value-split/ and in
## tools/character/measure_maestro_value_split.py.
##
## This test re-measures the separation IN ENGINE, on the real assets: it loads the
## atlas and the mask, reads the gate and the family-test constants back off the GPU
## material (so a profile or a shader default that drifted cannot pass), and counts
## how many sampled texels answer to both families with and without the gate.
##
## The family test itself is MIRRORED here in GDScript - a headless run has no
## renderer, so nothing can evaluate the GLSL. The mirror is exact (same HSV, same
## mod(), same smoothstep windows) and every constant it uses is read from the
## material, and the shader's source is checked for the gate uniforms so the mirror
## cannot be silently disconnected from the shader. What it cannot prove is what the
## recoloured garment LOOKS like: that needs a render, and there is none in this lane.

const Spawn := preload("res://src/character/athlete_spawn.gd")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")

const REGION_SHADER := "res://src/character/outfit_region_recolour.gdshader"
const MAESTRO_ATLAS := "res://assets/athletes/maestro_texture_0.png"
const MAESTRO_MASK := "res://assets/athletes/outfits/maestro/maestro_region_mask.png"

## The measured values this test pins. Changing any of them means the mask, the
## anchors or the split changed, which is a decision, not a refactor.
const EXPECTED_MASK_SHA_PREFIX := "dc39e62c92bc5b8e"
const EXPECTED_ANCHOR_A := "#102040"
const EXPECTED_ANCHOR_B := "#68a8c8"
const EXPECTED_BAND_A := Vector2(0.0, 0.74)
const EXPECTED_BAND_B := Vector2(0.76, 1.0)
const EXPECTED_FEATHER := 0.01

## Every 8th texel of the 2048x2048 atlas: 65,536 samples, ~36% of them inside the
## mask. Dense enough for a 1.5%-of-the-mask accent (the light family).
const SAMPLE_STEP := 8

## The hue test answers BOTH families for this share of the mask today (measured
## 0.6413 on all 1,518,775 masked texels; the sampled share is the same number).
const BOTH_TODAY_MIN_SHARE := 0.5
## With the gate, the two bands do not overlap, so no texel may answer both.
const BOTH_GATED_MAX := 0

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL %s" % message)


func check_eq(got, expected, message: String) -> void:
	check(got == expected, "%s (expected %s, got %s)" % [message, str(expected), str(got)])


func _initialize() -> void:
	call_deferred("run")
	_watchdog()


## A script error inside `run()` would otherwise leave the tree alive and the run
## hanging until the caller's timeout. Better to fail loudly and exit.
func _watchdog() -> void:
	await create_timer(240.0).timeout
	printerr("FAIL watchdog: the run did not finish within 240 s")
	quit(1)


## Shader parameters can read back null when a shader failed to compile (a headless
## run compiles the shader even with the dummy renderer). Reading them through this
## helper turns that into a failed check instead of a script error.
func _fparam(mat: ShaderMaterial, name: String) -> float:
	var v: Variant = mat.get_shader_parameter(name)
	check(v != null, "Shader parameter '%s' is readable" % name)
	return 0.0 if v == null else float(v)


## The family-test constants this profile actually runs with. The masked path never
## pushes MASK_DEFAULTS (protect_sat 0.22 / hue_tol 45 / sat_min 0.18 / val_min 0.02),
## so a profile material runs on the SHADER'S OWN declared literals - and those are
## what this mirror must use. Read from the shader source, not remembered, so the
## mirror cannot drift from the shader.
func _family_constants(code: String) -> Dictionary:
	var out := {}
	for name in ["hue_tol_deg", "sat_min", "val_min", "strength"]:
		var re := RegEx.new()
		re.compile("uniform\\s+float\\s+" + name + "\\s*[^=]*=\\s*([0-9.]+)\\s*;")
		var m := re.search(code)
		check(m != null, "Shader declares a default for '%s'" % name)
		out[name] = 0.0 if m == null else float(m.get_string(1))
	return out


func run() -> void:
	# ---------------------------------------------------------------- catalogue
	check(Catalogue.entries().size() == 26, "Catalogue count unchanged")
	check(Catalogue.has_profile(&"maestro"), "Maestro has a masked profile")
	var prof := Catalogue.profile(&"maestro")
	check_eq(String(prof.get("mask", "")), MAESTRO_MASK, "Profile names the measured mask")
	check_eq(String(prof.get("anchor_a", "")), EXPECTED_ANCHOR_A, "Profile anchor A is the measured navy")
	check_eq(String(prof.get("anchor_b", "")), EXPECTED_ANCHOR_B, "Profile anchor B is the measured sky")
	var gate := Catalogue.profile_value_gate(&"maestro")
	check_eq(bool(gate.get("enabled", false)), true, "Maestro declares the value gate")
	var fiamma_gate := Catalogue.profile_value_gate(&"fiamma")
	check_eq(bool(fiamma_gate.get("enabled", true)), false, "Fiamma does NOT declare the value gate")
	check_eq(Catalogue.profile_port_only(&"maestro", &"circuit"), ["hip_a"], "Circuit's one port slot is marked")
	check_eq(Catalogue.profile_port_only(&"maestro", &"legend"), [], "Legend has no port slot")
	var targets := Catalogue.profile_targets(&"maestro", &"circuit")
	check_eq(targets.size(), 6, "Circuit fills all six targets")
	check_eq(targets.get("target_hip_a"), Color("#315cff"), "Circuit hip_a is the ported primary")
	check_eq(targets.get("target_foot_b"), Color("#9ef8ff"), "Circuit foot_b is the declared accent")
	check_eq(Catalogue.profile_targets(&"maestro", &"mythic"), {}, "Mythic has no target set (out of scope)")

	# The mask the profile points at is the mask that was measured.
	var mask_bytes := FileAccess.get_file_as_bytes(MAESTRO_MASK)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(mask_bytes)
	var digest := ctx.finish().hex_encode()
	print("MEASURED maestro_mask_sha256=%s bytes=%d" % [digest.substr(0, 16), mask_bytes.size()])
	check_eq(digest.substr(0, 16), EXPECTED_MASK_SHA_PREFIX, "Mask on disk is the measured mask")

	# ---------------------------------------------------------------- the rigs
	var a = Spawn.make(&"maestro", &"base")
	var b = Spawn.make(&"maestro", &"legend")
	check(a != null and b != null, "Maestro spawns base and legend")
	if a == null or b == null:
		_finish()
		return
	root.add_child(a)
	root.add_child(b)
	var original = a.get_mesh_instance().get_surface_override_material(0)
	var original_texture = original.albedo_texture
	var bones: int = a.get_skeleton().get_bone_count()
	var nodes: int = a.get_child_count()

	check(Catalogue.apply(a, &"maestro", &"circuit"), "Circuit applies")
	var material = a.get_catalogue_surface()
	check(material != null, "Maestro goes through the masked material")
	if material == null:
		_finish()
		return
	var other_material = b.get_catalogue_surface()
	check(material != other_material, "Rig material isolation")
	check(material.get_shader_parameter("region_mask") != null, "Region mask is bound")
	check(material.get_shader_parameter("region_mask") == other_material.get_shader_parameter("region_mask"), "Immutable mask shared")
	check(material.get_shader_parameter("normal_tex") == a.get_base_material().normal_texture, "Normal map retained")
	check(material.get_shader_parameter("roughness_tex") == a.get_base_material().roughness_texture, "Roughness map retained")

	# Anchors and gate, read back off the material the GPU will use.
	var anchor_a: Vector3 = material.get_shader_parameter("anchor_a")
	var anchor_b: Vector3 = material.get_shader_parameter("anchor_b")
	print("MEASURED maestro_anchor_a=%s anchor_b=%s" % [str(anchor_a), str(anchor_b)])
	check(anchor_a.is_equal_approx(_srgb(Color(EXPECTED_ANCHOR_A))), "Anchor A reaches the material")
	check(anchor_b.is_equal_approx(_srgb(Color(EXPECTED_ANCHOR_B))), "Anchor B reaches the material")
	_check_gate(material, true, "maestro")

	# The family-test constants this profile actually runs with. The masked path does
	# NOT push MASK_DEFAULTS, so these are the shader's own declared defaults - the
	# mask lane's report assumed 45/0.18/0.02, which is the legacy path's set.
	var sh := load(REGION_SHADER) as Shader
	check(sh != null, "Region shader loads")
	check(sh != null and sh.code.contains("value_gate_enabled") and sh.code.contains("value_band_a")
		and sh.code.contains("value_band_b") and sh.code.contains("value_band_weight"),
		"Shader declares the gate this test mirrors")
	var consts := _family_constants(sh.code if sh != null else "")
	var hue_tol: float = consts["hue_tol_deg"]
	var sat_min: float = consts["sat_min"]
	var val_min: float = consts["val_min"]
	var strength: float = consts["strength"]
	print("MEASURED maestro_family_constants hue_tol_deg=%f sat_min=%f val_min=%f strength=%f" % [hue_tol, sat_min, val_min, strength])
	check_eq(hue_tol, 42.0, "Masked path runs on the shader's declared hue tolerance")
	check_eq(sat_min, 0.25, "Masked path runs on the shader's declared saturation floor")
	check_eq(val_min, 0.06, "Masked path runs on the shader's declared value floor")
	# 20.0 deg of anchor separation under any of these tolerances: the hue test alone
	# cannot separate Maestro's families. Asserted from the material, not from memory.
	var hue_sep := _hue_separation_deg(Color(EXPECTED_ANCHOR_A), Color(EXPECTED_ANCHOR_B))
	print("MEASURED maestro_anchor_hue_separation_deg=%.1f" % hue_sep)
	check(hue_sep < hue_tol, "Anchor hue separation is inside the hue tolerance (so hue alone cannot separate)")

	# ---------------------------------------------------------------- switching
	for cycle in 4:
		for id in [&"circuit", &"legend", &"signature"]:
			check(Catalogue.apply(a, &"maestro", id), "Apply " + String(id))
			check(a.get_catalogue_surface() == material, "Switch reuses same material")
			var want := _srgb(Catalogue.profile_targets(&"maestro", id)["target_torso_a"])
			check(a.get_catalogue_surface().get_shader_parameter("target_torso_a").is_equal_approx(want), "Targets follow the outfit")
		check(Catalogue.apply(a, &"maestro", &"base"), "Restore base")
		check(a.get_mesh_instance().get_surface_override_material(0) == original, "Exact original material restored")
		check(original.albedo_texture == original_texture, "Original texture unchanged")
		check(b.get_catalogue_surface().get_shader_parameter("target_torso_a").is_equal_approx(_srgb(Color("#fff0a3"))), "Other rig unchanged")
	check(a.get_skeleton().get_bone_count() == bones and a.get_child_count() == nodes, "No extra nodes or skeleton changes")

	# The render lane's own gate, checked here without a renderer (it lives in
	# res://tests/outfit_maestro_capture.gd, which needs a real framebuffer): the three
	# outfits must not carry the same shader parameters, or four "different" states
	# would render as four identical figures.
	var signatures := {}
	for id in [&"circuit", &"legend", &"signature"]:
		check(Catalogue.apply(a, &"maestro", id), "Apply " + String(id) + " for the signature check")
		signatures[id] = _uniform_signature(a)
	print("MEASURED outfit_signature circuit=%s" % str(signatures[&"circuit"]))
	check(String(signatures[&"circuit"]).contains("value_gate_enabled=true"), "The gate is part of the outfit signature")
	check(String(signatures[&"circuit"]).contains("value_band_a=") and String(signatures[&"circuit"]).contains("value_band_b="),
		"Both value bands are part of the outfit signature")
	check(signatures[&"circuit"] != signatures[&"signature"], "circuit and signature carry different shader parameters")
	check(signatures[&"circuit"] != signatures[&"legend"] and signatures[&"legend"] != signatures[&"signature"],
		"All three outfits are parameter-distinct")

	check(Catalogue.apply(a, &"maestro", &"mythic"), "Unauthored known outfit preserves safe fallback")
	check(a.is_base_surface(), "Mythic does not retain last supported appearance")
	check(not Catalogue.apply(a, &"maestro", &"invalid"), "Unknown outfit rejected")
	check(a.is_base_surface(), "Invalid selection leaves material intact")

	# ---------------------------------------------------------------- Fiamma, unchanged
	var f = Spawn.make(&"fiamma", &"circuit")
	check(f != null, "Fiamma still spawns")
	if f != null:
		var fmat = f.get_catalogue_surface()
		check(fmat != null, "Fiamma still goes through the masked material")
		if fmat != null:
			_check_gate(fmat, false, "fiamma")
			check(fmat.get_shader_parameter("anchor_a").is_equal_approx(_srgb(Color("#b8e828"))), "Fiamma anchors untouched")
		f.free()

	# ---------------------------------------------------------------- the separation, measured
	_measure_separation(material, consts)

	b.free()
	a.free()
	_finish()


func _check_gate(mat: ShaderMaterial, enabled: bool, who: String) -> void:
	var got_enabled := bool(mat.get_shader_parameter("value_gate_enabled"))
	var band_a: Vector2 = mat.get_shader_parameter("value_band_a")
	var band_b: Vector2 = mat.get_shader_parameter("value_band_b")
	var feather := float(mat.get_shader_parameter("value_band_feather"))
	print("MEASURED %s_gate enabled=%s band_a=(%.2f,%.2f) band_b=(%.2f,%.2f) feather=%.3f"
		% [who, str(got_enabled), band_a.x, band_a.y, band_b.x, band_b.y, feather])
	check_eq(got_enabled, enabled, "%s gate enabled flag" % who)
	if enabled:
		check(band_a.is_equal_approx(EXPECTED_BAND_A), "%s band_a is the measured dark band" % who)
		check(band_b.is_equal_approx(EXPECTED_BAND_B), "%s band_b is the measured light band" % who)
		check(is_equal_approx(feather, EXPECTED_FEATHER), "%s feather is the measured feather" % who)
	else:
		check(band_a.is_equal_approx(Vector2(0.0, 1.0)) and band_b.is_equal_approx(Vector2(0.0, 1.0)),
			"%s bands are the identity (no clipping possible)" % who)


# ---------------------------------------------------------------- helpers

## sRGB components in [0,1], as the shader's anchor/target uniforms carry them.
func _srgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## Every non-texture uniform on the rig's surface, as a sorted "name=value" string.
## The same shape as the render lane's `_targets_signature()`, so "these two outfits
## differ" means the same thing in both places.
const TEXTURE_UNIFORMS := ["source_tex", "region_mask", "normal_tex", "roughness_tex"]

func _uniform_signature(rig: Node) -> String:
	var mat := rig.get_catalogue_surface() as ShaderMaterial
	if mat == null:
		return ""
	var parts := PackedStringArray()
	for uniform in mat.shader.get_shader_uniform_list():
		var name: String = uniform["name"]
		if name in TEXTURE_UNIFORMS or int(uniform["type"]) == TYPE_OBJECT:
			continue
		parts.append("%s=%s" % [name, str(mat.get_shader_parameter(name))])
	var sorted := Array(parts)
	sorted.sort()
	return ",".join(sorted)


# ---------------------------------------------------------------- shader mirror
#
# Exact mirror of family_weight() in outfit_region_recolour.gdshader, including
# value_band_weight(). fposmod is GLSL's mod(); Godot's smoothstep is the same
# Hermite ramp. Every constant is passed in from the material.

func _hsv(c: Color) -> Vector3:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	var d := mx - mn
	var h := 0.0
	if d > 1e-9:
		if mx == c.r:
			h = fposmod(60.0 * (c.g - c.b) / d, 360.0)
		elif mx == c.g:
			h = 60.0 * (c.b - c.r) / d + 120.0
		else:
			h = 60.0 * (c.r - c.g) / d + 240.0
	var s := 0.0
	if mx > 1e-9:
		s = d / mx
	return Vector3(h, s, mx)


func _ss(x: float) -> float:
	return smoothstep(0.0, 1.0, clampf(x, 0.0, 1.0))


## The hue/saturation/value half of family_weight(), i.e. the shipped test with no
## gate. `wa_today` in the measurement is exactly this.
func _hue_weight(cur: Color, anchor: Color, hue_tol: float, sat_min: float, val_min: float) -> float:
	var hsv := _hsv(cur)
	var anchor_hsv := _hsv(anchor)
	var dh := absf(fposmod(hsv.x - anchor_hsv.x + 180.0, 360.0) - 180.0)
	var w := 1.0 - smoothstep(hue_tol * 0.55, hue_tol, dh)
	w *= _ss((hsv.y - sat_min) / 0.12)
	w *= _ss((hsv.z - val_min) / 0.12)
	return w


## value_band_weight() of the shader. 1.0 when the gate is off.
func _band_weight(value: float, band: Vector2, feather: float, gate_on: bool) -> float:
	if not gate_on:
		return 1.0
	var low := smoothstep(band.x - feather, band.x, value)
	var high := 1.0 - smoothstep(band.y, band.y + feather, value)
	return low * high


func _hue_separation_deg(a: Color, b: Color) -> float:
	var ha := _hsv(a).x
	var hb := _hsv(b).x
	return absf(fposmod(ha - hb + 180.0, 360.0) - 180.0)


func _measure_separation(mat: ShaderMaterial, consts: Dictionary) -> void:
	var tex := Image.new()
	var mask := Image.new()
	check(tex.load_png_from_buffer(FileAccess.get_file_as_bytes(MAESTRO_ATLAS)) == OK, "Atlas loads")
	check(mask.load_png_from_buffer(FileAccess.get_file_as_bytes(MAESTRO_MASK)) == OK, "Mask loads")
	if tex.is_empty() or mask.is_empty():
		return
	tex.convert(Image.FORMAT_RGBA8)
	mask.convert(Image.FORMAT_RGBA8)
	var tw := tex.get_width()
	var th := tex.get_height()
	var tdata := tex.get_data()
	var mdata := mask.get_data()

	var anchor_a: Vector3 = mat.get_shader_parameter("anchor_a")
	var anchor_b: Vector3 = mat.get_shader_parameter("anchor_b")
	var col_a := Color(anchor_a.x, anchor_a.y, anchor_a.z)
	var col_b := Color(anchor_b.x, anchor_b.y, anchor_b.z)
	var band_a: Vector2 = mat.get_shader_parameter("value_band_a")
	var band_b: Vector2 = mat.get_shader_parameter("value_band_b")
	var feather := _fparam(mat, "value_band_feather")
	var gate_on := bool(mat.get_shader_parameter("value_gate_enabled"))
	var hue_tol: float = consts["hue_tol_deg"]
	var sat_min: float = consts["sat_min"]
	var val_min: float = consts["val_min"]

	# The three region channels, so the inert-slot claim can be per region.
	var region_index := {"torso": 0, "hip": 1, "foot": 2}
	var counts := {
		"inside": 0,
		"both_today": 0, "both_gated": 0,
		"a_gated": 0, "b_gated": 0, "neither_gated": 0,
	}
	var b_by_region := {"torso": 0, "hip": 0, "foot": 0}
	var a_by_region := {"torso": 0, "hip": 0, "foot": 0}

	var y := 0
	while y < th:
		var x := 0
		while x < tw:
			var i := (y * tw + x) * 4
			if int(mdata[i + 3]) >= 128:
				counts["inside"] += 1
				var cur := Color(tdata[i] / 255.0, tdata[i + 1] / 255.0, tdata[i + 2] / 255.0)
				var v := maxf(cur.r, maxf(cur.g, cur.b))
				var wa_today := _hue_weight(cur, col_a, hue_tol, sat_min, val_min)
				var wb_today := _hue_weight(cur, col_b, hue_tol, sat_min, val_min)
				if wa_today > 0.5 and wb_today > 0.5:
					counts["both_today"] += 1
				var wa := wa_today * _band_weight(v, band_a, feather, gate_on)
				var wb := wb_today * _band_weight(v, band_b, feather, gate_on)
				if wa > 0.5 and wb > 0.5:
					counts["both_gated"] += 1
				elif wa > 0.5:
					counts["a_gated"] += 1
				elif wb > 0.5:
					counts["b_gated"] += 1
				else:
					counts["neither_gated"] += 1
				for r in region_index:
					if int(mdata[i + int(region_index[r])]) >= 128:
						if wa > 0.5:
							a_by_region[r] += 1
						if wb > 0.5:
							b_by_region[r] += 1
			x += SAMPLE_STEP
		y += SAMPLE_STEP

	var inside := int(counts["inside"])
	check(inside > 20000, "Sampled enough masked texels to measure (%d)" % inside)
	if inside == 0:
		return
	var both_today_share := float(counts["both_today"]) / inside
	var both_gated_share := float(counts["both_gated"]) / inside
	print("MEASURED sample_step=%d sampled_inside=%d" % [SAMPLE_STEP, inside])
	print("MEASURED both_families_today=%d share=%.4f" % [counts["both_today"], both_today_share])
	print("MEASURED both_families_gated=%d share=%.4f" % [counts["both_gated"], both_gated_share])
	print("MEASURED gated a_only=%d b_only=%d neither=%d" % [counts["a_gated"], counts["b_gated"], counts["neither_gated"]])
	print("MEASURED family_a_by_region=%s" % str(a_by_region))
	print("MEASURED family_b_by_region=%s" % str(b_by_region))
	check(both_today_share > BOTH_TODAY_MIN_SHARE,
		"Hue test alone collapses the families (both>0.5 for %.4f of the mask)" % both_today_share)
	check(counts["both_gated"] <= BOTH_GATED_MAX,
		"Value gate separates the families (both>0.5: %d texels)" % counts["both_gated"])
	check(counts["a_gated"] > 0, "The dark family is still recolourable")
	check(counts["b_gated"] > 0, "The light family is recolourable at all")
	check(b_by_region["hip"] > 0, "The accent lives in the hip region")
	check(b_by_region["foot"] == 0, "foot_b is inert: the shoe accent is desaturated (0 texels)")
	check(a_by_region["torso"] > 0 and a_by_region["hip"] > 0 and a_by_region["foot"] > 0,
		"The dark family covers all three regions")


func _finish() -> void:
	print("OUTFIT_MAESTRO_PROFILE_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
