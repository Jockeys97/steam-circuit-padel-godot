## Pure, conservative first-bounce planner. No RNG, timers or writes to state.
## Mirrored by js/ai-contact.js; physics remains owned by the simulation.
extends RefCounted

static func plan(p: Dictionary, b: Dictionary, court: Dictionary, balance: Dictionary) -> Dictionary:
	var out := {"wait": false, "reason": "emergency", "x": float(b.x), "y": float(b.y)}
	if bool(b.serve) or bool(b.fault) or not bool(b.incoming):
		out.reason = "not-playable"
		return out
	if int(b.bounces) > 0:
		out.reason = "bounced"
		return out
	var net_distance: float = float(court.netY) - float(p.y)
	var lateral: float = absf(float(b.x) - float(p.x)) / maxf(1.0, float(p.width))
	var comfortable: bool = net_distance < 130.0 + float(p.skill) * 20.0 \
		and float(b.z) >= 30.0 and float(b.z) <= 74.0 \
		and lateral < 0.60 + float(p.skill) * 0.12
	if comfortable:
		out.reason = "volley"
		return out
	# `bounce_bias` (State.aiBounceBias, 0..1) relaxes the three refusals that make
	# the back player volley (measured 2026-09-23, back player, level 1: the bounce
	# was refused for landing near the side glass ~50% of the time and near the net
	# ~46%). At 0 every threshold below is exactly the recorded one: lerpf(a, b, 0)
	# returns a bit for bit, so the golden matches do not move.
	var bias: float = clampf(float(p.get("bounce_bias", 0.0)), 0.0, 1.0)
	# Never for a player already in the volley zone: at the net, the air is right.
	if net_distance < 130.0:
		bias = 0.0
	var max_ground_time: float = lerpf(0.65, 1.10, bias)
	var side_margin: float = lerpf(76.0, 40.0, bias)
	var net_margin: float = lerpf(42.0, 22.0, bias)
	var gravity: float = float(balance.ballGravity)
	var impact: float = sqrt(maxf(0.0, float(b.vz) * float(b.vz) + 2.0 * gravity * maxf(0.0, float(b.z))))
	var ground_time: float = (float(b.vz) + impact) / gravity
	# A short descending lob is an attacking opportunity, not a reason to retreat.
	var landing_y: float = float(b.y) + float(b.vy) * ground_time
	if float(b.vz) < 0.0 and float(b.z) >= 58.0 and net_distance < 170.0 and lateral < 1.2 and landing_y > float(court.netY) - 126.0:
		out.reason = "overhead"
		return out
	# Short forecasts only; reject any possible wall contact before our target.
	if ground_time <= 0.0 or ground_time > max_ground_time:
		return out
	var slice_amount: float = clampf(float(b.backspin), 0.0, 1.2)
	var topspin: float = clampf(float(b.topspin), 0.0, 1.3)
	var restitution: float = (float(balance.groundRestitution) + float(balance.groundRestitutionBoost) * clampf(impact / 520.0, 0.0, 1.0)) * (1.0 - slice_amount * 0.28) + topspin * 0.12
	var rebound: float = maxf(float(balance.minimumBounceVz) * (1.0 - slice_amount * 0.26), impact * restitution)
	var after: float = minf(0.18, rebound / gravity)
	var target_height: float = rebound * after - 0.5 * gravity * after * after
	if target_height < 12.0 or target_height > float(balance.playableHitHeight):
		return out
	var x: float = float(b.x) + float(b.vx) * ground_time + (float(b.vx) + float(b.spin) * float(balance.groundSpinTransfer)) * float(balance.groundTangentialDamping) * after
	var y: float = float(b.y) + float(b.vy) * ground_time + float(b.vy) * float(balance.groundTangentialDamping) * (1.0 - slice_amount * 0.14) * (1.0 + topspin * 0.08) * after
	if x < float(court.left) + side_margin or x > float(court.right) - side_margin or y < float(court.top) + 84.0 or y > float(court.netY) - net_margin:
		return out
	# Budget both axes at the actual paddle speed, with reaction time and margin.
	var available: float = ground_time + after - float(p.reaction) - 0.10
	var travel_x: float = maxf(0.0, absf(x - float(p.x)) - float(p.width) * 0.45) / maxf(1.0, float(p.speed))
	var travel_y: float = maxf(0.0, absf(y - float(p.y)) - float(p.depth) * 0.45) / maxf(1.0, float(p.speed) * 0.56)
	if available > 0.0 and maxf(travel_x, travel_y) < available:
		out = {"wait": true, "reason": "reachable-bounce", "x": x, "y": y}
	return out
