extends RefCounted
class_name CustomCharacterPortrait
## CustomCharacterPortrait — the created athlete's own picture.
##
## The roster cards read a PNG off disk (`CharactersScreen._art_for`), and the six
## frozen portraits stay untouched. The custom athlete has no shipped portrait, so
## one is produced from the saved appearance:
##
##   * when a rendering device is available (the game, and any non-headless run) the
##     real 3D rig is rendered through a `SubViewport` and the frame is used;
##   * in a headless run, where the dummy renderer would hand back a blank frame, the
##     same record is painted directly into an `Image` — head, hair variant, garment
##     and accent in the record's own colours — so a card is never empty and a test
##     can still assert that two appearances produce two different pictures.
##
## Either way the file is cached at `user://custom_character/portrait_<signature>.png`
## and reused, so a card rebuild does not re-render.

const CustomCharacter := preload("res://src/character/custom_character.gd")
const CustomCharacterRig := preload("res://src/character/custom_character_rig.gd")

const DEFAULT_SIZE := Vector2i(256, 320)
const DIR := "user://custom_character"

## Which path produced the last image: "render" (a real 3D frame) or "paint" (the
## renderer-free portrait). Evidence, not behaviour.
static var last_source: String = ""


## The path a card can hand to `load()`. Renders on first use, caches afterwards.
static func portrait_path(record: Dictionary, size: Vector2i = DEFAULT_SIZE) -> String:
	var r := CustomCharacter.normalize(record)
	var path := "%s/portrait_v3_%s_%dx%d.png" % [DIR, _digest(CustomCharacter.signature(r)), size.x, size.y]
	if FileAccess.file_exists(path):
		return path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var image := image_for(r, size)
	if image.save_png(ProjectSettings.globalize_path(path)) != OK:
		return ""
	return path


## Stores a frame the editor's live 3D preview produced (2026-09-27): the synchronous
## `_render` below cannot count on the renderer having drawn, the editor's viewport has.
## The image is cropped to the card's aspect around `focus` (a pixel rect of the athlete's
## upper body) and cached where `portrait_path` looks, so the card shows the real athlete.
static func store_preview(record: Dictionary, frame: Image, focus: Rect2, size: Vector2i = DEFAULT_SIZE) -> String:
	if frame == null or frame.is_empty():
		return ""
	var r := CustomCharacter.normalize(record)
	var aspect := float(size.x) / float(size.y)
	var rect := focus
	if rect.size.x / maxf(rect.size.y, 1.0) < aspect:
		var w := rect.size.y * aspect
		rect.position.x -= (w - rect.size.x) * 0.5
		rect.size.x = w
	else:
		var h := rect.size.x / aspect
		rect.position.y -= (h - rect.size.y) * 0.5
		rect.size.y = h
	var bounds := Rect2(Vector2.ZERO, Vector2(frame.get_width(), frame.get_height()))
	rect = rect.intersection(bounds)
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return ""
	var crop := frame.get_region(Rect2i(rect))
	crop.convert(Image.FORMAT_RGBA8)
	crop.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	if not _has_content(crop):
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var path := "%s/portrait_v3_%s_%dx%d.png" % [DIR, _digest(CustomCharacter.signature(r)), size.x, size.y]
	if crop.save_png(ProjectSettings.globalize_path(path)) != OK:
		return ""
	last_source = "preview"
	return path


## The picture itself, without touching the disk. Prefers a real render.
static func image_for(record: Dictionary, size: Vector2i = DEFAULT_SIZE) -> Image:
	var r := CustomCharacter.normalize(record)
	if DisplayServer.get_name() != "headless":
		var rendered := _render(r, size)
		if rendered != null and _has_content(rendered):
			last_source = "render"
			return rendered
	last_source = "paint"
	return paint(r, size)


## Deterministic, renderer-free portrait: the same record always paints the same
## picture, and every cosmetic choice moves a visible area of it.
static func paint(record: Dictionary, size: Vector2i = DEFAULT_SIZE) -> Image:
	var r := CustomCharacter.normalize(record)
	var colors := CustomCharacter.colors(r)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color("141821"))
	var sx := float(size.x) / 256.0
	var sy := float(size.y) / 320.0
	var place := func(rect: Rect2, color: Color) -> void:
		var scaled := Rect2(rect.position * Vector2(sx, sy), rect.size * Vector2(sx, sy))
		img.fill_rect(Rect2i(scaled.position.floor(), scaled.size.ceil()), color)
	# floor shadow
	place.call(Rect2(48, 300, 160, 14), Color("101319"))
	# legs and shoes
	place.call(Rect2(100, 232, 22, 76), colors["skin"])
	place.call(Rect2(134, 232, 22, 76), colors["skin"])
	place.call(Rect2(96, 300, 30, 16), colors["shoe"])
	place.call(Rect2(130, 300, 30, 16), colors["shoe"])
	# shorts / garment hips
	place.call(Rect2(88, 214, 80, 34), colors["outfit"])
	# torso
	place.call(Rect2(86, 122, 84, 96), colors["outfit"])
	# accent band
	place.call(Rect2(86, 176, 84, 10), colors["accent"])
	# neck, then arms (sleeved on the two sleeved variants)
	place.call(Rect2(118, 104, 20, 22), colors["skin"])
	var sleeved: bool = StringName(r["outfit_id"]) != &"training"
	var arm_color: Color = colors["outfit"] if sleeved else colors["skin"]
	place.call(Rect2(68, 128, 20, 74), arm_color)
	place.call(Rect2(168, 128, 20, 74), arm_color)
	place.call(Rect2(68, 196, 20, 30), colors["skin"])
	place.call(Rect2(168, 196, 20, 30), colors["skin"])
	# head
	_disc(img, Vector2(128, 74) * Vector2(sx, sy), 36.0 * sx, colors["skin"])
	# hair variant: a different shape per id, in the hair colour
	var hair := StringName(r["hair_id"])
	if hair == &"buzz":
		_disc(img, Vector2(128, 62) * Vector2(sx, sy), 37.0 * sx, colors["hair"])
	elif hair == &"crop":
		_disc(img, Vector2(128, 60) * Vector2(sx, sy), 38.0 * sx, colors["hair"])
		place.call(Rect2(96, 66, 64, 14), colors["hair"])
	else:
		_disc(img, Vector2(128, 60) * Vector2(sx, sy), 38.0 * sx, colors["hair"])
		_disc(img, Vector2(128, 112) * Vector2(sx, sy), 20.0 * sx, colors["hair"])
		place.call(Rect2(116, 110, 24, 54), colors["hair"])
	# the face re-paints over the hair so the head reads as a face, not a blob
	_disc(img, Vector2(128, 82) * Vector2(sx, sy), 27.0 * sx, colors["skin"])
	return img


static func _digest(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 12)


static func _disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var r := int(ceil(radius))
	for y in range(int(center.y) - r, int(center.y) + r + 1):
		for x in range(int(center.x) - r, int(center.x) + r + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)


static func _has_content(img: Image) -> bool:
	# A background-only frame is not a picture of an athlete. The court-dark backdrop
	# is uniform, so a real frame has to show a decent share of pixels that are not it
	# (skin, hair, garment, shadow) — a dummy renderer or a mis-aimed camera does not.
	var background := img.get_pixel(0, 0)
	var differing := 0
	var sampled := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			sampled += 1
			var pixel := img.get_pixel(x, y)
			if absf(pixel.r - background.r) + absf(pixel.g - background.g) + absf(pixel.b - background.b) > 0.12:
				differing += 1
	return sampled > 0 and float(differing) / float(sampled) > 0.05


## A real 3D frame of the created athlete. Only meaningful with a rendering device;
## the caller falls back to `paint()` otherwise.
##
## 2026-09-27: a single `force_draw` right after adding the viewport returned an empty
## frame, so every card fell back to the painted placeholder (and cached it). The rig is
## now posed explicitly (idle clip sampled, head scale and hair settled) and the
## viewport drawn a few times before the frame is read. Framed as a card portrait:
## three-quarter view from the hips up, key and rim light, the card's dark backdrop.
static func _render(record: Dictionary, size: Vector2i) -> Image:
	var rig := CustomCharacterRig.make(record, {"name": "PortraitRig"})
	if rig == null:
		return null
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_4X
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141821")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfd6e4")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.25
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_color = Color("8fe6ff")
	rim.light_energy = 0.9
	viewport.add_child(rim)
	viewport.add_child(rig)
	rig.rotation_degrees.y = -22.0
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.current = true
	viewport.add_child(camera)
	Engine.get_main_loop().root.add_child(viewport)
	# Pose now: the idle clip at a fixed time, the head scale the body look asks for, and
	# the skeleton updated so the hair attachment follows.
	rig.play_locomotion(&"idle")
	if rig._anim != null:
		rig._anim.seek(0.3, true, true)
	var skeleton: Skeleton3D = rig.get_skeleton()
	if skeleton != null:
		var head_mod := skeleton.get_node_or_null("CustomHeadScale")
		if head_mod != null:
			skeleton.set_bone_pose_scale(int(head_mod.head_bone), Vector3.ONE * float(head_mod.head_scale))
		skeleton.force_update_all_bone_transforms()
	var bounds: AABB = rig.world_bounds()
	var height := maxf(bounds.size.y, 0.5)
	var foot_y: float = bounds.position.y
	var target := Vector3(0.0, foot_y + height * 0.74, 0.0)
	camera.look_at_from_position(target + Vector3(0.0, height * 0.03, height * 2.05), target, Vector3.UP)
	for i in 4:
		RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image
