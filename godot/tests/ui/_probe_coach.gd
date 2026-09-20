## _probe_coach.gd — a one-off visual probe for the coach block (not an audit).
##
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-driver opengl3 \
##     --path godot --script res://tests/ui/_probe_coach.gd -- --out=/absolute/dir
##
## WHY IT EXISTS. The audit proves the block's states and its route; a PNG is what shows
## the layout — the disclosure under the card's own content, the advice with the match's
## numbers, and the exercise line with the continuation note when the run is one press
## from continuing. The states it draws are CONSTRUCTED fixtures (the same ones
## `result_coach_audit.gd` mounts), and its transport is the audit's fake: nothing here
## reaches a bridge, and no image here is a claim about a real match.
##
## It writes `coach-idle.png`, `coach-advice.png` and `coach-pending.png` into `--out`
## (default `res://game/out`), refuses a blank frame (the dummy driver's signature) and
## exits 1 when it could not draw. Plain `--headless` renders blank PNGs; use the
## rendering driver, as `capture_ui.gd` does.
extends SceneTree

const DrillScene := preload("res://src/ui/screens/DrillScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Config := preload("res://game/match_config.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenScene := preload("res://src/ui/screens/ResultScreen.tscn")

const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 4
const DEFAULT_OUT := "res://game/out"
const SERVE_FOCUS := "serve_accuracy"

class FakePoster extends RefCounted:
	var callbacks: Array = []

	func post(_url: String, _body: String, _timeout_ms: int, on_done: Callable) -> void:
		callbacks.append(on_done)

	func cancel() -> void:
		pass

	func deliver(index: int, reply: Dictionary) -> void:
		if index < callbacks.size():
			callbacks[index].call(reply)


var _out := ""
var _saved: Array = []


func _initialize() -> void:
	_out = DEFAULT_OUT
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--out="):
			_out = String(arg).substr(6)
	var frame := Control.new()
	frame.name = "CoachProbeFrame"
	frame.size = FRAME
	root.size = Vector2i(int(FRAME.x), int(FRAME.y))
	root.add_child(frame)
	var router := Router.new()
	router.name = "Router"
	frame.add_child(router)
	router.register("result", ScreenScene)
	router.register("menu", PlaceholderScene)
	router.register("drill", DrillScene)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _shot("coach-idle", router, _payload(false), "")
	await _shot("coach-advice", router, _payload(false), SERVE_FOCUS)
	await _shot("coach-pending", router, _payload(true), SERVE_FOCUS)
	for path in _saved:
		print("# saved %s" % String(path))
	quit(0 if _saved.size() == 3 else 1)


## One constructed 11-7 match: the same fixture the coach audit mounts, and the same
## disclaimer — this is a layout, not a played match.
func _payload(pending: bool) -> Dictionary:
	return {
		"result": {
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
		},
		"mode": "career" if pending else "quick",
		"arena_id": String((Config.arena() as Dictionary).get("id", "")),
		"season": 1,
		"match": 1,
		"outcome": "",
		"tournament": {},
		"continue_pending": pending,
	}


## Mounts the screen, optionally drives one confident answer through the fake transport,
## and saves the frame.
func _shot(file: String, router: Control, payload: Dictionary, focus: String) -> void:
	router.go_to("result", payload)
	for _i in SETTLE_FRAMES:
		await process_frame
	var screen: Node = router.active_screen()
	var panel: Node = screen.call("coach_panel")
	if focus != "":
		var poster := FakePoster.new()
		panel.call("set_poster", poster)
		panel.call("press_analyze")
		var snapshot: Dictionary = panel.call("client").call("snapshot")
		var offered: Array = snapshot.get("candidates", [])
		poster.deliver(0, _reply(offered, focus))
		for _i in SETTLE_FRAMES:
			await process_frame
	await RenderingServer.frame_post_draw
	var texture := root.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null:
		push_error("_probe_coach: the viewport produced no image for %s" % file)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var path := "%s/%s.png" % [_out.rstrip("/"), file]
	var err := image.save_png(path)
	if err != OK:
		push_error("_probe_coach: save_png err=%d for %s" % [err, path])
		return
	var colours := {}
	var step := maxi(image.get_width() / 16, 1)
	var x := 0
	while x < image.get_width():
		var y := 0
		while y < image.get_height():
			colours[image.get_pixel(x, y).to_rgba32()] = true
			y += step
		x += step
	if colours.size() <= 1:
		push_error("_probe_coach: %s is a blank frame (%d colours)" % [path, colours.size()])
		return
	_saved.append(path)


func _reply(offered: Array, choice: String) -> Dictionary:
	var rest := (1.0 - 0.8) / float(maxi(offered.size() - 1, 1))
	var probabilities := {}
	for id in offered:
		probabilities[String(id)] = 0.8 if String(id) == choice else rest
	return {
		"status": "ok",
		"body": {"type": "choice", "choice": choice, "confidence": 0.82, "probabilities": probabilities},
	}
