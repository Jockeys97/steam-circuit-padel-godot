extends SceneTree

const Config := preload("res://game/match_config.gd")
const Save := preload("res://src/modes/modes_save.gd")
const Store := preload("res://src/save/save_store.gd")
const Rules := preload("res://src/modes/career_rules.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Economy := preload("res://src/economy/economy_service.gd")
const Catalog := preload("res://src/economy/ost_catalog.gd")
const Lineup := preload("res://game/lineup.gd")
var failures := 0
var checks := 0
var screen: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)

func enter(code: String) -> String:
	var point: Vector2 = screen.title_word_rect().get_center()
	for i in 3:
		screen.title_door_tap(point)
	return screen.submit_unlock_code(code)

func run() -> void:
	Config.save_dir = "user://relock-code-%d" % Time.get_ticks_usec()
	var store := Config.save_store()
	Economy.ensure_initialized(store)
	var career := Save.load_career(store)
	career["stars"] = 999
	career["trophies"] = 999
	career["wins"] = 42
	career["outfitsWon"] = {}
	career["equippedOutfits"] = {}
	for athlete_id in Tables.outfits():
		for outfit in Tables.outfits_for_athlete(athlete_id):
			if outfit.get("challenge") != null:
				career["outfitsWon"][String(outfit["unlockKey"])] = true
				career["equippedOutfits"][athlete_id] = outfit["id"]
	Save.save_career(store, career)
	var economy: Dictionary = store.read_group("economy")["payload"]
	economy["credits"] = 777
	economy["owned"] = Catalog.shop_ids()
	economy["receipts"] = {"retained-receipt": 42}
	store.write_group("economy", economy)
	var frame := Control.new()
	frame.size = Vector2(1280, 720)
	root.add_child(frame)
	screen = load("res://src/ui/screens/CharactersScreen.tscn").instantiate()
	frame.add_child(screen)
	for i in 6:
		await process_frame
	check(screen.submit_unlock_code("Alelu") == "refused", "closed code entry refuses input")
	check(enter("Lucale") == "ok", "Lucale still opens all content")
	check(enter("wrong") == "wrong", "unknown code is rejected")
	check(not bool(Save.load_career(store).get("lockAll", false)), "wrong code changes no locks")
	check(screen.submit_unlock_code("  aLeLu  ") == "ok", "Alelu works after Lucale, ignoring case and spaces")
	var restarted := Store.new(Config.save_dir)
	var locked := Save.load_career(restarted)
	check(bool(locked.get("lockAll", false)) and not bool(locked["unlockAll"]), "lock persists through a fresh store")
	for field in ["stars", "trophies", "wins", "outfitsWon", "equippedOutfits"]:
		check(locked[field] == career[field], "preserves career " + field)
	check(restarted.read_group("economy")["payload"] == economy, "preserves all purchases, credits and receipts")
	var gated_count := 0
	for item in Frozen.athletes():
		var gated := item.get("unlock") != null
		check(Rules.is_unlocked(item, locked) == not gated, "athlete gate " + String(item["id"]))
		if gated:
			gated_count += 1
	for athlete_id in Tables.outfits():
		for item in Tables.outfits_for_athlete(athlete_id):
			var gated := item.get("unlock") != null or item.get("challenge") != null
			check(Rules.is_unlocked(item, locked) == not gated, "outfit gate " + String(item["id"]))
			if gated:
				gated_count += 1
		check(Lineup.equipped_outfit(athlete_id, locked) == &"base", "locked equipped outfit falls back to base")
	check(gated_count > 0, "fixture includes earned unlockables")
	for id in Catalog.shop_ids():
		check(not Economy.has_access(restarted, id), "paid OST is relocked " + id)
		check(Economy.is_owned(restarted, id), "OST ownership retained " + id)
	for id in Catalog.starter_ids():
		check(Economy.has_access(restarted, id), "starter OST remains playable " + id)
	for id in Catalog.all_ids():
		if not Catalog.is_starter(id):
			check(not Economy.has_access(restarted, id), "every non-starter OST is locked " + id)
	for row in Economy.shop_rows(restarted):
		check(row["relocked"] and not row["accessible"], "shop advertises the code lock")
	check(Economy.purchase(restarted, Catalog.shop_ids()[0])["reason"] == "relocked", "purchase cannot debit while code lock is on")
	check(Economy.balance(restarted) == 777, "wallet unchanged after refused purchase")
	Lineup.set_pref_source({"lineup": {"playerMate": "colosso", "opponent": "oracolo"}})
	var lineup := Lineup.resolve(Frozen.athletes()[-1], null, locked)
	for athlete in lineup.values():
		check(Rules.is_unlocked(athlete, locked), "previous lineup cannot use locked athletes")
	check(enter("LUCALE") == "ok", "Lucale reverses Alelu through the same UI")
	var restored := Save.load_career(Store.new(Config.save_dir))
	check(not bool(restored.get("lockAll", true)), "reverse persists")
	for id in Catalog.shop_ids():
		check(Economy.has_access(restarted, id), "Lucale restores OST " + id)
	for athlete_id in Tables.outfits():
		for item in Tables.outfits_for_athlete(athlete_id):
			check(Rules.is_unlocked(item, restored), "Lucale restores outfit " + String(item["id"]))
	check(store.read_group("economy")["payload"] == economy, "reverse also preserves economy")
	frame.queue_free()
	await process_frame
	print("RELOCK_CODE %s %d/%d" % ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	quit(0 if failures == 0 else 1)
