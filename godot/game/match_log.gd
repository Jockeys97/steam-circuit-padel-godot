extends RefCounted
## match_log.gd — what the AI actually does in a REAL match, recorded for the owner's
## play tests.
##
## Why: the scripted player (`game/scripted_player.gd`) said the glass-aware AI was as
## strong and as often at the net as before; the owner, playing it at Leggenda, found
## it much weaker and almost never at the net (2026-09-23). A scripted opponent does
## not play like a person, so the only honest measure of an AI change is the owner's
## own matches. This records them.
##
## Off unless the game is launched with PADEL_MATCH_LOG=1. Read-only on the state:
## it never writes to the simulation, so a logged match plays exactly like any other.
## The file is rewritten at the end of every point, so quitting mid-match loses at
## most the point in play. Output: tools/match-log/out/ (git-ignored, `tools/*/out/`).
##
## One JSON per match:
##   header    level, athlete, arena, mode, seed, aiGlassPlay
##   contacts  every strike: side, striker, where it stood, contact height, in the air
##             or after the bounce, after the back glass or not, shot in and out, pace,
##             and for the AI the planner's reason on the tick before
##   points    who won, the simulation's reason, rally length, score after
##   samples   every SAMPLE_EVERY ticks of live play: the four players and the ball
##   summary   the numbers the owner's two complaints are about, precomputed

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Glass := preload("res://src/sim/ai_glass.gd")

const SAMPLE_EVERY := 15          # ticks: 8 samples a second
const NET_ZONE_PX := 130.0        # "at the net", as ai_rally_metrics.gd and ai_contact.gd

var path := ""
var _header := {}
var _contacts: Array = []
var _points: Array = []
var _samples: Array = []
var _tick := 0
var _last_side: Variant = null
var _prev := {}
var _rally_peak := 0
var _back_glass := {"ai": false, "player": false}
var _done := false


static func enabled() -> bool:
	return OS.get_environment("PADEL_MATCH_LOG") == "1"


func start(state, info: Dictionary) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../tools/match-log/out").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var level_id := String(state.ai.get("id", "?")) if state.ai is Dictionary else "?"
	path = dir.path_join("partita-%s-%s-%s.json" % [stamp, level_id, "vetri" if bool(state.aiGlassPlay) else "base"])
	_header = info.duplicate()
	_header["level_id"] = level_id
	_header["aiGlassPlay"] = bool(state.aiGlassPlay)
	_header["started"] = stamp
	_header["court"] = Frozen.court()
	_prev = _snapshot(state)
	print("MATCH_LOG recording to %s" % path)


## One call per simulation tick, after the tick (`match_controller.gd::tick_fixed`).
func observe(state) -> void:
	if _done:
		return
	_tick += 1
	var ball = state.ball
	var live: bool = not bool(state.serving) and float(state.pointPause) <= 0.0 and state.result == null
	var net_y := float(Frozen.court()["netY"])
	var top := float(Frozen.court()["top"])
	var bottom := float(Frozen.court()["bottom"])
	if live:
		_rally_peak = maxi(_rally_peak, int(state.rallyHits))
		# A ball that bounced on a half and came off that half's back glass.
		var prev_vy := float(_prev.get("vy", 0.0))
		if int(ball.bounces["ai"]) > 0 and prev_vy < 0.0 and float(ball.vy) > 0.0 and float(ball.y) < top + 40.0:
			_back_glass["ai"] = true
		if int(ball.bounces["player"]) > 0 and prev_vy > 0.0 and float(ball.vy) < 0.0 and float(ball.y) > bottom - 40.0:
			_back_glass["player"] = true
		if _tick % SAMPLE_EVERY == 0:
			_samples.append(_positions(state))

	var side: Variant = state.lastHitterSide
	# Strikes only in live play: during the pause between points `lastHitterSide` still
	# names the last hitter, and counting it there logged a "strike" every tick.
	if side != _last_side and side != null and not bool(state.serving) and float(state.pointPause) <= 0.0:
		_contacts.append(_contact(state, String(side)))
		_back_glass = {"ai": false, "player": false}
	_last_side = side if float(state.pointPause) <= 0.0 else null

	if float(state.pointPause) > 0.0 and float(_prev.get("pause", 0.0)) <= 0.0:
		var message := String(state.pointMessage)
		_points.append({
			"tick": _tick,
			"winner": "player" if message.begins_with("pointYou") else ("ai" if message.begins_with("pointOpp") else "none"),
			"reason": message.get_slice(":", 1),
			"rally": _rally_peak,
			"games": state.games.duplicate(), "sets": state.sets.duplicate(),
		})
		_rally_peak = 0
		write()
	if state.result != null and not _done:
		_header["result"] = state.result
		write()
		_done = true
	_prev = _snapshot(state)
	# The planner's reason for each AI player, kept for the NEXT tick's strike.
	if live and int(ball.bounces["ai"]) >= 0:
		for key in ["opponent", "opponentMate"]:
			_prev["plan_" + key] = String(Sim.ai_contact_plan(state, state.paddle(key), ball)["reason"])


func _snapshot(state) -> Dictionary:
	var b = state.ball
	return {
		"z": float(b.z), "vy": float(b.vy), "shot": String(b.shotType),
		"bounces_ai": int(b.bounces["ai"]), "bounces_player": int(b.bounces["player"]),
		"pause": float(state.pointPause),
		# The charge being built: the sim keeps it on the state for the active player
		# (`shotCharge`) and on the paddle; the larger of the two, before the release.
		"charge": maxf(float(state.shotCharge), float(state.active_player().charge) if state.active_player() != null else 0.0),
		"events": state.events.duplicate(),
	}


func _contact(state, side: String) -> Dictionary:
	var b = state.ball
	var net_y := float(Frozen.court()["netY"])
	var striker_key: String
	if side == "ai":
		var a = state.opponent
		var c = state.opponentMate
		var da := absf(float(a.x) - float(b.x)) + absf(float(a.y) - float(b.y))
		var dc := absf(float(c.x) - float(b.x)) + absf(float(c.y) - float(b.y))
		striker_key = "opponent" if da <= dc else "opponentMate"
	else:
		striker_key = String(state.activePlayerKey)
	var striker = state.paddle(striker_key)
	# In the air unless the ball bounced on the striker's half before the strike —
	# including a bounce in the strike's own tick (`landRing` is set to 0.5 then).
	var bounced_before := int(_prev.get("bounces_" + side, 0)) > 0 or is_equal_approx(float(b.landRing), 0.5)
	var from_net := absf(float(striker.y) - net_y)
	return {
		"tick": _tick,
		"side": side,
		"striker": striker_key,
		"x": snappedf(float(striker.x), 0.1), "y": snappedf(float(striker.y), 0.1),
		"from_net_px": snappedf(from_net, 0.1),
		"zone": "net" if from_net < NET_ZONE_PX else "back",
		"contact_z": snappedf(float(_prev.get("z", 0.0)), 0.1),
		"in_air": not bounced_before,
		"after_back_glass": bool(_back_glass[side]),
		"shot_in": String(_prev.get("shot", "")),
		"shot_out": String(b.shotType),
		"pace_out": snappedf(sqrt(float(b.vx) * float(b.vx) + float(b.vy) * float(b.vy)), 0.1),
		"plan": String(_prev.get("plan_" + striker_key, "")) if side == "ai" else "",
		"you": _your_shot(state) if side == "player" else {},
	}


## Your shot as the simulation judged it: the timing grade shown on screen, quality,
## mode, the charge you released, and the error the error model rolled (if any).
## For a lob, where it would come down and whether the AI net player can reach it.
func _your_shot(state) -> Dictionary:
	var fb: Variant = state.shotFeedback
	var out := {"charge": snappedf(float(_prev.get("charge", 0.0)), 0.01)}
	if fb is Dictionary:
		out["grade"] = String(fb.get("grade", ""))
		out["quality"] = snappedf(float(fb.get("quality", 0.0)), 0.001)
		out["mode"] = String(fb.get("mode", "")).get_slice(":", 1)
	# The events this strike added. `add_event` pushes to the front and drops from the
	# back (cap 5), so now = [new..., previous[0..5-new-1]]: the new ones are the
	# shortest prefix after which the rest matches the start of the previous list.
	var before: Array = _prev.get("events", [])
	var now: Array = state.events
	var fresh: Array = now.duplicate()
	for i in range(0, now.size() + 1):
		var rest: Array = now.slice(i)
		if rest == before.slice(0, rest.size()):
			fresh = now.slice(0, i)
			break
	out["events"] = fresh.filter(func(e): return String(e).begins_with("evShot") or String(e).begins_with("evLob") or String(e).begins_with("evDefensive") or String(e).begins_with("evGlobo"))
	var b = state.ball
	if String(b.shotType) in ["lob", "defensive-lob", "globo"]:
		var f: Array = Glass.forecast({"x": b.x, "y": b.y, "z": b.z, "vx": b.vx, "vy": b.vy, "vz": b.vz,
			"spin": b.spin, "backspin": b.backspin, "topspin": b.topspin, "r": b.r},
			Frozen.court(), Frozen.balance(), float(state.arena["wallBounce"]), 3.5)
		var net_y := float(Frozen.court()["netY"])
		var apex := 0.0
		var landing_from_net := -1.0
		for s in f:
			apex = maxf(apex, float(s.z))
			if bool(s.bounced) and landing_from_net < 0.0:
				landing_from_net = net_y - float(s.y)
		# Height of the lob as it passes the depth of the AI player nearest the net.
		var net_player = state.opponent if float(state.opponent.y) > float(state.opponentMate.y) else state.opponentMate
		var over_net_player := -1.0
		for s in f:
			if float(s.y) <= float(net_player.y):
				over_net_player = float(s.z)
				break
		out["lob"] = {
			"apex": snappedf(apex, 0.1),
			"lands_from_net_px": snappedf(landing_from_net, 0.1),      # -1: would not bounce in (glass on the full / out)
			"half_depth_px": net_y - float(Frozen.court()["top"]),
			"height_over_net_player": snappedf(over_net_player, 0.1),
			"net_player_from_net_px": snappedf(net_y - float(net_player.y), 0.1),
			"reachable_overhead_below": float(Frozen.balance()["playableHitHeight"]),
		}
	return out


func _positions(state) -> Dictionary:
	var out := {"tick": _tick, "ball": [snappedf(float(state.ball.x), 0.1), snappedf(float(state.ball.y), 0.1), snappedf(float(state.ball.z), 0.1)]}
	for key in ["player", "playerMate", "opponent", "opponentMate"]:
		var p = state.paddle(key)
		out[key] = [snappedf(float(p.x), 0.1), snappedf(float(p.y), 0.1)]
	return out


func _summary() -> Dictionary:
	var net_y := float(Frozen.court()["netY"])
	var ai := _contacts.filter(func(c): return c.side == "ai")
	var ai_back := ai.filter(func(c): return c.zone == "back")
	var ai_net := ai.filter(func(c): return c.zone == "net")
	var at_net := 0
	for s in _samples:
		for key in ["opponent", "opponentMate"]:
			if net_y - float(s[key][1]) < NET_ZONE_PX:
				at_net += 1
	var lost_by := {}
	var won_by := {}
	for p in _points:
		if p.winner == "player":
			lost_by[p.reason] = int(lost_by.get(p.reason, 0)) + 1
		elif p.winner == "ai":
			won_by[p.reason] = int(won_by.get(p.reason, 0)) + 1
	var pace := 0.0
	for c in ai:
		pace += float(c.pace_out)
	var pct := func(a: int, n: int) -> float: return snappedf(100.0 * a / maxf(1.0, n), 0.1)
	return {
		"points": _points.size(),
		"points_won_by_you": _points.filter(func(p): return p.winner == "player").size(),
		"ai_contacts": ai.size(),
		"ai_back_contacts": ai_back.size(),
		"ai_back_in_air_pct": pct.call(ai_back.filter(func(c): return c.in_air).size(), ai_back.size()),
		"ai_net_contacts": ai_net.size(),
		"ai_after_back_glass": ai.filter(func(c): return c.after_back_glass).size(),
		"ai_time_at_net_pct": pct.call(at_net, _samples.size() * 2),
		"ai_mean_pace": snappedf(pace / maxf(1.0, ai.size()), 0.1),
		"ai_lost_points_by": lost_by,
		"ai_won_points_by": won_by,
	}


func write() -> void:
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("MATCH_LOG cannot write %s" % path)
		return
	f.store_string(JSON.stringify({
		"header": _header, "summary": _summary(),
		"points": _points, "contacts": _contacts, "samples": _samples,
	}))
	f.close()
