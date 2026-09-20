extends SceneTree
const Policy = preload("res://src/sim/ai_contact.gd")
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
func _initialize() -> void:
	var failures := 0
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	for row in cases:
		var result: Dictionary = Policy.plan(row.p, row.b, Frozen.court(), Frozen.balance())
		if result.wait != row.expected.wait or result.reason != row.expected.reason or absf(result.x - row.expected.x) > 0.00001 or absf(result.y - row.expected.y) > 0.00001:
			failures += 1
			printerr("POLICY mismatch ", row.name, " ", result)
	# Exercise the actual caller: legal service/bounced contact and reaction gate.
	for kind in ["service", "bounced", "glass", "reaction"]:
		var s = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
		s.serving = false
		s.aiServiceReceiverKey = null
		s.aiReceiverLocked = true
		s.aiPrimaryKey = "opponent"
		s.aiReactionDelay = 0.5 if kind == "reaction" else 0.0
		s.opponent.x = 480.0
		s.opponent.y = 210.0
		s.ball.x = 480.0
		s.ball.y = 210.0
		s.ball.z = 40.0
		s.ball.vy = 80.0 if kind == "glass" else -80.0
		s.ball.vz = -40.0
		s.ball.serveInFlight = kind == "service"
		s.ball.bounces.ai = 1 if kind in ["bounced", "glass"] else 0
		if kind == "glass": s.ball.postGlassSide = "ai"
		s.lastHitterSide = "player"
		var before: int = s.rallyHits
		Sim.update_doubles_ai(s, 1.0 / 120.0)
		var should_hit: bool = kind in ["bounced", "glass"]
		if (s.rallyHits > before) != should_hit:
			failures += 1
			printerr("INTEGRATION mismatch ", kind)
	print("AI_POLICY_PASS ", cases.size(), " parity cases + 4 integration scenarios" if failures == 0 else " FAIL " + str(failures))
	quit(0 if failures == 0 else 1)
