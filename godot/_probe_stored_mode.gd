## _probe_stored_mode.gd — does the stored profile produce a partner who plays?
## AD-HOC VERIFICATION, not a suite. Reads the REAL save (`user://save/prefs.json`, no
## redirect) the way the arena screen does, boots a quick match with the mode that
## profile resolves to, and measures whether the partner is driven for the whole match.
##
## The chain under test: `ArenaScreen.gd:509` sets `Config.pending_player_mode` to the
## stored `playerMode` for a quick match (`ArenaScreen.gd:515 player_mode()` reads
## `ModesSave.profile(Config.save_store())["prefs"]["playerMode"]`); the controller maps
## that to `state.humanMode`; `sim.gd::update_doubles_ai:2457` drives the partner with the
## AI only `if not state.coop`. A profile in `coop` with no second controller therefore
## yields a partner that is repositioned for each serve and never plays.
##
## Command: "$GODOT" --headless --path godot/ --script res://_probe_stored_mode.gd
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Config := preload("res://game/match_config.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const FRAMES := 900
const DELTA := 1.0 / 60.0
## Frames of continuous movement a paddle the simulation drives produces in 15 seconds.
const PLAYED := 100


func _initialize() -> void:
	var audit := AuditBase.new("probe_stored_mode")
	for _i in 3:
		await process_frame
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	# The real store, exactly as the arena screen reads it. No `save_dir` override.
	var prefs: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
	var stored := String(prefs.get("playerMode", ""))
	audit.report("stored playerMode=%s (pacePreset=%s, mode=%s)"
		% [stored, String(prefs.get("pacePreset", "")), String(prefs.get("mode", ""))])
	audit.check_true(stored != "", "probe/the_stored_profile_resolves_a_player_mode")

	# What a quick match started from the arena screen would use.
	var pending := stored if String(prefs.get("mode", "quick")) == "quick" else "solo"
	Config.pending_mode = "quick"
	Config.pending_player_mode = pending
	Config.pending_round = -1
	Config.tier_index = 2
	Config.seed_value = 20260916

	var node: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(node)
	node.harness_mode()
	node.start_match()
	var state = node.get("state")
	audit.report("match humanMode=%s" % String(state.humanMode))
	audit.check_eq(String(state.humanMode), pending,
		"probe/a_quick_match_uses_the_stored_player_mode")

	var bot := ScriptedPlayer.new()
	var start := Vector2(float(state.playerMate.x), float(state.playerMate.y))
	var last := start
	var mate_moved := 0
	for _i in FRAMES:
		node.apply_frame(bot.decide(state), DELTA)
		var here := Vector2(float(state.playerMate.x), float(state.playerMate.y))
		var step := here.distance_to(last)
		if step > 0.05 and step < 20.0:
			mate_moved += 1
		last = here
	audit.report("partner moved for %d of %d frames, travel %.1f px, rally %d"
		% [mate_moved, FRAMES, here_distance(start, last, state), int(state.stats["longestRally"])])
	audit.check_gt(mate_moved, PLAYED,
		"probe/the_partner_is_driven_for_the_whole_match")
	if node.get_parent() != null:
		root.remove_child(node)
	node.free()


func here_distance(start: Vector2, last: Vector2, state) -> float:
	return last.distance_to(start)
