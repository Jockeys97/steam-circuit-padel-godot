extends SceneTree
## audio_port_test.gd — headless drift test: the Godot audio module vs the verified contract.
##
##   godot --headless --path godot --script res://tests/audio_port_test.gd
##   godot --headless --path godot --script res://tests/audio_port_test.gd -- --drift=remove-event
##
## What it proves, in-engine:
##   1. the contract copy the module ships (`res://src/audio/event_map.json`) is
##      byte-identical to the authoritative `tools/audio-port/event-map.json`;
##   2. the module builds exactly the contract's 10 events / 10 sounds, each event
##      resolving to the sound the contract binds it to (including the one
##      `sfx.point(win)` call site that splits into point-win / point-loss);
##   3. every event's WAV in the engine is byte-identical to the baked source the
##      contract points at, the contract's recorded sha256 matches, and the decoded
##      PCM equals the file payload byte-for-byte (no import re-encode);
##   4. the mixer numbers are the reference's (master 0.5, mute global default
##      false, music bus 0.55) applied with the baked master gain as unity, the
##      0..1 setter clamps exactly as `js/audio.js:286-289` does, mute gates new
##      voices without muting a bus, and nothing the contract records as undefined
##      (ducking, compression, limiter, panning, per-event volume) was invented;
##   5. playback actually starts and advances under the headless dummy driver.
##
## …and that the test is not blind: 14 injected-drift cases (contract-side,
## engine-view-side and live-engine-side) are each applied and MUST raise >=1
## failure. A case that raises none is printed MISSED and fails the run.
##
## Exit codes: 0 = every check green AND every injected drift caught;
##             1 = failures, or a blind drift case;
##             2 = `--drift=<name>` names no known scenario;
##             in `--drift=<name>` mode 1 means *the drift was caught* (by design).
##
## Output contract for CI: one `ok <name>` / `FAIL <name>: …` line per check, then
## `PASS <n>/<n>` or `FAIL <n>/<n>`.

const AudioPort := preload("res://src/audio/audio_port.gd")

const REPO_CONTRACT := "tools/audio-port/event-map.json"
const DB_TOLERANCE := 0.02
const ADVANCE_FRAMES := 20

var _engine: Node = null
var _repo: String = ""

var _checks: int = 0
var _failures: int = 0

var _drift_mode: String = ""
var _drift_exit_code: int = 0
var _uncaught: int = 0
var _caught_failure_total: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--drift="):
			_drift_mode = a.substr("--drift=".length())
	await _run()
	var code := 1 if (_failures > 0 or _uncaught > 0) else 0
	if _drift_mode != "":
		code = _drift_exit_code
	quit(code)


# ===========================================================================
# run
# ===========================================================================

func _run() -> void:
	_repo = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	_engine = AudioPort.new()
	_engine.name = "AudioPort"
	root.add_child(_engine)
	# Nodes added to the root during _initialize are not yet "inside the tree" for
	# playback purposes; one frame is enough (measured, see the evidence file).
	await process_frame

	print("audio port drift test — module vs contract")
	print("  engine copy   %s  sha256 %s" % [_engine.describe()["contract_path"], _engine.contract_sha256])
	print("  authoritative %s" % REPO_CONTRACT)
	print("  vending tool  tools/audio-port/sync-godot-audio.mjs")
	print("  repo          %s" % _repo)
	print("")

	if _drift_mode != "":
		await _run_single_drift(_drift_mode)
		return

	# ---- green run --------------------------------------------------------
	var base_contract: Dictionary = _engine.contract.duplicate(true)
	var base_view: Dictionary = _engine.describe()
	var live: Dictionary = await _collect_live_facts(base_contract)
	var results: Array = _run_checks(base_contract, base_view, live)
	print("checks")
	for r in results:
		_report(r)

	print("")
	_print_engine_facts(base_view)

	# ---- injected drift (every case must go RED) --------------------------
	print("")
	print("injected-drift self-check (each case must go RED)")
	for s in _scenarios():
		var c: Dictionary = _engine.contract.duplicate(true)
		var v: Dictionary = _engine.describe()
		_engine.reset()
		await process_frame
		call(str(s["apply"]), c, v)
		var case_live: Dictionary = await _collect_live_facts(c, true)
		var case_results: Array = _run_checks(c, v, case_live)
		var n := 0
		for cr in case_results:
			n += (cr["failures"] as Array).size()
		if n == 0:
			_uncaught += 1
			print("  [MISSED] %s  %s" % [str(s["name"]).rpad(24), str(s["what"])])
		else:
			_caught_failure_total += n
			print("  [CAUGHT] %s  %2d failure(s)  %s" % [str(s["name"]).rpad(24), n, str(s["what"])])
		call(str(s["undo"]), _engine)
	# free anything a scenario left behind (a detached player, an injected effect)
	_engine.reset()
	await process_frame

	print("")
	print("numbers")
	print("  events in contract              : %d" % (base_contract["events"] as Array).size())
	print("  engine players                  : %d" % (base_view["events"] as Array).size())
	print("  WAVs identical to the bake      : %d" % _count_identical(base_view))
	print("  buses built by the module       : %s" % str(_bus_names(base_view)))
	print("  injected drift cases            : %d" % _scenarios().size())
	print("  drift cases caught / missed     : %d / %d" % [_scenarios().size() - _uncaught, _uncaught])
	print("  failures raised by the drift    : %d" % _caught_failure_total)
	print("  green-check failures            : %d" % _failures)
	print("")

	# release the engine so the run does not report leaked streams/players at exit
	_engine.free()
	await process_frame

	if _failures == 0 and _uncaught == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		var line := "FAIL %d/%d" % [_checks - _failures, _checks]
		if _uncaught > 0:
			line += "  (%d blind injected-drift case(s))" % _uncaught
		print(line)
		printerr(line)


func _run_single_drift(name: String) -> void:
	var scenario: Dictionary = {}
	for s in _scenarios():
		if str(s["name"]) == name:
			scenario = s
	if scenario.is_empty():
		print("unknown drift scenario '%s'. known: %s" % [name, ", ".join(_scenario_names())])
		_drift_exit_code = 2
		return
	var c: Dictionary = _engine.contract.duplicate(true)
	var v: Dictionary = _engine.describe()
	_engine.reset()
	await process_frame
	call(str(scenario["apply"]), c, v)
	var live: Dictionary = await _collect_live_facts(c, true)
	var results: Array = _run_checks(c, v, live)
	var n := 0
	for r in results:
		n += (r["failures"] as Array).size()
	print("injected drift: %s — %s" % [name, str(scenario["what"])])
	print("")
	for r in results:
		if not (r["failures"] as Array).is_empty():
			print("[FAIL] %s%s" % [str(r["name"]), ("  %s" % str(r["detail"])) if str(r["detail"]) != "" else ""])
			for f in r["failures"]:
				print("       - %s" % f)
	for r in results:
		if (r["failures"] as Array).is_empty():
			print("[PASS] %s" % str(r["name"]))
	call(str(scenario["undo"]), _engine)
	_engine.reset()
	await process_frame
	print("")
	if n > 0:
		print("DRIFT DETECTED — %d failure(s) raised by injected '%s'." % [n, name])
		print("exit 1 is CORRECT here: this proves the test reacts to drift.")
		_drift_exit_code = 1
	else:
		print("NOT CAUGHT — injected '%s' produced 0 failures. The test is blind to this drift." % name)
		_drift_exit_code = 0
	_engine.queue_free()
	await process_frame


func _report(result: Dictionary) -> void:
	_checks += 1
	var failures: Array = result["failures"]
	var detail := ""
	if str(result["detail"]) != "":
		detail = "  %s" % str(result["detail"])
	if failures.is_empty():
		print("ok %s%s" % [str(result["name"]), detail])
		return
	_failures += 1
	var line := "FAIL %s%s" % [str(result["name"]), detail]
	print(line)
	printerr(line)
	for f in failures:
		print("       - %s" % f)
		printerr("       - %s" % f)


func _print_engine_facts(v: Dictionary) -> void:
	print("engine view")
	print("  contract copy sha256 : %s" % str(v["contract_sha256"]))
	for row in v["events"]:
		print("  %-11s -> res://assets/audio/%-14s bus=%-5s db=%.1f poly=%d  sha256 %s…" % [
			str(row["id"]), str(row["sound"]) + ".wav", str(row["bus"]), float(row["volume_db"]),
			int(row["max_polyphony"]), str(row["stream_sha256"]).substr(0, 16),
		])
	for b in v["buses"]:
		print("  bus %-8s volume_db=%7.4f send='%s' muted=%s effects=%d" % [
			str(b["name"]), float(b["volume_db"]), str(b["send"]), str(b["muted"]), int(b["effect_count"]),
		])


func _count_identical(v: Dictionary) -> int:
	var n := 0
	for row in v["events"]:
		if str(row["stream_sha256"]) != "" and str(row["stream_sha256"]) == str(row["wav_sha256"]):
			n += 1
	return n


func _bus_names(v: Dictionary) -> Array:
	var out: Array = []
	for b in v["buses"]:
		out.append(str(b["name"]))
	return out


# ===========================================================================
# checks — each is a pure function of (contract, engine view, live facts), so a
# mutated clone can be re-run through the whole set.
# ===========================================================================

func _run_checks(c: Dictionary, v: Dictionary, live: Dictionary) -> Array:
	return [
		_chk_contract_copy(c, v, live),
		_chk_structure(c, v, live),
		_chk_event_sound(c, v, live),
		_chk_players(c, v, live),
		_chk_assets_identity(c, v, live),
		_chk_contract_hash(c, v, live),
		_chk_asset_format(c, v, live),
		_chk_payload(c, v, live),
		_chk_mixer_defaults(c, v, live),
		_chk_gain_range(c, v, live),
		_chk_mute(c, v, live),
		_chk_no_invention(c, v, live),
		_chk_port_bindings(c, v, live),
		_chk_bus_layout(c, v, live),
		_chk_playback(c, v, live),
	]


func _result(name: String, failures: Array, detail: String) -> Dictionary:
	return {"name": name, "failures": failures, "detail": detail}


func _chk_contract_copy(c: Dictionary, v: Dictionary, _live: Dictionary) -> Dictionary:
	var f: Array = []
	var authoritative := _repo.path_join(REPO_CONTRACT)
	if not FileAccess.file_exists(authoritative):
		f.append("authoritative contract not reachable at %s — run the test from the repo" % authoritative)
	else:
		var h := AudioPort.sha256_of(authoritative)
		if h != str(v["contract_sha256"]):
			f.append("engine copy != authoritative contract\n      contract: %s\n      engine  : %s" % [h, str(v["contract_sha256"])])
	if str(v["schema"]) != "steam-circuit-padel-pro.audio-event-map":
		f.append("engine copy schema is '%s'" % str(v["schema"]))
	if str(v["schema"]) != str(c.get("schema", "")):
		f.append("engine schema '%s' != contract schema '%s'" % [str(v["schema"]), str(c.get("schema", ""))])
	if not bool(v["loaded"]):
		f.append("the module did not load the contract copy")
	return _result("contract copy: the engine copy is byte-identical to the authoritative contract", f, "sha256 %s…" % str(v["contract_sha256"]).substr(0, 16))


func _chk_structure(c: Dictionary, v: Dictionary, _live: Dictionary) -> Dictionary:
	var f: Array = []
	var events: Array = c.get("events", [])
	var sounds: Array = c.get("soundIds", [])
	if int(c.get("schemaVersion", -1)) != 1:
		f.append("schemaVersion is %s, expected 1" % str(c.get("schemaVersion", "missing")))
	if events.is_empty():
		f.append("contract declares no events")
	if events.size() != sounds.size():
		f.append("%d events != %d declared sounds" % [events.size(), sounds.size()])
	var seen := {}
	for e in events:
		var id := str(e.get("id", ""))
		if id == "":
			f.append("an event has no id")
		if seen.has(id):
			f.append("duplicate event id: %s" % id)
		seen[id] = true
	var ids: Array = v["event_ids"]
	if ids.size() != events.size():
		f.append("engine builds %d players, contract declares %d events" % [ids.size(), events.size()])
	for id in ids:
		if not seen.has(str(id)):
			f.append("engine has a player for '%s', which no contract event declares" % str(id))
	return _result("contract: 10 unique events == 10 declared sounds == 10 engine players", f, "%d events, %d players" % [events.size(), ids.size()])


func _chk_event_sound(c: Dictionary, v: Dictionary, _live: Dictionary) -> Dictionary:
	var f: Array = []
	var by_id := {}
	for row in v["events"]:
		by_id[str(row["id"])] = row
	var sound_ids: Array = c.get("soundIds", [])
	for e in c.get("events", []):
		var id := str(e.get("id", ""))
		var sound := str(e.get("sound", ""))
		var row: Dictionary = by_id.get(id, {})
		if row.is_empty():
			f.append("%s: the engine has no such event" % id)
			continue
		if str(row["sound"]) != sound:
			f.append("%s: engine plays '%s', contract binds '%s'" % [id, str(row["sound"]), sound])
		if not sound_ids.has(sound):
			f.append("%s: sound '%s' is not in soundIds" % [id, sound])
	# the one call site that emits two sounds (`sfx.point(win)`) must stay two events
	var point := {}
	for e in c.get("events", []):
		if str(e.get("id", "")) == "point-win" or str(e.get("id", "")) == "point-loss":
			point[str(e["id"])] = e
	if point.size() == 2:
		var a: Dictionary = point["point-win"]
		var b: Dictionary = point["point-loss"]
		if str(a["anchor"]["call"]) != str(b["anchor"]["call"]) or int(a["anchor"]["line"]) != int(b["anchor"]["line"]):
			f.append("point-win/point-loss no longer share one anchor line — the split changed")
		if str(a["sound"]) == str(b["sound"]):
			f.append("point-win and point-loss resolve to the same sound")
	elif point.size() != 0:
		f.append("the point win/loss pair is incomplete in the contract")
	return _result("engine: event -> sound resolution matches the contract (incl. the point win/loss split)", f, "%d events resolved" % (v["events"] as Array).size())


func _chk_players(c: Dictionary, v: Dictionary, live: Dictionary) -> Dictionary:
	var f: Array = []
	var sfx := str(v["sfx_bus_name"])
	if sfx == str(v["master_bus_name"]):
		f.append("the module routes SFX straight to the master bus")
	var bus := _bus(v, sfx)
	if bus.is_empty():
		f.append("bus '%s' does not exist" % sfx)
	else:
		if absf(float(bus["volume_db"])) > 0.001:
			f.append("bus '%s' is at %.4f dB — a per-bus attenuation nobody defined" % [sfx, float(bus["volume_db"])])
		if int(bus["effect_count"]) != 0:
			f.append("bus '%s' carries %d audio effect(s)" % [sfx, int(bus["effect_count"])])
	if int(live.get("bus_effect_total", 0)) != 0:
		f.append("the live AudioServer has %d bus effect(s): %s" % [int(live.get("bus_effect_total", 0)), str(live.get("bus_effect_counts", {}))])
	if int((c.get("events", []) as Array).size()) != (v["events"] as Array).size():
		f.append("contract declares %d events, engine describes %d" % [(c.get("events", []) as Array).size(), (v["events"] as Array).size()])
	for row in v["events"]:
		if str(row["bus"]) != sfx:
			f.append("%s: on bus '%s', expected '%s'" % [str(row["id"]), str(row["bus"]), sfx])
		if absf(float(row["volume_db"])) > 0.001:
			f.append("%s: player volume_db %.3f — the reference has no per-event runtime volume" % [str(row["id"]), float(row["volume_db"])])
		if str(row["player_class"]) != "AudioStreamPlayer":
			f.append("%s: player class is '%s' — a positional player would add panning the reference does not have" % [str(row["id"]), str(row["player_class"])])
		if int(row["max_polyphony"]) < 1:
			f.append("%s: max_polyphony %d cannot overlap itself" % [str(row["id"]), int(row["max_polyphony"])])
	return _result("engine: players are mono, un-panned, un-levelled and share one SFX bus", f, "bus '%s', %d players" % [sfx, (v["events"] as Array).size()])


func _chk_assets_identity(c: Dictionary, v: Dictionary, _live: Dictionary) -> Dictionary:
	var f: Array = []
	var by_id := {}
	for row in v["events"]:
		by_id[str(row["id"])] = row
	for e in c.get("events", []):
		var id := str(e.get("id", ""))
		var sound := str(e.get("sound", ""))
		var row: Dictionary = by_id.get(id, {})
		if row.is_empty():
			f.append("%s: the engine has no such event" % id)
			continue
		var rel := str(e.get("wav", {}).get("path", ""))
		var src := _repo.path_join(rel)
		if not FileAccess.file_exists(src):
			f.append("%s: baked source missing: %s" % [id, rel])
			continue
		var h := AudioPort.sha256_of(src)
		if h != str(row["stream_sha256"]):
			f.append("%s: engine WAV != baked source\n      baked : %s  (%s)\n      engine: %s" % [id, h, rel, str(row["stream_sha256"])])
		var want_path := "res://assets/audio/%s.wav" % sound
		if str(row["stream_path"]) != want_path:
			f.append("%s: engine stream path '%s', expected '%s'" % [id, str(row["stream_path"]), want_path])
	return _result("assets: every engine WAV is byte-identical to the baked source the contract points at", f, "%d events" % (v["events"] as Array).size())


func _chk_contract_hash(c: Dictionary, v: Dictionary, _live: Dictionary) -> Dictionary:
	var f: Array = []
	var by_id := {}
	for row in v["events"]:
		by_id[str(row["id"])] = row
	for e in c.get("events", []):
		var id := str(e.get("id", ""))
		var wav: Dictionary = e.get("wav", {})
		var row: Dictionary = by_id.get(id, {})
		if row.is_empty():
			f.append("%s: the engine has no such event" % id)
			continue
		if str(wav.get("sha256", "")) != str(row["stream_sha256"]):
			f.append("%s: contract records sha256 %s…, engine file is %s…" % [id, str(wav.get("sha256", "")).substr(0, 16), str(row["stream_sha256"]).substr(0, 16)])
		if int(wav.get("bytes", 0)) != int(row["wav_bytes"]):
			f.append("%s: contract records %d bytes, engine loaded %d" % [id, int(wav.get("bytes", 0)), int(row["wav_bytes"])])
	return _result("assets: the contract's recorded sha256/bytes match the files the engine loaded", f, "%d events" % (v["events"] as Array).size())


func _chk_asset_format(c: Dictionary, v: Dictionary, _live: Dictionary) -> Dictionary:
	var f: Array = []
	var by_id := {}
	for row in v["events"]:
		by_id[str(row["id"])] = row
	for e in c.get("events", []):
		var id := str(e.get("id", ""))
		var row: Dictionary = by_id.get(id, {})
		if row.is_empty():
			f.append("%s: the engine has no such event" % id)
			continue
		var src := _repo.path_join(str(e.get("wav", {}).get("path", "")))
		var head := _wav_header(src)
		if not bool(head["ok"]):
			f.append("%s: %s is not a readable RIFF/WAVE file" % [id, src])
			continue
		if int(row["stream_mix_rate"]) != int(head["rate"]):
			f.append("%s: engine mix_rate %d, baked file says %d" % [id, int(row["stream_mix_rate"]), int(head["rate"])])
		if bool(row["stream_stereo"]) != (int(head["channels"]) == 2):
			f.append("%s: engine stereo=%s, baked file has %d channel(s)" % [id, str(row["stream_stereo"]), int(head["channels"])])
		if int(row["stream_format"]) != AudioStreamWAV.FORMAT_16_BITS:
			f.append("%s: engine stream format %d, expected FORMAT_16_BITS (%d) — a compressed import re-encodes the bake" % [id, int(row["stream_format"]), AudioStreamWAV.FORMAT_16_BITS])
		if int(head["bits"]) != 16:
			f.append("%s: baked file is %d-bit, expected 16" % [id, int(head["bits"])])
		if int(row["stream_data_bytes"]) != int(head["data_bytes"]):
			f.append("%s: engine payload %d bytes, baked file %d" % [id, int(row["stream_data_bytes"]), int(head["data_bytes"])])
		if int(row["stream_frames"]) * 2 != int(row["stream_data_bytes"]):
			f.append("%s: engine frames %d do not match %d payload bytes at 16-bit mono" % [id, int(row["stream_frames"]), int(row["stream_data_bytes"])])
		if float(row["stream_length"]) <= 0.0:
			f.append("%s: engine stream has zero length" % id)
		if float(row["stream_length"]) > 10.0:
			f.append("%s: engine stream is %.3f s — the bake is 1.5 s" % [id, float(row["stream_length"])])
	return _result("assets: engine format equals the baked file's own header (44.1 kHz mono 16-bit, exact payload size)", f, "checked against each WAV header")


func _chk_payload(_c: Dictionary, _v: Dictionary, live: Dictionary) -> Dictionary:
	var f: Array = []
	var n := int(live.get("payload_checked", 0))
	if n == 0:
		f.append("no PCM payload was compared")
	if int(live.get("payload_diff_bytes", -1)) != 0:
		f.append("engine PCM differs from the baked payload in %d byte(s)" % int(live.get("payload_diff_bytes", -1)))
	for s in live.get("payload_errors", []):
		f.append(str(s))
	return _result("assets: the engine's decoded PCM equals the baked WAV payload byte-for-byte", f, "%d streams, %d bytes each" % [n, int(live.get("payload_bytes", 0))])


func _chk_mixer_defaults(c: Dictionary, v: Dictionary, _live: Dictionary) -> Dictionary:
	var f: Array = []
	var m: Dictionary = v["mixer"]
	var cm: Dictionary = c.get("mixer", {})
	var def := float(cm.get("masterGainDefault", {}).get("value", -1.0))
	var mus := float(cm.get("musicBusGain", {}).get("value", -1.0))
	var mute_default := bool(cm.get("mute", {}).get("default", true))
	if absf(float(m["master_gain"]) - def) > 0.0001:
		f.append("module master gain %.4f, contract default %.4f" % [float(m["master_gain"]), def])
	if absf(float(m["master_gain_default"]) - def) > 0.0001:
		f.append("module unity reference %.4f, contract default %.4f" % [float(m["master_gain_default"]), def])
	if bool(m["muted"]) != mute_default:
		f.append("module muted=%s, contract default %s" % [str(m["muted"]), str(mute_default)])
	if bool(m["muted_default"]) != mute_default:
		f.append("module's mute default %s != contract %s" % [str(m["muted_default"]), str(mute_default)])
	if absf(float(m["music_bus_gain"]) - mus) > 0.0001:
		f.append("module music bus gain %.4f, contract %.4f" % [float(m["music_bus_gain"]), mus])
	if bool(m["ducking_defined"]):
		f.append("the module reports ducking as defined — it defines none")
	if bool(m["panning_defined"]):
		f.append("the module reports panning as defined — it defines none")
	var rng: Dictionary = cm.get("masterGainRange", {})
	for k in ["min", "max", "step"]:
		var got := float(m["master_gain_%s" % k])
		var want := float(rng.get(k, -1.0))
		if absf(got - want) > 0.0000001:
			f.append("master gain %s: module %.4f, contract %.4f" % [k, got, want])
	# the baked level IS the reference default: at the default the master bus is unity
	var master := _bus(v, str(v["master_bus_name"]))
	if master.is_empty():
		f.append("no master bus")
	elif absf(float(master["volume_db"])) > 0.001:
		f.append("master bus at %.4f dB at the default gain — the bake already contains the reference's 0.5, so the default must be unity" % float(master["volume_db"]))
	var music := _bus(v, str(v["music_bus_name"]))
	if music.is_empty():
		f.append("no music bus")
	elif absf(float(music["volume_db"]) - linear_to_db(mus)) > DB_TOLERANCE:
		f.append("music bus %.4f dB, expected %.4f dB (20*log10(%.4f))" % [float(music["volume_db"]), linear_to_db(mus), mus])
	return _result("mixer: only the reference's numbers (master default, mute default, music bus gain)", f, "master %.3f, music %.3f, muted default %s" % [float(m["master_gain"]), float(m["music_bus_gain"]), str(bool(m["muted_default"]))])


func _chk_gain_range(c: Dictionary, v: Dictionary, live: Dictionary) -> Dictionary:
	var f: Array = []
	var rng: Dictionary = c.get("mixer", {}).get("masterGainRange", {})
	var lo := float(rng.get("min", 0.0))
	var hi := float(rng.get("max", 1.0))
	var def := float(c.get("mixer", {}).get("masterGainDefault", {}).get("value", 0.5))
	for probe in ["clamp_high", "clamp_low", "at_default"]:
		var p: Dictionary = live.get(probe, {})
		if p.is_empty():
			f.append("%s: probe did not run" % probe)
			continue
		var expected := clampf(float(p["input"]), lo, hi)
		if absf(float(p["ret"]) - expected) > 0.0000001:
			f.append("%s: set_master_gain(%.4f) returned %.4f, expected clamp to %.4f" % [probe, float(p["input"]), float(p["ret"]), expected])
		if expected <= 0.0:
			if not bool(p["bus_muted"]):
				f.append("%s: gain 0 must silence the master bus" % probe)
		else:
			var want_db := linear_to_db(expected / def) if def > 0.0 else 0.0
			if absf(float(p["bus_db"]) - want_db) > DB_TOLERANCE:
				f.append("%s: master bus %.4f dB, expected %.4f dB (relative to the baked %.4f)" % [probe, float(p["bus_db"]), want_db, def])
	var uq: Dictionary = live.get("unquantised", {})
	if uq.is_empty():
		f.append("the unquantised round-trip probe did not run")
	else:
		var expected_uq := clampf(float(uq["input"]), lo, hi)
		if absf(float(uq["ret"]) - expected_uq) > 0.0000001:
			f.append("set_master_gain(%.3f) returned %.4f — the setter clamps, it must not snap to the %.2f slider step" % [float(uq["input"]), float(uq["ret"]), float(rng.get("step", 0.01))])
	return _result("mixer: master gain clamps to the contract's range and scales relative to the baked 0.5", f, "range [%s, %s], unity at %s" % [str(lo), str(hi), str(def)])


func _chk_mute(c: Dictionary, v: Dictionary, live: Dictionary) -> Dictionary:
	var f: Array = []
	if not bool(live.get("muted_flag_while_muted", false)):
		f.append("set_muted(true) did not set the flag")
	if bool(live.get("muted_flag", true)):
		f.append("the module is still muted after set_muted(false)")
	if not bool(live.get("mute_refused_all", false)):
		f.append("play_event() still started %s while muted" % str(live.get("mute_refused_any", [])))
	if not bool(live.get("playing_before_mute", false)):
		f.append("a voice started before mute was not playing")
	if not bool(live.get("playing_after_mute", false)):
		f.append("muting cut a voice that was already sounding — js/audio.js:278-280 only sets a flag; the early returns gate new voices")
	if bool(live.get("master_bus_muted_while_muted", false)):
		f.append("mute muted a bus; the reference's mute only gates new voices")
	var m: Dictionary = v["mixer"]
	if not m.has("muted"):
		f.append("the engine view exposes no global mute")
	for row in v["events"]:
		if row.has("muted"):
			f.append("%s: a per-sound mute exists; the reference has one global flag" % str(row["id"]))
	return _result("mixer: mute is one global flag that gates new voices and mutes no bus", f, "%d events refused while muted" % (c.get("events", []) as Array).size())


func _chk_no_invention(c: Dictionary, v: Dictionary, live: Dictionary) -> Dictionary:
	var f: Array = []
	var cm: Dictionary = c.get("mixer", {})
	if bool(cm.get("ducking", {}).get("defined", true)):
		f.append("the contract now DEFINES ducking — the module would have to implement it, and it does not")
	if bool(cm.get("panning", {}).get("defined", true)):
		f.append("the contract now DEFINES panning — the module would have to implement it, and it does not")
	if int(v["mixer"]["per_event_volume_overrides"]) != 0:
		f.append("%d per-event volume override(s) exist" % int(v["mixer"]["per_event_volume_overrides"]))
	if (cm.get("unknowns", []) as Array).is_empty():
		f.append("the contract no longer records its unknowns; the 'we did not invent it' premise cannot be checked")
	for b in v["buses"]:
		if int(b["effect_count"]) != 0:
			f.append("bus '%s' carries %d effect(s) — the reference defines no compressor/limiter/ducking" % [str(b["name"]), int(b["effect_count"])])
	if int(live.get("bus_effect_total", 0)) != 0:
		f.append("the live AudioServer carries %d bus effect(s): %s" % [int(live.get("bus_effect_total", 0)), str(live.get("bus_effect_counts", {}))])
	var overlap: Dictionary = live.get("overlap", {})
	if overlap.is_empty():
		f.append("no overlapping pair was played")
	else:
		var playing: Array = overlap.get("playing", [])
		if playing.size() != 2 or not (bool(playing[0]) and bool(playing[1])):
			f.append("the overlapping pair %s did not stay playing together: %s" % [str(overlap.get("pair", [])), str(playing)])
		if absf(float(overlap.get("sfx_db_delta", 1.0))) > 0.0001:
			f.append("the SFX bus level moved %.4f dB while two events overlapped — that is ducking by another name" % float(overlap.get("sfx_db_delta", 1.0)))
		if absf(float(overlap.get("master_db_delta", 1.0))) > 0.0001:
			f.append("the master bus level moved %.4f dB while two events overlapped" % float(overlap.get("master_db_delta", 1.0)))
		if int(overlap.get("sfx_fx_delta", 1)) != 0:
			f.append("an effect was added to the SFX bus while two events overlapped")
	return _result("engine: no ducking, compression, limiter, panning or per-event volume was invented", f, "%d buses, %d live effects" % [(v["buses"] as Array).size(), int(live.get("bus_effect_total", 0))])


func _chk_port_bindings(c: Dictionary, v: Dictionary, live: Dictionary) -> Dictionary:
	var f: Array = []
	if not (v["port_bindings"] as Dictionary).is_empty():
		f.append("the module binds port message ids to sounds: %s" % str(v["port_bindings"]))
	if int((c.get("honestUnknowns", []) as Array).size()) == 0:
		f.append("the contract no longer records honestUnknowns")
	var accepted: Array = live.get("port_ids_accepted", [])
	if not accepted.is_empty():
		f.append("play_event() accepted port message id(s) as events: %s" % str(accepted))
	if int(live.get("port_ids_total", -1)) <= 0:
		f.append("no port message id was probed")
	var total_events := (c.get("events", []) as Array).size()
	if int(live.get("contract_ids_accepted", -1)) != total_events:
		f.append("play_event() accepted %s of %d contract event ids" % [str(live.get("contract_ids_accepted", -1)), total_events])
	return _result("engine: port message ids are not bound to sounds (the contract leaves that open)", f, "%d port ids rejected, %d event ids accepted" % [int(live.get("port_ids_total", 0)), int(live.get("contract_ids_accepted", 0))])


func _chk_bus_layout(_c: Dictionary, v: Dictionary, _live: Dictionary) -> Dictionary:
	var f: Array = []
	var path := str(v["bus_layout_path"])
	var layout: AudioBusLayout = load(path) as AudioBusLayout
	if layout == null:
		f.append("the shipped bus layout %s does not load" % path)
		return _result("bus layout: the shipped AudioBusLayout resource matches the buses the module builds", f, path)
	var buses: Array = v["buses"]
	var i := 0
	while i < 32:
		var layout_name: Variant = layout.get("bus/%d/name" % i)
		if layout_name == null:
			break
		var layout_db := float(layout.get("bus/%d/volume_db" % i))
		var layout_send := str(layout.get("bus/%d/send" % i))
		if i >= buses.size():
			f.append("layout declares bus %d ('%s') that the module does not build" % [i, str(layout_name)])
		else:
			var b: Dictionary = buses[i]
			if str(b["name"]) != str(layout_name):
				f.append("bus %d: layout '%s', module '%s'" % [i, str(layout_name), str(b["name"])])
			if absf(float(b["volume_db"]) - layout_db) > DB_TOLERANCE:
				f.append("bus %d ('%s'): layout %.4f dB, module %.4f dB" % [i, str(layout_name), layout_db, float(b["volume_db"])])
			if str(b["send"]) != layout_send:
				f.append("bus %d ('%s'): layout sends to '%s', module to '%s'" % [i, str(layout_name), layout_send, str(b["send"])])
		i += 1
	if i == 0:
		f.append("the shipped layout declares no buses")
	return _result("bus layout: the shipped AudioBusLayout resource matches the buses the module builds", f, "%d buses" % i)


func _chk_playback(_c: Dictionary, _v: Dictionary, live: Dictionary) -> Dictionary:
	var f: Array = []
	if not bool(live.get("start_returned", false)):
		f.append("play_event('hit') returned false: %s" % str(live.get("start_error", "")))
	if not bool(live.get("start_playing", false)):
		f.append("the player did not report `playing` after play_event('hit')")
	var pos := float(live.get("advance_pos", 0.0))
	if pos <= 0.0:
		f.append("playback position did not advance over %d frames under the headless driver" % ADVANCE_FRAMES)
	if pos > 1.6:
		f.append("playback position %.3f s exceeds the 1.5 s bake" % pos)
	return _result("engine: playback starts and advances under the headless driver", f, "%.3f s after %d frames" % [pos, ADVANCE_FRAMES])


func _bus(v: Dictionary, name: String) -> Dictionary:
	for b in v["buses"]:
		if str(b["name"]) == name:
			return b
	return {}


# ===========================================================================
# live facts — measured on the real engine, once per scenario
# ===========================================================================

func _collect_live_facts(c: Dictionary, skip_reset: bool = false) -> Dictionary:
	if not skip_reset:
		_engine.reset()
		await process_frame
	var live := {}

	# --- playback actually runs -------------------------------------------
	var started: bool = _engine.play_event("hit")
	var p: AudioStreamPlayer = _engine.player_for("hit")
	live["start_returned"] = started
	live["start_error"] = _engine.last_play_error
	live["start_playing"] = (p != null and p.playing)
	await process_frame
	for i in ADVANCE_FRAMES:
		await process_frame
	live["advance_pos"] = (p.get_playback_position() if p != null else 0.0)
	_engine.stop_all()

	# --- PCM payload == the baked file's payload --------------------------
	var diff_bytes := 0
	var checked := 0
	var payload_bytes := 0
	var errors: Array = []
	for id in _engine.event_ids():
		var pl: AudioStreamPlayer = _engine.player_for(id)
		var st: AudioStreamWAV = (pl.stream if pl != null else null)
		if st == null:
			errors.append("%s: no stream" % str(id))
			continue
		var res_path := str(pl.stream.resource_path)
		if not FileAccess.file_exists(res_path):
			errors.append("%s: %s is not readable" % [str(id), res_path])
			continue
		var raw := FileAccess.get_file_as_bytes(res_path)
		if raw.size() < 44:
			errors.append("%s: %s has no readable RIFF/WAVE header" % [str(id), res_path])
			continue
		var payload := raw.slice(44)
		checked += 1
		payload_bytes = payload.size()
		if payload != st.data:
			var d := 0
			var n := mini(payload.size(), st.data.size())
			for i in n:
				if payload[i] != st.data[i]:
					d += 1
			diff_bytes += d + absi(payload.size() - st.data.size())
	live["payload_checked"] = checked
	live["payload_bytes"] = payload_bytes
	live["payload_diff_bytes"] = diff_bytes
	live["payload_errors"] = errors

	# --- the live AudioServer carries no effect anywhere -------------------
	var effect_counts := {}
	var effect_total := 0
	for i in AudioServer.bus_count:
		var cnt := AudioServer.get_bus_effect_count(i)
		effect_counts[AudioServer.get_bus_name(i)] = cnt
		effect_total += cnt
	live["bus_effect_counts"] = effect_counts
	live["bus_effect_total"] = effect_total

	# --- mute: gates new voices, does not cut a sounding voice, no bus mute
	_engine.set_muted(false)
	_engine.play_event("wall")
	var playing_before: bool = _engine.is_playing("wall")
	_engine.set_muted(true)
	var playing_after: bool = _engine.is_playing("wall")
	var accepted: Array = []
	for e in c.get("events", []):
		if _engine.play_event(str(e.get("id", ""))):
			accepted.append(str(e.get("id", "")))
	live["playing_before_mute"] = playing_before
	live["playing_after_mute"] = playing_after
	live["mute_refused_all"] = accepted.is_empty()
	live["mute_refused_any"] = accepted
	live["master_bus_muted_while_muted"] = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	live["muted_flag_while_muted"] = _engine.is_muted()
	_engine.stop_all()
	_engine.set_muted(false)
	live["muted_flag"] = _engine.is_muted()

	# --- gain probes ------------------------------------------------------
	var rng: Dictionary = c.get("mixer", {}).get("masterGainRange", {})
	var lo := float(rng.get("min", 0.0))
	var hi := float(rng.get("max", 1.0))
	var def := float(c.get("mixer", {}).get("masterGainDefault", {}).get("value", 0.5))
	var midx := AudioServer.get_bus_index("Master")
	live["clamp_high"] = _gain_probe(midx, hi + 0.5)
	live["clamp_low"] = _gain_probe(midx, lo - 0.3)
	live["at_default"] = _gain_probe(midx, def)
	var uq := _gain_probe(midx, 0.333)
	live["unquantised"] = {"input": 0.333, "ret": uq["ret"]}
	_engine.set_master_gain(def)

	# --- overlap is additive ----------------------------------------------
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var sfx_db_before := AudioServer.get_bus_volume_db(sfx_idx)
	var sfx_fx_before := AudioServer.get_bus_effect_count(sfx_idx)
	var master_db_before := AudioServer.get_bus_volume_db(midx)
	var overlap := {}
	for e in c.get("events", []):
		if not (e.get("overlaps", []) as Array).is_empty():
			var id0 := str(e.get("id", ""))
			var id1 := str((e.get("overlaps", []) as Array)[0])
			var ok0: bool = _engine.play_event(id0)
			var ok1: bool = _engine.play_event(id1)
			overlap = {
				"pair": [id0, id1],
				"started": [ok0, ok1],
				"playing": [_engine.is_playing(id0), _engine.is_playing(id1)],
				"sfx_db_delta": AudioServer.get_bus_volume_db(sfx_idx) - sfx_db_before,
				"sfx_fx_delta": AudioServer.get_bus_effect_count(sfx_idx) - sfx_fx_before,
				"master_db_delta": AudioServer.get_bus_volume_db(midx) - master_db_before,
			}
			break
	live["overlap"] = overlap
	_engine.stop_all()

	# --- port message ids are not event ids -------------------------------
	var port_ids := {}
	for e in c.get("events", []):
		for a in (e.get("port", {}).get("eventIdAnchors", []) as Array):
			port_ids[str(a.get("id", ""))] = true
	# a fabricated id too, so an empty port set cannot make the check vacuous
	port_ids["evNotAContractEvent"] = true
	var accepted_port: Array = []
	for pid in port_ids.keys():
		if _engine.play_event(str(pid)):
			accepted_port.append(str(pid))
	live["port_ids_total"] = port_ids.size()
	live["port_ids_accepted"] = accepted_port
	var accepted_events := 0
	for e in c.get("events", []):
		if _engine.play_event(str(e.get("id", ""))):
			accepted_events += 1
	live["contract_ids_accepted"] = accepted_events
	_engine.stop_all()
	_engine.set_master_gain(def)
	_engine.set_muted(bool(c.get("mixer", {}).get("mute", {}).get("default", false)))
	return live


func _gain_probe(bus_idx: int, value: float) -> Dictionary:
	var ret: float = _engine.set_master_gain(value)
	return {
		"input": value,
		"ret": ret,
		"bus_db": AudioServer.get_bus_volume_db(bus_idx),
		"bus_muted": AudioServer.is_bus_mute(bus_idx),
	}


# ===========================================================================
# injected drift
# ===========================================================================

func _scenario_names() -> Array:
	var out: Array = []
	for s in _scenarios():
		out.append(str(s["name"]))
	return out


func _scenarios() -> Array:
	return [
		{"name": "remove-event", "what": "delete the 'wall' event from the contract", "apply": "_dr_remove_event", "undo": "_undo_nothing"},
		{"name": "add-event", "what": "append a fabricated 11th event with no WAV", "apply": "_dr_add_event", "undo": "_undo_nothing"},
		{"name": "sound-swap", "what": "point 'net' at hit.wav", "apply": "_dr_sound_swap", "undo": "_undo_nothing"},
		{"name": "soundids-drift", "what": "declare an 11th sound id no event uses", "apply": "_dr_soundids", "undo": "_undo_nothing"},
		{"name": "wav-hash-drift", "what": "expect a different sha256 for 'hit'", "apply": "_dr_hash", "undo": "_undo_nothing"},
		{"name": "mixer-gain", "what": "master default 0.5 -> 0.6", "apply": "_dr_mixer_gain", "undo": "_undo_nothing"},
		{"name": "mute-default", "what": "mute default false -> true", "apply": "_dr_mute_default", "undo": "_undo_nothing"},
		{"name": "music-bus-gain", "what": "music bus gain 0.55 -> 0.7", "apply": "_dr_music_gain", "undo": "_undo_nothing"},
		{"name": "ducking-invented", "what": "mark ducking as defined in the contract", "apply": "_dr_ducking", "undo": "_undo_nothing"},
		{"name": "schema-drift", "what": "bump schemaVersion to 2", "apply": "_dr_schema", "undo": "_undo_nothing"},
		{"name": "engine-sound-repoint", "what": "repoint the engine's 'net' player at hit.wav (engine view)", "apply": "_dr_engine_repoint", "undo": "_undo_nothing"},
		{"name": "engine-gain-drift", "what": "engine view reports master gain 0.6", "apply": "_dr_engine_gain", "undo": "_undo_nothing"},
		{"name": "engine-effect-injected", "what": "put a hard limiter on the SFX bus (live engine)", "apply": "_dr_engine_effect", "undo": "_undo_effect"},
		{"name": "engine-stream-emptied", "what": "clear the 'hit' player's stream (live engine)", "apply": "_dr_engine_emptied", "undo": "_undo_nothing"},
		{"name": "engine-player-detached", "what": "pull the 'hit' player out of the tree (live engine)", "apply": "_dr_engine_detached", "undo": "_undo_nothing"},
	]


func _undo_nothing(_engine_unused: Node) -> void:
	pass


func _first_event(c: Dictionary, id: String) -> Dictionary:
	for e in c.get("events", []):
		if str(e.get("id", "")) == id:
			return e
	return {}


func _dr_remove_event(c: Dictionary, _v: Dictionary) -> void:
	var keep: Array = []
	for e in c.get("events", []):
		if str(e.get("id", "")) != "wall":
			keep.append(e)
	c["events"] = keep


func _dr_add_event(c: Dictionary, _v: Dictionary) -> void:
	(c["events"] as Array).append({
		"id": "echo-dash",
		"sound": "echo-dash",
		"wav": {"path": "tools/audio-audition/baked/echo-dash.wav", "sha256": "0".repeat(64), "bytes": 132344},
		"anchor": {"file": "js/game.js", "line": 1, "fn": "hitBall", "call": "sfx.echoDash()"},
		"trigger": "fabricated",
		"overlaps": [],
		"port": {"file": "godot/src/sim/sim.gd", "line": 1, "fn": "hit_ball", "eventIdAnchors": []},
	})


func _dr_sound_swap(c: Dictionary, _v: Dictionary) -> void:
	var e := _first_event(c, "net")
	var hit := _first_event(c, "hit")
	if e.is_empty() or hit.is_empty():
		return
	e["sound"] = "hit"
	e["wav"] = (hit["wav"] as Dictionary).duplicate(true)


func _dr_soundids(c: Dictionary, _v: Dictionary) -> void:
	(c["soundIds"] as Array).append("echo-dash")


func _dr_hash(c: Dictionary, _v: Dictionary) -> void:
	var e := _first_event(c, "hit")
	if not e.is_empty():
		(e["wav"] as Dictionary)["sha256"] = "0".repeat(64)


func _dr_mixer_gain(c: Dictionary, _v: Dictionary) -> void:
	((c["mixer"] as Dictionary)["masterGainDefault"] as Dictionary)["value"] = 0.6


func _dr_mute_default(c: Dictionary, _v: Dictionary) -> void:
	((c["mixer"] as Dictionary)["mute"] as Dictionary)["default"] = true


func _dr_music_gain(c: Dictionary, _v: Dictionary) -> void:
	((c["mixer"] as Dictionary)["musicBusGain"] as Dictionary)["value"] = 0.7


func _dr_ducking(c: Dictionary, _v: Dictionary) -> void:
	((c["mixer"] as Dictionary)["ducking"] as Dictionary)["defined"] = true


func _dr_schema(c: Dictionary, _v: Dictionary) -> void:
	c["schemaVersion"] = 2


func _dr_engine_repoint(c: Dictionary, v: Dictionary) -> void:
	var hit := _first_event(c, "hit")
	var hash := str((hit.get("wav", {}) as Dictionary).get("sha256", ""))
	for row in v["events"]:
		if str(row["id"]) == "net":
			row["stream_path"] = "res://assets/audio/hit.wav"
			row["stream_sha256"] = hash
			row["wav_sha256"] = hash
			row["sound"] = "hit"


func _dr_engine_gain(_c: Dictionary, v: Dictionary) -> void:
	(v["mixer"] as Dictionary)["master_gain"] = 0.6


func _dr_engine_effect(_c: Dictionary, _v: Dictionary) -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.add_bus_effect(idx, AudioEffectHardLimiter.new(), 0)


func _undo_effect(_engine_unused: Node) -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		for i in range(AudioServer.get_bus_effect_count(idx) - 1, -1, -1):
			AudioServer.remove_bus_effect(idx, i)


# NOTE: `stream_paused = true` was tried here first and did NOT go red: Godot
# rebuilds the playback on `play()`, so a pre-set pause does not survive the call
# the playback check exercises. These two drifts are the ones that check
# demonstrably catches — a player that cannot start, and one that cannot advance.
# (Also recorded in the evidence file rather than quietly dropped.)
func _dr_engine_emptied(_c: Dictionary, _v: Dictionary) -> void:
	var p: AudioStreamPlayer = _engine.player_for("hit")
	if p != null:
		p.stream = null


func _dr_engine_detached(_c: Dictionary, _v: Dictionary) -> void:
	var p: AudioStreamPlayer = _engine.player_for("hit")
	if p != null:
		_engine.remove_child(p)


# ===========================================================================
# helpers
# ===========================================================================

## The 44-byte canonical PCM header facts, read from the file itself so the test
## compares the engine against the artefact, not against a typed-in constant.
func _wav_header(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.size() < 44:
		return {"ok": false}
	if raw.slice(0, 4).get_string_from_ascii() != "RIFF" or raw.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {"ok": false}
	return {
		"ok": true,
		"channels": raw.decode_u16(22),
		"rate": raw.decode_u32(24),
		"bits": raw.decode_u16(34),
		"data_bytes": raw.decode_u32(40),
	}
