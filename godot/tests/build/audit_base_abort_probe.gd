## audit_base_abort_probe.gd — the two false-green generators, proved shut.
##
## The independent review found the defect in two places (`independent-review.md`,
## M-4):
##
##   - `godot/src/audits/audit_base.gd:107` printed `PASS %d/%d` from the checks
##     that happened to be reached, so an audit that aborted before its first
##     assertion printed `PASS 0/0` — green, with nothing asserted.
##   - `godot/tests/audits/run_all.gd:99` printed `PASS %d/%d` from `AUDITS.size()`,
##     a constant, not from the audits that passed.
##
## This probe is the smallest thing that can go red for the first one: it drives
## `AuditBase` itself through the three states and asserts the verdict for each.
## The second one is proved by the aggregate run itself — the run that produced this
## section's evidence was RED (`FAIL 2/10`, exit 1) while the check counts did not
## match the pinned table, and green only once each audit's own count was measured
## and pinned.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/build/audit_base_abort_probe.gd
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	print("# audit_base verdict probe — an aborted audit must not read as green")
	# 1. An audit that never reached its first assertion. Before the fix this was
	#    `PASS 0/0` and exit 0. The `quiet` flag is left on so the probe's own log
	#    keeps exactly one `PASS` line.
	var aborted := AuditBase.new("probe_aborted")
	aborted.quiet = true
	_check_eq(aborted.finish(), 1, "an audit with 0 checks is a FAILURE, not a green PASS 0/0")
	_check_eq(aborted.checks, 0, "the probe really ran no assertion at all")
	# 2. An audit whose assertion failed: unchanged behaviour, and it must still be
	#    a failure after the fixed-timestep/edge work.
	var failed := AuditBase.new("probe_failed")
	failed.quiet = true
	failed.check_eq(1, 2, "probe/deliberate mismatch")
	_check_eq(failed.finish(), 1, "an audit with a failed assertion is a failure")
	# 3. A healthy audit still returns 0 — the fix must not fail everything.
	var healthy := AuditBase.new("probe_healthy")
	healthy.quiet = true
	healthy.check_eq(1, 1, "probe/deliberate match")
	_check_eq(healthy.finish(), 0, "a healthy audit is still a pass")
	# 4. `not_ported` is a recorded gap, not a failure (the reference's own design).
	var partial := AuditBase.new("probe_not_ported")
	partial.quiet = true
	partial.check_true(true, "probe/one real check")
	partial.not_ported("probe/dropped reference assertion", "no port exists")
	_check_eq(partial.finish(), 0, "a dropped reference assertion is recorded, not fatal")
	_check_eq(partial.not_ported_count, 1, "the dropped assertion is still counted")

	print("# probe checks=%d failures=%d" % [_checks, _failures])
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		return 0
	print("FAIL %d/%d" % [_checks - _failures, _checks])
	return 1


func _check_eq(actual: Variant, expected: Variant, name: String) -> void:
	_checks += 1
	if actual == expected:
		print("ok %s" % name)
		return
	_failures += 1
	print("FAIL %s: expected %s, got %s" % [name, expected, actual])
