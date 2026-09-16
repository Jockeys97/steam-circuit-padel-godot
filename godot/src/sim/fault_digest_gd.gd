## fault_digest_gd.gd — the Godot half of the full-charge serve parity comparison.
##
## The exact counterpart of `tools/sim-port/fault-digest.mjs`: same seed injection,
## same `setsToWin` override, same full-charge serve trigger and the same stop
## condition, driving the PORTED core (`res://src/sim/sim.gd`) instead of `js/game.js`.
##
## Serve trigger, a pure function of the simulated state (no `tick % N`):
##   charging: true every tick
##   hit:      state.serving and state.shotCharge >= 0.999
##
## It prints the frozen digest line shape (so `tools/parity/parity-compare.mjs` and
## `tools/sim-port/compare-digests.py` read it unchanged), plus `# tr` transition
## comment lines (one per tick where a discrete field moved) and `# ev` event lines.
## Comment lines are ignored by both comparators; they are what makes the fault tick
## and the second-serve tick visible at tick resolution.
##
## DIAGNOSTIC COMMENT LINES (ignored by both comparators; the text is the same on both
## engines so `tools/sim-port/trace-compare.py` can diff them directly):
##   `# strike tick=T kind=first|second charge=X serveSide=<player|ai>`
##   `# double-fault tick=T server=<player|ai> total=N`   (A3)
##   `# set-closed tick=T sets=p-a games=p-a`             (D2)
##
## `--athlete=<index>` selects `Frozen.athletes()[index]` (default 0 = "maestro", the
## frozen harness's athlete). It exists because A3 is a property of the server's
## `control` stat: `spread` carries `clamp(1.62 - control, 0.3, 1.0)` and the reserve
## serve carries `serveSecondSafety = 0.70`, so with maestro (1.28 -> 0.34) a full-charge
## SECOND serve can never fault, while index 1 ("pantera", 0.96 -> 0.66) reaches the
## double-fault branch. Default 0 keeps every pre-existing scenario byte-identical.
##
## Run (`tools/sim-port/fault-digest-gd.sh` does this):
##   env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
##     /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
##     --script res://src/sim/fault_digest_gd.gd -- --seed=999 --ticks=600 --every=60
extends SceneTree

const Sim := preload("res://src/sim/sim.gd")
const Digest := preload("res://src/sim/digest.gd")
const State := preload("res://src/sim/state.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## `FIXED_STEP = 1 / 120` (`js/main.js:1164`).
const FIXED_STEP := 1.0 / 120.0

## `state.shotCharge` is capped at 1 (`js/game.js:2686`); the JS runner uses the same
## threshold (`tools/sim-port/fault-digest.mjs` FULL_CHARGE).
const FULL_CHARGE := 0.999

const DEFAULT_SETS := 3

var _options := {"seed": 999, "ticks": 600, "every": 60, "sets": DEFAULT_SETS, "athlete": 0, "quiet": false}


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	_parse_args()
	var seed: int = int(_options["seed"])
	var ticks: int = int(_options["ticks"])
	var every: int = int(_options["every"])
	var sets: int = int(_options["sets"])
	var athlete: int = int(_options["athlete"])

	var athletes: Array = Frozen.athletes()
	if athlete < 0 or athlete >= athletes.size():
		push_error("fault_digest_gd.gd: --athlete=%d fuori intervallo [0, %d]" % [athlete, athletes.size() - 1])
		return 1
	var state: State = Sim.create_match_state(
		"quick",
		athletes[athlete],
		Frozen.arenas()[0],
		Frozen.ai_opponents()[1],
	)
	state.rng_state = seed
	state.rng_calls = 0
	state.running = true
	# `parity-coverage-frontier.md` §4 item 3: keep the match in the healthy regime.
	state.setsToWin = sets

	var lines: Array = []
	var trace: Array = []
	var events: Array = []
	var strikes: Array = []
	var double_faults: Array = []
	var set_closures: Array = []
	var previous_calls: int = 0
	var previous_trace: Variant = null
	var result_tick: Variant = null

	for tick in range(0, ticks + 1):
		if tick % every == 0:
			var delta: int = state.rng_calls - previous_calls
			previous_calls = state.rng_calls
			lines.append(Digest.digest_line(Digest.sample_state(state, tick, delta)))

		var current: Dictionary = _trace_of(state)
		for line in _trace_lines(previous_trace, current, tick):
			trace.append(line)
		previous_trace = current

		var head_text: String = "null" if state.events.is_empty() else String(state.events[0])
		if events.is_empty() or String(events[events.size() - 1]["message"]) != head_text:
			events.append({"tick": tick, "message": head_text})

		if tick == ticks:
			break

		# Entry snapshot: exactly the values the input script and the strike detector
		# both read, before `Sim.update_match` can move them (mirror of the JS runner).
		var charge_at_entry: float = state.shotCharge
		var serving_at_entry: bool = state.serving
		var serve_attempts_at_entry: int = state.serveAttempts
		var serve_side_at_entry: String = state.serveSide
		var sets_before: String = "%d-%d" % [int(state.sets["player"]), int(state.sets["ai"])]
		var double_faults_before: int = int(state.stats["doubleFaults"]["player"]) + int(state.stats["doubleFaults"]["ai"])

		Sim.update_match(state, FIXED_STEP, _scripted_input(tick, state, charge_at_entry), {})

		# A serve strike is the only transition that clears `state.serving`.
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

	var body_hash: String = Digest.sha256_of_lines(lines)

	if not bool(_options["quiet"]):
		print("# fault_digest_gd.gd seed=%d ticks=%d every=%d step=%.18f setsToWin=%d athlete=%d" % [seed, ticks, every, FIXED_STEP, sets, athlete])
		print("# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)")
		print("# serve-trigger=charging:true every tick, hit=(state.serving && state.shotCharge>=%.3f)" % FULL_CHARGE)
		print("# format=godot-side compare-js-fault-stream")
		for line in lines:
			print(line)
		for line in trace:
			print(line)
		for strike in strikes:
			print("# strike tick=%06d kind=%s charge=%.6f serveSide=%s" % [
				int(strike["tick"]), String(strike["kind"]), float(strike["charge"]), String(strike["serveSide"]),
			])
		for fault in double_faults:
			print("# double-fault tick=%06d server=%s total=%d" % [
				int(fault["tick"]), String(fault["server"]), int(fault["total"]),
			])
		for closure in set_closures:
			print("# set-closed tick=%06d sets=%s games=%s" % [
				int(closure["tick"]), String(closure["sets"]), String(closure["games"]),
			])
		for event in events:
			print("# ev tick=%06d events0=\"%s\"" % [int(event["tick"]), String(event["message"])])
		var first_serves := 0
		var second_serves := 0
		var second_charges: Array = []
		for strike in strikes:
			if String(strike["kind"]) == "second":
				second_serves += 1
				var charge_text := "%.6f" % float(strike["charge"])
				if not second_charges.has(charge_text):
					second_charges.append(charge_text)
			else:
				first_serves += 1
		print("# serves=%d firstServes=%d secondServes=%d" % [strikes.size(), first_serves, second_serves])
		print("# second-serve-charges=%s" % ("none" if second_charges.is_empty() else ",".join(second_charges)))
		var faults := 0
		for event in events:
			var message := String(event["message"]).to_lower()
			if message.contains("secondserve") or message.contains("second serve"):
				faults += 1
		print("# first-serve-faults=%d" % faults)
		print("# doubleFaults=%d/%d" % [
			int(state.stats["doubleFaults"]["player"]), int(state.stats["doubleFaults"]["ai"]),
		])
		var double_fault_ticks: Array = []
		for fault in double_faults:
			double_fault_ticks.append("%d:%s" % [int(fault["tick"]), String(fault["server"])])
		print("# doubleFaultTicks=%s" % ("none" if double_fault_ticks.is_empty() else ",".join(double_fault_ticks)))
		var closure_texts: Array = []
		for closure in set_closures:
			closure_texts.append("%d:%s" % [int(closure["tick"]), String(closure["sets"])])
		print("# setClosures=%s" % ("none" if closure_texts.is_empty() else ",".join(closure_texts)))
		print("# resultTick=%s" % ("none" if result_tick == null else str(int(result_tick))))

	print("PARITY-DIGEST GD PASS seed=%d ticks=%d sampledTicks=%d every=%d finalRngState=%d digestSha256=%s" % [
		seed, ticks, lines.size(), every, state.rng_state, body_hash,
	])
	return 0


## `scriptedInputFor` (`tools/sim-port/fault-digest.mjs`): charging held every tick,
## the strike requested only when the match is serving AND the charge is full.
## `charge_at_entry` is the charge the trigger predicate observes on the tick it fires.
func _scripted_input(tick: int, state: State, charge_at_entry: float) -> Dictionary:
	var input: Dictionary = Sim.empty_input()
	input["charging"] = true
	input["hit"] = state.serving and charge_at_entry >= FULL_CHARGE
	input["moveX"] = float(((int(floor(tick / 120.0)) % 3) - 1)) * 0.5
	input["moveY"] = -1.0 if tick % 240 < 120 else 0.0
	return input


# ---------------------------------------------------------------------------
# The transition trace — the same keys, the same order and the same spelling as
# `traceOf` in `tools/sim-port/fault-digest.mjs`, so the two traces diff directly.
# ---------------------------------------------------------------------------
const TRACE_KEYS := [
	"serving", "serveAttempts", "bounces", "points", "games", "sets", "rallyHits", "lastHitterSide",
]


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
			"sets":
				_options["sets"] = int(value)
			"athlete":
				_options["athlete"] = int(value)
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
