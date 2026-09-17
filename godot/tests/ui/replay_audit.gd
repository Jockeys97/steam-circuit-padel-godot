## replay_audit.gd — UIR-27's contract audit: the recorded buffer, the playback state
## machine, the keys, the pause button and the overlay chrome.
##
## WHAT IT PROVES, and the reference each question comes from:
##
##   1. ACTUAL RECORDED GAMEPLAY. A real point is played through `Match.tscn`'s own
##      controller (`harness_mode()`, `tick_fixed`), the real `scripted_player.gd` input and
##      the ported simulation — and the frames the controller itself captured are what the
##      playback below replays. Nothing here is a hand-written or stub track: every replay
##      assertion feeds on frames the running match produced.
##   2. the buffer (`js/game.js:313-315`, `:334-365`): one frame per sim tick, bounded at
##      `state.replayMax` (720, `state.gd:135`), front-dropped on overflow, restarted at a
##      new point (`js/game.js:3006`) and at match start (`js/main.js:1201`), with the newest
##      frame equal to the live state field for field and each frame carrying the reference's
##      own pad/ball field sets (`js/game.js:1304-1306`).
##   3. playback (`js/main.js:1243-1245`, `:1282`, `:1308-1319`): entering freezes the
##      simulation (`ticks` does not advance), the cursor advances one frame per 1/60 s of
##      rendered-frame delta, clamps at the last frame, `replay_progress()` is
##      `(replayIndex + 1) / total` (`js/main.js:1365`), and the 3D ball drawn during playback
##      is the RECORDED ball — read back from the controller's own `Ball` node.
##   4. restore-equality (`js/main.js:1321-1360`): the state digest (`src/sim/digest.gd`, the
##      parity digest's own sampler) is byte-identical before and after a full playback.
##   5. stop: the pre-replay pause state comes back (both entry paths: from live play and
##      from the pause card, `js/main.js:2238-2241`), the live simulation resumes on the next
##      frame, and the overlay hides.
##   6. the keys: `r` in play starts a replay and NO LONGER restarts the match (the port's
##      retired interim behaviour, asserted against a restart's own signature), `r` in replay
##      stops it, `r` while the pause card is up is refused (`js/main.js:2616-2626`), and ESC
##      in replay stops the replay instead of pausing (`js/main.js:2606-2609`, the hierarchy's
##      step 0).
##   7. UIR-20's button: `set_replay_active(true)` enables RIGUARDA PUNTO, clears its disabled
##      reason and lets `replay()` emit `replay_requested`.
##   8. the overlay (`js/main.js:1362-1381`): hidden until a replay is up, geometry at
##      `1280/960` of the reference's canvas pixels, the two strings in both locales, the
##      fill clamped to the track, no focusable node, no `SceneTree.paused`, no prose literal.
##
## WHAT IT DOES NOT DO, and says so rather than pretending:
##
##   - no Godot process ran this file in the UIR-27 wave (the wave's dispatch forbids it);
##     the integration owner runs it, and the acceptance command is in
##     `evidence/uir-27-replay.log` §Run;
##   - the controller half of the seam may not be in the tree yet. Every seam method is
##     checked by name first; when one is missing, the checks that need it do not run and the
##     run is RED with the missing names as the reason — a missing seam can never read as a
##     pass, and the red list IS the integration checklist (`evidence/uir-27-replay.log`
##     §Seam, which carries the same contract in prose);
##   - the keys are injected through the engine's own input pipeline
##     (`Input.parse_input_event`), not pressed on hardware;
##   - the ring's front-drop is exercised at a reduced capacity (`state.replayMax = 240`,
##     §buffer): the shipped value stays asserted as 720, and the reduction is named in the
##     log rather than hidden.
##
## THIS AUDIT WRITES ONLY TO A TEMP DIR (`user://uir27-replay-audit`) and removes it again;
## the real `user://save` is never touched.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const OverlayClass := preload("res://src/ui/screens/ReplayOverlay.gd")
const OverlayScene := preload("res://src/ui/screens/ReplayOverlay.tscn")
const PauseOverlayScene := preload("res://src/ui/screens/PauseOverlay.tscn")
const Sim := preload("res://src/sim/sim.gd")
const Digest := preload("res://src/sim/digest.gd")
const Court := preload("res://game/court.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const Config := preload("res://game/match_config.gd")
const SaveStore := preload("res://src/save/save_store.gd")

const MATCH_SCENE := "res://game/Match.tscn"
const OVERLAY_PATH := "res://src/ui/screens/ReplayOverlay.gd"
const TEMP_DIR := "user://uir27-replay-audit"
const FRAME := Vector2(1280.0, 720.0)
const TICK := 1.0 / 120.0
## The playback cadence: `while (replayAccum >= 1 / 60)` (`js/main.js:1315`).
const REPLAY_STEP := 1.0 / 60.0
## `replayMax: 720` (`js/game.js:314`, `state.gd:135`).
const REFERENCE_MAX := 720
## The reduced capacity the front-drop is exercised at. The value itself is this audit's
## instrumentation, named in the log; the shipped `replayMax` stays 720 and is asserted.
const RING_TEST_MAX := 240
## A point cannot end within this many ticks of `prepareServe` (the serve timer alone is
## 0.9 s = 108 ticks), so a tick window this wide proves "one frame per tick" without a
## point reset landing inside it.
const SAFE_WINDOW := 60
const SETTLE_FRAMES := 2
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const FORBIDDEN_PATTERNS := ["SceneTree.paused", "get_tree().paused", "paused = true", "paused = false"]
## The reference's own snapshot field sets (`js/game.js:1304-1306`).
const PAD_FIELDS := ["x", "y", "swing", "swingSide", "motion", "charge", "runPhase",
	"actionPose", "actionIntent", "moveRatio"]
const BALL_FIELDS := ["x", "y", "z", "vx", "vy", "vz", "spin", "topspin", "backspin",
	"shotType", "serveInFlight", "serveTouchedNet", "bouncePulse", "landRing", "hitFlash",
	"hitPulse", "trail"]
## The seam the controller must expose: the ticket's proposed four
## (`UIR-27-replay.md` microstep 2: `start_replay() -> bool`, `replay_active() -> bool`,
## `replay_progress() -> float`, `replay_finished`) plus `stop_replay()` — the exit paths
## have to call something, and the audit calls it directly. The signal is checked where it
## is used. A missing name is a red check, never a skipped pass.
const SEAM_REQUIRED := ["start_replay", "stop_replay", "replay_active", "replay_progress"]
## Readouts the audit uses when they are there and names in a note when they are not; the
## cursor and the count are readable through `replay_progress()` and `state.replayFrames`.
const SEAM_SOFT := ["replay_index", "replay_frame_count", "toggle_replay", "replay_was_paused"]

var _bot: RefCounted
var _store: RefCounted
var _overlay: Control
var _pause_overlay: Control
var _skipped_live: Array = []
## One note per run names the optional readouts the controller does not carry, so the log
## says which shape the seam took rather than leaving a silent branch.
var _soft_missed: bool = false


## The controller's own capture/playback seam, as this audit reads it.
class FakeSeam extends RefCounted:
	var active := false
	var index := 0
	var total := 0

	func replay_active() -> bool:
		return active

	func replay_progress() -> float:
		return 0.0 if total <= 0 else float(index + 1) / float(total)


## A seam that answers the visibility question and nothing else: the overlay must record
## the missing reader and never paint a guessed bar.
class HalfSeam extends RefCounted:
	func replay_active() -> bool:
		return true


func _initialize() -> void:
	var audit := AuditBase.new("uir27_replay")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	Config.save_dir = TEMP_DIR
	_bot = ScriptedPlayer.new()
	_store = SaveStore.new(TEMP_DIR)
	audit.check_eq(String(Config.save_dir), TEMP_DIR, "replay/this_audit_writes_only_to_its_temp_dir")

	# A frame to give the overlay a real size: the mission's own 1280x720, the frame every
	# capture in `evidence/` renders at, forced here so the pixel checks mean something.
	root.size = Vector2i(int(FRAME.x), int(FRAME.y))
	var frame := Control.new()
	frame.name = "ReplayAuditFrame"
	frame.size = FRAME
	root.add_child(frame)
	_overlay = OverlayScene.instantiate()
	frame.add_child(_overlay)
	_pause_overlay = PauseOverlayScene.instantiate()
	_pause_overlay.set_store(_store)
	frame.add_child(_pause_overlay)
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_eq(_overlay.size, FRAME, "replay/the_audit_frame_is_the_missions_own_1280x720")

	await _overlay_chrome(audit)
	await _reference_semantics(audit)
	await _recording(audit)
	await _playback(audit)
	await _stop_and_pause_restore(audit)
	await _keys(audit)
	await _pause_button(audit)
	await _overlay_seam(audit)
	await _localization(audit)
	_static_scan(audit)

	audit.not_ported("engine/run", "no Godot process ran this file in the UIR-27 wave (the wave's dispatch forbids it): the tally below is what the file asserts, and the acceptance command in evidence/uir-27-replay.log is the run that is owed")
	audit.not_ported("input/physical_keyboard", "the r/ESC paths are injected through Input.parse_input_event, the engine's own pipeline, not pressed on hardware")
	if not _skipped_live.is_empty():
		audit.note("the controller seam was absent, so these check groups did not run: %s — every name is in §Seam of evidence/uir-27-replay.log" % JSON.stringify(_skipped_live))
	audit.report("overlay: hidden=%s banner=%.2fpx bar=%.2fpx inset=%.2fpx" % [
		str(not _overlay.is_active()), OverlayClass.BANNER_H, OverlayClass.BAR_H, OverlayClass.INSET])


# ---------------------------------------------------------------------------
# 1. The overlay's own facts (no controller needed)
# ---------------------------------------------------------------------------

func _overlay_chrome(audit: AuditBase) -> void:
	var report: Dictionary = _overlay.report()
	audit.check_eq(report.get("active"), false, "replay/the_overlay_starts_hidden")
	audit.check_eq(_overlay.is_visible_in_tree(), false, "replay/nothing_is_painted_before_a_replay")
	audit.check_ne(_overlay.theme, null, "replay/the_scene_mounts_the_theme")
	audit.check_eq(_overlay.capture_states(), [OverlayClass.CAPTURE_REPLAY], "replay/the_one_capture_state_is_declared")
	audit.check_eq(_overlay.apply_capture_state("nope"), false, "replay/an_unknown_capture_state_is_refused")
	audit.check_eq(_overlay.focus_controls(), [], "replay/the_overlay_carries_no_focusable_node")
	audit.check_eq(_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "replay/the_overlay_swallows_no_input")
	audit.check_eq(OverlayClass.FRAME_SCALE, 1280.0 / 960.0, "replay/the_canvas_to_frame_scale_is_the_one_conversion")

	# The named nodes the mount and the captures address.
	for name in ["ReplayBanner", "ReplayBannerLabel", "ReplayExitHint", "ReplayProgress",
			"ReplayProgressTrack", "ReplayProgressFill"]:
		audit.check_ne(_overlay.find_child(String(name), true, false), null, "replay/the_%s_node_exists" % name)

	# Geometry: the reference's canvas pixels read at this frame's scale (`js/main.js:1366-1379`).
	var banner: Rect2 = _overlay.banner_rect()
	var bar: Rect2 = _overlay.bar_rect()
	audit.check_eq(is_equal_approx(banner.size.y, 40.0 * (1280.0 / 960.0)), true, "replay/the_banner_is_40_canvas_px_read_at_this_scale")
	audit.check_eq(is_equal_approx(bar.size.y, 8.0 * (1280.0 / 960.0)), true, "replay/the_bar_is_8_canvas_px_read_at_this_scale")
	audit.check_eq(is_equal_approx(banner.position.y, 0.0), true, "replay/the_banner_sits_on_the_top_edge")
	audit.check_eq(is_equal_approx(bar.position.y + bar.size.y, FRAME.y), true, "replay/the_bar_sits_on_the_bottom_edge")
	audit.check_eq(is_equal_approx(banner.size.x, FRAME.x), true, "replay/the_banner_spans_the_frame")
	audit.check_eq(is_equal_approx(bar.size.x, FRAME.x), true, "replay/the_bar_spans_the_frame")
	var label := _overlay.find_child("ReplayBannerLabel", true, false) as Label
	var hint := _overlay.find_child("ReplayExitHint", true, false) as Label
	audit.check_eq(is_equal_approx(label.global_position.x, 14.0 * (1280.0 / 960.0)), true, "replay/the_banner_text_starts_14_canvas_px_in")
	audit.check_eq(is_equal_approx(FRAME.x - (hint.global_position.x + hint.size.x), 14.0 * (1280.0 / 960.0)), true, "replay/the_exit_hint_ends_14_canvas_px_in")
	audit.check_eq(label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, "replay/the_banner_text_is_centred_in_the_strip")
	audit.check_eq(hint.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "replay/the_exit_hint_is_right_aligned")
	audit.check_eq(label.get_theme_font_size("font_size"), OverlayClass.BANNER_FONT_PX, "replay/the_banner_font_is_the_references_12px_read_at_this_scale")
	audit.check_eq(hint.get_theme_font_size("font_size"), OverlayClass.EXIT_FONT_PX, "replay/the_hint_font_is_the_references_11px_read_at_this_scale")

	# The state walk: never painted without a replay, the fill clamped to the track.
	audit.check_eq(_overlay.fill_ratio(), 0.0, "replay/an_idle_overlay_paints_no_fill")
	_overlay.set_replay(true, 0.25)
	audit.check_eq(_overlay.is_visible_in_tree(), true, "replay/set_replay_shows_the_chrome")
	audit.check_eq(absf(_overlay.fill_ratio() - 0.25) <= 0.01, true, "replay/a_quarter_of_the_point_paints_a_quarter_of_the_bar")
	_overlay.set_replay(true, 4.0)
	audit.check_eq(absf(_overlay.fill_ratio() - 1.0) <= 0.01, true, "replay/overflow_clamps_to_the_full_track")
	_overlay.set_replay(true, -2.0)
	audit.check_eq(_overlay.fill_ratio(), 0.0, "replay/a_negative_progress_clamps_to_empty")
	audit.check_eq(_overlay.banner_text(), String(OverlayClass.BANNER_GLYPH) + String.chr(32) + UiStrings.t("replay"), "replay/the_banner_carries_the_reference_glyph_and_word")
	audit.check_eq(_overlay.exit_hint_text(), UiStrings.t("replayExit"), "replay/the_hint_carries_the_reference_key")
	_overlay.set_replay(false)
	audit.check_eq(_overlay.is_visible_in_tree(), false, "replay/hiding_the_replay_hides_the_chrome")

	# With no seam the overlay cannot invent anything.
	audit.check_eq(_overlay.refresh(), false, "replay/without_a_seam_refresh_paints_nothing")
	audit.check_eq(_overlay.is_active(), false, "replay/without_a_seam_the_overlay_stays_hidden")
	audit.check_eq(_overlay.apply_capture_state(OverlayClass.CAPTURE_REPLAY), false, "replay/a_capture_without_a_replay_is_refused")
	# `paused` is a property of the SceneTree INSTANCE; the class reference is not an
	# object, so `SceneTree.paused` is not an evaluable expression in Godot 4.7
	# ("Invalid access to property or key 'paused' on a base object of type 'SceneTree'")
	# — and this script IS the tree, so the check reads it on itself.
	audit.check_eq(paused, false, "replay/the_tree_pause_is_not_touched")
	var misses: Array = _overlay.palette_misses()
	var stray: Array = []
	for key in misses:
		if not OverlayClass.palette_keys().has(String(key)):
			stray.append(String(key))
	audit.check_eq(stray, [], "replay/every_palette_miss_is_a_key_this_overlay_declares")
	if not misses.is_empty():
		audit.note("palette keys the theme does not carry yet, requested in evidence/uir-27-replay.log: %s" % JSON.stringify(misses))


# ---------------------------------------------------------------------------
# 2. The reference's own numbers, extracted (`js/game.js`, `js/main.js`)
# ---------------------------------------------------------------------------

func _reference_semantics(audit: AuditBase) -> void:
	var node := _new_match()
	var state = node.state
	audit.check_true(state.get("replayFrames") is Array, "replay/the_state_carries_the_record_field")
	audit.check_eq(int(state.replayMax), REFERENCE_MAX, "replay/the_record_is_bounded_at_the_references_720")
	audit.check_eq(state.replayFrames.size(), 0, "replay/a_fresh_match_starts_with_an_empty_record")
	audit.check_eq(REPLAY_STEP, 1.0 / 60.0, "replay/the_playback_cadence_is_1_60s")
	audit.check_eq(TICK, 1.0 / 120.0, "replay/the_capture_cadence_is_the_sim_tick")
	audit.report("the reference's buffer: replayMax=%d, capture 1/120 s, playback 1/60 s (js/game.js:314, :338-364, js/main.js:1315)" % REFERENCE_MAX)
	_drop(node)


# ---------------------------------------------------------------------------
# 3. Actual recorded gameplay — the buffer, on frames the running match produced
# ---------------------------------------------------------------------------

func _recording(audit: AuditBase) -> void:
	var node := _new_match()
	var need := _needs(node, ["start_replay", "replay_active"])
	if need != "":
		_skip_live(audit, "recording", need)
		_drop(node)
		return

	# A real point, played by the real scripted player against the real AI. The record is
	# read fresh after every tick block: the reference's reset REPLACES the array
	# (`state.replayFrames = []`, `sim.gd:248`), so a held reference goes stale.
	_tick_n(node, 240)
	var frames := _record(node)
	audit.check_ge(frames.size(), 1, "replay/playing_records_frames")
	audit.check_le(frames.size(), REFERENCE_MAX, "replay/the_record_never_exceeds_its_bound")
	if _has(node, "replay_frame_count"):
		audit.check_eq(int(node.replay_frame_count()), frames.size(), "replay/the_count_readout_matches_the_record")
	else:
		_seam_soft_miss(node, audit)

	# The shapes: the reference's own field sets (`js/game.js:1304-1306`, `:338-365`).
	var shape_problem := _frame_problem(node) if frames.size() > 0 else "no frame to check"
	audit.check_eq(shape_problem, "", "replay/every_frame_carries_the_references_pad_and_ball_fields")
	var moved := _moved_problem(frames)
	audit.check_eq(moved, "", "replay/frames_are_copies_that_move_with_the_match")
	if frames.size() > 0:
		audit.report("recorded %d frames in 240 ticks (%.1f KB by JSON encoding of the first frame)" % [
			frames.size(), float(JSON.stringify(frames[0]).length()) / 1024.0])

	# The newest frame is the tick that produced it. The check lands on a CAPTURING tick:
	# the reference returns before the capture on a point-pause tick and on the tick a
	# bounce scores (`js/game.js:2999-3009`, `:3328-3341`), so a tick is played, the
	# record's growth is the proof that it captured, and only then is the equality read.
	var captured := false
	for _attempt in 5:
		var size_before := _record(node).size()
		_tick_n(node, 1)
		if _record(node).size() > size_before:
			captured = true
			break
	audit.check_eq(captured, true, "replay/a_tick_that_captures_exists")
	audit.check_eq(_newest_matches_live(node), "", "replay/the_newest_frame_is_the_live_state")

	# One frame per tick. A natural point end inside the window is possible (a rally can
	# end there), and it restarts the record — the 1:1 proof that cannot be interrupted
	# is the forced-restart window below, so this window is exact when nothing ended.
	var before_120 := frames.size()
	_tick_n(node, 120)
	frames = _record(node)
	if frames.size() == before_120 + 120:
		audit.check_eq(true, true, "replay/one_tick_records_one_frame")
	else:
		audit.note("a point ended inside the second 120-tick window (the record restarted at %d frames); the uninterrupted 1:1 proof is the forced window below" % frames.size())
		audit.check_le(frames.size(), 120, "replay/one_tick_records_one_frame")

	# A new point restarts the record (`js/game.js:3005-3007`: `pointPause` -> 0 ->
	# `resetReplayBuffer`). `pointPause` is FORCED here, plainly: the point is ended by the
	# audit instead of by a rally, and everything after it is the engine's own path.
	#
	# The proof that the record was REPLACED is the array's identity: the reset assigns a
	# fresh array (`state.replayFrames = []`, `sim.gd:248`), so the reference kept here must
	# stop growing while the live record fills. A ball-triple inequality must NOT be used
	# for this: the forced end re-runs `prepare_serve` with the serve side unchanged, so the
	# fresh record's first frame IS the same canonical serve state the match opened on —
	# exactly what the reference produces (`js/main.js:1388-1399`).
	var stale_record: Array = frames
	var stale_size := stale_record.size()
	node.state.pointPause = 0.05
	_tick_n(node, 10)
	frames = _record(node)
	audit.check_le(frames.size(), 10, "replay/a_new_point_restarts_the_record")
	var restarted := frames.size()
	_tick_n(node, SAFE_WINDOW)
	frames = _record(node)
	audit.check_eq(frames.size(), restarted + SAFE_WINDOW, "replay/the_restarted_record_fills_one_frame_per_tick")
	if stale_size > 0:
		audit.check_eq(stale_record.size(), stale_size, "replay/the_restarted_record_is_not_the_old_one")

	# The ring's front-drop, at the reduced capacity this audit names.
	node.state.replayMax = RING_TEST_MAX
	node.state.pointPause = 0.05
	_tick_n(node, 10)
	frames = _record(node)
	var oldest := _ball_triple(frames[0]) if frames.size() > 0 else []
	_tick_n(node, RING_TEST_MAX + 40)
	frames = _record(node)
	audit.check_eq(frames.size(), RING_TEST_MAX, "replay/at_capacity_the_record_holds_exactly_its_bound")
	audit.check_ne(_ball_triple(frames[0]), oldest, "replay/at_capacity_the_oldest_frame_was_dropped")
	if _has(node, "replay_frame_count"):
		audit.check_eq(int(node.replay_frame_count()), RING_TEST_MAX, "replay/the_count_readout_matches_the_capped_record")
	audit.check_le(frames.size(), int(node.state.replayMax), "replay/the_capped_record_respects_the_bound_it_was_given")
	node.state.replayMax = REFERENCE_MAX
	audit.note("the front-drop ran at replayMax=%d (this audit's instrumentation); the shipped bound is asserted as %d" % [RING_TEST_MAX, REFERENCE_MAX])
	_drop(node)


# ---------------------------------------------------------------------------
# 4. Playback — frozen simulation, cadence, clamp, the recorded ball, restore-equality
# ---------------------------------------------------------------------------

func _playback(audit: AuditBase) -> void:
	var node := _new_match()
	var need := _needs(node, SEAM_REQUIRED)
	if need != "":
		_skip_live(audit, "playback", need)
		_drop(node)
		return
	_tick_n(node, 180)
	var frames: Array = node.state.replayFrames
	audit.check_ge(frames.size(), 2, "replay/playback_has_frames_to_play")
	if frames.size() < 2:
		_drop(node)
		return
	var total := frames.size()
	var digest_before := _digest(node)
	var ball_before := _live_ball(node)
	var ticks_before := int(node.ticks)
	var has_finished_signal: bool = node.has_signal("replay_finished")
	audit.check_eq(has_finished_signal, true, "replay/the_controller_exposes_replay_finished")
	var finished := [0]
	if has_finished_signal:
		node.connect("replay_finished", func() -> void: finished[0] += 1)

	audit.check_eq(node.start_replay(), true, "replay/r_starts_a_replay_when_frames_exist")
	audit.check_eq(node.replay_active(), true, "replay/the_replay_is_active")
	audit.check_eq(node.is_paused(), false, "replay/entering_clears_the_pause_like_the_reference")
	if _has(node, "replay_index"):
		audit.check_eq(int(node.replay_index()), 0, "replay/playback_starts_at_the_first_frame")
	audit.check_eq(node.replay_progress(), 1.0 / float(total), "replay/progress_is_index_plus_one_over_total")

	# One rendered frame at a time, the cadence the reference's own accumulator runs at
	# (`js/main.js:1308-1319`). The cursor is read through `replay_index()` when the
	# controller offers it and through `replay_progress()` when it does not — both are the
	# same fact, and the check is real either way.
	var ok_cadence := true
	var ok_frozen := true
	var ok_frames := true
	var view_problem := ""
	var steps := total + 5
	for i in steps:
		node.apply_frame(Sim.empty_input(), REPLAY_STEP)
		var want := mini(i + 1, total - 1)
		var progress := (float(want) + 1.0) / float(total)
		if int(node.ticks) != ticks_before:
			ok_frozen = false
		if absf(node.replay_progress() - progress) > 0.0001:
			ok_frames = false
		if _has(node, "replay_index"):
			if int(node.replay_index()) != want:
				ok_cadence = false
		elif absf(node.replay_progress() - progress) > 0.0001:
			ok_cadence = false
		if i == 2:
			view_problem = _ball_view_problem(node, want)
	audit.check_eq(ok_frozen, true, "replay/the_simulation_does_not_advance_while_the_replay_runs")
	audit.check_eq(ok_cadence, true, "replay/the_cursor_advances_one_frame_per_1_60s_of_rendered_frame")
	audit.check_eq(ok_frames, true, "replay/progress_follows_the_cursor")
	if _has(node, "replay_index"):
		audit.check_eq(int(node.replay_index()), total - 1, "replay/the_cursor_clamps_at_the_last_frame")
	else:
		audit.note("match_controller exposes no replay_index(); the clamp is asserted through replay_progress() == 1.0 below")
		_seam_soft_miss(node, audit)
	audit.check_eq(node.replay_progress(), 1.0, "replay/the_full_point_reads_a_full_bar")
	audit.check_eq(finished[0], 1, "replay/replay_finished_fires_once_at_the_end")
	audit.check_eq(view_problem, "", "replay/the_ball_rendered_during_playback_is_the_recorded_ball")
	node.apply_frame(Sim.empty_input(), REPLAY_STEP)
	audit.check_eq(absf(node.replay_progress() - 1.0) <= 0.0001, true, "replay/a_finished_replay_keeps_the_last_frame")
	audit.check_eq(int(node.ticks), ticks_before, "replay/the_frozen_simulation_stays_frozen")

	# Restore-equality: the digest the parity harness uses, before and after.
	node.stop_replay()
	audit.check_eq(node.replay_active(), false, "replay/stopping_ends_the_replay")
	audit.check_eq(_digest(node), digest_before, "replay/the_state_digest_is_byte_identical_after_playback")
	audit.check_eq(_live_ball(node), ball_before, "replay/the_live_ball_is_back_exactly")

	# Control returns: the next rendered frame advances the match again.
	node.apply_frame(Sim.empty_input(), 1.0 / 60.0)
	audit.check_gt(int(node.ticks), ticks_before, "replay/the_match_resumes_on_the_next_frame")

	# The entry gate: the reference refuses a replay with fewer than two frames
	# (`js/main.js:1390`), and the port has to as well.
	var fresh := _new_match()
	audit.check_eq(fresh.start_replay(), false, "replay/one_frame_is_not_enough_to_replay")
	audit.check_eq(fresh.replay_active(), false, "replay/a_refused_entry_leaves_the_match_running")
	audit.check_eq(fresh.is_paused(), false, "replay/a_refused_entry_does_not_pause")
	_drop(fresh)
	_drop(node)


# ---------------------------------------------------------------------------
# 5. Stop and the pause state — both entry paths (`js/main.js:2238-2241`, `:1394-1395`)
# ---------------------------------------------------------------------------

func _stop_and_pause_restore(audit: AuditBase) -> void:
	var node := _new_match()
	var need := _needs(node, SEAM_REQUIRED)
	if need != "":
		_skip_live(audit, "stop", need)
		_drop(node)
		return
	_tick_n(node, 180)
	if node.state.replayFrames.size() < 2:
		audit.check_true(false, "replay/stop_has_frames_to_play")
		_drop(node)
		return

	# Path A — entered from live play: stopping returns to live play.
	node.start_replay()
	node.apply_frame(Sim.empty_input(), REPLAY_STEP)
	node.stop_replay()
	audit.check_eq(node.is_paused(), false, "replay/from_live_play_the_mask_ends_unpaused")
	if node.has_method("replay_was_paused"):
		audit.check_eq(node.replay_was_paused(), false, "replay/the_remembered_pause_state_was_false")
	else:
		audit.note("match_controller has no replay_was_paused(); the pause restoration below is asserted through is_paused() alone")

	# Path B — entered from the pause card: stopping puts the pause back, so the card
	# reopens on the MATCH tab (UIR-20's open() lands there) and ESC's step 4 applies.
	audit.check_eq(node.set_match_paused(true), true, "replay/the_card_can_be_open_before_the_replay")
	audit.check_eq(node.start_replay(), true, "replay/the_card_starts_a_replay")
	audit.check_eq(node.is_paused(), false, "replay/entering_from_the_card_closes_the_card_like_the_reference")
	if node.has_method("replay_was_paused"):
		audit.check_eq(node.replay_was_paused(), true, "replay/the_remembered_pause_state_was_true")
	node.apply_frame(Sim.empty_input(), REPLAY_STEP)
	node.stop_replay()
	audit.check_eq(node.is_paused(), true, "replay/leaving_a_card_started_replay_restores_the_pause")
	# The card follows the flag through the seam's echo; open() lands on MATCH.
	_pause_overlay.set_match_paused(true)
	await process_frame
	audit.check_eq(_pause_overlay.is_open(), true, "replay/the_restored_pause_reopens_the_card")
	audit.check_eq(_pause_overlay.active_tab(), "match", "replay/the_restored_card_opens_on_the_match_tab")
	_pause_overlay.set_match_paused(false)
	await process_frame

	# The overlay follows the live seam, without the mount touching it per frame.
	_overlay.bind_seam(node)
	node.start_replay()
	_overlay.refresh()
	audit.check_eq(_overlay.is_active(), true, "replay/the_overlay_shows_while_the_match_replays")
	audit.check_eq(absf(_overlay.progress() - float(node.replay_progress())) <= 0.0001, true, "replay/the_overlay_paints_the_seams_progress")
	node.stop_replay()
	_overlay.refresh()
	audit.check_eq(_overlay.is_active(), false, "replay/the_overlay_hides_when_the_replay_ends")
	_overlay.bind_seam(null)
	_drop(node)


# ---------------------------------------------------------------------------
# 6. The keys (`js/main.js:2532`, `:2604-2627`)
# ---------------------------------------------------------------------------

func _keys(audit: AuditBase) -> void:
	var node := _new_match()
	var need := _needs(node, SEAM_REQUIRED)
	if need != "":
		_skip_live(audit, "keys", need)
		_drop(node)
		return
	_tick_n(node, 150)
	audit.check_ge(node.state.replayFrames.size(), 2, "replay/the_keys_have_frames_to_play")

	# `r` in play: a replay, not the retired restart. A restart resets `ticks` to 0 and
	# clears the record through `start_match` — both are asserted against.
	var ticks_before := int(node.ticks)
	var frames_before: int = int(node.state.replayFrames.size())
	_press_r()
	await process_frame
	await process_frame
	audit.check_eq(node.replay_active(), true, "replay/r_starts_a_replay_in_play")
	audit.check_eq(int(node.ticks) >= ticks_before, true, "replay/r_no_longer_restarts_the_match")
	audit.check_eq(node.state.replayFrames.size(), frames_before, "replay/r_leaves_the_record_untouched")

	# `r` again: stop (`js/main.js:2618-2626`).
	_press_r()
	await process_frame
	await process_frame
	audit.check_eq(node.replay_active(), false, "replay/r_stops_a_running_replay")

	# ESC in a replay: step 0 of the hierarchy, not a pause (`js/main.js:2606-2609`).
	node.start_replay()
	audit.check_eq(node.replay_active(), true, "replay/the_replay_is_up_before_escape")
	_press_pause_action()
	await process_frame
	await process_frame
	audit.check_eq(node.replay_active(), false, "replay/escape_stops_a_running_replay")
	audit.check_eq(node.is_paused(), false, "replay/escape_did_not_pause_the_match_instead")
	_press_pause_action()
	await process_frame
	await process_frame
	audit.check_eq(node.is_paused(), true, "replay/the_pause_still_works_after_the_replay")

	# `r` while the card is open is refused (`js/main.js:2616-2626`).
	var paused_ticks := int(node.ticks)
	_press_r()
	await process_frame
	await process_frame
	audit.check_eq(node.replay_active(), false, "replay/r_while_paused_is_refused")
	audit.check_eq(node.is_paused(), true, "replay/the_refused_key_leaves_the_card_up")
	audit.check_eq(int(node.ticks) >= paused_ticks, true, "replay/the_refused_key_does_not_restart_the_match")
	node.set_match_paused(false)
	_drop(node)


# ---------------------------------------------------------------------------
# 7. UIR-20's button becomes enabled (UIR-27's DoD)
# ---------------------------------------------------------------------------

func _pause_button(audit: AuditBase) -> void:
	var button: Button = _pause_overlay.find_child("ReplayButton", true, false)
	_pause_overlay.set_replay_active(true)
	audit.check_eq(_pause_overlay.replay_enabled(), true, "replay/the_flag_enables_the_entry")
	audit.check_eq(_pause_overlay.replay_disabled_reason(), "", "replay/an_enabled_entry_carries_no_reason")
	audit.check_ne(button, null, "replay/the_replay_button_exists")
	if button != null:
		audit.check_eq(button.disabled, false, "replay/the_button_is_pressable_once_uir27_is_wired")
	var emitted := [0]
	_pause_overlay.replay_requested.connect(func() -> void: emitted[0] += 1)
	audit.check_eq(_pause_overlay.replay(), true, "replay/the_button_route_reaches_the_entry")
	audit.check_eq(emitted[0], 1, "replay/the_entry_emits_replay_requested")
	var step: Dictionary = _pause_overlay.back()
	audit.check_eq(int(step.get("step", -1)), 0, "replay/escs_step_0_is_the_replay")
	audit.check_eq(String(step.get("kind", "")), "replay_close", "replay/step_0_closes_the_replay")
	audit.check_eq(paused, false, "replay/the_button_never_pauses_the_tree")
	_pause_overlay.set_replay_active(false)
	audit.check_eq(_pause_overlay.replay_enabled(), false, "replay/the_flag_is_the_only_gate")
	audit.check_eq(_pause_overlay.replay_disabled_reason(), "uir27-replay-entry-not-landed", "replay/the_gate_records_its_dependency_when_off")
	audit.note("integration wiring: the button's gate and the ESC step 0 are two different facts in UIR-20's single flag (availability vs a replay that is up) — §Seam of evidence/uir-27-replay.log names the split the integration owner has to pick")


# ---------------------------------------------------------------------------
# 8. The overlay's seam walk and the locale flip
# ---------------------------------------------------------------------------

func _overlay_seam(audit: AuditBase) -> void:
	var seam := FakeSeam.new()
	seam.active = true
	seam.total = 4
	seam.index = 2
	_overlay.bind_seam(seam)
	audit.check_eq(_overlay.refresh(), true, "replay/a_seam_that_turns_on_moves_the_view")
	audit.check_eq(_overlay.is_active(), true, "replay/the_seam_turns_the_overlay_on")
	audit.check_eq(absf(_overlay.fill_ratio() - 0.75) <= 0.01, true, "replay/the_seams_progress_paints_the_bar")
	seam.active = false
	_overlay.refresh()
	audit.check_eq(_overlay.is_active(), false, "replay/the_seam_turns_the_overlay_off")
	_overlay.bind_seam(null)

	# A seam that answers the visibility question but carries no progress reader: the
	# overlay records the miss (its report names it) and paints an empty bar — a guess
	# would be worse than an empty track.
	_overlay.bind_seam(HalfSeam.new())
	_overlay.refresh()
	audit.check_eq(_overlay.is_active(), true, "replay/a_half_seam_still_shows_the_chrome")
	audit.check_eq(_overlay.progress(), 0.0, "replay/a_missing_progress_reader_paints_an_empty_bar")
	audit.check_true((_overlay.report().get("seam_missing", []) as Array).has("replay_progress"), "replay/the_missing_reader_is_recorded_by_name")
	_overlay.bind_seam(null)
	_overlay.refresh()
	audit.check_eq(_overlay.is_active(), false, "replay/unbinding_the_seam_hides_the_chrome")


func _localization(audit: AuditBase) -> void:
	var language_at_start := Locale.current_lang()
	var other := ""
	for lang in Locale.locales():
		if String(lang) != language_at_start:
			other = String(lang)
			break
	audit.check_ne(other, "", "replay/a_second_locale_exists")
	var before_banner: String = String(_overlay.banner_text())
	var before_hint: String = String(_overlay.exit_hint_text())
	audit.check_eq(_overlay.set_language(other), true, "replay/the_other_language_is_taken")
	# The banner is glyph + separator + word by design (`banner_text`; this file's own
	# check at `:230` asserts exactly that composition), so the language flip moves the
	# WORD and the expectation has to carry the glyph too.
	audit.check_eq(_overlay.banner_text(), String(OverlayClass.BANNER_GLYPH) + String.chr(32) + UiStrings.t("replay"), "replay/the_banner_follows_the_language")
	audit.check_eq(_overlay.exit_hint_text(), UiStrings.t("replayExit"), "replay/the_hint_follows_the_language")
	audit.check_ne(_overlay.banner_text(), before_banner, "replay/the_banner_text_moved_with_the_flip")
	audit.check_ne(_overlay.exit_hint_text(), before_hint, "replay/the_hint_text_moved_with_the_flip")
	audit.check_eq(_overlay.set_language("xx"), false, "replay/an_unknown_locale_is_refused")
	audit.check_eq(_overlay.set_language(language_at_start), true, "replay/the_first_language_comes_back")
	for key in [OverlayClass.BANNER_KEY, OverlayClass.EXIT_KEY]:
		audit.check_eq(Locale.has_key(String(key)), true, "replay/the_%s_key_resolves" % String(key))


# ---------------------------------------------------------------------------
# 9. The static scan over the overlay source (`UIR-20`'s own rules)
# ---------------------------------------------------------------------------

func _static_scan(audit: AuditBase) -> void:
	var source := ""
	var file := FileAccess.open(OVERLAY_PATH, FileAccess.READ)
	if file != null:
		source = file.get_as_text()
		file.close()
	audit.check_true(source != "", "replay/the_overlay_source_is_readable")
	if source == "":
		return
	var code := _strip_comments(source)
	for pattern in FORBIDDEN_PATTERNS:
		audit.check_eq(code.contains(String(pattern)), false, "replay/ReplayOverlay.gd_never_carries_%s" % String(pattern).replace(" ", "_"))
	var offenders: Array = []
	for line in code.split("\n"):
		var trimmed := String(line).strip_edges()
		if trimmed.begins_with("##") or trimmed.begins_with("#"):
			continue
		var exempt := false
		for marker in DEVELOPER_MARKERS:
			if String(line).contains(String(marker)):
				exempt = true
		if exempt:
			continue
		var quoted := _quoted_literals(String(line))
		for literal in quoted:
			if String(literal).contains(" "):
				offenders.append(String(literal))
	audit.check_eq(offenders, [], "replay/zero_prose_literals_in_the_overlay")
	for method in ["bind_seam", "seam", "set_replay", "refresh", "is_active", "progress",
			"set_language", "refresh_strings", "report", "palette_misses", "focus_controls",
			"capture_states", "apply_capture_state", "banner_text", "exit_hint_text",
			"banner_rect", "bar_rect", "fill_ratio"]:
		audit.check_eq(_overlay.has_method(String(method)), true, "replay/the_audit_calls_%s_which_exists" % String(method))
	audit.check_eq(OverlayClass.palette_keys().size() >= 3, true, "replay/the_static_palette_list_is_readable")
	for key in OverlayClass.palette_keys():
		var name := String(key)
		var declared: bool = _overlay.palette_misses().has(name)
		audit.check_true(_theme_has_color(name) or declared, "replay/palette_%s_is_in_the_theme_or_declared" % name)
	# A miss is recorded exactly when the theme LACKS the key, so the two sides are
	# complements; the old form compared them for equality and could never pass
	# (theme lacks it -> false == true; theme has it -> true == false).
	audit.check_eq((not _theme_has_color("replay_banner")), _overlay.palette_misses().has("replay_banner"), "replay/the_banner_key_is_a_miss_exactly_when_the_theme_lacks_it")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _new_match() -> Node:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 2
	var packed: PackedScene = load(MATCH_SCENE)
	var node: Node = packed.instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	return node


func _tick_n(node: Node, count: int) -> void:
	for _i in count:
		node.tick_fixed(TICK, _bot.decide(node.state), Sim.empty_input())


func _drop(node: Node) -> void:
	if node != null and node.get_parent() != null:
		root.remove_child(node)
		node.free()


## The parity digest of the live state (`src/sim/digest.gd`, the same sampler the
## cross-engine parity run uses), so "the state is exactly as it was" is one string.
func _digest(node: Node) -> String:
	return Digest.sha256_of_lines([Digest.digest_line(Digest.sample_state(node.state, int(node.ticks), int(node.state.rng_calls)))])


func _live_ball(node: Node) -> Array:
	var ball = node.state.ball
	return [ball.x, ball.y, ball.z, ball.vx, ball.vy, ball.vz]


## The record as it is NOW. The reset REPLACES the array (`sim.gd:248`), so every read
## after a tick block goes through here rather than holding the old reference.
func _record(node: Node) -> Array:
	return node.state.replayFrames


func _ball_triple(frame: Dictionary) -> Array:
	var ball: Dictionary = frame.get("ball", {})
	return [ball.get("x", 0.0), ball.get("y", 0.0), ball.get("z", 0.0)]


## "" when the newest recorded frame IS the live state (field for field, no unit
## conversion — the snapshot copies the sim's own pixels), or the reason it is not.
func _newest_matches_live(node: Node) -> String:
	var frames: Array = node.state.replayFrames
	if frames.is_empty():
		return "no frames recorded"
	var frame: Dictionary = frames[frames.size() - 1]
	for key in ["serveSide", "serveCourt", "activePlayerKey"]:
		if String(frame.get(key, "")) != String(node.state.get(key)):
			return "frame.%s=%s live=%s" % [key, str(frame.get(key)), str(node.state.get(key))]
	var ball = node.state.ball
	var recorded: Dictionary = frame.get("ball", {})
	for key in ["x", "y", "z", "vx", "vy", "vz"]:
		if float(recorded.get(key, 0.0)) != float(ball.get(key)):
			return "ball.%s=%s live=%s" % [key, str(recorded.get(key)), str(ball.get(key))]
	var pads: Array = frame.get("pads", [])
	var keys := ["player", "playerMate", "opponent", "opponentMate"]
	for i in keys.size():
		var pad = node.state.get(String(keys[i]))
		var rec: Dictionary = pads[i] if i < pads.size() else {}
		if float(rec.get("x", 0.0)) != float(pad.x) or float(rec.get("y", 0.0)) != float(pad.y):
			return "pads[%d]=(%s,%s) live=(%s,%s)" % [i, str(rec.get("x")), str(rec.get("y")), str(pad.x), str(pad.y)]
	return ""


## "" when every frame carries the reference's own field sets and pads are four.
func _frame_problem(node: Node) -> String:
	var frames: Array = node.state.replayFrames
	var checks := mini(frames.size(), 8)
	for i in checks:
		var frame: Dictionary = frames[frames.size() - 1 - i]
		for key in ["serveSide", "serveCourt", "activePlayerKey", "ball", "pads"]:
			if not frame.has(key):
				return "frame misses %s" % key
		var ball: Dictionary = frame["ball"]
		for key in BALL_FIELDS:
			if not ball.has(String(key)):
				return "ball misses %s" % key
		if not (ball["trail"] is Array):
			return "ball.trail is not an array"
		var pads: Array = frame["pads"]
		if pads.size() != 4:
			return "pads has %d entries" % pads.size()
		for pad in pads:
			var entry: Dictionary = pad
			for key in PAD_FIELDS:
				if not entry.has(String(key)):
					return "a pad misses %s" % key
	return ""


## "" when the record moved during the point (proof the frames are copies of a living
## state, not one aliased dictionary repeated).
func _moved_problem(frames: Array) -> String:
	if frames.size() < 2:
		return "fewer than two frames"
	var first := _ball_triple(frames[0])
	var last := _ball_triple(frames[frames.size() - 1])
	if first == last:
		return "the first and last frames carry the same ball"
	return ""


## "" when the ball the controller's own 3D node shows is the frame the cursor is on.
func _ball_view_problem(node: Node, index: int) -> String:
	var frames: Array = node.state.replayFrames
	if index < 0 or index >= frames.size():
		return "the cursor %d is outside the record" % index
	var view: Node3D = node.get_node_or_null("Ball")
	if view == null:
		return "the controller has no Ball node"
	var ball: Dictionary = (frames[index] as Dictionary)["ball"]
	var want := Court.world_pos(float(ball["x"]), float(ball["y"]), float(ball["z"]))
	if not view.position.is_equal_approx(want):
		return "the rendered ball is at %s, the recorded frame at %s" % [str(view.position), str(want)]
	return ""


## Every seam method present, or the reason a live group cannot run. The names are the
## integration checklist; a missing one is a red check, never a skipped pass.
func _needs(node: Node, methods: Array) -> String:
	var missing: Array = []
	for name in methods:
		if not node.has_method(String(name)):
			missing.append(String(name))
	return "" if missing.is_empty() else "match_controller misses %s" % JSON.stringify(missing)


func _has(node: Node, method: String) -> bool:
	return node != null and node.has_method(method)


func _seam_soft_miss(node: Node, audit: AuditBase) -> void:
	if _soft_missed:
		return
	_soft_missed = true
	var missing: Array = []
	for name in SEAM_SOFT:
		if not node.has_method(String(name)):
			missing.append(String(name))
	if not missing.is_empty():
		audit.note("the controller carries none of the optional readouts: %s (the audit reads the record and the progress instead)" % JSON.stringify(missing))


func _skip_live(audit: AuditBase, group: String, reason: String) -> void:
	_skipped_live.append(group)
	audit.check_eq(reason, "", "replay/%s_group_can_run" % group)


func _press_r() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = true
	Input.parse_input_event(event)


func _press_pause_action() -> void:
	var event := InputEventAction.new()
	event.action = "padel_pause"
	event.pressed = true
	Input.parse_input_event(event)


## Comments stripped the way the UI lane's scan does it (a quote inside a comment is
## prose, not a literal) — and a `#` inside a quoted literal is not a comment.
func _strip_comments(source: String) -> String:
	var out := ""
	for line in source.split("\n"):
		var kept := ""
		var in_string := false
		var escaped := false
		for i in String(line).length():
			var ch := String(line)[i]
			if in_string:
				kept += ch
				if escaped:
					escaped = false
				elif ch == "\\":
					escaped = true
				elif ch == "\"":
					in_string = false
				continue
			if ch == "\"":
				in_string = true
				kept += ch
				continue
			if ch == "#":
				break
			kept += ch
		out += kept + "\n"
	return out


func _quoted_literals(line: String) -> Array:
	var out: Array = []
	var open_quote := -1
	for i in line.length():
		if line[i] == "\"":
			if open_quote < 0:
				open_quote = i
			else:
				out.append(line.substr(open_quote + 1, i - open_quote - 1))
				open_quote = -1
	return out


## Whether the shipped theme carries a Palette entry (read-only: the theme file is the
## theme lane's, this audit only looks).
func _theme_has_color(key: String) -> bool:
	var theme: Theme = load("res://src/ui/theme/padel_theme.tres")
	return theme != null and theme.has_color(key, "Palette")


func _wipe() -> void:
	Config.save_dir = ""
	var absolute := ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(absolute):
		_wipe_dir(TEMP_DIR)


func _wipe_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file in dir.get_files():
		DirAccess.remove_absolute(absolute.path_join(file))
