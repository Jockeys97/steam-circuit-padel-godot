## entities.gd — `SimPaddle` and `SimBall`, the two mutable entity shapes the
## simulation moves (`js/game.js:35-108`).
##
## Field-for-field transcription: no field is dropped and no field is added that
## the JavaScript does not have, so a later diff of a digest cannot be explained
## away by "the port has a different state shape".
extends RefCounted

const Frozen := preload("res://src/sim/frozen.gd")


class SimPaddle:
	var x: float = 0.0
	var y: float = 0.0
	# Width: the players' racket takes half weight from the chosen athlete
	# (`js/game.js:45`); the opponents' takes full weight plus the roster ratio.
	var w: float = 0.0
	var h: float = 16.0
	var speed: float = 0.0
	var reach: float = 0.0
	var swing: float = 0.0
	var swingSide: float = 1.0
	var actionPose: float = 0.0
	var actionIntent: String = "drive"
	var motion: float = 0.0
	var moveRatio: float = 0.0
	var runPhase: float = 0.0
	var isPlayer: bool = false
	var dashTimer: float = 0.0
	var hitCooldown: float = 0.0
	var controlled: bool = false
	var role: String = "back"
	var skill: float = 1.0
	var key: String = ""
	var charge: float = 0.0
	var aim: float = 0.0
	var aimY: float = 0.0
	var swingBuffer: float = 0.0
	## `null` or {power, charge, aim, aimY, slice, variant, precision, age}
	var queuedShot: Variant = null
	var shotIntent: String = "drive"
	var splitStep: float = 0.0
	var sprinting: float = 0.0
	# Added by `prepareServe` / the swing path on the JavaScript side too.
	var smashPrimed: bool = false
	var smashTapWindow: float = 0.0
	var smashContactGrace: float = 0.0
	var smashContactFallback: bool = false


class SimBall:
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var r: float = 11.0
	var vx: float = 0.0
	var vy: float = 0.0
	var vz: float = 0.0
	var spin: float = 0.0
	var backspin: float = 0.0
	var topspin: float = 0.0
	var shotType: String = "serve"
	var smashStage: int = 0
	var smashTargetSide: Variant = null
	var postGlassSide: Variant = null
	var wallAngleResolved: bool = false
	var bouncePulse: float = 0.0
	var netCord: float = 0.0
	var netFaultOwner: Variant = null
	var crossedNet: bool = true
	var serveTouchedNet: bool = false
	var served: bool = false
	var serveInFlight: bool = false
	var serveTargetSide: String = "left"
	var serveTargetX: float = 0.0
	var serveTargetY: float = 0.0
	## {player: int, ai: int}
	var bounces: Dictionary = {"player": 0, "ai": 0}
	var trail: Array = []
	var trailTime: float = 0.0
	var landRing: float = 0.0
	var hitFlash: float = 0.0
	var hitPulse: float = 0.0
	# Written outside `createBall` on the JavaScript side (`js/game.js:1506`).
	var wallKill: float = 0.0


## `createPaddle` (`js/game.js:35-72`). `profile` is a Dictionary because the
## JavaScript passes four differently-shaped option objects to the same builder.
static func make_paddle(x: float, y: float, is_player: bool, profile: Dictionary) -> SimPaddle:
	var balance: Dictionary = Frozen.balance()
	var stats: Dictionary = profile.get("stats", {"speed": 1.0, "control": 1.0, "reach": 1.0})
	var p := SimPaddle.new()
	p.x = x
	p.y = y
	var width_scale: float
	if is_player:
		width_scale = 0.86 + float(stats["control"]) * 0.14
	else:
		width_scale = 0.94 * float(profile.get("widthRatio", 1.0))
	p.w = float(balance["basePaddleWidth"]) * width_scale
	p.h = 16.0
	if profile.has("speed"):
		p.speed = float(profile["speed"])
	else:
		p.speed = float(balance["basePaddleSpeed"]) * float(stats["speed"])
	var reach_scale: float
	if is_player:
		reach_scale = float(stats.get("reach", 1.0))
	else:
		reach_scale = float(profile.get("reachRatio", 1.0))
	p.reach = 46.0 * reach_scale
	p.swing = 0.0
	p.swingSide = 1.0
	p.actionPose = 0.0
	p.actionIntent = "drive"
	p.motion = 0.0
	p.moveRatio = 0.0
	p.runPhase = 0.0
	p.isPlayer = is_player
	p.dashTimer = 0.0
	p.hitCooldown = 0.0
	p.controlled = bool(profile.get("controlled", false))
	p.role = String(profile.get("role", "back"))
	p.skill = float(profile.get("skill", 1.0))
	p.key = String(profile.get("key", ""))
	p.charge = 0.0
	p.aim = 0.0
	p.aimY = 0.0
	p.swingBuffer = 0.0
	p.queuedShot = null
	p.shotIntent = "drive"
	p.splitStep = 0.0
	p.sprinting = 0.0
	return p


## `createBall` (`js/game.js:74-108`).
static func make_ball() -> SimBall:
	var b := SimBall.new()
	var court: Dictionary = Frozen.court()
	var center_x: float = (float(court["left"]) + float(court["right"])) / 2.0
	b.x = center_x
	b.y = float(court["bottom"]) - 80.0
	b.z = 36.0
	b.r = 11.0
	b.vx = 0.0
	b.vy = 0.0
	b.vz = 0.0
	b.spin = 0.0
	b.backspin = 0.0
	b.topspin = 0.0
	b.shotType = "serve"
	b.smashStage = 0
	b.smashTargetSide = null
	b.postGlassSide = null
	b.wallAngleResolved = false
	b.bouncePulse = 0.0
	b.netCord = 0.0
	b.netFaultOwner = null
	b.crossedNet = true
	b.serveTouchedNet = false
	b.served = false
	b.serveInFlight = false
	b.serveTargetSide = "left"
	b.serveTargetX = center_x
	b.serveTargetY = float(court["netY"])
	b.bounces = {"player": 0, "ai": 0}
	b.trail = []
	b.trailTime = 0.0
	b.landRing = 0.0
	b.hitFlash = 0.0
	b.hitPulse = 0.0
	return b
