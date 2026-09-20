extends SceneTree
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
func _initialize() -> void:
	var failures := 0
	for mode in ["solo", "coop"]:
		for serving in [true, false]:
			var s = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1], 0, {"humanMode": mode})
			s.serving = serving
			s.serviceReceiverKey = null
			s.playerMate.x = float(Frozen.court()["left"]) + 80.0
			s.playerMate.y = float(Frozen.court()["netY"]) + 80.0
			var before := Vector2(s.playerMate.x, s.playerMate.y)
			for i in 60:
				Sim.update_doubles_ai(s, 1.0 / 60.0)
			var distance := before.distance_to(Vector2(s.playerMate.x, s.playerMate.y))
			print("MATE mode=", mode, " serving=", serving, " distance=", distance, " motion=", s.playerMate.motion)
			if (mode == "solo" and not serving and distance <= 1.0) or ((mode == "coop" or serving) and distance > 0.001):
				failures += 1
	print("MATE_MOVEMENT_PASS 4/4" if failures == 0 else "MATE_MOVEMENT_FAIL")
	quit(0 if failures == 0 else 1)
