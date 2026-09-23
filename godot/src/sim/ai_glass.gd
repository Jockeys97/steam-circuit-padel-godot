## ai_glass.gd — where an incoming ball can be taken AFTER its bounce, glass included.
##
## Pure: it steps a COPY of the ball with the simulation's own per-tick physics
## (`sim.gd` update_match: gravity, air drag, spin curve; `handle_ground_bounce`:
## restitution, backspin bite, tangential damping; `handle_walls`: glass reflection
## by the arena's `wallBounce`) and never touches the state or the RNG. The special
## glass cases that roll dice (smash X2/X3, cut-volley kill) are not forecast: the
## planner gives up on them and the AI plays them as it always did.
##
## Why it exists: `ai_contact.gd` refuses any bounce from which the ball might reach
## a glass, and in padel nearly every deep or angled ball does. Measured 2026-09-23
## (docs/agent-work/ai-bounce/): the AI back player took 76-100% of its balls in the
## air, 100% at the two top levels. Without a forecast through the glass, "let it
## bounce" cannot work whatever the other knobs say.
extends RefCounted

## Forecast resolution: the simulation's own fixed tick. Not coarser: `spinDecay`
## is applied once per tick in the sim, so a 1/60 s step decays spin at half the
## real rate and bends the forecast by up to ~60 px after a bounce (measured).
const STEP := 1.0 / 120.0
## Post-bounce contact height. Not a fixed number: a drive rises to about 40 px after
## its bounce and a slice to about 28 (measured 2026-09-23), so one threshold either
## scoops the ball off the floor (18 px: the AI's contact height fell from 42 to 24 px
## and the owner found it weak) or leaves almost no window (36 px: the planner found a
## contact so rarely it went back to volleying). The AI takes the ball near the top of
## ITS arc: at least TOP_SHARE of the highest point that arc reaches, never below
## CONTACT_MIN_Z.
const CONTACT_MIN_Z := 20.0
const TOP_SHARE := 0.8
const CONTACT_HEADROOM := 8.0
## Keep the planned contact inside the court the paddle can actually stand on.
const WALL_CLEARANCE_PX := 40.0
const NET_CLEARANCE_PX := 60.0
## Seconds of slack on top of reaction time before the ball arrives.
const ARRIVAL_MARGIN_S := 0.08
## A good contact this close in time is "on the racket now" and is never passed up for a
## later glass play. Without it the AI let reachable balls go, waiting for the glass,
## and then missed them: level 1 lost 136 points on a double bounce instead of 9
## (measured 2026-09-23).
const NOW_S := 2.0 / 120.0


## Samples of the ball's future on the AI half: {t, x, y, z, bounced, glass}. Stops
## at the second bounce, when the ball leaves the AI half, at an unbounced glass
## contact (that is a point, not a shot) or after `horizon` seconds.
static func forecast(b: Dictionary, court: Dictionary, balance: Dictionary, wall_bounce: float, horizon: float = 2.2, already_bounced: bool = false) -> Array:
	var out: Array = []
	var x := float(b.x); var y := float(b.y); var z := float(b.z)
	var vx := float(b.vx); var vy := float(b.vy); var vz := float(b.vz)
	var spin := float(b.spin); var backspin := float(b.backspin); var topspin := float(b.topspin)
	var r := float(b.r)
	var g := float(balance.ballGravity)
	var drag := pow(float(balance.airDrag), STEP * 60.0)
	var net_y := float(court.netY)
	var bounced := already_bounced
	var glass := false
	var on_ai_half := float(b.y) < net_y
	var t := 0.0
	while t < horizon:
		var prev_vz := vz
		var prev_z := z
		x += vx * STEP
		y += vy * STEP
		z += prev_vz * STEP - 0.5 * g * STEP * STEP
		vz = prev_vz - g * STEP
		vx = (vx + spin * float(balance.airSpinCurve) * STEP) * drag
		vy *= drag
		spin *= float(balance.spinDecay)
		backspin *= pow(0.996, STEP * 60.0)
		topspin *= pow(0.995, STEP * 60.0)
		t += STEP
		if y < net_y:
			on_ai_half = true
		elif on_ai_half:
			break                                   # came back over the net: not ours
		if not on_ai_half:
			if z <= 0.0:
				break                               # lands on the far half: not ours
			continue                                # still flying towards the net
		if z <= 0.0:
			if bounced:
				break                               # second bounce: the point is over
			bounced = true
			var disc := maxf(0.0, prev_vz * prev_vz + 2.0 * g * maxf(0.0, prev_z))
			var impact_time := clampf((prev_vz + sqrt(disc)) / g, 0.0, STEP)
			var impact := absf(prev_vz - g * impact_time)
			var slice_amount := clampf(backspin, 0.0, 1.2)
			var topspin_amount := clampf(topspin, 0.0, 1.3)
			var restitution := (float(balance.groundRestitution) + float(balance.groundRestitutionBoost) * clampf(impact / 520.0, 0.0, 1.0)) \
				* (1.0 - slice_amount * 0.28) + topspin_amount * 0.12
			var rebound := maxf(float(balance.minimumBounceVz) * (1.0 - slice_amount * 0.26), impact * restitution)
			vx = (vx + spin * float(balance.groundSpinTransfer)) * float(balance.groundTangentialDamping)
			vy *= float(balance.groundTangentialDamping) * (1.0 - slice_amount * 0.14) * (1.0 + topspin_amount * 0.08)
			spin *= 0.7
			backspin *= 0.35
			topspin *= 0.72
			var rest := STEP - impact_time
			z = maxf(0.0, rebound * rest - 0.5 * g * rest * rest)
			vz = rebound - g * rest
		var side_hit := x - r < float(court.left) or x + r > float(court.right)
		var back_hit := y - r < float(court.top)
		if side_hit or back_hit:
			if not bounced:
				break                               # glass before the floor: a point
			glass = true
			if side_hit:
				x = clampf(x, float(court.left) + r, float(court.right) - r)
				vx *= -wall_bounce
				vy *= float(balance.wallTangentialDamping)
			if back_hit:
				y = maxf(y, float(court.top) + r)
				vy *= -wall_bounce
				vx *= float(balance.wallTangentialDamping)
			spin *= -0.45
		out.append({"t": t, "x": x, "y": y, "z": z, "bounced": bounced, "glass": glass})
	return out


## The first post-bounce point this paddle can reach in time with the ball at a
## comfortable height, or {} when there is none. `p`: x, y, speed, reaction, width,
## depth (the same keys `ai_contact.gd` receives). Depth movement is 56% of lateral
## speed, as in the simulation's own paddle movement.
## When the ball is going to reach the BACK glass after its bounce and the AI can be
## where it comes off it, that contact is preferred over the ones before the glass:
## taking a deep ball after the back wall is the padel play the owner found missing
## (measured: 0-0.8% of AI contacts came after the back glass).
static func plan(p: Dictionary, b: Dictionary, court: Dictionary, balance: Dictionary, wall_bounce: float, already_bounced: bool = false) -> Dictionary:
	var top_z := float(balance.playableHitHeight) - CONTACT_HEADROOM
	var samples := forecast(b, court, balance, wall_bounce, 2.2, already_bounced)
	# The two arcs a padel ball offers after its bounce: before the glass, and after it.
	var arc_top := 0.0
	var glass_top := 0.0
	for s in samples:
		if bool(s.bounced):
			if bool(s.glass):
				glass_top = maxf(glass_top, float(s.z))
			else:
				arc_top = maxf(arc_top, float(s.z))
	var arc_floor := maxf(CONTACT_MIN_Z, arc_top * TOP_SHARE)
	var glass_floor := maxf(CONTACT_MIN_Z, glass_top * TOP_SHARE)
	var first: Dictionary = {}
	for s in samples:
		if not bool(s.bounced):
			continue
		var z := float(s.z)
		if z < (glass_floor if bool(s.glass) else arc_floor) or z > top_z:
			continue
		var x := float(s.x)
		var y := float(s.y)
		if x < float(court.left) + WALL_CLEARANCE_PX or x > float(court.right) - WALL_CLEARANCE_PX:
			continue
		if y < float(court.top) + WALL_CLEARANCE_PX or y > float(court.netY) - NET_CLEARANCE_PX:
			continue
		var speed := maxf(1.0, float(p.speed))
		var travel_x := maxf(0.0, absf(x - float(p.x)) - float(p.width) * 0.45) / speed
		var travel_y := maxf(0.0, absf(y - float(p.y)) - float(p.depth) * 0.45) / (speed * 0.56)
		# A glass contact pays one more reaction: the glass re-locks the AI receiver
		# (`sim.gd` handle_walls -> lock_ai_receiver_for_incoming_shot) and it stands still
		# while reading the rebound. Unbudgeted, the AI let reachable balls go for the
		# glass and then watched them run past it: 57 of 62 double bounces (measured).
		var relock := float(p.get("glass_relock", 0.0)) if bool(s.glass) else 0.0
		if float(p.reaction) + relock + maxf(travel_x, travel_y) + ARRIVAL_MARGIN_S <= float(s.t):
			var candidate := {"x": x, "y": y, "t": float(s.t), "z": z, "glass": bool(s.glass)}
			if bool(s.glass):
				return candidate                    # after the glass: the preferred play...
			if float(s.t) <= NOW_S:
				return candidate                    # ...unless a good ball is on the racket NOW
			if first.is_empty():
				first = candidate                   # before it: kept in case no glass play
	return first


## Where an incoming, not yet bounced ball ends up on the AI half, with the same
## physics as `forecast`: IN (it reaches the floor first), OUT (it reaches a glass
## first: in padel that is out, the point goes to the AI — `sim.gd` handle_walls,
## "msgWallNoBounce") or UNKNOWN (it comes back over the net, or not within the
## horizon). Pure, no RNG.
const IN := 1
const OUT := 0
const UNKNOWN := -1

static func first_contact(b: Dictionary, court: Dictionary, balance: Dictionary, horizon: float = 2.5) -> int:
	var x := float(b.x); var y := float(b.y); var z := float(b.z)
	var vx := float(b.vx); var vy := float(b.vy); var vz := float(b.vz)
	var spin := float(b.spin)
	var r := float(b.r)
	var g := float(balance.ballGravity)
	var drag := pow(float(balance.airDrag), STEP * 60.0)
	var net_y := float(court.netY)
	var on_ai_half := y < net_y
	var t := 0.0
	while t < horizon:
		x += vx * STEP
		y += vy * STEP
		z += vz * STEP - 0.5 * g * STEP * STEP
		vz -= g * STEP
		vx = (vx + spin * float(balance.airSpinCurve) * STEP) * drag
		vy *= drag
		spin *= float(balance.spinDecay)
		t += STEP
		if y < net_y:
			on_ai_half = true
		elif on_ai_half:
			return UNKNOWN
		if z <= 0.0:
			return IN if on_ai_half else UNKNOWN
		if on_ai_half and (x - r < float(court.left) or x + r > float(court.right) or y - r < float(court.top)):
			return OUT
	return UNKNOWN

