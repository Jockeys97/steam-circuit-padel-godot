## wall_rules_audit.gd — the port of `scripts/wall-rules-audit.mjs` (padel rule 13).
##
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/wall_rules_audit.gd
##
## Same scenario values, same seed (`state.rngState = 4242`), same `1/240` dt and
## the same 1500-frame budget as the reference. The reference is the executable
## specification; this file reproduces its four scenarios and its assertions one
## for one, driving `godot/src/sim/sim.gd` only.
##
## The four promises (`scripts/wall-rules-audit.mjs:98-155`):
##   1. live ball into the OPPONENT glass with zero bounces on that side -> point
##      to the side owning the wall (`:100-113`, point to "ai", within 3 frames);
##   2. the SAME contact on the OWN glass before the net -> legal, ball stays live
##      (`:121-133`, no point at contact);
##   3. after a legal bounce the glass is normal play (`:137-142`);
##   4. a serve onto the opponent glass is a serve fault, never a point for the
##      server (`:150-155`).
##
## Extra check the JavaScript cannot make (ticket `sim-rules-audits.md` §Tests):
## the defender choice behind rule 13 is a `.sort(...)[0]` in JavaScript, where
## V8's sort is stable, and an explicit `<` in the port. A deliberate distance tie
## is asserted here so the two agree by construction, not by luck.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

## `scripts/wall-rules-audit.mjs:64` — the contact window the reference scans.
const FRAMES := 1500
## `scripts/wall-rules-audit.mjs:71`, `:75`, `:179` — the reference dt for this audit.
const DT := 1.0 / 240.0
## `scripts/wall-rules-audit.mjs:50`.
const SEED := 4242


func _initialize() -> void:
	var audit := AuditBase.new("wall_rules")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	_opposing_glass(audit)
	_own_glass(audit)
	_glass_after_bounce(audit)
	_serve_onto_glass(audit)
	_defender_tie(audit)


# ---------------------------------------------------------------------------
# 1. `scripts/wall-rules-audit.mjs:98-113` — the opponent's glass on the fly is a
#    fault charged to the striker.
# ---------------------------------------------------------------------------

static func _opposing_glass(audit: AuditBase) -> void:
	var cases := [
		["lateral", {"x": 760.0, "y": 190.0, "z": 74.0, "vx": 900.0, "vy": -30.0, "vz": 260.0, "crossedNet": true}],
		["baseline", {"x": 480.0, "y": 180.0, "z": 74.0, "vx": 0.0, "vy": -760.0, "vz": 260.0, "crossedNet": true}],
	]
	for entry in cases:
		var name: String = entry[0]
		var outcome := scenario(entry[1], {"lastHitterSide": "player"})
		var at_glass: Variant = outcome["alVetro"]
		audit.check_true(at_glass != null, "wall_rules/opposing_glass_%s/reaches_glass" % name)
		if at_glass == null:
			# The reference's own `assert.ok(esito.alVetro, "Scenario mal costruito")`
			# fails here; the four checks below cannot be evaluated without a
			# contact, and the audit is already red. Nothing is dropped.
			audit.note("opposing_glass_%s: scenario mal costruito, la palla non arriva al vetro avversario" % name)
			continue
		audit.check_eq(String(at_glass["lato"]), "ai", "wall_rules/opposing_glass_%s/contact_in_ai_court" % name)
		audit.check_eq(int(Dictionary(at_glass["rimbalzi"])["ai"]), 0, "wall_rules/opposing_glass_%s/no_bounce_before_glass" % name)
		audit.check_eq(str(outcome["vincitore"]), "ai", "wall_rules/opposing_glass_%s/point_lost_by_striker" % name)
		var distance: Variant = outcome["distanza"]
		audit.check_true(
			distance != null and int(distance) <= 3,
			"wall_rules/opposing_glass_%s/fault_at_contact" % name,
		)


# ---------------------------------------------------------------------------
# 2. `scripts/wall-rules-audit.mjs:115-133` — your own walls are explicitly legal
#    before the net. The reference does not ask who wins the point; it asks that
#    NOTHING is awarded at the contact, because the ball is still live.
# ---------------------------------------------------------------------------

static func _own_glass(audit: AuditBase) -> void:
	var cases := [
		["lateral", {"x": 760.0, "y": 470.0, "z": 74.0, "vx": 900.0, "vy": -30.0, "vz": 260.0, "crossedNet": false}],
		["baseline", {"x": 480.0, "y": 470.0, "z": 74.0, "vx": 0.0, "vy": 760.0, "vz": 260.0, "crossedNet": false}],
	]
	for entry in cases:
		var name: String = entry[0]
		var outcome := scenario(entry[1], {"lastHitterSide": "player"})
		var at_glass: Variant = outcome["alVetro"]
		audit.check_true(at_glass != null, "wall_rules/own_glass_%s/reaches_glass" % name)
		if at_glass == null:
			audit.note("own_glass_%s: scenario mal costruito, la palla non arriva al proprio vetro" % name)
			continue
		audit.check_eq(String(at_glass["lato"]), "player", "wall_rules/own_glass_%s/contact_in_own_court" % name)
		audit.check_eq(int(Dictionary(at_glass["rimbalzi"])["player"]), 0, "wall_rules/own_glass_%s/no_bounce_before_glass" % name)
		var distance: Variant = outcome["distanza"]
		audit.check_true(
			distance == null or int(distance) > 30,
			"wall_rules/own_glass_%s/ball_stays_live" % name,
		)


# ---------------------------------------------------------------------------
# 3. `scripts/wall-rules-audit.mjs:135-142` — bounced in the opponent court, then
#    onto the glass: normal play, and the point goes to the striker.
# ---------------------------------------------------------------------------

static func _glass_after_bounce(audit: AuditBase) -> void:
	var outcome := scenario(
		{
			"x": 480.0, "y": 150.0, "z": 26.0, "vx": 0.0, "vy": -260.0, "vz": -30.0,
			"crossedNet": true, "bounces": {"player": 0, "ai": 1},
		},
		{"lastHitterSide": "player"},
	)
	audit.check_eq(str(outcome["vincitore"]), "player", "wall_rules/glass_after_bounce_is_normal_play")


# ---------------------------------------------------------------------------
# 4. `scripts/wall-rules-audit.mjs:144-155` — on the serve the rule is stricter:
#    the ball may not touch an opposing wall before the second bounce, and it is
#    always a serve fault, never a point for the server.
# ---------------------------------------------------------------------------

static func _serve_onto_glass(audit: AuditBase) -> void:
	var outcome := scenario(
		{"x": 760.0, "y": 190.0, "z": 74.0, "vx": 900.0, "vy": -30.0, "vz": 260.0, "crossedNet": true, "serveInFlight": true},
		{"lastHitterSide": "player", "serveSide": "player", "serveAttempts": 0},
	)
	audit.check_true(str(outcome["vincitore"]) != "player", "wall_rules/serve_onto_glass_is_not_a_winner")


# ---------------------------------------------------------------------------
# Extra check (see the file header): a deliberate distance tie must resolve to the
# first defender, which is what `.sort((a, b) => a.distance - b.distance)[0]`
# yields on V8's stable sort (`js/game.js:2236`, `:2332`, `:2597`).
# ---------------------------------------------------------------------------

static func _defender_tie(audit: AuditBase) -> void:
	var tie_state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	tie_state.ball.x = 480.0
	tie_state.ball.y = 300.0
	var left: Dictionary = Frozen.athletes()[0]
	var right: Dictionary = Frozen.athletes()[1]
	var first := Sim.Ent.make_paddle(200.0, 100.0, false, {"stats": left["stats"]})
	var second := Sim.Ent.make_paddle(760.0, 100.0, false, {"stats": right["stats"]})
	var picked: Dictionary = Sim.nearest_defender([first, second], tie_state.ball)
	audit.check_eq(picked["paddle"], first, "wall_rules/defender_tie_prefers_first")
	var reversed: Dictionary = Sim.nearest_defender([second, first], tie_state.ball)
	audit.check_eq(reversed["paddle"], second, "wall_rules/defender_tie_is_order_independent")


# ---------------------------------------------------------------------------
# `scenario` (`scripts/wall-rules-audit.mjs:48-96`), verbatim: same construction,
# same corner rackets, same per-tick probe, same point detection.
# ---------------------------------------------------------------------------

static func scenario(palla: Dictionary, extra: Dictionary) -> Dictionary:
	var court: Dictionary = Frozen.court()
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	Support.inject_seed(state, SEED)
	state.running = true
	state.serving = false
	state.pointPause = 0.0
	state.rallyHits = 3
	Support.clear_service_reception(state)
	if extra.has("lastHitterSide"):
		state.lastHitterSide = String(extra["lastHitterSide"])
	if extra.has("serveSide"):
		state.serveSide = String(extra["serveSide"])
	if extra.has("serveAttempts"):
		state.serveAttempts = int(extra["serveAttempts"])

	# Rackets in opposite corners: none of them may intercept and skew the verdict.
	state.player.x = 100.0
	state.player.y = 550.0
	state.player.controlled = true
	state.player.isPlayer = true
	state.player.hitCooldown = 0.0
	state.playerMate.x = 860.0
	state.playerMate.y = 550.0
	state.playerMate.hitCooldown = 0.0
	state.opponent.x = 100.0
	state.opponent.y = 70.0
	state.opponent.hitCooldown = 0.0
	state.opponentMate.x = 860.0
	state.opponentMate.y = 70.0
	state.opponentMate.hitCooldown = 0.0

	var ball := state.ball
	ball.bounces = {"player": 0, "ai": 0}
	ball.serveInFlight = false
	ball.netFaultOwner = null
	ball.x = float(palla["x"])
	ball.y = float(palla["y"])
	ball.z = float(palla["z"])
	ball.vx = float(palla["vx"])
	ball.vy = float(palla["vy"])
	ball.vz = float(palla["vz"])
	ball.crossedNet = bool(palla["crossedNet"])

	var at_glass: Variant = null
	for frame in range(0, FRAMES):
		state.aiReactionDelay = 99.0
		var before_y: float = ball.y
		var before_bounces := {"player": int(ball.bounces["player"]), "ai": int(ball.bounces["ai"])}
		Sim.update_match(state, DT, Support.vuoto())
		var points_now := Support.points_awarded(state)
		# The glass is crossed *during* the update: the reference probes the ball
		# AFTER the tick (`scripts/wall-rules-audit.mjs:76-78`) and keeps the
		# PRE-tick side and bounce counts of the contact frame (`:66-70`, `:80`).
		# The glass is reached mid-update, so only the post-tick position sees it.
		var ticked := state.ball
		var touches: bool = (
			ticked.x - ticked.r <= float(court["left"]) + 1.0
			or ticked.x + ticked.r >= float(court["right"]) - 1.0
			or ticked.y - ticked.r <= float(court["top"]) + 1.0
			or ticked.y + ticked.r >= float(court["bottom"]) - 1.0
		)
		if touches and at_glass == null:
			at_glass = {
				"lato": "ai" if before_y < float(court["netY"]) else "player",
				"rimbalzi": before_bounces,
				"frame": frame,
			}
		if points_now > 0:
			return {
				"vincitore": "player" if int(state.stats["pointsWon"]["player"]) > 0 else "ai",
				"alVetro": at_glass,
				"distanza": (frame - int(Dictionary(at_glass)["frame"])) if at_glass != null else null,
			}
	return {"vincitore": null, "alVetro": at_glass, "distanza": null}
