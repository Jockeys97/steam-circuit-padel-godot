## DemoContent.gd — the port's demo content table, read from the generated file.
##
## Nothing here is typed: the ids, the fixed difficulty, the modes and the outfit
## challenge counts all come from `res://tests/build/demo_content.json`, which
## `tools/export/gen-demo-content.mjs` writes by importing the reference
## (`js/build.js:43-56`, `js/data.js`, `index.html`). Re-generating that file and
## diffing is the drift check.
##
## This exists because the ticket's own file plan puts the table at
## `res://src/build/DemoContent.gd`; this slice's allowlist does not include
## `godot/src/**`, so the module lives here and the relocation is recorded as a
## request in `docs/wayfinder/evidence/demo-and-export.md` instead of being made.
extends RefCounted

const PATH := "res://tests/build/demo_content.json"

static var _doc: Dictionary = {}


static func _document() -> Dictionary:
	if _doc.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		if text.is_empty():
			push_error("DemoContent.gd: cannot read %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("DemoContent.gd: %s is not a JSON object" % PATH)
			return {}
		_doc = parsed
	return _doc


## The whole generated document: content + `allModes` + `outfitChallenges` +
## the source hashes. Evidence and drift checks read this.
static func document() -> Dictionary:
	return _document()


## `DEMO_CONTENT` as generated from `js/build.js:43-56`.
static func content() -> Dictionary:
	return _document().get("content", {})


static func allowed_athlete_ids() -> Array:
	return content().get("athletes", [])


static func allowed_arena_ids() -> Array:
	return content().get("arenas", [])


static func allowed_mode_ids() -> Array:
	return content().get("modes", [])


## The fixed difficulty (`js/build.js:47`) — the demo does not offer a choice.
static func difficulty() -> String:
	return str(content().get("difficulty", ""))


## `outfitChallenges: true` (`js/build.js:53`): the challenge set is reachable in
## the demo because the challenges are bound to a feat on the court, not to
## progression.
static func outfit_challenges_enabled() -> bool:
	return bool(content().get("outfitChallenges", false))


## Every mode the reference's menu declares (`index.html` `.mode-card[data-mode]`),
## so "quick match only" is measured against the full set, not asserted alone.
static func all_mode_ids() -> Array:
	return _document().get("allModes", [])


## Challenge outfits per athlete, from `js/data.js` `ATHLETE_OUTFITS`.
static func outfit_challenges() -> Dictionary:
	return _document().get("outfitChallenges", {})


## Total challenge outfits the demo grants.
static func demo_outfit_challenge_count() -> int:
	var total := 0
	for id in allowed_athlete_ids():
		total += int(outfit_challenges().get(id, 0))
	return total


## sha256 of each source file the table was generated from. Evidence only; a
## mismatch is found by re-running the generator and diffing the file.
static func source_hashes() -> Dictionary:
	return _document().get("sources", {})
