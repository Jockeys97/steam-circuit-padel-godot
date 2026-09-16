extends SceneTree
const Court = preload("res://game/court.gd")
const Sim = preload("res://src/sim/sim.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func _initialize() -> void:
	var c := Court.court()
	check(is_equal_approx(Court.court_len(), 10.0), "width 10 m")
	check(is_equal_approx(Court.court_depth(), 20.0), "length 20 m")
	check(is_equal_approx(Court.world_pos(c.left, c.netY, 0).x, -5.0), "left glass")
	check(is_equal_approx(Court.world_pos(c.right, c.netY, 0).x, 5.0), "right glass")
	check(is_equal_approx(Court.depth_m(c.top), -10.0), "far glass")
	check(is_equal_approx(Court.depth_m(c.bottom), 10.0), "near glass")
	check(is_zero_approx(Court.depth_m(c.netY)), "net origin")
	for side in [-1.0, 1.0]:
		var line: float = c.netY + side * Sim.SERVICE_LINE_OFFSET
		check(absf(Court.depth_m(line) - side * 6.95) < 0.00001, "visible service matches simulation boundary")
		var before := (Court.depth_m(line) - Court.depth_m(line - 0.01)) / 0.01
		var after := (Court.depth_m(line + 0.01) - Court.depth_m(line)) / 0.01
		check(absf(before - after) < 0.0001, "no velocity jump at service line")
	var last := Court.depth_m(float(c.top) - 20.0)
	for i in 1100:
		var y: float = float(c.top) - 20.0 + float(i + 1) * 0.5
		var next := Court.depth_m(y)
		check(next > last, "depth remains monotone")
		last = next
	print("%s court dimensions: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
