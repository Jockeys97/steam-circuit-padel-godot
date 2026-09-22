extends SceneTree
## Diagnostic only. Temporary rendering switches never reach preferences or source.
const Config = preload("res://game/match_config.gd")
const Sim = preload("res://src/sim/sim.gd")
var game
var rows: Array = []
func _initialize(): call_deferred("run")
func measure(id: String, arm: String, live: bool = false) -> void:
	for i in 20: await process_frame
	var samples: Array[float] = []
	var cpu: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	var accumulator := 0.0
	while Time.get_ticks_usec() - start < 2000000:
		# Explicit draw avoids macOS occlusion skipping the renderer. This is
		# a controlled rendering workload, not an in-game FPS certification.
		RenderingServer.force_draw(false)
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - previous) / 1000000.0
		samples.append(dt * 1000.0)
		previous = now
		if live:
			accumulator += minf(dt, 0.1)
			while accumulator >= game.FIXED_STEP:
				game.tick_fixed(game.FIXED_STEP, game._scripted.decide(game.state), Sim.empty_input())
				accumulator -= game.FIXED_STEP
			game._sync_views()
		cpu.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	samples.sort()
	cpu.sort()
	var spikes := 0
	for ms in samples:
		if ms > 33.33: spikes += 1
	var row := {"arena":id,"arm":arm,"resolution":str(root.size),"frames":samples.size(),"fps":samples.size()/elapsed,
		"p50_ms":samples[int(samples.size()*0.5)],"p95_ms":samples[int(samples.size()*0.95)],"p99_ms":samples[int(samples.size()*0.99)],
		"max_ms":samples.back(),"over33":spikes,"cpu_p95_ms":cpu[int(cpu.size()*0.95)],
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	rows.append(row)
	print("AUDIT_ROW ",JSON.stringify(row))
func run():
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	Config.save_dir = "user://arena-perf-audit-%d" % Time.get_ticks_usec()
	Config.camera_preset = "default"
	print("AUDIT_ENV ",OS.get_processor_name()," ",RenderingServer.get_video_adapter_name())
	for id in ["officina","torii","medina","carioca","aurora","egeo"]:
		root.size = Vector2i(1280,720)
		DisplayServer.window_move_to_foreground()
		Config.world_arena_id = "" if id == "officina" else id
		Config.arena_index = 0
		var start := Time.get_ticks_usec()
		game = load("res://game/Match.tscn").instantiate()
		root.add_child(game)
		game.engine_driven = false
		print("AUDIT_BUILD ",id," ms=",float(Time.get_ticks_usec()-start)/1000.0)
		for i in 60: await process_frame
		await measure(id,"static")
		root.size = Vector2i(1920,1080)
		await measure(id,"static1080")
		await measure(id,"scripted1080",true)
		var arena: Node = game._arena_root
		var env: Environment = arena.find_child("WorldEnvironment",true,false).environment
		var sun: DirectionalLight3D = arena.find_child("Sun",true,false)
		# Interleave restored baseline around each one-variable intervention.
		if id in ["torii","medina","egeo"]:
			for arm in ["glow","ssao","fog","shadows","stands_props","scenery"]:
				var old: bool = false
				var hidden: Array[Node3D] = []
				if arm == "glow":
					old=env.glow_enabled
					env.glow_enabled=false
				elif arm == "ssao":
					old=env.ssao_enabled
					env.ssao_enabled=false
				elif arm == "fog":
					old=env.fog_enabled
					env.fog_enabled=false
				elif arm == "shadows":
					old=sun.shadow_enabled
					sun.shadow_enabled=false
				else:
					for name in (["Bleachers","ArenaProps"] if arm == "stands_props" else ["Scenery"]):
						var node := arena.find_child(name,true,false) as Node3D
						if node != null and node.visible:
							hidden.append(node)
							node.hide()
				await measure(id,arm+"_off")
				if arm == "glow": env.glow_enabled=old
				elif arm == "ssao": env.ssao_enabled=old
				elif arm == "fog": env.fog_enabled=old
				elif arm == "shadows": sun.shadow_enabled=old
				for node in hidden: node.show()
				await measure(id,"restored_"+arm)
		game.free()
		await process_frame
	var file := FileAccess.open("/tmp/padel-arena-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	print("AUDIT_DONE rows=",rows.size())
	quit()
