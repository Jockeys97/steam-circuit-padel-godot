## content_filter_audit.gd — the two answers, proved independent.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ res://tests/build/content_filter_audit.tscn
##
## and the same with `-- --demo`.
##
## `js/build.js` answers two separate questions — `demoFilter` (:58) says what the
## build lists, `demoLocked` (:73) says whether a listed thing is offered — and
## the reference paid for conflating them (its own comment, `js/build.js:63-75`:
## the demo contradicted itself, listing nine arenas while fielding one). A single
## boolean would still pass `scripts/demo-audit.mjs:71`, which is why this audit
## is separate from `demo_audit.gd` and why it asserts the *combinations*:
##
##   in list, unlocked      the demo's own content, and the full build's everything
##   in list, locked        a thing the full build grants and the demo only shows
##   not in list, unlocked  a thing held back from the list but not forbidden
##
## All three are reachable, so the two functions are not one flag wearing two
## names.
extends "res://tests/build/TestHarness.gd"

const BuildFlag := preload("res://tests/build/BuildFlag.gd")
const ContentFilter := preload("res://tests/build/ContentFilter.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const Frozen := preload("res://src/sim/frozen.gd")


func _ready() -> void:
	var demo := BuildFlag.is_demo()
	print("# content_filter_audit — build=%s" % BuildFlag.label())

	var roster: Array = Frozen.athletes()
	var arenas: Array = Frozen.arenas()
	var demo_athletes: Array = DemoContent.allowed_athlete_ids()
	var demo_arenas: Array = DemoContent.allowed_arena_ids()
	var all_athlete_ids: Array = _ids(roster)
	var all_arena_ids: Array = _ids(arenas)

	# --- the build's own view ------------------------------------------------
	if demo:
		check_eq(ContentFilter.roster().size(), 2, "demo: the roster lists two athletes")
		check_eq(ContentFilter.arenas().size(), 1, "demo: the arenas list one arena")
		check_eq(ContentFilter.mode_ids(), ["quick"], "demo: the modes list quick match only")
		check_eq(ContentFilter.difficulty(), "medium", "demo: the difficulty is fixed at medium")
		check_eq(ContentFilter.locked_athletes().size(), roster.size() - 2, "demo: the locked athletes are the rest of the roster")
		check_eq(ContentFilter.locked_arenas().size(), arenas.size() - 1, "demo: the locked arenas are the rest of the list")
		check_eq(ContentFilter.locked_modes().size(), 2, "demo: tournament and career are shown locked")
	else:
		check_eq(ContentFilter.roster(), roster, "full: the roster lists every athlete")
		check_eq(ContentFilter.arenas(), arenas, "full: the arenas list every arena")
		check_eq(ContentFilter.mode_ids(), ["quick", "tournament", "career"], "full: every mode is listed")
		check_eq(ContentFilter.difficulty(), "", "full: no difficulty is imposed")
		check_eq(ContentFilter.locked_athletes(), [], "full: nothing is locked")
		check_eq(ContentFilter.locked_arenas(), [], "full: nothing is locked")
		check_eq(ContentFilter.locked_modes(), [], "full: nothing is locked")

	# The list a build shows is the one its filter produced — the screens read
	# this and nothing re-derives it (`js/ui.js:737-750` is the reference's half).
	for athlete in ContentFilter.roster():
		check_true(demo_athletes.has(athlete.id) or not demo, "listed athlete is inside the demo's set or this is the full build: %s" % athlete.id)

	# --- the allowed list decides the lock answer, not the filter's list ------
	var outsider: Dictionary = _first_outside(roster, demo_athletes)
	check_false(outsider.is_empty(), "there is an athlete outside the demo's set to reason about")

	# not in list, unlocked: this build filters it out of the roster's list, and
	# the same function answers "not locked" when asked with the full set.
	var filtered_out: Array = ContentFilter.filter([outsider], demo_athletes)
	check_eq(filtered_out.size(), 0 if demo else 1, "filter with the demo's list: excluded in a demo, kept in a full build")
	check_false(ContentFilter.is_locked(outsider, all_athlete_ids), "the same item is not locked when the allowed set grants it")

	# in list, locked: the full build's list keeps it, the demo's lock answer
	# still refuses it. Both are true at once, in the same build.
	var kept: Array = ContentFilter.filter([outsider], all_athlete_ids)
	check_eq(kept.size(), 1, "filter with the full list keeps it in the list")
	check_eq(ContentFilter.is_locked(outsider, demo_athletes), demo, "and the lock answer still follows the demo set and the build flag")

	# --- the ambiguity a single boolean would have --------------------------
	# With one flag, "not listed" and "not locked" could not disagree. They do:
	# the same athlete, in the same demo build, is out of the demo's list and
	# inside the full build's list, and its lock answer flips with the set it is
	# asked about rather than with the list it was filtered from.
	check_eq(
		ContentFilter.is_locked(outsider, all_athlete_ids) != ContentFilter.is_locked(outsider, demo_athletes),
		demo,
		"lock answer depends on the allowed set, and only in a demo does it differ"
	)

	# An empty allowed list is the limit case: in a demo it lists nothing, in a
	# full build it is not consulted at all — the reference's `if (!IS_DEMO) return items`.
	check_eq(ContentFilter.filter(roster, []).size(), 0 if demo else roster.size(), "empty allowed list: nothing in a demo, everything in a full build")

	finish()


static func _ids(list: Array) -> Array:
	var out: Array = []
	for item in list:
		out.append(item.get("id", ""))
	return out


static func _first_outside(list: Array, allowed: Array) -> Dictionary:
	for item in list:
		if not allowed.has(item.get("id", "")):
			return item
	return {}
