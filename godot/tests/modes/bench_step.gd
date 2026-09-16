## bench_step.gd — cost probe for the modes lane.
##
## Not an audit: the runner (`godot/tests/modes/run_all.gd`) does not list it, and
## it asserts nothing. It exists so the price of the drill/career tests is
## measured on this host instead of guessed: the drill audit steps the real
## simulation engine up to 2400 times per exercise, so a step that costs 500 µs
## would put a single audit at three quarters of an hour.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/modes/bench_step.gd -- 20000
##
## Prints `# bench steps=<n> elapsed_ms=<ms> us_per_step=<x>`.
extends SceneTree

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Support := preload("res://src/audits/audit_support.gd")


func _initialize() -> void:
	var steps := 20000
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			steps = int(arg)
	var athlete: Dictionary = Frozen.athletes()[0]
	var state := Sim.create_match_state("drill", athlete, Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.running = true
	state.serving = false
	state.pointPause = 0.0
	state.scoring = "points"
	state.pointsToWin = 0x7FFFFFFFFFFFFFFF
	state.lastHitterSide = "ai"
	var input: Dictionary = Support.vuoto()
	var start := Time.get_ticks_usec()
	for i in range(steps):
		Sim.update_match(state, 1.0 / 120.0, input)
	var elapsed := Time.get_ticks_usec() - start
	print("# bench steps=%d elapsed_ms=%.1f us_per_step=%.1f" % [
		steps, elapsed / 1000.0, float(elapsed) / float(steps),
	])
	quit(0)
