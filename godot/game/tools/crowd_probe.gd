extends SceneTree
## Proves the crowd REACTS: that a point landing raises the cheer and a long rally
## raises the murmur, driven by the same state object the match feeds it.
##
## WHY THIS AND NOT THE EYE. "The crowd cheers" is a claim about a number changing
## on a specific edge, and a screenshot of bobbing sprites cannot show which edge
## caused it. This drives `observe()` with a hand-built state, so the trigger is the
## thing under test rather than a rally that may or may not happen.
##
##   godot --headless --path godot/ --script res://game/tools/crowd_probe.gd

const Crowd := preload("res://game/arenas/crowd.gd")


## The fields of the simulation state this module actually reads. Keeping the fake
## this small is the point: if the crowd ever reads more, this stops compiling and
## the coupling becomes visible instead of silent.
class FakeState:
	var stats := {"pointsWon": {"player": 0, "ai": 0}}
	var rallyHits := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var crowd := Crowd.build(root)
	await process_frame

	var state := FakeState.new()
	var failures := 0

	# 1. The first observation must only prime the baseline. A crowd that cheered
	#    the score it walked in on would erupt on every arena change.
	state.stats["pointsWon"]["player"] = 3
	state.stats["pointsWon"]["ai"] = 2
	crowd.observe(state, 0)
	var cheer_after_first: float = crowd.get("_cheer_left")
	print("PRIME cheer=%.3f %s" % [cheer_after_first, "OK" if cheer_after_first == 0.0 else "FAIL"])
	failures += 0 if cheer_after_first == 0.0 else 1

	# 2. A point lands: the cheer must be armed for its full window.
	state.stats["pointsWon"]["player"] = 4
	crowd.observe(state, 1)
	var cheer: float = crowd.get("_cheer_left")
	print("POINT cheer=%.3f expected=%.3f %s" % [
		cheer, Crowd.CHEER_SECONDS, "OK" if is_equal_approx(cheer, Crowd.CHEER_SECONDS) else "FAIL"])
	failures += 0 if is_equal_approx(cheer, Crowd.CHEER_SECONDS) else 1

	# 3. The cheer decays and stops. Ticking the group must bring it back to rest,
	#    not leave the crowd bouncing for the rest of the match.
	for i in 40:
		crowd._process(0.1)
	var rested: float = crowd.get("_cheer_left")
	print("DECAY cheer=%.3f %s" % [rested, "OK" if rested == 0.0 else "FAIL"])
	failures += 0 if rested == 0.0 else 1

	# 4. A long rally raises the murmur, and ending it settles the crowd.
	state.rallyHits = Crowd.LONG_RALLY_HITS
	crowd.observe(state, 2)
	var murmuring: bool = crowd.get("_murmuring")
	print("RALLY_LONG hits=%d murmuring=%s %s" % [
		state.rallyHits, str(murmuring), "OK" if murmuring else "FAIL"])
	failures += 0 if murmuring else 1

	state.rallyHits = 0
	crowd.observe(state, 3)
	var settled: bool = not crowd.get("_murmuring")
	print("RALLY_END murmuring=%s %s" % [str(not settled), "OK" if settled else "FAIL"])
	failures += 0 if settled else 1

	# 5-6. Since 2026-09-25 the crowd is 3D (MultiMesh fans, motion in the shader). The
	#      same two promises, read from the new form: the cheer drives a bounded motion,
	#      and every spectator sits ON the stands.
	var fans: Array = crowd.get("_fans")
	var stand_h3d: float = 3.014
	if not fans.is_empty():
		state.stats["pointsWon"]["player"] = 5
		crowd.observe(state, 4)
		crowd._process(1.0 / 60.0)
		var sm := (fans[0] as MultiMeshInstance3D).material_override as ShaderMaterial
		var jump: float = sm.get_shader_parameter("jump")
		var bob: float = sm.get_shader_parameter("bob")
		var moving := jump > 0.5 and bob > 0.0 and bob <= Crowd.IDLE_BOB_M * 2.5 + 0.0001
		print("BOB jump=%.2f bob=%.4f m %s" % [jump, bob, "OK" if moving else "FAIL"])
		failures += 0 if moving else 1
		var lo := 1e9
		var hi := -1e9
		for mmi in fans:
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var y: float = mm.get_instance_transform(i).origin.y
				lo = minf(lo, y)
				hi = maxf(hi, y)
		var inside3d: bool = lo > 0.0 and hi < stand_h3d
		print("SEATED y=[%.3f, %.3f] stand_h=%.3f %s" % [lo, hi, stand_h3d, "OK" if inside3d else "FAIL"])
		failures += 0 if inside3d else 1
		print("CROWD_PROBE failures=%d %s" % [failures, "PASS" if failures == 0 else "FAIL"])
		quit(0 if failures == 0 else 1)
		return

	# 5. The bob must actually move the quads, and stay within its own bounds: a
	#    spectator that drifts is a spectator that ends up inside the canopy.
	var quads: Array = crowd.get("_quads")
	var sample: Sprite3D = quads[0]
	var lowest := 1e9
	var highest := -1e9
	state.stats["pointsWon"]["player"] = 5
	crowd.observe(state, 4)  # cheering: the widest swing the crowd ever makes
	for i in 60:
		crowd._process(1.0 / 60.0)
		lowest = minf(lowest, sample.position.y)
		highest = maxf(highest, sample.position.y)
	var travel := highest - lowest
	var ceiling := Crowd.IDLE_BOB_M * Crowd.CHEER_GAIN * 2.0
	print("BOB travel=%.4f m ceiling=%.4f m %s" % [
		travel, ceiling, "OK" if travel > 0.0 and travel <= ceiling else "FAIL"])
	failures += 0 if (travel > 0.0 and travel <= ceiling) else 1

	# 6. Every spectator sits ON the stands, not beside them or through the canopy.
	var lowest_seat := 1e9
	var highest_seat := -1e9
	for q in quads:
		lowest_seat = minf(lowest_seat, (q as Sprite3D).position.y)
		highest_seat = maxf(highest_seat, (q as Sprite3D).position.y)
	var stand_h: float = 3.014
	var inside: bool = lowest_seat > 0.0 and highest_seat < stand_h
	print("SEATED y=[%.3f, %.3f] stand_h=%.3f %s" % [
		lowest_seat, highest_seat, stand_h, "OK" if inside else "FAIL"])
	failures += 0 if inside else 1

	print("CROWD_PROBE failures=%d %s" % [failures, "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
