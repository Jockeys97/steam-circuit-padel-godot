## TestHarness.gd — the house test contract, shared by the slice's audits.
##
## Same contract as `res://tests/smoke_test.gd`, so one runner reads them all:
##
##   ok <name>
##   FAIL <name>: expected <x>, got <y>     (detail also on stderr)
##   PASS <n>/<n>   -> exit 0
##   FAIL <n>/<n>   -> exit 1
##
## Caveat CI must cover (observed on this host, `tests/smoke_test.gd:12-17`): if a
## script error aborts `_ready()` the headless loop keeps running forever, so the
## command must be wrapped in `timeout`. A hung job is not a red job.
extends Node

var _checks: int = 0
var _failures: int = 0


func check_eq(actual: Variant, expected: Variant, name: String) -> void:
	_checks += 1
	if _same(actual, expected):
		print("ok %s" % name)
		return
	_fail(actual, expected, name)


func check_true(condition: bool, name: String) -> void:
	check_eq(condition, true, name)


func check_false(condition: bool, name: String) -> void:
	check_eq(condition, false, name)


## The extremes rule is a number (`scripts/demo-audit.mjs:30`), so it is asserted
## as one. Two floats that differ by 0.25 must not pass on formatting luck.
func check_at_least(actual: float, minimum: float, name: String) -> void:
	_checks += 1
	if actual >= minimum:
		print("ok %s (%.4f >= %.4f)" % [name, actual, minimum])
		return
	_fail(actual, ">= %f" % minimum, name)


func finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		get_tree().quit(0)
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
		get_tree().quit(1)


func _fail(actual: Variant, expected: Variant, name: String) -> void:
	_failures += 1
	var line := "FAIL %s: expected %s, got %s" % [name, expected, actual]
	print(line)
	printerr(line)


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same((a as Array)[i], (b as Array)[i]):
				return false
		return true
	if (typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT) and (typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT):
		return is_equal_approx(float(a), float(b))
	return a == b
