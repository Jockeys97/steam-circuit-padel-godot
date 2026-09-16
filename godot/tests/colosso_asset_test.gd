## colosso_asset_test.gd — focused gate for the first real athlete asset.
##
## This test deliberately exercises only the new Colosso path. The existing rig
## test continues to cover the Volpe fallback, so a bad import cannot silently
## replace the working default.
extends SceneTree

const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	var rig: Node3D = AthleteSpawn.make(&"colosso", &"base", {
		"name": "ColossoAssetProbe",
		"locomotion": &"idle",
	})
	check_true(rig != null, "Colosso spawns through the normal factory")
	if rig != null:
		var details := AthleteSpawn.describe(rig)
		check_eq(details.get("athlete_asset", &""), &"colosso", "Colosso selects the Solar Titan asset")
		check_eq(details.get("load_error", ERR_FAILED), OK, "Colosso GLB loads")
		check_true(int(details.get("joints", 0)) >= 28, "Colosso keeps the exported Mixamo skeleton")
		check_true(&"idle" in (details.get("locomotion_states", []) as Array), "Colosso has idle")
		check_true(&"walk" in (details.get("locomotion_states", []) as Array), "Colosso has walk")
		check_true(&"run" in (details.get("locomotion_states", []) as Array), "Colosso has run")
		check_true(rig.play_locomotion(&"walk"), "Colosso walk clip plays")
		check_true(rig.play_locomotion(&"run"), "Colosso run clip plays")
		check_true(rig.play_stroke(&"drive"), "Colosso keeps the existing stroke API")
		rig.free()
	_finish()


func check_eq(got, expected, name: String) -> void:
	_checks += 1
	if got == expected:
		print("ok %s" % name)
	else:
		_failures += 1
		printerr("FAIL %s: expected %s, got %s" % [name, str(expected), str(got)])


func check_true(got: bool, name: String) -> void:
	check_eq(got, true, name)


func _finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)
