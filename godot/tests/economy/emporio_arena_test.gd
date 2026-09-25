extends SceneTree
## Arena commerce end-to-end on an isolated save. Never touches the real profile.
## Run with the native renderer when the capture matters: the 3D taster needs one.

const Store := preload("res://src/save/save_store.gd")
const Economy := preload("res://src/economy/economy_service.gd")
const ArenaShop := preload("res://src/economy/arena_shop_catalog.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const Config := preload("res://game/match_config.gd")
const EmporioScene := preload("res://src/ui/screens/EmporioScreen.tscn")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_dir := Config.save_dir
	Config.save_dir = "user://emporio-arena-%d" % Time.get_ticks_usec()
	var store := Store.new(Config.save_dir)
	_check(bool(Economy.ensure_initialized(store).get("ok", false)), "isolated economy initialized")

	# Catalog: the six career-gated arenas, priced above every outfit.
	var rows := ArenaShop.shop_rows()
	var ids: Array = []
	for row in rows:
		ids.append(String(row["id"]))
	_check(ids == ["cattedrale", "forgia", "tempesta", "abissale", "caldera", "orrery"], "the six career-gated arenas, in roster order (%s)" % [ids])
	_check(not ArenaShop.is_known("locomotive") and not ArenaShop.is_known("officina"), "arenas open from the start are not sold")
	var cheapest := 1 << 30
	for row in rows:
		cheapest = mini(cheapest, int(row["price"]))
		_check(String(row["art_path"]) != "", "%s has a cover" % row["id"])
	_check(cheapest > 1200, "every arena costs more than the dearest regular outfit (%d)" % cheapest)
	_check(ArenaShop.price_of("orrery") > ArenaShop.price_of("cattedrale"), "the deeper the career wall, the higher the price")

	# Refusals change nothing.
	_check(String(Economy.purchase_arena(store, "cattedrale").get("reason")) == "insufficient", "insufficient funds refuse purchase")
	_check(String(Economy.purchase_arena(store, "locomotive").get("reason")) == "unknown", "a free arena cannot be bought")
	var future := Store.new(Config.save_dir + "-future")
	future.write_group("economy", {"credits": 9000, "owned": [], "ownedOutfits": [], "ownedArenas": ["orrery"], "migrationVersion": 2, "receipts": {}})
	_check(Economy.owned_arena_ids(future).is_empty(), "a future economy payload grants no arena")

	# A purchase unlocks the arena everywhere the career wall is read, and nowhere else.
	var payload: Dictionary = store.read_group("economy")["payload"]
	payload["credits"] = 5000
	_check(bool(store.write_group("economy", payload).get("ok", false)), "fixture grants test credits")
	var orrery_row := ArenaShop.frozen_row("orrery")
	_check(not CareerRules.is_unlocked(orrery_row, ModesSave.load_career(store)), "orrery starts locked behind the career")
	var result := Economy.purchase_arena(store, "orrery")
	_check(bool(result.get("ok", false)) and int(result.get("debited", 0)) == ArenaShop.price_of("orrery"), "orrery bought at its catalog price")
	_check(Economy.balance(store) == 5000 - ArenaShop.price_of("orrery"), "wallet debited once")
	_check(CareerRules.is_unlocked(orrery_row, ModesSave.load_career(store)), "the career view now opens the orrery")
	var arena_locked := {}
	for row in UiData.arena_rows(store):
		arena_locked[String(row["id"])] = bool(row["locked"])
	_check(not bool(arena_locked.get("orrery", true)) and bool(arena_locked.get("caldera", false)), "arena picker: orrery open, caldera still locked")
	_check(String(Economy.purchase_arena(store, "orrery").get("reason")) == "owned", "a second purchase is refused")
	var stored_career: Variant = store.read_group("career").get("payload", {})
	_check(not (stored_career is Dictionary and (stored_career as Dictionary).has("arenasPurchased")), "no purchase leaks into the career file")
	var career := ModesSave.load_career(store)
	ModesSave.save_career(store, career)
	stored_career = store.read_group("career").get("payload", {})
	_check(not (stored_career is Dictionary and (stored_career as Dictionary).has("arenasPurchased")), "saving the career never writes the purchase overlay")
	_check(int(career.get("trophies", 0)) == 0 and int(career.get("stars", 0)) == 0, "no trophy or star forged")

	# Earned through the career: not for sale.
	var earned_store := Store.new(Config.save_dir + "-earned")
	Economy.ensure_initialized(earned_store)
	var wallet: Dictionary = earned_store.read_group("economy")["payload"]
	wallet["credits"] = 5000
	earned_store.write_group("economy", wallet)
	var earned_career := ModesSave.load_career(earned_store)
	earned_career["trophies"] = 2
	ModesSave.save_career(earned_store, earned_career)
	_check(String(Economy.purchase_arena(earned_store, "cattedrale").get("reason")) == "unlocked" and Economy.balance(earned_store) == 5000, "an arena the career opened is never charged")
	var earned_row: Dictionary = {}
	for row in Economy.arena_shop_rows(earned_store):
		if String(row["id"]) == "cattedrale":
			earned_row = row
	_check(bool(earned_row.get("earned", false)) and bool(earned_row.get("accessible", false)), "the shelf says it was earned in the career")

	# The screen: the arena shelf, the cover, the 3D taster, the confirm path.
	root.size = Vector2i(1280, 720)
	var shop: Control = EmporioScene.instantiate()
	shop.set_store(store)
	root.add_child(shop)
	await _settle()
	shop._set_shop_kind("arena")
	await _settle()
	_check(shop.shop_kind() == "arena" and shop.rows().size() == 6, "arena tab lists the six arenas")
	_check(shop._listen_btn.visible and not shop._ost_filters.visible, "the taster button replaces the OST filters")
	shop._select_track("abissale")
	await _settle()
	_check(shop._preview_cover.texture != null, "the selected arena shows its cover")
	shop._on_preview_pressed()
	await _settle()
	_check(shop.arena_3d_id() == "abissale" and shop._arena_view.visible and not shop._preview_cover.visible, "the 3D taster replaces the cover")
	var viewport: SubViewport = shop._arena_viewport
	_check(viewport != null and viewport.own_world_3d and viewport.find_child("Arena", false, false) != null, "the taster builds the real arena in its own world")
	var cam_before: Vector3 = shop._arena_camera.position
	for i in 20:
		await process_frame
	_check(shop._arena_camera != null and shop._arena_camera.position.distance_to(cam_before) > 0.01, "the taster camera circles the arena")
	if DisplayServer.get_name() != "headless":
		var capture := ProjectSettings.globalize_path("res://../docs/agent-work/emporio-arenas/emporio-arena-3d-1280x720.png")
		DirAccess.make_dir_recursive_absolute(capture.get_base_dir())
		_check(root.get_texture().get_image().save_png(capture) == OK, "arena taster 1280x720 captured")
	shop._select_track("caldera")
	await _settle()
	_check(shop.arena_3d_id() == "" and shop._arena_viewport == null, "choosing another arena frees the taster")
	shop._on_row_pressed("caldera")
	await _settle()
	_check(not shop.confirm_visible() and Economy.balance(store) == 5000 - ArenaShop.price_of("orrery"), "caldera (2700) with 1800 left: refused, nothing debited")
	shop._on_row_pressed("cattedrale")
	await _settle()
	_check(shop.confirm_visible() and shop.pending_id() == "cattedrale", "purchase asks for confirmation")
	shop._on_confirm_pressed()
	await _settle()
	_check(bool(shop.last_purchase().get("ok", false)) and Economy.owned_arena_ids(store).has("cattedrale"), "confirmed purchase unlocks the cathedral")
	if DisplayServer.get_name() != "headless":
		var shelf := ProjectSettings.globalize_path("res://../docs/agent-work/emporio-arenas/emporio-arenas-1280x720.png")
		_check(root.get_texture().get_image().save_png(shelf) == OK, "arena shelf 1280x720 captured")
	shop._set_shop_kind("ost")
	await _settle()
	_check(shop.shop_kind() == "ost" and shop._preview_cover.custom_minimum_size == Vector2(220, 220), "OST shelf returns with its square cover")
	shop.queue_free()
	await _settle()
	Config.save_dir = previous_dir
	print("EMPORIO_ARENA %d/%d" % [_checks - _failures, _checks])
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
