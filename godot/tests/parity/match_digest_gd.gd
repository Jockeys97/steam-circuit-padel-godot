## match_digest_gd.gd — the GODOT half of the cross-engine *match* parity proof
## (lane crew-parity). The exact counterpart of `tools/parity-godot/ref-match.mjs`.
##
## It plays a whole match with the PORTED simulation core (`res://src/sim/sim.gd`)
## from the same seed, the same athlete, the same `setsToWin` and the same
## scripted per-tick input as the JavaScript runner, and prints:
##
##   - the frozen 21-field digest line (`Digest.digest_line`, i.e. the shape of
##     `scripts/parity-digest.mjs:203-229`), so `tools/parity/parity-compare.mjs`
##     reads the stream unchanged;
##   - `# ev …` comment lines recording the events the digest line does NOT
##     print: net-cord contact, wall/glass bounce, wall-event re-arm, newest
##     in-game message, serve strike, double fault, set closure, match result.
##     The comment lines are ignored by both existing comparators.
##
## The port stores message IDS in `state.events` (`state.gd:18`) while the
## reference stores localized text, so `family=message` lines carry different
## wording by design; only their TICK numbers are compared (house convention,
## `tools/sim-port/trace-compare.py:14-17`). Every other family carries numbers
## read from state the two engines share field for field
## (`entities.gd` SimBall.netCord/postGlassSide, `state.gd` wallEventTimer,
## `stats.doubleFaults`), so those lines ARE compared value for value.
##
## Run (tools/parity-godot/run-match-gd.sh does this, one engine at a time):
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 \
##     /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
##     --script res://tests/parity/match_digest_gd.gd -- \
##     --seed=12345 --ticks=24000 --every=1 --script=frozen --athlete=0 --sets=1 --stop-at-result
##
## Argument names, defaults and semantics are the ones `ref-match.mjs` documents.
extends SceneTree

const Sim := preload("res://src/sim/sim.gd")
const Digest := preload("res://src/sim/digest.gd")
const State := preload("res://src/sim/state.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## `FIXED_STEP = 1 / 120` (`js/main.js:1164`).
const FIXED_STEP := 1.0 / 120.0
const FULL_CHARGE := 0.999
const SWING_EVERY := 30
const CHARGE_FROM_TICK := 60

var _options := {
	"seed": 12345,
	"ticks": 24000,
	"every": 1,
	"script": "frozen",
	"athlete": 0,
	"sets": -1,
	"stop_at_result": false,
	"quiet": false,
}


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	_parse_args()
	var seed: int = int(_options["seed"])
	var ticks: int = int(_options["ticks"])
	var every: int = int(_options["every"])
	var script: String = String(_options["script"])
	var athlete: int = int(_options["athlete"])
	var sets: int = int(_options["sets"])
	var stop_at_result: bool = bool(_options["stop_at_result"])

	var athletes: Array = Frozen.athletes()
	if athlete < 0 or athlete >= athletes.size():
		push_error("match_digest_gd.gd: --athlete=%d fuori intervallo [0, %d]" % [athlete, athletes.size() - 1])
		return 1
	if script != "frozen" and script != "full-charge":
		push_error("match_digest_gd.gd: --script deve essere frozen|full-charge, ricevuto \"%s\"" % script)
		return 1

	# `createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1])`
	# (`tools/parity-godot/ref-match.mjs`, `scripts/parity-digest.mjs:235`).
	var state: State = Sim.create_match_state(
		"quick",
		athletes[athlete],
		Frozen.arenas()[0],
		Frozen.ai_opponents()[1],
	)
	state.rng_state = seed
	state.rng_calls = 0
	state.running = true
	if sets > 0:
		state.setsToWin = sets

	var lines: Array = []
	var digest_lines: Array = []
	var previous_calls: int = 0
	var previous_observations: Dictionary = {"netCord": 0.0, "glass": "null", "wallTimer": 0.0}
	var last_message: String = "null"
	var result_tick: int = -1
	var result_winner: String = "-"
	var strikes: int = 0
	var double_faults: int = 0
	var set_closures: int = 0

	for tick in range(0, ticks + 1):
		var current: Dictionary = _observe(state)
		var extras: Array = []
		var message: String = "null" if state.events.is_empty() else String(state.events[0])
		if message != last_message:
			extras.append("# ev tick=%06d family=message msg=\"%s\"" % [tick, message])
			last_message = message
		for line in _event_lines(state, tick, previous_observations, current, extras):
			lines.append(line)
		previous_observations = current

		if tick % every == 0:
			var delta: int = state.rng_calls - previous_calls
			previous_calls = state.rng_calls
			var digest_line: String = Digest.digest_line(Digest.sample_state(state, tick, delta))
			digest_lines.append(digest_line)
			lines.append(digest_line)

		if tick == ticks:
			break

		# Entry snapshot: the values the input script and the strike detector both
		# read, captured before `Sim.update_match` can move them (mirror of the JS
		# runner's `chargeAtEntry` / `servingAtEntry`).
		var charge_at_entry: float = state.shotCharge
		var serving_at_entry: bool = state.serving
		var serve_attempts_at_entry: int = state.serveAttempts
		var serve_side_at_entry: String = state.serveSide
		var sets_before: String = "%d-%d" % [int(state.sets["player"]), int(state.sets["ai"])]
		var faults_before: int = int(state.stats["doubleFaults"]["player"]) + int(state.stats["doubleFaults"]["ai"])

		Sim.update_match(state, FIXED_STEP, _script_input(tick, state, charge_at_entry), null)

		# `state.serving` is cleared only by a serve strike.
		if serving_at_entry and not state.serving:
			strikes += 1
			lines.append("# ev tick=%06d family=strike serveKind=%s charge=%s serveSide=%s" % [
				tick,
				"second" if serve_attempts_at_entry > 0 else "first",
				Digest.fixed(charge_at_entry),
				serve_side_at_entry,
			])
		var faults_after: int = int(state.stats["doubleFaults"]["player"]) + int(state.stats["doubleFaults"]["ai"])
		if faults_after > faults_before:
			double_faults += 1
			lines.append("# ev tick=%06d family=double-fault server=%s total=%d" % [
				tick, serve_side_at_entry, faults_after,
			])
		var sets_after: String = "%d-%d" % [int(state.sets["player"]), int(state.sets["ai"])]
		if sets_after != sets_before:
			set_closures += 1
			lines.append("# ev tick=%06d family=set-closed sets=%s games=%s" % [
				tick, sets_after, "%d-%d" % [int(state.games["player"]), int(state.games["ai"])],
			])
		if state.result != null and result_tick == -1:
			result_tick = tick + 1
			result_winner = String(state.result["winner"])
			lines.append("# ev tick=%06d family=result winner=%s" % [result_tick, result_winner])
			if stop_at_result:
				break

	var body_hash: String = Digest.sha256_of_lines(digest_lines)

	if not bool(_options["quiet"]):
		print("# match_digest_gd.gd seed=%d ticks=%d every=%d step=%.18f" % [seed, ticks, every, FIXED_STEP])
		print("# script=%s athlete=%d setsToWin=%s stopAtResult=%s" % [
			script, athlete, str(sets) if sets > 0 else "default(1)", str(stop_at_result),
		])
		print("# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)")
		print("# format=godot-side compare-js-match-stream")
		print("# event-families=net-cord,glass,wall,message,strike,double-fault,set-closed,result (comment lines: ignored by parity-compare.mjs)")
		for line in lines:
			print(line)

	print("PARITY-DIGEST GD PASS seed=%d ticks=%d sampledTicks=%d every=%d finalRngState=%d digestSha256=%s" % [
		seed, ticks, digest_lines.size(), every, state.rng_state, body_hash,
	])
	return 0


# ---------------------------------------------------------------------------
# Event observation — the same observables, the same order, the same text as
# `ref-match.mjs` (`observe` / `eventLines`).
# ---------------------------------------------------------------------------

func _observe(state: State) -> Dictionary:
	return {
		"netCord": state.ball.netCord,
		"glass": "null" if state.ball.postGlassSide == null else String(state.ball.postGlassSide),
		"wallTimer": state.wallEventTimer,
	}


func _event_lines(state: State, tick: int, previous: Dictionary, current: Dictionary, extras: Array) -> Array:
	var lines: Array = []
	var ball = state.ball
	# A net contact sets `ball.netCord = 1` (`sim.gd:2263`, `js/game.js:2388`) and
	# it decays by `dt * 5.5` per tick, so an upward jump is the contact.
	if float(current["netCord"]) > float(previous["netCord"]) + 0.5:
		lines.append("# ev tick=%06d family=net-cord netCord=%s" % [tick, Digest.fixed(float(current["netCord"]))])
	# `postGlassSide` is written on every wall/back-wall bounce after a ground
	# bounce (`sim.gd:2235`, `js/game.js:2358`) and cleared by `hit_ball`.
	if String(current["glass"]) != String(previous["glass"]):
		lines.append("# ev tick=%06d family=glass glassSide=%s y=%s z=%s" % [
			tick, String(current["glass"]), Digest.fixed(ball.y), Digest.fixed(ball.z),
		])
	# The cooldown is re-armed exactly when a wall event fires (`sim.gd`, `js/game.js:2365`).
	if float(current["wallTimer"]) > float(previous["wallTimer"]):
		lines.append("# ev tick=%06d family=wall timer=%s" % [tick, Digest.fixed(float(current["wallTimer"]))])
	for extra in extras:
		lines.append(String(extra))
	return lines


# ---------------------------------------------------------------------------
# Scripted input — `scriptedInputFor` of both JS runners, as a pure function of
# the tick index and the state at entry.
# ---------------------------------------------------------------------------

func _script_input(tick: int, state: State, charge_at_entry: float) -> Dictionary:
	var input: Dictionary = Sim.empty_input()
	if String(_options["script"]) == "frozen":
		if tick < CHARGE_FROM_TICK:
			return input
		input["charging"] = true
		input["hit"] = tick % SWING_EVERY == 0
	else:
		input["charging"] = true
		input["hit"] = state.serving and charge_at_entry >= FULL_CHARGE
	input["moveX"] = float(((int(floor(tick / 120.0)) % 3) - 1)) * 0.5
	input["moveY"] = -1.0 if tick % 240 < 120 else 0.0
	return input


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
			"athlete":
				_options["athlete"] = int(value)
			"sets":
				_options["sets"] = int(value)
			"script":
				_options["script"] = String(value)
			"stop-at-result":
				_options["stop_at_result"] = true
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
