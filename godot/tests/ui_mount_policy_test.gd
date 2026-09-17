extends SceneTree
## ui_mount_policy_test.gd — architecture-deepening gate 4: CLOCK OWNERSHIP and the
## SHIPPING UI MOUNT are independent facts.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui_mount_policy_test.gd
##
## WHAT WAS WRONG. `match_controller.gd` decided the UI with
## `if _ui_new and engine_driven:` — one condition for two questions, so every
## harness that owned the clock (`harness_mode()` turns `engine_driven` off, and the
## slice calls it before the tree) silently skipped the mount and exercised the
## RETIRED ported column instead of the UI that ships. A clock is not a UI mode.
##
## WHAT THIS PROVES.
##   1. the source states the two facts separately: the recreated mount is selected
##      by the UI mode alone, the ported column is built only behind the explicit
##      legacy request, the engine-clock guard still exists, and every legacy-HUD
##      refresh is null-guarded (so a run without that column cannot touch it);
##   2. the REAL Match scene, driven by a harness clock (`harness_mode()` before the
##      tree — the slice's own order), mounts the shipping recreated UI: `UiHud`,
##      `PauseOverlay`, `TouchControls`, `ReplayOverlay` — and NOT the hidden
##      ported column;
##   3. that mount is live, not inert: the mounted HUD's PUBLIC `report()` carries
##      the sim's own scores and events after ticks driven through the production
##      `tick_fixed()` path, still carries them after a frame driven through the
##      production `apply_frame()` path, and ESC — the production input path —
##      opens and closes the mounted pause card;
##   4. the explicit legacy request still builds and drives the ported column
##      (`ui_legacy` before the tree, the switch `main_menu.gd` documents).
##
## It reads no private variable of the controller (`_ui_hud`, `_paused`, `_bridge`)
## and never mounts a HUD of its own: every UI fact below comes from the scene tree
## the controller built, or from the mounted surface's own public report.
##
## Output contract: one `ok <name>` / `FAIL <name>: expected <x>, got <y>` line per
## check, then one `PASS <n>/<n>` or `FAIL <n>/<n>`. Exit 0 on PASS, 1 on FAIL.

const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const Sim := preload("res://src/sim/sim.gd")

const MATCH_SCENE := preload("res://game/Match.tscn")
const CONTROLLER_PATH := "res://game/match_controller.gd"
const HUD_LAYER := "HudLayer"

## The old combined condition, verbatim: clock ownership AND UI selection in one
## test. The whole gate is its removal.
const COMBINED_CONDITION := "_ui_new and engine_driven"
## The recreated mount's own guard (one tab: `_build_scene`'s body).
const MOUNT_GUARD := "\tif _ui_new:"
## The explicit legacy request's guard.
const LEGACY_GUARD := "if not _ui_new:"
## The ported column's constructor — the thing the recreated path must not run.
const LEGACY_HUD_BUILD := "HudScript.new()"
## The construction itself: the uses that build the column (its name, its
## bind_names call) sit right after this assignment and need no null guard.
const LEGACY_HUD_ASSIGN := "_hud = HudScript.new()"
## How many lines after the assignment still count as "building it".
const LEGACY_BUILD_WINDOW := 4
## The engine clock's own guard, in `_process`. Removing it would be a different
## defect (the frame clock is the shipping clock).
const CLOCK_GUARD := "if not engine_driven:"
## A legacy-HUD use is safe only behind its null guard: a recreated run leaves
## `_hud` null and every call site must tolerate that.
const LEGACY_USE := "_hud."
const LEGACY_NULL_GUARD := "_hud != null"
## How far back a legacy use's null guard may sit (the guards are one-liners).
const GUARD_LOOKBACK := 3

## The four mounts the recreated path owns, in the shipping build.
const RECREATED_MOUNTS := ["UiHud", "PauseOverlay", "TouchControls", "ReplayOverlay"]
## The retired column, under the name the ported mount has always used.
const LEGACY_MOUNT := "Hud"
## Ticks driven through `tick_fixed` before the report is read: a multiple of the
## harness refresh cadence (`ticks % 30 == 0`), so the last refresh saw the last tick.
const DRIVEN_TICKS := 60

const TICK := 1.0 / 120.0

var _checks: int = 0
var _failures: int = 0
var _bot = ScriptedPlayer.new()


func _initialize() -> void:
	await _run()
	quit(1 if _failures > 0 else 0)


func _run() -> void:
	print("ui mount policy test — clock ownership is not a UI mode")
	print("  controller %s" % CONTROLLER_PATH)
	print("")
	_source_contract()
	# The loop has to be running before the scene is added: a node added from
	# `_initialize()` gets its `_ready()` deferred to the first frame, and `_ready`
	# is where the mount happens.
	await process_frame
	await _harness_clock_mounts_the_shipping_ui()
	await _legacy_mode_is_explicit_and_alive()
	_report_tally()


# ---------------------------------------------------------------------------
# 1. The source: two facts, two conditions
# ---------------------------------------------------------------------------

func _source_contract() -> void:
	var source := _text(CONTROLLER_PATH)
	_check("the controller source is readable", source != "", CONTROLLER_PATH)
	if source == "":
		return
	var lines := source.split("\n")

	_check("the recreated mount is selected by the UI mode alone (no clock in the condition)",
		not source.contains(COMBINED_CONDITION) and source.contains(MOUNT_GUARD),
		"!%s && %s" % [COMBINED_CONDITION, MOUNT_GUARD.strip_edges()])
	_check("the ported column is built only behind the explicit legacy request",
		_count_ident(source, LEGACY_HUD_BUILD) == 1
			and _guarded_by(lines, LEGACY_HUD_ASSIGN, LEGACY_GUARD),
		"%s x%d" % [LEGACY_HUD_BUILD, _count_ident(source, LEGACY_HUD_BUILD)])
	_check("the engine clock keeps its own guard (the frame clock is unchanged)",
		source.contains(CLOCK_GUARD), CLOCK_GUARD.strip_edges())

	# Every use of the ported column tolerates its absence: without this a recreated
	# run (which no longer builds it) would crash on the first refresh.
	var unguarded: Array[String] = []
	for i in lines.size():
		var line: String = lines[i]
		if not _touches_legacy_hud(line):
			continue
		var guarded := false
		for back in range(GUARD_LOOKBACK + 1):
			var at := i - back
			if at >= 0 and String(lines[at]).contains(LEGACY_NULL_GUARD):
				guarded = true
				break
		if _builds_legacy_hud(lines, i):
			guarded = true
		if not guarded:
			unguarded.append("line %d: %s" % [i + 1, line.strip_edges()])
	_check("every ported-column use is behind its null guard", unguarded.is_empty(), str(unguarded))


## True when line `index` is part of the ported column's own construction (a
## `_hud = HudScript.new()` assignment shortly above): building a thing and then
## naming it needs no null guard.
func _builds_legacy_hud(lines: PackedStringArray, index: int) -> bool:
	for back in range(1, LEGACY_BUILD_WINDOW + 1):
		var at := index - back
		if at < 0:
			return false
		if String(lines[at]).contains(LEGACY_HUD_ASSIGN):
			return true
	return false


## Occurrences of `needle` that are not the tail of a longer identifier: the ported
## column's script is `HudScript`, and `ModeHudScript.new()` contains exactly that
## text without being it.
func _count_ident(source: String, needle: String) -> int:
	var count := 0
	var at := source.find(needle)
	while at != -1:
		if at == 0 or not _is_ident_char(source[at - 1]):
			count += 1
		at = source.find(needle, at + 1)
	return count


## True when the line USES `_hud` (the ported column) — and not `_mode_hud`, which
## is the mode session's own panel and stays in every run.
func _touches_legacy_hud(line: String) -> bool:
	var at := line.find(LEGACY_USE)
	while at != -1:
		# The match is a bare `_hud.`, never the tail of `_mode_hud.`/`_ui_hud.`.
		if at == 0 or not _is_ident_char(line[at - 1]):
			if not line.contains(LEGACY_NULL_GUARD):
				return true
		at = line.find(LEGACY_USE, at + 1)
	return false


func _is_ident_char(c: String) -> bool:
	return c == "_" or c.to_lower() != c.to_upper() or c.is_valid_int()


## True when the nearest preceding `if`/`elif` above `needle` mentions `guard`.
func _guarded_by(lines: PackedStringArray, needle: String, guard: String) -> bool:
	for i in lines.size():
		if not String(lines[i]).contains(needle):
			continue
		var at := i - 1
		while at >= 0:
			var above := String(lines[at]).strip_edges()
			if above.begins_with("if ") or above.begins_with("elif "):
				return above.contains(guard)
			at -= 1
	return false


# ---------------------------------------------------------------------------
# 2. A harness-driven match mounts and exercises the shipping UI
# ---------------------------------------------------------------------------

func _harness_clock_mounts_the_shipping_ui() -> void:
	var node := _new_match(false)
	# The clock question and the UI question, asked separately.
	_check("the harness owns the clock in this run",
		not bool(node.engine_driven), "engine_driven=false")
	_check("the shipping recreated HUD is mounted while the harness owns the clock",
		_layer_node(node, RECREATED_MOUNTS[0]) != null, "HudLayer/%s" % RECREATED_MOUNTS[0])
	var missing: Array[String] = []
	for name in RECREATED_MOUNTS:
		if _layer_node(node, String(name)) == null:
			missing.append(String(name))
	_check("the whole recreated stack is mounted (HUD, pause card, touch layer, replay chrome)",
		missing.is_empty(), str(missing))
	_check("no hidden ported column is built behind the recreated UI",
		_layer_node(node, LEGACY_MOUNT) == null, "HudLayer/%s" % LEGACY_MOUNT)

	# The production tick path, then the mounted surface's own report.
	_tick(node, DRIVEN_TICKS)
	var hud := _layer_node(node, RECREATED_MOUNTS[0])
	if hud == null:
		_drop(node)
		return
	var report: Dictionary = hud.call("report")
	var view: Dictionary = report.get("view", {})
	_check("the mounted HUD has been fed by the production refresh path (its view is not empty)",
		not view.is_empty(), "view keys=%d" % view.size())
	var texts: Dictionary = report.get("texts", {})
	_check_eq("the mounted HUD shows the sim's own player score",
		String(texts.get("player_score", "")), String(node.state.playerScore))
	_check_eq("the mounted HUD shows the sim's own ai score",
		String(texts.get("ai_score", "")), String(node.state.aiScore))
	_check("the mounted HUD renders the sim's own events",
		not (view.get("log_lines", []) as Array).is_empty(), str(view.get("log_lines", [])))

	# The frame path the engine clock uses feeds the same mount.
	var before_score := String(node.state.playerScore)
	node.apply_frame(_bot.decide(node.state), TICK)
	_check_eq("the score a frame path sees is the same one the harness path sees",
		String(node.state.playerScore), before_score)
	var after: Dictionary = (hud.call("report") as Dictionary).get("texts", {})
	_check_eq("a frame through the production frame path keeps the mount on the sim's state",
		String(after.get("player_score", "")), String(node.state.playerScore))

	# The pause seam through the input path a player uses, read from the card itself.
	var card := _layer_node(node, "PauseOverlay")
	_check("the mounted pause card starts closed",
		card != null and not bool(card.call("is_open")), "is_open")
	if card != null:
		node.call("_unhandled_input", _action_event("padel_pause"))
		_check("ESC on a running harness match opens the mounted card",
			bool(card.call("is_open")), "is_open")
		node.call("_unhandled_input", _action_event("padel_pause"))
		_check("a second ESC closes it again (the card's own hierarchy)",
			not bool(card.call("is_open")), "is_open")
	_drop(node)


# ---------------------------------------------------------------------------
# 3. The legacy request is explicit — and the column still works
# ---------------------------------------------------------------------------

func _legacy_mode_is_explicit_and_alive() -> void:
	var node := _new_match(true)
	_check("the explicit legacy request builds the ported column",
		_layer_node(node, LEGACY_MOUNT) != null, "HudLayer/%s" % LEGACY_MOUNT)
	_check("and mounts no recreated HUD in its place",
		_layer_node(node, RECREATED_MOUNTS[0]) == null, "HudLayer/%s" % RECREATED_MOUNTS[0])
	_tick(node, DRIVEN_TICKS)
	var panels: Array[String] = []
	for name in ["ScorePanel", "DebugPanel", "LogPanel", "FeedbackPanel", "HintPanel", "ResultPanel"]:
		if node.get_node_or_null("%s/%s/%s" % [HUD_LAYER, LEGACY_MOUNT, name]) == null:
			panels.append(String(name))
	_check("the ported column still builds its panels (stable scene paths)",
		panels.is_empty(), str(panels))
	node.call("_unhandled_input", _action_event("padel_pause"))
	_check("ESC still pauses the ported path", bool(node.call("is_paused")), "is_paused")
	_drop(node)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A real Match scene, the way the harnesses build one: `harness_mode()` before the
## tree (the slice's own order) so the harness owns the clock. `legacy` sets the
## explicit ported-column request before `_ready()`, the switch `main_menu.gd`
## documents — never through the command line.
func _new_match(legacy: bool) -> Node:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 0
	var node: Node = MATCH_SCENE.instantiate()
	if legacy:
		node.set("ui_legacy", true)
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	return node


func _tick(node: Node, ticks: int) -> void:
	for _i in ticks:
		node.tick_fixed(TICK, _bot.decide(node.state), Sim.empty_input())


func _layer_node(node: Node, name: String) -> Node:
	return node.get_node_or_null("%s/%s" % [HUD_LAYER, name])


func _drop(node: Node) -> void:
	root.remove_child(node)
	node.free()


func _action_event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _check(name: String, condition: bool, got: Variant = "") -> void:
	_checks += 1
	if condition:
		print("ok %s" % name)
		return
	_failures += 1
	print("FAIL %s: expected true, got %s" % [name, str(got)])


func _check_eq(name: String, actual: Variant, expected: Variant) -> void:
	_checks += 1
	if actual == expected:
		print("ok %s" % name)
		return
	_failures += 1
	print("FAIL %s: expected %s, got %s" % [name, str(expected), str(actual)])


func _report_tally() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
