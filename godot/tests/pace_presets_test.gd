## pace_presets_test.gd — the game-pace ladder's own promises.
##
## The feature is one multiplication on the dt that feeds the simulation
## (`src/sim/pace.gd`), so what is worth asserting is the TABLE: that it is a
## ladder, that its default is the tuning the build already shipped, and that a
## lookup can never hand a clock a factor of zero.
extends SceneTree

const Pace = preload("res://src/sim/pace.gd")

## The rung labelled `Realistic`, as its `real : game` numerator.
const REAL_PACE := 1.5
## The ladder the labels promise, in table order.
const EXPECTED_RATIOS := [1.0, 1.5, 2.0, 2.5, 3.0]

var failures := 0
var checks := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func _initialize() -> void:
	var ids := Pace.ids()
	check(not Pace.PRESETS.is_empty(), "the table carries presets")
	check(ids.size() == Pace.PRESETS.size(), "ids() answers one id per preset")

	var seen := {}
	for id in ids:
		check(not seen.has(id), "the id %s appears once" % id)
		seen[id] = true

	var previous := INF
	for preset in Pace.PRESETS:
		var factor := float((preset as Dictionary)["factor"])
		check(factor > 0.0, "every factor is above zero")
		check(factor < previous, "the factors descend in table order")
		previous = factor

	# An unknown id is the case a save from another build lands in: it must read
	# back as the default, never as a clock that has stopped.
	check(Pace.has(Pace.default_id()), "the default id is one of the presets")
	check(not Pace.has("no_such_pace"), "an id outside the table is not a preset")
	check(is_equal_approx(Pace.factor_for("no_such_pace"), Pace.factor_for(Pace.default_id())),
		"an unknown id falls back to the default's factor")
	check(Pace.factor_for("no_such_pace") != 0.0, "an unknown id never returns zero")
	check(String(Pace.preset("no_such_pace")["id"]) == Pace.default_id(),
		"preset() falls back to the default's record")

	# `brisk` is exactly the tuning the build already had, which is why an existing
	# player sees nothing change until they choose otherwise.
	check(is_equal_approx(Pace.factor_for(Pace.default_id()), 1.0),
		"the default factor is exactly 1.0")

	for id in ids:
		var factor := Pace.factor_for(String(id))
		check(is_equal_approx(Pace.scaled_dt(1.0 / 120.0, String(id)), factor / 120.0),
			"scaled_dt multiplies the step by %s's factor" % id)
	check(is_zero_approx(Pace.scaled_dt(0.0, Pace.default_id())), "no time scales to no time")

	for index in ids.size():
		var id := String(ids[index])
		var ratio := REAL_PACE / Pace.factor_for(id)
		check(is_equal_approx(ratio, float(EXPECTED_RATIOS[index])),
			"%s plays %s times slower than real padel" % [id, EXPECTED_RATIOS[index]])
		check(is_equal_approx(Pace.real_pace_ratio(id), ratio),
			"real_pace_ratio(%s) is that same figure" % id)

	# The strings the settings row shows: every key the table names resolves in both
	# languages the port carries, so no rung can print a raw id.
	for preset in Pace.PRESETS:
		for key in ["label_key", "blurb_key"]:
			var message_id := String((preset as Dictionary)[key])
			for lang in Pace.STRINGS.keys():
				check(Pace.text(message_id, String(lang)) != message_id,
					"%s resolves in %s" % [message_id, lang])

	print("%s pace presets: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
