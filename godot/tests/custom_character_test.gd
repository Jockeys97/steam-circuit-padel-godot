## custom_character_test.gd — headless gate for the create-a-character slice.
##
## Contract (same shape as res://tests/athlete_rig_test.gd and
## res://tests/athlete_roster_test.gd): every check prints one machine-readable line
## and the run ends with exactly one of
##     PASS <n>/<n>
##     FAIL <n>/<n>
## exiting 0 on PASS and 1 on FAIL.
##
## It goes red if: an unknown or stale appearance id survives normalization, the store
## is not atomic (a failed save damages the previous record) or is not isolated, the
## generated kit does not bind to the rig's skeleton or does not actually change when a
## cosmetic choice changes, the custom athlete has different stats for different
## cosmetics, the frozen six are disturbed, or spawn does not return the custom rig.
##
## Run (verified invocation, from the repo root):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##     --script res://tests/custom_character_test.gd
extends SceneTree

const CustomCharacter := preload("res://src/character/custom_character.gd")
const CustomCharacterStore := preload("res://src/character/custom_character_store.gd")
const CustomCharacterRig := preload("res://src/character/custom_character_rig.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const Catalogue := preload("res://src/character/outfit_catalogue.gd")
const Frozen := preload("res://src/sim/frozen.gd")

const TEST_PATH := "user://custom_character_test.json"

var _checks: int = 0
var _failures: int = 0


func check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("ok ", label)
	else:
		_failures += 1
		printerr("FAIL %s" % label)


func _initialize() -> void:
	CustomCharacterStore.default_path_override = "user://custom-character-gate.json"
	CustomCharacterStore.new().erase()
	_check_record()
	_check_store()
	_check_stats_are_cosmetic()
	_check_spawn_and_frozen_roster()
	_check_rig()
	_check_meshy_body()
	_check_editor_and_match_door()
	# A runtime error aborts only the function it happens in, and the run continues, so
	# this sentinel is what turns a silently truncated gate into a red one.
	check(_checks >= 85, "the whole gate ran (%d checks)" % _checks)
	print("%s custom character: %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	CustomCharacterStore.new().erase()
	quit(0 if _failures == 0 else 1)


# ---------------------------------------------------------------- record

func _check_record() -> void:
	var defaults := CustomCharacter.defaults()
	check(defaults["schema_version"] == CustomCharacter.SCHEMA_VERSION, "record carries the schema version")

	# Every bounded table must actually offer a choice, and the defaults must live in it.
	for field in ["skin_id", "hair_id", "hair_color_id", "outfit_id", "outfit_color_id"]:
		var ids := CustomCharacter.option_ids(field)
		check(ids.size() >= 2, "%s offers at least two options" % field)
		check(ids.has(CustomCharacter.default_option(field)), "%s default is one of its options" % field)
	check(CustomCharacter.option_ids("hair_id").size() >= 2, "two visible hair variants exist")
	check(CustomCharacter.option_ids("outfit_id").size() >= 2, "two visible outfit variants exist")

	# A stale or hostile save normalizes to ids this build knows.
	var hostile := {
		"schema_version": 999,
		"display_name": "   giz   mo    ",
		"skin_id": "chartreuse",
		"hair_id": "mohawk",
		"hair_color_id": "neon",
		"outfit_id": "spacesuit",
		"outfit_color_id": "plaid",
	}
	var safe := CustomCharacter.normalize(hostile)
	check(safe["display_name"] == "GIZ MO", "a name is trimmed, collapsed and upper-cased")
	for field in ["skin_id", "hair_id", "hair_color_id", "outfit_id", "outfit_color_id"]:
		check(CustomCharacter.has_option(field, StringName(safe[field])),
			"a stale %s is normalized onto a known id" % field)
	check(safe["schema_version"] == CustomCharacter.SCHEMA_VERSION, "a stale schema version is normalized")
	check(int(safe.get("_source_schema_version", 0)) == 999, "the stale version is recorded, not hidden")

	# A long name is bounded, an empty one is the documented default.
	check(CustomCharacter.sanitize_name("A".repeat(64)).length() == CustomCharacter.NAME_MAX_LENGTH,
		"a long name is length-bounded")
	check(CustomCharacter.sanitize_name("   ") == CustomCharacter.DEFAULT_NAME,
		"an empty name falls back to the default")
	check(CustomCharacter.normalize(null) == defaults, "a null record reads as the default")
	check(CustomCharacter.normalize("nonsense") == defaults, "a non-record reads as the default")
	check(CustomCharacter.is_canonical(CustomCharacter.defaults()), "the default record is canonical")
	check(not CustomCharacter.is_canonical(hostile), "a hostile record is not canonical")

	# Two different appearances are two different signatures.
	var a := CustomCharacter.defaults()
	var b := a.duplicate(true)
	b["skin_id"] = "deep"
	b["outfit_id"] = "varsity"
	check(CustomCharacter.signature(a) != CustomCharacter.signature(b),
		"two appearances have two signatures")
	var other_body := a.duplicate(true)
	other_body["body_id"] = "uomo_robusto"
	check(CustomCharacter.signature(a) != CustomCharacter.signature(other_body),
		"a body change gets a distinct portrait cache key")


# ---------------------------------------------------------------- store

func _check_store() -> void:
	var store := CustomCharacterStore.new()
	store.path_override = TEST_PATH
	store.erase()

	var missing := store.load_record()
	check(missing[0] == CustomCharacter.defaults(), "a missing file reads as the default record")
	check(String(missing[1]) == "missing", "a missing file reports why")

	var wanted := CustomCharacter.defaults()
	wanted["display_name"] = "RIVA"
	wanted["skin_id"] = "olive"
	wanted["hair_id"] = "crop"
	wanted["hair_color_id"] = "blonde"
	wanted["outfit_id"] = "training"
	wanted["outfit_color_id"] = "azure"
	var written := store.write(wanted)
	check(bool(written["ok"]), "save reports success")
	check(store.exists(), "save created the file")
	var restored := store.read()
	check(restored == wanted, "restart restores name and every appearance field")

	# Atomicity: a failed write must leave the previous record exactly as it was.
	store.fail_before_rename = true
	var doomed := wanted.duplicate(true)
	doomed["display_name"] = "WRECKED"
	var failed_write := store.write(doomed)
	check(not bool(failed_write["ok"]), "a failed save reports failure")
	store.fail_before_rename = false
	check(store.read() == wanted, "a failed save leaves the saved record untouched")
	check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "a failed save leaves no temp file")

	# Corrupt file: default record, no crash, reason reported.
	var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	corrupt.store_string("{ this is not json")
	corrupt.close()
	var recovered := store.load_record()
	check(recovered[0] == CustomCharacter.defaults(), "a corrupt file reads as the default record")
	check(String(recovered[1]) == "malformed", "a corrupt file reports why")

	# An out-of-table record can never reach the disk: it is normalized at the door.
	var sneaky := wanted.duplicate(true)
	sneaky["outfit_id"] = "spacesuit"
	store.write(sneaky)
	check(CustomCharacter.has_option("outfit_id", StringName(store.read()["outfit_id"])),
		"an unknown id is normalized before it is written")
	store.erase()

	# Isolation: the shipped path is not the profile store's, and nothing here wrote
	# to the player's real appearance file.
	check(store.target_path() == TEST_PATH, "the test store is pointed away from the real file")
	check(not CustomCharacterStore.path().begins_with("user://save/"),
		"the appearance file lives outside the profile save group")


# ---------------------------------------------------------------- stats

func _check_stats_are_cosmetic() -> void:
	var first := CustomCharacter.defaults()
	var second := first.duplicate(true)
	second["skin_id"] = "porcelain"
	second["hair_id"] = "buzz"
	second["outfit_id"] = "varsity"
	second["outfit_color_id"] = "lime"
	check(CustomCharacter.stats() == CustomCharacter.stats(), "stats are stable across reads")
	check(CustomCharacter.roster_row(first)["stats"] == CustomCharacter.roster_row(second)["stats"],
		"two different appearances play with identical stats")
	check(CustomCharacter.stats() == Frozen.roster_average(),
		"the custom athlete plays the documented balanced preset")


# ---------------------------------------------------------------- spawn + frozen roster

func _check_spawn_and_frozen_roster() -> void:
	# The frozen six are untouched: same ids, same order, custom not merged in.
	var ids := AthleteSpawn.ids()
	check(ids.size() == 6, "the frozen roster still has exactly six athletes")
	check(not ids.has(CustomCharacter.ID), "the custom athlete is not merged into the frozen roster")
	check(AthleteSpawn.is_custom(CustomCharacter.ID), "the spawn factory knows the custom id")
	check(AthleteSpawn.is_known(CustomCharacter.ID), "the spawn factory treats the custom id as known")
	check(not AthleteSpawn.record(&"maestro").is_empty(), "a frozen athlete still answers with a record")
	check(AthleteSpawn.record(CustomCharacter.ID).get("custom", false), "the custom row is marked custom")
	check(AthleteSpawn.display_name(CustomCharacter.ID) == CustomCharacter.defaults()["display_name"],
		"the custom display name comes from the record")
	check(AthleteSpawn.outfit_ids(CustomCharacter.ID).size() >= 2,
		"the custom athlete offers its outfit variants")


# ---------------------------------------------------------------- rig

func _check_rig() -> void:
	var record := CustomCharacter.defaults()
	record["hair_id"] = "ponytail"
	# The procedural kit is the fallback since the Meshy bodies (2026-09-27); these
	# checks are about the kit, so they ask for it. `_check_meshy_body` covers the body.
	var rig := CustomCharacterRig.make(record, {"name": "TestCustom", "kit": true})
	check(rig != null, "the custom rig builds")
	if rig == null:
		return
	root.add_child(rig)
	var described: Dictionary = rig.describe()
	check(String(described["error"]) == "", "the rig reports no error")
	check(String(described["athlete_id"]) == String(CustomCharacter.ID), "the rig reports the custom id")
	check(int(described["bones"]) >= 24, "the rig carries the shared humanoid skeleton")
	check(int((described["kit"] as Dictionary)["triangles"]) > 200, "the generated kit has real geometry")
	check(String((described["kit"] as Dictionary)["mode"]) == "skinned",
		"the kit is skinned to that skeleton")
	check(bool(described["baked_mesh_visible"]) == false, "the borrowed baked mesh is hidden")
	check(bool(described["mesh_visible"]) == true, "the generated mesh is visible")
	check(int(described["strokes"]) > 0, "the rig keeps the authored padel strokes")

	var skeleton: Skeleton3D = rig.get_skeleton()
	check(skeleton != null and skeleton.get_bone_count() >= 24, "the wrapped skeleton is real")
	var custom_mesh: MeshInstance3D = rig.custom_mesh()
	check(custom_mesh != null and custom_mesh.skin != null, "the generated mesh has a skin")
	check(custom_mesh != null and custom_mesh.mesh.get_surface_count() >= 3,
		"skin, hair and outfit are separate surfaces")

	# A cosmetic change must really move the mesh's own material colours.
	var before: Dictionary = rig.kit().surface_colors()
	var changed := record.duplicate(true)
	changed["skin_id"] = "deep"
	changed["hair_color_id"] = "violet"
	changed["outfit_color_id"] = "lime"
	check(rig.apply_appearance(changed), "the kit re-applies a new appearance")
	var after: Dictionary = rig.kit().surface_colors()
	check(before != after, "changing the appearance changes the rendered colours")

	# A variant is different geometry, not a different tint.
	var geometry_before: int = int((rig.describe()["kit"] as Dictionary)["triangles"])
	var variant := changed.duplicate(true)
	variant["hair_id"] = "buzz"
	variant["outfit_id"] = "training"
	rig.apply_appearance(variant)
	var geometry_after: int = int((rig.describe()["kit"] as Dictionary)["triangles"])
	check(geometry_before != geometry_after, "a hair/outfit variant is different geometry")

	# Animation still drives it: locomotion states arrive through the wrapper.
	check(rig.play_locomotion(&"walk"), "the custom rig plays locomotion")
	check(String(rig.get_locomotion_state()) == "walk", "the locomotion state reads back")

	# Spawn returns the same custom rig, with the appearance handed in.
	var spawned: Node3D = AthleteSpawn.make(CustomCharacter.ID, AthleteSpawn.DEFAULT_OUTFIT, {
		"appearance": changed,
		"name": "SpawnedCustom",
	})
	check(spawned != null, "spawn builds the custom athlete")
	if spawned != null:
		var spawn_state := AthleteSpawn.describe(spawned)
		check(String(spawn_state.get("athlete_id", "")) == String(CustomCharacter.ID),
			"the spawned athlete describes itself as the custom one")
		check(spawn_state.get("kit", {}).get("appearance", {})["skin_id"] == "deep",
			"the spawned athlete uses the appearance it was handed")
		spawned.free()
	rig.free()


# ---------------------------------------------------------------- editor + match door

func _check_meshy_body() -> void:
	const Look := preload("res://src/character/custom_body_look.gd")
	check(CustomCharacter.option_ids("body_id").size() == 5, "five Meshy bodies to choose from, including stylized B")
	check(CustomCharacter.option_ids("hair_id").size() == 5, "five hair styles (bald, crop, ponytail, curly, bun)")
	for body in CustomCharacter.option_ids("body_id"):
		for hair in ["buzz", "bun"]:
			var record := CustomCharacter.defaults()
			record["body_id"] = String(body)
			record["hair_id"] = hair
			var rig := CustomCharacterRig.make(record, {"name": "BodyCheck"})
			check(rig != null and rig.body_id() == StringName("cc_" + String(body)), "%s builds on its Meshy body" % body)
			if rig == null:
				continue
			root.add_child(rig)
			var mat := rig.get_mesh_instance().get_surface_override_material(0) as ShaderMaterial
			check(mat != null and mat.shader == Look.BODY_SHADER, "%s wears the recolour shader" % body)
			var hair_node: Node = rig.get_skeleton().get_node_or_null(Look.HAIR_NODE)
			check((hair_node != null) == (hair != "buzz"), "%s/%s: hair piece present only when chosen" % [body, hair])
			check(rig.get_stroke_names().has(&"meshy_backhand") and rig.get_stroke_names().has(&"meshy_forehand_volley"), "%s carries the roster's baked strokes" % body)
			var other := record.duplicate()
			other["outfit_color_id"] = "azure"
			check(rig.apply_appearance(other), "%s recolours in place" % body)
			var swapped := record.duplicate()
			swapped["body_id"] = "uomo_robusto" if String(body) != "uomo_robusto" else "donna_media"
			check(not rig.apply_appearance(swapped), "%s asks for a rebuild on a new body" % body)
			root.remove_child(rig)
			rig.free()


func _check_editor_and_match_door() -> void:
	const EditorScene := preload("res://src/ui/screens/CharacterEditorScreen.tscn")
	const Store := preload("res://src/character/custom_character_store.gd")
	const Config := preload("res://game/match_config.gd")
	const Frozen := preload("res://src/sim/frozen.gd")

	# Nothing has been created yet: the picker offers exactly what the build shipped.
	Config.clear_special_athlete()
	check(AthleteSpawn.custom_selection_row().is_empty(),
		"before anything is created the custom athlete is not offered")

	# The selection door reads the SHIPPED path (one store in the game), so this
	# section runs against it and puts any real file back afterwards.
	var shipped := Store.new()
	var backup: Variant = null
	if shipped.exists():
		backup = FileAccess.get_file_as_bytes(shipped.target_path())
	var store := shipped
	store.erase()

	var editor: Control = EditorScene.instantiate()
	root.add_child(editor)
	editor.open_saved(store)
	check(editor.edited_record() == CustomCharacter.defaults(), "the editor opens on the default appearance")
	check(not editor.is_dirty(), "a freshly opened editor is not dirty")

	# Every visible option must actually move the preview.
	for field in ["skin_id", "hair_id", "hair_color_id", "outfit_id", "outfit_color_id"]:
		var before: Variant = editor.edited_record()[field]
		check(editor.cycle(field, 1), "the editor steps %s" % field)
		check(editor.edited_record()[field] != before, "stepping %s changes the previewed record" % field)
	editor.apply_name("nina")
	check(editor.edited_record()["display_name"] == "NINA", "the editor normalizes a typed name")
	check(editor.is_dirty(), "an edited editor is dirty")

	# Cancel: the saved record is untouched and the preview goes back.
	editor.cancel()
	check(not store.exists(), "cancel writes nothing")
	check(editor.edited_record() == CustomCharacter.defaults(), "cancel restores the preview")

	# Save: persisted, and the roster/picker now offers the created athlete.
	editor.cycle("skin_id", 2)
	editor.apply_name("NINA")
	var wanted: Dictionary = editor.edited_record()
	check(editor.save(), "save reports success")
	check(store.read() == wanted, "save persisted the appearance")
	check(editor.saved_record() == wanted, "the editor remembers what it saved")
	var reopened: Control = EditorScene.instantiate()
	root.add_child(reopened)
	reopened.open_saved(store)
	check(reopened.edited_record() == wanted, "reopening restores the name and every appearance field")
	reopened.free()

	# The match door: the created athlete is offered by name and can be selected.
	var rows: Array = Config.selectable_special_athletes()
	var custom_row := {}
	for row_in in rows:
		if String((row_in as Dictionary).get("id", "")) == String(CustomCharacter.ID):
			custom_row = row_in
	check(not custom_row.is_empty(), "after a save the created athlete is offered for selection")
	check(String(custom_row.get("name", "")) == "NINA", "the offered row carries the created name")
	check(Config.set_special_athlete_id(String(CustomCharacter.ID)),
		"the created athlete can be selected")
	check(Config.athlete_id() == String(CustomCharacter.ID), "the selection reads back as the created id")
	check(Config.athlete().get("stats", {}) == CustomCharacter.stats(),
		"the selected created athlete plays the balanced preset")

	# A match spawns it, and a rematch spawns it again from the same saved record.
	var match_rig: Node3D = AthleteSpawn.make(StringName(Config.athlete_id()))
	check(match_rig != null, "the match spawns the created athlete")
	if match_rig != null:
		var state := AthleteSpawn.describe(match_rig)
		check(state.get("kit", {}).get("appearance", {})["display_name"] == "NINA",
			"the spawned athlete carries the saved appearance")
		check(state.get("kit", {}).get("appearance", {})["skin_id"] == wanted["skin_id"],
			"the spawned athlete carries the saved skin")
		match_rig.free()
	Config.clear_special_athlete()
	var rematch: Node3D = AthleteSpawn.make(StringName(CustomCharacter.ID))
	check(rematch != null, "a rematch spawns the created athlete again")
	rematch.free()

	# The frozen roster is still exactly the frozen roster.
	check(Frozen.athletes().size() == 6, "the frozen athletes table is unchanged")
	check(Config.athletes().size() == 6, "the selection list is still the frozen six")

	editor.free()
	store.erase()
	# Put the player's own appearance back exactly as it was.
	if backup != null:
		var restore := FileAccess.open(shipped.target_path(), FileAccess.WRITE)
		restore.store_buffer(backup)
		restore.close()
