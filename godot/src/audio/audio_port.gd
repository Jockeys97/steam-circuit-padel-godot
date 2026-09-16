extends Node
## audio_port.gd — the port's audio layer, built on the verified event -> sound contract.
##
## THE CONTRACT THIS IMPLEMENTS
##   tools/audio-port/event-map.json — 10 game events, 9 `sfx` call sites in the
##   reference (`js/game.js`), 10 baked 44.1 kHz mono one-shots. It is vendored
##   byte-identical to `res://src/audio/event_map.json` by
##   `node tools/audio-port/sync-godot-audio.mjs`, and the WAVs to
##   `res://assets/audio/<sound>.wav` by the same tool.
##
## This module CONSUMES that map; it does not restate it. The sound set, the event
## ids, the mixer default, the master-gain range and the music-bus gain are read
## out of the JSON at `_ready()`. Nothing here hard-codes a second copy of a
## contract number, so a contract change that the module cannot honour surfaces as
## a failure in `godot/tests/audio_port_test.gd` instead of as a silently
## different-sounding game.
##
## WHAT IS DELIBERATELY *NOT* HERE (the contract records these as undecided, so the
## port must not invent them):
##   - No binding from the ported sim's message ids to sounds. The sim stores
##     string message ids (`state.events`, `state.pointMessage`; `sim.gd`'s
##     `add_event` takes a String), and event-map.json's `port.eventIdAnchors`
##     says which ids the sim can store at each trigger. Which id should *carry*
##     which sound is a presentation-layer decision the contract leaves open
##     (`honestUnknowns[4]`). `port_bindings()` therefore returns an empty map and
##     `play_event()` accepts only the contract's event ids — it rejects
##     `evWallValid`, `pointYou`, `evTape` and every other port message id.
##   - No ducking, compressor, limiter, fade or panning: `mixer.ducking.defined`
##     and `mixer.panning.defined` are `false` in the reference, so no bus effect
##     is installed and every player stays a plain (non-positional)
##     AudioStreamPlayer at 0 dB. Overlap is additive summation.
##   - No per-event runtime volume: each baked WAV already contains its synth gain
##     (`mixer.unknowns[1]`). Players sit at `volume_db = 0.0`.
##   - No randomised variants: how many variants a player holds is out of contract
##     (`notInContract[1]`). One player per sound, `max_polyphony` raised so the
##     same sound can overlap itself, as the reference's per-call oscillators do.
##   - No music. The 5 generative voices are not event-triggered and have no baked
##     WAV (`notInContract[0]`); the `Music` bus exists at the reference's gain for
##     whoever ports the sequencer, but nothing in this module routes to it.
##
## MUTE vs VOLUME (two different things in the reference, kept different here):
##   - `set_muted(true)` (`js/audio.js:278-280`) sets one global flag and nothing
##     else. Every synth entry point returns early while it is set
##     (`js/audio.js:24,41,157,184,202,262`), so it gates NEW voices; a voice
##     already sounding is not cut. This module therefore refuses to start
##     playback and does not mute any bus.
##   - `set_volume` / `set_master_gain` (`js/audio.js:286-289`) clamps to the
##     range and applies a gain. Volume 0 is silent but still plays.
##
## MASTER GAIN AND THE BAKED LEVEL (derived, not tuned):
##   the baked WAVs already contain the reference's master gain of 0.5
##   (`js/audio.js:4-5`, applied at `:15`): measured peak of `bounce.wav` is 0.1266
##   = synth gain 0.3 (`js/audio.js:65-67`) x 0.5. Godot's buses sit at 0 dB
##   (unity), so the reference DEFAULT maps to unity and the 0..1 slider is applied
##   relative to it: `bus_db = linear_to_db(value / default)`. At the default the
##   bus is 0 dB and the module reproduces the baked level exactly; nothing is
##   attenuated twice, and no target-loudness number is invented
##   (`mixer.unknowns[0]`).

const CONTRACT_PATH := "res://src/audio/event_map.json"
const ASSET_DIR := "res://assets/audio"
const BUS_LAYOUT_PATH := "res://assets/audio/padel_audio_bus.tres"
const CONTRACT_SCHEMA := "steam-circuit-padel-pro.audio-event-map"

const MASTER_BUS := "Master"
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
## Godot's minimum bus volume; stands in for the reference's gain 0.
const SILENCE_DB := -80.0
## The reference builds fresh oscillators per call (`js/audio.js:30-46`), so the
## same sound can overlap itself. One player per sound, many voices.
const MAX_POLYPHONY := 16

## Parsed contract copy, as loaded by this node (read-only for consumers).
var contract: Dictionary = {}
## sha256 of the contract copy this node loaded.
var contract_sha256: String = ""
## True when the contract copy parsed and declares the expected schema.
var loaded: bool = false
## Set by every failed `play_event()`; "" after a successful one.
var last_play_error: String = ""

var _players: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _master_gain: float = 0.0
var _muted: bool = false


func _ready() -> void:
	_load_contract()
	_build_buses()
	_build_players()
	_apply_master_gain()


## Tear everything down and rebuild from the contract. Legitimate on a match
## restart; also what the drift test uses to get a pristine engine per scenario.
func reset() -> void:
	stop_all()
	for p in _players.values():
		if is_instance_valid(p):
			p.free()
	_players.clear()
	_order = PackedStringArray()
	_muted = false
	_load_contract()
	_build_buses()
	_build_players()
	_apply_master_gain()


# ---------------------------------------------------------------------------
# contract loading
# ---------------------------------------------------------------------------

func _load_contract() -> void:
	loaded = false
	contract = {}
	contract_sha256 = ""
	if not FileAccess.file_exists(CONTRACT_PATH):
		push_error("audio_port: contract copy missing at %s — run `node tools/audio-port/sync-godot-audio.mjs`" % CONTRACT_PATH)
		return
	contract_sha256 = sha256_of(CONTRACT_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("audio_port: %s is not a JSON object" % CONTRACT_PATH)
		return
	contract = parsed
	if str(contract.get("schema", "")) != CONTRACT_SCHEMA:
		push_error("audio_port: %s declares schema '%s', expected '%s'" % [CONTRACT_PATH, contract.get("schema", ""), CONTRACT_SCHEMA])
		return
	if not contract.has("events") or (contract["events"] as Array).is_empty():
		push_error("audio_port: %s declares no events" % CONTRACT_PATH)
		return
	loaded = true
	_muted = muted_default()
	_master_gain = reference_master_gain()


## sha256 of a file, res:// or absolute. "" when the file is not readable.
static func sha256_of(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


# ---------------------------------------------------------------------------
# contract accessors (all values come from the JSON)
# ---------------------------------------------------------------------------

## `mixer.masterGainDefault.value` — 0.5 in the reference, and this is the level
## the bake already contains, so it is the module's unity reference.
func reference_master_gain() -> float:
	return float(_mixer().get("masterGainDefault", {}).get("value", 0.5))


## `mixer.musicBusGain.value` — 0.55 in the reference (music only; no WAV in this
## contract routes through that bus).
func reference_music_bus_gain() -> float:
	return float(_mixer().get("musicBusGain", {}).get("value", 0.55))


## `mixer.mute.default` — false in the reference.
func muted_default() -> bool:
	return bool(_mixer().get("mute", {}).get("default", false))


func master_gain_range() -> Dictionary:
	var r: Dictionary = _mixer().get("masterGainRange", {})
	return {
		"min": float(r.get("min", 0.0)),
		"max": float(r.get("max", 1.0)),
		"step": float(r.get("step", 0.01)),
	}


func _mixer() -> Dictionary:
	var m: Variant = contract.get("mixer", {})
	return m if typeof(m) == TYPE_DICTIONARY else {}


func event_ids() -> PackedStringArray:
	return _order.duplicate()


func sound_for_event(event_id: String) -> String:
	var e := _contract_event(event_id)
	return str(e.get("sound", "")) if not e.is_empty() else ""


func _contract_event(event_id: String) -> Dictionary:
	for e in contract.get("events", []):
		if str(e.get("id", "")) == event_id:
			return e
	return {}


## Always empty. The contract leaves the sim-message-id -> sound binding open
## (`honestUnknowns[4]`); inventing it here would be a new design decision.
func port_bindings() -> Dictionary:
	return {}


func player_for(event_id: String) -> AudioStreamPlayer:
	return _players.get(event_id, null)


# ---------------------------------------------------------------------------
# buses
# ---------------------------------------------------------------------------

func _build_buses() -> void:
	_ensure_bus(MASTER_BUS, "", 0.0)
	_ensure_bus(SFX_BUS, MASTER_BUS, 0.0)
	_ensure_bus(MUSIC_BUS, MASTER_BUS, linear_to_db(reference_music_bus_gain()))


## Names the bus, points it at `send` and sets its level; adds it if absent.
## Idempotent, so no project setting (and no `default_bus_layout.tres`) is needed.
func _ensure_bus(bus_name: String, send: String, volume_db: float) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	AudioServer.set_bus_volume_db(idx, volume_db)
	return idx


# ---------------------------------------------------------------------------
# players
# ---------------------------------------------------------------------------

func _build_players() -> void:
	_players.clear()
	_order = PackedStringArray()
	for e in contract.get("events", []):
		var id := str(e.get("id", ""))
		var sound := str(e.get("sound", ""))
		if id == "" or sound == "":
			continue
		var stream: AudioStreamWAV = _load_stream(sound)
		var p := AudioStreamPlayer.new()
		p.name = "sfx_" + id.replace("-", "_")
		p.stream = stream
		p.bus = SFX_BUS
		# No per-event runtime volume exists in the reference (`mixer.unknowns[1]`).
		p.volume_db = 0.0
		p.max_polyphony = MAX_POLYPHONY
		add_child(p)
		_players[id] = p
		_order.append(id)


func _load_stream(sound: String) -> AudioStreamWAV:
	var path := ASSET_DIR.path_join(sound + ".wav")
	if not ResourceLoader.exists(path, "AudioStreamWAV"):
		push_error("audio_port: no AudioStreamWAV at %s — run `node tools/audio-port/sync-godot-audio.mjs`" % path)
		return null
	return load(path) as AudioStreamWAV


# ---------------------------------------------------------------------------
# playback
# ---------------------------------------------------------------------------

## Starts the event's one-shot. Returns true when a voice was started.
## false + `last_play_error` when: the id is not a contract event id (port message
## ids belong here only once the contract decides the binding), the module is
## muted, the contract did not load, or the node is not in a running tree (an
## engine limit — Godot cannot start playback outside the tree).
func play_event(event_id: String) -> bool:
	last_play_error = ""
	if not loaded:
		last_play_error = "contract not loaded"
		return false
	var p: AudioStreamPlayer = _players.get(event_id, null)
	if p == null:
		last_play_error = "not a contract event id: %s" % event_id
		return false
	if _muted:
		# `js/audio.js:24,41,157,184,202,262` — early return; a sounding voice is
		# not cut, so this is not a bus mute.
		last_play_error = "muted"
		return false
	if not is_inside_tree() or not p.is_inside_tree():
		last_play_error = "outside the scene tree"
		return false
	p.play()
	return true


func is_playing(event_id: String) -> bool:
	var p: AudioStreamPlayer = _players.get(event_id, null)
	return p != null and p.playing


func stop_all() -> void:
	for p in _players.values():
		if is_instance_valid(p):
			p.stop()


# ---------------------------------------------------------------------------
# mixer
# ---------------------------------------------------------------------------

## `js/audio.js:286-289` — `Math.min(1, Math.max(0, Number(v) || 0))` with the
## range taken from the contract. Clamp only: the 0.01 step belongs to the slider
## (`index.html:426`), not to the setter, so no quantisation is applied.
## Returns the value actually stored.
func set_master_gain(value: float) -> float:
	var rng := master_gain_range()
	var v := value
	if is_nan(v):
		v = 0.0
	_master_gain = clampf(v, rng["min"], rng["max"])
	_apply_master_gain()
	return _master_gain


func master_gain() -> float:
	return _master_gain


## `js/audio.js:278-280` — the flag only. See the header for why no bus is muted.
func set_muted(flag: bool) -> void:
	_muted = bool(flag)


func is_muted() -> bool:
	return _muted


## Master bus level, relative to the level the bake already contains.
func _apply_master_gain() -> void:
	var idx := AudioServer.get_bus_index(MASTER_BUS)
	if idx < 0:
		return
	var reference := reference_master_gain()
	var relative := (_master_gain / reference) if reference > 0.0 else 0.0
	if relative <= 0.0:
		AudioServer.set_bus_volume_db(idx, SILENCE_DB)
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(relative))
		AudioServer.set_bus_mute(idx, false)


# ---------------------------------------------------------------------------
# the engine's own view of itself — what the drift test compares to the contract
# ---------------------------------------------------------------------------

## One dictionary describing everything this module believes and does: per-event
## stream/bus/hash facts, the bus graph, the mixer state. The test compares it
## field by field against the contract, so drift on either side is a failure.
func describe() -> Dictionary:
	var rows: Array = []
	for id in _order:
		var e := _contract_event(id)
		var wav: Dictionary = e.get("wav", {})
		var p: AudioStreamPlayer = _players[id]
		var st: AudioStreamWAV = p.stream
		var sound := str(e.get("sound", ""))
		rows.append({
			"id": id,
			"sound": sound,
			"wav_path": str(wav.get("path", "")),
			"wav_sha256": str(wav.get("sha256", "")),
			"wav_bytes": int(wav.get("bytes", 0)),
			"port_event_id_count": (e.get("port", {}).get("eventIdAnchors", []) as Array).size(),
			"stream_path": (st.resource_path if st != null else ""),
			"stream_sha256": sha256_of(ASSET_DIR.path_join(sound + ".wav")),
			"stream_mix_rate": (st.mix_rate if st != null else 0),
			"stream_stereo": (st.stereo if st != null else true),
			"stream_format": (st.format if st != null else -1),
			"stream_length": (st.get_length() if st != null else 0.0),
			"stream_data_bytes": (st.data.size() if st != null else 0),
			"stream_frames": (st.data.size() / 2 if st != null and st.format == AudioStreamWAV.FORMAT_16_BITS and not st.stereo else -1),
			"bus": p.bus,
			"volume_db": p.volume_db,
			"max_polyphony": p.max_polyphony,
			"player_class": p.get_class(),
			"playing": p.playing,
		})
	var buses: Array = []
	for i in AudioServer.bus_count:
		buses.append({
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"send": AudioServer.get_bus_send(i),
			"muted": AudioServer.is_bus_mute(i),
			"effect_count": AudioServer.get_bus_effect_count(i),
		})
	var mixer := _mixer()
	return {
		"schema": str(contract.get("schema", "")),
		"schema_version": int(contract.get("schemaVersion", -1)),
		"contract_path": CONTRACT_PATH,
		"contract_sha256": contract_sha256,
		"loaded": loaded,
		"events": rows,
		"event_ids": Array(_order),
		"sound_ids": Array(contract.get("soundIds", [])),
		"sfx_bus_name": SFX_BUS,
		"music_bus_name": MUSIC_BUS,
		"master_bus_name": MASTER_BUS,
		"buses": buses,
		"bus_layout_path": BUS_LAYOUT_PATH,
		"mixer": {
			"master_gain": _master_gain,
			"master_gain_default": reference_master_gain(),
			"master_gain_min": master_gain_range()["min"],
			"master_gain_max": master_gain_range()["max"],
			"master_gain_step": master_gain_range()["step"],
			"muted": _muted,
			"muted_default": muted_default(),
			"music_bus_gain": reference_music_bus_gain(),
			"ducking_defined": bool(mixer.get("ducking", {}).get("defined", false)),
			"panning_defined": bool(mixer.get("panning", {}).get("defined", false)),
			"reduced_motion_affects_audio": bool(mixer.get("reducedMotion", {}).get("affectsAudio", false)),
			"unknown_count": (mixer.get("unknowns", []) as Array).size(),
			"per_event_volume_overrides": 0,
		},
		# Deliberately empty — see the header and `port_bindings()`.
		"port_bindings": port_bindings(),
	}
