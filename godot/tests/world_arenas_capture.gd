## world_arenas_capture.gd — the RENDERED half of the world-arena proof: one PNG
## per arena per real camera preset, captured from the ACTUAL render viewport and
## verified in the same run.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path godot/ \
##     --rendering-driver opengl3 --resolution 1280x720 \
##     res://tests/world_arenas_capture.tscn -- \
##     --arenas=torii,medina,carioca,aurora,egeo --presets=default,wide,playable \
##     --out=/abs/path/to/run/captures
##
## WHY A REAL VIEWPORT. Plain `--headless` installs Godot's dummy rendering driver
## and every frame comes back blank; this harness therefore refuses to certify
## itself in that state: it gates on the display server not being `headless`, on a
## non-vacuous frame (a grid sample of one colour is the blank frame's signature)
## and on the frame being the FULL render target (a cropped image cannot pass).
##
## WHAT IS GATED HERE, per capture (arena x preset):
##   1. the frame is the full render target and exactly the requested capture size
##      — no crop, no re-scale;
##   2. the frame is non-vacuous and arena-distinct: a 64x36 colour sample doubles
##      as richness (>= 8 colours) and, within one preset, the five arenas must
##      produce five different signatures — five copies or one blank frame fail;
##   3. the framing mandate, measured through the LIVE camera at the real viewport
##      size: every court corner and every side/rear glass extent inside the frame
##      (behind-camera = fail). The projected pixels of those points are SAMPLED
##      from the written PNG and recorded (evidence, not a gate);
##   4. the glass cage is intact AND VISIBLE at capture time — every `Glass*` mesh
##      visible with its built alpha (rear panes == `Arena.rear_alpha(id)`, side
##      walls == `CourtBuilder.SIDE_ALPHA`), every scenery mesh visible. Hiding
##      glass or scenery to make a frame pass is a detection, not a strategy.
##
## The written PNGs are hashed in-run (SHA-256) and recorded with their projected
## points into `captures.json`, which `tools/world-arenas/build_manifest.py` folds
## into the frozen manifest after the integrator's arenas land.
##
## Machine-readable contract: `ok <name>` / `FAIL <name>: …` / `PASS n/n`, exit 0
## on PASS, 1 on FAIL, plus `CAPTURE_RECORD …` lines per saved frame.
extends Node3D

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Court := preload("res://game/court.gd")
const CourtBuilder := preload("res://game/arenas/court_builder.gd")

## The documented capture size. A run whose render target differs fails instead of
## silently producing a differently-sized evidence set.
const CAPTURE_SIZE := Vector2i(1280, 720)
## A frame whose 64x36 grid samples into fewer than this many colours is treated
## as vacuous (a blank frame samples one; a real arena frame samples hundreds).
const MIN_COLOURS := 8
const GRID_X := 64
const GRID_Y := 36
const SIG_X := 32
const SIG_Y := 18
## The core glass nodes whose presence and visibility every capture attests.
const GLASS_CORE := ["GlassFar", "GlassFar2", "GlassFar3", "GlassFar4", "GlassFar5",
	"GlassFar6", "GlassFarRail", "GlassFarRailHilite", "GlassFarBottom",
	"GlassLeft", "GlassRight", "GlassNear"]
const REAR_PANES := ["GlassFar", "GlassFar2", "GlassFar3", "GlassFar4", "GlassFar5", "GlassFar6"]

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
	Common.banner("WORLD_ARENAS_CAPTURE")
	var ids := Common.target_ids(args)
	var presets := _presets(args)
	var out_root := _resolve_out(Common.arg(args, "--out", "user://world-arenas-captures"))
	var size := _size(args)
	print("# display=%s adapter=%s api=%s size=%s out=%s targets=%s presets=%s" % [
		DisplayServer.get_name(), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(), str(size), out_root, str(ids), str(presets)])
	# A dummy/headless renderer cannot produce evidence: refuse by name, not by hope.
	_c.check("the display server is not headless (a dummy driver renders blank frames)",
		DisplayServer.get_name() != "headless", DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(out_root)

	var gating := Common.required_points()
	var textures := {}
	for preset in presets:
		var signatures := {}
		for id_in in ids:
			var id := String(id_in)
			if not Arena.has(id):
				_c.check("capture %s/%s: arena exists" % [preset, id], false, "not in the frozen roster")
				continue
			var ok := await _capture_one(preset, id, out_root, size, gating, signatures)
			if not ok:
				continue
			textures[preset] = textures.get(preset, 0) + 1
		var recorded: Array = []
		for s in signatures:
			recorded.append(String(s))
		if ids.size() > 1:
			_c.check("preset %s: the captured arenas render differently (%d captures, %d distinct signatures)" % [
				preset, ids.size(), signatures.size()],
				signatures.size() == ids.size(), "%d distinct: %s" % [signatures.size(), str(recorded)])

	_c.check("every capture was written and recorded", _records.size() == ids.size() * presets.size(),
		"%d of %d" % [_records.size(), ids.size() * presets.size()])
	_write_json(out_root)
	print("CAPTURE_SUMMARY captures=%d log=%s" % [_records.size(), out_root + "/captures.json"])
	_c.verdict()
	get_tree().quit(_c.exit_code())


## One arena x preset capture. Returns false when the arena could not be built (the
## checks above already reported it); the checks themselves are inside.
func _capture_one(preset: String, id: String, out_root: String, size: Vector2i,
		gating: Array, signatures: Dictionary) -> bool:
	var holder := Node3D.new()
	add_child(holder)
	var cam := Court.build_camera(holder, preset)
	var built := Arena.build_into(holder, id, preset)
	if built == null or cam == null:
		_c.check("capture %s/%s: builds" % [preset, id], false, "build returned null")
		remove_child(holder)
		holder.free()
		return false
	# What the glass and scenery look like at the moment of capture: recorded, and
	# gated, so a frame that passes with anything hidden is impossible.
	var glass := _glass_state(built, id)
	_c.check("capture %s/%s: every glass pane and scenery mesh is visible at capture time" % [preset, id],
		bool(glass["core_present"]) and bool(glass["all_visible"]), str(glass))
	_c.check("capture %s/%s: rear pane alpha is the arena's own (%.3f), side walls at %.3f" % [
		preset, id, float(glass["rear_alpha"]), float(CourtBuilder.SIDE_ALPHA)],
		absf(float(glass["rear_alpha"]) - float(glass["expected_rear_alpha"])) < 0.0001
		and absf(float(glass["side_alpha"]) - CourtBuilder.SIDE_ALPHA) < 0.0001 and float(glass["rear_alpha"]) > 0.0,
		str(glass))

	await _settle()
	var warmup := await _grab()
	if warmup == null:
		_c.check("capture %s/%s: the viewport produced an image" % [preset, id], false, "no warm-up image")
		remove_child(holder)
		holder.free()
		return false
	var img := await _grab()
	if img == null:
		_c.check("capture %s/%s: the viewport produced an image" % [preset, id], false, "no image")
		remove_child(holder)
		holder.free()
		return false
	var tex: ViewportTexture = get_viewport().get_texture()
	var tex_size: Vector2i = tex.get_size()
	var viewport := Vector2(get_viewport().get_visible_rect().size)

	# 1. Full render target, exact capture size: no crop.
	_c.check("capture %s/%s: frame is the full render target %s (got %dx%d)" % [
		preset, id, str(tex_size), img.get_width(), img.get_height()],
		img.get_width() == tex_size.x and img.get_height() == tex_size.y,
		"%dx%d vs target %dx%d" % [img.get_width(), img.get_height(), tex_size.x, tex_size.y])
	_c.check("capture %s/%s: capture size is the documented %dx%d (run with --resolution %dx%d)" % [
		preset, id, size.x, size.y, size.x, size.y],
		img.get_width() == size.x and img.get_height() == size.y,
		"%dx%d" % [img.get_width(), img.get_height()])

	# 2. Non-vacuous + signature.
	var colours: Dictionary = {}
	var signature := ""
	for gy in GRID_Y:
		for gx in GRID_X:
			var px := Vector2i(gx * img.get_width() / GRID_X, gy * img.get_height() / GRID_Y)
			var c := img.get_pixelv(px)
			colours[c.to_rgba32()] = true
			if gx % 2 == 0 and gy % 2 == 0:
				signature += "%08x" % c.to_rgba32()
	_c.check("capture %s/%s: the frame is non-vacuous (%d colours on a %dx%d grid)" % [
		preset, id, colours.size(), GRID_X, GRID_Y],
		colours.size() >= MIN_COLOURS, "%d colours" % colours.size())
	signatures[signature] = id

	# 3. The framing mandate through the LIVE camera at the real viewport, with the
	#    projected pixel sampled from the PNG for the record.
	var points: Array = []
	var outside: Array[String] = []
	var worst := INF
	var worst_name := ""
	for point in gating:
		var res := Common.project_point(cam, viewport, point["at"])
		var entry := {
			"name": point["name"], "px": [res["px"].x, res["px"].y],
			"margin": res["margin"], "inside": res["inside"], "behind": res["behind"],
			"colour": "",
		}
		if bool(res["inside"]):
			var sx := clampi(int(round(res["px"].x)), 0, img.get_width() - 1)
			var sy := clampi(int(round(res["px"].y)), 0, img.get_height() - 1)
			entry["colour"] = "#%08x" % img.get_pixel(sx, sy).to_rgba32()
		else:
			outside.append(String(point["name"]))
		if float(res["margin"]) < worst:
			worst = float(res["margin"])
			worst_name = String(point["name"])
		points.append(entry)
	_c.check("capture %s/%s: all court corners + side/rear glass extents inside the frame" % [preset, id],
		outside.is_empty(), "outside=%s" % str(outside))

	# 4. Save + hash. The per-preset directory is created HERE: the run's own
	#    `out_root` only makes the root (`_run`), `Image.save_png` does not create
	#    parent directories, and a missing one is err=7 for every frame — the
	#    first two runs recorded 15 captures with no bytes on disk.
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

	_records.append({
		"preset": preset, "arena": id, "png": rel, "sha256": sha,
		"size": [img.get_width(), img.get_height()],
		"colours": colours.size(), "signature": signature,
		"min_margin_px": worst, "worst_point": worst_name,
		"glass": glass, "points": points,
		"engine": Engine.get_version_info().get("string", "?"),
		"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"timestamp": Time.get_unix_time_from_system(),
	})
	print("CAPTURE_RECORD preset=%s arena=%s png=%s px=%dx%d colours=%d min_margin=%.1fpx(%s) sha256=%s" % [
		preset, id, abs_path, img.get_width(), img.get_height(), colours.size(), worst, worst_name, sha])
	remove_child(holder)
	holder.free()
	return true


## The glass/scenery visibility snapshot for one built arena, taken at capture time.
func _glass_state(built: Node3D, id: String) -> Dictionary:
	var core_present := true
	var all_visible := true
	var rear_alpha := -1.0
	var side_alpha := -1.0
	var glass_count := 0
	for node in built.find_children("Glass*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		glass_count += 1
		if not mi.visible:
			all_visible = false
		if REAR_PANES.has(String(mi.name)):
			var mat := mi.material_override as StandardMaterial3D
			rear_alpha = mat.albedo_color.a if mat != null else -1.0
	for name in GLASS_CORE:
		if built.find_child(name, true, false) == null:
			core_present = false
	var side := built.find_child("GlassLeft", true, false) as MeshInstance3D
	if side != null and side.material_override is StandardMaterial3D:
		side_alpha = (side.material_override as StandardMaterial3D).albedo_color.a
	var scenery: Node = built.get_node_or_null("Scenery")
	if scenery != null:
		for node in scenery.find_children("*", "MeshInstance3D", true, false):
			if not (node as MeshInstance3D).visible:
				all_visible = false
	else:
		all_visible = false
	return {
		"count": glass_count, "core_present": core_present, "all_visible": all_visible,
		"rear_alpha": rear_alpha, "expected_rear_alpha": Arena.rear_alpha(id),
		"side_alpha": side_alpha, "scenery_visible": scenery != null,
	}


## Let the freshly built tree draw a few frames before anything is measured: the
## first frames after a build can still carry a compiling material. The warm-up
## frame is DISCARDED; the frame that is checked and written is the settled one.
func _settle() -> void:
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	return tex.get_image() if tex != null else null


func _write_json(out_root: String) -> void:
	var payload := {
		"tool": "world_arenas_capture.gd",
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


func _presets(args: PackedStringArray) -> Array:
	var raw := Common.arg(args, "--presets", "")
	if raw == "":
		return ["default", "wide", "playable"]
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
