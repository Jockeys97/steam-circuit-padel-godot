## fornaio_special_test.gd — focused gate for IL FORNAIO, the Godot-only special athlete.
##
## WHAT THIS PROVES (the ticket's own list, plus the two seams the change touches):
##   1. the specials overlay loads and lists `fornaio` with his briefed facts;
##   2. the FROZEN roster is untouched: `Frozen.athletes()` is still six and
##      `OutfitCatalogue.athlete_ids()` is still the reference's six — a special is
##      additive content on its own list, never a seventh frozen row;
##   3. `AthleteSpawn.make(&"fornaio", &"base")` returns a real rig (not null, not the
##      Volpe fox), and the rig reports the maestro STAND-IN asset honestly;
##   4. the build gate hides him in a demo: `Gate.special_athletes()` /
##      `Config.selectable_special_athletes()` are empty and the seat cannot be held;
##   5. the selection can field him: the seat round trip, the lineup with him as the
##      player AND in an AI slot, and the ported menu's own strip selects him.
##
## Same shape as res://tests/maestro_asset_test.gd: one `ok <name>` / `FAIL <name>`
## line per check, exactly one `PASS n/n` / `FAIL n/n` tally line, exit 0 on PASS and
## 1 on FAIL. Every measured value is printed as a `MEASURED` line so the evidence
## file can quote it.
##
## Run from the repo root (both build answers are the same file):
##   GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" --headless --path godot/ \
##     --script res://tests/fornaio_special_test.gd
##   GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" --headless --path godot/ \
##     --script res://tests/fornaio_special_test.gd -- --demo
extends SceneTree

const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const AthleteRig := preload("res://src/character/athlete_rig.gd")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")
const Specials := preload("res://src/character/specials.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Gate := preload("res://game/content_gate.gd")
const Config := preload("res://game/match_config.gd")
const Lineup := preload("res://game/lineup.gd")
const Art := preload("res://src/ui/data/UiArtPaths.gd")
const Locale := preload("res://src/locale/locale.gd")

const SPECIAL_ID := &"fornaio"
const PORTRAIT_PATH := "res://assets/ui/athletes/fornaio.png"
## The Meshy front view lives OUTSIDE the Godot project: the engine's `res://` is
## `<repo>/godot/`, so the source view is one directory up.
const PORTRAIT_SOURCE_REL := "../meshy/views/fornaio-front.png"
## The stand-in mesh the id is mapped onto while no Meshy export exists
## (`ATHLETE_GLB`); the Volpe fox would be a silent fallback and is refused by name.
const STAND_IN_GLB := "res://assets/athletes/maestro-rigged.glb"
const VOLPE_GLB := "res://assets/athletes/volpe-rigged.glb"
const MENU_SCENE := "res://game/Main.tscn"

var _checks := 0
var _failures := 0
## The selection the menu section may find already set, saved so section 7 can put
## the static config back the way it found it.
var _saved_seat := ""
var _saved_special := false


func _initialize() -> void:
	var demo := Gate.is_demo()
	print("# fornaio special gate build=%s" % Gate.label())

	_overlay_data()
	_frozen_roster_untouched()
	_catalogue_sees_the_special()
	_spawn_and_stand_in()
	_build_gate(demo)
	_selection_and_lineup(demo)
	# The menu section waits for a frame (the ported column is built on `_ready()`),
	# so it returns a coroutine and the rest happens after the tree has iterated once.
	await _menu_strip(demo)
	_locale_and_portrait()

	_finish()


# ---------------------------------------------------------------------------
# 1. The overlay
# ---------------------------------------------------------------------------


func _overlay_data() -> void:
	check_eq(Specials.load_error(), OK, "the specials overlay parses")
	check_true(Specials.has("fornaio"), "the overlay lists fornaio")
	var ids := Specials.ids()
	print("MEASURED specials=%s" % str(ids))
	check_eq(ids.size(), Specials.rows().size(), "ids and rows agree")

	var record: Dictionary = Specials.athlete(SPECIAL_ID)
	check_eq(String(record.get("name", "")), "IL FORNAIO", "the display name is IL FORNAIO")
	check_eq(String(record.get("color", "")), "#d98e2b", "the roster UI colour is amber d98e2b")
	check_eq(Specials.height_m(SPECIAL_ID), 1.82, "the briefed rig height is 1.82 m")
	check_eq(
		Specials.stand_in_asset(SPECIAL_ID),
		STAND_IN_GLB,
		"the stand-in asset is named in the overlay"
	)
	check_true(bool(record.get("special_athlete", false)), "the record marks itself as an addition")
	var stats: Dictionary = record.get("stats", {})
	check_true(
		stats.has("speed") and stats.has("power") and stats.has("control"),
		"the record carries the sim's stats"
	)
	var special: Dictionary = record.get("special", {})
	check_true(
		float(special.get("cooldown", 0.0)) > 0.0, "the record carries a special with a cooldown"
	)


# ---------------------------------------------------------------------------
# 2. The frozen roster
# ---------------------------------------------------------------------------


func _frozen_roster_untouched() -> void:
	var frozen_size := Frozen.athletes().size()
	print("MEASURED frozen_athletes=%d" % frozen_size)
	check_eq(frozen_size, 6, "Frozen.athletes stays the reference's six")
	var ids := Catalogue.athlete_ids()
	check_eq(ids.size(), 6, "the outfit catalogue's roster is still the six")
	check_true(not ids.has(SPECIAL_ID), "fornaio is NOT in athlete_ids()")
	var entries := Catalogue.entries().size()
	print("MEASURED catalogue_entries=%d" % entries)
	check_eq(entries, 26, "the catalogue still carries the six athletes' 26 outfits")
	check_eq(
		Config.selectable_athletes().size(),
		Gate.roster().size(),
		"selectable_athletes is the build's own roster"
	)
	check_true(
		not _ids_of(Config.selectable_athletes()).has("fornaio"),
		"fornaio is NOT in selectable_athletes()"
	)


# ---------------------------------------------------------------------------
# 3. The catalogue answers for the special
# ---------------------------------------------------------------------------


func _catalogue_sees_the_special() -> void:
	check_true(Catalogue.has_outfit(SPECIAL_ID, &"base"), "has_outfit answers for fornaio/base")
	check_true(
		not Catalogue.has_outfit(SPECIAL_ID, &"legend"), "an outfit fornaio does not own is refused"
	)
	var outfits := Catalogue.outfit_ids(SPECIAL_ID)
	check_eq(str(outfits), str([&"base"]), "fornaio owns exactly the base outfit")

	var athlete := Catalogue.athlete(SPECIAL_ID)
	check_eq(
		String(athlete.get("name", "")),
		"IL FORNAIO",
		"the catalogue hands back the special's record"
	)

	var entry: Dictionary = Catalogue.resolve(SPECIAL_ID, &"base")
	check_true(not entry.is_empty(), "resolve answers for fornaio/base")
	check_eq(
		String(entry.get("primary_hex", "")).to_lower(),
		"#f7f4ee",
		"the base outfit's primary is the jacket white f7f4ee"
	)
	check_eq(
		String(entry.get("trim_hex", "")).to_lower(),
		"#d98e2b",
		"the base outfit's trim is the amber d98e2b"
	)

	# The same door `AthleteSpawn` uses, so `make()` can never be refused by the
	# nickname check the factory performs first.
	check_true(
		AthleteSpawn.is_known(SPECIAL_ID, &"base"), "AthleteSpawn.is_known answers for fornaio"
	)
	var outfit_key := AthleteSpawn.outfit_name_key(SPECIAL_ID, &"base")
	check_true(
		Locale.is_resolvable(outfit_key), "the base outfit's name key resolves (%s)" % outfit_key
	)


# ---------------------------------------------------------------------------
# 4. Spawn, and the stand-in honesty
# ---------------------------------------------------------------------------


func _spawn_and_stand_in() -> void:
	var rig: Node3D = AthleteSpawn.make(
		SPECIAL_ID, &"base", {"name": "FornaioProbe", "locomotion": &"idle"}
	)
	check_true(rig != null, "AthleteSpawn.make(fornaio, base) returns a rig, not null")
	if rig == null:
		return
	var details := AthleteSpawn.describe(rig)
	print(
		(
			"MEASURED joints=%d triangles=%d asset=%s glb=%s"
			% [
				int(details.get("joints", -1)),
				int(details.get("triangles", -1)),
				str(details.get("athlete_asset", &"")),
				str(details.get("asset_glb", "")),
			]
		)
	)
	check_eq(details.get("load_error", -1), OK, "the rig loads")
	check_eq(details.get("athlete_asset", &""), SPECIAL_ID, "the rig reports the fornaio id")
	check_eq(
		String(details.get("asset_glb", "")),
		STAND_IN_GLB,
		"the rig reports the maestro stand-in mesh"
	)
	check_true(
		String(details.get("asset_glb", "")) != VOLPE_GLB, "fornaio is never the Volpe fallback"
	)
	check_eq(
		str(AthleteRig.ATHLETE_GLB.get(SPECIAL_ID, "")),
		Specials.stand_in_asset(SPECIAL_ID),
		"ATHLETE_GLB and the overlay name the same stand-in"
	)
	var states: Array = details.get("locomotion_states", [])
	print("MEASURED locomotion=%s" % str(states))
	for clip in [&"idle", &"walk", &"run"]:
		check_true(clip in states, "the stand-in carries the '%s' clip" % clip)
	check_true(int(details.get("joints", 0)) >= 24, "the stand-in is a humanoid rig")
	check_eq(
		details.get("catalogue_outfit", {}).get("athlete_id", &""),
		SPECIAL_ID,
		"the outfit was noted on the rig through the catalogue's own door"
	)
	rig.free()


# ---------------------------------------------------------------------------
# 5. The build gate and the seat
# ---------------------------------------------------------------------------


func _build_gate(demo: bool) -> void:
	check_eq(
		str(Specials.selectable(true)),
		str([]),
		"a DEMO build offers no specials (the parameterised answer)"
	)
	check_eq(
		Specials.selectable(false).size(),
		Specials.ids().size(),
		"a FULL build offers the whole specials table"
	)

	var listed := _ids_of(Gate.special_athletes())
	var config_list := _ids_of(Config.selectable_special_athletes())
	check_eq(str(config_list), str(listed), "Config's special list is the gate's own answer")
	if demo:
		check_eq(str(listed), str([]), "a demo's gate lists no special")
		check_true(not Config.set_special_athlete_id("fornaio"), "a demo refuses the special seat")
		check_true(Config.athlete_id() != "fornaio", "a demo's selection is never fornaio")
		# The seat cannot even be forced: `apply_build_limits()` clears it.
		Config.special_athlete_id = "fornaio"
		var limits := Config.apply_build_limits()
		check_true(
			limits.has("special_athlete_id"), "the demo's limits report the cleared special seat"
		)
		check_eq(Config.special_athlete_id, "", "the demo's limits clear the special seat")
	else:
		check_true(listed.has("fornaio"), "a full build's gate lists fornaio")
		check_true(
			Config.selectable_special_athletes().size() > 0, "a full build offers the special strip"
		)
		# The seat round trip: selecting him takes the selection, a frozen pick gives
		# it back, and the frozen index is untouched all along.
		var before_index := Config.athlete_index
		check_true(
			Config.set_special_athlete_id("fornaio"), "a full build accepts the special seat"
		)
		check_eq(Config.athlete_id(), "fornaio", "the selected athlete id is fornaio")
		check_true(Config.is_special_selected(), "the seat reports itself occupied")
		check_eq(
			String(Config.athlete().get("name", "")),
			"IL FORNAIO",
			"Config.athlete() hands the special's record"
		)
		check_eq(Config.athlete_index, before_index, "the frozen index is left where it was")
		check_eq(
			str(Config.outfit_ids()), str([&"base"]), "the special's own outfit list reaches Config"
		)
		check_true(
			not Config.set_special_athlete_id("burattino"),
			"an id the overlay does not hold is refused"
		)
		check_eq(Config.apply_build_limits().size(), 0, "a full build's limits change nothing")
		Config.clear_special_athlete()
		check_eq(
			Config.athlete_id(),
			String(Frozen.athletes()[before_index]["id"]),
			"clearing the seat puts the frozen selection back"
		)
		check_true(
			Config.set_special_athlete_id("fornaio"), "the seat can be taken again after a clear"
		)
		Config.clear_special_athlete()


# ---------------------------------------------------------------------------
# 6. The selection fields him: the player slot and an AI slot
# ---------------------------------------------------------------------------


func _selection_and_lineup(demo: bool) -> void:
	var special: Dictionary = Catalogue.athlete(SPECIAL_ID)
	check_true(not special.is_empty(), "the special's record is a lineup candidate")

	var player: Dictionary = Frozen.athletes()[0]
	var as_player := Lineup.resolve(special)
	var player_ids := Lineup.ids(as_player)
	print("MEASURED lineup_player_special=%s" % JSON.stringify(player_ids))
	check_eq(String(player_ids.get("player", "")), "fornaio", "the player slot holds fornaio")
	check_eq(_distinct(player_ids), 4, "the four slots stay four distinct athletes")

	# An AI slot: the team screen's strip can assign him to a rival slot, and the
	# resolver must honour the preference or the pick would silently revert.
	Lineup.set_pref_source({"lineup": {"opponent": "fornaio"}})
	var with_mate := Lineup.resolve(player)
	var pref_ids := Lineup.ids(with_mate)
	print("MEASURED lineup_special_pref=%s" % JSON.stringify(pref_ids))
	check_eq(
		_distinct(pref_ids),
		4,
		"the four slots stay four distinct athletes with a special in the prefs"
	)
	if demo:
		check_true(
			String(pref_ids.get("opponent", "")) != "fornaio",
			"a demo never fields the special from a stored preference"
		)
	else:
		check_eq(
			String(pref_ids.get("opponent", "")),
			"fornaio",
			"a full build fields the special in an assigned AI slot"
		)
	Lineup.set_pref_source(null)

	# The spawn seam reads a lineup of records: the special's record must survive
	# the round trip it takes to `AthleteSpawn.make`.
	check_eq(
		String(special.get("id", "")),
		"fornaio",
		"the record a lineup carries keeps the id the rig is built from"
	)


# ---------------------------------------------------------------------------
# 7. The ported menu's own strip
# ---------------------------------------------------------------------------


func _menu_strip(demo: bool) -> void:
	var packed: PackedScene = load(MENU_SCENE)
	check_true(packed != null, "the menu scene loads")
	if packed == null:
		return
	var menu: Control = packed.instantiate() as Control
	# The PORTED column, the construction the slice asserts on (its own opt-out).
	menu.set("ui_legacy", true)
	get_root().add_child(menu)
	# `_initialize()` runs before the tree iterates: the added Control's `_ready()` (the
	# whole build) lands on the first frame, so the column is read AFTER it, never
	# synchronously — a synchronous read sees an empty node (measured, on the first run
	# of this test). `--script` runs a full SceneTree, so one `process_frame` suffices.
	await process_frame

	var button := menu.find_child("SpecialAthlete_fornaio", true, false) as Button
	check_eq(
		button != null,
		not demo,
		"the special has a strip button in a full build and none in a demo"
	)
	if button == null and not demo:
		# DIAGNOSTIC: name what the menu actually built, so a missing strip is data to
		# read rather than a guess (a column that never ran looks nothing like one that
		# ran without the block).
		var names := PackedStringArray()
		for found in _menu_buttons(menu):
			names.append(String(found.name))
		print(
			(
				"DIAG menu_nodes=%d buttons=%d legacy=%s names=%s"
				% [
					_all_nodes(menu).size(),
					names.size(),
					str(menu.get("ui_legacy")),
					", ".join(names).substr(0, 400),
				]
			)
		)
	var head := _label_with_prefix(menu, "SPECIAL (")
	check_eq(head != null, not demo, "the strip is labelled as its own block in a full build")
	# The frozen ATLETA row's own count is untouched (the roster, not the roster plus
	# the special).
	var roster_head := _label_with_prefix(menu, "ATLETA (")
	if roster_head != null:
		check_eq(
			roster_head.text,
			"ATLETA (%d)" % Config.selectable_athletes().size(),
			"the ATLETA label still counts the exposed roster alone"
		)
	# The slice's own invariant, cheaply reproduced: exactly one TOGGLE per tier,
	# exposed athlete and exposed arena. The strip's plain buttons never join them.
	var toggles := _toggle_buttons(menu)
	check_eq(
		toggles,
		(
			Frozen.ai_opponents().size()
			+ Config.selectable_athletes().size()
			+ Config.selectable_arenas().size()
		),
		"the menu still offers exactly one choice toggle per frozen row"
	)
	# The setup row's own budget: the world-arena block documents 1044 of the 1056 px
	# a 1152x648 frame allows, and the special strip rides the same column. Measured
	# pre-layout, so the assert is conservative and the MEASURED line is the record.
	if button != null:
		check_eq(button.text, "IL FORNAIO", "the strip names him from the overlay")
		var extras_col := button.get_parent() as Control
		var setup_row := extras_col.get_parent() as Control if extras_col != null else null
		if setup_row != null:
			var tallest_other := 0.0
			for child in setup_row.get_children():
				var column := child as Control
				if column == null or column == extras_col:
					continue
				tallest_other = maxf(tallest_other, column.get_combined_minimum_size().y)
			print(
				(
					"MEASURED menu_setup_row_min=(%.1f, %.1f) extras_min_h=%.1f tallest_other=%.1f"
					% [
						setup_row.get_combined_minimum_size().x,
						setup_row.get_combined_minimum_size().y,
						extras_col.get_combined_minimum_size().y,
						tallest_other,
					]
				)
			)
			check_true(
				setup_row.get_combined_minimum_size().x <= 1056.0,
				"the setup row still fits the 1152x648 width budget"
			)
			check_true(
				extras_col.get_combined_minimum_size().y <= tallest_other,
				"the special strip rides inside the setup row's existing height"
			)
		_saved_seat = Config.athlete_id()
		_saved_special = Config.is_special_selected()
		button.emit_signal("pressed")
		check_eq(Config.athlete_id(), "fornaio", "pressing the strip selects fornaio")
		check_eq(
			String(Config.athlete().get("name", "")),
			"IL FORNAIO",
			"the menu's selection is his record"
		)
		_restore_selection()

	menu.free()


func _restore_selection() -> void:
	Config.clear_special_athlete()
	if _saved_special:
		Config.set_special_athlete_id(_saved_seat)


# ---------------------------------------------------------------------------
# 8. Locale and portrait
# ---------------------------------------------------------------------------


func _locale_and_portrait() -> void:
	for lang in Locale.locales():
		var text := Locale.t("athlete_fornaio_name", {}, lang)
		check_true(text != "athlete_fornaio_name", "athlete_fornaio_name resolves in %s" % lang)
		print("MEASURED athlete_fornaio_name[%s]=%s" % [lang, text])
	check_eq(
		Locale.t("athlete_fornaio_name", {}, "it"), "IL FORNAIO", "the Italian name is IL FORNAIO"
	)
	check_eq(
		Locale.t("athlete_fornaio_name", {}, "en"), "THE BAKER", "the English name is THE BAKER"
	)

	check_true(FileAccess.file_exists(PORTRAIT_PATH), "the portrait copy is on disk")
	var source_path := _portrait_source_path()
	check_true(FileAccess.file_exists(source_path), "the Meshy source view is on disk")
	check_eq(
		Art.candidate_for("athletes", "fornaio"),
		PORTRAIT_PATH,
		"the art table's candidate for a special is the png"
	)
	check_eq(
		Art.path_for("athletes", "fornaio"),
		PORTRAIT_PATH,
		"path_for answers the special's portrait"
	)
	check_eq(
		Art.candidate_for("athletes", "maestro"),
		"res://assets/ui/athletes/maestro.webp",
		"a frozen athlete keeps the webp convention"
	)
	var size_copy := _file_size(PORTRAIT_PATH)
	var size_source := _file_size(source_path)
	print("MEASURED portrait_bytes copy=%d source=%d" % [size_copy, size_source])
	check_eq(size_copy, size_source, "the portrait is a byte-for-byte copy (same size)")


## The Meshy source view resolves OUTSIDE `res://` (see `PORTRAIT_SOURCE_REL`).
func _portrait_source_path() -> String:
	var project_dir := ProjectSettings.globalize_path("res://")
	return project_dir.path_join(PORTRAIT_SOURCE_REL).simplify_path()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _ids_of(rows: Array) -> Array:
	var out := []
	for row in rows:
		out.append(String((row as Dictionary).get("id", "")))
	return out


func _distinct(ids: Dictionary) -> int:
	var seen := {}
	for role in ids:
		seen[String(ids[role])] = true
	return seen.size()


func _label_with_prefix(root: Node, prefix: String) -> Label:
	for node in _all_nodes(root):
		if node is Label and String((node as Label).text).begins_with(prefix):
			return node as Label
	return null


func _toggle_buttons(root: Node) -> int:
	var count := 0
	for button in _menu_buttons(root):
		if button.toggle_mode:
			count += 1
	return count


## Every button under `root`, with its node path: the menu diagnostic names them when
## the strip is missing, so a build that never constructed the column is visible here
## rather than guessed at.
func _menu_buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	for node in _all_nodes(root):
		if node is Button:
			out.append(node as Button)
	return out


func _all_nodes(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		for child in node.get_children():
			stack.append(child)
	return out


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size


func check_eq(got, expected, name: String) -> void:
	_checks += 1
	if got == expected:
		print("ok %s" % name)
	else:
		_failures += 1
		printerr("FAIL %s: expected %s, got %s" % [name, str(expected), str(got)])


func check_true(got: bool, name: String) -> void:
	check_eq(got, true, name)


func _finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)
