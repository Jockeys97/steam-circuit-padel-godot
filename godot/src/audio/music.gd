extends Node
## music.gd — the port's MUSIC engine: the reference's sequencer, ported and testable.
##
## THE SPECIFICATION THIS IMPLEMENTS
##   `js/audio.js:106-271` is the reference's composer. It is not event-triggered: a
##   40 ms `setInterval` (`:130`) walks a 64-step loop (`:269`) at
##   `60 / (96 + intensity * 54)` beats per minute (`:267`, four steps to the beat,
##   `:268`) over a four-chord progression (`PROG`, `:110-115`), scheduling six
##   voices from a 150 ms lookahead (`:264-265`):
##
##     | layer      | gate (`js/audio.js`)            | voice                                   |
##     |------------|---------------------------------|-----------------------------------------|
##     | bass-on    | `s % 4 === 0` (`:229`)          | triangle, root-12, lowpass 520, 0.24 s  |
##     | bass-off   | `inten > 0.6 && s % 4 === 2`    | triangle, root-12, lowpass 520, 0.12 s  |
##     | pad        | `s === 0` (`:235-239`)          | 3 x sine on intervals[0..2], 1.7 s,     |
##     |            |                                 | attack 0.35 s, no filter                |
##     | arp        | `inten > 0.4` (`:241-252`)      | square, root + iv + (12|24), filt 2200  |
##     | kick       | `inten > 0.72 && s % 4 === 0`   | sine 130 -> 42 Hz, 0.15 s, gain 0.2     |
##     | hat        | `inten > 0.72 && s % 2 === 1`   | 0.04 s noise, highpass 7000             |
##
##   The expected note/chord stream is NOT restated here by hand: it is generated from
##   the reference by `tools/audio-music-port/extract-music.mjs` (which runs
##   `js/audio.js` against a fake AudioContext and records every node it starts) and
##   vendored byte-identical to `res://src/audio/music_reference.json`. The module
##   implements the engine; `godot/tests/music_port_test.gd` compares the two and fails
##   on any drift — in either direction.
##
## CONTEXTS (which is what "menu vs match" is in the reference):
##   the reference has exactly two music contexts and no third. `js/main.js:1158-1159`
##   starts the score with `music.setIntensity(0.12)` when a match begins and
##   `js/main.js:1220-1226` re-drives the intensity every frame from the rally; the
##   score is stopped at `js/main.js:1385` (match end) and `:1553` (quit). There is no
##   menu theme. So `set_context("match")` == `start()`, `set_context("menu")` ==
##   `stop()`, and the menu context's material is *silence* — which the test asserts
##   explicitly rather than pretending otherwise.
##
## MIXER SEMANTICS — the same ones `audio_port.gd` established:
##   - the music bus sits at the reference's own gain 0.55 (`js/audio.js:149`), read
##     from the vendored event contract (`mixer.musicBusGain`), not restated;
##   - `set_muted(true)` sets one flag. It gates the scheduler and the voices it would
##     create (`js/audio.js:262,157,184,202`) and does NOT mute a bus or cut a sounding
##     voice. While muted the walk is *frozen*, so the score resumes where it stopped
##     and takes the reference's catch-up branch (`:263`);
##   - `set_master_gain` clamps to the contract's range and applies the value relative
##     to the reference's default 0.5, so the default is unity. Volume 0 is silent but
##     still plays: the score keeps being scheduled and voices keep starting.
##   - no ducking, compressor, limiter, pan or fade is invented (`mixer.ducking.defined`
##     and `mixer.panning.defined` are false in the reference).
##
## WHAT IS NOT REPRODUCED (and is therefore never asserted):
##   - the noise samples inside a hat buffer (`js/audio.js:208`, `Math.random()`): the
##     port renders a deterministic noise buffer with a fixed seed and the test compares
##     only the hat's structural parameters;
##   - sample-accurate scheduling: the reference schedules oscillators at exact sample
##     positions; this module renders voice samples in engine memory with the reference's
##     oscillator shapes and exponential envelopes, but triggers them from the frame
##     clock. Per-sample identity is neither claimed nor tested — and with the dummy
##     audio driver nothing about the *sound* is claimed at all;
##   - per-voice gain sharing: a pooled player carries one `volume_db`, so two
##     overlapping events of the same voice signature with different gains share the
##     later gain (the reference gives every oscillator its own). The gains in the
##     *event stream* are exact.
##
## INTEGRATION NOTE (not done in this task): `set_master_gain` writes the MASTER bus,
## which `audio_port.gd` also owns. In a game tree where both modules live, one of them
## must own the master level — the reference has a single `audio._master` gain, so the
## SFX module is the natural owner and music.gd only needs its own bus.

const CONTRACT_PATH := "res://src/audio/event_map.json"
const CONTRACT_SCHEMA := "steam-circuit-padel-pro.audio-event-map"

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
## Godot's minimum bus volume; stands in for a gain of 0.
const SILENCE_DB := -80.0
## The reference builds fresh oscillators per call, so the same voice can overlap itself.
const MAX_POLYPHONY := 16
## Upper bound on the pooled per-signature players (54 distinct signatures exist:
## 32 arp + 12 pad + 8 bass + 1 kick + 1 hat).
const MAX_VOICE_POOL := 64

# --- sequencer constants: ported from js/audio.js, anchors are the reference's ---
const STEPS_PER_BAR := 16     # :224  Math.floor(step / 16) % PROG.length
const LOOP_STEPS := 64        # :269  (music._step + 1) % 64
const LEAD := 0.08            # :129  _nextTime = currentTime + 0.08
const LOOKAHEAD := 0.15       # :264  const lookahead = 0.15
## Signed, as the reference's expression reads: `_nextTime < currentTime - 0.1` (`:263`).
const CATCH_UP_BEHIND := -0.1 # :263
const CATCH_UP_LEAD := 0.05   # :263  _nextTime = currentTime + 0.05
const BPM_BASE := 96.0        # :267  60 / (96 + intensity * 54)
const BPM_INTENSITY := 54.0   # :267
const STEPS_PER_BEAT := 4.0   # :268  secondsPerBeat / 4
const DEFAULT_ATTACK := 0.012 # :155  attack = 0.012
const TONE_TAIL := 0.06       # :179  osc.stop(t + dur + 0.06)
const KICK_TAIL := 0.03       # :197  osc.stop(time + 0.18) with dur 0.15
const HAT_DUR := 0.04         # :205
const RENDER_RATE := 44100    # the reference AudioContext's rate; the hat buffer's
                              # length (1764) is derived from it (`:205-206`)

## `PROG` — the four chords (`js/audio.js:110-115`). Restating this table in code is
## what makes the port an engine rather than a replay; the test asserts it against the
## generated reference dump, so a wrong chord here is a named failure.
const PROG: Array = [
	{"root": 45, "intervals": [0, 3, 7, 12]},
	{"root": 41, "intervals": [0, 4, 7, 12]},
	{"root": 48, "intervals": [0, 4, 7, 12]},
	{"root": 43, "intervals": [0, 4, 7, 12]},
]

const CONTEXT_MENU := "menu"
const CONTEXT_MATCH := "match"

## Parsed contract copy (read-only for consumers); same file `audio_port.gd` reads.
var contract: Dictionary = {}
var contract_sha256: String = ""
var loaded: bool = false

var playing: bool = false
var intensity: float = 0.0
var step: int = 0
var next_time: float = 0.0
var context: String = CONTEXT_MENU
## Set by every rejected call; "" after a successful one.
var last_error: String = ""
## Voices started since `reset()`; the test's proof that the sequencer really fires.
var voices_started: int = 0

var _master_gain: float = 0.0
var _muted: bool = false
var _clock: float = 0.0
var _pool: Dictionary = {}
var _pool_order: PackedStringArray = PackedStringArray()
var _hat_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_hat_rng.seed = 1
	_load_contract()
	_build_buses()
	_apply_master_gain()


func _process(delta: float) -> void:
	# The real driver: advance the audio clock and walk the schedule. The headless test
	# disables processing (`set_process(false)`) and calls `tick(now)` itself, so the two
	# never fight over `next_time`.
	_clock += delta
	tick(_clock)


## Tear everything down and rebuild. Legitimate on a match restart; also what the
## drift test uses to get a pristine engine per scenario.
func reset() -> void:
	playing = false
	intensity = 0.0
	step = 0
	next_time = 0.0
	context = CONTEXT_MENU
	last_error = ""
	voices_started = 0
	_clock = 0.0
	_muted = false
	for p in _pool.values():
		if is_instance_valid(p):
			p.stop()
			p.free()
	_pool.clear()
	_pool_order = PackedStringArray()
	_hat_rng.seed = 1
	_load_contract()
	_build_buses()
	_apply_master_gain()


# ---------------------------------------------------------------------------
# contract (mixer numbers come from the same vendored file the SFX module reads)
# ---------------------------------------------------------------------------

func _load_contract() -> void:
	loaded = false
	contract = {}
	contract_sha256 = ""
	if not FileAccess.file_exists(CONTRACT_PATH):
		push_error("music: contract copy missing at %s — run `node tools/audio-port/sync-godot-audio.mjs`" % CONTRACT_PATH)
		return
	contract_sha256 = sha256_of(CONTRACT_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("music: %s is not a JSON object" % CONTRACT_PATH)
		return
	contract = parsed
	if str(contract.get("schema", "")) != CONTRACT_SCHEMA:
		push_error("music: %s declares schema '%s', expected '%s'" % [CONTRACT_PATH, contract.get("schema", ""), CONTRACT_SCHEMA])
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


func _mixer() -> Dictionary:
	var m: Variant = contract.get("mixer", {})
	return m if typeof(m) == TYPE_DICTIONARY else {}


## `js/audio.js:149` — `music._gain.gain.value = 0.55`.
func reference_music_bus_gain() -> float:
	return float(_mixer().get("musicBusGain", {}).get("value", 0.55))


## `js/audio.js:4-5, :15` — the level the score is written against.
func reference_master_gain() -> float:
	return float(_mixer().get("masterGainDefault", {}).get("value", 0.5))


func muted_default() -> bool:
	return bool(_mixer().get("mute", {}).get("default", false))


func master_gain_range() -> Dictionary:
	var r: Dictionary = _mixer().get("masterGainRange", {})
	return {"min": float(r.get("min", 0.0)), "max": float(r.get("max", 1.0)), "step": float(r.get("step", 0.01))}


# ---------------------------------------------------------------------------
# buses (idempotent; project.godot stays untouched, as in audio_port.gd)
# ---------------------------------------------------------------------------

func _build_buses() -> void:
	_ensure_bus(MASTER_BUS, "", 0.0)
	_ensure_bus(MUSIC_BUS, MASTER_BUS, linear_to_db(reference_music_bus_gain()))


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
# transport
# ---------------------------------------------------------------------------

## `js/audio.js:124-131`. No-op when already playing (`:125`). `now` defaults to the
## module's own clock; the headless test passes an explicit one.
func start(now := NAN) -> bool:
	if playing:
		last_error = "already playing"
		return false
	playing = true
	step = 0
	var t := _clock if is_nan(now) else now
	next_time = t + LEAD
	context = CONTEXT_MATCH
	last_error = ""
	return true


## `js/audio.js:132-138`.
func stop() -> void:
	playing = false
	context = CONTEXT_MENU


## `js/audio.js:139-141` — `Math.min(1, Math.max(0, value))`.
func set_intensity(value: float) -> float:
	if is_nan(value):
		value = 0.0
	intensity = minf(1.0, maxf(0.0, value))
	return intensity


## The two contexts the reference has (`js/main.js:1158-1159` vs `:1385, :1553`).
## Returns true when the context was accepted (recognised and applied).
func set_context(name: String, now := NAN) -> bool:
	match name:
		CONTEXT_MENU:
			stop()
			return true
		CONTEXT_MATCH:
			return start(now)
		_:
			last_error = "not a reference music context: %s" % name
			return false


## The reference's own per-frame coupling: `js/main.js:1220-1226`.
##     rallyTension = min(1, rallyHits / 12)
##     stakes       = min(0.35, (setsP+setsA)*0.15 + (gamesP+gamesA)*0.02)
##     intensity    = min(1, 0.12 + rallyTension*0.55 + stakes)
func intensity_for_rally(rally_hits: int, sets_total: int, games_total: int) -> float:
	return set_intensity(
		min(
			1.0,
			0.12
				+ minf(1.0, float(rally_hits) / 12.0) * 0.55
				+ minf(0.35, float(sets_total) * 0.15 + float(games_total) * 0.02)
		)
	)


# ---------------------------------------------------------------------------
# the pattern — one step of the 64-step loop, as an event stream
# ---------------------------------------------------------------------------

## `js/audio.js:106-108`.
static func midi_to_freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## `js/audio.js:223-258`. Returns the step's voices in the reference's order:
## bass, pad, arp, kick, hat. No `t` yet — the scheduler stamps it.
##
## `step` is the 64-step loop index; the reference immediately takes it modulo 16 with
## `const s = step % 16` (`:225`) and every gate below reads that `s` — including the
## pad gate `s === 0`, which fires four times per loop, not once.
func step_events(step: int, inten: float) -> Array:
	var bar := int(floor(float(step) / float(STEPS_PER_BAR))) % PROG.size()
	var s := step % STEPS_PER_BAR
	var chord: Dictionary = PROG[bar]
	var root := int(chord["root"])
	var intervals: Array = chord["intervals"]
	var out: Array = []

	# bass (`:229-233`)
	if s % 4 == 0:
		out.append(_tone("bass-on", root - 12, "triangle", 0.24, 0.15, DEFAULT_ATTACK, 520.0))
	elif inten > 0.6 and s % 4 == 2:
		out.append(_tone("bass-off", root - 12, "triangle", 0.12, 0.07, DEFAULT_ATTACK, 520.0))

	# pad (`:235-239`): intervals.slice(0, 3), one 1.7 s wash per bar
	if s == 0:
		for i in range(mini(3, intervals.size())):
			out.append(_tone("pad", root + int(intervals[i]), "sine", 1.7, 0.032, 0.35, -1.0))

	# arp (`:241-252`)
	if inten > 0.4:
		var note := int(intervals[s % intervals.size()])
		var octave := 12 if s % 8 < 4 else 24
		out.append(_tone("arp", root + note + octave, "square", 0.09, 0.028 + inten * 0.03, DEFAULT_ATTACK, 2200.0))

	# drums (`:254-257`)
	if inten > 0.72:
		if s % 4 == 0:
			out.append(_kick())
		if s % 2 == 1:
			out.append(_hat(0.02 + (inten - 0.72) * 0.1))
	return out


func _tone(layer: String, midi: int, type: String, dur: float, gain: float, attack: float, filter: float) -> Dictionary:
	return {
		"layer": layer,
		"kind": "tone",
		"type": type,
		"midi": midi,
		"freq": midi_to_freq(float(midi)),
		"freq_end": null,
		"sweep": null,
		"gain": gain,
		"attack": attack,
		"dur": dur,
		"filter_type": "lowpass" if filter > 0.0 else null,
		"filter": filter if filter > 0.0 else null,
		"buf_frames": null,
	}


## `js/audio.js:182-198`.
func _kick() -> Dictionary:
	return {
		"layer": "kick",
		"kind": "kick",
		"type": "sine",
		"midi": null,
		"freq": 130.0,
		"freq_end": 42.0,
		"sweep": 0.12,
		"gain": 0.2,
		"attack": null,
		"dur": 0.15,
		"filter_type": null,
		"filter": null,
		"buf_frames": null,
	}


## `js/audio.js:200-221`. The buffer length follows from the render rate (`:205-206`).
func _hat(gain: float) -> Dictionary:
	return {
		"layer": "hat",
		"kind": "hat",
		"type": null,
		"midi": null,
		"freq": null,
		"freq_end": null,
		"sweep": null,
		"gain": gain,
		"attack": null,
		"dur": HAT_DUR,
		"filter_type": "highpass",
		"filter": 7000.0,
		"buf_frames": int(RENDER_RATE * HAT_DUR),
	}


# ---------------------------------------------------------------------------
# the scheduler — `js/audio.js:260-271`
# ---------------------------------------------------------------------------

## Walks the schedule for this clock reading and returns what was emitted, as
## `[{"step": int, "t": float, "events": Array}]` — the exact shape the reference dump
## is generated in. Mirrors the reference's walk order and arithmetic, including the
## catch-up branch and the mute/ playing gates.
func tick(now: float) -> Array:
	var emitted: Array = []
	if not loaded:
		last_error = "contract not loaded"
		return emitted
	# `scheduleMusic` returns early when muted (`:262`): no step is walked, so the score
	# freezes and `next_time`/`step` keep their values for the un-mute catch-up.
	if not playing or _muted:
		return emitted
	if next_time < now + CATCH_UP_BEHIND:
		next_time = now + CATCH_UP_LEAD
	while next_time < now + LOOKAHEAD:
		var evs := step_events(step, intensity)
		for e in evs:
			e["s"] = step
			e["t"] = next_time
		emitted.append({"step": step, "t": next_time, "events": evs})
		_fire(evs)
		var seconds_per_beat := 60.0 / (BPM_BASE + intensity * BPM_INTENSITY)
		next_time += seconds_per_beat / STEPS_PER_BEAT
		step = (step + 1) % LOOP_STEPS
	return emitted


# ---------------------------------------------------------------------------
# voices — rendered in engine memory from the reference's own synth parameters
# ---------------------------------------------------------------------------

func _fire(events: Array) -> void:
	for e in events:
		var p := _voice_for(e)
		if p == null:
			continue
		p.volume_db = linear_to_db(maxf(float(e["gain"]), 0.0001))
		if is_inside_tree():
			p.play()
		voices_started += 1


## One pooled player per voice signature (type/frequency/envelope/filter). The gain is
## NOT part of the key: it is applied as the player's volume, so the pooled samples stay
## bounded and the reference's gain values stay exact in the event stream.
func _voice_for(e: Dictionary) -> AudioStreamPlayer:
	var key := _voice_key(e)
	var p: AudioStreamPlayer = _pool.get(key, null)
	if p != null:
		return p
	if _pool.size() >= MAX_VOICE_POOL:
		last_error = "voice pool full at %d signatures" % MAX_VOICE_POOL
		return null
	p = AudioStreamPlayer.new()
	p.name = "music_" + key.replace("|", "_").replace(".", "p")
	p.stream = _render(e)
	p.bus = MUSIC_BUS
	p.volume_db = 0.0
	p.max_polyphony = MAX_POLYPHONY
	add_child(p)
	_pool[key] = p
	_pool_order.append(key)
	return p


func _voice_key(e: Dictionary) -> String:
	return "%s|%s|%s|%.6f|%s|%s" % [
		str(e["layer"]),
		str(e["kind"]),
		"%.6f" % float(e["freq"]) if e["freq"] != null else "-",
		float(e["dur"]),
		"%.6f" % float(e["attack"]) if e["attack"] != null else "-",
		"%.1f" % float(e["filter"]) if e["filter"] != null else "-",
	]


func pool_size() -> int:
	return _pool.size()


func player_for_layer(layer: String) -> AudioStreamPlayer:
	for key in _pool_order:
		if key.begins_with(layer + "|"):
			return _pool[key]
	return null


func stop_all() -> void:
	for p in _pool.values():
		if is_instance_valid(p):
			p.stop()


## Renders the voice into an in-memory 16-bit mono WAV at unit peak, using the
## reference's oscillator shape (`sine`/`triangle`/`square`), its exponential envelope
## (`setValueAtTime` + two `exponentialRampToValueAtTime`, `js/audio.js:30-32, 165-167`)
## and a one-pole approximation of its biquad filter. The gain is applied by the player,
## not baked here. Samples are NOT byte-comparable to the reference (see the header).
func _render(e: Dictionary) -> AudioStreamWAV:
	var dur := float(e["dur"])
	var tail := TONE_TAIL
	if str(e["kind"]) == "kick":
		tail = KICK_TAIL
	elif str(e["kind"]) == "hat":
		tail = 0.0
	var frames := int(ceil((dur + tail) * float(RENDER_RATE)))
	var data := PackedByteArray()
	data.resize(frames * 2)
	var attack: Variant = e["attack"]
	var fc := 0.0 if e["filter"] == null else float(e["filter"])
	var hp := str(e["filter_type"]) == "highpass"
	var alpha := 1.0 - exp(-TAU * fc / float(RENDER_RATE)) if fc > 0.0 else 0.0
	var phase := 0.0
	var lp := 0.0
	for i in range(frames):
		var t := float(i) / float(RENDER_RATE)
		var value := 0.0
		if str(e["kind"]) == "hat":
			value = _hat_rng.randf_range(-1.0, 1.0)
		elif str(e["kind"]) == "kick":
			# `js/audio.js:190-191`: 130 -> 42 Hz exponentially over 0.12 s
			var sweep := float(e["sweep"])
			var f0 := float(e["freq"])
			var f := f0 * pow(float(e["freq_end"]) / f0, minf(t, sweep) / sweep)
			phase += f / float(RENDER_RATE)
			value = sin(TAU * phase)
		else:
			var f := float(e["freq"])
			if e["freq_end"] != null:
				f = f * pow(float(e["freq_end"]) / f, t / dur)
			phase += f / float(RENDER_RATE)
			value = _wave(str(e["type"]), phase)
		if alpha > 0.0:
			lp += alpha * (value - lp)
			value = (value - lp) if hp else lp
		var env := _envelope(t, dur, attack)
		var sample := int(clampf(value * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RENDER_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _wave(type: String, phase: float) -> float:
	match type:
		"triangle":
			return 2.0 / PI * asin(sin(TAU * phase))
		"square":
			return 1.0 if sin(TAU * phase) >= 0.0 else -1.0
		"sawtooth":
			return 2.0 * (phase - floor(phase + 0.5))
		_:
			return sin(TAU * phase)


## `js/audio.js:30-32` / `:165-167` / `:192-193` / `:215-216`: exponential ramps from
## 0.0001 up to the gain (when there is an attack) and down to 0.0001.
static func _envelope(t: float, dur: float, attack: Variant) -> float:
	if attack == null:
		return _exp_ramp(1.0, 0.0001, t / maxf(dur, 0.0000001))
	var a := float(attack)
	if t < a:
		return _exp_ramp(0.0001, 1.0, (t / a) if a > 0.0 else 1.0)
	var span := maxf(dur - a, 0.0000001)
	return _exp_ramp(1.0, 0.0001, minf((t - a) / span, 1.0))


static func _exp_ramp(from: float, to: float, frac: float) -> float:
	return from * pow(to / from, clampf(frac, 0.0, 1.0))


# ---------------------------------------------------------------------------
# mixer — the semantics `audio_port.gd` established
# ---------------------------------------------------------------------------

## `js/audio.js:286-289` — clamp to the contract's range, then apply relative to the
## reference's own default gain, which is the level the score is written against.
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


## `js/audio.js:278-280` — the flag only. No bus is muted and no voice is cut.
func set_muted(flag: bool) -> void:
	_muted = bool(flag)


func is_muted() -> bool:
	return _muted


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


func music_bus_gain_db() -> float:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	return AudioServer.get_bus_volume_db(idx) if idx >= 0 else -INF


# ---------------------------------------------------------------------------
# the engine's own view of itself — what the drift test compares to the dump
# ---------------------------------------------------------------------------

func describe() -> Dictionary:
	var buses: Array = []
	for i in AudioServer.bus_count:
		buses.append({
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"send": AudioServer.get_bus_send(i),
			"muted": AudioServer.is_bus_mute(i),
			"effect_count": AudioServer.get_bus_effect_count(i),
		})
	var voices: Array = []
	for key in _pool_order:
		var p: AudioStreamPlayer = _pool[key]
		var st: AudioStreamWAV = p.stream
		voices.append({
			"key": key,
			"stream_frames": (st.data.size() / 2 if st != null else -1),
			"stream_mix_rate": (st.mix_rate if st != null else 0),
			"stream_stereo": (st.stereo if st != null else true),
			"stream_format": (st.format if st != null else -1),
			"stream_length": (st.get_length() if st != null else 0.0),
			"bus": p.bus,
			"volume_db": p.volume_db,
			"max_polyphony": p.max_polyphony,
			"player_class": p.get_class(),
		})
	return {
		"schema": str(contract.get("schema", "")),
		"contract_path": CONTRACT_PATH,
		"contract_sha256": contract_sha256,
		"loaded": loaded,
		"buses": buses,
		"master_bus_name": MASTER_BUS,
		"music_bus_name": MUSIC_BUS,
		"transport": {
			"playing": playing,
			"context": context,
			"step": step,
			"next_time": next_time,
			"intensity": intensity,
			"clock": _clock,
			"voices_started": voices_started,
			"pool_size": _pool.size(),
			"last_error": last_error,
		},
		"engine": {
			"steps_per_bar": STEPS_PER_BAR,
			"loop_steps": LOOP_STEPS,
			"lead": LEAD,
			"lookahead": LOOKAHEAD,
			"catch_up_behind": CATCH_UP_BEHIND,
			"catch_up_lead": CATCH_UP_LEAD,
			"bpm_base": BPM_BASE,
			"bpm_intensity": BPM_INTENSITY,
			"steps_per_beat": STEPS_PER_BEAT,
			"tone_tail": TONE_TAIL,
			"kick_tail": KICK_TAIL,
			"hat_dur": HAT_DUR,
			"hat_buf_frames": int(RENDER_RATE * HAT_DUR),
			"render_rate": RENDER_RATE,
			"prog": PROG,
			"layer_order": ["bass", "pad", "arp", "kick", "hat"],
			"max_voice_pool": MAX_VOICE_POOL,
		},
		"mixer": {
			"master_gain": _master_gain,
			"master_gain_default": reference_master_gain(),
			"master_gain_min": master_gain_range()["min"],
			"master_gain_max": master_gain_range()["max"],
			"master_gain_step": master_gain_range()["step"],
			"muted": _muted,
			"muted_default": muted_default(),
			"music_bus_gain": reference_music_bus_gain(),
			"music_bus_gain_db": music_bus_gain_db(),
			"ducking_defined": bool(_mixer().get("ducking", {}).get("defined", false)),
			"panning_defined": bool(_mixer().get("panning", {}).get("defined", false)),
		},
		"voices": voices,
	}
