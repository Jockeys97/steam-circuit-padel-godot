# Stylized dusk in Godot 4 / GL Compatibility — a painted-concept-still recipe

Scan report for the Arena Kit mission (`docs/mission/arena-kit/CHARTER.md`, fog item:
"Sky strategy: procedural sky shader vs generated panorama (GL Compatibility limits matter)").

- **Engine**: Godot 4.7.2, `renderer/rendering_method="gl_compatibility"`
  (`godot/project.godot`, verified 2026-09-18).
- **Sources**: official docs, version-pinned `docs.godotengine.org/en/4.7/…`, read
  2026-09-18 (UTC 13:40). Every URL below was fetched and quoted from in this session.
- **Method**: documentation + repository source read only. **No engine run** (charter: one
  Godot process at a time; research lanes never run the engine). Values that the docs do
  not state are marked `[craft]`; claims inferred from docs rather than quoted are marked
  `[infer]`; anything that can only be settled in-engine is marked `[unverified]`.
- **Scope**: the stylized-dusk read (torii, medina, aurora especially). Same knobs apply
  to carioca/egeo, minus the warm bias.

Notation: `[doc]` = stated in the cited page. `[craft]` = art direction, no doc source.
`[infer]` = derived from a doc statement that is about a different renderer/context.

---

## 0. What the repo has today (so the delta is explicit)

Read from source, 2026-09-18:

| Where | What exists now |
|---|---|
| `godot/game/arenas/court_builder.gd:188-211` | `WorldEnvironment` with `background_mode = BG_COLOR`, `background_color = Color(0.07, 0.10, 0.16)`, `ambient_light_source = AMBIENT_SOURCE_COLOR`, `ambient_light_color = Color(0.42, 0.46, 0.55)`, `ambient_light_energy = 0.75`; `Sun` DirectionalLight3D energy 1.5, `rotation_degrees = (-62, -38, 0)`, `shadow_enabled = true`; `Fill` DirectionalLight3D energy 0.35, `rotation_degrees = (-28, 148, 0)`, shadows off |
| `godot/game/arenas/arena_scenery.gd:121-124` | the arena sky is a **flat textured quad** (`CourtBuilder.gradient_texture(style["sky"], 128)`) at `BACKDROP_Z`, not a `Sky` resource |
| `godot/game/arenas/arena_style.gd` | per-arena style: 3-stop `sky` gradient, `apron`, `glow`, props. torii `:290` `#0b1026 → #3a2350 → #e8734f`, glow `#ffb24d`. medina `:322` `#f7c884 → #e08a52 → #8f3f30`. aurora `:381` `#04060f → #0a1b33 → #123a3c`, glow `#4dffc3` |
| repo-wide grep | **no** `Sky`/`ProceduralSkyMaterial`/`PanoramaSkyMaterial`/`PhysicalSkyMaterial`, **no** `BG_SKY`, **no** `ReflectionProbe`, **no** `fog_enabled`, **no** `GPUParticles3D`/`CPUParticles3D` in `godot/game` or `godot/src` (prototypes excluded) |

Three consequences that drive everything below:

1. Without a real `Sky`, `AMBIENT_SOURCE_SKY`, `REFLECTION_SOURCE_SKY`,
   `fog_aerial_perspective` and sky-based glass reflections are all unavailable —
   the current look is constant-color ambient + two directional lights + unshaded quads.
2. A flat backdrop quad is *not* fog-reachable the way a sky is, and it does not feed the
   radiance cubemap, so reflections and aerial perspective have nothing to sample.
3. Nothing in the pipeline currently produces bloom, so lanterns cannot read as glowing.

---

## 1. WorldEnvironment recipe for a dusk look

### 1.1 Sky: three options, ranked for these arenas

Sources: `en/4.7/tutorials/3d/environment_and_post_processing.html`,
`en/4.7/classes/class_proceduralskymaterial.html`, `class_panoramaskymaterial.html`,
`class_physicalskymaterial.html`, `class_sky.html`,
`en/4.7/tutorials/shaders/shader_reference/sky_shader.html`,
`en/4.7/tutorials/rendering/renderers.html`.

| Option | Cost / availability | Fits the concept stills? |
|---|---|---|
| **`Sky` + `shader_type sky` ShaderMaterial** (recommended) | Sky shaders are documented with no Compatibility restriction `[doc]`. Max control: exact multi-stop gradient, per-pixel dither to kill banding, `sun_disk`-free look, `TIME`-free static → set `Sky.process_mode = PROCESS_MODE_QUALITY` and a small `radiance_size` | Yes. The stills are a *banded* gradient (indigo → magenta → warm), which the two-color procedural model cannot express |
| **`Sky` + `PanoramaSkyMaterial`** (recommended alt) | `panorama` = equirect image; docs "strongly recommend" HDR `.hdr`/`.exr` for accurate reflections `[doc]`; `filter` (default true) blurs; static sky ⇒ radiance map generated once | Yes, if the equirect is authored with dither baked in. Cheapest way to match a still pixel-for-pixel. Risk: an 8-bit PNG gradient will band, because Compatibility has no debanding (see 1.8) |
| **`Sky` + `ProceduralSkyMaterial`** | "lightweight shader… suited for real-time updates" `[doc]`; two colors + two curves (`sky_top_color`, `sky_horizon_color`, `sky_curve`, `ground_*`), sun disk driven by the **first four DirectionalLight3D nodes** (color/energy/direction/angular distance) `[doc]`; has `use_debanding` default **true** `[doc]` | Partly. Two-stop only — medina's gradient is inverted (bright `#f7c884` at the top), and none of the five styles is a two-stop ramp, so every arena needs either a mid band (shader) or a texture (panorama) |
| **`PhysicalSkyMaterial`** | Preetham daylight model, "substantially more realistic… but slower and less flexible", **one** sun, `use_debanding` default true `[doc]` | No. It models daytime atmospheric scattering; a stylized dusk with a magenta band is not its output |

Notes that matter whichever you pick:

- `Sky.process_mode` `PROCESS_MODE_AUTOMATIC` switches to `REALTIME` if the shader uses
  `TIME`/`POSITION` and to `INCREMENTAL` for `LIGHT_*`/uniforms `[doc]`. Our skies are
  static: force `PROCESS_MODE_QUALITY` (default 3 = `RADIANCE_SIZE_256`) so the radiance
  cubemap is generated once at high quality and then reused for ambient + reflections.
- If the shader samples `LIGHT0`, keep `DirectionalLight3D.sky_mode = SKY_MODE_LIGHT_AND_SKY`
  (default) — `SKY_MODE_SKY_ONLY` (2) is the documented way to light the sky from a light
  that must not illuminate the scene (a nice trick for a horizon glow that should not
  flatten the court) `[doc]`.
- `Environment.background_mode = BG_SKY` is required for all of this. Keeping the existing
  backdrop quad *and* adding a sky works (the quad is opaque and sits in front), and is the
  lowest-risk migration path: `[craft]` sky shader slightly *behind* the quad in color,
  quad keeps the exact still colors, sky supplies ambient/reflections/fog tint.

### 1.2 Ambient light

`Environment` (all defaults quoted from `en/4.7/classes/class_environment.html`):

- `ambient_light_source`: `AMBIENT_SOURCE_BG = 0` (default), `DISABLED = 1`,
  `COLOR = 2`, `SKY = 3` `[doc]`. For a dusk scene whose cool side must come *from the
  sky*, use `AMBIENT_SOURCE_SKY` (3) — documented as "Gather ambient light from the Sky
  regardless of what the background is."
- `ambient_light_sky_contribution` default `1.0`: 1.0 = all ambient from the sky, and the
  ambient color has **no** effect; below 1.0 the sky and the color mix `[doc]`, internally
  clamped 0–1 `[doc]`.
- `ambient_light_color` default `Color(0,0,0,1)` — "Only effective if
  `ambient_light_sky_contribution` is lower than 1.0 (exclusive)" `[doc]`.
- `ambient_light_energy` default `1.0`, same gating as the color `[doc]`.

**Recommended dusk split** `[craft]`: `ambient_light_source = AMBIENT_SOURCE_SKY`,
`ambient_light_sky_contribution = 0.75`, `ambient_light_color = Color(0.30, 0.36, 0.55)`
(cool violet-blue), `ambient_light_energy = 0.7`. That gives the warm-key / cool-fill
separation the stills show, with the cool fill actually derived from the dusk sky.
For arenas that keep `BG_COLOR` only, stay on `AMBIENT_SOURCE_COLOR` (what the repo does)
and use a similar color/energy.

### 1.3 Fog — and volumetric fog

Source: `class_environment.html`, `environment_and_post_processing.html`, `renderers.html`.

- `fog_enabled` default false; `fog_mode` `FOG_MODE_EXPONENTIAL = 0` (default) /
  `FOG_MODE_DEPTH = 1` `[doc]`. Depth mode's `fog_depth_begin` (10.0) / `fog_depth_end`
  (100.0, 0 = camera far) / `fog_depth_curve` (1.0) are "not physically accurate… useful
  when you need more artistic control" — exactly the "painted" case `[doc]`.
- `fog_light_color` default `Color(0.518, 0.553, 0.608, 1)`; `fog_light_energy` 1.0;
  `fog_density` 0.01; **`fog_sun_scatter` 0.0** — "If set above 0.0, renders the scene's
  directional light(s) in the fog color depending on the view angle. This can be used to
  give the impression that the sun is 'piercing' through the fog." `[doc]` — this is the
  single cheapest way to get the stills' warm haze direction.
- **`fog_aerial_perspective` 0.0**: above 0.0 it blends fog color toward the background
  Sky's **radiance cubemap**, requires `BG_SKY`, and has "a small performance cost" `[doc]`.
  This is the feature that makes distant silhouette hills read warm at the horizon and cold
  at the top — i.e. the concept stills' atmospheric depth. Needs a real Sky.
- `fog_sky_affect` default 1.0; "has no visual effect if `fog_aerial_perspective` is 1.0" `[doc]`.
- `fog_height` 0.0 / `fog_height_density` 0.0: density that "increase[s] fog as height
  decreases"; negative makes fog increase with height `[doc]` — use it for ground mist
  under the court rather than thickening the whole scene.
- **Volumetric fog: NOT available.** `class_environment.html`:
  "Note: Volumetric fog is only supported in the Forward+ rendering method, not Mobile or
  Compatibility." `renderers.html` agrees (Volumetric Fog ❌). With it goes every
  `volumetric_fog_*` property, `FogVolume`s, and any volumetric light shaft / god ray.

**Recommended dusk fog** `[craft]`: `fog_enabled = true`, `fog_mode = FOG_MODE_DEPTH`,
`fog_depth_begin = 18`, `fog_depth_end = 240`, `fog_depth_curve = 0.7`,
`fog_light_color = Color(0.72, 0.44, 0.34)` (warm horizon haze),
`fog_light_energy = 0.9`, `fog_sun_scatter = 0.35`, `fog_aerial_perspective = 0.5` (only
with `BG_SKY`), `fog_sky_affect = 0.8`, `fog_height_density = 0.15` with
`fog_height = 0.9`. Densities are deliberately low: fog "can cause banding to appear on the
viewport, especially at higher density levels" `[doc]`, and Compatibility banding is real
(1.8).

### 1.4 SSAO / SSIL / GI

`renderers.html` (Environment and post-processing table) and `class_environment.html`:

| Feature | Compatibility | Evidence |
|---|---|---|
| SSAO | **Supported**, since Godot 4.6 (simplified) | `renderers.html`: ✔️ Supported. `environment_and_post_processing.html`: "Since Godot 4.6, a simplified version of SSAO is available in the Compatibility renderer… **only the Radius and Intensity parameters can be adjusted**." `class_environment.html` still carries the older blanket note ("only supported in Forward+ and Compatibility") |
| SSIL | ❌ | "SSIL is only supported in the Forward+ rendering method, not Mobile or Compatibility" `[doc]` |
| VoxelGI | ❌ | table ❌ |
| SDFGI | ❌ | "SDFGI is only supported in the Forward+ rendering method, not Mobile or Compatibility" `[doc]` |
| LightmapGI | render yes, bake needs RenderingDevice | table: "⚠️ Rendering of baked lightmaps is supported. Baking requires hardware with RenderingDevice support." |
| Deb/Particle trails, SDF collision, Decals, DOF blur, SSR | ❌ | see Table B |

Consequences: with `ssao_enabled = true` only `ssao_radius` (default 1.0) and
`ssao_intensity` (default 2.0) do anything; `ssao_power`, `ssao_detail`, `ssao_horizon`,
`ssao_light_affect`, `ssao_ao_channel_affect`, `ssao_sharpness` `[infer]` are inert in
Compatibility (docs say "only Radius and Intensity"). Docs also warn SSAO only acts on
**ambient** light and to stay conservative with intensity `[doc]`.

**Recommended**: `ssao_enabled = true`, `ssao_radius = 2.0`, `ssao_intensity = 1.2`
`[craft]`. That is your only contact-shadow / crevice darkening — there is no SSIL to
bounce lantern light, so emissive lanterns will not tint their neighbours (see §3).

### 1.5 Glow / bloom

This is where Compatibility differs most, and the docs are explicit
(`class_environment.html`, `environment_and_post_processing.html`, `class_projectsettings.html`):

- Glow is **supported** `renderers.html` ("Glow ✔️ Supported"), but 4.7:
  "When using the Compatibility rendering method, glow uses a different implementation with
  some properties being unavailable and hidden from the inspector: `glow_levels/*`,
  `glow_normalized`, `glow_strength`, `glow_blend_mode`, `glow_mix`, `glow_map`, and
  `glow_map_strength`. This implementation is optimized to run on low-end devices and is
  less flexible as a result." `[doc]`
- `glow_blend_mode`: "The Compatibility renderer always uses `GLOW_BLEND_MODE_SCREEN` and
  `glow_blend_mode` will have no effect." `[doc]`
- `rendering/environment/glow/upscale_mode` "is only effective when using the Forward+ or
  Mobile rendering methods, as Compatibility uses a different glow implementation." `[doc]`

What still works in Compatibility: `glow_enabled`, `glow_hdr_threshold` (1.0),
`glow_hdr_scale` (2.0), `glow_hdr_luminance_cap` (12.0), `glow_bloom` (0.0),
`glow_intensity` (0.3) `[doc for defaults]`.

The important trap: Compatibility has **no internal HDR** — "When using the Compatibility
rendering method, internal HDR rendering is not used and the color precision is the lowest
of all rendering methods" (`3d_rendering_limitations.html`), and the renderer table lists
Color precision RGBA8 "Low dynamic range". `glow_hdr_threshold`'s default 1.0 assumes an
HDR buffer; the docs already tell us to drop below 1.0 exactly in this situation, for 2D and
for Mobile's low dynamic range: "this may need to be below 1.0 for glow to be visible. A
value of 0.9 works well in this case. This value also needs to be decreased below 1.0 when
using glow in 2D, as 2D rendering is performed in SDR." `[doc]` → applying that to a
Compatibility 3D buffer is an `[infer]`, and it is the first thing to check in-engine
`[unverified]`.

`glow_bloom` is the other documented lever: "If set to a value higher than 0, this will make
glow visible in areas darker than the glow_hdr_threshold." `[doc]`

**Recommended** `[craft, direction from doc]`: `glow_enabled = true`,
`glow_hdr_threshold = 0.75`, `glow_bloom = 0.12`, `glow_intensity = 1.2`,
`glow_hdr_scale = 2.0` (default), `glow_hdr_luminance_cap = 12.0` (default). `[infer]`:
`glow_intensity` above 1 is justified the same way the docs justify 1.5 for Mobile's lower
dynamic range. Do not spend effort on `glow_levels/*`, `glow_map`, `glow_strength` — inert.

### 1.6 Tonemapping

`class_environment.html` (ToneMapper enum) + `environment_and_post_processing.html`:

| Mode | Value | Character (doc quotes) | Verdict for a dusk still |
|---|---|---|---|
| `TONE_MAPPER_LINEAR` | 0 | "Does not modify color data… unnaturally clips bright values, causing bright lighting to look blown out. The simplest and fastest" | No — lanterns and horizon will clip |
| `TONE_MAPPER_REINHARDT` | 1 | "can appear dull and low contrast"; identical to Linear at `tonemap_white = 1.0` | No |
| `TONE_MAPPER_FILMIC` | 2 | film-like rolloff, better contrast than Reinhardt | Viable, cheapest filmic |
| `TONE_MAPPER_ACES` | 3 | "high-contrast film-like… desaturates bright values for a more realistic appearance"; multiplies values by 1.8 pre-tonemap | Viable; the classic "game look" |
| **`TONE_MAPPER_AGX`** | 4 | "adjustable film-like… Better than other tonemappers at maintaining the hue of colors as they become brighter. The slowest tonemapping option" | **Recommended** — hue preservation is what keeps a magenta/orange dusk from going white; `tonemap_agx_contrast` default 1.25 |

Numbers: `tonemap_exposure` 1.0 (default); `tonemap_white` 1.0 — docs recommend **6.0–8.0**
"for photorealistic lighting", and it "is ignored when using `TONE_MAPPER_LINEAR`" and is
superseded by `tonemap_agx_white` (default 16.29) under AgX `[doc]`.
Documented gotcha: "If you're using AgX, the mobile renderer, and HDR 2D is disabled, then
the value set here will be ignored, and a value of 2.0 will be used instead." — that note is
**Mobile-specific**; whether the Compatibility renderer clamps `tonemap_agx_white` the same
way is not stated → `[unverified]`, check in-engine before tuning it.

**Recommended** `[craft]`: `tonemap_mode = TONE_MAPPER_AGX`, `tonemap_exposure = 1.0`,
`tonemap_agx_contrast = 1.2` (below the 1.25 default for a softer painted read),
`tonemap_agx_white = 16.29` default first; only lower it after checking the Mobile-style
clamp above.

### 1.7 Colour correction, LUTs, adjustments

Supported: `renderers.html` lists **Adjustments ✔️ Supported** for Compatibility, and the
Godot 4.3 release notes name "Adjustments" and "Color correction" as Compatibility-renderer
features that made it feature-complete (`godotengine.org/releases/4.3/`, read 2026-09-18).

- `adjustment_enabled` default **false** — nothing applies until this is true `[doc]`.
- `adjustment_brightness` 1.0, `adjustment_contrast` 1.0, `adjustment_saturation` 1.0; all
  are applied **after** tonemapping, and docs explicitly say use `tonemap_exposure` (not
  brightness) to change scene brightness because it is applied before tonemapping `[doc]`.
  Contrast above 1.0 "is prone to clipping colors" `[doc]`.
- `adjustment_color_correction`: "The Texture2D or Texture3D lookup table (LUT)… Can use a
  `GradientTexture1D` for a 1-dimensional LUT, or a `Texture3D` for a more complex LUT" `[doc]`.
  3D LUT workflow: import mode must be **Texture3D**, horizontal/vertical slice counts set
  (33 for the bundled neutral template; typical sizes 17³/33³/51³/65³, odd sizes interpolate
  better), and the docs recommend a screenshot-next-to-LUT workflow in an image editor `[doc]`.
  "Color correction does not currently support HDR output" — irrelevant here, Compatibility
  is SDR anyway `[doc]`.

**Recommended dusk grade** `[craft]`: `adjustment_enabled = true`,
`adjustment_brightness = 1.0`, `adjustment_contrast = 1.03`, `adjustment_saturation = 1.12`,
and one 33³ `Texture3D` LUT per arena family (warm-lift / cool-crush) rather than per-arena
gradients — the graded look of the stills is a lift/shadow-tint, which a 1D gradient cannot
express per channel.

### 1.8 Background mode, banding, anti-aliasing (the parts that bite)

- Banding is the number-one threat to a gradient dusk on Compatibility:
  "When using the Compatibility rendering method, internal HDR rendering is not used and the
  color precision is the lowest of all rendering methods… This also applies to 2D rendering,
  where banding may be visible when using smooth gradient textures." `[doc]`
  The documented first remedy (Use Debanding) is **Forward+/Mobile only**: "If using the
  Forward+ or Forward Mobile rendering methods, enable Use Debanding in Project Settings >
  Rendering > Anti Aliasing." `[doc]`; the renderer table also lists Debanding ❌ for
  Compatibility. The documented remedy that *does* work here: "bake some noise into your
  textures… In 3D, you can also use a custom debanding shader to be applied on your
  materials. This technique works even if your project is rendered with low color precision,
  which means it will work when using the Mobile and Compatibility rendering methods." `[doc]`
  → So: dither/noise in the sky shader or in the panorama source image, plus
  `ProceduralSkyMaterial.use_debanding` (default true) if that path is used.
- `background_mode` values `[doc]`: `BG_CLEAR_COLOR` 0, `BG_COLOR` 1, `BG_SKY` 2,
  `BG_CANVAS` 3, `BG_KEEP` 4, `BG_CAMERA_FEED` 5. `BG_KEEP` is fastest but "can only be
  safely used in fully-interior scenes".
- Anti-aliasing available in Compatibility (`renderers.html`): **MSAA 3D ✔️**, SSAA ✔️,
  MSAA 2D ❌, TAA ❌, FSR2 ❌, **FXAA ❌, SMAA ❌**, screen-space roughness limiter ❌.
  `rendering/scaling_3d/mode` FSR "is only effective when using the Forward+ rendering
  method… If using an incompatible rendering method, FSR will fall back to bilinear scaling" `[doc]`,
  and supersampling is supported in bilinear mode: "Values greater than 1.0 are only valid
  for bilinear mode and can be used to improve 3D rendering quality at a high performance
  cost (supersampling)" `[doc]`.
  → MSAA 3D (`rendering/anti_aliasing/quality/msaa_3d`, default 0) is the AA lever; it is
  "only read when the project starts" (`Viewport.msaa_3d` at runtime) `[doc]`. This matters
  because there is no TAA/FXAA/SMAA to hide shadow-dither or roughness sparkle. Note the
  user-contributed-policy-free doc statement that MSAA won't AA alpha-scissor edges "unless
  alpha antialiasing is enabled in the material's properties" `[doc]` (`3d_rendering_limitations.html`).
- **Depth of field blur ❌** in Compatibility. For a painted still, the far-field softness
  must come from fog/aerial perspective and a fullscreen-quad post shader — "Custom
  post-processing with fullscreen quad ✔️ Supported" while "CompositorEffects ❌ Not
  supported" `[doc]`. That quad is also the clean place for vignette + grain + a gentle
  bloom-ish blur, all of which the stills have.

---

## 2. Lighting rig for golden hour

Source for all light properties: `en/4.7/classes/class_light3d.html`,
`class_directionallight3d.html`, `en/4.7/tutorials/3d/lights_and_shadows.html`.

### 2.1 The key (sun)

- **Angle.** `DirectionalLight3D` points along its local −Z; pitching `rotation_degrees.x`
  downward past −90° flips it past zenith. The repo's current `x = -62` is a fairly high sun
  (~28° elevation `[infer]`), i.e. late afternoon, not golden hour. For the stills' long
  raking light `[craft]`: `rotation_degrees = Vector3(-14, -38, 0)` (≈14° elevation) so the
  net and players throw long shadows across the court; yaw between roughly −20° and −50°
  keeps the shadows pointing into frame rather than at the camera.
- **Colour.** Two equivalent routes. `Light3D.light_color` default `Color(1,1,1,1)`, and
  "An overbright color can be used to achieve a result equivalent to increasing the light's
  `light_energy`" `[doc]` — in an LDR Compatibility buffer prefer staying at/under 1.0 and
  raising energy instead `[infer]`. Or `Light3D.light_temperature`, documented with the
  anchor we need: "The sun on a cloudy day is approximately 6500 Kelvin, on a clear day it is
  between 5500 to 6000 Kelvin, and **on a clear day at sunrise or sunset it ranges to around
  1850 Kelvin**." `[doc]` → `light_temperature ≈ 1800–2400` `[craft]`, which tints whatever
  `light_color` is set.
- **Energy.** `light_energy` default 1.0; it is "the light's strength multiplier (this is
  not a physical unit)" `[doc]`. The repo uses 1.5, which is a reasonable golden-hour value;
  keep 1.2–2.0 `[craft]`. (`light_intensity_lumens` only applies when
  `rendering/lights_and_shadows/use_physical_light_units` is true `[doc]` — leave that off.)
- **Shadows.** `shadow_enabled` default false; "This has a significant performance cost" `[doc]`.
  For the key light: `shadow_enabled = true`, `shadow_bias` 0.1 (default) and
  `shadow_normal_bias` 2.0 (default) — docs: prefer raising **normal** bias over bias, which
  causes peter-panning `[doc]`.
  - **Soft shadows: the PCSS path is unavailable.** "PCSS for directional lights is only
    supported in the Forward+ rendering method, not Mobile or Compatibility" `[doc]`, so
    `light_angular_distance` (the "contact-hardening"/sun-size softness control, default
    0.0, Sun ≈ 0.5) does nothing here. Softness in Compatibility comes from the constant
    `shadow_blur` (default 1.0) plus the project shadow filter quality:
    `rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality` default
    **2** ("Soft Medium" by the 0/1/2 ordering; docs name Soft Very Low, Soft Medium, Soft
    High, Soft Ultra and state the automatic blur multipliers 0.75×/1.5×/2×) `[doc]`.
    → Keep quality at 2 and leave `shadow_blur` at 1.0 `[craft]`; raising blur "can impact
    performance, make shadows appear grainy" `[doc]`.
  - `directional_shadow_mode`: `SHADOW_ORTHOGONAL = 0` fastest ("may result in blurrier
    shadows on close objects"), `SHADOW_PARALLEL_2_SPLITS = 1` compromise,
    `SHADOW_PARALLEL_4_SPLITS = 2` default and slowest `[doc]`. For a bounded arena `[craft]`:
    `SHADOW_PARALLEL_2_SPLITS` with `directional_shadow_split_1 = 0.1` (default),
    `directional_shadow_max_distance = 80` (default 100), `directional_shadow_fade_start = 0.8`
    (default); `directional_shadow_blend_splits = true` only if the seam shows — it "sacrifices
    shadow detail" and has a "moderate performance cost" `[doc]`.
  - `directional_shadow_size` is a project setting, default **4096** (`size.mobile` 2048) `[doc]`.
    Don't raise it; that is a straight cost with a steeper cliff on GL.
  - **Expect a look change when shadows are on.** "Due to limitations with older mobile
    devices, shadows are implemented using a multi-pass rendering approach so lights with
    shadows are rendered in sRGB space instead of linear space" (Compatibility renderer)
    `[doc]`. Tune the shadowed scene; don't chase Forward+ parity.
- `shadow_caster_mask` (default all layers) is the lever to keep the scenery silhouettes out
  of the shadow map if they cost too much `[doc]`.

### 2.2 The cool fill

- Keep the repo's two-directional-light structure (up to 8 DirectionalLights are allowed in
  Compatibility `[doc]`): `Fill` with `shadow_enabled = false`, cool colour
  (`Color(0.55, 0.66, 0.95)` or `light_temperature ≈ 9000 K`), energy 0.25–0.45 `[craft]`,
  pointed down-and-across from the opposite side (`rotation_degrees ≈ (-28, 148, 0)` is fine).
- Add the sky-derived ambient of §1.2 — that is the "cool fill" the stills actually show on
  the shadow side of the torii and the court glass.

### 2.3 Faking bounce light without GI — the documented toolbox

There is no SSIL, no VoxelGI, no SDFGI, and no baking (Table B). The doc-supported fakes:

1. **`shadow_opacity` < 1.0 on the key light.** "The opacity to use when rendering the
   light's shadow map. Values lower than 1.0 make the light appear through shadows. **This
   can be used to fake global illumination at a low performance cost.**" `[doc]` →
   `shadow_opacity = 0.7–0.85` `[craft]`. This is the single cheapest bounce fake and it
   directly lifts the shadowed side toward the warm key.
2. **Ambient light from the sky** (§1.2) — the documented "light can come from… Ambient
   light in the Environment" `[doc]`.
3. **A `ReflectionProbe` with `ambient_mode = AMBIENT_COLOR`** (default 1) around the court:
   `ambient_color` + `ambient_color_energy` "defines the custom ambient color energy to use
   within the ReflectionProbe's box defined by its size", blending smoothly into the rest of
   the scene `[doc]`. A warm, low-energy probe under/over the court is a local bounce source
   that ignores the sky. Watch the **2 probes per mesh** limit in Compatibility (§5).
4. **`light_specular`** (default 1.0) — set below 1.0 "to avoid unrealistic reflections when
   placing lights above an emissive surface" `[doc]`, i.e. keep lantern emissives from
   getting a fake specular hit.
5. **A second, shadowless, upward-facing low-energy DirectionalLight3D in the ground colour**
   as literal ground bounce `[craft]` — not doc-sourced, but it is the standard complement to
   (1) since directional lights do not attenuate and cost almost nothing compared with omnis
   (the Compatibility budget is 8 omni + 8 spot per mesh, 32 positional lights per frame —
   `rendering/limits/opengl/max_renderable_lights = 32`,
   `rendering/limits/opengl/max_lights_per_object = 8`, both "only effective when using the
   Compatibility rendering method" `[doc]`).

### 2.4 What is NOT in the rig

- No light projectors: "Light projector textures are only supported in the Forward+ and
  Mobile rendering methods, not Compatibility." `[doc]` → lanterns cannot throw a shaped
  gobo pattern; the lantern glow must be emissive geometry + glow.
- No PCSS anywhere (§2.1); positional `light_size` penumbra is also Forward+/Mobile only:
  "PCSS for positional lights is only supported in the Forward+ and Mobile rendering methods,
  not Compatibility." `[doc]`
- `light_indirect_energy` is documented as "Used with VoxelGI and SDFGI" `[doc]` → inert here.
- `light_volumetric_fog_energy` is inert without volumetric fog `[doc]`.
- Textured **area** lights are unavailable ("Textured area lights are not supported in the
  Compatibility renderer" `[doc]`) and the tutorial warns area lights are "the most expensive
  to render in real-time… consider using them only for cinematics"; in Compatibility only
  objects actually reached by an area light pay the cost `[doc]`. Use them only for a
  deliberate hero shot.

---

## 3. Emissive materials for lanterns and windows

Source: `en/4.7/classes/class_basematerial3d.html`,
`en/4.7/tutorials/3d/standard_material_3d.html`.

- Working properties: `emission_enabled` (default false) — "If true, the body emits light.
  Emitting light makes the object appear brighter"; `emission` colour (default black);
  `emission_energy_multiplier` (default **1.0**), "Multiplier for emitted light";
  `emission_on_uv2` (false) to read the emission texture from UV2 `[doc]`. Recommended
  `[craft]`: `emission_enabled = true`, `emission = #ffb24d` (torii glow) / `#4dffc3`
  (aurora) — i.e. reuse the arena's `glow` style key — `emission_energy_multiplier = 1.4–2.0`.
- **Emission cannot light its neighbours here.** "Emitting light… The object can also cast
  light on other objects **if a VoxelGI, SDFGI, or LightmapGI is used** and this object is
  used in baked lighting" `[doc]`, and the lights tutorial restates it: emission "does not
  affect nearby objects unless baked or screen-space indirect lighting is enabled" `[doc]`.
  VoxelGI/SDFGI/SSIL are all unavailable; LightmapGI baking needs a RenderingDevice-capable
  machine (Table B). → **Plan a shadowless `OmniLight3D` per lantern cluster** (radius 2–4 m,
  energy 0.6–1.5, no shadows, `light_specular` lowered) and respect the 8-omni-per-mesh /
  32-positional-per-frame caps: with 4 lanterns already in the torii prop list
  (`arena_style.gd:307-310`), a "one omni per pair of lanterns" rule keeps you inside budget.
  For the light pool on the court, use an unshaded additive quad — decals are unavailable
  (Table B).
- **There is no per-material glow in Godot 4 — in any renderer.** Glow is an
  `Environment`-level screen-space effect (`class_environment.html`: it is a post effect;
  `glow_map` is the only per-screen modulation and it is inert in Compatibility). So
  "lanterns glow" = emissive material + Environment glow. In Compatibility the halo will be
  weaker and always SCREEN-blended (see §1.5).
- On an LDR RGBA8 buffer, `emission_energy_multiplier` above ~2 buys nothing visible
  `[infer]` — the value clamps. Verify with `glow_hdr_threshold` 0.75 and `glow_bloom` 0.12.
- Cheaper alternative used by the stills for window grids: an **unshaded** material on the
  window quads (albedo = warm colour, `shading_mode = SHADING_MODE_UNSHADED`) plus the same
  glow. Unshaded is "the fastest" and "turns off all interactions with lights" `[doc]`,
  which for a dusk window is exactly right; add a second slightly larger, alpha-faded quad
  behind it for the halo before you spend glow budget.
- `emission_operator` (ADD/MULTIPLY) exists in 4.7 but its description did not come back in
  my class-page fetch → **gap**: read it in the editor's inspector before relying on it.

---

## 4. Atmosphere props: particles in Compatibility

Sources: `en/4.7/classes/class_gpuparticles3d.html`, `class_cpuparticles3d.html`,
`class_particleprocessmaterial.html`, `en/4.7/tutorials/3d/particles/index.html`,
`renderers.html`.

**Availability**

- **GPUParticles3D works in Compatibility.** The class page carries exactly **one** renderer
  restriction — `emit_particle()`: "only supported on the Forward+ and Mobile rendering
  methods, not Compatibility" `[doc]`. There is no statement that GPU particle simulation
  itself is unavailable, and the Godot 4.3 release notes list GPUParticles among the parts of
  the engine that got faster (`godotengine.org/releases/4.3/`, read 2026-09-18). `[infer]`
  but well grounded: plan on GPU particles, and if a target GL context misbehaves, fall back
  to CPU (below).
- **CPUParticles3D: fully available.** The class page contains **zero** occurrences of
  "Compatibility" `[doc]`. Docs: "CPU particle systems are less flexible… but they work on a
  wider range of hardware and provide better support for older devices and mobile phones…
  they are not as performant… can't render as many individual particles" `[doc]`.
- **Not available** (`renderers.html`, Other features): **Particle trails ❌** and
  **Particle SDF collision ❌**. So no ribbon trails behind motes, and
  GPUParticlesCollision/attractor-driven snow settling is out — though attractors/collision
  nodes themselves are not listed as restricted `[doc]`, only the SDF collision mode is.

**Cheap recipes** (all `[craft]` numbers on top of documented properties):

*Drifting petals (torii)* — `GPUParticles3D`:
`amount = 220`, `lifetime = 11.0`, `one_shot = false`, `fixed_fps = 30` (default),
`interpolate = true` (default), `local_coords = false`, `visibility_aabb = AABB(-16,-2,-16, 32, 10, 32)`
(docs: "Grow the box if particles suddenly appear/disappear"), `preprocess = 6.0` — with the
documented warning that preprocess "can be very expensive if set to a high number as it
requires running the particle shader a number of times equal to the `fixed_fps`… for every
second", so keep it single-digit.
Process material (`ParticleProcessMaterial`): `direction = (0,-1,0)`, `spread = 35`,
`initial_velocity_min/max = 0.4/1.1`, `gravity = (0.15,-0.5,0.05)`, `angular_velocity ±40°`,
`scale_min/max = 0.05/0.14`, `damping = 0.15`, `emission_shape = BOX` sized ~30×8×30,
`color_ramp` warm-white → petal pink.
Draw pass: `QuadMesh` + `StandardMaterial3D` with `billboard_mode = BILLBOARD_ENABLED`,
`shading_mode = SHADING_MODE_UNSHADED`, `transparency = TRANSPARENCY_ALPHA_SCISSOR`
(docs prefer scissor/alpha-test where the texture is mostly opaque-or-transparent: it is
"faster to render and doesn't suffer from transparency issues" `[doc]`), `alpha_antialiasing`
enabled if the edges matter, and `texture_filter` set explicitly.

*Drifting snow (aurora)* — two layers, both `GPUParticles3D`:
far/dense: `amount = 600`, `lifetime = 18`, `fixed_fps = 20`, tiny quads 0.02–0.05,
`initial_velocity` 0.3–0.6, `spread = 12`, `gravity = (0.05,-0.35,0.02)`;
near/sparse: `amount = 120`, `lifetime = 14`, quads 0.06–0.12, `fixed_fps = 30`,
`interpolate = true`, slight `blend_mode = BLEND_MODE_ADD` for the sparkle pass with a low
`emission` value. Two layers do the depth work that a single 1000-particle hairball cannot.

*Lantern embers / warm motes* — `amount = 40`, `lifetime = 4`, additive blend, unshaded
billboard, no gravity (`gravity = (0, 0, 0)`), `initial_velocity` 0.15–0.4 upward, driven off
the same glow colour as the lantern emissive.

Cost notes: `fixed_fps` (default 30) is the direct particle-cost dial — "note this does not
slow down the simulation of the particle system itself" `[doc]`, so halving it halves the
simulation ticks without changing the motion; `amount_ratio` (default 1.0) is the runtime
dial but "there is no performance benefit, since resources need to be allocated and processed
for the total amount of particles regardless" `[doc]` — so cut `amount` at author time and
use `amount_ratio` only for a runtime quality slider.

---

## 5. Glass, the court, and reflections in Compatibility

Sources: `renderers.html`, `class_reflectionprobe.html`, `en/4.7/tutorials/3d/reflection_probes.html`,
`class_basematerial3d.html`, `en/4.7/tutorials/3d/3d_rendering_limitations.html`.

### 5.1 What reflections you actually have

| Source | Compatibility | Note |
|---|---|---|
| Screen-space reflections | **❌ Not supported** | "SSR is only supported in the Forward+ rendering method, not Mobile or Compatibility" `[doc]` |
| Sky radiance (IBL) | ✔ | needs a real `Sky` + `Environment.reflected_light_source` (`REFLECTION_SOURCE_BG` 0 default / `DISABLED` 1 / `SKY` 2) `[doc]` |
| ReflectionProbe | ✔ **max 2 per mesh** | "when using the Compatibility renderer, up to 2 reflection probes can be applied per mesh. If more than 2 reflection probes affect a single mesh, additional probes will not be rendered" `[doc]` (the class page says "will not render any additional probes") |
| VoxelGI / SDFGI | ❌ | Table B |

Also documented and relevant: "Transparent materials won't be reflected, as they don't write
to the depth buffer… This also applies to shaders that use `hint_screen_texture` or
`hint_depth_texture`" `[doc]` — so the glass cage can never appear in another surface's
reflection in any renderer, and the `refraction_enabled` screen-texture path only shows
opaque geometry: "Refraction is implemented using the screen texture. Only opaque materials
will appear in the refraction" `[doc]`.

### 5.2 Believable glass, without SSR

The court glass already exists as alpha-blended `StandardMaterial3D` panes
(`court_builder.gd:35-60`, rear alpha 0.30–0.46 wired to `wallBounce`, side alpha 0.34).
Keep that structure; the believable-reflection levers in Compatibility are:

1. **One court-sized `ReflectionProbe`** `[craft]`:
   `size ≈ Vector3(16, 7, 26)` centred on the court, `box_projection = true` ("makes
   reflections look more correct in rectangle-shaped rooms"), `update_mode = UPDATE_ONCE`
   (default 0, "recommended for most objects"; the radiance map is generated over the
   following six frames), `enable_shadows = false` (it only makes the probe slower),
   `intensity = 0.8`, `blend_distance = 2.0`, `max_distance` sized to the probe so the
   "decrease this to improve performance" advice applies `[doc for properties]`.
   Set `cull_mask` to large objects only — "It is best to only include large objects which
   are likely to take up a lot of space in the reflection in order to save on rendering
   cost" `[doc]`. `UPDATE_ALWAYS` is the one to avoid: "ReflectionProbes render all objects
   within their cull_mask, so updating them can be quite expensive" `[doc]`.
   Remember the probe samples the **WorldEnvironment's** Environment; a per-`Camera3D`
   Environment is ignored, "which can lead to incorrect lighting within the ReflectionProbe" `[doc]`.
2. **Sky-backed reflections** (`reflected_light_source` default `REFLECTION_SOURCE_BG` with
   `BG_SKY`, or `REFLECTION_SOURCE_SKY`): the glass panes will pick up the dusk gradient,
   which is what makes them read as *present* at dusk. `Sky.radiance_size` controls the
   quality/price (default `RADIANCE_SIZE_256` = index 3) `[doc]`; with a static sky one
   `PROCESS_MODE_QUALITY` generation is enough.
3. **Material values** `[craft]` on the panes: `roughness = 0.08–0.15`, `metallic = 0.0`,
   `metallic_specular = 0.5` (doc: "not energy-conserving, so it should be left at 0.5 in
   most cases"), `specular_mode` left default; add the existing painted "reflection gradient"
   quad instead of raising energy, and consider `rim_enabled` for the pane edges
   ("Rim lighting increases the brightness at glancing angles") `[doc]`.
   **Keep a roughness floor ≥ 0.1**: the screen-space roughness limiter is **❌ not supported**
   in Compatibility `[doc]`, so very-low-roughness surfaces sparkle/alias — and there is no
   TAA/FXAA/SMAA to hide it, only MSAA 3D.

### 5.3 How much alpha-blended transparency is affordable

Documented facts to budget against:

- "Any transparency mode other than `TRANSPARENCY_DISABLED` has a greater performance impact
  compared to opaque rendering" `[doc]`; "Values other than `Mix` force the object into the
  transparent pipeline" `[doc]`.
- "In Godot, transparent materials are drawn after opaque materials. Transparent objects are
  sorted back to front **before being drawn based on the Node3D's position, not the vertex
  position in world space**. Due to this, overlapping objects may often be sorted out of
  order." `[doc]` Fixes: material `render_priority` / `GeometryInstance3D.sorting_offset`,
  "Even then, these may not always be sufficient" `[doc]`.
- "Some rendering engines feature order-independent transparency techniques… Godot currently
  doesn't provide this feature." `[doc]` → **no OIT anywhere**, so the budget is a sorting
  budget as much as a fill-rate budget.
- "Transparent objects are not rendered to the normal-roughness buffer… features that rely on
  the normal-roughness buffer will not affect transparent materials" `[doc]` (and the
  normal-roughness buffer is ❌ in Compatibility anyway).
- Escape hatches the docs endorse: alpha scissor for mostly-opaque textures (faster, no
  sorting bugs, MSAA needs `alpha_antialiasing` to AA the edges); `TRANSPARENCY_DEPTH_PRE_PASS`
  "can sometimes work (at a performance cost)" for semi-transparent regions;
  `distance_fade_mode` Pixel/Object **Dither** instead of Pixel Alpha, "which also speeds up
  rendering" `[doc]`.

**Practical budget** `[craft]`: keep the count of overlapping alpha-blended *layers* per
pixel in the low single digits. The court as built is fine (6 rear panes + 2 side walls +
rails). What will break it: full-screen glass with several panes behind one another, a
petal billboard quad drawn with alpha blend *through* that glass, and a large additive haze
card in the same pixels. Rules that follow: petals/snow → alpha scissor; haze/glow cards →
additive and pushed to the far side of the court; never stack two blended sheets with a
third blended prop between them.

---

## 6. Performance budget — and what to cut first

Documented framing: Compatibility has "Low base cost, but high scaling cost", is aimed at
"older mobile devices, or older desktop devices", and its advanced features are "❌ No"
(`renderers.html`). Hard ceilings in Compatibility (all "only effective when using the
Compatibility rendering method" `[doc]`):

| Ceiling | Value |
|---|---|
| `rendering/limits/opengl/max_lights_per_object` | 8 omni + 8 spot per mesh |
| `rendering/limits/opengl/max_renderable_lights` | 32 positional lights per frame ("If more lights than this number are used, they will be ignored") |
| `rendering/limits/opengl/max_renderable_elements` | 65536 |
| ReflectionProbes per mesh | 2 |
| DirectionalLights | 8 |
| `rendering/limits/global_shader_variables/buffer_size` | "most mobile devices (and all web exports) will be limited to a maximum size of 1024" |
| Shadow atlas | `positional_shadow/atlas_size` 4096 (mobile 2048), `directional_shadow/size` 4096 (mobile 2048) |

Cost ranking for these arenas, most expensive first `[infer, from doc properties]`:

1. **Shadows on a light, in Compatibility** — multi-pass, plus the documented sRGB-space
   behaviour change (`lights_and_shadows.html`). One shadowed directional light, positional
   lights unshadowed, is the whole rig.
2. **`ReflectionProbe` with `UPDATE_ALWAYS`** — "render all objects within their cull_mask,
   so updating them can be quite expensive" `[doc]`.
3. **Transparent overdraw** — sorting + blending, no OIT.
4. **Particles** — governed by `amount` and `fixed_fps`; `preprocess` is documented as a
   spike ("can be very expensive").
5. **Glow** — a Compatibility-specific cheaper chain `[doc]`, but still a mip/blur pass on an
   already fill-limited renderer; keep `glow_bloom` low (it "sends the whole screen to the
   glow processor at higher amounts" per the glow tutorial prose).
6. **SSAO** — the Compatibility version is "significantly better" than Forward+ on low-end
   devices `[doc]`, so it is attractive; it still costs a depth-based pass.
7. **`fog_aerial_perspective` > 0** — "a small performance cost when set above 0.0" `[doc]`.
8. **MSAA 3D / supersampling** — MSAA is "significantly cheaper" than supersampling `[doc]`,
   but "can be significantly slower on some hardware, especially integrated graphics due to
   their limited memory bandwidth" `[doc]`.

**Cut order when a dusk arena misses frame budget** `[craft]`:

1. `ReflectionProbe.update_mode` → `UPDATE_ONCE`, then shrink `max_distance`/`cull_mask`.
2. Unshadow the Fill, then drop `shadow_opacity` tweak-first? No — keep `shadow_opacity`
   (it is cheaper than shadows, not more expensive); instead reduce `ssao_radius` to 1.0.
3. Convert every particle billboard and petal quad to `TRANSPARENCY_ALPHA_SCISSOR`.
4. Halve particle `amount` on the dense layers and drop their `fixed_fps` 30 → 20.
5. `fog_aerial_perspective = 0.0`, raise `fog_density`/lower `fog_depth_end` to keep depth
   (lose the sky-tinted haze, keep the flattening).
6. `msaa_3d` 4× → 2× → off (project setting, needs a restart; `Viewport.msaa_3d` at runtime).
7. Shadows: `directional_shadow_mode = SHADOW_ORTHOGONAL`,
   `directional_shadow_max_distance = 50`, or disable shadows on the far arenas (aurora/egeo)
   where the concept still is mostly silhouette + glow.
8. Last resort: `rendering/scaling_3d/scale = 0.85` with bilinear mode (FSR is unavailable —
   it "will fall back to bilinear scaling" `[doc]`).

An order that preserves the *painted* read best: keep glow, SSAO and the sky; sacrifice
shadow resolution, reflection-probe updates, particle counts, then supersampling. Never
sacrifice the sky — with `BG_SKY` gone, ambient, reflections, aerial perspective and the
gradient all vanish at once.

---

## Table A — settings to apply (dusk arena, GL Compatibility)

Values are `[craft]` unless marked; every property name is from the 4.7 class reference.

| # | Node / setting | Value | Why |
|---|---|---|---|
| 1 | `Sky.sky_material` | `ShaderMaterial` (`shader_type sky`) **or** `PanoramaSkyMaterial` with a dithered equirect. Avoid `ProceduralSkyMaterial` for the 3-stop styles | Two-stop procedural cannot express torii `#0b1026→#3a2350→#e8734f` or medina's inverted ramp; sky shaders carry no documented Compatibility restriction |
| 2 | `Sky.process_mode` / `radiance_size` | `PROCESS_MODE_QUALITY`; 256 | Static sky → one high-quality radiance generation `[doc]` |
| 3 | `Environment.background_mode` | `BG_SKY` | Only mode that feeds `fog_aerial_perspective` `[doc]`; keep the existing backdrop quad in front for exact colours |
| 4 | `ambient_light_source` | `AMBIENT_SOURCE_SKY` (3), else `COLOR` (2) | Cool fill straight from the dusk sky `[doc]` |
| 5 | `ambient_light_sky_contribution` / `_color` / `_energy` | 0.75 / `Color(0.30,0.36,0.55)` / 0.7 | Warm-key vs cool-fill split; colour only bites below 1.0 `[doc]` |
| 6 | `fog_enabled`, `fog_mode` | true, `FOG_MODE_DEPTH` | Depth fog = documented "more artistic control" `[doc]` |
| 7 | `fog_depth_begin/end/curve` | 18 / 240 / 0.7 | Painted haze band, silhouettes at the far end |
| 8 | `fog_light_color` / `fog_light_energy` | `Color(0.72,0.44,0.34)` / 0.9 | Warm horizon haze; low density to limit banding `[doc]` |
| 9 | `fog_sun_scatter` | 0.35 | Doc: fakes the sun "piercing" the fog `[doc]` |
| 10 | `fog_aerial_perspective` / `fog_sky_affect` | 0.5 / 0.8 | Sky-tinted distance haze; small documented cost `[doc]` |
| 11 | `ssao_enabled` / `ssao_radius` / `ssao_intensity` | true / 2.0 / 1.2 | Only these two SSAO knobs exist in Compatibility `[doc]` |
| 12 | `glow_enabled` / `glow_hdr_threshold` / `glow_bloom` / `glow_intensity` | true / 0.75 / 0.12 / 1.2 | LDR buffer `[doc]`; threshold <1 mirrors the documented Mobile/2D advice `[infer]` |
| 13 | *inert in Compatibility* | `glow_levels/*`, `glow_strength`, `glow_blend_mode`, `glow_mix`, `glow_map`, `glow_map_strength`, `glow_normalized` | Don't spend time here `[doc]` |
| 14 | `tonemap_mode` | `TONE_MAPPER_AGX` (4) | Best hue retention as lanterns blow out `[doc]`; `tonemap_agx_contrast` 1.2 (default 1.25) |
| 15 | `tonemap_exposure` | 1.0 | Cheaper/safer than `adjustment_brightness` for scene brightness `[doc]` |
| 16 | `adjustment_enabled` | **true** (default false) | Nothing in `adjustment_*` applies otherwise `[doc]` |
| 17 | `adjustment_contrast` / `adjustment_saturation` | 1.03 / 1.12 | Applied after tonemapping `[doc]` |
| 18 | `adjustment_color_correction` | one 33³ `Texture3D` LUT (import as Texture3D, 33 slices) per arena family | Per-channel lift/shadow tint; 1D gradient can't do it `[doc]` for mechanics |
| 19 | `Sun.rotation_degrees` | `(-14, -38, 0)` | ≈14° elevation = golden hour; today's `-62` is late afternoon |
| 20 | `Sun.light_temperature` (or `light_color`) | 1800–2400 K (or `#ffb27a`) | Doc anchor: sunset sun ≈ 1850 K `[doc]` |
| 21 | `Sun.light_energy` | 1.2–2.0 (1.5 now) | Non-physical multiplier `[doc]` |
| 22 | `Sun.shadow_enabled` + `shadow_opacity` | true + **0.75** | `shadow_opacity<1` is the doc's cheap GI fake `[doc]` |
| 23 | `Shadow bias` | `shadow_bias` 0.1, `shadow_normal_bias` 2.0 (defaults) | Prefer normal bias over bias `[doc]` |
| 24 | `directional_shadow_mode` / `max_distance` / `fade_start` | `SHADOW_PARALLEL_2_SPLITS` / 80 / 0.8 | Trade the 4-split default for cost `[doc]` for modes |
| 25 | `directional_shadow/blend_splits` | false unless a seam shows | "sacrifices shadow detail", moderate cost `[doc]` |
| 26 | `directional_shadow/soft_shadow_filter_quality` | 2 (Soft Medium, default) | PCSS is unavailable, so this is the softness dial `[doc]` |
| 27 | `Fill` light | second `DirectionalLight3D`, `shadow_enabled = false`, `light_temperature ≈ 9000`, energy 0.25–0.45 | Cool shadow-side separation; up to 8 dir lights allowed `[doc]` |
| 28 | optional ground-bounce light | shadowless `DirectionalLight3D` pointing up, warm, energy 0.1–0.25 | Fake bounce without GI `[craft]` |
| 29 | `ReflectionProbe` (court) | `box_projection = true`, `update_mode = UPDATE_ONCE`, `intensity = 0.8`, `blend_distance = 2.0`, `enable_shadows = false`, cull mask = large objects only | ≤2 probes per mesh in Compatibility `[doc]` |
| 30 | `ReflectionProbe.ambient_mode` | `AMBIENT_COLOR` with a warm `ambient_color`, `ambient_color_energy` 0.2–0.6 | Local bounce fill inside the probe box `[doc]` |
| 31 | lantern/window material | `emission_enabled = true`, `emission` = arena `glow` key, `emission_energy_multiplier` 1.4–2.0, windows `shading_mode = UNSHADED` | Emission is the only per-material glow control `[doc]` |
| 32 | lantern light pools | shadowless `OmniLight3D`, radius 2–4 m, energy 0.6–1.5, `light_specular` ≈ 0.3; ≤8 omnis per mesh, ≤32 positional lights/frame | Emission cannot light neighbours here `[doc]` |
| 33 | glass panes | `TRANSPARENCY_ALPHA`, `roughness` 0.08–0.15, `metallic` 0.0, `metallic_specular` 0.5, rear alpha 0.30–0.46 as today | Existing look; keep a roughness floor (no roughness limiter, no TAA) |
| 34 | petals / snow quads | `TRANSPARENCY_ALPHA_SCISSOR`, `shading_mode = UNSHADED`, `billboard_mode = BILLBOARD_ENABLED` | Faster, no transparent-sorting bugs `[doc]` |
| 35 | particles | `GPUParticles3D`, `amount` trimmed at author time, `fixed_fps` 20–30, `interpolate = true`, `preprocess` ≤ 6–12, `visibility_aabb` grown to the drift volume | Only `emit_particle()` is restricted in Compatibility `[doc]`; preprocess is a documented spike |
| 36 | project AA | `msaa_3d = 2` or `4`; `scaling_3d/mode` stays bilinear; use `scaling_3d/scale > 1.0` only for hero captures | MSAA 3D and SSAA are the only AA available `[doc]` |
| 37 | banding mitigation | noise/dither baked into the sky shader or the panorama image | Project-level Use Debanding is Forward+/Mobile only `[doc]` |
| 38 | "painted" finish | one fullscreen-quad `ColorRect` shader: vignette + grain + gentle blur + edge warmth | `CompositorEffects` unavailable, fullscreen-quad post-processing is supported `[doc]` |

## Table B — NOT available in GL Compatibility → use this instead

| Not available | Evidence | Use instead |
|---|---|---|
| **Volumetric fog**, `FogVolume`s, volumetric light shafts / god rays | `class_environment.html`: "Volumetric fog is only supported in the Forward+ rendering method, not Mobile or Compatibility"; renderers table ❌ | Depth/exponential fog + `fog_sun_scatter` + `fog_aerial_perspective`; additive unshaded haze cards; glow as a stand-in for bloom-in-air |
| **SSIL** (screen-space indirect lighting) | "SSIL is only supported in the Forward+ rendering method, not Mobile or Compatibility" `[doc]` | `shadow_opacity` < 1 `[doc]`; sky ambient; `ReflectionProbe` `AMBIENT_COLOR`; a shadowless upward bounce light |
| **VoxelGI / SDFGI** | both ❌ in the renderers table; SDFGI note `[doc]` | same as above; `LightmapGI` **rendering** is supported for static geometry (baking needs a RenderingDevice machine) `[doc]` |
| **SSR** (screen-space reflections) | "SSR is only supported in the Forward+ rendering method, not Mobile or Compatibility" `[doc]` | `ReflectionProbe` (≤2/mesh); sky radiance via `reflected_light_source`; painted reflection-gradient quads on the panes |
| **Decals** | renderers table ❌ | unshaded quads / meshes for lantern light pools on the court |
| **Depth of field blur** | renderers table ❌ | fog-density depth cue + fullscreen-quad post shader blur |
| **CompositorEffects** | renderers table ❌ | "Custom post-processing with fullscreen quad ✔️ Supported" `[doc]` |
| **Per-material glow** (any renderer) + `glow_map` in Compatibility | glow is an Environment effect; `glow_levels/*`, `glow_strength`, `glow_blend_mode`, `glow_mix`, `glow_map`, `glow_map_strength`, `glow_normalized` are inert in Compatibility `[doc]` | Emission + a *global* glow with `glow_bloom` and a sub-1.0 `glow_hdr_threshold`; a second faded unshaded quad for a per-prop halo |
| **PCSS soft shadows** (directional and positional) | "PCSS for directional lights is only supported in the Forward+…, not Mobile or Compatibility"; "PCSS for positional lights is only supported in the Forward+ and Mobile…, not Compatibility" `[doc]` | constant `shadow_blur` + project `soft_shadow_filter_quality`; accept hard-ish shadows (which suit the stylized look) |
| **Light projector textures** | "Light projector textures are only supported in the Forward+ and Mobile rendering methods, not Compatibility" `[doc]` | emissive geometry + glow; textured quads; AreaLight3D only for hero shots |
| **Textured area lights** | "Textured area lights are not supported in the Compatibility renderer" `[doc]` | plain `AreaLight3D` (sparingly) or an omni + emissive prop |
| **TAA, FSR2, FXAA, SMAA, MSAA 2D** | renderers table (Antialiasing) ❌ for each; MSAA 3D and SSAA ✔️ | `msaa_3d`; `scaling_3d/scale > 1.0` in bilinear mode (SSAA); `alpha_antialiasing` on scissor materials |
| **Screen-space roughness limiter** | renderers table ❌ | roughness floor ~0.1–0.2 on glossy materials; MSAA; avoid mirror-smooth panes |
| **Project-level Debanding** (`rendering/anti_aliasing/quality/use_debanding`) | debanding is applied only for Forward+/Mobile; renderers table ❌ for Compatibility | noise/dither baked into the sky texture or a custom debanding shader in materials (explicitly documented as working on Compatibility) `[doc]` |
| **HDR: internal HDR rendering, 2D HDR viewport, HDR output** | renderers table: Color precision RGBA8 "Low dynamic range", "2D HDR Viewport ❌", "HDR output ❌"; "internal HDR rendering is not used" `[doc]` | author emission and light energy for a 0–1 buffer; use glow + adjustments for the "HDR look" instead |
| **Particle trails** | renderers table ❌ | short-lived quads / a second particle pass |
| **Particle SDF collision** | renderers table ❌ | keep snow from settling (aesthetic choice) or hand-place ground snow; non-SDF attractor/collision nodes are not listed as restricted `[doc]` |
| **Shader: normal/roughness buffer, compute shaders** | renderers table ❌ | screen texture and depth texture **are** supported `[doc]` — that is enough for refraction-style tricks on opaque backgrounds |
| **Order-independent transparency** | "Godot currently doesn't provide this feature" `[doc]` | alpha scissor / dither fade; `render_priority` + `sorting_offset`; keep blended layers few |

---

## 7. Uncertainty, contradictions, and what only an engine run can settle

1. **`glow_hdr_threshold` in a Compatibility 3D buffer.** The docs state the sub-1.0
   requirement for Mobile's low dynamic range and for SDR 2D, and state that Compatibility
   is LDR — but never state the threshold rule for Compatibility 3D. My 0.75 is an `[infer]`.
   Test: set threshold 1.0 vs 0.75 with one emissive lantern on screen.
2. **`tonemap_agx_white` under AgX in Compatibility.** The documented "ignored → 2.0" note is
   Mobile-specific; Compatibility is not mentioned. `[unverified]`.
3. **Sky-shader subpasses** (`use_half_res_pass`, `use_quarter_res_pass`) carry no documented
   Compatibility restriction, but I did not verify them in-engine. Keep the dusk sky
   single-pass and static.
4. **Fog on unshaded materials.** The repo leans on unshaded props, and `StandardMaterial3D`
   exposes "Disable Fog" (`fog_disabled`), which implies fog applies by default. The only
   Compatibility-specific evidence I found is open bug godotengine/godot#115018
   ("Compatibility Renderer: Fog not disabled when using Display Unshaded", opened 2026-01-16,
   open, reproducible in 4.5.1/4.6.rc1) — but that report is about the **editor's Display
   Unshaded debug view mode**, not the material flag. Treat "fog applies to unshaded props in
   Compatibility" as probable and "the material Disable Fog flag works there" as `[unverified]`.
5. **Doc-page drift.** The renderer comparison table is authoritative for availability, and
   it contradicts two prose pages: `class_environment.html` still says SSAO is "only supported
   in the Forward+ and Compatibility rendering methods" without the "simplified since 4.6"
   caveat that `environment_and_post_processing.html` gives; and `class_directionallight3d.html`
   carries no notes at all. Where they disagree, trust `renderers.html` + the tutorial page.
6. **Misreadable note (resolved here):** in `class_projectsettings.html` the note "MSAA is
   only supported in the Forward+ and Mobile rendering methods, not Compatibility" attaches to
   `rendering/anti_aliasing/quality/msaa_2d` (default 0), which is immediately before
   `.../msaa_3d` (default 0). **MSAA 3D is supported in Compatibility; MSAA 2D is not.**
   Anyone grepping the file for "msaa_3d" will see that note on the line above and could
   conclude the opposite.
7. **`emission_operator`** description did not come through in my fetch of
   `class_basematerial3d.html` → read it in the inspector before wiring ADD/MULTIPLY.
8. **`High dynamic range lighting` tutorial** is flagged on-page as "not yet updated for
   Godot 4.7 and may be outdated" — I used it for background only and cited nothing
   Compatibility-specific from it.
9. **No engine run.** Every number labelled `[craft]`/`[infer]` needs a capture to confirm;
   the charter's proof path for this is an in-engine capture pair (concept still vs frame)
   reviewed by the council, not this scan.

## 8. Sources (all fetched 2026-09-18)

Engine context:
- https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html — feature comparison table (SSAO ✔️, glow ✔️, adjustments ✔️, volumetric fog/SSR/SSIL/VoxelGI/SDFGI/debanding/DOF/decals/trails ❌, RGBA8 LDR color precision)
- https://godotengine.org/releases/4.3/ — "Compatibility rendering backend… is now considered feature complete. Keywords… MSAA, Resolution scaling, Glow, ReflectionProbes, LightmapGI, Adjustments, Color correction"

Environment:
- https://docs.godotengine.org/en/4.7/classes/class_environment.html — every default and Compatibility note in §1
- https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html — SSAO-since-4.6 + only Radius/Intensity in Compatibility, glow section, fog section, LUT workflow, "adjustments after tonemapping"
- https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html — Compatibility-only limits, shadow sizes/filter quality, `use_debanding`, `scaling_3d`, glow upscale_mode

Sky:
- https://docs.godotengine.org/en/4.7/classes/class_sky.html
- https://docs.godotengine.org/en/4.7/classes/class_proceduralskymaterial.html
- https://docs.godotengine.org/en/4.7/classes/class_panoramaskymaterial.html
- https://docs.godotengine.org/en/4.7/classes/class_physicalskymaterial.html
- https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/sky_shader.html

Lights:
- https://docs.godotengine.org/en/4.7/classes/class_light3d.html — PCSS notes, `light_temperature` sunset ≈ 1850 K, `shadow_opacity` GI fake, projector restriction
- https://docs.godotengine.org/en/4.7/classes/class_directionallight3d.html — shadow modes/splits/fade
- https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html — Compatibility 8+8 per mesh, sRGB-space multi-pass shadows note, shadow filter/blur behaviour, area-light limits

Materials, reflections, transparency:
- https://docs.godotengine.org/en/4.7/classes/class_basematerial3d.html — emission family, transparency/blend, refraction, specular
- https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html — unshaded, disable fog, specular modes
- https://docs.godotengine.org/en/4.7/classes/class_reflectionprobe.html — 2-per-mesh Compatibility limit, ambient_mode, update modes
- https://docs.godotengine.org/en/4.7/tutorials/3d/reflection_probes.html — same limit restated
- https://docs.godotengine.org/en/4.7/tutorials/3d/3d_rendering_limitations.html — banding on Compatibility, transparency sorting, no OIT, normal-roughness buffer, alpha scissor/dither advice

Particles:
- https://docs.godotengine.org/en/4.7/classes/class_gpuparticles3d.html — `emit_particle()` Forward+/Mobile only, `visibility_aabb`, `fixed_fps`, `amount_ratio`, `preprocess`
- https://docs.godotengine.org/en/4.7/classes/class_cpuparticles3d.html — no Compatibility notes
- https://docs.godotengine.org/en/4.7/classes/class_particleprocessmaterial.html — no Compatibility notes
- https://docs.godotengine.org/en/4.7/tutorials/3d/particles/index.html

Bug tracker:
- https://github.com/godotengine/godot/issues/115018 — "Compatibility Renderer: Fog not disabled when using Display Unshaded", open, created 2026-01-16, updated 2026-02-22 (about the editor debug view mode)

Repo sources read (read-only): `godot/project.godot`; `godot/game/arenas/court_builder.gd:35-60,188-211`;
`godot/game/arenas/arena_scenery.gd:121-124,348-380`; `godot/game/arenas/arena_style.gd:283-410`;
`art/concepts/world-arenas-r1/01-torii.png` (visual read).
