## court_timing_marks.gd — THE one owner of the court timing presentation: the ring
## the charge fills, the green circle of a met perfect window, the advice word and its
## panel, the RT precision bar, the energy bar under the active athlete, and the
## verdict drawn over the athlete who hit.
##
## WHY THIS FILE EXISTS
##   `godot/game/match_controller.gd` grew the whole presentation: twenty-six
##   `TIMING_*` geometry constants with the reference anchors and the frame
##   measurements that forced them, eleven mark nodes and their state, the builders,
##   the per-frame placement, the verdict's own rendering, and the report the tests,
##   the capture's marker lines and the evidence read. All of that is one concern —
##   what the reference draws around `state[state.activePlayerKey]` and over the
##   athlete who hit (`js/render.js:1646-1750`, `:1031-1037`, `:1041-1069`) — sitting
##   inside the file that also owns the scene, the clock, the input latch and the
##   replay. This module is that one owner. The match shell creates it, mounts it and
##   calls it once a frame; it reaches for no private variable of the shell.
##
## WHAT IT OWNS
##   - the GEOMETRY: every `TIMING_*` constant, with the reference's canvas anchors
##     and the measurements that forced the port's values. A size is expressed through
##     `TIMING_M_PER_PX` for the reason the constants' own comments give: a faithful
##     number has to be faithful ON THE FRAME.
##   - the MARKS: the eleven nodes, built by `mount()` as children of the parent it is
##     handed. Same names, same build order, same parent the shell used before this
##     extraction — the tree did not move, the owner did.
##   - the PLACEMENT: `update()` decides what is drawn and where, once per frame, from
##     the live state — the ring's fill fraction and reconstructed arc, the window's
##     blink, the precision fill and its pulse, the advice word and its measured
##     panel, the energy bands, and the verdict over the athlete who HIT.
##   - the VERDICT'S RENDERING: the reference's two lines, its four colours, the
##     `life / 0.28` fade and the upward drift (`js/render.js:1041-1069`).
##   - the REPORT: `report()` — the numbers the last `update()` placed, for the tests,
##     the capture's marker lines and the evidence. This extraction ENRICHED it with
##     each mark's placed position (including the verdict's) and the colour each mark
##     was actually drawn with, so a test crosses this seam instead of reading the
##     shell's private timing variables.
##   - the CAPTURE'S LINES: `capture_lines()` renders the `CAPTURE_TIMING` /
##     `CAPTURE_VERDICT` marker lines the frame recorder prints (`_save_frame`), kept
##     byte-for-byte: a reader who cannot find the ring in the PNG cannot tell "not
##     drawn" from "drawn somewhere else".
##
## WHAT IS DELIBERATELY NOT HERE
##   - no simulation state and no rules: the sim stores, this module reads `state`;
##   - no vocabulary: the words and the colours come from `feedback_vocabulary.gd`
##     (gate 1's one owner of the feedback language), asked from here;
##   - no scene, no camera, no clock, no frame: the shell hands its own node as the
##     mount parent and calls `update()` from the one place it already synced the
##     views; the A/B capture's mute is a flag on this module, not on the shell.
##
## Behaviour is a move, not a change: every constant, comment, branch and value below
## is the one `godot/game/match_controller.gd` shipped, and
## `godot/tests/court_timing_marks_test.gd` pins the placement, the verdict and the
## report through this interface.
extends RefCounted

const Court := preload("res://game/court.gd")
const Vocabulary := preload("res://game/feedback_vocabulary.gd")

## Every mark `mount()` builds, in build order. The names are the ones the shell's
## scene carried before this extraction: the tree is unchanged, only its builder is.
const MARK_NAMES := [
	"TimingRingTrack", "TimingRing", "TimingWindow",
	"TimingPrecisionBar", "TimingPrecisionFill",
	"TimingEnergyBar", "TimingEnergyFill",
	"TimingAdvice", "TimingAdvicePanel",
	"TimingVerdict", "TimingVerdictMode",
]

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

# THE ONE CONVERSION BETWEEN THE REFERENCE'S CANVAS AND THIS FRAME.
# The reference draws on a 960x620 canvas the captures render at 1280x720, so its
# pixel values are read at `1280/960`; and on this frame the default camera maps one
# metre at the athlete's feet to ~36 px vertically, measured on a rendered frame —
# the 2.45 m pin floats 89 px above the athlete's feet, the 0.18 m energy track
# prints 7 px tall. Every size below is therefore expressed through
# `TIMING_M_PER_PX`, which is what makes a faithful size faithful ON THE FRAME
# rather than in the arithmetic.
const TIMING_PX_PER_M := 36.0
const TIMING_M_PER_PX := 1.0 / TIMING_PX_PER_M
const TIMING_FRAME_SCALE := 1280.0 / 960.0

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
## Restore the compact reference typography (11/14/9 at 60 reference pixels/m).
## Keep ring and bar geometry independent from this text-only presentation scale.
const TIMING_ADVICE_PX := 11
const TIMING_VERDICT_PX := 14
const TIMING_VERDICT_MODE_PX := 9
## Compact world-space lettering, independent of the timing ring/bar scale.
const TIMING_TEXT_M_PER_PX := 1.0 / 60.0
## The verdict over the athlete who hit (`js/render.js:1041-1069`): the grade word
## at `700 14px` with a 5 px `rgba(4, 14, 32, 0.9)` stroke, the mode line at
## `600 9px` fifteen pixels below it, and the whole thing rising `(0.78 - life) * 18`
## px while it fades with `alpha = clamp(life / 0.28, 0, 1)`.
const TIMING_VERDICT_FONT_PX := 14.0
const TIMING_VERDICT_MODE_FONT_PX := 9.0
## `p.fillText(feedback.mode, p.x, y + 15)` (`js/render.js:1068`), in metres.
const TIMING_VERDICT_MODE_DROP := 15.0 * TIMING_TEXT_M_PER_PX
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

## The mark the presentation hangs off: the node the shell handed `mount()`. All
## eleven marks are its children (it was the shell itself before this extraction).
var _parent: Node3D
## The ring that fills with the charge and its track, the green circle of a met
## perfect window, the advice word and its panel, the RT precision bar and the energy
## bar under the athlete's feet. Built by `mount`, placed every frame by `update`.
var _ring: MeshInstance3D
var _ring_track: MeshInstance3D
var _window: MeshInstance3D
var _advice: Label3D
var _advice_panel: MeshInstance3D
var _precision: MeshInstance3D
var _precision_track: MeshInstance3D
var _energy: MeshInstance3D
var _energy_track: MeshInstance3D
## The verdict over the athlete who hit (`js/render.js:1041-1069`). The mode line is
## the reference's own second line (`js/render.js:1066-1068`).
var _verdict: Label3D
var _verdict_mode: Label3D
## The last `update`'s numbers, for the tests, the shell's capture lines and the
## evidence. Never read back into the drawing: `update` recomputes.
var _report: Dictionary = {}
## Segments the fill arc was last built with: the mesh is rebuilt when the fill
## changes, not on every frame. `_fill_extent` is that same mesh's measured extent,
## reported so "the drawn arc got longer" is assertable without reaching for a node.
var _fill_segments: int = 0
var _fill_extent: float = 0.0
## Set only by the capture's A/B frame: every timing mark off, for the same tick.
var _muted: bool = false


# ---------------------------------------------------------------------------
# The seam: mount, update, report
# ---------------------------------------------------------------------------

## Build every mark as a child of `parent` (the match shell) and return how many were
## built. Idempotent in the sense that matters to a scene: called once, from the
## shell's own scene build, at the point the marks were always added.
func mount(parent: Node3D) -> int:
	_parent = parent
	var opaque := Color(1.0, 1.0, 1.0, 1.0)
	# The track the coloured arc fills along: `ctx.arc(0, 0, r, 0, PI*1.85)` stroked
	# in `rgba(255,255,255,0.22)` (`js/render.js:1664-1668`).
	_ring_track = _build_mesh("TimingRingTrack",
		_arc_mesh(TIMING_RING_RADIUS, TIMING_RING_WIDTH, TIMING_ARC_TRACK,
			Color(1.0, 1.0, 1.0, 0.22), false),
		_material(opaque, true, 1))
	# The fill. Its mesh is rebuilt as the charge moves; it starts empty.
	_ring = _build_mesh("TimingRing", null, _material(opaque, true, 2))
	# `if (inWindow)`: the green circle at `r + 5*scale`, `0.55 + 0.4*blink`
	# (`js/render.js:1679-1688`).
	_window = _build_mesh("TimingWindow",
		_arc_mesh(TIMING_RING_RADIUS + TIMING_FLASH_GAP, TIMING_FLASH_WIDTH, TAU,
			Color(0.549, 1.0, 0.784, 1.0), false),
		_material(Color(0.549, 1.0, 0.784, 1.0), true, 3))

	# The RT precision bar: a `46*scale x 5*scale` body at `rgba(4,14,32,0.78)` with
	# a `rgba(126,243,255,0.35)` rim, and a fill that grows from its left edge
	# (`js/render.js:1697-1717`).
	_precision_track = _build_mesh("TimingPrecisionBar", _bar_mesh(false),
		_material(Color(0.016, 0.055, 0.125, 0.78), true, 1))
	_precision = _build_mesh("TimingPrecisionFill", _bar_mesh(true),
		_material(Vocabulary.PRECISION_CYAN, true, 2))
	# The energy bar under the athlete's feet, with the reference's own three bands
	# (`js/render.js:1031-1037`).
	_energy_track = _build_mesh("TimingEnergyBar", _bar_mesh(false),
		_material(Color(0.016, 0.055, 0.125, 0.72), true, 1))
	_energy = _build_mesh("TimingEnergyFill", _bar_mesh(true),
		_material(Vocabulary.FIELD_ENERGY_TEAL, true, 2))

	# Compact advice and panel: 11 reference pixels at 1/60 metre per pixel.
	# Screen size follows the camera projection, not the viewport's raw pixels.
	_advice = Label3D.new()
	_advice.name = "TimingAdvice"
	_advice.font = ThemeDB.fallback_font
	_advice.font_size = TIMING_ADVICE_PX
	_advice.pixel_size = TIMING_TEXT_M_PER_PX
	_advice.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_advice.no_depth_test = true
	_advice.render_priority = 3
	_advice.visible = false
	parent.add_child(_advice)
	_advice_panel = _build_mesh("TimingAdvicePanel", _bar_mesh(false),
		_material(Color(0.016, 0.055, 0.125, 0.82), true, 2))

	# The verdict over the athlete who hit (`js/render.js:1041-1069`): the grade word
	# with the reference's dark stroke, and the mode line under it.
	_verdict = _verdict_label("TimingVerdict", TIMING_VERDICT_PX, 5)
	_verdict_mode = _verdict_label("TimingVerdictMode", TIMING_VERDICT_MODE_PX, 0)
	return MARK_NAMES.size()


## The marks this module built and placed, in build order — the module's own
## statement of what it owns, for the scene proof and the tests. Never the nodes.
func mark_names() -> PackedStringArray:
	return PackedStringArray(MARK_NAMES)


## The timing presentation, from the live state, once per frame. One place decides
## what is drawn and where; the nodes only follow, and the frame's own numbers are
## left in the report for the tests, the shell's capture lines and the evidence.
func update(state, finished: bool) -> Dictionary:
	if _ring == null:
		return report()
	var read: Dictionary = state.shotRead
	var active = state.active_player()
	var live: bool = bool(state.running) and not finished and active != null
	# `js/render.js:1656`: `(state.shotCharge ?? 0) > 0.05 && read?.active`.
	var charging: bool = (float(state.shotCharge) > TIMING_CHARGE_FLOOR
		and bool(read.get("active", false)))
	if _muted:
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
	_ring_track.visible = ring_on
	_ring.visible = ring_on
	if ring_on:
		var at := ground + Vector3(0.0, TIMING_RING_HEIGHT, 0.0)
		_ring.position = at
		_ring_track.position = at
		var segments := _arc_segments(TIMING_ARC_FILL * fraction)
		if segments != _fill_segments:
			_fill_segments = segments
			var arc := _arc_mesh(TIMING_RING_RADIUS, TIMING_RING_WIDTH,
				TIMING_ARC_FILL * fraction, Color(1.0, 1.0, 1.0, 1.0), true)
			_ring.mesh = arc
			_fill_extent = arc.get_aabb().size.length()
	_window.visible = ring_on and in_window
	if _window.visible:
		_window.position = ground + Vector3(0.0, TIMING_RING_HEIGHT, 0.0)
		var blink: float = 0.5 + 0.5 * sin(clock * 18.0)
		(_window.material_override as StandardMaterial3D).albedo_color.a = 0.55 + 0.4 * blink

	# --- the precision bar: `charge > 0.05 && precision > 0.04` ----------------
	var prec_on: bool = live and charging and precision > TIMING_PRECISION_FLOOR
	_precision_track.visible = prec_on
	_precision.visible = prec_on
	if prec_on:
		var armed: bool = tight > 0.02
		var pulse: float = (0.62 + 0.38 * sin(clock * 16.0)) if armed else 1.0
		var at := ground + Vector3(0.0, TIMING_PRECISION_HEIGHT, 0.0)
		_precision_track.position = at
		_precision.position = at + Vector3(-TIMING_PRECISION_W * 0.5, 0.0, 0.0)
		# The reference's rim: `roundRect(x - 1, y - 1, w + 2, h + 2)`.
		_precision_track.scale = Vector3(TIMING_PRECISION_W + 0.03, TIMING_PRECISION_H + 0.03, 1.0)
		_precision.scale = Vector3(maxf(0.02, TIMING_PRECISION_W * precision), TIMING_PRECISION_H, 1.0)
		var pmat := _precision.material_override as StandardMaterial3D
		pmat.albedo_color = Vocabulary.precision_color(tight, pulse)

	# --- the advice word: `!serving && !(pointPause > 0)` ----------------------
	var advice_on: bool = live and not bool(state.serving) and float(state.pointPause) <= 0.0
	_advice.visible = advice_on
	_advice_panel.visible = advice_on
	if advice_on:
		var word: String = Vocabulary.advice_word(Vocabulary.advice_of(read))
		var color: Color = Vocabulary.advice_color(String(read.get("profile", "control")))
		var at := ground + Vector3(0.0, TIMING_ADVICE_HEIGHT, 0.0)
		_advice.position = at
		_advice.text = word
		_advice.modulate = color
		# The panel is the reference's `measureText(label).width + 22` by 20 px box
		# (`js/render.js:1735-1742`) measured with the same font the label draws with,
		# in the reference's own ratios to its font: one line of padding either side
		# (22/11) in a box 20/11 lines tall. Placed just behind the text.
		var line_m: float = float(TIMING_ADVICE_PX) * TIMING_TEXT_M_PER_PX
		var text_px: float = 0.0
		if _advice.font != null:
			text_px = _advice.font.get_string_size(
				word, HORIZONTAL_ALIGNMENT_LEFT, -1, TIMING_ADVICE_PX).x
		_advice_panel.position = Vector3(at.x, at.y, at.z - 0.01)
		_advice_panel.scale = Vector3(
			maxf(line_m * TIMING_ADVICE_BOX_LINES, text_px * TIMING_TEXT_M_PER_PX + line_m * TIMING_ADVICE_PAD_LINES),
			line_m * TIMING_ADVICE_BOX_LINES, 1.0)

	# --- the energy bar: every frame, under the active athlete ----------------
	_energy_track.visible = live
	_energy.visible = live
	if live:
		var at := ground + Vector3(0.0, TIMING_ENERGY_HEIGHT, TIMING_FOOT_FORWARD)
		_energy_track.position = at
		_energy.position = at + Vector3(-TIMING_ENERGY_W * 0.5, 0.0, 0.0)
		# `fillRect(energyX - scale, energyY - scale, energyWidth + 2*scale, 4*scale)`
		# over a `2*scale` fill: the track is twice the fill's height.
		_energy_track.scale = Vector3(TIMING_ENERGY_W + 0.04, TIMING_ENERGY_H * 2.0, 1.0)
		_energy.scale = Vector3(maxf(0.02, TIMING_ENERGY_W * energy), TIMING_ENERGY_H, 1.0)
		var emat := _energy.material_override as StandardMaterial3D
		emat.albedo_color = Vocabulary.field_energy_color(energy)

	# --- the verdict over the athlete who hit ---------------------------------
	var report_verdict := _place_verdict(state, live)

	_report = {
		"charge": float(state.shotCharge),
		"charging": charging,
		"eta": eta,
		"fraction": fraction,
		"in_window": in_window,
		"ring_visible": ring_on,
		"ring_at": _ring.position if ring_on else Vector3.ZERO,
		"fill_segments": _fill_segments if ring_on else 0,
		"fill_radius": TIMING_RING_RADIUS,
		"fill_extent": _fill_extent if ring_on else 0.0,
		"prec_visible": prec_on,
		"precision": precision,
		"tight": tight,
		"prec_width": TIMING_PRECISION_W * precision if prec_on else 0.0,
		"prec_at": _precision_track.position if prec_on else Vector3.ZERO,
		"prec_fill_at": _precision.position if prec_on else Vector3.ZERO,
		"prec_color": _drawn_color(_precision) if prec_on else "",
		"advice_visible": advice_on,
		"advice": _advice.text if advice_on else "",
		"advice_color": _advice.modulate.to_html(false) if advice_on else "",
		"advice_panel_w": _advice_panel.scale.x if advice_on else 0.0,
		"advice_at": _advice.position if advice_on else Vector3.ZERO,
		"energy_visible": live,
		"energy": energy,
		"energy_width": TIMING_ENERGY_W * energy if live else 0.0,
		"energy_at": _energy_track.position if live else Vector3.ZERO,
		"energy_fill_at": _energy.position if live else Vector3.ZERO,
		"energy_color": _drawn_color(_energy) if live else "",
		"verdict_visible": report_verdict["visible"],
		"verdict": report_verdict["word"],
		"verdict_mode": report_verdict["mode"],
		"verdict_grade": report_verdict["grade"],
		"verdict_color": report_verdict["color"],
		"verdict_alpha": report_verdict["alpha"],
		"verdict_paddle": report_verdict["paddle"],
		"verdict_at": report_verdict["at"],
	}
	return report()


## What the last `update` drew: the ring's fill, the two bars' widths, the advice
## word and the verdict, as the frame computed them — with each mark's placed
## position and drawn colour added by this extraction, so the tests and the evidence
## read the presentation's own statement rather than re-deriving the reference's
## arithmetic. A copy: a caller cannot write into this module's state.
func report() -> Dictionary:
	return _report.duplicate()


## The capture's A/B frame: every timing mark off for the same tick, switched by the
## frame recorder and switched back. Nothing else about the presentation changes.
## The flag is deliberately not exposed: a caller reads the frame it produced, not
## the module's own state (the getter was removed as unused surface — review F-10).
func set_muted(muted: bool) -> void:
	_muted = muted


## The two marker lines `_save_frame` prints next to a written PNG: where the marks
## landed in that frame, and what the report says was drawn. Empty until the marks
## exist; `(-1, -1)` is a point with no camera, the same convention the shell's
## screen-space reads use.
func capture_lines(camera: Camera3D) -> PackedStringArray:
	var out := PackedStringArray()
	if _ring == null:
		return out
	var ring_at := _screen_px(camera, _ring.global_position)
	var advice_at := _screen_px(camera, _advice.global_position)
	var verdict_at := _screen_px(camera, _verdict.global_position)
	var energy_at := _screen_px(camera, _energy.global_position)
	# Both format strings are the shell's own, kept byte-for-byte: split across
	# adjacent literals for the line limit, joined before the `%` so the printed
	# line is character for character the one the evidence files quote.
	out.append(("CAPTURE_TIMING ring=(%.0f,%.0f) advice=(%.0f,%.0f) verdict=(%.0f,%.0f)"
		+ " energy=(%.0f,%.0f) ring_visible=%s advice_visible=%s verdict_visible=%s fill=%.3f"
		+ " segments=%d radius_m=%.3f energy=%.3f advice_w_m=%.3f") % [
		ring_at.x, ring_at.y, advice_at.x, advice_at.y, verdict_at.x, verdict_at.y,
		energy_at.x, energy_at.y,
		str(_ring.visible), str(_advice.visible), str(_verdict.visible),
		float(_report.get("fraction", 0.0)), int(_report.get("fill_segments", 0)),
		TIMING_RING_RADIUS, float(_report.get("energy", 0.0)),
		float(_report.get("advice_panel_w", 0.0))])
	out.append(("CAPTURE_VERDICT word=%s mode=%s grade=%s paddle=%s alpha=%.3f charge=%.3f"
		+ " eta=%.3f in_window=%s precision=%.3f") % [
		String(_report.get("verdict", "")), String(_report.get("verdict_mode", "")),
		String(_report.get("verdict_grade", "")), String(_report.get("verdict_paddle", "")),
		float(_report.get("verdict_alpha", 0.0)), float(_report.get("charge", 0.0)),
		float(_report.get("eta", 0.0)), str(bool(_report.get("in_window", false))),
		float(_report.get("precision", 0.0))])
	return out


# ---------------------------------------------------------------------------
# The builders (the reference's own paint order, made explicit)
# ---------------------------------------------------------------------------

## One of the two lines of the verdict: a camera-facing, depth-test-free label with
## the reference's dark stroke (`js/render.js:1060-1061`) at metres-per-screen-pixel.
func _verdict_label(node_name: String, font_size: int, outline: int) -> Label3D:
	var l := Label3D.new()
	l.name = node_name
	l.font = ThemeDB.fallback_font
	l.font_size = font_size
	l.pixel_size = TIMING_TEXT_M_PER_PX
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 4
	l.outline_size = outline
	l.outline_modulate = TIMING_VERDICT_OUTLINE
	l.modulate = Color(1.0, 1.0, 1.0, 0.9)
	l.visible = false
	_parent.add_child(l)
	return l


## A mark of the presentation: invisible until `update` says otherwise, and never
## casting a shadow (a billboarded transparent quad would).
func _build_mesh(node_name: String, mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	_parent.add_child(mi)
	return mi


## The material every mark shares. `render_priority` is the reference's paint order
## made explicit (track under fill, body of a bar under its fill), since with the
## depth test off nothing else separates two coplanar marks.
##
## `billboard_keep_scale` is what lets a bar be a unit quad sized by its node's
## scale: without it, billboarding throws the scale away and every bar would be one
## metre wide (`BaseMaterial3D.billboard_keep_scale`).
func _material(base: Color, use_vertex_color: bool, priority: int) -> StandardMaterial3D:
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
func _arc_mesh(radius: float, width: float, sweep: float, base: Color, gradient: bool) -> ArrayMesh:
	var segments: int = _arc_segments(sweep)
	var inner := radius - width * 0.5
	var outer := radius + width * 0.5
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in segments:
		var a0 := sweep * float(i) / float(segments)
		var a1 := sweep * float(i + 1) / float(segments)
		var d0 := Vector2(sin(a0), cos(a0))
		var d1 := Vector2(sin(a1), cos(a1))
		var c0: Color = _gradient(sin(a0)) if gradient else base
		var c1: Color = _gradient(sin(a1)) if gradient else base
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


## How many ribbon segments a sweep is drawn with. Reported per frame so a test can
## assert the FILL moved without reading the mesh.
func _arc_segments(sweep: float) -> int:
	return maxi(1, int(ceil(absf(sweep) / TIMING_ARC_STEP)))


## A unit quad in the XY plane facing +Z. `anchored_left` keeps x in 0..1, so the
## fill grows from the bar's left edge — `ctx.fillRect(x, y, w * value, h)`
## (`js/render.js:1716`); otherwise x is -0.5..0.5 and the node's scale is the whole
## extent, which is how the track is drawn.
func _bar_mesh(anchored_left: bool) -> ArrayMesh:
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
static func _gradient(t: float) -> Color:
	var x := clampf(t, 0.0, 1.0)
	for i in range(1, TIMING_GRADIENT.size()):
		var lo: Array = TIMING_GRADIENT[i - 1]
		var hi: Array = TIMING_GRADIENT[i]
		if x <= float(hi[0]):
			var span := maxf(0.0001, float(hi[0]) - float(lo[0]))
			return (lo[1] as Color).lerp(hi[1] as Color, (x - float(lo[0])) / span)
	return TIMING_GRADIENT[TIMING_GRADIENT.size() - 1][1]


# ---------------------------------------------------------------------------
# The verdict, and the small report helpers
# ---------------------------------------------------------------------------

## The verdict over the athlete who hit (`js/render.js:1041-1069`): `PERFETTO`,
## `BUONO`, `ANTICIPATO`, `RITARDATO` at the paddle the simulation says hit
## (`state.shotFeedback.paddleKey`), in the reference's own four colours and fading
## with `life / 0.28`. Returns what it drew.
func _place_verdict(state, live: bool) -> Dictionary:
	var out := {
		"visible": false, "word": "", "mode": "", "grade": "", "color": "",
		"alpha": 0.0, "paddle": "", "at": Vector3.ZERO,
	}
	var feedback: Variant = state.shotFeedback
	_verdict.visible = false
	_verdict_mode.visible = false
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
	var word: String = Vocabulary.feedback_label(String(feedback.get("text", "")))
	var mode: String = Vocabulary.mode_label(String(feedback.get("mode", "")))
	var color: Color = Vocabulary.field_grade_color(grade)
	# `alpha = clamp(feedback.life / 0.28, 0, 1)` (`js/render.js:1047`).
	var alpha: float = clampf(life / TIMING_VERDICT_FADE, 0.0, 1.0)
	# `y = p.y - 105*scale - (0.78 - life) * 18` (`js/render.js:1062`): the word rides
	# up as it fades, and it is anchored to the athlete who HIT, not to the one under
	# control.
	var feet: Vector3 = Court.world_pos(paddle.x, paddle.y, 0.0)
	var lift: float = (TIMING_VERDICT_LIFE - life) * (TIMING_VERDICT_DRIFT / TIMING_VERDICT_LIFE)
	var at := feet + Vector3(0.0, TIMING_VERDICT_HEIGHT + lift, 0.0)
	_verdict.position = at
	_verdict.text = word
	_verdict.modulate = Color(color.r, color.g, color.b, alpha)
	_verdict.visible = true
	_verdict_mode.position = at + Vector3(0.0, -TIMING_VERDICT_MODE_DROP, 0.0)
	_verdict_mode.text = mode
	_verdict_mode.modulate = Color(1.0, 1.0, 1.0, 0.9 * alpha)
	_verdict_mode.visible = true
	return {
		"visible": true, "word": word, "mode": mode, "grade": grade,
		"color": color.to_html(false), "alpha": alpha, "paddle": key, "at": at,
	}


## The colour a mark's own material carries right now, as the frame draws it.
func _drawn_color(mi: MeshInstance3D) -> String:
	var mat := mi.material_override as StandardMaterial3D
	return mat.albedo_color.to_html(false) if mat != null else ""


## Where a world point lands in the frame, or (-1, -1) when there is no camera. Used
## by `capture_lines`, which are what make a capture readable.
func _screen_px(cam: Camera3D, at: Vector3) -> Vector2:
	return cam.unproject_position(at) if cam != null else Vector2(-1.0, -1.0)
