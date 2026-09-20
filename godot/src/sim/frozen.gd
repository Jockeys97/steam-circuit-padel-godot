## frozen.gd — the frozen JavaScript tables, loaded verbatim in Godot.
##
## `js/data.js` is authoritative (docs/wayfinder/tickets/simulation-port-boundary.md
## §5: "must NOT be retuned or invented"). `res://src/sim/frozen/data.json` is a
## mechanical serialisation of `COURT`, `BALANCE`, `ATHLETES`, `ROSTER_AVERAGE`,
## `ARENAS`, `MATCH_FORMATS`, `AI_OPPONENTS`, `EVENT_LINES` produced by
## `tools/sim-port/extract-constants.mjs`. Nothing here is typed by hand, and
## nothing here is re-tuned.
##
## Missing keys must be loud: `bal()` asserts presence rather than returning a
## silent default, because a silently-defaulted balance key is a re-tuned game.
extends RefCounted

const DATA_PATH := "res://src/sim/frozen/data.json"

static var _data: Dictionary = {}

static func all() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(DATA_PATH)
		if text.is_empty():
			push_error("frozen.gd: cannot read %s" % DATA_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("frozen.gd: %s is not a JSON object" % DATA_PATH)
			return {}
		_data = parsed
	return _data

## BALANCE (163 keys, `js/data.js:81-323`), keyed as in JavaScript.
static func balance() -> Dictionary:
	return all().get("balance", {})

## COURT (`js/data.js:1-8`).
static func court() -> Dictionary:
	return all().get("court", {})

static func athletes() -> Array:
	return all().get("athletes", [])

static func arenas() -> Array:
	return all().get("arenas", [])

static func ai_opponents() -> Array:
	return all().get("aiOpponents", [])

static func roster_average() -> Dictionary:
	return all().get("rosterAverage", {})

static func event_lines() -> Array:
	return all().get("eventLines", [])


## MATCH_FORMATS (`js/data.js:689-698`). The frozen table keeps menu choices
## data-driven instead of duplicating their values in the match scene.
static func match_formats() -> Dictionary:
	return all().get("matchFormats", {})

## Numeric view of BALANCE. JSON numbers arrive as float; the simulation reads
## them as floats everywhere (`js/game.js` does the same — every BALANCE value is
## used in a float expression), so one accessor is enough and an unknown key
## fails loudly instead of quietly producing 0.
static func bal(name: String) -> float:
	var table := balance()
	if not table.has(name):
		push_error("frozen.gd: BALANCE has no key '%s' — port bug, do not invent a value" % name)
		assert(false, "unknown BALANCE key: %s" % name)
		return 0.0
	return float(table[name])

static func has_bal(name: String) -> bool:
	return balance().has(name)
