## _probe_pace_row.gd — the setup row's minimum width, measured in the two states the
## legibility audit distinguishes.
## AD-HOC EVIDENCE, not a suite. `tests/ui/ui_legibility_audit.gd` is the gate: it walks
## every registered screen, every capture state and four frame widths, and fails any
## Control that leaves its parent's rect. This probe answers the question a FAIL line
## like
##
##   FAIL legibility/1280x720/modes/demo-locked/containment: expected [], got
##   ["Frame [P: (-32.5, 0.0), S: (1345.0, 720.0)] outside ModesScreen …"]
##
## raises but cannot explain: WHICH node makes the row too wide, and by how much.
##
## WHAT IT SHOWS. `SetupArea` centres the reference's own 712 px content box with two
## margins, `side = max(0, (size.x - 760) / 2) + 24`, and a `MarginContainer`'s minimum
## size INCLUDES its margins — so the content it holds has to fit 712 px or the row
## overflows the screen at every width (the margins grow with the frame, the box does
## not). The binding state is `demo-locked`, which the reference never renders: the
## three un-granted difficulty rungs are disabled there, and the theme's disabled
## segmented box measures 80-95 px against 36-51 px enabled, taking the row's minimum
## from 637 to 769 px. The row is an `HFlowContainer` for exactly that reason: it WRAPS
## (difficulty + length on the first line, pace on the second) instead of pushing
## `Frame` past the screen's right edge, while at the design frame the three groups
## still pack onto one line as they did before the pace group existed.
##
## Writes nothing, changes nothing: it mounts the screen, reads it and prints.
##
## Command: "$GODOT" --headless --path godot/ --script res://_probe_pace_row.gd
extends SceneTree

const ModesScene := preload("res://src/ui/screens/ModesScreen.tscn")
const ModesScreenClass := preload("res://src/ui/screens/ModesScreen.gd")
const Pace := preload("res://src/sim/pace.gd")

## The reference's own content box for `#matchSetup` (`styles.css:2129-2139`).
const CONTENT_BOX := 712.0
const TOLERANCE := 1.0
const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 3

## The row's own node and the three groups on it, in document order.
const ROW := "MatchSetup"
const GROUPS: Array[String] = ["DifficultyGroup", "LengthGroup", "PaceGroup"]

var failures := 0
var checks := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func _initialize() -> void:
	var frame := Control.new()
	frame.size = FRAME
	root.add_child(frame)
	for _i in SETTLE_FRAMES:
		await process_frame
	var screen: Node = ModesScene.instantiate()
	frame.add_child(screen)
	for _i in SETTLE_FRAMES:
		await process_frame

	var live: Dictionary = await _measure(screen, "default")
	var demo: Dictionary = await _measure(screen, "demo-locked")

	# The row's minimum, in both states, against the box the frame gives it.
	check(float(live["row_min"]) <= CONTENT_BOX + TOLERANCE,
		"live/the_row_minimum_fits_the_content_box")
	check(float(demo["row_min"]) <= CONTENT_BOX + TOLERANCE,
		"demo/the_row_minimum_fits_the_content_box")
	check(float(live["frame_min"]) <= FRAME.x + TOLERANCE, "live/the_frame_minimum_fits_the_screen")
	check(float(demo["frame_min"]) <= FRAME.x + TOLERANCE, "demo/the_frame_minimum_fits_the_screen")

	# The packing policy: one line at the design frame, and a wrap where the groups
	# cannot fit (which is the demo view and only the demo view, at this frame).
	check(int(live["wrapped"]) == 0, "live/three_groups_on_one_line")
	check(int(demo["wrapped"]) > 0, "demo/the_row_wraps_instead_of_overflowing")
	# The reference's own two groups keep their positions and their equal height.
	for line in [live, demo]:
		var state := String(line["state"])
		check(float(line["group_heights"][0]) > 0.0, "%s/the_first_group_has_a_height" % state)
	if int(live["wrapped"]) == 0:
		check(is_equal_approx(float(live["group_heights"][0]), float(live["group_heights"][2])),
			"live/the_three_groups_share_one_height")

	print("%s pace row: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


## Mounts one state and reports the numbers the FAIL line needs: the row's minimum,
## the frame's minimum, each group's size and position (a group whose `y` is not zero
## is on a second line) and the disabled rung widths that drive the difference.
func _measure(screen: Node, state: String) -> Dictionary:
	screen.apply_capture_state(state)
	for _i in SETTLE_FRAMES:
		await process_frame
	var row: Control = screen.find_child(ROW, true, false)
	var frame: Control = screen.find_child("Frame", true, false)
	var heights: Array = []
	var wrapped := 0
	print("=== %s: screen=%.1f" % [state, (screen as Control).size.x])
	print("  %-16s min=%.1f size=(%.1f, %.1f) type=%s" % [
		ROW, row.get_combined_minimum_size().x, row.size.x, row.size.y, row.get_class()])
	for group_name in GROUPS:
		var group: Control = screen.find_child(group_name, true, false)
		heights.append(group.size.y)
		if group.position.y > 0.0:
			wrapped += 1
		print("  %-16s min=(%.1f, %.1f) size=(%.1f, %.1f) pos=(%.1f, %.1f)" % [
			group_name, group.get_combined_minimum_size().x, group.get_combined_minimum_size().y,
			group.size.x, group.size.y, group.position.x, group.position.y])
	for key in ModesScreenClass.DIFFICULTY_ORDER:
		var button: Button = screen.find_child(ModesScreenClass.DIFFICULTY_PREFIX + key, true, false)
		if button != null:
			print("  diff %-8s disabled=%-5s min=%.1f text='%s'" % [
				key, str(button.disabled), button.get_combined_minimum_size().x, button.text])
	for id in Pace.ids():
		var button: Button = screen.find_child(ModesScreenClass.PACE_PREFIX + String(id), true, false)
		if button != null:
			print("  pace %-8s min=%.1f text='%s'" % [
				id, button.get_combined_minimum_size().x, button.text])
	return {
		"state": state,
		"row_min": row.get_combined_minimum_size().x,
		"frame_min": frame.get_combined_minimum_size().x,
		"group_heights": heights,
		"wrapped": wrapped,
	}
