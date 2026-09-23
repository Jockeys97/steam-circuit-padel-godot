extends SceneTree
## Two interstitial moments, measured on a real match:
##  A. AFTER A POINT: for the first 0.7 s of every `pointPause`, what clip each
##     rig plays and how far it moves. Today the paddles teleport, so this is
##     what the freeze actually looks like.
##  B. THE SERVE: where the ball sits relative to the server's racket hand while
##     `state.serving` (is a cosmetic bounce even plausible?).
##
##   $GODOT --headless --path godot/ --script res://game/tools/interstitial_beat_probe.gd
const Sim = preload("res://src/sim/sim.gd")
const Config = preload("res://game/match_config.gd")
const Scripted = preload("res://game/scripted_player.gd")
const Court = preload("res://game/court.gd")

const TICK := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 3
	var node: Node = (load("res://game/Match.tscn") as PackedScene).instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	node.build_athletes()
	var view = node._athletes
	var human = Scripted.new()
	var prev_pause := 0.0
	var prev_pos := {}
	var in_pause := false
	var elapsed := 0.0
	var log: Array = []
	var serve_samples: Array = []
	for tick in 24000:
		node.tick_fixed(TICK, human.decide(node.state), Sim.empty_input())
		if node.state == null or node.state.result != null:
			break
		var pause := float(node.state.pointPause)
		view.sync(node.state, TICK)
		for role in view.rigs:
			view.rigs[role]._anim.advance(TICK)
		if pause > 0.0 and prev_pause == 0.0:
			in_pause = true
			elapsed = 0.0
			log = []
			prev_pos = {}
		if in_pause:
			elapsed += TICK
			var rows := []
			for role in view.rigs:
				var rig = view.rigs[role]
				var pos: Vector2 = Vector2(rig.position.x, rig.position.z)
				var moved: float = pos.distance_to(prev_pos.get(role, pos)) if prev_pos.has(role) else 0.0
				prev_pos[role] = pos
				rows.append("%s=%s(%.3fm)" % [role, String(rig._anim.current_animation), moved])
			log.append("PAUSE t=%.2f  %s" % [elapsed, "  ".join(rows)])
			if elapsed >= 0.7:
				in_pause = false
				for line in log:
					print("BEAT ", line)
		elif node.state.serving:
			var srole := String(node.state.activePlayerKey)
			var rig = view.rigs.get(srole)
			if rig != null:
				var hand: Vector3 = rig.position + Vector3(0, 1.2, 0)
				var ball := Court.world_pos(float(node.state.ball.x), float(node.state.ball.y), float(node.state.ball.z))
				serve_samples.append([srole, String(rig._anim.current_animation), ball.distance_to(hand), ball.y - rig.position.y])
		prev_pause = pause
	if not serve_samples.is_empty():
		var clips := {}
		for s in serve_samples:
			clips[s[1]] = int(clips.get(s[1], 0)) + 1
		var mid = serve_samples[serve_samples.size() / 2]
		print("SERVE samples=%d clips=%s  median ball->hand(1.2m above feet)=%.2fm  ball height above feet=%.2fm" % [
			serve_samples.size(), clips, mid[2], mid[3]])
	quit(0)
