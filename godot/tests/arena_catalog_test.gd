## arena_catalog_test.gd — the arena-catalog seam, crossed by BOTH UI paths.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/arena_catalog_test.gd
##   ... -- --demo        (the demo half: the world set does not exist there)
##
## WHAT IT GATES, per `docs/mission/architecture-deepening/tickets/arena-catalog.md`
## ("one source of truth for frozen and world arena selection, lock reasons, demo
## availability and display rows, feeding both adapters"):
##
##   A. WORLD REACHABLE IN THE RECREATED UI. The arena screen builds one card per
##      world arena in a full build, names it with the row the legacy path also
##      reads, selects it on a press, carries it in the start payload and lands the
##      world seat in `match_config.gd` on a quick start — then a frozen press
##      clears it. In career/tournament wording the world cards are switched off
##      exactly like every other non-fixture card, and in a DEMO build the set does
##      not exist at all.
##   B. ONE CATALOG. `game/arenas/arena_catalog.gd` is the module both adapters
##      read: the recreated adapter's frozen rows (`UiData.arena_rows`) are its
##      `frozen_rows`, the legacy adapter's world availability
##      (`Config.selectable_world_arenas`) is its `world_rows`, and `seat()` is
##      where `Config.set_arena_id` lands.
##   C. THE FROZEN NINE AND THE DEMO'S OWN RULES ARE UNCHANGED: the screen's frozen
##      grid is still the nine-row catalog in order, its lock list is still the
##      build's wall plus the career's, and the world set never enters `Arena.ids()`
##      or `Config.selectable_arenas()`.
##
## THE ONE DYNAMIC CALL IN THIS SUITE. The catalog module is loaded by PATH at run
## time (section B), never preloaded: this suite has to run — and fail cleanly — on
## the run BEFORE that module exists, and a `preload` of a missing file fails the
## whole file instead of one check. Everything else here is a normal static call.
##
## HEADLESS IS CORRECT HERE: nothing renders. Rendered world-arena proof is
## `world_arenas_capture.gd`; the ported menu column's world row is
## `world_arenas_selection_test.gd` section 6.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const ScreenRouter := preload("res://src/ui/ScreenRouter.gd")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")

const SCREEN_SCENE := "res://src/ui/screens/ArenaScreen.tscn"
## The quick match's scene, as `game/main_menu.gd` changes to it (`:497`) — the same
## value the screen's payload carries.
const MATCH_SCENE := "res://game/Match.tscn"
## The one catalog module, and the screen's own world-card node names.
const CATALOG_PATH := "res://game/arenas/arena_catalog.gd"
const WORLD_CARD_PREFIX := "WorldArenaCard_"
const WORLD_NAME_PREFIX := "WorldArenaName_"
const FRAME := Vector2(1280, 720)

var _c := Common.new()
var _router: ScreenRouter = null
var _host: Control = null
var _store_dir := ""
var _previous_save_dir := ""
var _previous_mode := ""


func _initialize() -> void:
	_previous_save_dir = Config.save_dir
	_previous_mode = String(Config.pending_mode)
	_store_dir = "user://arena_catalog_test_%d" % Time.get_ticks_usec()
	Config.save_dir = _store_dir
	await _run()
	Config.pending_mode = _previous_mode
	_cleanup()
	quit(_c.exit_code())


func _cleanup() -> void:
	if _store_dir == "":
		return
	DirAccess.remove_absolute(_store_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_store_dir))
	Config.save_dir = _previous_save_dir


func _run() -> void:
	Common.banner("ARENA_CATALOG")
	var demo := Gate.is_demo()
	var world_ids := _ids(Arena.world_ids())
	var frozen_ids := _ids(Frozen.arenas())
	print("# build=%s frozen=%s world=%s" % [Gate.label(), str(frozen_ids), str(world_ids)])

	# -----------------------------------------------------------------------
	# A. The recreated UI: the world five, under the legacy path's own rules.
	# -----------------------------------------------------------------------
	Config.pending_mode = "quick"
	var screen: Node = await _mount()
	var cards := _world_cards(screen)
	if demo:
		_c.check("A/a_demo_builds_no_world_card", cards.is_empty(), str(cards))
		_c.check("A/a_demo_refuses_every_world_arena", not Config.set_arena_id(String(world_ids[0])),
			Config.arena_id())
	else:
		_c.check_eq("A/a_full_build_lists_one_card_per_world_arena_in_the_recreated_grid",
			str(cards), str(world_ids))
		var legacy: Array = Config.selectable_world_arenas()
		var name_problems: Array[String] = []
		for row_in in legacy:
			var row: Dictionary = row_in
			var id := String(row.get("id", ""))
			var label := _control(screen, WORLD_NAME_PREFIX + id)
			if label == null or String(label.text) != String(row.get("name", "")):
				name_problems.append("%s: shown=%s row=%s" % [
					id, "null" if label == null else label.text, row.get("name", "")])
		_c.check("A/a_world_card_is_named_by_the_same_row_the_legacy_path_reads",
			name_problems.is_empty(), str(name_problems))

		var start_problems: Array[String] = []
		for id_in in world_ids:
			var id := String(id_in)
			if not bool(screen.select_arena(id)) or String(screen.selected_arena_id()) != id:
				start_problems.append("%s: the press did not select it" % id)
				continue
			var payload: Dictionary = screen.start_payload()
			if String(payload.get("arena_id", "")) != id or int(payload.get("arena_index", 0)) != -1:
				start_problems.append("%s: payload=%s" % [id, str(payload)])
				continue
			if String(payload.get("scene", "")) != MATCH_SCENE or not bool(screen.start_match(false)):
				start_problems.append("%s: quick start refused" % id)
				continue
			if Config.arena_id() != id or not Config.is_world_selected() \
					or String(Config.arena().get("id", "")) != id:
				start_problems.append("%s: match seat is %s (world=%s)" % [
					id, Config.arena_id(), str(Config.is_world_selected())])
		_c.check("A/a_world_press_selects_and_a_quick_start_lands_the_world_seat",
			start_problems.is_empty(), str(start_problems))

		var back_id := _first_open_frozen(screen)
		var cleared := bool(screen.select_arena(back_id)) and bool(screen.start_match(false)) \
			and Config.arena_id() == back_id and not Config.is_world_selected()
		_c.check("A/a_frozen_press_clears_the_world_seat", cleared,
			"%s: seat=%s world=%s" % [back_id, Config.arena_id(), str(Config.is_world_selected())])

		Config.pending_mode = "career"
		var career_screen: Node = await _mount()
		var fixture := String(career_screen.in_program_id())
		var switched_off: Array[String] = []
		for id_in in world_ids:
			var id := String(id_in)
			var state := String(career_screen.arena_card_state(id))
			if state != "out_of_matchday" or bool(career_screen.select_arena(id)):
				switched_off.append("%s: state=%s" % [id, state])
		_c.check("A/the_calendar_switches_every_world_card_off_like_every_other_card",
			switched_off.is_empty(), str(switched_off))
		_c.check("A/a_career_start_still_uses_the_calendars_arena",
			fixture != "" and String(career_screen.start_arena_id()) == fixture,
			"fixture=%s start=%s" % [fixture, career_screen.start_arena_id()])

	# -----------------------------------------------------------------------
	# B. One catalog: both adapters read it, and both seats land where it says.
	# -----------------------------------------------------------------------
	if ResourceLoader.exists(CATALOG_PATH):
		var script: GDScript = load(CATALOG_PATH)
		var catalog: RefCounted = script.new(Gate.is_demo(), Gate.arenas())
		var career: Dictionary = ModesSave.load_career(Config.save_store())
		_c.check_eq("B/the_recreated_adapters_frozen_rows_are_the_catalogs_own",
			_row_facts(UiData.arena_rows(Config.save_store())),
			_row_facts(catalog.call("frozen_rows", career)))
		_c.check_eq("B/the_legacy_adapters_world_availability_is_the_catalogs_own",
			str(_ids(Config.selectable_world_arenas())), str(_ids(catalog.call("world_rows"))))
		if demo:
			_c.check("B/a_demo_offers_no_world_arena_at_all",
				_ids(catalog.call("world_rows")).is_empty(), str(world_ids))
		else:
			_c.check_eq("B/a_full_build_offers_the_five_world_arenas_in_table_order",
				str(_ids(catalog.call("world_rows"))), str(world_ids))
		var seat_problems: Array[String] = []
		for id_in in catalog.call("all_ids"):
			var id := String(id_in)
			var seat: Dictionary = catalog.call("seat", id)
			var want := int(seat["index"]) >= 0 or (bool(seat["world"]) and bool(seat["offered"]))
			var took := Config.set_arena_id(id)
			if took != want:
				seat_problems.append("%s: set_arena_id=%s seat=%s" % [id, str(took), str(seat)])
				continue
			if int(seat["index"]) >= 0:
				if Config.arena_index != int(seat["index"]) or Config.is_world_selected():
					seat_problems.append("%s: frozen seat not taken (index=%d world=%s)" % [
						id, Config.arena_index, str(Config.is_world_selected())])
			elif bool(seat["world"]) and bool(seat["offered"]):
				if Config.world_arena_id != id or String(Config.arena_id()) != id \
						or String(Config.arena().get("id", "")) != id:
					seat_problems.append("%s: world seat not taken (seat=%s id=%s arena=%s)" % [
						id, Config.world_arena_id, Config.arena_id(), Config.arena().get("id", "")])
		_c.check("B/both_seats_land_exactly_where_the_catalog_says", seat_problems.is_empty(),
			str(seat_problems))
	else:
		_c.check("B/the_one_catalog_module_both_adapters_read_exists", false, CATALOG_PATH)

	# -----------------------------------------------------------------------
	# C. The frozen nine and the demo's own rules are where they were.
	# -----------------------------------------------------------------------
	Config.pending_mode = "quick"
	_c.check_eq("C/Arena.ids_is_still_the_frozen_nine", str(_ids(Arena.ids())), str(frozen_ids))
	var frozen_screen: Node = await _mount()
	_c.check_eq("C/the_screens_own_grid_is_still_the_nine_row_catalog",
		str(_ids(frozen_screen.arena_rows_now())), str(frozen_ids))
	_c.check_eq("C/the_screens_lock_list_is_still_the_build_wall_plus_the_careers",
		str(_sorted(frozen_screen.locked_ids())), str(_sorted(_expected_locked())))
	var leaked: Array[String] = []
	for id_in in world_ids:
		if frozen_ids.has(String(id_in)) or _ids(Config.selectable_arenas()).has(String(id_in)):
			leaked.append(String(id_in))
	_c.check("C/the_world_set_never_entered_the_frozen_roster_or_the_builds_own_list",
		leaked.is_empty(), str(leaked))
	if demo:
		_c.check_eq("C/a_demo_still_grants_exactly_its_one_arena",
			str(_ids(Config.selectable_arenas())), str(DemoContent.allowed_arena_ids()))
	else:
		_c.check_eq("C/a_full_build_still_grants_the_frozen_nine",
			str(_ids(Config.selectable_arenas())), str(frozen_ids))

	_c.verdict()


# ---------------------------------------------------------------------------
# The mount (the shape `tests/ui/screen_arena_audit.gd` uses: a real router and the
# real screen scene, no test double)
# ---------------------------------------------------------------------------


func _mount() -> Node:
	if _host != null and _host.is_inside_tree():
		_host.queue_free()
	_host = Control.new()
	_host.name = "ArenaCatalogTestFrame"
	root.add_child(_host)
	_host.size = FRAME
	var router := ScreenRouter.new()
	router.name = "ArenaCatalogTestRouter"
	for id in ScreenRouter.ids():
		router.register(String(id), PlaceholderScene)
	router.register("arena", load(SCREEN_SCENE))
	_host.add_child(router)
	router.size = FRAME
	_router = router
	router.go_to("arena")
	await process_frame
	await process_frame
	return router.active_screen()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


## The ids of a catalog list, whatever shape it comes in: a row Array (the frozen
## table, a wrapped catalogue answer) or a plain id list (`Arena.ids()`).
func _ids(items: Variant) -> Array:
	var out: Array = []
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(String((item as Dictionary).get("id", "")))
		else:
			out.append(String(item))
	return out


## The display facts one row carries, one comparable line per row: the seam is a
## pass-through, so the same arena must read the same on both paths.
func _row_facts(rows: Array) -> Array:
	var out: Array = []
	for row_in in rows:
		var row: Dictionary = row_in
		out.append("%s|%s|%s|%s|%s|%s|%s" % [
			row.get("id", ""), row.get("name_key", ""), row.get("desc_key", ""),
			row.get("art_path", ""), str(row.get("demo_locked", "")),
			str(row.get("locked", "")), str(row.get("selectable", "")),
		])
	return out


## The world cards the screen built, in the catalog's own order.
func _world_cards(screen: Node) -> Array:
	var out: Array = []
	for id_in in Arena.world_ids():
		if _control(screen, WORLD_CARD_PREFIX + String(id_in)) != null:
			out.append(String(id_in))
	return out


func _control(from: Node, node_name: String) -> Control:
	return from.find_child(node_name, true, false) as Control


func _first_open_frozen(screen: Node) -> String:
	for row_in in screen.arena_rows_now():
		var row: Dictionary = row_in
		if not bool(row.get("locked", false)):
			return String(row.get("id", ""))
	return String(Arena.default_id())


## The two walls this build's frozen grid carries, re-derived from the frozen table,
## the demo's own arena table and the career rules — never from the screen.
func _expected_locked() -> Array:
	var career: Dictionary = ModesSave.load_career(Config.save_store())
	var exposed: Array = DemoContent.allowed_arena_ids()
	var out: Array = []
	for arena in Frozen.arenas():
		var row: Dictionary = arena
		var id := String(row.get("id", ""))
		if Gate.is_demo() and not exposed.has(id):
			out.append(id)
			continue
		if not CareerRules.is_unlocked(row, career):
			out.append(id)
	return out


func _sorted(ids: Array) -> Array:
	var out: Array = ids.duplicate()
	out.sort()
	return out
