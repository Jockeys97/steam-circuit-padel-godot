extends SceneTree
## ai_rally_metrics.gd — how the AI actually plays, measured, per level.
##
## Plays many scripted matches through the real simulation (`Sim.update_match`, no
## scene, no rendering) for every AI level and two human policies — every shot a
## drive (A) or every shot a slice (X) — and reports what a player feels:
##   - points won by the human, and mean rally length (peak `rallyHits` per point);
##   - AI contacts taken in the air, split by where the AI player stood (net / back);
##   - human shots the AI never returned;
##   - for back-player volleys, why `ai_contact.gd` refused to wait for the bounce;
##   - how the AI lost its points (the sim's own `pointMessage` reason).
## Every number is read from the state; nothing is written to it. The human side is
## `game/scripted_player.gd`: weak and deterministic — compare policies and levels
## against each other and against a later run, not against a human player.
##
## "In the air" is the sim's own bounce counter on the tick before the AI's strike,
## corrected for a bounce in the strike's own tick (see `bounced_now`);
## a second, independent detector (the ball reaching the floor on the AI's half and
## reversing) is reported alongside so the counter can be trusted (agreement ~95%).
##
## Run (from the repo root):
##   godot --headless --path godot/ --script res://game/tools/ai_rally_metrics.gd
## Environment:
##   SEEDS=16            matches per level and policy
##   AI_BOUNCE_BIAS=0.0  State.aiBounceBias for every match (0 = recorded behaviour)
##   AI_GLASS_PLAY=1     State.aiGlassPlay on for every match (default off)
##   BOUNCE_RESTITUTION, BOUNCE_MIN_VZ   try other ground-bounce values IN THIS PROCESS
##                       only (`groundRestitution`, `minimumBounceVz`): every part of the
##                       sim reads them from `Frozen.balance()` at use, so one write
##                       reaches the bounce, the AI planners and the forecast alike.
##   LEVELS=0,1,2,3      which `aiOpponents` entries to play
## Output: one readable block per level and policy, plus one `METRICS {json}` line.

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const Glass := preload("res://src/sim/ai_glass.gd")
const DT := 1.0 / 120.0
const MAX_TICKS := 40000
## Where "at the net" ends for an AI player, in sim px from the net line; the same
## 130 px `ai_contact.gd` uses for a comfortable volley at skill 0.
const NET_ZONE_PX := 130.0


func _initialize() -> void:
	call_deferred("_run")


func _env_int(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback


func _run() -> void:
	var seeds := _env_int("SEEDS", 16)
	var bias := float(OS.get_environment("AI_BOUNCE_BIAS")) if OS.get_environment("AI_BOUNCE_BIAS") != "" else 0.0
	var levels: Array = []
	for part in (OS.get_environment("LEVELS") if OS.get_environment("LEVELS") != "" else "0,1,2,3").split(","):
		levels.append(int(part))
	var balance: Dictionary = Frozen.balance()
	if OS.get_environment("BOUNCE_RESTITUTION") != "":
		balance["groundRestitution"] = float(OS.get_environment("BOUNCE_RESTITUTION"))
	if OS.get_environment("BOUNCE_MIN_VZ") != "":
		balance["minimumBounceVz"] = float(OS.get_environment("BOUNCE_MIN_VZ"))
	print("AI_RALLY_METRICS seeds=%d bias=%.2f glass=%s levels=%s restitution=%.2f min_bounce_vz=%.0f" % [
		seeds, bias, OS.get_environment("AI_GLASS_PLAY") == "1", levels,
		float(balance["groundRestitution"]), float(balance["minimumBounceVz"])])
	for level in levels:
		for policy in ["drive", "slice"]:
			var m := _measure(int(level), policy, seeds, bias)
			_report(int(level), policy, bias, m)
	quit(0)


func _measure(level: int, policy: String, seeds: int, bias: float) -> Dictionary:
	var m := {
		"points": 0, "human_points": 0, "rally_sum": 0,
		"ai_contacts": 0, "ai_air": 0, "net_contacts": 0, "net_air": 0, "back_contacts": 0, "back_air": 0,
		"detector_agree": 0, "human_shots": 0, "not_returned": 0,
		"back_refusals": {}, "ai_lost_by": {}, "live_ticks": 0, "ai_net_ticks": 0,
		"ai_z_sum": 0.0, "ai_pace_sum": 0.0, "ai_shots": 0,
		"apexes": [], "ai_after_back_glass": 0,
	}
	var net_y := float(Frozen.court()["netY"])
	var profile: Dictionary = Frozen.ai_opponents()[level]
	for seed in range(1, seeds + 1):
		var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], profile)
		state.rng_state = seed * 7919
		state.running = true
		state.setsToWin = 1
		state.aiBounceBias = bias
		state.aiGlassPlay = OS.get_environment("AI_GLASS_PLAY") == "1"
		var bot = ScriptedPlayer.new()
		var idle: Dictionary = Sim.empty_input()
		var last_side: Variant = null
		var prev_bounces := 0
		var prev_type := ""
		var prev_z := 0.0
		var prev_vz := 0.0
		var prev_pause := 0.0
		var landed := false
		var rally_peak := 0
		var awaiting_reply := false
		var last_plans := {}
		var prev_ball_y := 999.0
		var back_glass := false          # this ball bounced on the AI half and came off the back glass
		var prev_vy := 0.0
		for _t in MAX_TICKS:
			var plans := {}
			for key in ["opponent", "opponentMate"]:
				var plan: Dictionary = Sim.ai_contact_plan(state, state.paddle(key), state.ball)
				plans[key] = String(plan["reason"]) if String(plan["reason"]) != "emergency" else "emergency:" + _refusal(state, bias)
			var input: Dictionary = bot.decide(state)
			input["slice"] = policy == "slice"
			Sim.update_match(state, DT, input, idle)
			var ball = state.ball
			if float(state.pointPause) <= 0.0:
				rally_peak = maxi(rally_peak, int(state.rallyHits))
				if not bool(state.serving):
					for p in [state.opponent, state.opponentMate]:
						m.live_ticks += 1
						if float(p.y) > net_y - NET_ZONE_PX:
							m.ai_net_ticks += 1
			if (prev_vz < 0.0 and float(ball.vz) > 0.0 and float(ball.z) < 6.0 and float(ball.y) < net_y) \
					or (is_equal_approx(float(ball.landRing), 0.5) and float(ball.y) < net_y):
				landed = true
			prev_vz = float(ball.vz)
			# How high a human ball WOULD rise after its bounce on the AI half: the exact
			# forecast (`ai_glass.gd`, validated to 0.00 px against the real ball) taken as
			# it crosses the net, outside hit-stop. Measuring the real ball instead mixed in
			# bounces it should not have and gave a false "10 px" (2026-09-23).
			if prev_ball_y >= net_y and float(ball.y) < net_y and float(ball.vy) < 0.0 \
					and state.lastHitterSide == "player" and not bool(state.serving) \
					and float(state.hitStop) <= 0.0 and int(ball.bounces["ai"]) == 0:
				var rise := -1.0
				for s in Glass.forecast({"x": ball.x, "y": ball.y, "z": ball.z, "vx": ball.vx, "vy": ball.vy, "vz": ball.vz,
						"spin": ball.spin, "backspin": ball.backspin, "topspin": ball.topspin, "r": ball.r},
						Frozen.court(), Frozen.balance(), float(state.arena["wallBounce"]), 3.0):
					if bool(s.bounced):
						rise = maxf(rise, float(s.z))
				if rise >= 0.0:
					m.apexes.append(rise)
			prev_ball_y = float(ball.y)
			if landed and prev_vy < 0.0 and float(ball.vy) > 0.0 and float(ball.y) < float(Frozen.court()["top"]) + 40.0:
				back_glass = true
			prev_vy = float(ball.vy)
			var side: Variant = state.lastHitterSide
			if side != last_side and side == "ai" and prev_type != "serve":
				var striker = _nearest_ai(state)
				var key := "opponent" if striker == state.opponent else "opponentMate"
				# A bounce and the AI's strike can land in the SAME tick (the ball step
				# bounces it, then the AI hits it): the counter on the previous tick still
				# says 0. `handle_ground_bounce` sets `landRing = 0.5` and it only decays
				# from the next tick, so 0.5 at the end of this tick means "bounced now".
				var bounced_now := is_equal_approx(float(ball.landRing), 0.5)
				var in_air := prev_bounces == 0 and not bounced_now
				var at_net := float(striker.y) > net_y - NET_ZONE_PX
				m.ai_contacts += 1
				if back_glass:
					m.ai_after_back_glass += 1
				back_glass = false
				# The shot the AI just played: contact height (previous tick's ball) and the
				# pace it sent the ball away with (horizontal speed right after the strike).
				m.ai_z_sum += prev_z
				m.ai_pace_sum += sqrt(float(ball.vx) * float(ball.vx) + float(ball.vy) * float(ball.vy))
				m.ai_shots += 1
				if in_air: m.ai_air += 1
				if in_air != landed: m.detector_agree += 1
				if at_net:
					m.net_contacts += 1
					if in_air: m.net_air += 1
				else:
					m.back_contacts += 1
					if in_air:
						m.back_air += 1
						var why := String(last_plans.get(key, "?"))
						m.back_refusals[why] = int(m.back_refusals.get(why, 0)) + 1
				awaiting_reply = false
			if side != last_side and side == "player":
				m.human_shots += 1
				awaiting_reply = true
				landed = false
				back_glass = false
			last_side = side
			if float(state.pointPause) > 0.0 and prev_pause <= 0.0:
				m.points += 1
				m.rally_sum += rally_peak
				rally_peak = 0
				var message := String(state.pointMessage)
				if message.begins_with("pointYou"):
					m.human_points += 1
					if awaiting_reply: m.not_returned += 1
					var reason := message.get_slice(":", 1)
					m.ai_lost_by[reason] = int(m.ai_lost_by.get(reason, 0)) + 1
				awaiting_reply = false
				last_side = null
				back_glass = false
			prev_pause = float(state.pointPause)
			prev_bounces = int(ball.bounces["ai"])
			prev_z = float(ball.z)
			prev_type = String(ball.shotType)
			last_plans = plans
			if state.result != null:
				break
	return m


func _nearest_ai(state):
	var b = state.ball
	var a = state.opponent
	var c = state.opponentMate
	var da := absf(float(a.x) - float(b.x)) + absf(float(a.y) - float(b.y))
	var dc := absf(float(c.x) - float(b.x)) + absf(float(c.y) - float(b.y))
	return a if da <= dc else c


## Which of `ai_contact.gd`'s gates refused the bounce, labelled. Mirrors the planner
## at the same bias; a drift between the two shows up as "unexplained".
func _refusal(state, bias: float) -> String:
	var b = state.ball
	var court: Dictionary = Frozen.court()
	var balance: Dictionary = Frozen.balance()
	var g := float(balance["ballGravity"])
	var impact := sqrt(maxf(0.0, float(b.vz) * float(b.vz) + 2.0 * g * maxf(0.0, float(b.z))))
	var ground := (float(b.vz) + impact) / g
	if ground <= 0.0:
		return "not-descending"
	if ground > lerpf(0.65, 1.10, bias):
		return "bounce-too-far-ahead"
	var slice_amount := clampf(float(b.backspin), 0.0, 1.2)
	var topspin := clampf(float(b.topspin), 0.0, 1.3)
	var restitution := (float(balance["groundRestitution"]) + float(balance["groundRestitutionBoost"]) * clampf(impact / 520.0, 0.0, 1.0)) * (1.0 - slice_amount * 0.28) + topspin * 0.12
	var rebound := maxf(float(balance["minimumBounceVz"]) * (1.0 - slice_amount * 0.26), impact * restitution)
	var after := minf(0.18, rebound / g)
	var height := rebound * after - 0.5 * g * after * after
	if height < 12.0:
		return "rebound-too-low"
	if height > float(balance["playableHitHeight"]):
		return "rebound-too-high"
	var x := float(b.x) + float(b.vx) * ground
	var y := float(b.y) + float(b.vy) * ground
	var side := lerpf(76.0, 40.0, bias)
	if x < float(court["left"]) + side or x > float(court["right"]) - side:
		return "bounce-near-side-glass"
	if y < float(court["top"]) + 84.0:
		return "bounce-near-back-glass"
	if y > float(court["netY"]) - lerpf(42.0, 22.0, bias):
		return "bounce-near-net"
	return "no-time"


func _pct(a: int, b: int) -> float:
	return 100.0 * float(a) / maxf(1.0, float(b))


func _report(level: int, policy: String, bias: float, m: Dictionary) -> void:
	var name := String(Frozen.ai_opponents()[level].get("id", str(level)))
	print("== level %d %-10s policy=%-5s bias=%.2f" % [level, name, policy, bias])
	print("   points=%d  human won %.0f%%  mean rally %.1f hits  human shots not returned %.1f%%" % [
		m.points, _pct(m.human_points, m.points), float(m.rally_sum) / maxf(1.0, float(m.points)), _pct(m.not_returned, m.human_shots)])
	print("   AI in the air %.0f%% of %d  [net %.0f%% of %d | back %.0f%% of %d]  detector agreement %.0f%%" % [
		_pct(m.ai_air, m.ai_contacts), m.ai_contacts, _pct(m.net_air, m.net_contacts), m.net_contacts,
		_pct(m.back_air, m.back_contacts), m.back_contacts, _pct(m.detector_agree, m.ai_contacts)])
	print("   AI players at the net %.0f%% of live time   AI contact height %.0f px   AI shot pace %.0f px/s" % [
		_pct(m.ai_net_ticks, m.live_ticks), m.ai_z_sum / maxf(1.0, float(m.ai_shots)), m.ai_pace_sum / maxf(1.0, float(m.ai_shots))])
	var ap: Array = m.apexes.duplicate()
	ap.sort()
	var above := ap.filter(func(a): return a >= 38.0).size()
	if not ap.is_empty():
		print("   a human ball would rise after its bounce: median %.0f px  p90 %.0f px   above the net (38 px) %.0f%%   AI plays after the back glass %.1f%% of its contacts" % [
			ap[ap.size() / 2], ap[int(ap.size() * 0.9)], _pct(above, ap.size()), _pct(m.ai_after_back_glass, m.ai_contacts)])
	print("   back volleys, planner's reason: %s" % [_top(m.back_refusals)])
	print("   AI lost its points by: %s" % [_top(m.ai_lost_by)])
	print("METRICS " + JSON.stringify({
		"level": level, "ai": name, "policy": policy, "bias": bias, "points": m.points,
		"human_won_pct": snappedf(_pct(m.human_points, m.points), 0.1),
		"mean_rally": snappedf(float(m.rally_sum) / maxf(1.0, float(m.points)), 0.01),
		"not_returned_pct": snappedf(_pct(m.not_returned, m.human_shots), 0.1),
		"ai_air_pct": snappedf(_pct(m.ai_air, m.ai_contacts), 0.1),
		"net_air_pct": snappedf(_pct(m.net_air, m.net_contacts), 0.1),
		"back_air_pct": snappedf(_pct(m.back_air, m.back_contacts), 0.1),
		"ai_net_time_pct": snappedf(_pct(m.ai_net_ticks, m.live_ticks), 0.1),
		"ai_contact_z": snappedf(m.ai_z_sum / maxf(1.0, float(m.ai_shots)), 0.1),
		"ai_pace": snappedf(m.ai_pace_sum / maxf(1.0, float(m.ai_shots)), 0.1),
		"apex_median": ap[ap.size() / 2] if not ap.is_empty() else -1,
		"apex_p90": ap[int(ap.size() * 0.9)] if not ap.is_empty() else -1,
		"above_net_pct": snappedf(_pct(above, ap.size()), 0.1),
		"ai_after_back_glass_pct": snappedf(_pct(m.ai_after_back_glass, m.ai_contacts), 0.1),
		"restitution": float(Frozen.balance()["groundRestitution"]),
		"min_bounce_vz": float(Frozen.balance()["minimumBounceVz"]),
		"back_contacts": m.back_contacts, "net_contacts": m.net_contacts,
		"back_refusals": m.back_refusals, "ai_lost_by": m.ai_lost_by,
	}))


func _top(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	var parts: Array = []
	for k in keys.slice(0, 5):
		parts.append("%s %d" % [k, int(counts[k])])
	return ", ".join(parts) if not parts.is_empty() else "-"
