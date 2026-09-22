## Small reproducible rally sample, not a substitute for human playtesting.
extends SceneTree
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
func _initialize():
	var engine = Sim
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="):
			engine = load(arg.trim_prefix("--baseline="))
	if engine == null:
		quit(1)
		return
	var results := []
	for seed in [12345, 999, 2024]:
		var s = engine.create_match_state("quick",Frozen.athletes()[0],Frozen.arenas()[0],Frozen.ai_opponents()[1],0,{"seed":seed})
		s.running = true
		s.rng_state = seed
		for tick in 12000:
			var input = engine.empty_input()
			input.charging = tick >= 60
			input.hit = tick >= 60 and tick % 30 == 0
			engine.update_match(s,1.0/120.0,input)
		results.append({"seed":seed,"rallies":s.stats.rallyCount,"hits":s.stats.totalRallyHits,"longest":s.stats.longestRally,"points":s.stats.pointsWon,"errors":s.stats.errors})
	print("CENSUS ",JSON.stringify(results))
	quit()
