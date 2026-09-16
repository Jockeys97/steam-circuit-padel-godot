## DemoSelfReport.gd — the demo build asserting on itself.
##
## This scene is the main scene of the `linux-x86_64-demo-selfcheck` preset. It
## runs *inside the exported artifact*, with the artifact's own feature tags, its
## own packed resource set and its own copy of the frozen tables — so what it
## reports is what a player would get, not what the repository contains.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 godot/build/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.x86_64 --headless
##
## The same scene also runs inside the demo preset's own binary when it is asked
## for by path, and in the editor project (`--headless --path godot/ res://tests/build/DemoSelfReport.tscn -- --demo`),
## where it reports the full build unless `--demo` is passed.
##
## It prints the content set as one machine-readable JSON line (evidence) and then
## the usual `ok`/`PASS n/n` contract, exiting 0/1 — so the gate is a built thing
## asserting on itself, which is the only proof the ticket accepts.
extends "res://tests/build/TestHarness.gd"

const BuildFlag := preload("res://tests/build/BuildFlag.gd")
const ContentFilter := preload("res://tests/build/ContentFilter.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## Resources that must be inside the pack. A build without these cannot run.
##
## Two probes, because the pack is not a copy of the project directory:
## `script_export_mode=2` stores scripts as binary tokens and rewrites the paths
## that referenced them, so a packed scene or script is found by the resource
## loader (which follows the rewrite) while `FileAccess` on the source path
## legitimately misses. Measured on the first self-check run: `FileAccess.file_exists`
## was false for `res://game/Main.tscn` while `ResourceLoader.exists` was true.
const MUST_BE_PACKED_RESOURCES := [
	"res://game/Main.tscn",
	"res://game/Match.tscn",
	"res://src/sim/frozen.gd",
]

## Raw data files, stored verbatim: only these are readable with `FileAccess`.
const MUST_BE_PACKED_FILES := [
	"res://src/sim/frozen/data.json",
	"res://tests/build/demo_content.json",
]

## Resources the presets exclude. Claimed to be absent, and checked both ways: a
## file a filter dropped is absent to the loader and to FileAccess alike.
const MUST_NOT_BE_PACKED := [
	"res://prototypes/arena_spike/Main.tscn",
	"res://prototypes/render_probe/Main.tscn",
]


func _ready() -> void:
	var demo := BuildFlag.is_demo()
	var exported := not DisplayServer.get_name().is_empty() and OS.has_feature("editor") == false
	print("# DemoSelfReport — build=%s, demo feature tag=%s, exported=%s" % [BuildFlag.label(), OS.has_feature("demo"), exported])
	print("# engine=%s" % Engine.get_version_info().get("string", "?"))
	print("# main scene setting=%s" % ProjectSettings.get_setting("application/run/main_scene", "<unset>"))

	# --- what this build exposes --------------------------------------------
	var athlete_ids: Array = []
	for athlete in ContentFilter.roster():
		athlete_ids.append(athlete.id)
	var arena_ids: Array = []
	for arena in ContentFilter.arenas():
		arena_ids.append(arena.id)
	var locked_ids: Array = []
	for athlete in ContentFilter.locked_athletes():
		locked_ids.append(athlete.id)

	print("# CONTENT " + JSON.stringify({
		"build": BuildFlag.label(),
		"demo_feature_tag": OS.has_feature("demo"),
		"athletes": athlete_ids,
		"all_athletes_in_tables": Frozen.athletes().size(),
		"arenas": arena_ids,
		"all_arenas_in_tables": Frozen.arenas().size(),
		"modes": ContentFilter.mode_ids(),
		"all_modes": DemoContent.all_mode_ids(),
		"difficulty": ContentFilter.difficulty(),
		"locked_athletes": locked_ids,
		"locked_arenas": ContentFilter.locked_arenas().size(),
		"locked_modes": ContentFilter.locked_modes().size(),
		"outfit_challenge_outfits": DemoContent.demo_outfit_challenge_count(),
	}))

	# --- what the demo rule says it must be ---------------------------------
	if demo:
		check_eq(athlete_ids, DemoContent.allowed_athlete_ids(), "the running demo fields exactly the demo's athletes")
		check_eq(arena_ids, DemoContent.allowed_arena_ids(), "the running demo offers exactly the demo's arena")
		check_eq(ContentFilter.mode_ids(), ["quick"], "the running demo offers quick match only")
		check_eq(ContentFilter.difficulty(), "medium", "the running demo runs the fixed difficulty")
		check_eq(athlete_ids.size(), 2, "two athletes, on the artifact")
		check_eq(arena_ids.size(), 1, "one arena, on the artifact")
		check_eq(locked_ids.size() > 0, true, "the demo still shows what it does not grant")
	else:
		check_eq(ContentFilter.roster(), Frozen.athletes(), "the full build exposes every athlete")
		check_eq(ContentFilter.arenas(), Frozen.arenas(), "the full build exposes every arena")
		check_eq(ContentFilter.mode_ids(), DemoContent.all_mode_ids(), "the full build exposes every mode")
		check_eq(ContentFilter.locked_athletes(), [], "the full build locks nothing")

	# --- the pack itself ----------------------------------------------------
	for path in MUST_BE_PACKED_RESOURCES:
		check_true(ResourceLoader.exists(path), "packed (resource loader): %s" % path)
	for path in MUST_BE_PACKED_FILES:
		check_true(FileAccess.file_exists(path), "packed (raw file): %s" % path)
	for path in MUST_NOT_BE_PACKED:
		check_false(FileAccess.file_exists(path), "not packed (raw file): %s" % path)
		check_false(ResourceLoader.exists(path), "not packed (resource loader): %s" % path)

	# The demo's own table is inside the artifact that must obey it.
	check_true(FileAccess.file_exists("res://tests/build/demo_content.json"), "the demo content table ships in the demo build")
	check_true(ResourceLoader.exists("res://game/Main.tscn"), "the game menu scene resolves inside the pack")

	finish()
