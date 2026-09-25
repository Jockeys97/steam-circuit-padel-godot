extends SceneTree
## soundtrack_manager_test.gd — Automated tests for SoundtrackManager and OST routing.
##
## Run with:
##   godot --headless --path godot --script res://tests/soundtrack_manager_test.gd

const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	await _run()
	var code := 1 if _failures > 0 else 0
	quit(code)


func _run() -> void:
	print("[soundtrack_manager_test] Starting verification suite...")

	# 1. Catalog integrity & count (83 OST tracks: 22 standard + 8 epic + 12 Sawano + 5 DBGT + 15 Automata + 1 HxH + 15 Menu Legends + 5 Canzoni Cantate)
	var all_tracks := SoundtrackManager.all_track_ids()
	_assert_eq(all_tracks.size(), 83, "Catalog contains exactly 83 distinct OST track IDs")

	# 2. Frozen 9 Arena Mappings
	_assert_eq(SoundtrackManager.track_id_for_arena("officina"), "ost_officina", "Arena officina maps to ost_officina")
	_assert_eq(SoundtrackManager.track_id_for_arena("fonderia"), "ost_fonderia", "Arena fonderia maps to ost_fonderia")
	_assert_eq(SoundtrackManager.track_id_for_arena("cattedrale"), "ost_cattedrale", "Arena cattedrale maps to ost_cattedrale")
	_assert_eq(SoundtrackManager.track_id_for_arena("forgia"), "ost_forgia", "Arena forgia maps to ost_forgia")
	_assert_eq(SoundtrackManager.track_id_for_arena("osservatorio"), "ost_osservatorio", "Arena osservatorio maps to ost_osservatorio")
	_assert_eq(SoundtrackManager.track_id_for_arena("tempesta"), "ost_tempesta", "Arena tempesta maps to ost_tempesta")
	_assert_eq(SoundtrackManager.track_id_for_arena("abissale"), "ost_abissale", "Arena abissale maps to ost_abissale")
	_assert_eq(SoundtrackManager.track_id_for_arena("caldera"), "ost_caldera", "Arena caldera maps to ost_caldera")
	_assert_eq(SoundtrackManager.track_id_for_arena("orrery"), "ost_orrery", "Arena orrery maps to ost_orrery")

	# 3. World 5 Arena Mappings
	_assert_eq(SoundtrackManager.track_id_for_arena("torii"), "ost_torii", "World arena torii maps to ost_torii")
	_assert_eq(SoundtrackManager.track_id_for_arena("medina"), "ost_medina", "World arena medina maps to ost_medina")
	_assert_eq(SoundtrackManager.track_id_for_arena("carioca"), "ost_carioca", "World arena carioca maps to ost_carioca")
	_assert_eq(SoundtrackManager.track_id_for_arena("aurora"), "ost_aurora", "World arena aurora maps to ost_aurora")
	_assert_eq(SoundtrackManager.track_id_for_arena("egeo"), "ost_egeo", "World arena egeo maps to ost_egeo")

	# 4. Special New Arenas
	_assert_eq(SoundtrackManager.track_id_for_arena("heritage_hall"), "ost_heritage_hall", "Heritage Hall maps to ost_heritage_hall")
	_assert_eq(SoundtrackManager.track_id_for_arena("steam_workshop"), "ost_steam_workshop", "Steam Workshop maps to ost_steam_workshop")

	# 5. System & UI Context Mappings
	_assert_eq(SoundtrackManager.track_id_for_context("menu"), "ost_menu", "Context menu maps to ost_menu")
	_assert_eq(SoundtrackManager.track_id_for_context("roster"), "ost_roster", "Context roster maps to ost_roster")
	_assert_eq(SoundtrackManager.track_id_for_context("career"), "ost_career", "Context career maps to ost_career")
	_assert_eq(SoundtrackManager.track_id_for_context("training"), "ost_training", "Context training maps to ost_training")
	_assert_eq(SoundtrackManager.track_id_for_context("climax"), "ost_climax", "Context climax maps to ost_climax")
	_assert_eq(SoundtrackManager.track_id_for_context("victory"), "ost_victory", "Context victory maps to ost_victory")

	# 5b. Epic / Anime Special Context Mappings
	_assert_eq(SoundtrackManager.track_id_for_context("epic_anthem"), "ost_epic_anthem", "Context epic_anthem maps to ost_epic_anthem")
	_assert_eq(SoundtrackManager.track_id_for_context("epic_semifinal"), "ost_epic_semifinal", "Context epic_semifinal maps to ost_epic_semifinal")
	_assert_eq(SoundtrackManager.track_id_for_context("epic_grand_final"), "ost_epic_grand_final", "Context epic_grand_final maps to ost_epic_grand_final")
	_assert_eq(SoundtrackManager.track_id_for_context("epic_rival_legend"), "ost_epic_rival_legend", "Context epic_rival_legend maps to ost_epic_rival_legend")
	_assert_eq(SoundtrackManager.track_id_for_context("epic_awakening"), "ost_epic_awakening", "Context epic_awakening maps to ost_epic_awakening")
	_assert_eq(SoundtrackManager.track_id_for_context("epic_sudden_death"), "ost_epic_sudden_death", "Context epic_sudden_death maps to ost_epic_sudden_death")
	_assert_eq(SoundtrackManager.track_id_for_context("epic_ascension"), "ost_epic_ascension", "Context epic_ascension maps to ost_epic_ascension")
	_assert_eq(SoundtrackManager.track_id_for_context("epic_rematch"), "ost_epic_rematch", "Context epic_rematch maps to ost_epic_rematch")

	# 5c. Sawano / Attack on Titan Special Context Mappings (6 Instrumental + 6 Vocal Anthems)
	_assert_eq(SoundtrackManager.track_id_for_context("titan_breach"), "ost_sawano_titan_breach", "Context titan_breach maps to ost_sawano_titan_breach")
	_assert_eq(SoundtrackManager.track_id_for_context("titan_breach_vocal"), "ost_sawano_titan_breach_vocal", "Context titan_breach_vocal maps to ost_sawano_titan_breach_vocal")
	_assert_eq(SoundtrackManager.track_id_for_context("counterattack"), "ost_sawano_counterattack", "Context counterattack maps to ost_sawano_counterattack")
	_assert_eq(SoundtrackManager.track_id_for_context("k21_vocal"), "ost_sawano_k21_vocal", "Context k21_vocal maps to ost_sawano_k21_vocal")
	_assert_eq(SoundtrackManager.track_id_for_context("wings_of_freedom"), "ost_sawano_wings_of_freedom", "Context wings_of_freedom maps to ost_sawano_wings_of_freedom")
	_assert_eq(SoundtrackManager.track_id_for_context("wings_of_freedom_vocal"), "ost_sawano_wings_of_freedom_vocal", "Context wings_of_freedom_vocal maps to ost_sawano_wings_of_freedom_vocal")
	_assert_eq(SoundtrackManager.track_id_for_context("shiganshina_cry"), "ost_sawano_shiganshina_cry", "Context shiganshina_cry maps to ost_sawano_shiganshina_cry")
	_assert_eq(SoundtrackManager.track_id_for_context("shiganshina_cry_vocal"), "ost_sawano_shiganshina_cry_vocal", "Context shiganshina_cry_vocal maps to ost_sawano_shiganshina_cry_vocal")
	_assert_eq(SoundtrackManager.track_id_for_context("colossal_smash"), "ost_sawano_colossal_smash", "Context colossal_smash maps to ost_sawano_colossal_smash")
	_assert_eq(SoundtrackManager.track_id_for_context("colossal_smash_vocal"), "ost_sawano_colossal_smash_vocal", "Context colossal_smash_vocal maps to ost_sawano_colossal_smash_vocal")
	_assert_eq(SoundtrackManager.track_id_for_context("barricades"), "ost_sawano_barricades", "Context barricades maps to ost_sawano_barricades")
	_assert_eq(SoundtrackManager.track_id_for_context("barricades_vocal"), "ost_sawano_barricades_vocal", "Context barricades_vocal maps to ost_sawano_barricades_vocal")

	# 5d. Dragon Ball GT / 90s Anime Suite Context Mappings (2 Sung Vocal Anthems + 3 Instrumentals)
	_assert_eq(SoundtrackManager.track_id_for_context("dbgt_dan_dan_vocal"), "ost_dbgt_dan_dan_vocal", "Context dbgt_dan_dan_vocal maps to ost_dbgt_dan_dan_vocal")
	_assert_eq(SoundtrackManager.track_id_for_context("dbgt_dont_you_see_vocal"), "ost_dbgt_dont_you_see_vocal", "Context dbgt_dont_you_see_vocal maps to ost_dbgt_dont_you_see_vocal")
	_assert_eq(SoundtrackManager.track_id_for_context("dbgt_grand_tour"), "ost_dbgt_grand_tour", "Context dbgt_grand_tour maps to ost_dbgt_grand_tour")
	_assert_eq(SoundtrackManager.track_id_for_context("dbgt_super_saiyan_4"), "ost_dbgt_super_saiyan_4", "Context dbgt_super_saiyan_4 maps to ost_dbgt_super_saiyan_4")
	_assert_eq(SoundtrackManager.track_id_for_context("dbgt_sabitsuita_machine_gun"), "ost_dbgt_sabitsuita_machine_gun", "Context dbgt_sabitsuita_machine_gun maps to ost_dbgt_sabitsuita_machine_gun")

	# 5e. Automata Suite Context Mappings (15 Acoustic / Choral / Orchestral Tracks)
	_assert_eq(SoundtrackManager.track_id_for_context("rays_of_rust"), "ost_rays_of_rust", "Context rays_of_rust maps to ost_rays_of_rust")
	_assert_eq(SoundtrackManager.track_id_for_context("weight_of_the_rally"), "ost_weight_of_the_rally", "Context weight_of_the_rally maps to ost_weight_of_the_rally")
	_assert_eq(SoundtrackManager.track_id_for_context("beautiful_duel"), "ost_beautiful_duel", "Context beautiful_duel maps to ost_beautiful_duel")
	_assert_eq(SoundtrackManager.track_id_for_context("memories_of_sand"), "ost_memories_of_sand", "Context memories_of_sand maps to ost_memories_of_sand")
	_assert_eq(SoundtrackManager.track_id_for_context("rebirth_of_hope"), "ost_rebirth_of_hope", "Context rebirth_of_hope maps to ost_rebirth_of_hope")
	_assert_eq(SoundtrackManager.track_id_for_context("broken_monolith"), "ost_broken_monolith", "Context broken_monolith maps to ost_broken_monolith")
	_assert_eq(SoundtrackManager.track_id_for_context("city_of_pearls"), "ost_city_of_pearls", "Context city_of_pearls maps to ost_city_of_pearls")
	_assert_eq(SoundtrackManager.track_id_for_context("tears_of_porcelain"), "ost_tears_of_porcelain", "Context tears_of_porcelain maps to ost_tears_of_porcelain")
	_assert_eq(SoundtrackManager.track_id_for_context("hymn_of_the_ancients"), "ost_hymn_of_the_ancients", "Context hymn_of_the_ancients maps to ost_hymn_of_the_ancients")
	_assert_eq(SoundtrackManager.track_id_for_context("ashes_of_destiny"), "ost_ashes_of_destiny", "Context ashes_of_destiny maps to ost_ashes_of_destiny")
	_assert_eq(SoundtrackManager.track_id_for_context("carnival_of_illusions"), "ost_carnival_of_illusions", "Context carnival_of_illusions maps to ost_carnival_of_illusions")
	_assert_eq(SoundtrackManager.track_id_for_context("verdant_whispers"), "ost_verdant_whispers", "Context verdant_whispers maps to ost_verdant_whispers")
	_assert_eq(SoundtrackManager.track_id_for_context("abyssal_silence"), "ost_abyssal_silence", "Context abyssal_silence maps to ost_abyssal_silence")
	_assert_eq(SoundtrackManager.track_id_for_context("dance_of_the_blade"), "ost_dance_of_the_blade", "Context dance_of_the_blade maps to ost_dance_of_the_blade")
	_assert_eq(SoundtrackManager.track_id_for_context("cradle_of_waves"), "ost_cradle_of_waves", "Context cradle_of_waves maps to ost_cradle_of_waves")

	# 5f. Hunter x Hunter Special Vocal Anthem
	_assert_eq(SoundtrackManager.track_id_for_context("hyori_ittai_vocal"), "ost_hyori_ittai_vocal", "Context hyori_ittai_vocal maps to ost_hyori_ittai_vocal")

	# 5g. Legendary Game Menu Themes Context Mappings
	_assert_eq(SoundtrackManager.track_id_for_context("menu_velvet_lounge"), "ost_menu_velvet_lounge", "Context menu_velvet_lounge maps to ost_menu_velvet_lounge")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_grand_touring"), "ost_menu_grand_touring", "Context menu_grand_touring maps to ost_menu_grand_touring")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_astral_solitude"), "ost_menu_astral_solitude", "Context menu_astral_solitude maps to ost_menu_astral_solitude")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_dearly_reminiscent"), "ost_menu_dearly_reminiscent", "Context menu_dearly_reminiscent maps to ost_menu_dearly_reminiscent")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_cyber_terminal"), "ost_menu_cyber_terminal", "Context menu_cyber_terminal maps to ost_menu_cyber_terminal")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_breeze_plaza"), "ost_menu_breeze_plaza", "Context menu_breeze_plaza maps to ost_menu_breeze_plaza")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_sacred_spring"), "ost_menu_sacred_spring", "Context menu_sacred_spring maps to ost_menu_sacred_spring")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_ancient_sanctum"), "ost_menu_ancient_sanctum", "Context menu_ancient_sanctum maps to ost_menu_ancient_sanctum")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_rainy_atrium"), "ost_menu_rainy_atrium", "Context menu_rainy_atrium maps to ost_menu_rainy_atrium")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_chronicle_winds"), "ost_menu_chronicle_winds", "Context menu_chronicle_winds maps to ost_menu_chronicle_winds")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_subaquatic_drift"), "ost_menu_subaquatic_drift", "Context menu_subaquatic_drift maps to ost_menu_subaquatic_drift")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_northern_aurora"), "ost_menu_northern_aurora", "Context menu_northern_aurora maps to ost_menu_northern_aurora")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_champions_pavilion"), "ost_menu_champions_pavilion", "Context menu_champions_pavilion maps to ost_menu_champions_pavilion")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_orbital_vanguard"), "ost_menu_orbital_vanguard", "Context menu_orbital_vanguard maps to ost_menu_orbital_vanguard")
	_assert_eq(SoundtrackManager.track_id_for_context("menu_third_strike"), "ost_menu_third_strike", "Context menu_third_strike maps to ost_menu_third_strike")
	_assert_eq(SoundtrackManager.track_id_for_context("vocal_overdrive_line"), "ost_vocal_overdrive_line", "Context vocal_overdrive_line maps to ost_vocal_overdrive_line")
	_assert_eq(SoundtrackManager.track_id_for_context("vocal_break_point_riot"), "ost_vocal_break_point_riot", "Context vocal_break_point_riot maps to ost_vocal_break_point_riot")
	_assert_eq(SoundtrackManager.track_id_for_context("vocal_reach_for_the_sun"), "ost_vocal_reach_for_the_sun", "Context vocal_reach_for_the_sun maps to ost_vocal_reach_for_the_sun")
	_assert_eq(SoundtrackManager.track_id_for_context("vocal_neon_velocity"), "ost_vocal_neon_velocity", "Context vocal_neon_velocity maps to ost_vocal_neon_velocity")
	_assert_eq(SoundtrackManager.track_id_for_context("vocal_girei"), "ost_vocal_girei", "Context vocal_girei maps to ost_vocal_girei")

	# 6. Candidate Paths Formatting
	var paths := SoundtrackManager.candidate_paths("ost_officina")
	_assert(paths.has("res://assets/audio/music/ost_officina.ogg"), "Candidate paths include .ogg")
	_assert(paths.has("res://assets/audio/music/ost_officina.mp3"), "Candidate paths include .mp3")
	_assert(paths.has("res://assets/audio/music/ost_officina.wav"), "Candidate paths include .wav")

	# 7. Node instantiation, dual audio players & bus wiring
	var sm := SoundtrackManager.new()
	root.add_child(sm)
	# Process one frame so _ready() executes
	await process_frame

	var player_a: AudioStreamPlayer = sm.get_node_or_null("MusicPlayerA")
	var player_b: AudioStreamPlayer = sm.get_node_or_null("MusicPlayerB")
	_assert(player_a != null, "MusicPlayerA node is created")
	_assert(player_b != null, "MusicPlayerB node is created")
	if player_a != null:
		_assert_eq(player_a.bus, "Music", "MusicPlayerA is wired to Music bus")
	if player_b != null:
		_assert_eq(player_b.bus, "Music", "MusicPlayerB is wired to Music bus")

	# 8. Safe Fallback Behavior (missing files return false without crashing)
	var played := sm.play_track("non_existent_dummy_ost", 0.1)
	_assert(!played, "Missing track returns false safely")
	_assert_eq(sm.get_current_track_id(), "", "Current track remains empty when playback fails")

	var played_arena := sm.play_for_arena("officina", 0.1)
	if not SoundtrackManager.has_track("ost_officina"):
		_assert(!played_arena, "play_for_arena returns false when assets are not yet on disk")
	else:
		_assert(played_arena, "play_for_arena plays ost_officina successfully when asset is on disk")
		_assert_eq(sm.get_current_track_id(), "ost_officina", "Current track is ost_officina")

	# 9. Stop and Intensity controls
	sm.set_intensity(1.5) # Should clamp to 1.0
	_assert_eq(sm._current_intensity, 1.0, "Intensity is clamped to maximum 1.0")
	sm.set_intensity(-0.5) # Should clamp to 0.0
	_assert_eq(sm._current_intensity, 0.0, "Intensity is clamped to minimum 0.0")

	sm.stop(0.0)
	_assert_eq(sm.get_current_track_id(), "", "stop() resets current track ID")

	# 10. Preview offsets for vocal tracks and defaults
	_assert_eq(SoundtrackManager.preview_offset("ost_vocal_overdrive_line"), 26.0, "Overdrive Line preview offset is 26.0s")
	_assert_eq(SoundtrackManager.preview_offset("ost_vocal_break_point_riot"), 40.0, "Break Point Riot preview offset is 40.0s")
	_assert_eq(SoundtrackManager.preview_offset("ost_vocal_reach_for_the_sun"), 40.0, "Reach for the Sun preview offset is 40.0s")
	_assert_eq(SoundtrackManager.preview_offset("ost_vocal_neon_velocity"), 60.0, "Neon Velocity preview offset is 60.0s")
	_assert_eq(SoundtrackManager.preview_offset("ost_vocal_girei"), 115.5, "Girei preview offset is 115.5s")
	_assert_eq(SoundtrackManager.preview_offset("ost_hyori_ittai_vocal"), 18.7, "Hyori Ittai preview offset is 18.7s")
	_assert_eq(SoundtrackManager.preview_offset("ost_officina"), 0.0, "Standard track offset defaults to 0.0s")
	_assert_eq(SoundtrackManager.preview_offset("non_existent_track"), 0.0, "Unknown track offset defaults to 0.0s")

	sm.queue_free()
	await process_frame
	# Decoder disposal is queued on the audio thread, not the scene-tree frame.
	await create_timer(0.1).timeout

	print("\n[soundtrack_manager_test] Results: %d checks, %d failures." % [_checks, _failures])
	if _failures == 0:
		print("PASS all soundtrack manager checks!")
	else:
		print("FAIL soundtrack manager checks.")


func _assert(condition: bool, msg: String) -> void:
	_checks += 1
	if condition:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)


func _assert_eq(actual, expected, msg: String) -> void:
	_checks += 1
	if actual == expected:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s (got: %s, expected: %s)" % [msg, str(actual), str(expected)])
