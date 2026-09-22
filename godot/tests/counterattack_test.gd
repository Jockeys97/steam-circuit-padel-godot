extends SceneTree
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
const Tactics = preload("res://src/sim/court_tactics.gd")
const Vocabulary = preload("res://game/feedback_vocabulary.gd")
var checks := 0
var failures := 0
var captures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func fresh(tier := 1):
	var s = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[tier], 0, {"seed":12345})
	s.serving = false
	s.running = true
	s.serviceReceiverKey = null
	s.aiServiceReceiverKey = null
	s.rallyHits = 3
	s.incomingShot = "chiquita"
	return s
func _initialize():
	call_deferred("run")
func run():
	var c = Frozen.court()
	var centre: float = (c.left + c.right) * 0.5
	for skill in [0.0, 0.5, 1.0]:
		check(Tactics.containment(40,1,1,skill) == 0, "comfortable height unchanged")
		check(Tactics.containment(12,0,0,skill) == 0, "planted centred contact unchanged")
		check(Tactics.containment(12,1,1,skill) > Tactics.containment(30,1,1,skill), "lower stretched ball limits depth progressively")
		check(Tactics.containment(12,1,1,skill) <= 1, "bounded response")
	check(Tactics.containment(20,1,1,1) < Tactics.containment(20,1,1,0), "skilled opponent contains better")
	var drives := 0
	for tier in 4:
		var s = fresh(tier)
		s.opponent.y = c.netY - 80
		s.opponent.x = centre
		s.ball.x = centre
		s.ball.y = s.opponent.y
		s.ball.z = 16
		s.player.y = c.bottom - 60
		s.playerMate.y = c.bottom - 70
		for seed in 40:
			s.rng_state = 1000 + seed * 7919
			s.opponent.moveRatio = 0
			s.ball.x = centre
			var normal = Sim.choose_computer_shot(s,s.opponent,s.ai,16,1)
			var rng_after: int = s.rng_state
			s.rng_state = 1000 + seed * 7919
			s.opponent.moveRatio = 1
			s.ball.x = centre + Sim.contact_width(s.opponent,s.ball)*0.9
			var block = Sim.choose_computer_shot(s,s.opponent,s.ai,16,1)
			check(s.rng_state == rng_after and normal.kind == block.kind, "no extra RNG or forced shot selection")
			if block.kind == "drive":
				drives += 1
				check(block.y < normal.y and block.flightTime > normal.flightTime, "low stretch yields shorter playable block")
				check(block.y >= c.netY + 120 and block.x == normal.x, "placement and safe depth retained")
			else:
				check(block == normal, "lob alternative remains untouched")
	check(drives > 40, "exercise actual drive branch across tiers")
	var smash_state = fresh()
	smash_state.incomingShot = "smash-x2"
	smash_state.opponent.y = c.netY - 80
	smash_state.ball.z = 16
	smash_state.ball.x = smash_state.opponent.x + Sim.contact_width(smash_state.opponent,smash_state.ball)*0.95
	smash_state.opponent.moveRatio = 1
	for seed in 40:
		smash_state.rng_state = 1000 + seed*7919
		var reply = Sim.choose_computer_shot(smash_state,smash_state.opponent,smash_state.ai,16,1)
		check(float(reply.get("containment",0)) == 0, "existing smash defence not weakened")
	# Real legal contact, not only a helper: low stretch produces a live reply,
	# with a ball crossing the net. No increase in contact reach.
	var successful := 0
	for seed in 40:
		var s = fresh()
		s.rng_state = 1000 + seed * 7919
		s.opponent.y = c.netY - 80
		s.opponent.x = centre
		s.opponent.moveRatio = 1
		s.ball.x = centre + Sim.contact_width(s.opponent,s.ball)*0.95
		s.ball.y = s.opponent.y
		s.ball.z = 16
		s.ball.vy = -120
		s.ball.bounces.ai = 1
		s.ball.shotType = "chiquita"
		s.lastHitterSide = "player"
		s.player.y = c.bottom - 60
		s.playerMate.y = c.bottom - 70
		check(Sim.hit_ball(s,s.opponent), "legal low-ball contact still possible")
		if s.ball.shotType == "drive" and not "evOppOutOfPos" in s.events:
			var net_time: float = (c.netY-s.ball.y)/s.ball.vy
			var net_height: float = s.ball.z+s.ball.vz*net_time-0.5*float(Frozen.balance().ballGravity)*net_time*net_time
			check(net_height > float(Frozen.balance().netClearance) + s.ball.r*0.35, "block clears net, not forced error")
			for tick in 240:
				Sim.update_match(s,1.0/240.0,Sim.empty_input())
				if s.ball.y > c.netY or s.pointPause > 0:
					break
			check(s.ball.y > c.netY and s.pointPause == 0 and s.ball.netFaultOwner == null, "real flight crosses without a net fault")
			successful += 1
	check(successful > 10, "real low stretched drives stay playable")
	var s = fresh()
	s.lastHitterSide = "player"
	s.player.y = c.bottom - 80
	s.ball.shotType = "lob"
	s.ball.y = c.netY - 100
	s.ball.z = 145
	s.ball.vz = -50
	s.ball.vy = -140
	s.opponent.y = c.top + 65
	s.opponentMate.y = c.top + 75
	Sim.update_shot_read(s,s.player)
	check(s.shotRead.advice == "advance", "deep lob against retreating pair cues advancing")
	if "--capture" in OS.get_cmdline_user_args():
		await capture(s, "advance")
	s.ball.vy = -20
	Sim.update_shot_read(s,s.player)
	check(s.shotRead.advice != "advance", "short lob never grants advance cue")
	s.ball.vy = -140
	s.opponentMate.y = c.netY - 60
	Sim.update_shot_read(s,s.player)
	check(s.shotRead.advice != "advance", "net opponent still dangerous")
	s.ball.y = c.netY + 55
	s.ball.x = centre
	s.ball.z = 28
	s.ball.vz = 0
	s.ball.vy = 120
	s.ball.vx = 0
	s.player.y = c.netY + 90
	s.player.x = centre
	s.opponent.x = c.left + 100
	s.opponentMate.x = centre - 20
	s.opponent.y = c.top + 65
	s.opponentMate.y = c.top + 75
	s.lastHitterSide = "ai"
	Sim.update_shot_read(s,s.player)
	check(s.shotRead.advice == "space", "short reachable ball with open lane cues placement")
	if "--capture" in OS.get_cmdline_user_args():
		await capture(s, "space")
	s.opponentMate.x = c.right - 100
	Sim.update_shot_read(s,s.player)
	check(s.shotRead.advice != "space", "covered court not falsely marked open")
	s.opponentMate.x = centre - 20
	s.player.y = c.bottom - 60
	Sim.update_shot_read(s,s.player)
	check(s.shotRead.advice != "space", "baseline player must earn position")
	for id in ["advance", "space"]:
		check(Vocabulary.advice_word(id) != id.to_upper(), "cue localizes " + id)
	if "--capture" in OS.get_cmdline_user_args():
		check(captures == 2, "both live capture sections completed")
	print("COUNTERATTACK %d/%d drives=%d real_blocks=%d" % [checks-failures,checks,drives,successful])
	quit(0 if failures == 0 else 1)

func capture(s, label: String):
	var game = load("res://game/Match.tscn").instantiate()
	game.engine_driven = false
	root.add_child(game)
	await process_frame
	game.state = s
	game._refresh_ui(s,game.meta)
	if game._hud != null:
		game._hud.refresh(s,game.meta)
	game._sync_views()
	await process_frame
	await RenderingServer.frame_post_draw
	var marks = game.court_timing_marks().report()
	check(marks.advice_visible and marks.advice == Vocabulary.advice_word(label), "live Match renders " + label)
	root.get_texture().get_image().save_png("/tmp/padel-counterattack-" + label + ".png")
	game.set_hud_hidden(true)
	game._sync_views()
	check(not game.court_timing_marks().report().advice_visible, "clean UI hides tactical cue")
	captures += 1
	game.free()
