extends SceneTree

const Catalogue := preload("res://src/character/outfit_catalogue.gd")
const Spawn := preload("res://src/character/athlete_spawn.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const Lineup := preload("res://game/lineup.gd")
const Config := preload("res://game/match_config.gd")
const Save := preload("res://src/modes/modes_save.gd")
const Art := preload("res://src/ui/data/UiArtPaths.gd")
const Locale := preload("res://src/locale/locale.gd")
const Concept := preload("res://src/character/concept_outfits.gd")
const Economy := preload("res://src/economy/economy_service.gd")
const OutfitShop := preload("res://src/economy/outfit_shop_catalog.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	if not ok:
		failures += 1


func run() -> void:
	Config.save_dir = "user://concept-outfits-%s" % Time.get_ticks_usec()
	var store := Config.save_store()
	check(bool(Economy.ensure_initialized(store).get("ok", false)), "isolated outfit wallet initialized")
	var wallet: Dictionary = store.read_group("economy")["payload"]
	wallet["credits"] = 1500
	check(bool(store.write_group("economy", wallet).get("ok", false)), "test wallet funded")
	var screen: Variant = load("res://src/ui/screens/CharactersScreen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	for spec in [["fiamma", "solar_sprint", 1], ["maestro", "polar_ace", 2]]:
		var athlete_id := String(spec[0])
		var outfit_id := String(spec[1])
		var style := int(spec[2])
		check(Catalogue.outfit_ids(StringName(athlete_id)).find(StringName(outfit_id)) == -1,
			"frozen reference excludes %s" % outfit_id)
		check(Spawn.outfit_ids(StringName(athlete_id)).has(StringName(outfit_id)),
			"playable list includes %s" % outfit_id)
		check(Tables.playable_outfits_for_athlete(athlete_id).size() == Tables.outfits_for_athlete(athlete_id).size() + 1,
			"wardrobe adds exactly one kit for %s" % athlete_id)
		check(Catalogue.is_renderable(StringName(athlete_id), StringName(outfit_id)),
			"%s is renderable" % outfit_id)
		check(Art.outfit_path_for(athlete_id, outfit_id).ends_with("%s-preview.webp" % outfit_id),
			"%s has its own imported preview" % outfit_id)
		check(Locale.is_resolvable(Spawn.outfit_name_key(StringName(athlete_id), StringName(outfit_id)), "it")
			and Locale.is_resolvable(Spawn.outfit_name_key(StringName(athlete_id), StringName(outfit_id)), "en"),
			"%s has localized names" % outfit_id)
		var unlock_key := "%s:%s" % [athlete_id, outfit_id]
		var outfit_row: Dictionary = Concept.menu_rows(athlete_id)[0]
		check(bool(outfit_row.get("shopOnly", false)) and not CareerRules.is_unlocked(outfit_row, Save.load_career(store)),
			"%s starts locked in the wardrobe" % outfit_id)
		check(CareerRules.is_unlocked(outfit_row, {"unlockAll": true}),
			"Lucale still unlocks %s" % outfit_id)
		var purchased_view := {}
		purchased_view[unlock_key] = true
		check(not CareerRules.is_unlocked(outfit_row, {"lockAll": true, "outfitsPurchased": purchased_view}),
			"Alelu temporarily relocks %s" % outfit_id)
		check(not screen.equip_outfit(athlete_id, outfit_id), "wardrobe cannot equip unbought %s" % outfit_id)
		check(OutfitShop.price_of(unlock_key) == 750, "%s has a server-side Emporio price" % outfit_id)
		check(bool(Economy.purchase_outfit(store, unlock_key).get("ok", false)), "Emporio buys %s" % outfit_id)
		screen.refresh_data()
		check(screen.equip_outfit(athlete_id, outfit_id), "wardrobe equips %s" % outfit_id)
		var saved := Save.load_career(Config.save_store())
		check(Lineup.equipped_outfit(athlete_id, saved) == StringName(outfit_id),
			"saved %s reaches lineup" % outfit_id)
		var rig: Node3D = Spawn.make(StringName(athlete_id), Lineup.equipped_outfit(athlete_id, saved))
		check(rig != null, "field rig spawns %s" % outfit_id)
		if rig != null:
			var material: ShaderMaterial = rig.get_catalogue_surface()
			check(material != null and int(material.get_shader_parameter("concept_style")) == style,
				"%s has its real field material" % outfit_id)
			check(Catalogue.apply(rig, StringName(athlete_id), &"circuit"),
				"%s can switch to existing kit" % outfit_id)
			check(int(material.get_shader_parameter("concept_style")) == 0,
				"existing kit clears concept graphic")
			check(Catalogue.apply(rig, StringName(athlete_id), StringName(outfit_id))
				and int(material.get_shader_parameter("concept_style")) == style,
				"%s survives a round-trip" % outfit_id)
			rig.free()
	check(Economy.balance(store) == 0 and Economy.owned_outfit_keys(store).size() == 2,
		"both shop-only kits persist with exact debit")
	if "--capture" in OS.get_cmdline_user_args():
		check(screen.apply_capture_state("outfit-open"), "wardrobe capture state opens")
		await process_frame
		await RenderingServer.frame_post_draw
		var capture_dir := OS.get_environment("OUTFIT_REVIEW_DIR")
		if capture_dir != "":
			check(root.get_texture().get_image().save_png(capture_dir.path_join("wardrobe-maestro.png")) == OK,
				"wardrobe screenshot saved")
			var scroll: ScrollContainer = screen.get_node("Frame/ScreenScroll")
			scroll.scroll_vertical = 530
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(capture_dir.path_join("wardrobe-maestro-lower.png")) == OK,
				"new kit row screenshot saved")
	# Exercise the same Match scene that play-now uses, not just a standalone rig.
	Save.save_pref(Config.save_store(), "lineup", {
		"playerMate": "fiamma", "opponent": "oracolo", "opponentMate": "colosso"})
	Lineup.set_pref_source(Config.stored_prefs())
	var saved_for_cycle := Save.load_career(Config.save_store())
	check(Lineup.outfits({"player": {"id": "maestro"}}, &"polar_ace", saved_for_cycle).get("player") == &"polar_ace",
		"quick-match outfit cycle can choose the new kit")
	check(Lineup.outfits({"player": {"id": "maestro"}}, &"signature",
		{"equippedOutfits": {}, "outfitsWon": {}}).get("player") == &"base",
		"quick-match outfit cycle cannot bypass old challenge locks")
	Config.athlete_index = 0
	Config.outfit_index = 0
	Config.pending_mode = "quick"
	var match_node: Variant = load("res://game/Match.tscn").instantiate()
	match_node.harness_mode()
	root.add_child(match_node)
	await process_frame
	check(match_node.build_athletes() == 4, "actual Match spawns four athletes")
	for role in ["player", "playerMate"]:
		var wanted := "polar_ace" if role == "player" else "solar_sprint"
		var expected_style := 2 if role == "player" else 1
		var court_rig: Node3D = match_node._athletes.rigs.get(role)
		check(court_rig != null and String(match_node._athletes.outfits.get(role, "")) == wanted,
			"%s reaches actual Match %s" % [wanted, role])
		if court_rig != null:
			var court_material: ShaderMaterial = court_rig.get_catalogue_surface()
			check(court_material != null and int(court_material.get_shader_parameter("concept_style")) == expected_style,
				"%s renders on court" % wanted)
	match_node.queue_free()
	screen.queue_free()
	await process_frame
	print("CONCEPT_OUTFITS ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
