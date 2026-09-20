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
extends RefCounted

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillSeed := preload("res://src/modes/drill_seed.gd")
const DrillTarget := preload("res://src/modes/drill_target.gd")
const DrillScoring := preload("res://src/modes/drill_scoring.gd")

## `Number.MAX_SAFE_INTEGER` (`js/drill.js:97`): the "a point cannot close the
## session" target. The audit asserts `pointsToWin > 1000`
## (`scripts/drill-audit.mjs:75`); this is the reference's exact value.
const MAX_SAFE_INTEGER: int = 9007199254740991

## The score a session starts with and the pause the result phase lasts
## (`js/drill.js:261`).
const RESULT_PAUSE: float = 1.6
const GRADE_LIFE: float = 1.2

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


## `createDrill(exerciseId, athlete, arena, aiProfile, lineup)`
## (`js/drill.js:86-146`).
static func create(exercise_id: String, athlete: Dictionary, arena: Dictionary, ai_profile: Dictionary, opts: Dictionary = {}) -> RefCounted:
	var session := new()
	session.exercise = Tables.drill_exercise(exercise_id)
	session.seed_value = int(opts.get("seed", 0))
	session.gen = DrillSeed.from_seed(session.seed_value)
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
	return session


## `placeTeams(state)` (`js/drill.js:77-84`): player at the back, the pair at the
## net. Deterministic, and part of the scenario.
func _place_teams() -> void:
	var court: Dictionary = Frozen.court()
	var mid_x: float = (float(court["left"]) + float(court["right"])) / 2.0
	var net_y := float(court["netY"])
	var top := float(court["top"])
	_place(state.player, mid_x, net_y + 150.0)
	_place(state.playerMate, mid_x + 190.0, net_y + 120.0)
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
	_place_teams()


## `closeAttempt(drill, { inZone, tier, diagnosis })` (`js/drill.js:249-262`).
## The execution grade is not invented here: it is `state.shotFeedback`, the
## engine's own assessment.
func close_attempt(in_zone: bool, tier: float, why: Variant = null) -> void:
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
	phase = "result"
	result_timer = RESULT_PAUSE


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

	# Gli avversari restano immobili solo dove l'esercizio lo richiede.
	if not bool(exercise.get("rivals", false)):
		state.opponent.hitCooldown = Tables.drill_freeze()
		state.opponentMate.hitCooldown = Tables.drill_freeze()

	var colpi_prima: int = int(state.rallyHits)
	var punti_prima: int = int(state.stats["pointsWon"]["player"])
	var falli_prima: int = int(state.stats["doubleFaults"]["player"])
	var ace_ai_prima: int = int(state.stats["aces"]["ai"])
	var z_prima: float = float(state.ball.z)
	# La velocita' verticale *prima* del passo: dopo l'impatto il motore l'ha
	# gia' riflessa e attenuata.
	var vz_prima: float = float(state.ball.vz)
	Sim.update_match(state, dt, input)

	# Il voto arriva dal motore, ma solo quello del giocatore: `shotFeedback` e'
	# condiviso.
	var feedback: Variant = state.shotFeedback
	if feedback is Dictionary:
		var key := String((feedback as Dictionary).get("paddleKey", ""))
		if (feedback as Dictionary).get("grade") != null and (key == "player" or key == String(state.activePlayerKey)):
			grade = (feedback as Dictionary)["grade"]
			grade_life = GRADE_LIFE
	if int(state.rallyHits) > colpi_prima:
		rally_hits += 1
		best_rally = maxi(best_rally, rally_hits)
		# Il tipo di colpo va preso *ora*, mentre l'ha appena battuto il
		# giocatore.
		if state.lastHitterSide == "player":
			last_player_shot = state.ball.shotType

	var ball = state.ball
	var atterrata: bool = z_prima > 0.0 and float(ball.z) <= 0.0
	if atterrata:
		impact_vz = absf(vz_prima)
		squash = DrillTarget.squash_quality(impact_vz)

	if bool(exercise.get("targets", false)):
		if atterrata and bool(target.get("active", false)):
			landing = {"x": float(ball.x), "y": float(ball.y)}
			# Solo un rimbalzo nella meta' avversaria e' un tiro al bersaglio.
			if DrillTarget.in_opponents_half(float(ball.y)):
				var graded := DrillTarget.tier(target, squash, float(ball.x), float(ball.y))
				close_attempt(bool(graded["in_zone"]), float(graded["tier"]), graded["diagnosis"])
			else:
				close_attempt(false, 0.0, "drillWhyOwnHalf")
		elif _punto_chiuso():
			_consuma_esito()
			close_attempt(false, 0.0, "drillWhyMissed")
		return

	if String(exercise.get("id", "")) == "return":
		_step_return(ace_ai_prima, colpi_prima, z_prima, vz_prima)
		return

	if String(exercise.get("id", "")) == "serve":
		# Il doppio fallo lo dichiara il motore; la seconda palla si legge da
		# `serveAttempts`.
		serve_attempt = int(state.serveAttempts)
		if int(state.stats["doubleFaults"]["player"]) > falli_prima:
			double_faults += 1
			_consuma_esito()
			close_attempt(false, 0.0, "drillWhyDoubleFault")
			return
		if not _punto_chiuso():
			return
		# Servizio andato a segno: la prima palla vale piena, la seconda meno,
		# l'ace di piu'.
		var ace: bool = int(state.stats["aces"]["player"]) > 0
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
		var vinto: bool = int(state.stats["pointsWon"]["player"]) > punti_prima
		var colpo: Variant = last_player_shot
		var smashato: bool = colpo == "smash-x2" or colpo == "smash-x3"
		var tier: float = 1.4 if colpo == "smash-x3" else (1.0 if colpo == "smash-x2" else 0.35)
		_consuma_esito()
		var why: String = "drillWhyNoSmash"
		if smashato:
			why = ("drillWhyX3" if colpo == "smash-x3" else "drillWhyX2") if vinto else "drillWhyDefended"
		close_attempt(vinto, tier if vinto else 0.2, why)
		return

	# Scambio: il tentativo dura quanto il punto, e il punteggio premia la
	# lunghezza invece del singolo colpo.
	var tenuto: int = rally_hits
	var energia: float = float(state.rallyEnergy.get("player", 1.0))
	_consuma_esito()
	var why_rally: String = "drillWhyRallyShort" if tenuto < 2 \
		else ("drillWhyDrained" if energia < Frozen.bal("rallyEnergyFloor") + 0.2 else "drillWhyRallyHeld")
	close_attempt(tenuto >= 4, minf(1.5, 0.25 + float(tenuto) * 0.18), why_rally)


## The `return` exercise's branch (`drill_extras.gd`): the opponents served, and the
## attempt is the human side's return. It succeeds when the return CLEARED THE NET and
## BOUNCED INSIDE THE OPPONENTS' COURT — both read off the engine's own ball — and fails
## when the point closed without that bounce. Every diagnosis is a measured fact: an
## opponent ace (`aces.ai`, counted by the engine), the net (the return never crossed),
## out (it crossed and left the court), or a point closed before the bounce. No cause is
## named, because nothing here measures one.
func _step_return(ace_ai_prima: int, colpi_prima: int, z_prima: float, vz_prima: float) -> void:
	var ball = state.ball
	var atterrata: bool = z_prima > 0.0 and float(ball.z) <= 0.0
	if atterrata:
		impact_vz = absf(vz_prima)
		squash = DrillTarget.squash_quality(impact_vz)
	# Il contatto del lato umano: i colpi di scambio salgono e l'ultimo e' del player.
	if int(state.rallyHits) > colpi_prima and state.lastHitterSide == "player":
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
