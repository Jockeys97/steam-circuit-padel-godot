extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Store := preload("res://src/save/save_store.gd")
const Economy := preload("res://src/economy/economy_service.gd")
const Catalog := preload("res://src/economy/ost_catalog.gd")
const Config := preload("res://game/match_config.gd")
const MatchController := preload("res://game/match_controller.gd")

const DIR_NEW := "user://emporio-audit-new"
const DIR_LEGACY := "user://emporio-audit-legacy"
const DIR_REFUSED := "user://emporio-audit-refused"
const DIR_FUTURE := "user://emporio-audit-future"
const DIR_PREFS := "user://emporio-audit-prefs"
const DIR_CORRUPT := "user://emporio-audit-corrupt"
const DIR_UNION := "user://emporio-audit-union"
const DIR_BUY := "user://emporio-audit-buy"
const DIR_LUCALE := "user://emporio-audit-lucale"
const DIR_AWARD := "user://emporio-audit-award"
const DIR_HOST := "user://emporio-audit-host"
const DIR_MC := "user://emporio-audit-controller"
const CAPTURE_DIR := "res://../docs/agent-work/emporio/captures"

var audit: AuditBase


func _initialize() -> void:
	audit = AuditBase.new("emporio_ost")
	call_deferred("run")


func run() -> void:
	_catalog()
	_new_profile()
	_legacy_profile()
	_refused_future_prefs()
	_corrupt_recovery()
	_migration_union()
	_purchases()
	_lucale()
	_rewards()
	_controller_award()
	await _host()
	_cleanup()
	quit(audit.finish())


func _catalog() -> void:
	audit.check_eq(Catalog.all_ids().size(), 47, "catalog/47_tracks")
	audit.check_eq(Catalog.starter_ids().size(), 4, "catalog/4_starters")
	audit.check_eq(Catalog.shop_ids().size(), 43, "catalog/43_shop_items")
	audit.check_eq(int(Catalog.catalog_report()["standard"]), 18, "catalog/18_standard")
	audit.check_eq(int(Catalog.catalog_report()["special"]), 25, "catalog/25_special")
	audit.check_eq(Catalog.price_of("ost_officina"), 150, "catalog/arena_150")
	audit.check_eq(Catalog.price_of("ost_sawano_titan_breach"), 250, "catalog/sawano_250")
	audit.check_eq(Catalog.price_of("ost_menu"), 0, "catalog/starter_not_sold")
	audit.check_eq(int(Catalog.exclusion_report()["count"]), 0, "exclusions/none_objective_linked")
	audit.check_true(String(Catalog.exclusion_report()["reason"]) != "", "exclusions/reported")


func _new_profile() -> void:
	var store: RefCounted = Store.new(DIR_NEW)
	_wipe(DIR_NEW)
	var init: Dictionary = Economy.ensure_initialized(store)
	audit.check_true(bool(init["ok"]) and not bool(init["granted"]), "new/init_no_grant")
	var state: Dictionary = Economy.read_state(store)
	audit.check_eq(int(state["credits"]), 0, "new/zero_credits")
	audit.check_eq((state["owned"] as Array).size(), 0, "new/owns_nothing")
	audit.check_true(Economy.is_owned(store, "ost_menu"), "new/starter_owned")
	audit.check_true(not Economy.has_access(store, "ost_officina"), "new/locked")
	var marker := _marker(store)
	audit.check_true(not marker.is_empty() and not bool(marker.get("legacy", true)), "new/marker_not_legacy")
	audit.check_true(bool(Economy.ensure_initialized(store)["already"]), "new/second_init_noop")


func _legacy_profile() -> void:
	var store: RefCounted = Store.new(DIR_LEGACY)
	_wipe(DIR_LEGACY)
	store.write_group("career", {"season": 4, "wins": 11, "unlockAll": false})
	var init: Dictionary = Economy.ensure_initialized(store)
	audit.check_true(bool(init["ok"]) and bool(init["granted"]), "legacy/granted_once")
	audit.check_eq((Economy.owned_ids(store) as Array).size(), 47, "legacy/owns_catalog")
	audit.check_eq(Economy.balance(store), 0, "legacy/access_not_credits")


func _refused_future_prefs() -> void:
	var s: RefCounted = Store.new(DIR_REFUSED)
	_wipe(DIR_REFUSED)
	var bytes := "{\"format\":\"padel-save\",\"schemaVersion\":99,\"group\":\"economy\",\"payload\":{\"credits\":0}}"
	_raw_write(s.group_path("economy"), bytes)
	var init: Dictionary = Economy.ensure_initialized(s)
	audit.check_true(not bool(init["ok"]) and String(init["reason"]).contains("refused"), "refused/init_refuses")
	audit.check_eq(_raw_read(s.group_path("economy")), bytes, "refused/file_untouched")
	audit.check_true(not FileAccess.file_exists(s.group_path("prefs")), "refused/no_marker")
	audit.check_true(not bool(Economy.purchase(s, "ost_officina")["ok"]), "refused/purchase_refused")

	var f: RefCounted = Store.new(DIR_FUTURE)
	_wipe(DIR_FUTURE)
	f.write_group("economy", {"credits": 500, "owned": [], "migrationVersion": 2, "receipts": {}})
	var before := _raw_read(f.group_path("economy"))
	var init2: Dictionary = Economy.ensure_initialized(f)
	audit.check_true(not bool(init2["ok"]) and String(init2["reason"]).contains("newer"), "future/refuses")
	audit.check_eq(_raw_read(f.group_path("economy")), before, "future/not_rewritten")

	var p: RefCounted = Store.new(DIR_PREFS)
	_wipe(DIR_PREFS)
	var pbytes := "{\"format\":\"padel-save\",\"schemaVersion\":99,\"group\":\"prefs\",\"payload\":{\"lang\":\"xx\"}}"
	_raw_write(p.group_path("prefs"), pbytes)
	var init3: Dictionary = Economy.ensure_initialized(p)
	audit.check_true(not bool(init3["ok"]), "prefs_refused/init_refuses")
	audit.check_eq(_raw_read(p.group_path("prefs")), pbytes, "prefs_refused/prefs_untouched")
	audit.check_true(not FileAccess.file_exists(p.group_path("economy")), "prefs_refused/no_economy")


func _corrupt_recovery() -> void:
	var store: RefCounted = Store.new(DIR_CORRUPT)
	_wipe(DIR_CORRUPT)
	_raw_write(store.group_path("economy"), "{not json")
	var init: Dictionary = Economy.ensure_initialized(store)
	audit.check_true(bool(init["ok"]) and not bool(init["granted"]), "corrupt/reinit_no_grant")
	audit.check_eq((Economy.owned_ids(store) as Array).size(), 0, "corrupt/empty")
	audit.check_true(_marker(store).has("legacy"), "corrupt/decision_recorded")
	DirAccess.remove_absolute(store.group_path("economy"))
	var again: Dictionary = Economy.ensure_initialized(store)
	audit.check_true(not bool(again["granted"]), "corrupt/missing_later_no_grant_all")
	audit.check_eq((Economy.owned_ids(store) as Array).size(), 0, "corrupt/still_empty")


func _migration_union() -> void:
	var store: RefCounted = Store.new(DIR_UNION)
	_wipe(DIR_UNION)
	store.write_group("prefs", {"lang": "it", "economyInit": {"version": 1, "legacy": false}})
	store.write_group("economy", {"credits": 40, "owned": ["ost_torii"], "migrationVersion": 0, "receipts": {}})
	audit.check_true(bool(Economy.ensure_initialized(store)["ok"]), "union/init_ok")
	var state: Dictionary = Economy.read_state(store)
	audit.check_true((state["owned"] as Array).has("ost_torii"), "union/existing_purchase_kept")
	audit.check_eq(int(state["credits"]), 40, "union/credits_kept")


func _purchases() -> void:
	var store: RefCounted = Store.new(DIR_BUY)
	_wipe(DIR_BUY)
	Economy.ensure_initialized(store)
	audit.check_eq(String(Economy.purchase(store, "ost_officina")["reason"]), "insufficient", "buy/insufficient")
	_wallet(store, 1000, [])
	audit.check_eq(String(Economy.purchase(store, "ost_nope")["reason"]), "unknown", "buy/unknown")
	audit.check_eq(String(Economy.purchase(store, "ost_menu")["reason"]), "starter", "buy/starter")
	var ok: Dictionary = Economy.purchase(store, "ost_officina")
	audit.check_true(bool(ok["ok"]) and int(ok["debited"]) == 150 and int(ok["balance"]) == 850, "buy/debits_price")
	audit.check_eq(String(Economy.purchase(store, "ost_officina")["reason"]), "owned", "buy/duplicate")
	audit.check_eq(Economy.balance(store), 850, "buy/no_second_debit")
	store.fail_before_rename = true
	var failed: Dictionary = Economy.purchase(store, "ost_fonderia")
	store.fail_before_rename = false
	audit.check_true(not bool(failed["ok"]) and String(failed["reason"]) == "write_failed", "buy/write_failure")
	audit.check_eq(Economy.balance(store), 850, "buy/failure_no_debit")
	audit.check_true(not (Economy.owned_ids(store) as Array).has("ost_fonderia"), "buy/failure_no_ownership")
	audit.check_ge(Economy.balance(store), 0, "buy/credits_never_negative")


func _lucale() -> void:
	var store: RefCounted = Store.new(DIR_LUCALE)
	_wipe(DIR_LUCALE)
	Economy.ensure_initialized(store)
	store.write_group("career", {"season": 1, "unlockAll": true})
	_wallet(store, 1000, [])
	audit.check_true(Economy.has_access(store, "ost_sawano_titan_breach"), "lucale/access")
	audit.check_true(not Economy.is_owned(store, "ost_sawano_titan_breach"), "lucale/not_faked_owned")
	audit.check_eq(String(Economy.purchase(store, "ost_sawano_titan_breach")["reason"]), "unlocked", "lucale/no_debit")
	audit.check_eq(Economy.balance(store), 1000, "lucale/balance_untouched")


func _rewards() -> void:
	audit.check_eq(Economy.reward_for(0, false), 20, "reward/base")
	audit.check_eq(Economy.reward_for(10, true), 55, "reward/per_point_and_victory")
	audit.check_eq(Economy.reward_for(500, true), 115, "reward/capped")
	audit.check_eq(Economy.points_played({"pointsWon": {"player": 11, "ai": 7}}), 18, "reward/points_from_accumulated_totals")
	audit.check_eq(Economy.points_played({"points": {"player": 3, "ai": 1}}), 0, "reward/scoreboard_is_not_the_source")
	audit.check_true(Economy.award_eligible("quick", false, true, true, true, true), "elig/quick_ok")
	audit.check_true(not Economy.award_eligible("drill", false, true, true, true, true), "elig/drill_excluded")
	audit.check_true(not Economy.award_eligible("quick", true, true, true, true, true), "elig/demo_excluded")
	audit.check_true(not Economy.award_eligible("quick", false, false, true, true, true), "elig/harness_excluded")
	audit.check_true(not Economy.award_eligible("quick", false, true, true, false, true), "elig/dry_fixture_excluded")
	audit.check_true(not Economy.award_eligible("quick", false, true, true, true, false), "elig/no_result_excluded")

	var store: RefCounted = Store.new(DIR_AWARD)
	_wipe(DIR_AWARD)
	Economy.ensure_initialized(store)
	audit.check_true(int(Economy.award_completion(store, "m1", 10, true)["awarded"]) == 55, "award/first")
	audit.check_true(bool(Economy.award_completion(store, "m1", 10, true)["already"]), "award/once_only")
	audit.check_eq(Economy.balance(store), 55, "award/no_double_pay")
	audit.check_true(not bool(Economy.award_completion(store, "m2", 6, false)["already"]), "award/rematch_new_id")
	audit.check_eq(Economy.balance(store), 87, "award/rematch_balance")
	audit.check_true(bool(Economy.award_completion(Store.new(DIR_AWARD), "m1", 10, true)["already"]), "award/receipt_survives_restart")
	audit.check_true(not bool(Economy.award_completion(store, "", 5, true)["ok"]), "award/empty_id")


## The REAL controller's award hook, driven on a lightweight instance (no scene, no
## display): the match's own facts are configured directly and `_award_economy` is
## called, so the live call site — not just the service — is covered. The call must
## award once, be idempotent for the same match, and never navigate.
func _controller_award() -> void:
	_wipe(DIR_MC)
	Config.save_dir = DIR_MC
	Economy.ensure_initialized(Config.save_store())
	var mc = MatchController.new()
	mc.engine_driven = true
	mc.load_models = true
	mc.economy_award_enabled = true
	mc.session = null
	mc.state = {
		"stats": {"pointsWon": {"player": 11, "ai": 7}},
		"result": {"winner": "player"},
	}
	var first: Dictionary = mc.call("_award_economy")
	audit.check_true(bool(first.get("ok", false)) and int(first.get("awarded", 0)) == 71, "controller/awards_real_match")
	audit.check_eq(Economy.balance(Config.save_store()), 71, "controller/balance_after_award")
	audit.check_true(String(mc.call("economy_match_id")) != "", "controller/match_id_assigned")
	audit.check_eq(int((mc.call("economy_award") as Dictionary).get("awarded", 0)), 71, "controller/award_readable_for_result")
	var second: Dictionary = mc.call("_award_economy")
	audit.check_true(bool(second.get("already", false)) and int(second.get("awarded", 0)) == 0, "controller/idempotent")
	audit.check_eq(Economy.balance(Config.save_store()), 71, "controller/no_double_pay")
	audit.check_true(Config.pending_result.is_empty(), "controller/no_scene_jump")
	mc.free()


func _host() -> void:
	_wipe(DIR_HOST)
	Config.save_dir = DIR_HOST
	var scene := load("res://game/Main.tscn") as PackedScene
	audit.check_true(scene != null, "host/menu_loads")
	if scene == null:
		return
	var menu: Node = scene.instantiate()
	root.add_child(menu)
	await _settle(4)
	audit.check_eq((Economy.owned_ids(Config.save_store()) as Array).size(), 0, "host/boot_init_no_grant")
	var model = menu.call("focus_model")
	var ids: Array = model.call("ids") if model != null else []
	audit.report("focus ids=%s" % str(ids))
	audit.check_true(ids.has("emporio"), "host/emporio_in_focus_registry")
	audit.check_true(bool(menu.call("_emporio_shortcut_available")), "host/menu_allows_shop_shortcut")
	var code_field := LineEdit.new()
	menu.add_child(code_field)
	code_field.grab_focus()
	var key_e := InputEventKey.new()
	key_e.keycode = KEY_E
	key_e.unicode = 101
	key_e.pressed = true
	root.push_input(key_e)
	audit.check_true(menu.call("emporio_overlay") == null, "host/typing_e_does_not_open_shop")
	audit.check_eq(code_field.text, "e", "host/code_field_receives_e")
	code_field.queue_free()
	await _settle(1)
	_wallet(Config.save_store(), 1000, [])
	menu.call("toggle_emporio")
	await _settle(3)
	var overlay: Control = menu.call("emporio_overlay")
	audit.check_true(overlay != null, "host/overlay_mounted")
	if overlay == null:
		return
	audit.check_true(bool(menu.call("_overlay_owns_input")), "host/overlay_owns_input")
	audit.check_eq((overlay.call("rows") as Array).size(), 43, "host/43_rows")
	var target := ""
	for row in (overlay.call("rows") as Array):
		if bool(row.get("affordable", false)) and not bool(row.get("owned", false)):
			target = String(row["id"])
			break
	overlay.call("_on_row_pressed", target)
	audit.check_true(bool(overlay.call("confirm_visible")), "host/confirm_arms")
	overlay.call("_on_confirm_pressed")
	audit.check_true(bool((overlay.call("last_purchase") as Dictionary).get("ok", false)), "host/confirm_buys")
	audit.check_true((Economy.owned_ids(Config.save_store()) as Array).has(target), "host/owned_after_buy")
	overlay.call("_focus_first_row")
	var menu_focus := _focus_name(menu)
	_pad_accept()
	await _settle(3)
	audit.check_eq(_focus_name(menu), menu_focus, "host/pad_no_menu_leak")
	overlay.call("_on_back_pressed")
	await _settle(3)
	audit.check_true(menu.call("emporio_overlay") == null, "host/back_closes")

	# A real pad press BUYS inside the shop: arm the confirmation, focus its Confirm
	# button, and push a pad accept — the GUI delivers `ui_accept` to the button.
	overlay = menu.call("emporio_overlay")
	menu.call("toggle_emporio")
	await _settle(3)
	overlay = menu.call("emporio_overlay")
	var target2 := ""
	for row in (overlay.call("rows") as Array):
		if bool(row.get("affordable", false)) and not bool(row.get("owned", false)):
			target2 = String(row["id"])
			break
	overlay.call("_on_row_pressed", target2)
	var confirm_btn: Button = overlay.get("_confirm_btn")
	confirm_btn.grab_focus()
	await _settle(1)
	var owner := root.gui_get_focus_owner()
	audit.report("confirm focus owner=%s" % (String(owner.name) if owner != null else "<null>"))
	audit.check_true(InputMap.event_is_action(_joypad_a(), "ui_accept"), "host/pad_a_maps_to_ui_accept")
	audit.check_true(owner == confirm_btn, "host/confirm_button_holds_gui_focus")
	_pad_accept_joypad()
	await _settle(3)
	audit.check_true(bool((overlay.call("last_purchase") as Dictionary).get("ok", false)), "host/pad_confirm_button_buys")
	audit.check_true((Economy.owned_ids(Config.save_store()) as Array).has(target2), "host/pad_purchase_persisted")
	overlay.call("_on_back_pressed")
	await _settle(2)

	# A real pad press OPENS the shop from the initial menu, with the NORMAL registration:
	# the focus is moved onto the registered `emporio` control through the bridge's own
	# `set_focus`, then the accept travels the real path (`_input` ->
	# `handle_pad_event` -> `_bridge.act` -> `action_requested` -> toggle).
	var bridge = menu.get("_bridge")
	var focus_model = menu.get("_focus")
	audit.check_true(bool(bridge.call("has", "emporio")), "host/emporio_registered_in_bridge")
	audit.check_true(bool(bridge.call("set_focus", "emporio")), "host/set_focus_reaches_emporio")
	focus_model.call("apply_focus")
	audit.check_eq(String(focus_model.call("focus_id")), "emporio", "host/pad_focus_reaches_emporio")
	_pad_accept()
	await _settle(3)
	audit.check_true(menu.call("emporio_overlay") != null, "host/pad_accept_opens_emporio_from_menu")
	menu.call("toggle_emporio")
	await _settle(2)

	menu.call("toggle_jukebox")
	await _settle(3)
	var juke: Control = menu.get("_jukebox_overlay")
	audit.check_true(juke != null, "host/jukebox_mounted")
	if juke != null:
		audit.check_true(not bool(juke.call("is_locked", "ost_menu")), "host/juke_starter_playable")
		audit.check_gt((juke.call("locked_ids") as Array).size(), 0, "host/juke_locked_listed")
		var locked_id := String((juke.call("locked_ids") as Array)[0])
		var tids: PackedStringArray = juke.get("_track_ids")
		juke.set("_selected_idx", tids.find(locked_id))
		juke.call("_on_play_pressed")
		await _settle(3)
		audit.check_true(menu.get("_emporio_overlay") != null, "host/juke_routes_to_shop")
	await _capture(menu)
	menu.queue_free()
	await _settle(2)


## A 1280x720 render of the shop, real renderer only (a headless dummy driver paints
## blank frames). Also inspects that no row's text is clipped at that frame.
func _capture(menu: Node) -> void:
	# Deterministic: open the shop only if it is not already up (the Jukebox route above
	# may have left it open), so the capture never toggles a visible shop shut.
	if menu.call("emporio_overlay") == null:
		menu.call("toggle_emporio")
	await _settle(3)
	var overlay: Control = menu.call("emporio_overlay")
	if overlay == null:
		return
	if DisplayServer.get_name() == "headless":
		audit.note("1280x720 capture skipped: headless dummy driver renders blank frames")
		return
	root.size = Vector2i(1280, 720)
	await _settle(4)
	# No clipping at 1280x720: every row must be at least as wide as its own text wants.
	var clipped := 0
	for b in (overlay.get("_row_buttons") as Array):
		if b != null and is_instance_valid(b) and b.get_minimum_size().x > b.size.x + 1.0:
			clipped += 1
	audit.check_eq(clipped, 0, "capture/no_clipped_rows_at_1280x720")
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	var tex := root.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		audit.check_true(false, "capture/viewport_produced_no_image")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var path := ProjectSettings.globalize_path(CAPTURE_DIR).path_join("emporio-1280x720.png")
	var err := img.save_png(path)
	audit.check_true(err == OK and _colours(img) > 8, "capture/emporio_1280x720_non_blank -> %s" % path)


func _colours(img: Image) -> int:
	var seen := {}
	var sx := maxi(img.get_width() / 24, 1)
	var sy := maxi(img.get_height() / 14, 1)
	var x := 0
	while x < img.get_width():
		var y := 0
		while y < img.get_height():
			seen[img.get_pixel(x, y).to_rgba32()] = true
			y += sy
		x += sx
	return seen.size()


func _focus_name(menu: Node) -> String:
	var model = menu.get("_focus")
	if model == null:
		return ""
	var node = model.call("focus_node")
	return "" if node == null else String(node.name)


func _pad_accept() -> void:
	_pad_accept_joypad()


func _joypad_a() -> InputEventJoypadButton:
	return _joypad_button(true)


func _joypad_button(pressed: bool) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = pressed
	return ev


## A real pad press is press THEN release: `BaseButton`'s default action mode activates
## on RELEASE, so a lone `pressed = true` never fires the focused control.
func _pad_accept_joypad() -> void:
	root.push_input(_joypad_button(true))
	root.push_input(_joypad_button(false))


func _wallet(store: RefCounted, credits: int, owned: Array) -> void:
	store.write_group("economy", {
		"credits": credits, "owned": owned,
		"migrationVersion": Economy.MIGRATION_VERSION, "receipts": {},
	})


func _marker(store: RefCounted) -> Dictionary:
	var read: Dictionary = store.read_group("prefs")
	var payload: Variant = read.get("payload", null)
	if payload is Dictionary:
		var m: Variant = (payload as Dictionary).get("economyInit", null)
		if m is Dictionary:
			return m
	return {}


func _raw_write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _raw_read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.open(path, FileAccess.READ).get_as_text()


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


func _cleanup() -> void:
	for d in [DIR_NEW, DIR_LEGACY, DIR_REFUSED, DIR_FUTURE, DIR_PREFS, DIR_CORRUPT, DIR_UNION, DIR_BUY, DIR_LUCALE, DIR_AWARD, DIR_HOST]:
		_wipe(d)


func _wipe(dir_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
