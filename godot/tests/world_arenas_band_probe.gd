## world_arenas_band_probe.gd — the integrator's diagnostic for the round-2 review
## note "band() playable pitch mismatch" (NOT a gate; run_proof.sh does not call it).
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##     --script res://tests/world_arenas_band_probe.gd
##
## THE QUESTION, stated precisely. `ArenaScenery.band()` derives the scenery band
## from the preset's `pitch_deg` with a pure-pitch closed form. `Court.build_camera`
## orientates the "default" and "wide" cameras with `rotation_degrees =
## (pitch_deg, 0, 0)` — the closed form's assumption — but the "playable" camera
## with `look_at(0, 0.9, -1)`, i.e. a pitch of about -21.5 deg while the table
## says `pitch_deg: 0.0`. `integrator-check.py` records this ("the closed form is
## for a pure-pitch camera; look_at needs the basis") and skips the playable
## round-trip. This probe measures, per preset, what band() claims against what
## the LIVE camera actually requires:
##   live_pitch      — the built camera's real pitch (`global_rotation.x`);
##   required_top    — world y where the frame's top-centre ray crosses the wall
##                     plane z = BACKDROP_Z, through `project_ray_normal`;
##   required_half_x — the widest |x| of any frame-edge ray crossing that plane at
##                     or above the ground;
##   margins         — band top/half_x minus what the live camera requires.
## Output: `# BAND_PROBE ...` lines only. Read-only: builds cameras, writes nothing.
extends SceneTree

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Court := preload("res://game/court.gd")

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var viewport := Vector2(root.get_visible_rect().size)
	var z := Common.backdrop_wall_z()
	print("# BAND_PROBE wall_plane_z=%.2f law_z=%.1f viewport=%s" % [z, Common.BACKDROP_Z_LAW, str(viewport)])
	for preset in ["default", "wide", "playable"]:
		_probe(String(preset), viewport, z)
	quit(0)


func _probe(preset: String, viewport: Vector2, z: float) -> void:
	if not Court.CAMERAS.has(preset):
		print("# BAND_PROBE preset=%s: not a camera preset" % preset)
		return
	var cfg: Dictionary = Court.CAMERAS[preset]
	var holder := Node3D.new()
	root.add_child(holder)
	var cam := Court.build_camera(holder, preset)
	var band: Dictionary = Arena.band(preset, z)
	var live := Common.live_band_requirement(cam, viewport, z)
	var live_pitch := rad_to_deg(cam.global_rotation.x)
	print("# BAND_PROBE preset=%-8s cfg_pos=%s cfg_pitch=%+.2f cfg_fov=%.2f look_at=%s" % [
		preset, str(cfg.get("pos", "?")), float(cfg.get("pitch_deg", 0.0)),
		float(cfg.get("fov", 0.0)), str(cfg.get("look_at", "<none>"))])
	print("# BAND_PROBE preset=%-8s live_pitch=%+.2f band_top=%.2f required_top=%.2f margin_top=%+.2f" % [
		preset, live_pitch, float(band["top"]), float(live["required_top"]),
		float(band["top"]) - float(live["required_top"])])
	print("# BAND_PROBE preset=%-8s band_half_x=%.2f required_half_x=%.2f margin_half_x=%+.2f prop_half_x=%.2f crossed=%s samples=%d" % [
		preset, float(band["half_x"]), float(live["required_half_x"]),
		float(band["half_x"]) - float(live["required_half_x"]), float(band["prop_half_x"]),
		str(live["crossed"]), int(live["samples"])])
	root.remove_child(holder)
	holder.free()
