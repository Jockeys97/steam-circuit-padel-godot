## match_audio.gd — the one place the ported simulation's message ids become sounds.
##
## WHAT IT IS
##   The verified audio module (`res://src/audio/audio_port.gd`, 10 baked one-shots
##   on the `SFX` bus, contract `tools/audio-port/event-map.json`; evidence
##   `docs/wayfinder/evidence/audio-module-godot.md`) takes *contract* event ids:
##   `serve`, `hit`, `special`, `point-win`, `point-loss`, `victory`, `defeat`,
##   `bounce`, `wall`, `net`. The ported simulation stores *message ids*
##   (`evWallValid`, `pointYou:msgOut`, ...). Nothing bridged the two: the module's
##   own `port_bindings()` is deliberately empty and its test asserts that.
##
##   This file is that bridge, and it is the only one: `sound_for_message_id()` is
##   the whole routing decision, in one function, and it is derived from the
##   contract's own anchors rather than invented (see the table below).
##
## WHAT "DERIVED" MEANS HERE (`tools/audio-port/event-map.json`)
##   The contract records, per sound, `port.eventIdAnchors`: the message ids the
##   ported simulation stores *at the reference's own `sfx.*` call site*. Where an
##   anchor exists, this file uses it verbatim:
##
##     sfx.wall()    at js/game.js:2363 handleWalls          -> evWallValid   (sim.gd:2242)
##     sfx.net()     at js/game.js:2382 handleNetCollision   -> evTape, evNetRebound (sim.gd:2273, 2284)
##     sfx.bounce()  at js/game.js:2209 handleGroundBounce   -> evServeValid, evSmashValid (sim.gd:2091, 2115)
##     sfx.special() at js/game.js:1898 hitBall(isSpecial)   -> evPrecision, evLightningDash,
##                                                              evSteamSmash, evSteamShield,
##                                                              evPerfectVision, evSteamHammer (sim.gd:1884-1915)
##     sfx.point(w)  at js/game.js:2111 scorePoint           -> pointYou / pointOpp (sim.gd:2026)
##
##   The contract also records where there is NO anchor, and those are the three
##   triggers that are not message ids at all. For them the reference's call site is
##   matched to the *state change the same line of the port produces*, which is the
##   only faithful option: an id that does not exist cannot be routed.
##
##     sfx.hit()     at js/game.js:1893 hitBall            -> `ball.hitFlash` rises
##                     (set to 1.0/1.35 at the contact point, sim.gd:1847-1851;
##                      the contract's own note: "the port's hit_ball stores ... none
##                      at the raw contact point")
##     sfx.serve()   at js/game.js:750  performServe        -> `ball.serveInFlight` rises
##                     (set true only in perform_serve, sim.gd:735; the contract's note:
##                      "the ported perform_serve stores no event id at the strike")
##     sfx.victory/defeatMatch() at js/game.js:2113-2115   -> `state.result` becomes
##                     non-null (`winner` decides which). The contract's note: "the
##                     authoritative port signal is state.result being set".
##
##   Nothing else plays a sound. An id that maps to no sound is silent, on purpose:
##   `evLet`, `evTape`, the tactic ids and the 90-odd readable-only ids are text.
##
## HOW IT IS PROVEN WITHOUT A SOUND DEVICE
##   `AudioServer.get_driver_name()` is `"Dummy"` on this host: nothing can be
##   listened to. So the evidence is engine state: every request is counted by
##   contract event id, `play_event()`'s return value and `last_play_error` are
##   checked, and `port.is_playing()` is read back during the match. `requests` is
##   the tick-stamped log the slice test asserts on.
extends Node

const AudioPortScript := preload("res://src/audio/audio_port.gd")
## The port's MUSIC engine (`js/audio.js:106-271`). It is a module of its own, not an
## event: the reference starts it with the match (`js/main.js:1211-1212`), re-drives its
## intensity from the rally and the scoreboard every frame (`:1273-1279`) and stops it
## when the match ends (`:1438`). Until this seam existed the module was tested and never
## heard, which is the one open item the hand-off named ("you will hear effects only").
const MusicScript := preload("res://src/audio/music.gd")

## `js/main.js:1211` — the intensity a match opens at, before the first rally.
const REFERENCE_START_INTENSITY := 0.12

## The routing decision, as data. Keys are message ids the ported simulation can
## store at the reference's own `sfx.*` call site (contract `port.eventIdAnchors`).
const ANCHORED_SOUNDS := {
	# handle_walls / handle_net_collision / handle_ground_bounce
	"evWallValid": "wall",
	"evTape": "net",
	"evNetRebound": "net",
	"evServeValid": "bounce",
	"evSmashValid": "bounce",
	# apply_special, one id per athlete's special (sim.gd:1884-1915)
	"evPrecision": "special",
	"evLightningDash": "special",
	"evSteamSmash": "special",
	"evSteamShield": "special",
	"evPerfectVision": "special",
	"evSteamHammer": "special",
}

## The two composite point ids are prefixes, not keys: the simulation stores
## `pointYou:<reason>` / `pointOpp:<reason>` (sim.gd:2026) and the reference plays
## `sfx.point(winner === "player")` (`js/game.js:2111`).
const POINT_PREFIXES := {
	"pointYou": "point-win",
	"pointOpp": "point-loss",
}

## The audio module, built from the contract at `_ready()`.
var port: Node = null
## The music engine, built at `_ready()` and driven from the match's own state.
var music: Node = null
var use_ost := false
var ost: Node = null
## How many times the score has been stopped (a match end), for the read-back.
var music_stops: int = 0
## The last intensity this seam pushed into the score.
var music_last_intensity: float = -1.0
## Every sound requested, in order: {tick, event, source, started}.
var requests: Array[Dictionary] = []
## Requests the module refused, with the reason it gave.
var errors: Array[Dictionary] = []
## Per contract-event-id request count.
var counts: Dictionary = {}
## The last tick at which `port.is_playing()` was observed true for any event.
var last_playing_probe: Dictionary = {}

var _prev_hit_flash: float = 0.0
var _prev_serve_in_flight: bool = false
var _prev_had_result: bool = false
var _prev_points_total: int = -1
var _prev_player_points: int = 0
var _prev_ring: Array = []
var _ticks: int = 0


func _ready() -> void:
	port = AudioPortScript.new()
	port.name = "AudioPort"
	add_child(port)
	if use_ost:
		ost = get_node("/root/BackgroundMusic")
		ost.set_muted(false)
		return
	music = MusicScript.new()
	music.name = "Music"
	add_child(music)
	# The menu context is the reference's own name for silence (there is no menu
	# theme — see `music.gd`'s header), so a scene that never starts a match stays quiet.
	music.set_context(MusicScript.CONTEXT_MENU)


## Forget the previous match: the ring, the edge detectors and the request log.
## Called on `start_match()`/`rematch()` so a restart does not fire on the old
## match's last tick, and so the counters describe one match.
func reset() -> void:
	if ost != null:
		ost.set_held(false)
		ost.set_arena(preload("res://game/match_config.gd").arena_id())
	_prev_hit_flash = 0.0
	_prev_serve_in_flight = false
	_prev_had_result = false
	_prev_points_total = -1
	_prev_ring = []
	_ticks = 0
	requests.clear()
	errors.clear()
	counts.clear()
	last_playing_probe.clear()
	if port != null:
		port.stop_all()
	# The reference starts the score with the match, at its opening intensity
	# (`js/main.js:1211-1212`), and a rematch is that same call — so a restart never
	# inherits the previous match's tempo.
	if music != null:
		music.stop()
		music.set_intensity(REFERENCE_START_INTENSITY)
		music_last_intensity = REFERENCE_START_INTENSITY
		music.set_context(MusicScript.CONTEXT_MATCH)


# ---------------------------------------------------------------------------
# The routing decision
# ---------------------------------------------------------------------------

## One message id -> one contract event id, or `""` for "this id is text, not a
## sound". This is the whole decision; the table above is its data.
static func sound_for_message_id(message_id: String) -> String:
	if ANCHORED_SOUNDS.has(message_id):
		return String(ANCHORED_SOUNDS[message_id])
	var sep := message_id.find(":")
	var parent := message_id if sep < 0 else message_id.substr(0, sep)
	if POINT_PREFIXES.has(parent):
		return String(POINT_PREFIXES[parent])
	return ""


# ---------------------------------------------------------------------------
# Per-tick observation
# ---------------------------------------------------------------------------

## Called once per simulation tick, after `Sim.update_match`. Plays whatever the
## tick produced and returns the contract event ids it played, in order.
##
## The ring diff: `state.events` is a five-slot newest-first ring (`add_event`,
## sim.gd:241-244). The new entries are the prefix of the new ring up to the first
## entry that is also the head of the previous ring. A tick that emitted six or more
## events would be under-reported (the ring holds five); the sim's own sites emit at
## most a couple per tick, and the slice test reports the observed maximum.
func observe(state, tick: int) -> Array:
	_ticks = tick
	var played: Array = []
	var ring: Array = state.events
	for message_id in new_events(_prev_ring, ring):
		var sounds := _request(sound_for_message_id(String(message_id)), String(message_id), tick)
		played.append_array(sounds)
	_prev_ring = ring.duplicate()
	played.append_array(_transition_sounds(state, tick))
	_drive_music(state)
	return played


## The new entries of the events ring, oldest of the new first.
static func new_events(previous: Array, ring: Array) -> Array:
	if ring.is_empty():
		return []
	if previous.is_empty():
		return [ring[0]]
	var head: Variant = previous[0]
	for i in ring.size():
		if ring[i] == head:
			var fresh: Array = []
			for j in range(i - 1, -1, -1):
				fresh.append(ring[j])
			return fresh
	# The previous head fell off the ring: five or more events in one tick.
	return ring.duplicate()


## The three triggers the simulation stores no message id for — see the header.
func _transition_sounds(state, tick: int) -> Array:
	var played: Array = []
	var hit_flash := float(state.ball.hitFlash)
	if hit_flash > _prev_hit_flash:
		played.append_array(_request("hit", "ball.hitFlash", tick))
	_prev_hit_flash = hit_flash

	var in_flight: bool = bool(state.ball.serveInFlight)
	if in_flight and not _prev_serve_in_flight:
		played.append_array(_request("serve", "ball.serveInFlight", tick))
	_prev_serve_in_flight = in_flight

	# Points. The reference plays `sfx.point(winner === "player")` in the very
	# statement that stores the message id (`js/game.js:2110-2111`), and the port
	# stores that id in `state.pointMessage` (sim.gd:2026) — NOT in the events ring,
	# so the ring diff above cannot see it. The routing id therefore comes from
	# `pointMessage` itself, and the "a point just happened" edge comes from the
	# sim's own totals (`stats.pointsWon`, the field `sync_point_display` maintains).
	# A point that ENDS the match is the match's sound: the reference's `else if`
	# means the last point never plays a point sound.
	var player_points := int(state.stats["pointsWon"]["player"])
	var total := player_points + int(state.stats["pointsWon"]["ai"])
	if _prev_points_total < 0:
		_prev_points_total = total
		_prev_player_points = player_points
	elif total > _prev_points_total:
		_prev_points_total = total
		if state.result == null:
			var sound := sound_for_message_id(String(state.pointMessage))
			if sound == "":
				# The id would have been a point id; route by which side's count rose
				# and say so, rather than guessing silently.
				sound = "point-win" if player_points > _prev_player_points else "point-loss"
			played.append_array(_request(sound, "state.pointMessage:%s" % String(state.pointMessage), tick))
		_prev_player_points = player_points

	var has_result: bool = state.result != null
	if has_result and not _prev_had_result:
		var winner := String(state.result["winner"])
		var event_id := "victory" if winner == "player" else "defeat"
		played.append_array(_request(event_id, "state.result:%s" % winner, tick))
	_prev_had_result = has_result
	return played


static func points_total(state) -> int:
	return int(state.stats["pointsWon"]["player"]) + int(state.stats["pointsWon"]["ai"])


func _request(event_id: String, source: String, tick: int) -> Array:
	if event_id == "":
		return []
	var started: bool = port != null and port.play_event(event_id)
	if not started:
		errors.append({
			"tick": tick,
			"event": event_id,
			"source": source,
			"error": String(port.last_play_error) if port != null else "no audio port",
		})
		return []
	counts[event_id] = int(counts.get(event_id, 0)) + 1
	requests.append({"tick": tick, "event": event_id, "source": source})
	# Engine state, not a flag: the module's own `is_playing` reads the player.
	last_playing_probe[event_id] = port.is_playing(event_id)
	return [event_id]


# ---------------------------------------------------------------------------
# Read-back for the slice test and for the evidence file
# ---------------------------------------------------------------------------

func total_requests() -> int:
	return requests.size()


func is_physical() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


func summary() -> Dictionary:
	var sources: Dictionary = {}
	for row in requests:
		sources[String(row["source"])] = int(sources.get(String(row["source"]), 0)) + 1
	return {
		"driver": AudioServer.get_driver_name(),
		"ticks_observed": _ticks,
		"requests": requests.size(),
		"counts": counts.duplicate(),
		"by_source": sources,
		"errors": errors.duplicate(),
		"playing_probe": last_playing_probe.duplicate(),
		"contract_events": (Array(port.event_ids()) if port != null else []),
		"music": music_summary(),
	}


## The reference's own drive, ported line for line (`js/main.js:1273-1279`):
##
##     rallyTension = min(1, rallyHits / 12)
##     stakes       = min(0.35, (sets.p + sets.a) * 0.15 + (games.p + games.a) * 0.02)
##     intensity    = min(1, 0.12 + rallyTension * 0.55 + stakes)
##
## and the stop at the match's end (`:1438`). A paused frame in the reference still
## re-drives the intensity (`gameLoop` runs while paused), so this does too: pause is not
## a reason to freeze the tempo map, only to stop advancing the match.
func _drive_music(state) -> void:
	if ost != null:
		ost.set_muted(port.is_muted() if port != null else false)
		if state.result != null:
			ost.set_screen("result")
		else:
			ost.set_arena(preload("res://game/match_config.gd").arena_id())
			ost.classic.set_intensity(ost.classic.intensity_for_rally(int(state.rallyHits), int(state.sets["player"]) + int(state.sets["ai"]), int(state.games["player"]) + int(state.games["ai"])))
		return
	if music == null:
		return
	if state.result != null:
		if bool(music.playing):
			music.stop()
			music_stops += 1
		return
	var rally_tension: float = minf(1.0, float(state.rallyHits) / 12.0)
	var stakes: float = minf(0.35,
		float(int(state.sets["player"]) + int(state.sets["ai"])) * 0.15
		+ float(int(state.games["player"]) + int(state.games["ai"])) * 0.02)
	var want: float = minf(1.0, REFERENCE_START_INTENSITY + rally_tension * 0.55 + stakes)
	music.set_intensity(want)
	music_last_intensity = want
	if not bool(music.playing):
		music.start()


## What the slice test and the evidence file read back about the score: the engine's own
## state, never a flag this seam keeps about itself.
func music_summary() -> Dictionary:
	if ost != null:
		return {
			"present": true,
			"engine": "ost",
			"playing": ost.classic.is_processing() if ost._track == ost.CLASSIC else ost.player.is_playing(),
			"paused": ost._held or ost._muted,
			"track": ost._track,
			"muted": port.is_muted(),
			"master_gain": port.master_gain(),
		}
	if music == null:
		return {"present": false}
	return {
		"present": true,
		"playing": bool(music.playing),
		"context": String(music.context),
		"intensity": float(music.intensity),
		"last_intensity_set": music_last_intensity,
		"voices_started": int(music.voices_started),
		"stops": music_stops,
		"muted": bool(music.is_muted()),
		"master_gain": float(music.master_gain()),
		"music_bus_gain": float(music.reference_music_bus_gain()),
	}
