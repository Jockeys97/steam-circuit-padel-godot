extends SceneTree
const Config := preload("res://game/match_config.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func run() -> void:
	Config.save_dir = "user://tournament-ui-%d" % Time.get_ticks_usec()
	Config.pending_mode = "tournament"
	root.size = Vector2i(1280, 720)
	var screen = load("res://game/ModeScreen.tscn").instantiate()
	root.add_child(screen)
	for i in 4:
		await process_frame
	var focus = screen.focus_model()
	check(focus.reachable_ids().size() == 5, "all three rounds, play and back reachable")
	check(not screen._mode_subtitle().contains("godot"), "no developer text")
	focus.menu.nav.set_focus("tournament:round0")
	focus.step_pad({"buttons": {}, "now_ms": 0.0})
	var right = focus.step_pad({"buttons": {"15": true}, "now_ms": 500.0})
	screen._dispatch(right)
	check(focus.focus_id() == "tournament:round1", "D-pad right reaches semifinal")
	focus.step_pad({"buttons": {}, "now_ms": 600.0})
	screen._dispatch(focus.step_pad({"buttons": {"0": true}, "now_ms": 700.0}))
	check(screen._detail.text.contains("SEMI"), "A displays round detail")
	focus.menu.nav.set_focus("start")
	check(focus.menu.confirm().get("action") == "start", "A on play uses existing start action")
	check(screen.start_mode(true).get("started", false), "tournament launch contract preserved")
	focus.step_pad({"buttons": {}, "now_ms": 800.0})
	var back = focus.step_pad({"buttons": {"1": true}, "now_ms": 900.0})
	check(back.get("action") == "to-menu", "B resolves menu return")
	root.size = Vector2i(960, 540)
	for i in 4:
		await process_frame
	focus.refresh()
	check(focus.reachable_ids().size() == 5, "small viewport retains all targets")
	check(screen._tournament_scroll != null, "small screen can scroll to back")
	current_scene = screen
	screen._dispatch(back)
	for i in 5:
		await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://game/Main.tscn", "B actually returns to main menu")
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	print("TOURNAMENT_UI %d/%d" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
