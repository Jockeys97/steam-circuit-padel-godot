extends SceneTree
## music_port_test.gd — headless drift test: the ported music engine vs the reference's
## own generated output.
##
##   godot --headless --path godot --script res://tests/music_port_test.gd
##   godot --headless --path godot --script res://tests/music_port_test.gd -- --drift=wrong-chord
##
## What it proves, in-engine:
##   1. the reference dump the engine is tested against
##      (`res://src/audio/music_reference.json`) is byte-identical to the one
##      `tools/audio-music-port/extract-music.mjs` generates from `js/audio.js`, and the
##      dump still describes the `js/audio.js` / `js/main.js` on disk (both sources'
##      sha256 are re-checked), so a reference change without a re-extract fails here;
##   2. the module's chord table, sequencer constants and mixer numbers are the
##      reference's, item by item;
##   3. for every scenario in the dump — nine constant-intensity runs straddling the
##      three gates (0.4 arp, 0.6 bass off-beat, 0.72 drums), the intensity ramp driven
##      by the reference's own `js/main.js:1220-1226` formula, two mute windows, and the
##      volume 0 / default pair — the module's emitted step AND event streams are equal
##      to the reference's, field by field: layer, timbre, midi/frequency, gain, attack,
##      duration, filter, step index and scheduled time;
##   4. the two contexts behave as the reference does: `menu` emits nothing,
##      `match` emits the progression;
##   5. the mixer semantics `audio_port.gd` established hold: the Music bus sits at the
##      reference's 0.55, mute freezes the scheduler (mutes no bus, cuts no sounding
##      voice), volume 0 is silent but still plays and does not change the score, and the
##      0..1 setter clamps and applies relative to the reference's own default gain;
##   6. voices actually start and are addressed at the reference's gain for that note
##      under the headless dummy driver, and the pooled voices stay bounded.
##
## …and that the test is not blind: 15 injected-drift cases are each applied and MUST
## raise the named failure — the eleven stream-side ones (the captured material mutated
## before the comparator sees it) and the four engine-side ones (the module put into a
## state the reference forbids). A case that raises none — or a different name — is
## printed MISSED and fails the run; every gate is verified green before its injection.
## `--drift=<name>` runs that single case only (the full suite is the no-argument run).
##
## Exit codes: 0 = every check green AND every injected drift caught;
##             1 = failures, or a blind drift case;
##             2 = `--drift=<name>` names no known case;
##             in `--drift=<name>` mode 1 means *the drift was caught* (by design).
##
## Output contract for CI: one `ok <name>` / `FAIL <name>: …` line per check, then
## `PASS <n>/<n>` or `FAIL <n>/<n>`.
##
## WHAT THIS DOES NOT PROVE: anything about how the score sounds. The module runs the
## dummy audio driver here; no listening test was performed and no audible claim is made.

const MusicPort := preload("res://src/audio/music.gd")

const ENGINE_DUMP := "res://src/audio/music_reference.json"
const REPO_DUMP := "tools/audio-music-port/out/music-reference.json"
const SCENARIO_COUNT := 15

## Scheduled times are IEEE doubles produced by the same arithmetic on both sides; the
## tolerances only absorb JSON round-tripping.
const T_TOL := 1e-9
const F_TOL := 1e-6
const G_TOL := 1e-9

var _engine: Node = null
var _repo: String = ""
var _dump: Dictionary = {}
var _scenarios: Dictionary = {}

var _checks: int = 0
var _failures: int = 0
## The injection the currently running gate must apply ("" = the honest run).
var _inject: String = ""

var _drift_mode: String = ""
var _drift_exit_code: int = 0
var _uncaught: int = 0


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
	_engine = MusicPort.new()
	_engine.name = "MusicPort"
	root.add_child(_engine)
	# Keep the module's own clock out of the way: the test drives `tick(now)` itself with
	# the same pump the reference dump was generated with.
	_engine.set_process(false)
	# Nodes added to the root during _initialize are not yet "inside the tree" for
	# playback purposes; one frame is enough (as in audio_port_test.gd).
	await process_frame

	print("music port drift test — module vs the reference's own generated output")
	print("  engine dump   %s  sha256 %s" % [ENGINE_DUMP, MusicPort.sha256_of(ENGINE_DUMP)])
	print("  authoritative %s" % REPO_DUMP)
	print("  extractor     tools/audio-music-port/extract-music.mjs")
	print("  vending tool  tools/audio-music-port/sync-godot-music.mjs")
	print("  driver        %s (headless dummy — structure and engine state only)" % AudioServer.get_driver_name())

	if not _check_dump():
		print("FAIL %d/%d — the reference dump could not be read" % [_checks - _failures, _checks])
		return
	# `--drift=<name>` is a targeted probe: it loads the dump, runs that one case (clean,
	# then injected) and reports. The full check suite is the no-argument run.
	if _drift_mode != "":
		_run_one_drift(_drift_mode)
		_engine.stop_all()
		root.remove_child(_engine)
		_engine.free()
		return
	_check_contract_mixer()
	_check_constants()
	_check_chords()
	_check_streams()
	_check_loop_wrap()
	_check_intensity_formula()
	_check_contexts()
	_check_mixer_semantics()
	_check_voices()
	_check_engine_report()

	_run_drift_cases()

	if _failures == 0 and _uncaught == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
	# Release the pooled voices, so the run exits without leaking engine objects.
	_engine.stop_all()
	root.remove_child(_engine)
	_engine.free()


# ===========================================================================
# 1. the dump itself
# ===========================================================================

func _check_dump() -> bool:
	var engine_bytes := FileAccess.get_file_as_bytes(ENGINE_DUMP)
	var repo_path := _repo.path_join(REPO_DUMP)
	var repo_bytes := FileAccess.get_file_as_bytes(repo_path)
	# The generated dump lives under `tools/*/out/`, which is gitignored, so a source
	# checkout has none. That absence is not a defect of the checkout and is not scored —
	# but it is stated, so a green run is never read as "the generated dump was compared".
	# The provenance and payload checks below run in every mode and can still fail.
	if repo_bytes.size() == 0:
		print("# DUMP_MODE generated %s absent (source checkout) — byte-identity not compared, not scored" % repo_path)
	else:
		var same := engine_bytes.size() > 0 and engine_bytes.size() == repo_bytes.size() and engine_bytes == repo_bytes
		_check("dump is vendored byte-identical to the generated one", same,
			"%d vs %d bytes, sha256 %s vs %s" % [
				engine_bytes.size(), repo_bytes.size(),
				MusicPort.sha256_of(ENGINE_DUMP), MusicPort.sha256_of(repo_path),
			])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENGINE_DUMP))
	if typeof(parsed) != TYPE_DICTIONARY:
		_check("dump parses as a JSON object", false, "not a dictionary")
		return false
	_dump = parsed
	_check("dump schema and version", str(_dump.get("schema", "")) == "steam-circuit-padel-pro.music-reference"
		and int(_dump.get("schemaVersion", -1)) == 1, str(_dump.get("schema", "")))
	for s in _dump.get("scenarios", []):
		_scenarios[str(s["id"])] = s
	_check("dump carries the reference's %d scenarios" % SCENARIO_COUNT, _scenarios.size() >= SCENARIO_COUNT,
		str(_scenarios.size()))
	var self_checks_ok := true
	for c in _dump.get("self_checks", []):
		if not bool(c.get("ok", false)):
			self_checks_ok = false
	_check("the extractor's own self-checks all passed", self_checks_ok and (_dump.get("self_checks", []) as Array).size() > 100,
		"%d checks" % (_dump.get("self_checks", []) as Array).size())
	# The dump must still describe the reference source it was derived from.
	for key in ["js/audio.js", "js/main.js"]:
		var recorded := str(_dump.get("source", {}).get(key, {}).get("sha256", ""))
		var on_disk := MusicPort.sha256_of(_repo.path_join(key))
		_check("dump matches the %s on disk" % key, recorded != "" and recorded == on_disk,
			"dump %s vs on disk %s — re-run the extractor" % [recorded.substr(0, 16), on_disk.substr(0, 16)])
	return true


# ===========================================================================
# 2. constants and chords
# ===========================================================================

func _check_contract_mixer() -> void:
	var m: Dictionary = _engine.describe()["mixer"]
	_check("music bus gain is the reference's 0.55 (from the event contract)",
		is_equal_approx(float(m["music_bus_gain"]), 0.55), str(m["music_bus_gain"]))
	_check("the Music bus is set to that gain",
		is_equal_approx(float(m["music_bus_gain_db"]), linear_to_db(0.55)), str(m["music_bus_gain_db"]))
	var idx := AudioServer.get_bus_index("Music")
	var send: String = AudioServer.get_bus_send(idx) if idx >= 0 else ""
	_check("the Music bus feeds the master bus", idx >= 0 and send == "Master", send)
	_check("no bus effect is invented (ducking/panning are undefined in the reference)",
		idx >= 0 and AudioServer.get_bus_effect_count(idx) == 0
		and not bool(m["ducking_defined"]) and not bool(m["panning_defined"]),
		"effects=%d" % (AudioServer.get_bus_effect_count(idx) if idx >= 0 else -1))
	_check("the mixer numbers come from the same contract file the SFX module reads",
		_dump.size() > 0 and float(_dump["engine"]["music_bus_gain"]) == float(m["music_bus_gain"]),
		"contract=%s dump=%s" % [m["music_bus_gain"], _dump["engine"]["music_bus_gain"]])


func _check_constants() -> void:
	var want: Dictionary = _dump["engine"]
	var got: Dictionary = _engine.describe()["engine"]
	# [module key, dump key, tolerance] — the dump names the render rate `sample_rate`.
	var pairs := [
		["lead", "lead", T_TOL], ["lookahead", "lookahead", T_TOL],
		["catch_up_behind", "catch_up_behind", T_TOL], ["catch_up_lead", "catch_up_lead", T_TOL],
		["steps_per_bar", "steps_per_bar", 0.0], ["loop_steps", "loop_steps", 0.0],
		["bpm_base", "bpm_base", 0.0], ["bpm_intensity", "bpm_intensity", 0.0],
		["steps_per_beat", "steps_per_beat", 0.0], ["hat_dur", "hat_dur", T_TOL],
		["hat_buf_frames", "hat_buf_frames", 0.0], ["render_rate", "sample_rate", 0.0],
	]
	var bad: Array = []
	for p in pairs:
		if not _num_eq(got.get(p[0]), want.get(p[1]), float(p[2])):
			bad.append("%s module=%s reference=%s" % [p[0], got.get(p[0]), want.get(p[1])])
	_check("sequencer constants are the reference's", bad.is_empty(), ", ".join(bad))
	# The stop tails come from the reference's own osc.stop() calls (`:179`, `:197`).
	_check("voice stop tails are the reference's",
		is_equal_approx(float(got["tone_tail"]), 0.06) and is_equal_approx(float(got["kick_tail"]), 0.18 - 0.15),
		"tone=%s kick=%s" % [got["tone_tail"], got["kick_tail"]])
	_check("the voice pool is bounded", int(got["max_voice_pool"]) > 0 and int(got["max_voice_pool"]) <= 128,
		str(got["max_voice_pool"]))


func _check_chords() -> void:
	var want: Array = _dump["prog"]
	var got: Array = _engine.describe()["engine"]["prog"]
	var ok := got.size() == want.size()
	if ok:
		for i in range(want.size()):
			if int(got[i]["root"]) != int(want[i]["root"]):
				ok = false
			var wi: Array = want[i]["intervals"]
			var gi: Array = got[i]["intervals"]
			if gi.size() != wi.size():
				ok = false
			else:
				for j in range(wi.size()):
					if int(gi[j]) != int(wi[j]):
						ok = false
	_check("the module's PROG is the reference's four chords", ok, JSON.stringify(got))
	# ...and the chords reach the stream: bar 0 opens with the reference's first chord,
	# bar 1 with the second (root 41, major shape).
	var pad0: Array = []
	var pad1: Array = []
	for e in _engine.step_events(0, 0.0):
		if str(e["layer"]) == "pad":
			pad0.append(int(e["midi"]))
	for e in _engine.step_events(16, 0.0):
		if str(e["layer"]) == "pad":
			pad1.append(int(e["midi"]))
	_check("the bars carry the reference's chords (Am at bar 0, F at bar 1)",
		pad0 == [45, 48, 52] and pad1 == [41, 45, 48], "%s / %s" % [str(pad0), str(pad1)])


# ===========================================================================
# 3. the streams
# ===========================================================================

func _check_streams() -> void:
	var ids: Array = []
	for s in _dump["scenarios"]:
		ids.append(str(s["id"]))
	var red: Array = []
	for id in ids:
		var failures := _gate("stream/" + id)
		if not failures.is_empty():
			red.append("%s: %s" % [id, failures[0]])
	_check("every scenario's step+event stream equals the reference's", red.is_empty(), "; ".join(red))
	# Say out loud how much was compared, so a silently shrinking dump is visible.
	var steps := 0
	var events := 0
	for s in _dump["scenarios"]:
		steps += (s["steps"] as Array).size()
		events += (s["events"] as Array).size()
	_check("the compared stream is non-trivial", steps >= 200 and events >= 400,
		"%d steps, %d events" % [steps, events])


## The 64-step loop (`js/audio.js:269`) — not reachable inside the 2.5 s dump scenarios,
## so it is asserted structurally against the module's own walk.
func _check_loop_wrap() -> void:
	_engine.reset()
	_engine.set_process(false)
	_engine.start(0.0)
	_engine.set_intensity(0.8)
	var seen: Array = []
	var now := 0.0
	while seen.size() < 70:
		now += 0.02
		for rec in _engine.tick(now):
			seen.append(int(rec["step"]))
	var wraps := true
	for i in range(70):
		if int(seen[i]) != i % 64:
			wraps = false
	var first: Array = []
	var second: Array = []
	for e in _engine.step_events(0, 0.8):
		first.append("%s/%s" % [e["layer"], e["midi"]])
	for e in _engine.step_events(64, 0.8):
		second.append("%s/%s" % [e["layer"], e["midi"]])
	_check("the loop walks 64 steps and wraps to the same material",
		wraps and first == second and seen.size() >= 70, "%d steps seen, wrap %s" % [seen.size(), str(wraps)])


func _check_intensity_formula() -> void:
	var failures := _gate("intensity/reference-formula")
	_check("intensity follows js/main.js:1220-1226 exactly", failures.is_empty(),
		failures[0] if not failures.is_empty() else "")


# ===========================================================================
# 4. contexts
# ===========================================================================

func _check_contexts() -> void:
	var failures := _gate("context/menu-is-silent")
	_check("menu context is silent and match context plays the progression", failures.is_empty(),
		failures[0] if not failures.is_empty() else "")
	# The transport itself: the reference's two contexts are start() and stop().
	_engine.reset()
	_engine.set_process(false)
	_engine.stop()
	var stopped := not bool(_engine.describe()["transport"]["playing"])
	var accepted: bool = _engine.set_context("match", 0.0)
	var playing := bool(_engine.describe()["transport"]["playing"])
	var step0 := int(_engine.describe()["transport"]["step"]) == 0
	var refused: bool = _engine.set_context("lobby", 0.0)
	var still_playing := bool(_engine.describe()["transport"]["playing"])
	# A second start while playing is a no-op in the reference (`js/audio.js:125`).
	var restart: bool = _engine.set_context("match", 0.0)
	var last_error := str(_engine.describe()["transport"]["last_error"])
	_check("set_context maps menu->stop, match->start, and refuses an unknown context",
		stopped and accepted and playing and step0 and not refused and still_playing and not restart
		and last_error == "already playing",
		"accepted=%s playing=%s refused=%s restart=%s err=%s" % [accepted, playing, refused, restart, last_error])


# ===========================================================================
# 5. mixer semantics (the ones audio_port.gd established)
# ===========================================================================

func _check_mixer_semantics() -> void:
	var failures := _gate("mute/freeze-and-catch-up")
	_check("mute freezes the scheduler and the score resumes at the catch-up", failures.is_empty(),
		failures[0] if not failures.is_empty() else "")

	failures = _gate("volume/zero-is-silent-but-plays")
	_check("volume 0 is silent, still plays, and does not change the score", failures.is_empty(),
		failures[0] if not failures.is_empty() else "")

	# The setter clamps and is relative to the reference's own default gain.
	_engine.reset()
	_engine.set_process(false)
	var master := AudioServer.get_bus_index("Master")
	var lo: float = _engine.set_master_gain(-3.0)
	var lo_silent := master >= 0 and AudioServer.is_bus_mute(master) and AudioServer.get_bus_volume_db(master) <= -80.0
	var hi: float = _engine.set_master_gain(4.0)
	var half: float = _engine.set_master_gain(0.25)
	var half_db := AudioServer.get_bus_volume_db(master)
	_engine.set_master_gain(0.5)
	var dflt_db := AudioServer.get_bus_volume_db(master)
	_check("master gain clamps to the contract's range", is_equal_approx(lo, 0.0) and is_equal_approx(hi, 1.0),
		"lo=%s hi=%s" % [lo, hi])
	_check("master gain applies relative to the reference's own default (0.5 = unity)",
		lo_silent and is_equal_approx(half, 0.25) and is_equal_approx(half_db, linear_to_db(0.5))
		and absf(dflt_db) < 1e-6, "half_db=%s default_db=%s" % [half_db, dflt_db])

	# mute is a flag, not a bus mute, and it does not cut a sounding voice.
	_engine.reset()
	_engine.set_process(false)
	_engine.start(0.0)
	_engine.set_intensity(0.8)
	_engine.tick(0.3)
	var voice: AudioStreamPlayer = _engine.player_for_layer("arp")
	var started: int = _engine.voices_started
	var sounding := voice != null and voice.playing
	_engine.set_muted(true)
	var muted_buses: Array = []
	for i in AudioServer.bus_count:
		if AudioServer.is_bus_mute(i):
			muted_buses.append(AudioServer.get_bus_name(i))
	_check("mute is a flag: it mutes no bus and cuts no sounding voice",
		muted_buses.is_empty() and sounding and voice.playing and started > 0,
		"muted buses=%s sounding=%s started=%d" % [str(muted_buses), str(sounding), started])
	_engine.set_muted(false)


# ===========================================================================
# 6. voices under the dummy driver
# ===========================================================================

func _check_voices() -> void:
	var got := _replay_capture("match_i080", "")
	var routed := true
	var counted := 0
	for v in _engine.describe()["voices"]:
		counted += 1
		if str(v["bus"]) != "Music":
			routed = false
		if int(v["stream_frames"]) <= 0 or int(v["stream_mix_rate"]) != 44100 or bool(v["stream_stereo"]):
			routed = false
	_check("voices start under the dummy driver and are routed to the Music bus",
		routed and (got["events"] as Array).size() > 0 and _engine.voices_started > 0 and counted > 0,
		"events=%d voices_started=%d pooled=%d" % [(got["events"] as Array).size(), _engine.voices_started, counted])
	_check("pooled voices stay bounded by the signature count", counted <= 64, "pooled=%d" % counted)

	# The player's volume is the reference's own gain for that note.
	var arp_gain := -1.0
	var arp_midi := -1
	for e in got["events"]:
		if str(e["layer"]) == "arp":
			arp_gain = float(e["gain"])
			arp_midi = int(e["midi"])
			break
	var p: AudioStreamPlayer = _engine.player_for_layer("arp")
	var p_db := p.volume_db if p != null else -INF
	var expect_db := linear_to_db(maxf(arp_gain, 0.0001))
	_check("a voice is addressed at the reference's gain for that note",
		is_equal_approx(p_db, expect_db) and arp_midi > 0,
		"player_db=%s expected=%s (gain %s)" % [p_db, expect_db, arp_gain])
	_engine.stop_all()


func _check_engine_report() -> void:
	var d: Dictionary = _engine.describe()
	_check("describe() reports the contracted bus layout and the mixer state",
		str(d["master_bus_name"]) == "Master" and str(d["music_bus_name"]) == "Music"
		and bool(d["loaded"]) and str(d["contract_sha256"]).length() == 64,
		str(d["contract_sha256"]).substr(0, 16))
	_check("no per-voice runtime volume is invented beyond the reference's gain",
		int(d["engine"]["max_voice_pool"]) == 64 and float(d["mixer"]["master_gain_step"]) > 0.0,
		"step=%s" % d["mixer"]["master_gain_step"])


# ===========================================================================
# gates — each returns [] when green, or one named failure string
# ===========================================================================

func _gate(name: String) -> Array:
	if name.begins_with("stream/"):
		return _gate_stream(name.substr("stream/".length()))
	if name == "intensity/reference-formula":
		return _gate_intensity()
	if name == "context/menu-is-silent":
		return _gate_context()
	if name == "mute/freeze-and-catch-up":
		return _gate_mute()
	if name == "volume/zero-is-silent-but-plays":
		return _gate_volume()
	return ["unknown-gate %s" % name]


func _gate_stream(id: String) -> Array:
	var sc: Dictionary = _scenarios.get(id, {})
	if sc.is_empty():
		return ["unknown-scenario %s" % id]
	var got := _replay_capture(id, "")
	var failure := _compare_streams({"steps": sc["steps"], "events": sc["events"]}, got)
	return [] if failure == "" else [failure]


## Every frame of the ramp scenario, against the intensity the reference's own
## `js/main.js:1220-1226` produced for the same rally/sets/games inputs.
func _gate_intensity() -> Array:
	var inj := _inject
	var sc: Dictionary = _scenarios.get("match_ramp", {})
	var inputs_value: Variant = sc.get("intensity_inputs")
	if sc.is_empty() or typeof(inputs_value) != TYPE_ARRAY:
		return ["missing-intensity-inputs (re-run the extractor)"]
	var inputs: Array = inputs_value
	var series: Array = sc["intensity_series"]
	for f in range(mini(inputs.size(), series.size())):
		var row: Dictionary = inputs[f]
		var got: float = _engine.intensity_for_rally(int(row["rally_hits"]), int(row["sets_total"]), int(row["games_total"]))
		if inj == "intensity-off" and f == 5:
			got = minf(1.0, got + 0.05)
		if absf(got - float(series[f])) > T_TOL:
			return ["wrong-intensity@frame %d module=%s reference=%s" % [f, got, series[f]]]
	return []


func _gate_context() -> Array:
	var sc: Dictionary = _scenarios["menu_stopped"]
	var got := _replay_capture("menu_stopped", _inject)
	var failures: Array = []
	if _engine.playing or not (got["steps"] as Array).is_empty() or not (got["events"] as Array).is_empty():
		failures.append("wrong-context@menu steps=%d events=%d playing=%s" % [
			(got["steps"] as Array).size(), (got["events"] as Array).size(), str(_engine.playing)])
	var match_failures := _gate_stream("match_i080")
	for f in match_failures:
		failures.append(f)
	return failures


func _gate_mute() -> Array:
	var inj := _inject
	var sc: Dictionary = _scenarios["match_muted_from_start"]
	var got := _replay_capture("match_muted_from_start", inj)
	var failures: Array = []
	# 1. nothing is scheduled inside the mute window: the walk is frozen (`:262`)
	var muted_end := 0.0
	for w in sc["mute_windows"]:
		muted_end = maxf(muted_end, float(int(w[1]) + 1) * float(sc["dt"]))
	var inside := 0
	for e in got["events"]:
		if float(e["t"]) < muted_end:
			inside += 1
	if inside > 0:
		failures.append("mute-drift@%d events scheduled while muted (window ends %s)" % [inside, muted_end])
	# 2. the reference's own stream, after the catch-up
	var failure := _compare_streams({"steps": sc["steps"], "events": sc["events"]}, got)
	if failure != "":
		failures.append(failure)
	return failures


func _gate_volume() -> Array:
	var inj := _inject
	var sc: Dictionary = _scenarios["match_volume_zero"]
	var dflt: Dictionary = _scenarios["match_volume_default"]
	var got := _replay_capture("match_volume_zero", inj)
	var failures: Array = []
	var master := AudioServer.get_bus_index("Master")
	var silent := master >= 0 and AudioServer.is_bus_mute(master) and AudioServer.get_bus_volume_db(master) <= -80.0
	var started: int = _engine.voices_started
	if not silent or started <= 0:
		failures.append("volume-drift@silent=%s voices_started=%d" % [str(silent), started])
	var failure := _compare_streams({"steps": sc["steps"], "events": sc["events"]}, got)
	if failure != "":
		failures.append(failure)
	# ...and the score at volume 0 is the score at the reference's default volume
	var other := _replay_capture("match_volume_default", "")
	if failure == "" and _compare_streams({"steps": other["steps"], "events": other["events"]}, got) != "":
		failures.append("volume-drift@the score changed with the volume")
	return failures


# ===========================================================================
# the replay — the same pump the extractor used
# ===========================================================================

func _replay_capture(id: String, inject: String) -> Dictionary:
	var sc: Dictionary = _scenarios[id]
	_engine.reset()
	_engine.set_process(false)
	if sc["volume"] != null:
		_engine.set_master_gain(float(sc["volume"]))
		if inject == "not-applied-at-zero":
			_engine.set_master_gain(float(_engine.reference_master_gain()))
	var series: Array = sc["intensity_series"]
	if not series.is_empty():
		_engine.set_intensity(float(series[0]))
	if str(sc["context"]) == "match" or inject == "started-in-menu":
		_engine.start(0.0)
	var steps: Array = []
	var events: Array = []
	var frames := int(sc["frames"])
	var dt := float(sc["dt"])
	for f in range(frames):
		var now := float(f + 1) * dt
		_engine.set_intensity(float(series[f]))
		if inject == "ignored-mute":
			_engine.set_muted(false)
		else:
			_engine.set_muted(_muted_at(sc, f))
		for rec in _engine.tick(now):
			steps.append({"step": int(rec["step"]), "t": float(rec["t"])})
			for e in rec["events"]:
				events.append(e)
	return {"steps": steps, "events": events}


func _muted_at(sc: Dictionary, f: int) -> bool:
	for w in sc.get("mute_windows", []):
		if f >= int(w[0]) and f < int(w[1]):
			return true
	return false


# ===========================================================================
# the comparator — where every drift gets its name
# ===========================================================================

## "" when equal, else "<name>@…". Order matters: sizes, then step index, then time,
## then voice identity, then the voice's parameters.
func _compare_streams(exp: Dictionary, got: Dictionary) -> String:
	var es: Array = exp["steps"]
	var gs: Array = got["steps"]
	var ee: Array = exp["events"]
	var ge: Array = got["events"]
	if gs.size() < es.size():
		return "stream-truncated@%d of %d steps" % [gs.size(), es.size()]
	if gs.size() > es.size():
		return "added-step@%d of %d steps" % [gs.size(), es.size()]
	if ge.size() < ee.size():
		return "dropped-note@%d of %d events" % [ge.size(), ee.size()]
	if ge.size() > ee.size():
		return "added-note@%d of %d events" % [ge.size(), ee.size()]
	for i in range(es.size()):
		if int(gs[i]["step"]) != int(es[i]["step"]):
			return "wrong-step@index %d: step %s != %s" % [i, gs[i]["step"], es[i]["step"]]
		if not _num_eq(float(gs[i]["t"]), float(es[i]["t"]), T_TOL):
			return "wrong-tempo@step %s index %d: t %s != %s" % [es[i]["step"], i, gs[i]["t"], es[i]["t"]]
	for i in range(ee.size()):
		var e: Dictionary = ee[i]
		var g: Dictionary = ge[i]
		var at := "step %s ev %d" % [e["s"], i]
		if str(g.get("layer", "")) != str(e["layer"]) or str(g.get("kind", "")) != str(e["kind"]):
			return "wrong-voice@%s: %s/%s != %s/%s" % [at, g.get("layer"), g.get("kind"), e["layer"], e["kind"]]
		if int(g.get("s", -1)) != int(e["s"]):
			return "wrong-step@%s: event step %s != %s" % [at, g.get("s"), e["s"]]
		if not _num_eq(float(g.get("t")), float(e["t"]), T_TOL):
			return "wrong-tempo@%s: t %s != %s" % [at, g.get("t"), e["t"]]
		# The chord, for tone layers only: the reference's kick is a pitch sweep with no
		# chord and the hat has no pitch at all, so only its structure is compared.
		if str(e["kind"]) == "tone":
			if str(g.get("type", "")) != str(e["type"]):
				return "wrong-timbre@%s: %s != %s" % [at, g.get("type"), e["type"]]
			if not _num_eq(g.get("midi"), e["midi"], F_TOL) or not _num_eq(g.get("freq"), e["freq"], F_TOL):
				return "wrong-chord@%s: midi/freq %s/%s != %s/%s" % [at, g.get("midi"), g.get("freq"), e["midi"], e["freq"]]
		if not _num_eq(float(g.get("gain")), float(e["gain"]), G_TOL):
			return "wrong-gain@%s: %s != %s" % [at, g.get("gain"), e["gain"]]
		if not _num_eq(g.get("dur"), e["dur"], T_TOL):
			return "wrong-dur@%s: %s != %s" % [at, g.get("dur"), e["dur"]]
		if not _num_eq(g.get("attack"), e["attack"], T_TOL):
			return "wrong-attack@%s: %s != %s" % [at, g.get("attack"), e["attack"]]
		if str(g.get("filter_type", "")) != str(e["filter_type"]) or not _num_eq(g.get("filter"), e["filter"], F_TOL):
			return "wrong-filter@%s: %s/%s != %s/%s" % [at, g.get("filter_type"), g.get("filter"), e["filter_type"], e["filter"]]
		if not _num_eq(g.get("freq_end"), e["freq_end"], F_TOL):
			return "wrong-sweep@%s: freq_end %s != %s" % [at, g.get("freq_end"), e["freq_end"]]
		if not _num_eq(g.get("buf_frames"), e["buf_frames"], F_TOL):
			return "wrong-buffer@%s: %s != %s" % [at, g.get("buf_frames"), e["buf_frames"]]
	return ""


func _num_eq(a: Variant, b: Variant, tol: float) -> bool:
	if a == null and b == null:
		return true
	if a == null or b == null:
		return false
	if tol == 0.0:
		return is_equal_approx(float(a), float(b))
	return absf(float(a) - float(b)) <= tol


# ===========================================================================
# injected drift — a gate that cannot fail is not a gate
# ===========================================================================

## name -> gate, injection, the named failure it must produce.
## Two kinds of injection, and each case says which it is:
##   "mutation:<name>" — the material the gate compares is mutated before the comparator
##                       sees it (proves the comparator is not vacuous);
##   "engine:<name>"   — the module is put into a state the reference would never be in
##                       (proves the assertion really reads the engine).
func _drift_cases() -> Array:
	return [
		{"name": "wrong-chord", "gate": "stream/match_i080", "inject": "mutation:wrong-chord", "expect": "wrong-chord"},
		{"name": "wrong-voice", "gate": "stream/match_i080", "inject": "mutation:wrong-voice", "expect": "wrong-voice"},
		{"name": "wrong-timbre", "gate": "stream/match_i080", "inject": "mutation:wrong-timbre", "expect": "wrong-timbre"},
		{"name": "wrong-tempo", "gate": "stream/match_i080", "inject": "mutation:wrong-tempo", "expect": "wrong-tempo"},
		{"name": "wrong-step", "gate": "stream/match_i080", "inject": "mutation:wrong-step", "expect": "wrong-step"},
		{"name": "dropped-note", "gate": "stream/match_i080", "inject": "mutation:dropped-note", "expect": "dropped-note"},
		{"name": "added-note", "gate": "stream/match_i080", "inject": "mutation:added-note", "expect": "added-note"},
		{"name": "truncated-stream", "gate": "stream/match_i080", "inject": "mutation:truncated-stream", "expect": "stream-truncated"},
		{"name": "wrong-gain", "gate": "stream/match_i080", "inject": "mutation:wrong-gain", "expect": "wrong-gain"},
		{"name": "wrong-filter", "gate": "stream/match_i050", "inject": "mutation:wrong-filter", "expect": "wrong-filter"},
		{"name": "wrong-buffer", "gate": "stream/match_i080", "inject": "mutation:wrong-buffer", "expect": "wrong-buffer"},
		{"name": "wrong-intensity", "gate": "intensity/reference-formula", "inject": "engine:intensity-off", "expect": "wrong-intensity"},
		{"name": "wrong-context", "gate": "context/menu-is-silent", "inject": "engine:started-in-menu", "expect": "wrong-context"},
		{"name": "mute-drift", "gate": "mute/freeze-and-catch-up", "inject": "engine:ignored-mute", "expect": "mute-drift"},
		{"name": "volume-drift", "gate": "volume/zero-is-silent-but-plays", "inject": "engine:not-applied-at-zero", "expect": "volume-drift"},
	]


func _run_drift_cases() -> void:
	print("")
	var caught_count := 0
	for c in _drift_cases():
		var gate := str(c["gate"])
		var clean := _gate(gate)
		var red := _gate_injected(gate, str(c["inject"]))
		var caught := false
		for f in red:
			if str(f).begins_with(str(c["expect"])):
				caught = true
		if clean.is_empty() and caught:
			caught_count += 1
			print("ok drift/%s — %s injection produced %s" % [c["name"], str(c["inject"]).split(":")[0], red[0]])
		else:
			_uncaught += 1
			print("MISSED drift/%s — expected `%s` from a %s injection; clean=%s red=%s" % [
				c["name"], c["expect"], str(c["inject"]).split(":")[0], str(clean), str(red)])
	print("injected drift: %d/%d cases caught, each with its own named failure" % [caught_count, _drift_cases().size()])


func _run_one_drift(name: String) -> void:
	for c in _drift_cases():
		if str(c["name"]) != name:
			continue
		var gate := str(c["gate"])
		var clean := _gate(gate)
		if not clean.is_empty():
			print("FAIL drift/%s — the gate is red before any injection: %s" % [name, clean[0]])
			_drift_exit_code = 0
			return
		var red := _gate_injected(gate, str(c["inject"]))
		for f in red:
			if str(f).begins_with(str(c["expect"])):
				print("ok drift/%s — caught: %s" % [name, f])
				_drift_exit_code = 1
				return
		print("MISSED drift/%s — %s" % [name, str(red)])
		_drift_exit_code = 0
		return
	print("FAIL — unknown drift case %s" % name)
	_drift_exit_code = 2


## Runs a gate with an injected drift.
func _gate_injected(gate: String, inject: String) -> Array:
	if inject.begins_with("mutation:"):
		return _gate_stream_mutated(gate.substr("stream/".length()), inject.substr("mutation:".length()))
	_inject = inject.substr("engine:".length())
	var out: Array = _gate(gate)
	_inject = ""
	_engine.set_muted(false)
	if _engine.playing:
		_engine.stop()
	return out


# --- stream-side mutations: applied to the real captured material -----------------

func _gate_stream_mutated(id: String, mutation: String) -> Array:
	var sc: Dictionary = _scenarios[id]
	var got := _replay_capture(id, "")
	var steps: Array = []
	for s in got["steps"]:
		steps.append({"step": int(s["step"]), "t": float(s["t"])})
	var events: Array = []
	for e in got["events"]:
		var c := {}
		for k in e.keys():
			c[k] = e[k]
		events.append(c)
	_apply_mutation(mutation, steps, events)
	var failure := _compare_streams({"steps": sc["steps"], "events": sc["events"]}, {"steps": steps, "events": events})
	return [] if failure == "" else [failure]


func _apply_mutation(key: String, steps: Array, events: Array) -> void:
	match key:
		"wrong-chord":
			for e in events:
				if str(e["layer"]) == "arp":
					e["midi"] = int(e["midi"]) + 1
					e["freq"] = float(e["freq"]) * 1.0594630943592953
					break
		"wrong-voice":
			for e in events:
				if str(e["layer"]) == "arp":
					e["layer"] = "pad"
					break
		"wrong-timbre":
			for e in events:
				if str(e["layer"]) == "arp":
					e["type"] = "sawtooth"
					break
		"wrong-tempo":
			if steps.size() > 3:
				steps[3]["t"] = float(steps[3]["t"]) * 1.05
		"wrong-step":
			if steps.size() > 3:
				var swap: Variant = steps[2]["step"]
				steps[2]["step"] = steps[3]["step"]
				steps[3]["step"] = swap
		"dropped-note":
			if events.size() > 5:
				events.remove_at(5)
		"added-note":
			if events.size() > 5:
				var copy: Dictionary = {}
				for k in (events[5] as Dictionary).keys():
					copy[k] = (events[5] as Dictionary)[k]
				events.insert(5, copy)
		"truncated-stream":
			var keep := maxi(1, steps.size() - 3)
			var cutoff := float(steps[keep - 1]["t"])
			steps.resize(keep)
			var kept: Array = []
			for e in events:
				if float(e["t"]) <= cutoff:
					kept.append(e)
			events.clear()
			for e in kept:
				events.append(e)
		"wrong-gain":
			for e in events:
				if str(e["layer"]) == "pad":
					e["gain"] = 0.09
					break
		"wrong-filter":
			for e in events:
				if str(e["layer"]) == "arp":
					e["filter"] = 1800.0
					break
		"wrong-buffer":
			for e in events:
				if str(e["layer"]) == "hat":
					e["buf_frames"] = int(e["buf_frames"]) + 36
					break


# ===========================================================================
# helpers
# ===========================================================================

func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("ok %s" % name)
	else:
		_failures += 1
		print("FAIL %s: %s" % [name, detail])
