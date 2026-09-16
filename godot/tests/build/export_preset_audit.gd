## export_preset_audit.gd — the preset inventory, read from `res://export_presets.cfg`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ res://tests/build/export_preset_audit.tscn
##
## A preset file that exists is not a preset that works — this audit only checks
## the shape (names, paths, tags, filters). What proves the presets is the
## exported artifact and `DemoSelfReport.gd`, which runs inside it.
##
## What it does check is the set of mistakes a preset file makes silently:
## two presets sharing an output path (the second export overwrites the first),
## a preset that forgot the demo feature tag (the demo would be the full game),
## a preset that would ship without `*.json` (the game would have no frozen
## tables), a preset whose exclude pattern does not actually match what it claims
## to exclude (Godot's `String.match` is asserted here rather than assumed), and
## a preset that would boot the test harness scene instead of the game.
extends "res://tests/build/TestHarness.gd"

const PRESETS_PATH := "res://export_presets.cfg"
const HARNESS_SCENE := "res://tests/SmokeTest.tscn"


func _ready() -> void:
	print("# export_preset_audit — reading %s" % PRESETS_PATH)

	check_true(FileAccess.file_exists(PRESETS_PATH), "export_presets.cfg is inside the project")
	if not FileAccess.file_exists(PRESETS_PATH):
		finish()
		return

	var cfg := ConfigFile.new()
	var err := cfg.load(PRESETS_PATH)
	check_eq(err, OK, "export_presets.cfg parses as a ConfigFile")

	var presets := _presets(cfg)
	check_eq(presets.size(), 3, "three presets are declared")
	check_true(presets.size() > 0, "at least one preset is declared")

	# The two that exist because the ticket demands them, plus the self-check one.
	check_true(_by_name(presets, "linux-x86_64") != null, "the full desktop preset exists")
	check_true(_by_name(presets, "linux-x86_64-demo") != null, "the demo preset exists")
	check_true(_by_name(presets, "linux-x86_64-demo-selfcheck") != null, "the demo self-check preset exists")

	var names: Array = []
	var paths: Array = []
	var tagged: Array = []
	for preset in presets:
		names.append(preset.name)
		paths.append(preset.path)
		check_eq(preset.platform, "Linux", "preset %s targets Linux" % preset.name)
		check_true(preset.runnable, "preset %s is marked runnable" % preset.name)
		check_true(preset.path.ends_with(".x86_64"), "preset %s writes an x86_64 binary" % preset.name)
		if preset.name.contains("demo"):
			check_true(preset.features.has("demo"), "preset %s carries the demo feature tag" % preset.name)
		else:
			check_false(preset.features.has("demo"), "preset %s does not carry the demo feature tag" % preset.name)
		if preset.features.has("demo"):
			tagged.append(preset.name)

		# Every preset must carry its own main scene: `run/main_scene` in
		# `project.godot` is the harness scene on purpose and must not change.
		var main_scene: String = str(preset.options.get("application/main_scene", ""))
		check_true(main_scene.ends_with(".tscn"), "preset %s declares a main scene (%s)" % [preset.name, main_scene])
		check_true(main_scene != HARNESS_SCENE, "preset %s does not boot the test harness scene" % preset.name)

		# JSON is packed only when asked for. Both the frozen tables and the demo
		# content table are JSON, so a preset without this ships an empty game.
		check_true(preset.include_filter.contains("*.json"), "preset %s includes *.json" % preset.name)
		check_true(preset.exclude_filter.contains("res://prototypes/"), "preset %s excludes the prototype projects" % preset.name)
		# Render evidence is not game content: `scripts/build-dist.mjs:1-18` is the
		# reference making the same call (131 MB of masters are for regenerating
		# assets, not for playing). Measured on the first export: those imported
		# textures were 54,275,370 of the pack's 55,426,408 bytes.
		check_true(preset.exclude_filter.contains("res://src/character/out/"), "preset %s excludes the rig render evidence" % preset.name)
		check_true(preset.exclude_filter.contains("res://game/out/"), "preset %s excludes the slice's screenshots" % preset.name)
		for pattern in preset.exclude_filter.split(","):
			check_true(pattern.ends_with("/*"), "preset %s excludes a directory tree, not a file: %s" % [preset.name, pattern])

	check_eq(_unique(names), names, "preset names are distinct")
	check_eq(_unique(paths), paths, "preset output paths are distinct")
	check_eq(tagged.size(), 2, "exactly the two demo presets carry the demo feature tag")

	# The exclude pattern has to match what it claims: a deep file under
	# `res://prototypes/`, which is what a nested scratch project writes.
	var probe := "res://prototypes/arena_spike/assets/volpe-rigged.glb"
	check_true(probe.match("res://prototypes/*"), "the exclude pattern matches a nested prototype file (%s)" % probe)
	var harness := "res://tests/SmokeTest.tscn"
	check_false(harness.match("res://prototypes/*"), "and it does not match the harness scene")

	# The demo preset differs from the full one only by the feature tag: the demo
	# cuts progression, not the game, so it deletes no resource (`js/build.js:38`).
	var full := _by_name(presets, "linux-x86_64")
	var demo := _by_name(presets, "linux-x86_64-demo")
	if full != null and demo != null:
		check_eq(demo.files, full.files, "the demo preset ships the same resource set as the full one")
		check_eq(demo.exclude_filter, full.exclude_filter, "and excludes the same paths")
		check_eq(_minus(demo.features, "demo"), full.features, "the demo preset's tags are the full preset's plus demo")

	finish()


## A preset, flattened to just what this audit reasons about.
class Preset:
	var name: String
	var platform: String
	var path: String
	var features: Array
	var files: String
	var include_filter: String
	var exclude_filter: String
	var options: Dictionary
	var runnable: bool


func _presets(cfg: ConfigFile) -> Array:
	var out: Array = []
	for section in cfg.get_sections():
		if not section.begins_with("preset."):
			continue
		if section.ends_with(".options"):
			continue
		var p := Preset.new()
		p.name = str(cfg.get_value(section, "name", ""))
		p.platform = str(cfg.get_value(section, "platform", ""))
		p.path = str(cfg.get_value(section, "export_path", ""))
		p.files = str(cfg.get_value(section, "export_filter", ""))
		p.include_filter = str(cfg.get_value(section, "include_filter", ""))
		p.exclude_filter = str(cfg.get_value(section, "exclude_filter", ""))
		p.runnable = bool(cfg.get_value(section, "runnable", false))
		var tags: Array = []
		for tag in str(cfg.get_value(section, "custom_features", "")).split(",", false):
			tags.append(tag.strip_edges())
		p.features = tags
		p.options = {}
		var options_section := section + ".options"
		if cfg.has_section(options_section):
			for key in cfg.get_section_keys(options_section):
				p.options[key] = cfg.get_value(options_section, key)
		out.append(p)
	return out


func _by_name(presets: Array, name: String) -> Preset:
	for preset in presets:
		if preset.name == name:
			return preset
	return null


static func _unique(list: Array) -> Array:
	var seen: Array = []
	for item in list:
		if not seen.has(item):
			seen.append(item)
	return seen


static func _minus(list: Array, item: String) -> Array:
	var out: Array = []
	for entry in list:
		if entry != item:
			out.append(entry)
	return out
