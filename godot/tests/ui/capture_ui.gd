## capture_ui.gd — UIR-24's capture harness: one PNG per registered screen and per
## declared capture state.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-driver opengl3 \
##     --path godot --resolution 1280x720 res://tests/ui/capture_ui.tscn \
##     -- --capture=all --seed=20260916 --tier=3
##
## `--capture=all` walks every screen the router has registered; `--capture=<id>`
## walks one (UIR-25 uses that for spot checks). The router is a screen's only
## registration point, so a new screen ticket lights up here with no edit to this
## file — the states come from the screen itself (`capture_states()`, the UIR-03
## contract), and a state the screen refuses is recorded as a finding, never
## captured.
##
## OUTPUT: `res://game/out/ui-<id>.png` for a screen's `default` state and
## `ui-<id>-<state>.png` for every other declared state. That prefix is this
## ticket's namespace; the ported screens' own PNGs (`menu.png`, `hud.png`, …) and
## UIR-09's `ui-prototype-*.png` are never written here.
##
## RENDERING: the captures come from the real viewport (`get_viewport().
## get_texture().get_image()`), so the run needs a real window context — plain
## `--headless` renders blank PNGs (the dummy driver) and `--rendering-driver
## opengl3` on this Mac gives `OpenGL API 4.1 Metal`. Every PNG is checked
## non-vacuous here (a sampled colour count of 1 is a blank frame) instead of
## being trusted because it exists.
##
## The host is the game's own (`res://game/Main.tscn`) with its prototype switch
## pre-set, so the walk mounts exactly what `--ui=new` mounts — one registration
## list, not a second one that could drift.
extends Control

const HostScene := preload("res://game/Main.tscn")
const ScreenContract := preload("res://src/ui/screens/ScreenContract.gd")
const OutDir := "res://game/out"
const SETTLE_FRAMES := 3
const SAMPLES := 16

var _ok_count: int = 0
var _failures: Array = []
var _refused: Array = []
var _blank: Array = []
var _saved: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	var which := _arg(args, "--capture=", "all")
	print("CAPTURE_UI_START which=%s seed=%s tier=%s frame=%s" % [
		which, _arg(args, "--seed=", "20260916"), _arg(args, "--tier=", "3"),
		str(get_viewport_rect().size)])
	await _walk(which)


func _arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


func _walk(which: String) -> void:
	await get_tree().process_frame
	var host: Control = HostScene.instantiate()
	# The host's prototype switch, set before `_ready()` runs: the same construction
	# `--ui=new` builds on the command line.
	host.set("ui_prototype", true)
	add_child(host)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var router: Control = host.call("ui_router") if host.has_method("ui_router") else null
	if router == null:
		_fail("harness/the_host_mounted_a_router", "the host built no router")
		_finish()
		return
	_ok("harness/the_host_mounted_a_router")
	var registered: Array = router.call("registered_ids")
	var pending: Array = []
	for id in router.call("ids"):
		if not registered.has(id):
			pending.append(String(id))
	print("SCREENS registered=%s pending=%s" % [JSON.stringify(registered), JSON.stringify(pending)])
	for id in registered:
		var screen_id := String(id)
		if which != "all" and which != screen_id:
			continue
		# A registered scene that is not a UIR-03 screen owns its own capture lane and
		# reads the same `--capture=` argument this harness uses: mounting it fires that
		# lane under our feet and it quits the run when it finishes (the ported Modes
		# screen did exactly that in a measured 01:24 run). The contract is therefore
		# checked on the scene, off-tree, before the router mounts anything.
		var scenes: Dictionary = router.get("_scenes") if router.get("_scenes") is Dictionary else {}
		var packed: PackedScene = scenes.get(screen_id)
		if packed != null:
			var probe: Node = packed.instantiate()
			var recreated: bool = probe is ScreenContract
			probe.free()
			if not recreated:
				print("note screen/%s pending: the recreation has not landed; it keeps its own capture lane" % screen_id)
				continue
		if not bool(router.call("go_to", screen_id)):
			_fail("screen/%s/mounted" % screen_id, "the router refused '%s'" % screen_id)
			continue
		_ok("screen/%s/mounted" % screen_id)
		for _i in SETTLE_FRAMES:
			await get_tree().process_frame
		var screen: Node = router.call("active_screen")
		var states := _states_of(screen)
		print("STATES screen=%s states=%s" % [screen_id, JSON.stringify(states)])
		for state_in in states:
			var state := String(state_in)
			if state != "default":
				if not screen.has_method("apply_capture_state") \
						or not bool(screen.call("apply_capture_state", state)):
					_refused.append("%s/%s" % [screen_id, state])
					print("note screen/%s/%s declared and refused" % [screen_id, state])
					continue
			for _i in SETTLE_FRAMES:
				await get_tree().process_frame
			var file := "ui-%s" % screen_id if state == "default" else "ui-%s-%s" % [screen_id, state]
			await _capture(file)
	_finish()


## The states a screen declares. A screen without the UIR-03 hooks (a scene the
## recreation has not rebuilt yet) has exactly the one state every screen has: the
## live one. That is reported, not guessed at.
func _states_of(screen: Node) -> Array:
	if screen != null and screen.has_method("capture_states"):
		var declared: Array = screen.call("capture_states")
		if not declared.is_empty():
			return declared
	return ["default"]


func _capture(file: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		_fail("capture/%s" % file, "the viewport produced no image")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OutDir))
	var path := "%s/%s.png" % [OutDir, file]
	var err := img.save_png(path)
	# Non-vacuous: a blank frame is the dummy driver's signature, and it samples as
	# a single colour. Sixteen points on a grid are enough to tell blank from drawn.
	var colours := {}
	var step_x := maxi(img.get_width() / SAMPLES, 1)
	var step_y := maxi(img.get_height() / SAMPLES, 1)
	var x := 0
	while x < img.get_width():
		var y := 0
		while y < img.get_height():
			colours[img.get_pixel(x, y).to_rgba32()] = true
			y += step_y
		x += step_x
	if colours.size() <= 1:
		_blank.append(file)
		_fail("blank/%s" % file, "the frame carries one colour (%d)" % colours.size())
		return
	if err != OK:
		_fail("capture/%s" % file, "save_png err=%d" % err)
		return
	_saved.append(path)
	_ok("capture/%s" % file)
	print("ok %s path=%s size=%dx%d colours=%d" % [file, path, img.get_width(), img.get_height(), colours.size()])


func _ok(name: String) -> void:
	print("ok %s" % name)
	_ok_count += 1


func _fail(name: String, why: String) -> void:
	print("FAIL %s: %s" % [name, why])
	_failures.append(name)


func _finish() -> void:
	print("# refused=%s" % JSON.stringify(_refused))
	print("# blank=%s" % JSON.stringify(_blank))
	print("# saved=%s" % JSON.stringify(_saved))
	var total := _ok_count + _failures.size()
	if _failures.is_empty():
		print("PASS %d/%d" % [_ok_count, total])
		get_tree().quit(0)
	else:
		print("FAIL %d/%d first=%s" % [_ok_count, total, String(_failures[0])])
		get_tree().quit(1)
