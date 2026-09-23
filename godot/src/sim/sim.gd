## sim.gd — the GDScript port of the match simulation in `js/game.js`.
##
## This is a TRANSCRIPTION, not a re-implementation: function bodies follow the
## JavaScript line by line, in the same order, with the same operations, so that
## a digest difference can only come from a number, not from a differently-shaped
## algorithm. Where the JavaScript is re-stated rather than copied, the comment
## says why.
##
## Module granularity: everything the tick touches lives in this one file. The
## boundary ticket (`docs/wayfinder/tickets/simulation-port-boundary.md` §8) says
## the number of files is a proposal and does not affect parity; the cross-module
## call graph here is genuinely cyclic (movement calls into shot choice, shot
## choice calls back into movement), and GDScript preload cycles are a footgun
## worth not stepping on for a tracer bullet.
##
## The four couplings the ticket says to strip ARE stripped:
##   - `sfx.*` / `emit*` / `updateFx` / `resetFx` (audio.js, fx.js): not called.
##     Where a call site also *writes state* (`state.fx.shake`, `hapticPulse`)
##     the state write is kept and only the presentation call is dropped.
##   - `t()` (i18n.js): replaced by message ids — the strings are never compared.
##   - `isReduceMotion()` (fx.js) at `js/game.js:1058`: the branch is presentation
##     only; the port takes the "no reduced motion" side, which is the branch the
##     JavaScript harness runs under too (it never sets `reducedMotion`).
##   - `clamp` from `js/render.js:4-6`: re-implemented here (`clamp` is a Godot
##     global with the same `min(max(v,lo),hi)` semantics).
##
## Tick: `update_match(state, 1/120.0, input)` — the constant is `FIXED_STEP` at
## `js/main.js:1164`, consumed by the loop at `js/main.js:1186-1207`. This file
## holds no tick constant of its own, exactly like `js/game.js`.
extends RefCounted

const Stamina := preload("res://src/sim/rally_stamina.gd")
const Tactics := preload("res://src/sim/court_tactics.gd")

const Ent := preload("res://src/sim/entities.gd")
const State := preload("res://src/sim/state.gd")
const Rng := preload("res://src/sim/rng.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## `js/game.js:30-31` — duplicated as `SERV_LINE` in `js/render.js:8`.
const SERVICE_LINE_OFFSET := 126.0
const POINT_KINDS := ["0", "15", "30", "40"]
const POINT_WINNER := "winner"
const POINT_ERROR := "error"

# ---------------------------------------------------------------------------
# Small numeric helpers. Godot's built-ins differ from JavaScript's in exactly
# three places that matter here, and each difference is made explicit rather
# than discovered later in a digest diff:
#   - `Math.hypot` has no Godot equivalent; `hypot2` is sqrt(a*a+b*b).
#   - `Math.round` rounds half toward +infinity; Godot's `roundi` rounds half
#     away from zero. `js_round` uses floor(x+0.5).
#   - JS `x ** y` is `pow(x, y)`.
# ---------------------------------------------------------------------------

static func hypot2(a: float, b: float) -> float:
	return sqrt(a * a + b * b)

static func js_round(value: float) -> float:
	return floor(value + 0.5)

## `Math.sign(x) || fallback` — JS `0 || fallback` is the fallback.
static func js_sign_or(value: float, fallback: float) -> float:
	var s := signf(value)
	if s == 0.0:
		return fallback
	return s


# ---------------------------------------------------------------------------
# Geometry / classification helpers (`js/game.js:110-130`)
# ---------------------------------------------------------------------------

static func court_side(y: float) -> String:
	var court: Dictionary = Frozen.court()
	return "player" if y > float(court["netY"]) else "ai"


static func ball_playable_direction(side: String, ball: Ent.SimBall) -> bool:
	var incoming := ball.vy > 0.0 if side == "player" else ball.vy < 0.0
	var returning_from_own_glass := ball.postGlassSide != null and String(ball.postGlassSide) == side and court_side(ball.y) == side
	return incoming or returning_from_own_glass


static func point_label(own: int, opponent: int) -> String:
	if own >= 3 and opponent >= 3:
		if own == opponent:
			return "40"
		return "AD" if own > opponent else "40"
	return POINT_KINDS[int(minf(own, 3))]


static func sync_point_display(state: State) -> void:
	if state.pointsToWin != 0:
		state.playerScore = str(state.points["player"])
		state.aiScore = str(state.points["ai"])
		return
	state.playerScore = str(state.tieBreakPoints["player"]) if state.tieBreak else point_label(int(state.points["player"]), int(state.points["ai"]))
	state.aiScore = str(state.tieBreakPoints["ai"]) if state.tieBreak else point_label(int(state.points["ai"]), int(state.points["player"]))


static func shot_side(paddle: Ent.SimPaddle) -> String:
	return "player" if paddle.isPlayer else "ai"


static func shot_mode(charge: float) -> String:
	if charge < 0.2:
		return "control"
	if charge > 0.7:
		return "power"
	return "balanced"


static func shot_profile(charge: float, aim: float, quality: float) -> String:
	var aggression := charge * 0.72 + absf(aim) * 0.28
	if aggression > 0.88 and quality >= 0.62:
		return "risk"
	if aggression > 0.42:
		return "attack"
	return "control"


static func target_y_for_side(side: String, depth: float) -> float:
	var court: Dictionary = Frozen.court()
	var net_y := float(court["netY"])
	return net_y - depth if side == "ai" else net_y + depth


static func opponents_near_net(opponent_side: String, opponents: Array) -> bool:
	var court: Dictionary = Frozen.court()
	var average_y: float = (opponents[0].y + opponents[1].y) / 2.0
	return average_y > float(court["netY"]) - 132.0 if opponent_side == "ai" else average_y < float(court["netY"]) + 132.0


static func opponents_forwardness(opponent_side: String, opponents: Array) -> float:
	var court: Dictionary = Frozen.court()
	var average_y: float = (opponents[0].y + opponents[1].y) / 2.0
	var profondita: float = float(court["bottom"]) - float(court["netY"]) - 40.0
	var distanza: float
	if opponent_side == "ai":
		distanza = float(court["netY"]) - average_y
	else:
		distanza = average_y - float(court["netY"])
	return clamp(1.0 - distanza / profondita, 0.0, 1.0)


static func paddle_under_pressure(paddle: Ent.SimPaddle) -> bool:
	var court: Dictionary = Frozen.court()
	return paddle.y > float(court["netY"]) + 168.0 if paddle.isPlayer else paddle.y < float(court["netY"]) - 168.0


static func within_net_range(paddle: Ent.SimPaddle, window: float) -> bool:
	var court: Dictionary = Frozen.court()
	return paddle.y <= float(court["netY"]) + window if paddle.isPlayer else paddle.y >= float(court["netY"]) - window


static func is_smash_shot(shot_type: Variant) -> bool:
	if shot_type == null:
		return false
	var s := String(shot_type)
	return s == "smash" or s == "smash-x2" or s == "smash-x3" or s == "smash-flat"


static func role_bounds(paddle: Ent.SimPaddle) -> Dictionary:
	var court: Dictionary = Frozen.court()
	var net_y := float(court["netY"])
	if paddle.isPlayer:
		if paddle.role == "net":
			return {"minY": net_y + 42.0, "maxY": net_y + 158.0}
		return {"minY": net_y + 158.0, "maxY": float(court["bottom"]) - 42.0}
	if paddle.role == "net":
		return {"minY": net_y - 158.0, "maxY": net_y - 42.0}
	return {"minY": float(court["top"]) + 42.0, "maxY": net_y - 158.0}


static func paddle_distance(paddle: Ent.SimPaddle, ball: Ent.SimBall) -> float:
	return absf(paddle.x - ball.x) + absf(paddle.y - ball.y) * 1.35


## Esegue `reflectedCourtX` (`js/game.js:459-468`).
static func reflected_court_x(x: float) -> float:
	var court: Dictionary = Frozen.court()
	var lo: float = float(court["left"]) + 24.0
	var hi: float = float(court["right"]) - 24.0
	var reflected := x
	while reflected < lo or reflected > hi:
		if reflected < lo:
			reflected = lo + (lo - reflected)
		if reflected > hi:
			reflected = hi - (reflected - hi)
	return reflected


# ---------------------------------------------------------------------------
# Lineup / stat ratios (`js/game.js:154-183`)
# ---------------------------------------------------------------------------

static func build_lineup(athlete: Dictionary, lineup: Dictionary) -> Dictionary:
	return {
		"player": athlete,
		"playerMate": lineup.get("playerMate", null),
		"opponent": lineup.get("opponent", null),
		"opponentMate": lineup.get("opponentMate", null),
	}


static func athlete_for(state: State, paddle: Ent.SimPaddle) -> Variant:
	if paddle != null and paddle.key != "" and state.lineup.has(paddle.key) and state.lineup[paddle.key] != null:
		return state.lineup[paddle.key]
	return state.athlete


static func stat_ratio(chosen: Variant, key: String, spread: float = 1.0) -> float:
	if chosen == null:
		return 1.0
	var average: float = float(Frozen.roster_average()[key])
	var ratio: float = float(chosen["stats"][key]) / average
	return 1.0 + (ratio - 1.0) * spread


static func paddle_ratio(state: State, paddle: Ent.SimPaddle, key: String, spread: float = 1.0) -> float:
	var chosen: Variant = null
	if paddle != null and paddle.key != "" and state.lineup.has(paddle.key):
		chosen = state.lineup[paddle.key]
	return stat_ratio(chosen, key, spread)


static func computer_profile(state: State, paddle: Ent.SimPaddle) -> Dictionary:
	if not paddle.isPlayer:
		return state.ai
	var compagno: Variant = athlete_for(state, paddle)
	var control: float = float(compagno["stats"]["control"])
	return {
		"skill": clamp(0.6 + (control - 0.9) * 0.34, 0.58, 0.78),
		"power": float(compagno["stats"]["power"]),
		"speed": paddle.speed * Stamina.speed_factor(paddle.staminaEnergy),
	}


# ---------------------------------------------------------------------------
# Events / replay buffer (`js/game.js:328-365`)
# ---------------------------------------------------------------------------

static func add_event(state: State, message_id: String) -> void:
	state.events.push_front(message_id)
	if state.events.size() > 5:
		state.events.pop_back()


static func reset_replay_buffer(state: State) -> void:
	state.replayFrames = []


## The ports of `resetFx` (`js/fx.js`). Reset is presentation; the simulation
## state it touched is cleared here.
static func reset_fx(state: State) -> void:
	state.shotFeedback = null


static func capture_replay_frame(state: State) -> void:
	var ball := state.ball
	var snap := {
		"serveSide": state.serveSide,
		"serveCourt": state.serveCourt,
		"activePlayerKey": state.activePlayerKey,
		"ball": {
			"x": ball.x, "y": ball.y, "z": ball.z,
			"vx": ball.vx, "vy": ball.vy, "vz": ball.vz,
			"spin": ball.spin, "topspin": ball.topspin, "backspin": ball.backspin,
			"shotType": ball.shotType,
			"serveInFlight": ball.serveInFlight,
			"serveTouchedNet": ball.serveTouchedNet,
			"bouncePulse": ball.bouncePulse,
			"landRing": ball.landRing,
			"hitFlash": ball.hitFlash,
			"hitPulse": ball.hitPulse,
			"trail": [],
		},
		"pads": [],
	}
	for p in [state.player, state.playerMate, state.opponent, state.opponentMate]:
		snap["pads"].append({
			"x": p.x, "y": p.y, "swing": p.swing, "swingSide": p.swingSide,
			"motion": p.motion, "charge": p.charge, "runPhase": p.runPhase,
			"actionPose": p.actionPose, "actionIntent": p.actionIntent, "moveRatio": p.moveRatio,
			"staminaEnergy": p.staminaEnergy,
		})
	state.replayFrames.append(snap)
	if state.replayFrames.size() > state.replayMax:
		state.replayFrames = state.replayFrames.slice(state.replayFrames.size() - state.replayMax)


static func match_format(state: State) -> Dictionary:
	var tie_break_at: Variant = 6
	if state.tieBreakAt != null:
		tie_break_at = state.tieBreakAt
	return {
		"gamesToWin": state.gamesToWin,
		"gameMargin": state.gameMargin,
		"tieBreakAt": tie_break_at,
		"setsToWin": state.setsToWin if state.mode != "tournament" else 2,
	}


# ---------------------------------------------------------------------------
# The match constructor (`js/game.js:184-326`)
#
# `js/game.js:218` seeds `rngState` from `Math.random()` and the constructor has
# no seed parameter; the harness injects the seed by assignment afterwards. The
# port takes the seed as a parameter and never reads an engine RNG inside the
# simulation — the ticket (§4) requires that, and the observable state is the
# same because the assignment happens before the first `nextRandom` call.
# ---------------------------------------------------------------------------

static func create_match_state(mode: String, athlete: Dictionary, arena: Dictionary, ai_profile: Dictionary, tournament_round: int = 0, options: Dictionary = {}) -> State:
	var human_mode: String = String(options.get("humanMode", "solo"))
	var lineup := build_lineup(athlete, options.get("lineup", {}))
	var mate_athlete: Variant = lineup["playerMate"]
	if mate_athlete == null:
		mate_athlete = athlete
	var mate_stats: Dictionary = mate_athlete["stats"]
	var court: Dictionary = Frozen.court()
	var center_x: float = (float(court["left"]) + float(court["right"])) / 2.0

	var state: State = State.new()
	state.lineup = lineup
	state.mode = mode
	state.athlete = athlete
	state.arena = arena
	state.ai = ai_profile
	state.tournamentRound = tournament_round
	state.humanMode = human_mode
	state.coop = human_mode == "coop"
	state.pvp = human_mode == "pvp"
	state.pvpActiveKey = "opponent"
	state.pvpSwitchCooldown = 0.0
	state.pvpSwitchFlash = 0.0
	state.pvpAthlete = null
	state.scoring = "tennis"
	state.pointsToWin = 0
	state.points = {"player": 0, "ai": 0}
	state.games = {"player": 0, "ai": 0}
	state.sets = {"player": 0, "ai": 0}
	state.tieBreak = false
	state.tieBreakPoints = {"player": 0, "ai": 0}
	state.setScores = []
	state.playerScore = "0"
	state.aiScore = "0"
	state.combo = 1
	state.rallyHits = 0
	state.rallyEnergy = {"player": 1.0, "ai": 1.0}
	for athlete_paddle in [state.player, state.playerMate, state.opponent, state.opponentMate]:
		if athlete_paddle != null:
			athlete_paddle.staminaEnergy = 1.0
	state.rng_state = 0
	state.rng_calls = 0
	state.shotFeedback = null
	state.shotRead = {
		"active": false, "eta": null, "perfectWindow": 0.055, "advice": "read",
		"profile": "control", "overlap": false,
	}
	state.specialCooldown = 0.0
	state.specialReady = 1.0
	state.serveSide = "player"
	state.serveCourt = "right"
	state.serveAttempts = 0
	state.serving = true
	state.serveTimer = 0.9
	state.serviceReceiverKey = null
	state.aiServiceReceiverKey = null
	state.pointPause = 0.0
	state.hitStop = 0.0
	state.pointMessage = ""
	state.lastHitterSide = null
	state.flash = 0.0
	state.shieldTimer = 0.0
	state.wallEventTimer = 0.0
	state.paused = false
	state.running = false
	state.lastTime = 0.0
	state.elapsed = 0.0
	state.events = []
	state.result = null

	state.player = Ent.make_paddle(center_x, float(court["bottom"]) - 52.0, true, {
		"stats": athlete["stats"], "controlled": true, "key": "player",
	})
	state.playerMate = Ent.make_paddle(center_x, float(court["netY"]) + 88.0, true, {
		"stats": mate_stats, "role": "net", "key": "playerMate",
	})
	state.opponent = Ent.make_paddle(center_x, float(court["top"]) + 76.0, false, {
		"speed": float(ai_profile["speed"]) * (0.86 + float(ai_profile["skill"]) * 0.1) * stat_ratio(lineup["opponent"], "speed"),
		"skill": float(ai_profile["skill"]),
		"reachRatio": stat_ratio(lineup["opponent"], "reach"),
		"widthRatio": stat_ratio(lineup["opponent"], "control", 0.5),
		"role": "back",
		"key": "opponent",
	})
	state.opponentMate = Ent.make_paddle(center_x, float(court["netY"]) - 84.0, false, {
		"speed": float(ai_profile["speed"]) * (0.9 + float(ai_profile["skill"]) * 0.1) * stat_ratio(lineup["opponentMate"], "speed"),
		"skill": float(ai_profile["skill"]),
		"reachRatio": stat_ratio(lineup["opponentMate"], "reach"),
		"widthRatio": stat_ratio(lineup["opponentMate"], "control", 0.5),
		"role": "net",
		"key": "opponentMate",
	})
	state.ball = Ent.make_ball()
	state.aiTargetX = center_x
	state.aiReactionDelay = 0.0
	state.aiPrimaryKey = "opponent"
	state.aiReceiverLocked = false
	state.aiShotPressure = 0.0
	state.aiRecoveryMode = false
	state.aiTeamShape = "defend"
	state.playerTeamTactic = "balanced"
	state.tacticFlash = 0.0
	state.aiX3Recovery = 0.0
	state.playerX3Recovery = 0.0
	state.playerSwingBuffer = 0.0
	state.queuedShotPower = 1.0
	state.queuedShotAim = 0.0
	state.queuedShotAimY = 0.0
	state.queuedShotSlice = false
	state.queuedShotVariant = "auto"
	state.queuedShotAge = 0.0
	state.queuedShotCharge = 0.0
	state.queuedShotPrecision = 0.0
	state.smashPrimed = false
	state.cutVolleyPrimed = false
	state.cutVolleyTapWindow = 0.0
	state.globoPrimed = false
	state.globoTapWindow = 0.0
	state.smashTapWindow = 0.0
	state.smashContactGrace = 0.0
	state.smashContactFallback = false
	state.shotCharge = 0.0
	state.shotAim = 0.0
	state.shotAimY = 0.0
	state.shotPrecision = 0.0
	state.shotIntent = "drive"
	state.activePlayerKey = "player"
	state.controlMode = "semi"
	state.switchCooldown = 0.0
	state.receiverLocked = false
	state.manualReceiverOverride = false
	state.manualMovementTimer = 0.0
	state.receiverSwitchFlash = 0.0
	state.manualSwitchFlash = 0.0
	state.hapticPulse = null
	state.stats = {
		"pointsWon": {"player": 0, "ai": 0},
		"aces": {"player": 0, "ai": 0},
		"winners": {"player": 0, "ai": 0},
		"errors": {"player": 0, "ai": 0},
		"smashWinners": {"player": 0, "ai": 0},
		"doubleFaults": {"player": 0, "ai": 0},
		"longestRally": 0,
		"totalRallyHits": 0,
		"rallyCount": 0,
	}
	state.replayFrames = []
	state.replayMax = 720

	if state.coop:
		state.player.controlled = true
		state.playerMate.controlled = true
		state.activePlayerKey = "player"
	elif state.pvp:
		state.opponent.controlled = true

	reset_fx(state)
	prepare_serve(state)
	return state


# ---------------------------------------------------------------------------
# Serve geometry and formations (`js/game.js:367-457`)
# ---------------------------------------------------------------------------

static func serve_target_x(state: State) -> float:
	var court: Dictionary = Frozen.court()
	var width: float = float(court["right"]) - float(court["left"])
	var is_right: bool = state.serveCourt == "right"
	return float(court["left"]) + width * (0.28 if is_right else 0.72)


static func service_origin_x(state: State) -> float:
	var court: Dictionary = Frozen.court()
	var width: float = float(court["right"]) - float(court["left"])
	return float(court["left"]) + width * (0.61 if state.serveCourt == "right" else 0.39)


static func service_court_bounds(state: State, paddle: Ent.SimPaddle) -> Dictionary:
	var court: Dictionary = Frozen.court()
	var middle: float = (float(court["left"]) + float(court["right"])) / 2.0
	var padding: float = paddle.w / 2.0 + 14.0
	if state.serveCourt == "right":
		return {"min": middle + padding, "max": float(court["right"]) - padding}
	return {"min": float(court["left"]) + padding, "max": middle - padding}


static func partner_service_x(state: State) -> float:
	var court: Dictionary = Frozen.court()
	var width: float = float(court["right"]) - float(court["left"])
	return float(court["left"]) + width * (0.31 if state.serveCourt == "right" else 0.69)


static func reset_paddle_for_serve(paddle: Ent.SimPaddle, x: float, y: float) -> void:
	paddle.x = x
	paddle.y = y
	paddle.dashTimer = 0.0
	paddle.hitCooldown = 0.0
	paddle.swing = 0.0
	paddle.swingSide = 1.0
	paddle.motion = 0.0
	paddle.moveRatio = 0.0


static func service_receiver_key(state: State) -> String:
	return "player" if state.ball.serveTargetSide == "left" else "playerMate"


static func prepare_opponent_serve_reception(state: State) -> void:
	var court: Dictionary = Frozen.court()
	var width: float = float(court["right"]) - float(court["left"])
	var left_x: float = float(court["left"]) + width * 0.28
	var right_x: float = float(court["left"]) + width * 0.72
	reset_paddle_for_serve(state.player, left_x, float(court["bottom"]) - 74.0)
	reset_paddle_for_serve(state.playerMate, right_x, float(court["bottom"]) - 74.0)
	state.serviceReceiverKey = service_receiver_key(state)
	if state.activePlayerKey != String(state.serviceReceiverKey):
		set_active_player(state, String(state.serviceReceiverKey), false)
		state.receiverSwitchFlash = 0.65
	state.receiverLocked = true
	state.manualReceiverOverride = false


static func prepare_ai_serve_reception(state: State) -> void:
	var court: Dictionary = Frozen.court()
	var width: float = float(court["right"]) - float(court["left"])
	reset_paddle_for_serve(state.opponent, float(court["left"]) + width * 0.28, float(court["top"]) + 74.0)
	reset_paddle_for_serve(state.opponentMate, float(court["left"]) + width * 0.72, float(court["top"]) + 74.0)
	state.aiServiceReceiverKey = "opponent" if state.ball.serveTargetSide == "left" else "opponentMate"
	if state.pvp:
		set_pvp_active(state, String(state.aiServiceReceiverKey))


static func prepare_player_serve_formation(state: State) -> void:
	var court: Dictionary = Frozen.court()
	reset_paddle_for_serve(state.player, service_origin_x(state), float(court["bottom"]) - 78.0)
	reset_paddle_for_serve(state.playerMate, partner_service_x(state), float(court["netY"]) + 62.0)
	if state.activePlayerKey != "player":
		set_active_player(state, "player", false)


static func prepare_ai_serve_formation(state: State) -> void:
	var court: Dictionary = Frozen.court()
	reset_paddle_for_serve(state.opponent, service_origin_x(state), float(court["top"]) + 78.0)
	reset_paddle_for_serve(state.opponentMate, partner_service_x(state), float(court["netY"]) - 62.0)


static func set_active_player(state: State, key: String, manual: bool = false) -> void:
	if state.coop:
		return
	if state.activePlayerKey == key:
		return
	state.activePlayerKey = key
	state.player.controlled = key == "player"
	state.playerMate.controlled = key == "playerMate"
	state.switchCooldown = 0.7 if manual else 0.28
	# `t("roleBackPos")` / `t("roleNetPos")` / `t("controlMsg", ...)` — message ids.
	var position := "roleBackPos" if state.paddle(key).y > float(Frozen.court()["netY"]) + 150.0 else "roleNetPos"
	add_event(state, "controlMsg:%s" % position)


static func set_pvp_active(state: State, key: String) -> void:
	if state.pvpActiveKey == key:
		return
	state.pvpActiveKey = key
	state.opponent.controlled = key == "opponent"
	state.opponentMate.controlled = key == "opponentMate"
	state.pvpSwitchCooldown = 0.28


static func update_pvp_active(state: State, dt: float, force_switch: bool, switch_direction: Variant = null) -> void:
	state.pvpSwitchCooldown = maxf(0.0, state.pvpSwitchCooldown - dt)
	if not force_switch and switch_direction == null:
		return
	if state.aiServiceReceiverKey != null:
		return
	var other_key := "opponentMate" if state.pvpActiveKey == "opponent" else "opponent"
	if switch_direction != null:
		var current := state.paddle(state.pvpActiveKey)
		var alternate := state.paddle(other_key)
		var dir: Dictionary = switch_direction
		var dx := alternate.x - current.x
		var dy := alternate.y - current.y
		var length := hypot2(dx, dy)
		if length == 0.0:
			length = 1.0
		var direction_length := hypot2(float(dir["x"]), float(dir["y"]))
		if direction_length == 0.0:
			direction_length = 1.0
		var alignment := (dx / length) * (float(dir["x"]) / direction_length) + (dy / length) * (float(dir["y"]) / direction_length)
		if alignment < 0.2:
			return
	set_pvp_active(state, other_key)
	state.pvpSwitchFlash = 0.55


# ---------------------------------------------------------------------------
# Player switching (`js/game.js:641-667`)
# ---------------------------------------------------------------------------

static func update_active_player(state: State, dt: float, force_switch: bool, switch_direction: Variant = null) -> void:
	state.switchCooldown = maxf(0.0, state.switchCooldown - dt)
	if not force_switch and switch_direction == null:
		return
	if state.serviceReceiverKey != null:
		add_event(state, "evReceiverLock")
		return
	var other_key := "playerMate" if state.activePlayerKey == "player" else "player"
	if switch_direction != null:
		var current := state.paddle(state.activePlayerKey)
		var alternate := state.paddle(other_key)
		var dir: Dictionary = switch_direction
		var dx := alternate.x - current.x
		var dy := alternate.y - current.y
		var length := hypot2(dx, dy)
		if length == 0.0:
			length = 1.0
		var direction_length := hypot2(float(dir["x"]), float(dir["y"]))
		if direction_length == 0.0:
			direction_length = 1.0
		var alignment := (dx / length) * (float(dir["x"]) / direction_length) + (dy / length) * (float(dir["y"]) / direction_length)
		if alignment < 0.2:
			return
	set_active_player(state, other_key, true)
	state.receiverSwitchFlash = 0.0
	state.manualSwitchFlash = 0.55
	if state.receiverLocked or state.ball.vy > 0.0:
		state.receiverLocked = true
		state.manualReceiverOverride = true


# ---------------------------------------------------------------------------
# `prepareServe` / `performServe` (`js/game.js:669-778`)
# ---------------------------------------------------------------------------

static func prepare_serve(state: State) -> void:
	var is_player: bool = state.serveSide == "player"
	state.serviceReceiverKey = null
	state.aiServiceReceiverKey = null
	state.receiverLocked = false
	state.manualReceiverOverride = false
	state.aiReceiverLocked = false
	state.aiReactionDelay = 0.0
	state.aiShotPressure = 0.0
	state.aiRecoveryMode = false
	state.smashPrimed = false
	state.smashTapWindow = 0.0
	state.cutVolleyPrimed = false
	state.cutVolleyTapWindow = 0.0
	state.globoPrimed = false
	state.globoTapWindow = 0.0
	state.smashContactGrace = 0.0
	state.smashContactFallback = false
	state.playerSwingBuffer = 0.0
	state.queuedShotVariant = "auto"
	state.hitStop = 0.0
	for paddle in [state.player, state.playerMate, state.opponent, state.opponentMate]:
		paddle.smashPrimed = false
		paddle.smashTapWindow = 0.0
		paddle.smashContactGrace = 0.0
		paddle.smashContactFallback = false
		paddle.swingBuffer = 0.0
		paddle.queuedShot = null
	state.ball = Ent.make_ball()
	state.ball.serveTargetSide = "left" if state.serveCourt == "right" else "right"
	if is_player:
		prepare_player_serve_formation(state)
		prepare_ai_serve_reception(state)
	else:
		prepare_ai_serve_formation(state)
		prepare_opponent_serve_reception(state)
	var server := state.player if is_player else state.opponent
	state.ball.x = server.x + (28.0 if is_player else -28.0)
	state.ball.y = server.y - 24.0 if is_player else server.y + 24.0
	state.ball.z = 34.0
	state.serving = true
	state.serveTimer = 0.0 if state.serveSide == "player" else 0.75


## `requestedCharge` is `Variant` because the JavaScript signature defaults it to
## `null` and falls back to the state's own charge (`js/game.js:719`).
static func perform_serve(state: State, requested_charge: Variant = null, slice: bool = false) -> void:
	var ball := state.ball
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var is_player: bool = state.serveSide == "player"
	var server := state.player if is_player else state.opponent
	var requested: float
	if requested_charge == null:
		requested = state.shotCharge if is_player else 0.62
	else:
		requested = float(requested_charge)
	var charge := clampf(requested, 0.0, 1.0)
	var server_control: float
	if is_player:
		server_control = float(athlete_for(state, server)["stats"]["control"])
	else:
		server_control = (0.92 + float(state.ai["skill"]) * 0.1) * paddle_ratio(state, server, "control", 0.6)
	var second_serve: bool = state.serveAttempts > 0
	var spread: float = float(balance["serveSpread"]) \
		* (float(balance["serveSpreadBase"]) + charge * charge * (1.0 - float(balance["serveSpreadBase"]))) \
		* clampf(1.62 - server_control, 0.3, 1.0) \
		* (float(balance["serveSecondSafety"]) if second_serve else 1.0)
	var depth_error: float = (Rng.next_random(state) - 0.5) * 2.0 * spread * float(balance["serveDepthSpread"])
	var lateral_error: float = (Rng.next_random(state) - 0.5) * 2.0 * spread
	var service_box_depth: float = SERVICE_LINE_OFFSET * (0.24 + charge * 0.52) + depth_error
	var target_y: float = float(court["netY"]) - service_box_depth if is_player else float(court["netY"]) + service_box_depth
	var time: float = float(balance["serveFlightBase"]) - charge * float(balance["serveFlightGain"])
	var drag_rate: float = -60.0 * log(float(balance["airDrag"]))
	var drag_distance_factor: float = (1.0 - exp(-drag_rate * time)) / (drag_rate * time) if drag_rate > 0.0001 else 1.0
	var drag_compensation: float = 1.0 / drag_distance_factor
	var target_x: float = serve_target_x(state) + lateral_error
	ball.serveTargetSide = "left" if state.serveCourt == "right" else "right"
	ball.serveTargetX = target_x
	ball.serveTargetY = target_y
	if is_player:
		prepare_ai_serve_reception(state)
	else:
		prepare_opponent_serve_reception(state)
	ball.vx = ((target_x - ball.x) / time) * drag_compensation
	ball.vy = ((target_y - ball.y) / time) * drag_compensation
	ball.vz = float(balance["ballGravity"]) * time * 0.5 - ball.z / time + 18.0 + (1.0 - charge) * 18.0
	ball.spin = float(-1 if state.serveCourt == "right" else 1) * 14.0
	ball.backspin = 0.75 if slice else 0.0
	if slice:
		ball.spin *= 1.8
	ball.served = true
	ball.serveInFlight = true
	ball.serveTouchedNet = false
	ball.netFaultOwner = null
	ball.bounces = {"player": 0, "ai": 0}
	ball.crossedNet = false
	state.lastHitterSide = state.serveSide
	ball.trail = []
	ball.trailTime = 0.0
	ball.landRing = 0.0
	state.serving = false
	state.rallyHits = 0
	state.combo = 1
	server.shotIntent = "serve"
	server.actionIntent = "serve"
	server.actionPose = 0.46
	server.swing = 1.0
	server.swingSide = -1.0 if state.serveCourt == "right" else 1.0
	if is_player:
		lock_ai_receiver_for_incoming_shot(state, true)
	else:
		lock_receiver_for_incoming_shot(state, true)


## `updateServing` (`js/game.js:2604-2672`).
static func update_serving(state: State, dt: float, input: Dictionary, second: Dictionary) -> void:
	var is_player: bool = state.serveSide == "player"
	if is_player and state.activePlayerKey != "player":
		set_active_player(state, "player", false)
	var server := state.active_player() if is_player else state.opponent
	if is_player:
		var start_x := server.x
		var start_y := server.y
		var move_x := clampf(float(input.get("moveX", 0.0)), -1.0, 1.0)
		var move_y := clampf(float(input.get("moveY", 0.0)), -1.0, 1.0)
		server.x += move_x * server.speed * dt
		server.y += move_y * server.speed * 0.58 * dt
		var service_bounds := service_court_bounds(state, server)
		server.x = clampf(server.x, float(service_bounds["min"]), float(service_bounds["max"]))
		server.y = clampf(server.y, float(Frozen.court()["netY"]) + SERVICE_LINE_OFFSET + 28.0, float(Frozen.court()["bottom"]) - 42.0)
		server.motion = 1.0 if absf(server.x - start_x) + absf(server.y - start_y) > 0.4 else maxf(0.0, server.motion - dt * 7.0)
		state.ball.x = server.x + 28.0
		state.ball.y = server.y - 24.0
		if bool(input.get("hit", false)) or bool(input.get("special", false)):
			perform_serve(state, state.shotCharge, bool(input.get("slice", false)))
			state.shotCharge = 0.0
			state.shotAim = 0.0
			state.shotAimY = 0.0
			add_event(state, "serveHint")
	elif state.humanMode == "pvp":
		if state.pvpActiveKey != "opponent":
			set_pvp_active(state, "opponent")
		state.serveTimer = 0.0
		var start_x := server.x
		var start_y := server.y
		var move_x := clampf(float(second.get("moveX", 0.0)), -1.0, 1.0)
		var move_y := clampf(float(second.get("moveY", 0.0)), -1.0, 1.0)
		server.x += move_x * server.speed * dt
		server.y += move_y * server.speed * 0.58 * dt
		var service_bounds := service_court_bounds(state, server)
		server.x = clampf(server.x, float(service_bounds["min"]), float(service_bounds["max"]))
		server.y = clampf(server.y, float(Frozen.court()["top"]) + 28.0, float(Frozen.court()["netY"]) - SERVICE_LINE_OFFSET - 42.0)
		server.motion = 1.0 if absf(server.x - start_x) + absf(server.y - start_y) > 0.4 else maxf(0.0, server.motion - dt * 7.0)
		state.ball.x = server.x - 28.0
		state.ball.y = server.y + 24.0
		control_paddle_charge(state, server, second, dt)
		if bool(second.get("hit", false)):
			perform_serve(state, server.charge, bool(second.get("slice", false)))
			server.charge = 0.0
			server.aim = 0.0
			server.aimY = 0.0
			add_event(state, "serveHint")
	else:
		state.serveTimer -= dt
		server.x += (service_origin_x(state) - server.x) * minf(1.0, dt * 4.0)
		state.ball.x = server.x - 28.0
		state.ball.y = server.y + 24.0
		if state.serveTimer <= 0.0:
			perform_serve(state)
			add_event(state, "evOppServe")


# ---------------------------------------------------------------------------
# Contact geometry (`js/game.js:479-546`, `780-808`)
# ---------------------------------------------------------------------------

static func contact_width(paddle: Ent.SimPaddle, ball: Ent.SimBall) -> float:
	var balance: Dictionary = Frozen.balance()
	if paddle.isPlayer:
		return paddle.w * float(balance["playerContactReach"]) + ball.r
	var skill_reach: float = float(balance["aiContactReachBase"]) + clampf(paddle.skill, 0.0, 1.0) * float(balance["aiContactReachSkill"])
	return paddle.w * skill_reach + ball.r


static func responder_forecast(paddle: Ent.SimPaddle, ball: Ent.SimBall) -> Dictionary:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	if not ball_playable_direction("player", ball):
		return {"score": INF, "reachable": false, "contactX": paddle.x}
	var contact_y: float = clampf(paddle.y, float(court["netY"]) + 42.0, float(court["bottom"]) - 42.0)
	var time: float = (contact_y - ball.y) / ball.vy
	if time < 0.04 or time > 1.65:
		return {"score": INF, "reachable": false, "contactX": paddle.x}
	var contact_x := reflected_court_x(ball.x + ball.vx * time)
	var contact_z: float = maxf(0.0, ball.z + ball.vz * time - 0.5 * float(balance["ballGravity"]) * time * time)
	var horizontal_reach := contact_width(paddle, ball)
	var travel_distance: float = maxf(0.0, absf(contact_x - paddle.x) - horizontal_reach)
	var travel_time: float = travel_distance / maxf(1.0, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy))
	var late_by: float = maxf(0.0, travel_time - time)
	var playable_height: float = float(balance["playableHitHeight"])
	var height_penalty: float = 1.4 + (contact_z - playable_height) / 80.0 if contact_z > playable_height else 0.0
	return {
		"score": travel_time + late_by * 3.2 + height_penalty,
		"reachable": late_by <= 0.1 and contact_z <= playable_height + 12.0,
		"contactX": contact_x,
	}


static func ai_responder_forecast(paddle: Ent.SimPaddle, ball: Ent.SimBall) -> Dictionary:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	if not ball_playable_direction("ai", ball):
		return {"score": INF, "reachable": false, "contactX": paddle.x}
	var contact_y: float = clampf(paddle.y, float(court["top"]) + 42.0, float(court["netY"]) - 42.0)
	var time: float = (contact_y - ball.y) / ball.vy
	if time < 0.04 or time > 1.8:
		return {"score": INF, "reachable": false, "contactX": paddle.x}
	var contact_x := reflected_court_x(ball.x + ball.vx * time)
	var contact_z: float = maxf(0.0, ball.z + ball.vz * time - 0.5 * float(balance["ballGravity"]) * time * time)
	var horizontal_reach := contact_width(paddle, ball)
	var travel_distance: float = maxf(0.0, absf(contact_x - paddle.x) - horizontal_reach)
	var travel_time: float = travel_distance / maxf(1.0, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy))
	var late_by: float = maxf(0.0, travel_time - time)
	var playable_height: float = float(balance["playableHitHeight"])
	var height_penalty: float = 1.4 + (contact_z - playable_height) / 80.0 if contact_z > playable_height else 0.0
	return {
		"score": travel_time + late_by * 3.2 + height_penalty,
		"reachable": late_by <= 0.12 and contact_z <= playable_height + 12.0,
		"contactX": contact_x,
	}


## Pure decision used by movement and the final legal contact gate.
static func ai_contact_plan(state: State, paddle: Ent.SimPaddle, ball: Ent.SimBall) -> Dictionary:
	var plan: Dictionary = _ai_contact_plan_base(state, paddle, ball)
	if not state.aiGlassPlay or bool(plan["wait"]):
		return plan
	# Glass-aware bounce play (`ai_glass.gd`), only where the old planner said "take it
	# in the air" for a player out of the volley zone: at the net the air stays right.
	# Only where the old planner said "take it now": "emergency" before the bounce, or
	# "bounced" after it. A comfortable volley ("volley") stays a volley: overriding it
	# pulled mid-court players back and emptied the net (measured, level 2: net
	# contacts 774 -> 454).
	var reason := String(plan["reason"])
	if reason != "emergency" and reason != "bounced":
		return plan
	if float(Frozen.court()["netY"]) - paddle.y < AI_VOLLEY_ZONE_PX:
		return plan
	if ball.shotType.begins_with("smash-x") or ball.wallKill > 0.0:
		return plan                             # glass cases decided by dice: not forecast
	var already_bounced := int(ball.bounces["ai"]) > 0
	# A ball on the racket NOW at a playable height is played now, bounced or not: the
	# glass is for the ball that cannot be taken before it (too deep, high or fast),
	# as in padel. Gambling a reachable ball on the glass cost the AI its point in 57
	# of 62 double bounces at level 1 and 24 of 27 at level 2 (measured): after the
	# glass the receiver is re-locked with a reaction that is partly pressure and
	# partly dice (`lock_ai_receiver_for_incoming_shot`), so it cannot be planned.
	var glass_module := preload("res://src/sim/ai_glass.gd")
	if can_hit(paddle, ball) and ball.z >= glass_module.CONTACT_MIN_Z:
		# ...but a ball still RISING after its bounce is let climb to near the top of its
		# arc first (exact apex: z + vz^2 / 2g). Taking it on the way up at ~20 px left
		# the AI's shots 4-7% slower and 6-8 px lower than today's volleys (measured).
		var gravity: float = float(Frozen.balance()["ballGravity"])
		var apex: float = ball.z + (ball.vz * ball.vz / (2.0 * gravity) if ball.vz > 0.0 else 0.0)
		var target_z: float = apex * glass_module.TOP_SHARE
		if not (already_bounced and ball.vz > 0.0 and ball.z < target_z):
			return plan
		# Only if the ball will STILL be on the racket when it gets there (straight-line
		# x/y over the time to climb; a margin inside the contact box). Otherwise the
		# wait lets it out of reach and the point goes on a double bounce (measured).
		var rise_t: float = (ball.vz - sqrt(maxf(0.0, ball.vz * ball.vz - 2.0 * gravity * (target_z - ball.z)))) / gravity
		var then_x: float = ball.x + ball.vx * rise_t
		var then_y: float = ball.y + ball.vy * rise_t
		var depth_reach: float = paddle.reach * float(Frozen.balance()["aiDepthReach"])
		if absf(then_x - paddle.x) < contact_width(paddle, ball) * 0.8 and absf(then_y - paddle.y) < depth_reach * 0.8:
			return {"wait": true, "reason": "bounce-rising", "x": paddle.x, "y": paddle.y}
		return plan
	var glass: Dictionary = preload("res://src/sim/ai_glass.gd").plan({
		"x": paddle.x, "y": paddle.y, "speed": paddle.speed * Stamina.speed_factor(paddle.staminaEnergy),
		"reaction": state.aiReactionDelay, "width": contact_width(paddle, ball),
		"depth": paddle.reach * float(Frozen.balance()["aiDepthReach"]),
		# The deterministic part of the reaction the glass will impose
		# (`lock_ai_receiver_for_incoming_shot`: base reaction, pressure excluded).
		"glass_relock": clampf(0.28 - (float(state.ai["reactionSkill"]) if state.ai.has("reactionSkill") else float(state.ai["skill"])) * 0.25, 0.07, 0.42),
	}, {
		"x": ball.x, "y": ball.y, "z": ball.z, "vx": ball.vx, "vy": ball.vy, "vz": ball.vz,
		"spin": ball.spin, "backspin": ball.backspin, "topspin": ball.topspin, "r": ball.r,
	}, Frozen.court(), Frozen.balance(), float(state.arena["wallBounce"]), already_bounced)
	if glass.is_empty():
		return plan                             # nothing better ahead: play it now
	# The planned moment is (about) now: play it. Without this the AI, standing on the
	# spot, would keep "waiting" for a point it has already reached.
	if float(glass["t"]) <= AI_BOUNCE_HIT_NOW_S:
		return plan
	return {"wait": true, "reason": "glass-play" if bool(glass["glass"]) else "bounce-play",
		"x": float(glass["x"]), "y": float(glass["y"])}


static func _ai_contact_plan_base(state: State, paddle: Ent.SimPaddle, ball: Ent.SimBall) -> Dictionary:
	return preload("res://src/sim/ai_contact.gd").plan({
		"x": paddle.x, "y": paddle.y, "speed": paddle.speed * Stamina.speed_factor(paddle.staminaEnergy), "skill": paddle.skill,
		"width": contact_width(paddle, ball), "depth": paddle.reach * float(Frozen.balance()["aiDepthReach"]),
		"reaction": state.aiReactionDelay, "bounce_bias": state.aiBounceBias,
	}, {
		"x": ball.x, "y": ball.y, "z": ball.z, "vx": ball.vx, "vy": ball.vy, "vz": ball.vz,
		"spin": ball.spin, "backspin": ball.backspin, "topspin": ball.topspin,
		"bounces": ball.bounces["ai"], "serve": ball.serveInFlight,
		"fault": ball.netFaultOwner != null, "incoming": ball_playable_direction("ai", ball),
	}, Frozen.court(), Frozen.balance())


static func best_responder(state: State) -> Dictionary:
	var back := responder_forecast(state.player, state.ball)
	var net := responder_forecast(state.playerMate, state.ball)
	if float(back["score"]) <= float(net["score"]):
		return {"key": "player", "forecast": back, "alternate": net}
	return {"key": "playerMate", "forecast": net, "alternate": back}


static func lock_receiver_for_incoming_shot(state: State, is_serve: bool = false) -> void:
	if state.coop:
		state.receiverLocked = false
		state.manualReceiverOverride = false
		return
	if not ball_playable_direction("player", state.ball):
		return
	var choice := best_responder(state)
	var control_mode: String = state.controlMode
	var key: String
	if is_serve:
		key = String(state.serviceReceiverKey) if state.serviceReceiverKey != null else service_receiver_key(state)
	else:
		key = String(choice["key"])
	var current_forecast := responder_forecast(state.active_player(), state.ball)
	var is_close_decision: bool = float(current_forecast["score"]) <= float(choice["forecast"]["score"]) + 0.1
	if not is_serve:
		if control_mode == "manual":
			state.receiverLocked = false
			state.manualReceiverOverride = true
			return
		if control_mode == "semi":
			var decisive_advantage: bool = float(choice["forecast"]["score"]) + 0.32 < float(current_forecast["score"])
			var rescue_needed: bool = (not bool(current_forecast["reachable"])) and bool(choice["forecast"]["reachable"])
			key = String(choice["key"]) if (decisive_advantage or rescue_needed) else state.activePlayerKey
		elif state.manualMovementTimer > 0.0 and bool(current_forecast["reachable"]) and is_close_decision:
			key = state.activePlayerKey
	if key != state.activePlayerKey:
		set_active_player(state, key, false)
		state.receiverSwitchFlash = 0.65
	state.receiverLocked = true
	state.manualReceiverOverride = false


static func lock_ai_receiver_for_incoming_shot(state: State, is_serve: bool = false) -> void:
	var balance: Dictionary = Frozen.balance()
	if not ball_playable_direction("ai", state.ball):
		return
	var pace := hypot2(state.ball.vx, state.ball.vy)
	var pace_pressure: float = clampf((pace - 250.0) / 270.0, 0.0, 1.0)
	var angle_pressure: float = clampf(absf(state.ball.vx) / 380.0, 0.0, 1.0)
	state.aiShotPressure = pace_pressure * 0.55 + angle_pressure * 0.45
	var key: Variant = state.aiServiceReceiverKey
	var forecast: Dictionary
	if is_serve and key != null:
		forecast = ai_responder_forecast(state.paddle(String(key)), state.ball)
	else:
		var back := ai_responder_forecast(state.opponent, state.ball)
		var mate := ai_responder_forecast(state.opponentMate, state.ball)
		var best_key := "opponent" if float(back["score"]) <= float(mate["score"]) else "opponentMate"
		var best_forecast: Dictionary = back if best_key == "opponent" else mate
		var committed_key: String = state.aiPrimaryKey
		var committed_forecast: Dictionary = back if committed_key == "opponent" else mate
		var commitment_chance: float = (1.0 - float(state.ai["skill"])) * (0.1 + state.aiShotPressure * 0.35)
		var can_be_wrong_footed: bool = committed_key != best_key and float(committed_forecast["score"]) <= float(best_forecast["score"]) + 0.75
		if can_be_wrong_footed and Rng.next_random(state) < commitment_chance:
			key = committed_key
			forecast = committed_forecast
		elif float(back["score"]) <= float(mate["score"]):
			key = "opponent"
			forecast = back
		else:
			key = "opponentMate"
			forecast = mate
	state.aiPrimaryKey = String(key) if key != null else "opponent"
	state.aiTargetX = float(forecast["contactX"]) if forecast.has("contactX") else state.paddle(state.aiPrimaryKey).x
	state.aiReceiverLocked = true
	var reaction_skill: float = float(state.ai["reactionSkill"]) if state.ai.has("reactionSkill") else float(state.ai["skill"])
	var base_reaction: float = 0.28 - reaction_skill * 0.25
	var pressure_penalty: float = state.aiShotPressure * (1.0 - reaction_skill) * 0.42
	var wrong_footed_chance: float = 0.0 if is_serve else clampf((state.aiShotPressure - 0.25) * (2.0 - reaction_skill * 1.8), 0.0, 0.7)
	var wrong_footed: bool = Rng.next_random(state) < wrong_footed_chance
	var wrong_footed_delay: float = 0.28 + state.aiShotPressure * 0.22 if wrong_footed else 0.0
	state.aiReactionDelay = 0.0 if is_serve else clampf(base_reaction + pressure_penalty, 0.07, 0.42) + wrong_footed_delay
	if wrong_footed:
		add_event(state, "evCounter")


static func can_hit(paddle: Ent.SimPaddle, ball: Ent.SimBall) -> bool:
	var balance: Dictionary = Frozen.balance()
	if ball.serveInFlight or ball.netFaultOwner != null:
		return false
	var within_x: bool = absf(ball.x - paddle.x) < contact_width(paddle, ball)
	var depth_reach: float = float(balance["playerDepthReach"]) if paddle.isPlayer else float(balance["aiDepthReach"])
	var within_y: bool = absf(ball.y - paddle.y) < paddle.reach * depth_reach
	var side := "player" if paddle.isPlayer else "ai"
	return within_x and within_y and ball_playable_direction(side, ball) and ball.z <= float(balance["playableHitHeight"])


static func crossed_paddle(paddle: Ent.SimPaddle, ball: Ent.SimBall, previous_ball: Variant) -> bool:
	var balance: Dictionary = Frozen.balance()
	if previous_ball == null:
		return false
	if ball.z > float(balance["playableHitHeight"]):
		return false
	var side := "player" if paddle.isPlayer else "ai"
	if not ball_playable_direction(side, ball):
		return false
	var prev: Dictionary = previous_ball
	var crossed_y: bool = (float(prev["y"]) - paddle.y) * (ball.y - paddle.y) <= 0.0
	if not crossed_y:
		return false
	var distance: float = ball.y - float(prev["y"])
	if absf(distance) < 0.001:
		return false
	var t := clampf((paddle.y - float(prev["y"])) / distance, 0.0, 1.0)
	var contact_x: float = float(prev["x"]) + (ball.x - float(prev["x"])) * t
	return absf(contact_x - paddle.x) <= contact_width(paddle, ball)


# ---------------------------------------------------------------------------
# Shot quality / timing (`js/game.js:810-1053`)
# ---------------------------------------------------------------------------

static func hit_power_profile(paddle: Ent.SimPaddle, state: State, power: float) -> float:
	if paddle.isPlayer:
		return power * float(athlete_for(state, paddle)["stats"]["power"])
	if state.pvp and paddle.controlled:
		var pvp_power: float = float(state.pvpAthlete["stats"]["power"]) if state.pvpAthlete != null else float(state.ai["power"])
		return power * pvp_power
	return power * float(state.ai["power"]) * paddle_ratio(state, paddle, "power")


static func contextual_perfect_window(state: State, paddle: Ent.SimPaddle, charge: float = 0.0) -> float:
	var balance: Dictionary = Frozen.balance()
	var ball := state.ball
	var side := shot_side(paddle)
	var moving := clampf(paddle.moveRatio, 0.0, 1.0)
	var glass_ball: bool = ball.postGlassSide != null and String(ball.postGlassSide) == side
	var power := pow(clampf(charge, 0.0, 1.0), 2.0)
	return clampf(
		float(balance["perfectTimingWindow"])
			- moving * float(balance["timingWindowRunPenalty"])
			- (float(balance["timingWindowGlassPenalty"]) if glass_ball else 0.0)
			- power * float(balance["timingWindowChargePenalty"])
			+ clampf(paddle.splitStep, 0.0, 1.0) * float(balance["timingWindowSplitStepBonus"]),
		float(balance["timingWindowMin"]),
		float(balance["timingWindowMax"]),
	)


## Returns `null` or a float, like the JavaScript (`js/game.js:866-881`).
static func playable_eta(state: State, paddle: Ent.SimPaddle) -> Variant:
	var balance: Dictionary = Frozen.balance()
	var ball := state.ball
	if not (ball.vy > 28.0):
		return null
	var time_to_line: float = (paddle.y - ball.y) / ball.vy
	if not is_finite(time_to_line):
		return null
	var ceiling: float = float(balance["playableHitHeight"])
	var g: float = float(balance["ballGravity"])
	var z_at_line: float = ball.z + ball.vz * time_to_line - 0.5 * g * time_to_line * time_to_line
	if z_at_line <= ceiling:
		return time_to_line
	var discriminant: float = ball.vz * ball.vz + 2.0 * g * (ball.z - ceiling)
	if discriminant < 0.0:
		return time_to_line
	var descending_crossing: float = (ball.vz + sqrt(discriminant)) / g
	return maxf(time_to_line, descending_crossing)


static func update_shot_read(state: State, paddle: Ent.SimPaddle) -> void:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	var incoming: bool = ball_playable_direction("player", ball) and ball.y > float(court["netY"])
	var eta: Variant = playable_eta(state, paddle) if incoming else null
	var glass_ball: bool = ball.postGlassSide != null and String(ball.postGlassSide) == "player"
	var near_glass: bool = paddle.y > float(court["bottom"]) - 145.0 or glass_ball
	var near_net: bool = paddle.y < float(court["netY"]) + 145.0
	var high_ball: bool = ball.z >= float(balance["smashMinHeight"])
	var opponents_forward := opponents_near_net("ai", [state.opponent, state.opponentMate])
	var advice := "read"
	var gravity: float = float(balance["ballGravity"])
	var ground_time := (ball.vz + sqrt(maxf(0.0, ball.vz * ball.vz + 2.0 * gravity * ball.z))) / gravity
	var drag_rate := -60.0 * log(float(balance["airDrag"]))
	var flight_distance := (1.0 - exp(-drag_rate * ground_time)) / drag_rate if drag_rate > 0.0001 else ground_time
	var landing_y := ball.y + ball.vy * flight_distance
	# A deep lob earns time to advance, not a speed/precision bonus. Only cue it
	# once the ball actually pushed the pair back and remains above their reach.
	if not incoming and not state.serving and state.lastHitterSide == "player" \
			and ball.shotType in ["lob", "defensive-lob", "globo"] \
			and ball.y < float(court["netY"]) and ball.vy < 0.0 \
			and ball.z > float(balance["playableHitHeight"]) + 30.0 \
			and landing_y > float(court["top"]) + 30.0 and landing_y < float(court["netY"]) - 160.0 \
			and maxf(state.opponent.y, state.opponentMate.y) < float(court["netY"]) - 145.0 \
			and paddle.y > float(court["netY"]) + 110.0:
		advice = "advance"
	if incoming:
		if near_glass and ball.z < 62.0:
			advice = "lob" if opponents_forward else "chiquita"
		elif near_net and high_ball:
			advice = "smash"
		elif near_net and ball.z >= 42.0:
			advice = "vibora"
		elif opponents_forward and ball.z < 48.0:
			advice = "lob"
		else:
			advice = "drive"
		# Show a placement opportunity only for a reachable short reply and a
		# genuinely uncovered lane. Never aim or hit on the player's behalf.
		var open_lane := maxf(minf(state.opponent.x, state.opponentMate.x) - float(court["left"]), float(court["right"]) - maxf(state.opponent.x, state.opponentMate.x))
		if advice == "drive" and near_net and eta != null and float(eta) >= 0.0 and float(eta) < 0.9 \
				and bool(responder_forecast(paddle, ball)["reachable"]) \
				and ball.z < 42.0 and hypot2(ball.vx, ball.vy) < 330.0 \
				and landing_y > float(court["netY"]) + 42.0 and landing_y < float(court["netY"]) + 155.0 \
				and open_lane > (float(court["right"]) - float(court["left"])) * 0.34:
			advice = "space"
	var perfect_window := contextual_perfect_window(state, paddle, state.shotCharge)
	var moving := clampf(paddle.moveRatio, 0.0, 1.0)
	var profile := shot_profile(state.shotCharge, state.shotAim, clampf(1.0 - moving * 0.25, 0.0, 1.0))
	var mate := state.playerMate
	var overlap: bool = absf(paddle.x - mate.x) < (paddle.w + mate.w) * 0.52 and absf(paddle.y - mate.y) < 92.0
	var aim_freedom: float = 0.78 if profile == "control" else (0.96 if profile == "attack" else 1.1)
	var athlete: Variant = athlete_for(state, paddle)
	var control_stat: float = float(athlete["stats"]["control"]) if athlete != null else 1.0
	var preview_offset: float = clampf(state.shotAim * control_stat * aim_freedom, -1.0, 1.0)
	var precision := clampf(state.shotPrecision, 0.0, 1.0)
	var tight: float = precision * clampf((absf(preview_offset) - 0.55) / 0.35, 0.0, 1.0)
	state.shotRead = {
		"active": incoming and eta != null and float(eta) > -0.16 and float(eta) < 1.15,
		"eta": eta,
		"perfectWindow": perfect_window,
		"advice": advice,
		"profile": profile,
		"overlap": overlap,
		"precision": precision,
		"tight": tight,
	}


## `evaluateShotQuality` (`js/game.js:928-1010`). `options` carries the same
## defaults as the JavaScript destructuring, including the `aiTiming: null`
## sentinel that switches the timing branch.
static func evaluate_shot_quality(state: State, paddle: Ent.SimPaddle, options: Dictionary = {}) -> Dictionary:
	var balance: Dictionary = Frozen.balance()
	var ball := state.ball
	var charge: float = float(options.get("charge", 0.5))
	var aim: float = float(options.get("aim", 0.0))
	var variant: String = String(options.get("variant", "drive"))
	var timing_age: float = float(options.get("timingAge", 0.0))
	var ai_timing: Variant = options.get("aiTiming", null)

	var side := shot_side(paddle)
	var passed_distance: float = maxf(0.0, (ball.y - paddle.y) * (1.0 if paddle.isPlayer else -1.0))
	var lateral_distance: float = absf(ball.x - paddle.x) / maxf(1.0, contact_width(paddle, ball))
	var longitudinal_distance: float = absf(ball.y - paddle.y) / maxf(1.0, paddle.reach * 1.3)
	var contact_distance := hypot2(lateral_distance * 0.82, longitudinal_distance * 0.58)
	var position: float = clampf(1.08 - contact_distance * 0.58 - passed_distance / 155.0, 0.18, 1.0)
	var sprint_penalty: float = clampf(paddle.sprinting, 0.0, 1.0) * float(balance["sprintAccuracyPenalty"])
	var split_step_bonus: float = clampf(paddle.splitStep, 0.0, 1.0) * float(balance["splitStepQualityBonus"])
	var movement_penalty: float = clampf(paddle.moveRatio, 0.0, 1.0) * 0.22 + sprint_penalty
	var balance_: float = clampf(1.0 - movement_penalty - maxf(0.0, lateral_distance - 0.68) * 0.32, 0.28, 1.0)
	var perfect_window: float = float(balance["perfectTimingWindow"]) if ai_timing != null else contextual_perfect_window(state, paddle, charge)
	var window_ratio: float = perfect_window / float(balance["perfectTimingWindow"])
	var early_miss: float = maxf(0.0, timing_age - perfect_window) / maxf(0.01, float(balance["goodTimingWindow"]) * float(balance["timingDecaySpan"]) * window_ratio)
	var late_miss: float = passed_distance / (paddle.reach * float(balance["lateGraceFactor"]) * 4.6)
	var timing: float = float(ai_timing) if ai_timing != null else clampf(1.0 - early_miss - late_miss, 0.18, 1.0)
	var late_grace: float = paddle.reach * float(balance["lateGraceFactor"])
	var timing_bias: float = 0.0 if ai_timing != null else clampf(late_miss - early_miss, -1.0, 1.0)
	var overhead: bool = variant == "smash" or variant.begins_with("smash-")
	var height: float
	if overhead:
		height = clampf((ball.z - 42.0) / 35.0, 0.2, 1.0)
	else:
		height = clampf(1.0 - maxf(0.0, ball.z - 82.0) / 100.0, 0.55, 1.0)
	var energy: float = Stamina.execution_energy(paddle.staminaEnergy, clampf(charge, 0.0, 1.0), clampf(paddle.moveRatio, 0.0, 1.0), timing, clampf(paddle.splitStep, 0.0, 1.0), overhead)
	var control: float
	if paddle.isPlayer:
		control = clampf(float(athlete_for(state, paddle)["stats"]["control"]) / 1.22, 0.72, 1.05)
	elif state.pvp and paddle.controlled:
		var pvp_control: float = float(state.pvpAthlete["stats"]["control"]) if state.pvpAthlete != null else 1.0
		control = clampf(pvp_control / 1.22, 0.72, 1.05)
	else:
		control = clampf((0.72 + float(state.ai["skill"]) * 0.34) * paddle_ratio(state, paddle, "control", 0.6), 0.72, 1.02)
	var quality: float = clampf(
		timing * float(balance["qualityTimingWeight"])
			+ position * 0.21
			+ balance_ * 0.12
			+ height * 0.1
			+ energy * 0.08
			+ control * 0.05
			+ split_step_bonus,
		0.0,
		1.0,
	)
	var mode := shot_mode(charge)
	var aggression: float = clampf(
		charge * 0.72 + absf(aim) * 0.28 + (0.16 if overhead else 0.0),
		0.0,
		1.2,
	)
	var risk: float = clampf(
		(1.0 - quality) * (0.48 + aggression * 0.82)
			+ maxf(0.0, absf(aim) - 0.72) * 0.5
			+ (maxf(0.0, 0.62 - energy) * 0.42 if mode == "power" else 0.0),
		0.0,
		1.25,
	)
	var profile := shot_profile(charge, aim, quality)
	var grade: String
	if timing >= 0.9:
		grade = "perfect"
	elif passed_distance > late_grace:
		grade = "late"
	elif timing >= 0.7:
		grade = "good"
	else:
		grade = "early"
	return {
		"quality": quality, "timing": timing, "timingBias": timing_bias, "position": position,
		"balance": balance_, "height": height, "energy": energy, "aggression": aggression,
		"risk": risk, "profile": profile, "mode": mode, "grade": grade,
	}


static func consume_rally_energy(state: State, paddle: Ent.SimPaddle, assessment: Dictionary, variant: String, slice: bool) -> void:
	var athlete: Dictionary = athlete_for(state, paddle)
	var resistance := clampf(float(athlete.get("stats", {}).get("stamina", 1.0)), 0.7, 1.5)
	paddle.staminaEnergy = clampf(paddle.staminaEnergy - Stamina.shot_cost(variant, slice, String(assessment.get("mode", "control"))) / resistance, Stamina.FLOOR, 1.0)
	sync_rally_energy(state)


static func sync_rally_energy(state: State) -> void:
	state.rallyEnergy["player"] = state.active_player().staminaEnergy
	state.rallyEnergy["ai"] = (state.opponent.staminaEnergy + state.opponentMate.staminaEnergy) * 0.5


## `showShotFeedback` (`js/game.js:1055-1076`), minus the localized strings and
## minus the `isReduceMotion()` branch (a presentation-only branch; see the file
## header). The `hitStop` write it guards is kept — it is simulation state
## (`js/game.js:3012`).
static func show_shot_feedback(state: State, paddle: Ent.SimPaddle, assessment: Dictionary) -> void:
	if not paddle.controlled:
		return
	var balance: Dictionary = Frozen.balance()
	if String(assessment["grade"]) == "perfect":
		state.hitStop = float(balance["hitStopPerfect"])
	state.shotFeedback = {
		"text": "shot:%s" % String(assessment["grade"]),
		"mode": "shotMode:%s" % String(assessment["mode"]),
		"profile": assessment["profile"],
		"grade": assessment["grade"],
		"quality": assessment["quality"],
		"life": 0.78,
		"paddleKey": paddle.key if paddle.key != "" else state.activePlayerKey,
	}


# ---------------------------------------------------------------------------
# AI shot choice (`js/game.js:1119-1466`)
# ---------------------------------------------------------------------------

static func attack_read(state: State, paddle: Ent.SimPaddle, contact_height: float) -> float:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	var height: float = clampf(
		(contact_height - float(balance["attackReadHeightLo"]))
			/ (float(balance["attackReadHeightHi"]) - float(balance["attackReadHeightLo"])),
		0.0,
		1.0,
	)
	var speed := hypot2(ball.vx, ball.vy)
	var slow: float = clampf(
		1.0 - (speed - float(balance["attackReadSlowSpeed"]))
			/ (float(balance["attackReadFastSpeed"]) - float(balance["attackReadSlowSpeed"])),
		0.0,
		1.0,
	)
	var reach: float = float(balance["attackReadAdvance"])
	var advance: float
	if paddle.isPlayer:
		advance = clampf((float(court["netY"]) + reach - paddle.y) / reach, 0.0, 1.0)
	else:
		advance = clampf((paddle.y - (float(court["netY"]) - reach)) / reach, 0.0, 1.0)
	return clampf(
		height * float(balance["attackReadWeightHeight"])
			+ slow * float(balance["attackReadWeightSlow"])
			+ advance * float(balance["attackReadWeightAdvance"]),
		0.0,
		1.0,
	)


static func choose_computer_shot(state: State, paddle: Ent.SimPaddle, profile: Dictionary, contact_height: float = 0.0, ai_timing: float = 1.0) -> Dictionary:
	var style := Tactics.style(String(athlete_for(state, paddle).get("id", "")))
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var opponent_side := "ai" if paddle.isPlayer else "player"
	var opponents: Array = [state.opponent, state.opponentMate] if opponent_side == "ai" else [state.player, state.playerMate]
	var coverage_x: float = (opponents[0].x + opponents[1].x) / 2.0
	var center_x: float = (float(court["left"]) + float(court["right"])) / 2.0
	var side_bias: float = 1.0 if coverage_x <= center_x else -1.0
	var accuracy_error: float = (1.0 - float(profile["skill"])) * 44.0
	var at_net: bool = paddle.y < float(court["netY"]) + 126.0 if paddle.isPlayer else paddle.y > float(court["netY"]) - 126.0
	var pressured: bool = paddle_under_pressure(paddle) or state.ball.z < 38.0
	var opponents_are_forward := opponents_near_net(opponent_side, opponents)
	var avanzamento: float = maxf(
		opponents_forwardness(opponent_side, opponents),
		float(balance["aiLobPressure"]) if pressured else 0.0,
	)
	var lob_chance: float = clampf(
		float(balance["aiLobBase"]) + avanzamento * (float(balance["aiLobForward"]) + float(profile["skill"]) * float(balance["aiLobSkill"])) + float(style.lob),
		0.0,
		0.85,
	)
	var choice: float = Rng.next_random(state)
	var overhead_ready: bool = at_net and contact_height >= 58.0 and state.rallyHits > 0
	var attack := attack_read(state, paddle, contact_height)
	var smash_chance: float = clampf(
		0.08 + float(profile["skill"]) * 0.14 + attack * (float(balance["attackReadSmashGain"]) + float(profile["skill"]) * float(balance["attackReadSmashSkillGain"])) + float(style.smash),
		0.0,
		float(balance["attackReadSmashCap"]),
	)
	var returning_smash := is_smash_shot(state.incomingShot)
	if returning_smash and ai_timing < float(balance["smashReturnCounterTiming"]):
		return {
			"kind": "lob",
			"x": clampf(center_x + (Rng.next_random(state) - 0.5) * 180.0, float(court["left"]) + 120.0, float(court["right"]) - 120.0),
			"y": target_y_for_side(opponent_side, 196.0),
			"flightTime": 1.34,
		}
	var kind := "drive"
	if overhead_ready and choice < smash_chance:
		var x3_chance: float = clampf((float(profile["skill"]) - 0.48) * 0.55, 0.02, 0.16)
		kind = "smash-x3" if Rng.next_random(state) < x3_chance else "smash-x2"
	elif not (at_net and contact_height >= 46.0) and choice < lob_chance:
		kind = "lob"
	elif at_net and state.ball.z > 42.0 and choice < 0.78 + attack * float(balance["attackReadVolleyGain"]):
		kind = "vibora" if Rng.next_random(state) < 0.28 + float(profile["skill"]) * 0.12 else "volley"

	var shot_setups := {
		"lob": {"depth": 202.0, "lateral": 76.0, "margin": 92.0, "flightTime": 1.28},
		"smash-x2": {"depth": 222.0, "lateral": 52.0, "margin": 82.0, "flightTime": 0.62},
		"smash-x3": {"depth": 218.0, "lateral": 260.0, "margin": 48.0, "flightTime": 0.66},
		"vibora": {"depth": 154.0, "lateral": 184.0, "margin": 68.0, "flightTime": 0.84},
		"volley": {"depth": 132.0, "lateral": 142.0, "margin": 76.0, "flightTime": 0.8},
		"drive": {"depth": 168.0, "lateral": 126.0, "margin": 84.0, "flightTime": 0.98},
	}
	var setup: Dictionary = shot_setups.get(kind, shot_setups["drive"])
	# Preserve lob, smash defence and comfortable volleys. A genuine low,
	# stretched drive becomes a playable block, not a forced miss or a free point.
	var containment := 0.0
	if kind == "drive" and at_net and not returning_smash:
		containment = Tactics.containment(contact_height, absf(state.ball.x - paddle.x) / maxf(1.0, contact_width(paddle, state.ball)), paddle.moveRatio, float(profile["skill"]))
		setup = setup.duplicate()
		setup["depth"] = lerpf(float(setup["depth"]), 120.0, containment)
		setup["flightTime"] = lerpf(float(setup["flightTime"]), 1.12, containment)
	var ampiezza: float = float(balance["aiAimWidthBase"]) + float(profile["skill"]) * float(balance["aiAimWidthSkill"])
	var x: float = clampf(
		center_x + side_bias * float(setup["lateral"]) * ampiezza + (Rng.next_random(state) - 0.5) * accuracy_error,
		float(court["left"]) + float(setup["margin"]),
		float(court["right"]) - float(setup["margin"]),
	)
	return {
		"kind": kind,
		"x": x,
		"y": target_y_for_side(opponent_side, float(setup["depth"])),
		"flightTime": float(setup["flightTime"]) * (1.06 - float(profile["skill"]) * 0.08),
		"containment": containment,
	}


static func ai_shot_error(state: State, profile: Dictionary, assessment: Dictionary, kind: String = "drive") -> Variant:
	var balance: Dictionary = Frozen.balance()
	var rally: float = minf(1.0, maxf(0.0, (state.rallyHits - 2) / 10.0))
	var aggressive: bool = kind == "smash-x2" or kind == "smash-x3" or kind == "vibora"
	var execution_miss: float = clampf(
		(float(balance["shotErrorThreshold"]) - float(assessment["quality"])) / float(balance["shotErrorSpan"]),
		0.0,
		1.0,
	)
	var chance: float = clampf(
		pow(1.0 - float(profile["skill"]), 2.0) * float(balance["aiErrorSkillWeight"])
			+ pow(execution_miss, float(balance["shotErrorCurve"])) * float(balance["aiErrorExecutionWeight"])
			+ float(assessment["risk"]) * (1.0 - float(profile["skill"])) * 0.1
			+ rally * (1.0 - float(assessment["energy"])) * 0.12
			+ (0.025 if aggressive else 0.0),
		0.02,
		0.38,
	)
	var roll: float = Rng.next_random(state)
	if roll < chance * (0.34 if aggressive else 0.16):
		return {"type": "out"}
	if roll < chance:
		return {"type": "short"}
	return null


static func roll_shot_error(state: State, assessment: Dictionary, aimed_offset: float, tight: float = 0.0, tight_depth: float = 0.0) -> Variant:
	var balance: Dictionary = Frozen.balance()
	var miss: float = clampf(
		(float(balance["shotErrorThreshold"]) - float(assessment["quality"])) / float(balance["shotErrorSpan"]),
		0.0,
		1.0,
	)
	if miss <= 0.0:
		return null
	var chance: float = pow(miss, float(balance["shotErrorCurve"])) * float(balance["shotErrorMaxChance"])
	if Rng.next_random(state) >= chance:
		return null
	var wide_share: float = float(balance["shotErrorWideShare"])
	if tight > 0.0:
		wide_share = wide_share + clampf(tight, 0.0, 1.0) * (float(balance["tightAngleWideShare"]) - float(balance["shotErrorWideShare"]))
	if tight_depth > 0.02 and Rng.next_random(state) < clampf(tight_depth, 0.0, 1.0) * float(balance["tightDepthLongShare"]):
		return {"type": "long"}
	if absf(aimed_offset) >= float(balance["shotErrorWideAim"]) and Rng.next_random(state) < wide_share:
		return {"type": "wide"}
	return {"type": "long"} if float(assessment["timingBias"]) > 0.05 else {"type": "net"}


static func report_shot_error(state: State, paddle: Ent.SimPaddle, shot_error: Dictionary) -> void:
	if not paddle.controlled:
		return
	var kind := String(shot_error["type"])
	var id := "evShotLong" if kind == "long" else ("evShotWide" if kind == "wide" else "evShotNet")
	add_event(state, id)


static func set_computer_trajectory(ball: Ent.SimBall, target_x: float, target_y: float, flight_time: float) -> void:
	var balance: Dictionary = Frozen.balance()
	var drag_rate: float = -60.0 * log(float(balance["airDrag"]))
	var drag_distance_factor: float = (1.0 - exp(-drag_rate * flight_time)) / (drag_rate * flight_time) if drag_rate > 0.0001 else 1.0
	var drag_compensation: float = 1.0 / drag_distance_factor
	ball.vx = ((target_x - ball.x) / flight_time) * drag_compensation
	ball.vy = ((target_y - ball.y) / flight_time) * drag_compensation
	ball.vz = (float(balance["ballGravity"]) * flight_time * flight_time * 0.5 - ball.z) / flight_time


static func apply_computer_shot(state: State, paddle: Ent.SimPaddle, contact_height: float = 0.0) -> void:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	ball.backspin = 0.0
	var opponent_side := "ai" if paddle.isPlayer else "player"
	var center_x: float = (float(court["left"]) + float(court["right"])) / 2.0
	var profile := computer_profile(state, paddle)
	var pressure: float = 0.0 if paddle.isPlayer else state.aiShotPressure
	var timing_variance: float = (Rng.next_random(state) - 0.5) * maxf(0.05, float(balance["aiTimingSpread"]) - float(profile["skill"]) * float(balance["aiTimingSpreadSkill"]))
	var ai_timing: float = clampf(
		float(balance["aiTimingBase"]) + float(profile["skill"]) * float(balance["aiTimingSkill"]) - pressure * 0.25 + timing_variance,
		0.25,
		1.0,
	)
	var target := choose_computer_shot(state, paddle, profile, contact_height, ai_timing)
	var ai_charge: float = (0.38 + float(profile["skill"]) * 0.34) if (String(target["kind"]) == "lob" or String(target["kind"]) == "drive") else (0.62 + float(profile["skill"]) * 0.28)
	var target_aim: float = clampf(
		(float(target["x"]) - center_x) / ((float(court["right"]) - float(court["left"])) * 0.42),
		-1.0,
		1.0,
	)
	var assessment := evaluate_shot_quality(state, paddle, {
		"charge": ai_charge, "aim": target_aim, "variant": target["kind"], "aiTiming": ai_timing,
	})
	var error: Variant = ai_shot_error(state, profile, assessment, String(target["kind"]))
	consume_rally_energy(state, paddle, assessment, String(target["kind"]), String(target["kind"]) == "vibora")

	if error != null and String(error["type"]) == "out":
		var target_y_out: float = float(court["top"]) - 34.0 if opponent_side == "ai" else float(court["bottom"]) + 34.0
		set_computer_trajectory(ball, center_x + (Rng.next_random(state) - 0.5) * 260.0, target_y_out, 0.78)
		ball.shotType = "error"
		if not paddle.isPlayer:
			add_event(state, "evAiForced")
		return

	if error != null and String(error["type"]) == "short":
		var variant_roll: float = Rng.next_random(state)
		var target_x: float
		var target_y: float
		var flight_time: float
		if variant_roll < 0.45:
			target_x = center_x + (Rng.next_random(state) - 0.5) * 220.0
			target_y = target_y_for_side(opponent_side, 142.0)
			flight_time = 1.16
		elif variant_roll < 0.75:
			target_x = float(court["left"]) + 82.0 if Rng.next_random(state) < 0.5 else float(court["right"]) - 82.0
			target_y = target_y_for_side(opponent_side, 176.0)
			flight_time = 1.08
		else:
			target_x = center_x + (Rng.next_random(state) - 0.5) * 130.0
			target_y = target_y_for_side(opponent_side, 78.0)
			flight_time = 1.02
		set_computer_trajectory(ball, target_x, target_y, flight_time)
		ball.backspin = 0.3
		ball.spin = clampf(ball.vx * 0.05, -18.0, 18.0)
		if not paddle.isPlayer:
			state.aiRecoveryMode = true
			add_event(state, "evOppOutOfPos")
		return

	var power_scale: float = clampf(float(profile["power"]), 0.84, 1.08)
	var atleta_power: float = clampf(paddle_ratio(state, paddle, "power"), 0.85, 1.2)
	var execution_spread: float = float(assessment["risk"]) * (1.0 - float(profile["skill"]) * 0.45)
	target["x"] = float(target["x"]) + (Rng.next_random(state) - 0.5) * execution_spread * 150.0
	target["y"] = float(target["y"]) + (Rng.next_random(state) - 0.45) * execution_spread * 105.0
	var kind := String(target["kind"])
	if kind == "smash-x2" or kind == "smash-x3":
		var smash_target_y: float = float(court["top"]) + 44.0 if opponent_side == "ai" else float(court["bottom"]) - 44.0
		set_computer_trajectory(ball, float(target["x"]), smash_target_y, float(target["flightTime"]) / (power_scale * atleta_power))
		ball.shotType = kind
		ball.smashTargetSide = opponent_side
		ball.topspin = 1.12 if kind == "smash-x3" else 0.98
		if kind == "smash-x3":
			ball.spin = js_sign_or(float(target["x"]) - center_x, 1.0) * 76.0
		else:
			ball.spin = clampf(ball.vx * 0.04, -24.0, 24.0)
	else:
		set_computer_trajectory(ball, float(target["x"]), float(target["y"]), float(target["flightTime"]) / ((0.92 + power_scale * 0.08) * atleta_power))
		ball.shotType = kind
		ball.spin = clampf(ball.vx * (0.2 if kind == "vibora" else 0.08), -72.0, 72.0)
		if kind == "vibora":
			ball.backspin = 0.76
	if not paddle.isPlayer:
		state.aiRecoveryMode = false
		if kind == "lob":
			add_event(state, "evOppLob")
		elif kind == "volley":
			add_event(state, "evCoverCenter")
		elif kind == "vibora":
			add_event(state, "evOppVibora")
		elif kind == "smash-x2":
			add_event(state, "evOppSmashX2")
		elif kind == "smash-x3":
			add_event(state, "evOppSmashX3")


# ---------------------------------------------------------------------------
# `hitBall` (`js/game.js:1468-1921`)
# ---------------------------------------------------------------------------

static func hit_ball(state: State, paddle: Ent.SimPaddle, power: float = 1.0, is_special: bool = false, force_contact: bool = false, aim: float = 0.0, slice: bool = false, shot_variant: String = "auto", aim_y: float = 0.0, timing_age: float = 0.0, precision: float = 0.0) -> bool:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	if paddle.hitCooldown > 0.0 or (not force_contact and not can_hit(paddle, ball)):
		return false

	var contact_height := ball.z
	var offset: float = clampf((ball.x - paddle.x) / (paddle.w / 2.0), -1.0, 1.0)
	var raw_charge: float = clampf((power - 0.4) / 0.95, 0.0, 1.0)
	var assessment := evaluate_shot_quality(state, paddle, {
		"charge": raw_charge, "aim": aim, "variant": shot_variant, "timingAge": timing_age,
	})
	var power_mul := hit_power_profile(paddle, state, power)
	var control: float
	if paddle.isPlayer:
		control = float(athlete_for(state, paddle)["stats"]["control"])
	elif state.pvp and paddle.controlled:
		control = float(state.pvpAthlete["stats"]["control"]) if state.pvpAthlete != null else (0.92 + float(state.ai["skill"]) * 0.1)
	else:
		control = (0.92 + float(state.ai["skill"]) * 0.1) * paddle_ratio(state, paddle, "control", 0.6)
	var direction: float = -1.0 if paddle.isPlayer else 1.0
	ball.y = paddle.y + direction * (ball.r + 6.0)
	ball.z = maxf(22.0, minf(ball.z, 74.0))
	ball.topspin = 0.0
	state.incomingShot = ball.shotType
	ball.wallKill = 0.0
	var returning_smash := is_smash_shot(state.incomingShot)
	ball.shotType = "drive"
	ball.smashStage = 0
	ball.smashTargetSide = null
	ball.postGlassSide = null
	ball.wallAngleResolved = false

	if paddle.controlled:
		var shot_power: float = clampf(power_mul, 0.34, 1.5)
		var read_smash: bool = String(assessment["grade"]) == "perfect" or (String(assessment["grade"]) == "good" and paddle.splitStep >= float(balance["smashCounterSplitStep"]))
		var smash_defence: bool = returning_smash and not read_smash
		var scrambled: bool = returning_smash and String(assessment["grade"]) != "perfect" and String(assessment["grade"]) != "good"
		var base_freedom: float = 0.78 if String(assessment["profile"]) == "control" else (0.96 if String(assessment["profile"]) == "attack" else 1.1)
		var aim_freedom: float = base_freedom * (float(balance["smashReturnScrambleAim"]) if scrambled else (float(balance["smashReturnDefenceAim"]) if smash_defence else 1.0))
		var aimed_offset: float = clampf(aim * control * aim_freedom + offset * 0.24, -1.0, 1.0)
		var aimed_depth: float = clampf(aim_y, -1.0, 1.0)
		var center_x: float = (float(court["left"]) + float(court["right"])) / 2.0
		var near_net := within_net_range(paddle, float(balance["smashNetWindow"]))
		var vibora_range := within_net_range(paddle, float(balance["smashNetWindow"]) if shot_variant == "vibora" else float(balance["viboraNetWindow"]))
		var explicit_smash: bool = shot_variant == "smash"
		var service_return: bool = state.rallyHits == 0
		var smash_ready: bool = (not slice) \
			and (explicit_smash or shot_variant == "auto") \
			and (not service_return) \
			and near_net \
			and contact_height >= float(balance["smashMinHeight"]) \
			and shot_power >= float(balance["smashMinPower"])
		var smash_type: Variant = null
		if smash_ready and explicit_smash:
			if aimed_depth <= -0.28:
				smash_type = "smash-x3" if absf(aimed_offset) >= 0.42 else "smash-x2"
			elif aimed_depth >= 0.32:
				smash_type = "bandeja"
			else:
				smash_type = "smash-flat"
		elif smash_ready:
			smash_type = "smash-x3" if absf(aimed_offset) >= 0.52 else "smash-x2"
		elif explicit_smash:
			smash_type = "bandeja"
		var seeks_side_glass: bool = smash_type == null and (not slice) and shot_variant != "lob" and absf(aimed_offset) >= 0.72
		var safe_power: float = 1.16 + (control - 1.0) * 0.16
		var overcharge_risk: float = maxf(0.0, shot_power - safe_power)
		var control_risk: float = clampf(1.3 - control, 0.06, 0.46)
		var profile_risk: float = 1.34 if String(assessment["profile"]) == "risk" else (1.0 if String(assessment["profile"]) == "attack" else 0.62)
		var rt_travel: float = clampf(precision, 0.0, 1.0)
		var lateral_dominant: bool = absf(aimed_offset) >= absf(aimed_depth)
		var tight: float = rt_travel * clampf((absf(aimed_offset) - 0.55) / 0.35, 0.0, 1.0) if lateral_dominant else 0.0
		var tight_depth: float = 0.0 if lateral_dominant else rt_travel * clampf((-aimed_depth - 0.55) / 0.35, 0.0, 1.0)
		var aim_reach: float = 0.42 + tight * float(balance["tightAngleReachGain"])
		var execution_risk: float = float(assessment["risk"]) * (0.72 + control_risk * 0.7) * profile_risk
		var tight_spread: float = tight * float(balance["tightAngleMinSpread"]) / maxf(0.6, control)
		var lateral_jitter: float = (Rng.next_random(state) - 0.5) \
			* ((overcharge_risk * control_risk * 300.0 + execution_risk * 170.0)
				* (1.0 - clampf(precision, 0.0, 1.0) * float(balance["tightAngleJitterCut"]))
				+ tight_spread)
		var depth_jitter: float = (Rng.next_random(state) - 0.44) * (overcharge_risk * control_risk * 480.0 + execution_risk * 210.0)
		var target_margin: float
		if seeks_side_glass or tight > 0.2:
			target_margin = js_round(30.0 - tight * (30.0 - float(balance["tightAngleMargin"])))
		elif String(assessment["profile"]) == "control":
			target_margin = 108.0
		elif String(assessment["profile"]) == "attack":
			target_margin = 72.0
		else:
			target_margin = 48.0
		var execution_miss: float = clampf(
			(float(balance["shotErrorThreshold"]) - float(assessment["quality"])) / float(balance["shotErrorSpan"]),
			0.0,
			1.0,
		)
		var shot_error: Variant = roll_shot_error(state, assessment, aimed_offset, tight, tight_depth)
		var raw_target_x: float = center_x + aimed_offset * (float(court["right"]) - float(court["left"])) * aim_reach + lateral_jitter
		var target_x: float
		if shot_error != null and String(shot_error["type"]) == "wide":
			target_x = center_x + js_sign_or(aimed_offset, 1.0) * ((float(court["right"]) - float(court["left"])) * 0.5 + 52.0)
		elif overcharge_risk > 0.04 or execution_risk > 0.34:
			target_x = clampf(raw_target_x, float(court["left"]) - 24.0, float(court["right"]) + 24.0)
		else:
			target_x = clampf(raw_target_x, float(court["left"]) + target_margin, float(court["right"]) - target_margin)
		var base_target_depth: float = (78.0 + shot_power * 46.0) if slice else (72.0 + shot_power * 78.0)
		var target_depth: float = clampf(
			base_target_depth
				- aimed_depth * 42.0
				+ overcharge_risk * 70.0
				+ depth_jitter
				- execution_miss * float(balance["shotErrorShort"])
				+ execution_miss * float(assessment["timingBias"]) * float(balance["shotErrorDepth"])
				- (float(balance["smashReturnScrambleDepth"]) if scrambled else (float(balance["smashReturnDefenceDepth"]) if smash_defence else 0.0))
				+ tight_depth * float(balance["tightDepthReachGain"])
				+ (Rng.next_random(state) - 0.5) * tight_depth * float(balance["tightDepthMinSpread"]) / maxf(0.6, control),
			62.0,
			float(balance["shotErrorMaxDepth"]),
		)
		var opponent_side := "ai" if paddle.isPlayer else "player"
		var target_y: float
		if shot_error != null and String(shot_error["type"]) == "long":
			target_y = (float(court["top"]) - 30.0) if opponent_side == "ai" else (float(court["bottom"]) + 30.0)
		else:
			target_y = target_y_for_side(opponent_side, target_depth)
		var quality_pace: float = float(balance["qualityPaceBase"]) + float(assessment["quality"]) * float(balance["qualityPaceSpan"])
		var defence_arc: float = float(balance["smashReturnScrambleArc"]) if scrambled else (float(balance["smashReturnDefenceArc"]) if smash_defence else 0.0)
		var base_flight: float = (1.14 - shot_power * 0.20) if slice else (1.12 - shot_power * 0.26)
		var flight_time: float = (base_flight + defence_arc) / quality_pace
		if shot_error != null and String(shot_error["type"]) == "net":
			set_computer_trajectory(ball, target_x, float(court["netY"]), flight_time * 0.66)
		else:
			set_computer_trajectory(ball, target_x, target_y, flight_time)
		ball.spin = aimed_offset * 45.0 * control
		ball.backspin = 0.65 + shot_power * 0.35 if slice else 0.0
		if shot_variant == "chiquita":
			var chiquita_x: float = clampf(
				center_x + aimed_offset * (float(court["right"]) - float(court["left"])) * 0.3,
				float(court["left"]) + 62.0,
				float(court["right"]) - 62.0,
			)
			var chiquita_depth: float = 62.0 + shot_power * 34.0 - aimed_depth * 18.0
			set_computer_trajectory(ball, chiquita_x, target_y_for_side("ai" if paddle.isPlayer else "player", chiquita_depth), 1.02)
			ball.backspin = 0.55
			ball.spin = aimed_offset * 30.0 * control
			ball.shotType = "chiquita"
			add_event(state, "evChiquita")
		elif shot_variant == "lob" or shot_variant == "defensive-lob":
			var defensive_lob: bool = shot_variant == "defensive-lob"
			var power_ratio: float = clampf((shot_power - 0.34) / 1.16, 0.0, 1.0)
			var safe_power_lob: float = 1.12 + (control - 1.0) * 0.18
			var overcharge: float = maxf(0.0, shot_power - safe_power_lob)
			var control_error: float = clampf(1.28 - control, 0.05, 0.42)
			var lob_risk: float = float(assessment["risk"]) * (0.7 + overcharge * 0.8)
			var lateral_error: float = (Rng.next_random(state) - 0.5) * (overcharge * control_error * 340.0 + lob_risk * 150.0)
			var depth_error: float = (Rng.next_random(state) - 0.46) * (overcharge * control_error * 320.0 + lob_risk * 190.0)
			var lob_target_x: float = center_x + aimed_offset * (float(court["right"]) - float(court["left"])) * (0.31 + overcharge * 0.12) + lateral_error
			var lob_depth: float = (112.0 if defensive_lob else 96.0) + power_ratio * (98.0 if defensive_lob else 118.0) - aimed_depth * 24.0 + overcharge * 70.0 + depth_error
			var lob_target_y := target_y_for_side("ai" if paddle.isPlayer else "player", lob_depth)
			var lob_flight_time: float = (1.68 if defensive_lob else 1.5) - power_ratio * (0.12 if defensive_lob else 0.18)
			set_computer_trajectory(ball, lob_target_x, lob_target_y, lob_flight_time)
			ball.shotType = "defensive-lob" if defensive_lob else "lob"
			add_event(state, "evLobOver" if overcharge > 0.06 else ("evLobShort" if power_ratio < 0.3 else ("evDefensiveLob" if defensive_lob else "evLobHigh")))
		elif smash_type != null and String(smash_type) == "smash-x3" and float(assessment["quality"]) >= float(balance["smashX3MinQuality"]):
			var side_sign: float = js_sign_or(aimed_offset, 1.0 if paddle.x < center_x else -1.0)
			var smash_target_x: float = center_x + side_sign * (float(court["right"]) - float(court["left"])) * 0.34
			set_computer_trajectory(ball, smash_target_x, float(court["top"]) + 50.0, 0.62)
			ball.topspin = 1.15
			ball.spin = side_sign * 82.0 * control
			ball.shotType = "smash-x3"
			ball.smashTargetSide = "ai"
			add_event(state, "evSmashX3")
		elif smash_type != null and String(smash_type) == "smash-x3" and float(assessment["quality"]) >= float(balance["smashX2MinQuality"]):
			var smash_target_x: float = center_x + aimed_offset * (float(court["right"]) - float(court["left"])) * 0.12
			set_computer_trajectory(ball, smash_target_x, float(court["top"]) + 44.0, 0.61)
			ball.topspin = 0.96
			ball.spin = aimed_offset * 25.0
			ball.shotType = "smash-x2"
			ball.smashTargetSide = "ai"
			add_event(state, "evSmashX3Downgrade")
		elif smash_type != null and String(smash_type) == "smash-x2" and float(assessment["quality"]) >= float(balance["smashX2MinQuality"]):
			var smash_target_x: float = center_x + aimed_offset * (float(court["right"]) - float(court["left"])) * 0.12
			set_computer_trajectory(ball, smash_target_x, float(court["top"]) + 44.0, 0.58)
			ball.topspin = 1.0
			ball.spin = aimed_offset * 28.0
			ball.shotType = "smash-x2"
			ball.smashTargetSide = "ai"
			add_event(state, "evSmashX2Deep")
		elif smash_ready and smash_type != null and float(assessment["quality"]) >= float(balance["smashFlatMinQuality"]):
			var flat_target_x: float = clampf(
				center_x + aimed_offset * (float(court["right"]) - float(court["left"])) * 0.24,
				float(court["left"]) + 76.0,
				float(court["right"]) - 76.0,
			)
			set_computer_trajectory(ball, flat_target_x, float(court["netY"]) - 174.0, 0.61)
			ball.topspin = 0.72
			ball.shotType = "smash-flat"
			add_event(state, "evSmashCenter" if String(smash_type) == "smash-flat" else "evSmashFlatFallback")
		elif smash_type != null:
			var bandeja_side: float = js_sign_or(aimed_offset, 1.0)
			var bandeja_target_x: float = center_x + bandeja_side * (float(court["right"]) - float(court["left"])) * 0.22
			set_computer_trajectory(ball, bandeja_target_x, float(court["netY"]) - 152.0, 1.02)
			ball.backspin = 0.58
			ball.spin = bandeja_side * 48.0
			ball.shotType = "bandeja"
			add_event(state, "evBandejaConverted" if (explicit_smash and ((not smash_ready) or float(assessment["quality"]) < float(balance["smashX2MinQuality"]))) else "evBandeja")
		elif seeks_side_glass:
			ball.shotType = "wall-angle"
			ball.spin = aimed_offset * 68.0 * control
			add_event(state, "evAngleWall")
		elif shot_variant == "globo":
			var globo_riuscito: bool = float(assessment["quality"]) >= float(balance["globoMinQuality"])
			var globo_depth: float = float(balance["globoDepth"]) if globo_riuscito else float(balance["globoFailDepth"])
			set_computer_trajectory(
				ball,
				clampf(center_x + aimed_offset * (float(court["right"]) - float(court["left"])) * 0.26, float(court["left"]) + 96.0, float(court["right"]) - 96.0),
				target_y_for_side("ai" if paddle.isPlayer else "player", globo_depth),
				float(balance["globoFlightTime"]) if globo_riuscito else float(balance["globoFailFlightTime"]),
			)
			ball.shotType = "globo" if globo_riuscito else "lob"
			if globo_riuscito and paddle.isPlayer:
				state.aiRecoveryMode = true
			add_event(state, "evGlobo" if globo_riuscito else "evGloboShort")
		elif shot_variant == "cut-volley" and float(assessment["quality"]) >= float(balance["cutVolleyMinQuality"]):
			var cut_side: float = js_sign_or(aimed_offset, 1.0)
			set_computer_trajectory(
				ball,
				clampf(center_x + aimed_offset * (float(court["right"]) - float(court["left"])) * 0.3, float(court["left"]) + 70.0, float(court["right"]) - 70.0),
				target_y_for_side("ai" if paddle.isPlayer else "player", float(balance["cutVolleyDepth"])),
				float(balance["cutVolleyFlightTime"]),
			)
			ball.backspin = float(balance["cutVolleyBackspin"])
			ball.spin = cut_side * 52.0 * control
			ball.shotType = "cut-volley"
			ball.wallKill = clampf(float(assessment["quality"]), 0.0, 1.0)
			add_event(state, "evCutVolley")
		elif slice:
			if vibora_range and contact_height >= (42.0 if shot_variant == "vibora" else 48.0):
				var vibora_side: float = js_sign_or(aimed_offset, 1.0)
				var vibora_depth: float = 132.0 + shot_power * 28.0 + overcharge_risk * 96.0
				set_computer_trajectory(
					ball,
					center_x + vibora_side * (float(court["right"]) - float(court["left"])) * 0.31,
					target_y_for_side("ai" if paddle.isPlayer else "player", vibora_depth),
					0.82,
				)
				ball.backspin = 0.82
				ball.spin = vibora_side * 76.0
				ball.shotType = "vibora"
				add_event(state, "evVibora")
			else:
				ball.shotType = "slice"
				add_event(state, "evSlice")
		if shot_error != null and (ball.shotType == "drive" or ball.shotType == "slice" or ball.shotType == "wall-angle"):
			report_shot_error(state, paddle, shot_error)
		if is_special:
			apply_special(state, aimed_offset, paddle)
		consume_rally_energy(state, paddle, assessment, ball.shotType, slice)
		show_shot_feedback(state, paddle, assessment)
		if explicit_smash and state.shotFeedback != null:
			var successful_smash: bool = ball.shotType.begins_with("smash-")
			var label: String
			if successful_smash:
				label = "shotSmashX3" if ball.shotType == "smash-x3" else ("shotSmashX2" if ball.shotType == "smash-x2" else "shotSmashFlat")
			else:
				label = "shotBandejaFallback"
			state.shotFeedback["text"] = label
			state.shotFeedback["mode"] = String(assessment["grade"]).to_upper() if successful_smash else "smashNotReady"
		state.receiverLocked = false
		state.manualReceiverOverride = false
		state.serviceReceiverKey = null
		if not paddle.isPlayer:
			state.aiServiceReceiverKey = null
	else:
		apply_computer_shot(state, paddle, contact_height)
		if not paddle.isPlayer:
			state.aiPrimaryKey = "opponent" if paddle == state.opponent else "opponentMate"
			state.aiServiceReceiverKey = null
			state.aiReceiverLocked = false
			state.aiReactionDelay = 0.0
			lock_receiver_for_incoming_shot(state)

	if paddle.isPlayer:
		lock_ai_receiver_for_incoming_shot(state)
		if state.specialReadPenalty != 0.0:
			state.aiReactionDelay += state.specialReadPenalty
			state.specialReadPenalty = 0.0
		if ball.shotType == "smash-x2" or ball.shotType == "smash-x3":
			var letto: bool = Rng.next_random(state) < clampf(
				float(balance["smashInterceptBase"]) + float(state.ai["skill"]) * float(balance["smashInterceptSkill"]),
				0.0,
				float(balance["smashInterceptCap"]),
			)
			var smash_read_penalty: float = float(balance["smashInterceptPenalty"]) if letto else (0.48 if ball.shotType == "smash-x2" else 0.18)
			if letto:
				add_event(state, "evSmashIntercepted")
			var reaction_skill: float = float(state.ai["reactionSkill"]) if state.ai.has("reactionSkill") else float(state.ai["skill"])
			state.aiReactionDelay += smash_read_penalty + (1.0 - reaction_skill) * 0.16
			if ball.shotType == "smash-x3":
				state.aiX3Recovery = 0.9 + float(state.ai["skill"]) * 0.22
		elif ball.shotType == "lob":
			state.aiReactionDelay = maxf(0.04, state.aiReactionDelay - float(state.ai["skill"]) * 0.08)
	elif ball.shotType == "smash-x3":
		state.playerX3Recovery = float(balance["playerX3RecoveryWindow"])

	ball.serveInFlight = false
	ball.serveTouchedNet = false
	ball.netFaultOwner = null
	ball.netCord = 0.0
	ball.crossedNet = false
	state.lastHitterSide = "player" if paddle.isPlayer else "ai"
	ball.bounces = {"player": 0, "ai": 0}

	paddle.shotIntent = ball.shotType
	paddle.actionIntent = ball.shotType
	paddle.actionPose = 0.42
	paddle.swing = 1.0
	paddle.swingSide = -1.0 if (aim if paddle.controlled else offset) < -0.08 else 1.0
	paddle.hitCooldown = float(balance["hitCooldownPlayer"]) if paddle.isPlayer else float(balance["hitCooldownAi"])
	ball.hitFlash = 1.0
	ball.hitPulse = 1.0
	var finishing_shot: bool = ball.shotType == "smash-x2" or ball.shotType == "smash-x3" or ball.shotType == "smash" or ball.shotType == "smash-flat" or ball.shotType == "vibora"
	if finishing_shot:
		ball.hitFlash = 1.35
		ball.hitPulse = 1.25
	state.rallyHits += 1
	state.combo = int(minf(float(balance["comboMax"]), 1.0 + floor(state.rallyHits / float(balance["comboStep"]))))
	state.flash = 0.65
	if paddle.controlled:
		var fin: bool = ball.shotType == "smash-x2" or ball.shotType == "smash-x3"
		if fin:
			state.hapticPulse = {"duration": 120, "strong": 0.82, "weak": 0.48}
		elif ball.shotType == "smash-flat" or ball.shotType == "vibora":
			state.hapticPulse = {"duration": 82, "strong": 0.58, "weak": 0.38}
		else:
			state.hapticPulse = {"duration": 48, "strong": 0.26, "weak": 0.3}
	# `EVENT_LINES.length` is sim-visible even though the text is not
	# (`simulation-port-boundary.md` §5): the pick consumes a draw.
	if state.rallyHits > 0 and state.rallyHits % 5 == 0:
		add_event(state, "eventLine%d" % int(floor(Rng.next_random(state) * float(Frozen.event_lines().size()))))
	return true


## `applySpecial` (`js/game.js:1923-1976`). The `state.fx.shake` write at `1973`
## is a particle-buffer write (the `fx` coupling); the simulation state it does
## not touch is unaffected, so the shake line is dropped rather than ported.
static func apply_special(state: State, offset: float, paddle: Ent.SimPaddle) -> void:
	var court: Dictionary = Frozen.court()
	var athlete := state.athlete
	var ball := state.ball
	var id := String(athlete.get("id", ""))
	if id == "maestro":
		ball.vx = offset * 480.0
		ball.vy = -470.0
		ball.vz = 325.0
		state.specialReadPenalty = 0.13
		add_event(state, "evPrecision")
	elif id == "pantera":
		paddle.dashTimer = 0.26
		ball.vy = -455.0
		ball.vz = 300.0
		add_event(state, "evLightningDash")
	elif id == "steamer":
		var wall_side: float = js_sign_or(offset, 1.0 if paddle.x < (float(court["left"]) + float(court["right"])) / 2.0 else -1.0)
		ball.vx = wall_side * 470.0
		ball.vy = -520.0
		ball.vz = 410.0
		ball.spin = wall_side * 74.0
		ball.shotType = "wall-angle"
		add_event(state, "evSteamSmash")
	elif id == "fiamma":
		state.shieldTimer = 2.2
		ball.vy = -410.0
		ball.vz = 280.0
		add_event(state, "evSteamShield")
	elif id == "oracolo":
		ball.vx = offset * 505.0
		ball.vy = -412.0
		ball.vz = 315.0
		ball.spin = offset * 92.0
		state.specialReadPenalty = 0.26
		add_event(state, "evPerfectVision")
	elif id == "colosso":
		ball.vx = offset * 190.0
		ball.vy = -560.0
		ball.vz = 430.0
		ball.topspin = 0.9
		add_event(state, "evSteamHammer")


static func try_special(state: State) -> void:
	var balance: Dictionary = Frozen.balance()
	if state.specialCooldown > 0.0 or state.specialReady < float(balance["specialMinCharge"]):
		return
	var hit := hit_ball(state, state.active_player(), 1.15, true)
	if hit:
		state.specialCooldown = float(state.athlete["special"]["cooldown"])
		state.specialReady = 0.0
	elif String(state.athlete.get("id", "")) == "fiamma" and state.ball.vy > 0.0:
		state.shieldTimer = 2.4
		state.specialCooldown = float(state.athlete["special"]["cooldown"])
		state.specialReady = 0.0
		add_event(state, "evSteamShieldAbsorb")


# ---------------------------------------------------------------------------
# Scoring (`js/game.js:1992-2148`)
# ---------------------------------------------------------------------------

static func game_won(points: int, opponent: int) -> bool:
	return points >= 4 and points - opponent >= 2


static func finish_set(state: State, winner: String) -> void:
	state.sets[winner] = int(state.sets[winner]) + 1
	state.setScores.append({"player": state.games["player"], "ai": state.games["ai"]})
	state.games = {"player": 0, "ai": 0}
	state.tieBreak = false
	state.tieBreakPoints = {"player": 0, "ai": 0}
	add_event(state, "setToYou" if winner == "player" else "setToCircuit")
	if int(state.sets[winner]) >= int(match_format(state)["setsToWin"]):
		state.result = {"winner": winner}


static func finish_game(state: State, winner: String) -> void:
	state.games[winner] = int(state.games[winner]) + 1
	state.points = {"player": 0, "ai": 0}
	var loser: String = State.other(winner)
	var fmt := match_format(state)
	if int(state.games[winner]) >= int(fmt["gamesToWin"]) and int(state.games[winner]) - int(state.games[loser]) >= int(fmt["gameMargin"]):
		finish_set(state, winner)
	elif fmt["tieBreakAt"] != null and int(state.games["player"]) == int(fmt["tieBreakAt"]) and int(state.games["ai"]) == int(fmt["tieBreakAt"]):
		state.tieBreak = true
		state.tieBreakPoints = {"player": 0, "ai": 0}
		add_event(state, "tieBreak")
	state.serveSide = State.other(state.serveSide)
	state.serveCourt = "right"


static func record_point_stats(state: State, winner: String, kind: Variant) -> void:
	var stats: Dictionary = state.stats
	if stats.is_empty():
		return
	var loser: String = State.other(winner)
	stats["pointsWon"][winner] = int(stats["pointsWon"][winner]) + 1
	stats["longestRally"] = int(maxi(int(stats["longestRally"]), state.rallyHits))
	stats["totalRallyHits"] = int(stats["totalRallyHits"]) + state.rallyHits
	stats["rallyCount"] = int(stats["rallyCount"]) + 1
	var is_winner_shot: bool = kind == POINT_WINNER
	var is_error: bool = kind == POINT_ERROR
	if is_winner_shot:
		stats["winners"][winner] = int(stats["winners"][winner]) + 1
	if is_error:
		stats["errors"][loser] = int(stats["errors"][loser]) + 1
	if state.ball.shotType == "smash-x2" or state.ball.shotType == "smash-x3":
		stats["smashWinners"][winner] = int(stats["smashWinners"][winner]) + 1
	if state.doubleFaultFlag:
		stats["doubleFaults"][loser] = int(stats["doubleFaults"][loser]) + 1
	if is_winner_shot and winner == state.serveSide and state.rallyHits == 0:
		stats["aces"][winner] = int(stats["aces"][winner]) + 1


static func score_point(state: State, winner: String, reason: String, kind: Variant = null) -> String:
	var receiver: String = State.other(state.serveSide)
	if reason != "":
		add_event(state, reason)
	record_point_stats(state, winner, kind)
	if state.tieBreak:
		state.tieBreakPoints[winner] = int(state.tieBreakPoints[winner]) + 1
		if int(state.tieBreakPoints[winner]) >= 7 and int(state.tieBreakPoints[winner]) - int(state.tieBreakPoints[State.other(winner)]) >= 2:
			finish_set(state, winner)
	elif state.pointsToWin != 0:
		state.points[winner] = int(state.points[winner]) + 1
		if int(state.points[winner]) >= state.pointsToWin:
			state.result = {"winner": winner}
	else:
		state.points[winner] = int(state.points[winner]) + 1
		if game_won(int(state.points[winner]), int(state.points[State.other(winner)])):
			finish_game(state, winner)
	if state.pointsToWin != 0 and state.result == null:
		state.serveSide = State.other(state.serveSide)
	state.combo = 1
	state.rallyHits = 0
	state.rallyEnergy = {"player": 1.0, "ai": 1.0}
	for athlete_paddle in [state.player, state.playerMate, state.opponent, state.opponentMate]:
		if athlete_paddle != null:
			athlete_paddle.staminaEnergy = 1.0
	state.shotFeedback = null
	state.receiverLocked = false
	state.manualReceiverOverride = false
	state.serviceReceiverKey = null
	state.aiServiceReceiverKey = null
	state.aiReceiverLocked = false
	state.aiReactionDelay = 0.0
	state.aiShotPressure = 0.0
	state.aiRecoveryMode = false
	state.serveAttempts = 0
	state.serveCourt = "left" if state.serveCourt == "right" else "right"
	sync_point_display(state)
	if state.result == null:
		state.pointPause = 1.4
		state.pointMessage = "pointYou" if winner == "player" else "pointOpp"
		state.pointMessage += ":%s" % reason if reason != "" else ""
	return receiver


static func serve_fault(state: State, reason: String) -> void:
	if state.serveAttempts == 0:
		state.serveAttempts = 1
		add_event(state, "%s secondServe" % reason)
		prepare_serve(state)
		return
	state.doubleFaultFlag = true
	score_point(state, State.other(state.serveSide), "doubleFault:%s" % reason.to_lower(), POINT_ERROR)
	state.doubleFaultFlag = false


static func serve_let(state: State) -> void:
	state.ball.serveInFlight = false
	state.pointPause = 1.0
	state.pointMessage = "LET"
	add_event(state, "evLet")


static func valid_service_bounce(state: State, side: String) -> bool:
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	var net_y := float(court["netY"])
	var receiver: String = State.other(state.serveSide)
	if side != receiver:
		return false
	var service_top := net_y - SERVICE_LINE_OFFSET
	var service_bottom := net_y + SERVICE_LINE_OFFSET
	var in_depth: bool
	if receiver == "ai":
		in_depth = ball.y >= service_top and ball.y < net_y
	else:
		in_depth = ball.y > net_y and ball.y <= service_bottom
	var is_left: bool = ball.x < (float(court["left"]) + float(court["right"])) / 2.0
	return in_depth and ((is_left) if ball.serveTargetSide == "left" else (not is_left))


# ---------------------------------------------------------------------------
# Bounce / walls / net (`js/game.js:2150-2414`)
# ---------------------------------------------------------------------------

static func handle_ground_bounce(state: State, impact_vz: float, remaining_time: float) -> bool:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	var side := court_side(ball.y)
	if ball.netFaultOwner != null:
		score_point(state, State.other(String(ball.netFaultOwner)), "msgNetFault", POINT_ERROR)
		return true
	if ball.y < float(court["top"]) or ball.y > float(court["bottom"]):
		score_point(state, State.other(side), "msgOut", POINT_ERROR)
		return true
	if ball.serveInFlight:
		if not valid_service_bounce(state, side):
			serve_fault(state, "serveOutBox")
			return true
		if ball.serveTouchedNet:
			serve_let(state)
			return true
		ball.serveInFlight = false
		ball.bounces[side] = 1
		add_event(state, "evServeValid")
	else:
		if state.lastHitterSide != null and String(state.lastHitterSide) == side and not ball.crossedNet:
			score_point(state, State.other(side), "msgNetShort", POINT_ERROR)
			return true
		ball.bounces[side] = int(ball.bounces[side]) + 1
		if int(ball.bounces[side]) > 1:
			score_point(state, State.other(side), "msgDoubleBounce", POINT_WINNER)
			return true
	var impact_speed: float = absf(impact_vz)
	var speed_factor: float = clampf(impact_speed / 520.0, 0.0, 1.0)
	var slice_amount: float = clampf(ball.backspin, 0.0, 1.2)
	var topspin_amount: float = clampf(ball.topspin, 0.0, 1.3)
	var restitution: float = (float(balance["groundRestitution"]) + float(balance["groundRestitutionBoost"]) * speed_factor) \
		* (1.0 - slice_amount * 0.28) + topspin_amount * 0.12
	var minimum_bounce: float = float(balance["minimumBounceVz"]) * (1.0 - slice_amount * 0.26)
	var rebound_vz: float = maxf(minimum_bounce, impact_speed * restitution)
	ball.vx = (ball.vx + ball.spin * float(balance["groundSpinTransfer"])) * float(balance["groundTangentialDamping"])
	ball.vy *= float(balance["groundTangentialDamping"]) * (1.0 - slice_amount * 0.14) * (1.0 + topspin_amount * 0.08)
	ball.spin *= 0.7
	ball.backspin *= 0.35
	ball.topspin *= 0.72
	if (ball.shotType == "smash-x2" or ball.shotType == "smash-x3") and ball.smashTargetSide != null and String(ball.smashTargetSide) == side:
		ball.smashStage = int(maxi(ball.smashStage, 1))
		add_event(state, "evSmashValid")
	ball.z = maxf(0.0, rebound_vz * remaining_time - 0.5 * float(balance["ballGravity"]) * remaining_time * remaining_time)
	ball.vz = rebound_vz - float(balance["ballGravity"]) * remaining_time
	ball.bouncePulse = 1.0
	ball.landRing = 0.5
	return false


## Ordered pick of the two defenders by distance from the ball. The JavaScript
## sorts with V8's *stable* `sort` and takes element 0 (`js/game.js:2231-2233`);
## Godot's `sort_custom` is not stable, and on a tied distance the two engines
## would pick different defenders and then consume RNG on different branches
## (risk 4 in the boundary ticket). So the choice is made explicitly, with the
## first array element winning ties — the same result a stable sort gives.
static func nearest_defender(defenders: Array, ball: Ent.SimBall) -> Dictionary:
	var best_index := 0
	var best_distance := hypot2(defenders[0].x - ball.x, defenders[0].y - ball.y)
	for i in range(1, defenders.size()):
		var d := hypot2(defenders[i].x - ball.x, defenders[i].y - ball.y)
		if d < best_distance:
			best_distance = d
			best_index = i
	return {"paddle": defenders[best_index], "distance": best_distance}


static func handle_walls(state: State) -> bool:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	var side := court_side(ball.y)
	var has_bounced: bool = int(ball.bounces[side]) > 0
	var hit_side_wall: bool = ball.x - ball.r < float(court["left"]) or ball.x + ball.r > float(court["right"])
	var hit_back_wall: bool = ball.y - ball.r < float(court["top"]) or ball.y + ball.r > float(court["bottom"])
	if not hit_side_wall and not hit_back_wall:
		return false
	if not has_bounced:
		if ball.serveInFlight:
			serve_fault(state, "serveWallFault")
			return true
		if state.lastHitterSide == null or String(state.lastHitterSide) != side or ball.crossedNet:
			score_point(state, side, "msgWallNoBounce", POINT_WINNER)
			return true
		add_event(state, "evOwnWallOut")
	var wall_bounce: float = float(state.arena["wallBounce"])
	if hit_side_wall and ball.shotType == "smash-x3" and ball.smashStage >= 2:
		var defenders: Array = [state.opponent, state.opponentMate] if side == "ai" else [state.player, state.playerMate]
		var recovery := nearest_defender(defenders, ball)
		var read: bool = (state.aiX3Recovery if side == "ai" else state.playerX3Recovery) > 0.0
		var back_limit: float = float(court["top"]) + 158.0 if side == "ai" else float(court["bottom"]) - 158.0
		var in_back: bool = recovery["paddle"].y < back_limit if side == "ai" else recovery["paddle"].y > back_limit
		var raggio: float = recovery["paddle"].reach * float(balance["x3RecoveryReach"])
		var in_raggio: bool = float(recovery["distance"]) <= raggio
		var abilita: float = clampf(float(balance["x3RecoveryChanceBase"]) + float(state.ai["skill"]) * float(balance["x3RecoveryChanceSkill"]), 0.0, 0.95) if side == "ai" else 1.0
		var recovered: bool = read and in_back and in_raggio and Rng.next_random(state) < abilita
		if not recovered:
			score_point(state, String(state.lastHitterSide), "msgSmashX3Wall", POINT_WINNER)
			return true
		ball.x = clampf(ball.x, float(court["left"]) + ball.r, float(court["right"]) - ball.r)
		ball.vx *= -wall_bounce * 0.72
		ball.vy = maxf(180.0, absf(ball.vy) * 0.7)
		ball.vz = maxf(160.0, ball.vz * 0.62)
		ball.shotType = "x3-recovered"
		ball.smashStage = 0
		state.aiX3Recovery = 0.0
		state.playerX3Recovery = 0.0
		add_event(state, "evX3Recovered")
		return false
	if hit_side_wall:
		ball.x = clampf(ball.x, float(court["left"]) + ball.r, float(court["right"]) - ball.r)
		ball.vx *= -wall_bounce
		ball.vy *= float(balance["wallTangentialDamping"])
		if has_bounced and ball.shotType == "wall-angle" and not ball.wallAngleResolved:
			ball.vx *= 1.08
			ball.wallAngleResolved = true
			state.aiReactionDelay += (1.0 - float(state.ai["skill"])) * 0.22
			add_event(state, "evSideWallCenter")
	if hit_back_wall:
		ball.y = clampf(ball.y, float(court["top"]) + ball.r, float(court["bottom"]) - ball.r)
		ball.vy *= -wall_bounce
		ball.vx *= float(balance["wallTangentialDamping"])
		if has_bounced and ball.wallKill > 0.0:
			var read_skill: float = float(state.ai["skill"]) if side == "ai" else 0.6
			var letta: bool = Rng.next_random(state) \
				< clampf(float(balance["cutVolleyReadBase"]) + read_skill * float(balance["cutVolleyReadSkill"]), 0.0, 0.85) \
					* (1.0 - ball.wallKill * float(balance["cutVolleyReadSuppress"]))
			if not letta:
				ball.vz = float(balance["cutVolleyKillVz"]) * ball.wallKill
				ball.vy *= float(balance["cutVolleyKillDamp"])
				ball.vx *= float(balance["cutVolleyKillDamp"])
				add_event(state, "evCutVolleyKill")
			else:
				add_event(state, "evCutVolleyRead")
			ball.wallKill = 0.0
		if has_bounced and ball.shotType == "smash-x3" and ball.smashTargetSide != null and String(ball.smashTargetSide) == side:
			var outward: float = js_sign_or(ball.vx if ball.vx != 0.0 else ball.spin, 1.0)
			ball.vx = outward * maxf(275.0, absf(ball.vx))
			ball.vy = (1.0 if side == "ai" else -1.0) * maxf(115.0, absf(ball.vy) * 0.46)
			ball.vz = maxf(245.0, ball.vz)
			ball.smashStage = 2
			add_event(state, "evSmashX3Grid")
		elif has_bounced and ball.shotType == "smash-x2" and ball.smashTargetSide != null and String(ball.smashTargetSide) == side:
			var defenders2: Array = [state.opponent, state.opponentMate] if side == "ai" else [state.player, state.playerMate]
			var nearest := nearest_defender(defenders2, ball)
			var read_skill2: float = float(state.ai["skill"]) if side == "ai" else float(computer_profile(state, state.player)["skill"])
			var proximity: float = clampf(1.0 - float(nearest["distance"]) / float(balance["smashX2ReadRange"]), 0.0, 1.0)
			var chance: float = clampf(
				float(balance["smashX2ReadBase"]) + read_skill2 * float(balance["smashX2ReadSkill"]) + proximity * float(balance["smashX2ReadProximity"]),
				0.0,
				float(balance["smashX2ReadCap"]),
			)
			var read2: bool = Rng.next_random(state) < chance
			if read2:
				ball.vy = (1.0 if side == "ai" else -1.0) * float(balance["smashX2ReadVy"])
				ball.vz = float(balance["smashX2ReadVz"])
			else:
				ball.vy = (1.0 if side == "ai" else -1.0) * maxf(float(balance["smashX2ReturnVy"]), absf(ball.vy) * 1.08)
				ball.vz = maxf(float(balance["smashX2ReturnVz"]), ball.vz)
			ball.smashStage = 2
			add_event(state, "evSmashX2Read" if read2 else "evSmashX2")
	if has_bounced:
		ball.postGlassSide = side
		if side == "ai":
			lock_ai_receiver_for_incoming_shot(state)
		else:
			lock_receiver_for_incoming_shot(state)
	ball.spin *= -0.45
	if state.wallEventTimer <= 0.0:
		add_event(state, "evWallValid")
		state.wallEventTimer = float(balance["wallEventCooldown"])
	return false


static func handle_net_collision(state: State, previous_ball: Dictionary) -> bool:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	var delta_y: float = ball.y - float(previous_ball["y"])
	var crossed: bool = (float(previous_ball["y"]) - float(court["netY"])) * (ball.y - float(court["netY"])) <= 0.0
	if not crossed or absf(delta_y) < 0.01:
		return false
	var crossing_t: float = clampf((float(court["netY"]) - float(previous_ball["y"])) / delta_y, 0.0, 1.0)
	var contact_z: float = float(previous_ball["z"]) + (ball.z - float(previous_ball["z"])) * crossing_t
	var touches_net: bool = contact_z <= float(balance["netClearance"]) + ball.r * 0.35
	if not touches_net:
		return false
	var direction: float = js_sign_or(delta_y, js_sign_or(ball.vy, 1.0))
	var speed: float = absf(ball.vy)
	var tape_contact: bool = contact_z >= float(balance["netClearance"]) - 6.0 and speed >= 250.0
	ball.netCord = 1.0
	ball.bouncePulse = maxf(ball.bouncePulse, 0.72)
	if tape_contact:
		ball.y = float(court["netY"]) + direction * (ball.r + 2.0)
		ball.z = maxf(float(balance["netClearance"]) - 2.0, contact_z)
		ball.vx *= 0.78
		ball.vy *= 0.48
		ball.vz = maxf(42.0, ball.vz * 0.3)
		if ball.serveInFlight:
			ball.serveTouchedNet = true
		add_event(state, "evTape")
		return false
	ball.y = float(court["netY"]) - direction * (ball.r + 2.0)
	ball.z = maxf(2.0, contact_z)
	ball.vx *= 0.58
	ball.vy *= -0.18
	ball.vz = maxf(20.0, absf(ball.vz) * 0.14)
	if ball.serveInFlight:
		ball.serveTouchedNet = true
	else:
		ball.netFaultOwner = "player" if direction < 0.0 else "ai"
	add_event(state, "evNetRebound")
	return false


# ---------------------------------------------------------------------------
# Paddle movement (`js/game.js:2416-2542`, `2737-2839`, `2543-2602`)
# ---------------------------------------------------------------------------

static func move_computer_paddle(state: State, paddle: Ent.SimPaddle, ball: Ent.SimBall, dt: float, home_y: float, accuracy: float) -> void:
	var court: Dictionary = Frozen.court()
	var start_x := paddle.x
	var start_y := paddle.y
	var side := "player" if paddle.isPlayer else "ai"
	var incoming := ball_playable_direction(side, ball)
	var bounds := role_bounds(paddle)
	var ball_on_own_side: bool = ball.y > float(court["netY"]) if paddle.isPlayer else ball.y < float(court["netY"])
	var shift: float = -16.0 if paddle.isPlayer else 16.0
	var target_y: float = clampf(ball.y + shift, float(bounds["minY"]), float(bounds["maxY"])) if (incoming and ball_on_own_side) else home_y
	var target_x: float
	if incoming and ball_on_own_side:
		target_x = ball.x + (Rng.next_random(state) - 0.5) * (1.0 - accuracy) * 20.0
	else:
		target_x = (float(court["left"]) + float(court["right"])) / 2.0
	paddle.x = clampf(paddle.x + clampf(target_x - paddle.x, -paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt), float(court["left"]) + paddle.w / 2.0, float(court["right"]) - paddle.w / 2.0)
	paddle.y = clampf(paddle.y + clampf(target_y - paddle.y, -paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * 0.56 * dt, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * 0.56 * dt), float(bounds["minY"]), float(bounds["maxY"]))
	paddle.motion = 1.0 if absf(paddle.x - start_x) + absf(paddle.y - start_y) > 0.4 else maxf(0.0, paddle.motion - dt * 7.0)
	paddle.moveRatio = clampf(
		hypot2(paddle.x - start_x, paddle.y - start_y) / maxf(1.0, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt),
		0.0,
		1.0,
	)


static func move_paddle_to(paddle: Ent.SimPaddle, target_x: float, target_y: float, dt: float) -> void:
	var court: Dictionary = Frozen.court()
	var start_x := paddle.x
	var start_y := paddle.y
	paddle.x = clampf(
		paddle.x + clampf(target_x - paddle.x, -paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt),
		float(court["left"]) + paddle.w / 2.0,
		float(court["right"]) - paddle.w / 2.0,
	)
	paddle.y = clampf(
		paddle.y + clampf(target_y - paddle.y, -paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * 0.56 * dt, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * 0.56 * dt),
		float(court["top"]) + 42.0,
		float(court["netY"]) - 42.0,
	)
	paddle.motion = 1.0 if absf(paddle.x - start_x) + absf(paddle.y - start_y) > 0.4 else maxf(0.0, paddle.motion - dt * 7.0)
	paddle.moveRatio = clampf(
		hypot2(paddle.x - start_x, paddle.y - start_y) / maxf(1.0, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt),
		0.0,
		1.0,
	)


## How far behind the predicted bounce a defending AI waits when `aiBounceBias` is
## on, in sim px: roughly the ball's travel in the first 0.18 s after the bounce,
## the window `ai_contact.gd` plans the post-bounce contact in.
const AI_BOUNCE_SETBACK_PX := 64.0
## The net player's zone, in sim px from the net: the same 130 px `ai_contact.gd`
## treats as a comfortable volley at skill 0. Inside it the bias does nothing.
const AI_VOLLEY_ZONE_PX := 130.0
## A planned post-bounce contact this close in time is "now" (1.5 sim ticks).
const AI_BOUNCE_HIT_NOW_S := 1.5 / 120.0


## Depth (sim y) where an incoming ball first reaches the floor on the AI's half,
## or null when it will not (rising too long, already past, or landing on the other
## half). Straight-line in y, like `ai_contact.gd`'s own forecast. Pure read.
static func predicted_landing_y(ball: Ent.SimBall) -> Variant:
	var court: Dictionary = Frozen.court()
	var gravity: float = float(Frozen.balance()["ballGravity"])
	var ground_time: float = (ball.vz + sqrt(maxf(0.0, ball.vz * ball.vz + 2.0 * gravity * maxf(0.0, ball.z)))) / gravity
	if ground_time <= 0.0 or ground_time > 1.6:
		return null
	var y: float = ball.y + ball.vy * ground_time
	if y < float(court["top"]) or y > float(court["netY"]):
		return null
	return y


static func move_opponent_team(state: State, dt: float) -> void:
	var court: Dictionary = Frozen.court()
	var ball := state.ball
	var opponent := state.opponent
	var opponent_mate := state.opponentMate
	var center_x: float = (float(court["left"]) + float(court["right"])) / 2.0
	var court_width: float = float(court["right"]) - float(court["left"])
	var live_prediction: float = clampf(ball.x + ball.vx * 0.2, float(court["left"]) + 72.0, float(court["right"]) - 72.0)
	var ai_defending_direction := ball_playable_direction("ai", ball)
	var predicted_x: float
	if state.aiReceiverLocked and ai_defending_direction:
		predicted_x = clampf(state.aiTargetX, float(court["left"]) + 72.0, float(court["right"]) - 72.0)
	else:
		predicted_x = live_prediction
	var primary: Ent.SimPaddle = state.paddle(state.aiPrimaryKey)
	if primary == null:
		primary = opponent
	var support: Ent.SimPaddle = opponent_mate if primary == opponent else opponent
	var ball_on_ai_side: bool = ball.y < float(court["netY"])
	var defending: bool = ball_on_ai_side and ai_defending_direction
	var attacking: bool = (not state.aiRecoveryMode) \
		and (not ball_on_ai_side) \
		and ball.vy > 0.0 \
		and (state.rallyHits > 0 or ball.served) \
		and ball.z < 165.0
	var min_separation: float = court_width * 0.24
	var primary_target_x: float = predicted_x
	var support_target_x: float = (center_x + court_width * 0.2) if predicted_x < center_x else (center_x - court_width * 0.2)

	if absf(primary_target_x - support_target_x) < min_separation:
		var cover_direction: float = 1.0 if primary_target_x < center_x else -1.0
		support_target_x = clampf(
			primary_target_x + cover_direction * min_separation,
			float(court["left"]) + 72.0,
			float(court["right"]) - 72.0,
		)

	var primary_target_y: float
	var support_target_y: float
	if defending:
		var glass_return_offset: float = 42.0 if (ball.postGlassSide != null and String(ball.postGlassSide) == "ai") else -18.0
		var x3_read: bool = state.aiX3Recovery > 0.0 and ball.shotType == "smash-x3"
		if x3_read:
			primary_target_y = float(court["top"]) + 66.0
		else:
			primary_target_y = clampf(ball.y + glass_return_offset, float(court["top"]) + 76.0, float(court["netY"]) - 104.0)
			# `aiBounceBias` > 0: stop walking INTO the incoming ball. The line above
			# sends the defender towards the ball's current depth, so it meets the ball
			# in the air; measured 2026-09-23, the back player volleys ~82% of what it
			# touches, and relaxing `ai_contact.gd` alone changed nothing because by
			# then the defender is already on top of the ball. With a bias, it settles
			# BEHIND the predicted bounce instead — never further forward than today —
			# and the bounce planner then picks the post-bounce contact. At 0 this
			# block is skipped entirely: the golden matches do not move.
			# Only a defender already out of the volley zone: at the net, taking the
			# ball in the air is the right play and stays exactly as it was.
			var volley_zone: bool = float(court["netY"]) - primary.y < AI_VOLLEY_ZONE_PX
			if state.aiBounceBias > 0.0 and not volley_zone and int(ball.bounces["ai"]) == 0 and ball.postGlassSide == null:
				var landing_y: Variant = predicted_landing_y(ball)
				if landing_y != null:
					var behind_bounce: float = clampf(float(landing_y) - AI_BOUNCE_SETBACK_PX, float(court["top"]) + 60.0, float(court["netY"]) - 104.0)
					primary_target_y = lerpf(primary_target_y, minf(primary_target_y, behind_bounce), clampf(state.aiBounceBias, 0.0, 1.0))
		if x3_read:
			support_target_y = float(court["top"]) + 98.0
		else:
			support_target_y = clampf(primary_target_y - 10.0, float(court["top"]) + 70.0, float(court["netY"]) - 112.0)
		if x3_read:
			primary_target_x = clampf(ball.x - ball.vx * 0.12, float(court["left"]) + 58.0, float(court["right"]) - 58.0)
			support_target_x = (center_x + court_width * 0.24) if primary_target_x < center_x else (center_x - court_width * 0.24)
		state.aiTeamShape = "defend"
	elif attacking:
		var style := Tactics.style(String(athlete_for(state, primary).get("id", "")))
		primary_target_y = float(court["netY"]) - float(style.net_depth)
		support_target_y = primary_target_y - 8.0
		state.aiTeamShape = "attack"
	else:
		primary_target_y = float(court["top"]) + 92.0
		support_target_y = float(court["top"]) + 84.0
		state.aiTeamShape = "reset"

	if defending:
		var plan := ai_contact_plan(state, primary, ball)
		if bool(plan["wait"]):
			primary_target_x = float(plan["x"])
			primary_target_y = float(plan["y"])
			# Glass/bounce play: the receiver drops back for the ball, the partner does NOT
			# follow it. A partner already near the net keeps the net (the padel "one up,
			# one back"); before this, `support_target_y` trailed the receiver and the pair
			# left the net (measured, level 2: net contacts 774 -> 454). Only with the new
			# play: the recorded behaviour's `reachable-bounce` wait is untouched.
			var reason := String(plan["reason"])
			if (reason == "glass-play" or reason == "bounce-play") \
					and float(court["netY"]) - support.y < AI_VOLLEY_ZONE_PX + 40.0:
				var style := Tactics.style(String(athlete_for(state, support).get("id", "")))
				support_target_y = float(court["netY"]) - float(style.net_depth)
	var reading_incoming_shot: bool = defending and state.aiReceiverLocked and state.aiReactionDelay > 0.0
	if not reading_incoming_shot:
		move_paddle_to(primary, primary_target_x, primary_target_y, dt)
	else:
		primary.motion = maxf(0.0, primary.motion - dt * 7.0)
	move_paddle_to(support, support_target_x, support_target_y, dt)


static func tactical_mate_target(state: State, mate: Ent.SimPaddle) -> Dictionary:
	var court: Dictionary = Frozen.court()
	var active := state.active_player()
	var opposite_lane: float = Tactics.cover_lane(active.x, mate.x, float(court["left"]), float(court["right"]))
	var tactic: String = state.playerTeamTactic
	if tactic == "attack":
		return {"x": opposite_lane, "y": float(court["netY"]) + 78.0}
	if tactic == "defend":
		return {"x": opposite_lane, "y": float(court["bottom"]) - 76.0}
	if tactic == "staggered":
		var active_at_net: bool = active.y < float(court["netY"]) + 150.0
		return {"x": opposite_lane, "y": (float(court["bottom"]) - 92.0) if active_at_net else (float(court["netY"]) + 88.0)}
	return {
		"x": opposite_lane,
		"y": (float(court["netY"]) + 88.0) if active.y < float(court["netY"]) + 145.0 else (float(court["bottom"]) - 92.0),
	}


static func move_tactical_mate(state: State, mate: Ent.SimPaddle, dt: float) -> void:
	var court: Dictionary = Frozen.court()
	var target := tactical_mate_target(state, mate)
	var active := state.active_player()
	target.y = Tactics.safe_cover_y(active.x, active.y, mate.x, mate.y, target.x, target.y, float(court["bottom"]))
	if (mate.x - active.x) * (float(target.x) - active.x) <= 0.0 and absf(mate.y - active.y) < 64.0:
		target.x = mate.x # Create room in depth before crossing the human's lane.
	var start_x := mate.x
	var start_y := mate.y
	mate.x = clampf(mate.x + clampf(float(target["x"]) - mate.x, -mate.speed * Stamina.speed_factor(mate.staminaEnergy) * dt, mate.speed * Stamina.speed_factor(mate.staminaEnergy) * dt), float(court["left"]) + mate.w / 2.0, float(court["right"]) - mate.w / 2.0)
	mate.y = clampf(mate.y + clampf(float(target["y"]) - mate.y, -mate.speed * Stamina.speed_factor(mate.staminaEnergy) * 0.56 * dt, mate.speed * Stamina.speed_factor(mate.staminaEnergy) * 0.56 * dt), float(court["netY"]) + 42.0, float(court["bottom"]) - 42.0)
	mate.motion = 1.0 if absf(mate.x - start_x) + absf(mate.y - start_y) > 0.4 else maxf(0.0, mate.motion - dt * 7.0)
	mate.moveRatio = clampf(hypot2(mate.x - start_x, mate.y - start_y) / maxf(1.0, mate.speed * Stamina.speed_factor(mate.staminaEnergy) * dt), 0.0, 1.0)


static func update_doubles_ai(state: State, dt: float) -> void:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	if state.serving:
		return
	var ball := state.ball
	var opponent := state.opponent
	var opponent_mate := state.opponentMate
	var ai: Dictionary = state.ai
	state.aiReactionDelay = maxf(0.0, state.aiReactionDelay - dt)
	var inactive_team_mate: Ent.SimPaddle = state.playerMate if state.activePlayerKey == "player" else state.player
	var inactive_home_y: float = float(court["netY"]) + 92.0 if inactive_team_mate.role == "net" else float(court["bottom"]) - 86.0
	if not state.coop:
		if state.serviceReceiverKey != null:
			var width: float = float(court["right"]) - float(court["left"])
			var reception_x: float = float(court["left"]) + width * 0.28 if inactive_team_mate == state.player else float(court["left"]) + width * 0.72
			var reception_y: float = float(court["bottom"]) - 74.0
			inactive_team_mate.x += clampf(reception_x - inactive_team_mate.x, -inactive_team_mate.speed * Stamina.speed_factor(inactive_team_mate.staminaEnergy) * dt, inactive_team_mate.speed * Stamina.speed_factor(inactive_team_mate.staminaEnergy) * dt)
			inactive_team_mate.y += clampf(reception_y - inactive_team_mate.y, -inactive_team_mate.speed * Stamina.speed_factor(inactive_team_mate.staminaEnergy) * 0.56 * dt, inactive_team_mate.speed * Stamina.speed_factor(inactive_team_mate.staminaEnergy) * 0.56 * dt)
		else:
			move_tactical_mate(state, inactive_team_mate, dt)
	if state.pvp:
		var inactive_pvp: Ent.SimPaddle = opponent_mate if state.pvpActiveKey == "opponent" else opponent
		var pvp_home_y: float = float(court["netY"]) - 84.0 if inactive_pvp.role == "net" else float(court["top"]) + 76.0
		if state.aiServiceReceiverKey != null:
			var width: float = float(court["right"]) - float(court["left"])
			var receiver: Ent.SimPaddle = state.paddle(String(state.aiServiceReceiverKey))
			var reception_x: float = float(court["left"]) + width * 0.28 if inactive_pvp == opponent else float(court["left"]) + width * 0.72
			var target_x: float = ball.x if (inactive_pvp == receiver and not ball.serveInFlight) else reception_x
			var reception_y: float = float(court["top"]) + 74.0
			inactive_pvp.x += clampf(target_x - inactive_pvp.x, -inactive_pvp.speed * Stamina.speed_factor(inactive_pvp.staminaEnergy) * dt, inactive_pvp.speed * Stamina.speed_factor(inactive_pvp.staminaEnergy) * dt)
			inactive_pvp.y += clampf(reception_y - inactive_pvp.y, -inactive_pvp.speed * Stamina.speed_factor(inactive_pvp.staminaEnergy) * 0.56 * dt, inactive_pvp.speed * Stamina.speed_factor(inactive_pvp.staminaEnergy) * 0.56 * dt)
		else:
			var pvp_accuracy: float = float(state.pvpAthlete["stats"]["control"]) if state.pvpAthlete != null else float(ai["skill"])
			move_computer_paddle(state, inactive_pvp, ball, dt, pvp_home_y, pvp_accuracy)
		return
	if state.aiServiceReceiverKey != null:
		var width: float = float(court["right"]) - float(court["left"])
		var receiver: Ent.SimPaddle = state.paddle(String(state.aiServiceReceiverKey))
		for paddle in [opponent, opponent_mate]:
			var reception_x: float = float(court["left"]) + width * 0.28 if paddle == opponent else float(court["left"]) + width * 0.72
			var target_x: float = ball.x if (paddle == receiver and not ball.serveInFlight) else reception_x
			var reception_y: float = float(court["top"]) + 74.0
			paddle.x += clampf(target_x - paddle.x, -paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt)
			paddle.y += clampf(reception_y - paddle.y, -paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * 0.56 * dt, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * 0.56 * dt)
	else:
		move_opponent_team(state, dt)

	var controllable_height: bool = ball.z <= float(balance["playableHitHeight"])
	var defenders: Array
	if state.aiReceiverLocked:
		defenders = [state.paddle(state.aiPrimaryKey)]
	else:
		var pair: Array = [opponent, opponent_mate]
		defenders = [pair[0], pair[1]] if paddle_distance(pair[0], ball) <= paddle_distance(pair[1], ball) else [pair[1], pair[0]]
	var responder: Variant = null
	for paddle in defenders:
		if can_hit(paddle, ball):
			responder = paddle
			break
	if responder != null and controllable_height and state.aiReactionDelay <= 0.0:
		var plan := ai_contact_plan(state, responder, ball)
		if not bool(plan["wait"]) and not ai_lets_it_go_out(state, ball):
			hit_ball(state, responder, 0.88 + float(ai["skill"]) * 0.12)


## True when the human's ball, not yet bounced on the AI half, is going to reach a
## glass before the floor: out, the point is the AI's (`handle_walls`). A padel player
## lets it go; this AI used to volley it back into play and so rescued the human's
## own errors (owner's match 2026-09-23: 2 of his 3 "long" errors were volleyed back
## by the AI at the net). Exact forecast (`ai_glass.gd` first_contact), no RNG.
static func ai_lets_it_go_out(state: State, ball: Ent.SimBall) -> bool:
	if ball.serveInFlight or int(ball.bounces["ai"]) > 0 or state.lastHitterSide != "player" or not ball.crossedNet:
		return false
	var glass := preload("res://src/sim/ai_glass.gd")
	return glass.first_contact({
		"x": ball.x, "y": ball.y, "z": ball.z, "vx": ball.vx, "vy": ball.vy, "vz": ball.vz,
		"spin": ball.spin, "r": ball.r,
	}, Frozen.court(), Frozen.balance()) == glass.OUT


static func control_paddle_charge(state: State, paddle: Ent.SimPaddle, input: Dictionary, dt: float) -> void:
	if bool(input.get("analogAim", false)):
		paddle.aim = clampf(float(input.get("aim", 0.0)), -1.0, 1.0)
		paddle.aimY = clampf(float(input.get("aimY", 0.0)), -1.0, 1.0)
	if bool(input.get("charging", false)):
		paddle.charge = minf(1.0, paddle.charge + dt / 1.05)
		if not bool(input.get("analogAim", false)):
			var aim_direction: float = -1.0 if bool(input.get("left", false)) else (1.0 if bool(input.get("right", false)) else 0.0)
			paddle.aim = clampf(paddle.aim + aim_direction * dt * 1.9, -1.0, 1.0)
		if input.get("shotVariant", null) != null:
			paddle.shotIntent = String(input["shotVariant"])
		else:
			paddle.shotIntent = "slice" if bool(input.get("slice", false)) else "drive"
	elif not bool(input.get("hit", false)):
		paddle.aim *= maxf(0.0, 1.0 - dt * 8.0)
		paddle.aimY *= maxf(0.0, 1.0 - dt * 8.0)


static func queue_paddle_hit(state: State, paddle: Ent.SimPaddle, input: Dictionary) -> void:
	var balance: Dictionary = Frozen.balance()
	if bool(input.get("smashUpgrade", false)) and paddle.smashPrimed and paddle.queuedShot != null:
		paddle.queuedShot["variant"] = "smash"
		paddle.queuedShot["aim"] = clampf(float(input.get("aim", paddle.queuedShot["aim"])), -1.0, 1.0)
		paddle.queuedShot["aimY"] = clampf(float(input.get("aimY", paddle.queuedShot["aimY"])), -1.0, 1.0)
		paddle.queuedShot["age"] = 0.0
		paddle.smashPrimed = false
		paddle.smashTapWindow = 0.0
		paddle.shotIntent = "smash"
		add_event(state, "evSmashTapConfirmed")
		return
	if not bool(input.get("hit", false)):
		return
	var variant: String
	if input.get("shotVariant", null) != null:
		variant = String(input["shotVariant"])
	else:
		variant = "slice" if bool(input.get("slice", false)) else "auto"
	paddle.queuedShot = {
		"power": 0.4 + paddle.charge * 0.95,
		"charge": paddle.charge,
		"aim": paddle.aim,
		"aimY": paddle.aimY,
		"slice": bool(input.get("slice", false)),
		"variant": variant,
		"precision": clampf(float(input.get("sprint", 0.0)), 0.0, 1.0),
		"age": 0.0,
	}
	var near_net := within_net_range(paddle, float(balance["smashNetWindow"]))
	var can_prime_smash: bool = String(paddle.queuedShot["variant"]) == "drive" \
		and (not bool(paddle.queuedShot["slice"])) \
		and state.rallyHits > 0 \
		and near_net \
		and state.ball.z >= float(balance["smashMinHeight"]) - 8.0 \
		and hit_power_profile(paddle, state, float(paddle.queuedShot["power"])) >= float(balance["smashMinPower"])
	paddle.smashPrimed = can_prime_smash
	paddle.smashTapWindow = float(balance["smashDoubleTapWindow"]) if can_prime_smash else 0.0
	paddle.swingBuffer = float(balance["smashBufferWindow"]) if can_prime_smash else float(balance["shotBufferWindow"])
	if can_prime_smash:
		add_event(state, "evSmashPrimed")
	paddle.charge = 0.0
	paddle.aim = 0.0
	paddle.aimY = 0.0


static func decay_human_swing(state: State, paddle: Ent.SimPaddle, dt: float) -> void:
	if paddle.swingBuffer <= 0.0:
		return
	var had_contact_grace: bool = paddle.smashContactGrace > 0.0
	paddle.smashContactGrace = maxf(0.0, paddle.smashContactGrace - dt)
	if had_contact_grace and paddle.smashContactGrace == 0.0 and paddle.smashPrimed:
		paddle.smashPrimed = false
		paddle.smashTapWindow = 0.0
		paddle.smashContactFallback = true
		add_event(state, "evSmashTapExpired")
	if paddle.smashPrimed:
		paddle.smashTapWindow = maxf(0.0, paddle.smashTapWindow - dt)
		if paddle.smashTapWindow == 0.0:
			paddle.smashPrimed = false
			add_event(state, "evSmashTapExpired")
	if paddle.queuedShot != null:
		paddle.queuedShot["age"] = float(paddle.queuedShot["age"]) + dt
	paddle.swingBuffer = maxf(0.0, paddle.swingBuffer - dt)
	if paddle.swingBuffer == 0.0 and paddle.queuedShot != null and String(paddle.queuedShot["variant"]) == "smash":
		state.shotFeedback = {
			"text": "smashMissedContact",
			"mode": "smashMissedHint",
			"grade": "early",
			"quality": 0.0,
			"life": 1.05,
			"paddleKey": paddle.key,
		}
		paddle.queuedShot = null


static func attempt_human_swing(state: State, paddle: Ent.SimPaddle, previous_ball: Dictionary) -> void:
	var balance: Dictionary = Frozen.balance()
	if paddle.swingBuffer <= 0.0 or paddle.queuedShot == null:
		return
	var contact_now: bool = can_hit(paddle, state.ball) or crossed_paddle(paddle, state.ball, previous_ball)
	if paddle.smashPrimed and contact_now:
		paddle.smashContactGrace = maxf(paddle.smashContactGrace, float(balance["smashContactGrace"]))
		return
	if paddle.smashPrimed:
		return
	if not contact_now and not paddle.smashContactFallback and not (paddle.smashContactGrace > 0.0):
		return
	var q: Dictionary = paddle.queuedShot
	var timing_age: float = float(minf(float(q["age"]), float(balance["smashTimingAgeCap"]))) if String(q["variant"]) == "smash" else float(q["age"])
	if hit_ball(state, paddle, float(q["power"]), false, true, float(q["aim"]), bool(q["slice"]), String(q["variant"]), float(q["aimY"]), timing_age, float(q["precision"])):
		paddle.swingBuffer = 0.0
		paddle.queuedShot = null
		paddle.smashContactGrace = 0.0
		paddle.smashContactFallback = false


static func set_player_team_tactic(state: State, tactic: Variant) -> void:
	if tactic == null or String(tactic) == "" or state.playerTeamTactic == String(tactic):
		return
	state.playerTeamTactic = String(tactic)
	state.tacticFlash = 1.1
	add_event(state, "tactic_%s" % String(tactic))


static func update_shot_control(state: State, dt: float, input: Dictionary) -> void:
	if bool(input.get("analogAim", false)):
		state.shotAim = clampf(float(input.get("aim", 0.0)), -1.0, 1.0)
		state.shotAimY = clampf(float(input.get("aimY", 0.0)), -1.0, 1.0)
	if not bool(input.get("charging", false)):
		if not bool(input.get("hit", false)):
			state.shotAim *= maxf(0.0, 1.0 - dt * 8.0)
			state.shotAimY *= maxf(0.0, 1.0 - dt * 8.0)
		return
	state.shotCharge = minf(1.0, state.shotCharge + dt / 1.05)
	if not bool(input.get("analogAim", false)):
		var aim_direction: float = -1.0 if bool(input.get("left", false)) else (1.0 if bool(input.get("right", false)) else 0.0)
		state.shotAim = clampf(state.shotAim + aim_direction * dt * 1.9, -1.0, 1.0)
	state.shotPrecision = clampf(float(input.get("sprint", 0.0)), 0.0, 1.0)
	if input.get("shotVariant", null) != null:
		state.shotIntent = String(input["shotVariant"])
	else:
		state.shotIntent = "slice" if bool(input.get("slice", false)) else "drive"


static func queue_charged_shot(state: State, slice: bool = false, variant: String = "auto") -> void:
	state.queuedShotPower = 0.4 + state.shotCharge * 0.95
	state.queuedShotCharge = state.shotCharge
	state.queuedShotAge = 0.0
	state.queuedShotAim = state.shotAim
	state.queuedShotAimY = state.shotAimY
	state.queuedShotSlice = slice
	state.queuedShotVariant = variant
	state.queuedShotPrecision = state.shotPrecision
	state.shotPrecision = 0.0
	state.shotCharge = 0.0
	state.shotAim = 0.0
	state.shotAimY = 0.0


static func move_human_paddle(state: State, paddle: Ent.SimPaddle, input: Dictionary, dt: float) -> void:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var digital_x: float = (-1.0 if bool(input.get("left", false)) else 0.0) + (1.0 if bool(input.get("right", false)) else 0.0)
	var digital_y: float = (-1.0 if bool(input.get("up", false)) else 0.0) + (1.0 if bool(input.get("down", false)) else 0.0)
	var move_x: float = clampf(float(input.get("moveX", digital_x)), -1.0, 1.0)
	var move_y: float = clampf(float(input.get("moveY", digital_y)), -1.0, 1.0)
	var split_step: float = 0.0 if bool(input.get("charging", false)) else clampf(float(input.get("splitStep", 0.0)), 0.0, 1.0)
	var charge_movement: float = 0.32 if bool(input.get("charging", false)) else 1.0
	var movement_multiplier: float = charge_movement * (1.0 - split_step * (1.0 - float(balance["splitStepSpeed"])))
	paddle.splitStep = split_step
	paddle.sprinting = 0.0
	var start_x := paddle.x
	var start_y := paddle.y
	paddle.x += move_x * paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * movement_multiplier * dt
	paddle.y += move_y * paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * 0.68 * movement_multiplier * dt
	if paddle.dashTimer > 0.0:
		paddle.x += move_x * 260.0 * dt
		paddle.dashTimer -= dt
	paddle.x = clampf(paddle.x, float(court["left"]) + paddle.w / 2.0, float(court["right"]) - paddle.w / 2.0)
	var receiver_key: Variant = state.serviceReceiverKey if paddle.isPlayer else state.aiServiceReceiverKey
	var min_y: float
	var max_y: float
	if paddle.isPlayer:
		min_y = float(court["netY"]) + 42.0
		max_y = float(court["bottom"]) - 42.0
		if receiver_key != null and String(receiver_key) == paddle.key:
			min_y = float(court["netY"]) + SERVICE_LINE_OFFSET + 20.0
	else:
		min_y = float(court["top"]) + 42.0
		max_y = float(court["netY"]) - 42.0
		if receiver_key != null and String(receiver_key) == paddle.key:
			max_y = float(court["netY"]) - SERVICE_LINE_OFFSET - 20.0
	paddle.y = clampf(paddle.y, min_y, max_y)
	paddle.motion = 1.0 if absf(paddle.x - start_x) + absf(paddle.y - start_y) > 0.4 else maxf(0.0, paddle.motion - dt * 7.0)
	paddle.moveRatio = clampf(
		hypot2(paddle.x - start_x, paddle.y - start_y) / maxf(1.0, paddle.speed * Stamina.speed_factor(paddle.staminaEnergy) * dt),
		0.0,
		1.0,
	)
	paddle.hitCooldown = maxf(0.0, paddle.hitCooldown - dt)


# ---------------------------------------------------------------------------
# `EMPTY_INPUT` (`js/game.js:2712-2735`) and `updateMatch` (`js/game.js:2973-3359`)
# ---------------------------------------------------------------------------

static func empty_input() -> Dictionary:
	return {
		"left": false, "right": false, "up": false, "down": false,
		"moveX": 0.0, "moveY": 0.0,
		"charging": false, "hit": false, "slice": false, "shotVariant": null,
		"special": false, "switchPlayer": false, "switchDirection": null,
		"aim": 0.0, "aimY": 0.0, "analogAim": false,
		"splitStep": 0.0, "sprint": 0.0, "technicalModifier": false, "teamTactic": null,
		"cutVolley": false, "globo": false,
		"smashUpgrade": false,
	}


## The single tick entry point. Same argument order and same control flow as
## `updateMatch` (`js/game.js:2973`); `dt` is the caller's constant
## (`1/120`, `js/main.js:1164`), never an engine delta.
static func update_match(state: State, dt_in: float, input: Dictionary, input2: Variant = null) -> Variant:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var second: Dictionary = input2 if input2 != null else empty_input()
	if state.paused or not state.running:
		return null
	var dt := dt_in
	state.elapsed += dt
	state.receiverSwitchFlash = maxf(0.0, state.receiverSwitchFlash - dt)
	state.manualSwitchFlash = maxf(0.0, state.manualSwitchFlash - dt)
	state.pvpSwitchFlash = maxf(0.0, state.pvpSwitchFlash - dt)
	state.tacticFlash = maxf(0.0, state.tacticFlash - dt)
	state.aiX3Recovery = maxf(0.0, state.aiX3Recovery - dt)
	state.playerX3Recovery = maxf(0.0, state.playerX3Recovery - dt)
	set_player_team_tactic(state, input.get("teamTactic", null))
	if state.shotFeedback != null:
		state.shotFeedback["life"] = maxf(0.0, float(state.shotFeedback["life"]) - dt)
		if float(state.shotFeedback["life"]) == 0.0:
			state.shotFeedback = null
	# `updateFx(state, dt)` at `js/game.js:2988` is the particle coupling; the
	# simulation state it does not touch is unchanged by dropping it.
	for paddle in [state.player, state.playerMate, state.opponent, state.opponentMate]:
		paddle.actionPose = maxf(0.0, paddle.actionPose - dt)
		if paddle.motion > 0.12:
			var pace: float = 7.5 + paddle.moveRatio * 3.5 + paddle.sprinting * 1.0
			var split_step_factor: float = 1.0 - paddle.splitStep * 0.22
			paddle.runPhase = fmod(paddle.runPhase + dt * pace * split_step_factor, 8.0)
	if state.pointPause > 0.0:
		for paddle in [state.player, state.playerMate, state.opponent, state.opponentMate]:
			paddle.motion = 0.0
			paddle.moveRatio = 0.0
		state.pointPause = maxf(0.0, state.pointPause - dt)
		if state.pointPause == 0.0 and state.result == null:
			reset_replay_buffer(state)
			prepare_serve(state)
		return state.result
	# From here on: the simulation. It slows during the hit-stop, while effects,
	# animations and UI timers above stay at real speed (`js/game.js:3012-3015`).
	var fatigue_dt := dt if state.hitStop <= 0.0 else 0.0
	if state.hitStop > 0.0:
		state.hitStop = maxf(0.0, state.hitStop - dt)
		dt *= float(balance["hitStopTimeScale"])
	if state.humanMode != "coop" or state.serving:
		update_shot_control(state, dt, input)
	var ball := state.ball
	if state.serving:
		update_serving(state, dt, input, second)
		capture_replay_frame(state)
		return state.result

	var effort_start := {}
	for p in [state.player, state.playerMate, state.opponent, state.opponentMate]:
		# Preserve double precision like the JS simulation; Vector2 rounds to float32.
		effort_start[p.key] = [p.x, p.y]
	var player := state.active_player()
	if state.humanMode == "coop":
		control_paddle_charge(state, player, input, dt)
		queue_paddle_hit(state, player, input)
		move_human_paddle(state, player, input, dt)
		decay_human_swing(state, player, dt)
		control_paddle_charge(state, state.playerMate, second, dt)
		queue_paddle_hit(state, state.playerMate, second)
		move_human_paddle(state, state.playerMate, second, dt)
		decay_human_swing(state, state.playerMate, dt)
		state.opponent.hitCooldown = maxf(0.0, state.opponent.hitCooldown - dt)
		state.opponentMate.hitCooldown = maxf(0.0, state.opponentMate.hitCooldown - dt)
		state.wallEventTimer = maxf(0.0, state.wallEventTimer - dt)
		var had_smash_contact_grace: bool = state.smashContactGrace > 0.0
		state.smashContactGrace = maxf(0.0, state.smashContactGrace - dt)
		if had_smash_contact_grace and state.smashContactGrace == 0.0 and state.smashPrimed:
			state.smashPrimed = false
			state.smashTapWindow = 0.0
			state.smashContactFallback = true
			add_event(state, "evSmashTapExpired")
		if bool(input.get("special", false)):
			state.playerSwingBuffer = 0.24
			try_special(state)
		state.shotCharge = player.charge
		state.shotAim = player.aim
		state.shotAimY = player.aimY
	else:
		var digital_move_x: float = (-1.0 if bool(input.get("left", false)) else 0.0) + (1.0 if bool(input.get("right", false)) else 0.0)
		var digital_move_y: float = (-1.0 if bool(input.get("up", false)) else 0.0) + (1.0 if bool(input.get("down", false)) else 0.0)
		var move_x: float = clampf(float(input.get("moveX", digital_move_x)), -1.0, 1.0)
		var move_y: float = clampf(float(input.get("moveY", digital_move_y)), -1.0, 1.0)
		var movement_intent: bool = hypot2(move_x, move_y) > 0.08
		state.manualMovementTimer = 0.18 if movement_intent else maxf(0.0, state.manualMovementTimer - dt)
		update_active_player(state, dt, bool(input.get("switchPlayer", false)), input.get("switchDirection", null))
		player = state.active_player()
		var player_start_x := player.x
		var player_start_y := player.y

		var split_step: float = 0.0 if bool(input.get("charging", false)) else clampf(float(input.get("splitStep", 0.0)), 0.0, 1.0)
		var charge_movement: float = 0.58 if bool(input.get("charging", false)) else 1.0
		var movement_multiplier: float = charge_movement * (1.0 - split_step * (1.0 - float(balance["splitStepSpeed"])))
		player.splitStep = split_step
		player.sprinting = 0.0
		player.x += move_x * player.speed * Stamina.speed_factor(player.staminaEnergy) * movement_multiplier * dt
		player.y += move_y * player.speed * Stamina.speed_factor(player.staminaEnergy) * 0.68 * movement_multiplier * dt
		if player.dashTimer > 0.0:
			player.x += move_x * 260.0 * dt
			player.dashTimer -= dt
		player.x = clampf(player.x, float(court["left"]) + player.w / 2.0, float(court["right"]) - player.w / 2.0)
		var player_min_y: float = (float(court["netY"]) + SERVICE_LINE_OFFSET + 20.0) if state.serviceReceiverKey != null else (float(court["netY"]) + 42.0)
		player.y = clampf(player.y, player_min_y, float(court["bottom"]) - 42.0)
		player.motion = 1.0 if absf(player.x - player_start_x) + absf(player.y - player_start_y) > 0.4 else maxf(0.0, player.motion - dt * 7.0)
		player.moveRatio = clampf(
			hypot2(player.x - player_start_x, player.y - player_start_y) / maxf(1.0, player.speed * Stamina.speed_factor(player.staminaEnergy) * dt),
			0.0,
			1.0,
		)
		player.hitCooldown = maxf(0.0, player.hitCooldown - dt)
		state.playerMate.hitCooldown = maxf(0.0, state.playerMate.hitCooldown - dt)
		state.opponent.hitCooldown = maxf(0.0, state.opponent.hitCooldown - dt)
		state.opponentMate.hitCooldown = maxf(0.0, state.opponentMate.hitCooldown - dt)
		state.wallEventTimer = maxf(0.0, state.wallEventTimer - dt)
		if state.smashPrimed:
			state.smashTapWindow = maxf(0.0, state.smashTapWindow - dt)
			if state.smashTapWindow == 0.0:
				state.smashPrimed = false
				add_event(state, "evSmashTapExpired")
		if state.cutVolleyPrimed:
			state.cutVolleyTapWindow = maxf(0.0, state.cutVolleyTapWindow - dt)
			if state.cutVolleyTapWindow == 0.0:
				state.cutVolleyPrimed = false
		if state.globoPrimed:
			state.globoTapWindow = maxf(0.0, state.globoTapWindow - dt)
			if state.globoTapWindow == 0.0:
				state.globoPrimed = false
		if bool(input.get("hit", false)):
			var shot_variant: String
			if input.get("shotVariant", null) != null:
				shot_variant = String(input["shotVariant"])
			else:
				shot_variant = "slice" if bool(input.get("slice", false)) else "auto"
			queue_charged_shot(state, bool(input.get("slice", false)), shot_variant)
			var queued_power: float = state.queuedShotPower * float(state.athlete["stats"]["power"])
			var can_prime_smash: bool = state.queuedShotVariant == "drive" \
				and (not state.queuedShotSlice) \
				and state.rallyHits > 0 \
				and within_net_range(player, float(balance["smashNetWindow"])) \
				and ball.z >= float(balance["smashMinHeight"]) - 8.0 \
				and queued_power >= float(balance["smashMinPower"])
			var can_prime_cut_volley: bool = (not can_prime_smash) \
				and state.queuedShotSlice \
				and state.rallyHits > 0 \
				and int(ball.bounces["player"]) == 0 \
				and within_net_range(player, float(balance["viboraNetWindow"])) \
				and ball.z >= float(balance["cutVolleyMinHeight"])
			state.smashPrimed = can_prime_smash
			state.smashTapWindow = float(balance["smashDoubleTapWindow"]) if can_prime_smash else 0.0
			var can_prime_globo: bool = (not can_prime_smash) \
				and (not can_prime_cut_volley) \
				and state.queuedShotVariant == "lob" \
				and state.queuedShotCharge >= float(balance["globoMinCharge"]) \
				and ball.z <= float(balance["globoMaxHeight"])
			state.cutVolleyPrimed = can_prime_cut_volley
			state.cutVolleyTapWindow = float(balance["cutVolleyTapWindow"]) if can_prime_cut_volley else 0.0
			state.globoPrimed = can_prime_globo
			state.globoTapWindow = float(balance["globoTapWindow"]) if can_prime_globo else 0.0
			if can_prime_smash:
				state.playerSwingBuffer = float(balance["smashBufferWindow"])
			elif can_prime_cut_volley:
				state.playerSwingBuffer = float(balance["cutVolleyBufferWindow"])
			elif can_prime_globo:
				state.playerSwingBuffer = float(balance["globoBufferWindow"])
			else:
				state.playerSwingBuffer = float(balance["shotBufferWindow"])
			if can_prime_smash:
				add_event(state, "evSmashPrimed")
			elif can_prime_cut_volley:
				add_event(state, "evCutVolleyPrimed")
			elif can_prime_globo:
				add_event(state, "evGloboPrimed")
		if bool(input.get("globo", false)) and state.globoPrimed and state.playerSwingBuffer > 0.0:
			state.queuedShotVariant = "globo"
			state.queuedShotAim = clampf(float(input.get("aim", state.queuedShotAim)), -1.0, 1.0)
			state.queuedShotAge = 0.0
			state.shotIntent = "globo"
			state.globoPrimed = false
			state.globoTapWindow = 0.0
			add_event(state, "evGloboConfirmed")
		if bool(input.get("cutVolley", false)) and state.cutVolleyPrimed and state.playerSwingBuffer > 0.0:
			state.queuedShotVariant = "cut-volley"
			state.queuedShotAim = clampf(float(input.get("aim", state.queuedShotAim)), -1.0, 1.0)
			state.queuedShotAge = 0.0
			state.shotIntent = "cut-volley"
			state.cutVolleyPrimed = false
			state.cutVolleyTapWindow = 0.0
			add_event(state, "evCutVolleyConfirmed")
		if bool(input.get("smashUpgrade", false)) and state.smashPrimed and state.playerSwingBuffer > 0.0:
			state.queuedShotVariant = "smash"
			state.queuedShotAim = clampf(float(input.get("aim", state.queuedShotAim)), -1.0, 1.0)
			state.queuedShotAimY = clampf(float(input.get("aimY", state.queuedShotAimY)), -1.0, 1.0)
			state.queuedShotAge = 0.0
			state.shotIntent = "smash"
			state.smashPrimed = false
			state.smashTapWindow = 0.0
			add_event(state, "evSmashTapConfirmed")
		var had_swing_buffer: bool = state.playerSwingBuffer > 0.0
		if state.playerSwingBuffer > 0.0:
			state.queuedShotAge += dt
		state.playerSwingBuffer = maxf(0.0, state.playerSwingBuffer - dt)
		if had_swing_buffer and state.playerSwingBuffer == 0.0 and state.queuedShotVariant == "smash":
			state.shotFeedback = {
				"text": "smashMissedContact",
				"mode": "smashMissedHint",
				"grade": "early",
				"quality": 0.0,
				"life": 1.05,
				"paddleKey": state.activePlayerKey,
			}
			state.queuedShotAge = 0.0
			state.queuedShotVariant = "auto"
		if bool(input.get("special", false)):
			state.playerSwingBuffer = 0.24
			try_special(state)
	if state.humanMode == "pvp":
		update_pvp_active(state, dt, bool(second.get("switchPlayer", false)), second.get("switchDirection", null))
		var p2 := state.paddle(state.pvpActiveKey)
		control_paddle_charge(state, p2, second, dt)
		queue_paddle_hit(state, p2, second)
		move_human_paddle(state, p2, second, dt)
		decay_human_swing(state, p2, dt)

	if state.shieldTimer > 0.0 and ball.vy > 0.0:
		ball.vy *= 1.0 - dt * 0.55
	state.shieldTimer = maxf(0.0, state.shieldTimer - dt)

	update_shot_read(state, state.active_player())

	var previous_ball := {"x": ball.x, "y": ball.y, "z": ball.z}
	var previous_vz := ball.vz
	ball.x += ball.vx * dt
	ball.y += ball.vy * dt
	ball.z += previous_vz * dt - 0.5 * float(balance["ballGravity"]) * dt * dt
	ball.vz = previous_vz - float(balance["ballGravity"]) * dt
	var air_drag: float = pow(float(balance["airDrag"]), dt * 60.0)
	ball.vx = (ball.vx + ball.spin * float(balance["airSpinCurve"]) * dt) * air_drag
	ball.vy *= air_drag
	ball.spin *= float(balance["spinDecay"])
	ball.backspin *= pow(0.996, dt * 60.0)
	ball.topspin *= pow(0.995, dt * 60.0)
	ball.bouncePulse = maxf(0.0, ball.bouncePulse - dt * 8.5)
	ball.hitFlash = maxf(0.0, ball.hitFlash - dt * 4.2)
	ball.hitPulse = maxf(0.0, ball.hitPulse - dt * 5.5)
	ball.netCord = maxf(0.0, ball.netCord - dt * 5.5)
	ball.landRing = maxf(0.0, ball.landRing - dt)

	if not state.serving:
		ball.trailTime -= dt
		if ball.trailTime <= 0.0 and hypot2(ball.vx, ball.vy) > 80.0:
			ball.trail.append({"x": ball.x, "y": ball.y, "z": ball.z, "life": 0.3})
			if ball.trail.size() > 10:
				ball.trail.pop_front()
			ball.trailTime = 0.022
		for point in ball.trail:
			point["life"] = float(point["life"]) - dt
		if ball.trail.size() > 0 and float(ball.trail[0]["life"]) <= 0.0:
			ball.trail.pop_front()
	else:
		ball.trail = []

	var player_contact_now: bool = can_hit(player, ball) or crossed_paddle(player, ball, previous_ball)
	if state.playerSwingBuffer > 0.0 and state.smashPrimed and player_contact_now:
		state.smashContactGrace = maxf(state.smashContactGrace, float(balance["smashContactGrace"]))
	if state.playerSwingBuffer > 0.0 \
		and (not state.smashPrimed) \
		and (player_contact_now or state.smashContactGrace > 0.0 or state.smashContactFallback):
		var timing_age: float = float(minf(state.queuedShotAge, float(balance["smashTimingAgeCap"]))) if state.queuedShotVariant == "smash" else state.queuedShotAge
		if hit_ball(
			state,
			player,
			state.queuedShotPower,
			false,
			true,
			state.queuedShotAim,
			state.queuedShotSlice,
			state.queuedShotVariant,
			state.queuedShotAimY,
			timing_age,
			state.queuedShotPrecision,
		):
			state.playerSwingBuffer = 0.0
			state.queuedShotAge = 0.0
			state.queuedShotSlice = false
			state.queuedShotVariant = "auto"
			state.smashPrimed = false
			state.smashTapWindow = 0.0
			state.smashContactGrace = 0.0
			state.smashContactFallback = false
	if state.humanMode == "coop":
		attempt_human_swing(state, state.player, previous_ball)
		attempt_human_swing(state, state.playerMate, previous_ball)
	elif state.humanMode == "pvp":
		attempt_human_swing(state, state.paddle(state.pvpActiveKey), previous_ball)
	if handle_net_collision(state, previous_ball):
		return state.result
	var smash_returns_over_net: bool = ball.shotType == "smash-x2" \
		and ball.smashStage >= 2 \
		and ((state.lastHitterSide != null and String(state.lastHitterSide) == "player"
			and float(previous_ball["y"]) < float(court["netY"])
			and ball.y >= float(court["netY"])
			and ball.vy > 0.0)
			or (state.lastHitterSide != null and String(state.lastHitterSide) == "ai"
				and float(previous_ball["y"]) > float(court["netY"])
				and ball.y <= float(court["netY"])
				and ball.vy < 0.0))
	if smash_returns_over_net:
		score_point(state, String(state.lastHitterSide), "msgSmashReturned", POINT_WINNER)
		return state.result
	if not ball.crossedNet \
		and (float(previous_ball["y"]) - float(court["netY"])) * (ball.y - float(court["netY"])) <= 0.0 \
		and absf(ball.y - float(previous_ball["y"])) > 0.01:
		ball.crossedNet = true
	if ball.z <= 0.0:
		var discriminant: float = maxf(0.0, previous_vz * previous_vz + 2.0 * float(balance["ballGravity"]) * maxf(0.0, float(previous_ball["z"])))
		var impact_time: float = clampf((previous_vz + sqrt(discriminant)) / float(balance["ballGravity"]), 0.0, dt)
		var impact_vz: float = previous_vz - float(balance["ballGravity"]) * impact_time
		if handle_ground_bounce(state, impact_vz, dt - impact_time):
			return state.result
	if handle_walls(state):
		return state.result
	update_doubles_ai(state, dt)
	if state.pointPause <= 0.0 and state.result == null:
		for p in [state.player, state.playerMate, state.opponent, state.opponentMate]:
			var distance: float = hypot2(p.x - float(effort_start[p.key][0]), p.y - float(effort_start[p.key][1]))
			var movement := clampf(distance / maxf(0.000001, p.speed * dt), 0.0, 1.0)
			var athlete: Dictionary = athlete_for(state, p)
			p.staminaEnergy = Stamina.effort_energy(p.staminaEnergy, fatigue_dt, movement, p.sprinting, float(athlete.get("stats", {}).get("stamina", 1.0)))
		sync_rally_energy(state)

	player.swing = maxf(0.0, player.swing - dt * 5.0)
	state.playerMate.swing = maxf(0.0, state.playerMate.swing - dt * 5.0)
	state.opponent.swing = maxf(0.0, state.opponent.swing - dt * 5.0)
	state.opponentMate.swing = maxf(0.0, state.opponentMate.swing - dt * 5.0)
	state.specialCooldown = maxf(0.0, state.specialCooldown - dt)
	if state.specialCooldown <= 0.0:
		state.specialReady = minf(1.0, state.specialReady + dt * float(balance["specialRegen"]) * float(state.athlete["stats"]["stamina"]))
	state.flash = maxf(0.0, state.flash - dt * 3.0)
	capture_replay_frame(state)
	return state.result
