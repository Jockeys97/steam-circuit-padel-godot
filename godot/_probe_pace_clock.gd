## _probe_pace_clock.gd — the game-pace presets, measured on the real clock.
## AD-HOC VERIFICATION, not a suite. `tests/pace_presets_test.gd` proves the TABLE;
## nothing in the suite proves the table reaches the simulation's clock, because
## `advance_frame` is the only place real frame time becomes simulated time and no
## audit drives it. This probe drives it.
##
## WHAT IT PROVES. For a fixed span of real frames, the number of whole `FIXED_STEP`
## ticks the controller runs is proportional to the selected preset's factor, and at
## the default preset it is exactly the count the build ran before this feature
## existed. The simulation's own step is untouched either way: every call is still a
## whole `1/120` tick, which is why `tests/audits/court_speed_audit.gd` still passes
## 25/25 and why every balance ratio survives by construction.
##
## Writes only to its own temp dir (`user://pace-probe`); the real `user://save` is
## never touched. Lives at the project root, outside the sweep's hashed trees
## (`godot/game`, `godot/src`, `godot/tests`).
##
## Command: "$GODOT" --headless --path godot/ --script res://_probe_pace_clock.gd
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Sim := preload("res://src/sim/sim.gd")
const Config := preload("res://game/match_config.gd")
const Pace := preload("res://src/sim/pace.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const TEMP_DIR := "user://pace-probe"
## 60 frames at 1/60 equals exactly 120 ticks at factor 1.0, so the expectations
## below are exact integers rather than a tolerance around a measurement.
const FRAMES := 60
const DELTA := 1.0 / 60.0
const TICKS_AT_ONE := 120


func _initialize() -> void:
	var audit := AuditBase.new("probe_pace_clock")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	Config.save_dir = TEMP_DIR
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 2

	# The tree must be iterating before the node is created: a node added from
	# `_initialize()` gets its `_ready` deferred to the first frame.
	for _i in 3:
		await process_frame

	var measured := {}
	for id in Pace.ids():
		measured[String(id)] = await _ticks_for(audit, String(id))

	# The headline: the clock's rate follows the factor.
	for id in Pace.ids():
		var key := String(id)
		var expected := int(round(float(TICKS_AT_ONE) * Pace.factor_for(key)))
		var got := int(measured[key])
		audit.check_between(got, expected - 2, expected + 2,
			"probe/%s_advances_%d_ticks_in_%d_frames" % [key, expected, FRAMES])

	# No silent retune: the default rung is the tuning the build already had.
	audit.check_eq(int(measured[Pace.default_id()]), TICKS_AT_ONE,
		"probe/the_default_preset_reproduces_the_pre_change_clock")

	# The ladder, as a rate rather than a label.
	audit.check_gt(int(measured["realistic"]), int(measured["brisk"]),
		"probe/realistic_runs_the_clock_faster_than_the_default")
	audit.check_lt(int(measured["learning"]), int(measured["standard"]),
		"probe/learning_runs_the_clock_slower_than_standard")
	var ratio := float(measured["realistic"]) / maxf(1.0, float(measured["brisk"]))
	audit.check_between(ratio, 1.45, 1.55, "probe/realistic_is_one_and_a_half_times_the_default")
	audit.report("ticks over %d frames: %s" % [FRAMES, JSON.stringify(measured)])

	# A save from a build that never had the key, and a save holding an id this
	# build does not know: both must read back as the default rather than stopping
	# the clock or speeding it up.
	var store := Config.save_store()
	ModesSave.save_pref(store, "pacePreset", "no_such_pace")
	audit.check_eq(Config.pace_id(), Pace.default_id(),
		"probe/an_unknown_stored_id_reads_back_as_the_default")
	audit.check_eq(Config.pace_factor(), 1.0,
		"probe/an_unknown_stored_id_keeps_the_unscaled_clock")


## Boots one match, picks `id`, and counts the whole ticks one span of real frames
## buys. A fresh node per preset, so no accumulator carries over between presets.
func _ticks_for(audit: AuditBase, id: String) -> int:
	ModesSave.save_pref(Config.save_store(), "pacePreset", id)
	var node: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(node)
	node.harness_mode()
	node.start_match()
	audit.check_eq(Config.pace_factor(), Pace.factor_for(id),
		"probe/%s_the_match_picked_up_its_factor" % id)
	var ticks := 0
	for _i in FRAMES:
		var step: Dictionary = node.advance_frame(DELTA)
		ticks += int(step.get("steps", 0))
	if node.get_parent() != null:
		root.remove_child(node)
	node.free()
	return ticks


func _wipe() -> void:
	var abs := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for file in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(file))
	for dir in DirAccess.get_directories_at(abs):
		DirAccess.remove_absolute(abs.path_join(dir))
	DirAccess.remove_absolute(abs)
