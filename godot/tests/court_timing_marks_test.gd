## court_timing_marks_test.gd — the court timing marks' own gate: the seam the match
## shell calls, and the presentation it places.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/court_timing_marks_test.gd
##
## WHAT IT GATES, per `docs/mission/architecture-deepening/tickets/court-timing-marks.md`
## ("move court timing geometry, state, placement, verdict rendering and report
## behavior out of the match shell ... tests cross the new module interface instead
## of private controller fields"):
##
##   A. THE ONE OWNER. `game/court_timing_marks.gd` exists and declares the moved
##      geometry and builders, and `match_controller.gd` neither declares nor reaches
##      into them any more: its whole timing surface is the module — one preload, one
##      `mount`, one `update` a frame, one `report`, one `capture_lines`.
##   B. THE MARKS. `mount()` builds the eleven marks, with the names and the
##      camera-facing, unshaded, depth-test-free contract the reference's paint order
##      requires (it draws them AFTER the court, `js/main.js:1919`).
##   C. THE PLACEMENT. `update()` places the ring, the window, the precision bar, the
##      advice word, the energy bar and the verdict from a live state, at the geometry
##      the port measured (`docs/wayfinder/evidence/timing-presentation-3d.md`), and
##      reports what it drew — including each mark's placed position and colour.
##   D. THE VERDICT. The reference's own rules (`js/render.js:1041-1069`): the two
##      words, the four colours, `life / 0.28`, the drift, and the athlete who HIT.
##   E. THE A/B MUTE and the capture marker lines the frame recorder prints.
##
## Everything below crosses the module's interface: no `match_controller` private
## variable is named or read here. The module is loaded by PATH at run time, never
## preloaded — this suite has to run, and fail cleanly, on the run BEFORE that module
## and its wiring exist (a `preload` of a missing file fails the whole file instead of
## one check).
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Court := preload("res://game/court.gd")
const Vocabulary := preload("res://game/feedback_vocabulary.gd")
const Locale := preload("res://src/locale/locale.gd")

const MODULE_PATH := "res://game/court_timing_marks.gd"
const CONTROLLER_PATH := "res://game/match_controller.gd"

## The geometry the module must own: every `TIMING_*` constant the shell carried,
## with the reference anchor or the measurement that set it.
const MOVED_CONSTANTS := [
	"const TIMING_ENERGY_HEIGHT", "const TIMING_PRECISION_HEIGHT",
	"const TIMING_RING_HEIGHT", "const TIMING_VERDICT_HEIGHT",
	"const TIMING_ADVICE_HEIGHT", "const TIMING_FOOT_FORWARD",
	"const TIMING_PX_PER_M", "const TIMING_M_PER_PX",
	"const TIMING_REF_PX_PER_M", "const TIMING_REF_M_PER_PX",
	"const TIMING_RING_RADIUS", "const TIMING_RING_WIDTH",
	"const TIMING_FLASH_GAP", "const TIMING_FLASH_WIDTH",
	"const TIMING_ARC_TRACK", "const TIMING_ARC_FILL", "const TIMING_ETA_SPAN",
	"const TIMING_CHARGE_FLOOR", "const TIMING_PRECISION_FLOOR",
	"const TIMING_PRECISION_W", "const TIMING_PRECISION_H",
	"const TIMING_ENERGY_W", "const TIMING_ENERGY_H",
	"const TIMING_ADVICE_FONT_PX", "const TIMING_ADVICE_BOX_LINES",
	"const TIMING_ADVICE_PAD_LINES", "const TIMING_ADVICE_PX",
	"const TIMING_VERDICT_PX", "const TIMING_VERDICT_MODE_PX",
	"const TIMING_VERDICT_FONT_PX", "const TIMING_VERDICT_MODE_FONT_PX",
	"const TIMING_VERDICT_MODE_DROP", "const TIMING_VERDICT_OUTLINE",
	"const TIMING_VERDICT_DRIFT", "const TIMING_VERDICT_LIFE",
	"const TIMING_VERDICT_FADE", "const TIMING_GRADIENT", "const TIMING_ARC_STEP",
]
## The private declarations the shell must not carry any more: the builders and the
## per-frame sync it used to own. (The module names its own internals for its own
## module — what must not survive in the shell are these.)
const SHELL_MOVED_FUNCTIONS := [
	"_build_timing_marks", "_timing_verdict_label", "_timing_mesh", "_timing_material",
	"_timing_arc_mesh", "_timing_arc_segments", "_timing_bar_mesh", "_timing_gradient",
	"_sync_timing", "_sync_verdict",
]
## The module's own building surface: the geometry, the marks and the verdict.
const MODULE_BUILDERS := [
	"_build_mesh", "_material", "_arc_mesh", "_arc_segments", "_bar_mesh",
	"_gradient", "_verdict_label", "_place_verdict",
]
## The module's public seam: what the shell and the tests are allowed to call.
## Six calls — the mute's state is read through the marks it turns off, not
## through a getter, so `is_muted()` was deleted as unused surface
## (independent review F-10).
const SEAM_FUNCTIONS := [
	"mount", "mark_names", "update", "report", "set_muted", "capture_lines",
]
## The eleven marks, in build order: the names the shell's scene carried before this
## extraction. The tree did not move, the owner did.
const MARK_NAMES := [
	"TimingRingTrack", "TimingRing", "TimingWindow",
	"TimingPrecisionBar", "TimingPrecisionFill",
	"TimingEnergyBar", "TimingEnergyFill",
	"TimingAdvice", "TimingAdvicePanel",
	"TimingVerdict", "TimingVerdictMode",
]
## The marks that are meshes with a shared material contract, and the two labels.
const MESH_MARKS := [
	"TimingRingTrack", "TimingRing", "TimingWindow",
	"TimingPrecisionBar", "TimingPrecisionFill",
	"TimingEnergyBar", "TimingEnergyFill", "TimingAdvicePanel",
]
const LABEL_MARKS := ["TimingAdvice", "TimingVerdict", "TimingVerdictMode"]

## The port's measured geometry, in metres (`evidence/timing-presentation-3d.md`):
## pinned as literals here, so a drift in the module is a red check, not a new number.
const RING_HEIGHT := 1.60
const PRECISION_HEIGHT := 0.75
const ENERGY_HEIGHT := 0.30
const ADVICE_HEIGHT := 2.95
const VERDICT_HEIGHT := 1.44
const FOOT_FORWARD := 0.5
const RING_RADIUS := 0.62
const BAR_W := 0.80
const ETA_SPAN := 0.55
const VERDICT_LIFE := 0.78
const VERDICT_DRIFT := 0.25
const VERDICT_FADE := 0.28
## `1.6*PI` of fill in `PI/24` steps at eta 0 (`js/render.js:1677`).
const FULL_ARC_SEGMENTS := 39
## The mode id the reference stores for a control shot (`sim.gd:1246`).
const MODE_CONTROL := "shotMode:control"

## Every section this run must complete. Each section ends with its own
## `_section_done(<name>)`: a GDScript runtime error aborts only the function it
## happens in (`game/check_log.sh`'s "a printed PASS n/n is not enough"), so
## without this guard a section that threw would still tally green over the checks
## it never ran — the exact failure the independent review found in this suite
## (F-03).
const SECTIONS := ["_seam", "_marks_contract", "_placement", "_verdict", "_mute_and_capture"]

var _checks: int = 0
var _failures: int = 0
var _module: GDScript = null
var _marks = null
var _parent: Node3D = null
var _state = null
var _sections_done: Array[String] = []


## Called at the end of every section in `SECTIONS`.
func _section_done(name: String) -> void:
	_sections_done.append(name)


func _initialize() -> void:
	await _run()
	quit(1 if _failures > 0 else 0)


func _run() -> void:
	print("court timing marks seam test — one owner for the presentation")
	print("  module %s" % MODULE_PATH)
	print("  caller %s" % CONTROLLER_PATH)
	print("")
	Locale.set_lang("it")
	_module = load(MODULE_PATH) as GDScript
	_seam()
	if _module == null:
		_report_tally()
		return
	_parent = Node3D.new()
	_parent.name = "CourtTimingMount"
	root.add_child(_parent)
	# A node added during `_initialize()` is not in the tree until the loop
	# processes the entry (the deferral `padel-godot-port-ops` documents), and a
	# `global_position` read before then is an engine
	# `ERROR: Condition "!is_inside_tree()"` — an unallowed class that the strict
	# log gate refuses. One frame is enough: the marks mount as children of a
	# parent that is by then inside the tree, so the capture's reads are real
	# (independent review F-05; no allowance was added for the ERROR).
	await process_frame
	_marks = _module.new()
	var built: int = _marks.mount(_parent)
	_marks_contract(built)
	_state = _live_state()
	_placement()
	_verdict()
	_mute_and_capture()
	# The section guard: a section that threw is a failure even when every check
	# that did run printed `ok` (the rule `game/check_log.sh` exists for — F-03).
	var not_reported: Array[String] = []
	for name in SECTIONS:
		if not _sections_done.has(name):
			not_reported.append(name)
	_check("every test section ran to completion (a section that threw is a failure)",
		not_reported.is_empty(), str(not_reported))
	_report_tally()


# ---------------------------------------------------------------------------
# A. The one owner: the module owns the concern, the shell only calls it
# ---------------------------------------------------------------------------

func _seam() -> void:
	var source := _text(MODULE_PATH)
	var controller := _text(CONTROLLER_PATH)
	_check("the one court timing module exists at %s" % MODULE_PATH, source != "", MODULE_PATH)
	if source == "":
		return

	var missing: Array[String] = []
	for declaration in MOVED_CONSTANTS:
		if not source.contains(String(declaration)):
			missing.append(String(declaration))
	_check("the module owns every moved geometry constant", missing.is_empty(), str(missing))
	var unbuilt: Array[String] = []
	for fn in MODULE_BUILDERS:
		if not source.contains("func %s" % fn):
			unbuilt.append(String(fn))
	_check("the module owns every builder of the presentation",
		unbuilt.is_empty(), str(unbuilt))
	var unexposed: Array[String] = []
	for fn in SEAM_FUNCTIONS:
		if not source.contains("func %s(" % fn):
			unexposed.append(String(fn))
	_check("the module's public seam is the six calls the shell and the tests use",
		unexposed.is_empty(), str(unexposed))

	# The shell: no constant, no private timing variable, no builder of its own. The
	# regex is the whole point — the ONLY `_timing_*` identifier left in the shell is
	# the module reference itself.
	var timing_constants := _matches(controller, "TIMING_[A-Z_]+")
	_check("the match shell carries no TIMING_* constant any more",
		timing_constants.is_empty(), str(timing_constants))
	var timing_identifiers := _matches(controller, "_timing_[a-z_]+")
	_check("the shell's only `_timing_*` name is the module reference",
		timing_identifiers == PackedStringArray(["_timing_marks"]), str(timing_identifiers))
	var still_declared: Array[String] = []
	for fn in SHELL_MOVED_FUNCTIONS:
		if controller.contains("func %s" % fn):
			still_declared.append(String(fn))
	_check("the match shell declares none of the moved builders",
		still_declared.is_empty(), str(still_declared))
	_check("the match shell preloads the module", controller.contains("preload(\"%s\")" % MODULE_PATH),
		MODULE_PATH)
	_check("the shell uses the one interface: create, mount, update, report, capture_lines",
		controller.contains("CourtTiming.new()") and controller.contains(".mount(")
			and controller.contains(".update(") and controller.contains(".report()")
			and controller.contains(".capture_lines("),
		"create/mount/update/report/capture_lines")
	_check("the module preloads no caller (no pass-through, no cycle)",
		not source.contains("preload(\"res://game/match_controller.gd\")")
			and not source.contains("preload(\"res://game/hud.gd\")"),
		"preload(res://game/match_controller.gd)")
	_check("the module preloads no simulation script: it reads the state it is handed",
		not source.contains("preload(\"res://src/sim/"), "preload(res://src/sim/…)")
	_section_done("_seam")


# ---------------------------------------------------------------------------
# B. The marks: names, tree, and the drawing contract
# ---------------------------------------------------------------------------

func _marks_contract(built: int) -> void:
	_check_eq("mount() built every mark of the presentation", built, MARK_NAMES.size())
	_check_eq("the module's own list is the scene's eleven marks, names and order unchanged",
		_marks.mark_names(), PackedStringArray(MARK_NAMES))
	var missing: Array[String] = []
	for name in MARK_NAMES:
		if _mark(String(name)) == null:
			missing.append(String(name))
	_check("every mark is a child of the mount parent", missing.is_empty(), str(missing))
	_check_eq("the mount parent carries the eleven marks and nothing else",
		_parent.get_child_count(), MARK_NAMES.size())
	var drawn: Array[String] = []
	var wrong_type: Array[String] = []
	for name in MARK_NAMES:
		var node := _mark(String(name)) as Node3D
		if node == null or node.visible:
			drawn.append(String(name))
	for name in MESH_MARKS:
		if not (_mark(String(name)) is MeshInstance3D):
			wrong_type.append(String(name))
	for name in LABEL_MARKS:
		if not (_mark(String(name)) is Label3D):
			wrong_type.append(String(name))
	_check("every mark starts invisible: `update` decides what is on screen",
		drawn.is_empty(), str(drawn))
	_check("every mesh mark is a mesh and every label mark a label",
		wrong_type.is_empty(), str(wrong_type))
	var bad: Array[String] = []
	for name in MESH_MARKS:
		var mi := _mark(String(name)) as MeshInstance3D
		var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D if mi != null else null
		if mi == null or mat == null or not mat.no_depth_test or not mat.billboard_keep_scale:
			bad.append(String(name))
		elif mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
			bad.append(String(name))
		elif mat.cull_mode != BaseMaterial3D.CULL_DISABLED:
			bad.append(String(name))
		elif mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
			bad.append(String(name))
		elif mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			bad.append(String(name))
	_check("every mark is camera-facing, unshaded, depth-test-free and shadowless",
		bad.is_empty(), str(bad))
	var advice := _mark("TimingAdvice") as Label3D
	# The reference's own 11 px at its own 1/60 m: the proportion the owner ratified
	# (11 of the ring's 96 px), not 11 px read at this frame's 1280/960 scale.
	_check("the advice word is a camera-facing, depth-test-free label at 1/60 m per pixel",
		advice != null and advice.billboard == BaseMaterial3D.BILLBOARD_ENABLED
			and advice.no_depth_test and advice.font_size == 11
			and is_equal_approx(advice.pixel_size, 1.0 / 60.0), "")
	var verdict := _mark("TimingVerdict") as Label3D
	_check("the verdict's grade line carries the reference's own size and stroke",
		verdict != null and verdict.font_size == 14 and verdict.outline_size == 5
			and verdict.billboard == BaseMaterial3D.BILLBOARD_ENABLED and verdict.no_depth_test, "")
	var verdict_mode := _mark("TimingVerdictMode") as Label3D
	_check("the verdict's mode line is the reference's own second line",
		verdict_mode != null and verdict_mode.font_size == 9 and verdict_mode.outline_size == 0, "")
	_section_done("_marks_contract")


# ---------------------------------------------------------------------------
# C. The placement: what is drawn and where, from a live state
# ---------------------------------------------------------------------------

func _mark(name: String) -> Node:
	return _parent.get_node_or_null(NodePath(name))


func _placement() -> void:
	# The section's docstring says "from a live state": the module's report is empty
	# until the first `update()`, and reading `report["ring_visible"]` on the initial
	# `{}` is an engine error that aborts the rest of this section while the tally
	# stays green (independent review F-03). One update first.
	_marks.update(_state, false)
	var report: Dictionary = _marks.report()
	# --- a fresh, live state: nothing charging, the energy bar alone ------------
	_check("with nothing charging only the energy bar is drawn",
		not bool(report["ring_visible"]) and not bool(report["prec_visible"])
			and not bool(report["advice_visible"]) and bool(report["energy_visible"]),
		str(report))
	var ground: Vector3 = _ground(String(_state.activePlayerKey))
	_check("the energy bar sits under the active athlete, pulled towards the camera",
		_at(report["energy_at"], ground + Vector3(0.0, ENERGY_HEIGHT, FOOT_FORWARD)),
		"%s vs %s" % [str(report["energy_at"]), str(ground)])
	_check("the energy fill hangs off the bar's left edge, half a bar to the left",
		_at(report["energy_fill_at"], (report["energy_at"] as Vector3) + Vector3(-BAR_W * 0.5, 0.0, 0.0)),
		str(report["energy_fill_at"]))
	_check("the energy fill is `rallyEnergy.player` of the bar",
		is_equal_approx(float(report["energy_width"]), BAR_W * 1.0), str(report["energy_width"]))
	_check_eq("full energy is the reference's #56e8d8", report["energy_color"], "56e8d8")

	# --- the gate: `shotCharge > 0.05 && read.active` --------------------------
	_state.shotCharge = 0.6
	_state.shotRead["active"] = true
	_state.shotRead["eta"] = 0.3
	_state.shotRead["precision"] = 0.72
	_state.shotRead["tight"] = 0.0
	_marks.update(_state, false)
	report = _marks.report()
	_check("a charging shot with a live read draws the ring",
		bool(report["ring_visible"]), str(report))
	_check("the ring is over the athlete, at the measured ring height",
		_at(report["ring_at"], ground + Vector3(0.0, RING_HEIGHT, 0.0)), str(report["ring_at"]))
	_check("the fill is `1 - read.eta / 0.55`, the reference's own expression",
		is_equal_approx(float(report["fraction"]), clampf(1.0 - 0.3 / ETA_SPAN, 0.0, 1.0)),
		str(report["fraction"]))
	_check("the drawn arc is quantised to the reference's own 7.5-degree step",
		int(report["fill_segments"]) > 1 and float(report["fill_extent"]) > 0.0,
		"segments=%s extent=%s" % [str(report["fill_segments"]), str(report["fill_extent"])])
	_check("the window is not drawn while eta is outside `perfectWindow`",
		not bool(report["in_window"]), str(report["in_window"]))
	var mid_segments: int = int(report["fill_segments"])
	var mid_extent: float = float(report["fill_extent"])

	_state.shotRead["eta"] = 0.0
	_marks.update(_state, false)
	report = _marks.report()
	_check("an eta at the perfect window fills the ring to the top of the arc",
		is_equal_approx(float(report["fraction"]), 1.0), str(report["fraction"]))
	_check_eq("the full arc is `1.6*PI` in `PI/24` steps",
		int(report["fill_segments"]), FULL_ARC_SEGMENTS)
	_check("the drawn arc is rebuilt longer as the fill grows",
		int(report["fill_segments"]) > mid_segments and float(report["fill_extent"]) > mid_extent,
		"%d -> %d segments, %.3f -> %.3f extent" % [
			mid_segments, int(report["fill_segments"]), mid_extent, float(report["fill_extent"])])
	_check("the perfect window is the read's own `perfectWindow`",
		bool(report["in_window"]), "eta=0 window=%s" % str(_state.shotRead["perfectWindow"]))
	_check_eq("the ring's own radius is the measured one", float(report["fill_radius"]), RING_RADIUS)
	var window_mat := _mark("TimingWindow").material_override as StandardMaterial3D
	_check("the met window blinks at `0.55 + 0.4 * (0.5 + 0.5*sin(18t))`",
		is_equal_approx(window_mat.albedo_color.a, 0.75), str(window_mat.albedo_color.a))

	_state.shotRead["eta"] = ETA_SPAN
	_marks.update(_state, false)
	_check("an eta past 0.55 leaves the fill empty, as `clampf(..., 0, 1)` requires",
		is_zero_approx(float(_marks.report()["fraction"])), str(_marks.report()["fraction"]))

	# --- the precision bar: the SPRINT input, above the 0.04 floor -------------
	_state.shotRead["eta"] = 0.3
	_state.shotRead["precision"] = 0.03
	_marks.update(_state, false)
	_check("the precision bar is hidden at or under `precision > 0.04`",
		not bool(_marks.report()["prec_visible"]), str(_marks.report()["prec_visible"]))
	_state.shotRead["precision"] = 0.72
	_marks.update(_state, false)
	report = _marks.report()
	_check("the precision bar is drawn while the charge carries precision",
		bool(report["prec_visible"]), str(report))
	_check("the precision bar is at the measured precision height",
		_at(report["prec_at"], ground + Vector3(0.0, PRECISION_HEIGHT, 0.0)), str(report["prec_at"]))
	_check("the precision fill grows from the bar's left edge",
		_at(report["prec_fill_at"], (report["prec_at"] as Vector3) + Vector3(-BAR_W * 0.5, 0.0, 0.0)),
		str(report["prec_fill_at"]))
	_check("the precision fill is `precision` of the bar",
		is_equal_approx(float(report["prec_width"]), BAR_W * 0.72), str(report["prec_width"]))
	_check_eq("an unarmed angle is the reference's cyan", report["prec_color"], "7ef3ff")
	_state.shotRead["tight"] = 0.5
	_marks.update(_state, false)
	_check_eq("an armed angle takes the vocabulary's amber (the reference's pulse rule)",
		_marks.report()["prec_color"], Vocabulary.precision_color(0.5, 1.0).to_html(false))
	_check("an armed angle is no longer the unarmed cyan",
		String(_marks.report()["prec_color"]) != "7ef3ff", str(_marks.report()["prec_color"]))

	# --- the advice word: `!serving && !(pointPause > 0)` ----------------------
	_state.serving = false
	_state.pointPause = 0.0
	_state.shotRead["advice"] = "lob"
	_state.shotRead["profile"] = "control"
	_marks.update(_state, false)
	report = _marks.report()
	var expected_word := Locale.t("shotAdvice_lob").to_upper()
	_check("the advice word is the locale's `shotAdvice_<advice>`, uppercased as the reference does",
		bool(report["advice_visible"]) and String(report["advice"]) == expected_word,
		"advice=%s locale=%s" % [str(report["advice"]), expected_word])
	_check("no id ever reaches the field: the word is the resolved sentence",
		not String(report["advice"]).begins_with("shotAdvice"), str(report["advice"]))
	_check("the word is the vocabulary module's own resolution",
		String(report["advice"]) == Vocabulary.advice_word(Vocabulary.advice_of(_state.shotRead)),
		str(report["advice"]))
	_check("the word sits at the measured advice height",
		_at(report["advice_at"], ground + Vector3(0.0, ADVICE_HEIGHT, 0.0)), str(report["advice_at"]))
	_check_eq("a control profile is the reference's #8fffd0", report["advice_color"], "8fffd0")
	_check("the word's panel is a box around the measured text, not a fixed width",
		float(report["advice_panel_w"]) > 0.5, str(report["advice_panel_w"]))
	_state.shotRead["profile"] = "aggressive"
	_marks.update(_state, false)
	_check_eq("an aggressive profile is the reference's #ffd46a",
		_marks.report()["advice_color"], "ffd46a")
	_state.serving = true
	_marks.update(_state, false)
	_check("no advice while the athlete is serving", not bool(_marks.report()["advice_visible"]), "")
	_state.serving = false
	_state.pointPause = 0.5
	_marks.update(_state, false)
	_check("no advice while the point is paused", not bool(_marks.report()["advice_visible"]), "")
	_state.pointPause = 0.0

	# --- the energy bar's own bands (`js/render.js:1031-1037`) -----------------
	for band in [[1.0, "56e8d8"], [0.4, "ffd45c"], [0.2, "ff6b64"]]:
		_state.rallyEnergy = {"player": float(band[0]), "ai": 1.0}
		_marks.update(_state, false)
		_check_eq("energy %.2f is the reference's #%s" % [float(band[0]), String(band[1])],
			_marks.report()["energy_color"], String(band[1]))
	_state.rallyEnergy = {"player": 0.2, "ai": 1.0}
	_marks.update(_state, false)
	var low_width: float = float(_marks.report()["energy_width"])
	_check("the energy fill follows the player's own energy",
		is_equal_approx(low_width, BAR_W * 0.2), str(low_width))
	_state.rallyEnergy = {"player": 1.0, "ai": 1.0}

	# --- both follow a switch, like the zone and the pin -----------------------
	_state.activePlayerKey = "playerMate" if String(_state.activePlayerKey) == "player" else "player"
	_marks.update(_state, false)
	report = _marks.report()
	var mate_ground: Vector3 = _ground(String(_state.activePlayerKey))
	_check("the energy bar follows a switch to the partner",
		_at(report["energy_at"], mate_ground + Vector3(0.0, ENERGY_HEIGHT, FOOT_FORWARD)),
		"%s vs %s" % [str(report["energy_at"]), str(mate_ground)])
	_check("the ring follows the same switch as the energy bar",
		_at(report["ring_at"], mate_ground + Vector3(0.0, RING_HEIGHT, 0.0)), str(report["ring_at"]))

	# --- not live means nothing on the court ----------------------------------
	_state.running = false
	_marks.update(_state, false)
	report = _marks.report()
	_check("a state that is not running draws nothing",
		not bool(report["ring_visible"]) and not bool(report["energy_visible"])
			and not bool(report["advice_visible"]) and not bool(report["prec_visible"]),
		str(report))
	_state.running = true
	_state.shotCharge = 0.6
	_state.shotRead["active"] = true
	_state.shotRead["eta"] = 0.3
	_state.serving = false
	_section_done("_placement")


# ---------------------------------------------------------------------------
# D. The verdict, over the athlete who HIT (`js/render.js:1041-1069`)
# ---------------------------------------------------------------------------

func _verdict() -> void:
	_marks.update(_state, false)
	_check("no feedback means no verdict on the field",
		not bool(_marks.report()["verdict_visible"]), "")
	_state.shotFeedback = _feedback("shot:perfect", "shotMode:control", "perfect", "playerMate", 0.14)
	_marks.update(_state, false)
	var report: Dictionary = _marks.report()
	_check("the verdict is drawn while the feedback lives",
		bool(report["verdict_visible"]), str(report))
	_check_eq("the verdict word is the locale's grade word, not the id",
		String(report["verdict"]), Locale.t("shotPerfect"))
	_check_eq("the mode line is the locale's mode word",
		String(report["verdict_mode"]), Locale.t("shotModeControl"))
	_check_eq("a perfect grade takes the reference's #74ffba",
		String(report["verdict_color"]), "74ffba")
	_check("it fades with `life / 0.28`, as the reference does",
		is_equal_approx(float(report["verdict_alpha"]), 0.5), str(report["verdict_alpha"]))
	_check("it is anchored to the athlete who HIT, not to the one under control",
		String(report["verdict_paddle"]) == "playerMate"
			and _at(report["verdict_at"], _verdict_ground(0.14)),
		"paddle=%s at=%s" % [str(report["verdict_paddle"]), str(report["verdict_at"])])
	var settled: float = (report["verdict_at"] as Vector3).y
	_state.shotFeedback = _feedback("shot:perfect", "shotMode:control", "perfect", "playerMate", 0.05)
	_marks.update(_state, false)
	_check("the verdict drifts upwards as it fades",
		float((_marks.report()["verdict_at"] as Vector3).y) > settled,
		"%f -> %f" % [settled, float((_marks.report()["verdict_at"] as Vector3).y)])
	_state.shotFeedback = _feedback("shot:perfect", "shotMode:control", "perfect", "", 0.14)
	_marks.update(_state, false)
	_check("a feedback with no paddle key draws no verdict",
		not bool(_marks.report()["verdict_visible"]), "")
	_state.shotFeedback = _feedback("shot:perfect", "shotMode:control", "perfect", "playerMate", 0.0)
	_marks.update(_state, false)
	_check("a spent feedback draws no verdict", not bool(_marks.report()["verdict_visible"]), "")
	for row in [["shot:good", "good", "77e7ff"], ["shot:early", "early", "ffd45c"],
			["shot:late", "late", "ff8b70"], ["shotSmashX2", "smashX2", "ffffff"]]:
		_state.shotFeedback = _feedback(String(row[0]), MODE_CONTROL, String(row[1]), "playerMate", 0.14)
		_marks.update(_state, false)
		_check_eq("a %s grade takes the reference's #%s" % [String(row[1]), String(row[2])],
			_marks.report()["verdict_color"], String(row[2]))
	_state.shotFeedback = null
	_section_done("_verdict")


# ---------------------------------------------------------------------------
# E. The A/B mute, the report contract and the capture marker lines
# ---------------------------------------------------------------------------

func _mute_and_capture() -> void:
	_state.shotCharge = 0.6
	_state.shotRead["active"] = true
	_state.shotRead["eta"] = 0.0
	_state.shotFeedback = _feedback("shot:perfect", "shotMode:control", "perfect", "playerMate", 0.14)
	_marks.update(_state, false)
	var charged: Dictionary = _marks.report()
	_check("the frame before the A/B has the marks on screen",
		bool(charged["ring_visible"]) and bool(charged["energy_visible"]), str(charged))

	var before: String = String(charged["verdict"])
	_marks.set_muted(true)
	_marks.update(_state, false)
	var muted: Dictionary = _marks.report()
	# The mute's own state is not a getter any more (F-10): it is asserted by the
	# frame it produces — every timing mark off for the same tick — and by the
	# restore below.
	_check("the A/B mute turns every timing mark off for the same tick",
		not bool(muted["ring_visible"]) and not bool(muted["prec_visible"])
			and not bool(muted["advice_visible"]) and not bool(muted["energy_visible"])
			and not bool(muted["verdict_visible"]),
		str(muted))
	_check("a muted frame reports no placement at all",
		(muted["ring_at"] as Vector3) == Vector3.ZERO and float(muted["prec_width"]) == 0.0
			and String(muted["energy_color"]) == "",
		str(muted))
	_marks.set_muted(false)
	_marks.update(_state, false)
	_check("switching the mute back restores the same frame",
		bool(_marks.report()["ring_visible"])
			and String(_marks.report()["verdict"]) == before,
		str(_marks.report()))

	# The report is a copy: a caller cannot write into the module's state.
	var copy: Dictionary = _marks.report()
	copy["fraction"] = -1.0
	_check("the report is a copy, not the module's own dictionary",
		not is_equal_approx(float(_marks.report()["fraction"]), -1.0), str(_marks.report()["fraction"]))

	# The capture's marker lines: the format the evidence files quote.
	var lines: PackedStringArray = _marks.capture_lines(null)
	_check_eq("the frame recorder gets its two marker lines", lines.size(), 2)
	if lines.size() == 2:
		_check("the timing line is the one the evidence files quote, key for key",
			String(lines[0]).begins_with("CAPTURE_TIMING ring=(")
				and String(lines[0]).contains("ring_visible=true")
				and String(lines[0]).contains("radius_m=0.620")
				and String(lines[0]).contains("segments="),
			String(lines[0]))
		_check("the verdict line carries the report's own word, mode, grade and paddle",
			String(lines[1]).begins_with("CAPTURE_VERDICT word=")
				and String(lines[1]).contains("word=%s mode=%s grade=perfect paddle=playerMate alpha=0.500" % [
					Locale.t("shotPerfect"), Locale.t("shotModeControl")]),
			String(lines[1]))
	_check("no camera is the shell's own (-1, -1), never a crash",
		String(_marks.capture_lines(null)[0]).contains("ring=(-1,-1)"), str(_marks.capture_lines(null)))

	# Before it is mounted the module is inert: no marks, nothing to report.
	var unmounted = _module.new()
	_check("an unmounted module draws nothing and reports nothing",
		unmounted.update(_state, false).is_empty() and unmounted.report().is_empty(), "")
	_section_done("_mute_and_capture")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A live quick-match state, as `Match.tscn`'s own `start_match` leaves it: the sim
## creates it stopped (`sim.gd:372`) and the shell sets `running`.
func _live_state() -> Variant:
	var state = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.running = true
	return state


## The state's own words, the way the reference stores them (`sim.gd:1245-1246`).
func _feedback(text: String, mode: String, grade: String, paddle: String,
		life: float) -> Dictionary:
	return {"text": text, "mode": mode, "grade": grade, "quality": 1.0,
		"life": life, "paddleKey": paddle}


func _ground(key: String) -> Vector3:
	var paddle = _state.paddle(key)
	return Court.world_pos(paddle.x, paddle.y, 0.0)


## Where the verdict must sit: the hitter's feet, the measured height, plus the
## reference's `(0.78 - life) * 18 px` of drift in metres (`js/render.js:1062`).
func _verdict_ground(life: float) -> Vector3:
	var lift: float = (VERDICT_LIFE - life) * (VERDICT_DRIFT / VERDICT_LIFE)
	return _ground("playerMate") + Vector3(0.0, VERDICT_HEIGHT + lift, 0.0)


func _at(got: Variant, expected: Vector3) -> bool:
	var v: Vector3 = got
	return (absf(v.x - expected.x) < 0.001 and absf(v.y - expected.y) < 0.001
		and absf(v.z - expected.z) < 0.001)


## Every match of a pattern in a source text, as a set-like list, for the ownership
## scans above.
func _matches(text: String, pattern: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string(pattern)
	if re == null or text == "":
		return out
	for m in re.search_all(text):
		var hit := m.get_string()
		if not out.has(hit):
			out.append(hit)
	return out


## The text of a resource, or `""` when it is not on disk.
func _text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("ok %s" % name)
	else:
		_failures += 1
		print("FAIL %s: %s" % [name, detail])


func _check_eq(name: String, got: Variant, expected: Variant) -> void:
	_check(name, got == expected, "expected %s, got %s" % [str(expected), str(got)])


func _report_tally() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
