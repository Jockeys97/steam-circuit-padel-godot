## run_all.gd — the runner for the ten ported rules/simulation audits.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 1800 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ \
##     --script res://tests/audits/run_all.gd
##
## One `ok`/`FAIL` line group per audit, one per-audit summary line, then a single
## combined `PASS <audits>/<audits>` (or `FAIL`) and exit 0/1. The individual
## audits are suppressed from printing their own summary in this mode
## (`AuditBase.quiet`), so exactly one `PASS` line ends the log.
##
## The audits run cheapest-first so a red on the small ones is visible in seconds.
## Every audit is the same file the single-audit invocation runs; nothing here
## re-implements a rule.
##
## The harness checks at the top are NOT reference assertions. They pin the two
## things this slice added that no JavaScript audit carries: the seed arithmetic
## `Support.seeded_rng_state` reproduces (against vectors printed by
## `node tools/audit-port/seed-vectors.mjs`, i.e. by V8 itself) and the tick the
## ported audits drive.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")

## Cheapest first. Each entry is `[audit name, script path]`.
const AUDITS := [
	["controller_tactics", "res://tests/audits/controller_tactics_audit.gd"],
	["match_format", "res://tests/audits/match_format_audit.gd"],
	["wall_rules", "res://tests/audits/wall_rules_audit.gd"],
	["court_speed", "res://tests/audits/court_speed_audit.gd"],
	["shot_quality", "res://tests/audits/shot_quality_audit.gd"],
	["smash_input", "res://tests/audits/smash_input_audit.gd"],
	["lineup", "res://tests/audits/lineup_audit.gd"],
	["ai_attack", "res://tests/audits/ai_attack_audit.gd"],
	["difficulty", "res://tests/audits/difficulty_audit.gd"],
	["shot_balance", "res://tests/audits/shot_balance_audit.gd"],
]

## HOW MANY CHECKS EACH AUDIT MUST RUN, pinned here so an audit that dies half-way
## cannot pass. The independent review found the defect (M-4): the verdict was
## `_failures == 0` over the assertions that happened to be REACHED, so a section
## that aborted silently shrank the total and the run stayed green — `PASS 10/10`
## was a constant, `AUDITS.size()`, not an accumulated count. A GDScript runtime
## error aborts one function and execution continues, which is exactly the hole.
##
##   - measured: `# totals checks=221` over the ten audits, before the fix
##   - `checks != EXPECTED_CHECKS[name]` now fails that audit, in either direction:
##     a skipped or dead section lowers it, an audit that grew silently raises it
##     (a new assertion must be recorded here, deliberately).
##
## RE-MEASURED, and how. The first version of this table carried the right TOTAL
## (221, the recorded measurement) with eight of the ten per-name counts attached to
## the wrong names — an audit reported `ran 14 checks, expected 22` while another
## reported `ran 35, expected 23`, i.e. the numbers were permuted across the name
## list. The table below is each audit's own measured count, read back from the
## ten `ok <name> (<n> checks)` lines of the run in
## docs/wayfinder/evidence/quick-match-playable.md §12, and the ten of them still add
## up to the recorded 221 (`EXPECTED_TOTAL` below). Nothing else about the verdict
## changed: a count that moves is still a failure, deliberately, in either direction.
const EXPECTED_CHECKS := {
	"controller_tactics": 14,
	"match_format": 26,
	"wall_rules": 22,
	"court_speed": 25,
	"shot_quality": 13,
	"smash_input": 24,
	"lineup": 23,
	"ai_attack": 16,
	"difficulty": 35,
	"shot_balance": 23,
}
## The sum `EXPECTED_CHECKS` must add up to. Checked, so a typo in the table above
## is caught by the runner itself rather than by a reader.
const EXPECTED_TOTAL := 221

## `(Math.random() * 0xffffffff) | 0` for `seededRandom(seed)`'s first draw, as
## printed by `node tools/audit-port/seed-vectors.mjs` on this host (V8 12.x).
const SEED_VECTORS := {
	1: -1601705230,
	11: -2097717654,
	42: -1713246341,
	4242: -1946882333,
	7919: -1331012520,
	20260811: 1659286287,
}
const HALF_VECTOR := 2147483647

var _checks: int = 0
var _failures: int = 0
var _not_ported: int = 0


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	print("# rules/simulation audits ported from scripts/*.mjs — reference commit 2979588")
	_harness_checks()

	var passed := 0
	var total_checks := 0
	var total_failures := 0
	var mismatched: Array[String] = []
	if _expected_total() != EXPECTED_TOTAL:
		print("FAIL expected-checks table sums to %d, EXPECTED_TOTAL is %d" % [_expected_total(), EXPECTED_TOTAL])
		_checks += 1
		_failures += 1
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
		# The count is the second half of the verdict, and it is what catches an
		# audit whose section died half-way: `finish()` alone only fails `checks == 0`.
		var expected: int = int(EXPECTED_CHECKS.get(name, -1))
		if expected < 0:
			print("FAIL %s: no EXPECTED_CHECKS entry — pin its check count" % name)
			code = 1
			mismatched.append(name)
		elif audit.checks != expected:
			print("FAIL %s: ran %d checks, expected %d (a skipped or dead section)" % [name, audit.checks, expected])
			code = 1
			mismatched.append(name)
		_checks += 1
		total_checks += audit.checks
		total_failures += audit.failures
		if code == 0:
			passed += 1
			print("ok %s (%d checks)" % [name, audit.checks])
		else:
			_failures += 1
			print("FAIL %s (%d/%d checks, first: %s)" % [name, audit.checks - audit.failures, audit.checks, audit.first_failure])
		if audit.not_ported_count > 0:
			print("# audit %s not-ported=%d" % [name, audit.not_ported_count])
		_not_ported += audit.not_ported_count

	var audits_failed := AUDITS.size() - passed
	print("# totals checks=%d failures=%d not-ported=%d expected-checks=%d mismatched=%s audits_failed=%d" % [
		total_checks, total_failures, _not_ported, EXPECTED_TOTAL, str(mismatched), audits_failed])
	# The verdict is the ACCUMULATED result (`passed`), not the constant
	# `AUDITS.size()` it used to print (independent review, M-4).
	print("# verdict audits passed=%d/%d harness checks=%d/%d" % [passed, AUDITS.size(), _checks - _failures, _checks])
	if _failures == 0:
		print("PASS %d/%d" % [passed, AUDITS.size()])
		return 0
	print("FAIL %d/%d" % [passed, AUDITS.size()])
	printerr("FAIL %d/%d" % [passed, AUDITS.size()])
	return 1


static func _expected_total() -> int:
	var total := 0
	for key in EXPECTED_CHECKS:
		total += int(EXPECTED_CHECKS[key])
	return total


## The seed arithmetic, against V8's own output, and the tick the ported audits
## drive (`FIXED_STEP` is `js/main.js:1164`; the audits that use `1/240` copy the
## JavaScript audit's own dt, which is a scenario value, not the engine tick).
func _harness_checks() -> void:
	for seed in SEED_VECTORS:
		_check_eq(
			Support.seeded_rng_state(int(seed)), int(SEED_VECTORS[seed]),
			"harness/seeded_rng_state_matches_v8_seed_%d" % int(seed),
		)
	# `Math.random = () => 0.5`: the draw is `2**31`, so the state is `2**31 - 1`.
	_check_eq(
		Support.state_from_draw(2147483648), HALF_VECTOR,
		"harness/half_draw_rng_state_matches_v8",
	)
	_check_eq(Support.HALF_RNG_STATE, HALF_VECTOR, "harness/half_rng_state_constant")
	_check_eq(Engine.physics_ticks_per_second, 120, "harness/physics_tick_is_120_hz")
	# `Sim.empty_input()` (`js/game.js:2712-2734`) carries 23 fields, and the
	# JavaScript audits' 11-field `VUOTO` literal is the same struct with the rest
	# unset — the count is pinned so a field silently dropped from the input
	# contract is visible here.
	_check_eq(Support.vuoto().size(), 23, "harness/empty_input_has_the_full_field_set")


func _check_eq(actual: Variant, expected: Variant, name: String) -> void:
	_checks += 1
	if actual == expected:
		print("ok %s" % name)
		return
	_failures += 1
	print("FAIL %s: expected %s, got %s" % [name, expected, actual])
