## parity_digest_gd.gd — the Godot half of the cross-engine parity comparison.
##
## Runs the ported simulation core (`res://src/sim/sim.gd`) headlessly with the
## same explicit seed and the same pure-function-of-tick input script as
## `scripts/parity-digest.mjs`, prints one digest line per sampled tick in the
## frozen field order, and (when the JavaScript reference is present) checks each
## sampled tick against it.
##
## Run:
##   env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
##     /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
##     --script res://src/sim/parity_digest_gd.gd -- --seed=12345 --ticks=1440 --every=60
##
## The JavaScript reference is read (never written, never consulted for the
## Godot values): every number the Godot side prints comes from the ported
## simulation. Reading it is how a divergence is *found* rather than asserted.
extends SceneTree

const Sim := preload("res://src/sim/sim.gd")
const Digest := preload("res://src/sim/digest.gd")
const State := preload("res://src/sim/state.gd")
const Rng := preload("res://src/sim/rng.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## `FIXED_STEP = 1 / 120` (`js/main.js:1164`), the step the JS harness advances
## per tick (`scripts/parity-digest.mjs:41`).
const FIXED_STEP := 1.0 / 120.0
const SWING_EVERY := 30
const CHARGE_FROM_TICK := 60

## Absolute `1e-3` on court units and court units per second — the *proposal* in
## `docs/wayfinder/tickets/simulation-port-boundary.md` §6, which explicitly
## says it is "not measured". This harness is the first measurement of it, so the
## tolerance is reported, not assumed to hold.
const POSITION_TOLERANCE := 1e-3

const DEFAULT_JS_REFERENCE := "res://../tools/parity/parity-digest-seed12345.json"

var _options := {"seed": 12345, "ticks": 1440, "every": 60, "quiet": false, "js": ""}


func _initialize() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	_parse_args()
	var seed: int = int(_options["seed"])
	var ticks: int = int(_options["ticks"])
	var every: int = int(_options["every"])

	# `createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1])`
	# (`scripts/parity-digest.mjs:235`).
	var state: State = Sim.create_match_state(
		"quick",
		Frozen.athletes()[0],
		Frozen.arenas()[0],
		Frozen.ai_opponents()[1],
	)
	# `state.rngState = seed; state.running = true` (`scripts/parity-digest.mjs:242-243`).
	state.rng_state = seed
	state.rng_calls = 0
	state.running = true

	var lines: Array = []
	var samples: Array = []
	var sampled_ticks: Array = []
	var previous_rng_state: int = state.rng_state
	var reconstruct_failures: Array = []

	for tick in range(0, ticks + 1):
		if tick % every == 0:
			# The counter is real here (it lives inside `nextRandom`), so the
			# digest prints the actual delta. The reconstruction is also run as a
			# cross-check: a disagreement means something wrote `rng_state`
			# outside `nextRandom`.
			var delta: int = state.rng_calls - _cumulative_at_previous(samples, state.rng_calls)
			var reconstructed: int = Rng.count_calls(previous_rng_state, state.rng_state)
			if reconstructed != delta:
				reconstruct_failures.append({"tick": tick, "counted": delta, "reconstructed": reconstructed})
			samples.append(Digest.sample_state(state, tick, delta))
			sampled_ticks.append(tick)
			lines.append(Digest.digest_line(samples[samples.size() - 1]))
			previous_rng_state = state.rng_state
		if tick == ticks:
			break
		Sim.update_match(state, FIXED_STEP, _scripted_input(tick), null)

	var body_hash: String = Digest.sha256_of_lines(lines)

	var js_path: String = String(_options["js"])
	if js_path == "":
		js_path = ProjectSettings.globalize_path(DEFAULT_JS_REFERENCE)
	var reference: Dictionary = _load_reference(js_path)

	if not bool(_options["quiet"]):
		print("# parity-digest-gd.gd seed=%d ticks=%d every=%d step=%.18f" % [seed, ticks, every, FIXED_STEP])
		print("# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)")
		print("# format=godot-side compare-js-digest")
		for line in lines:
			print(line)
		print("# js-reference=%s" % js_path)

	if reference.is_empty():
		print("# js-reference=unavailable path=%s" % js_path)
		print("PARITY-DIGEST GD FAIL seed=%d ticks=%d sampledTicks=%d every=%d finalRngState=%d digestSha256=%s" % [
			seed, ticks, lines.size(), every, state.rng_state, body_hash,
		])
		return 1

	var comparison: Dictionary = _compare(samples, reference)
	print("# compare sampledTicks=%d discreteMismatchTicks=%d floatToleranceTicks=%d firstDivergence=%s" % [
		comparison["matched"], comparison["discrete_mismatch_ticks"], comparison["float_fail_ticks"], comparison["first_divergence"],
	])
	for note in comparison["notes"]:
		print("#   %s" % note)

	var ok: bool = int(comparison["discrete_mismatch_ticks"]) == 0 \
		and int(comparison["float_fail_ticks"]) == 0 \
		and comparison["matched"] == lines.size() \
		and reconstruct_failures.is_empty() \
		and body_hash == String(reference.get("digestSha256", ""))
	if not reconstruct_failures.is_empty():
		print("# rngCalls reconstruction mismatch: %s" % str(reconstruct_failures))
	print("PARITY-DIGEST GD %s seed=%d ticks=%d sampledTicks=%d every=%d finalRngState=%d digestSha256=%s" % [
		"PASS" if ok else "FAIL", seed, ticks, lines.size(), every, state.rng_state, body_hash,
	])
	return 0 if ok else 1


func _cumulative_at_previous(samples: Array, current_cumulative: int) -> int:
	# The digest prints the *per-sample delta* (`scripts/parity-digest.mjs:255`),
	# so the running total is reconstructed from the deltas already emitted.
	var total := 0
	for sample in samples:
		total += int(sample["rngCalls"])
	return total


## `scriptedInputFor(tick)` (`scripts/parity-digest.mjs:89-98`), a pure function
## of the tick index. The field names and values are the 22-field EMPTY_INPUT of
## `js/game.js:2712-2735` plus the four scripted ones.
func _scripted_input(tick: int) -> Dictionary:
	if tick < CHARGE_FROM_TICK:
		return Sim.empty_input()
	var input: Dictionary = Sim.empty_input()
	input["charging"] = true
	input["hit"] = tick % SWING_EVERY == 0
	input["moveX"] = float(((int(floor(tick / 120.0)) % 3) - 1)) * 0.5
	input["moveY"] = -1.0 if tick % 240 < 120 else 0.0
	return input


func _load_reference(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _parse_args() -> void:
	for raw in OS.get_cmdline_user_args():
		var match_result: Dictionary = _match_arg(raw)
		if match_result.is_empty():
			push_error("Argomento non riconosciuto: %s" % raw)
			continue
		var name := String(match_result["name"])
		var value: Variant = match_result["value"]
		match name:
			"seed":
				_options["seed"] = int(value)
			"ticks":
				_options["ticks"] = int(value)
			"every":
				_options["every"] = int(value)
			"js":
				_options["js"] = String(value)
			"quiet":
				_options["quiet"] = true


func _match_arg(raw: String) -> Dictionary:
	if not raw.begins_with("--"):
		return {}
	var body := raw.substr(2)
	var eq := body.find("=")
	if eq == -1:
		return {"name": body, "value": null}
	return {"name": body.substr(0, eq), "value": body.substr(eq + 1)}


# ---------------------------------------------------------------------------
# The comparison. Discrete fields are compared exactly (they are what the
# boundary ticket calls bit-comparable); floats are compared against the
# proposed absolute 1e-3 on court units / court units per second.
# ---------------------------------------------------------------------------

## Bit-comparable fields, exactly as the ticket lists them. Compared as strings
## so that "15" and 15 are not accidentally equal.
const DISCRETE_FIELDS := [
	"rngState", "rngCalls",
	"ball.shotType", "ball.smashStage", "ball.bounces.player", "ball.bounces.ai",
	"score.points", "score.games", "score.sets",
	"score.playerScore", "score.aiScore", "score.pointsWon",
	"score.rallyHits", "score.serveAttempts", "score.longestRally",
]

## Float fields: "not bit-comparable" per the ticket — cos/sin/pow/hypot do not
## agree between engines. `vx`/`vy`/`vz` are court units per second.
const FLOAT_FIELDS := [
	"ball.x", "ball.y", "ball.z",
	"ball.vx", "ball.vy", "ball.vz",
	"ball.spin",
	"paddles.player.x", "paddles.player.y",
	"paddles.playerMate.x", "paddles.playerMate.y",
	"paddles.opponent.x", "paddles.opponent.y",
	"paddles.opponentMate.x", "paddles.opponentMate.y",
]


func _compare(gd_samples: Array, reference: Dictionary) -> Dictionary:
	var js_samples: Array = reference.get("samples", [])
	var notes: Array = []
	var matched := 0
	var discrete_mismatch_ticks := 0
	var float_fail_ticks := 0
	var first_divergence := "none"
	var seen_ticks: Dictionary = {}

	for js_sample in js_samples:
		var tick := int(js_sample["tick"])
		seen_ticks[tick] = true
		var gd_sample: Variant = null
		for candidate in gd_samples:
			if int(candidate["tick"]) == tick:
				gd_sample = candidate
				break
		if gd_sample == null:
			notes.append("tick=%06d MISSING on the Godot side" % tick)
			continue

		var discrete_ok := true
		var float_ok := true
		var worst := 0.0
		var worst_field := ""

		for field in DISCRETE_FIELDS:
			var js_text := _text(js_sample, field)
			var gd_text := _text(gd_sample, field)
			if js_text != gd_text:
				discrete_ok = false
				if first_divergence == "none":
					first_divergence = "tick=%06d field=%s js=%s gd=%s" % [tick, field, js_text, gd_text]
				notes.append("tick=%06d %s: js=%s gd=%s" % [tick, field, js_text, gd_text])

		for field in FLOAT_FIELDS:
			var diff: float = absf(float(_value(js_sample, field)) - float(_value(gd_sample, field)))
			if diff > worst:
				worst = diff
				worst_field = field
		if worst > POSITION_TOLERANCE:
			float_ok = false
			if first_divergence == "none":
				first_divergence = "tick=%06d field=%s js=%s gd=%s abs=%.9f" % [
					tick, worst_field, _text(js_sample, worst_field), _text(gd_sample, worst_field), worst,
				]

		if discrete_ok and float_ok:
			matched += 1
		if not discrete_ok:
			discrete_mismatch_ticks += 1
		if not float_ok:
			float_fail_ticks += 1
		notes.append("tick=%06d discrete=%s floats(max abs)=%.9f%s" % [
			tick, "OK" if discrete_ok else "MISMATCH", worst, "" if float_ok else " > 1e-3",
		])

	for gd_sample in gd_samples:
		if not seen_ticks.has(int(gd_sample["tick"])):
			notes.append("tick=%06d PRESENT only on the Godot side" % int(gd_sample["tick"]))

	return {
		"matched": matched,
		"discrete_mismatch_ticks": discrete_mismatch_ticks,
		"float_fail_ticks": float_fail_ticks,
		"first_divergence": first_divergence,
		"notes": notes,
	}


## Dotted-path lookup; `null` when the path does not exist.
func _value(source: Dictionary, path: String) -> Variant:
	var cursor: Variant = source
	for key in path.split("."):
		if typeof(cursor) != TYPE_DICTIONARY or not cursor.has(key):
			return null
		cursor = cursor[key]
	return cursor


func _text(source: Dictionary, path: String) -> String:
	var value: Variant = _value(source, path)
	if value == null:
		return "<absent>"
	if typeof(value) == TYPE_FLOAT:
		# JSON has a single number type: the JavaScript reference stores whole
		# numbers like `rngState` as floats, so an integral float is normalised
		# back to its integer spelling before the comparison.
		if is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0:
			return str(int(value))
		return Digest.fixed(float(value))
	return str(value)
