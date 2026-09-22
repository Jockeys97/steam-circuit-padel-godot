## arena_look.gd — the LOOK lane: the per-arena SKY / ATMOSPHERE / LIGHTING recipe that makes
## the five world arenas read like their designed concept stills
## (`art/concepts/world-arenas-r1/*.png`), on the GL Compatibility renderer.
##
## The recipe is the one `docs/mission/arena-kit/scan/stylized-look-godot.md` derives from the
## 4.7 documentation (its Table A), restricted to what that scan's Table B proves is AVAILABLE
## in Compatibility. Its own numbers are marked `[craft]` there and stay `[craft]` here: this
## module is the "verify in-engine with a capture" half of that scan.
##
## WHAT IT TOUCHES, AND WHERE. `apply()` is called by `court_builder.gd::build_world()` with the
## nodes it has already built (`WorldEnvironment`, `Sun`, `Fill`) — the pinned node names, their
## count and their parent do not move, and NOT ONE NODE IS ADDED: the sky is a `Sky` RESOURCE on
## the existing `Environment`, and the pipeline that proves an arena's built tree is unchanged
## (`tests/arena_kit_test.gd` against `run/tmp/arena-kit/baseline.json`) therefore only sees the
## changes this lane is FOR (the `Sun`/`Fill` transforms it re-records).
##
## IT IS A NO-OP FOR THE FROZEN NINE. Every entry above the five `family: "world"` arenas keeps
## exactly the numbers `build_world()` has always written (`BG_COLOR`, ambient colour, two
## directional lights), so the nine arenas and their committed captures do not move.
##
## WHAT COMPATIBILITY CANNOT DO, and what stands in for it (Table B): no volumetric fog and no
## light shafts -> depth fog + `fog_sun_scatter` + `fog_aerial_perspective`; no SSIL / VoxelGI /
## SDFGI -> `shadow_opacity` < 1 (the documented GI fake), sky-derived ambient and SSAO; no SSR
## -> the sky radiance cubemap feeds the glass; no per-material glow -> emissive/bright albedo
## through the global glow; no debanding pass -> the dither baked into the sky panorama.
##
## THE SKY IS GENERATED, NOT IMPORTED. `sky_texture()` renders the arena's own three style stops
## (`ArenaStyle.style(id)["sky"]`, the stills' stops) into a dithered equirect `Image`, because
## (a) `ProceduralSkyMaterial` is a two-stop ramp and cannot express any of the five, and (b) a
## shipped image would need the editor's import step, which this repo's drop-in assets
## deliberately avoid (`arena_scenery.gd::_load_artwork`, `arena_kit.gd` header). It is cached
## per arena: the panorama is a pure function of (stops, apron), so it is built once per process.
##
## GROUND TEXTURE WIRING — the same fallback discipline as the kit slots (KIT-STANDARD §5):
## `res://assets/arenas/<arena>/ground_texture.png` (the image-only slot, §1) is read at RUNTIME
## and used as the ground's albedo, tiled at `GROUND_TILE_M` metres per tile. When the file is
## ABSENT — today's state of the repo — `ground_texture()` returns null, `apply_ground_texture()`
## returns false BEFORE touching the material, and the built tree and the rendered frame are
## byte-identical to the pre-look build. Nothing is `preload`ed, so an empty folder costs nothing.
extends RefCounted

const ArenaStyle := preload("res://game/arenas/arena_style.gd")
const ArenaKit := preload("res://game/arenas/arena_kit.gd")

## The image-only slot's file name inside an arena's kit folder (`ArenaKit.KIT_DIR`).
const GROUND_TEXTURE := "ground_texture.png"
## Metres of ground one tile of `ground_texture.png` covers. The swatch is a full-bleed
## paving/earth tile, authored square: 2.5 m reads at player scale on the apron and keeps the
## far ground from turning into noise (see `art/arena-kits/GROUND-TEXTURE-NOTE.md`).
const GROUND_TILE_M := 2.5
## The generated sky panorama's size. A smooth three-stop gradient needs no more, and it keeps
## the per-arena generation (once per process) in the low tens of milliseconds.
const PANORAMA_W := 256
const PANORAMA_H := 128
## Baked dither strength, as the alpha of a mid-grey noise overlay. Compatibility has no
## Debanding pass (`stylized-look-godot.md` §1.8), so the documented remedy — noise baked into
## the texture — is applied here: ~2 levels of 8-bit noise, enough to break the gradient steps
## without reading as grain.
##
## WHERE IT IS SPENT, AND WHERE IT IS NOT. Only the generated sky panorama carries it. The
## backdrop quad does NOT: a per-pixel dither on that surface would need a ~2048x1024 texture
## (the quad is ~2100 screen px wide at z = -12, so anything smaller turns the noise into
## visible blobs, and a GDScript pixel loop at that size costs seconds per build), and the
## before-captures show its 128-row gradient reading smooth at 1280x720. Recorded in LOOK.md
## as a deliberate miss rather than silently skipped.
const DITHER_ALPHA := 0.022

## THE PER-ARENA RIG. One entry per world arena; `_base()` supplies the keys an entry does not
## override. Colours are written numerically with the still's hex in the comment, because a
## `const` cannot fold a `Color("#…")` constructor.
##
## Keys: sun_rotation/color/energy/shadow_opacity, fill_color/energy, ambient_color/energy/
## sky_contribution, exposure/saturation/contrast, fog_depth (begin, end, curve), fog_color/
## energy/sun_scatter/aerial/sky_affect, glow_threshold/bloom/intensity, ssao_radius/intensity.
const LOOKS := {
	# Kyoto at dusk: the still is a low sun already at the horizon (its coral band), lanterns
	# lit against a violet sky. Long raking shadows, warm haze, the strongest glow of the five.
	"torii": {
		"sun_rotation": Vector3(-13.0, -34.0, 0.0),
		"sun_color": Color(1.0, 0.686, 0.435),        # #ffaf6f warm dusk key
		"sun_energy": 1.60,
		"shadow_opacity": 0.72,
		"fill_color": Color(0.34, 0.42, 0.72),        # #576cb8 cool violet counter-light
		"fill_energy": 0.42,
		"ambient_color": Color(0.24, 0.27, 0.46),     # #3d4575 dusk violet
		"ambient_energy": 0.85,
		"ambient_sky_contribution": 0.72,
		"exposure": 1.03,
		"saturation": 1.18,
		"adjust_contrast": 1.06,
		"fog_depth": Vector3(16.0, 220.0, 0.65),
		"fog_color": Color(0.78, 0.40, 0.28),         # #c76647 coral horizon haze
		"fog_energy": 0.85,
		"fog_sun_scatter": 0.45,
		"fog_aerial": 0.5,
		"fog_sky_affect": 0.8,
		"glow_threshold": 0.70,
		"glow_bloom": 0.15,
		"glow_intensity": 1.30,
		"ssao_radius": 2.0,
		"ssao_intensity": 1.2,
	},
	# Marrakech at golden hour: a high warm key, dust in the air, the zellige turquoise as the
	# only cool accent. Warm ambient, warm haze, no bloom on the sky (its top stop is bright).
	"medina": {
		"sun_rotation": Vector3(-17.0, -52.0, 0.0),
		"sun_color": Color(1.0, 0.80, 0.56),          # #ffcc8f clay-gold key
		"sun_energy": 1.65,
		"shadow_opacity": 0.68,
		"fill_color": Color(0.42, 0.50, 0.78),        # #6b80c7 cool sky-side fill
		"fill_energy": 0.35,
		"ambient_color": Color(0.38, 0.34, 0.40),     # #615766 warm-grey bounce
		"ambient_energy": 0.90,
		"ambient_sky_contribution": 0.70,
		"exposure": 1.00,
		"saturation": 1.12,
		"adjust_contrast": 1.04,
		"fog_depth": Vector3(20.0, 260.0, 0.70),
		"fog_color": Color(0.85, 0.60, 0.42),         # #d9996b dust-warm haze
		"fog_energy": 0.90,
		"fog_sun_scatter": 0.50,
		"fog_aerial": 0.5,
		"fog_sky_affect": 0.8,
		"glow_threshold": 0.78,
		"glow_bloom": 0.10,
		"glow_intensity": 1.15,
		"ssao_radius": 2.0,
		"ssao_intensity": 1.1,
	},
	# Rio at noon: a hard high sun, blue-green granite ridges behind a blue haze, sand and
	# painted concrete. The still is the brightest of the five: high ambient, weak glow.
	"carioca": {
		"sun_rotation": Vector3(-58.0, 24.0, 0.0),
		"sun_color": Color(1.0, 0.965, 0.90),         # #fff6e6 tropical noon key
		"sun_energy": 1.40,
		"shadow_opacity": 0.80,
		"fill_color": Color(0.52, 0.68, 0.92),        # #85addb sky bounce
		"fill_energy": 0.40,
		"ambient_color": Color(0.55, 0.68, 0.82),     # #8caed1 noon sky wash
		"ambient_energy": 0.95,
		"ambient_sky_contribution": 0.85,
		"exposure": 1.04,
		"saturation": 1.06,
		"adjust_contrast": 1.02,
		"fog_depth": Vector3(28.0, 320.0, 0.80),
		"fog_color": Color(0.80, 0.90, 0.96),         # #cce6f5 sea haze over the ridges
		"fog_energy": 0.90,
		"fog_sun_scatter": 0.25,
		"fog_aerial": 0.45,
		"fog_sky_affect": 0.85,
		"glow_threshold": 0.85,
		"glow_bloom": 0.07,
		"glow_intensity": 1.00,
		"ssao_radius": 1.8,
		"ssao_intensity": 1.0,
	},
	# Iceland at night: moonlight, snow, basalt, and the aurora ribbons as the only emissive
	# subject. The arena the glow threshold exists for — and the lowest key of the five.
	"aurora": {
		"sun_rotation": Vector3(-22.0, 32.0, 0.0),
		"sun_color": Color(0.72, 0.82, 0.98),         # #b8d1fa moon key
		"sun_energy": 0.62,
		"shadow_opacity": 0.85,
		"fill_color": Color(0.22, 0.52, 0.52),        # #387f85 cold teal fill
		"fill_energy": 0.30,
		"ambient_color": Color(0.16, 0.26, 0.34),     # #294252 night teal
		"ambient_energy": 0.62,
		"ambient_sky_contribution": 0.85,
		"exposure": 1.06,
		"saturation": 1.20,
		"adjust_contrast": 1.08,
		"fog_depth": Vector3(14.0, 170.0, 0.60),
		"fog_color": Color(0.10, 0.22, 0.28),         # #1a3847 night air
		"fog_energy": 0.80,
		"fog_sun_scatter": 0.18,
		"fog_aerial": 0.5,
		"fog_sky_affect": 0.85,
		"glow_threshold": 0.58,
		"glow_bloom": 0.16,
		"glow_intensity": 1.50,
		"ssao_radius": 2.0,
		"ssao_intensity": 1.4,
	},
	# Santorini at noon: high key, white plaster, cobalt, and the caldera haze below. Bright
	# ambient on the white masses, the second-weakest glow.
	"egeo": {
		"sun_rotation": Vector3(-56.0, -18.0, 0.0),
		"sun_color": Color(1.0, 0.98, 0.93),          # #fffaea white noon key
		"sun_energy": 1.45,
		"shadow_opacity": 0.78,
		"fill_color": Color(0.50, 0.64, 0.95),        # #80a3f2 cobalt bounce
		"fill_energy": 0.40,
		"ambient_color": Color(0.52, 0.62, 0.85),     # #859ed9 sky wash on whitewash
		"ambient_energy": 1.00,
		"ambient_sky_contribution": 0.85,
		"exposure": 1.05,
		"saturation": 1.10,
		"adjust_contrast": 1.03,
		"fog_depth": Vector3(34.0, 340.0, 0.85),
		"fog_color": Color(0.82, 0.90, 0.98),         # #d1e6fa caldera haze
		"fog_energy": 0.85,
		"fog_sun_scatter": 0.20,
		"fog_aerial": 0.40,
		"fog_sky_affect": 0.85,
		"glow_threshold": 0.84,
		"glow_bloom": 0.07,
		"glow_intensity": 1.00,
		"ssao_radius": 1.8,
		"ssao_intensity": 1.0,
	},
}

## Generated panoramas by arena id (`sky_texture()`) and loaded ground textures by path
## (`ground_texture()`), both static so a rebuild inside one process reuses them.
static var _sky_cache: Dictionary = {}
static var _ground_cache: Dictionary = {}


# ---------------------------------------------------------------------------
# The public surface
# ---------------------------------------------------------------------------

## The five arena ids this lane has a rig for, in `ArenaStyle` order.
static func ids() -> Array:
	return LOOKS.keys()


## Is this arena one of the five world decks? `Arena.build()` hands the builders the
## `Arena.info()` record, whose `family` is `"world"` for the port additions and never for the
## nine frozen rows — that is the gate `apply()` and the ground wiring both read.
static func is_world(arena: Dictionary) -> bool:
	return String(arena.get("family", "")) == "world"


## One arena's rig: its entry merged over the base values (`{}` for a non-world id).
static func look(arena_id: String) -> Dictionary:
	if not LOOKS.has(arena_id):
		return {}
	var merged := _base()
	merged.merge(LOOKS[arena_id], true)
	merged["arena"] = arena_id
	merged["sky_stops"] = ArenaStyle.style(arena_id).get("sky", [])
	merged["apron"] = Color(String(ArenaStyle.style(arena_id).get("apron", "#303030")))
	return merged


## The rig every arena starts from: the scan's Table A recommendations that are not per-arena
## taste (tonemap, adjustments, glow family, fog family, the shadow-split budget).
static func _base() -> Dictionary:
	return {
		"tonemap": Environment.TONE_MAPPER_AGX,
		"exposure": 1.0,
		"agx_contrast": 1.2,
		"adjust_brightness": 1.0,
		"adjust_contrast": 1.03,
		"saturation": 1.1,
		"ambient_sky_contribution": 0.8,
		"fog_mode": Environment.FOG_MODE_DEPTH,
		"fog_sun_scatter": 0.35,
		"fog_aerial": 0.5,
		"fog_sky_affect": 0.8,
		"glow_hdr_scale": 2.0,
		"glow_luminance_cap": 12.0,
		"shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"shadow_max_distance": 80.0,
		"fill_rotation": Vector3(-28.0, 148.0, 0.0),
		"sky_process_mode": Sky.PROCESS_MODE_QUALITY,
		"sky_radiance_size": Sky.RADIANCE_SIZE_256,
	}


## Applies one arena's atmosphere to the nodes `court_builder.gd::build_world()` keeps by
## name. Returns false — having touched NOTHING — when this is not a world arena, which is what
## holds the nine frozen decks and their evidence exactly where they are.
static func apply(env: Environment, sun: DirectionalLight3D, fill: DirectionalLight3D,
		arena: Dictionary) -> bool:
	if env == null or sun == null or fill == null or not is_world(arena):
		return false
	var id := String(arena.get("id", ""))
	if not LOOKS.has(id):
		return false
	var rig: Dictionary = look(id)

	# 1. The sky: BG_SKY plus a generated, dithered panorama. Only BG_SKY feeds
	#    `fog_aerial_perspective`, sky-derived ambient and the pane reflections.
	var sky := Sky.new()
	sky.sky_material = _panorama_material(id)
	sky.process_mode = int(rig["sky_process_mode"])
	sky.radiance_size = int(rig["sky_radiance_size"])
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# 2. Ambient: the cool side of the stills comes from the sky itself, mixed with a per-arena
	#    tint (`ambient_light_color` only bites below a sky contribution of 1.0).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = float(rig["ambient_sky_contribution"])
	env.ambient_light_color = rig["ambient_color"]
	env.ambient_light_energy = float(rig["ambient_energy"])

	# 3. Depth fog: the painted horizon band and the aerial perspective the stills have and the
	#    captures before this lane had none of. Volumetric fog is Forward+-only (Table B).
	env.fog_enabled = true
	env.fog_mode = int(rig["fog_mode"])
	var fd: Vector3 = rig["fog_depth"]
	env.fog_depth_begin = fd.x
	env.fog_depth_end = fd.y
	env.fog_depth_curve = fd.z
	env.fog_light_color = rig["fog_color"]
	env.fog_light_energy = float(rig["fog_energy"])
	env.fog_sun_scatter = float(rig["fog_sun_scatter"])
	env.fog_aerial_perspective = float(rig["fog_aerial"])
	env.fog_sky_affect = float(rig["fog_sky_affect"])

	# 4. Contact darkening. Compatibility's SSAO exposes only radius and intensity (4.6+).
	env.ssao_enabled = true
	env.ssao_radius = float(rig["ssao_radius"])
	env.ssao_intensity = float(rig["ssao_intensity"])

	# 5. Glow on an LDR buffer: the threshold has to sit below 1.0 or nothing blooms
	#    (`stylized-look-godot.md` §1.5; glow_levels/strength/blend_mode are inert here).
	env.glow_enabled = true
	env.glow_hdr_threshold = float(rig["glow_threshold"])
	env.glow_hdr_scale = float(rig["glow_hdr_scale"])
	env.glow_hdr_luminance_cap = float(rig["glow_luminance_cap"])
	env.glow_bloom = float(rig["glow_bloom"])
	env.glow_intensity = float(rig["glow_intensity"])

	# 6. Tonemap and grade. AgX keeps the magenta/coral dusk from clipping to white; the
	#    adjustments are applied AFTER tonemapping (docs) and are the stills' saturation.
	env.tonemap_mode = int(rig["tonemap"])
	env.tonemap_exposure = float(rig["exposure"])
	env.tonemap_agx_contrast = float(rig["agx_contrast"])
	env.adjustment_enabled = true
	env.adjustment_brightness = float(rig["adjust_brightness"])
	env.adjustment_contrast = float(rig["adjust_contrast"])
	env.adjustment_saturation = float(rig["saturation"])

	# 7. The light rig: a low warm key with `shadow_opacity` < 1 (the documented GI fake, since
	#    SSIL/VoxelGI/SDFGI are unavailable), a cool shadowless fill, and the two-split shadow
	#    budget the scan recommends for a bounded arena.
	sun.rotation_degrees = rig["sun_rotation"]
	sun.light_color = rig["sun_color"]
	sun.light_energy = float(rig["sun_energy"])
	sun.shadow_enabled = true
	sun.shadow_opacity = float(rig["shadow_opacity"])
	sun.directional_shadow_mode = int(rig["shadow_mode"])
	sun.directional_shadow_max_distance = float(rig["shadow_max_distance"])
	fill.rotation_degrees = rig["fill_rotation"]
	fill.light_color = rig["fill_color"]
	fill.light_energy = float(rig["fill_energy"])
	fill.shadow_enabled = false
	if id == "egeo":
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("287dc0")
		sky_material.sky_horizon_color = Color("b0d5e3")
		sky_material.ground_horizon_color = Color("b0d5e3")
		sky_material.ground_bottom_color = Color("237e9f")
		sky_material.sky_curve = 0.2
		sky.sky_material = sky_material
		env.fog_sky_affect = 0.0
		env.fog_depth_begin = 80.0
		env.fog_depth_end = 700.0
		env.fog_light_energy = 0.35
		env.fog_light_color = Color("75a1b8")
		env.ambient_light_energy = 0.65
		env.tonemap_exposure = 0.9
		env.glow_enabled = false
	return true


# ---------------------------------------------------------------------------
# The sky panorama
# ---------------------------------------------------------------------------

## The arena's sky texture: a dithered equirect rendered from its own three style stops, cached
## per arena (a pure function of the stops and the apron colour).
static func sky_texture(arena_id: String) -> Texture2D:
	if _sky_cache.has(arena_id):
		return _sky_cache[arena_id]
	if not LOOKS.has(arena_id):
		return null
	var rig := look(arena_id)
	var img := panorama_image(rig["sky_stops"], rig["apron"], PANORAMA_W, PANORAMA_H, arena_id)
	var tex := ImageTexture.create_from_image(img)
	_sky_cache[arena_id] = tex
	return tex


static func _panorama_material(arena_id: String) -> PanoramaSkyMaterial:
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = sky_texture(arena_id)
	# `filter` stays on (default): the radiance map is generated once and blurred, which is what
	# ambient and the pane reflections read. The panorama keeps its dither for the direct look.
	pano.filter = true
	return pano


## The equirect itself, exposed for the test (and for anyone re-deriving the numbers):
## `v = 0` is the zenith, `v = 0.5` the horizon, and the stops run zenith -> horizon over the
## upper half exactly as they run top -> bottom on the backdrop quad, so the sky behind the wall
## and the wall in front of it agree. Below the horizon the horizon colour sinks toward the
## arena's own apron in shadow, which is what the lower hemisphere contributes to the ambient.
static func panorama_image(stops: Array, apron: Color, w := PANORAMA_W, h := PANORAMA_H,
		seed_str := "") -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var horizon := _sample_stops(stops, 1.0)
	var nadir := apron.darkened(0.55)
	for y in h:
		var v := float(y) / float(h - 1)
		var c: Color
		if v <= 0.5:
			c = _sample_stops(stops, v / 0.5)
		else:
			c = horizon.lerp(nadir, (v - 0.5) / 0.5)
		img.fill_rect(Rect2i(0, y, w, 1), Color(c.r, c.g, c.b, 1.0))
	_bake_dither(img, w, h, seed_str)
	return img


## A three-stop gradient sampled at `t` (0.0 = the first stop), the same convention
## `court_builder.gd::gradient_texture()` uses on the backdrop quad.
static func _sample_stops(stops: Array, t: float) -> Color:
	if stops.is_empty():
		return Color(0.1, 0.1, 0.15)
	var pts: Array = []
	for stop in stops:
		pts.append([float(stop[0]), _color_of(stop[1])])
	if pts.size() == 1:
		return pts[0][1]
	var x := clampf(t, 0.0, 1.0)
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if x <= float(b[0]) or i == pts.size() - 2:
			var span := float(b[0]) - float(a[0])
			var k := 0.0 if span <= 0.0 else clampf((x - float(a[0])) / span, 0.0, 1.0)
			return (a[1] as Color).lerp(b[1] as Color, k)
	return pts[pts.size() - 1][1]


static func _color_of(value: Variant) -> Color:
	return value if typeof(value) == TYPE_COLOR else Color(String(value))


## Bakes the debanding noise: a 32x32 mid-grey sequence laid over the whole panorama at
## `DITHER_ALPHA`. Deterministic (seeded off the arena), so two runs of the same build render
## the same frame.
static func _bake_dither(img: Image, w: int, h: int, seed_str: String) -> void:
	var tile := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_str)
	var noise := Image.create_empty(tile, tile, false, Image.FORMAT_RGBA8)
	for y in tile:
		for x in tile:
			var n := rng.randf_range(-1.0, 1.0) * 0.5 + 0.5
			noise.set_pixel(x, y, Color(n, n, n, DITHER_ALPHA))
	for ty in range(0, h - tile + 1, tile):
		for tx in range(0, w - tile + 1, tile):
			img.blend_rect(noise, Rect2i(0, 0, tile, tile), Vector2i(tx, ty))


# ---------------------------------------------------------------------------
# The ground texture (the image-only kit slot)
# ---------------------------------------------------------------------------

## Where an arena's ground texture is expected, whether or not it is there.
static func ground_texture_path(arena_id: String) -> String:
	return "%s%s/%s" % [ArenaKit.KIT_DIR, arena_id, GROUND_TEXTURE]


## The arena's ground texture, or null when the slot is empty (today) — read at RUNTIME with
## `FileAccess.file_exists` + `Image.load_from_file`, the drop-in discipline of this repo: no
## `.import` step, no `preload`, and an absent file costs one `file_exists` call.
static func ground_texture(arena_id: String) -> Texture2D:
	var path := ground_texture_path(arena_id)
	if _ground_cache.has(path):
		return _ground_cache[path]
	if not ArenaStyle.is_world(arena_id) or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		push_warning("arena_look: cannot read '%s' (ground keeps its palette colour)" % path)
		_ground_cache[path] = null
		return null
	if not img.has_mipmaps():
		img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_ground_cache[path] = tex
	return tex


## TEST SEAM (mirrors `arena_kit.gd::suppress_overrides` in spirit): drops one arena's cached
## ground texture so a suite that drops a fixture file and removes it again can re-read the
## absent state in the same process. Production never calls this — a shipped swatch does not
## disappear at runtime.
static func forget_ground_texture(arena_id: String) -> void:
	_ground_cache.erase(ground_texture_path(arena_id))


## Tiles the arena's ground texture over a material whose UVs span `uv_size` metres. Returns
## false — having touched NOTHING — when the slot is empty or the arena has no kit, so the
## absent-file build is byte-identical to the pre-look one (KIT-STANDARD §5's fallback rule).
## The digested material facts (albedo colour, metallic, roughness, transparency, shading) are
## never modified: only the texture, its scaling and its filter.
static func apply_ground_texture(mat: StandardMaterial3D, arena_id: String,
		uv_size: Vector2) -> bool:
	if mat == null:
		return false
	var tex := ground_texture(arena_id)
	if tex == null:
		return false
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(
		maxf(1.0, uv_size.x / GROUND_TILE_M),
		maxf(1.0, uv_size.y / GROUND_TILE_M),
		1.0)
	# A tiled floor needs mipmaps and anisotropy: Compatibility has no roughness limiter and no
	# TAA/FXAA/SMAA, so an unfiltered repeat pattern shimmers at distance.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return true
