extends SceneTree
## Outfit commerce end-to-end on an isolated save. Never touches the real profile.

const Store := preload("res://src/save/save_store.gd")
const Economy := preload("res://src/economy/economy_service.gd")
const OutfitShop := preload("res://src/economy/outfit_shop_catalog.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const ModeTables := preload("res://src/modes/mode_tables.gd")
const Lineup := preload("res://game/lineup.gd")
const Config := preload("res://game/match_config.gd")
const EmporioScene := preload("res://src/ui/screens/EmporioScreen.tscn")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_dir := Config.save_dir
	Config.save_dir = "user://emporio-outfit-%d" % Time.get_ticks_usec()
	var store := Store.new(Config.save_dir)
	_check(bool(Economy.ensure_initialized(store).get("ok", false)), "isolated economy initialized")
	var rows := OutfitShop.shop_rows()
	_check(rows.size() == 22, "20 challenge outfits and 2 Emporio-only kits appear in catalog")
	_check(OutfitShop.price_of("fiamma:solar_sprint") == 750 and OutfitShop.price_of("maestro:polar_ace") == 750,
		"new 3D kits have fixed Emporio prices")
	_check(OutfitShop.price_of("maestro:circuit") == 600 and OutfitShop.price_of("maestro:mythic") == 1800, "outfit prices exceed 250 CC OST")
	_check(OutfitShop.price_of("maestro:base") == 0 and OutfitShop.price_of("unknown:mythic") == 0, "base and unknown ids cannot be priced")
	_check(String(Economy.purchase_outfit(store, "maestro:circuit").get("reason")) == "insufficient", "insufficient funds refuse purchase")
	_check(String(Economy.purchase_outfit(store, "maestro:base").get("reason")) == "unknown", "base cannot be bought")
	var unsupported := ""
	var supported_count := 0
	for row in rows:
		if bool(row["supported"]):
			supported_count += 1
		if not bool(row["supported"]):
			unsupported = String(row["id"])
	print("renderable challenge outfits: %d/%d" % [supported_count, rows.size()])
	_check(unsupported != "" and String(Economy.purchase_outfit(store, unsupported).get("reason")) == "not_for_sale", "unusable 3D outfit cannot debit")
	var future := Store.new(Config.save_dir + "-future")
	future.write_group("economy", {"credits": 5000, "owned": [], "ownedOutfits": ["maestro:circuit"], "migrationVersion": 2, "receipts": {}})
	_check(Economy.owned_outfit_keys(future).is_empty(), "future economy payload cannot grant outfit access")
	_check(not CareerRules.is_unlocked(ModeTables.outfit_by_unlock_key("maestro:circuit"), ModesSave.load_career(future)), "future outfit stays locked in career view")
	_check(not bool(Economy.purchase_outfit(future, "maestro:legend").get("ok", true)), "future economy refuses purchase")
	var future_career := Store.new(Config.save_dir + "-future-career")
	Economy.ensure_initialized(future_career)
	var future_wallet: Dictionary = future_career.read_group("economy")["payload"]
	future_wallet["credits"] = 5000
	future_career.write_group("economy", future_wallet)
	var file := FileAccess.open(future_career.group_path("career"), FileAccess.WRITE)
	file.store_string('{"format":"padel-save","schemaVersion":99,"group":"career","payload":{"outfitsWon":{}}}')
	file.close()
	_check(bool(Economy.outfit_shop_rows(future_career)[0]["unavailable"]), "future career disables outfit shelf")
	_check(String(Economy.purchase_outfit(future_career, "maestro:circuit").get("reason")) == "store_unavailable" and Economy.balance(future_career) == 5000, "future career cannot consume outfit credits")
	var payload: Dictionary = store.read_group("economy")["payload"]
	payload["credits"] = 5000
	_check(bool(store.write_group("economy", payload).get("ok", false)), "fixture grants test credits")

	root.size = Vector2i(1280, 720)
	var shop: Control = EmporioScene.instantiate()
	shop.set_store(store)
	root.add_child(shop)
	await _settle()
	_check(shop.shop_kind() == "ost", "OST tab remains default")
	shop._set_shop_kind("outfit")
	await _settle()
	_check(shop.shop_kind() == "outfit" and shop.rows().size() == 22, "outfit tab lists challenge and shop-only outfits")
	var before_focus: String = shop.selected_id()
	var polar_card: Button = null
	for card in shop._row_buttons:
		if String(card.get_meta("track_id")) == "maestro:polar_ace":
			polar_card = card
			break
	_check(polar_card != null, "outfit card is reachable")
	if polar_card != null:
		polar_card.mouse_entered.emit()
		polar_card.grab_focus()
		await _settle()
		_check(shop.selected_id() == before_focus, "outfit hover and controller focus do not select")
		var select_action := InputEventAction.new()
		select_action.action = "ui_accept"
		select_action.pressed = true
		root.push_input(select_action)
		select_action.pressed = false
		root.push_input(select_action)
		await _settle()
		_check(shop.selected_id() == "maestro:polar_ace" and not shop.confirm_visible(), "controller confirm selects outfit without buying")
	shop._select_track("maestro:polar_ace")
	_check(shop._preview_cover.texture != null and shop._preview_state.text.find("Sfida:") == -1,
		"Polar Ace uses its portrait and has no invented challenge")
	_check(not shop._ost_filters.visible and not shop._listen_btn.visible, "OST-only controls hidden in outfit tab")
	_check(shop._section_buttons["outfit"].is_visible_in_tree() and shop._row_buttons[0].focus_neighbor_top == shop._row_buttons[0].get_path_to(shop._section_buttons["outfit"]), "outfit cards navigate back to visible section tab")
	var last_card: Button = shop._row_buttons[shop._row_buttons.size() - 1]
	_check(last_card.get_node_or_null(last_card.focus_neighbor_right) == shop._purchase_btn, "last outfit card navigates to visible purchase action")
	last_card.grab_focus()
	await _settle()
	var press := InputEventAction.new()
	press.action = "ui_right"
	press.pressed = true
	root.push_input(press)
	await _settle()
	_check(root.gui_get_focus_owner() == shop._purchase_btn, "controller reaches outfit purchase without hidden audio control")
	press.pressed = false
	root.push_input(press)
	shop._select_track("maestro:circuit")
	shop._purchase_btn.pressed.emit()
	_check(shop.confirm_visible(), "outfit purchase requires confirmation")
	_check(Economy.balance(store) == 5000, "confirmation alone does not debit")
	shop._on_confirm_pressed()
	await _settle()
	_check(bool(shop.last_purchase().get("ok", false)) and not shop.confirm_visible(), "confirmed purchase succeeds")
	_check(Economy.balance(store) == 4400 and Economy.owned_outfit_keys(store).has("maestro:circuit"), "ownership and 600 CC debit persist together")
	var raw_career: Variant = store.read_group("career").get("payload", null)
	var saved_career: Dictionary = raw_career if raw_career is Dictionary else {}
	_check(not (saved_career.get("outfitsWon", {}) as Dictionary).get("maestro:circuit", false), "buying does not forge challenge win")
	_check(String(Economy.purchase_outfit(store, "maestro:circuit").get("reason")) == "owned" and Economy.balance(store) == 4400, "duplicate purchase cannot debit twice")

	var career := ModesSave.load_career(store)
	var circuit := ModeTables.outfit_by_unlock_key("maestro:circuit")
	_check(CareerRules.is_unlocked(circuit, career), "purchased outfit unlocked by career read view")
	career["equippedOutfits"] = {"maestro": "circuit"}
	ModesSave.save_career(store, career)
	_check(not (store.read_group("career")["payload"] as Dictionary).has("outfitsPurchased"), "derived ownership never copied into career save")
	_check(Lineup.equipped_outfit("maestro", ModesSave.load_career(store)) == &"circuit", "purchased outfit reaches match lineup")

	var screen: Control = (load("res://src/ui/screens/CharactersScreen.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await _settle()
	_check(screen.equip_outfit("maestro", "circuit"), "wardrobe accepts purchased outfit")
	screen.queue_free()
	await _settle()
	Config.athlete_index = 0
	Config.pending_mode = "quick"
	var match_node: Node = (load("res://game/Match.tscn") as PackedScene).instantiate()
	match_node.call("harness_mode")
	root.add_child(match_node)
	await _settle()
	_check(match_node.call("build_athletes") == 4 and String(match_node.get("_athletes").outfits.get("player", "")) == "circuit", "real match spawns bought outfit")
	match_node.queue_free()
	await _settle()

	career = ModesSave.load_career(store)
	var newly_won := CareerProgress.award_outfit_challenges(career, "maestro", {"winners": {"player": 4}}, true, 1.0)
	_check(newly_won.any(func(outfit): return String(outfit.get("unlockKey", "")) == "maestro:circuit"), "challenge can still be won after purchase")
	ModesSave.save_career(store, career)
	_check(bool((store.read_group("career")["payload"] as Dictionary).get("outfitsWon", {}).get("maestro:circuit", false)), "challenge win persists separately")

	var future_buy := "fiamma:circuit"
	store.fail_before_rename = true
	var failed := Economy.purchase_outfit(store, future_buy)
	store.fail_before_rename = false
	_check(String(failed.get("reason")) == "write_failed", "atomic write failure reported")
	_check(Economy.balance(store) == 4400 and not Economy.owned_outfit_keys(store).has(future_buy), "failed write debits nothing and grants nothing")

	career = ModesSave.load_career(store)
	career["unlockAll"] = true
	ModesSave.save_career(store, career)
	_check(String(Economy.purchase_outfit(store, future_buy).get("reason")) == "unlocked", "LUCALE access never consumes credits")
	career["unlockAll"] = false
	career["lockAll"] = true
	ModesSave.save_career(store, career)
	_check(not CareerRules.is_unlocked(circuit, ModesSave.load_career(store)), "ALELU temporarily relocks purchased outfit")
	_check(String(Economy.purchase_outfit(store, future_buy).get("reason")) == "relocked", "ALELU prevents new purchase")
	career["lockAll"] = false
	ModesSave.save_career(store, career)
	_check(CareerRules.is_unlocked(circuit, ModesSave.load_career(store)), "purchased access returns after ALELU")
	var cross := Store.new(Config.save_dir + "-cross")
	Economy.ensure_initialized(cross)
	var cross_payload: Dictionary = cross.read_group("economy")["payload"]
	cross_payload["credits"] = 2500
	cross.write_group("economy", cross_payload)
	_check(bool(Economy.purchase_outfit(cross, "maestro:circuit").get("ok", false)), "cross-economy outfit purchase")
	_check(bool(Economy.purchase(cross, "ost_officina").get("ok", false)), "OST purchase still works after outfit purchase")
	Economy.award_completion(cross, "outfit-cross-match", 5, false)
	_check(Economy.owned_outfit_keys(cross).has("maestro:circuit") and Economy.owned_ids(cross).has("ost_officina"), "OST purchase and match reward preserve outfit ownership")
	if DisplayServer.get_name() != "headless":
		shop._select_track("maestro:legend")
		await _settle()
		await RenderingServer.frame_post_draw
		var capture := ProjectSettings.globalize_path("res://../docs/agent-work/emporio-outfits/emporio-outfits-1280x720.png")
		_check(root.get_texture().get_image().save_png(capture) == OK, "outfit shelf 1280x720 captured")
		print("capture: ", capture)

	shop._set_shop_kind("ost")
	_check(shop.shop_kind() == "ost" and shop.rows().size() > 0 and shop._listen_btn.visible, "OST shelf and preview controls return")
	shop.queue_free()
	await _settle()
	Config.save_dir = previous_dir
	print("EMPORIO_OUTFIT %d/%d" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("ok ", label)
	else:
		_failures += 1
		printerr("FAIL ", label)


func _settle() -> void:
	for i in 4:
		await process_frame
