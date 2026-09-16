## drill_target.gd — the drill's target: where it is, what kind it is, how the
## ball's landing is graded against it.
##
## Ported from `js/drill.js:148-162` (`placeTarget`), `js/drill.js:264-313`
## (`squashQuality`, `targetTier`). The geometry constants come from the generated
## table (`TARGET_R`, `BULLSEYE`, `SQUASH_FLAT`, `SQUASH_LOW`), never retyped.
##
## API (a UI lane consumes this without reading its internals):
##
##   DrillTarget.place(gen, exercise, round) -> Dictionary
##       A new target `{x, y, r, kind, active}`. `gen` is a `DrillSeed`; the
##       reference's unseeded `Math.random` is replaced by it (see
##       `drill_seed.gd` for the defect and its anchors). Kind alternates with
##       the round, it is not random (`js/drill.js:151-153`).
##   DrillTarget.EMPTY -> Dictionary
##       The inactive target a drill starts with, `js/drill.js:123`.
##   DrillTarget.kind_for(exercise, round) -> String
##       `"short"` / `"deep"`, or `"short"` for an exercise with no target kinds.
##   DrillTarget.squash_quality(impact_vz) -> float
##       `js/drill.js:270-273`, clamped to 0..1.
##   DrillTarget.tier(target, squash, ball_x, ball_y) -> Dictionary
##       `js/drill.js:283-313`: `{in_zone, tier, diagnosis}`. `tier` is the score
##       multiplier before the grade, `diagnosis` is the message id the HUD shows.
##   DrillTarget.in_opponents_half(y) -> bool
##       Only a bounce in the opponents' half is a target hit (`js/drill.js:394`).
##
## The grading is continuous, not a threshold: between the two measured squash
## references the score slides (`js/drill.js:28-39`), so a badly executed cut
## scores lower than a good one instead of passing anyway.
extends RefCounted

const Tables := preload("res://src/modes/mode_tables.gd")
const Frozen := preload("res://src/sim/frozen.gd")


## `js/drill.js:123`: the drill's `target` field at construction.
static func empty() -> Dictionary:
	return {"x": 0.0, "y": 0.0, "r": Tables.drill_target_r(), "kind": "short", "active": false}


## `js/drill.js:151-153`: the kind of the target for this round.
static func kind_for(exercise: Dictionary, round: int) -> String:
	var kinds: Array = exercise.get("kinds", [])
	if kinds.size() > 0:
		return String(kinds[round % kinds.size()])
	return "short"


## `placeTarget` (`js/drill.js:149-162`). The two draws are in the reference's
## own order (`x` first, then `y`), so a later fix to the reference's defect has a
## single place to align.
static func place(gen: RefCounted, exercise: Dictionary, round: int) -> Dictionary:
	var court: Dictionary = Frozen.court()
	var kind := kind_for(exercise, round)
	var pad := 90.0
	var left := float(court["left"])
	var right := float(court["right"])
	var net_y := float(court["netY"])
	var top := float(court["top"])
	var x: float = left + pad + gen.draw() * (right - left - pad * 2.0)
	# Corto: appena oltre la rete, dove resta giocabile solo una palla che
	# rimbalza bassa. Profondo: contro il vetro di fondo, che chiede spinta.
	var y: float = net_y - 130.0 - gen.draw() * 50.0 if kind == "short" \
		else top + 60.0 + gen.draw() * 50.0
	return {"x": x, "y": y, "r": Tables.drill_target_r(), "kind": kind, "active": true}


## `squashQuality(impactVz)` (`js/drill.js:270-273`): how low the ball bounced,
## 0 = flat, 1 = fully cut.
static func squash_quality(impact_vz: float) -> float:
	var flat := Tables.drill_squash_flat()
	var low := Tables.drill_squash_low()
	var q: float = (flat - impact_vz) / (flat - low)
	return clampf(q, 0.0, 1.0)


## `targetTier(drill, ball)` (`js/drill.js:283-313`). The short target wants a
## low bounce, the deep one wants the drive: the same scale read in the two
## directions.
static func tier(target: Dictionary, squash: float, ball_x: float, ball_y: float) -> Dictionary:
	var dx: float = ball_x - float(target["x"])
	var dy: float = ball_y - float(target["y"])
	var dist: float = sqrt(dx * dx + dy * dy)
	var radius := float(target["r"])
	var corto := String(target["kind"]) == "short"
	if dist > radius:
		# La diagnosi guarda la direzione dell'errore: il verso di `y` cresce
		# allontanandosi dal fondo, quindi piu' grande vuol dire piu' corto.
		var lontano_x: bool = absf(dx) > radius
		var diagnosis := "drillWhyWide" if lontano_x \
			else ("drillWhyShort" if ball_y > float(target["y"]) else "drillWhyDeep")
		return {"in_zone": false, "tier": 0.2, "diagnosis": diagnosis}
	var centrato: bool = dist < radius * Tables.drill_bullseye()
	var base: float = 1.0 if centrato else 0.6
	var esecuzione: float = squash if corto else 1.0 - squash
	if esecuzione < 0.35:
		return {
			"in_zone": true,
			"tier": base * 0.5,
			"diagnosis": "drillWhyTooBouncy" if corto else "drillWhyTooSoft",
		}
	return {
		"in_zone": true,
		"tier": base * (0.62 + esecuzione * 0.38),
		"diagnosis": "drillWhyBullseye" if centrato else "drillWhyInZone",
	}


## `ball.y < COURT.netY` (`js/drill.js:394`): a bounce in your own half is a
## missed attempt, not a target hit.
static func in_opponents_half(y: float) -> bool:
	return y < float(Frozen.court()["netY"])
