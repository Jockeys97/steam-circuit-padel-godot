## ui_visibility_capture.gd — the visual captures for the UI visibility bundle.
##
##   /opt/homebrew/bin/godot --path godot --rendering-driver opengl3 \
##     --resolution 1280x720 res://tests/ui/ui_visibility_capture.tscn \
##     -- --out=<dir>
##
## Three frames, written as PNGs straight into the bundle's evidence directory:
##
##   1. the fourth pause tab (`UI`) at the design frame;
##   2. the clean-view restore hint at 1280x720 (live play, card closed);
##   3. the same pause tab at the port's narrow supported frame (1152x648).
##
## The captures come from the real viewport (a real window context: plain
## `--headless` renders blank PNGs through the dummy driver), and each frame is
## checked non-vacuous here instead of being trusted because the file exists —
## `capture_ui.gd`'s own rule.
extends Control

const MATCH_SCENE := preload("res://game/Match.tscn")
const SETTLE_FRAMES := 4

var _out_dir := ""
var _saved: Array = []
var _failures: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_out_dir = _arg(OS.get_cmdline_user_args(), "--out=", "res://game/out")
	print("CAPTURE_UI_VISIBILITY_START out=%s frame=%s" % [_out_dir, str(get_viewport_rect().size)])
	var node: Node = MATCH_SCENE.instantiate()
	node.harness_mode()
	add_child(node)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	node.start_match()
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame

	# 1. The UI tab, at the design frame.
	node.call("set_match_paused", true)
	var overlay: Node = node.get_node_or_null("HudLayer/PauseOverlay")
	if overlay == null:
		_fail("tab/no_pause_card")
	else:
		overlay.call("set_tab", "ui")
		await _capture("ui-visibility-tab-1280x720")

	# 2. The restore hint, in clean live play with the card closed.
	node.call("set_match_paused", false)
	node.call("set_hud_hidden", true)
	await _capture("ui-visibility-hint-1280x720")

	# 3. The same tab at the port's narrow supported frame (1152x648).
	DisplayServer.window_set_size(Vector2i(1152, 648))
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	node.call("set_hud_hidden", false)
	node.call("set_match_paused", true)
	if overlay != null:
		overlay.call("set_tab", "ui")
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _capture("ui-visibility-tab-1152x648")

	print("# saved=%s" % JSON.stringify(_saved))
	if _failures.is_empty():
		print("PASS %d/%d" % [_saved.size(), _saved.size()])
		get_tree().quit(0)
	else:
		print("FAIL 0/%d first=%s" % [_failures.size(), String(_failures[0])])
		get_tree().quit(1)


func _arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


func _capture(file: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		_fail(file + ": no image")
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var path := "%s/%s.png" % [_out_dir, file]
	var err := img.save_png(path)
	var colours := {}
	var step := maxi(img.get_width() / 16, 1)
	var y_step := maxi(img.get_height() / 16, 1)
	var x := 0
	while x < img.get_width():
		var y := 0
		while y < img.get_height():
			colours[img.get_pixel(x, y).to_rgba32()] = true
			y += y_step
		x += step
	if colours.size() <= 1:
		_fail(file + ": blank frame")
		return
	if err != OK:
		_fail(file + ": save_png err=%d" % err)
		return
	_saved.append(path)
	print("ok %s path=%s size=%dx%d colours=%d" % [file, path, img.get_width(), img.get_height(), colours.size()])


func _fail(why: String) -> void:
	_failures.append(why)
	print("FAIL %s" % why)
