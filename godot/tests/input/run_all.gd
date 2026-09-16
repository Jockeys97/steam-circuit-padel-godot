## run_all.gd — the four input/accessibility audits, one log, one verdict.
##
##   cd /root/projects/steam-circuit-padel-pro && \
##   flock -w 900 /tmp/padel-godot.lock timeout 600 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/input/run_all.gd
##
## Cheapest first, so a red is visible in seconds. Each entry is the same script
## the single-audit invocation runs — nothing here re-implements a rule — and the
## per-audit `PASS`/`FAIL` summary is suppressed (`AuditBase.quiet`) so exactly one
## `PASS <n>/<n>` line ends the log, the same contract as
## `godot/tests/audits/run_all.gd`.
##
## The input-inventory lines each audit prints (`# input-inventory …`) pass through
## untouched: the log is the evidence, and a parser reads it from here.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")

## `[audit name, script path]`, cheapest first.
const AUDITS := [
	["reachability", "res://tests/input/reachability_audit.gd"],
	["input_coverage", "res://tests/input/input_coverage_audit.gd"],
	["gamepad_nav", "res://tests/input/gamepad_nav_audit.gd"],
	["input_remap_a11y", "res://tests/input/input_remap_a11y_audit.gd"],
]

var _checks: int = 0
var _failures: int = 0
var _not_ported: int = 0


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	print("# input/accessibility audits ported from scripts/*.mjs — reference commit 2979588")

	var passed := 0
	var total_checks := 0
	var total_failures := 0
	for entry in AUDITS:
		var name: String = entry[0]
		var path: String = entry[1]
		var audit := AuditBase.new(name)
		audit.quiet = true
		var script: GDScript = load(path)
		if script == null:
			print("FAIL %s: script not loadable" % name)
			_checks += 1
			_failures += 1
			continue
		print("# audit %s (%s)" % [name, path])
		script.run(audit)
		var code: int = audit.finish()
		total_checks += audit.checks
		total_failures += audit.failures
		if code == 0:
			passed += 1
			print("ok %s (%d checks)" % [name, audit.checks])
		else:
			print("FAIL %s (%d/%d checks, first: %s)" % [name, audit.checks - audit.failures, audit.checks, audit.first_failure])
		if audit.not_ported_count > 0:
			print("# audit %s not-ported=%d" % [name, audit.not_ported_count])
		_not_ported += audit.not_ported_count

	var audits_failed := AUDITS.size() - passed
	_checks += AUDITS.size()
	_failures += audits_failed
	print("# totals checks=%d failures=%d not-ported=%d" % [total_checks, total_failures, _not_ported])
	if _failures == 0:
		print("PASS %d/%d" % [AUDITS.size(), AUDITS.size()])
		return 0
	print("FAIL %d/%d" % [passed, AUDITS.size()])
	printerr("FAIL %d/%d" % [passed, AUDITS.size()])
	return 1
