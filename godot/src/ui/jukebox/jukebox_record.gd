extends Control
## jukebox_record.gd — the Jukebox player card's procedural record motif.
##
## PROCEDURAL ON PURPOSE. The player card needs one piece of art that reads as
## "record player" without shipping an external generated asset or a texture pack
## the rest of the menus do not have. The disc, its grooves, its centre label and
## the rotation tick are drawn from the theme's own navy/cyan palette, so the motif
## stays crisp at 1280x720 and at 1920x1080 and costs the repository no binary.
##
## COST. The disc is rasterised ONCE by `_draw()`. Spinning is a tween on this
## node's own `rotation`, which reuses that raster: no shader, no particles, and
## deliberately no per-frame `queue_redraw()`. The only redraws are the two this
## control asks for itself — when the accent colour changes and when playback
## flips — so the motif adds nothing measurable to the frame budget.
##
## HONESTY. The tick mark is asymmetric on purpose: concentric circles alone would
## hide the rotation, and this motif must only ever turn while audio is really
## playing. `set_spinning(false)` also eases the disc back to its upright rest pose
## so a stopped player never sits frozen mid-turn.

## Seconds for one full turn. Slow enough to read as a record, not as an animation
## competing with the match.
const SPIN_SECONDS := 6.0

## Seconds spent easing back to the rest pose when playback stops.
const REST_SECONDS := 0.35

var _accent: Color = Color(0.0, 0.898, 1.0)
var _spinning: bool = false
var _spin_tween: Tween = null


func _ready() -> void:
	# The disc is drawn inside its own rect, so the pivot is the rect centre and the
	# rotation never leaves the space the layout gave this control.
	resized.connect(_recentre_pivot)
	_recentre_pivot()


func _recentre_pivot() -> void:
	pivot_offset = size * 0.5


## The label/rim colour, taken from the selected track's category by the screen.
func set_accent(colour: Color) -> void:
	if colour == _accent:
		return
	_accent = colour
	queue_redraw()


## Turns the disc while — and only while — the manager reports real playback.
func set_spinning(on: bool) -> void:
	if on == _spinning:
		return
	_spinning = on
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = null
	if not is_inside_tree():
		rotation = 0.0
		return
	if on:
		_spin_tween = create_tween().set_loops()
		_spin_tween.set_trans(Tween.TRANS_LINEAR)
		# A whole turn ends where it started, so the loop seam is invisible.
		_spin_tween.tween_property(self, "rotation", TAU, SPIN_SECONDS)
	else:
		var rest := create_tween()
		rest.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rest.tween_property(self, "rotation", 0.0, REST_SECONDS)
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	if radius <= 1.0:
		return

	# Vinyl body: near-black navy so the card behind it stays the lightest surface.
	draw_circle(centre, radius, Color(0.024, 0.031, 0.098))

	# Grooves: faint concentric rings, the disc's own texture.
	for i in 5:
		var groove := radius * (0.88 - 0.075 * float(i))
		draw_arc(centre, groove, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, 0.055), 1.0, true)

	# Rim: the accent, brighter while the disc is actually turning.
	draw_arc(centre, radius - 1.0, 0.0, TAU, 96, Color(_accent, 0.85 if _spinning else 0.45), 2.0, true)

	# A single cyan light-catch across the upper-left quadrant, the way a physical
	# record catches a lamp — it also gives the rotation a second read.
	draw_arc(centre, radius * 0.80, -2.45, -1.25, 32, Color(0.0, 0.898, 1.0, 0.34), 2.0, true)

	# Centre label: the category colour, dimmed so the title above stays dominant.
	var label_radius := radius * 0.33
	draw_circle(centre, label_radius, _accent.darkened(0.55))
	draw_arc(centre, label_radius, 0.0, TAU, 64, Color(_accent, 0.9), 1.5, true)

	# Rotation tick: the asymmetric mark that makes the spin readable.
	draw_line(
		centre + Vector2(0.0, -label_radius - 2.0),
		centre + Vector2(0.0, -radius * 0.55),
		Color(_accent, 0.95), 2.0, true
	)

	# Spindle hole.
	draw_circle(centre, maxf(radius * 0.055, 2.0), Color(0.016, 0.02, 0.07))
