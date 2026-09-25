extends SceneTree
## test_jukebox_search.gd — Automated tests for Jukebox search-by-name feature.
##
## Run with:
##   godot --headless --path godot --script res://tests/test_jukebox_search.gd

const JukeboxScene := preload("res://src/ui/jukebox/JukeboxScreen.tscn")
const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")
const Config := preload("res://game/match_config.gd")

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok: %s" % message)
	else:
		_failures += 1
		printerr("  FAIL: %s" % message)

func _assert_eq(got: Variant, expected: Variant, message: String) -> void:
	_checks += 1
	if got == expected:
		print("  ok: %s" % message)
	else:
		_failures += 1
		printerr("  FAIL: %s (got %s, expected %s)" % [message, str(got), str(expected)])

func _run() -> void:
	print("[test_jukebox_search] Starting test suite...")
	Config.save_dir = "user://test-jukebox-search-%d" % Time.get_ticks_usec()
	var store := Config.save_store()

	var screen: Control = JukeboxScene.instantiate()
	screen.set_store(store)
	root.add_child(screen)

	for f in 3:
		await process_frame

	# 1. Verify search input exists and is configured
	var search_input: LineEdit = screen.get("_search_input")
	_assert(search_input != null, "Search input node exists")
	_assert(search_input.clear_button_enabled, "Clear button enabled on search input")
	_assert(search_input.placeholder_text.contains("Cerca"), "Placeholder text contains search prompt")
	_assert_eq(screen.get("_search_query"), "", "Initial search query is empty")

	var initial_visible: Array = screen.call("_visible_ids")
	_assert(initial_visible.size() > 0, "Initial visible tracks > 0 (match scope)")

	# 2. Search for 'overdrive' (matches Steam Spiral Overdrive, Scouting Overdrive, Overdrive Line)
	search_input.text = "overdrive"
	search_input.text_changed.emit("overdrive")
	await process_frame

	_assert_eq(screen.get("_search_query"), "overdrive", "Query updated to 'overdrive'")
	var visible_overdrive: Array = screen.call("_visible_ids")
	_assert_eq(visible_overdrive.size(), 3, "Exactly 3 tracks match 'overdrive' in title")
	_assert(visible_overdrive.has("ost_vocal_overdrive_line"), "Matches ost_vocal_overdrive_line")
	_assert(visible_overdrive.has("ost_epic_anthem"), "Matches ost_epic_anthem")

	# Search for specific full name 'Overdrive Line'
	search_input.text = "Overdrive Line"
	search_input.text_changed.emit("Overdrive Line")
	await process_frame

	var visible_od_exact: Array = screen.call("_visible_ids")
	_assert_eq(visible_od_exact.size(), 1, "Exactly 1 track matches 'Overdrive Line'")
	_assert_eq(visible_od_exact[0], "ost_vocal_overdrive_line", "Matches ost_vocal_overdrive_line")
	_assert_eq(screen.get("_title_label").text, "Overdrive Line", "Auto-selected Overdrive Line")

	# 3. Search for 'riot' (Break Point Riot)
	search_input.text = "riot"
	search_input.text_changed.emit("riot")
	await process_frame

	var visible_riot: Array = screen.call("_visible_ids")
	_assert_eq(visible_riot.size(), 1, "Exactly 1 track matches 'riot'")
	_assert_eq(visible_riot[0], "ost_vocal_break_point_riot", "Matches ost_vocal_break_point_riot")
	_assert_eq(screen.get("_title_label").text, "Break Point Riot", "Auto-selected Break Point Riot")

	# 4. Search for 'reach' (Reach for the Sun & Titan Breach) - test case-insensitivity
	search_input.text = "REACH"
	search_input.text_changed.emit("REACH")
	await process_frame

	var visible_reach: Array = screen.call("_visible_ids")
	_assert_eq(visible_reach.size(), 3, "Case-insensitive substring search 'REACH' matches Reach for the Sun and 2 Breach tracks")
	_assert(visible_reach.has("ost_vocal_reach_for_the_sun"), "Matches ost_vocal_reach_for_the_sun")
	_assert(visible_reach.has("ost_sawano_titan_breach"), "Matches ost_sawano_titan_breach")

	# Search for specific full name 'Reach for the Sun'
	search_input.text = "Reach for the Sun"
	search_input.text_changed.emit("Reach for the Sun")
	await process_frame

	var visible_reach_exact: Array = screen.call("_visible_ids")
	_assert_eq(visible_reach_exact.size(), 1, "Exactly 1 track matches 'Reach for the Sun'")
	_assert_eq(visible_reach_exact[0], "ost_vocal_reach_for_the_sun", "Matches ost_vocal_reach_for_the_sun")
	_assert_eq(screen.get("_title_label").text, "Reach for the Sun", "Auto-selected Reach for the Sun")

	# 5. Search for 'dan dan'
	search_input.text = "dan dan"
	search_input.text_changed.emit("dan dan")
	await process_frame

	var visible_dandan: Array = screen.call("_visible_ids")
	_assert_eq(visible_dandan.size(), 1, "Matches 'dan dan'")
	_assert_eq(visible_dandan[0], "ost_dbgt_dan_dan_vocal", "Matches ost_dbgt_dan_dan_vocal")

	# 5b. Search for 'neon' (Neon Velocity)
	search_input.text = "neon"
	search_input.text_changed.emit("neon")
	await process_frame

	var visible_neon: Array = screen.call("_visible_ids")
	_assert_eq(visible_neon.size(), 1, "Matches 'neon'")
	_assert_eq(visible_neon[0], "ost_vocal_neon_velocity", "Matches ost_vocal_neon_velocity")
	_assert_eq(screen.get("_title_label").text, "Neon Velocity", "Auto-selected Neon Velocity")

	# 5c. Search for 'girei' (Girei (Almighty Judgment))
	search_input.text = "girei"
	search_input.text_changed.emit("girei")
	await process_frame

	var visible_girei: Array = screen.call("_visible_ids")
	_assert_eq(visible_girei.size(), 1, "Matches 'girei'")
	_assert_eq(visible_girei[0], "ost_vocal_girei", "Matches ost_vocal_girei")
	_assert_eq(screen.get("_title_label").text, "Girei (Almighty Judgment)", "Auto-selected Girei")

	# 5d. Search for 'Apex Victory'
	search_input.text = "Apex Victory"
	search_input.text_changed.emit("Apex Victory")
	await process_frame

	var visible_apex: Array = screen.call("_visible_ids")
	_assert_eq(visible_apex.size(), 1, "Matches 'Apex Victory'")
	_assert_eq(visible_apex[0], "ost_apex_victory", "Matches ost_apex_victory")
	_assert_eq(screen.get("_title_label").text, "Apex Victory", "Auto-selected Apex Victory")

	# 5e. Search for 'Gleiches Blut'
	search_input.text = "Gleiches"
	search_input.text_changed.emit("Gleiches")
	await process_frame

	var visible_gleiches: Array = screen.call("_visible_ids")
	_assert_eq(visible_gleiches.size(), 1, "Matches 'Gleiches'")
	_assert_eq(visible_gleiches[0], "ost_vocal_gleiches_blut", "Matches ost_vocal_gleiches_blut")

	# 5f. Search for 'Железная Воля'
	search_input.text = "Железная"
	search_input.text_changed.emit("Железная")
	await process_frame

	var visible_volya: Array = screen.call("_visible_ids")
	_assert_eq(visible_volya.size(), 1, "Matches Cyrillic query 'Железная'")
	_assert_eq(visible_volya[0], "ost_vocal_zheleznaia_volya", "Matches ost_vocal_zheleznaia_volya")

	# 5g. Search for 'Double Rebond'
	search_input.text = "Double Rebond"
	search_input.text_changed.emit("Double Rebond")
	await process_frame

	var visible_dr: Array = screen.call("_visible_ids")
	_assert_eq(visible_dr.size(), 1, "Matches 'Double Rebond'")
	_assert_eq(visible_dr[0], "ost_vocal_double_rebond", "Matches ost_vocal_double_rebond")

	# 5h. Search for 'Oltre il Vetro'
	search_input.text = "Oltre il Vetro"
	search_input.text_changed.emit("Oltre il Vetro")
	await process_frame

	var visible_oiv: Array = screen.call("_visible_ids")
	_assert_eq(visible_oiv.size(), 1, "Matches 'Oltre il Vetro'")
	_assert_eq(visible_oiv[0], "ost_vocal_oltre_il_vetro", "Matches ost_vocal_oltre_il_vetro")

	# 6. Cross-scope search hint: search for 'velvet' while in 'match' scope
	search_input.text = "velvet"
	search_input.text_changed.emit("velvet")
	await process_frame

	var visible_velvet_match: Array = screen.call("_visible_ids")
	_assert_eq(visible_velvet_match.size(), 0, "No velvet track in match scope")
	var hint: Label = screen.get("_playlist_hint")
	_assert(hint.visible, "Playlist hint is visible on empty results")
	_assert(hint.text.contains("Musiche menu"), "Hint mentions other scope 'Musiche menu'")

	# Switch to menu scope: 'velvet' should now appear
	screen.call("_set_scope", "menu")
	await process_frame

	var visible_velvet_menu: Array = screen.call("_visible_ids")
	_assert_eq(visible_velvet_menu.size(), 1, "Velvet found after switching to menu scope")
	_assert_eq(visible_velvet_menu[0], "ost_menu_velvet_lounge", "Matches ost_menu_velvet_lounge")

	# 7. Search for nonexistent string
	search_input.text = "supercalifragilistic_padel"
	search_input.text_changed.emit("supercalifragilistic_padel")
	await process_frame

	var visible_none: Array = screen.call("_visible_ids")
	_assert_eq(visible_none.size(), 0, "No tracks match nonsense query")
	_assert(hint.visible, "Hint visible for nonexistent track")
	_assert(hint.text.contains("supercalifragilistic_padel"), "Hint text includes searched query")

	# 8. Clear search -> full list restored
	search_input.text = ""
	search_input.text_changed.emit("")
	await process_frame

	_assert_eq(screen.get("_search_query"), "", "Search query cleared")
	var restored_visible: Array = screen.call("_visible_ids")
	_assert(restored_visible.size() > 0, "Visible tracks restored after clearing search")
	_assert(not hint.visible, "Hint hidden after clearing search")

	# 9. ESC key on search input clears text
	search_input.text = "test_escape"
	search_input.text_changed.emit("test_escape")
	await process_frame
	_assert_eq(screen.get("_search_query"), "test_escape", "Query set before escape test")

	var escape_event := InputEventKey.new()
	escape_event.pressed = true
	escape_event.keycode = KEY_ESCAPE
	screen.call("_on_search_gui_input", escape_event)
	await process_frame

	_assert_eq(search_input.text, "", "ESC key clears search input text")
	_assert_eq(screen.get("_search_query"), "", "ESC key clears search query state")

	# 10. Enter key / submission moves focus to first matching track
	screen.call("_set_scope", "match")
	await process_frame
	search_input.text = "Riot"
	search_input.text_changed.emit("Riot")
	await process_frame

	screen.call("_on_search_submitted", "Riot")
	await process_frame
	var buttons: Array = screen.get("_track_buttons")
	var all_ids: PackedStringArray = SoundtrackManager.all_track_ids()
	var riot_idx := all_ids.find("ost_vocal_break_point_riot")
	_assert_eq(screen.get_viewport().gui_get_focus_owner(), buttons[riot_idx], "Enter key moves focus to matching track button")

	screen.queue_free()

	# Clean up test temp save dir
	if DirAccess.dir_exists_absolute(Config.save_dir):
		OS.execute("rm", ["-rf", ProjectSettings.globalize_path(Config.save_dir)])

	print("[test_jukebox_search] Results: %d checks, %d failures." % [_checks, _failures])
	if _failures == 0:
		print("PASS all jukebox search checks!")
		quit(0)
	else:
		printerr("FAILED jukebox search checks.")
		quit(1)
