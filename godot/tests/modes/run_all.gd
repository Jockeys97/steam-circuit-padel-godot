## run_all.gd — the runner for the ported game-modes audits.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 1800 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ \
##     --script res://tests/modes/run_all.gd
##
## One `ok`/`FAIL` line group per audit, one per-audit summary line, then a single
## combined `PASS <audits>/<audits>` (or `FAIL`) and exit 0/1 — the same contract
## as `godot/tests/audits/run_all.gd`. The individual audits are suppressed from
## printing their own `PASS` line in this mode (`AuditBase.quiet`), so exactly one
## `PASS` line ends the log.
##
## Cheapest first, so a red on the small ones shows up in seconds; `drill` is last
## because it steps the simulation engine for about 40 000 ticks.
##
## Every entry is the same file the single-audit invocation runs; nothing here
## re-implements a rule. `bench_step.gd` is deliberately NOT listed: it is a cost
## probe with no assertions, and a probe inside a `PASS n/n` would be a check that
## cannot fail.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")

## `[audit name, script path]`, cheapest first.
const AUDITS := [
	["tournament", "res://tests/modes/tournament_audit.gd"],
	["outfit_challenges", "res://tests/modes/outfit_challenges_audit.gd"],
	["save_progression", "res://tests/modes/save_progression_audit.gd"],
	["reference_grid", "res://tests/modes/reference_grid_audit.gd"],
	["career", "res://tests/modes/career_audit.gd"],
	["drill", "res://tests/modes/drill_audit.gd"],
]

var _checks: int = 0
var _failures: int = 0
var _not_ported: int = 0


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	print("# game-modes audits ported from scripts/{drill,career,tournament,outfit-challenges}-audit.mjs — reference commit 2979588")
	var passed := 0
	var total_checks := 0
	var total_failures := 0
	var started := Time.get_ticks_msec()
	for entry in AUDITS:
		var name: String = entry[0]
		var path: String = entry[1]
		var script: GDScript = load(path)
		if script == null:
			print("FAIL %s: script not loadable (%s)" % [name, path])
			_checks += 1
			_failures += 1
			continue
		var audit := AuditBase.new(name)
		audit.quiet = true
		print("# audit %s (%s)" % [name, path])
		var before := Time.get_ticks_msec()
		script.run(audit)
		var code: int = audit.finish()
		total_checks += audit.checks
		total_failures += audit.failures
		if code == 0:
			passed += 1
			print("ok %s (%d checks, %d ms)" % [name, audit.checks, Time.get_ticks_msec() - before])
		else:
			print("FAIL %s (%d/%d checks, first: %s)" % [name, audit.checks - audit.failures, audit.checks, audit.first_failure])
		if audit.not_ported_count > 0:
			print("# audit %s not-ported=%d" % [name, audit.not_ported_count])
		_not_ported += audit.not_ported_count

	var audits_failed := AUDITS.size() - passed
	_checks += AUDITS.size()
	_failures += audits_failed
	print("# totals checks=%d failures=%d not-ported=%d elapsed_ms=%d" % [total_checks, total_failures, _not_ported, Time.get_ticks_msec() - started])
	if _failures == 0:
		print("PASS %d/%d" % [AUDITS.size(), AUDITS.size()])
		return 0
	print("FAIL %d/%d" % [passed, AUDITS.size()])
	printerr("FAIL %d/%d" % [passed, AUDITS.size()])
	return 1
