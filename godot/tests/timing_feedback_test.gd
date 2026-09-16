## timing_feedback_test.gd — the timing model's own gate: the numbers behind
## "PERFETTO", asserted against the reference's own values, and the Godot half of
## `tools/sim-port/timing-trace.mjs`.
##
## WHY THIS FILE EXISTS
##   The frozen digest (`scripts/parity-digest.mjs` / `godot/src/sim/digest.gd`)
##   samples ball, paddles and score. None of the timing fields that stand behind
##   the on-screen meter are in it: `shotCharge`, `shotRead.active/eta/perfectWindow/
##   advice/profile/overlap`, the assessment's `quality`/`grade` and the x3
##   recoveries are all outside the digest shape, so a green parity digest says
##   nothing about them. This test does two things about that:
##
##   1. it asserts, in-process, the constants and the semantics the reference pins
##      (`js/game.js:220`, `:826-881`, `:883-926`, `:928-1010`, `js/data.js:181-199`):
##      the `shotRead` default literal and the full key set the step writes, the
##      perfect window and its clamp band, `eta` null/not-null, the grade ids and
##      their reachability, and that the weights that build `quality` are the ones
##      that reconstruct it;
##   2. it replays the SAME scripted scenario as `tools/sim-port/timing-trace.mjs`
##      through the ported step and writes a per-tick `# tm` stream, one line per
##      tick, that `tools/sim-port/timing-compare.py` diffs field by field against
##      the JavaScript engine's stream. The stream also carries the frozen digest
##      shape and `# tr`/`# ev`/`# strike` lines, so the existing in-house
##      comparator (`tools/sim-port/trace-compare.py`) can additionally assert that
##      the two streams are the same run, not two runs that happen to agree.
##
## INPUT SCRIPT (identical in both halves; a pure function of the state and the
## tick, no wall clock, no unseeded randomness):
##   charging: true                        every tick
##   hit:      (serving and charge >= 0.999) OR (shotRead.active and eta < 0.30|0.10
##             on a 480-tick square wave)
##   analogAim: true, aim = 0.7|-0.35 on a 900-tick square wave
##   moveX/moveY: the frozen harness's movement pattern (`scripts/parity-digest.mjs:89-98`)
##
## Output contract (same shape as `res://tests/smoke_test.gd`): one
## `ok <name>` / `FAIL <name>: expected <x>, got <y>` line per check, then exactly
## one `PASS <n>/<n>` or `FAIL <n>/<n>`, exiting 0 on PASS and 1 on FAIL.
##
## Run (macOS host, engine pin verified in the run itself by res://tests/smoke_test.gd):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/timing_feedback_test.gd -- \
##     --seed=2024 --ticks=3600 --every=120 --trace=tools/sim-port/out/timing/gd-2024.txt
##   ... same command with --inject-failure   (negative control: shifts the expected
##     perfect window by 1 ms, so the suite must print FAIL and exit 1)
##
## It goes red if: a timing constant drifted from the reference's, `shotRead` lost a
## field, `eta` went finite outside the incoming window (or the reverse), a grade id
## left the reference's vocabulary, the quality weights stopped reconstructing the
## score, or the scripted scenario stopped exercising the read model and the x3 path.
extends SceneTree

const Sim := preload("res://src/sim/sim.gd")
const State := preload("res://src/sim/state.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Digest := preload("res://src/sim/digest.gd")
const Locale := preload("res://src/locale/locale.gd")

## `FIXED_STEP = 1 / 120` (`js/main.js:1164`).
const FIXED_STEP := 1.0 / 120.0
## `state.shotCharge` is capped at 1 (`js/game.js:2686`); same threshold as the JS half.
const FULL_CHARGE := 0.999

## The scenario the two streams are compared on unless overridden. Seed 2024 is the
## one that reaches the x3 branch (measured: 867 ticks with `ball.shotType ==
## "smash-x3"` and 372 ticks with `aiX3Recovery > 0` over 3 600 ticks); the guard at
## the end of the run fails if that stops being true.
const DEFAULT_SEED := 2024
const DEFAULT_TICKS := 3600
const DEFAULT_EVERY := 120
const DEFAULT_SETS := 3

## `js/game.js:220` — the literal `createMatchState` puts in `state.shotRead`.
const SHOT_READ_DEFAULTS := {
	"active": false,
	"eta": null,
	"perfectWindow": 0.055,
	"advice": "read",
	"profile": "control",
	"overlap": false,
}

## `js/game.js:916-925` — the keys `updateShotRead` writes every tick. A field
## missing here is a field the HUD would read as `undefined`.
const SHOT_READ_STEP_KEYS := [
	"active", "eta", "perfectWindow", "advice", "profile", "overlap", "precision", "tight",
]

## `js/game.js:889-901` — the advice ids `t(\`shotAdvice_${advice}\`)` looks up
## (`js/render.js:1730`).
const ADVICE_IDS := ["read", "lob", "chiquita", "smash", "vibora", "drive"]
## `js/game.js:1003-1009` — the grade ids, in the reference's own spelling.
const GRADE_IDS := ["perfect", "good", "early", "late"]
## `js/game.js:826-832` — the profile ids `shotProfile` returns.
const PROFILE_IDS := ["control", "attack", "risk"]

## The timing constants compared between the engines' own balance tables.
const TIMING_CONSTANTS := [
	"perfectTimingWindow",
	"goodTimingWindow",
	"timingWindowRunPenalty",
	"timingWindowEnergyPenalty",
	"timingWindowGlassPenalty",
	"timingWindowSplitStepBonus",
	"timingWindowChargePenalty",
	"timingWindowMin",
	"timingWindowMax",
	"timingDecaySpan",
	"qualityTimingWeight",
	"playableHitHeight",
	"ballGravity",
	"smashMinHeight",
	"lateGraceFactor",
	"sprintAccuracyPenalty",
	"splitStepQualityBonus",
	"rallyEnergyFloor",
	"smashX2MinQuality",
	"smashX3MinQuality",
]

const TRACE_KEYS := [
	"serving", "serveAttempts", "bounces", "points", "games", "sets", "rallyHits", "lastHitterSide",
]

## Float64 arithmetic, not an engine tolerance: both engines compute these sums in
## double precision, so this only absorbs the associativity of one addition order.
const EXACT_EPSILON := 1e-12

var _checks := 0
var _failures := 0
var _options := {
	"seed": DEFAULT_SEED,
	"ticks": DEFAULT_TICKS,
	"every": DEFAULT_EVERY,
	"sets": DEFAULT_SETS,
	"athlete": 0,
	"trace": "",
	"quiet": false,
	"inject_failure": false,
}


## `--inject-failure` shifts the expected perfect window by 1 ms. It exists to prove
## the gate can go red: a suite that cannot fail is not evidence.
func _injected() -> float:
	return 0.001 if bool(_options["inject_failure"]) else 0.0


func _initialize() -> void:
	_parse_args()
	_check_shot_read_model()
	_check_perfect_window()
	_check_eta_semantics()
	_check_grade_ids()
	_check_quality_weights()
	_run_scenario()
	_finish()


# ---------------------------------------------------------------------------
# 1. The model in process: constants, keys, semantics
# ---------------------------------------------------------------------------

## `js/game.js:220` and `js/game.js:916-925`.
func _check_shot_read_model() -> void:
	var balance: Dictionary = Frozen.balance()
	var fresh := _scratch_state()
	var defaults: Dictionary = fresh.shotRead
	_check_eq(defaults.keys().size(), SHOT_READ_DEFAULTS.keys().size(), "shotRead literal carries the reference's six keys")
	for key in SHOT_READ_DEFAULTS:
		_check_true(defaults.has(key), "shotRead literal has key %s" % key)
	_check_eq(bool(defaults["active"]), false, "shotRead.active default is false")
	_check_eq(defaults["eta"], null, "shotRead.eta default is null")
	_check_eq(float(defaults["perfectWindow"]), 0.055 + _injected(), "shotRead.perfectWindow default is 0.055")
	_check_eq(String(defaults["advice"]), "read", "shotRead.advice default is \"read\"")
	_check_eq(String(defaults["profile"]), "control", "shotRead.profile default is \"control\"")
	_check_eq(bool(defaults["overlap"]), false, "shotRead.overlap default is false")
	_check_eq(float(balance["perfectTimingWindow"]), 0.055 + _injected(), "balance.perfectTimingWindow is 0.055")

	# The step's own write, with no ball in play: every key of the reference's
	# object literal must be present, including the two the literal does not carry.
	Sim.update_shot_read(fresh, fresh.player)
	var written: Dictionary = fresh.shotRead
	_check_eq(written.keys().size(), SHOT_READ_STEP_KEYS.size(), "update_shot_read writes the reference's eight keys")
	for key in SHOT_READ_STEP_KEYS:
		_check_true(written.has(key), "shotRead written by the step has key %s" % key)
	_check_eq(String(written["advice"]), "read", "no incoming ball leaves advice at \"read\"")
	_check_eq(written["eta"], null, "no incoming ball leaves eta at null")


## `js/game.js:841-857` (`contextualPerfectWindow`) and its clamp band
## (`js/data.js:198-200`).
func _check_perfect_window() -> void:
	var state := _scratch_state()
	var balance: Dictionary = Frozen.balance()
	var paddle := state.player
	var base := float(balance["perfectTimingWindow"])
	var run_penalty := float(balance["timingWindowRunPenalty"])
	var energy_penalty := float(balance["timingWindowEnergyPenalty"])
	var glass_penalty := float(balance["timingWindowGlassPenalty"])
	var split_bonus := float(balance["timingWindowSplitStepBonus"])
	var charge_penalty := float(balance["timingWindowChargePenalty"])
	var window_min := float(balance["timingWindowMin"])
	var window_max := float(balance["timingWindowMax"])

	_check_eq(window_min, 0.026, "balance.timingWindowMin is 0.026")
	_check_eq(window_max, 0.07, "balance.timingWindowMax is 0.07")
	_check_close(charge_penalty, 0.018, EXACT_EPSILON, "balance.timingWindowChargePenalty is 0.018")

	# A paddle at rest, full energy, no glass: the window is the base minus the
	# quadratic charge term only.
	_check_close(Sim.contextual_perfect_window(state, paddle, 0.0), 0.055 + _injected(), EXACT_EPSILON, "window at charge 0 is 0.055")
	_check_close(Sim.contextual_perfect_window(state, paddle, 0.5), 0.0505, EXACT_EPSILON, "window at charge 0.5 is 0.0505")
	_check_close(Sim.contextual_perfect_window(state, paddle, 1.0), 0.037, EXACT_EPSILON, "window at charge 1 is 0.037")

	# Quadratic in the charge: the midpoint of the charge costs a quarter of the
	# full-charge penalty.
	var full_cost := base - float(Sim.contextual_perfect_window(state, paddle, 1.0))
	var half_cost := base - float(Sim.contextual_perfect_window(state, paddle, 0.5))
	_check_close(half_cost, full_cost * 0.25, EXACT_EPSILON, "the charge term is quadratic (0.5^2 of the full cost)")
	_check_true(float(Sim.contextual_perfect_window(state, paddle, 0.25)) > float(Sim.contextual_perfect_window(state, paddle, 0.5)), "the window shrinks as the charge grows")

	# Running, the glass, and the split-step: one term each.
	paddle.moveRatio = 1.0
	_check_close(Sim.contextual_perfect_window(state, paddle, 0.0), base - run_penalty, EXACT_EPSILON, "running costs timingWindowRunPenalty")
	paddle.moveRatio = 0.0
	paddle.splitStep = 1.0
	_check_close(Sim.contextual_perfect_window(state, paddle, 0.0), base + split_bonus, EXACT_EPSILON, "the split-step pays timingWindowSplitStepBonus")
	paddle.splitStep = 0.0

	state.ball.postGlassSide = "player"
	_check_close(Sim.contextual_perfect_window(state, paddle, 0.0), base - glass_penalty, EXACT_EPSILON, "coming off my own glass costs timingWindowGlassPenalty")
	state.ball.postGlassSide = "ai"
	_check_close(Sim.contextual_perfect_window(state, paddle, 0.0), base + _injected(), EXACT_EPSILON, "the opponent's glass is not my penalty")
	state.ball.postGlassSide = null

	state.rallyEnergy["player"] = 0.41
	paddle.moveRatio = 1.0
	var raw := base - run_penalty - (0.65 - 0.41) * energy_penalty - charge_penalty
	_check_true(raw < window_min, "the four penalties together land below timingWindowMin (%.6f)" % raw)
	_check_close(Sim.contextual_perfect_window(state, paddle, 1.0), window_min, EXACT_EPSILON, "the window clamps at timingWindowMin")
	_check_true(base + split_bonus < window_max, "base + the split-step bonus stays under timingWindowMax, so that clamp is inert")
	state.rallyEnergy["player"] = 1.0
	paddle.moveRatio = 0.0


## `js/game.js:866-881` (`playableEta`) — null outside the incoming window, finite
## inside it.
func _check_eta_semantics() -> void:
	var state := _scratch_state()
	var paddle := state.player
	var ball = state.ball

	ball.vy = 20.0
	_check_eq(Sim.playable_eta(state, paddle), null, "eta is null while the ball is not arriving (vy 20 <= 28)")
	ball.vy = 28.0
	_check_eq(Sim.playable_eta(state, paddle), null, "eta is null exactly at the vy guard, which is strict")
	ball.vy = 0.0
	_check_eq(Sim.playable_eta(state, paddle), null, "eta is null on a still ball")

	# Arriving, below the playable ceiling at the paddle line: the linear case.
	ball.y = paddle.y - 200.0
	ball.z = 40.0
	ball.vz = 0.0
	ball.vy = 40.0
	var linear: Variant = Sim.playable_eta(state, paddle)
	_check_true(linear != null, "eta is not null on an arriving ball")
	_check_true(is_finite(float(linear)), "eta is finite on an arriving ball")
	_check_close(float(linear), 5.0, EXACT_EPSILON, "eta on a flat approach is (paddle.y - ball.y) / vy")

	# Arriving above the ceiling: the useful contact is the descent under
	# `playableHitHeight`, which happens after the ball crosses the paddle line.
	ball.y = paddle.y - 20.0
	ball.z = 150.0
	ball.vz = 0.0
	ball.vy = 400.0
	var ceiling: float = float(Frozen.balance()["playableHitHeight"])
	var time_to_line: float = (paddle.y - ball.y) / ball.vy
	var descent: Variant = Sim.playable_eta(state, paddle)
	_check_true(descent != null, "eta is not null for a ball arriving above the ceiling")
	_check_true(is_finite(float(descent)), "eta is finite for a ball arriving above the ceiling")
	_check_true(float(descent) > time_to_line * 5.0, "eta waits for the descent under playableHitHeight (%.6f s vs %.6f s to the paddle line)" % [float(descent), time_to_line])
	_check_true(ball.z > ceiling, "the case above really is above playableHitHeight")


## `js/game.js:1003-1009` — the grade ids, the thresholds as constants, and the
## mapping from the sim's grade to the message id the shell resolves
## (`js/game.js:1062-1069`, `godot/game/hud.gd:521-531`).
func _check_grade_ids() -> void:
	var state := _scratch_state()
	var paddle := state.player
	var ball = state.ball
	var base := float(Frozen.balance()["perfectTimingWindow"])

	# A clean contact at rest is perfect.
	ball.x = paddle.x
	ball.y = paddle.y
	ball.z = 60.0
	var perfect: Dictionary = Sim.evaluate_shot_quality(state, paddle, {"charge": 0.5, "aim": 0.0, "timingAge": 0.0})
	_check_eq(String(perfect["grade"]), "perfect", "a contact on the ball is graded perfect")
	var window_at_half := float(Sim.contextual_perfect_window(state, paddle, 0.5))
	# Clearly inside the window, then clearly outside it: never on the edge.
	var inside: Dictionary = Sim.evaluate_shot_quality(state, paddle, {"charge": 0.5, "aim": 0.0, "timingAge": window_at_half * 0.5})
	_check_eq(String(inside["grade"]), "perfect", "half the window early is still perfect")
	var outside: Dictionary = Sim.evaluate_shot_quality(state, paddle, {"charge": 0.5, "aim": 0.0, "timingAge": window_at_half * 1.5})
	_check_true(String(outside["grade"]) != "perfect", "half a window beyond the window is no longer perfect")

	# Sweep the swing age: the vocabulary is exactly the reference's four ids and
	# all three reachable-at-contact ones appear.
	var seen := {}
	for step in range(0, 121):
		var age := 0.004 * float(step)
		var graded: Dictionary = Sim.evaluate_shot_quality(state, paddle, {"charge": 0.5, "aim": 0.0, "timingAge": age})
		var grade := String(graded["grade"])
		if step == 0:
			_check_true(GRADE_IDS.has(grade), "the grade vocabulary is the reference's (%s)" % grade)
		seen[grade] = true
	for grade in GRADE_IDS:
		if grade != "late":
			_check_true(seen.has(grade), "the sweep reaches grade %s" % grade)
	_check_eq(seen.keys().size(), 3, "the sweep produces exactly perfect, good and early")

	# A swing delivered after the ball passed the body, with the timing decayed
	# below the perfect band, is late (`js/game.js:1006-1007`).
	ball.y = paddle.y + 40.0
	var late: Dictionary = Sim.evaluate_shot_quality(state, paddle, {"charge": 0.5, "aim": 0.0, "timingAge": 0.4})
	_check_eq(String(late["grade"]), "late", "a contact with the ball behind the paddle is graded late")
	_check_true(float(late["timing"]) < 0.9, "the late contact really is below the perfect timing band")
	ball.y = paddle.y

	# The sim stores `shot:<grade>`; the reference renders `t("shot" + Grade)`
	# (`js/game.js:1062-1069`), which is the key `godot/game/hud.gd:513-531`
	# reconstructs. Each derivation must land on a resolvable message id, for every
	# grade the model can return.
	for grade in GRADE_IDS:
		var key := "shot" + String(grade).capitalize()
		_check_true(Locale.is_resolvable(key), "the HUD key for grade %s resolves (%s)" % [grade, key])
		var stored := "shot:%s" % grade
		_check_eq("shot" + stored.substr(5).capitalize(), key, "the stored id %s derives the reference key %s" % [stored, key])
	# And the advice ids the read model emits are the HUD's lookup keys
	# (`js/render.js:1730`).
	for advice in ADVICE_IDS:
		_check_true(Locale.is_resolvable("shotAdvice_" + String(advice)), "the HUD key shotAdvice_%s resolves" % advice)


## `js/game.js:977-990` — `quality` is the weighted sum of the parts the call
## returns. The returned dictionary has no `control` key (the reference's own
## literal stops at `grade`), so the weights are pinned by the parts that ARE
## returned and the residual — the control term — is pinned to its band
## (`clamp(control / 1.22, 0.72, 1.05) * 0.05`, `js/game.js:968-975`).
func _check_quality_weights() -> void:
	var state := _scratch_state()
	var paddle := state.player
	var ball = state.ball
	var balance: Dictionary = Frozen.balance()
	ball.x = paddle.x - 30.0
	ball.y = paddle.y - 25.0
	ball.z = 70.0
	var residuals: Array = []
	for case in [{"charge": 0.2, "aim": 0.9, "timingAge": 0.01}, {"charge": 0.8, "aim": -0.4, "timingAge": 0.09}]:
		var quality: Dictionary = Sim.evaluate_shot_quality(state, paddle, case)
		var split_bonus := float(paddle.splitStep) * float(balance["splitStepQualityBonus"])
		var explained := float(quality["timing"]) * float(balance["qualityTimingWeight"]) \
			+ float(quality["position"]) * 0.21 \
			+ float(quality["balance"]) * 0.12 \
			+ float(quality["height"]) * 0.1 \
			+ float(quality["energy"]) * 0.08 \
			+ split_bonus
		residuals.append(float(quality["quality"]) - explained)
		_check_true(float(quality["quality"]) > 0.0 and float(quality["quality"]) < 1.0, "quality is not clamped for charge %.2f" % float(case["charge"]))
	_check_close(float(residuals[0]), float(residuals[1]), 1e-9, "the terms that cannot be seen from outside (control) are constant")
	var control_lo := 0.72 * 0.05
	var control_hi := 1.05 * 0.05
	_check_true(float(residuals[0]) >= control_lo - 1e-9 and float(residuals[0]) <= control_hi + 1e-9, "the residual is the control term in the reference's clamp band (%.6f)" % float(residuals[0]))
	_check_close(float(balance["qualityTimingWeight"]), 0.44, EXACT_EPSILON, "balance.qualityTimingWeight is 0.44")
	_check_close(float(balance["goodTimingWindow"]), 0.13, EXACT_EPSILON, "balance.goodTimingWindow is 0.13")
	_check_close(float(balance["timingDecaySpan"]), 0.9, EXACT_EPSILON, "balance.timingDecaySpan is 0.9")


# ---------------------------------------------------------------------------
# 2. The scripted scenario: the same input script, the same stream as the JS half
# ---------------------------------------------------------------------------
func _run_scenario() -> void:
	var seed: int = int(_options["seed"])
	var ticks: int = int(_options["ticks"])
	var every: int = int(_options["every"])
	var sets: int = int(_options["sets"])
	var athlete: int = int(_options["athlete"])
	var quiet: bool = bool(_options["quiet"])

	var athletes: Array = Frozen.athletes()
	if athlete < 0 or athlete >= athletes.size():
		push_error("timing_feedback_test.gd: --athlete=%d fuori intervallo [0, %d]" % [athlete, athletes.size() - 1])
		_checks += 1
		_failures += 1
		return
	var state: State = Sim.create_match_state(
		"quick", athletes[athlete], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	state.rng_state = seed
	state.rng_calls = 0
	state.running = true
	state.setsToWin = sets

	var header: Array = [
		"# timing_feedback_test.gd seed=%d ticks=%d every=%d step=%.18f setsToWin=%d athlete=%d" % [seed, ticks, every, FIXED_STEP, sets, athlete],
		"# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)",
		"# input-script=charging:true every tick; hit=(state.serving && shotCharge>=%.3f) || (shotRead.active && eta < 0.30|0.10 on a 480-tick square wave); analogAim:true aim=0.7|-0.35 on a 900-tick square wave; moveX/moveY = the frozen harness pattern" % FULL_CHARGE,
		"# format=gd-side compare-js-timing-stream",
	]
	var digest_lines: Array = []
	var trace: Array = []
	var timing: Array = []
	var events: Array = []
	var strikes: Array = []
	var double_faults: Array = []
	var set_closures: Array = []
	var previous_calls: int = 0
	var previous_trace: Variant = null
	var result_tick: Variant = null

	# Live invariants, counted over every traced tick.
	var eta_null_not_active: int = 0
	var active_but_eta_unusable: int = 0
	var eta_not_finite: int = 0
	var window_out_of_band: int = 0
	var advice_off_vocabulary: int = 0
	var profile_off_vocabulary: int = 0
	var grade_off_vocabulary: int = 0
	var window_min: float = float(Frozen.balance()["timingWindowMin"])
	var window_max: float = float(Frozen.balance()["timingWindowMax"])
	# The release, as the model actually behaves (`js/game.js:2624-2627` for the
	# serve, `:2694-2707` `queueChargedShot` for a rally hit): a release drops
	# `shotCharge` to 0 on the next tick, restarts the charge from zero, and — for a
	# rally hit — carries the charge it held into `queuedShotCharge`. The serve
	# release consumes the charge directly and leaves `queuedShotCharge` alone. A
	# reset is detected from the trace itself: charge(T-1) > 0.05, charge(T) == 0.
	var one_tick_charge: float = FIXED_STEP / 1.05
	var reset_pending: bool = false
	var previous_charge: float = 0.0
	var previous_serving: bool = true
	var previous_window: float = 0.0
	var resets: int = 0
	var rally_resets: int = 0
	var serve_resets: int = 0
	var reset_not_restarted: int = 0
	var rally_reset_without_carry: int = 0
	var carry_over_cap: int = 0
	var reset_window_not_widened: int = 0
	var reset_active_eta: int = 0

	for tick in range(0, ticks + 1):
		if tick % every == 0:
			var delta: int = state.rng_calls - previous_calls
			previous_calls = state.rng_calls
			digest_lines.append(Digest.digest_line(Digest.sample_state(state, tick, delta)))

		var current: Dictionary = _trace_of(state)
		for line in _trace_lines(previous_trace, current, tick):
			trace.append(line)
		previous_trace = current

		var read: Dictionary = state.shotRead
		var eta: Variant = read["eta"]
		var active := bool(read["active"])
		if eta == null and active:
			eta_null_not_active += 1
		if eta != null and not is_finite(float(eta)):
			eta_not_finite += 1
		if active and (eta == null or float(eta) <= -0.16 or float(eta) >= 1.15):
			active_but_eta_unusable += 1
		var window := float(read["perfectWindow"])
		if window < window_min or window > window_max:
			window_out_of_band += 1
		if not ADVICE_IDS.has(String(read["advice"])):
			advice_off_vocabulary += 1
		if not PROFILE_IDS.has(String(read["profile"])):
			profile_off_vocabulary += 1
		var feedback: Variant = state.shotFeedback
		if feedback != null and not GRADE_IDS.has(String(feedback["grade"])):
			grade_off_vocabulary += 1

		var charge_now: float = state.shotCharge
		var window_now := float(read["perfectWindow"])
		if reset_pending:
			# The charge restarts from zero: a model that had merely trimmed it
			# would show the previous charge plus a tick or two.
			if charge_now > 2.0 * one_tick_charge + 1e-9:
				reset_not_restarted += 1
			reset_pending = false
		if previous_charge > 0.05 and charge_now == 0.0:
			resets += 1
			if previous_serving:
				serve_resets += 1
			else:
				rally_resets += 1
				if float(state.queuedShotCharge) <= 0.0:
					rally_reset_without_carry += 1
			if float(state.queuedShotCharge) > minf(1.0, previous_charge + one_tick_charge) + 1e-9:
				carry_over_cap += 1
			if window_now < previous_window - 1e-9:
				reset_window_not_widened += 1
			if bool(read["active"]):
				reset_active_eta += 1
			reset_pending = true
		previous_charge = charge_now
		previous_serving = state.serving
		previous_window = window_now

		var timing_line := _timing_line(state, tick)
		timing.append(timing_line)

		var head_text: String = "null" if state.events.is_empty() else String(state.events[0])
		if events.is_empty() or String(events[events.size() - 1]["message"]) != head_text:
			events.append({"tick": tick, "message": head_text})

		if tick == ticks:
			break

		var charge_at_entry: float = state.shotCharge
		var serving_at_entry: bool = state.serving
		var serve_attempts_at_entry: int = state.serveAttempts
		var serve_side_at_entry: String = state.serveSide
		var sets_before: String = "%d-%d" % [int(state.sets["player"]), int(state.sets["ai"])]
		var double_faults_before: int = int(state.stats["doubleFaults"]["player"]) + int(state.stats["doubleFaults"]["ai"])

		var input := _scripted_input(tick, state)
		Sim.update_match(state, FIXED_STEP, input, {})

		if serving_at_entry and not state.serving:
			strikes.append({
				"tick": tick,
				"kind": "second" if serve_attempts_at_entry > 0 else "first",
				"charge": charge_at_entry,
				"serveSide": serve_side_at_entry,
			})
		var double_faults_after: int = int(state.stats["doubleFaults"]["player"]) + int(state.stats["doubleFaults"]["ai"])
		if double_faults_after > double_faults_before:
			double_faults.append({"tick": tick, "server": serve_side_at_entry, "total": double_faults_after})
		var sets_after: String = "%d-%d" % [int(state.sets["player"]), int(state.sets["ai"])]
		if sets_after != sets_before:
			set_closures.append({
				"tick": tick,
				"sets": sets_after,
				"games": "%d-%d" % [int(state.games["player"]), int(state.games["ai"])],
			})

		if state.result != null:
			result_tick = tick + 1
			break

	var coverage: Array = _coverage(timing)
	var body: Array = header.duplicate()
	body.append_array(_constants_lines())
	body.append_array(digest_lines)
	body.append_array(trace)
	for strike in strikes:
		body.append("# strike tick=%06d kind=%s charge=%s serveSide=%s" % [
			int(strike["tick"]), String(strike["kind"]), Digest.fixed(float(strike["charge"])), String(strike["serveSide"]),
		])
	for fault in double_faults:
		body.append("# double-fault tick=%06d server=%s total=%d" % [int(fault["tick"]), String(fault["server"]), int(fault["total"])])
	for closure in set_closures:
		body.append("# set-closed tick=%06d sets=%s games=%s" % [int(closure["tick"]), String(closure["sets"]), String(closure["games"])])
	for event in events:
		body.append("# ev tick=%06d events0=\"%s\"" % [int(event["tick"]), String(event["message"])])
	body.append("# resultTick=%s" % ("none" if result_tick == null else str(int(result_tick))))
	body.append_array(timing)
	body.append_array(coverage)
	body.append("# timingFields=17 charge,active,eta,perfectWindow,advice,profile,overlap,serving,fbGrade,fbQuality,fbProfile,fbMode +shotType,queuedCharge,queuedPower,x3ai,x3player")
	var timing_sha := Digest.sha256_of_lines(timing)
	body.append("# timingSha256=%s" % timing_sha)
	var digest_sha := Digest.sha256_of_lines(digest_lines)
	var summary := "TIMING-TRACE GD PASS seed=%d ticks=%d tracedTicks=%d every=%d finalRngState=%d digestSha256=%s timingSha256=%s" % [
		seed, ticks, timing.size(), every, state.rng_state, digest_sha, timing_sha,
	]
	body.append(summary)

	# Coverage guards: a scenario that stopped exercising the read model, the
	# contact assessment or the x3 branch must fail here rather than silently
	# compare two empty traces. They are asserted on the documented scenario — a
	# short probe run is allowed to be uninteresting.
	var active_ticks := 0
	var finite_eta := 0
	var x3_smash := 0
	var x3_flagged := 0
	for line in timing:
		if line.contains(" active=1"):
			active_ticks += 1
		if not _field(line, "eta=") == "null":
			finite_eta += 1
		if line.contains("shotType=smash-x3"):
			x3_smash += 1
		if not _field(line, "x3ai=") == "0.000000":
			x3_flagged += 1
	var documented: bool = seed == DEFAULT_SEED and ticks == DEFAULT_TICKS and every == DEFAULT_EVERY and athlete == 0
	if documented:
		_check_true(active_ticks > 100, "the scenario reads an incoming ball on %d ticks" % active_ticks)
		_check_true(finite_eta > 50, "the scenario has a finite eta on %d ticks" % finite_eta)
		_check_true(x3_smash > 0, "the documented scenario reaches the x3 smash (%d ticks)" % x3_smash)
		_check_true(x3_flagged > 0, "the documented scenario arms the x3 recovery flag (%d ticks)" % x3_flagged)
	else:
		print("# note=coverage guards skipped: this is a probe run (seed=%d ticks=%d every=%d athlete=%d)" % [seed, ticks, every, athlete])

	_check_eq(eta_null_not_active, 0, "no tick has active without an eta")
	_check_eq(active_but_eta_unusable, 0, "every active tick has eta in (-0.16, 1.15)")
	_check_eq(eta_not_finite, 0, "every non-null eta is finite")
	_check_eq(window_out_of_band, 0, "every perfectWindow stays inside [timingWindowMin, timingWindowMax]")
	_check_eq(advice_off_vocabulary, 0, "every advice id is one of the reference's six")
	_check_eq(profile_off_vocabulary, 0, "every profile id is one of the reference's three")
	_check_eq(grade_off_vocabulary, 0, "every feedback grade is one of the reference's four")
	_check_eq(reset_not_restarted, 0, "every reset restarts the charge from zero")
	_check_eq(rally_reset_without_carry, 0, "every rally release carries its charge into queuedShotCharge")
	_check_eq(carry_over_cap, 0, "no queued charge exceeds the charge held at the release")
	_check_eq(reset_window_not_widened, 0, "every release widens the perfect window (the charge penalty drops)")
	if documented:
		_check_true(resets > 0, "the scenario releases a charge on %d ticks" % resets)
		_check_true(rally_resets > 0, "the scenario exercises the rally release on %d ticks" % rally_resets)
		_check_true(serve_resets > 0, "the scenario exercises the serve release on %d ticks" % serve_resets)
		_check_true(reset_active_eta > 0, "the read keeps an incoming eta across a release on %d ticks" % reset_active_eta)

	if not quiet:
		for line in coverage:
			print(line)
		print(summary)
	if String(_options["trace"]) != "":
		if not _write_trace(String(_options["trace"]), body):
			_checks += 1
			_failures += 1
			print("FAIL trace written to %s" % _options["trace"])
	else:
		for line in body:
			print(line)


## The input script, mirrored from `tools/sim-port/timing-trace.mjs`.
func _scripted_input(tick: int, state: State) -> Dictionary:
	var input: Dictionary = Sim.empty_input()
	var read: Dictionary = state.shotRead
	var eta: Variant = read["eta"]
	var early_band: bool = tick % 480 < 240
	var swing: bool = bool(read["active"]) and eta != null and float(eta) < (0.30 if early_band else 0.10)
	input["charging"] = true
	input["hit"] = (state.serving and state.shotCharge >= FULL_CHARGE) or swing
	input["analogAim"] = true
	input["aim"] = 0.7 if tick % 900 < 450 else -0.35
	input["aimY"] = 0.0
	input["moveX"] = float((int(floor(tick / 120.0)) % 3) - 1) * 0.5
	input["moveY"] = -1.0 if tick % 240 < 120 else 0.0
	return input


## One `# tm` line per tick: the timing fields the digest does not carry. Same
## field order, same spelling and same six-decimal formatting as the JS half.
func _timing_line(state: State, tick: int) -> String:
	var read: Dictionary = state.shotRead
	var eta: Variant = read["eta"]
	var feedback: Variant = state.shotFeedback
	var parts: Array = [
		"charge=%s" % Digest.fixed(state.shotCharge),
		"active=%d" % (1 if bool(read["active"]) else 0),
		"eta=%s" % ("null" if eta == null else Digest.fixed(float(eta))),
		"perfectWindow=%s" % Digest.fixed(float(read["perfectWindow"])),
		"advice=%s" % String(read["advice"]),
		"profile=%s" % String(read["profile"]),
		"overlap=%d" % (1 if bool(read["overlap"]) else 0),
		"serving=%d" % (1 if state.serving else 0),
	]
	if feedback == null:
		parts.append("fbGrade=none")
		parts.append("fbQuality=none")
		parts.append("fbProfile=none")
		parts.append("fbMode=none")
	else:
		parts.append("fbGrade=%s" % String(feedback["grade"]))
		parts.append("fbQuality=%s" % Digest.fixed(float(feedback["quality"])))
		parts.append("fbProfile=%s" % String(feedback.get("profile", "none")))
		parts.append("fbMode=%s" % _feedback_mode_id(String(feedback["mode"])))
	parts.append("shotType=%s" % String(state.ball.shotType))
	parts.append("queuedCharge=%s" % Digest.fixed(float(state.queuedShotCharge)))
	parts.append("queuedPower=%s" % Digest.fixed(float(state.queuedShotPower)))
	parts.append("x3ai=%s" % Digest.fixed(state.aiX3Recovery))
	parts.append("x3player=%s" % Digest.fixed(state.playerX3Recovery))
	return "# tm tick=%06d %s" % [tick, " ".join(parts)]


## The port stores the mode as an id (`shotMode:<mode>`); the reference stores
## `t("shotMode" + Capitalized)`. The value compared is the id
## (`godot/game/hud.gd:526-531` does this derivation for the HUD).
func _feedback_mode_id(text_id: String) -> String:
	if text_id.begins_with("shotMode:"):
		return "shotMode" + text_id.substr(9).capitalize()
	return text_id


func _constants_lines() -> Array:
	var balance: Dictionary = Frozen.balance()
	var lines: Array = []
	for name in TIMING_CONSTANTS:
		if not balance.has(name):
			lines.append("# con name=%s value=missing" % name)
			continue
		lines.append("# con name=%s value=%s" % [name, Digest.fixed(float(balance[name]))])
	return lines


## Coverage counters, the same fields and the same ordering rule as the JS half.
func _coverage(timing: Array) -> Array:
	var values := {"advice": {}, "profile": {}, "fbGrade": {}, "fbQuality": {}, "shotType": {}}
	var active_ticks := 0
	var eta_null := 0
	var eta_values: Array = []
	var overlap_ticks := 0
	var x3_smash := 0
	var x3_ai := 0
	var x3_player := 0
	for line in timing:
		if line.contains(" active=1"):
			active_ticks += 1
		if line.contains(" overlap=1"):
			overlap_ticks += 1
		if line.contains("shotType=smash-x3"):
			x3_smash += 1
		if not _field(line, "x3ai=") == "0.000000":
			x3_ai += 1
		if not _field(line, "x3player=") == "0.000000":
			x3_player += 1
		var eta_text := _field(line, "eta=")
		if eta_text == "null":
			eta_null += 1
		else:
			eta_values.append(float(eta_text))
		for key in ["advice", "profile", "fbGrade", "fbQuality"]:
			var value := _field(line, "%s=" % key)
			values[key][value] = int(values[key].get(value, 0)) + 1
		var shot_type := _field(line, "shotType=")
		if shot_type != "serve":
			values["shotType"][shot_type] = int(values["shotType"].get(shot_type, 0)) + 1
	var eta_min := "none"
	var eta_max := "none"
	if not eta_values.is_empty():
		var lo: float = float(eta_values[0])
		var hi: float = float(eta_values[0])
		for value in eta_values:
			lo = minf(lo, float(value))
			hi = maxf(hi, float(value))
		eta_min = Digest.fixed(lo)
		eta_max = Digest.fixed(hi)
	var distinct_quality: Array = []
	for value in values["fbQuality"]:
		if String(value) != "none":
			distinct_quality.append(value)
	return [
		"# cov ticks=%d activeTicks=%d etaNullTicks=%d etaFiniteTicks=%d" % [timing.size(), active_ticks, eta_null, eta_values.size()],
		"# cov etaMin=%s etaMax=%s" % [eta_min, eta_max],
		"# cov advice=%s" % _counts(values["advice"]),
		"# cov profile=%s" % _counts(values["profile"]),
		"# cov overlapTicks=%d" % overlap_ticks,
		"# cov fbGrade=%s" % _counts(values["fbGrade"]),
		"# cov fbQualityDistinct=%d" % distinct_quality.size(),
		"# cov shotTypes=%s" % ("none" if values["shotType"].is_empty() else _counts(values["shotType"])),
		"# cov x3SmashTicks=%d" % x3_smash,
		"# cov x3aiTicks=%d" % x3_ai,
		"# cov x3playerTicks=%d" % x3_player,
	]


## `value:count`, descending by count then ascending by value — the same tie-break
## on both sides, so the line is comparable too.
func _counts(table: Dictionary) -> String:
	var pairs: Array = []
	for value in table:
		pairs.append({"value": String(value), "count": int(table[value])})
	pairs.sort_custom(func(a, b):
		if int(a["count"]) != int(b["count"]):
			return int(a["count"]) > int(b["count"])
		return String(a["value"]) < String(b["value"])
	)
	var parts: Array = []
	for pair in pairs:
		parts.append("%s:%d" % [String(pair["value"]), int(pair["count"])])
	return ",".join(parts) if not parts.is_empty() else "none"


## `line.split(" ").find((p) => p.startsWith(prefix))` in the JS half.
func _field(line: String, prefix: String) -> String:
	for part in line.split(" "):
		if part.begins_with(prefix):
			return part.substr(prefix.length())
	return ""


func _trace_of(state: State) -> Dictionary:
	return {
		"serving": 1 if state.serving else 0,
		"serveAttempts": state.serveAttempts,
		"bounces": "%d/%d" % [int(state.ball.bounces["player"]), int(state.ball.bounces["ai"])],
		"points": "%d-%d" % [int(state.points["player"]), int(state.points["ai"])],
		"games": "%d-%d" % [int(state.games["player"]), int(state.games["ai"])],
		"sets": "%d-%d" % [int(state.sets["player"]), int(state.sets["ai"])],
		"rallyHits": state.rallyHits,
		"lastHitterSide": "null" if state.lastHitterSide == null else String(state.lastHitterSide),
	}


func _trace_lines(previous: Variant, current: Dictionary, tick: int) -> Array:
	if previous == null:
		var all: Array = []
		for key in TRACE_KEYS:
			all.append("%s=%s" % [key, str(current[key])])
		return ["# tr tick=%06d %s" % [tick, " ".join(all)]]
	var moved: Array = []
	for key in TRACE_KEYS:
		if str(previous[key]) != str(current[key]):
			moved.append("%s=%s" % [key, str(current[key])])
	if moved.is_empty():
		return []
	return ["# tr tick=%06d %s" % [tick, " ".join(moved)]]


## `--trace=<path>`: an absolute path, a `res://` path, or a path relative to the
## repository root (the `godot/` project's parent, which is where the JS half is
## invoked from too).
func _resolve_trace_path(path: String) -> String:
	if path.begins_with("/"):
		return path
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return ProjectSettings.globalize_path("res://").path_join("../" + path).simplify_path()


func _write_trace(path: String, lines: Array) -> bool:
	var target := _resolve_trace_path(path)
	var handle := FileAccess.open(target, FileAccess.WRITE)
	if handle == null:
		push_error("timing_feedback_test.gd: impossibile scrivere %s (errore %d)" % [target, FileAccess.get_open_error()])
		return false
	for line in lines:
		handle.store_line(line)
	handle.close()
	return true


func _scratch_state() -> State:
	return Sim.create_match_state(
		"quick", Frozen.athletes()[int(_options["athlete"])], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)


# ---------------------------------------------------------------------------
# The check contract
# ---------------------------------------------------------------------------
func _check_eq(got, expected, name: String) -> void:
	_checks += 1
	if got == expected:
		print("ok %s" % name)
	else:
		_failures += 1
		var line := "FAIL %s: expected %s, got %s" % [name, str(expected), str(got)]
		print(line)
		printerr(line)


func _check_true(got: bool, name: String) -> void:
	_check_eq(got, true, name)


func _check_close(got: float, expected: float, epsilon: float, name: String) -> void:
	_checks += 1
	if absf(got - expected) <= epsilon:
		print("ok %s" % name)
	else:
		_failures += 1
		var line := "FAIL %s: expected %s, got %s" % [name, "%.12f" % expected, "%.12f" % got]
		print(line)
		printerr(line)


func _finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		var line := "FAIL %d/%d" % [_checks - _failures, _checks]
		print(line)
		printerr(line)
		quit(1)


func _parse_args() -> void:
	for raw in OS.get_cmdline_user_args():
		if not raw.begins_with("--"):
			push_error("Argomento non riconosciuto: %s" % raw)
			continue
		var body := raw.substr(2)
		var eq := body.find("=")
		var name := body if eq == -1 else body.substr(0, eq)
		var value := "" if eq == -1 else body.substr(eq + 1)
		match name:
			"seed":
				_options["seed"] = int(value)
			"ticks":
				_options["ticks"] = int(value)
			"every":
				_options["every"] = int(value)
			"sets":
				_options["sets"] = int(value)
			"athlete":
				_options["athlete"] = int(value)
			"trace":
				_options["trace"] = value
			"quiet":
				_options["quiet"] = true
			"inject-failure":
				_options["inject_failure"] = true
			_:
				push_error("Opzione sconosciuta: --%s" % name)
