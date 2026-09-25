## state.gd — `SimState`, the port of the object `createMatchState` builds
## (`js/game.js:184-326`).
##
## Every field the JavaScript state carries is here, including the ones that are
## presentation-shaped but advanced inside the step (`runPhase`, `actionPose`,
## `motion`, `moveRatio`, `ball.trail`, `bouncePulse`, `landRing`, `hitFlash`).
## `simulation-port-boundary.md` §4 keeps them in the sim state on purpose: they
## are deterministic functions of state, and dropping them would quietly change
## the branch structure of the step.
##
## Two deliberate divergences from the JavaScript, both required by the port:
##
##   - `rngCalls` is a real counter bumped inside `nextRandom`. JavaScript cannot
##     count its calls (`js/game.js` tracks only `rngState`), which is why the
##     digest harness reconstructs the count by replay. The port keeps the real
##     number, so a mismatch between the counter and the reconstruction is a
##     finding rather than a rounding problem.
##   - localized text is not stored. `events` and `pointMessage` hold message
##     ids, per §2 of the boundary ticket (`t()` is a presentation coupling).
##     Neither field enters the digest.
extends RefCounted

const Ent := preload("res://src/sim/entities.gd")

var lineup: Dictionary = {}
var mode: String = "quick"
var athlete: Dictionary = {}
var arena: Dictionary = {}
var ai: Dictionary = {}
var tournamentRound: int = 0
var humanMode: String = "solo"
var coop: bool = false
var pvp: bool = false
var pvpActiveKey: String = "opponent"
var pvpSwitchCooldown: float = 0.0
var pvpSwitchFlash: float = 0.0
var pvpAthlete: Variant = null
var scoring: String = "tennis"
## `null` in JavaScript; 0 means "unset" here (`state.pointsToWin` is only ever
## compared for truthiness / used as an integer threshold).
var pointsToWin: int = 0
var points: Dictionary = {"player": 0, "ai": 0}
var games: Dictionary = {"player": 0, "ai": 0}
var sets: Dictionary = {"player": 0, "ai": 0}
var tieBreak: bool = false
var tieBreakPoints: Dictionary = {"player": 0, "ai": 0}
var setScores: Array = []
var playerScore: String = "0"
var aiScore: String = "0"
var combo: int = 1
var rallyHits: int = 0
var rallyEnergy: Dictionary = {"player": 1.0, "ai": 1.0}
var rng_state: int = 0
var rng_calls: int = 0
var shotFeedback: Variant = null
var shotRead: Dictionary = {
	"active": false,
	"eta": null,
	"perfectWindow": 0.055,
	"advice": "read",
	"profile": "control",
	"overlap": false,
}
var specialCooldown: float = 0.0
var specialReady: float = 1.0
var serveSide: String = "player"
var serveCourt: String = "right"
var serveAttempts: int = 0
var serving: bool = true
var serveTimer: float = 0.9
var serviceReceiverKey: Variant = null
var aiServiceReceiverKey: Variant = null
var pointPause: float = 0.0
var hitStop: float = 0.0
var pointMessage: String = ""
var lastHitterSide: Variant = null
var flash: float = 0.0
var shieldTimer: float = 0.0
var wallEventTimer: float = 0.0
var paused: bool = false
var running: bool = false
var lastTime: float = 0.0
var elapsed: float = 0.0
var events: Array = []
var result: Variant = null
var player: Ent.SimPaddle = null
var playerMate: Ent.SimPaddle = null
var opponent: Ent.SimPaddle = null
var opponentMate: Ent.SimPaddle = null
var ball: Ent.SimBall = null
var aiTargetX: float = 0.0
var aiReactionDelay: float = 0.0
var aiPrimaryKey: String = "opponent"
var aiReceiverLocked: bool = false
var aiShotPressure: float = 0.0
var aiRecoveryMode: bool = false
var aiTeamShape: String = "defend"
var playerTeamTactic: String = "balanced"
var tacticFlash: float = 0.0
var aiX3Recovery: float = 0.0
## How willing the AI is to let a ball bounce instead of taking it in the air
## (`ai_contact.gd`). 0.0 is the behaviour recorded in tools/parity-godot/golden/
## (a conservative bounce planner: the back player volleys ~82% of the balls it
## touches, measured 2026-09-23); 1.0 relaxes the planner's three refusals fully.
## A knob for tuning, not yet a rule: nothing sets it above 0 in a real match.
var aiBounceBias: float = 0.0
## Glass-aware bounce play for the AI back player (`ai_glass.gd`): when on, a ball
## the old planner would take in the air is instead forecast through its bounce and
## any glass, and the AI waits for it where it can reach it at a comfortable height.
## Off by default: the golden matches and the shipped game are unchanged until a
## level turns it on on purpose.
var aiGlassPlay: bool = false
## The last error roll of a human shot (`sim.gd` roll_shot_error): quality, chance,
## the draw and the outcome. Diagnostic only, read by `game/match_log.gd`; no rule
## reads it and it is not in the parity digest. Added 2026-09-23 because a recorded
## match showed 5 errors where the curve predicted ~14 and the simulation alone
## could not reproduce it.
var lastShotErrorRoll: Dictionary = {}
## The AI's read of the human ball it has just locked a receiver for, decided ONCE at
## that moment (`sim.gd` lock_ai_receiver_for_incoming_shot), as a player decides:
## an overhead chance ({key, x, y}: smash it there) or, for a lob with no such chance,
## `aiLobOver` (it goes over them: let it bounce, play it off the bounce or the glass).
## Re-evaluating every tick flipped the decision mid-flight and lost smashes.
var aiOverheadPlan: Dictionary = {}
var aiLobOver: bool = false
## Where the human can take the ball as it comes back off their own back glass
## (`Sim.update_glass_exit`): {x, y, z, at} in court px and match seconds, or {}.
## Presentation reads it; no rule does. `glassExitKey` caches the forecast per bounce.
var glassExit: Dictionary = {}
var glassExitKey: String = ""
## The AI receiver was wrong-footed by the last human shot (`evCounter`), and whether
## its net player already tried the reflex block for this ball (one roll per shot).
var aiWrongFooted: bool = false
var aiReflexTried: bool = false
## The strike in progress is a reflex block: a short, slow, central volley.
var aiReflexBlock: bool = false
## Quality of the strike in progress when a human struck it, -1 otherwise (the AI
## partner of the human, or the AI). Read by the "ball in the middle" rule.
var humanShotQuality: float = -1.0
var playerX3Recovery: float = 0.0
var playerSwingBuffer: float = 0.0
var queuedShotPower: float = 1.0
var queuedShotAim: float = 0.0
var queuedShotAimY: float = 0.0
var queuedShotSlice: bool = false
var queuedShotVariant: String = "auto"
var queuedShotAge: float = 0.0
var queuedShotCharge: float = 0.0
var queuedShotPrecision: float = 0.0
var smashPrimed: bool = false
var cutVolleyPrimed: bool = false
var cutVolleyTapWindow: float = 0.0
var globoPrimed: bool = false
var globoTapWindow: float = 0.0
var smashTapWindow: float = 0.0
var smashContactGrace: float = 0.0
var smashContactFallback: bool = false
var shotCharge: float = 0.0
var shotAim: float = 0.0
var shotAimY: float = 0.0
var shotPrecision: float = 0.0
var shotIntent: String = "drive"
var activePlayerKey: String = "player"
var controlMode: String = "semi"
var switchCooldown: float = 0.0
var receiverLocked: bool = false
var manualReceiverOverride: bool = false
var manualMovementTimer: float = 0.0
var receiverSwitchFlash: float = 0.0
var manualSwitchFlash: float = 0.0
var hapticPulse: Variant = null
var stats: Dictionary = {}
var replayFrames: Array = []
var replayMax: int = 720
## Written by `hitBall` (`js/game.js:1505`) — the shot being replied to.
var incomingShot: Variant = null
var specialReadPenalty: float = 0.0
var doubleFaultFlag: bool = false
## `matchFormat` (`js/game.js:2006-2015`) reads four optional fields off the
## state; the constructor never sets them, so the defaults here are the
## `??` fallbacks written into the JavaScript.
var gamesToWin: int = 6
var gameMargin: int = 2
var tieBreakAt: Variant = 6
var setsToWin: int = 1


## `state[key]` on the JavaScript side (`js/game.js:445`, `588`, `2552`, ...).
func paddle(key: String) -> Ent.SimPaddle:
	match key:
		"player":
			return player
		"playerMate":
			return playerMate
		"opponent":
			return opponent
		"opponentMate":
			return opponentMate
	push_error("state.paddle(): unknown key '%s'" % key)
	return player


func active_player() -> Ent.SimPaddle:
	return paddle(activePlayerKey)


## `other(side)` (`js/game.js:110`).
static func other(side: String) -> String:
	return "ai" if side == "player" else "player"
