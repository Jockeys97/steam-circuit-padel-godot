## _probe_second_player.gd — who drives the second player, measured over a played match.
## AD-HOC VERIFICATION, not a suite. `playerMode` is persisted and applied to a quick
## match; nothing in the suite proves what a stored `coop`/`pvp` does to the partner
## slot when no second controller is attached. This probe drives it.
##
## WHAT IT PROVES. For each human mode it boots one match, plays 20 seconds of it with
## the repo's own scripted player (`game/scripted_player.gd`, which fills the first
## player's 22-field input struct) through the real frame path (`apply_frame`, so the
## second player's sampler is consulted exactly as a played frame would), and measures
## per paddle: frames moved continuously, positional jumps, furthest travel, plus the
## points and rally hits the match produced.
##
## WHY CONTINUOUS FRAMES AND NOT TRAVEL. Travel alone lies here: `reset_paddle_for_serve`
## teleports every paddle, so a paddle that never takes part still "travels". A paddle
## that is actually being driven moves a few pixels a frame; a paddle that is only
## repositioned jumps and then sits still. The probe reports both.
##
## The mechanism it measures: in `solo` the partner is the simulation's own AI
## (`sim.gd::update_doubles_ai` moves the inactive team mate only `if not state.coop`);
## in `coop`/`pvp` the partner is a HUMAN input slot fed by the second sampler, which is
## pad-only (`game/input_map.gd:31-33`; the reference's `getInput2()` reads gamepad 2
## alone, `js/main.js:1096`) — so with no second controller the partner is repositioned
## for the serve and then takes no part. That is the reference's own design: its hint
## reads "Co-op: two controllers on the same team, each drives one player".
##
## Writes only to its own temp dir (`user://probe-second-player`); the real
## `user://save` is never touched. Lives at the project root, outside the sweep's
## hashed trees (`godot/game`, `godot/src`, `godot/tests`).
##
## Command: "$GODOT" --headless --path godot/ --script res://_probe_second_player.gd
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const InputSource := preload("res://game/input_map.gd")
const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const TEMP_DIR := "user://probe-second-player"
## 1200 frames at 1/60 is 20 seconds of played padel: long enough for serves, rallies
## and scored points, so a still paddle is a still paddle rather than a match frozen
## in its serve phase.
const FRAMES := 1200
const DELTA := 1.0 / 60.0
## The four paddles the measurement walks, by their state field names.
const PADDLES: Array[String] = ["player", "playerMate", "opponent", "opponentMate"]
## A frame-to-frame move above this is a repositioning jump, not play: at 60 fps a
## driven paddle covers a few pixels a frame.
const JUMP := 20.0
## A frame-to-frame move under this is noise, not travel.
const STILL := 0.05
## How many continuously-moving frames a paddle the simulation is driving produces in
## 20 seconds. Measured on the first player (430 px of play) and well clear of the
## repositioning-only case.
const PLAYED := 100


func _initialize() -> void:
	var audit := AuditBase.new("probe_second_player")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	Config.save_dir = TEMP_DIR
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 2
	Config.seed_value = 20260916

	# The tree must be iterating before a node is created: a node added from
	# `_initialize()` gets its `_ready` deferred to the first frame.
	for _i in 3:
		await process_frame

	var table := {}
	for mode in ["solo", "coop", "pvp"]:
		table[mode] = await _play_for(audit, String(mode))
	print("# table %s" % JSON.stringify(table))

	# The measurement is only meaningful if the match actually played.
	for mode in ["solo", "coop", "pvp"]:
		audit.check_gt(int(table[mode]["points"]), 0,
			"probe/%s_the_match_scored_points" % mode)
		audit.check_gt(int(table[mode]["player"]["moved"]), PLAYED,
			"probe/%s_the_first_player_is_driven_all_match" % mode)

	# The mechanism, as a measurement rather than a claim: the partner plays in `solo`
	# (the simulation's AI drives it) and does not play in `coop` without a second
	# controller — it is repositioned for the serve, which is why a travel-only metric
	# reads it as movement.
	audit.check_gt(int(table["solo"]["playerMate"]["moved"]), PLAYED,
		"probe/solo_the_partner_is_ai_driven_and_plays")
	audit.check_gt(int(table["solo"]["opponent"]["moved"]) + int(table["solo"]["opponentMate"]["moved"]),
		PLAYED, "probe/solo_the_opponent_pair_is_ai_driven_and_plays")
	audit.check_lt(int(table["coop"]["playerMate"]["moved"]), PLAYED,
		"probe/coop_without_a_second_controller_the_partner_does_not_play")
	audit.check_gt(int(table["coop"]["playerMate"]["jumps"]), 0,
		"probe/coop_the_partner_is_still_moved_by_the_serve_repositioning")
	audit.check_gt(float(table["coop"]["playerMate"]["travel"]), 1.0,
		"probe/coop_a_travel_only_metric_would_read_that_partner_as_moving")

	# And the reason, read from the sampler itself rather than from a comment.
	var node: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(node)
	node.harness_mode()
	node.start_match()
	var state = node.get("state")
	var second := InputSource.new(false)
	var sample: Dictionary = second.sample(state)
	audit.check_eq(second.device, InputSource.NO_DEVICE,
		"probe/the_second_sampler_holds_no_device_without_a_controller")
	audit.check_eq(float(sample.get("moveX", 0.0)), 0.0,
		"probe/the_second_sampler_reads_no_movement_without_a_controller")
	audit.check_true(not bool(sample.get("left", false)) and not bool(sample.get("right", false)),
		"probe/the_second_sampler_reads_no_direction_without_a_controller")
	if node.get_parent() != null:
		root.remove_child(node)
	node.free()


## Boots one match in `mode` and plays it with the scripted first player for `FRAMES`
## frames through `apply_frame`, reporting per paddle how many frames it moved
## continuously, how many repositioning jumps it took, how far it travelled, and what
## the match produced (points, longest rally). A fresh node and a fresh bot per mode.
func _play_for(audit: AuditBase, mode: String) -> Dictionary:
	Config.pending_player_mode = mode
	var node: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(node)
	node.harness_mode()
	node.start_match()
	var state = node.get("state")
	var bot := ScriptedPlayer.new()
	var start := {}
	var last := {}
	var travel := {}
	var moved := {}
	var jumps := {}
	for key in PADDLES:
		start[key] = Vector2(float(state.get(key).x), float(state.get(key).y))
		last[key] = start[key]
		travel[key] = 0.0
		moved[key] = 0
		jumps[key] = 0
	for _i in FRAMES:
		node.apply_frame(bot.decide(state), DELTA)
		for key in PADDLES:
			var here := Vector2(float(state.get(key).x), float(state.get(key).y))
			var step := here.distance_to(last[key])
			if step >= JUMP:
				jumps[key] = int(jumps[key]) + 1
			elif step > STILL:
				moved[key] = int(moved[key]) + 1
			last[key] = here
			travel[key] = maxf(float(travel[key]), here.distance_to(start[key]))
	var stats: Dictionary = state.stats
	audit.check_eq(String(state.humanMode), mode,
		"probe/%s_the_match_runs_the_stored_human_mode" % mode)
	var report := {}
	for key in PADDLES:
		report[key] = {
			"moved": moved[key], "jumps": jumps[key],
			"travel": travel[key],
		}
	report["points"] = int(stats["pointsWon"]["player"]) + int(stats["pointsWon"]["ai"])
	report["longestRally"] = int(stats["longestRally"])
	audit.report("%s: %s" % [mode, JSON.stringify(report)])
	if node.get_parent() != null:
		root.remove_child(node)
	node.free()
	return report


func _wipe() -> void:
	var abs := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for file in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(file))
	for dir in DirAccess.get_directories_at(abs):
		DirAccess.remove_absolute(abs.path_join(dir))
	DirAccess.remove_absolute(abs)
