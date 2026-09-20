## colosso_asset_test.gd — focused gate for the first real athlete asset.
##
## This test deliberately exercises only the new Colosso path. The existing rig
## test continues to cover the Volpe fallback, so a bad import cannot silently
## replace the working default.
extends SceneTree

const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const AthletesView := preload("res://game/athletes_view.gd")
const Court := preload("res://game/court.gd")

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
		check_eq(details.get("athlete_asset", &""), &"colosso", "Colosso selects its own asset")
		check_eq(details.get("load_error", -1), OK, "Colosso GLB loads")
		check_true(int(details.get("joints", 0)) >= 28, "Colosso keeps the exported Mixamo skeleton")
		check_true(&"idle" in (details.get("locomotion_states", []) as Array), "Colosso has idle")
		check_true(&"walk" in (details.get("locomotion_states", []) as Array), "Colosso has walk")
		check_true(&"run" in (details.get("locomotion_states", []) as Array), "Colosso has run")
		check_true(rig.play_locomotion(&"walk"), "Colosso walk clip plays")
		check_true(rig.play_locomotion(&"run"), "Colosso run clip plays")
		check_true(rig.play_stroke(&"drive"), "Colosso keeps the existing stroke API")
		var skeleton: Skeleton3D = rig.get_skeleton()
		var hand_name := "mixamorig:RightHand"
		var hand_index := skeleton.find_bone(hand_name)
		if hand_index < 0:
			hand_name = "mixamorig_RightHand"
			hand_index = skeleton.find_bone(hand_name)
		check_true(hand_index >= 0, "Colosso exposes the standard right-hand bone")
		var attachment: BoneAttachment3D = rig.make_standard_bone_attachment(
			&"RightHand", &"RacketAnchorTest")
		check_true(attachment != null, "Colosso creates a racket attachment on the standard skeleton")
		if attachment != null:
			check_eq(attachment.get_parent(), skeleton, "Racket attachment belongs to Colosso's skeleton")
			check_eq(attachment.bone_name, hand_name, "Racket attachment resolves the exported hand name")
			var racket := Court.make_racket_view(attachment, "RacketTest", Color.GOLD)
			racket.position = Vector3(0.0, 0.24, 0.0)
			check_eq(racket.get_parent(), attachment, "Racket geometry is parented to the hand attachment")
			check_true(racket.get_node_or_null("SlamRacket") != null,
				"Hand attachment carries the complete racket geometry")
		rig.free()

	# Exercise the real match integration too: the view must choose the wrist mount
	# for a standard athlete rather than merely exposing a helper that nobody calls.
	var athletes_view := AthletesView.new()
	root.add_child(athletes_view)
	var spawned := athletes_view.spawn(
		{"player": {"id": "colosso"}},
		{"player": &"base"},
		{"player": Color.GOLD})
	check_eq(spawned, 1, "Match athlete view spawns Colosso")
	if spawned == 1:
		var live_racket: Node3D = athletes_view.rackets["player"]
		check_true(live_racket.get_parent() is BoneAttachment3D,
			"Match athlete view mounts Colosso's racket on a bone attachment")
		check_eq(live_racket.position, AthletesView.RACKET_HAND_LOCAL,
			"Match racket uses the calibrated grip-centre offset")
	athletes_view.free()
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
