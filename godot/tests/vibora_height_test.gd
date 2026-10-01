extends SceneTree
## vibora_height_test.gd — RB+X plays a víbora only on a ball at shoulder height
## (2026-09-30, owner: direct points on the return of serve with RB+X; every one was
## met at 43-49 px after the bounce). Below VIBORA_MIN_Z it is a plain slice.

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")

var passed := 0
var failed := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("ok " + name)
	else:
		failed += 1
		print("FAIL %s: %s" % [name, detail])


func _shot(z: float) -> String:
	var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[3])
	state.running = true
	state.serving = false
	state.rallyHits = 1
	var net_y := float(Frozen.court()["netY"])
	var p = state.active_player()
	p.x = 300.0
	p.y = net_y + 150.0
	var ball = state.ball
	ball.x = p.x
	ball.y = p.y - 4.0
	ball.z = z
	ball.vx = 0.0
	ball.vy = 380.0
	ball.vz = -40.0
	ball.served = true
	ball.serveInFlight = false
	ball.bounces = {"player": 1, "ai": 0}
	ball.shotType = "drive"
	Sim.hit_ball(state, p, 1.0, false, true, 0.6, true, "vibora")
	return String(ball.shotType)


func _initialize() -> void:
	var low := _shot(46.0)
	check("RB+X on a waist-high ball (46 px, the return of serve) is a slice", low == "slice", low)
	var high := _shot(72.0)
	check("RB+X on a shoulder-high ball (72 px) is still a víbora", high == "vibora", high)
	print("%s %d/%d" % ["PASS" if failed == 0 else "FAIL", passed, passed + failed])
	quit(0 if failed == 0 else 1)
