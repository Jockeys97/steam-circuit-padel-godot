extends SceneTree
## Time budget of a real match, by rig clip: how much of a match the athletes
## spend standing in `ready` between points, how long the pauses and the serve
## walk-up actually are, and how often a rig is asked for a transient
## (split_step / recover_*) that the view never triggers.
## Headless (no rendering): the clip state is what the view asks for.
##
##   $GODOT --headless --path godot/ --script res://game/tools/interstitial_probe.gd -- --ticks=24000
const Sim = preload("res://src/sim/sim.gd")
const Config = preload("res://game/match_config.gd")
const Scripted = preload("res://game/scripted_player.gd")

const TICK := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var ticks := 24000
	var tier := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="): ticks = int(a.substr(8))
		elif a.begins_with("--tier="): tier = int(a.substr(7))
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = tier
	var node: Node = (load("res://game/Match.tscn") as PackedScene).instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	node.build_athletes()
	var view = node._athletes
	var human = Scripted.new()
	var by_clip := {}
	var pause_ticks := 0
	var serve_ticks := 0
	var rally_ticks := 0
	var points := 0
	var ready_pause := 0
	var strokes := 0
	var prev_hitter := ""
	var prev_pause := 0.0
	var pause_runs: Array = []
	var run_len := 0
	for tick in ticks:
		node.tick_fixed(TICK, human.decide(node.state), Sim.empty_input())
		if node.state == null or node.state.result != null:
			break
		var pause := float(node.state.pointPause)
		if pause > 0.0:
			pause_ticks += 1
			run_len += 1
			if prev_pause == 0.0:
				points += 1
		elif run_len > 0:
			pause_runs.append(run_len)
			run_len = 0
		prev_pause = pause
		if node.state.serving:
			serve_ticks += 1
		elif pause <= 0.0:
			rally_ticks += 1
		var hitter := String(node.state.lastHitterSide) if node.state.lastHitterSide != null else ""
		if hitter != "" and hitter != prev_hitter and not node.state.serving:
			strokes += 1
		prev_hitter = hitter
		view.sync(node.state, TICK)
		for role in view.rigs:
			view.rigs[role]._anim.advance(TICK)
		for role in view.rigs:
			var rig = view.rigs[role]
			var c := String(rig._anim.current_animation)
			by_clip[c] = int(by_clip.get(c, 0)) + 1
			if c == "ready" and pause > 0.0:
				ready_pause += 1
	var total := pause_ticks + serve_ticks + rally_ticks
	print("INTERSTITIAL ticks=%d rig_ticks=%d points=%d strokes=%d" % [total, view.rigs.size() * total, points, strokes])
	print("INTERSTITIAL PHASES  pause=%.1f%%  serve=%.1f%%  rally=%.1f%%" % [
		100.0 * pause_ticks / maxf(1.0, total), 100.0 * serve_ticks / maxf(1.0, total), 100.0 * rally_ticks / maxf(1.0, total)])
	print("INTERSTITIAL PAUSE_RUNS n=%d median=%.2fs max=%.2fs" % [
		pause_runs.size(), 0.0 if pause_runs.is_empty() else TICK * float(pause_runs[pause_runs.size() / 2]),
		0.0 if pause_runs.is_empty() else TICK * float(pause_runs.max())])
	var keys := by_clip.keys()
	keys.sort_custom(func(a, b): return int(by_clip[a]) > int(by_clip[b]))
	for k in keys:
		var share := 100.0 * float(by_clip[k]) / maxf(1.0, view.rigs.size() * total)
		if share >= 0.4:
			print("INTERSTITIAL CLIP %-22s %6.2f%%" % [k, share])
	print("INTERSTITIAL ready_during_pause=%.1f%% of rig ticks" % [100.0 * ready_pause / maxf(1.0, view.rigs.size() * total)])
	quit(0)
