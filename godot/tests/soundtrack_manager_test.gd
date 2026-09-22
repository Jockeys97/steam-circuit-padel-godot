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

	# 1. Catalog integrity & count (30 OST tracks)
	var all_tracks := SoundtrackManager.all_track_ids()
	_assert_eq(all_tracks.size(), 30, "Catalog contains exactly 30 distinct OST track IDs")

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

	sm.queue_free()
	await process_frame

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
