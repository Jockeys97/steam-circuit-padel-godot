shader_type spatial;

// outfit_region_recolour.gdshader - the masked sibling of outfit_recolour.gdshader.
//
// WHY A SECOND SHADER
// `outfit_recolour.gdshader` finds the garment by saturation, which works on the
// Volpe placeholder because a fox's ivory fur is less saturated than its kit. It
// does not work on a human athlete: Fiamma's skin is as saturated as her kit, so a
// colour floor would repaint her arms and legs along with her top. This shader
// therefore takes the region from an explicit UV mask authored by
// `tools/character/build_fiamma_outfit_mask.py` - regions come from the skeleton,
// never from the texture - and consults the texture only *inside* a region, and
// only to tell the baked atlas's two recolourable families apart.
//
//   region_mask.r  torso garment   (tank top, straps)
//   region_mask.g  hip garment     (skirt, shorts)
//   region_mask.b  foot garment    (shoe, sock)
//   region_mask.a  coverage        (evidence only, unused here)
//
// Each region carries two targets, because each of them uses both atlas families:
// the lime kit and its navy trim. Six targets, one texture:
//
//                family A (lime)     family B (navy)
//   torso        target_torso_a      target_torso_b
//   hip          target_hip_a        target_hip_b
//   foot         target_foot_a       target_foot_b
//
// Anything the mask does not cover - skin, hair, eyes, racket, wristbands, and
// every texel of every other athlete - keeps its baked colour no matter what it
// looks like. Set every uniform through src/character/outfit_catalogue.gd.
//
// THE VALUE GATE (optional, per profile). The hue test above assumes the two
// families are two different hues. Maestro's are not - see the `value_gate_enabled`
// block below - so a profile may separate them by VALUE instead. Off by default:
// a profile that does not declare the gate renders exactly as it did before.

uniform sampler2D source_tex : source_color, filter_linear_mipmap, repeat_enable;

// Data, not colour: the mask is a weight map and must not be linearised.
uniform sampler2D region_mask : filter_linear, repeat_disable;

// The two recolourable families of the baked atlas, measured inside the garment
// regions by tools/character/build_fiamma_outfit_mask.py. Raw sRGB components in
// [0,1]; deliberately NOT hinted `source_color`, exactly like the anchors of
// outfit_recolour.gdshader.
uniform vec3 anchor_a = vec3(0.7216, 0.9098, 0.1569);  // #b8e828 lime kit
uniform vec3 anchor_b = vec3(0.0314, 0.0941, 0.2196);  // #081838 navy trim

uniform vec3 target_torso_a = vec3(0.7216, 0.9098, 0.1569);
uniform vec3 target_torso_b = vec3(0.0314, 0.0941, 0.2196);
uniform vec3 target_hip_a = vec3(0.7216, 0.9098, 0.1569);
uniform vec3 target_hip_b = vec3(0.0314, 0.0941, 0.2196);
uniform vec3 target_foot_a = vec3(0.7216, 0.9098, 0.1569);
uniform vec3 target_foot_b = vec3(0.0314, 0.0941, 0.2196);

// Family test, and the luma clamp shared with outfit_recolour.gdshader so a
// recoloured garment keeps the shading that was baked into the atlas.
uniform float hue_tol_deg = 42.0;
uniform float sat_min = 0.25;
uniform float val_min = 0.06;
uniform float val_max = 0.99;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float luma_clamp_lo = 0.45;
uniform float luma_clamp_hi = 1.7;

// OPTIONAL PER-PROFILE VALUE GATE — disabled unless a profile declares it.
//
// The hue test above separates the two families when they are two different hues
// (Fiamma: lime 77 deg vs navy 219 deg). It CANNOT separate them when both
// families sit in one hue band: Maestro's anchors are 20.0 deg apart (#102040 navy
// at 217.1, #68a8c8 sky at 196.5) under a 42 deg tolerance, so 973,915 masked
// texels answer to both anchors at once and the six targets collapse onto one
// colour per region (measured by tools/character/measure_maestro_value_split.py).
//
// Maestro's families are far apart in VALUE instead: the navy kit and its baked
// shading live below 0.75, the sky-blue accent above. So a profile may declare a
// value band per family. A texel outside both bands belongs to neither family and
// keeps its baked colour, which is what stops a recolour from leaving patches.
//
// The gate MULTIPLIES the hue weight, so with the gate off (`value_gate_enabled`
// false, the default) `family_weight()` is bit-for-bit the shipped behaviour:
// `value_band_weight()` returns exactly 1.0 and the bands are never read.
//
//   value_band_a  [0.0, 0.74] for Maestro: the dark family, full membership at or
//   value_band_b  [0.76, 1.0] for Maestro: the light family
//   value_band_feather  the width of each ramp; Maestro's two ramps meet at 0.75,
//                 which is the accent's own antialiased edge, so no recolourable
//                 texel is orphaned (measured: 103 orphan texels out of 1,518,775).
uniform bool value_gate_enabled = false;
uniform vec2 value_band_a = vec2(0.0, 1.0);
uniform vec2 value_band_b = vec2(0.0, 1.0);
uniform float value_band_feather = 0.05;

// Reversible non-glTF PBR defaults; see AthleteRig owner decision 1.
uniform float pbr_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float pbr_roughness : hint_range(0.0, 1.0) = 0.85;
uniform bool normal_enabled = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float normal_scale = 1.0;
uniform bool roughness_enabled = false;
uniform sampler2D roughness_tex : filter_linear_mipmap;
uniform int roughness_channel = 1;

// Optional geometric design on top of the colour families. Existing outfits
// leave this at zero. Bind-space position avoids overlapping UV atlas islands.
uniform int concept_style = 0; // 1 = Solar Sprint, 2 = Polar Ace
uniform vec3 concept_panel = vec3(0.125, 0.278, 0.490);
uniform vec3 concept_piping = vec3(0.718, 0.435, 0.227);
varying vec3 concept_bind_position;

void vertex() {
	concept_bind_position = VERTEX;
}

const float LUMA_EPS = 1e-4;

vec3 lin_to_srgb(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 srgb_to_lin(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 rgb_to_hsv_deg(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 1e-9) {
		if (mx == c.r) {
			h = mod(60.0 * (c.g - c.b) / d, 360.0);
		} else if (mx == c.g) {
			h = 60.0 * (c.b - c.r) / d + 120.0;
		} else {
			h = 60.0 * (c.r - c.g) / d + 240.0;
		}
	}
	float s = mx > 1e-9 ? d / mx : 0.0;
	return vec3(h, s, mx);
}

float ss(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

float luma_lin(vec3 lin) {
	return dot(lin, vec3(0.2126, 0.7152, 0.0722));
}

// 1.0 when the gate is off, so `family_weight` is unchanged for every profile that
// does not declare one. With the gate on, a texel outside the band keeps its baked
// colour: both families then score zero and `apply_anchor` returns early.
// Declared BEFORE family_weight: Godot's shader language, like GLSL, needs a
// function declared before its first call.
float value_band_weight(float value, vec2 band) {
	if (!value_gate_enabled) {
		return 1.0;
	}
	float low = smoothstep(band.x - value_band_feather, band.x, value);
	float high = 1.0 - smoothstep(band.y, band.y + value_band_feather, value);
	return low * high;
}

// How much this texel belongs to the family anchored at `anchor_srgb`, in [0,1].
// Same windows as outfit_recolour.gdshader's apply_anchor, minus the target, plus
// the optional per-profile value band (identity when the gate is off).
float family_weight(vec3 cur, vec3 anchor_srgb, vec2 value_band) {
	vec3 hsv = rgb_to_hsv_deg(cur);
	vec3 anchor_hsv = rgb_to_hsv_deg(anchor_srgb);
	float dh = abs(mod(hsv.x - anchor_hsv.x + 180.0, 360.0) - 180.0);
	float w = 1.0 - smoothstep(hue_tol_deg * 0.55, hue_tol_deg, dh);
	w *= ss((hsv.y - sat_min) / 0.12);
	w *= ss((hsv.z - val_min) / 0.12);
	w *= value_band_weight(hsv.z, value_band);
	return w;
}

// One apply_anchor pass, in sRGB, with an explicit mask. Lifted from
// outfit_recolour.gdshader so both lanes colour a garment the same way.
vec3 apply_anchor(vec3 cur, vec3 anchor_srgb, vec3 target_srgb, float mask) {
	if (mask <= 0.0) {
		return cur;
	}
	vec3 target_lin = srgb_to_lin(target_srgb);
	float anchor_luma = max(luma_lin(srgb_to_lin(anchor_srgb)), LUMA_EPS);
	float ratio = clamp(luma_lin(srgb_to_lin(cur)) / anchor_luma, luma_clamp_lo, luma_clamp_hi);
	return mix(cur, lin_to_srgb(target_lin * ratio), mask);
}

void fragment() {
	vec3 sampled = texture(source_tex, UV).rgb;
	vec3 base_srgb = OUTPUT_IS_SRGB ? sampled : lin_to_srgb(sampled);
	vec4 region = texture(region_mask, UV);

	// Classified once, from the baked colour, so the two passes cannot compound.
	float fam_a = family_weight(base_srgb, anchor_a, value_band_a);
	float fam_b = family_weight(base_srgb, anchor_b, value_band_b);

	vec3 cur = base_srgb;
	cur = apply_anchor(cur, anchor_a, target_torso_a, region.r * fam_a * strength);
	cur = apply_anchor(cur, anchor_b, target_torso_b, region.r * fam_b * strength);
	cur = apply_anchor(cur, anchor_a, target_hip_a, region.g * fam_a * strength);
	cur = apply_anchor(cur, anchor_b, target_hip_b, region.g * fam_b * strength);
	cur = apply_anchor(cur, anchor_a, target_foot_a, region.b * fam_a * strength);
	cur = apply_anchor(cur, anchor_b, target_foot_b, region.b * fam_b * strength);

	if (concept_style != 0) {
		// Maestro's import is in centimetres; Fiamma's is already in metres.
		vec3 p = concept_bind_position * (concept_style == 2 ? 0.01 : 1.0);
		if (concept_style == 2) {
			float torso = region.r * smoothstep(1.10, 1.17, p.y) * (1.0 - smoothstep(1.64, 1.70, p.y));
			float edge = p.x - (0.55 * p.y - 0.80);
			float panel = torso * smoothstep(-0.026, 0.012, edge);
			float piping = torso * (1.0 - smoothstep(0.008, 0.025, abs(edge)));
			float shorts_panel = region.g * smoothstep(0.65, 0.75, p.y) * (1.0 - smoothstep(1.07, 1.13, p.y)) * smoothstep(0.07, 0.15, p.x);
			cur = apply_anchor(cur, target_torso_a, concept_panel, panel);
			cur = apply_anchor(cur, target_torso_a, concept_piping, piping);
			cur = apply_anchor(cur, target_hip_a, concept_panel, shorts_panel);
		} else {
			float torso = region.r * smoothstep(1.10, 1.18, p.y) * (1.0 - smoothstep(1.61, 1.68, p.y));
			float edge = p.x + 0.33 * (p.y - 1.28) + 0.03;
			float panel = torso * (1.0 - smoothstep(-0.015, 0.025, edge));
			float piping = torso * (1.0 - smoothstep(0.010, 0.028, abs(edge)));
			cur = apply_anchor(cur, target_torso_a, concept_panel, panel);
			cur = apply_anchor(cur, target_torso_a, concept_piping, piping);
		}
	}

	ALBEDO = OUTPUT_IS_SRGB ? cur : srgb_to_lin(cur);
	METALLIC = pbr_metallic;
	ROUGHNESS = pbr_roughness;
	if (roughness_enabled) {
		vec4 packed = texture(roughness_tex, UV);
		float value = roughness_channel == 4 ? dot(packed.rgb, vec3(0.333333)) : packed[clamp(roughness_channel, 0, 3)];
		ROUGHNESS *= value;
	}
	if (normal_enabled) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
