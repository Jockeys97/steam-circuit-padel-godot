## audit_support.gd — the scenario builders the reference audits carry locally,
## shared by the ported audits under `godot/tests/audits/`.
##
## This file is a support module, not an audit: it has no `-audit` name and the
## runner does not report it. It holds the three things more than one reference
## audit repeats verbatim:
##
##   1. `VUOTO` / `EMPTY_INPUT` — the 11-field empty input the JavaScript audits
##      hand to `updateMatch`. `Sim.empty_input()` (`js/game.js:2712-2734`) is the
##      authoritative 24-field struct; the JavaScript literal is the same struct
##      with the remaining fields `undefined`, which the JavaScript reads as falsy
##      and the port reads as the dictionary default. `vuoto()` is `empty_input()`
##      with the 11 documented fields set, so the two are byte-equal in effect.
##
##   2. The seed injection. Every JavaScript audit seeds in one of two ways:
##        - `state.rngState = <literal>` after construction; or
##        - `Math.random = seededRandom(seed)` *before* construction, because
##          `js/game.js:218` builds `rngState` from `Math.random()`. `Math.random`
##          is used nowhere else in `js/game.js` (verified at the frozen baseline:
##          the only other five hits are comments). `seeded_rng_state()` reproduces
##          that initial value exactly (see the note below).
##
##   3. The scripted tick loop shape (`update_match` at a caller-chosen dt).
##
## SEED NOTE — `seededRandom` (`scripts/shot-quality-audit.mjs:18-29`) is
## mulberry32; `js/game.js:218` then does `(Math.random() * 0xffffffff) | 0`. The
## draw is an exact `uint32 / 2**32`, so the product is `u * (2**32 - 1) / 2**32`,
## which is strictly between `u - 1` and `u` and never rounds up to `u` (the
## distance to `u` is at least `2**-32`, twenty orders of magnitude above half an
## ulp near `u`). `| 0` therefore truncates to `u - 1`, and `seeded_rng_state()` is
## exact, not an approximation.
##
## This module reads `godot/src/sim/**` and never writes to it, and it never
## re-implements a physics or scoring rule — every rule under test is reached
## through `Sim`.
extends RefCounted

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Rng := preload("res://src/sim/rng.gd")


## `EMPTY_INPUT` / `VUOTO`, the input every reference audit's scripted loop uses.
static func vuoto() -> Dictionary:
	return Sim.empty_input()


## One mulberry32 draw from `seed`, as a uint32 in `0 .. 2**32 - 1`
## (`scripts/shot-quality-audit.mjs:18-29`):
##
##     value = (value + 0x6D2B79F5) | 0
##     t = Math.imul(value ^ (value >>> 15), 1 | value)
##     t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
##     return ((t ^ (t >>> 14)) >>> 0) / 4294967296
##
## The 32-bit masking is `Rng.i32` / `Rng.imul`, the pair the bit-exact
## `nextRandom` port already uses.
static func mulberry32_step(value_in: int) -> Dictionary:
	var value := Rng.i32(value_in + 0x6D2B79F5)
	var t := Rng.imul(value ^ ((value & 0xFFFFFFFF) >> 15), 1 | value)
	t = Rng.i32(Rng.i32(t + Rng.imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t)) ^ t)
	return {"value": value, "draw": (t ^ ((t & 0xFFFFFFFF) >> 14)) & 0xFFFFFFFF}


## The first draw, kept for the single-shot case.
static func mulberry32_first(seed_value: int) -> int:
	return int(mulberry32_step(Rng.i32(seed_value))["draw"])


## `(seededRandom(seed)() * 0xffffffff) | 0` — the `rngState` `createMatchState`
## ends up with when the JavaScript audit patches `Math.random` before calling it.
static func seeded_rng_state(seed_value: int) -> int:
	return state_from_draw(mulberry32_first(seed_value))


## `(Math.random() * 0xffffffff) | 0` for one draw.
static func state_from_draw(draw: int) -> int:
	if draw == 0:
		return 0
	return Rng.i32(draw - 1)


## The `n`-th draw (1-based) of `seededRandom(seed)`, as an initial `rngState`.
##
## Needed because a benchmark that installs ONE generator and then constructs many
## states consumes one draw per construction: `scripts/shot-balance-audit.mjs:165`
## does `Math.random = seededRandom(20260811)` once and then builds 5000 rally
## states, so state `i` starts from draw `i`, not from draw 1.
static func seeded_rng_state_nth(seed_value: int, n: int) -> int:
	var value := Rng.i32(seed_value)
	var draw := 0
	for step in range(0, maxi(1, n)):
		var next := mulberry32_step(value)
		value = int(next["value"])
		draw = int(next["draw"])
	return state_from_draw(draw)


## The `Math.random = () => 0.5` case: `0.5 * 0xffffffff` truncated.
const HALF_RNG_STATE := 2147483647


## `state.rngState = seed` — the direct injection every other reference audit
## uses (`scripts/wall-rules-audit.mjs:50`, `court-speed-audit.mjs:39`, ...).
static func inject_seed(state, seed_value: int) -> void:
	state.rng_state = seed_value
	state.rng_calls = 0


## The rally bench every AI-facing audit builds
## (`scripts/difficulty-audit.mjs:33-67`, `scripts/shot-balance-audit.mjs:33-67`,
## `scripts/ai-attack-audit.mjs:30-58`): a live rally, `lastHitterSide` the AI, and
## the three serve-reception keys cleared — without clearing them the opponents'
## rackets are parked in service-reception position by a branch that runs before
## the defence logic, and the bench measures an AI waiting for a serve.
static func rally_state(athlete: Dictionary, ai_profile: Dictionary) -> Sim.State:
	var state := Sim.create_match_state("quick", athlete, Frozen.arenas()[0], ai_profile)
	state.running = true
	state.serving = false
	state.pointPause = 0.0
	state.lastHitterSide = "ai"
	state.rallyHits = 3
	state.aiServiceReceiverKey = null
	state.serviceReceiverKey = null
	state.aiReceiverLocked = false
	return state


## `js/game.js` reads two paddles as "the receiving team" while the serve keys are
## set; the audits clear them, so this helper is the one place that spelling lives.
static func clear_service_reception(state) -> void:
	state.aiServiceReceiverKey = null
	state.serviceReceiverKey = null
	state.aiReceiverLocked = false


## `state.stats.pointsWon.player + state.stats.pointsWon.ai` — the total the
## reference audits watch to detect that a point was awarded.
static func points_awarded(state) -> int:
	return int(state.stats["pointsWon"]["player"]) + int(state.stats["pointsWon"]["ai"])


## `Math.hypot(vx, vy)` of the ball, the speed every reference audit measures.
static func ball_speed(state) -> float:
	return Sim.hypot2(state.ball.vx, state.ball.vy)
