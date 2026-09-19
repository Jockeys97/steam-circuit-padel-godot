## arena_kit_specs_dump.gd — the pre-viz lane's headless PROBE: prints the arena kit's own
## placement contract as JSON on stdout, so `tools/arena-kit/previz_2d.py` never hand-copies a
## number out of `godot/game/arenas/arena_kit.gd` (the brief's "no invention" gate).
##
## Run (ONE Godot process at a time — guard with `pgrep -x Godot` first):
##
##   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
##   $GODOT --headless --path godot/ --script res://tests/arena_kit_specs_dump.gd
##     > docs/mission/arena-kit/arena-props/previz/arena_kit_specs_dump.log 2>&1
##
## The JSON body sits between the markers `SPECS_JSON_BEGIN` / `SPECS_JSON_END`; everything
## outside them is engine boot noise. Exit 0 = dumped, 2 = the project's own kit script could
## not be loaded (a real failure, never a silent empty table).
##
## WHAT IS IN IT. The five x ten `SPECS` table exactly as the engine holds it (anchor,
## target_h, repeats, spread, depth, footprint, suppress, kinds), the load-bearing constants
## beside it (FIELD_LAW_Z, GLASS_PLANE_Z, PROP_Z, DEPTH_BUDGET, AUTHORED_HALF_X), the court
## geometry the plan draws its outline from (`game/court.gd` — what `court_builder.gd` builds
## the bed and the lines from; `tests/world_arenas_common.gd` only re-states it), the running
## frame the spec table is authored for (`arena_scenery.gd::band("default", BACKDROP_Z)` and
## its `x_scale`), and, per slot, the DERIVED placement facts the plan draws:
##
##   * the repeat instances' centres, using `arena_kit.gd::mount_slot()`'s own formula
##     `x_i = (anchor.x + (i - (repeats - 1) * 0.5) * spread) * x_scale`, z unchanged.
##     The dump keeps BOTH frames explicitly, because they differ: `ax` is the authored
##     x (the spec table's own metres, the frame `AUTHORED_HALF_X` = 14.35 bounds) and
##     `cx` is the world x the engine actually mounts at (`ax * x_scale`; at the default
##     camera preset the running frame is `prop_half_x` = 19.283 m wide, so
##     `x_scale` = 1.34375 and a world metre on x is 0.744 authored metres).
##   * the footprint's front/back world z (`anchor.z ± depth * 0.5`, z is never scaled)
##     and its x extent (W parsed out of the footprint note, checked against the spec's
##     own `target_h` / `depth` — H and D must match, or the note is reported as unparsed).
##   * the verdicts the plan must show honestly: field law (front z <= -8.0), measured
##     rear glass (front z <= -10.02), depth budget, authored frame law for the repeat
##     run and for the drawn rectangle, and the same rectangle in world x against the
##     built frame.
##
## Nothing here writes to disk or touches an asset: it reads scripts, prints, quits.
extends SceneTree

const ARENAS := ["torii", "medina", "carioca", "aurora", "egeo"]


func _initialize() -> void:
	var kit: GDScript = load("res://game/arenas/arena_kit.gd")
	if kit == null:
		print("PROBE_ERROR cannot load res://game/arenas/arena_kit.gd")
		quit(2)
		return
	var court: GDScript = load("res://game/court.gd")
	var scenery: GDScript = load("res://game/arenas/arena_scenery.gd")
	var frame := _frame(scenery, kit)
	var out := {
		"probe": "res://tests/arena_kit_specs_dump.gd",
		"godot": String(Engine.get_version_info()["string"]),
		"project": ProjectSettings.globalize_path("res://"),
		"arena_kit_path": "res://game/arenas/arena_kit.gd",
		"constants": _constants(kit),
		"court": _court(court),
		"frame": frame,
		"arenas": _arenas(kit, frame),
	}
	out["instance_totals"] = _totals(out["arenas"])
	print("SPECS_JSON_BEGIN")
	print(JSON.stringify(out, "  "))
	print("SPECS_JSON_END")
	quit(0)


func _constants(kit: GDScript) -> Dictionary:
	return {
		"FIELD_LAW_Z": float(kit.FIELD_LAW_Z),
		"GLASS_PLANE_Z": float(kit.GLASS_PLANE_Z),
		"PROP_Z": float(kit.PROP_Z),
		"DEPTH_BUDGET": float(kit.DEPTH_BUDGET),
		"AUTHORED_HALF_X": float(kit.AUTHORED_HALF_X),
		"KIT_DIR": String(kit.KIT_DIR),
		"SLOTS": (kit.SLOTS as Array).duplicate(),
		"ARENAS": (kit.ARENAS as Array).duplicate(),
	}


## The court the plan's outline is read from: `game/court.gd` is what `court_builder.gd`
## builds the bed and the lines from (`court_len()` x `court_depth()`, x and z), so it is
## the authoritative geometry here.
func _court(court: GDScript) -> Dictionary:
	if court == null:
		return {"error": "res://game/court.gd did not load"}
	return {
		"source": "res://game/court.gd",
		"width_m": float(court.WIDTH_M),
		"length_m": float(court.LENGTH_M),
		"court_len_x": float(court.court_len()),
		"court_depth_z": float(court.court_depth()),
		"half_len_x": float(court.half_len()),
		"half_depth_z": float(court.half_depth()),
		"service_z": float(court.service_z()),
		"net_h": float(court.net_h()),
		"glass_h": float(court.GLASS_H),
		"center_line_len_z": 2.0 * (float(court.service_z()) + 0.2),
	}


## The frame the spec table is authored for: the default camera preset's own band (the
## `arena_scenery.gd::build()` extent it computes before placing props). `x_scale` is the
## factor `arena_kit.gd::mount_slot()` and every `Dressing_*` container scale x by; the
## built frame's half-width is `prop_half_x`, and `AUTHORED_HALF_X` = 14.35 is the authored
## half-span the tables were written against (`x_scale == 1.0` only where they coincide).
func _frame(scenery: GDScript, kit: GDScript) -> Dictionary:
	if scenery == null:
		return {"preset": "default", "error": "res://game/arenas/arena_scenery.gd did not load", "x_scale": 1.0}
	var extent: Dictionary = scenery.band("default", scenery.BACKDROP_Z)
	return {
		"preset": "default",
		"backdrop_z": float(scenery.BACKDROP_Z),
		"prop_half_x": float(extent["prop_half_x"]),
		"half_x": float(extent["half_x"]),
		"top": float(extent["top"]),
		"x_scale": float(extent["prop_half_x"]) / float(kit.AUTHORED_HALF_X),
	}


func _arenas(kit: GDScript, frame: Dictionary) -> Array:
	var out: Array = []
	for arena_id in ARENAS:
		var slots: Array = []
		var total := 0
		for slot in (kit.SLOTS as Array):
			var entry := _slot(kit, String(arena_id), String(slot), frame)
			if entry.is_empty():
				continue
			total += int(entry["repeats"])
			slots.append(entry)
		out.append({"id": String(arena_id), "slots": slots, "instances_total": total})
	return out


func _slot(kit: GDScript, arena_id: String, slot: String, frame: Dictionary) -> Dictionary:
	var spec: Dictionary = kit.spec(arena_id, slot)
	if spec.is_empty():
		return {}
	var x_scale := float(frame.get("x_scale", 1.0))
	var prop_half_x := float(frame.get("prop_half_x", float(kit.AUTHORED_HALF_X)))
	var anchor: Vector3 = spec["anchor"]
	var repeats := int(spec["repeats"])
	var spread := float(spec["spread"])
	var depth := float(spec["depth"])
	var target_h := float(spec["target_h"])
	var parsed := _parse_footprint(String(spec["footprint"]))
	var w: float = float(parsed.get("w", 0.0))
	var front_z := anchor.z + depth * 0.5
	var back_z := anchor.z - depth * 0.5
	var run_half_x := float(repeats - 1) * 0.5 * spread
	var instances: Array = []
	var rect_authored_ok := true
	var rect_world_ok := true
	for i in repeats:
		var ax: float = anchor.x + (float(i) - float(repeats - 1) * 0.5) * spread
		var cx: float = ax * x_scale
		var ax_min: float = ax - w * 0.5
		var ax_max: float = ax + w * 0.5
		var cx_min: float = cx - w * 0.5
		var cx_max: float = cx + w * 0.5
		if absf(ax_min) > float(kit.AUTHORED_HALF_X) or absf(ax_max) > float(kit.AUTHORED_HALF_X):
			rect_authored_ok = false
		if absf(cx_min) > prop_half_x or absf(cx_max) > prop_half_x:
			rect_world_ok = false
		instances.append({
			"i": i + 1,
			"ax": ax,
			"cx": cx,
			"cz": anchor.z,
			"front_z": front_z,
			"back_z": back_z,
			"ax_min": ax_min,
			"ax_max": ax_max,
			"x_min": cx_min,
			"x_max": cx_max,
		})
	return {
		"slot": slot,
		"anchor": {"x": anchor.x, "y": anchor.y, "z": anchor.z},
		"target_h": target_h,
		"repeats": repeats,
		"spread": spread,
		"depth": depth,
		"footprint": String(spec["footprint"]),
		"footprint_parsed": parsed,
		"footprint_matches_spec": bool(parsed.get("matches", false)),
		"suppress": bool(spec["suppress"]),
		"kinds": (spec["kinds"] as Array).duplicate(),
		"front_z": front_z,
		"back_z": back_z,
		"run_half_x": run_half_x,
		"instances": instances,
		"field_law_ok": front_z <= float(kit.FIELD_LAW_Z),
		"glass_ok": front_z <= float(kit.GLASS_PLANE_Z),
		"depth_ok": depth > 0.0 and depth <= float(kit.DEPTH_BUDGET),
		"frame_run_ok": absf(anchor.x) + run_half_x <= float(kit.AUTHORED_HALF_X),
		"frame_rect_authored_ok": rect_authored_ok,
		"frame_rect_world_ok": rect_world_ok,
	}


## The footprint note is `"W x H x D m - what it is"` (KIT-STANDARD §2): W is the x extent
## the plan draws, H must equal `target_h` and D must equal the declared `depth`. A note
## that does not parse is reported, never patched up.
func _parse_footprint(note: String) -> Dictionary:
	var re := RegEx.create_from_string("^([0-9]+(?:\\.[0-9]+)?) x ([0-9]+(?:\\.[0-9]+)?) x ([0-9]+(?:\\.[0-9]+)?) m - (.+)$")
	var m := re.search(note)
	if m == null:
		return {"matches": false, "error": "footprint note does not parse", "note": note}
	return {
		"w": float(m.get_string(1)),
		"h": float(m.get_string(2)),
		"d": float(m.get_string(3)),
		"what": m.get_string(4),
		"matches": true,
		"note": note,
	}


func _totals(arenas: Array) -> Dictionary:
	var out := {}
	for a in arenas:
		var d: Dictionary = a
		out[String(d["id"])] = int(d["instances_total"])
	return out
