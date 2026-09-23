## arena_selector_contract_test.gd — Luca's 2026-09-18 arena-screen screenshot
## symptoms, read back off the mounted ArenaScreen as a contract.
##
## WHAT IT PROVES, one named check per symptom (ticket `WORLD_ARENAS_SELECTION`,
## the screen's own ticket UIR-12 — the red checks are what the screenshot failed):
##
##   1. the header is bound, not raw: `TitleLabel`, `SubLabel` and `BackButton`
##      show `UiStrings.t("arenaTitle")` / `t("arenaSub")` / `t("back")` and never
##      the key itself (the screenshot read "arenaTitle", "arenaSub", "back");
##   2. the world five are on the screen: `world_arena_rows_now()` is exactly
##      torii, medina, carioca, aurora, egeo in catalog order, each
##      `WorldArenaCard_<id>` exists, and `WorldGridArea` is a PREVIOUS sibling of
##      `GridArea` inside `Body` — the world block sits above the frozen nine
##      instead of below the fold;
##   3. no visible Label or Button carries an unresolved locale template — the raw
##      "🏆 {n} {word}" form the locked cards showed through `unlockTrophies` /
##      `unlockStars` bound with no params;
##   4. a card is click-to-play: `ArenaScreen.activate_arena(arena_id, apply_scene)`
##      exists, accepts an open frozen arena and — in a full build — a world arena
##      with `apply_scene = false`, writes `Config.arena_id()` and
##      `Config.pending_mode`, and refuses a locked frozen arena;
##   5. the five are VISIBLE, not just present: every `WorldArenaArt_<id>` preview
##      holds a TextureRect with a real texture — the designed still from
##      `art/concepts/world-arenas-r1/`, copied into `game/arenas/art/world/<id>.png`
##      (the screenshot showed five empty accent panels). Card preview only: the
##      match backdrop stays procedural.
##
## THE DEMO HALF (`-- --demo`, `Gate.is_demo()`): the world set does not exist —
## `world_arena_rows_now()` is empty and no `WorldArenaCard_*` is built.
##
## RED IS EXPECTED until the selector fix lands: every red check is one of the
## bugs, by name. The screen is mounted through the real `ScreenRouter` in a
## 1280x720 host and `Config.save_dir` points at a scratch store removed on the
## way out, so no real profile is read or written; `pending_mode` is restored.
##
## Run:  "$GODOT" --headless --path godot/ --script res://tests/ui/arena_selector_contract_test.gd
##       same, with `-- --demo` appended, runs the demo half.

extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const ScreenRouter := preload("res://src/ui/ScreenRouter.gd")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")

const FRAME := Vector2(1280, 720)

## The world five in `arena_style.gd` table order (`Arena.world_ids()` order).
const WORLD_FIVE := ["torii", "medina", "carioca", "aurora", "egeo"]
const WORLD_AREA_NODE := "WorldGridArea"
const WORLD_CARD_PREFIX := "WorldArenaCard_"
const WORLD_ART_PREFIX := "WorldArenaArt_"
const BODY_NODE := "Body"
const FROZEN_GRID_AREA_NODE := "GridArea"

## An unresolved locale template still on screen: `unlockTrophies` / `unlockStars`
## render as "🏆 {n} {word}" / "⭐ {n} {word}" until count and noun are substituted,
## so any visible `{…}` placeholder is the raw form Luca read on the locked cards.
const TEMPLATE_PATTERN := "\\{[a-zA-Z0-9_]+\\}"

var _host: Control = null
var _store_dir: String = ""
var _previous_save_dir: String = ""
var _entry_mode: String = ""


func _initialize() -> void:
	var audit := AuditBase.new("WORLD_ARENAS_SELECTION / UIR-12 ArenaScreen contract")
	_previous_save_dir = Config.save_dir
	_store_dir = "user://arena_selector_contract_%d" % Time.get_ticks_usec()
	Config.save_dir = _store_dir
	_entry_mode = String(Config.pending_mode)
	await _run(audit)
	Config.pending_mode = _entry_mode
	_cleanup_store()
	quit(audit.finish())


## The same isolation `screen_arena_audit.gd` uses: the scratch store is removed
## and the config's own directory is put back before the verdict is printed.
func _cleanup_store() -> void:
	if _store_dir == "":
		return
	var absolute := ProjectSettings.globalize_path(_store_dir)
	DirAccess.remove_absolute(_store_dir)
	DirAccess.remove_absolute(absolute)
	Config.save_dir = _previous_save_dir


func _run(audit: AuditBase) -> void:
	Config.pending_mode = "quick"
	var screen: Node = await _mount()
	audit.check_true(screen != null, "arena/the_screen_mounts")
	if screen == null:
		return
	_header(audit, screen)
	_world(audit, screen)
	_templates(audit, screen)
	_activation(audit, screen)
	_fixture_launch(audit, screen)


func _fixture_launch(audit: AuditBase, screen: Node) -> void:
	for mode in ["career", "tournament"]:
		Config.pending_mode = mode
		screen.enter({"entry_mode": mode})
		var launch := screen.find_child("PlayFixture", true, false) as Button
		audit.check_true(launch != null and launch.is_visible_in_tree(), mode + "/launch_visible")
		audit.check_true(not launch.disabled, mode + "/launch_enabled")
		audit.check_eq(launch.get_parent().get_parent().name, &"Frame", mode + "/launch_outside_scroll")
		audit.check_true(launch.pressed.is_connected(screen.start_match), mode + "/mouse_uses_existing_start")
		var registered := false
		for spec in screen.focus_controls():
			if spec.get("action", "") == "play-fixture":
				registered = true
		audit.check_true(registered, mode + "/controller_launch_registered")
		audit.check_true(screen.start_match(false), mode + "/scheduled_match_can_start")
		audit.check_eq(Config.arena_id(), screen.in_program_id(), mode + "/starts_calendar_arena")
		audit.check_eq(Config.pending_mode, mode, mode + "/preserves_mode")
		var scroll := screen.find_child("Scroll", true, false) as ScrollContainer
		scroll.scroll_vertical = 10000
		audit.check_true(launch.is_visible_in_tree(), mode + "/launch_remains_visible_when_scrolling")
	Config.pending_mode = "quick"
	screen.enter({"entry_mode": "quick"})
	audit.check_true(not screen.find_child("FixtureLaunch", true, false).visible, "quick/no_calendar_launch")


## The router mount of `screen_arena_audit.gd`, one screen and two frames: the
## screen under test is the scene's own, never a hand-built stand-in.
func _mount() -> Node:
	if _host != null and _host.is_inside_tree():
		_host.queue_free()
	_host = Control.new()
	_host.name = "ContractHost"
	root.add_child(_host)
	_host.size = FRAME
	var router := ScreenRouter.new()
	router.name = "ContractRouter"
	for screen_id in ScreenRouter.ids():
		router.register(String(screen_id), PlaceholderScene)
	var arena_scene: PackedScene = load("res://src/ui/screens/ArenaScreen.tscn")
	router.register("arena", arena_scene)
	_host.add_child(router)
	router.size = FRAME
	router.go_to("arena")
	await process_frame
	await process_frame
	return router.active_screen()


# ---------------------------------------------------------------------------
# 1. The header: the locale's words, never the keys


func _header(audit: AuditBase, screen: Node) -> void:
	var title := _text_of(screen.find_child("TitleLabel", true, false))
	var sub := _text_of(screen.find_child("SubLabel", true, false))
	var back := _text_of(screen.find_child("BackButton", true, false))
	audit.report("header: title=%s sub=%s back=%s" % [title, sub, back])
	audit.check_eq(title, UiStrings.t("arenaTitle"), "arena/title_is_the_locales_word")
	audit.check_ne(title, "arenaTitle", "arena/title_is_not_the_raw_key")
	audit.check_eq(sub, UiStrings.t("arenaSub"), "arena/sub_is_the_locales_word")
	audit.check_ne(sub, "arenaSub", "arena/sub_is_not_the_raw_key")
	audit.check_eq(back, UiStrings.t("back"), "arena/back_is_the_locales_word")
	audit.check_ne(back, "back", "arena/back_is_not_the_raw_key")


# ---------------------------------------------------------------------------
# 2. The world five, on screen and above the fold


func _world(audit: AuditBase, screen: Node) -> void:
	var has_rows := screen.has_method("world_arena_rows_now")
	audit.check_true(has_rows, "arena/world_arena_rows_now_exists")
	if Gate.is_demo():
		_world_demo(audit, screen, has_rows)
		return
	if not has_rows:
		audit.report("world_arena_rows_now is missing: the world checks fail by name")
		for check_name in ["arena/world_rows_are_the_five_in_catalog_order",
				"arena/world_card_torii_is_on_the_screen",
				"arena/world_card_medina_is_on_the_screen",
				"arena/world_card_carioca_is_on_the_screen",
				"arena/world_card_aurora_is_on_the_screen",
				"arena/world_card_egeo_is_on_the_screen",
				"arena/world_grid_area_exists",
				"arena/world_grid_area_sits_above_the_frozen_grid",
				"arena/world_card_torii_shows_its_still",
				"arena/world_card_medina_shows_its_still",
				"arena/world_card_carioca_shows_its_still",
				"arena/world_card_aurora_shows_its_still",
				"arena/world_card_egeo_shows_its_still"]:
			audit.check_true(false, String(check_name))
		return

	var ids: Array = []
	for row in screen.world_arena_rows_now():
		ids.append(String((row as Dictionary).get("id", "")))
	audit.report("world rows: %s" % JSON.stringify(ids))
	audit.check_eq(ids, WORLD_FIVE, "arena/world_rows_are_the_five_in_catalog_order")
	for id in WORLD_FIVE:
		audit.check_true(screen.find_child(WORLD_CARD_PREFIX + String(id), true, false) != null,
			"arena/world_card_%s_is_on_the_screen" % id)
	audit.check_true(screen.find_child(WORLD_AREA_NODE, true, false) != null,
		"arena/world_grid_area_exists")
	_sits_above(audit, screen)
	_world_art(audit, screen)


## Symptom 5 (Luca could not SEE the five): each world card's preview carries the
## designed still, not an empty accent panel. The frozen grid loads its art into a
## TextureRect under `ArenaArt_<id>`; a world card must do the same under
## `WorldArenaArt_<id>`, and the texture must actually be there.
func _world_art(audit: AuditBase, screen: Node) -> void:
	for id in WORLD_FIVE:
		var preview := screen.find_child(WORLD_ART_PREFIX + String(id), true, false)
		if preview == null:
			audit.report("no %s%s on the screen" % [WORLD_ART_PREFIX, id])
			audit.check_true(false, "arena/world_card_%s_shows_its_still" % id)
			continue
		var texture: Texture2D = null
		for child in preview.get_children():
			if child is TextureRect:
				texture = (child as TextureRect).texture
				break
		audit.report("%s%s texture: %s" % [WORLD_ART_PREFIX, id, texture])
		audit.check_true(texture != null, "arena/world_card_%s_shows_its_still" % id)


func _world_demo(audit: AuditBase, screen: Node, has_rows: bool) -> void:
	if not has_rows:
		audit.report("world_arena_rows_now is missing: the demo checks fail by name")
		audit.check_true(false, "arena/demo_offers_no_world_rows")
		audit.check_true(false, "arena/demo_builds_no_world_card_torii")
		return
	var rows: Array = screen.world_arena_rows_now()
	audit.report("demo build: world rows=%d" % rows.size())
	audit.check_eq(rows.size(), 0, "arena/demo_offers_no_world_rows")
	audit.check_true(screen.find_child(WORLD_CARD_PREFIX + "torii", true, false) == null,
		"arena/demo_builds_no_world_card_torii")


## The world block must sit ABOVE the frozen block inside `Body` (a smaller child
## index), or the player scrolls past six 16:9 frozen cards before seeing it.
func _sits_above(audit: AuditBase, screen: Node) -> void:
	var body := screen.find_child(BODY_NODE, true, false)
	var world_area := screen.find_child(WORLD_AREA_NODE, true, false)
	var frozen_area := screen.find_child(FROZEN_GRID_AREA_NODE, true, false)
	if body == null or world_area == null or frozen_area == null:
		audit.report("cannot compare places: body=%s world=%s grid=%s"
			% [body, world_area, frozen_area])
		audit.check_true(false, "arena/world_grid_area_sits_above_the_frozen_grid")
		return
	audit.report("Body children: WorldGridArea#%d GridArea#%d"
		% [world_area.get_index(), frozen_area.get_index()])
	audit.check_true(world_area.get_parent() == body and frozen_area.get_parent() == body
		and world_area.get_index() < frozen_area.get_index(),
		"arena/world_grid_area_sits_above_the_frozen_grid")


# ---------------------------------------------------------------------------
# 3. No raw template anywhere on the screen


func _templates(audit: AuditBase, screen: Node) -> void:
	var pattern := RegEx.new()
	pattern.compile(TEMPLATE_PATTERN)
	var scanned: Array = []
	var offenders: Array = []
	_collect_text(screen, pattern, scanned, offenders)
	audit.report("visible text nodes scanned: %d" % scanned.size())
	audit.check_gt(scanned.size(), 0, "arena/the_label_scan_reaches_the_screen")
	audit.check_eq(offenders, [], "arena/no_visible_label_shows_a_raw_template")


## Every visible text node the screen draws, Labels and Buttons both: a template
## is a bug in either. `is_visible_in_tree()` is the screen's own answer about
## what a player could read, so a hidden node cannot fail the scan.
func _collect_text(node: Node, pattern: RegEx, scanned: Array, offenders: Array) -> void:
	if (node is Label or node is Button) and node.is_visible_in_tree():
		var shown := _text_of(node)
		if shown != "":
			scanned.append(shown)
			if pattern.search(shown) != null:
				offenders.append("%s reads \"%s\"" % [node.name, shown])
	for child in node.get_children():
		_collect_text(child, pattern, scanned, offenders)


# ---------------------------------------------------------------------------
# 4. A card is click-to-play (`activate_arena`)


func _activation(audit: AuditBase, screen: Node) -> void:
	var exists := screen.has_method("activate_arena")
	audit.check_true(exists, "arena/activate_arena_exists")
	if not exists:
		audit.report("ArenaScreen.activate_arena is missing: the activation checks fail by name")
		audit.check_true(false, "arena/activate_arena_returns_true_for_an_open_arena")
		audit.check_true(false, "arena/activate_arena_writes_the_session_arena")
		audit.check_true(false, "arena/activate_arena_keeps_the_pending_mode_quick")
		audit.check_true(false, "arena/activate_arena_refuses_a_locked_arena")
		if not Gate.is_demo():
			audit.check_true(false, "arena/activate_arena_reaches_a_world_arena")
			audit.check_true(false, "arena/activate_arena_takes_the_world_seat")
		return

	var open_id := _first_unlocked_frozen_id(screen)
	audit.report("open frozen id: %s" % open_id)
	var opened: Variant = screen.activate_arena(open_id, false)
	audit.check_true(opened == true, "arena/activate_arena_returns_true_for_an_open_arena")
	audit.check_eq(Config.arena_id(), open_id, "arena/activate_arena_writes_the_session_arena")
	var pending := String(Config.pending_mode)
	audit.check_eq(pending, "quick", "arena/activate_arena_keeps_the_pending_mode_quick")

	var locked_id := _first_locked_frozen_id(screen)
	audit.report("locked frozen id: %s" % locked_id)
	if locked_id == "":
		audit.check_true(false, "arena/activate_arena_refuses_a_locked_arena")
	else:
		var refused: Variant = screen.activate_arena(locked_id, false)
		audit.check_true(refused == false, "arena/activate_arena_refuses_a_locked_arena")

	if Gate.is_demo():
		return
	var world: Variant = screen.activate_arena("torii", false)
	audit.check_true(world == true, "arena/activate_arena_reaches_a_world_arena")
	audit.check_true(Config.is_world_selected() or Config.arena_id() == "torii",
		"arena/activate_arena_takes_the_world_seat")


## The brief's own first choice: the first frozen arena this build leaves open
## (`officina` in a fresh profile, which is the fallback if the walk finds none).
func _first_unlocked_frozen_id(screen: Node) -> String:
	for row in screen.arena_rows_now():
		var entry: Dictionary = row
		if not bool(entry.get("locked", false)):
			return String(entry.get("id", ""))
	return "officina"


## A frozen arena behind a lock (`cattedrale` in a fresh profile: trophies 2).
## An empty answer is reported and the check fails by name rather than passing.
func _first_locked_frozen_id(screen: Node) -> String:
	for row in screen.arena_rows_now():
		var entry: Dictionary = row
		if bool(entry.get("locked", false)):
			return String(entry.get("id", ""))
	return ""


func _text_of(node: Node) -> String:
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	return ""
