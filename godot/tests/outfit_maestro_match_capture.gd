extends SceneTree
## Render harness for the Maestro outfits IN THE REAL MATCH SCENE.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path godot \
##     --script res://tests/outfit_maestro_match_capture.gd
##
## Modelled on `res://tests/outfit_fiamma_match_capture.gd`, which is the accepted
## precedent for "the outfit reaches the court": it instantiates the real
## `res://game/Match.tscn`, replaces the athlete view with the real
## `res://game/athletes_view.gd`, spawns rigs through the documented factory
## `AthleteSpawn.make()`, drives them through the match's own `_sync_views()` and
## saves the framebuffer.
##
## WHAT THIS ADDS OVER THE FIAMMA HARNESS. Maestro is the profile that needs the
## per-family VALUE gate (`value_gate_enabled`, see
## `src/character/outfit_region_recolour.gdshader`): its two atlas families are
## 20.0 deg apart in hue under a 42 deg tolerance, so the hue test alone collapses
## the six slots onto one colour per region. The gate is therefore the one thing
## that makes these three outfits read as three outfits, and a capture that did not
## read the gate back off the live GPU material would not prove it was on. So the
## four rigs on court are read back through `OutfitCatalogue.read_back()` and the
## gate uniforms are read off `AthleteRig.get_catalogue_surface()`, and the run
## FAILS if a profiled outfit is on court with the gate off.
##
## WHY THERE ARE THREE IMAGES. The first version of this harness saved only the
## whole-court frame, and that frame was read by a human as "four athletes, two
## pairs, I cannot tell which outfits they wear". Both readings were true, and
## neither was a defect in the integration:
##   * the match camera is 27.5 m back at fov 30, so an athlete is ~80 px tall in
##     1280x720 and his torso panel is ~15 px wide;
##   * the authored variants share their sleeves and their shorts cut, so the
##     panels that carry the outfit are a fraction of an already small figure.
##   * the two Maestro of a pair stand ~6 m apart (measured), so pulling the
##     camera in far enough to frame them together only reaches ~250 px per
##     athlete — better, still not something an outfit can be judged from.
## So this harness saves:
##   * `maestro-match-wide.png` — the match's own camera, untouched: the four rigs
##     and the four states in the real scene, at the size the game draws them.
##   * `maestro-match.png`      — the PROOF: two panels, each a render of the SAME
##     real scene (same `Match.tscn`, same rigs, same materials, same view sync)
##     through a second camera framed on ONE Maestro, composed in-engine at
##     capture size and labelled with the outfit read back off that rig. Each
##     panel is a whole frame of the real world; nothing is cropped and nothing is
##     composited outside Godot.
##   * `maestro-match-all-base.png` — the control frame behind the pixel test.
##
## FOUR RIGS, FOUR STATES. All four slots are Maestro so that the three authored
## variants and the untouched `base` are visible in one frame:
##   player       -> circuit
##   playerMate   -> legend
##   opponent     -> signature
##   opponentMate -> base      (the rig's own material, per the profile's design)
##
## No saved settings are touched: this is a staged visual fixture over the real
## scene, exactly like the Fiamma harness. It exits non-zero on any failed
## assertion.
##
## Real rendering only: run WITHOUT `--headless`, because a headless Godot has no
## framebuffer for `root.get_texture()`.
##
## Args (optional):
##   --out=PATH   proof output PNG, relative to the repo root or absolute.
##                Default: docs/agent-work/outfits-3d/evidence/maestro-match.png
##                The other two are written next to it as `<out>-wide.png` and
##                `<out>-all-base.png`.

const View := preload("res://game/athletes_view.gd")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const Config := preload("res://game/match_config.gd")

const ATHLETE := "maestro"
const DEFAULT_OUT := "docs/agent-work/outfits-3d/evidence/maestro-match.png"

## The Match scene reads and writes prefs through `Config.save_store()`, which
## points at the real profile (`user://save`) unless it is moved. A visual harness
## must not do that, so the store is pointed at a scratch directory and removed at
## the end. (The Fiamma harness predates this and writes the real
## `user://save/prefs.json` on every run; this one does not.)
const SAVE_DIR := "user://maestro-match-capture"

## role -> the outfit that role must be wearing on court.
const LINEUP_OUTFITS := {
	"player": &"circuit",
	"playerMate": &"legend",
	"opponent": &"signature",
	"opponentMate": &"base",
}

## The three outfits the profile authors. `base` is deliberately absent: it is the
## rig's own material and carries no shader, so there is no gate to read.
const PROFILED := ["circuit", "legend", "signature"]

## The two Maestro the proof is made of: the near pair, wearing two different
## authored outfits. Order is the panel order, left to right.
const PROOF_ROLES := ["player", "playerMate"]

## One panel of the proof image, in pixels. Two of them side by side are exactly
## the 1280x720 the rest of this harness captures at, so the composed image is
## shown 1:1 and never resampled on its way into the saved frame.
const PANEL := Vector2i(640, 720)
## How much of a panel's half-fov one athlete may occupy. Below 1 leaves the top
## and bottom strips free for the labels; 0.63 measures out at ~400 px of athlete
## in a 720 px panel (against the ~80 px the whole-court frame gives him) with his
## head clear of the label block.
const PANEL_FILL := 0.63

## How far apart two outfits' repainted pixels must be, in 0..441 RGB distance, for
## the frame to count as showing two outfits rather than one. Measured values are
## printed; this is the floor that makes "two different outfits" an assertion and
## not an adjective.
const MIN_OUTFIT_COLOUR_DISTANCE := 60.0
## Repainted pixels a proof role must show in its panel before the comparison means
## anything.
const MIN_REPAINTED_PIXELS := 400
## An athlete must be at least this fraction of his panel's height to count as
## "clearly visible" — the defect this rewrite exists to fix was legibility, so
## legibility is measured rather than asserted.
const MIN_ATHLETE_HEIGHT_FRACTION := 0.45

var _failures := 0


func _initialize() -> void:
	call_deferred("run")


func _check(condition: bool, what: String) -> void:
	if condition:
		print("ok   %s" % what)
		return
	_failures += 1
	printerr("FAIL %s" % what)


func _out_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.substr("--out=".length())
	return DEFAULT_OUT


## A repo-root-relative path (the documented default) or an absolute one, resolved
## to a real filesystem path. `res://` is `godot/`, so its parent is the repo root.
func _resolve(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://../%s" % path)


func run() -> void:
	_cleanup()
	Config.save_dir = SAVE_DIR
	# The profile must exist before anything is rendered: without it all four
	# states fall back to the same baked material and the capture is four
	# identical frames of the base look, which is an empty result dressed as
	# evidence.
	_check(Catalogue.has_profile(StringName(ATHLETE)),
		"the maestro profile exists in OUTFIT_PROFILES")
	var gate := Catalogue.profile_value_gate(StringName(ATHLETE))
	_check(bool(gate.get("enabled", false)),
		"the maestro profile declares an ENABLED value gate")
	print("MEASURED gate=%s" % JSON.stringify(gate))

	# The mask must be a first-class IMPORTED resource, not merely a file Godot
	# can read off disk. `OutfitCatalogue.profile_mask()` falls back to
	# `Image.load_png_from_buffer` when the importer has not run, which hides a
	# missing `.import` in an editor session and breaks on a clean checkout or an
	# export. This is the assertion that the fallback is not what is being used.
	var mask_path := String(Catalogue.profile(StringName(ATHLETE)).get("mask", ""))
	_check(ResourceLoader.exists(mask_path),
		"the region mask is an imported resource (%s)" % mask_path)
	var imported_mask: Texture2D = load(mask_path) as Texture2D
	_check(imported_mask != null, "the imported mask loads as a Texture2D")
	if imported_mask != null:
		print("MEASURED mask=%s size=%dx%d class=%s path=%s"
			% [mask_path, imported_mask.get_width(), imported_mask.get_height(),
				imported_mask.get_class(), imported_mask.resource_path])
	_check(FileAccess.file_exists(mask_path + ".import"),
		"the mask carries a .import file on disk")
	_check(Catalogue.profile_mask(StringName(ATHLETE)) != null,
		"OutfitCatalogue hands the mask to the shader")
	if _failures > 0:
		printerr("refusing to render: the maestro profile is not in place")
		_cleanup()
		quit(1)
		return

	var game = load("res://game/Match.tscn").instantiate()
	game.engine_driven = false
	root.add_child(game)
	await process_frame

	# Staged visual fixture: the real Match scene and its normal view sync, with
	# four Maestro rigs wearing four independent states. No saved settings touched.
	game._athletes.free()
	var view := View.new()
	game.add_child(view)
	game._athletes = view
	var lineup: Dictionary = game._lineup.duplicate(true)
	for role in LINEUP_OUTFITS:
		lineup[role] = {"id": ATHLETE}
	var outfits := LINEUP_OUTFITS.duplicate()
	var count: int = view.spawn(lineup, outfits, {})
	_check(count == 4, "four rigs spawn on the real match court (got %d)" % count)
	if count != 4:
		printerr("refusing to render: the match court did not build four rigs")
		_finish(game, 1)
		return

	for role in View.ROLES:
		game._athlete_roots[role] = view.rigs[role]
		game._paddle_views[role] = view.rackets[role]
	game._sync_views()
	await process_frame
	await RenderingServer.frame_post_draw

	# --- what is actually on the rigs, read back off the live material ---------
	var surfaces: Dictionary = {}
	for role in View.ROLES:
		var rig: Node3D = view.rigs[role]
		var wanted := String(outfits[role])
		var worn := Catalogue.read_back(rig)
		# The rig really is the Maestro asset, not another athlete wearing his
		# mask: `Catalogue.apply` refuses a profile whose athlete id does not match
		# the rig's own asset, so this is the same fact that guard relies on.
		_check(rig.get_athlete_asset() == StringName(ATHLETE),
			"%s is the %s asset (got '%s')" % [role, ATHLETE, rig.get_athlete_asset()])
		_check(String(worn.get("profile", "")) == ATHLETE,
			"%s is on the maestro profile" % role)
		_check(String(rig.get_catalogue_outfit().get("outfit_id", "")) == wanted,
			"%s wears '%s' (read back: '%s')" % [role, wanted, rig.get_catalogue_outfit().get("outfit_id", "")])
		if wanted in PROFILED:
			_check(String(worn.get("visual_status", "")) == "applied",
				"%s ('%s') has the masked material applied" % [role, wanted])
			_check(String(worn.get("mask", "")) == "set",
				"%s ('%s') has the region mask bound" % [role, wanted])
			var mat: ShaderMaterial = rig.get_catalogue_surface()
			_check(mat != null, "%s ('%s') exposes a catalogue surface" % [role, wanted])
			if mat != null:
				var on: bool = bool(mat.get_shader_parameter("value_gate_enabled"))
				_check(on, "%s ('%s') runs with value_gate_enabled = true" % [role, wanted])
				var band_a: Vector2 = mat.get_shader_parameter("value_band_a")
				var band_b: Vector2 = mat.get_shader_parameter("value_band_b")
				_check(band_a == Vector2(gate["band_a"][0], gate["band_a"][1]),
					"%s ('%s') band_a is the profile's %s" % [role, wanted, str(gate["band_a"])])
				_check(band_b == Vector2(gate["band_b"][0], gate["band_b"][1]),
					"%s ('%s') band_b is the profile's %s" % [role, wanted, str(gate["band_b"])])
				print("MEASURED %s outfit=%s gate=%s band_a=%s band_b=%s feather=%.3f resource=%s"
					% [role, wanted, str(on), str(band_a), str(band_b),
						float(mat.get_shader_parameter("value_band_feather")), mat.resource_name])
				surfaces[role] = mat
		else:
			_check(String(worn.get("visual_status", "")) == "base",
				"%s ('%s') is the rig's own material, untouched" % [role, wanted])

	# The three variants must be three different materials, not one reused.
	var distinct: Dictionary = {}
	for role in surfaces:
		distinct[surfaces[role]] = true
	_check(distinct.size() == 3,
		"circuit / legend / signature are three independent surfaces (got %d)" % distinct.size())
	_check(view.rigs.player.get_catalogue_surface() != view.rigs.playerMate.get_catalogue_surface(),
		"player and playerMate do not share a material")

	# --- the whole-court frame, on the match's own camera ----------------------
	var outfit_img: Image = root.get_texture().get_image()
	_check(outfit_img != null and not outfit_img.is_empty(), "the framebuffer produced an image")

	# --- PROOF THE OUTFITS ARE WHAT IS DRAWN, not merely what is bound --------
	# Read-back proves the right shader and uniforms are on the rig. It does not
	# prove those uniforms reach the screen. So the frame is rendered again with
	# every rig on `base` and each athlete's own screen-space box is compared
	# pixel by pixel. A profiled outfit that changed nothing on court fails here,
	# whatever its material says.
	#
	# The comparison is calibrated against the scene's OWN noise floor: the rigs
	# are animated, so two consecutive frames of an UNCHANGED scene already differ
	# by a few dozen pixels. That floor is measured (frame vs the next frame) and
	# the effect of the outfit must clear it by a wide margin, so this cannot pass
	# on animation alone and cannot fail on it either.
	var base_img: Image = null
	var idle_img: Image = null
	var cam: Camera3D = root.get_camera_3d()
	_check(cam != null, "the match scene has an active camera to project through")
	if outfit_img != null and not outfit_img.is_empty() and cam != null:
		var image_size := Vector2(outfit_img.get_width(), outfit_img.get_height())
		# The noise floor: one more frame with nothing changed at all.
		await process_frame
		await RenderingServer.frame_post_draw
		idle_img = root.get_texture().get_image()
		# The control: every rig on the rig's own material.
		for role in View.ROLES:
			_check(view.set_outfit(String(role), &"base"), "%s can be switched to base" % role)
		game._sync_views()
		await process_frame
		await RenderingServer.frame_post_draw
		base_img = root.get_texture().get_image()
		for role in View.ROLES:
			var rect := _screen_rect(cam, view.rigs[role], image_size)
			var noise := _changed_pixels(outfit_img, idle_img, rect)
			var effect := _changed_pixels(outfit_img, base_img, rect)
			var pixels: int = rect.size.x * rect.size.y
			var wanted := String(outfits[role])
			if wanted in PROFILED:
				_check(effect > 4 * maxi(noise, 1),
					"%s ('%s') repaints %d px vs %d px of animation noise: the outfit is on screen"
						% [role, wanted, effect, noise])
			else:
				_check(effect <= 3 * maxi(noise, 1),
					"%s ('base') is within the animation noise band (%d px vs noise %d)"
						% [role, effect, noise])
			print("MEASURED pixels role=%s outfit=%s box=%s of=%d effect=%d noise=%d"
				% [role, wanted, str(rect), pixels, effect, noise])
		# How far apart the two Maestro of a pair stand: the number that decides
		# whether one frame can hold both of them at a legible size.
		var separation: float = view.rigs.player.global_position.distance_to(
			view.rigs.playerMate.global_position)
		print("MEASURED pair_separation_m=%.2f" % separation)

	var base_out := _resolve(_out_path())
	var wide_path := base_out.get_basename() + "-wide.png"
	if outfit_img != null:
		var wide_result := outfit_img.save_png(wide_path)
		_check(wide_result == OK, "the whole-court frame saved to %s" % wide_path)
	if base_img != null:
		var base_path := base_out.get_basename() + "-all-base.png"
		var base_result := base_img.save_png(base_path)
		_check(base_result == OK, "the all-base comparison frame saved to %s" % base_path)

	# --- THE PROOF: two Maestro, two outfits, one panel each -------------------
	# Every rig goes back on its own outfit, then each proof role is rendered
	# through a second camera that sees the SAME world the match is in, framed on
	# that athlete alone, at PANEL size. The two panels are composed in-engine at
	# exactly the capture size, so the saved frame shows each athlete at ~490 px
	# instead of ~80 px and the outfit can actually be judged.
	for role in View.ROLES:
		view.set_outfit(String(role), StringName(String(outfits[role])))
	game._sync_views()
	await process_frame
	await RenderingServer.frame_post_draw

	var panel_cam: Camera3D = null
	var panel_view: SubViewport = null
	if cam != null:
		panel_view = SubViewport.new()
		panel_view.name = "MaestroProofPanel"
		panel_view.size = PANEL
		panel_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(panel_view)
		# The same World3D the match scene lives in: the panel is a second camera
		# on the real court, not a second copy of it.
		panel_view.world_3d = root.world_3d
		panel_cam = Camera3D.new()
		panel_cam.name = "ProofCam"
		panel_cam.fov = cam.fov
		panel_view.add_child(panel_cam)
		panel_cam.current = true
		await process_frame
		_check(panel_view.world_3d == root.world_3d,
			"the proof camera renders the match's own World3D")

	var panel_outfit: Dictionary = {}
	var panel_base: Dictionary = {}
	var panel_rect: Dictionary = {}
	if panel_cam != null:
		for role in PROOF_ROLES:
			var img: Image = await _render_panel(panel_view, panel_cam, role, view)
			panel_outfit[role] = img
			panel_rect[role] = _screen_rect(panel_cam, view.rigs[role], Vector2(PANEL))
			var height_fraction := float(panel_rect[role].size.y) / float(PANEL.y)
			print("MEASURED panel role=%s outfit=%s box=%s height_fraction=%.2f"
				% [role, String(outfits[role]), str(panel_rect[role]), height_fraction])
			_check(height_fraction >= MIN_ATHLETE_HEIGHT_FRACTION,
				"%s ('%s') fills %.0f%% of his panel height (floor %.0f%%): the athlete is clearly visible"
					% [role, String(outfits[role]), height_fraction * 100.0,
						MIN_ATHLETE_HEIGHT_FRACTION * 100.0])
		# The control, same framing, rig on its own material: the pixels the outfit
		# repaints inside that athlete's own box, and the mean colour of them.
		for role in PROOF_ROLES:
			_check(view.set_outfit(role, &"base"),
				"%s can be switched to base for the panel control" % role)
		game._sync_views()
		await process_frame
		await RenderingServer.frame_post_draw
		for role in PROOF_ROLES:
			panel_base[role] = await _render_panel(panel_view, panel_cam, role, view)
		for role in PROOF_ROLES:
			view.set_outfit(role, StringName(String(outfits[role])))
		game._sync_views()
		await process_frame
		await RenderingServer.frame_post_draw

	var panel_mean: Dictionary = {}
	var panel_count: Dictionary = {}
	if not panel_outfit.is_empty():
		for role in PROOF_ROLES:
			var measured := _changed_mean(panel_outfit[role], panel_base[role], panel_rect[role])
			panel_mean[role] = measured["mean"]
			panel_count[role] = measured["count"]
			print("MEASURED panel_pixels role=%s outfit=%s repainted=%d mean_rgb=%s"
				% [role, String(outfits[role]), int(panel_count[role]),
					_color_hex(panel_mean[role])])
			_check(int(panel_count[role]) >= MIN_REPAINTED_PIXELS,
				"%s ('%s') repaints %d px in its panel (floor %d)"
					% [role, String(outfits[role]), int(panel_count[role]), MIN_REPAINTED_PIXELS])
			# The material is read back AGAIN after the framing, so the labels
			# cannot name an outfit the rig is not actually wearing.
			_check(String(Catalogue.read_back(view.rigs[role]).get("profile", "")) == ATHLETE,
				"%s is still on the maestro profile in its panel" % role)
		var mean_a: Color = panel_mean[PROOF_ROLES[0]]
		var mean_b: Color = panel_mean[PROOF_ROLES[1]]
		var distance := (Vector3(mean_a.r, mean_a.g, mean_a.b)
			- Vector3(mean_b.r, mean_b.g, mean_b.b)).length() * 255.0
		print("MEASURED proof_colour_distance=%.0f/441 floor=%.0f"
			% [distance, MIN_OUTFIT_COLOUR_DISTANCE])
		_check(distance >= MIN_OUTFIT_COLOUR_DISTANCE,
			"the two panels are two measured colours: %s='%s' %s vs %s='%s' %s (distance %.0f/441)"
				% [PROOF_ROLES[0], String(outfits[PROOF_ROLES[0]]), _color_hex(mean_a),
					PROOF_ROLES[1], String(outfits[PROOF_ROLES[1]]), _color_hex(mean_b), distance])

	# --- compose, label, save -------------------------------------------------
	var composed: Image = null
	if panel_outfit.has(PROOF_ROLES[0]) and panel_outfit.has(PROOF_ROLES[1]):
		composed = _compose(panel_outfit[PROOF_ROLES[0]], panel_outfit[PROOF_ROLES[1]])
		_check(composed != null, "the two panels composed into one image")
	if composed != null:
		_label_frame(panel_cam, view, outfits, panel_rect, panel_mean, panel_count, composed)
		await process_frame
		await RenderingServer.frame_post_draw
		var proof: Image = root.get_texture().get_image()
		var result := proof.save_png(base_out) if proof != null else FAILED
		_check(result == OK, "the labelled proof frame saved to %s" % base_out)
		if result != OK:
			_finish(game, 1)
			return
	else:
		_failures += 1
		printerr("FAIL the proof image could not be composed")

	if _failures == 0:
		print("OUTFIT_MAESTRO_MATCH_PASS rigs=%d profiled=%d base=1 panels=%d proof=%s"
			% [count, surfaces.size(), panel_outfit.size(), base_out])
		_finish(game, 0)
		return
	printerr("OUTFIT_MAESTRO_MATCH_FAIL %d check(s) failed" % _failures)
	_finish(game, 1)


# ---------------------------------------------------------------------------
# Framing, panels and annotation
# ---------------------------------------------------------------------------

## Renders one proof panel: the proof camera framed on `role`, one frame of the
## real world at PANEL size. Async because the framebuffer is only valid after the
## frame has actually been drawn.
func _render_panel(panel_view: SubViewport, panel_cam: Camera3D, role: String, view) -> Image:
	_frame_on(panel_cam, [role], view)
	await process_frame
	await RenderingServer.frame_post_draw
	return panel_view.get_texture().get_image()


## Frames a camera on a set of rigs, IN PLACE. The cameras are the scene's own
## (`Court.build_camera()` for the match, a second `Camera3D` on the match's own
## World3D for the panels); only the transform is staged, so every frame stays the
## real scene seen from a distance a viewer can judge an outfit from.
##
## The distance is solved from the rigs' own bounds (the same 0.05 m / 1.95 m the
## screen boxes use) rather than hardcoded, so it follows the pair wherever the
## simulation put them instead of assuming a court position.
func _frame_on(cam: Camera3D, roles: Array, view) -> void:
	var points: Array[Vector3] = []
	for role in roles:
		var rig: Node3D = view.rigs[role]
		var origin: Vector3 = rig.global_position
		points.append(origin + Vector3(0.0, 0.05, 0.0))
		points.append(origin + Vector3(0.0, 1.95, 0.0))
	if points.is_empty():
		return
	var centre := Vector3.ZERO
	for p in points:
		centre += p
	centre /= float(points.size())
	var radius := 0.0
	for p in points:
		radius = maxf(radius, centre.distance_to(p))
	# A raised three-quarter view: high enough that the athlete's torso is not
	# lost to his own shorts, angled enough to give the figure depth.
	var aim := centre + Vector3(0.0, 0.15, 0.0)
	var direction := Vector3(0.30, 0.38, 1.0).normalized()
	var half_fov := deg_to_rad(cam.fov * 0.5)
	# The athlete's bounding sphere must subtend PANEL_FILL of the half-fov.
	var distance: float = maxf(1.5, radius / sin(PANEL_FILL * half_fov))
	cam.global_position = aim + direction * distance
	cam.look_at(aim, Vector3.UP)
	print("MEASURED framing role=%s centre=%s radius=%.2f distance=%.2f"
		% [str(roles), str(centre), radius, distance])


## The two panels side by side, at exactly the size the proof frame is captured
## at, so nothing is resampled between the render and the saved image.
func _compose(left: Image, right: Image) -> Image:
	if left == null or right == null or left.is_empty() or right.is_empty():
		return null
	var a := left.duplicate()
	var b := right.duplicate()
	if a.get_format() != Image.FORMAT_RGBA8:
		a.convert(Image.FORMAT_RGBA8)
	if b.get_format() != Image.FORMAT_RGBA8:
		b.convert(Image.FORMAT_RGBA8)
	if a.get_size() != PANEL or b.get_size() != PANEL:
		return null
	var out := Image.create_empty(PANEL.x * 2, PANEL.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, PANEL), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, PANEL), Vector2i(PANEL.x, 0))
	return out


## Draws the annotation the whole-court frame could not carry: the composed panels,
## a banner naming the scene, and one label per panel naming the outfit read back
## off that rig's live material plus the measured colour its outfit repaints.
func _label_frame(panel_cam: Camera3D, view, outfits: Dictionary, rects: Dictionary,
		means: Dictionary, counts: Dictionary, composed: Image) -> void:
	var layer := CanvasLayer.new()
	layer.name = "MaestroProof"
	layer.layer = 10
	root.add_child(layer)

	var size := Vector2(root.get_visible_rect().size)

	# The composed panels, 1:1. A TextureRect rather than a file: the proof frame
	# is the real framebuffer, not a paste-up.
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(composed)
	rect.position = Vector2.ZERO
	rect.size = Vector2(composed.get_width(), composed.get_height())
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

	# Divider between the panels, so neither label can be read across the seam.
	var seam := ColorRect.new()
	seam.color = Color(0.06, 0.06, 0.07)
	seam.position = Vector2(float(PANEL.x) - 2.0, 0.0)
	seam.size = Vector2(4.0, float(PANEL.y))
	seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(seam)

	# Banner. Split over two lines and sized so neither line reaches the frame
	# edge: a label that runs off the capture is a label the reader never gets.
	_add_strip(layer, Rect2(Vector2.ZERO, Vector2(size.x, 62.0)))
	layer.add_child(_text(
		"MAESTRO  —  REAL MATCH SCENE  ·  res://game/Match.tscn  ·  two Maestro rigs, two outfits",
		Vector2(18.0, 8.0), 20, Color(1.0, 0.95, 0.55)))
	layer.add_child(_text(
		"real athletes_view.gd  ·  real AthleteSpawn.make()  ·  real _sync_views()  ·  outfit name and colour read back off the rig's live material",
		Vector2(18.0, 34.0), 15, Color(0.86, 0.92, 1.0)))

	# One label per panel: the role, the athlete, and the outfit read back off the
	# rig's live material — not off a dictionary this harness kept.
	for i in PROOF_ROLES.size():
		var role: String = PROOF_ROLES[i]
		var rig: Node3D = view.rigs[role]
		var outfit := String(rig.get_catalogue_outfit().get("outfit_id", "?"))
		var worn := Catalogue.read_back(rig)
		var x := float(i * PANEL.x) + 18.0
		layer.add_child(_text("%s  ·  MAESTRO  ·  outfit '%s'" % [role, outfit],
			Vector2(x, 70.0), 23, Color(1.0, 0.9, 0.35)))
		var mean: Color = means.get(role, Color.BLACK)
		layer.add_child(_text(
			"masked material %s · value gate ON · repaints %d px, mean %s"
				% [String(worn.get("visual_status", "?")), int(counts.get(role, 0)), _color_hex(mean)],
			Vector2(x, 100.0), 16, Color(0.78, 0.95, 0.78)))
		# The measured colour itself, as a swatch, so the number is checkable by eye.
		var swatch := ColorRect.new()
		swatch.color = mean
		swatch.position = Vector2(x, 122.0)
		swatch.size = Vector2(64.0, 22.0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(swatch)
		layer.add_child(_text("= the outfit's mean repainted colour",
			Vector2(x + 72.0, 124.0), 15, Color(0.8, 0.8, 0.85)))
		# A marker on the athlete himself, so the label is tied to a body.
		if panel_cam != null:
			var head := panel_cam.unproject_position(rig.global_position + Vector3(0.0, 2.1, 0.0))
			var mark := ColorRect.new()
			mark.color = Color(1.0, 0.9, 0.35, 0.9)
			mark.position = Vector2(float(i * PANEL.x) + head.x - 1.0, head.y)
			mark.size = Vector2(3.0, 14.0)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(mark)

	# Footer.
	_add_strip(layer, Rect2(Vector2(0.0, size.y - 58.0), Vector2(size.x, 58.0)))
	layer.add_child(_text(
		"four Maestro rigs on court:  player = circuit  ·  playerMate = legend  ·  opponent = signature  ·  opponentMate = base",
		Vector2(18.0, size.y - 50.0), 15, Color(0.86, 0.92, 1.0)))
	layer.add_child(_text(
		"each panel is a whole frame of the same real scene through a camera framed on that one athlete — no crop, no compositing outside Godot.",
		Vector2(18.0, size.y - 28.0), 15, Color(0.86, 0.92, 1.0)))


func _add_strip(layer: CanvasLayer, rect: Rect2) -> void:
	var strip := ColorRect.new()
	strip.color = Color(0.0, 0.0, 0.0, 0.74)
	strip.position = rect.position
	strip.size = rect.size
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(strip)


func _text(body: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = body
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Leaves the tree as it was found and exits: the staged match is freed, the
## scratch save directory removed, and `Config.save_dir` handed back to the real
## profile so a later harness in the same process is not left pointing at scratch.
func _finish(game: Node, code: int) -> void:
	game.free()
	_cleanup()
	quit(code)


func _cleanup() -> void:
	Config.save_dir = ""
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(SAVE_DIR)


## The screen-space box an athlete occupies, from a camera: the head is the world
## point 2.1 m above the rig's origin and the feet 0.1 m, which is the rig's own
## height range, so the box follows the athlete wherever the camera puts it rather
## than being a hardcoded rectangle.
func _screen_rect(cam: Camera3D, rig: Node3D, image_size: Vector2) -> Rect2i:
	var origin: Vector3 = rig.global_position
	var head := cam.unproject_position(origin + Vector3(0.0, 2.1, 0.0))
	var feet := cam.unproject_position(origin + Vector3(0.0, 0.1, 0.0))
	var height := absf(head.y - feet.y)
	var half_width: float = maxf(24.0, height * 0.55)
	var centre := (head + feet) * 0.5
	var x0 := int(clampf(centre.x - half_width, 0.0, image_size.x - 1.0))
	var x1 := int(clampf(centre.x + half_width, 0.0, image_size.x - 1.0))
	var y0 := int(clampf(minf(head.y, feet.y), 0.0, image_size.y - 1.0))
	var y1 := int(clampf(maxf(head.y, feet.y), 0.0, image_size.y - 1.0))
	return Rect2i(x0, y0, maxi(1, x1 - x0), maxi(1, y1 - y0))


## How many pixels inside `rect` differ between two same-sized frames. A
## threshold rather than an exact compare, so a one-bit dither difference is not
## counted as a changed kit.
func _changed_pixels(a: Image, b: Image, rect: Rect2i, threshold: int = 18) -> int:
	return int(_changed_mean(a, b, rect, threshold)["count"])


## The count AND the mean colour of the pixels inside `rect` that differ between
## two frames: what the outfit repainted, and in what colour. The mean is over the
## changed pixels only — the whole box is mostly court, and the material's uniforms
## prove binding rather than drawing.
func _changed_mean(a: Image, b: Image, rect: Rect2i, threshold: int = 18) -> Dictionary:
	if a == null or b == null or a.is_empty() or b.is_empty():
		return {"count": 0, "mean": Color.BLACK}
	var r := 0.0
	var g := 0.0
	var bl := 0.0
	var n := 0
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var delta := absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			if delta * 255.0 > float(threshold):
				r += ca.r
				g += ca.g
				bl += ca.b
				n += 1
	if n == 0:
		return {"count": 0, "mean": Color.BLACK}
	return {"count": n, "mean": Color(r / float(n), g / float(n), bl / float(n))}


func _color_hex(c: Color) -> String:
	return "#%02x%02x%02x" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]
