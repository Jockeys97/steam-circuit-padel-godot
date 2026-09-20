extends SceneTree
## Headless contract for the gameplay -> animation seam.
##
## The simulation remains authoritative: this test does not create a second ball
## or decide a shot. It proves that every `shotType` emitted by `hit_ball` has a
## deterministic visual recipe and that the rig can begin that recipe at the
## semantic contact frame. A missing mapping would silently turn a smash, volley
## or technical variant into an unrelated idle/drive animation in a live match.

const AthleteRigScene := preload("res://src/character/AthleteRig.tscn")
const AthletesView := preload("res://game/athletes_view.gd")

const INTENTS := [
	"serve", "drive", "slice", "lob", "globo", "chiquita", "vibora",
	"volley", "cut-volley", "bandeja", "wall-angle", "smash-flat", "smash-x2", "smash-x3",
]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	for intent in INTENTS:
		var recipe: Dictionary = AthletesView.stroke_recipe(intent)
		check(recipe.has("clip"), "%s has a stroke clip" % intent)
		check(recipe.has("contact_phase"), "%s has a contact phase" % intent)
		check(recipe.has("speed_scale"), "%s has a stroke speed" % intent)
		check(recipe["clip"] in [&"drive", &"slice", &"lob", &"serve", &"volley"],
			"%s resolves to a registered clip" % intent)
		check(float(recipe["contact_phase"]) > 0.0 and float(recipe["contact_phase"]) < 1.0,
			"%s contact phase is inside the clip" % intent)

	var rig: Node3D = AthleteRigScene.instantiate()
	root.add_child(rig)
	check(rig.has_method("play_stroke_at"), "rig exposes contact-synchronised stroke API")
	check(rig.play_stroke_at(&"drive", 0.34, 1.12),
		"rig starts a drive at the contact phase")
	var pose: Dictionary = rig.get_pose()
	check_eq(String(pose.get("clip", "")), "drive", "contact-synchronised pose reports drive")
	check(float(pose.get("time", 0.0)) > 0.0, "contact-synchronised pose seeks past wind-up")
	check(rig.is_stroking(), "contact-synchronised pose keeps the stroke active")

	rig.queue_free()
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
		quit(1)


func check(condition: bool, name: String) -> void:
	_checks += 1
	if condition:
		print("ok %s" % name)
	else:
		_failures += 1
		printerr("FAIL %s" % name)


func check_eq(actual: Variant, expected: Variant, name: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [name, str(expected), str(actual)])
