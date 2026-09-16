## drill_audit.gd — the port of `scripts/drill-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/modes/drill_audit.gd
##
## The reference audit's point is that the drill stays THE GAME
## (`scripts/drill-audit.mjs:14-27`): it used to be a second engine with its own
## gravity and meter, training a physics that did not exist in a match. The same
## promises, in the same order, with the same seeds:
##
##   §1 `:50-61`   no parallel physics: the drill must import the engine, and none
##                 of `ballGravity * dt`, `GRAVITY * dt`, `vz -=`, `b.z +=` may
##                 appear in it. Structural as well as behavioural — the check
##                 reads the drill's own source, as the JavaScript audit does;
##   §2 `:63-76`   the drill's state is a real match state: the athlete carries its
##                 stats, the arena carries its `wallBounce`, the mode declares
##                 itself, `pointsToWin > 1000` so one point cannot close a session;
##   §3 `:78-135`  every exercise starts a round on the first input, prepares the
##                 serve where the feed is `serve`, places an active target where
##                 the exercise has targets, closes an attempt inside 20 simulated
##                 seconds, counts it, and reports four populated HUD metrics;
##   §4 `:137-147` the target exercise keeps its opponents frozen;
##   §5 `:149-159` the exercises with rivals let them play;
##   §6 `:161-165` every declared exercise resolves, an unknown id falls back to
##                 the first;
##   §7 `:168-196` every attempt says why it went that way, and every diagnosis
##                 resolves in both languages;
##   §8 `:198-227` the squash scale is continuous and monotone, not a threshold;
##   §9 `:229-241` serving uses the engine's rules and shows the double faults.
##
## Two adaptations, both deliberate:
##
##   - The reference patches `Math.random` before constructing the drill, which is
##     what seeds the engine's `rngState` (`js/game.js:218`); the port injects the
##     same state explicitly with `AuditSupport.inject_seed`. The engine's stream
##     is therefore the same for the same seed. The TARGET placement is not: the
##     reference draws it from the same global generator
##     (`js/drill.js:155,159,160`), the port draws it from its own injected seed
##     (`godot/src/modes/drill_seed.gd`), so target positions — and nothing else —
##     differ, and no digest is compared across engines.
##   - §7's language check reads the port's locale layer (`Locale.is_resolvable`,
##     the port's own equivalent of `t(key) !== key`) instead of `js/i18n.js`.
##
## Port-only additions at the end: the two-run determinism the JavaScript cannot
## claim, and the coverage check that every exercise in the table was exercised.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const DrillTarget := preload("res://src/modes/drill_target.gd")

const Locale := preload("res://src/locale/locale.gd")

## `const STEP = 1 / 120` (`scripts/drill-audit.mjs:48`).
const STEP := 1.0 / 120.0
## `for (let frame = 0; frame < 2400 ...)` = 20 simulated seconds (`:108`).
const ATTEMPT_FRAMES := 2400

## The drill sources the §1 structural check reads. All of them: a second physics
## path could be introduced in any file of the module.
const DRILL_SOURCES: Array = [
	"res://src/modes/drill_session.gd",
	"res://src/modes/drill_target.gd",
	"res://src/modes/drill_scoring.gd",
	"res://src/modes/drill_seed.gd",
]

## `scripts/drill-audit.mjs:56`: a self-integrated ball flight is the failure.
const FORBIDDEN: Array = ["ballGravity * dt", "GRAVITY * dt", "vz -=", "b.z +="]


func _initialize() -> void:
	var audit := AuditBase.new("drill")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var athlete: Dictionary = Frozen.athletes()[0]
	var arena: Dictionary = Frozen.arenas()[0]
	var opponents: Array = Frozen.ai_opponents()

	# ── 1. Nessuna fisica parallela ─────────────────────────────────────────
	var session_source := _read("res://src/modes/drill_session.gd")
	audit.check_true(
		session_source.contains("preload(\"res://src/sim/sim.gd\")"),
		"drill/step_delegates_to_the_engine_the_drill_imports_it",
	)
	audit.check_true(
		session_source.contains("Sim.update_match("),
		"drill/the_single_line_where_a_drill_step_becomes_an_engine_step",
	)
	var forbidden_found: Array = []
	var bytes_read := 0
	for path in DRILL_SOURCES:
		var text := _read(path)
		bytes_read += text.length()
		for expression in FORBIDDEN:
			if text.contains(String(expression)):
				forbidden_found.append("%s:%s" % [path, String(expression)])
	audit.check_eq(forbidden_found.size(), 0, "drill/no_self_integrated_ball_flight_in_the_drill_sources")
	audit.report("drill_sources_bytes=%d" % bytes_read)

	# ── 2. Lo stato e' quello del match ──────────────────────────────────────
	var drill := seeded_drill("precision", athlete, arena, opponents[1], 7)
	var state = drill.state
	for field in ["arena", "athlete", "rallyEnergy", "stats", "player", "opponent", "ball"]:
		audit.check_true(state.get(field) != null, "drill/state_has_%s" % field)
	audit.check_gt(float(Dictionary(state.athlete["stats"])["control"]), 0.0, "drill/athlete_carries_its_stats")
	audit.check_gt(float(Dictionary(state.arena)["wallBounce"]), 0.0, "drill/arena_carries_the_glass_physics")
	audit.check_eq(String(state.mode), "drill", "drill/state_declares_its_mode")
	audit.check_gt(int(state.pointsToWin), 1000, "drill/a_point_cannot_close_the_session")

	# ── 3. Ogni esercizio chiude un tentativo e lo valuta ────────────────────
	var report: Array = []
	for exercise in Tables.drill_exercises():
		var id := String(exercise["id"])
		var session := seeded_drill(id, athlete, arena, opponents[1], 1234)

		# Primo `hit`: dalla posa di attesa si passa al tentativo.
		session.step(STEP, input({"hit": true}))
		audit.check_eq(session.phase, "live", "drill/%s/first_command_starts_the_attempt" % id)
		if String(exercise["feed"]) == "serve":
			audit.check_true(bool(session.state.serving), "drill/serve/the_engine_prepared_the_serve")
		else:
			var ball = session.state.ball
			audit.check_true(
				float(ball.vy) != 0.0 or float(ball.vz) != 0.0,
				"drill/%s/the_engine_put_the_ball_in_play" % id,
			)
		if bool(exercise["targets"]):
			audit.check_true(bool(session.target["active"]), "drill/%s/a_target_was_placed" % id)
			audit.check_lt(
				float(session.target["y"]), 310.0,
				"drill/%s/the_target_sits_in_the_opponents_half" % id,
			)

		var closed := false
		var frames := 0
		while frames < ATTEMPT_FRAMES and not closed:
			session.step(STEP, _player_input(session, {}))
			closed = session.phase == "result"
			frames += 1
		audit.check_true(closed, "drill/%s/an_attempt_closes_within_20_simulated_seconds" % id)
		audit.check_eq(session.attempts, 1, "drill/%s/the_attempt_was_counted_once" % id)
		audit.check_ge(session.points, 0, "drill/%s/points_are_valid" % id)
		audit.check_true(is_finite(float(session.score)), "drill/%s/the_score_is_numeric" % id)

		var metrics: Array = session.metrics()
		audit.check_eq(metrics.size(), 4, "drill/%s/the_hud_wants_four_metrics" % id)
		var populated := true
		for metric in metrics:
			populated = populated and metric.has("key") and metric.get("value") != null
		audit.check_true(populated, "drill/%s/every_metric_is_populated" % id)

		report.append("%s tentativi=%d centrati=%d punti=%d voto=%s colpi=%d energia=%.2f" % [
			id, session.attempts, session.hits, session.points, str(session.grade),
			session.rally_hits, float(session.state.rallyEnergy["player"]),
		])

	# ── 4. Il tiro al bersaglio non deve essere disturbato ───────────────────
	var frozen_drill := seeded_drill("precision", athlete, arena, opponents[3], 99)
	frozen_drill.step(STEP, input({"hit": true}))
	for frame in range(0, 400):
		frozen_drill.step(STEP, input({}))
	audit.check_true(
		float(frozen_drill.state.opponent.hitCooldown) > 0.0 and float(frozen_drill.state.opponentMate.hitCooldown) > 0.0,
		"drill/precision/opponents_stay_frozen_or_they_intercept",
	)

	# ── 5. Gli esercizi con avversario non lo congelano ──────────────────────
	for id in ["smash", "rally"]:
		var session := seeded_drill(String(id), athlete, arena, opponents[1], 55)
		session.step(STEP, input({"hit": true}))
		for frame in range(0, 240):
			session.step(STEP, input({}))
		audit.check_lt(
			float(session.state.opponent.hitCooldown), 5.0,
			"drill/%s/the_opponent_must_be_able_to_play" % String(id),
		)

	# ── 6. Ogni esercizio dichiarato deve essere raggiungibile ───────────────
	for id in ["precision", "smash", "rally", "serve"]:
		audit.check_eq(String(Tables.drill_exercise(String(id))["id"]), String(id), "drill/exercise_%s_resolves" % String(id))
	audit.check_eq(
		String(Tables.drill_exercise("inesistente")["id"]),
		String(Tables.drill_exercises()[0]["id"]),
		"drill/an_unknown_id_falls_back_to_the_first_exercise",
	)

	# ── 7. Ogni tentativo deve dire perche' e' andato cosi' ──────────────────
	var diagnoses: Dictionary = {}
	for exercise in Tables.drill_exercises():
		var id := String(exercise["id"])
		var session := seeded_drill(id, athlete, arena, opponents[1], 4321)
		session.step(STEP, input({"hit": true}))
		var frames := 0
		while frames < 3600 and session.phase != "result":
			session.step(STEP, _player_input(session, {}))
			frames += 1
		audit.check_eq(session.phase, "result", "drill/%s/attempt_closes_for_the_diagnosis_check" % id)
		audit.check_true(session.diagnosis != null, "drill/%s/a_closed_attempt_carries_a_diagnosis" % id)
		diagnoses[String(session.diagnosis)] = true
	# Le diagnosi devono esistere in entrambe le lingue.
	var unresolved: Array = []
	for lang in ["it", "en"]:
		for key in diagnoses:
			if not Locale.is_resolvable(String(key), String(lang)):
				unresolved.append("%s:%s" % [String(lang), String(key)])
	audit.check_eq(unresolved.size(), 0, "drill/every_diagnosis_resolves_in_both_languages")
	audit.report("diagnosi=%s" % JSON.stringify(diagnoses.keys()))

	# ── 8. Il rimbalzo schiacciato si valuta a scorrimento ───────────────────
	var samples: Array = []
	for seed_value in [3, 9, 15, 21, 27, 33]:
		var session := seeded_drill("precision", athlete, arena, opponents[1], int(seed_value))
		session.step(STEP, input({"hit": true}))
		var frames := 0
		while frames < ATTEMPT_FRAMES and session.phase != "result":
			session.step(STEP, _player_input(session, {"slice": int(seed_value) % 2 == 0}))
			frames += 1
		if session.impact_vz > 0.0:
			samples.append({"vz": session.impact_vz, "q": session.squash})
	audit.check_ge(samples.size(), 3, "drill/the_squash_scale_needs_three_landings")
	var out_of_scale := 0
	for sample in samples:
		if float(sample["q"]) < 0.0 or float(sample["q"]) > 1.0:
			out_of_scale += 1
	audit.check_eq(out_of_scale, 0, "drill/squash_quality_stays_in_scale")
	var ordered := samples.duplicate()
	ordered.sort_custom(func(a, b): return float(a["vz"]) < float(b["vz"]))
	var monotone := true
	for i in range(1, ordered.size()):
		monotone = monotone and float(ordered[i]["q"]) <= float(ordered[i - 1]["q"]) + 1e-9
	audit.check_true(monotone, "drill/the_squash_scale_is_monotone")
	audit.report("squash_samples=%s" % JSON.stringify(samples))

	# ── 9. Il servizio usa le regole del motore ──────────────────────────────
	var serve := seeded_drill("serve", athlete, arena, opponents[1], 777)
	serve.step(STEP, input({"hit": true}))
	audit.check_true(bool(serve.state.serving), "drill/serve/the_state_is_in_the_serve")
	audit.check_eq(String(serve.state.serveSide), "player", "drill/serve/the_player_serves_not_the_opponent")
	var serve_keys: Array = []
	for metric in serve.metrics():
		serve_keys.append(String(metric["key"]))
	audit.check_true(serve_keys.has("drillDoubleFaults"), "drill/serve/the_double_faults_are_shown")

	# ── 10. Port-only: same seed, same targets, same attempts ────────────────
	# The JavaScript cannot make this claim from the test side (its placement draws
	# from `Math.random`, `js/drill.js:155,159,160`); the port can, because the
	# placement draws from an injected seed.
	var first := _run_scripted(4242)
	var second := _run_scripted(4242)
	var third := _run_scripted(4243)
	audit.check_eq(JSON.stringify(first["targets"]), JSON.stringify(second["targets"]), "drill/same_seed_same_targets")
	audit.check_eq(JSON.stringify(first["outcomes"]), JSON.stringify(second["outcomes"]), "drill/same_seed_same_attempt_outcomes")
	audit.check_true(
		JSON.stringify(first["targets"]) != JSON.stringify(third["targets"]),
		"drill/a_different_seed_places_different_targets",
	)
	var target_in_half := true
	for target in first["targets"]:
		target_in_half = target_in_half and bool(target["active"]) and float(target["y"]) < 310.0
	audit.check_true(target_in_half, "drill/every_seeded_target_sits_in_the_opponents_half")

	# ── 11. Port-only: every declared exercise was exercised ─────────────────
	audit.check_eq(Tables.drill_exercises().size(), 4, "drill/the_exercise_table_still_has_four_entries")

	audit.report("drill=%s" % JSON.stringify(report))
	audit.report("source_sha256=%s" % JSON.stringify(Tables.source_sha256()))


# ---------------------------------------------------------------------------
# Scenario builders
# ---------------------------------------------------------------------------

## `createDrill(...)` with the seed injected the way the reference's
## `Math.random = seededRandom(seed)` patch injects it (`js/game.js:218`).
static func seeded_drill(exercise_id: String, athlete: Dictionary, arena: Dictionary, ai_profile: Dictionary, seed_value: int) -> RefCounted:
	var session := DrillSession.create(String(exercise_id), athlete, arena, ai_profile, {"seed": seed_value})
	Support.inject_seed(session.state, Support.seeded_rng_state(seed_value))
	return session


## `input(over)` (`scripts/drill-audit.mjs:41-46`): the reference's own literal,
## with the port's `empty_input` field set as the base (`Sim.empty_input()`
## carries the same keys and more).
static func input(over: Dictionary) -> Dictionary:
	var base: Dictionary = Support.vuoto()
	for key in over:
		base[key] = over[key]
	return base


## `const vicina = Math.abs(palla.y - state.player.y) < 90 && palla.z <= 108`
## (`scripts/drill-audit.mjs:110`): the scripted player swings when the ball
## arrives. `over` is applied ONLY in that branch, exactly as the reference builds
## `input(vicina ? { hit: true, charging: true, ... } : {})`.
static func _player_input(session, over: Dictionary) -> Dictionary:
	var ball = session.state.ball
	var vicina: bool = absf(float(ball.y) - float(session.state.player.y)) < 90.0 and float(ball.z) <= 108.0
	if not vicina:
		return input({})
	var merged: Dictionary = {"hit": true, "charging": true}
	for key in over:
		merged[key] = over[key]
	return input(merged)


## Two runs of one seed, reported so the log shows the targets and the attempt
## outcomes side by side.
static func _run_scripted(seed_value: int) -> Dictionary:
	var athlete: Dictionary = Frozen.athletes()[0]
	var arena: Dictionary = Frozen.arenas()[0]
	var opponents: Array = Frozen.ai_opponents()
	var session := seeded_drill("precision", athlete, arena, opponents[1], seed_value)
	var targets: Array = []
	var outcomes: Array = []
	for round in range(0, 3):
		session.step(STEP, input({"hit": true}))
		targets.append({
			"kind": String(session.target["kind"]),
			"x": "%.6f" % float(session.target["x"]),
			"y": "%.6f" % float(session.target["y"]),
			"active": bool(session.target["active"]),
		})
		var frames := 0
		while frames < ATTEMPT_FRAMES and session.phase != "result":
			session.step(STEP, _player_input(session, {}))
			frames += 1
		outcomes.append({
			"round": session.round,
			"attempts": session.attempts,
			"hits": session.hits,
			"points": session.points,
			"score": session.score,
			"diagnosis": str(session.diagnosis),
			"grade": str(session.grade),
			"frames": frames,
		})
		# The result phase closes and the next round starts on the next input.
		session.step(STEP, input({"hit": true}))
	return {"targets": targets, "outcomes": outcomes}


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
