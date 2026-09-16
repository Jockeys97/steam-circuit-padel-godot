## audit_base.gd — the shared assertion/printing contract for the ported rules
## audits under `godot/tests/audits/`.
##
## Same machine-readable contract as `res://tests/smoke_test.gd`, so a shell or a
## CI job reads every audit the same way:
##
##   ok <check name>
##   FAIL <check name>: expected <x>, got <y>
##   PASS <n>/<n>     |     FAIL <n>/<n>
##
## plus two comment-only line kinds (ignored by any parser, kept for evidence):
##
##   # not-ported <check name>: <why>
##   # note <text>
##
## A `not-ported` line is the replacement for a reference assertion that cannot be
## carried over to the headless simulation. It never counts as a passed check, so
## a dropped assertion can never hide behind a green `PASS n/n`.
##
## Exit code: 0 when every check passed, 1 when any failed (`finish()` returns it
## and the caller passes it to `quit()`).
extends RefCounted

var audit_name: String = ""
var checks: int = 0
var failures: int = 0
var not_ported_count: int = 0
var notes_count: int = 0

## When true, `finish()` does not print the per-audit `PASS n/n` line: the runner
## (`godot/tests/audits/run_all.gd`) owns the summary line in that mode, and two
## `PASS` lines in one log would make a grep ambiguous. The per-check `ok`/`FAIL`
## lines always print — they are the machine-readable contract, not the summary.
var quiet: bool = false

## The first failure line, kept so the runner can print a one-line reason.
var first_failure: String = ""


func _init(name_in: String = "") -> void:
	audit_name = name_in


# ---------------------------------------------------------------------------
# Assertions. Every one of these is a direct port of a `node:assert` call from
# the reference audit: same relation, same case, same expected value.
# ---------------------------------------------------------------------------

func check_true(condition: bool, check_name: String) -> void:
	_tally(condition, check_name, true, condition)


func check_eq(actual: Variant, expected: Variant, check_name: String) -> void:
	_tally(actual == expected, check_name, expected, actual)


func check_ne(actual: Variant, unexpected: Variant, check_name: String) -> void:
	_tally(actual != unexpected, check_name, "not %s" % _fmt(unexpected), actual)


func check_gt(actual: Variant, limit: Variant, check_name: String) -> void:
	_tally(_cmp(actual, limit) > 0, check_name, "> %s" % _fmt(limit), actual)


func check_ge(actual: Variant, limit: Variant, check_name: String) -> void:
	_tally(_cmp(actual, limit) >= 0, check_name, ">= %s" % _fmt(limit), actual)


func check_lt(actual: Variant, limit: Variant, check_name: String) -> void:
	_tally(_cmp(actual, limit) < 0, check_name, "< %s" % _fmt(limit), actual)


func check_le(actual: Variant, limit: Variant, check_name: String) -> void:
	_tally(_cmp(actual, limit) <= 0, check_name, "<= %s" % _fmt(limit), actual)


## `assert.ok(a && b)` in the one shape the reference audits use most: a value
## that must be present and inside a band.
func check_between(actual: Variant, low: Variant, high: Variant, check_name: String) -> void:
	_tally(_cmp(actual, low) > 0 and _cmp(actual, high) < 0, check_name, "%s < x < %s" % [_fmt(low), _fmt(high)], actual)


# ---------------------------------------------------------------------------
# Recording
# ---------------------------------------------------------------------------

## A reference assertion with no port. Prints a `# not-ported` line and does NOT
## increment `checks` — a dropped check must not be able to read as a pass.
func not_ported(check_name: String, why: String) -> void:
	not_ported_count += 1
	print("# not-ported %s: %s" % [check_name, why])


func note(text: String) -> void:
	notes_count += 1
	print("# note %s" % text)


## A measured value the reference audit prints in its JSON report at the end.
func report(text: String) -> void:
	print("# report %s" % text)


## The verdict, and it is a verdict about the AUDIT, not about the assertions that
## happened to be reached:
##
##   - `checks == 0` is NOT a pass. A GDScript runtime error aborts only the
##     function it happens in and Godot keeps running, so an audit that died before
##     its first assertion would otherwise report `PASS 0/0` — green, with nothing
##     asserted (independent review, M-4). It fails, and says so by name.
##   - `not_ported` never turns the verdict green or red: a dropped reference
##     assertion is a recorded gap, not a failure (L-3).
##
## The runner that owns the aggregate verdict additionally pins each audit's check
## COUNT (`tests/audits/run_all.gd`, `EXPECTED_CHECKS`), because an audit that dies
## after its fifth assertion still has `checks > 0` here.
func finish() -> int:
	if checks == 0:
		var aborted := "FAIL %s: 0 checks ran — the audit aborted before its first assertion" % audit_name
		if first_failure == "":
			first_failure = aborted
		if not quiet:
			print(aborted)
		printerr(aborted)
		return 1
	if failures == 0:
		if not quiet:
			print("PASS %d/%d" % [checks, checks])
		return 0
	if not quiet:
		print("FAIL %d/%d" % [checks - failures, checks])
	printerr("FAIL %d/%d" % [checks - failures, checks])
	print("# first failure %s" % first_failure)
	printerr("# first failure %s" % first_failure)
	return 1


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _tally(passed: bool, check_name: String, expected: Variant, actual: Variant) -> void:
	checks += 1
	if passed:
		print("ok %s" % check_name)
		return
	failures += 1
	var line := "FAIL %s: expected %s, got %s" % [check_name, _fmt(expected), _fmt(actual)]
	if first_failure == "":
		first_failure = line
	print(line)


static func _cmp(actual: Variant, limit: Variant) -> int:
	var a := float(actual)
	var b := float(limit)
	if a > b:
		return 1
	if a < b:
		return -1
	return 0


## Values print the way the reference's own failure messages read them: integers
## as integers, fractions with enough places to see a band failure.
static func _fmt(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return "%.6f" % float(value)
		TYPE_NIL:
			return "null"
		TYPE_STRING:
			return "\"%s\"" % String(value)
		TYPE_DICTIONARY:
			return JSON.stringify(value)
		TYPE_ARRAY:
			return JSON.stringify(value)
	return str(value)
