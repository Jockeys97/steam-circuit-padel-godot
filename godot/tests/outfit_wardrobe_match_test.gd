extends SceneTree

const Config := preload("res://game/match_config.gd")
const Save := preload("res://src/modes/modes_save.gd")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")
const Spawn := preload("res://src/character/athlete_spawn.gd")
const Lineup := preload("res://game/lineup.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1

func run() -> void:
	Config.save_dir = "user://outfit-flow-%s" % Time.get_ticks_usec()
	var career := Save.load_career(Config.save_store())
	career["unlockAll"] = true
	Save.save_career(Config.save_store(), career)
	var screen = load("res://src/ui/screens/CharactersScreen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	for id in ["maestro", "fiamma"]:
		for outfit in ["circuit", "legend", "signature"]:
			check(screen.equip_outfit(id, outfit), "wardrobe accepts %s/%s" % [id, outfit])
			check(Lineup.equipped_outfit(id, Save.load_career(Config.save_store())) == StringName(outfit),
				"saved selection survives reload %s/%s" % [id, outfit])
			var selected := Lineup.equipped_outfit(id, Save.load_career(Config.save_store()))
			var rig := Spawn.make(StringName(id), selected)
			check(rig != null and Catalogue.read_back(rig).get("visual_status") == "applied",
				"saved selection produces real shader %s/%s" % [id, outfit])
			if rig != null:
				rig.free()
	check(screen.equip_outfit("oracolo", "signature"), "wardrobe accepts Oracolo signature")
	check(screen.equip_outfit("colosso", "signature"), "wardrobe accepts Colosso signature")
	var colosso := Spawn.make(&"colosso", &"signature")
	check(colosso != null, "Colosso original animated rig loads")
	if colosso != null:
		var material = colosso.get_mesh_instance().get_surface_override_material(0)
		var other := Spawn.make(&"colosso", &"base")
		check(other != null and other.is_base_surface(), "Colosso texture does not contaminate another player")
		if other != null:
			other.free()
		check(Catalogue.apply(colosso, &"colosso", &"base") and colosso.is_base_surface(), "Colosso restores base")
		check(Catalogue.apply(colosso, &"colosso", &"signature") and colosso.get_mesh_instance().get_surface_override_material(0) == material,
			"Colosso reuses per-instance texture material")
		check(colosso.play_clip(&"run"), "Colosso keeps original running animation")
		colosso.free()
	check(screen.equip_outfit("maestro", "mythic"), "Maestro mythic can be equipped when unlocked")
	check(screen.equip_outfit("fiamma", "mythic"), "Fiamma mythic is now supported")
	check(screen.equip_outfit("fiamma", "signature"), "restore fixture signature for teammate")
	Save.save_pref(Config.save_store(), "lineup", {"playerMate": "fiamma", "opponent": "oracolo", "opponentMate": "colosso"})
	Lineup.set_pref_source(Config.stored_prefs())
	Config.athlete_index = 0
	Config.pending_mode = "quick"
	var match_node = load("res://game/Match.tscn").instantiate()
	match_node.harness_mode()
	root.add_child(match_node)
	await process_frame
	check(match_node.build_athletes() == 4, "actual match builds all four rigs")
	for role in ["player", "playerMate", "opponent", "opponentMate"]:
		var rig = match_node._athletes.rigs[role]
		var report := Catalogue.read_back(rig)
		var expected := "mythic" if role == "player" else "signature"
		check(match_node._athletes.outfits[role] == expected, "saved outfit reaches court role %s" % role)
		check(report.get("visual_status") == "applied", "real material applied on %s" % role)
		if role == "player":
			check(rig.get_athlete_glb_path().contains("/mythic/"), "actual Match uses new Mythic geometry")
			check(not Spawn.set_outfit(rig, &"maestro", &"base"), "live geometry switch rejected without corrupting rig")
	for outfit in [&"base", &"circuit", &"legend", &"signature"]:
		var base_rig := Spawn.make(&"maestro", outfit)
		check(base_rig != null and base_rig.get_athlete_glb_path() == "res://assets/athletes/maestro.glb", "original Maestro preserved: %s" % outfit)
		if base_rig != null:
			base_rig.free()
	check(Lineup.equipped_outfit("maestro", {"equippedOutfits":{"maestro":"mythic"},"outfitsWon":{}}) == &"base", "locked Mythic cannot bypass challenge")
	var locked := {"equippedOutfits": {"maestro": "signature"}, "outfitsWon": {}}
	check(Lineup.equipped_outfit("maestro", locked) == &"base", "locked saved outfit cannot bypass challenge")
	if "--capture" in OS.get_cmdline_user_args():
		screen.hide()
		match_node._sync_views()
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var capture_dir := ProjectSettings.globalize_path("res://../docs/agent-work/meshy-outfit-trial/runtime")
		DirAccess.make_dir_recursive_absolute(capture_dir)
		check(root.get_texture().get_image().save_png(capture_dir.path_join("mythic-match.png")) == OK, "real match capture saved")
	match_node.queue_free()
	screen.queue_free()
	await process_frame
	print("OUTFIT_WARDROBE_MATCH ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
