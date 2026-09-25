## fantasy_arenas_capture.gd — the rendered half of the six rebuilt arenas' proof: one PNG
## per real camera preset, plus a HUD-free WebP for the two arenas whose frames become UI
## previews, taken from the ACTUAL render viewport and verified in the same run.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path godot/ \
##     --rendering-driver opengl3 --resolution 1280x720 \
##     res://tests/fantasy_arenas_capture.tscn -- \
##     --arenas=cattedrale,forgia,tempesta,abissale,caldera,orrery \
##     --presets=default,courtside --out=/abs/path/to/captures
##
## WHY A REAL VIEWPORT. Plain `--headless` installs Godot's dummy rendering driver and every
## frame comes back blank, so this harness refuses to certify itself in that state and gates
## on the display server not being headless, on a non-vacuous frame, and on the frame being
## the FULL render target (a cropped image cannot pass).
##
## WHAT IS GATED, per capture (arena x preset):
##   1. the frame is the full render target;
##   2. the frame is non-vacuous, and within one preset the six arenas produce six different
##      signatures — six copies of one frame fail;
##   3. the framing mandate, measured through the LIVE camera at the real viewport size:
##      every court corner and every side/rear glass extent inside the frame;
##   4. the rebuilt environment is actually rendered: `FantasyEnvironment` present, its
##      legacy `Backdrop*`/`Dressing_*` nodes hidden, its dome visible at capture time.
##      Hiding the environment to make a frame pass is a detection, not a strategy.
##
## HUD-FREE. The capture build adds ONLY `Arena.build_into`, so nothing from the match HUD,
## scoreline or roster appears: these frames are court + environment, which is what the
## Cathedral/Forge preview slots and the review need.
##
## `CAPTURE_RECORD` lines carry the path, size, colour count and SHA-256 of every frame;
## `captures.json` in the output directory is the machine-readable record.
extends Node3D

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Fantasy := preload("res://game/arenas/fantasy_environment.gd")
const FantasyKit := preload("res://game/arenas/fantasy/fantasy_kit.gd")
const Court := preload("res://game/court.gd")

const CAPTURE_SIZE := Vector2i(1280, 720)
const MIN_COLOURS := 8
const GRID_X := 64
const GRID_Y := 36
## The two arenas whose default frame is also written as WebP for the UI preview slots.
const PREVIEW_WEBP := ["cattedrale", "forgia"]
const GLASS_CORE := ["GlassFar", "GlassFar2", "GlassFar3", "GlassFar4", "GlassFar5",
	"GlassFar6", "GlassLeft", "GlassRight", "GlassNear"]

var _c := Common.new()
var _records: Array = []
var _ran := false


func _ready() -> void:
	if _ran:
		return
	_ran = true
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	Common.banner("FANTASY_ARENAS_CAPTURE")
	var ids := _ids(args)
	var presets := _presets(args)
	var out_root := _resolve_out(Common.arg(args, "--out", "user://fantasy-arenas-captures"))
	var size := _size(args)
	print("# display=%s adapter=%s api=%s size=%s out=%s targets=%s presets=%s" % [
		DisplayServer.get_name(), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(), str(size), out_root, str(ids), str(presets)])
	_c.check("the display server is not headless (a dummy driver renders blank frames)",
		DisplayServer.get_name() != "headless", DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(out_root)

	var gating := Common.required_points()
	for preset in presets:
		var signatures := {}
		for id_in in ids:
			var id := String(id_in)
			if not Arena.has(id):
				_c.check("capture %s/%s: arena exists" % [preset, id], false, "not in the roster")
				continue
			await _capture_one(preset, id, out_root, size, gating, signatures)
		if ids.size() > 1:
			_c.check("preset %s: the captured arenas render differently (%d captures, %d distinct signatures)" % [
				preset, ids.size(), signatures.size()], signatures.size() == ids.size(),
				"%d distinct" % signatures.size())
	_c.check("every capture was written and recorded", _records.size() == ids.size() * presets.size(),
		"%d of %d" % [_records.size(), ids.size() * presets.size()])
	_write_json(out_root)
	print("CAPTURE_SUMMARY captures=%d log=%s" % [_records.size(), out_root + "/captures.json"])
	_c.verdict()
	get_tree().quit(_c.exit_code())


func _capture_one(preset: String, id: String, out_root: String, size: Vector2i,
		gating: Array, signatures: Dictionary) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var cam := Court.build_camera(holder, preset)
	var built := Arena.build_into(holder, id, preset)
	if built == null or cam == null:
		_c.check("capture %s/%s: builds" % [preset, id], false, "build returned null")
		remove_child(holder)
		holder.free()
		return
	var state := _environment_state(built, id)
	_c.check("capture %s/%s: the rebuilt environment is present, its legacy panel is hidden, its dome is visible" % [preset, id],
		bool(state["env_present"]) and bool(state["legacy_hidden"]) and bool(state["dome_visible"]), str(state))
	var glass_ok := true
	for nm in GLASS_CORE:
		var node := built.find_child(nm, true, false)
		if node == null or not (node as Node3D).visible:
			glass_ok = false
	_c.check("capture %s/%s: the glass cage is intact and visible at capture time" % [preset, id],
		glass_ok, "missing or hidden pane")

	await _settle()
	var _warm := await _grab()
	var img := await _grab()
	if img == null:
		_c.check("capture %s/%s: the viewport produced an image" % [preset, id], false, "no image")
		remove_child(holder)
		holder.free()
		return
	var tex_size: Vector2i = get_viewport().get_texture().get_size()
	var viewport := Vector2(get_viewport().get_visible_rect().size)
	_c.check("capture %s/%s: frame is the full render target %s (got %dx%d)" % [
		preset, id, str(tex_size), img.get_width(), img.get_height()],
		img.get_width() == tex_size.x and img.get_height() == tex_size.y,
		"%dx%d vs %dx%d" % [img.get_width(), img.get_height(), tex_size.x, tex_size.y])

	var colours: Dictionary = {}
	var signature := ""
	for gy in GRID_Y:
		for gx in GRID_X:
			var c := img.get_pixel(gx * img.get_width() / GRID_X, gy * img.get_height() / GRID_Y)
			colours[c.to_rgba32()] = true
			if gx % 2 == 0 and gy % 2 == 0:
				signature += "%08x" % c.to_rgba32()
	_c.check("capture %s/%s: the frame is non-vacuous (%d colours on a %dx%d grid)" % [
		preset, id, colours.size(), GRID_X, GRID_Y], colours.size() >= MIN_COLOURS,
		"%d colours" % colours.size())
	signatures[signature] = id

	var outside: Array[String] = []
	var worst := INF
	var worst_name := ""
	for point in gating:
		var res := Common.project_point(cam, viewport, point["at"])
		if not bool(res["inside"]):
			outside.append(String(point["name"]))
		if float(res["margin"]) < worst:
			worst = float(res["margin"])
			worst_name = String(point["name"])
	_c.check("capture %s/%s: all court corners + side/rear glass extents inside the frame" % [preset, id],
		outside.is_empty(), "outside=%s" % str(outside))

	var rel := "%s/arena-%s.png" % [preset, id]
	var abs_path := out_root + "/" + rel
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	var sha := ""
	if err == OK and FileAccess.file_exists(abs_path):
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(FileAccess.get_file_as_bytes(abs_path))
		sha = ctx.finish().hex_encode()
	_c.check("capture %s/%s: PNG saved and hashed (%s)" % [preset, id, abs_path],
		err == OK and sha != "", "err=%d sha=%s" % [err, sha])

	# The HUD-free preview pair: the same frame, written as WebP so the root can drop it
	# straight into an `assets/ui/arenas/*.webp` slot with no image tooling in between.
	var webp_path := ""
	if preset == "default" and PREVIEW_WEBP.has(id):
		webp_path = "%s/preview-%s.webp" % [out_root, id]
		var werr := img.save_webp(webp_path, true, 0.92)
		_c.check("capture %s/%s: HUD-free WebP preview written for the UI slot (%s)" % [preset, id, webp_path],
			werr == OK and FileAccess.file_exists(webp_path), "err=%d" % werr)
		if werr != OK:
			webp_path = ""

	_records.append({
		"preset": preset, "arena": id, "png": rel, "webp": webp_path, "sha256": sha,
		"size": [img.get_width(), img.get_height()], "colours": colours.size(),
		"signature": signature, "min_margin_px": worst, "worst_point": worst_name,
		"environment": state,
		"budget": FantasyKit.budget(built.get_node_or_null(Fantasy.ROOT_NAME)),
		"engine": Engine.get_version_info().get("string", "?"),
		"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"timestamp": Time.get_unix_time_from_system(),
	})
	print("CAPTURE_RECORD preset=%s arena=%s png=%s px=%dx%d colours=%d min_margin=%.1fpx(%s) webp=%s sha256=%s" % [
		preset, id, abs_path, img.get_width(), img.get_height(), colours.size(), worst, worst_name,
		webp_path, sha])
	remove_child(holder)
	holder.free()


## The rebuilt environment's own state at capture time.
func _environment_state(built: Node3D, id: String) -> Dictionary:
	var env := built.get_node_or_null(Fantasy.ROOT_NAME)
	var legacy_hidden := true
	var legacy_seen := 0
	var scenery := built.get_node_or_null("Scenery")
	if scenery == null:
		legacy_hidden = false
	else:
		for child in scenery.get_children():
			var nm := String(child.name)
			if nm.begins_with("Backdrop") or nm.begins_with("Dressing_"):
				legacy_seen += 1
				if child is Node3D and (child as Node3D).visible:
					legacy_hidden = false
	var dome_visible := false
	if env != null:
		var dome_name := "StarShell" if id == "orrery" else "Dome"
		var dome := env.get_node_or_null(dome_name)
		dome_visible = dome != null and (dome as Node3D).visible
	return {
		"env_present": env != null, "legacy_nodes": legacy_seen,
		"legacy_hidden": legacy_hidden, "dome_visible": dome_visible,
		"multimesh_nodes": int(FantasyKit.multimesh_report(env)["nodes"]) if env != null else 0,
	}


func _settle() -> void:
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	return tex.get_image() if tex != null else null


func _write_json(out_root: String) -> void:
	var payload := {
		"tool": "fantasy_arenas_capture.gd",
		"engine": Engine.get_version_info().get("string", "?"),
		"display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"capture_size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"records": _records,
	}
	var f := FileAccess.open(out_root + "/captures.json", FileAccess.WRITE)
	if f == null:
		_c.check("captures.json written", false, "open failed")
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	_c.check("captures.json written (%d records)" % _records.size(),
		FileAccess.file_exists(out_root + "/captures.json"), out_root + "/captures.json")


func _resolve_out(raw: String) -> String:
	if raw.begins_with("res://") or raw.begins_with("user://"):
		return ProjectSettings.globalize_path(raw)
	return raw


func _ids(args: PackedStringArray) -> Array:
	var raw := Common.arg(args, "--arenas", "")
	if raw == "":
		var all: Array = []
		for id in Fantasy.IDS:
			all.append(String(id))
		return all
	var out: Array = []
	for piece in raw.split(",", false):
		var id := piece.strip_edges()
		if id != "":
			out.append(id)
	return out


func _presets(args: PackedStringArray) -> Array:
	var raw := Common.arg(args, "--presets", "")
	if raw == "":
		return ["default", "courtside"]
	var out: Array = []
	for piece in raw.split(",", false):
		var p := piece.strip_edges()
		if p != "":
			out.append(p)
	return out


func _size(args: PackedStringArray) -> Vector2i:
	var raw := Common.arg(args, "--size", "")
	if raw == "":
		return CAPTURE_SIZE
	var parts := raw.split("x", false)
	if parts.size() != 2:
		return CAPTURE_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))
