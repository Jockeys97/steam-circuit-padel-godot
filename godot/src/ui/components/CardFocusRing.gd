## CardFocusRing.gd — the reference's `.menu-focus` ring, as a card-sized overlay.
##
## WHAT IT IS. `styles.css:733-738`, verbatim:
##
##     .menu-focus {
##       outline: 3px solid var(--cyan);
##       outline-offset: 3px;
##       border-radius: inherit;
##       animation: menu-focus-pulse 1.3s ease-in-out infinite;
##     }
##     @keyframes menu-focus-pulse {          /* :740-743 */
##       0%, 100% { outline-color: var(--cyan); }   /* #00e5ff */
##       50%      { outline-color: #a5ffe0; }
##     }
##
## The outline is the PAD'S OWN presentation and it is NOT the pointer's: `:hover`
## paints the card's own border at `rgba(0,229,255,0.35)` and moves it 3 px
## (`styles.css:335-340`), while `.menu-focus` paints a 3 px `#00e5ff` ring THREE PIXELS
## OUTSIDE the card, pulsing. The two are separate rules and the reference stacks them
## when both are true: `js/main.js:2579-2588` hands `.menu-focus` to the card under the
## pointer whenever a pad is connected (`if (!gamepad.connected) return;`), so with a
## controller in hand a hovered card wears the soft border, the lift AND the ring.
##
## WHY IT IS A CHILD OVERLAY, NOT A THEME VARIATION. A card is a `PanelContainer` and
## the `Panel`-family variations carry the card's OWN frame; `StyleBoxFlat` also carries
## at most one shadow, so the ring cannot ride the card's box. The overlay is a `Panel`
## laid into the card's content rect — the card's boxes zero their content margins
## (`CharactersScreen._theme_box`, `ArenaScreen._theme_box`), so that rect IS the card's
## rect — and its stylebox draws its border OUTSIDE that rect.
##
## WHY `expand_margin` AND NOT `position`/`scale`. `outline-offset: 3px` paints outside
## the element without moving it or changing the space it occupies.
## `StyleBoxFlat.expand_margin_*` is the one Godot mechanism with the same property, and
## it is measured layout-free: `get_minimum_size()` returns the CONTENT margins alone
## (18.0 with `expand_margin_* = 3`), and a card wearing an expand-margin panel keeps its
## own size — `godot/tests/ui/menu_hover_probe.gd`, recorded in
## `docs/agent-work/menu-hover/REPORT.md`. `position` and `scale` are both refused here
## for a reason of the engine's: a `Container` overwrites them on every re-sort
## (`Container::fit_child_in_rect` writes the rect and resets rotation and scale), which
## is the same constraint the hover lift works around.
##
## THE COLOURS ARE THE THEME'S. `cyan` and the pulse's `focus_pulse` are `Palette` reads
## (`padel_theme.tres`); the file carries no literal colour, and a missing token is
## RECORDED (`misses_of`) rather than silently substituted — `ControlLegend.gd`'s and
## `Hud.gd`'s contract. The audit asserts `misses_of` empty.
##
## THE PULSE OBEYS THE PLAYER. `body.reduce-motion` switches the keyframes off in the
## reference (`styles.css:2748-2758`) and leaves the ring at full width; here the policy
## is `UiMotionPolicy`, the port's one door for "may this animation run". With no policy
## the ring is drawn static, which is the reduce-motion frame.
extends Panel

const UiMotionPolicy := preload("res://src/ui/accessibility/UiMotionPolicy.gd")

## The node name every card screen can address the ring by.
const RING_NODE := "CardFocusRing"
## `outline-width: 3px` (`styles.css:734`).
const RING_WIDTH := 3
## `outline-offset: 3px` (`styles.css:735`) — the GAP between the card's edge and the
## ring's inner edge.
const RING_OFFSET := 3.0
## The drawn box is grown by the offset PLUS the width, because `expand_margin` grows the
## box and the border is then drawn INSIDE it: with a bare offset the ring would sit flush
## against the card, which is what the first capture showed. 3 + 3 puts the border in the
## band 3..6 px outside the card, which is exactly `outline-offset: 3px` over a 3 px
## `outline`.
const RING_EXPAND := RING_OFFSET + float(RING_WIDTH)
## `border-radius: inherit` (`styles.css:736`) — the card's own radius, kept literal.
## Chrome may expand an offset outline's radius by the offset; that is not reproduced and
## is recorded in `docs/agent-work/menu-hover/REPORT.md` rather than guessed at.
const RING_RADIUS := 12
## `1.3s ease-in-out infinite` (`styles.css:737`): one full cycle, half up, half down.
const PULSE_SECONDS := 1.3
## The keyframe the animation travels to (`styles.css:742`).
const PULSE_TOKEN := "focus_pulse"

var _misses: Array = []
var _tween: Tween = null


## The path this component loads itself by: `Panel.new()` would build the base node
## WITHOUT this script, and the UI lane addresses its components by `preload` rather than
## by a global `class_name`, so the factory instantiates the script by its own path
## (`load` is cached; a `const` preload of this same file would be a cycle).
const SELF_PATH := "res://src/ui/components/CardFocusRing.gd"

## Attaches a hidden ring to `card` and returns it. Idempotent: a card that already
## carries one keeps it, so a caller may attach before or after its own styling.
static func attach(card: Control) -> Panel:
	var existing := ring_of(card)
	if existing != null:
		return existing
	var ring: Panel = (load(SELF_PATH) as Script).new()
	ring.name = RING_NODE
	# The ring must never be the control under the pointer: it covers the whole card.
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", ring_box(card))
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.visible = false
	card.add_child(ring)
	return ring


## The ring a card carries, or null.
static func ring_of(card: Control) -> Panel:
	if card == null or not is_instance_valid(card):
		return null
	var found := card.get_node_or_null(RING_NODE)
	return found as Panel


## Shows the ring for the card the PAD holds and hides it for every other. `motion` is
## the port's policy; without one the ring is static, which is the reference's own
## reduce-motion frame.
static func set_focused(card: Control, focused: bool, motion: UiMotionPolicy = null) -> void:
	var ring := ring_of(card)
	if ring == null:
		return
	var wanted := focused and card.visible and card.is_visible_in_tree()
	if ring.visible != wanted:
		ring.visible = wanted
	if wanted:
		ring.start_pulse(motion)
	else:
		ring.stop_pulse()


## Whether the card is currently wearing the ring. The audit's read.
static func is_focused(card: Control) -> bool:
	var ring := ring_of(card)
	return ring != null and ring.visible


## The `Palette` keys the theme does not carry, for this card's ring, in first-seen
## order. A miss is loud (the audit fails on it) and never silently substituted.
static func misses_of(card: Control) -> Array:
	var ring := ring_of(card)
	return ring._misses.duplicate() if ring != null else []


## `.menu-focus`'s outline as a `StyleBoxFlat`: 3 px of `cyan` drawn 3 px outside the
## card's rect, at the card's own radius, with no fill.
static func ring_box(host: Control) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.content_margin_left = 0.0
	box.content_margin_top = 0.0
	box.content_margin_right = 0.0
	box.content_margin_bottom = 0.0
	box.border_color = palette_of(host, "cyan")
	box.set_border_width_all(RING_WIDTH)
	box.set_corner_radius_all(RING_RADIUS)
	box.set_expand_margin_all(RING_EXPAND)
	return box


## The gap between the card's edge and the ring's inner edge, in px — the reference's
## `outline-offset`. Exposed so a reader (and the audit) can check the geometry rather
## than trusting the two numbers above.
static func offset_of(box: StyleBoxFlat) -> float:
	if box == null:
		return 0.0
	return box.expand_margin_left - float(box.border_width_left)


## A `Palette` read through the card's own theme chain (`Control.get_theme_color` walks
## the same owner the card's frames come from). A key the theme does not carry is
## recorded on the ring and answered with the theme's `ink`, then white — never a
## literal of this file's own.
static func palette_of(host: Control, key: String) -> Color:
	if host == null or not is_instance_valid(host):
		return Color.WHITE
	if host.has_theme_color(key, "Palette"):
		return host.get_theme_color(key, "Palette")
	var ring := ring_of(host)
	if ring != null and not ring._misses.has(key):
		ring._misses.append(key)
	if host.has_theme_color("ink", "Palette"):
		return host.get_theme_color("ink", "Palette")
	return Color.WHITE


## The ring's stylebox, for a caller that wants to read its widths back. Static so an
## audit can ask a card that only types as `Panel`.
static func ring_style_of(card: Control) -> StyleBoxFlat:
	var ring := ring_of(card)
	if ring == null:
		return null
	return ring.ring_style()


## The ring's stylebox, for a caller that wants to read its widths back.
func ring_style() -> StyleBoxFlat:
	var box: StyleBox = get_theme_stylebox("panel")
	return box as StyleBoxFlat


## The ring's pulse: `ease-in-out` between `cyan` and the `focus_pulse` keyframe, one
## cycle per `PULSE_SECONDS`, forever. A policy that forbids motion leaves the ring at
## `cyan` — the animation's own 0 %/100 % frame.
func start_pulse(motion: UiMotionPolicy = null) -> void:
	stop_pulse()
	if motion != null and not motion.motion_allowed():
		return
	var box := ring_style()
	if box == null:
		return
	var from := palette_of(self, "cyan")
	var to := palette_of(self, PULSE_TOKEN)
	if from.is_equal_approx(to):
		return
	box.border_color = from
	_tween = create_tween()
	_tween.set_loops()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_pulse_to.bind(box, from, to), 0.0, 1.0, PULSE_SECONDS * 0.5)
	_tween.tween_method(_pulse_to.bind(box, from, to), 1.0, 0.0, PULSE_SECONDS * 0.5)


func stop_pulse() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	var box := ring_style()
	if box != null:
		box.border_color = palette_of(self, "cyan")


func _pulse_to(t: float, box: StyleBoxFlat, from: Color, to: Color) -> void:
	box.border_color = from.lerp(to, t)
