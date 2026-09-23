extends SceneTree
## test_jukebox_covers.gd — Automated tests for Picture Disc cover art integration in Jukebox.

const JukeboxScene := preload("res://src/ui/jukebox/JukeboxScreen.tscn")
const JukeboxRecord := preload("res://src/ui/jukebox/jukebox_record.gd")
const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[test_jukebox_covers] Starting verification suite...")
	var failures := 0

	# 1. Test JukeboxRecord with and without cover texture
	var record := JukeboxRecord.new()
	record.size = Vector2(168, 168)
	if record._cover_texture != null:
		print("  FAIL: initial _cover_texture should be null")
		failures += 1
	else:
		print("  ok: initial _cover_texture is null")

	# Create a dummy test texture
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.2))
	var dummy_tex := ImageTexture.create_from_image(img)

	record.set_cover_texture(dummy_tex)
	if record._cover_texture != dummy_tex:
		print("  FAIL: set_cover_texture did not assign texture")
		failures += 1
	else:
		print("  ok: set_cover_texture assigned dummy texture successfully")

	# Test recentering pivot and size
	record._recentre_pivot()
	if record.pivot_offset != Vector2(84, 84):
		print("  FAIL: pivot offset mismatch: ", record.pivot_offset)
		failures += 1
	else:
		print("  ok: pivot offset correctly centered at (84, 84)")

	# 2. Test JukeboxScreen cover loading and caching
	var screen: Control = JukeboxScene.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame

	# Verify K21 cover exists on disk and loads
	var k21_tex: Texture2D = screen._load_cover_for_track("ost_sawano_k21_vocal")
	if k21_tex == null:
		print("  FAIL: ost_sawano_k21_vocal cover failed to load")
		failures += 1
	else:
		print("  ok: ost_sawano_k21_vocal cover loaded successfully (", k21_tex.get_width(), "x", k21_tex.get_height(), ")")

	# Verify cache
	var cached_tex: Texture2D = screen._load_cover_for_track("ost_sawano_k21_vocal")
	if cached_tex != k21_tex:
		print("  FAIL: cached texture reference does not match loaded texture")
		failures += 1
	else:
		print("  ok: cover texture correctly cached in _cover_cache")

	# Verify fallback when cover file does not exist
	var nonexistent_tex: Texture2D = screen._load_cover_for_track("ost_nonexistent_fake_track")
	if nonexistent_tex != null:
		print("  FAIL: nonexistent track returned non-null texture")
		failures += 1
	else:
		print("  ok: nonexistent track returns null gracefully without crash")

	# 3. Test that ALL 47 tracks have valid cover textures on disk and load correctly
	var all_ids: PackedStringArray = SoundtrackManager.all_track_ids()
	print("  Verifying cover textures for all %d catalogue tracks..." % all_ids.size())
	var missing_covers := 0
	for i in all_ids.size():
		var tid := all_ids[i]
		var tex: Texture2D = screen._load_cover_for_track(tid)
		if tex == null:
			print("  FAIL: missing cover for track %s" % tid)
			failures += 1
			missing_covers += 1
		else:
			screen._select_track(i)
			if screen._record._cover_texture != tex:
				print("  FAIL: record did not receive cover for %s" % tid)
				failures += 1

	if missing_covers == 0:
		print("  ok: all %d tracks have valid high-resolution covers and load cleanly into record" % all_ids.size())

	screen.queue_free()
	record.free()

	print("[test_jukebox_covers] Result: %d failures." % failures)
	if failures > 0:
		quit(1)
	else:
		print("PASS all jukebox cover tests!")
		quit(0)
