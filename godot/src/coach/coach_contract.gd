## coach_contract.gd — the coach's declared contract, read from its own JSON.
##
## WHAT THIS IS. One file, `res://src/coach/coach_contract.json`, is the authoritative
## copy of what the coach may send and accept: the wire version, the bounded counter
## allowlist, the sufficiency floors, the provisional confidence gate, the fixed
## TypeSafe endpoint and the Choice question's ids, instructions and criteria. The Godot
## adapter reads it here; the local bridge (`scripts/coach/jev_bridge.mjs`) reads the
## same file from the repository. There is no second copy of the categories.
##
## WHY THE QUESTION TEXT LIVES IN DATA. The criteria are the model-facing rubric of the
## Choice, not player-facing prose: they never reach a screen (the coach's own sentences
## live in `coach_strings.json`, resolved by `coach_text.gd`), and they must be the exact
## text the bridge checks a request against before it forwards anything upstream.
##
## FAILING LOUDLY, NOT QUIETLY. A missing or malformed contract is an error the caller
## must not paper over — a coach that invents its own category list is worse than one
## that refuses to run — so this module pushes an error and answers an empty dictionary,
## which `available()` reports.
extends RefCounted

const PATH := "res://src/coach/coach_contract.json"

## The one category that means "no focus is supported" (`question.criteria`).
const INSUFFICIENT := "insufficient_data"

## The Choice question's own id, and the wire version the bridge accepts.
const QUESTION_ID := "coach_focus"
const WIRE_VERSION := 1

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		if text.is_empty():
			push_error("coach_contract.gd: cannot read %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("coach_contract.gd: %s is not a JSON object" % PATH)
			return {}
		_data = parsed
	return _data


## True when the contract loaded and declares the parts the adapter needs.
static func available() -> bool:
	var loaded := data()
	var ids := category_ids()
	return not loaded.is_empty() and loaded.get("stats", {}) is Dictionary and not ids.is_empty() and ids.has(INSUFFICIENT)


static func wire() -> Dictionary:
	return _dict("wire")


static func upstream() -> Dictionary:
	return _dict("upstream")


static func stats() -> Dictionary:
	return _dict("stats")


static func sufficiency() -> Dictionary:
	return _dict("sufficiency")


## The provisional gate `coach_advice.gd` applies to TypeSafe's own Choice confidence.
static func confidence_gate() -> float:
	var gate: Variant = data().get("confidenceGate", 0.5)
	return float(gate) if gate is float or gate is int else 0.5


static func question() -> Dictionary:
	return _dict("question")


static func instructions() -> Dictionary:
	var out: Variant = question().get("instructions", {})
	return out if out is Dictionary else {}


static func criteria() -> Dictionary:
	var out: Variant = question().get("criteria", {})
	return out if out is Dictionary else {}


## Every declared category id, insufficient_data included, in the order the contract
## writes them — the same order the Choice's criteria are sent in.
static func category_ids() -> Array[String]:
	var out: Array[String] = []
	for key in criteria().keys():
		out.append(String(key))
	return out


## The categories a drill can be attached to, in declared order. `insufficient_data`
## maps to no exercise and is never one of these.
static func drill_categories() -> Array[String]:
	var out: Array[String] = []
	for id in category_ids():
		if id != INSUFFICIENT:
			out.append(id)
	return out


## The counter groups the wire carries, each with its two sides.
static func group_names() -> Array[String]:
	var out: Array[String] = []
	for key in _groups().keys():
		out.append(String(key))
	return out


static func group_sides(group: String) -> Array[String]:
	var sides: Variant = _groups().get(group, [])
	var out: Array[String] = []
	if sides is Array:
		for side in sides:
			out.append(String(side))
	return out


## The single-valued counters (rally count, rally length, and the rally tally).
static func counter_names() -> Array[String]:
	var names: Variant = stats().get("counters", [])
	var out: Array[String] = []
	if names is Array:
		for name in names:
			out.append(String(name))
	return out


## The largest whole number any counter may carry on the wire.
static func max_value() -> int:
	var value: Variant = stats().get("maxValue", 9999)
	return int(value) if value is int or value is float else 9999


static func _groups() -> Dictionary:
	var out: Variant = stats().get("groups", {})
	return out if out is Dictionary else {}


static func _dict(key: String) -> Dictionary:
	var out: Variant = data().get(key, {})
	return out if out is Dictionary else {}
