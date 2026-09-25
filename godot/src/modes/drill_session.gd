## drill_session.gd — the drill session: exercises, rounds, attempts, phases and
## the step that delegates every physical movement to the simulation engine.
##
## Ported from `js/drill.js:86-146` (`createDrill`), `:77-84` (`placeTeams`),
## `:168-232` (`feedBall`, `startRound`), `:234-242` (`resetDrill`), `:244-262`
## (`closeAttempt`) and `:326-463` (`updateDrill`).
##
## THE RULE THIS MODULE EXISTS TO KEEP: the drill is a WRAPPER, not a second
## engine. `js/drill.js:361` is the single line where a drill step becomes an
## engine step (`updateMatch(state, dt, input)`), and the reference audit fails
## the build if the file integrates ball flight itself
## (`scripts/drill-audit.mjs:52-61`). The port has the same shape: `step()` calls
## `Sim.update_match` and nothing else moves the ball, and
## `godot/tests/modes/drill_audit.gd` reads this file's own source and fails on
## any of the four forbidden expressions.
##
## API (a UI lane consumes this without reading its internals):
##
##   DrillSession.create(exercise_id, athlete, arena, ai_profile, opts := {})
##       -> DrillSession. `opts` carries `lineup` (`{playerMate, opponent,
##       opponentMate}`, resolved outside because resolving it needs the UI) and
##       `seed` (int) for the port's seeded target placement.
##   session.exercise -> Dictionary      the exercise row (`drill_exercises()`)
##   session.state    -> SimState        the real match state; the drill owns no
##                                      physics of its own
##   session.phase    -> String          `ready` | `live` | `result`
##   session.round, .attempts, .hits, .score, .best, .streak, .points
##   session.grade, .grade_life, .result_timer, .diagnosis
##   session.target   -> Dictionary      `{x, y, r, kind, active}`
##   session.landing  -> Variant         `{x, y}` of the last graded bounce
##   session.rally_hits, .best_rally, .last_player_shot, .impact_vz, .squash
##   session.serve_attempt, .double_faults, .running
##   session.run_limit, .run_done, .attempt_time
##       The bounded run: `run_limit` attempts (the exercise's own, `drill_objective.gd`),
##       `run_done` once they are all played. `phase` becomes `summary` at that point and
##       the session WAITS for the player (`restart_run()` retries, `reset()` leaves).
##   session.summary() -> Dictionary
##       `{attempts, hits, accuracy, score, best, grade, exercise, run_limit, run_done}` —
##       the run's own numbers, read from the same counters the HUD shows.
##   session.restart_run() -> void
##       A fresh run: the attempt counters go back to zero, `best` (the record the save
##       module persists on improvement) does not.
##   session.attempt_contact, .attempt_contact_shot, .attempt_contact_in_air,
##   session.attempt_contact_after_glass, .attempt_tactic_called, .attempt_glass,
##   session.attempt_bounced_ai, .attempt_bounced_own
##       The per-attempt observation the new objectives are graded on. Every one is the
##       engine's own mark (`rallyHits` + `lastHitterSide`, `ball.bounces`,
##       `ball.postGlassSide`, `stats.pointsWon`, `playerTeamTactic`), reset with the
##       attempt, and never a re-derivation of the ball's flight.
##   session.return_contact, .return_cleared
##       The Godot-only `return` exercise's own two measured facts: the human side
##       touched the serve, and that return cleared the net (`drill_extras.gd`).
##   session.return_ball_diagnosis() -> String
##       The measured outcome of the return ball itself, for the audit: `none`,
##       `cleared`, `over-the-back-wall`, `net-or-short` or `own-half`.
##   session.step(dt, input) -> void     one engine tick, `updateDrill`
##   session.reset() -> void             `resetDrill`
##   session.score_line() -> String      `DrillScoring.score_line`
##   session.metrics() -> Array          `DrillScoring.metrics`
##   session.athletes_for_display() -> Dictionary
##       `{playerMate, opponent, opponentMate}` — the three modelled athletes
##       the scene draws. The reference puts them on the state itself
##       (`js/drill.js:105-107` sets `playerMateAthlete` / `opponentAthlete` /
##       `opponentMateAthlete`); the port's `SimState` has no such fields (it
##       carries `lineup`, `godot/src/sim/state.gd`), so the same information is
##       read from `lineup` here instead of added to a file this lane may not
##       edit.
##
## Two behaviours the port reproduces on purpose, both named in the ticket:
##
##   - the API profile comes from the caller (`js/main.js:1639` resolves it with
##     the same `getAiForMatch` the match uses, `CareerRules.ai_for_match`);
##   - `pointsToWin` is `Number.MAX_SAFE_INTEGER` (`js/drill.js:97`), so a single
##     point cannot end a session. The pointer below is the reference's own
##     constant, not a rounder number.
##
## THE GODOT-ONLY FIFTH EXERCISE. `return` (`godot/src/modes/drill_extras.gd`) is not in
## the frozen reference table, so its branch in `step()` is the port's, not a port of
## anything: the opponents serve (`opponentServe`), the attempt is the human side's return,
## and it is graded on what the ENGINE measured — the ball clearing the net and bouncing
## inside the opponents' court. Nothing here infers why a return failed; the diagnosis
## names the measured outcome (an opponent ace, the net, out, or a point closed before the
## bounce). The reference's four exercises are untouched by it.
##
## A FRESH HUMAN CONTACT, THEN A LEGAL OUTCOME. Every objective branch — the reference's
## target exercise included — grades the ball only after the HUMAN side has touched it this
## attempt (`attempt_contact`, set from `rallyHits` rising with `lastHitterSide ==
## "player"`) and reads the landing off the engine's own substep marks instead of the
## drill's own z-crossing sample: `handle_ground_bounce` leaves `ball.bounces[side]` set
## across the sub-step that produced the bounce and `hit_ball` clears it on the next strike,
## so the mark is the engine's statement that the ball landed. The reference's target
## exercise used to grade ANY detected landing, which counted the opponents' own feed coming
## down in their half as the player's hit; the gate is what removes that credit, and
## `drill_audit.gd` still closes every one of its four rows.
##
## AND A BOUND. A run is `run_limit` attempts (8 by default, `drill_objective.gd`); the last
## close moves the session to `summary` instead of opening another round, and an attempt
## that never resolves times out at `ATTEMPT_TIMEOUT` with a measured diagnosis rather than
## running forever.
extends RefCounted

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillSeed := preload("res://src/modes/drill_seed.gd")
const DrillTarget := preload("res://src/modes/drill_target.gd")
const DrillScoring := preload("res://src/modes/drill_scoring.gd")
const DrillObjective := preload("res://src/modes/drill_objective.gd")

## `Number.MAX_SAFE_INTEGER` (`js/drill.js:97`): the "a point cannot close the
## session" target. The audit asserts `pointsToWin > 1000`
## (`scripts/drill-audit.mjs:75`); this is the reference's exact value.
const MAX_SAFE_INTEGER: int = 9007199254740991

## The score a session starts with and the pause the result phase lasts
## (`js/drill.js:261`).
const RESULT_PAUSE: float = 1.6
const GRADE_LIFE: float = 1.2

## How long one attempt may stay live before the drill closes it as a timeout. The
## reference has no such bound (a drill runs until the player leaves); with a fixed run of
## 8 attempts a stalled ball would strand the run, so the attempt is closed and named.
## 25 simulated seconds is longer than any real drill point (the audits' own scripted
## attempt budget is 20) and shorter than a player's patience.
const ATTEMPT_TIMEOUT: float = 25.0

## The human shots the NET-PLAY exercise accepts as an attacking net shot. These are the
## engine's own `ball.shotType` values (`sim.gd`'s `hit_ball` branches), not a parallel
## vocabulary: a volley is a contact made before the ball bounced, and the rest are the
## overhead family the reference's own `choose_computer_shot` calls net play.
const NET_PLAY_SHOTS: Array = ["bandeja", "vibora", "cut-volley", "smash-x2", "smash-x3", "smash-flat"]
## What a return that the OPPONENTS had to play back pays. A return they volley never
## landed, so there is no measured depth to read: the flat tier says "playable return",
## below the deep bonus of a measured landing (`DrillTarget.return_depth`).
const RETURN_PLAYED_TIER: float = 0.85
## The pair tactics the doubles exercise accepts, by the id `Sim.set_player_team_tactic`
## stores from `input.teamTactic` (`game/input_map.gd::PAD_TACTICS`). `balanced` is the
## state's own default, so it is NOT a call: only a change away from the value the attempt
## started on counts, which is what `attempt_tactic_start` is for.
const TACTIC_IDS: Array = ["attack", "defend", "staggered"]

var exercise: Dictionary = {}
var state: Object = null
var gen: RefCounted = null
var seed_value: int = 0

var phase: String = "ready"
var round: int = 0
var attempts: int = 0
var hits: int = 0
var score: int = 0
var best: int = 0
var streak: int = 0
var points: int = 0
var grade: Variant = null
var grade_life: float = 0.0
var result_timer: float = 0.0
var target: Dictionary = {}
var landing: Variant = null
var rally_hits: int = 0
var best_rally: int = 0
var last_player_shot: Variant = null
var diagnosis: Variant = null
var impact_vz: float = 0.0
var squash: float = 0.0
var serve_attempt: int = 0
var double_faults: int = 0
var running: bool = true
## The `return` exercise's own two measured facts, reset with every round.
var return_contact: bool = false
var return_cleared: bool = false

## The bounded run: how many attempts it lasts and whether it has finished.
var run_limit: int = DrillObjective.DEFAULT_ATTEMPTS
var run_done: bool = false
## How long the live attempt has been running, for the stalled-attempt bound.
var attempt_time: float = 0.0

## The per-attempt observation every objective branch is graded on. All of it is the
## engine's own mark, and all of it is cleared by `start_round()`/`reset()` — a stale mark
## from the previous attempt must never grade the next one.
var attempt_contact: bool = false
var attempt_contact_shot: String = ""
## Which SIDE struck on the frame just observed, and whether that strike was the controlled
## human's own paddle (`"player"` / `"ai"` / `""`). Set by `_observe_after` on the step that
## produced a contact and cleared on the next one, so a branch can ask "did the human just
## strike?" without re-deriving it from a flag that latches for the whole attempt.
var attempt_contact_fresh_side: String = ""
var attempt_contact_in_air: bool = false
var attempt_contact_after_glass: bool = false
var attempt_tactic_called: bool = false
var attempt_tactic_start: String = "balanced"
var attempt_glass: bool = false
var attempt_bounced_ai: bool = false
var attempt_bounced_own: bool = false
## True while the LAST contact of the attempt belongs to the human side and the ball has
## bounced in the opponents' half since: the "his shot landed" mark the net and doubles
## exercises ask for. Cleared by any later contact, so an opponent's return can never be
## credited as the player's own landing.
var attempt_landed_ai_after_contact: bool = false
var _last_contact_human: bool = false


## `createDrill(exerciseId, athlete, arena, aiProfile, lineup)`
## (`js/drill.js:86-146`).
static func create(exercise_id: String, athlete: Dictionary, arena: Dictionary, ai_profile: Dictionary, opts: Dictionary = {}) -> RefCounted:
	var session := new()
	session.exercise = Tables.drill_exercise(exercise_id)
	session.seed_value = int(opts.get("seed", 0))
	session.gen = DrillSeed.from_seed(session.seed_value)
	session.run_limit = DrillObjective.attempts_for(String(session.exercise.get("id", "")))
	session.state = Sim.create_match_state(
		"drill", athlete, arena, ai_profile, 0, {"lineup": opts.get("lineup", {})}
	)
	var st = session.state
	# A punti, con un traguardo inarrivabile: in allenamento nessun punto deve
	# chiudere qualcosa, e cosi' la macchina di game/set/tie-break non entra mai
	# in gioco.
	st.running = true
	st.serving = false
	st.pointPause = 0.0
	st.scoring = "points"
	st.pointsToWin = MAX_SAFE_INTEGER
	st.lastHitterSide = "ai"
	session._place_teams()
	session.target = DrillTarget.empty()
	session.landing = null
	session.grade = null
	session.diagnosis = null
	session.attempt_tactic_start = String(session.state.playerTeamTactic)
	return session


## `placeTeams(state)` (`js/drill.js:77-84`): player at the back, the pair at the
## net. Deterministic, and part of the scenario.
##
## The HUMAN pair's own two rows follow the exercise's `formation` (`drill_extras.gd`): the
## reference's placement when the row declares none, the net when the exercise is the net
## play drill, the back when it is the glass recovery. The opponents keep the reference's
## placement in every case — the drill changes where the human stands, never where the feed
## comes from.
func _place_teams() -> void:
	var court: Dictionary = Frozen.court()
	var mid_x: float = (float(court["left"]) + float(court["right"])) / 2.0
	var net_y := float(court["netY"])
	var top := float(court["top"])
	var bottom := float(court["bottom"])
	var formation := String(exercise.get("formation", ""))
	var player_y: float = net_y + 150.0
	var mate_y: float = net_y + 120.0
	if formation == "net":
		player_y = net_y + 60.0
		mate_y = net_y + 118.0
	elif formation == "deep":
		player_y = bottom - 78.0
		mate_y = net_y + 150.0
	_place(state.player, mid_x, player_y)
	_place(state.playerMate, mid_x + 190.0, mate_y)
	_place(state.opponent, mid_x - 150.0, top + 120.0)
	_place(state.opponentMate, mid_x + 150.0, top + 150.0)


func _place(paddle, x: float, y: float) -> void:
	paddle.x = x
	paddle.y = y
	paddle.hitCooldown = 0.0


## The three modelled athletes the scene draws, read from the state's lineup.
func athletes_for_display() -> Dictionary:
	var lineup: Dictionary = state.lineup if state.lineup is Dictionary else {}
	return {
		"playerMate": lineup.get("playerMate", state.athlete),
		"opponent": lineup.get("opponent", state.athlete),
		"opponentMate": lineup.get("opponentMate", state.athlete),
	}


## `feedBall(drill)` (`js/drill.js:173-217`): the ball is put in play BY the
## engine (`forceContact`), so what arrives is a real shot of the game — with its
## dispersion, its spin and the physics of the chosen arena.
func _feed_ball() -> void:
	var court: Dictionary = Frozen.court()
	if String(exercise.get("feed", "")) == "serve":
		state.serveAttempts = 0
		state.serving = true
		# Chi batte lo dichiara l'esercizio: al servizio la palla la mette in gioco
		# il giocatore, alla risposta l'avversario. In entrambi i casi e'
		# `prepareServe` a costruire la posa e `updateMatch` a gestire carica, fallo
		# e seconda palla, cosi' l'esercizio usa le regole vere.
		state.serveSide = "ai" if bool(exercise.get("opponentServe", false)) else "player"
		Sim.prepare_serve(state)
		state.lastHitterSide = null
		landing = null
		return
	var feeder = state.opponent
	var mid_x: float = (float(court["left"]) + float(court["right"])) / 2.0
	var lob := String(exercise.get("feed", "")) == "lob"
	state.ball.x = feeder.x
	state.ball.y = feeder.y + 10.0
	state.ball.z = 96.0 if lob else 70.0
	state.ball.vx = 0.0
	state.ball.vy = 0.0
	state.ball.vz = 0.0
	state.ball.bounces = {"player": 0, "ai": 0}
	state.ball.serveInFlight = false
	state.ball.serveTouchedNet = false
	state.ball.netFaultOwner = null
	state.ball.crossedNet = false
	# `js/drill.js:202` resets this to `null`; the port's `SimBall.shotType` is a
	# typed `String` (`godot/src/sim/entities.gd:70`) and the simulation itself
	# never restores it to null, so the empty string is the port's "no shot yet".
	state.ball.shotType = ""
	state.ball.smashStage = 0
	state.ball.backspin = 0.0
	state.ball.topspin = 0.0
	feeder.hitCooldown = 0.0
	var mira: float = clampf(
		(mid_x - feeder.x) / ((float(court["right"]) - float(court["left"])) / 2.0), -1.0, 1.0
	)
	# Palla alta e molle a meta' campo per il lob (smashabile); piatto pieno per
	# il feed normale.
	if lob:
		Sim.hit_ball(state, feeder, 0.62, false, true, mira, false, "lob")
	else:
		Sim.hit_ball(state, feeder, 0.86, false, true, mira, false, "auto")
	state.lastHitterSide = "ai"
	landing = null


## `startRound(drill)` (`js/drill.js:219-232`).
func start_round() -> void:
	if bool(exercise.get("targets", false)):
		target = DrillTarget.place(gen, exercise, round)
	else:
		target["active"] = false
	phase = "live"
	grade = null
	grade_life = 0.0
	rally_hits = 0
	last_player_shot = null
	diagnosis = null
	impact_vz = 0.0
	squash = 0.0
	serve_attempt = 0
	return_contact = false
	return_cleared = false
	# The attempt's own observations, cleared HERE and never carried over: a mark left by
	# the previous attempt would grade this one.
	attempt_time = 0.0
	attempt_contact = false
	attempt_contact_shot = ""
	attempt_contact_in_air = false
	attempt_contact_after_glass = false
	attempt_tactic_called = false
	attempt_tactic_start = String(state.playerTeamTactic)
	attempt_glass = false
	attempt_bounced_ai = false
	attempt_bounced_own = false
	attempt_landed_ai_after_contact = false
	_last_contact_human = false
	# The player's own serve IS the human side's contact for the serving exercises: the
	# engine builds the pose, the human plays it (`_feed_ball`).
	if String(exercise.get("feed", "")) == "serve" and not bool(exercise.get("opponentServe", false)):
		attempt_contact = true
		attempt_contact_shot = "serve"
	_feed_ball()


## `resetDrill(drill)` (`js/drill.js:234-242`).
func reset() -> void:
	phase = "ready"
	grade = null
	grade_life = 0.0
	landing = null
	target["active"] = false
	result_timer = 0.0
	# The `return` exercise's own two marks are part of the attempt, so they go with the
	# rest of it.
	return_contact = false
	return_cleared = false
	attempt_time = 0.0
	attempt_contact = false
	attempt_contact_shot = ""
	attempt_contact_in_air = false
	attempt_contact_after_glass = false
	attempt_tactic_called = false
	attempt_glass = false
	attempt_bounced_ai = false
	attempt_bounced_own = false
	attempt_landed_ai_after_contact = false
	_place_teams()


## `closeAttempt(drill, { inZone, tier, diagnosis })` (`js/drill.js:249-262`).
## The execution grade is not invented here: it is `state.shotFeedback`, the
## engine's own assessment.
func close_attempt(in_zone: bool, tier: float, why: Variant = null) -> void:
	if phase == "summary" or phase == "result":
		return
	var points_scored: int = DrillScoring.attempt_points(tier, grade if grade != null else "good")
	points = points_scored
	attempts += 1
	if in_zone:
		hits += 1
	score += points_scored
	streak = streak + 1 if in_zone else 0
	best = DrillScoring.best_after(best, score)
	diagnosis = why
	round += 1
	# The bounded run: the last attempt closes the RUN, and the session waits for the
	# player instead of opening another round. Every earlier attempt keeps the reference's
	# own result pause.
	if attempts >= run_limit:
		run_done = true
		phase = "summary"
		result_timer = 0.0
	else:
		phase = "result"
		result_timer = RESULT_PAUSE


## One run's own numbers, read from the same counters the HUD shows. `accuracy` is the
## fraction of attempts that closed in the zone (0.0 when nothing was attempted yet).
func summary() -> Dictionary:
	return {
		"exercise": String(exercise.get("id", "")),
		"attempts": attempts,
		"hits": hits,
		"accuracy": 0.0 if attempts <= 0 else float(hits) / float(attempts),
		"score": score,
		"best": best,
		"grade": grade,
		"run_limit": run_limit,
		"run_done": run_done,
	}


## A fresh run on the same exercise: the attempt counters go back to zero, `best` — the
## record the save module persists on improvement — does not.
func restart_run() -> void:
	attempts = 0
	hits = 0
	score = 0
	streak = 0
	points = 0
	round = 0
	best_rally = 0
	double_faults = 0
	run_done = false
	running = true
	reset()
	start_round()


## `updateDrill(drill, dt, input)` (`js/drill.js:326-463`).
func step(dt: float, input: Dictionary) -> void:
	if not running:
		return
	grade_life = maxf(0.0, grade_life - dt)
	var hit_input: bool = bool(input.get("hit", false))

	if phase == "ready":
		if hit_input:
			start_round()
		return

	if phase == "result":
		result_timer = maxf(0.0, result_timer - dt)
		if hit_input or result_timer == 0.0:
			reset()
			start_round()
		return

	if phase != "live":
		return

	attempt_time += dt
	# Gli avversari restano immobili solo dove l'esercizio lo richiede.
	if not bool(exercise.get("rivals", false)):
		state.opponent.hitCooldown = Tables.drill_freeze()
		state.opponentMate.hitCooldown = Tables.drill_freeze()

	# Le misure PRIMA del passo: dopo l'impatto il motore ha gia' riflesso la velocita' e
	# azzerato i marchi del rimbalzo, quindi lo stato del contatto va letto qui.
	var obs := _observe_before()
	Sim.update_match(state, dt, input)
	_observe_after(obs)
	_grade_live(obs)
	if phase == "live" and attempt_time >= ATTEMPT_TIMEOUT:
		_consuma_esito()
		close_attempt(false, 0.0, "drillWhyTimeout")


## The attempt's own measurements, taken BEFORE the engine step: the counters a branch
## diffs against, the ball's pre-impact height and velocity, and the engine's own marks
## (`ball.bounces`, `ball.postGlassSide`) as they stood at the moment of a contact.
func _observe_before() -> Dictionary:
	var ball = state.ball
	return {
		"rally": int(state.rallyHits),
		"points": int(state.stats["pointsWon"]["player"]),
		"faults": int(state.stats["doubleFaults"]["player"]),
		"ace_ai": int(state.stats["aces"]["ai"]),
		"ace_player": int(state.stats["aces"]["player"]),
		"z": float(ball.z),
		"vz": float(ball.vz),
		"active_key": String(state.activePlayerKey),
		"feedback_life": float((state.shotFeedback as Dictionary).get("life", 0.0)) if state.shotFeedback is Dictionary else 0.0,
		"bounces": (ball.bounces as Dictionary).duplicate() if ball.bounces is Dictionary else {"player": 0, "ai": 0},
		"glass": ball.postGlassSide,
	}


## The observations the engine produced on this step, all of them its own marks. A new
## contact closes the previous sequence first, so a bounce mark can only ever be attributed
## to whoever struck the ball last.
func _observe_after(obs: Dictionary) -> void:
	# Nessun contatto su questo passo finche' il blocco qui sotto non ne trova uno: il ramo
	# della risposta legge questo campo per sapere se il giocatore ha appena colpito.
	attempt_contact_fresh_side = ""
	if obs["glass"] != null and String(obs["glass"]) == "player":
		attempt_glass = true
	var glass_now: Variant = state.ball.postGlassSide
	if glass_now != null and String(glass_now) == "player":
		attempt_glass = true

	# Il voto arriva dal motore, ma solo quello del giocatore: `shotFeedback` e'
	# condiviso.
	var feedback: Variant = state.shotFeedback
	if feedback is Dictionary:
		var key := String((feedback as Dictionary).get("paddleKey", ""))
		if (feedback as Dictionary).get("grade") != null and (key == "player" or key == String(state.activePlayerKey)):
			grade = (feedback as Dictionary)["grade"]
			grade_life = GRADE_LIFE

	if int(state.rallyHits) > int(obs["rally"]):
		rally_hits += 1
		best_rally = maxi(best_rally, rally_hits)
		# Un contatto nuovo chiude sempre la sequenza precedente.
		attempt_landed_ai_after_contact = false
		# Chi ha colpito SU QUESTO passo: lato (identita' di squadra) e azione del giocatore
		# controllato sono due domande diverse, e il ramo della risposta legge la seconda.
		attempt_contact_fresh_side = "ai" if state.lastHitterSide == "ai" else ""
		_last_contact_human = false
		# Il tipo di colpo del lato umano resta quello del riferimento: `lastHitterSide` e'
		# identita' di SQUADRA (`player` copre anche il compagno), e gli esercizi del
		# riferimento leggono cosi' il loro `lastPlayerShot`. L'AZIONE del giocatore
		# controllato e' un'altra domanda, e la risponde `_human_contact_key`.
		if state.lastHitterSide == "player":
			# Il tipo di colpo va preso *ora*, mentre l'ha appena battuto il giocatore.
			last_player_shot = state.ball.shotType
		var contact_key := _human_contact_key(obs)
		if contact_key != "" and contact_key == String(obs["active_key"]):
			attempt_contact_fresh_side = "player"
			_last_contact_human = true
			attempt_contact = true
			attempt_contact_shot = String(state.ball.shotType)
			# In aria = la palla non era ancora rimbalzata nella meta' umana al momento
			# dell'impatto: il motore azzera i rimbalzi colpendo, quindi vanno letti prima.
			attempt_contact_in_air = int((obs["bounces"] as Dictionary).get("player", 0)) == 0
			attempt_contact_after_glass = attempt_glass

	if _rimbalzo_del_lato("ai"):
		attempt_bounced_ai = true
		if _last_contact_human and state.lastHitterSide == "player":
			attempt_landed_ai_after_contact = true
	if _rimbalzo_del_lato("player"):
		attempt_bounced_own = true

	# La tattica di coppia: il motore la registra in `playerTeamTactic`. Solo un CAMBIO
	# rispetto all'inizio del tentativo e' una chiamata.
	if TACTIC_IDS.has(String(state.playerTeamTactic)) and String(state.playerTeamTactic) != attempt_tactic_start:
		attempt_tactic_called = true

	var ball = state.ball
	if float(obs["z"]) > 0.0 and float(ball.z) <= 0.0:
		impact_vz = absf(float(obs["vz"]))
		squash = DrillTarget.squash_quality(impact_vz)


## The CONTROLLED human paddle that just struck the ball, or `""`. Two facts, both the
## engine's:
##
##   - the strike is FRESH. `show_shot_feedback` writes `life = 0.78` on a controlled strike
##     and `update_match` only ever decrements it, so a `life` that went UP since the
##     previous tick proves this tick's hit wrote the feedback. Without that test an
##     opponent's contact would leave the human's earlier feedback in place and the drill
##     would credit a shot nobody made.
##   - the paddle that struck is the CONTROLLED one. `paddleKey` identifies the paddle
##     (`show_shot_feedback`), and `controlled` is set on the paddle the human is driving.
##     `lastHitterSide == "player"` alone is team identity: it is also true when the
##     player's PARTNER strikes, which is not a human action at all.
func _human_contact_key(obs: Dictionary) -> String:
	if not (state.shotFeedback is Dictionary):
		return ""
	var feedback: Dictionary = state.shotFeedback
	if float(feedback.get("life", 0.0)) <= float(obs.get("feedback_life", 0.0)):
		return ""
	var key := String(feedback.get("paddleKey", ""))
	if key == "":
		return ""
	var struck = state.paddle(key)
	if struck == null or not bool(struck.controlled):
		return ""
	return key


## The objective branches, in the order they are asked. Every one of them requires a fresh
## HUMAN contact (`attempt_contact`) and reads the OUTCOME off the engine's own marks; none
## of them moves the ball, and none credits an opponent's contact as the player's.
func _grade_live(obs: Dictionary) -> void:
	if bool(exercise.get("targets", false)):
		# Solo un rimbalzo nella meta' avversaria, DOPO che il lato umano ha colpito, e'
		# un tiro al bersaglio: il marchio del motore sopravvive al sotto-passo.
		if attempt_landed_ai_after_contact:
			landing = {"x": float(state.ball.x), "y": float(state.ball.y)}
			if DrillTarget.in_opponents_half(float(state.ball.y)):
				var graded := DrillTarget.tier(target, squash, float(state.ball.x), float(state.ball.y))
				close_attempt(bool(graded["in_zone"]), float(graded["tier"]), graded["diagnosis"])
			else:
				close_attempt(false, 0.0, "drillWhyOwnHalf")
		elif _punto_chiuso():
			_consuma_esito()
			close_attempt(false, 0.0, "drillWhyMissed")
		return

	var id := String(exercise.get("id", ""))

	if id == "return":
		_step_return(int(obs["ace_ai"]), int(obs["rally"]), float(obs["z"]), float(obs["vz"]))
		return

	if id == "glass_recovery":
		_step_glass_recovery()
		return

	if id == "net_play":
		_step_net_play()
		return

	if id == "doubles_tactics":
		_step_doubles_tactics(obs)
		return

	if String(exercise.get("id", "")) == "serve":
		# Il doppio fallo lo dichiara il motore; la seconda palla si legge da
		# `serveAttempts`.
		serve_attempt = int(state.serveAttempts)
		if int(state.stats["doubleFaults"]["player"]) > int(obs["faults"]):
			double_faults += 1
			_consuma_esito()
			close_attempt(false, 0.0, "drillWhyDoubleFault")
			return
		if not _punto_chiuso():
			return
		# Servizio andato a segno: la prima palla vale piena, la seconda meno,
		# l'ace di piu'.
		var ace: bool = int(state.stats["aces"]["player"]) > int(obs["ace_player"])
		var prima: bool = serve_attempt == 0
		var tier: float = 1.5 if ace else (1.0 if prima else 0.6)
		_consuma_esito()
		state.stats["aces"]["player"] = 0
		close_attempt(
			true, tier,
			"drillWhyAce" if ace else ("drillWhyFirstServe" if prima else "drillWhySecondServe"),
		)
		return

	if not _punto_chiuso():
		return

	if String(exercise.get("id", "")) == "smash":
		# Lo x2 e lo x3 valgono se sopravvivono: l'esito lo decide il motore.
		var vinto: bool = int(state.stats["pointsWon"]["player"]) > int(obs["points"])
		var colpo: Variant = last_player_shot
		var smashato: bool = colpo == "smash-x2" or colpo == "smash-x3"
		var tier: float = 1.4 if colpo == "smash-x3" else (1.0 if colpo == "smash-x2" else 0.35)
		_consuma_esito()
		var why: String = "drillWhyNoSmash"
		# Il nome del fallimento resta quello del riferimento (`drillWhyNoSmash`): la tabella
		# della lingua e' generata da `js/i18n.js` e questo ramo non introduce id nuovi, cosi'
		# `tests/modes/drill_audit.gd` continua a leggerli dalla tabella del riferimento.
		if smashato:
			why = ("drillWhyX3" if colpo == "smash-x3" else "drillWhyX2") if vinto else "drillWhyDefended"
		var completed := vinto and smashato and attempt_contact
		close_attempt(completed, tier if completed else 0.2, why)
		return

	# Scambio: il tentativo dura quanto il punto, e il punteggio premia la
	# lunghezza invece del singolo colpo.
	var tenuto: int = rally_hits
	var energia: float = float(state.rallyEnergy.get("player", 1.0))
	_consuma_esito()
	var why_rally: String = "drillWhyRallyShort" if tenuto < 2 \
		else ("drillWhyDrained" if energia < Frozen.bal("rallyEnergyFloor") + 0.2 else "drillWhyRallyHeld")
	close_attempt(attempt_contact and tenuto >= 4, minf(1.5, 0.25 + float(tenuto) * 0.18) if attempt_contact else 0.0, why_rally)


## The `glass_recovery` branch (`drill_extras.gd`): the human pair is at the back, the ball
## is played out, and the attempt is the recovery OFF THE HUMAN'S OWN GLASS. Success needs
## three measured facts in order — the ball touched that glass (`ball.postGlassSide`, set by
## the engine's own wall handler), the human then contacted it, and that contact came down in
## the opponents' half. The feed's own landing is no contact of the player's and never grades.
func _step_glass_recovery() -> void:
	if attempt_landed_ai_after_contact and attempt_contact_after_glass:
		_consuma_esito()
		close_attempt(true, _landing_tier(), "drillWhyGlassIn")
		return
	if not _punto_chiuso():
		return
	_consuma_esito()
	if not attempt_contact:
		close_attempt(false, 0.0, "drillWhyGlassMissed")
	elif not attempt_contact_after_glass:
		close_attempt(false, 0.0, "drillWhyGlassEarly")
	else:
		close_attempt(false, 0.0, "drillWhyGlassOut")


## The `net_play` branch (`drill_extras.gd`): the human pair starts at the net and the
## attempt is an ATTACKING BALL — a contact made before the ball bounced on the player's own
## side (a volley) or one of the engine's own overhead shot types (`bandeja`, `vibora`, the
## smash family) — that lands in the opponents' half. Both halves of the rule are engine
## measurements: the pre-impact bounce mark, `ball.shotType`, and `ball.bounces["ai"]`.
func _step_net_play() -> void:
	if attempt_landed_ai_after_contact:
		var attacking: bool = attempt_contact_in_air or NET_PLAY_SHOTS.has(attempt_contact_shot)
		_consuma_esito()
		if attacking:
			close_attempt(true, _landing_tier(), "drillWhyNetIn")
		else:
			close_attempt(false, 0.0, "drillWhyNoNetShot")
		return
	if not _punto_chiuso():
		return
	_consuma_esito()
	close_attempt(false, 0.0, "drillWhyNetMissed" if attempt_contact else "drillWhyNoContact")


## The `doubles_tactics` branch (`drill_extras.gd`): the pair has to CALL a tactic while the
## ball is live (a real change in `playerTeamTactic`) and then close the attempt legally —
## either by winning the point or by the player's own shot landing in the opponents' half.
## The tactic is the engine's own record, the landing is the engine's own bounce mark, and
## the point is the engine's own counter: nothing here reads a key press directly.
func _step_doubles_tactics(obs: Dictionary) -> void:
	var won: bool = int(state.stats["pointsWon"]["player"]) > int(obs["points"])
	if _punto_chiuso():
		_consuma_esito()
		if not attempt_contact:
			close_attempt(false, 0.0, "drillWhyNoContact")
		elif not attempt_tactic_called:
			close_attempt(false, 0.2 if won else 0.0, "drillWhyNoTactic")
		elif won:
			close_attempt(true, 1.4, "drillWhyTacticIn")
		else:
			close_attempt(false, 0.2 if attempt_landed_ai_after_contact else 0.0, "drillWhyTacticLost")
		return
	# The exercise's own success is reachable before the point closes: a called tactic and a
	# legal ball in the opponents' half is what it asks for. The attempt ends once, here.
	if attempt_contact and attempt_tactic_called and attempt_landed_ai_after_contact:
		_consuma_esito()
		close_attempt(true, 1.0, "drillWhyTacticIn")


## How deep a successful attacking ball landed in the opponents' half, on the same measured
## scale the `return` exercise uses (`DrillTarget.return_depth`): the tier is read off the
## landing the engine produced, not judged.
func _landing_tier() -> float:
	return float(DrillTarget.return_depth(float(state.ball.y))["tier"])


## The `return` exercise's branch (`drill_extras.gd`): the opponents served, and the
## attempt is the human side's return. It succeeds when the return CLEARED THE NET and
## BOUNCED INSIDE THE OPPONENTS' COURT — both read off the engine's own ball — and fails
## when the point closed without that bounce. Every diagnosis is a measured fact: an
## opponent ace (`aces.ai`, counted by the engine), the net (the return never crossed),
## out (it crossed and left the court), or a point closed before the bounce. No cause is
## named, because nothing here measures one.
func _step_return(ace_ai_prima: int, colpi_prima: int, z_prima: float, vz_prima: float) -> void:
	var ball = state.ball
	# L'altezza e la velocita' pre-impatto sono gia' state misurate da `_observe_after` su
	# questo stesso passo (`impact_vz`, `squash`); i parametri restano nella firma perche'
	# gli audit li passano esplicitamente quando guidano questo ramo con un fixture.
	if z_prima > 0.0 and float(ball.z) <= 0.0:
		# Un fixture che chiama questo ramo direttamente non passa da `_observe_after`:
		# l'esecuzione va comunque misurata.
		impact_vz = absf(vz_prima)
		squash = DrillTarget.squash_quality(impact_vz)
	# Il contatto e' DEL GIOCATORE CONTROLLATO, non del lato: `lastHitterSide` copre anche il
	# compagno, che in allenamento non tocca mai la palla con un comando umano. La freschezza
	# del feedback e' l'altra meta' della regola (`_human_contact_key`, che `_observe_after`
	# ha gia' chiesto su questo stesso passo).
	if int(state.rallyHits) > colpi_prima and state.lastHitterSide == "player" and attempt_contact_fresh_side == "player":
		return_contact = true
	# La rete passata va letta sul colpo DEL lato umano: dopo un colpo avversario
	# `crossedNet` racconta quell'altro tiro, non la risposta.
	if return_contact and state.lastHitterSide == "player" and bool(ball.crossedNet):
		return_cleared = true
	# Il rimbalzo va letto sul marchio che il motore stesso lascia quando la palla
	# tocca terra (`handle_ground_bounce`): `bounces[side] > 0` e' la stessa cosa,
	# ma sopravvive a un tick in cui il rimbalzo e' avvenuto dentro un sotto-passo
	# — che e' esattamente come `bounce`, la funzione condivisa, fa atterrare la
	# palla.
	if return_contact and state.lastHitterSide == "player" and _rimbalzo_del_lato("ai"):
		landing = {"x": float(ball.x), "y": float(ball.y)}
		if DrillTarget.in_return_zone(float(ball.y)):
			var graded := DrillTarget.return_depth(float(ball.y))
			_consuma_esito()
			close_attempt(true, float(graded["tier"]), String(graded["diagnosis"]))
			return
		# Un rimbalzo oltre il vetro di fondo e' fuori dal campo avversario, come dice
		# il motore: la risposta ha passato la rete ma non e' rimbalzata DENTRO la
		# meta' avversaria. E' un tentativo mancato e lo diciamo con le parole del
		# motore, non con una causa inventata.
		if float(ball.y) < float(Frozen.court()["top"]):
			_consuma_esito()
			close_attempt(false, 0.0, "msgOut")
			return
		_consuma_esito()
		close_attempt(false, 0.0, "drillWhyReturnOut" if return_cleared else "drillWhyReturnNet")
		return
	# LA RISPOSTA GIOCATA DALL'AVVERSARIO E' UNA RISPOSTA LEGALE. Se la palla ha passato la
	# rete e l'avversario l'ha colpita (una volée, o qualsiasi contatto prima del rimbalzo),
	# la risposta era giocabile: il motore ha lasciato che l'altro lato la giocasse, e
	# chiamarla fallo di rete vorrebbe dire inventare un tocco che non c'e' stato. Il bonus
	# di profondita' NON si applica qui: non c'e' un atterraggio misurato su cui leggerlo.
	#
	# `return_cleared` NON e' la condizione, ed e' un difetto trovato dalla sonda del root il
	# 2026-09-24: il motore alza `crossedNet` quando la palla attraversa la rete, ma se
	# l'avversario la colpisce NELLO STESSO tick `hit_ball` riazzera `crossedNet` prima che
	# questo ramo lo veda, e una risposta perfettamente legale finiva per essere chiamata
	# fallo di rete. La condizione e' il CONTATTO LEGALE STESSO, piu' il fatto osservabile che
	# e' avvenuto nella meta' avversaria: una racchetta puo' colpire solo la palla giocabile
	# dalla propria parte (`Sim.can_hit`), quindi un contatto avversario con la palla oltre la
	# rete E' la prova che la risposta era passata. Quando lo accettiamo, il marchio
	# `return_cleared` viene alzato anche qui: la risposta era buona, e il report lo dice.
	if return_contact and int(state.rallyHits) > colpi_prima and state.lastHitterSide == "ai" \
			and float(ball.y) < float(Frozen.court()["netY"]):
		return_cleared = true
		_consuma_esito()
		close_attempt(true, RETURN_PLAYED_TIER, "drillWhyReturnPlayed")
		return
	if not _punto_chiuso():
		return
	var why := "drillWhyNoReturn"
	if return_contact:
		why = "drillWhyReturnLost" if return_cleared else "drillWhyReturnNet"
	elif int(state.stats["aces"]["ai"]) > ace_ai_prima:
		why = "drillWhyAceAgainst"
	_consuma_esito()
	close_attempt(false, 0.0, why)


## True when the ball has already touched the ground on this side in the current attempt.
## The engine writes this itself: `handle_ground_bounce` sets `ball.bounces[side]` (and
## clears it on every new hit, `godot/src/sim/sim.gd:1851`), so a bounce that happened
## inside a physics sub-step is still visible on the next drill tick. The drill reads the
## engine's mark instead of re-deriving the landing from the ball's height, which is the
## same rule the reference's target exercise uses for its own bounce
## (`js/drill.js:394` reads the ball at the landing).
func _rimbalzo_del_lato(side: String) -> bool:
	if state.ball.bounces is Dictionary:
		return int((state.ball.bounces as Dictionary).get(side, 0)) > 0
	return false


## What actually happened to the RETURN ball, read off the engine's own marks, for the
## audit to assert against (`godot/tests/modes/return_drill_audit.gd`). It is a report, not
## a second grading rule: the attempt was already closed by `_step_return`. `none` means
## the human side never touched the serve.
func return_ball_diagnosis() -> String:
	if not return_contact:
		return "none"
	if return_cleared:
		if float(state.ball.y) < float(Frozen.court()["top"]):
			return "over-the-back-wall"
		if DrillTarget.in_return_zone(float(state.ball.y)):
			return "cleared"
		return "crossed-and-returned"
	if _rimbalzo_del_lato("player") or float(state.ball.y) > float(Frozen.court()["netY"]):
		return "own-half"
	return "net-or-short"


## `puntoChiuso(state)` (`js/drill.js:316-318`).
func _punto_chiuso() -> bool:
	return state.result != null or float(state.pointPause) > 0.0


## `consumaEsito(state)` (`js/drill.js:321-324`): the drill has no score to
## defend, so the engine's point outcome is consumed and cleared.
func _consuma_esito() -> void:
	state.result = null
	state.pointPause = 0.0


## `drillScoreLine(drill)` (`js/drill.js:466-472`).
func score_line() -> String:
	if grade == null:
		return "—"
	return DrillScoring.score_line(grade, points)


## `drillMetrics(drill)` (`js/drill.js:475-498`).
func metrics() -> Array:
	return DrillScoring.metrics(self)
