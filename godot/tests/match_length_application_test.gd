## match_length_application_test.gd — does the setup choice alter a quick state?
##
## The Modes screen has always persisted `prefs.matchLength`; this test proves the
## match-construction boundary now reads the same preference and transfers every
## frozen MATCH_FORMATS field. It uses an isolated save root and does not mount or
## mutate the player's profile.
extends SceneTree

const Config := preload("res://game/match_config.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Sim := preload("res://src/sim/sim.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1


func quick_state() -> Variant:
	return Sim.create_match_state("quick", Config.athlete(), Config.arena(), Config.tier())


func run() -> void:
	Config.save_dir = "user://match-length-application-test"
	for case in [
		{"id": "points11", "scoring": "points", "points": 11},
		{"id": "points21", "scoring": "points", "points": 21},
		{"id": "games3", "scoring": "tennis", "games": 2, "margin": 1, "tie": null, "sets": 1},
		{"id": "games5", "scoring": "tennis", "games": 3, "margin": 1, "tie": null, "sets": 1},
		{"id": "set", "scoring": "tennis", "games": 6, "margin": 2, "tie": 6, "sets": 1},
		{"id": "match2", "scoring": "tennis", "games": 6, "margin": 2, "tie": 6, "sets": 2},
	]:
		var row: Dictionary = case
		ModesSave.save_pref(Config.save_store(), "matchLength", String(row["id"]))
		var state = quick_state()
		Config.apply_quick_match_format(state)
		check(Config.match_length() == String(row["id"]), "%s is read from prefs" % row["id"])
		check(state.scoring == String(row["scoring"]), "%s transfers scoring" % row["id"])
		if row.has("points"):
			check(state.pointsToWin == int(row["points"]), "%s transfers target points" % row["id"])
		else:
			check(state.gamesToWin == int(row["games"]), "%s transfers games target" % row["id"])
			check(state.gameMargin == int(row["margin"]), "%s transfers game margin" % row["id"])
			check(state.tieBreakAt == row["tie"], "%s transfers tie-break rule" % row["id"])
			check(state.setsToWin == int(row["sets"]), "%s transfers sets target" % row["id"])

	ModesSave.save_pref(Config.save_store(), "matchLength", "not-a-format")
	check(Config.match_length() == "points11", "an invalid persisted value falls back to points11")
	print("MATCH_LENGTH_APPLICATION %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(1 if failures else 0)
