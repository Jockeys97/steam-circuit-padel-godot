## specials.gd — the Godot-only special athletes (port additions).
##
## ===========================================================================
## WHY THIS FILE EXISTS
## ===========================================================================
## The reference's six athletes are a MECHANICAL DUMP of `js/data.js` into
## `src/sim/frozen/data.json`, and the outfit catalogue's six ids are the same six
## (`assets/athletes/reference_catalogue.json`, extracted by
## `tools/character/extract_reference_catalogue.py`). Both are frozen: a special
## athlete can never appear in `Frozen.athletes`, in
## `OutfitCatalogue.athlete_ids()` or in `Config.selectable_athletes()` — the
## slice pins the frozen counts, and a demo build's own `DEMO_CONTENT` cannot list
## an addition (`js/build.js`).
##
## So the specials live here, on their own list, exactly as the world arenas live
## in `game/arenas/arena_style.gd::world_ids()`: ADDITIVE content the selection
## asks for BY NAME, never merged into a frozen table. The one overlay file is
## `assets/athletes/specials_catalogue.json`; nothing about a special is typed in
## this script.
##
## ===========================================================================
## PUBLIC API
## ===========================================================================
##   ITEMS
##     Specials.ids() -> PackedStringArray            # table order
##     Specials.has(id) -> bool
##     Specials.rows() -> Array                       # every special's record
##     Specials.selectable(is_demo) -> Array          # [] in a demo build
##
##   ONE ATHLETE (the shape the catalogue, the sim and the menus read)
##     Specials.athlete(id) -> Dictionary             # {} if unknown
##     Specials.outfit_ids(id) -> Array
##     Specials.outfit_record(id, outfit_id) -> Dictionary
##     Specials.stand_in_asset(id) -> String          # the temporary mesh
##     Specials.source_info() -> Dictionary           # provenance, for evidence
##     Specials.load_error() -> int                   # OK (0) when the JSON parsed
##
## ===========================================================================
## WHAT A RECORD IS (and what it is not)
## ===========================================================================
## A special's record carries the SAME KEYS the frozen rows carry where a
## consumer reads them (`id`, `name`, `role`, `color`, `visual`, `desc`, `stats`,
## `special`), because `src/sim/sim.gd` reads `stats` and `special.cooldown` off
## whatever athlete it is handed, and `outfit_catalogue.gd::resolve()` reads
## `name`/`role`/`visual`. It carries `special_athlete: true` and
## `provisional: true` so a reader can always tell an addition from a frozen row.
##
## MY DECISIONS, NOT THE REFERENCE'S: the five stat numbers and the special's
## cooldown are a first pass inside the frozen roster's own envelope (the values
## documented in `docs/wayfinder/evidence/fornaio-special.md`); the owner replaces
## them when the character is tuned. Nothing here is measured from a Meshy export,
## because no fornaio export exists yet — `stand_in` names the mesh the rig
## actually uses and `stand_in_note` says so in words.
##
## ===========================================================================
## THE DEMO ANSWER IS A PARAMETER
## ===========================================================================
## `selectable(is_demo)` takes the build's own answer instead of reading the build
## flag here, so `game/content_gate.gd` (the only file in `godot/game/**` that
## knows where the export lane's tables live) can hand it `is_demo()` and a test
## can ask both answers of one process — the same shape
## `game/arenas/arena_catalog.gd::_init(demo, exposed)` uses for the world set.
extends RefCounted

const DATA_PATH := "res://assets/athletes/specials_catalogue.json"

static var _data: Dictionary = {}
static var _error: int = ERR_UNCONFIGURED


# =========================================================================
# Loading
# =========================================================================

static func _ensure_loaded() -> void:
	if _error != ERR_UNCONFIGURED:
		return
	_error = ERR_CANT_OPEN
	if not FileAccess.file_exists(DATA_PATH):
		push_error("Specials: missing %s (a special athlete's facts live there)" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Specials: %s is not a JSON object" % DATA_PATH)
		_error = ERR_FILE_CORRUPT
		return
	_data = parsed as Dictionary
	if not _data.has("specials") or not _data.has("outfits"):
		push_error("Specials: %s has no specials/outfits" % DATA_PATH)
		_error = ERR_FILE_CORRUPT
		return
	_error = OK


static func load_error() -> int:
	_ensure_loaded()
	return _error


static func source_info() -> Dictionary:
	_ensure_loaded()
	if _error != OK:
		return {"error": _error}
	return {
		"source": _data.get("_source", ""),
		"tool": _data.get("_tool", ""),
		"specials": ids().size(),
		"outfit_entries": _outfit_entry_count(),
	}


# =========================================================================
# Items
# =========================================================================

static func ids() -> PackedStringArray:
	_ensure_loaded()
	var out := PackedStringArray()
	if _error != OK:
		return out
	for row in (_data["specials"] as Array):
		out.append(String((row as Dictionary).get("id", "")))
	return out


static func has(id: String) -> bool:
	return ids().has(id)


## The whole special set, in the table's own order. `selectable(false)` is this
## list; `selectable(true)` is empty — a demo does not offer an addition.
static func rows() -> Array:
	_ensure_loaded()
	if _error != OK:
		return []
	return (_data["specials"] as Array).duplicate(true)


## The specials THIS BUILD offers as a choice: the whole table in a full build,
## NONE in a demo. The build's answer is handed in (`content_gate.gd::special_athletes()`),
## never read here — this module knows nothing about the build flag.
static func selectable(is_demo: bool) -> Array:
	if is_demo:
		return []
	return rows()


# =========================================================================
# One athlete
# =========================================================================

## The record for one special, or {} for an unknown id. See the header for what
## the record carries; `special_athlete: true` marks it as an addition.
static func athlete(athlete_id: StringName) -> Dictionary:
	_ensure_loaded()
	if _error != OK:
		return {}
	for row in (_data["specials"] as Array):
		var record: Dictionary = row
		if StringName(record.get("id", "")) != athlete_id:
			continue
		var out := record.duplicate(true)
		out["special_athlete"] = true
		return out
	return {}


static func outfit_ids(athlete_id: StringName) -> Array:
	_ensure_loaded()
	var out := []
	if _error != OK:
		return out
	var lists: Dictionary = _data["outfits"]
	if not lists.has(String(athlete_id)):
		return out
	for e in (lists[String(athlete_id)] as Array):
		out.append(StringName((e as Dictionary)["id"]))
	return out


static func outfit_record(athlete_id: StringName, outfit_id: StringName) -> Dictionary:
	_ensure_loaded()
	if _error != OK:
		return {}
	var lists: Dictionary = _data["outfits"]
	if not lists.has(String(athlete_id)):
		return {}
	for e in (lists[String(athlete_id)] as Array):
		if StringName((e as Dictionary)["id"]) == outfit_id:
			return e as Dictionary
	return {}


## The mesh the rig actually loads for this special today. NOT the character: no
## Meshy export exists for a special yet, so the rig maps the id onto an existing
## human mesh as a stand-in (`athlete_rig.gd` `ATHLETE_GLB` / `COMPANION_CLIPS`).
## `""` for an unknown id.
static func stand_in_asset(athlete_id: StringName) -> String:
	return String(athlete(athlete_id).get("stand_in", ""))


## The briefed height in metres, as the overlay records it. The STAND-IN mesh has
## its own measured height (the rig's `get_world_extent()` is the engine's answer)
## — the two numbers are allowed to differ, and the difference is recorded in the
## evidence file rather than papered over.
static func height_m(athlete_id: StringName) -> float:
	return float(athlete(athlete_id).get("height_m", 0.0))


static func _outfit_entry_count() -> int:
	var out := 0
	for key in (_data["outfits"] as Dictionary):
		out += ((_data["outfits"] as Dictionary)[key] as Array).size()
	return out
