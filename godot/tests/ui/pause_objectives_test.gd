extends SceneTree

const OverlayScene := preload("res://src/ui/screens/PauseOverlay.tscn")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const MatchController := preload("res://game/match_controller.gd")
const ModeSession := preload("res://game/mode_session.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")

class FakeState extends RefCounted:
	var stats := {"winners": {"player": 2}, "pointsWon": {"player": 3}}

class FakeSeam extends RefCounted:
	var mode := "quick"
	var routes: Array[String] = []

	func pause_objectives() -> Dictionary:
		if mode == "quick":
			return {}
		if mode == "tournament":
			return {"mode": mode, "rows": [{"section_key": "objTitle", "label_key": "pauseTournamentRound", "progress": 2, "target": 3}]}
		return {"mode": mode, "rows": [{"section_key": "objMatchTitle", "label_key": "objMatch_winners", "progress": 2, "target": 10}]}

	func selection_route(screen_id: String) -> void:
		routes.append(screen_id)


func _initialize() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var overlay := OverlayScene.instantiate()
	overlay.set_store(SaveStore.new("user://pause-objectives-test"))
	var seam := FakeSeam.new()
	overlay.bind_seam(seam)
	host.add_child(overlay)
	await process_frame
	var action: Button = overlay.find_child("ChangeArenaButton", true, false)
	var panel: VBoxContainer = overlay.find_child("PauseObjectives", true, false)
	assert(action != null and panel != null)

	# Quick match keeps the existing arena-selection action.
	overlay.open()
	assert(action.text == UiStrings.t("changeArena"))
	assert(overlay.change_arena())
	assert(seam.routes == ["arena"])
	assert(not overlay.is_open())

	# Both fixed-fixture modes stay in the match and expose the actual goal.
	for mode in ["career", "tournament"]:
		seam.mode = mode
		overlay.open()
		assert(action.text == UiStrings.t("viewObjectives"))
		assert(overlay.change_arena())
		assert(overlay.is_open() and panel.visible)
		assert(not overlay.find_child("PauseActions", true, false).visible)
		assert(seam.routes.size() == 1)
		assert(overlay.report().get("objectives_open") == true)
		assert(overlay.back().get("kind") == "objectives_close")
		assert(overlay.is_open() and not panel.visible)
		assert(overlay.find_child("PauseActions", true, false).visible)
		overlay.close()

	# The live career snapshot reads the simulation without mutating saved totals.
	var controller := MatchController.new()
	controller.session = ModeSession.new()
	controller.session.mode = "career"
	controller.session.career = CareerProgress.empty_career()
	controller.session.objective = {"id": "winners", "target": 10}
	controller.state = FakeState.new()
	var saved_before: Dictionary = controller.session.career.duplicate(true)
	var live: Dictionary = controller.pause_objectives()
	assert(live.get("mode") == "career")
	assert((live.get("rows") as Array).size() == 4)
	assert(int((live.get("rows") as Array)[0].get("progress")) == 2)
	assert(controller.session.career == saved_before)
	controller.session.mode = "tournament"
	controller.session.round = 1
	assert(controller.pause_objectives().get("mode") == "tournament")
	controller.session.mode = "quick"
	assert(controller.pause_objectives().is_empty())
	controller.free()

	print("PASS pause objectives quick/career/tournament/live progress")
	quit(0)
