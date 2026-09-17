## match_controller.gd — the quick-match scene: it owns one `SimState` from
## `Sim.create_match_state`, steps it with the fixed `1/120` tick, drives the 3D
## arena, the four athletes, the ball and the paddles from that state, and feeds
## the HUD.
##
## The rules, physics and tuning are NOT here. This file calls `Sim.update_match`
## and reads `state`. The one place it looks like logic — `_observe` — only counts
## what the sim already produced (ball crossings of the net, points, events), for
## the HUD and for the headless slice run's assertions.
##
## Input and the clock, exactly as the browser does it (`js/main.js:1186-1205`).
## ONE rendered frame runs the whole sequence, in `apply_frame()`, which `_process`
## calls and the slice test calls with its own sample and delta:
##   - the frame's input struct is sampled ONCE and its one-shot edges
##     (`hit`, `special`, `switchPlayer`, `switchDirection`, `smashUpgrade`,
##     `cutVolley`, `globo`, `teamTactic`) are **latched**;
##   - the frame's own `delta` goes into the accumulator, which is clamped to
##     `FIXED_STEP * MAX_SIM_STEPS`, and whole `1/120` s ticks run until it is spent;
##   - the latched one-shots are delivered to the FIRST sub-step of the frame and
##     cleared before the second, so the same shot can never be queued twice. If a
##     frame justifies no sub-step at all, the latch survives to the next frame —
##     which is what makes a press+release inside one frame (render fps > 120)
##     reach the simulation instead of being overwritten.
##
## THE CLOCK IS THE RENDER FRAME, NOT GODOT'S PHYSICS TICK, and that is the point:
## `_physics_process` is never enabled. Its `delta` is always `1/120` (the project's
## `physics_ticks_per_second`) whatever the render rate, and Godot runs it 0, 1 or 2
## times per rendered frame — so stepping there advances the simulation once per
## rendered frame at best, i.e. 60 ticks per wall second at 60 fps and a dropped
## sample at 240 fps. That was the independent review's H-2 defect; the browser
## instead adds the RENDER frame's duration to its accumulator, which is what this
## file does now. The measured proof is `_frame_clock_contract()` in
## `tests/game_slice_test.gd`: the same wall-clock time yields the same 120 ticks/s
## at 30, 60 and 240 fps.
##
## The browser, for comparison, reads its queued flags directly (`hitQueued`,
## `specialQueued`, `js/main.js:2573-2580`) and clears them with the same
## `consumeOneShot` after the first sub-step; the latch is the port's equivalent of
## a key queue it does not have, and the substep size is the same `1/120` in both,
## which is the property that matters for determinism.
##
## Headless: the same scene and the same controller run without a display. The
## athletes are real rigs (`game/athletes_view.gd`); when their GLBs cannot be read
## the controller falls back to capsule bodies and says so in its own log line, and
## `engine_driven` can be switched off so a harness drives the ticks itself through
## the public `tick_fixed()` — one code path, two clocks.
extends Node3D

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Court := preload("res://game/court.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const InputSource := preload("res://game/input_map.gd")
const HudScript := preload("res://game/hud.gd")
const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MatchAudioScript := preload("res://game/match_audio.gd")
const AthletesView := preload("res://game/athletes_view.gd")
const Lineup := preload("res://game/lineup.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const AthleteRig := preload("res://src/character/athlete_rig.gd")
const ModeSession := preload("res://game/mode_session.gd")
const ModeHudScript := preload("res://game/mode_hud.gd")

## `js/main.js:1164-1165`.
const FIXED_STEP := 1.0 / 120.0
## `MAX_SIM_STEPS` (`js/main.js:1165`): the catch-up clamp. At most this many whole
## `1/120` s ticks may run for one rendered frame, i.e. at most 66.7 ms of simulated
## time per frame. Below 15 fps the simulation therefore falls behind wall clock by
## design — the browser's anti-spiral-of-death bound, kept because a machine that
## cannot render faster than the simulation must not be asked to simulate faster.
const MAX_SIM_STEPS := 8
## `Math.min(dt, 0.25)` (`js/main.js:1189`): a frame longer than a quarter second
## (a breakpoint, a stall, a window drag) contributes a quarter second, not itself.
const MAX_FRAME_DELTA := 0.25
## The one-shot fields, `consumeOneShot` (`js/main.js:1167-1180`) plus the port's
## `globo`, which `input_map.gd` fills from the same pad press.
const ONE_SHOTS := ["hit", "special", "switchPlayer", "switchDirection", "smashUpgrade", "cutVolley", "globo", "teamTactic"]
## How far above the floor the active athlete's zone lies, in metres. `world_pos`'s
## third argument is in sim PIXELS, so a metre value passed there lands a thousandth
## of itself up: 0.04 gave y = 1 mm and the depth buffer swallowed the ring whole.
## 3 cm is what the athletes' own tint rings use (`court.gd:279`).
const ACTIVE_RING_LIFT := 0.03
## How high the marker floats above the athlete's feet, in metres: above the head
## (~1.9 m on this rig), clear of the racket swing, inside the default framing.
const ACTIVE_PIN_HEIGHT := 2.45

# ---------------------------------------------------------------------------
# The timing presentation (`js/render.js:1646-1750`, `js/render.js:1031-1037`)
# ---------------------------------------------------------------------------
# The reference draws four things around `state[state.activePlayerKey]`, three of
# them only while a shot is charging:
#
#   ring       at `p.y - 96*scale`: a `1.85*PI` track in `rgba(255,255,255,0.22)`
#              with radius `20*scale` and stroke `3.4*scale`, a coloured arc up to
#              `1.6*PI * clamp(1 - eta/0.55, 0, 1)` over it, and a green blinking
#              circle when `|eta| <= perfectWindow`   (`js/render.js:1655-1690`)
#   precision  at `p.y - 64*scale`, `46*scale x 5*scale`, cyan below the armed
#              threshold and amber/pulsing above     (`js/render.js:1695-1726`)
#   advice     at `p.y - 132*scale`, `t("shotAdvice_<advice>")` in the profile
#              colour                                  (`js/render.js:1730-1750`)
#   energy     at `p.y + 54*scale`, `52*scale` long, a 2 px fill over a 4 px track,
#              drawn EVERY frame for the active athlete with the player side's
#              energy                                  (`js/render.js:1031-1037`)
#
# THOSE OFFSETS ARE CANVAS PIXELS OF A HAND-DRAWN PROJECTION, NOT METRES. The
# reference's own `point()` (`js/render.js:740-750`) returns
# `scale = 0.58 + depth * 0.62` for a 960x620 canvas in which the athlete sprite is
# ~139 px tall. The port's court is 10 x 20 m, so every offset is re-expressed as a
# HEIGHT IN METRES above the athlete's feet and every size in metres, and then
# MEASURED on a rendered frame: `evidence/active-player-marker.md` is the record of
# what happens when a ring that is faithful to the 2D numbers is believed instead
# of measured (98 x 25 px, invisible).
#
# The heights follow the reference's own order from the feet up — precision below
# the ring, the verdict inside it, the advice above — re-spaced for the sizes the
# measurements forced (`TIMING_RING_RADIUS` below): at these sizes the advice has to
# clear the pin at 2.45 m, and it does.
const TIMING_ENERGY_HEIGHT := 0.30
const TIMING_PRECISION_HEIGHT := 0.75
const TIMING_RING_HEIGHT := 1.60
const TIMING_VERDICT_HEIGHT := 1.44
const TIMING_ADVICE_HEIGHT := 2.95
## How far towards the camera the bar under the athlete's feet is pulled. The
## reference draws it BELOW the feet in screen space (`p.y + 54*scale`), which in
## three dimensions is under the floor: drawn in front of the feet instead, at
## `TIMING_ENERGY_HEIGHT`, it lands under the athlete in the frame.
const TIMING_FOOT_FORWARD := 0.5

# TWO CONVERSIONS, AND WHICH ONE EACH THING IS IN.
#
# THE FRAME'S OWN: on a 1280x720 capture the default camera maps one metre at the
# athlete's feet to ~36 px vertically, measured on a rendered frame — the 2.45 m pin
# floats 89 px above the athlete's feet, the 0.18 m energy track prints 7 px tall.
# It is the number the delivered sizes are *read* against (`TIMING_PX_PER_M`), and it
# grows with the window: the camera's vertical FOV is fixed, so a 1568x881 frame
# prints the same metre at ~44 px. A world-anchored mark therefore scales with the
# window exactly as the court does.
const TIMING_PX_PER_M := 36.0
const TIMING_M_PER_PX := 1.0 / TIMING_PX_PER_M
#
# THE REFERENCE'S OWN, which is what its TEXTS are sized in. The reference draws on a
# 960x620 canvas (`js/render.js:1627`) whose ring floats `96*scale` px above the feet
# (`js/render.js:1657`); this port maps that offset to `TIMING_RING_HEIGHT` metres, so
# the reference's canvas reads 60 px/m and ONE REFERENCE PIXEL IS 1/60 m.
#
# The lane that delivered the first sizes read the reference's fonts at `1280/960`
# and then at 36 px/m — the frame's canvas scale applied on top of a world conversion
# — which printed 11 px as 0.417 m instead of 0.183 m, twice the reference's
# proportion (measured: 16 px glyphs where the reference's proportion is 6.6 px). That
# size is what the owner rejected with *"le scritte qui sono troppo grandi"*. The
# reference's own canvas is itself scaled to the window
# (`ctx.scale(canvas.width / 960, canvas.height / 620)`; `.canvas-wrap canvas
# { object-fit: contain }`, `styles.css:2836-2843`), so the proportion — 11 of the
# ring's 96 px — is what is held at every window size, not a fixed pixel count.
const TIMING_REF_PX_PER_M := 60.0
const TIMING_REF_M_PER_PX := 1.0 / TIMING_REF_PX_PER_M

## The reference's `20*scale` radius and `3.4*scale` stroke (`js/render.js:1658`,
## `:1675`) are 26.7 px of radius on this frame; the faithful 0.44 m printed a
## 48 x 36 px ellipse whose stroke did not read, so the radius is enlarged to ~37 px
## of horizontal extent (the ring's vertical extent is foreshortened by the camera,
## which is why the measured mark is an ellipse). The before/after is in
## `docs/wayfinder/evidence/timing-presentation-3d.md`.
const TIMING_RING_RADIUS := 0.62
const TIMING_RING_WIDTH := 0.11
## The green circle of a met perfect window (`js/render.js:1679-1688`): radius
## `r + 5*scale`, stroke `2*scale`, alpha `0.55 + 0.4*blink`.
const TIMING_FLASH_GAP := 0.20
const TIMING_FLASH_WIDTH := 0.07
## `ctx.arc(0, 0, r, 0, Math.PI * 1.85)` and `... * 1.6 * frac` (`js/render.js:1667`,
## `:1677`), and the fill `1 - read.eta / 0.55` (`js/render.js:1659`).
const TIMING_ARC_TRACK := PI * 1.85
const TIMING_ARC_FILL := PI * 1.6
const TIMING_ETA_SPAN := 0.55
## `if ((state.shotCharge ?? 0) > 0.05 && read?.active)` — the reference's gate, used
## for the ring and for the precision bar (`js/render.js:1656`, `:1695`).
const TIMING_CHARGE_FLOOR := 0.05
## `precision > 0.04` (`js/render.js:1695`). `state.shotPrecision` is the SPRINT
## input (`sim.gd:2643`), so this bar is drawn exactly while a human holds RT.
const TIMING_PRECISION_FLOOR := 0.04
## `46*scale x 5*scale` and `52*scale` with a 2 px fill over a 4 px track
## (`js/render.js:1697-1700`, `:1031-1037`), enlarged: 43 x 7 px and 49 x 2.7 px are
## marks whose thickness the ticket's ~20 px rule catches.
const TIMING_PRECISION_W := 0.80
const TIMING_PRECISION_H := 0.14
const TIMING_ENERGY_W := 0.80
const TIMING_ENERGY_H := 0.13
## The advice panel: `800 ${11 * scale}px` in a `tw + 22` by 20 px rounded rect
## (`js/render.js:1734-1742`). `TIMING_ADVICE_FONT_PX` is the reference's 11 px, and
## the box and the padding are its own ratios to that font: 20/11 and 22/11.
const TIMING_ADVICE_FONT_PX := 11.0
const TIMING_ADVICE_BOX_LINES := 20.0 / 11.0
const TIMING_ADVICE_PAD_LINES := 22.0 / 11.0
## The three font sizes are THE REFERENCE'S OWN pixel values — `800 ${11 * scale}px`
## (`js/render.js:1734`), `700 14px` and `600 9px` (`js/render.js:1060`, `:1068`) —
## printed at `TIMING_REF_M_PER_PX`: `font_size * pixel_size` is the word's height in
## metres, so 11 / 14 / 9 px are 0.183 / 0.233 / 0.150 m and read 6.6 / 8.4 / 5.4 px
## on a 1280x720 frame's 36 px/m. They are WORLD sizes: they hold the reference's
## proportion to the ring (11 of its 96 px) at any window size, and grow with the
## window exactly as the ring and the court beside them do, which is what the
## reference's own window-scaled canvas does.
const TIMING_ADVICE_PX := 11
const TIMING_VERDICT_PX := 14
const TIMING_VERDICT_MODE_PX := 9
## The verdict over the athlete who hit (`js/render.js:1041-1069`): the grade word
## at `700 14px` with a 5 px `rgba(4, 14, 32, 0.9)` stroke, the mode line at
## `600 9px` fifteen pixels below it, and the whole thing rising `(0.78 - life) * 18`
## px while it fades with `alpha = clamp(life / 0.28, 0, 1)`.
const TIMING_VERDICT_FONT_PX := 14.0
const TIMING_VERDICT_MODE_FONT_PX := 9.0
## `p.fillText(feedback.mode, p.x, y + 15)` (`js/render.js:1068`), in metres: the
## reference's own 15 px, at the reference's own 60 px/m.
const TIMING_VERDICT_MODE_DROP := 15.0 * TIMING_REF_M_PER_PX
const TIMING_VERDICT_OUTLINE := Color(0.016, 0.055, 0.125, 0.9)
## The 18 px of upward drift over the feedback's 0.78 s life (`js/render.js:1062`),
## in metres at the reference's own sprite scale.
const TIMING_VERDICT_DRIFT := 0.25
const TIMING_VERDICT_LIFE := 0.78
const TIMING_VERDICT_FADE := 0.28
## The reference's four gradient stops (`js/render.js:1670-1673`), sampled by each
## vertex's own local x projection: `createLinearGradient(0, 0, r, 0)` inside the
## `rotate(-PI/2)` frame, so the point at the top of the ring takes the last stop
## (orange) and the one at the bottom the first (cyan), and a canvas gradient clamps
## past its ends.
const TIMING_GRADIENT := [
	[0.0, Color(0.157, 0.843, 0.910)],   # #28d7e8
	[0.72, Color(0.620, 0.941, 0.357)],  # #9ef05b
	[0.86, Color(1.0, 0.953, 0.416)],    # #fff36a
	[1.0, Color(1.0, 0.439, 0.282)],     # #ff7048
]
## One ribbon segment every 7.5 degrees: the fill is quantised to this step, and a
## step change is what rebuilds the arc's mesh.
const TIMING_ARC_STEP := PI / 24.0

var state
var ticks: int = 0
var crossings: int = 0
var points_scored: int = 0
var max_rally: int = 0
var seen_events: Dictionary = {}
var score_history: Array = []
var meta: Dictionary = {}
var finished: bool = false

## The playable mode session this scene is running, or null for a quick match.
## `Config.pending_mode` decides which: a mode entry on the menu sets it, and the
## session in turn resolves the arena, the rival pair and the AI profile through
## `godot/src/modes/**` and persists the result through `ModesSave`. A quick match
## leaves it null and this file behaves exactly as it did before modes existed —
## which is what keeps the frame-clock and parity checks their own subject.
var session = null

## Off for the headless harness, which calls `tick_fixed()` itself.
var engine_driven: bool = true
## Off when there is no display (or when a harness asks): the rigs are not spawned.
var load_models: bool = true
var use_scripted_input: bool = false

## The browser's accumulator (`js/main.js:1187-1205`). Simulated time owed, in
## seconds, never above `FIXED_STEP * MAX_SIM_STEPS` and never negative.
var sim_accumulator: float = 0.0
## One-shot fields armed by a rendered frame and not yet consumed by a sub-step.
var queued_one_shots: Dictionary = {}
## The second player's latched one-shots, kept apart from the first's: the reference
## latches per pad (`gamepad2.*Queued`, `js/main.js:1096-1134`) and `advance_frame`
## consumes both at the same sub-step boundary.
var queued_one_shots2: Dictionary = {}
## Ticks run for the most recent rendered frame, and the largest value seen: the
## clamp made visible, which is what the review asked this file to report.
var last_frame_steps: int = 0
var max_frame_steps: int = 0
## The input struct of the most recent tick, for the harness to read back.
var last_tick_input: Dictionary = {}

var _input_source
## The second player's sampler: device 1, pad only. Sampled only when a second human
## is on court (`_second_human`); every other mode keeps the empty input.
var _input_source2
var _scripted = ScriptedPlayer.new()
var _frame_input: Dictionary = {}
var _frame_input2: Dictionary = {}
var _pending_input: Dictionary = {}
var _pending_input2: Dictionary = {}
var _hud
var _mode_hud
var _audio
var _cam: Camera3D
## The arena environment currently in the scene, built by
## `game/arenas/arena_library.gd`. Rebuilt in place when the arena changes (the
## per-arena capture run does exactly that, nine times).
var _arena_root: Node3D
var _ball_view: MeshInstance3D
var _land_ring: MeshInstance3D
## Fixed-size floor halo identifying the controlled athlete.
var _active_ring: MeshInstance3D
## Camera-facing downward triangle above the controlled athlete.
var _active_pin: MeshInstance3D
## The timing presentation (`js/render.js:1646-1750`): the ring that fills with the
## charge and its track, the green circle of a met perfect window, the advice word
## and its panel, the RT precision bar and the energy bar under the athlete's feet.
## Built by `_build_timing_marks`, placed every frame by `_sync_timing`.
var _timing_ring: MeshInstance3D
var _timing_ring_track: MeshInstance3D
var _timing_window: MeshInstance3D
var _timing_advice: Label3D
var _timing_advice_panel: MeshInstance3D
var _timing_precision: MeshInstance3D
var _timing_precision_track: MeshInstance3D
var _timing_energy: MeshInstance3D
var _timing_energy_track: MeshInstance3D
## The verdict over the athlete who hit (`js/render.js:1041-1069`). The mode line is
## the reference's own second line (`js/render.js:1066-1068`).
var _timing_verdict: Label3D
var _timing_verdict_mode: Label3D
## The last `_sync_timing`'s numbers, for the tests, the capture's marker line and
## the evidence. Never read back into the drawing: `_sync_views` recomputes.
var _timing_state: Dictionary = {}
## Segments the fill arc was last built with: the mesh is rebuilt when the fill
## changes, not on every frame.
var _timing_fill_segments: int = 0
## Set only by the capture's A/B frame: every timing mark off, for the same tick.
var _timing_muted: bool = false
## The drill's target, drawn where the drill session put it. Invisible in every
## other mode (and in quick match, where there is no session at all).
var _target_ring: MeshInstance3D
## The four athletes as real rigs (`game/athletes_view.gd`). Empty of rigs when the
## rig GLBs cannot be read, in which case `_athlete_roots` holds capsule fallbacks.
var _athletes: Node3D
var _lineup: Dictionary = {}
var _player_color: Color = Color(0.0, 0.898, 1.0)
var _ai_color: Color = Color(0.54, 0.83, 1.0)
var _athlete_roots: Dictionary = {}
var _paddle_views: Dictionary = {}
var _capture_shots: Array = []
var _capture_index: int = 0
var _capture_ticks: int = 0
var _paused: bool = false
var _points_total_prev: int = 0


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var capture := _arg(args, "--capture=", "")
	var camera := _arg(args, "--camera=", Config.camera_preset)
	var tier := _arg(args, "--tier=", "")
	var athlete := _arg(args, "--athlete=", "")
	var arena_arg := _arg(args, "--arena=", "")
	var seed_arg := _arg(args, "--seed=", "")
	# THE DEMO GATE, ON EVERY ENTRY ROUTE (review-2 F-2). This scene used to write
	# `Config.tier_index` / `athlete_index` / `arena_index` straight from the
	# command line, so a demo build launched as
	# `Match.tscn -- --demo --athlete=5 --arena=orrery --tier=3` started on
	# `leggenda`/`colosso`/`orrery` — locked content — because the only caller of
	# `Config.apply_build_limits()` was the menu. `apply_cli_selection` pins the
	# selection into what this build grants and refuses anything else by name, and
	# it is the only path from an argument to a selection.
	var selection := Config.apply_cli_selection(athlete, arena_arg, tier)
	if not (selection["refused"] as Dictionary).is_empty():
		print("MATCH_BUILD_GATE refused=%s effective=%s (this build does not grant them)" % [
			JSON.stringify(selection["refused"]), JSON.stringify(selection["effective"])])
	else:
		print("MATCH_BUILD_GATE refused={} effective=%s" % JSON.stringify(selection["effective"]))
	if seed_arg != "":
		Config.seed_value = int(seed_arg)
	Config.camera_preset = camera

	var headless := DisplayServer.get_name() == "headless"
	load_models = not headless
	if _arg(args, "--models=", "") == "0":
		load_models = false
	# The accumulator is driven by rendered frames (`apply_frame`), never by Godot's
	# fixed physics tick: at 120 Hz and with a `delta` that is always `1/120`, the
	# physics callback can only ever justify one tick per rendered frame — the
	# review's H-2 defect. Off in every mode, headless or not.
	set_physics_process(false)

	print("MATCH_START tier=%s athlete=%s arena=%s seed=%d camera=%s models=%s headless=%s switch=%s" % [
		String(Config.tier()["id"]),
		String(Config.athlete()["id"]),
		String(Config.arena()["id"]),
		Config.seed_value,
		camera,
		str(load_models),
		str(headless),
		# The switching mode the match is about to run with, read the same way
		# `start_match` / `_adopt_session` read it (`js/main.js:1184`).
		Config.control_mode(),
	])

	_input_source = InputSource.new()
	_input_source2 = InputSource.new(false)
	# A mode match resolves its arena, its rival and its AI through
	# `godot/src/modes/**` BEFORE the scene is built: the court the physics runs on
	# is the fixture's, not the menu's selection, so the arena has to be known by
	# the time `_build_scene()` asks `Config.arena_id()`.
	if Config.pending_mode != "quick" and Config.pending_mode != "":
		_start_mode_session()
	_build_scene()
	if session != null:
		_adopt_session()
	else:
		start_match()

	if capture != "":
		engine_driven = false
		set_physics_process(false)
		if capture == "arenas":
			# One engine run renders all nine arenas: this host allows exactly one
			# Godot process at a time and every software-rendered start-up is paid
			# for once (`godot/game/run.sh shots-arenas`).
			_run_arena_capture()
		elif capture == "modes":
			# One engine run renders all three mode HUDs, in the same scene, for the
			# same reason: one start-up, one software renderer.
			_run_mode_capture()
		else:
			_capture_shots = _capture_plan()
			_run_capture()


func _arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


# ---------------------------------------------------------------------------
# Modes: one playable session, resolved and persisted by `game/mode_session.gd`
# ---------------------------------------------------------------------------

## Builds the mode session and moves THIS match's configuration onto the mode's own
## fixture: the arena the calendar or the bracket names, and the AI tier whose
## colour and name the scoreboard shows. Nothing is guessed here — the session
## answers all of it through `godot/src/modes/**`.
##
## A refused mode (the demo build, `DEMO_CONTENT.modes = ["quick"]`) leaves
## `session` null and `pending_mode` back at "quick": the caller falls through to a
## quick match with a printed reason instead of a half-built mode. That is the
## fourth of the four routes item 4 refuses, and it is the one no screen can
## bypass, because every screen goes through `Config.pending_mode` -> here.
func _start_mode_session() -> void:
	var wanted := String(Config.pending_mode)
	session = ModeSession.start(wanted, Config.save_store(), Config.mode_options())
	if session == null:
		print("MODE_REFUSED mode=%s reason=%s (build grants %s)" % [
			wanted, ModeSession.refusal(wanted), str(Config.mode_ids()),
		])
		Config.pending_mode = "quick"
		return
	# The session's arena is the fixture's. `set_arena_id` keeps the config, the
	# arena library and the scoreboard reading one arena.
	var arena_id := String(session.arena.get("id", ""))
	if arena_id != "":
		Config.set_arena_id(arena_id)
	# The tier index the mode's own AI profile corresponds to, for the scoreboard
	# colour and the opponent's name. A profile the frozen table does not hold (a
	# ramped career rival is a COPY of a tier with raised numbers) falls back to
	# the plain career/tournament tier by id.
	var opponents: Array = Frozen.ai_opponents()
	for i in opponents.size():
		if String((opponents[i] as Dictionary).get("id", "")) == String(session.ai.get("id", "")):
			Config.tier_index = i
			break
	print("MODE_RESOLVED %s" % JSON.stringify(session.report()))


## Hands the controller the session's state. The tick loop, the accumulator, the
## one-shot latch and `apply_frame` are all untouched: only the state they step is
## the mode's, so there is still exactly one frame path and one physics path.
func _adopt_session() -> void:
	state = session.state
	# The saved switching mode, on the state the mode session built: the reference
	# copies it onto the match before its loop starts (`js/main.js:1184`).
	state.controlMode = Config.control_mode()
	ticks = 0
	crossings = 0
	points_scored = 0
	max_rally = 0
	seen_events = {}
	score_history = []
	finished = false
	_clear_pause()
	sim_accumulator = 0.0
	queued_one_shots.clear()
	queued_one_shots2.clear()
	last_frame_steps = 0
	max_frame_steps = 0
	last_tick_input = {}
	_scripted.reset()
	if _audio != null:
		_audio.reset()
	_points_total_prev = _points_total()
	meta = {
		"seed": Config.seed_value,
		"tier": String(Config.tier()["id"]),
		"camera": Config.camera_preset,
		"tick": 0,
		"mode": session.mode,
		"arena": String(session.arena.get("id", "")),
	}
	if _mode_hud != null:
		_mode_hud.bind_session(session)
	_sync_views()
	if _hud != null:
		_hud.refresh(state, meta)
	print("MODE_START %s" % JSON.stringify(session.report()))


## The single end-of-mode path. `session.finish()` awards what the reference awards
## and writes it through `ModesSave`; this only reports it and repaints. Idempotent
## on both sides, so a tick loop that observes the result twice persists once.
func _finish_mode() -> Dictionary:
	if session == null or session.finished:
		return session.awarded if session != null else {}
	var awarded: Dictionary = session.finish()
	if _mode_hud != null:
		_mode_hud.refresh()
	if _hud != null:
		_hud.refresh(state, meta)
	print("MODE_FINISH %s" % JSON.stringify(awarded))
	return awarded


## The drill's own exit (`js/main.js`'s drill screen leaves through a key, and the
## record is written then): a live drill ends here, with the reference's grading
## already accumulated attempt by attempt, and the record persisted on improvement.
func end_drill() -> Dictionary:
	if session == null or session.mode != "drill" or finished:
		return {}
	session.closed_by_player = true
	finished = true
	var awarded := _finish_mode()
	# `show_result` reads `state.result`, which a drill never sets: the drill's own
	# result is the mode HUD's ("FASE DONE" plus the attempt summary), so the match
	# result panel is only shown when the engine really produced a result.
	if _hud != null and state.result != null:
		_hud.show_result(state)
	return awarded


## The mode HUD this run built, or null in a quick match.
func mode_hud():
	return _mode_hud


## True in a quick match and in the two match modes; false in a drill, whose end
## is its own module's business. The one place that question is answered.
func _mode_runs_by_points() -> bool:
	return session == null or session.mode != "drill"


# ---------------------------------------------------------------------------
# Arenas: one environment per arena, built by `game/arenas/arena_library.gd`
# ---------------------------------------------------------------------------

## Adds one arena environment as a child of the match. Only the environment: the
## camera, the athletes, the ball and the HUD belong to the scene and are not
## rebuilt with it. Returns null for an unknown id.
func add_arena(id: String) -> Node3D:
	return Arena.build_into(self, id, Config.camera_preset)


## Switches the match to another arena: frees the previous environment, builds the
## new one, rebuilds the simulation state on the new arena's frozen values and
## re-syncs every view. Returns false for an unknown id, leaving the match alone.
func set_arena(id: String) -> bool:
	if not _swap_arena(id):
		return false
	# Restart on the new court: a mode restarts through its own resolution (the
	# round may have advanced, the season may have moved), a quick match through
	# `start_match`.
	if session != null:
		Config.pending_mode = session.mode
		session = null
		_start_mode_session()
		if session != null:
			_adopt_session()
		else:
			start_match()
	else:
		start_match()
	return true


## The environment half of `set_arena`: free the old arena, build the new one and
## point the config at it. No state is rebuilt, so a capture that only wants the
## arena drawn (and a mode whose state is already built) can use it alone.
func _swap_arena(id: String) -> bool:
	if not Arena.has(id):
		push_error("match_controller: unknown arena id '%s'" % id)
		return false
	if _arena_root != null and is_instance_valid(_arena_root):
		remove_child(_arena_root)
		_arena_root.free()
		_arena_root = null
	Config.set_arena_id(id)
	_arena_root = Arena.build_into(self, id, Config.camera_preset)
	if _arena_root == null:
		return false
	meta["arena"] = id
	return true


## How many meshes an arena environment draws — read back by the slice test.
func arena_mesh_count() -> int:
	return _count_meshes(_arena_root) if _arena_root != null else -1


func _count_meshes(from: Node) -> int:
	if from == null:
		return 0
	return from.find_children("*", "MeshInstance3D", true, false).size()


func _build_scene() -> void:
	_arena_root = add_arena(Config.arena_id())
	_cam = Court.build_camera(self, Config.camera_preset)

	var player_color := Color(String(Config.athlete().get("color", "#00e5ff")))
	var ai_color := Config.tier_color(Config.tier_index)
	_player_color = player_color
	_ai_color = ai_color
	if load_models:
		build_athletes()

	# The audio module, wired to the simulation through `game/match_audio.gd`. It is
	# built in headless runs too, on the Dummy driver: the wiring is engine state and
	# the slice test asserts on it, so it must not depend on a display.
	_audio = MatchAudioScript.new()
	_audio.name = "MatchAudio"
	add_child(_audio)

	_ball_view = MeshInstance3D.new()
	_ball_view.name = "Ball"
	var sm := SphereMesh.new()
	sm.radius = Court.BALL_R
	sm.height = Court.BALL_R * 2.0
	_ball_view.mesh = sm
	_ball_view.material_override = Court.material(Color(0.98, 0.90, 0.16), 0.4)
	add_child(_ball_view)

	_land_ring = MeshInstance3D.new()
	_land_ring.name = "LandRing"
	var rm := TorusMesh.new()
	rm.inner_radius = Court.BALL_R * 0.9
	rm.outer_radius = Court.BALL_R * 1.6
	_land_ring.mesh = rm
	_land_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_land_ring.material_override = Court.material(Color(0.98, 0.90, 0.16))
	_land_ring.visible = false
	add_child(_land_ring)

	# A compact selection halo. Its visual size is independent of the hitbox.
	_active_ring = MeshInstance3D.new()
	_active_ring.name = "ActiveRing"
	_active_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arm := TorusMesh.new()
	arm.inner_radius = 0.48
	arm.outer_radius = 0.54
	_active_ring.mesh = arm
	# TorusMesh already lies in XZ; rotating it stood the ring upright.
	var amat := Court.material(Color("fff36a"), 0.85, 0.95)
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_active_ring.material_override = amat
	_active_ring.visible = false
	add_child(_active_ring)

	# A small camera-facing triangle over the controlled athlete.
	_active_pin = MeshInstance3D.new()
	_active_pin.name = "ActivePin"
	_active_pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pin_mesh := ArrayMesh.new()
	var pin_arrays := []
	pin_arrays.resize(Mesh.ARRAY_MAX)
	pin_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.15, 0.12, 0), Vector3(0.15, 0.12, 0), Vector3(0, -0.16, 0)])
	pin_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pin_arrays)
	_active_pin.mesh = pin_mesh
	# Billboard keeps a downward triangle readable at every camera angle.
	var pin_mat := Court.material(Color("fff36a"), 0.6, 1.0)
	pin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pin_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pin_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_active_pin.material_override = pin_mat
	_active_pin.visible = false
	add_child(_active_pin)

	_build_timing_marks()

	# The drill's target, drawn from the live session (invisible in every other
	# mode: a quick match has no session and the two match modes have no target).
	_target_ring = MeshInstance3D.new()
	_target_ring.name = "TargetRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.45
	_target_ring.mesh = tm
	_target_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_target_ring.material_override = Court.material(Color(0.42, 0.98, 0.55))
	_target_ring.visible = false
	add_child(_target_ring)

	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	_hud = HudScript.new()
	_hud.name = "Hud"
	layer.add_child(_hud)
	_hud.bind_names(
		String(Config.athlete()["name"]),
		String(Config.tier()["name"]),
		player_color,
		ai_color
	)
	# The mode HUD rides in the same layer, behind the match's own panels: it is
	# the overlay that tells a drill from a tournament round from a career match,
	# and it stays invisible in a quick match (no session to bind).
	_mode_hud = ModeHudScript.new()
	_mode_hud.name = "ModeHud"
	layer.add_child(_mode_hud)
	if session != null:
		_mode_hud.bind_session(session)


## The four athletes on court, as real rigs from `src/character/athlete_spawn.gd`.
##
## The roster comes from `Lineup.resolve(Config.athlete())` (the reference's
## `resolveLineup`), the outfits from the menu's choice plus each athlete's default,
## and the tint colours are the ones the scoreboard already uses per side. The rigs
## are the athletes; the capsule bodies below are the fallback for a build whose rig
## assets could not be read, and the log line says which one this run got — the
## packaged-build defect the review found (H-1) was exactly a silent fallback to
## capsules, so it is announced, printed with the source path, and asserted.
##
## Public so a headless run can build the rigs after `harness_mode()` (which turns
## `load_models` off deliberately: no display, no texture upload) without driving the
## whole scene twice. Returns how many rigs were built.
func build_athletes() -> int:
	_lineup = Lineup.resolve(Config.athlete())
	if _athletes == null:
		_athletes = AthletesView.new()
		_athletes.name = "Athletes"
		add_child(_athletes)
	var started := Time.get_ticks_msec()
	var spawned: int = _athletes.spawn(_lineup, Lineup.outfits(_lineup, Config.outfit_id()), {
		"player": _player_color,
		"playerMate": _player_color.lightened(0.25),
		"opponent": _ai_color,
		"opponentMate": _ai_color.lightened(0.25),
	})
	var rig_ms := Time.get_ticks_msec() - started

	if spawned == 0:
		_build_capsule_fallback()
		print("ATHLETES rigs=0 fallback=capsules load_errors=%d glb=%s" % [
			int(_athletes.load_errors), Court.GLB_PATH])
	else:
		for role in AthletesView.ROLES:
			var rig: Node3D = _athletes.rig(role)
			if rig != null:
				_athlete_roots[role] = rig
				_paddle_views[role] = _athletes.rackets[role]
		print("ATHLETES rigs=%d source=%s glb_loads=%d spawn_ms=%d lineup=%s" % [
			spawned, AthleteRig.GLB_BASE, spawned * 3, rig_ms, JSON.stringify(Lineup.ids(_lineup))])
	print("MODELS rigged_glb=%s mesh_instances=%d copies=4 rigs=%d" % [
		Court.GLB_PATH, _count_meshes(self), spawned])
	return spawned


func _build_capsule_fallback() -> void:
	var base: Node = Court.load_athlete_scene()
	_athlete_roots["player"] = Court.make_athlete(self, base, "PlayerBody", _player_color)
	_athlete_roots["playerMate"] = Court.make_athlete(self, base, "PlayerMateBody", _player_color.lightened(0.25))
	_athlete_roots["opponent"] = Court.make_athlete(self, base, "OpponentBody", _ai_color)
	_athlete_roots["opponentMate"] = Court.make_athlete(self, base, "OpponentMateBody", _ai_color.lightened(0.25))
	if base != null:
		base.queue_free()
	for key in ["player", "playerMate", "opponent", "opponentMate"]:
		_paddle_views[key] = Court.make_racket_view(self, "Racket_%s" % key,
			_player_color if key.begins_with("player") else _ai_color)


## The four athletes' roots (rigs, or the capsule fallbacks) — the slice test reads
## this back by role rather than by traversal order.
func athlete_root(role: String) -> Node3D:
	return _athlete_roots.get(role, null)


## The racket of one athlete: a child of its rig since this slice, so it inherits
## the athlete's yaw. Position is local to the rig.
func racket_view(role: String) -> Node3D:
	return _paddle_views.get(role, null)


## Everything the athletes view knows about what it spawned, read off the nodes.
func athletes_report() -> Dictionary:
	if _athletes == null:
		return {"rigs": 0}
	return _athletes.describe_all()


func athlete_cost() -> Dictionary:
	if _athletes == null:
		return {"rigs": 0, "spawn_ms": 0.0, "glb_loads": 0, "load_errors": 0}
	return _athletes.cost_report()


## `create_match_state` + the two assignments the browser makes before its loop
## (`js/main.js:1144-1148`, mirrored from `scripts/parity-digest.mjs:242-243`):
## the seed is injected and the match is switched on.
func start_match() -> void:
	state = Sim.create_match_state("quick", Config.athlete(), Config.arena(), Config.tier(), 0, {})
	state.rng_state = Config.seed_value
	state.running = true
	# The saved switching mode (`js/main.js:1184`,
	# `matchState.controlMode = ui.controlMode`), validated against the reference's
	# own three values by `Config.control_mode()` (`js/main.js:2273`).
	state.controlMode = Config.control_mode()
	ticks = 0
	crossings = 0
	points_scored = 0
	max_rally = 0
	seen_events = {}
	score_history = []
	finished = false
	# The accumulator and the latch start clean: a new match does not inherit the
	# previous one's owed time or its unconsumed shots. The pause flag is part of the
	# same reset (review-2 F-3): a match that starts paused is a match that never
	# ticks while the HUD says it is running.
	_clear_pause()
	sim_accumulator = 0.0
	queued_one_shots.clear()
	queued_one_shots2.clear()
	last_frame_steps = 0
	max_frame_steps = 0
	last_tick_input = {}
	_scripted.reset()
	if _audio != null:
		_audio.reset()
	_points_total_prev = _points_total()
	meta = {
		"seed": Config.seed_value,
		"tier": String(Config.tier()["id"]),
		"camera": Config.camera_preset,
		"tick": 0,
	}
	_sync_views()
	if _hud != null:
		_hud.refresh(state, meta)


# ---------------------------------------------------------------------------
# The tick
# ---------------------------------------------------------------------------

## There is deliberately NO `_physics_process` in this file: the simulation is
## stepped from rendered frames (`apply_frame`), as the browser's RAF loop does.
## Godot's fixed physics tick is 120 Hz and its `delta` is always `1/120`, so using
## it as the accumulator's source is the H-2 defect — one simulated tick per
## rendered frame, 60 per wall second at 60 fps. `set_physics_process(false)` in
## `_ready()` keeps it off even if an editor or a future scene re-enables it.
##
## The browser's fixed-step loop (`js/main.js:1187-1205`), one rendered frame at a
## time. `delta` is the frame's own wall-clock duration.
##
##   simAccumulator = min(simAccumulator + dt, FIXED_STEP * MAX_SIM_STEPS)
##   while simAccumulator >= FIXED_STEP and steps < MAX_SIM_STEPS:
##       updateMatch(state, FIXED_STEP, input, input2)
##       if result: break
##       if steps == 1: input = consumeOneShot(input)
##
## Two clamps, both the reference's: the frame's `delta` is capped at
## `MAX_FRAME_DELTA` (0.25 s), and the accumulator is capped at
## `FIXED_STEP * MAX_SIM_STEPS` = 66.67 ms, so one frame can never justify more
## than `MAX_SIM_STEPS` sub-steps however long it took. The result is 120 simulated
## ticks per wall-clock second at any render rate at or above 15 fps, and a
## simulation that falls behind (rather than firing a burst) below it.
##
## Public, and taking `delta` as an argument, so the slice test can feed a frame
## pattern (30 fps, 240 fps, a 2-second stall) without a real clock.
func advance_frame(delta: float) -> Dictionary:
	if state == null:
		return {"steps": 0, "accumulator": sim_accumulator, "ticks": ticks}
	var dt := minf(delta, MAX_FRAME_DELTA)
	sim_accumulator = minf(sim_accumulator + dt, FIXED_STEP * float(MAX_SIM_STEPS))
	var input := _pending_input
	var input2 := _pending_input2
	var steps := 0
	while sim_accumulator >= FIXED_STEP and steps < MAX_SIM_STEPS:
		tick_fixed(FIXED_STEP, input, input2)
		sim_accumulator -= FIXED_STEP
		steps += 1
		if finished:
			break
		# The one-shots are worth one sub-step: repeating them would queue the same
		# shot twice inside one frame (`js/main.js:1204-1206`).
		if steps == 1:
			input = InputSource.consume_one_shots(input)
			input2 = InputSource.consume_one_shots(input2)
	# The sub-steps consumed the latch. A frame that justified no sub-step keeps it.
	if steps > 0:
		queued_one_shots.clear()
	last_frame_steps = steps
	max_frame_steps = maxi(max_frame_steps, steps)
	return {"steps": steps, "accumulator": sim_accumulator, "ticks": ticks}


## One rendered frame, end to end. `_process` samples the frame's input and hands
## it here with the frame's own `delta`; the slice test hands the SAME function a
## synthetic sample and delta, so there is one frame path, not a test copy of it.
##
## Returns `advance_frame`'s report, or a zero-step report when nothing ran.
func apply_frame(sample: Dictionary, delta: float) -> Dictionary:
	if state == null:
		return {"steps": 0, "accumulator": sim_accumulator, "ticks": ticks}
	if _paused:
		# A paused frame arms nothing and keeps nothing armed: the reference clears
		# its queued one-shots on both edges of a pause (`js/main.js:1532,1543` ->
		# `resetTransientInput`, `js/main.js:333-339`), and `_process` keeps calling
		# `apply_frame` while paused, so without this a sample taken during the
		# pause survived to the first sub-step after the resume (review-2 F-4).
		_reset_transient_input()
	else:
		latch_one_shots(sample)
	_frame_input = sample
	# The second player's sample: built only when a second human is on court
	# (`humanMode` is `"pvp"` or `"coop"`, set by `create_match_state`). Every other
	# mode keeps the empty dict the reference's `getInput2()` never overrides.
	if _second_human():
		_frame_input2 = _input_source2.sample(state)
		if not _paused:
			latch_one_shots2(_frame_input2)
	else:
		_frame_input2 = Sim.empty_input()
	# The frame's sample plus everything still armed: a one-shot seen on a frame
	# that justified no physics step is not overwritten, it waits — a DELIBERATE
	# DIVERGENCE from the reference, which drops it (see the latch note below).
	_pending_input = _with_queued(_frame_input)
	_pending_input2 = _with_queued2(_frame_input2)
	var result := {"steps": 0, "accumulator": sim_accumulator, "ticks": ticks}
	if not _paused:
		result = advance_frame(delta)
	if _hud != null and not finished:
		_hud.refresh(state, meta)
	if _mode_hud != null and session != null and not finished:
		_mode_hud.refresh()
	_sync_views()
	return result


func _process(delta: float) -> void:
	if state == null:
		return
	if not engine_driven:
		return
	# Which pads the two samplers read is a property of THIS frame, not of setup:
	# macOS keeps already-connected controllers in the list, so the pad in the
	# player's hands is the one somebody touches (`js/main.js:780-784`).
	_refresh_pads()
	# Sample once per rendered frame. `use_scripted_input` is the harness path;
	# the default path reads the keyboard and the pad through the InputMap.
	if use_scripted_input:
		apply_frame(_scripted.decide(state), delta)
	else:
		apply_frame(_input_source.sample(state), delta)


## `selectPrimaryGamepad` + the `pad2` lookup, once per rendered frame
## (`js/main.js:780-784`): in a local co-op/PvP match the two seats are locked to
## the pads they started on (`keepCurrent`), everywhere else the pad a button is
## pressed on takes over and the second player gets the next connected pad.
func _refresh_pads() -> void:
	var keep := state != null and (bool(state.pvp) or bool(state.coop))
	var pads: Array = InputSource.assign_devices(keep, _input_source.device, _input_source2.device)
	_input_source.set_device(int(pads[0]))
	_input_source2.set_device(int(pads[1]))


## Arms every one-shot this sample carries, without clearing the ones already
## armed. Public so the slice test can deliver a press+release edge itself.
func latch_one_shots(input: Dictionary) -> void:
	for key in ONE_SHOTS:
		var value: Variant = input.get(key, null)
		if value == null:
			continue
		if typeof(value) == TYPE_BOOL:
			if bool(value):
				queued_one_shots[key] = true
		else:
			# `switchDirection` is a dictionary and `teamTactic` a string: a
			# non-null value IS the edge, exactly as `consumeOneShot` treats them.
			queued_one_shots[key] = value


func _with_queued(input: Dictionary) -> Dictionary:
	if queued_one_shots.is_empty():
		return input
	var out := input.duplicate()
	for key in queued_one_shots:
		out[key] = queued_one_shots[key]
	return out


## The second player's latch and its armed overlay, mirroring the pair above.
func latch_one_shots2(input: Dictionary) -> void:
	for key in ONE_SHOTS:
		var value: Variant = input.get(key, null)
		if value == null:
			continue
		if typeof(value) == TYPE_BOOL:
			if bool(value):
				queued_one_shots2[key] = true
		else:
			queued_one_shots2[key] = value


func _with_queued2(input: Dictionary) -> Dictionary:
	if queued_one_shots2.is_empty():
		return input
	var out := input.duplicate()
	for key in queued_one_shots2:
		out[key] = queued_one_shots2[key]
	return out


## Whether a second human is on court. `humanMode` comes from the mode session or the
## quick-match configuration; when it is neither `pvp` nor `coop` the reference never
## consults `getInput2()` either, and the simulation gets the empty struct it already
## defaults to (`sim.gd::update_match`).
func _second_human() -> bool:
	return state != null and (bool(state.pvp) or bool(state.coop))


## Whether a one-shot is armed and unconsumed — the state the review's H-3 defect
## destroyed, kept observable for the test and the evidence dump.
func one_shot_armed(key: String) -> bool:
	return bool(queued_one_shots.get(key, false))


## The single tick entry point. The engine-driven loop and the headless harness
## both come through here, so there is exactly one code path from input to state.
func tick_fixed(dt: float, input: Dictionary, input2: Dictionary) -> Variant:
	if state == null:
		return null
	var prev_y: float = state.ball.y
	var result = null
	if session != null:
		# The mode's own step: the drill's `DrillSession.step` (which calls
		# `Sim.update_match` itself, `js/drill.js:361`) or the engine directly for
		# the two match modes. One tick, one physics path.
		session.step(dt, input, input2)
	else:
		result = Sim.update_match(state, dt, input, input2)
	ticks += 1
	# The debug line's tick, kept in step with the tick it names: it used to be
	# written once in `start_match()` and read `TICK 0` for the whole match
	# (independent review M-5).
	meta["tick"] = ticks
	last_tick_input = input
	_observe(prev_y)
	# The sounds this tick produced. `match_audio.gd` owns the whole routing
	# decision; this is the one call site, on the one tick path, so the engine-driven
	# build and the headless harness hear the same match.
	if _audio != null:
		_audio.observe(state, ticks)
	return result


func _points_total() -> int:
	if state == null:
		return 0
	return int(state.stats["pointsWon"]["player"]) + int(state.stats["pointsWon"]["ai"])


func _observe(prev_y: float) -> void:
	var net_y: float = Court.net_y()
	var ball = state.ball
	if (prev_y - net_y) * (ball.y - net_y) < 0.0:
		crossings += 1
	if int(state.rallyHits) > max_rally:
		max_rally = int(state.rallyHits)
	for id in state.events:
		var key := String(id)
		seen_events[key] = int(seen_events.get(key, 0)) + 1
	var total := _points_total()
	if total > _points_total_prev:
		_points_total_prev = total
		points_scored = total
		score_history.append({
			"tick": ticks,
			"playerScore": String(state.playerScore),
			"aiScore": String(state.aiScore),
			"points": {"player": int(state.points["player"]), "ai": int(state.points["ai"])},
			"games": {"player": int(state.games["player"]), "ai": int(state.games["ai"])},
			"sets": {"player": int(state.sets["player"]), "ai": int(state.sets["ai"])},
			"tieBreak": bool(state.tieBreak),
			"message": String(state.pointMessage),
		})
	# A mode's result reaches the save on the tick that produced it, once. The
	# drill is excluded on purpose: its `pointsToWin` is `Number.MAX_SAFE_INTEGER`
	# (`js/drill.js:97`), so an engine "result" is never the end of a drill — the
	# attempts its own module closes are, and the session ends when the player
	# leaves (`end_drill`).
	if state.result != null and not finished and _mode_runs_by_points():
		finished = true
		if session != null:
			_finish_mode()
		if _hud != null:
			_hud.refresh(state, meta)
			_hud.show_result(state)
	# The engine-driven build refreshes the HUD once per rendered frame in
	# `_process`. A harness that owns the tick loop has no rendered frames, so the
	# tick path also refreshes it — at 4 Hz during play, and always on the last
	# tick — so both clocks show the same HUD and the harness can read it back.
	if _hud != null and not engine_driven and (finished or ticks % 30 == 0):
		_hud.refresh(state, meta)
		# The same rule for the mode HUD, so a harness that owns the tick loop
		# reads the same panel a rendered frame would show.
		if _mode_hud != null and session != null and not finished and not _page_finished():
			_mode_hud.refresh()


## True when the mode's own end has been reached — a drill that the player left.
func _page_finished() -> bool:
	return session != null and session.finished


# ---------------------------------------------------------------------------
# View sync: every position comes from the live state, never a cached copy
# ---------------------------------------------------------------------------

func _sync_views() -> void:
	if state == null:
		return
	var ball = state.ball
	_ball_view.position = Court.world_pos(ball.x, ball.y, ball.z)
	var pulse: float = 1.0 + clampf(float(ball.bouncePulse), 0.0, 1.0) * 0.9
	_ball_view.scale = Vector3(pulse, pulse, pulse)
	var ring: float = float(ball.landRing)
	_land_ring.visible = ring > 0.0
	if _land_ring.visible:
		_land_ring.position = Court.world_pos(ball.x, ball.y, 0.5)
		var ring_scale: float = 1.0 + (1.0 - ring) * 4.0
		_land_ring.scale = Vector3(ring_scale, ring_scale, ring_scale)

	# Follow the actual selected athlete; display geometry never changes reach.
	if _active_ring != null:
		var active = state.active_player()
		var shown: bool = bool(state.running) and not finished and active != null
		_active_ring.visible = shown
		if _active_ring.visible:
			var ground: Vector3 = Court.world_pos(active.x, active.y, 0.0)
			ground.y = ACTIVE_RING_LIFT
			_active_ring.position = ground
			_active_ring.scale = Vector3.ONE
		if _active_pin != null:
			_active_pin.visible = shown
			if shown:
				var over: Vector3 = Court.world_pos(active.x, active.y, 0.0)
				over.y = ACTIVE_PIN_HEIGHT
				_active_pin.position = over

	# The drill's target. Drawn from the session, at the drill's own coordinates,
	# scaled to the drill's own radius (`TARGET_R`, `js/drill.js:20`) — the court's
	# metre scale is the one `Court.world_pos` already applies to every position.
	if _target_ring != null:
		var target: Dictionary = {}
		if session != null and session.mode == "drill":
			target = session.drill.target
		_target_ring.visible = bool(target.get("active", false))
		if _target_ring.visible:
			_target_ring.position = Court.world_pos(float(target.get("x", 0.0)), float(target.get("y", 0.0)), 0.6)
			var metres: float = Court.PX_TO_M * float(target.get("r", 1.0))
			_target_ring.scale = Vector3(metres, metres, 1.0)

	# The timing presentation: the ring, the words and the two bars, from the same
	# live state. Placed BEFORE the athletes' early return below, so a frame with
	# rigs (the playable build) syncs it exactly as a frame without them does.
	_sync_timing()

	# The four athletes. The rigs own their own position, facing, gait, stroke and
	# racket (`game/athletes_view.gd`); only the capsule fallback is moved here.
	if _athletes != null and _athletes.spawn_rigs > 0:
		_athletes.sync(state)
		return
	for key in ["player", "playerMate", "opponent", "opponentMate"]:
		var root: Node3D = _athlete_roots.get(key, null)
		var view: Node3D = _paddle_views.get(key, null)
		# A headless harness has no rigs at all (`load_models` off): nothing to
		# place, and reaching for a null root here used to abort this function and
		# silently skip the rest of the frame's view sync.
		if root == null or view == null:
			continue
		var paddle = state.paddle(key)
		var ground := Court.world_pos(paddle.x, paddle.y, 0.0)
		root.position = ground
		# Facing: the player's pair faces the net from +Z, the AI's from -Z.
		var base_yaw: float = 180.0 if key.begins_with("player") else 0.0
		var sway: float = sin(float(paddle.runPhase) * 0.8) * 7.0 * float(paddle.motion)
		root.rotation_degrees = Vector3(0.0, base_yaw + sway, 0.0)

		# The racket is held by the athlete: it hangs off the hand offset in METRES
		# (see `court.gd`'s HAND_* constants), not off the sim's contact box. The old
		# version offset it by `paddle.w * 0.5 + 8` px — up to 1.4 m sideways — and
		# drew it `paddle.w` wide, which is the "metre-wide bar detached from the
		# player" in the defect list. The swing moves the racket, and the sim owns
		# which side the swing is on (`paddle.swingSide`) and how far through it is.
		var towards_net: float = -1.0 if key.begins_with("player") else 1.0
		var swing: float = clampf(float(paddle.swing), 0.0, 1.0)
		var swing_side: float = -1.0 if paddle.swingSide < 0.0 else 1.0
		var racket := ground + Vector3(
			swing_side * Court.HAND_SIDE * (1.0 + swing * 0.6),
			Court.HAND_H + swing * Court.HAND_SWING_LIFT,
			towards_net * Court.HAND_FWD
		)
		view.position = racket
		view.rotation_degrees = Vector3(-18.0 - swing * 40.0, 0.0, swing_side * (18.0 + swing * 30.0))


# ---------------------------------------------------------------------------
# Timing presentation: the ring, the words, the bars
# (`js/render.js:1646-1750`, `js/render.js:1041-1069`, `js/render.js:1031-1037`)
# ---------------------------------------------------------------------------

## Every mark of the timing presentation. All of them are camera-facing, unshaded
## and drawn with the depth test OFF, because the reference draws them AFTER the
## court (`js/main.js:1919`): they lie over the athlete's own body, over the net and
## over the glass, exactly as they do on the canvas.
func _build_timing_marks() -> void:
	var opaque := Color(1.0, 1.0, 1.0, 1.0)
	# The track the coloured arc fills along: `ctx.arc(0, 0, r, 0, PI*1.85)` stroked
	# in `rgba(255,255,255,0.22)` (`js/render.js:1664-1668`).
	_timing_ring_track = _timing_mesh("TimingRingTrack",
		_timing_arc_mesh(TIMING_RING_RADIUS, TIMING_RING_WIDTH, TIMING_ARC_TRACK,
			Color(1.0, 1.0, 1.0, 0.22), false),
		_timing_material(opaque, true, 1))
	# The fill. Its mesh is rebuilt as the charge moves; it starts empty.
	_timing_ring = _timing_mesh("TimingRing", null, _timing_material(opaque, true, 2))
	# `if (inWindow)`: the green circle at `r + 5*scale`, `0.55 + 0.4*blink`
	# (`js/render.js:1679-1688`).
	_timing_window = _timing_mesh("TimingWindow",
		_timing_arc_mesh(TIMING_RING_RADIUS + TIMING_FLASH_GAP, TIMING_FLASH_WIDTH, TAU,
			Color(0.549, 1.0, 0.784, 1.0), false),
		_timing_material(Color(0.549, 1.0, 0.784, 1.0), true, 3))

	# The RT precision bar: a `46*scale x 5*scale` body at `rgba(4,14,32,0.78)` with
	# a `rgba(126,243,255,0.35)` rim, and a fill that grows from its left edge
	# (`js/render.js:1697-1717`).
	_timing_precision_track = _timing_mesh("TimingPrecisionBar", _timing_bar_mesh(false),
		_timing_material(Color(0.016, 0.055, 0.125, 0.78), true, 1))
	_timing_precision = _timing_mesh("TimingPrecisionFill", _timing_bar_mesh(true),
		_timing_material(HudScript.PRECISION_CYAN, true, 2))
	# The energy bar under the athlete's feet, with the reference's own three bands
	# (`js/render.js:1031-1037`).
	_timing_energy_track = _timing_mesh("TimingEnergyBar", _timing_bar_mesh(false),
		_timing_material(Color(0.016, 0.055, 0.125, 0.72), true, 1))
	_timing_energy = _timing_mesh("TimingEnergyFill", _timing_bar_mesh(true),
		_timing_material(HudScript.FIELD_ENERGY_TEAL, true, 2))

	# The advice word and its panel (`js/render.js:1730-1750`). The font size is the
	# reference's own 11 px and `pixel_size` is metres per REFERENCE pixel (1/60 m):
	# `font_size * pixel_size` is therefore the word's height in metres, 0.183 m, which
	# this frame's 36 px/m prints at 6.6 px — the reference's own proportion to the
	# ring's 96 px, held at any window size.
	_timing_advice = Label3D.new()
	_timing_advice.name = "TimingAdvice"
	_timing_advice.font = ThemeDB.fallback_font
	_timing_advice.font_size = TIMING_ADVICE_PX
	_timing_advice.pixel_size = TIMING_REF_M_PER_PX
	_timing_advice.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_timing_advice.no_depth_test = true
	_timing_advice.render_priority = 3
	_timing_advice.visible = false
	add_child(_timing_advice)
	_timing_advice_panel = _timing_mesh("TimingAdvicePanel", _timing_bar_mesh(false),
		_timing_material(Color(0.016, 0.055, 0.125, 0.82), true, 2))

	# The verdict over the athlete who hit (`js/render.js:1041-1069`): the grade word
	# with the reference's own 5 px dark stroke, and the mode line under it.
	_timing_verdict = _timing_verdict_label("TimingVerdict", TIMING_VERDICT_PX, 5)
	_timing_verdict_mode = _timing_verdict_label("TimingVerdictMode", TIMING_VERDICT_MODE_PX, 0)


## One of the two lines of the verdict: a camera-facing, depth-test-free label with
## the reference's dark stroke (`js/render.js:1060-1061`) at metres per REFERENCE
## pixel, so `font_size` is the reference's own px and the word is 14/60 m tall.
func _timing_verdict_label(node_name: String, font_size: int, outline: int) -> Label3D:
	var l := Label3D.new()
	l.name = node_name
	l.font = ThemeDB.fallback_font
	l.font_size = font_size
	l.pixel_size = TIMING_REF_M_PER_PX
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 4
	l.outline_size = outline
	l.outline_modulate = TIMING_VERDICT_OUTLINE
	l.modulate = Color(1.0, 1.0, 1.0, 0.9)
	l.visible = false
	add_child(l)
	return l


## A mark of the timing presentation: invisible until `_sync_timing` says otherwise,
## and never casting a shadow (a billboarded transparent quad would).
func _timing_mesh(node_name: String, mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


## The material every timing mark shares. `render_priority` is the reference's paint
## order made explicit (track under fill, body of a bar under its fill), since with
## the depth test off nothing else separates two coplanar marks.
##
## `billboard_keep_scale` is what lets a bar be a unit quad sized by its node's
## scale: without it, billboarding throws the scale away and every bar would be one
## metre wide (`BaseMaterial3D.billboard_keep_scale`).
func _timing_material(base: Color, use_vertex_color: bool, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.roughness = 0.6
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = use_vertex_color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = priority
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## One arc in the XY plane facing +Z, `sweep` radians CLOCKWISE FROM THE TOP: the
## reference's `rotate(-PI/2)` followed by `ctx.arc(..., 0, sweep)` in a canvas
## whose y axis points DOWN (`js/render.js:1663-1677`), so a point at angle `a` is
## `(sin a, cos a)` here. The ribbon is centred on `radius`, the way a canvas stroke
## of `width` is centred on its path.
##
## `gradient` colours each vertex from the reference's own four stops sampled at the
## vertex's local x projection (`js/render.js:1669-1674`).
func _timing_arc_mesh(radius: float, width: float, sweep: float, base: Color, gradient: bool) -> ArrayMesh:
	var segments: int = _timing_arc_segments(sweep)
	var inner := radius - width * 0.5
	var outer := radius + width * 0.5
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in segments:
		var a0 := sweep * float(i) / float(segments)
		var a1 := sweep * float(i + 1) / float(segments)
		var d0 := Vector2(sin(a0), cos(a0))
		var d1 := Vector2(sin(a1), cos(a1))
		var c0: Color = _timing_gradient(sin(a0)) if gradient else base
		var c1: Color = _timing_gradient(sin(a1)) if gradient else base
		verts.append(Vector3(d0.x * inner, d0.y * inner, 0.0))
		verts.append(Vector3(d0.x * outer, d0.y * outer, 0.0))
		verts.append(Vector3(d1.x * outer, d1.y * outer, 0.0))
		verts.append(Vector3(d0.x * inner, d0.y * inner, 0.0))
		verts.append(Vector3(d1.x * outer, d1.y * outer, 0.0))
		verts.append(Vector3(d1.x * inner, d1.y * inner, 0.0))
		cols.append(c0)
		cols.append(c0)
		cols.append(c1)
		cols.append(c0)
		cols.append(c1)
		cols.append(c1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## How many ribbon segments a sweep is drawn with. Public to the frame report so a
## test can assert the FILL moved without reading the mesh.
func _timing_arc_segments(sweep: float) -> int:
	return maxi(1, int(ceil(absf(sweep) / TIMING_ARC_STEP)))


## A unit quad in the XY plane facing +Z. `anchored_left` keeps x in 0..1, so the
## fill grows from the bar's left edge — `ctx.fillRect(x, y, w * value, h)`
## (`js/render.js:1716`); otherwise x is -0.5..0.5 and the node's scale is the whole
## extent, which is how the track is drawn.
func _timing_bar_mesh(anchored_left: bool) -> ArrayMesh:
	var x0 := 0.0 if anchored_left else -0.5
	var x1 := 1.0 if anchored_left else 0.5
	var corners := PackedVector3Array([
		Vector3(x0, -0.5, 0.0), Vector3(x1, -0.5, 0.0), Vector3(x1, 0.5, 0.0),
		Vector3(x0, -0.5, 0.0), Vector3(x1, 0.5, 0.0), Vector3(x0, 0.5, 0.0)])
	var cols := PackedColorArray()
	for _i in 6:
		cols.append(Color(1.0, 1.0, 1.0, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = corners
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The reference's four stops, interpolated in sRGB between the two the value falls
## between and clamped at both ends, which is what a canvas gradient does.
static func _timing_gradient(t: float) -> Color:
	var x := clampf(t, 0.0, 1.0)
	for i in range(1, TIMING_GRADIENT.size()):
		var lo: Array = TIMING_GRADIENT[i - 1]
		var hi: Array = TIMING_GRADIENT[i]
		if x <= float(hi[0]):
			var span := maxf(0.0001, float(hi[0]) - float(lo[0]))
			return (lo[1] as Color).lerp(hi[1] as Color, (x - float(lo[0])) / span)
	return TIMING_GRADIENT[TIMING_GRADIENT.size() - 1][1]


## The timing presentation, from the live state, once per frame. One place decides
## what is drawn and where; the nodes only follow, and the frame's own numbers are
## left in `_timing_state` for the tests, `_save_frame` and the evidence.
func _sync_timing() -> void:
	if _timing_ring == null:
		return
	var read: Dictionary = state.shotRead
	var active = state.active_player()
	var live: bool = bool(state.running) and not finished and active != null
	# `js/render.js:1656`: `(state.shotCharge ?? 0) > 0.05 && read?.active`.
	var charging: bool = float(state.shotCharge) > TIMING_CHARGE_FLOOR and bool(read.get("active", false))
	if _timing_muted:
		live = false
		charging = false
	# The reference's clock, for the two blinks (`js/render.js:1680`, `:1711`). The
	# simulation's own elapsed time, not the wall clock: a frame the capture writes
	# is then reproducible from its tick.
	var clock: float = float(state.elapsed)
	var ground: Vector3 = Court.world_pos(active.x, active.y, 0.0) if active != null else Vector3.ZERO
	# `read.eta` is null whenever no ball is incoming (`state.gd:56-63`), and it is the
	# only field of the read that can be: `float(null)` is a runtime error in GDScript,
	# so it is unwrapped once, here.
	var eta_raw: Variant = read.get("eta", null)
	var eta: float = float(eta_raw) if eta_raw != null else 0.0
	var precision: float = clampf(float(read.get("precision", 0.0)), 0.0, 1.0)
	var tight: float = clampf(float(read.get("tight", 0.0)), 0.0, 1.0)
	var energy: float = clampf(float(state.rallyEnergy.get("player", 1.0)), 0.0, 1.0)

	# --- the ring: `1 - read.eta / 0.55`, drawn from the top clockwise ----------
	var fraction: float = clampf(1.0 - eta / TIMING_ETA_SPAN, 0.0, 1.0)
	var in_window: bool = absf(eta) <= float(read.get("perfectWindow", 0.055))
	var ring_on: bool = live and charging
	_timing_ring_track.visible = ring_on
	_timing_ring.visible = ring_on
	if ring_on:
		var at := ground + Vector3(0.0, TIMING_RING_HEIGHT, 0.0)
		_timing_ring.position = at
		_timing_ring_track.position = at
		var segments := _timing_arc_segments(TIMING_ARC_FILL * fraction)
		if segments != _timing_fill_segments:
			_timing_fill_segments = segments
			_timing_ring.mesh = _timing_arc_mesh(TIMING_RING_RADIUS, TIMING_RING_WIDTH,
				TIMING_ARC_FILL * fraction, Color(1.0, 1.0, 1.0, 1.0), true)
	_timing_window.visible = ring_on and in_window
	if _timing_window.visible:
		_timing_window.position = ground + Vector3(0.0, TIMING_RING_HEIGHT, 0.0)
		var blink: float = 0.5 + 0.5 * sin(clock * 18.0)
		(_timing_window.material_override as StandardMaterial3D).albedo_color.a = 0.55 + 0.4 * blink

	# --- the precision bar: `charge > 0.05 && precision > 0.04` ----------------
	var prec_on: bool = live and charging and precision > TIMING_PRECISION_FLOOR
	_timing_precision_track.visible = prec_on
	_timing_precision.visible = prec_on
	if prec_on:
		var armed: bool = tight > 0.02
		var pulse: float = (0.62 + 0.38 * sin(clock * 16.0)) if armed else 1.0
		var at := ground + Vector3(0.0, TIMING_PRECISION_HEIGHT, 0.0)
		_timing_precision_track.position = at
		_timing_precision.position = at + Vector3(-TIMING_PRECISION_W * 0.5, 0.0, 0.0)
		# The reference's rim: `roundRect(x - 1, y - 1, w + 2, h + 2)`.
		_timing_precision_track.scale = Vector3(TIMING_PRECISION_W + 0.03, TIMING_PRECISION_H + 0.03, 1.0)
		_timing_precision.scale = Vector3(maxf(0.02, TIMING_PRECISION_W * precision), TIMING_PRECISION_H, 1.0)
		(_timing_precision.material_override as StandardMaterial3D).albedo_color = HudScript.precision_color(tight, pulse)

	# --- the advice word: `!serving && !(pointPause > 0)` ----------------------
	var advice_on: bool = live and not bool(state.serving) and float(state.pointPause) <= 0.0
	_timing_advice.visible = advice_on
	_timing_advice_panel.visible = advice_on
	if advice_on:
		var word: String = HudScript.advice_word(HudScript.advice_of(read))
		var color: Color = HudScript.advice_color(String(read.get("profile", "control")))
		var at := ground + Vector3(0.0, TIMING_ADVICE_HEIGHT, 0.0)
		_timing_advice.position = at
		_timing_advice.text = word
		_timing_advice.modulate = color
		# The panel is the reference's `measureText(label).width + 22` by 20 px box
		# (`js/render.js:1735-1742`) measured with the same font the label draws with,
		# in the reference's own px at the reference's own 1/60 m per px: one line of
		# padding either side (22/11) in a box 20/11 lines tall. Placed just behind
		# the text.
		var line_m: float = float(TIMING_ADVICE_PX) * TIMING_REF_M_PER_PX
		var text_px: float = 0.0
		if _timing_advice.font != null:
			text_px = _timing_advice.font.get_string_size(
				word, HORIZONTAL_ALIGNMENT_LEFT, -1, TIMING_ADVICE_PX).x
		_timing_advice_panel.position = Vector3(at.x, at.y, at.z - 0.01)
		# Never narrower than one box line tall (the previous floor was a fixed 0.30 m,
		# which is a size at the DELIVERED scale, not a proportion).
		_timing_advice_panel.scale = Vector3(
			maxf(line_m * TIMING_ADVICE_BOX_LINES,
				text_px * TIMING_REF_M_PER_PX + line_m * TIMING_ADVICE_PAD_LINES),
			line_m * TIMING_ADVICE_BOX_LINES, 1.0)

	# --- the energy bar: every frame, under the active athlete ----------------
	_timing_energy_track.visible = live
	_timing_energy.visible = live
	if live:
		var at := ground + Vector3(0.0, TIMING_ENERGY_HEIGHT, TIMING_FOOT_FORWARD)
		_timing_energy_track.position = at
		_timing_energy.position = at + Vector3(-TIMING_ENERGY_W * 0.5, 0.0, 0.0)
		# `fillRect(energyX - scale, energyY - scale, energyWidth + 2*scale, 4*scale)`
		# over a `2*scale` fill: the track is twice the fill's height.
		_timing_energy_track.scale = Vector3(TIMING_ENERGY_W + 0.04, TIMING_ENERGY_H * 2.0, 1.0)
		_timing_energy.scale = Vector3(maxf(0.02, TIMING_ENERGY_W * energy), TIMING_ENERGY_H, 1.0)
		(_timing_energy.material_override as StandardMaterial3D).albedo_color = HudScript.field_energy_color(energy)

	# --- the verdict over the athlete who hit ---------------------------------
	var report_verdict := _sync_verdict(live, ground)

	_timing_state = {
		"charge": float(state.shotCharge),
		"charging": charging,
		"eta": eta,
		"fraction": fraction,
		"in_window": in_window,
		"ring_visible": ring_on,
		"fill_segments": _timing_fill_segments if ring_on else 0,
		"fill_radius": TIMING_RING_RADIUS,
		# The ring's own anchor height: `p.y - 96*scale` in the reference
		# (`js/render.js:1657`), i.e. the 96 px the advice's 11 px is a proportion of.
		"ring_height": TIMING_RING_HEIGHT,
		"prec_visible": prec_on,
		"precision": precision,
		"tight": tight,
		"prec_width": TIMING_PRECISION_W * precision if prec_on else 0.0,
		"advice_visible": advice_on,
		"advice": _timing_advice.text if advice_on else "",
		"advice_color": _timing_advice.modulate.to_html(false) if advice_on else "",
		"advice_panel_w": _timing_advice_panel.scale.x if advice_on else 0.0,
		"advice_h_m": TIMING_ADVICE_PX * TIMING_REF_M_PER_PX if advice_on else 0.0,
		"labels_px": _timing_labels_px(),
		"energy_visible": live,
		"energy": energy,
		"energy_width": TIMING_ENERGY_W * energy if live else 0.0,
		"verdict_visible": report_verdict["visible"],
		"verdict": report_verdict["word"],
		"verdict_mode": report_verdict["mode"],
		"verdict_grade": report_verdict["grade"],
		"verdict_color": report_verdict["color"],
		"verdict_alpha": report_verdict["alpha"],
		"verdict_paddle": report_verdict["paddle"],
		"verdict_at": report_verdict["at"],
	}


## The verdict over the athlete who hit (`js/render.js:1041-1069`): `PERFETTO`,
## `BUONO`, `ANTICIPATO`, `RITARDATO` at the paddle the simulation says hit
## (`state.shotFeedback.paddleKey`), in the reference's own four colours and fading
## with `life / 0.28`. Returns what it drew.
func _sync_verdict(live: bool, _ground: Vector3) -> Dictionary:
	var out := {
		"visible": false, "word": "", "mode": "", "grade": "", "color": "",
		"alpha": 0.0, "paddle": "", "at": Vector3.ZERO,
	}
	var feedback: Variant = state.shotFeedback
	_timing_verdict.visible = false
	_timing_verdict_mode.visible = false
	if not live or feedback == null:
		return out
	var life: float = float(feedback.get("life", 0.0))
	if life <= 0.0:
		return out
	var key := String(feedback.get("paddleKey", ""))
	var paddle = state.paddle(key) if key != "" else null
	if paddle == null:
		return out
	var grade := String(feedback.get("grade", ""))
	var word: String = HudScript.feedback_label(String(feedback.get("text", "")))
	var mode: String = HudScript.mode_label(String(feedback.get("mode", "")))
	var color: Color = HudScript.field_grade_color(grade)
	# `alpha = clamp(feedback.life / 0.28, 0, 1)` (`js/render.js:1047`).
	var alpha: float = clampf(life / TIMING_VERDICT_FADE, 0.0, 1.0)
	# `y = p.y - 105*scale - (0.78 - life) * 18` (`js/render.js:1062`): the word rides
	# up as it fades, and it is anchored to the athlete who HIT, not to the one under
	# control.
	var feet: Vector3 = Court.world_pos(paddle.x, paddle.y, 0.0)
	var lift: float = (TIMING_VERDICT_LIFE - life) * (TIMING_VERDICT_DRIFT / TIMING_VERDICT_LIFE)
	var at := feet + Vector3(0.0, TIMING_VERDICT_HEIGHT + lift, 0.0)
	_timing_verdict.position = at
	_timing_verdict.text = word
	_timing_verdict.modulate = Color(color.r, color.g, color.b, alpha)
	_timing_verdict.visible = true
	_timing_verdict_mode.position = at + Vector3(0.0, -TIMING_VERDICT_MODE_DROP, 0.0)
	_timing_verdict_mode.text = mode
	_timing_verdict_mode.modulate = Color(1.0, 1.0, 1.0, 0.9 * alpha)
	_timing_verdict_mode.visible = true
	return {
		"visible": true, "word": word, "mode": mode, "grade": grade,
		"color": color.to_html(false), "alpha": alpha, "paddle": key, "at": at,
	}


## What the last sync drew: the ring's fill, the two bars' widths, the advice word
## and the verdict, as the frame computed them. The tests and the evidence read this
## rather than re-deriving the reference's arithmetic.
func timing_report() -> Dictionary:
	return _timing_state.duplicate()


## The three texts' on-screen height in the LIVE frame's own pixels: each word's world
## height (`font_size * pixel_size`) unprojected through the current camera at its own
## position — a measurement, not the arithmetic restated. This is the number the slice
## test's proportion check and the capture's marker line print, and the PNG
## measurements in the evidence are taken again from the written frame.
func _timing_labels_px() -> Dictionary:
	var out := {"advice": 0.0, "verdict": 0.0, "mode": 0.0}
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return out
	var pairs := {
		"advice": _timing_advice,
		"verdict": _timing_verdict,
		"mode": _timing_verdict_mode,
	}
	for key in pairs.keys():
		var l: Label3D = pairs[key]
		if l == null or not l.visible or l.text == "":
			continue
		var h: float = float(l.font_size) * l.pixel_size
		var at: Vector3 = l.global_position
		var top: Vector2 = cam.unproject_position(at + Vector3(0.0, h, 0.0))
		var base: Vector2 = cam.unproject_position(at)
		out[key] = absf(top.y - base.y)
	return out


# ---------------------------------------------------------------------------
# Capture harness: same scene, same controller, driven by a fixed tick budget
# ---------------------------------------------------------------------------

func _capture_plan() -> Array:
	return [
		{"file": "quickmatch-serve.png", "max_ticks": 600, "batch": 20, "got": false,
			"when": func(s): return (not s.serving) and s.ball.y < Court.net_y() - 20.0},
		{"file": "rally.png", "max_ticks": 4000, "batch": 20, "got": false,
			"when": func(s): return int(s.rallyHits) >= 3 and s.ball.z < 140.0},
		# The timing presentation, while a shot is charging (slice S14c): the ring the
		# charge fills, the advice word, the precision bar and the energy bar under the
		# athlete are all on screen on this frame. `ab` writes the SAME frame with the
		# timing marks switched off — the attribution the evidence needs, since a mark
		# that survives the switch-off is not this lane's.
		{"file": "timing.png", "ab": "timing-off.png", "max_ticks": 2400, "batch": 20, "got": false,
			"when": func(s): return float(s.shotCharge) > 0.5 and bool(s.shotRead.get("active", false))},
		{"file": "hud.png", "ab": "hud-off.png", "max_ticks": 6000, "batch": 20, "got": false,
			"when": func(s): return s.shotFeedback != null},
		# The last shot needs the whole match to finish. Ticking in batches of
		# thousands keeps the number of SOFTWARE-rendered frames small: the batch
		# size changes how many ticks happen between two drawn frames, never the
		# tick size, and every tick still gets its own scripted input.
		{"file": "result.png", "max_ticks": 400000, "batch": 4000, "got": false,
			"when": func(s): return s.result != null},
	]


func _run_capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out_dir := "res://game/out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var deadline_ticks := 0
	for shot in _capture_shots:
		deadline_ticks += int(shot["max_ticks"])
	while _capture_index < _capture_shots.size() and ticks < deadline_ticks:
		var current_shot: Dictionary = _capture_shots[_capture_index]
		var batch: int = int(current_shot["batch"])
		for _i in batch:
			if _capture_index >= _capture_shots.size():
				break
			var shot: Dictionary = _capture_shots[_capture_index]
			var input := _scripted.decide(state)
			tick_fixed(FIXED_STEP, input, Sim.empty_input())
			var hit: bool = bool(shot["when"].call(state))
			if hit or ticks >= _shot_deadline(_capture_index):
				_hud.refresh(state, meta)
				_sync_views()
				await _save_frame("%s/%s" % [out_dir, String(shot["file"])])
				print("CAPTURE_SHOT name=%s tick=%d points=%d crossings=%d rally=%d" % [
					String(shot["file"]), ticks, points_scored, crossings, max_rally,
				])
				# The A/B: the same tick, the same camera, the same frame, with the
				# timing marks switched off. What survives the switch-off is not
				# theirs — the measurement `evidence/active-player-marker.md` made,
				# kept in the harness so the number can be reproduced.
				var ab := String(shot.get("ab", ""))
				if ab != "":
					_timing_muted = true
					_sync_timing()
					await _save_frame("%s/%s" % [out_dir, ab])
					_timing_muted = false
					_sync_timing()
					print("CAPTURE_AB file=%s timing_hidden=true tick=%d" % [ab, ticks])
				_capture_index += 1
		_hud.refresh(state, meta)
		_sync_views()
		await get_tree().process_frame
	print("CAPTURE_DONE shots=%d ticks=%d result=%s score=%s-%s points=%d" % [
		_capture_index, ticks, str(state.result), String(state.playerScore), String(state.aiScore), points_scored,
	])
	get_tree().quit(0)


## One frame per arena, written to `res://game/out/arena-<id>.png`.
##
## Same scene, same controller, same camera preset, same tick: the only thing that
## changes between two frames is the arena — its environment, its court dressing,
## its backdrop and its scenery — plus the arena's own frozen values in the
## simulation state. Deliberately ONE engine run for all nine: this host allows a
## single Godot process at a time and each software-rendered start-up is expensive.
func _run_arena_capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out_dir := "res://game/out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var want := Arena.ids()
	var written := 0
	for id in want:
		if not set_arena(String(id)):
			push_error("arena capture: could not build arena '%s'" % id)
			continue
		_sync_views()
		if _hud != null:
			_hud.refresh(state, meta)
		await _save_frame("%s/arena-%s.png" % [out_dir, id])
		var scenery: Node = _arena_root.get_node_or_null("Scenery") if _arena_root != null else null
		print("ARENA_CAPTURE id=%s family=%s wallBounce=%.2f rear_alpha=%.3f meshes=%d scenery=%d artwork=%s" % [
			id,
			String(_arena_root.get_meta("family")) if _arena_root != null else "?",
			float(Config.arena()["wallBounce"]),
			Arena.rear_alpha(String(id)),
			arena_mesh_count(),
			(scenery.get_child_count() if scenery != null else -1),
			str(scenery.get_meta("artwork") if scenery != null else false),
		])
		written += 1
	print("ARENA_CAPTURE_DONE arenas=%d expected=%d" % [written, want.size()])
	get_tree().quit(0 if written == want.size() else 1)


func _shot_deadline(index: int) -> int:
	var total := 0
	for i in index + 1:
		total += int(_capture_shots[i]["max_ticks"])
	return total


## Where a world point lands in the frame, or (-1, -1) when there is no camera. Used
## by `_save_frame`'s marker lines, which are what make a capture readable.
func _screen_px(cam: Camera3D, at: Vector3) -> Vector2:
	return cam.unproject_position(at) if cam != null else Vector2(-1.0, -1.0)


## One frame per mode, written to `res://game/out/mode-<mode>.png`.
##
## Same scene, same controller, same tick path as a played match: each mode is
## resolved by `game/mode_session.gd`, the arena is swapped to the mode's own
## fixture, and the session is stepped with the SAME scripted input the quick-match
## captures use until its HUD has something to show (a live drill attempt with a
## placed target, a tournament round, a career match). The mode HUD is on screen in
## every frame, which is the point of the exercise.
func _run_mode_capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out_dir := "res://game/out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var want: Array = ["drill", "tournament", "career"]
	var written := 0
	for mode in want:
		Config.pending_mode = String(mode)
		session = null
		_start_mode_session()
		if session == null:
			print("MODE_CAPTURE_SKIP mode=%s reason=%s" % [mode, ModeSession.refusal(String(mode))])
			continue
		_swap_arena(String(session.arena.get("id", "")))
		_adopt_session()
		# A bounded batch of real ticks through the SAME tick path a played frame
		# uses, until the HUD has live numbers on it. The budget is per mode and the
		# loop stops on the first satisfied frame: a drill attempt is closed and a
		# target placed within a few hundred ticks, a match score line is immediate.
		var budget := 900 if session.mode == "drill" else 120
		if session.mode == "drill":
			# The drill's `ready` gate: without one press the session never starts a
			# round and the render would show `fase ready` with no target on it.
			tick_fixed(FIXED_STEP, {"hit": true}, Sim.empty_input())
		for _i in budget:
			var input := _scripted.decide(state)
			tick_fixed(FIXED_STEP, input, Sim.empty_input())
			if session.mode == "drill" and bool(session.drill.target.get("active", false)) and int(session.drill.attempts) > 0:
				break
		if _hud != null:
			_hud.refresh(state, meta)
		if _mode_hud != null:
			_mode_hud.refresh()
		_sync_views()
		await _save_frame("%s/mode-%s.png" % [out_dir, String(mode)])
		print("MODE_CAPTURE mode=%s tick=%d arena=%s hud=%s" % [
			mode, ticks, String(session.arena.get("id", "")),
			JSON.stringify((_mode_hud.report() if _mode_hud != null else {})),
		])
		written += 1
	print("MODE_CAPTURE_DONE modes=%d expected=%d" % [written, want.size()])
	get_tree().quit(0 if written == want.size() else 1)


func _save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("capture: viewport texture null")
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("capture: viewport image null")
		return
	# Where the controlled athlete's markers are, in the frame about to be written.
	# This line is here to stay: a capture is evidence, and a reader who cannot find
	# the mark in the PNG cannot tell "not drawn" from "drawn somewhere else" — which
	# is exactly the mistake a whole afternoon went into, measuring the wrong pixels.
	if _active_ring != null and _active_pin != null:
		var cam := get_viewport().get_camera_3d()
		var ring_px: Vector2 = cam.unproject_position(_active_ring.global_position) if cam != null else Vector2(-1, -1)
		var pin_px: Vector2 = cam.unproject_position(_active_pin.global_position) if cam != null else Vector2(-1, -1)
		print("CAPTURE_MARKER zone=(%.0f,%.0f) pin=(%.0f,%.0f) zone_visible=%s pin_visible=%s" % [
			ring_px.x, ring_px.y, pin_px.x, pin_px.y,
			str(_active_ring.visible), str(_active_pin.visible)])
	# The timing marks' own coordinates, and what the frame drew of them: a reader who
	# cannot find the ring in the PNG cannot tell "not drawn" from "drawn somewhere
	# else", which is the mistake the marker line above exists to prevent.
	if _timing_ring != null:
		var tcam := get_viewport().get_camera_3d()
		var ring_at := _screen_px(tcam, _timing_ring.global_position)
		var advice_at := _screen_px(tcam, _timing_advice.global_position)
		var verdict_at := _screen_px(tcam, _timing_verdict.global_position)
		var energy_at := _screen_px(tcam, _timing_energy.global_position)
		var labels: Dictionary = _timing_state.get("labels_px", {})
		print("CAPTURE_TIMING ring=(%.0f,%.0f) advice=(%.0f,%.0f) verdict=(%.0f,%.0f) energy=(%.0f,%.0f) ring_visible=%s advice_visible=%s verdict_visible=%s fill=%.3f segments=%d radius_m=%.3f energy=%.3f advice_w_m=%.3f advice_h_m=%.3f labels_px=advice:%.1f,verdict:%.1f,mode:%.1f" % [
			ring_at.x, ring_at.y, advice_at.x, advice_at.y, verdict_at.x, verdict_at.y,
			energy_at.x, energy_at.y,
			str(_timing_ring.visible), str(_timing_advice.visible), str(_timing_verdict.visible),
			float(_timing_state.get("fraction", 0.0)), int(_timing_state.get("fill_segments", 0)),
			TIMING_RING_RADIUS, float(_timing_state.get("energy", 0.0)),
			float(_timing_state.get("advice_panel_w", 0.0)),
			float(_timing_state.get("advice_h_m", 0.0)),
			float(labels.get("advice", 0.0)), float(labels.get("verdict", 0.0)), float(labels.get("mode", 0.0))])
		print("CAPTURE_VERDICT word=%s mode=%s grade=%s paddle=%s alpha=%.3f charge=%.3f eta=%.3f in_window=%s precision=%.3f" % [
			String(_timing_state.get("verdict", "")), String(_timing_state.get("verdict_mode", "")),
			String(_timing_state.get("verdict_grade", "")), String(_timing_state.get("verdict_paddle", "")),
			float(_timing_state.get("verdict_alpha", 0.0)), float(_timing_state.get("charge", 0.0)),
			float(_timing_state.get("eta", 0.0)), str(bool(_timing_state.get("in_window", false))),
			float(_timing_state.get("precision", 0.0))])
	var err := img.save_png(path)
	print("CAPTURE_SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])


# ---------------------------------------------------------------------------
# Player-facing controls that are not the game's input struct
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event.is_action_pressed("padel_pause"):
		# A live drill ends here, exactly as the browser's drill screen leaves
		# through a key: `end_drill` closes the session with the reference's own
		# grading and persists the record (improvement only).
		if session != null and session.mode == "drill" and not finished:
			end_drill()
		# Finished: escape leaves the match. In play: escape pauses.
		elif finished:
			_leave_match()
		else:
			_paused = not _paused
			# `pauseGame` AND `resumeGame` both call `resetTransientInput()`
			# (`js/main.js:1532,1543`) — a one-shot sampled while the game is
			# paused must not land on the first sub-step after the resume
			# (review-2 F-4). Both edges, as the reference does.
			_reset_transient_input()
			if _hud != null:
				_hud.set_paused(_paused)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu_quit"):
		_leave_match()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_R and (event as InputEventKey).pressed:
		# `r` is the browser's replay key (`js/main.js:2532`); there is no replay in
		# this slice, so it restarts the match instead.
		rematch()
		get_viewport().set_input_as_handled()


## Harness entry point: no engine clock, no GLB, no display work. The caller owns
## the tick loop and calls `tick_fixed()` itself.
func harness_mode() -> void:
	engine_driven = false
	load_models = false
	set_process(false)
	set_physics_process(false)


func rematch() -> void:
	if session != null:
		# A mode replays through its own resolution: for a tournament round that
		# has just been won, `tournament_round` has already advanced, so the replay
		# is the NEXT fixture — which is what a bracket does.
		Config.pending_mode = session.mode
		session = null
		_start_mode_session()
		if session != null:
			state = null
			_adopt_session()
		else:
			start_match()
	else:
		start_match()
	_clear_pause()


## The pause state, readable: the HUD hint and the accumulator gate are two
## renderings of one flag and a test must be able to read it (review-2 F-3).
func is_paused() -> bool:
	return _paused


## A reset is not a pause. `rematch()` — the `r` key (`_unhandled_input`) — rebuilds
## the match through `start_match()`/`_adopt_session()`, and neither of those used
## to touch `_paused`: ESC then R left `_paused == true` with the HUD hint switched
## back to the unpaused text, so the match was frozen for good while the screen said
## it was running (review-2 F-3). Every reset path comes through here.
func _clear_pause() -> void:
	_paused = false
	if _hud != null:
		_hud.set_paused(false)


## `resetTransientInput` (`js/main.js:333-339`): drop every queued one-shot without
## firing it. The reference calls it on both edges of a pause, and this is the same
## rule the reset paths already apply (`start_match`/`_adopt_session` clear the same
## dictionary).
func _reset_transient_input() -> void:
	queued_one_shots.clear()
	queued_one_shots2.clear()


func to_menu() -> void:
	get_tree().change_scene_to_file("res://game/Main.tscn")


## The road back from a mode match: the mode's own screen, so the player sees the
## advanced bracket or the season state they just changed.
func to_mode_screen() -> void:
	get_tree().change_scene_to_file("res://game/ModeScreen.tscn")


func _leave_match() -> void:
	if session != null:
		to_mode_screen()
	else:
		to_menu()


## A compact, machine-readable summary of everything the harness asserts on.
func summary() -> Dictionary:
	return {
		"ticks": ticks,
		"crossings": crossings,
		"points_scored": points_scored,
		"max_rally": max_rally,
		"arena": Config.arena_id(),
		"camera": Config.camera_preset,
		"arena_meshes": arena_mesh_count(),
		"result": str(state.result),
		"player_score": String(state.playerScore),
		"ai_score": String(state.aiScore),
		"games": {"player": int(state.games["player"]), "ai": int(state.games["ai"])},
		"sets": {"player": int(state.sets["player"]), "ai": int(state.sets["ai"])},
		"events": seen_events.duplicate(),
		"score_history": score_history.duplicate(),
		"audio": (_audio.summary() if _audio != null else {}),
		# The fixed-step loop's own numbers: owed time, the last frame's tick count
		# and the largest one seen, so a run can state how far from the clamp it is.
		"sim_accumulator": sim_accumulator,
		"last_frame_steps": last_frame_steps,
		"max_frame_steps": max_frame_steps,
		"athletes": athletes_report(),
		"athlete_cost": athlete_cost(),
		"lineup": Lineup.ids(_lineup) if not _lineup.is_empty() else {},
		# The mode this run played, when it played one: what the mode HUD drew and
		# what the session awarded. Empty in a quick match, which has neither.
		"mode": session.mode if session != null else "",
		"mode_hud": (_mode_hud.report() if _mode_hud != null and session != null else {}),
		"mode_awarded": session.awarded if session != null else {},
	}
