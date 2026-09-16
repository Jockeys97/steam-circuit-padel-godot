extends Node
## Headless smoke test for the Godot harness.
##
##   godot --headless --path godot/
##   godot --headless --path godot/ -- --inject-failure   (proves the failure signal)
##
## Contract for CI: every check prints one machine-readable line to stdout
##   ok <name>
##   FAIL <name>: expected <x>, got <y>
## and the run ends with a single line
##   PASS <n>/<n>
## or
##   FAIL <n>/<n>   (failure detail also on stderr)
## The process exits 0 on PASS and 1 on FAIL, so a runner needs no output parser.
##
## Caveat CI must cover: if a script error aborts _ready() before quit() is
## reached, this main loop keeps running and the process never exits — a hung
## job, not a red job. Wrap the command in `timeout` (or `--quit-after`).
## Observed on 2026-09-16; see docs/wayfinder/evidence/godot-harness-smoke.log.

var _checks: int = 0
var _failures: int = 0
var _inject_failure: bool = false


func _ready() -> void:
	_inject_failure = "--inject-failure" in OS.get_cmdline_user_args()

	# The version assertions double as the engine pin: if the binary on the
	# runner is not the one this harness was verified against, the run goes red.
	var info: Dictionary = Engine.get_version_info()
	print("# Engine.get_version_info() = %s" % [info])
	check_eq(info.get("major", 0), 4, "engine major version")
	check_eq(info.get("minor", 0), 7, "engine minor version")
	check_eq(info.get("patch", 0), 2, "engine patch version")
	check_eq(info.get("status", ""), "stable", "engine channel is stable")
	check_eq(info.get("string", ""), "4.7.2-stable (official)", "engine version string")
	# Full build hash, not the short one: this is the pin. It matches the
	# "built from commit" line in the official 4.7.2 release notes.
	check_eq(
		info.get("hash", ""),
		"ed1daf0bf001b61586d9930840f2f1394092c079",
		"engine build commit"
	)

	check_eq(Engine.physics_ticks_per_second, 120, "physics tick is 120 Hz")

	# Why the port must count integer ticks instead of accumulating 1/120 s:
	# summed as floats, 1 s at 120 Hz needs 121 steps, so a float accumulator
	# drifts out of phase with the web build. Measured, not assumed.
	var elapsed: float = 0.0
	var steps: int = 0
	while elapsed < 1.0:
		elapsed += 1.0 / 120.0
		steps += 1
	check_eq(steps, 121, "float accumulator overshoots 120 steps (count integer ticks)")

	if _inject_failure:
		check_eq(1, 2, "injected failure (deliberate, proves the exit code)")

	# Deliberate runtime error *inside* _ready: aborts the callback before quit()
	# is ever reached, so the headless main loop never stops and the process has
	# to be killed. This is the failure mode `timeout` exists to convert into a
	# red job. Dynamic call so it is a runtime error, not a parse error.
	if "--inject-abort" in OS.get_cmdline_user_args():
		var engine: Variant = Engine
		engine.this_method_does_not_exist()

	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		get_tree().quit(0)
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
		get_tree().quit(1)


func check_eq(actual: Variant, expected: Variant, name: String) -> void:
	_checks += 1
	if actual == expected:
		print("ok %s" % name)
		return
	_failures += 1
	var line := "FAIL %s: expected %s, got %s" % [name, expected, actual]
	print(line)
	printerr(line)
