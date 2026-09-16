shader_type spatial;

// outfit_recolour.gdshader — the reference's two outfit colours, applied to the
// one baked atlas the rig actually has, per fragment, at zero disk cost.
//
// WHY A SHADER AND NOT A BAKED PNG
// The Meshy rig ships ONE material and ONE baked baseColorTexture (measured,
// tools/character/glb_tri_count.py). The previous slice proved the recolour by
// baking 2048x2048 atlases offline with tools/character/recolour_outfits.py. That
// works, but js/data.js defines 26 outfit entries, and 26 baked atlases is ~26x16 MB
// of RAM on a 3910 MB host with no swap. This shader is a line-for-line port of that
// script's `apply_anchor` operator, so the same maths runs per fragment instead,
// driven by two uniforms that come straight from the reference's `colors: [a, b]`.
//
// THE MASK IS INFERRED FROM COLOUR, NOT FROM UV LAYOUT
// The atlas has no garment zones. `protect_sat` is a saturation floor: the ivory fur
// of the spitz sits at saturation ~0.13-0.20, the garment panels sit well above it,
// so a saturation floor separates cloth from fur without a UV mask. Values are the
// measured ones from tools/character/outfits-strong.json, not re-tuned here.
//
// Set every uniform through src/character/outfit_catalogue.gd; nothing here is
// intended to be hand-tuned per outfit.

uniform sampler2D source_tex : source_color, filter_linear_mipmap, repeat_enable;

// Source anchors: the two recolourable texel families of the baked atlas.
// Deliberately NOT hinted `source_color`: that hint would linearise the value on the
// way in, and every comparison below is done in sRGB. These carry raw sRGB
// components in [0,1]; outfit_catalogue.gd feeds them as Vector3, never as Color.
uniform vec3 anchor_primary = vec3(0.1333, 0.1882, 0.2902);  // #22304a
uniform vec3 anchor_trim = vec3(1.0000, 0.7882, 0.2902);     // #ffc94a

// Targets: the reference outfit's colors[0] and colors[1], raw sRGB components.
uniform vec3 target_primary = vec3(0.1333, 0.1882, 0.2902);
uniform vec3 target_trim = vec3(1.0000, 0.7882, 0.2902);

// Mask + match tolerances. Measured defaults, see outfits-strong.json.
uniform float protect_sat = 0.22;
uniform float hue_tol_deg = 45.0;
uniform float sat_min = 0.18;
uniform float val_min = 0.02;
uniform float val_max = 0.98;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float luma_clamp_lo = 0.45;
uniform float luma_clamp_hi = 1.7;

// Reversible non-glTF PBR defaults; see AthleteRig owner decision 1.
uniform float pbr_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float pbr_roughness : hint_range(0.0, 1.0) = 0.85;

const float LUMA_EPS = 1e-4;

// Godot's `source_color` hint linearises sRGB uniforms and texture reads for us, but
// the anchor test in recolour_outfits.py classifies texels in *sRGB* HSV. Round-trip
// explicitly so the two implementations agree instead of nearly agreeing.
vec3 lin_to_srgb(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 srgb_to_lin(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// h in degrees [0,360), s and v in [0,1] — same convention as the Python tool.
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

// The Python tool's `smoothstep(x)`: clamp to [0,1] then the cubic. Kept as its own
// helper so each call site can pass the exact same normalised argument.
float ss(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

float luma_lin(vec3 lin) {
	return dot(lin, vec3(0.2126, 0.7152, 0.0722));
}

// One `apply_anchor` pass over a single texel, in sRGB. `cur` is the working colour
// (anchors compose in order, exactly as the offline tool composes them).
vec3 apply_anchor(vec3 cur, vec3 anchor_srgb, vec3 target_srgb, float mask) {
	vec3 hsv = rgb_to_hsv_deg(cur);
	vec3 anchor_hsv = rgb_to_hsv_deg(anchor_srgb);

	float dh = abs(mod(hsv.x - anchor_hsv.x + 180.0, 360.0) - 180.0);
	float w = ss((hue_tol_deg - dh) / max(hue_tol_deg, 1e-6));
	w *= ss((hsv.y - sat_min) / 0.12);
	w *= ss((hsv.z - val_min) / 0.12);
	w *= ss((val_max - hsv.z) / 0.12);
	w *= mask * strength;
	if (w <= 0.0) {
		return cur;
	}

	vec3 target_lin = srgb_to_lin(target_srgb);
	float anchor_luma = max(luma_lin(srgb_to_lin(anchor_srgb)), LUMA_EPS);
	float ratio = clamp(luma_lin(srgb_to_lin(cur)) / anchor_luma, luma_clamp_lo, luma_clamp_hi);
	return mix(cur, lin_to_srgb(target_lin * ratio), w);
}

void fragment() {
	vec3 base_srgb = lin_to_srgb(texture(source_tex, UV).rgb);

	// Fur/skin guard: near-neutral texels never move.
	float sat = rgb_to_hsv_deg(base_srgb).y;
	float mask = ss((sat - protect_sat) / 0.10);

	vec3 cur = base_srgb;
	cur = apply_anchor(cur, anchor_primary, target_primary, mask);
	cur = apply_anchor(cur, anchor_trim, target_trim, mask);

	ALBEDO = srgb_to_lin(cur);
	METALLIC = pbr_metallic;
	ROUGHNESS = pbr_roughness;
}
