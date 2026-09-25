extends SceneTree

const MusicPreferences := preload("res://src/audio/music_preferences.gd")

class DummyStore:
	func read_group(_grp: String) -> Dictionary:
		return {"payload": {}}

func _init() -> void:
	var store = DummyStore.new()
	var menu_tracks := [
		"ost_menu",
		"ost_roster",
		"ost_career",
		"ost_menu_velvet_lounge",
		"ost_menu_grand_touring",
		"ost_menu_astral_solitude",
		"ost_menu_dearly_reminiscent",
		"ost_menu_cyber_terminal",
		"ost_menu_breeze_plaza",
		"ost_menu_sacred_spring",
		"ost_menu_ancient_sanctum",
		"ost_menu_rainy_atrium",
		"ost_menu_chronicle_winds",
		"ost_menu_subaquatic_drift",
		"ost_menu_northern_aurora",
		"ost_menu_champions_pavilion",
		"ost_menu_orbital_vanguard",
		"ost_menu_third_strike"
	]
	var failures := 0
	for tid in menu_tracks:
		var in_menu := MusicPreferences.belongs(store, tid, "menu")
		var in_match := MusicPreferences.belongs(store, tid, "match")
		print("Checking %s: in_menu=%s, in_match=%s" % [tid, in_menu, in_match])
		if not in_menu:
			print("  FAIL: %s should be in menu!" % tid)
			failures += 1
		if in_match:
			print("  FAIL: %s should NOT be in match!" % tid)
			failures += 1

	var match_sample := ["ost_officina", "ost_sawano_titan_breach", "ost_dbgt_dan_dan_vocal", "ost_rays_of_rust", "ost_hyori_ittai_vocal"]
	for tid in match_sample:
		var in_menu := MusicPreferences.belongs(store, tid, "menu")
		var in_match := MusicPreferences.belongs(store, tid, "match")
		print("Checking match track %s: in_menu=%s, in_match=%s" % [tid, in_menu, in_match])
		if in_menu:
			print("  FAIL: %s should NOT be in menu!" % tid)
			failures += 1
		if not in_match:
			print("  FAIL: %s should be in match!" % tid)
			failures += 1

	if failures == 0:
		print("[SUCCESS] All 18 menu tracks belong to 'Musiche menu' and NOT to 'Musiche partita'!")
		quit(0)
	else:
		print("FAILURES: %d" % failures)
		quit(1)
