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

// Reversible non-glTF PBR defaults; see AthleteRig owner decision 1.
uniform float pbr_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float pbr_roughness : hint_range(0.0, 1.0) = 0.85;
uniform bool normal_enabled = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float normal_scale = 1.0;
uniform bool roughness_enabled = false;
uniform sampler2D roughness_tex : filter_linear_mipmap;
uniform int roughness_channel = 1;

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

// How much this texel belongs to the family anchored at `anchor_srgb`, in [0,1].
// Same windows as outfit_recolour.gdshader's apply_anchor, minus the target.
float family_weight(vec3 cur, vec3 anchor_srgb) {
	vec3 hsv = rgb_to_hsv_deg(cur);
	vec3 anchor_hsv = rgb_to_hsv_deg(anchor_srgb);
	float dh = abs(mod(hsv.x - anchor_hsv.x + 180.0, 360.0) - 180.0);
	float w = 1.0 - smoothstep(hue_tol_deg * 0.55, hue_tol_deg, dh);
	w *= ss((hsv.y - sat_min) / 0.12);
	w *= ss((hsv.z - val_min) / 0.12);
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
	float fam_a = family_weight(base_srgb, anchor_a);
	float fam_b = family_weight(base_srgb, anchor_b);

	vec3 cur = base_srgb;
	cur = apply_anchor(cur, anchor_a, target_torso_a, region.r * fam_a * strength);
	cur = apply_anchor(cur, anchor_b, target_torso_b, region.r * fam_b * strength);
	cur = apply_anchor(cur, anchor_a, target_hip_a, region.g * fam_a * strength);
	cur = apply_anchor(cur, anchor_b, target_hip_b, region.g * fam_b * strength);
	cur = apply_anchor(cur, anchor_a, target_foot_a, region.b * fam_a * strength);
	cur = apply_anchor(cur, anchor_b, target_foot_b, region.b * fam_b * strength);

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
