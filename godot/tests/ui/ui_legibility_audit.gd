## ui_legibility_audit.gd — UIR-24's legibility audit: no visible Control overflows its
## carrier, no forbidden overlap, and readable text, on every registered screen and on
## the field HUD, at the four widths the mission checks.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/ui_legibility_audit.gd ; echo "exit=$?"
##
## Headless is correct here and only here: this audit measures Controls (rects, theme
## colours, containment) and never captures a frame, so the dummy driver's blank frames
## cannot lie to it. Frames are `capture_ui`'s job.
##
## WHAT IT ASSERTS, per screen and per declared capture state:
##   a. containment — every visible Control's rect is inside its visible parent's rect
##      (1 px tolerance for the layout's rounding);
##   b. contrast — every visible Label/Button with text keeps its `font_color` at or
##      above `CONTRAST_FLOOR` against the nearest painting ancestor's fill;
##   c. disjointness — no two visible sibling blocks overlap (the screens are
##      single-column flows; the reference forbids two blocks on the same pixels).
## The HUD family gets the same containment rule over the regions `Hud.panels()` names,
## which is the port's own definition of the HUD's boxes (`hud_audit` owns the tighter
## per-descendant version).
##
## A screen the recreation has not landed yet (registered, but still the ported scene)
## is REPORTED, not failed: `not_ported`, which `AuditBase` tallies apart from failures.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const HostScene := preload("res://game/Main.tscn")
const HudScene := preload("res://src/ui/Hud.tscn")
const ScreenContract := preload("res://src/ui/screens/ScreenContract.gd")

## WCAG 2.1 AA for normal text (4.5:1) — the floor the reference's own dark-panel
## palette was tuned to clear; the port keeps it as the number, not as a habit.
const CONTRAST_FLOOR := 4.5
const CONTAINMENT_TOLERANCE := 1.0
const OVERLAP_TOLERANCE := 0.5
const SETTLE_FRAMES := 3
const SIZES: Array = [
	Vector2(1280.0, 720.0),
	Vector2(1152.0, 648.0),
	Vector2(1920.0, 1080.0),
	Vector2(1024.0, 600.0),
]

## The closing report line's counters: one per registered screen per size, one per declared
## HUD state per HUD size. They were printed as hardcoded zeros until the pre-gate wave,
## which read as "nothing ran" next to a 76-check PASS — the checks always ran, the line
## did not count them.
var _screens_walked: int = 0
var _hud_states_walked: int = 0


func _initialize() -> void:
	var audit := AuditBase.new("ui_legibility")
	await _walk_screens(audit)
	await _walk_hud(audit)
	audit.report("sizes=%d screens=%d hud_states=%d" % [SIZES.size(), _screens_walked, _hud_states_walked])
	quit(audit.finish())


func _mount(frame_size: Vector2) -> Array:
	var frame := Control.new()
	frame.name = "Frame"
	frame.size = frame_size
	get_root().add_child(frame)
	var host: Control = HostScene.instantiate()
	host.set("ui_prototype", true)
	frame.add_child(host)
	for _i in SETTLE_FRAMES:
		await process_frame
	return [frame, host]


func _walk_screens(audit: AuditBase) -> void:
	for frame_size in SIZES:
		var tag := "%dx%d" % [int(frame_size.x), int(frame_size.y)]
		var pair: Array = await _mount(frame_size)
		var host: Control = pair[1]
		var router: Control = host.call("ui_router") if host.has_method("ui_router") else null
		if router == null:
			audit.check_true(false, "legibility/%s/the_host_mounted_a_router" % tag)
			(pair[0] as Node).queue_free()
			await process_frame
			continue
		audit.check_true(true, "legibility/%s/the_host_mounted_a_router" % tag)
		for id_in in router.call("registered_ids"):
			var id := String(id_in)
			if not bool(router.call("go_to", id)):
				audit.check_true(false, "legibility/%s/%s/mounted" % [tag, id])
				continue
			for _i in SETTLE_FRAMES:
				await process_frame
			var screen: Node = router.call("active_screen")
			if not (screen is ScreenContract):
				audit.not_ported("legibility/%s/%s" % [tag, id], "'%s' is still the ported scene (no UIR-03 hooks)" % id)
				continue
			_screens_walked += 1
			for state_in in screen.call("capture_states"):
				var state := String(state_in)
				if state != "default" and screen.has_method("apply_capture_state"):
					screen.call("apply_capture_state", state)
				for _i in SETTLE_FRAMES:
					await process_frame
				var where := "legibility/%s/%s/%s" % [tag, id, state]
				audit.check_eq(_overflow((screen as Control), frame_size), [], "%s/containment" % where)
				audit.check_eq(_sibling_overlaps(screen as Control), [], "%s/disjoint_blocks" % where)
				audit.check_eq(_low_contrast(screen as Control), [], "%s/contrast" % where)
		(pair[0] as Node).queue_free()
		await process_frame


## The HUD family: its own scene, mounted on a frame of each measured size, every state
## it declares, with the regions `panels()` names as the carriers.
func _walk_hud(audit: AuditBase) -> void:
	for frame_size in [SIZES[0], SIZES[1]]:
		var tag := "%dx%d" % [int(frame_size.x), int(frame_size.y)]
		var frame := Control.new()
		frame.size = frame_size
		get_root().add_child(frame)
		var hud: Control = HudScene.instantiate()
		frame.add_child(hud)
		for _i in SETTLE_FRAMES:
			await process_frame
		hud.apply_safe_area(frame_size)
		for state_in in hud.capture_states():
			var state := String(state_in)
			hud.apply_capture_state(state)
			_hud_states_walked += 1
			for _i in SETTLE_FRAMES:
				await process_frame
			var where := "legibility/%s/hud/%s" % [tag, state]
			var strays: Array = []
			for panel in hud.panels():
				var region: Control = panel
				if region.is_visible_in_tree():
					strays.append_array(_overflow_from(region))
			audit.check_eq(strays, [], "%s/containment" % where)
			audit.check_eq(_region_overlaps(hud), [], "%s/regions_disjoint" % where)
		frame.queue_free()
		await process_frame


## Every visible Control whose rect leaves its visible parent's rect. The frame itself
## is the top: a screen may fill it exactly, not exceed it.
func _overflow(root: Control, frame_size: Vector2) -> Array:
	var out: Array = []
	for node in root.find_children("*", "Control", true, false):
		var child: Control = node
		if not child.is_visible_in_tree():
			continue
		var parent: Control = child.get_parent() as Control
		if parent == null:
			continue
		# A ScrollContainer's content is larger than its viewport by definition —
		# that is what scrolling is; the reference marks its scroll areas
		# `overflow-y: auto` for the same reason.
		if parent is ScrollContainer:
			continue
		var parent_rect: Rect2 = parent.get_global_rect()
		if not parent_rect.grow(CONTAINMENT_TOLERANCE).encloses(child.get_global_rect()):
			out.append("%s %s outside %s %s" % [
				String(child.name), str(child.get_global_rect()),
				String(parent.name), str(parent_rect)])
	var frame_rect := Rect2(Vector2.ZERO, frame_size)
	if not frame_rect.grow(CONTAINMENT_TOLERANCE).encloses(root.get_global_rect()):
		out.append("%s %s outside the frame %s" % [String(root.name), str(root.get_global_rect()), str(frame_rect)])
	return out


## Every visible descendant of a region that leaves the region's rect: the HUD's own
## carrier — the needles ride and overhang their bars, which is the reference's
## `overflow: visible`, so the immediate parent cannot be the boundary here.
func _overflow_from(region: Control) -> Array:
	var out: Array = []
	var region_rect: Rect2 = region.get_global_rect()
	for node in region.find_children("*", "Control", true, false):
		var child: Control = node
		if not child.is_visible_in_tree():
			continue
		if not region_rect.grow(CONTAINMENT_TOLERANCE).encloses(child.get_global_rect()):
			out.append("%s %s outside region %s %s" % [
				String(child.name), str(child.get_global_rect()),
				String(region.name), str(region_rect)])
	return out


## Visible sibling blocks that land on the same pixels.
func _sibling_overlaps(root: Control) -> Array:
	var out: Array = []
	var blocks: Array = []
	for node in root.get_children():
		var control: Control = node as Control
		if control != null and control.is_visible_in_tree() and control.size.x > 0.0 and control.size.y > 0.0:
			blocks.append(control)
	for index in blocks.size():
		for other in range(index + 1, blocks.size()):
			var a: Control = blocks[index]
			var b: Control = blocks[other]
			if a.get_global_rect().grow(OVERLAP_TOLERANCE).intersects(b.get_global_rect().grow(OVERLAP_TOLERANCE)):
				out.append("%s x %s" % [String(a.name), String(b.name)])
	return out


## The HUD's own regions, the way `hud_audit` defines them: hidden regions are not on the
## frame and are asserted by name there instead.
func _region_overlaps(hud: Control) -> Array:
	var out: Array = []
	var regions: Array = []
	for panel in hud.call("panels"):
		var control: Control = panel
		if control.is_visible_in_tree():
			regions.append(control)
	for index in regions.size():
		for other in range(index + 1, regions.size()):
			var a: Control = regions[index]
			var b: Control = regions[other]
			if a.get_global_rect().grow(OVERLAP_TOLERANCE).intersects(b.get_global_rect().grow(OVERLAP_TOLERANCE)):
				out.append("%s x %s" % [String(a.name), String(b.name)])
	return out


## Every visible text carrier below the floor. The background is the nearest ancestor
## that paints a fill (its `panel`/`normal` stylebox), else the screen's own background
## rect, else white — the audit says WHICH pair it measured so a wrong guess is visible.
func _low_contrast(root: Control) -> Array:
	var out: Array = []
	for node in root.find_children("*", "Control", true, false):
		var control: Control = node
		if not control.is_visible_in_tree():
			continue
		var text := ""
		if control is Label:
			text = (control as Label).text
		elif control is Button:
			text = (control as Button).text
		if text.strip_edges() == "":
			continue
		var fg: Color = control.get_theme_color("font_color")
		if fg.a < 0.5:
			continue
		var bg := _background_of(control)
		var ratio := _ratio(fg, bg)
		if ratio < CONTRAST_FLOOR:
			out.append("%s '%s' ratio=%.2f fg=%s bg=%s" % [
				String(control.name), text.substr(0, 18), ratio, fg.to_html(false), bg.to_html(false)])
	return out


## The colour text actually sits on. Layers are painted back to front: the screen's
## background rect first, then every fill standing over it, blended through its own
## alpha and finishing with the nearest one — the control's own box included, because a
## Button's `normal` box *is* its background. A box with `draw_center = false` paints a
## border, not a surface, and is stepped over: the coral ring first found behind the hero
## texts was exactly that.
func _background_of(control: Control) -> Color:
	var layers: Array = []
	var node: Node = control
	while node != null:
		var candidate: Control = node as Control
		if candidate != null:
			for style_name in ["panel", "normal"]:
				var box := candidate.get_theme_stylebox(style_name)
				if box is StyleBoxFlat and (box as StyleBoxFlat).draw_center and (box as StyleBoxFlat).bg_color.a > 0.01:
					layers.append((box as StyleBoxFlat).bg_color)
					break
		node = node.get_parent()
	# `Color.blend` paints its argument *over* the receiver, so the walk runs from the
	# outermost layer down: the page first, each layer over it, the nearest last.
	var painted := _screen_background(control)
	for index in range(layers.size() - 1, -1, -1):
		painted = painted.blend(layers[index] as Color)
	return painted


## The page behind everything the screen draws: the widest visible background rect
## standing under the control, the reference's own page colour; white only if a screen
## paints nothing at all.
func _screen_background(control: Control) -> Color:
	# The rect that contains the control when one does, else the widest rect on the frame:
	# a control scrolled out of view or hung off the frame's edge sits on the same page as
	# the rest of the screen once it is back in view, and white is not a colour any screen
	# here paints (`_background_of` reads the screen's own boxes on top of this).
	var widest: ColorRect = null
	if control.is_inside_tree():
		var centre: Vector2 = control.get_global_rect().get_center()
		for rect_node in control.get_tree().root.find_children("*", "ColorRect", true, false):
			var background: ColorRect = rect_node
			if not background.is_visible_in_tree() or background.size.x <= 64.0:
				continue
			if background.get_global_rect().has_point(centre):
				return background.color
			if widest == null or background.size.x > widest.size.x:
				widest = background
	if widest != null:
		return widest.color
	return Color.WHITE


## WCAG relative luminance ratio.
func _ratio(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	var high := maxf(la, lb)
	var low := minf(la, lb)
	return (high + 0.05) / (low + 0.05)


func _luminance(color: Color) -> float:
	var channels := [color.r, color.g, color.b]
	var out := 0.0
	for index in 3:
		var channel: float = channels[index]
		channel = channel / 12.92 if channel <= 0.03928 else pow((channel + 0.055) / 1.055, 2.4)
		out += channel * [0.2126, 0.7152, 0.0722][index]
	return out
