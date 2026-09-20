## coach_integration_probe.gd — the end-to-end half of the coach's integration test.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##       --script res://tests/coach_integration_probe.gd -- --port=18790 --mode=client
##
## WHAT IT IS. The real `CoachClient` (the engine's own `HTTPRequest`, no fake poster) and
## the real result screen with the real coach block, driven against a bridge a Node process
## started: `scripts/coach/jev_bridge_integration_test.mjs` owns the bridge, its fake
## upstream and the assertions, and reads this probe's `probe <key>=<value>` lines. Nothing
## here reaches TypeSafe, and nothing here needs a key.
##
## MODES
##   client  — one client, two asks: the first meets an upstream that answers 503, the second
##             meets one that answers, so the run proves fail -> retry -> advice end to end.
##   ui      — the whole visible path: the result screen mounts the block, the button is
##             pressed, the advice arrives, and the exercise button routes into the real
##             drill screen with the recommended exercise selected.
##   offline — the same client against a bridge whose upstream is unreachable: the truthful
##             unavailable state, twice (a retry is a new request, not a cached failure).
##
## Exit 0 when the mode's own expectations held, 1 otherwise; the Node side re-checks the
## printed values, so a green exit here is not the only evidence.
extends SceneTree

const Client := preload("res://src/coach/coach_client.gd")
const Config := preload("res://game/match_config.gd")
const DrillScene := preload("res://src/ui/screens/DrillScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenScene := preload("res://src/ui/screens/ResultScreen.tscn")
const UiStrings := preload("res://src/ui/UiStrings.gd")

const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 4
const WAIT_FRAMES := 600
const TEMP_DIR := "user://jev-coach-integration"
const SERVE_FOCUS := "serve_accuracy"

var _failures: Array = []


func _initialize() -> void:
	var port := 0
	var mode := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--port="):
			port = int(String(arg).substr(7))
		if String(arg).begins_with("--mode="):
			mode = String(arg).substr(7)
	if port <= 0 or mode == "":
		printerr("coach_integration_probe: --port and --mode are required")
		quit(1)
		return
	OS.set_environment("COACH_PORT", str(port))
	Config.save_dir = TEMP_DIR
	var frame := Control.new()
	frame.name = "CoachIntegrationFrame"
	frame.size = FRAME
	root.size = Vector2i(int(FRAME.x), int(FRAME.y))
	root.add_child(frame)
	for _i in SETTLE_FRAMES:
		await process_frame
	match mode:
		"client":
			await _client_mode()
		"ui":
			await _ui_mode(frame)
		"offline":
			await _offline_mode()
		_:
			_fail("unknown mode %s" % mode)
	_cleanup()
	quit(1 if not _failures.is_empty() else 0)


## One client, two asks. The bridge is real; only the upstream behind it changes its answer.
func _client_mode() -> void:
	var client := Client.new()
	client.name = "CoachIntegrationClient"
	root.add_child(client)
	var snapshot: Dictionary = client.snapshot_of(_result())
	var first := await _ask(client, snapshot)
	_report("first", String(first.get("state", "")))
	var second := await _ask(client, snapshot)
	_report("second", String(second.get("state", "")))
	_report("drill", String(second.get("drill_id", "")))
	_report("requests", str(client.request_count()))
	_check(String(first.get("state", "")) == "unavailable", "the first ask met the failing upstream")
	_check(String(second.get("state", "")) == "advice", "the retry met the answering upstream")
	_check(String(second.get("drill_id", "")) == "serve", "the advice links the serve exercise")
	_check(client.request_count() == 2, "the retry was a new request, not a cached failure")
	_check(client.open_completion_handlers() == 0, "no completion handler is left behind")
	client.queue_free()
	await process_frame


## The visible path: mount the result screen, press the button, read the advice, take the
## route into the training screen.
func _ui_mode(frame: Control) -> void:
	var router := Router.new()
	router.name = "Router"
	frame.add_child(router)
	router.register("result", ScreenScene)
	router.register("menu", PlaceholderScene)
	router.register("drill", DrillScene)
	router.go_to("result", _payload(false))
	for _i in SETTLE_FRAMES:
		await process_frame
	var screen: Node = router.active_screen()
	var panel: Node = screen.call("coach_panel")
	_report("before", String(panel.call("state_id")))
	_check(String(panel.call("state_id")) == "idle", "the block waits for a press")
	_check(int(panel.call("client").call("request_count")) == 0, "and asks nothing on arrival")
	panel.call("press_analyze")
	await _await_state(panel, "advice")
	_report("after", String(panel.call("state_id")))
	_report("exercise", String(panel.call("shown_exercise")))
	_report("evidence", String(panel.call("shown_evidence")))
	_check(String(panel.call("state_id")) == "advice", "the advice arrived through the real bridge")
	_check(String(panel.call("shown_exercise")).contains(UiStrings.t("drill_serve_name")), "the block names the serve exercise")
	_check(bool(panel.call("drill_visible")), "the exercise button is offered")
	Config.pending_mode = "career"
	var routed := String(panel.call("press_drill"))
	for _i in SETTLE_FRAMES:
		await process_frame
	_report("route", String(router.active_id()))
	_report("selected", String(router.active_screen().call("exercise")))
	_report("pending_mode", String(Config.pending_mode))
	_check(routed == "serve", "the button reported the recommended exercise")
	_check(String(router.active_id()) == "drill", "the router opened the training screen")
	_check(String(router.active_screen().call("exercise")) == "serve", "with the exercise selected")
	_check(String(Config.pending_mode) == "career", "and the pending run was left alone")
	Config.pending_mode = ""


## A bridge whose upstream is unreachable: the truthful state, twice.
func _offline_mode() -> void:
	var client := Client.new()
	client.name = "CoachOfflineClient"
	root.add_child(client)
	var snapshot: Dictionary = client.snapshot_of(_result())
	var first := await _ask(client, snapshot)
	_report("first", String(first.get("state", "")))
	var second := await _ask(client, snapshot)
	_report("second", String(second.get("state", "")))
	_report("requests", str(client.request_count()))
	_report("advice", String(second.get("advice_id", "")))
	_check(String(first.get("state", "")) == "unavailable", "an unreachable upstream is unavailable")
	_check(String(second.get("state", "")) == "unavailable", "and a retry is a new request that says the same")
	_check(client.request_count() == 2, "the retry really went out")
	_check(String(second.get("advice_id", "")) == "", "nothing is claimed about the match")
	_check(client.open_completion_handlers() == 0, "no completion handler is left behind")
	client.queue_free()
	await process_frame


func _ask(client: Node, snapshot: Dictionary) -> Dictionary:
	client.analyze(snapshot)
	for _frame in WAIT_FRAMES:
		if not client.pending():
			break
		await process_frame
	return client.record()


func _await_state(panel: Node, wanted: String) -> void:
	for _frame in WAIT_FRAMES:
		if String(panel.call("state_id")) == wanted:
			return
		await process_frame


## A CONSTRUCTED 11-7 match: the fixture the coach audits mount, labelled as a fixture.
func _result() -> Dictionary:
	return {
		"score": "11-7",
		"won": true,
		"pointsToWin": 11,
		"player": 11,
		"ai": 7,
		"stats": {
			"pointsWon": {"player": 11, "ai": 7},
			"aces": {"player": 2, "ai": 1},
			"winners": {"player": 5, "ai": 3},
			"errors": {"player": 4, "ai": 6},
			"doubleFaults": {"player": 3, "ai": 1},
			"smashWinners": {"player": 1, "ai": 0},
			"rallyCount": 9,
			"totalRallyHits": 32,
			"longestRally": 7,
		},
	}


func _payload(pending: bool) -> Dictionary:
	return {
		"result": _result(),
		"mode": "career" if pending else "quick",
		"arena_id": String((Config.arena() as Dictionary).get("id", "")),
		"season": 1,
		"match": 1,
		"outcome": "",
		"tournament": {},
		"continue_pending": pending,
	}


func _report(key: String, value: String) -> void:
	# One line per value: a reported line can be a multi-line block (the advice plus the
	# exercise), and the Node side reads one `probe k=v` line per fact.
	print("probe %s=%s" % [key, value.replace("\n", " | ")])


func _check(condition: bool, what: String) -> void:
	print("%s %s" % ["ok" if condition else "FAIL", what])
	if not condition:
		_failures.append(what)


func _fail(what: String) -> void:
	_check(false, what)


func _cleanup() -> void:
	DirAccess.remove_absolute(TEMP_DIR)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))
