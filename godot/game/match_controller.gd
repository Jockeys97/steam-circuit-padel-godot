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
## UIR-27, the recorded point played back (`js/main.js:138-140`, `:1243-1245`,
## `:1308-1395`). The record is the simulation's (`src/sim/sim.gd`: one frame per
## tick, bounded at `state.replayMax`); this file owns the playback. `r` in play
## toggles `start_replay()`/`stop_replay()`, ESC stops a replay before it can pause
## (`js/main.js:2606-2626`), and a replay frame runs `_replay_frame()` instead of the
## accumulator: the cursor advances one stored frame per `1/60` s of rendered-frame
## delta, clamped at the last frame, `replay_finished` fires once on the step that
## reaches it, and the frame is applied to the live state, drawn through the same
## `_sync_views()` a live frame uses, and restored (`js/main.js:1319-1360`) — the
## simulation is byte-identical after a playback. DIVERGENCE, per UIR-27 line 61:
## `stop_replay()` RESTORES the pause the entry recorded, where the reference's
## `toggleReplay` clears it on both edges.
## Headless: the same scene and the same controller run without a display. The
## athletes are real rigs (`game/athletes_view.gd`); when their GLBs cannot be read
## the controller falls back to capsule bodies and says so in its own log line, and
## `engine_driven` can be switched off so a harness drives the ticks itself through
## the public `tick_fixed()` — one code path, two clocks.
extends Node3D

## UIR-27: once, on the step that first reaches the last stored frame
## (`js/main.js:1313-1319`).
signal replay_finished

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
## The reference's three human modes (`js/main.js:1156`, prefs validated at
## `js/main.js:830`-era load): `solo` is one human on court, `coop` and `pvp` are two.
const HUMAN_MODES := ["solo", "coop", "pvp"]
const Court := preload("res://game/court.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const InputSource := preload("res://game/input_map.gd")
## The ported column is built ONLY when a run asks for it explicitly — `ui_legacy`
## set before the tree, or `--ui=legacy` (architecture-deepening gate 4: the mount
## is a UI-mode question, never a clock question, so a harness-driven match mounts
## the shipping recreated UI too). It is NOT the vocabulary any more (gate 1): the
## words and colours the court marks draw with are
## `godot/game/feedback_vocabulary.gd`'s, read by the court timing module below,
## which is this shell's only vocabulary consumer (gate 3).
const HudScript := preload("res://game/hud.gd")
## The one owner of the court timing presentation (architecture-deepening gate 3): the
## ring the charge fills, the perfect-window circle, the advice word and its panel, the
## two bars, the verdict over the athlete who hit — and their report. The shell creates
## it, mounts it on itself and calls it once a frame.
const CourtTiming := preload("res://game/court_timing_marks.gd")
## UIR-09's prototype overlay: the recreated HUD (`godot/src/ui/Hud.tscn`), mounted in
## the same layer the ported column uses and fed the same state+meta. The default
## since UIR-22, and since gate 4 the only mount whose construction does not depend
## on the clock.
const Config := preload("res://game/match_config.gd")
const MusicSettings := preload("res://src/audio/music_settings.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MatchAudioScript := preload("res://game/match_audio.gd")
const AthletesView := preload("res://game/athletes_view.gd")
const MatchLog := preload("res://game/match_log.gd")
## Glass-aware bounce play for the AI back player (`src/sim/ai_glass.gd`). On in the
## game for the owner's second play test (2026-09-23). The first version, tried the
## same day, made the AI weaker and pulled it off the net; this one takes the ball
## near the top of its post-bounce arc, never gambles a reachable ball on the glass,
## and keeps the partner at the net. Measured against the switch off, levels 1-3:
## back-court volleys 63-97% -> 36-47%, shot pace within 5%, time at the net
## unchanged or up. The simulation's own default stays off, so the golden matches
## (`tools/parity-godot/run-golden.sh`) do not move. docs/agent-work/ai-bounce/.
## Set false to go back to the recorded behaviour.
## OFF again after the owner's second play test (same day): "much weaker than before,
## at Leggenda it used to be far stronger; it almost never comes to the net". The
## scripted-player measurement had said "as strong, as much at the net": it does not
## represent a human opponent, so it cannot be the judge of this change.
## ON again 2026-09-25, owner's call after three play tests with it on against
## Leggenda (7-20, 9-24 points; before the wall-exit timing fix 0-3 per match): the
## wall-exit fix removed what made its glass play weak (the AI's own post-glass
## contacts were graded as "passed").
const AI_GLASS_PLAY := true
## The owner's play-test recorder (`game/match_log.gd`): null unless the game was
## launched with PADEL_MATCH_LOG=1. Launching with PADEL_AI_GLASS=1 / =0 overrides
## AI_GLASS_PLAY for that session, so both AIs can be tried without editing code.
var _match_log = null
const Lineup := preload("res://game/lineup.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const AthleteRig := preload("res://src/character/athlete_rig.gd")
const ModeSession := preload("res://game/mode_session.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
## The Emporio OST's economy service: the completion reward is awarded through it at
## the end-of-match boundary (see `_award_economy`).
const Economy := preload("res://src/economy/economy_service.gd")
const Gate := preload("res://game/content_gate.gd")
const ModeHudScript := preload("res://game/mode_hud.gd")
## UIR-22: the card's range rows are read through the shared component's own accessors
## (`focus_node`), never through a node-path guess.
const SettingsRows := preload("res://src/ui/components/SettingsRows.gd")
## UIR-22: the pause card's controls run on the same verified navigation model as
## every menu screen (`game/menu_focus.gd` over `src/input/**`), not on Godot's
## built-in `ui_*` walk.
const MenuFocus := preload("res://game/menu_focus.gd")
## How many frames the card's rows are re-measured for after they are built (see
## `_rebuild_pause_focus`). Two, because a container sorts on the frame after it
## becomes visible and a second pass costs nothing while the match is paused.
const PAUSE_MEASURE_FRAMES := 2

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

## The summary's grace before a pad/keyboard action is accepted (`_tick_training_summary`):
## long enough that the shot which ended the run cannot also press Retry, short enough that
## the player does not feel the pause.
const TRAINING_SUMMARY_GRACE := 0.35
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
# The timing presentation is its own module (architecture-deepening gate 3)
# ---------------------------------------------------------------------------
# The ring the charge fills, the green circle of a met perfect window, the advice
# word and its panel, the RT precision bar, the energy bar under the active athlete
# and the verdict over the athlete who hit -- with every constant, the reference
# anchors and the frame measurements that forced them -- are
# `godot/game/court_timing_marks.gd`'s (`js/render.js:1646-1750`, `:1031-1037`,
# `:1041-1069`). This shell creates that module in `_build_scene`, mounts it on
# itself, calls its one `update` from `_sync_views`, forwards its report
# (`timing_report`) and prints its capture lines. No mark, no geometry and no
# verdict arithmetic lives here any more.

# ---------------------------------------------------------------------------
# UIR-27: the playback constants (`js/main.js:138-140`)
# ---------------------------------------------------------------------------

## One stored frame per `1/60` s of rendered-frame delta (`stepReplay`,
## `js/main.js:1312-1319`).
const REPLAY_STEP := 1.0 / 60.0
## The reference's own snapshot field sets (`js/game.js:1304-1306`), read back here as
## the names a frame is applied onto the live entities with: four paddles, the ball,
## and the three state keys the draw reads.
const REPLAY_PAD_KEYS := ["player", "playerMate", "opponent", "opponentMate"]
const REPLAY_PAD_FIELDS := ["x", "y", "swing", "swingSide", "motion", "charge",
	"runPhase", "actionPose", "actionIntent", "moveRatio", "staminaEnergy"]
const REPLAY_BALL_FIELDS := ["x", "y", "z", "vx", "vy", "vz", "spin", "topspin",
	"backspin", "shotType", "serveInFlight", "serveTouchedNet", "bouncePulse",
	"landRing", "hitFlash", "hitPulse", "trail"]
const REPLAY_STATE_KEYS := ["serveSide", "serveCourt", "activePlayerKey"]

var state
var ticks: int = 0
var crossings: int = 0
var points_scored: int = 0
var max_rally: int = 0
var seen_events: Dictionary = {}
var score_history: Array = []
var meta: Dictionary = {}
var finished: bool = false
## Quick matches do not own a ModeSession. Their outfit award is cached here on
## the result edge so repeated payload/render calls cannot increment athleteWins.
var _quick_outfit_award: Dictionary = {}
## Emporio OST: this match's own award id and the award it produced. The id is
## generated once per match (never from the simulation's RNG) and is the receipt key,
## so the reward is paid once across a repeated finish, a re-opened result screen and
## a restart. A rematch is a new scene and therefore a new id.
var _economy_match_id: String = ""
var _economy_award: Dictionary = {}
## Off for a fixture that plays a match it must not be paid for (a probe/dry run). The
## shipped game never clears it; the eligibility rule is in `Economy.award_eligible`.
var economy_award_enabled: bool = true

## The playable mode session this scene is running, or null for a quick match.
## `Config.pending_mode` decides which: a mode entry on the menu sets it, and the
## session in turn resolves the arena, the rival pair and the AI profile through
## `godot/src/modes/**` and persists the result through `ModesSave`. A quick match
## leaves it null and this file behaves exactly as it did before modes existed —
## which is what keeps the frame-clock and parity checks their own subject.
var session = null

## Off for the headless harness, which calls `tick_fixed()` itself. THE CLOCK ONLY:
## whether this scene steps its own frames. It has no say in which UI is mounted —
## that is `_ui_new`'s question (architecture-deepening gate 4), so a harness that
## owns the clock still gets the shipping recreated UI.
var engine_driven: bool = true
## The explicit ported-column request, set before `_ready()` — the match's half of
## the switch `main_menu.gd:87` documents (`--ui=legacy` is the same request from
## the command line). Nothing in the shipped game sets it: the recreated UI is the
## shipping path, and the ported column is the diagnostic fallback the legacy
## sections of `tests/game_slice_test.gd` still assert.
var ui_legacy := false
## Off when there is no display (or when a harness asks): the rigs are not spawned.
var load_models: bool = true
var use_scripted_input: bool = false

## The browser's accumulator (`js/main.js:1187-1205`). Simulated time owed, in
## seconds, never above `FIXED_STEP * MAX_SIM_STEPS` and never negative.
var sim_accumulator: float = 0.0
## The game-pace preset's dt multiplier (`src/sim/pace.gd`), read once when a match
## or a mode session starts. This is the ONE place the pace setting enters the
## simulation: `advance_frame` is the only clock that turns real frame time into
## simulated time, for a quick match and for a mode session alike (a mode's own
## `step` is called from `tick_fixed` with a whole `FIXED_STEP`, so scaling there
## too would apply the factor twice). The default preset's factor is 1.0, which is
## why an untouched profile runs the arithmetic it always ran.
var pace_factor: float = 1.0

# ---------------------------------------------------------------------------
# In-match UI visibility (docs/agent-work/ui-visibility-settings/PLAN.md)
#
# One per-match profile over the six component ids below, plus the memory of the
# last profile that was NOT fully clean, so the clean-view gesture restores what
# the player had rather than forcing `all`. Presentation only: nothing here is
# persisted, nothing here touches the simulation, and a new match resets to `all`.
# ---------------------------------------------------------------------------

## The six stable component ids, in the contract's own order. `src/ui/Hud.gd`
## mirrors this list (`Hud.COMPONENT_IDS`) and `tests/ui/ui_visibility_audit.gd`
## asserts the two are equal, so the HUD cannot drift from the owner.
const UI_COMPONENTS := ["score", "time", "map", "guidance", "indicators", "events", "preparation"]

## The four presets, as exact maps over `UI_COMPONENTS`.
const UI_PRESET_MAPS := {
	"all": {
		"score": true, "time": true, "map": true,
		"guidance": true, "indicators": true, "events": true, "preparation": true,
	},
	"essential": {
		"score": true, "time": true, "map": false,
		"guidance": false, "indicators": true, "events": true, "preparation": true,
	},
	"score_only": {
		"score": true, "time": false, "map": false,
		"guidance": false, "indicators": false, "events": false, "preparation": false,
	},
	"clean": {
		"score": false, "time": false, "map": false,
		"guidance": false, "indicators": false, "events": false, "preparation": false,
	},
}
## The presets in the order the pause tab lists them.
const UI_PRESET_IDS := ["all", "essential", "score_only", "clean"]
## One locale id per preset and per component: the pause tab reads these instead of
## carrying its own copy of the vocabulary (`PauseOverlay`), because the ids are
## the profile's names, not the tab's.
const UI_PRESET_LABELS := {
	"all": "uiPresetAll", "essential": "uiPresetEssential",
	"score_only": "uiPresetScoreOnly", "clean": "uiPresetClean",
}
const UI_COMPONENT_LABELS := {
	"score": "uiCompScore", "time": "uiCompTime", "map": "uiCompMap",
	"guidance": "uiCompGuidance", "indicators": "uiCompIndicators",
	"events": "uiCompEvents",
	"preparation": "uiCompPreparation",
}
## The hint's own geometry: 24 px above the frame's bottom edge, centred.
const UI_HINT_BOTTOM := 24.0
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
## Ball-cue thresholds and colours, copied value for value from `js/render.js` so
## the port shows a cut ball at exactly the moments the browser does.
const TRAIL_MAX_POINTS := 10                        # sim.gd:2990, ball.trail cap
## Whether the ball draws its trail at all. A `static var` so the probe can price it
## and the owner can change his mind without a rebuild; see the note at the build
## site. The render loop walks `_trail_views`, so an empty array means the per-frame
## cost is zero rather than invisible work.
static var show_trail := false
const TRAIL_FAST_SPEED := 620.0                     # js/render.js:1367
const SPIN_VISIBLE := 0.5                           # js/render.js:1369
const SPIN_RING_VISIBLE := 0.08                     # js/render.js:1546
const TRAIL_BASE := Color(198.0 / 255.0, 240.0 / 255.0, 106.0 / 255.0)
const TRAIL_SPIN := Color(94.0 / 255.0, 233.0 / 255.0, 255.0 / 255.0)
const TRAIL_FAST_SPIN := Color(255.0 / 255.0, 224.0 / 255.0, 102.0 / 255.0)
const SPIN_RING_TINT := Color(69.0 / 255.0, 224.0 / 255.0, 255.0 / 255.0)

var _mode_hud
## The recreated HUD (UIR-08), null ONLY in an explicitly legacy run — the ported
## column and this one are never built together any more (gate 4). `--ui=new` — the
## default since UIR-22, and the mount a harness gets too — shows it; `--ui=legacy`
## / `ui_legacy` is a real fallback rather than a broken one, and the run that asks
## for it is the only one that pays for `game/hud.gd`.
var _ui_hud: Control = null
var _ui_new := false
## UIR-22's overlay stack, mounted with the recreated HUD: the pause card and its
## nested smash tutorial (UIR-20) and the coarse-pointer touch layer (UIR-26). Null
## only in a legacy run: since gate 4 a harness-driven match mounts this stack like
## any other, so the harnesses exercise the overlays a player can open.
var _pause_overlay: Control = null
var _touch_layer: Control = null
## The pause card's controls in the port's verified navigation model
## (`game/menu_focus.gd`): built on every open and rebuilt on every tab change,
## because the tab decides which rows exist. Null until the card has been opened.
var _pause_focus = null
var _pause_pad_seen := false
## Frames still owed a re-measure of the card's rows (`_remeasure_pause_focus`).
var _pause_measure_frames := 0
var _audio
## The stands' crowd, found in the arena after the scenery is built. Presentation
## only; null in any build whose arena has no stands.
var _crowd: Node = null
var _cam: Camera3D
## The arena environment currently in the scene, built by
## `game/arenas/arena_library.gd`. Rebuilt in place when the arena changes (the
## per-arena capture run does exactly that, nine times).
var _arena_root: Node3D
var _ball_view: MeshInstance3D
var _land_ring: MeshInstance3D
## The two cues the browser draws for a spinning ball, and which this port was
## missing: the ball came out of a slice with the right physics (`sim.gd:1662`
## sets backspin exactly as `js/game.js:1671` does, and the bounce bites at
## `sim.gd:2102`) and no way to see it. Both are presentation only — every number
## below is read from the simulation state, none is computed here.
##   - the trail (`js/render.js:1413-1440`): `ball.trail`, already carried by the
##     ported state (`sim.gd:2987-2991`, capped at 10 points), turns cyan on spin;
##   - the spin ring (`js/render.js:1546-1553`): a ring around the ball whenever
##     `backspin > 0.08`. The browser draws it screen-facing, so this one is turned
##     towards the camera every frame rather than pinned to an axis: at the match
##     preset's -65 degrees a floor-plane ring would read as a flat line.
var _trail_views: Array[MeshInstance3D] = []
var _spin_ring: MeshInstance3D
## Fixed-size floor halo identifying the controlled athlete.
var _active_ring: MeshInstance3D
## Camera-facing downward triangle above the controlled athlete.
var _active_pin: MeshInstance3D
## The court timing presentation (`godot/game/court_timing_marks.gd`, gate 3): the
## ring, the window, the advice word and its panel, the two bars and the verdict. The
## module builds every mark into this node with its own `mount` and places them with
## its own `update`; this shell owns no mark of its own.
var _timing_marks
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
## Clean mode: while true the informational presentation is hidden and the court is
## left alone. Presentation only — no simulation state, no pause state and no match
## persistence reads or writes this flag, and every reset path clears it.
var _hud_hidden: bool = false
## Training: the finished run's own two flags. `_training_persisted` keeps the record write
## to once per run (a retry clears it); `_training_choice` is the action a finished run left
## behind for the engine clock, consumed once by `take_training_choice()`.
var _training_persisted: bool = false
var _training_choice: String = ""
## The summary's own guard: how long it has been up, and whether a quiet tick has armed it.
## A held button from the shot that ended the run therefore cannot press "retry" for the
## player.
var _training_elapsed: float = 0.0
var _training_armed: bool = false
## The profile in force, one entry per `UI_COMPONENTS` entry. Empty means `all`:
## `ui_visibility_snapshot()` resolves the default rather than storing a copy of it.
var _ui_visibility: Dictionary = {}
## The last profile that was not fully clean — what the gesture restores. Empty
## means the default `all` (a match that has never left the full view).
var _ui_last_non_clean: Dictionary = {}
## The restore hint: a small sibling of the shipping HUD, under the pause card and
## independent of the HUD root the profile hides components inside.
var _restore_hint: Control = null
## The locale door the hint's text goes through, loaded on first use.
var _ui_strings: Object = null

# ---------------------------------------------------------------------------
# UIR-27: the playback state (`js/main.js:138-140`)
# ---------------------------------------------------------------------------

## The `REPLAY_*` constants and the `replay_finished` signal live up with the file's
## own (consts and signals sit before the state, this file's order).
var _replay_active: bool = false
var _replay_index: int = 0
var _replay_accum: float = 0.0
var _replay_done: bool = false
## The pause the entry recorded, put back by `stop_replay()` — the ticket's one
## divergence from the reference's letter (§3.4 of `evidence/uir-27-replay.log`).
var _replay_was_paused: bool = false
## UIR-27's chrome over the court, mounted in `_build_scene` behind the new UI.
var _replay_overlay: Control = null


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var capture := _arg(args, "--capture=", "")
	# UIR-22: the recreated HUD and the overlay stack are the playable path now, so
	# the default flipped — `--ui=legacy` keeps the ported HUD reachable for the
	# diagnostic side-by-side the captures and the slice's visual-contract section
	# read, and `ui_legacy` (set before the tree, the menu's own switch) is the
	# in-process form of the same request. THIS IS THE WHOLE MOUNT POLICY: one
	# question, asked once, and the clock (`engine_driven`) is not part of it
	# (architecture-deepening gate 4).
	_ui_new = (not ui_legacy) and _arg(args, "--ui=", "new") != "legacy"
	var camera := _arg(args, "--camera=", String(Config.stored_prefs().get("cameraPreset", "default")))
	if not Court.CAMERAS.has(camera):
		camera = "default"
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
			# One engine run renders every arena THIS build offers — the frozen
			# nine and, in a full build, the five world arenas
			# (`_run_arena_capture` enumerates the library through the build's own
			# content rule): this host allows exactly one Godot process at a time
			# and every software-rendered start-up is paid for once
			# (`godot/game/run.sh shots-arenas`).
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
	state.aiGlassPlay = AI_GLASS_PLAY
	_start_play_test(state)
	pace_factor = Config.pace_factor()
	ticks = 0
	crossings = 0
	points_scored = 0
	max_rally = 0
	seen_events = {}
	score_history = []
	finished = false
	# A new session is a new training run: the finished-run flags start clean.
	_training_persisted = false
	_training_choice = ""
	_quick_outfit_award = {}
	# A new match is a new receipt key: the previous award must not block this one.
	_economy_match_id = ""
	_economy_award = {}
	# A new match starts at `all` (the visibility profile is a per-match view, not a
	# stored preference): the profile, its restore memory and the clean flag reset
	# together, and `_apply_hud_visibility` below repaints every surface.
	_reset_ui_visibility()
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
	_apply_stored_audio_prefs()
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
	_apply_hud_visibility()
	_sync_views()
	if _hud != null:
		_hud.refresh(state, meta)
	_refresh_ui(state, meta)
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
	_refresh_ui(state, meta)
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


# ---------------------------------------------------------------------------
# Training: the finished run, its record and its three actions
# ---------------------------------------------------------------------------

## True while the BOUNDED training run is over and waiting for the player. The drill's own
## `summary` phase is the mode's end (`drill_session.gd`); the match's `finished` flag stays
## false, so nothing here travels the generic end-of-match path: no result panel, no economy
## award, no history entry, no outfit challenge — training pays a record and nothing else.
func training_summary_up() -> bool:
	if session == null or session.mode != "drill" or session.drill == null or finished:
		return false
	return String(session.drill.phase) == "summary"


## The finished run's own numbers, or `{}` while the run is still on. Public so a test (and
## the summary panel) can read the same model the HUD draws.
func training_summary() -> Dictionary:
	if not training_summary_up():
		return {}
	return session.drill.summary()


## The one tick a finished run consumes: persist the record once (an improved best must
## survive whatever the player does next), then read the action.
## `ARMED` IS WHAT KEEPS THE LAST SHOT OUT OF THE MENU. A drill's attempt closes on the very
## tick the player's swing produced, and the same button (or a held trigger, or a mouse press)
## is still down on the next one: without a guard the run would retry itself the instant it
## ended. So the summary accepts a pad/keyboard action only after a tick with no action input
## has been observed AND the grace below has passed — the rule a click on the panel's own
## buttons already has, because a click is a fresh press.
func _tick_training_summary(input: Dictionary, dt: float) -> Variant:
	if _mode_hud != null:
		_mode_hud.visible = not _paused
	if not _training_persisted:
		session.persist_training_record()
		_training_persisted = true
		if _mode_hud != null:
			_mode_hud.refresh()
	ticks += 1
	_training_elapsed += dt
	var hit := bool(input.get("hit", false))
	var special := bool(input.get("special", false))
	if not hit and not special and _training_elapsed >= TRAINING_SUMMARY_GRACE:
		_training_armed = true
	if _training_armed:
		if hit:
			if _mode_hud != null:
				_mode_hud.activate_training_action()
			else:
				training_retry()
		elif special:
			training_choose()
	if _mode_hud != null:
		_mode_hud.refresh()
	return null


## `A` on the summary: the same exercise, a fresh run. The attempt counters go back to zero
## and the record does not (`DrillSession.restart_run`), so a retry can never silently
## discard an improved best, and the next run is measured like-for-like again.
func training_retry() -> Dictionary:
	if not training_summary_up():
		return {}
	session.persist_training_record()
	session.drill.restart_run()
	_training_persisted = false
	_training_armed = false
	_training_elapsed = 0.0
	if _mode_hud != null:
		_mode_hud.refresh()
	if _hud != null:
		_hud.refresh(state, meta)
	_refresh_ui(state, meta)
	return session.drill.summary()


## `B` on the summary: leave with the run's record written and report where the player goes
## next. The scene change belongs to `training_leave()`, which only the engine-driven clock
## performs — a harness reads `_training_choice` instead of losing its own scene.
func training_choose() -> Dictionary:
	if not training_summary_up():
		return {}
	var run: Dictionary = session.drill.summary()
	session.persist_training_record()
	_training_persisted = true
	var awarded := end_drill()
	_training_choice = "choose"
	return {"summary": run, "awarded": awarded, "scene": Config.training_return_scene(), "left": true}


## Leave training altogether: the run's record is written (as in `training_choose`), the session
## ends, and the player goes to the menu rather than to another exercise. The scene change,
## like the other two routes, belongs to `training_leave`.
func training_exit() -> Dictionary:
	if not training_summary_up():
		return {}
	var run: Dictionary = session.drill.summary()
	session.persist_training_record()
	_training_persisted = true
	var awarded := end_drill()
	_training_choice = "exit"
	return {"summary": run, "awarded": awarded, "scene": "res://game/Main.tscn", "left": true}


## The route back to the training hub the run started from (`Config.training_return_scene`):
## the routed hub is mounted by the menu host, the ported one is its own scene. Nothing here
## decides the destination per call — the hub that started the run wrote it.
func training_leave(choice: String = "choose") -> void:
	var destination := training_destination(choice)
	Config.pending_menu_screen = String(destination["screen"])
	get_tree().change_scene_to_file(String(destination["scene"]))


func training_destination(choice: String) -> Dictionary:
	return {
		"scene": "res://game/Main.tscn" if choice == "exit" else Config.training_return_scene(),
		"screen": "menu" if choice == "exit" else "drill",
	}


## The choice a finished run left behind, consumed once by the engine clock.
func take_training_choice() -> String:
	var held := _training_choice
	_training_choice = ""
	return held


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
	# The crowd belongs to the arena, so it is found again on every arena change
	# rather than cached once: a rebuilt arena carries a new crowd, and holding the
	# old one would tick a freed node.
	_crowd = _arena_root.find_child("Crowd", true, false)
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
	_audio.use_ost = true
	_audio.name = "MatchAudio"
	add_child(_audio)

	_ball_view = MeshInstance3D.new()
	_ball_view.name = "Ball"
	var sm := SphereMesh.new()
	sm.radius = Court.BALL_R
	sm.height = Court.BALL_R * 2.0
	_ball_view.mesh = sm
	var ball_material := ShaderMaterial.new()
	ball_material.shader = preload("res://game/ball_readable.gdshader")
	_ball_view.material_override = ball_material
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

	# The trail: one small sphere per simulation trail point. Additive and unshaded,
	# which is what the browser's "lighter" composite does (`js/render.js:1434`).
	# OFF by the owner's call (2026-09-17): ten additive transparent spheres are ten
	# draws that cannot be batched and that the depth prepass cannot help, and he read
	# the cost in the frame rate before the measurement was in. Kept rather than
	# deleted because it is the browser's own cue and the parity checks still describe
	# it — flip `show_trail` to bring it back and `--trail=1` on the probe to price it.
	for i in (TRAIL_MAX_POINTS if show_trail else 0):
		var dot := MeshInstance3D.new()
		dot.name = "TrailDot%d" % i
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dm := SphereMesh.new()
		dm.radius = Court.BALL_R
		dm.height = Court.BALL_R * 2.0
		dot.mesh = dm
		var dmat := StandardMaterial3D.new()
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		dmat.albedo_color = Color(TRAIL_BASE.r, TRAIL_BASE.g, TRAIL_BASE.b, 0.0)
		dot.material_override = dmat
		dot.visible = false
		add_child(dot)
		_trail_views.append(dot)

	_spin_ring = MeshInstance3D.new()
	_spin_ring.name = "SpinRing"
	_spin_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sr := TorusMesh.new()
	sr.inner_radius = Court.BALL_R * 1.45
	sr.outer_radius = Court.BALL_R * 1.75
	_spin_ring.mesh = sr
	var srm := StandardMaterial3D.new()
	srm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	srm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	srm.albedo_color = Color(SPIN_RING_TINT.r, SPIN_RING_TINT.g, SPIN_RING_TINT.b, 0.9)
	_spin_ring.material_override = srm
	_spin_ring.visible = false
	add_child(_spin_ring)
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

	# The court timing presentation: the module builds its eleven marks into this
	# node (same names, same order, same parent as before gate 3) and places them
	# every frame from `_sync_views`.
	_timing_marks = CourtTiming.new()
	_timing_marks.mount(self)

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
	# THE MOUNT POLICY (architecture-deepening gate 4). The recreated UI is the
	# shipping path; the ported column below is built only when a run asked for it
	# EXPLICITLY (`ui_legacy` / `--ui=legacy`). A recreated run builds no hidden
	# copy of it and nothing refreshes it — which is also why the legacy request
	# and the clock are two separate questions: `engine_driven` is off in every
	# harness, and the harnesses still exercise what ships.
	if not _ui_new:
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
	# and it stays invisible in a quick match (no session to bind). It is NOT the
	# ported column: a mode match carries it in both UI modes.
	_mode_hud = ModeHudScript.new()
	_mode_hud.name = "ModeHud"
	layer.add_child(_mode_hud)
	# The finished training run's own three actions: the panel's buttons are the MOUSE route,
	# and the controller's input (A/B/ESC) is the pad and keyboard one. Both go through the
	# same three methods, so a click and a button press cannot diverge.
	_mode_hud.training_retry_requested.connect(training_retry)
	_mode_hud.training_choose_requested.connect(training_choose)
	_mode_hud.training_exit_requested.connect(training_exit)
	if session != null:
		_mode_hud.bind_session(session)
	if _ui_new:
		# UIR-09's prototype mount, now the playable one. Same layer, same state+meta
		# (`_refresh_ui`), same names, and the pause button the ported HUD also
		# carries — a drill's ESC still flips `_paused` in one place, which both
		# overlays read. Loaded, not preloaded: a legacy run does not pull these
		# scenes and their theme into the engine's object count.
		# UIR-27's replay chrome: the reference draws it on the game canvas UNDER the
		# HTML HUD (`.game-hud` z-index 5, `styles.css:536-544`), so it is a sibling of
		# the HUDs with a negative z_index rather than a child of either. It paints
		# only what the controller's seam answers (`replay_active`/`replay_progress`)
		# and carries no focus row of its own.
		_replay_overlay = (load("res://src/ui/screens/ReplayOverlay.tscn") as PackedScene).instantiate()
		_replay_overlay.name = "ReplayOverlay"
		layer.add_child(_replay_overlay)
		_replay_overlay.z_index = -1
		_replay_overlay.bind_seam(self)
		_ui_hud = (load("res://src/ui/Hud.tscn") as PackedScene).instantiate()
		_ui_hud.name = "UiHud"
		layer.add_child(_ui_hud)
		_ui_hud.bind_names(
			String(Config.athlete()["name"]),
			String(Config.tier()["name"]),
			player_color,
			ai_color
		)
		_ui_hud.pause_requested.connect(_on_ui_pause)
		_ui_hud.mute_toggled.connect(func(muted: bool) -> void:
			_audio.port.set_muted(muted)
			# Apply immediately, including while simulation is paused or in replay.
			if _audio.ost != null:
				_audio.ost.set_muted(muted)
		)
		# The restore hint: a sibling of the HUD, added BEFORE the card so the card
		# draws over it. It carries no state of its own — `_apply_ui_hint` decides
		# when it shows.
		_restore_hint = _build_restore_hint()
		layer.add_child(_restore_hint)
		# UIR-20's pause card, above the HUD: its own recipe's steps 1-6 (instantiate
		# over the match, one store, one seam, the echo, the stick feed, the pad flag).
		# EXACTLY ONE pause route is live — the seam bound here — and the overlay's
		# signals are used only for what the seam does not cover (the focus rebuild
		# on a tab change, the tutorial's own opens), never to toggle the flag a
		# second time.
		_pause_overlay = (load("res://src/ui/screens/PauseOverlay.tscn") as PackedScene).instantiate()
		_pause_overlay.name = "PauseOverlay"
		layer.add_child(_pause_overlay)
		_pause_overlay.bind_seam(self)
		_pause_overlay.set_store(Config.save_store())
		_sync_pause_pad_identity()
		_pause_overlay.set_osk_open(false)
		_pause_overlay.set_match_paused(false)
		_pause_overlay.tab_changed.connect(_on_pause_tab_changed)
		_pause_overlay.music_volume_changed.connect(_on_pause_music_volume_changed)
		# UIR-27's entry from the card (`js/main.js:2238-2241`): the reference hides the
		# card and toggles the replay. The card hides through the pause echo the entry
		# performs, and the toggle is the same seam the `r` key calls.
		_pause_overlay.replay_requested.connect(_on_replay_requested)
		# UIR-26's touch layer: the reference's coarse-pointer deck/pad (its own
		# visibility rules decide whether anything shows at this frame width).
		_touch_layer = (load("res://src/ui/screens/TouchControls.tscn") as PackedScene).instantiate()
		_touch_layer.name = "TouchControls"
		layer.add_child(_touch_layer)
		_touch_layer.set_frame_width(float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)))
		_touch_layer.apply_visibility()
		# Only the mode HUD is hidden here: it is carried in both UI modes, and in
		# this one its facts are the recreated strip's (the recreated HUD is what a
		# player reads). The ported column is not built at all in this mode, so
		# there is nothing to hide.
		_mode_hud.visible = session != null and session.mode == "drill"


## The prototype overlay's pause button asks the same question the key does: it emits,
## this file owns `_paused` (the HUD never sets it), and both overlays are told.
func _on_ui_pause() -> void:
	set_match_paused(not _paused)


## UIR-27: the card's replay entry (`replay_requested`). The reference's card entry
## hides the card and then toggles the playback (`js/main.js:2238-2241`):
## `start_replay()` is that path here — it records the card's pause, so stopping
## reopens the card. A press while a playback is up stops it instead.
func _on_replay_requested() -> void:
	if _replay_active:
		stop_replay()
		return
	start_replay()


## THE PAUSE SEAM (UIR-20's one-line request, UIR-22's implementation). An EXPLICIT
## state, not a toggle: the overlay calls it with `false` on CONTINUE and ESC step 4
## and with `true` on ESC step 5 and on RIPRENDI E PROVA. `_reset_transient_input()`
## runs on BOTH edges, because the reference calls `resetTransientInput()` in
## `pauseGame` AND `resumeGame` (`js/main.js:1532,1543`) — a one-shot sampled while
## paused must not land on the first sub-step after the resume (review-2 F-4).
## The echo back into the overlay is the last line: the card shows exactly while the
## match is paused, and a second identical echo is a no-op inside the overlay.
func set_match_paused(paused: bool) -> bool:
	_paused = paused
	if _audio != null and _audio.ost != null:
		_audio.ost.set_held(paused)
	_reset_transient_input()
	if _hud != null:
		_hud.set_paused(_paused)
	if _ui_hud != null:
		_ui_hud.set_paused(_paused)
	if _pause_overlay != null:
		_pause_overlay.set_match_paused(_paused)
		_tell_pause_card()
		if _paused:
			_rebuild_pause_focus()
		else:
			_pause_pad_seen = false
			_pause_measure_frames = 0
	# The restore hint belongs to live play: the card opening hides it, and closing
	# the card in clean mode brings it back (`_apply_ui_hint` reads `_paused`).
	_apply_ui_hint()
	return _paused


## The card's rows depend on its active tab, so the model is rebuilt when the tab
## changes, not only when the card opens.
func _on_pause_tab_changed(_tab_id: String) -> void:
	if _paused:
		_rebuild_pause_focus()


## The pause card's controls, in the port's verified navigation model
## (`game/menu_focus.gd`). The overlay hands its rows over (`focus_controls()`); the
## model decides the geometric moves, and the activation stays the focused Button's
## own press — the same split every menu screen uses, so the pad and the arrow keys
## behave the same here as everywhere else.
##
## THE ROWS ARE MEASURED TOO EARLY HERE, AND THAT IS NOT A DETAIL. This runs on the
## frame the card opens (and the frame a tab changes), i.e. the frame the card became
## visible — and a container has not sorted its children yet at that point. Measured
## on the card's own table, every row reports `P(0,0)` with only its minimum size, so
## the model's geometry is fiction: `move_focus("down")` finds no candidate at all
## and `move_focus("right")` hops between the three tabs, whose minimum widths differ.
## The rows are re-measured once the layout is real (`_remeasure_pause_focus`, armed
## by the counter below); the build itself stays here, so the focus exists on the same
## frame the card opens.
func _rebuild_pause_focus() -> void:
	if _pause_overlay == null:
		return
	if _pause_focus == null:
		_pause_focus = MenuFocus.new()
	else:
		_pause_focus.clear()
	for row in _pause_overlay.focus_controls():
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = row
		var node: Control = entry.get("node", null)
		if node == null:
			continue
		_pause_focus.add(String(entry.get("id", "")), node, String(entry.get("action", "")), entry.get("opts", {}))
	_pause_focus.refresh()
	_pause_focus.ensure_focus()
	_pause_measure_frames = PAUSE_MEASURE_FRAMES


## Re-measures the card's rows once the containers have sorted, keeping the focus on
## the row it was on. `MenuFocus.refresh()` rebuilds the model's target list, and the
## model's own rule (`focus_nav.gd::ensure_focus`) is that a rebuild which cannot find
## the old id falls back to the first target — asked here in that order, so a
## re-measure cannot silently teleport the focus back to the first tab. GEOMETRY ONLY:
## nothing is painted here, because the group the player opened the card with decides
## whether a focus ring exists at all (a tab is focused with a pad in hand and not
## without, `js/main.js:2349` — `PauseOverlay.set_tab`'s own rule).
func _remeasure_pause_focus() -> void:
	if _pause_focus == null:
		return
	var keep: String = _pause_focus.focus_id()
	_pause_focus.refresh()
	if keep != "" and _pause_focus.focusable_ids().has(keep):
		_pause_focus.menu.nav.set_focus(keep)
	else:
		_pause_focus.ensure_focus()


## The joypad the card reads: the match's own primary seat, which `_refresh_pads`
## re-assigns every frame from the pad somebody touches (`js/main.js:780-784`), not a
## hard-wired pad 0. `NO_DEVICE` (nobody connected) passes through as itself: the
## model's own reads are neutral then (`menu_focus.gd::_menu_axis`/`_menu_button`).
func _pause_pad_device() -> int:
	return 0 if _input_source == null else int(_input_source.device)


## The D-pad's four arrows, as the engine's own `ui_*` actions see them: those are the
## events the model's poll replaces (`MenuFocus.poll_pad`), so the caller swallows
## them. A/B/X and everything else is NOT this function's business — the focused
## Button still answers `ui_accept` itself.
static func _pause_direction_button(event: InputEventJoypadButton) -> bool:
	return event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
		or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")


## B and X, the two buttons the model's own back edge reads (`menu_nav.gd::poll_pad`):
## the card answers them with the same five-step return ESC walks (`PauseOverlay.back`).
static func _pause_back_button(event: InputEventJoypadButton) -> bool:
	return event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_X


## The pause card's own key navigation, while it is open: the model's four
## directions, consumed before the engine's built-in `ui_*` walk can move the same
## focus twice. Buttons are deliberately left to the engine — the focused Button
## answers `ui_accept` itself, and swallowing it here would make the card dead.
func _pause_nav(event: InputEvent) -> bool:
	if _pause_focus == null:
		return false
	if event is InputEventKey:
		var verdict: Dictionary = _pause_focus.handle_key(event as InputEventKey)
		if bool(verdict.get("handled", false)):
			_pause_focus.apply_focus()
			_apply_pause_range()
			return true
	return false


## The card's ranges, on the same hand-off the menu's bridge does with
## `range_changed`: the model steps the value in place (`focus_nav._adjust_range`) and
## never touches a node, so the mount hands the new value back to the card, whose own
## handler persists it (`PauseOverlay.set_row_value`). The step is clamped to the
## ROW's own bounds first: in this path the model is driven directly (no bridge to
## merge the carried `min`/`max`/`step`, see `UiFocusBridge.CARRIED_KEYS`), so the
## model's step can name a value outside the row's range — the row is the authority.
func _apply_pause_range() -> void:
	if _pause_focus == null or _pause_overlay == null:
		return
	var nav = _pause_focus.menu.nav
	var target: Dictionary = nav.focus()
	if String(target.get("kind", "")) != "range":
		return
	var id := String(target.get("id", ""))
	if id == "":
		return
	var action := id.get_slice("/", 1)
	var row_names := {
		"volume": "VolumeRow",
		"deadzone": "DeadzoneRow",
		"music-volume": "MusicVolumeRow",
	}
	var row_name := String(row_names.get(action, action))
	var value := float(target.get("value", 0.0))
	var row: Control = _pause_overlay.rows().get(row_name, null)
	if row is SettingsRows.RangeRow:
		var slider := SettingsRows.focus_node(row) as Range
		if slider != null:
			value = clampf(value, slider.min_value, slider.max_value)
	_pause_overlay.set_row_value(row_name, value)
	# The stored value is also the live value: the audio module and the pad reader take
	# it here, so a change made on the pause card is in force for the rest of the match
	# (review F6). The overlay owns the persist; this is the application.
	if row_name == "VolumeRow" and _audio != null and _audio.port != null:
		_audio.port.set_master_gain(value)
	elif row_name == "DeadzoneRow":
		InputSource.set_deadzone(value)


func _on_pause_music_volume_changed(value: float) -> void:
	var prefs := Config.stored_prefs()
	prefs["musicVolume"] = value
	MusicSettings.apply(prefs)


## The stored mixer/input prefs, applied at match boot the way the reference applies
## them at load (`js/main.js:2276-2278`): `volume` to the audio module's own master
## gain (the bus derivation stays in the module) and `gamepadDeadzone` to the pad
## reader, clamped to the reference's band inside `set_deadzone`.
func _apply_stored_audio_prefs() -> void:
	var prefs: Dictionary = Config.stored_prefs()
	if _audio != null and _audio.port != null:
		_audio.port.set_master_gain(float(prefs.get("volume", 0.5)))
	MusicSettings.apply(prefs)
	InputSource.set_deadzone(float(prefs.get("gamepadDeadzone", 0.15)))


## The one call site that feeds the prototype HUD: it is refreshed wherever the ported
## HUD is, with the same state and meta, so the two cannot drift before UIR-22.
func _refresh_ui(state_ref, meta_ref: Dictionary) -> void:
	if _ui_hud != null:
		_ui_hud.refresh(state_ref, meta_ref)


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
	_lineup = Lineup.resolve(Config.athlete(), null, ModesSave.load_career(Config.save_store()))
	if _athletes == null:
		_athletes = AthletesView.new()
		_athletes.name = "Athletes"
		add_child(_athletes)
	var started := Time.get_ticks_msec()
	var spawned: int = _athletes.spawn(_lineup, Lineup.outfits(_lineup, Config.outfit_id(),
		ModesSave.load_career(Config.save_store())), {
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
			_player_color if key.begins_with("player") else _ai_color, _racket_style_of(key))


## The same racket style the rigged path would have chosen (`AthletesView.racket_style_for`),
## read off the lineup this match already resolved: the capsule fallback is a degraded
## build, not a different athlete — Fornaio keeps Il Cornetto even here.
func _racket_style_of(role: String) -> StringName:
	var athlete: Variant = _lineup.get(role, null)
	if athlete == null:
		return Court.RACKET_STYLE_STANDARD
	return AthletesView.racket_style_for(StringName(String((athlete as Dictionary)["id"])))


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
	# The human mode: the arena screen's stored choice on a quick match, `"solo"`
	# everywhere else (`js/main.js:1156`), validated against the reference's three
	# values the way `Config.control_mode()` validates the control mode.
	var human_mode := "solo"
	if Config.pending_mode == "quick" and HUMAN_MODES.has(Config.pending_player_mode):
		human_mode = Config.pending_player_mode
	state = Sim.create_match_state("quick", Config.athlete(), Config.arena(), Config.tier(), 0, {"humanMode": human_mode})
	# The setup screen's match-length selection applies only to a quick match;
	# tournament and career keep the fixed rules their sessions construct.
	Config.apply_quick_match_format(state)
	state.aiGlassPlay = AI_GLASS_PLAY
	_start_play_test(state)
	state.rng_state = Config.seed_value
	state.running = true
	# The saved switching mode (`js/main.js:1184`,
	# `matchState.controlMode = ui.controlMode`), validated against the reference's
	# own three values by `Config.control_mode()` (`js/main.js:2273`).
	state.controlMode = Config.control_mode()
	pace_factor = Config.pace_factor()
	ticks = 0
	crossings = 0
	points_scored = 0
	max_rally = 0
	seen_events = {}
	score_history = []
	finished = false
	_quick_outfit_award = {}
	# A new match starts with its informational overlay showing, exactly as a mode
	# session's `_adopt_session()` does above: the profile, its restore memory and
	# the clean flag go back to the full view together.
	_reset_ui_visibility()
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
	_apply_stored_audio_prefs()
	_points_total_prev = _points_total()
	meta = {
		"seed": Config.seed_value,
		"tier": String(Config.tier()["id"]),
		"camera": Config.camera_preset,
		"tick": 0,
	}
	_apply_hud_visibility()
	_sync_views()
	if _hud != null:
		_hud.refresh(state, meta)
	_refresh_ui(state, meta)


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
	# The game-pace preset scales the SIMULATED time a real frame is worth, and the
	# catch-up clamp with it: leaving the clamp at its unscaled value would make it
	# k times tighter in simulated seconds, so a fast preset would quietly drop sim
	# time whenever a frame ran long. Both clamps stay the reference's own at the
	# default preset, whose factor is 1.0.
	var dt := minf(delta, MAX_FRAME_DELTA) * pace_factor
	sim_accumulator = minf(sim_accumulator + dt, FIXED_STEP * float(MAX_SIM_STEPS) * pace_factor)
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
	# The training summary's own choice, on the FRAME (not inside a sub-step): a finished
	# run that asked to change exercise leaves here, once. A harness owns its own scene and
	# never sets `engine_driven`, so this is inert for it.
	if engine_driven and _training_choice != "":
		training_leave(take_training_choice())
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
	if _replay_active:
		# A playback frame never touches the accumulator (`js/main.js:1243-1245`): the
		# match stays frozen under the replay whatever the pause flag says, and the
		# cursor is the only thing that moves.
		return _replay_frame(delta)
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
	if _ui_hud != null and not finished:
		_ui_hud.refresh(state, meta)
	if _mode_hud != null and session != null and not finished:
		_mode_hud.refresh()
		if session.mode == "drill":
			_mode_hud.visible = not _paused and (training_summary_up() or _ui_component_on("guidance"))
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
	# The pause card's navigation, while it is open: the model is polled once per
	# frame (the reference polls its pad in the render loop), and the match itself
	# ticked nothing this frame — a paused frame arms nothing (`apply_frame`).
	if _pause_overlay != null and _pause_overlay.is_open():
		if _pause_focus != null:
			# The rows are measured BEFORE the frame's move is resolved: the first
			# frames after the card opens are exactly the ones whose geometry is
			# still at the origin (`_rebuild_pause_focus`).
			if _pause_measure_frames > 0:
				_pause_measure_frames -= 1
				_remeasure_pause_focus()
			var pause_move: Dictionary = _pause_focus.poll_pad(_pause_pad_device())
			if bool(pause_move.get("focus_moved", false)):
				_pause_focus.apply_focus()
			_apply_pause_range()
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
	_sync_pause_pad_identity()


## The 2D game classifies `gamepad.id` on every connected/disconnected edge and on
## every active-pad change. Godot exposes the same identity through
## `Input.get_joy_name(device)`: the selected primary seat is the one the pause guide
## describes, including when another connected pad takes over after real activity.
func _sync_pause_pad_identity() -> void:
	if _pause_overlay == null:
		return
	var device := _pause_pad_device()
	var connected_devices := Input.get_connected_joypads()
	# During `_build_scene` the input seat has not polled its first frame yet. Show
	# an already-connected controller immediately instead of spending that frame on
	# the disconnected fallback; `_refresh_pads` will then confirm or replace it.
	if device == InputSource.NO_DEVICE and not connected_devices.is_empty():
		device = int(connected_devices[0])
	var connected := device != InputSource.NO_DEVICE and connected_devices.has(device)
	var device_name := Input.get_joy_name(device) if connected else ""
	_pause_pad_seen = connected
	if _pause_overlay.has_method("set_pad_device"):
		_pause_overlay.call("set_pad_device", device, device_name, connected)
	else:
		_pause_overlay.set_pad_connected(connected)


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
## Play-test switches, read once per match from the environment (see `_match_log`).
func _start_play_test(match_state) -> void:
	var glass := OS.get_environment("PADEL_AI_GLASS")
	if glass != "":
		match_state.aiGlassPlay = glass == "1"
	_match_log = null
	if MatchLog.enabled():
		_match_log = MatchLog.new()
		_match_log.start(match_state, {
			"mode": String(Config.pending_mode),
			"athlete": String(Config.athlete().get("id", "?")),
			"arena": String(Config.arena().get("id", "?")),
			"seed": Config.seed_value,
		})


func tick_fixed(dt: float, input: Dictionary, input2: Dictionary) -> Variant:
	if state == null:
		return null
	# TRAINING: a FINISHED run has no clock of its own. The bounded run closes its eighth
	# attempt and parks in `summary`; from there the three actions are the player's — retry,
	# choose another exercise, or leave — so the tick path does not step the engine and does
	# not let the run restart itself. This is the only input the summary consumes.
	if training_summary_up():
		return _tick_training_summary(input, dt)
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
	if _match_log != null:
		_match_log.observe(state)
	# The sounds this tick produced. `match_audio.gd` owns the whole routing
	# decision; this is the one call site, on the one tick path, so the engine-driven
	# build and the headless harness hear the same match.
	if _audio != null:
		_audio.observe(state, ticks)
	# The crowd reads the same state on the same tick, and for the same reason: the
	# sim stores no "cheer now" flag, so the reaction is derived from the totals it
	# does keep. Presentation only — nothing it does is read back here.
	if _crowd != null:
		_crowd.observe(state, ticks)
	var train := _depot_train()
	if train != null:
		if ticks == 1: train.reset_schedule()
		train.step(dt, float(state.pointPause) > 0.0, state.result != null)
	return result


func _depot_train() -> Node3D:
	if _arena_root == null: return null
	return _arena_root.get_node_or_null("Scenery/LocomotiveDepot/PassingTrain") as Node3D


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
		else:
			_finish_quick_outfits()
		# Emporio OST: the completion reward is awarded HERE, at the authoritative
		# end-of-match boundary — a real, engine-driven playable match. A drill never
		# reaches this block (`_mode_runs_by_points`), an aborted game never produces a
		# `state.result`, and a headless probe/harness is skipped inside `_award_economy`.
		_award_economy()
		if _hud != null:
			_hud.refresh(state, meta)
			_hud.show_result(state)
		_refresh_ui(state, meta)
		# UIR-22: the end of a match is the result screen. The payload is built from
		# the live state and the session's own facts (UIR-21's builder) and left in
		# `Config.pending_result`; the router host consumes it. A harness run (no
		# engine clock, no display) is left exactly as it was: it reads `summary()`
		# and never navigates.
		if engine_driven and load_models:
			finish_route()
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
	if _ui_hud != null and not engine_driven and (finished or ticks % 30 == 0):
		_ui_hud.refresh(state, meta)


## `awardOutfitChallenges(matchState, won)` is called before the browser branches
## into career/tournament handling (`js/main.js:1472`). Quick mode has no
## ModeSession in this port, so its common end-of-match edge performs that one
## progression write directly. The cached result makes the operation idempotent.
func _finish_quick_outfits() -> Dictionary:
	if not _quick_outfit_award.is_empty() or state == null or state.result == null:
		return _quick_outfit_award
	var won := String(state.result.get("winner", "")) == "player"
	_quick_outfit_award = ModesSave.award_match_outfits(
		Config.save_store(), String(state.athlete.get("id", "")), state.stats, won,
		float(state.ai.get("skill", 0.0))
	)
	return _quick_outfit_award


## True when the mode's own end has been reached — a drill that the player left.
func _page_finished() -> bool:
	return session != null and session.finished


# ---------------------------------------------------------------------------
# Emporio OST: the completion reward
# ---------------------------------------------------------------------------

## Award the completed match's credits, once. Called only from the end-of-match block,
## and only for a real playable match: the headless harness and the probe runs set
## `engine_driven`/`load_models` off, and they are skipped here so a test or a capture
## never writes a wallet. The id is this match's own; the service's persisted receipt
## makes a second call (a re-rendered result, a restart) award nothing.
func _award_economy() -> Dictionary:
	if not Economy.award_eligible(
		session.mode if session != null else "quick",
		Gate.is_demo(), engine_driven, load_models, economy_award_enabled,
		state != null and state.result != null
	):
		return {}
	if _economy_match_id == "":
		_economy_match_id = _new_economy_match_id()
	var won := String(state.result.get("winner", "")) == "player"
	# The ACCUMULATED totals, not the tennis scoreboard: `state.points` resets every game.
	var played := Economy.points_played(state.stats)
	_economy_award = Economy.award_completion(Config.save_store(), _economy_match_id, played, won)
	return _economy_award


## A match id that is unique across processes, non-simulation and stable for the life of
## this match. The wall clock separates processes (a monotonic uptime clock would repeat
## after a reboot) and OS entropy separates two matches in the same second. Deliberately
## NOT the simulation's RNG: nothing here may perturb the match's own determinism.
func _new_economy_match_id() -> String:
	var nonce := Crypto.new().generate_random_bytes(8).hex_encode()
	return "m%d-%s" % [int(Time.get_unix_time_from_system()), nonce]


## This match's award (`{}` before the end, or in a harness run). The result payload
## reads it so the screen can show the reward and the balance.
func economy_award() -> Dictionary:
	return _economy_award.duplicate(true)


func economy_match_id() -> String:
	return _economy_match_id


# ---------------------------------------------------------------------------
# View sync: every position comes from the live state, never a cached copy
# ---------------------------------------------------------------------------

## The cut ball, made visible. Every threshold, colour and radius here is the
## browser's (`js/render.js:1360-1440` for the trail, `:1546-1553` for the ring);
## every input is simulation state (`ball.trail`, `ball.spin`, `ball.backspin`,
## `ball.vx/vy`), so this cannot change what the match does — only what it shows.
func _sync_ball_cues(ball) -> void:
	var speed: float = sqrt(float(ball.vx) * float(ball.vx) + float(ball.vy) * float(ball.vy))
	var fast: bool = speed > TRAIL_FAST_SPEED
	var spinning: bool = float(ball.topspin) > SPIN_VISIBLE or float(ball.backspin) > SPIN_VISIBLE
	var tint := TRAIL_BASE
	if spinning:
		tint = TRAIL_SPIN
	if fast and spinning:
		tint = TRAIL_FAST_SPIN

	var points: Array = ball.trail
	var shown: int = mini(points.size(), _trail_views.size())
	for i in _trail_views.size():
		var dot: MeshInstance3D = _trail_views[i]
		if i >= shown:
			dot.visible = false
			continue
		var p: Dictionary = points[i]
		dot.visible = true
		dot.position = Court.world_pos(
			float(p.get("x", 0.0)), float(p.get("y", 0.0)), float(p.get("z", 0.0)))
		# Oldest point is the smallest and faintest, exactly as `idx` does in the browser.
		var idx: float = 0.0 if shown <= 1 else float(i) / float(shown - 1)
		var life: float = clampf(float(p.get("life", 0.0)) / 0.3, 0.0, 1.0)
		var r: float = (0.32 + 0.42 * idx) * (1.22 if fast else 1.0)
		dot.scale = Vector3(r, r, r)
		var mat: StandardMaterial3D = dot.material_override
		mat.albedo_color = Color(tint.r, tint.g, tint.b, life * (0.5 if fast else 0.32))

	var ring_on: bool = float(ball.backspin) > SPIN_RING_VISIBLE
	_spin_ring.visible = ring_on
	if ring_on:
		_spin_ring.position = _ball_view.position
		if _cam != null:
			var towards: Vector3 = _cam.global_position - _spin_ring.global_position
			# look_at breaks when the direction is parallel to its up vector; at the
			# match preset it never is, but a camera straight overhead would make it so.
			if towards.length() > 0.001 and absf(towards.normalized().dot(Vector3.UP)) < 0.999:
				_spin_ring.look_at(_cam.global_position, Vector3.UP)
				# A torus lies in its own XZ plane, so its axis is local Y: after look_at
				# that axis is sideways. This quarter turn puts it down the view direction,
				# which is what makes the ring read as a circle rather than an edge.
				_spin_ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)


## Seconds to hand the drawn ball between the simulation's parked serve ball and the
## server's bouncing hand, both ways, so neither edge of the ritual is a jump.
const SERVE_BALL_BLEND_S := 0.15
var _serve_ball_weight := 0.0
var _serve_ball_at := Vector3.ZERO


## The server's bounce ritual, drawn (`AthletesView.serve_ball_override`). Blends by
## wall-clock time, so a headless run (no frame delta) never moves the ball at all.
func _sync_serve_ball() -> void:
	var over: Variant = _athletes.serve_ball_override(state)
	if over != null:
		_serve_ball_at = over
	var step: float = get_process_delta_time() / SERVE_BALL_BLEND_S
	_serve_ball_weight = move_toward(_serve_ball_weight, 1.0 if over != null else 0.0, step)
	if _serve_ball_weight > 0.0:
		_ball_view.position = _ball_view.position.lerp(_serve_ball_at, _serve_ball_weight)


func _sync_views() -> void:
	var train := _depot_train()
	if train != null:
		var muted: bool = _audio == null or _audio.port == null or _audio.port.is_muted()
		train.sync_audio(_paused or _replay_active, muted)
	if state == null:
		return
	# UIR-22: the views only exist when the models were loaded — `harness_mode()` and
	# the headless lanes run without them (`load_models == false`), and every line below
	# writes through `_ball_view`/`_land_ring`. Without this guard the harness path,
	# which still calls `start_match()` and `rematch()`, raised "Invalid assignment of
	# property or key 'position' ... on a base object of type 'Nil'" on every start.
	if _ball_view == null:
		return
	var ball = state.ball
	# Every position comes from the live state (this section's own header) — and during
	# a playback the live state IS the frame at the cursor (`_replay_apply`), which is
	# what draws the recorded ball (`js/main.js:1347-1356`).
	_ball_view.position = Court.world_pos(ball.x, ball.y, ball.z)
	var pulse: float = 1.0 + clampf(float(ball.bouncePulse), 0.0, 1.0) * 0.9
	_ball_view.scale = Vector3(pulse, pulse, pulse)
	_sync_ball_cues(ball)
	var ring: float = float(ball.landRing)
	_land_ring.visible = ring > 0.0
	if _land_ring.visible:
		_land_ring.position = Court.world_pos(ball.x, ball.y, 0.5)
		var ring_scale: float = 1.0 + (1.0 - ring) * 4.0
		_land_ring.scale = Vector3(ring_scale, ring_scale, ring_scale)

	# Follow the actual selected athlete; display geometry never changes reach.
	if _active_ring != null:
		var active = state.active_player()
		# The ring and the pin are the `indicators` component: informational, so they
		# follow the profile exactly as the HUD's own panels do. The component is
		# folded into `shown` here, which is what this every-frame rewrite has to
		# respect — a refresh must never re-show a disabled component.
		var shown: bool = bool(state.running) and not finished and active != null \
			and _ui_component_on("indicators")
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
		_target_ring.visible = bool(target.get("active", false)) and _ui_component_on("indicators")
		if _target_ring.visible:
			_target_ring.position = Court.world_pos(float(target.get("x", 0.0)), float(target.get("y", 0.0)), 0.6)
			var metres: float = Court.PX_TO_M * float(target.get("r", 1.0))
			_target_ring.scale = Vector3(metres, metres, 1.0)

	# The court timing presentation: the ring, the words and the two bars, from the
	# same live state. Placed BEFORE the athletes' early return below, so a frame with
	# rigs (the playable build) syncs it exactly as a frame without them does.
	if _timing_marks != null:
		var preparation := Sim.evaluate_shot_quality(state, state.active_player(), {
			"charge": state.shotCharge, "aim": state.shotAim, "variant": state.shotIntent,
		})
		_timing_marks.update(state, finished, preparation)

	# The four athletes. The rigs own their own position, facing, gait, stroke and
	# racket (`game/athletes_view.gd`); only the capsule fallback is moved here.
	if _athletes != null and _athletes.spawn_rigs > 0:
		_athletes.sync(state)
		_sync_serve_ball()
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
# Court timing marks: the module's own report and seam
# ---------------------------------------------------------------------------

## The court timing module this shell created and mounted (`_build_scene`), whose
## `update` places the marks every frame. The tests and the capture cross this seam
## rather than a private variable of this file.
func court_timing_marks():
	return _timing_marks


## What the last frame drew -- the module's own report, forwarded for the tests, the
## capture's marker lines and the evidence.
func timing_report() -> Dictionary:
	return _timing_marks.report() if _timing_marks != null else {}


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
				if _hud != null:
					_hud.refresh(state, meta)
				_refresh_ui(state, meta)
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
					_timing_marks.set_muted(true)
					_timing_marks.update(state, finished)
					await _save_frame("%s/%s" % [out_dir, ab])
					_timing_marks.set_muted(false)
					_timing_marks.update(state, finished)
					print("CAPTURE_AB file=%s timing_hidden=true tick=%d" % [ab, ticks])
				_capture_index += 1
		if _hud != null:
			_hud.refresh(state, meta)
		_refresh_ui(state, meta)
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
## its backdrop and its scenery — plus the arena's own values in the simulation
## state. The enumeration is the WHOLE library (`Arena.all_ids()`: the frozen nine,
## then the world five), so a world arena is captured like any other; the frames
## land side by side in `res://game/out/` and are TRACKED evidence — this path is
## only re-run deliberately. Deliberately ONE engine run for all of them: this host
## allows a single Godot process at a time and each software-rendered start-up is
## expensive.
func _run_arena_capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out_dir := "res://game/out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# Every arena this build OFFERS, through the config's own build-aware lists:
	# the frozen nine (`Arena.ids()`, the roster order) plus — in a full build
	# only — the five world arenas (port additions, `selectable_world_arenas()` is
	# empty in a demo, and a demo must not render a court it cannot offer).
	# `Arena.all_ids()` is the library's whole list; the capture enumerates the
	# same ids in a full build and stays consistent with the demo's content rule.
	var want: Array = []
	for id in Arena.ids():
		want.append(String(id))
	for row in Config.selectable_world_arenas():
		want.append(String((row as Dictionary)["id"]))
	var written := 0
	for id in want:
		if not set_arena(String(id)):
			push_error("arena capture: could not build arena '%s'" % id)
			continue
		_sync_views()
		if _hud != null:
			_hud.refresh(state, meta)
		_refresh_ui(state, meta)
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
		_refresh_ui(state, meta)
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
	# else", which is the mistake the marker line above exists to prevent. The lines
	# are the court timing module's (`capture_lines`), which is where the marks are.
	if _timing_marks != null:
		for line in _timing_marks.capture_lines(get_viewport().get_camera_3d()):
			print(line)
	var err := img.save_png(path)
	print("CAPTURE_SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])


# ---------------------------------------------------------------------------
# Player-facing controls that are not the game's input struct
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	# The pause card's stick monitor, while it is open: the overlay's own handler
	# takes the four stick axes and the mount consumes them, so the same motion
	# cannot also drive the match (`overlay.handle_joypad_motion`, UIR-20 recipe).
	if _pause_overlay != null and _pause_overlay.is_open() and event is InputEventJoypadMotion:
		if _pause_overlay.handle_joypad_motion(event as InputEventJoypadMotion):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("padel_pause"):
		# UIR-27's step 0 (`js/main.js:2606-2609`): while a replay is up, ESC stops the
		# replay instead of pausing. The rung is FIRST and outside the `_pause_overlay`
		# arm below, so the harness construction (no overlay) walks the same hierarchy
		# the playable one does.
		if _replay_active:
			stop_replay()
		# A live drill ends here, exactly as the browser's drill screen leaves
		# through a key: `end_drill` closes the session with the reference's own
		# grading and persists the record (improvement only).
		elif session != null and session.mode == "drill" and not finished:
			end_drill()
		# Finished: escape leaves the match. In play: escape pauses.
		elif finished:
			_leave_match()
		elif _pause_overlay != null:
			# UIR-22: the playable path's ESC is the overlay's own five-step
			# hierarchy (`js/main.js:2607-2614`) — step 4 resumes, step 5 pauses,
			# steps 0-3 close what is open — and every rung that flips the flag does
			# it through the seam above, so `_reset_transient_input` runs once.
			_pause_overlay.back()
		else:
			# The ported path, unchanged: ESC toggles the flag in one place and both
			# ported overlays read it.
			set_match_paused(not _paused)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu_quit"):
		_leave_match()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_R and (event as InputEventKey).pressed:
		# `r` is the browser's replay key (`js/main.js:2532`, `:2616-2626`): in play it
		# toggles the replay, and `toggle_replay()` refuses it while the card is up or
		# the match is over. It no longer restarts the match — that interim behaviour is
		# retired; `rematch()` keeps its own callers (the card's rematch row, the result
		# route).
		get_viewport().set_input_as_handled()
		toggle_replay()


## The pause card's navigation, on the frame path: consumed here (before the engine's
## `ui_*` walk) while the card is open, and nowhere else. A key or a button the model
## does not own falls through to the engine, so the focused Button still answers
## confirm and the OS keeps its own bindings.
##
## THE PAD'S DIRECTIONS ARE ONE NAVIGATOR, NOT TWO. The card's focus is moved by the
## model, polled once per frame in `_process` (`MenuFocus.poll_pad` — the stick with
## the menu's own deadzone, the D-pad and the buttons by the pad the match selected).
## Godot's built-in walk, though, is driven by the very same events: `ui_up`/`ui_down`/
## `ui_left`/`ui_right` are built-ins whose defaults carry both the left stick and the
## D-pad, so without consuming them here one push moves the focus twice — once by the
## engine's geometry, once by the model's — and the two do not agree. Measured on a
## probe bed, one stick event and one D-pad press each moved a focused control on their
## own. `main_menu.gd:963-968` states the same rule for every menu screen and is why
## this card is the only place the walk used to run.
func _input(event: InputEvent) -> void:
	if training_summary_up() and not _paused and event.is_action("ui_accept"):
		# Pad confirm is sampled by the gameplay input source on release. Do not also
		# activate the focused native Button on press.
		if event is InputEventKey and event.is_pressed() and not event.is_echo() and _training_armed:
			_mode_hud.activate_training_action()
		get_viewport().set_input_as_handled()
		return
	if _audio != null and _audio.ost != null and (event is InputEventJoypadButton or event is InputEventKey):
		if (event is InputEventKey or _input_source == null or _input_source.device == InputSource.NO_DEVICE or event.device == _input_source.device) and _audio.ost.handle_skip(event):
			get_viewport().set_input_as_handled()
			return
	# Options (PS5) / Menu (Xbox) always use the pause route, even with HUD hidden.
	if state != null and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		var pause_event := InputEventAction.new()
		pause_event.action = &"padel_pause"
		pause_event.pressed = true
		_unhandled_input(pause_event)
		get_viewport().set_input_as_handled()
		return
	# Clean mode rides the PRE-GUI path. A left double-click over any HUD control with
	# `MOUSE_FILTER_STOP` is consumed by that control before `_unhandled_input` ever
	# runs, so the gesture has to be answered here, before the engine's GUI walk.
	# `_clean_mode_event` returns false while the pause card is open, so the card keeps
	# every press it owns; the event is consumed here so a pad View cannot also
	# reach the InputMap's `padel_pause` below (`_unhandled_input`).
	if state != null and _clean_mode_event(event):
		get_viewport().set_input_as_handled()
		return
	if _pause_overlay == null or not _pause_overlay.is_open():
		return
	if _pause_nav(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		# The CONTROLLER tab's dots take the stick from the event (the overlay's own
		# `_input` handler); the event is then swallowed so the same motion cannot
		# also walk the focus, which the model has already done from its own poll.
		_pause_overlay.handle_joypad_motion(event as InputEventJoypadMotion)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed and _pause_back_button(button):
			# The pad's back, on the card's own five-step return: the same rung the
			# keyboard's ESC and the pad's Start reach (`PauseOverlay.back`).
			_pause_overlay.back()
			get_viewport().set_input_as_handled()
			return
		if button.pressed and _pause_direction_button(button):
			# The D-pad: the model's, from its own poll (the button stays held across
			# frames, which is what the model's first-repeat/next-repeat clock reads).
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


# ---------------------------------------------------------------------------
# In-match UI visibility: the profile, its seams and the restore hint
#
# THE SEAM IS THE PROFILE. `_hud_hidden` (clean mode) is now the special case of a
# profile whose six components are all off — every legacy seam below still answers,
# and the gesture that toggles it restores the exact profile the player had rather
# than forcing `all` back. The shipping HUD is handed the whole profile
# (`Hud.set_component_visibility`) and hides its own named panels; the world-space
# marks and the timing presentation, which no HUD panel owns, follow `indicators`
# here in `_apply_hud_visibility` and `_sync_views`.
# ---------------------------------------------------------------------------

## True while the informational overlay is hidden for a clean view of the court.
func is_hud_hidden() -> bool:
	return _hud_hidden


## The profile in force, one entry per `UI_COMPONENTS` entry. A copy: the caller
## reads it, it does not write through it (`set_ui_component` is the door).
func set_camera_preset(id: String) -> bool:
	if id not in ["default", "immersive", "tactical", "broadcast", "courtside"] or _cam == null:
		return false
	Court.apply_camera(_cam, id)
	Config.camera_preset = id
	ModesSave.save_pref(Config.save_store(), "cameraPreset", id)
	return true


func ui_visibility_snapshot() -> Dictionary:
	var out := {}
	for id in UI_COMPONENTS:
		out[id] = _ui_component_on(String(id))
	return out


## The canonical component ids, in the contract's order.
func ui_components() -> Array:
	return UI_COMPONENTS.duplicate()


## The four preset ids, in the order the pause tab lists them.
func ui_preset_ids() -> Array:
	return UI_PRESET_IDS.duplicate()


## The locale id the pause tab shows for a component / for a preset. The profile's
## own vocabulary lives with the profile, not with the tab.
func ui_component_label(id: String) -> String:
	return String(UI_COMPONENT_LABELS.get(id, ""))


func ui_preset_label(id: String) -> String:
	return String(UI_PRESET_LABELS.get(id, ""))


## One component's own state, read by the pause tab and the HUD-facing passes.
func is_ui_component_visible(id: String) -> bool:
	return _ui_component_on(id)


## The preset the profile is EXACTLY, or "" when a toggle has moved it off every
## preset (the contract's "changing a toggle that no longer exactly matches a
## preset leaves no preset selected").
func ui_preset_id() -> String:
	var now := ui_visibility_snapshot()
	for id in UI_PRESET_IDS:
		if _ui_profiles_equal(now, UI_PRESET_MAPS[id]):
			return String(id)
	return ""


## One component on or off. Unknown ids are refused, never silently absorbed.
func set_ui_component(id: String, visible: bool) -> bool:
	if not UI_COMPONENTS.has(id):
		return false
	var next := ui_visibility_snapshot()
	next[id] = visible
	_apply_ui_profile(next)
	return true


## One of the four presets, by id. The map applied is the preset's exact map.
func set_ui_preset(id: String) -> bool:
	if not UI_PRESET_MAPS.has(id):
		return false
	_apply_ui_profile((UI_PRESET_MAPS[id] as Dictionary).duplicate())
	return true


## The explicit state behind `toggle_hud_hidden`, so a test drives the same seam a
## player's gesture does. `true` is the `clean` preset; `false` restores the exact
## last non-clean profile (the default `all` before any other profile was chosen).
## Returns the state now in force.
func set_hud_hidden(hidden: bool) -> bool:
	if hidden:
		_apply_ui_profile((UI_PRESET_MAPS["clean"] as Dictionary).duplicate())
	else:
		_apply_ui_profile(_restore_profile())
	return _hud_hidden


## The toggle the left double-click and the pad's View ride. Returns the new
## state.
func toggle_hud_hidden() -> bool:
	return set_hud_hidden(not _hud_hidden)


## A new match sees the full view: the profile and its memory go back to `all`.
## Every reset path calls this (`start_match`, `_adopt_session`).
func _reset_ui_visibility() -> void:
	_ui_visibility = {}
	_ui_last_non_clean = {}
	_hud_hidden = false


## The profile to restore: the last non-clean one, or the `all` default when the
## player has never left the full view.
func _restore_profile() -> Dictionary:
	if _ui_last_non_clean.is_empty():
		return (UI_PRESET_MAPS["all"] as Dictionary).duplicate()
	return _ui_last_non_clean.duplicate()


## The one writer of the profile: remembers what it is leaving, stores the new
## map, derives `_hud_hidden` from it and re-applies every surface.
func _apply_ui_profile(next: Dictionary) -> void:
	var before := ui_visibility_snapshot()
	if not _ui_profile_is_clean(before):
		_ui_last_non_clean = before
	var stored := {}
	for id in UI_COMPONENTS:
		stored[id] = bool(next.get(id, true))
	_ui_visibility = stored
	# A profile that is not fully clean is also the newest thing to restore to.
	if not _ui_profile_is_clean(stored):
		_ui_last_non_clean = stored.duplicate()
	_hud_hidden = _ui_profile_is_clean(stored)
	_apply_hud_visibility()
	# The world-space marks and the timing presentation are rewritten every frame by
	# `_sync_views`; re-running it here makes the seam's effect immediate as well as
	# persistent (the profile, not a one-shot write, is what survives the refresh).
	_sync_views()


## The profile's own default: an entry the map does not carry is ON (the full view).
func _ui_component_on(id: String) -> bool:
	return bool(_ui_visibility.get(id, true))


func _ui_profile_is_clean(profile: Dictionary) -> bool:
	for id in UI_COMPONENTS:
		if bool(profile.get(id, true)):
			return false
	return true


## Exact equality over the six components, so `ui_preset_id()` cannot report a
## preset for a profile that merely resembles it.
func _ui_profiles_equal(a: Dictionary, b: Dictionary) -> bool:
	for id in UI_COMPONENTS:
		if bool(a.get(id, true)) != bool(b.get(id, true)):
			return false
	return true


## Writes the profile onto the surfaces the controller owns. The shipping HUD is
## handed the profile itself (it hides its own panels — never its root, which the
## hint's independence depends on); the legacy column, which has no component seam,
## keeps the whole-surface behaviour proportionally.
func _apply_hud_visibility() -> void:
	if _ui_hud != null:
		_ui_hud.call("set_component_visibility", ui_visibility_snapshot())
	if _hud != null:
		_hud.visible = not _hud_hidden
	# The ported mode strip rides `_mode_hud` in BOTH UI modes, but a recreated run
	# hides it on purpose (the recreated HUD carries the facts): showing it when
	# clean mode ends would be exactly the regression the mount policy forbids. It is
	# the `guidance` component where it does show.
	if _mode_hud != null:
		_mode_hud.visible = training_summary_up() or (_ui_component_on("guidance") and (not _ui_new or (session != null and session.mode == "drill")))
	# The court timing presentation (the ring, the window, the two bars, the advice
	# word and the verdict) through the module's own mute seam — the same flag the
	# A/B capture flips.
	if _timing_marks != null:
		_timing_marks.set_muted(not _ui_component_on("indicators"))
		_timing_marks.preparation_enabled = _ui_component_on("preparation")
	# The hint's visibility is a function of the profile and the card, so it is
	# re-derived on every pass that repaints the surfaces (one writer, no drift).
	_apply_ui_hint()


## The restore hint: one small chip, bottom-centre, and it is shown only in clean
## live play. Every edge that can change either half of that condition re-runs this
## (`_apply_ui_profile` on a profile change, `set_match_paused` on the card), so it
## is never left on screen after a restore or behind an open card.
func _apply_ui_hint() -> void:
	if _restore_hint == null:
		return
	# The text is re-resolved on every pass, so a language flip cannot leave the
	# hint reading the other locale's string.
	var label := _restore_hint.get_node_or_null("HintChip/HintLabel") as Label
	if label != null:
		label.text = _ui_hint_text()
	_restore_hint.visible = _hud_hidden and not _is_pause_card_open()


## True while the pause card is up: the hint belongs to live play, and a press that
## opens the card is exactly what the contract says must hide it.
func _is_pause_card_open() -> bool:
	return _paused or (_pause_overlay != null and bool(_pause_overlay.call("is_open")))


## The hint's own text, through the locale layer. Loaded on first use rather than
## preloaded: a legacy run mounts no hint, and its object count is measured.
func _ui_hint_text() -> String:
	if _ui_strings == null:
		_ui_strings = load("res://src/ui/UiStrings.gd")
	return String(_ui_strings.call("t", "uiHintRestore"))


## The hint's own node tree: a full-rect, input-transparent root carrying one chip
## anchored to the bottom centre. Every node is `MOUSE_FILTER_IGNORE`, because the
## hint sits over live play and must not eat a click.
func _build_restore_hint() -> Control:
	var root := Control.new()
	root.name = "UiRestoreHint"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var chip := PanelContainer.new()
	chip.name = "HintChip"
	chip.theme_type_variation = &"ServeChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.anchor_left = 0.5
	chip.anchor_right = 0.5
	chip.anchor_top = 1.0
	chip.anchor_bottom = 1.0
	chip.offset_left = 0.0
	chip.offset_right = 0.0
	chip.offset_top = -UI_HINT_BOTTOM
	chip.offset_bottom = -UI_HINT_BOTTOM
	chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(chip)
	var label := Label.new()
	label.name = "HintLabel"
	label.theme_type_variation = &"HudLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _ui_hint_text()
	chip.add_child(label)
	return root


## Double-click and View toggle clean mode. Options/Menu belongs to pause.
## A press while the pause card is open belongs to the card and is left alone.
func _clean_mode_event(event: InputEvent) -> bool:
	if _pause_overlay != null and _pause_overlay.is_open():
		return false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.double_click and mouse.button_index == MOUSE_BUTTON_LEFT:
			toggle_hud_hidden()
			return true
		return false
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed and button.button_index == JOY_BUTTON_BACK:
			toggle_hud_hidden()
			return true
	return false


# ---------------------------------------------------------------------------
# UIR-27: the replay seam — the recorded point, played back over a frozen match.
# The contract is `evidence/uir-27-replay.log` §Seam; `tests/ui/replay_audit.gd`
# is its consumer.
# ---------------------------------------------------------------------------

## Whether a playback is running. The overlay's whole visibility reads it, together
## with `replay_progress()`, through `bind_seam(self)`.
func replay_active() -> bool:
	return _replay_active


## The cursor, 0-based into `state.replayFrames`.
func replay_index() -> int:
	return _replay_index


## How many frames the record holds right now (0 before the first capture).
func replay_frame_count() -> int:
	return state.replayFrames.size() if state != null else 0


## `(replayIndex + 1) / replayFrames.length` (`js/main.js:1365`), clamped to `[0, 1]`;
## `0.0` with nothing recorded.
func replay_progress() -> float:
	var total := replay_frame_count()
	if total <= 0:
		return 0.0
	return clampf((float(_replay_index) + 1.0) / float(total), 0.0, 1.0)


## The pause the entry recorded — what `stop_replay()` puts back.
func replay_was_paused() -> bool:
	return _replay_was_paused


## Enter the playback. Refused — `false`, nothing touched — unless the match is
## running and the record holds at least two frames (`js/main.js:1390`). Entering
## clears the pause like the reference (`js/main.js:1394-1395`) and REMEMBERS it:
## UIR-27 line 61 keeps the pause for the way out.
func start_replay() -> bool:
	if state == null or finished or _replay_active:
		return false
	if replay_frame_count() < 2:
		return false
	_replay_was_paused = _paused
	if _paused:
		set_match_paused(false)
	_replay_active = true
	_replay_index = 0
	_replay_accum = 0.0
	_replay_done = false
	_tell_pause_card()
	return true


## Idempotent. Restores the pause the entry recorded, so a replay entered from live
## play returns to live play and one entered from the card reopens it (UIR-20's
## `open()` lands on the MATCH tab), then tells the card.
func stop_replay() -> void:
	if not _replay_active:
		return
	_replay_active = false
	_replay_accum = 0.0
	set_match_paused(_replay_was_paused)
	_tell_pause_card()


## The `r` key (`js/main.js:2616-2626`): stop a running replay; refuse while the card
## is open or the match is over; otherwise enter. Returns whether a replay is up
## after the call.
func toggle_replay() -> bool:
	if _replay_active:
		stop_replay()
		return false
	if _paused or finished:
		return false
	return start_replay()


## The card's two readings, told apart (UIR-20's flag split, §3.4 of
## `evidence/uir-27-replay.log`): the PLAYBACK reading feeds `set_replay_active`, so
## ESC's step 0 (`back()`) can never be stale, and the AVAILABILITY reading feeds
## `set_replay_available`, so the card's entry is reachable exactly while a playback
## can start (`start_replay()`'s own gates — `js/main.js:1389-1390`). Called on every
## pause edge and on every entry/exit.
func _tell_pause_card() -> void:
	if _pause_overlay != null:
		_pause_overlay.set_replay_active(_replay_active)
		_pause_overlay.set_replay_available(_replay_can_start())


## The card entry's availability: the gates `start_replay()` itself enforces — a live
## match with at least two recorded frames.
func _replay_can_start() -> bool:
	return state != null and not finished and replay_frame_count() >= 2


## One rendered frame of the playback (`js/main.js:1243-1245`, `:1282`, `:1308-1319`):
## the cursor advances one stored frame per `REPLAY_STEP` of the frame's own delta,
## clamped at the last frame, and `replay_finished` fires once, on the step that first
## reaches it. The frame at the cursor is then applied to the live state, drawn, and
## restored — the simulation never advances, and the HUDs are not refreshed (the
## reference's `syncHud` lives in `drawScene`, which a replay frame never reaches).
func _replay_frame(delta: float) -> Dictionary:
	var total := replay_frame_count()
	if total <= 0:
		stop_replay()
		return {"steps": 0, "accumulator": sim_accumulator, "ticks": ticks}
	_replay_accum += minf(delta, MAX_FRAME_DELTA)
	while _replay_accum >= REPLAY_STEP:
		_replay_accum -= REPLAY_STEP
		if _replay_index < total - 1:
			_replay_index += 1
		if _replay_index >= total - 1 and not _replay_done:
			_replay_done = true
			replay_finished.emit()
	_replay_index = mini(_replay_index, total - 1)
	var saved := _replay_apply(state.replayFrames[_replay_index])
	_sync_views()
	_replay_restore(saved)
	return {"steps": 0, "accumulator": sim_accumulator, "ticks": ticks}


## `applyReplayFrame` (`js/main.js:1319-1330`): the frame's own field sets are written
## onto the live entities so the draw reads ONE state, and every value that was
## overwritten comes back in the returned dict for `_replay_restore`. Exactly the
## reference's set is written — nothing else in the state is touched, which is why the
## parity digest is byte-identical after a playback.
func _replay_apply(frame: Dictionary) -> Dictionary:
	var saved_pads: Array = []
	var pads: Array = frame.get("pads", [])
	for i in REPLAY_PAD_KEYS.size():
		var pad = state.paddle(String(REPLAY_PAD_KEYS[i]))
		var entry: Dictionary = pads[i] if i < pads.size() else {}
		entry = entry.duplicate()
		if not entry.has("staminaEnergy"):
			entry["staminaEnergy"] = 1.0
		var keep := {}
		for field in REPLAY_PAD_FIELDS:
			if not entry.has(field):
				continue
			keep[field] = pad.get(field)
			pad.set(field, entry[field])
		saved_pads.append([pad, keep])
	var ball = state.ball
	var recorded: Dictionary = frame.get("ball", {})
	var keep_ball := {}
	for field in REPLAY_BALL_FIELDS:
		if not recorded.has(field):
			continue
		keep_ball[field] = ball.get(field)
		ball.set(field, recorded[field])
	var keep_keys := {}
	for key in REPLAY_STATE_KEYS:
		if not frame.has(key):
			continue
		keep_keys[key] = state.get(key)
		state.set(key, frame[key])
	return {"pads": saved_pads, "ball": [ball, keep_ball], "keys": keep_keys}


## `restoreReplayFrame` (`js/main.js:1347-1360`): every saved value back, so the live
## match is exactly what it was before the playback started.
func _replay_restore(saved: Dictionary) -> void:
	var saved_pads: Array = saved.get("pads", [])
	for entry in saved_pads:
		var pad = entry[0]
		var keep: Dictionary = entry[1]
		for field in keep:
			pad.set(field, keep[field])
	var ball_entry: Array = saved.get("ball", [])
	if ball_entry.size() == 2:
		var ball = ball_entry[0]
		var keep_ball: Dictionary = ball_entry[1]
		for field in keep_ball:
			ball.set(field, keep_ball[field])
	var keep_keys: Dictionary = saved.get("keys", {})
	for key in keep_keys:
		state.set(key, keep_keys[key])


## A reset is not a pause. `rematch()` — the card's rematch row and the result route
## (no longer the `r` key, which toggles the replay since UIR-27) — rebuilds the match
## through `start_match()`/`_adopt_session()`, and neither of those used
## to touch `_paused`: ESC then R left `_paused == true` with the HUD hint switched
## back to the unpaused text, so the match was frozen for good while the screen said
## it was running (review-2 F-3). Every reset path comes through here. UIR-22: the
## pause card is told as well, because it is the third reader of the same flag.
func _clear_pause() -> void:
	_paused = false
	# `js/main.js:1201-1204`: a new match clears the playback with the pause — a reset
	# is not a replay either.
	_replay_active = false
	_replay_index = 0
	_replay_accum = 0.0
	_replay_done = false
	if _hud != null:
		_hud.set_paused(false)
	if _pause_overlay != null:
		_pause_overlay.set_match_paused(false)
	_pause_pad_seen = false


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
##
## A TRAINING run goes back to the hub THAT STARTED IT (`Config.training_return_scene`):
## the recreated hub is mounted by the menu host, the ported one is its own scene, and both
## write the seam before the match opens.
func to_mode_screen() -> void:
	if session != null and session.mode == "drill":
		training_leave("choose")
		return
	get_tree().change_scene_to_file("res://game/ModeScreen.tscn")


func _leave_match() -> void:
	if session != null:
		to_mode_screen()
	else:
		to_menu()


## The route out, under the name UIR-20's overlay looks for (`seam.leave_match()`;
## the overlay's quit flow calls the seam when the method exists and otherwise
## defers to the host — this is that method). The private `_leave_match()` keeps its
## two destinations: a mode match returns to its mode screen, a quick match to the
## menu.
func leave_match() -> void:
	_leave_match()


## The payload `ResultScreen.enter()` takes, built from the live state and the mode
## session's own facts through UIR-21's builder (`payload_from_state`): the score,
## the four stat rows and the foot figures come from `state`'s own fields — nothing
## is recomputed here and nothing is invented — and the mode facts come from
## `session.report()`, never from a guess about the mode.
func result_payload() -> Dictionary:
	if state == null:
		return {}
	var won := state.result != null and String(state.result.get("winner", "")) == "player"
	var facts := {
		"mode": session.mode if session != null else "quick",
		"arena_id": Config.arena_id(),
		"won": won,
	}
	if session != null:
		var report: Dictionary = session.report()
		var mode := String(report.get("mode", ""))
		if mode != "":
			facts["mode"] = mode
		var arena_id := String(report.get("arena", ""))
		if arena_id != "":
			facts["arena_id"] = arena_id
		facts["season"] = int(report.get("season", 0))
		facts["match"] = int(report.get("match_index", 0))
		facts["awarded"] = report.get("awarded", {})
		if String(report.get("winner", "")) != "":
			facts["won"] = String(report.get("winner", "")) == "player"
		# The rematch button's label follows this flag (UIR-21: `rematch` vs
		# `nextMatch`): a tournament or career match that was WON has a next fixture
		# or the rest of the season waiting, which is what the session has already
		# advanced its bracket/calendar to. A quick match never continues.
		facts["continue_pending"] = bool(facts["won"]) and mode in ["tournament", "career"]
	# Emporio OST: the reward this match paid and the resulting balance, for the result
	# screen's own row. Absent in a harness run (no award) — the screen then shows none.
	if not _economy_award.is_empty():
		facts["reward"] = {
			"awarded": int(_economy_award.get("awarded", 0)),
			"earned": int(_economy_award.get("earned", 0)),
			"breakdown": _economy_award.get("breakdown", {}),
			"balance": int(_economy_award.get("balance", 0)),
			"match_id": String(_economy_award.get("match_id", "")),
			"animate": bool(_economy_award.get("ok", false)) and not bool(_economy_award.get("already", false)) and int(_economy_award.get("awarded", 0)) > 0,
			"already": bool(_economy_award.get("already", false)),
			"ok": bool(_economy_award.get("ok", false)),
		}
	var builder := load("res://src/ui/screens/ResultScreen.gd") as GDScript
	return builder.payload_from_state(state, facts)


## The route a finished match takes when the playable UI is up: record the payload
## for the router host (`Config.pending_result`) and hand the player to the result
## screen, which the host mounts under the `result` id. `dry_run` stops before the
## engine call so an audit can assert the payload in-process — the same shape the
## drill and mode screens use for their own start routes.
func finish_route(dry_run := false) -> Dictionary:
	var payload := result_payload()
	var route := {
		"action": "result",
		"scene": "res://game/Main.tscn",
		"payload_ready": not payload.is_empty(),
	}
	if payload.is_empty():
		return route
	Config.pending_result = payload
	if not dry_run and is_inside_tree():
		get_tree().change_scene_to_file(String(route["scene"]))
	return route


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
