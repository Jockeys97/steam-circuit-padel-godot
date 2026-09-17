extends RefCounted
## mixer_contract.gd — THE one reader of the audio mixer contract.
##
## WHY THIS FILE EXISTS
##   `audio_port.gd` (10 baked SFX on the `SFX` bus) and `music.gd` (the ported
##   sequencer on the `Music` bus) both take their mixer numbers from the same
##   vendored contract, `res://src/audio/event_map.json` (the byte-identical copy
##   of `tools/audio-port/event-map.json` the sync tool vends). Before this
##   module existed, each adapter parsed that JSON, checked its schema, hashed it,
##   read `mixer.masterGainDefault` / `mixer.musicBusGain` / `mixer.mute.default`
##   / `mixer.masterGainRange`, and built the same buses — two copies of one fact
##   set, which is how the two modules can silently drift apart. Now they do not:
##   everything in the paragraph above is owned HERE, and both adapters consume
##   this reader. What they keep is their own playback: which sounds play, how a
##   player is built, how the sequencer walks.
##
## WHAT IS OWNED HERE
##   - reading and validating the contract: JSON parse, `schema` check, the
##     "declares events" check, and the sha256 of the exact copy that was read
##     (`load_contract()`; `error` carries the reason for every refusal);
##   - the mixer facts: `reference_master_gain()` (0.5 — the level the bake
##     already contains, so it is every adapter's unity reference),
##     `reference_music_bus_gain()` (0.55), `muted_default()` (false),
##     `master_gain_range()`;
##   - the gain law: `clamp_gain()` (the reference clamps and does not quantise;
##     the 0.01 step belongs to the slider) and `apply_master_gain()`, which sets
##     the real Master bus relative to the baked reference — 0 means silence and
##     muting the bus, exactly as both adapters used to do line for line;
##   - the bus setup facts: the names (`MASTER_BUS`, `SFX_BUS`, `MUSIC_BUS`), the
##     graph (`BUS_SENDS`: SFX and Music feed Master) and the levels
##     (`bus_volume_db()`: Music at the contract's own gain, the rest at 0 dB),
##     applied through the idempotent `ensure_bus()`. WHICH buses an adapter
##     builds stays the adapter's decision; the facts of each bus live here.
##
## WHAT IS DELIBERATELY NOT HERE
##   - no playback, no players, no voices, no sequencer: the two adapters keep
##     all of it (`audio_port.gd`, `music.gd`);
##   - no per-adapter state: mute *values* and master-gain *values* are stored by
##     each adapter (its own `_muted` / `_master_gain`); this module owns the
##     defaults they start from and the law they apply;
##   - no ducking, panning, compression or limiter: the contract records those as
##     undefined, so nothing is invented here either.
##
## `contract_path` is a var, not a constant, for one reason: the shared-reader
## test (`godot/tests/mixer_contract_test.gd`) hands each adapter a reader pointed
## at a doctored contract copy and then asserts the adapter obeys it. A future
## match-level wiring could use the same hook to share ONE instance between both
## adapters; nothing here requires that, and nothing here forbids it.

const CONTRACT_PATH := "res://src/audio/event_map.json"
const CONTRACT_SCHEMA := "steam-circuit-padel-pro.audio-event-map"

const MASTER_BUS := "Master"
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
## Godot's minimum bus volume; stands in for the reference's gain 0.
const SILENCE_DB := -80.0

## bus name -> the bus it feeds. The reference has every voice feeding one master
## gain; in Godot that is one `send` edge per bus.
const BUS_SENDS: Dictionary = {
	MASTER_BUS: "",
	SFX_BUS: MASTER_BUS,
	MUSIC_BUS: MASTER_BUS,
}

## The file this reader reads. Defaults to the vendored contract copy.
var contract_path: String = CONTRACT_PATH
## Parsed contract copy, as loaded by this reader (read-only for consumers).
var contract: Dictionary = {}
## sha256 of the contract copy this reader loaded.
var contract_sha256: String = ""
## True when the contract copy parsed and declares the expected schema with events.
var loaded: bool = false
## "" after a successful load; the reason for every refusal otherwise.
var error: String = ""


# ---------------------------------------------------------------------------
# reading and validating the contract (once, for both adapters)
# ---------------------------------------------------------------------------

## Reads `contract_path`, validates it and exposes it through `contract`.
## Returns `loaded`. Every refusal sets `error` and pushes an engine error, so a
## missing or drifted contract copy is loud at `_ready()` and not silent at play.
func load_contract() -> bool:
	loaded = false
	contract = {}
	contract_sha256 = ""
	error = ""
	if not FileAccess.file_exists(contract_path):
		_refuse(
			"contract copy missing at %s — run `node tools/audio-port/sync-godot-audio.mjs`"
				% contract_path
		)
		return false
	contract_sha256 = sha256_of(contract_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(contract_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_refuse("%s is not a JSON object" % contract_path)
		return false
	var candidate: Dictionary = parsed
	if str(candidate.get("schema", "")) != CONTRACT_SCHEMA:
		_refuse(
			"%s declares schema '%s', expected '%s'"
				% [contract_path, candidate.get("schema", ""), CONTRACT_SCHEMA]
		)
		return false
	if not candidate.has("events") or (candidate["events"] as Array).is_empty():
		_refuse("%s declares no events" % contract_path)
		return false
	contract = candidate
	loaded = true
	return true


## A refused load: the reason, and the engine error that names this module.
func _refuse(reason: String) -> void:
	error = reason
	push_error("mixer_contract: " + reason)


## sha256 of a file, res:// or absolute. "" when the file is not readable.
static func sha256_of(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


# ---------------------------------------------------------------------------
# the mixer facts (all values come from the JSON; one owner for both adapters)
# ---------------------------------------------------------------------------

## The parsed `mixer` object of the contract; `{}` when there is none.
func mixer() -> Dictionary:
	var m: Variant = contract.get("mixer", {})
	return m if typeof(m) == TYPE_DICTIONARY else {}


## `mixer.masterGainDefault.value` — 0.5 in the reference, and this is the level
## the bake already contains, so it is every adapter's unity reference.
func reference_master_gain() -> float:
	return float(mixer().get("masterGainDefault", {}).get("value", 0.5))


## `mixer.musicBusGain.value` — 0.55 in the reference (`js/audio.js:149`).
func reference_music_bus_gain() -> float:
	return float(mixer().get("musicBusGain", {}).get("value", 0.55))


## `mixer.mute.default` — false in the reference.
func muted_default() -> bool:
	return bool(mixer().get("mute", {}).get("default", false))


func master_gain_range() -> Dictionary:
	var r: Dictionary = mixer().get("masterGainRange", {})
	return {
		"min": float(r.get("min", 0.0)),
		"max": float(r.get("max", 1.0)),
		"step": float(r.get("step", 0.01)),
	}


# ---------------------------------------------------------------------------
# the gain law (the lines both adapters used to repeat verbatim)
# ---------------------------------------------------------------------------

## `js/audio.js:286-289` — `Math.min(1, Math.max(0, Number(v) || 0))` with the
## range taken from the contract. Clamp only: the 0.01 step belongs to the slider
## (`index.html:426`), not to the setter, so no quantisation is applied.
func clamp_gain(value: float) -> float:
	var range := master_gain_range()
	var v := value
	if is_nan(v):
		v = 0.0
	return clampf(v, range["min"], range["max"])


## Master bus level, relative to the level the bake already contains: at the
## default the bus is unity and nothing is attenuated twice. Gain 0 is silence
## (Godot's minimum plus a bus mute). Returns the bus level in dB.
func apply_master_gain(gain: float) -> float:
	var idx := AudioServer.get_bus_index(MASTER_BUS)
	if idx < 0:
		return 0.0
	var reference := reference_master_gain()
	var relative := (gain / reference) if reference > 0.0 else 0.0
	if relative <= 0.0:
		AudioServer.set_bus_volume_db(idx, SILENCE_DB)
		AudioServer.set_bus_mute(idx, true)
		return SILENCE_DB
	AudioServer.set_bus_volume_db(idx, linear_to_db(relative))
	AudioServer.set_bus_mute(idx, false)
	return linear_to_db(relative)


# ---------------------------------------------------------------------------
# the bus setup facts (names, graph, levels) — applied, not restated
# ---------------------------------------------------------------------------

## The level a contracted bus sits at: Music carries the reference's own gain,
## every other bus is at unity (0 dB). The bake already contains the master 0.5,
## so no bus restates it.
func bus_volume_db(bus_name: String) -> float:
	if bus_name == MUSIC_BUS:
		return linear_to_db(reference_music_bus_gain())
	return 0.0


## Names the bus, points it at its send and sets its level; adds it if absent.
## Idempotent, so no project setting (and no `default_bus_layout.tres`) is needed.
func ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, str(BUS_SENDS.get(bus_name, "")))
	AudioServer.set_bus_volume_db(idx, bus_volume_db(bus_name))
	return idx
