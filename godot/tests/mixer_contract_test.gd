extends SceneTree
## mixer_contract_test.gd — the shared-reader seam (architecture-deepening gate 5):
## ONE mixer-contract reader, consumed by BOTH audio adapters.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##       --script res://tests/mixer_contract_test.gd
##
## What it proves, in-engine:
##   1. the reader (`res://src/audio/mixer_contract.gd`) loads the vendored audio
##      event contract, validates it (schema, events, sha256), and refuses a JSON
##      object that is not that contract — so "read and validate once" is a
##      behaviour, not a docstring;
##   2. its mixer facts (master-gain default, music-bus gain, mute default,
##      master-gain range) and its bus facts (the graph and the per-bus levels,
##      applied through `ensure_bus`) are the JSON's own values, re-derived
##      here from the file rather than from the reader;
##   3. BOTH adapters consume it: each engine is handed a reader pointed at a
##      doctored contract copy (master 0.4, music 0.7, mute default true, range
##      0.1..0.9) before it enters the tree, and the engine's own `describe()` and
##      the REAL AudioServer buses must show the doctored numbers. An adapter that
##      still parsed `res://src/audio/event_map.json` itself fails here;
##   4. a control engine on the shipped contract shows the shipped numbers (0.5,
##      0.55, false, max 1.0), so a hard-coded constant in an adapter cannot pass
##      point 3 by accident;
##   5. the master-gain law and the range clamp are the reader's: 0.2 against the
##      doctored 0.4 default is half (−6.02 dB) on the master bus, the injected
##      default itself is unity, and 1.5 clamps to 0.9.
##
## Output contract for CI: one `ok <name>` / `FAIL <name>: …` line per check, then
## `PASS <n>/<n>` or `FAIL <n>/<n>`. Exit 0 = every check green.

const AudioPort := preload("res://src/audio/audio_port.gd")
const MusicPort := preload("res://src/audio/music.gd")

const READER_PATH := "res://src/audio/mixer_contract.gd"
const CONTRACT_PATH := "res://src/audio/event_map.json"
const CONTRACT_SCHEMA := "steam-circuit-padel-pro.audio-event-map"
## A real JSON object that is NOT the audio contract (different schema) — the
## music module's own test dump, so the impostor also exists on disk.
const IMPOSTOR_PATH := "res://src/audio/music_reference.json"
## The doctored contract copy the test writes and the injected readers read.
const DOCTORED_PATH := "user://mixer_contract_doctored.json"
const DOCTORED := {"master": 0.4, "music": 0.7, "min": 0.1, "max": 0.9, "step": 0.05}
const DB_TOLERANCE := 0.02
const TOLERANCE := 0.0001

var _checks: int = 0
var _failures: int = 0
var _reader_script: Script = null


func _initialize() -> void:
	await _run()
	quit(1 if _failures > 0 else 0)


func _run() -> void:
	print("mixer contract seam test — one reader, both adapters")
	print("  reader   %s" % READER_PATH)
	print("  contract %s" % CONTRACT_PATH)
	print("")
	_reader_script = load(READER_PATH)
	_check("the one mixer-contract reader exists", _reader_script != null, READER_PATH)
	_check("audio_port holds the shared reader before _ready()",
		_holds_reader(AudioPort), "mixer_contract")
	_check("music holds the shared reader before _ready()",
		_holds_reader(MusicPort), "mixer_contract")
	if _reader_script == null:
		_report_tally()
		return

	# --- 1. the reader: load, validate, hash ------------------------------
	var reader: Object = _reader_script.new()
	reader.load_contract()
	var reader_sha := str(reader.contract_sha256)
	_check("the reader loaded the vendored contract copy", bool(reader.loaded), str(reader.error))
	_check("the reader's copy is the file on disk (sha256)",
		reader_sha.length() == 64 and reader_sha == _sha256(CONTRACT_PATH),
		reader_sha.substr(0, 16))
	_check("the reader validated the schema and found events",
		str(reader.contract.get("schema", "")) == CONTRACT_SCHEMA
		and not (reader.contract.get("events", []) as Array).is_empty(),
		str(reader.contract.get("schema", "")))
	var impostor: Object = _reader_script.new()
	impostor.contract_path = IMPOSTOR_PATH
	impostor.load_contract()
	_check("the reader refuses a JSON object that is not the audio contract",
		not bool(impostor.loaded), IMPOSTOR_PATH)
	var missing: Object = _reader_script.new()
	missing.contract_path = "res://src/audio/no_such_contract.json"
	missing.load_contract()
	_check("the reader refuses a missing contract file",
		not bool(missing.loaded), str(missing.error))

	# --- 2. the reader's facts are the JSON's own -------------------------
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	var jmix: Dictionary = json["mixer"]
	var j_default := float((jmix["masterGainDefault"] as Dictionary)["value"])
	var j_music := float((jmix["musicBusGain"] as Dictionary)["value"])
	var j_mute := bool((jmix["mute"] as Dictionary)["default"])
	var jrng: Dictionary = jmix["masterGainRange"]
	var rng: Dictionary = reader.master_gain_range()
	_check("the reader's master-gain default is the contract's",
		is_equal_approx(float(reader.reference_master_gain()), j_default),
		str(reader.reference_master_gain()))
	_check("the reader's music-bus gain is the contract's",
		is_equal_approx(float(reader.reference_music_bus_gain()), j_music),
		str(reader.reference_music_bus_gain()))
	_check("the reader's mute default is the contract's",
		bool(reader.muted_default()) == j_mute, str(reader.muted_default()))
	_check("the reader's gain range is the contract's",
		is_equal_approx(float(rng["min"]), float(jrng["min"]))
		and is_equal_approx(float(rng["max"]), float(jrng["max"]))
		and is_equal_approx(float(rng["step"]), float(jrng["step"])), JSON.stringify(rng))
	_check("the reader clamps gain to that range",
		is_equal_approx(float(reader.clamp_gain(5.0)), 1.0)
		and is_equal_approx(float(reader.clamp_gain(-3.0)), 0.0)
		and is_equal_approx(float(reader.clamp_gain(NAN)), 0.0),
		"%s / %s / %s" % [reader.clamp_gain(5.0), reader.clamp_gain(-3.0), reader.clamp_gain(NAN)])
	var rows: Array[String] = []
	var bus_ok := true
	for bus_name in ["Master", "SFX", "Music"]:
		var idx: int = reader.ensure_bus(String(bus_name))
		var want_send := "" if String(bus_name) == "Master" else "Master"
		var db: float = reader.bus_volume_db(String(bus_name))
		rows.append("%s send=%s db=%.4f" % [String(bus_name),
			AudioServer.get_bus_send(idx) if idx >= 0 else "<no bus>", db])
		bus_ok = bus_ok and idx >= 0 and AudioServer.get_bus_send(idx) == want_send
		bus_ok = bus_ok and ((absf(db - linear_to_db(j_music)) < DB_TOLERANCE)
			if String(bus_name) == "Music" else absf(db) < DB_TOLERANCE)
	_check("the reader's bus facts are the reference's graph (SFX and Music on Master)",
		bus_ok, ", ".join(rows))

	# --- 3/4/5. both adapters consume the reader --------------------------
	_check("the doctored contract copy was written", _write_doctored(), DOCTORED_PATH)
	await _probe_adapter("audio_port", AudioPort)
	await _probe_adapter("music", MusicPort)
	_cleanup()
	_report_tally()


## One adapter, twice: once on an injected reader pointed at the doctored copy
## (its numbers must win), once on the shipped contract (the control).
func _probe_adapter(label: String, adapter: Script) -> void:
	var want_master := float(DOCTORED["master"])
	var want_music := float(DOCTORED["music"])
	var want_min := float(DOCTORED["min"])
	var want_max := float(DOCTORED["max"])
	var want_step := float(DOCTORED["step"])
	var engine: Node = adapter.new()
	engine.name = label + "_injected"
	var reader: Object = _reader_script.new()
	reader.contract_path = DOCTORED_PATH
	engine.set("mixer_contract", reader)
	root.add_child(engine)
	await process_frame
	var m: Dictionary = engine.describe()["mixer"]
	_check("%s: the injected reader's master default is the engine's" % label,
		absf(float(m["master_gain_default"]) - want_master) < TOLERANCE,
		str(m["master_gain_default"]))
	_check("%s: the injected reader's music-bus gain is the engine's" % label,
		absf(float(m["music_bus_gain"]) - want_music) < TOLERANCE,
		str(m["music_bus_gain"]))
	_check("%s: the injected reader's gain range is the engine's" % label,
		absf(float(m["master_gain_min"]) - want_min) < TOLERANCE
		and absf(float(m["master_gain_max"]) - want_max) < TOLERANCE
		and absf(float(m["master_gain_step"]) - want_step) < TOLERANCE,
		"%s..%s step %s" % [m["master_gain_min"], m["master_gain_max"], m["master_gain_step"]])
	_check("%s: the injected reader's mute default gates the engine" % label,
		bool(m["muted_default"]) and bool(m["muted"]) and bool(engine.is_muted()),
		"default=%s muted=%s" % [str(m["muted_default"]), str(m["muted"])])
	var music_idx := AudioServer.get_bus_index("Music")
	var music_db := AudioServer.get_bus_volume_db(music_idx) if music_idx >= 0 else 0.0
	_check("%s: the Music bus sits at the injected gain" % label,
		music_idx >= 0 and absf(music_db - linear_to_db(want_music)) < DB_TOLERANCE,
		("%.4f dB" % music_db) if music_idx >= 0 else "no Music bus")
	var master_idx := AudioServer.get_bus_index("Master")
	var applied: float = engine.set_master_gain(0.2)
	var master_db := AudioServer.get_bus_volume_db(master_idx) if master_idx >= 0 else 0.0
	_check("%s: the gain law is the reader's (0.2 against the 0.4 default is half)" % label,
		is_equal_approx(applied, 0.2) and master_idx >= 0
		and absf(master_db - linear_to_db(0.2 / want_master)) < DB_TOLERANCE,
		"ret=%s db=%s" % [str(applied), str(master_db)])
	var at_default: float = engine.set_master_gain(want_master)
	var default_db := AudioServer.get_bus_volume_db(master_idx) if master_idx >= 0 else 0.0
	_check("%s: at the injected default the master bus is unity" % label,
		is_equal_approx(at_default, want_master) and master_idx >= 0 and absf(default_db) < 0.001,
		"ret=%s db=%s" % [str(at_default), str(default_db)])
	var clamped: float = engine.set_master_gain(1.5)
	_check("%s: the clamp is the reader's range (1.5 -> %.2f)" % [label, want_max],
		is_equal_approx(clamped, want_max), str(clamped))
	root.remove_child(engine)
	engine.free()
	await process_frame

	var control: Node = adapter.new()
	control.name = label + "_control"
	root.add_child(control)
	await process_frame
	var cm: Dictionary = control.describe()["mixer"]
	_check("%s: on the shipped contract the engine shows the shipped numbers" % label,
		absf(float(cm["master_gain_default"]) - 0.5) < TOLERANCE
		and absf(float(cm["music_bus_gain"]) - 0.55) < TOLERANCE
		and not bool(cm["muted_default"]) and not bool(cm["muted"])
		and absf(float(cm["master_gain_max"]) - 1.0) < TOLERANCE,
		"%s / %s / muted %s" % [cm["master_gain_default"], cm["music_bus_gain"], str(cm["muted"])])
	var c_music := AudioServer.get_bus_index("Music")
	var c_db := AudioServer.get_bus_volume_db(c_music) if c_music >= 0 else 0.0
	_check("%s: the control engine put the Music bus back at the shipped 0.55" % label,
		c_music >= 0 and absf(c_db - linear_to_db(0.55)) < DB_TOLERANCE,
		("%.4f dB" % c_db) if c_music >= 0 else "no Music bus")
	root.remove_child(control)
	control.free()
	await process_frame


func _holds_reader(adapter: Script) -> bool:
	var node: Node = adapter.new()
	var holds: bool = node.get("mixer_contract") != null
	node.free()
	return holds


## The real contract, with only the mixer numbers moved — everything the reader
## validates (schema, events) stays intact.
func _write_doctored() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var contract: Dictionary = parsed
	var mixer: Dictionary = contract["mixer"]
	(mixer["masterGainDefault"] as Dictionary)["value"] = float(DOCTORED["master"])
	(mixer["musicBusGain"] as Dictionary)["value"] = float(DOCTORED["music"])
	(mixer["mute"] as Dictionary)["default"] = true
	(mixer["masterGainRange"] as Dictionary)["min"] = float(DOCTORED["min"])
	(mixer["masterGainRange"] as Dictionary)["max"] = float(DOCTORED["max"])
	(mixer["masterGainRange"] as Dictionary)["step"] = float(DOCTORED["step"])
	var f := FileAccess.open(DOCTORED_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(contract))
	f.close()
	return true


func _sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


func _cleanup() -> void:
	if FileAccess.file_exists(DOCTORED_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DOCTORED_PATH))


func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("ok %s" % name)
	else:
		_failures += 1
		print("FAIL %s: %s" % [name, detail])


func _report_tally() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
