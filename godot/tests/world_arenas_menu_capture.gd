## world_arenas_menu_capture.gd — the RENDERED menu proof (round-2 review item):
## the real main menu, the only surface that offers the world chooser
## (`Main.tscn`'s ported legacy column, `--ui=legacy` shape), captured from the
## ACTUAL render viewport at 1280x720 with the world row gated present, visible
## and inside the frame, and the PNG hashed in-run.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path godot/ \
##     --rendering-driver opengl3 --resolution 1280x720 \
##     res://tests/world_arenas_menu_capture.tscn -- --out=/abs/path/to/captures
##
## Writes `<out>/menu/menu-world-chooser.png` + `<out>/menu_capture.json` and
## gates, in this order:
##   1. the display server is not headless (a dummy driver renders blank frames);
##   2. the run is a FULL build — the world chooser exists only there (a demo
##      offers none of the five by design, so this harness refuses to certify a
##      demo menu rather than photograph an empty row);
##   3. the real menu scene loads and builds its ported column (`MenuColumn`);
##   4. one `WorldArena_<id>` button per world arena: present, visible in tree,
##      non-empty rect, and the whole rect inside the 1280x720 frame (a cropped
##      or zero-sized chooser cannot pass);
##   5. the frame is the full render target at the documented size and is
##      non-vacuous (the blank-frame signature again);
##   6. the PNG is written and its bytes hash to the recorded SHA-256.
## The button rects and the colour sampled from the PNG at each button's centre
## are recorded in `menu_capture.json` as evidence, never used as a gate on
## theme colours.
##
## Machine-readable contract: `ok <name>` / `FAIL <name>: …` / `PASS n/n`, exit 0
## on PASS, 1 on FAIL, plus one `MENU_CAPTURE_RECORD …` line.
extends Node3D

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Gate := preload("res://game/content_gate.gd")

const MENU_SCENE := "res://game/Main.tscn"
const CAPTURE_SIZE := Vector2i(1280, 720)
const MIN_COLOURS := 8
const GRID_X := 64
const GRID_Y := 36

var _c := Common.new()
var _ran := false


func _ready() -> void:
	if _ran:
		return
	_ran = true
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	Common.banner("WORLD_ARENAS_MENU_CAPTURE")
	var out_root := _resolve_out(Common.arg(args, "--out", "user://world-arenas-captures"))
	var size := _size(args)
	print("# display=%s adapter=%s size=%s out=%s menu=%s" % [
		DisplayServer.get_name(), RenderingServer.get_video_adapter_name(), str(size), out_root, MENU_SCENE])
	_c.check("the display server is not headless (a dummy driver renders blank frames)",
		DisplayServer.get_name() != "headless", DisplayServer.get_name())
	_c.check("this is a FULL build: the world chooser exists only there (%s)" % Gate.label(),
		not Gate.is_demo(), Gate.label())
	DirAccess.make_dir_recursive_absolute(out_root)

	var packed: PackedScene = load(MENU_SCENE)
	if packed == null:
		_c.check("the real menu scene loads", false, MENU_SCENE)
		_finish(out_root, null)
		return
	var menu: Node = packed.instantiate()
	# The shape the slice and the UIR harnesses read: the ported column, with
	# `ui_legacy` set before the tree so `_ready()` builds it exactly as always.
	menu.set("ui_legacy", true)
	var host := Control.new()
	host.name = "MenuCaptureFrame"
	host.size = Vector2(size)
	add_child(host)
	host.add_child(menu)
	await _settle()
	var warmup := await _grab()
	if warmup == null:
		_c.check("the viewport produced an image", false, "no warm-up image")
		_finish(out_root, null)
		return
	var img := await _grab()
	if img == null:
		_c.check("the viewport produced an image", false, "no image")
		_finish(out_root, null)
		return
	var tex: ViewportTexture = get_viewport().get_texture()
	var tex_size: Vector2i = tex.get_size()

	# 3. The real menu and its ported column.
	var column := _find(menu, "MenuColumn")
	_c.check("the real menu (%s) built its ported column (MenuColumn)" % MENU_SCENE, column != null,
		str(column))

	# 4. The world chooser: one button per world arena, present + visible + inside.
	var ids := Common.WORLD_IDS
	var buttons: Dictionary = {}
	var missing: Array[String] = []
	var viewport := Vector2(size)
	var worst := INF
	for id_in in ids:
		var id := String(id_in)
		var button := _find(menu, "WorldArena_%s" % id) as Button
		if button == null:
			missing.append("%s: no WorldArena_ button" % id)
			continue
		var rect := button.get_global_rect()
		var margin := minf(minf(rect.position.x, rect.position.y), minf(viewport.x - rect.end.x, viewport.y - rect.end.y))
		worst = minf(worst, margin)
		var centre := rect.get_center()
		var colour := "#%08x" % img.get_pixel(
			clampi(int(round(centre.x)), 0, img.get_width() - 1),
			clampi(int(round(centre.y)), 0, img.get_height() - 1)).to_rgba32()
		buttons[id] = {
			"text": button.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"visible": button.visible and button.is_visible_in_tree(),
			"inside_frame": margin >= 0.0 and rect.size.x > 0.0 and rect.size.y > 0.0,
			"px_colour": colour,
		}
		if not (bool(buttons[id]["visible"]) and bool(buttons[id]["inside_frame"])):
			missing.append("%s: visible=%s inside=%s rect=%s" % [id, str(buttons[id]["visible"]), str(buttons[id]["inside_frame"]), str(buttons[id]["rect"])])
	_c.check("the world chooser shows one %s button per world arena, each visible and fully inside the frame" % "WorldArena_<id>",
		missing.is_empty() and buttons.size() == ids.size(),
		"missing=%s" % str(missing))

	# 5. Full render target, documented size, non-vacuous.
	_c.check("frame is the full render target %s (got %dx%d)" % [str(tex_size), img.get_width(), img.get_height()],
		img.get_width() == tex_size.x and img.get_height() == tex_size.y,
		"%dx%d vs target %dx%d" % [img.get_width(), img.get_height(), tex_size.x, tex_size.y])
	_c.check("capture size is the documented %dx%d (run with --resolution %dx%d)" % [size.x, size.y, size.x, size.y],
		img.get_width() == size.x and img.get_height() == size.y,
		"%dx%d" % [img.get_width(), img.get_height()])
	var colours: Dictionary = {}
	for gy in GRID_Y:
		for gx in GRID_X:
			colours[img.get_pixelv(Vector2i(gx * img.get_width() / GRID_X, gy * img.get_height() / GRID_Y)).to_rgba32()] = true
	_c.check("the frame is non-vacuous (%d colours on a %dx%d grid)" % [colours.size(), GRID_X, GRID_Y],
		colours.size() >= MIN_COLOURS, "%d colours" % colours.size())

	# 6. Save + hash.
	var rel := "menu/menu-world-chooser.png"
	var abs_path := out_root + "/" + rel
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	var sha := ""
	if err == OK and FileAccess.file_exists(abs_path):
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(FileAccess.get_file_as_bytes(abs_path))
		sha = ctx.finish().hex_encode()
	_c.check("the menu PNG is saved and hashed (%s)" % abs_path, err == OK and sha != "",
		"err=%d sha=%s" % [err, sha])
	print("MENU_CAPTURE_RECORD png=%s px=%dx%d colours=%d buttons=%d min_margin=%.1fpx sha256=%s" % [
		abs_path, img.get_width(), img.get_height(), colours.size(), buttons.size(), worst, sha])
	_finish(out_root, {
		"png": rel, "sha256": sha, "size": [img.get_width(), img.get_height()],
		"colours": colours.size(), "min_margin_px": worst, "buttons": buttons,
		"engine": Engine.get_version_info().get("string", "?"),
		"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"timestamp": Time.get_unix_time_from_system(),
	})


func _finish(out_root: String, record: Variant) -> void:
	if record != null:
		var payload := {
			"tool": "world_arenas_menu_capture.gd",
			"scene": MENU_SCENE,
			"engine": Engine.get_version_info().get("string", "?"),
			"display": DisplayServer.get_name(),
			"adapter": RenderingServer.get_video_adapter_name(),
			"record": record,
		}
		var f := FileAccess.open(out_root + "/menu_capture.json", FileAccess.WRITE)
		if f == null:
			_c.check("menu_capture.json written", false, "open failed")
		else:
			f.store_string(JSON.stringify(payload, "\t"))
			f.close()
			_c.check("menu_capture.json written", FileAccess.file_exists(out_root + "/menu_capture.json"),
				out_root + "/menu_capture.json")
	_c.verdict()
	get_tree().quit(_c.exit_code())


func _settle() -> void:
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	return tex.get_image() if tex != null else null


func _resolve_out(raw: String) -> String:
	if raw.begins_with("res://") or raw.begins_with("user://"):
		return ProjectSettings.globalize_path(raw)
	return raw


func _size(args: PackedStringArray) -> Vector2i:
	var raw := Common.arg(args, "--size", "")
	if raw == "":
		return CAPTURE_SIZE
	var parts := raw.split("x", false)
	if parts.size() != 2:
		return CAPTURE_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _find(from: Node, node_name: String) -> Node:
	for node in from.find_children("*", "", true, false):
		if String(node.name) == node_name:
			return node
	return null
