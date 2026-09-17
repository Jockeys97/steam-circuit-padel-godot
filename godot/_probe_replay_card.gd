## _probe_replay_card.gd — the wired pause-card entry, executed. Finalize closure,
## integration owner, 2026-09-17, local only.
##
## WHAT IT PROVES, and why the audits do not already: `replay_audit.gd` drives a
## STANDALONE `PauseOverlay` and a harness node whose UIR chrome is not mounted
## (`harness_mode()` runs before `add_child`, so `_ready`'s mount block
## (`if _ui_new and engine_driven:`) is skipped); `uir_route_audit.gd` boots the real
## mount but never touches replay. The WIRE between them — the controller's
## availability feed onto the MOUNTED card and the mounted card's `replay_requested`
## signal back into `start_replay()` — is asserted here, on the real node.
##
## Boot: Match.tscn instantiated and added AFTER the tree is already iterating (the
## probe's own warm-up frames) and BEFORE `harness_mode()`, so `_ready` runs on
## `add_child` with `engine_driven` still true and mounts the UIR chrome — the order
## and the timing `uir_route_audit.gd` creates its nodes with (a node added from
## `_initialize()`, before the first iteration, gets its `_ready` deferred to the
## first frame — after `harness_mode()`, which is why that order is load-bearing);
## the harness then hands the ticks to this probe (`tick_fixed`, the same step
## `replay_audit.gd` uses) and never runs the engine's own loop.
##
## THIS PROBE WRITES ONLY TO ITS OWN TEMP DIR (`user://uir-finalize-probe`) and wipes
## it at the end; the real `user://save` is never touched. It lives at the project
## root (`res://_probe_replay_card.gd`) — outside the sweep's hashed trees
## (`godot/game`, `godot/src`, `godot/tests`) — and is preserved at
## `docs/implementation/ui-recreation/evidence/uir-finalize/scripts/`.
##
## Command: "$GODOT" --headless --path godot/ --script res://_probe_replay_card.gd
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Sim := preload("res://src/sim/sim.gd")
const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const TEMP_DIR := "user://uir-finalize-probe"
const TICK := 1.0 / 120.0
const RECORD_TICKS := 150

var _bot: RefCounted


func _initialize() -> void:
	var audit := AuditBase.new("probe_replay_card")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	Config.save_dir = TEMP_DIR
	_bot = ScriptedPlayer.new()
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 2

	# The tree must be iterating before the node is created: a node added from
	# `_initialize()` (before the first iteration) gets its `_ready` deferred to the
	# first frame, which would run AFTER `harness_mode()` and skip the mount.
	for _i in 3:
		await process_frame

	# The game's boot order: add first (the mount runs in `_ready`, now on
	# `add_child`), THEN hand the clock to the harness.
	var node: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(node)
	node.harness_mode()
	node.start_match()
	for _i in 3:
		await process_frame

	var card: Node = node.get_node_or_null("HudLayer/PauseOverlay")
	audit.check_true(card != null, "probe/the_real_card_is_mounted")
	if card == null:
		return
	var button: Button = card.find_child("ReplayButton", true, false)
	audit.check_true(button != null, "probe/the_real_entry_button_is_there")
	audit.check_eq(bool(card.call("is_open")), false, "probe/the_card_starts_closed")
	audit.check_eq(bool(card.call("replay_enabled")), false, "probe/the_entry_is_gated_off_before_any_frames")
	audit.check_eq(String(card.call("replay_disabled_reason")), "uir27-replay-entry-not-landed", "probe/the_gate_names_the_landing")

	# Record: the same fixed steps `replay_audit` uses to pass the two-frame gate.
	for _i in RECORD_TICKS:
		node.tick_fixed(TICK, _bot.decide(node.state), Sim.empty_input())
	audit.check_ge(node.state.replayFrames.size(), 2, "probe/frames_are_recorded")

	# The pause edge: the controller's echo opens the card and the availability feed
	# turns the real button on.
	audit.check_eq(node.set_match_paused(true), true, "probe/the_match_pauses")
	await process_frame
	audit.check_eq(bool(card.call("is_open")), true, "probe/the_echo_opens_the_card")
	audit.check_eq(bool(card.call("replay_enabled")), true, "probe/the_availability_feed_reaches_the_card")
	audit.check_eq(String(card.call("replay_disabled_reason")), "", "probe/an_enabled_entry_carries_no_reason")
	audit.check_eq(button.disabled, false, "probe/the_real_button_is_not_disabled")

	# The entry, through the button's own signal: `pressed` -> `replay()` ->
	# `replay_requested` -> the controller's handler -> `start_replay()`
	# (`js/main.js:2238-2241`: hide the card, then toggle the playback).
	button.pressed.emit()
	await process_frame
	audit.check_eq(node.replay_active(), true, "probe/the_button_press_starts_the_replay")
	audit.check_eq(node.is_paused(), false, "probe/entering_lifts_the_pause")
	audit.check_eq(bool(card.call("is_open")), false, "probe/the_card_hides_on_entry")

	# The way out: the recorded pause comes back and the card reopens on MATCH.
	node.stop_replay()
	await process_frame
	audit.check_eq(node.is_paused(), true, "probe/stopping_restores_the_pause")
	audit.check_eq(node.replay_active(), false, "probe/the_playback_ends")
	audit.check_eq(bool(card.call("is_open")), true, "probe/the_card_reopens_after_stop")
	audit.check_eq(bool(card.call("replay_enabled")), true, "probe/a_second_replay_is_startable")
	audit.report("wired entry: button -> signal -> start_replay -> stop_replay, all on the mounted card")
	_drop(node)


func _drop(node: Node) -> void:
	if node != null and node.get_parent() != null:
		root.remove_child(node)
		node.free()


func _wipe() -> void:
	var abs := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for file in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(file))
	for dir in DirAccess.get_directories_at(abs):
		DirAccess.remove_absolute(abs.path_join(dir))
	DirAccess.remove_absolute(abs)
