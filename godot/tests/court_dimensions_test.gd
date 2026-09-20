extends SceneTree
const Court = preload("res://game/court.gd")
const Sim = preload("res://src/sim/sim.gd")

## The width the owner is looking at, declared here ONCE.
##
## `docs/wayfinder/tickets/court-width-render.md`: 10.0 m is the real padel width
## and the measurement is accepted; the RENDER is what he rejects, and the choice
## between the candidates 10.5 / 11.0 / 12.0 m is his. Until he picks, this is the
## value `game/court.gd` carries. When his pick lands, this number — and only this
## number in this file — moves with it; the mapping checks below are written in
## terms of it, so they cannot disagree with `WIDTH_M` in silence.
const EXPECTED_WIDTH_M := 11.0
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func _initialize() -> void:
	var c := Court.court()
	# The width is the owner's pick, not a literal: pinning 10.0 here made a
	# deliberate width change (the object of `tickets/court-width-render.md`) read
	# as a regression. The expectation moves with `Court.WIDTH_M`; everything else
	# in this file — the depth curve, the 6.95 m service boundary, the monotonicity
	# sweep — is unchanged and still pinned to the simulation's own numbers.
	check(is_equal_approx(Court.court_len(), Court.WIDTH_M), "width is the declared candidate")
	check(is_equal_approx(Court.court_depth(), 20.0), "length 20 m")
	check(is_equal_approx(Court.world_pos(c.left, c.netY, 0).x, -Court.WIDTH_M * 0.5), "left glass")
	check(is_equal_approx(Court.world_pos(c.right, c.netY, 0).x, Court.WIDTH_M * 0.5), "right glass")
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
