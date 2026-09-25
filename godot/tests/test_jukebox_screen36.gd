extends SceneTree

const JukeboxScene := preload("res://src/ui/jukebox/JukeboxScreen.tscn")
const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")

func _initialize() -> void:
	var juke = JukeboxScene.instantiate()
	root.add_child(juke)
	
	# Wait for UI setup
	for f in 3:
		await process_frame
		
	var track_count: int = juke._track_buttons.size()
	print("Track buttons count: %d" % track_count)
	assert(track_count == 98, "Jukebox should display exactly 98 tracks, got %d" % track_count)
	
	# Find the index of ost_sawano_titan_breach
	var all_ids := SoundtrackManager.all_track_ids()
	var titan_idx := all_ids.find("ost_sawano_titan_breach")
	print("Found ost_sawano_titan_breach at index: %d" % titan_idx)
	
	juke._select_track(titan_idx)
	print("Track details: %s | %s" % [juke._title_label.text, juke._category_badge.text])
	assert(juke._category_badge.text == "[ SAWANO / TITAN SPECIAL ]", "Badge must be SAWANO / TITAN SPECIAL")
	assert(juke._status_badge.text.contains("✔"), "Audio file must be present on disk")
	
	# Test Play
	juke._on_play_pressed()
	print("Play status: %s" % juke._now_playing_label.text)
	assert(juke._manager.current_track_id() == "ost_sawano_titan_breach", "Current track must be ost_sawano_titan_breach")
	
	# Test all 6 Vocal Tracks in Sawano Suite
	var vocal_targets := [
		"ost_sawano_titan_breach_vocal",
		"ost_sawano_k21_vocal",
		"ost_sawano_wings_of_freedom_vocal",
		"ost_sawano_shiganshina_cry_vocal",
		"ost_sawano_colossal_smash_vocal",
		"ost_sawano_barricades_vocal"
	]
	for vox_id in vocal_targets:
		var v_idx := all_ids.find(vox_id)
		assert(v_idx != -1, "%s must be present in all_track_ids" % vox_id)
		juke._select_track(v_idx)
		assert(juke._category_badge.text == "[ SAWANO / TITAN SPECIAL ]", "Badge must be SAWANO / TITAN SPECIAL")
		assert(juke._status_badge.text.contains("✔"), "%s audio file must be present on disk" % vox_id)
		juke._on_play_pressed()
		assert(juke._manager.current_track_id() == vox_id, "Current track must match %s" % vox_id)
		print("Verified Vocal Anthem: %s -> %s" % [vox_id, juke._now_playing_label.text])

	# Test Dragon Ball GT Tracks (including the 2 sung vocal anthems)
	var dbgt_targets := [
		"ost_dbgt_dan_dan_vocal",
		"ost_dbgt_dont_you_see_vocal",
		"ost_dbgt_grand_tour",
		"ost_dbgt_super_saiyan_4",
		"ost_dbgt_sabitsuita_machine_gun"
	]
	for db_id in dbgt_targets:
		var db_idx := all_ids.find(db_id)
		assert(db_idx != -1, "%s must be present in all_track_ids" % db_id)
		juke._select_track(db_idx)
		assert(juke._category_badge.text == "[ DRAGON BALL GT / 90S ANIME ]", "Badge must be DRAGON BALL GT / 90S ANIME")
		assert(juke._status_badge.text.contains("✔"), "%s audio file must be present on disk" % db_id)
		juke._on_play_pressed()
		assert(juke._manager.current_track_id() == db_id, "Current track must match %s" % db_id)
		print("Verified Dragon Ball GT OST: %s -> %s" % [db_id, juke._now_playing_label.text])
	
	# Test 5 New Boss & Battle Champions Special Tracks
	var boss_targets := [
		"ost_apex_victory",
		"ost_clash_of_champions",
		"ost_reflex_strike",
		"ost_iron_juggernaut",
		"ost_thunder_strike"
	]
	for boss_id in boss_targets:
		var b_idx := all_ids.find(boss_id)
		assert(b_idx != -1, "%s must be present in all_track_ids" % boss_id)
		juke._select_track(b_idx)
		assert(juke._category_badge.text == "[ EPICO / ANIME SPECIAL ]", "Badge must be EPICO / ANIME SPECIAL")
		assert(juke._status_badge.text.contains("✔"), "%s audio file must be present on disk" % boss_id)
		juke._on_play_pressed()
		assert(juke._manager.current_track_id() == boss_id, "Current track must match %s" % boss_id)
		print("Verified Boss Special OST: %s -> %s" % [boss_id, juke._now_playing_label.text])

	# Test 6 New Suno Vocal Anthems (Canzoni Cantate)
	var vocal_new_targets := [
		"ost_vocal_gleiches_blut",
		"ost_vocal_tie_break_burn",
		"ost_vocal_maschine_jagd",
		"ost_vocal_schwarzmarkt",
		"ost_vocal_nullpunkt",
		"ost_vocal_zheleznaia_volya",
		"ost_vocal_double_rebond",
		"ost_vocal_oltre_il_vetro",
		"ost_vocal_padelista_energy",
		"ost_vocal_balle_de_match"
	]
	for v_id in vocal_new_targets:
		var v_idx := all_ids.find(v_id)
		assert(v_idx != -1, "%s must be present in all_track_ids" % v_id)
		juke._select_track(v_idx)
		assert(juke._category_badge.text == "[ CANZONI CANTATE ]", "Badge must be CANZONI CANTATE")
		assert(juke._status_badge.text.contains("✔"), "%s audio file must be present on disk" % v_id)
		juke._on_play_pressed()
		assert(juke._manager.current_track_id() == v_id, "Current track must match %s" % v_id)
		print("Verified Vocal Anthem: %s -> %s" % [v_id, juke._now_playing_label.text])

	# Ensure Track 16 (ost_sawano_counterattack) is still present and working
	var k21_orig_idx := all_ids.find("ost_sawano_counterattack")
	assert(k21_orig_idx != -1, "Original Track 16 ost_sawano_counterattack must remain intact")
	juke._select_track(k21_orig_idx)
	juke._on_play_pressed()
	assert(juke._manager.current_track_id() == "ost_sawano_counterattack", "Track 16 must play properly")
	
	juke._on_stop_pressed()
	print("All Jukebox 98-track features verified successfully!")
	quit(0)
