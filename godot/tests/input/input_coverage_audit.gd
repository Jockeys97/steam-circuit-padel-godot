## input_coverage_audit.gd — every action, and what a player can press to fire it.
##
##   cd /root/projects/steam-circuit-padel-pro && \
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/input/input_coverage_audit.gd
##   … add `-- --list-actions` to print only the inventory and the summary.
##
## This is the ported form of the reference's pad-help checks: the browser's pad
## help strings exist because the mapping exists, and the mapping is the thing a
## player discovers by pressing buttons. Two questions, both answerable by machine:
##
##   1. **Does the port's input map carry what the reference wires?** The device
##      coverage is the reference's own (`godot/src/input/scheme.gd`, anchors in
##      `js/main.js` and `GAMEPLAY_RULES.md:152-180`); the bindings are read from
##      the live `InputMap` (`godot/project.godot`, owned by the quick-match
##      slice), so this audit compares two independent things and fails on drift.
##   2. **Is the coverage enumerable?** Every action, its pad binding, its keyboard
##      binding, its help label — printed as one line per action between the
##      `# input-inventory` markers, so the evidence file is generated, not typed.
##
## A NOTE ON THE STRICTER RULE, stated rather than quietly dropped. The ticket's
## own text (`docs/implementation/tickets/accessibility-locales-performance.md:108`)
## asks that "a pad-only action is a failure because the keyboard is the fallback
## path". That is not what the reference does: eight of its actions are pad-only by
## design — the lob has no keyboard branch at all (`js/main.js:1079`), LT and RT are
## analog, RB is the technical modifier and the D-pad sets the pair's tactic
## (`GAMEPLAY_RULES.md:159-175`). The port asserts the reference's coverage as a
## *floor* and reports the eight, because inventing keyboard keys for them would be
## a new feature, and because the input map belongs to another lane.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Scheme := preload("res://src/input/scheme.gd")
const RemapModel := preload("res://src/input/remap.gd")
const InputStrings := preload("res://src/input/strings.gd")

## `godot/project.godot` declares seventeen `padel_*` actions and `menu_quit`.
const PROJECT_ACTION_COUNT := 18
## The actions the reference wires on the pad only — see the header.
const PAD_ONLY := [
	"padel_lob", "padel_split_step", "padel_sprint", "padel_technical",
	"padel_tactic_attack", "padel_tactic_balanced", "padel_tactic_defend", "padel_tactic_staggered",
]
## The menu actions the reference maps on BOTH devices: the arrows and the D-pad /
## stick navigate, `ui_accept` is A/Cross and Enter/Space, `ui_cancel` is
## B/Circle and Escape (`js/main.js:940-996`, `js/main.js:2551-2569`).
const MENU_DUAL_DEVICE := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]


func _initialize() -> void:
	var audit := AuditBase.new("input_coverage")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var snapshot := {}
	for row in Scheme.snapshot():
		snapshot[String(row["id"])] = row

	# --- 1. the declared inventory exists in the live map -------------------
	var missing: Array = []
	for action in Scheme.ids():
		if not InputMap.has_action(action):
			missing.append(action)
	audit.check_eq(missing, [], "coverage/every_declared_action_exists_in_the_input_map")
	audit.check_eq(Scheme.ids().size(), 24, "coverage/the_scheme_declares_twenty_four_actions")
	audit.check_eq(Scheme.gameplay_ids().size(), 17, "coverage/seventeen_gameplay_actions")
	audit.check_eq(Scheme.menu_ids().size(), 7, "coverage/seven_menu_actions")

	# ...and the reverse, restricted to the actions the project itself declares:
	# a new `padel_*` action that no row describes would be invisible here.
	var declared := Scheme.project_declared_actions()
	audit.check_eq(declared.size(), PROJECT_ACTION_COUNT, "coverage/the_project_declares_eighteen_actions")
	var undeclared: Array = []
	for action in declared:
		if not Scheme.ids().has(action):
			undeclared.append(action)
	audit.check_eq(undeclared, [], "coverage/project_declared_actions_match_the_scheme")
	var phantom: Array = []
	for action in Scheme.gameplay_ids() + ["menu_quit"]:
		if not declared.has(action):
			phantom.append(action)
	audit.check_eq(phantom, [], "coverage/the_scheme_names_no_action_the_project_does_not_declare")

	# --- 2. the reference's device coverage is the floor --------------------
	var keyboard_short: Array = []
	var pad_short: Array = []
	for action in Scheme.ids():
		var row: Dictionary = snapshot[action]
		var devices: Array = Scheme.devices(action)
		if devices.has("keyboard") and row["keys"].is_empty():
			keyboard_short.append(action)
		if devices.has("pad") and row["buttons"].is_empty() and row["axes"].is_empty():
			pad_short.append(action)
	audit.check_eq(keyboard_short, [], "coverage/every_keyboard_action_has_a_key_in_the_live_map")
	audit.check_eq(pad_short, [], "coverage/every_pad_action_has_a_button_or_axis_in_the_live_map")
	audit.check_eq(Scheme.pad_ids().size(), 23, "coverage/twenty_three_actions_reach_the_pad")
	audit.check_eq(Scheme.keyboard_ids().size(), 16, "coverage/sixteen_actions_reach_the_keyboard")

	# The gameplay actions the reference wires on both devices, by name.
	for action in ["padel_left", "padel_right", "padel_up", "padel_down", "padel_drive",
			"padel_slice", "padel_special", "padel_switch", "padel_pause"]:
		audit.check_true(
			not (snapshot[action] as Dictionary)["keys"].is_empty()
			and (not (snapshot[action] as Dictionary)["buttons"].is_empty()
				or not (snapshot[action] as Dictionary)["axes"].is_empty()),
			"coverage/%s_is_bound_on_both_devices" % action,
		)

	# --- 3. the menu's pad contract (scripts/gamepad-nav-audit.mjs:84-92) ---
	var accept: Dictionary = snapshot["ui_accept"]
	var cancel: Dictionary = snapshot["ui_cancel"]
	audit.check_true(accept["buttons"].has("0"), "coverage/confirm_has_a_pad_button")
	audit.check_true(Scheme.CONFIRM_PAD_BUTTONS.has(0), "coverage/confirm_is_a_cross")
	audit.check_true(cancel["buttons"].has("1"), "coverage/back_has_a_pad_button")
	var second_back_button: bool = cancel["buttons"].has("2")
	for action in MENU_DUAL_DEVICE:
		var row: Dictionary = snapshot[action]
		audit.check_true(
			(not row["keys"].is_empty())
			and (not row["buttons"].is_empty() or not row["axes"].is_empty()),
			"coverage/%s_binds_both_a_key_and_a_pad_input" % action,
		)
	# Every D-pad direction the model resolves must be a real pad event somewhere:
	# up 11 / down 12 / left 13 / right 14, or the four ui_* axes.
	audit.check_true(
		snapshot["ui_up"]["buttons"].has("11") or snapshot["ui_up"]["axes"].has("1:-1.0"),
		"coverage/dpad_up_reaches_ui_up",
	)
	audit.check_true(
		snapshot["ui_down"]["buttons"].has("12") or snapshot["ui_down"]["axes"].has("1:+1.0"),
		"coverage/dpad_down_reaches_ui_down",
	)
	audit.check_true(
		snapshot["ui_left"]["buttons"].has("13") or snapshot["ui_left"]["axes"].has("0:-1.0"),
		"coverage/dpad_left_reaches_ui_left",
	)
	audit.check_true(
		snapshot["ui_right"]["buttons"].has("14") or snapshot["ui_right"]["axes"].has("0:+1.0"),
		"coverage/dpad_right_reaches_ui_right",
	)

	# --- 4. the pad-only set is the reference's, named ----------------------
	var pad_only: Array = []
	for action in Scheme.ids():
		if Scheme.devices(action) == ["pad"]:
			pad_only.append(action)
	pad_only.sort()
	var expected := PAD_ONLY.duplicate()
	expected.sort()
	audit.check_eq(pad_only, expected, "coverage/the_pad_only_actions_are_the_references_eight")
	audit.check_eq(Scheme.keyboard_ids(), Scheme.ids().filter(func(a: String) -> bool: return not pad_only.has(a)), "coverage/every_other_action_has_a_keyboard_path")

	# --- 5. help labels, or a declared reason for none ----------------------
	var unlabelled: Array = []
	for action in Scheme.ids():
		var row := Scheme.row(action)
		if String(row.get("label_id", "")) == "":
			if String(row.get("context", "")) == Scheme.CONTEXT_GAMEPLAY and not bool(row.get("port_only", false)):
				unlabelled.append(action)
	audit.check_eq(unlabelled, [], "coverage/every_gameplay_action_has_a_help_label")
	var broken_labels: Array = []
	for action in Scheme.ids():
		var label_id := String(Scheme.row(action).get("label_id", ""))
		if label_id != "" and not InputStrings.text(label_id).contains(label_id):
			continue
		if label_id != "" and InputStrings.text(label_id) == label_id:
			broken_labels.append(action)
	audit.check_eq(broken_labels, [], "coverage/every_help_label_resolves_through_the_locale")

	# --- 6. the inventory --------------------------------------------------
	var table := RemapModel.new().table()
	audit.check_eq(table.size(), Scheme.ids().size(), "coverage/the_inventory_covers_every_action")
	var rows_without_binding: Array = []
	for row in table:
		if String(row["keyboard"]) == "" and String(row["pad"]) == "":
			rows_without_binding.append(String(row["action"]))
	audit.check_eq(rows_without_binding, [], "coverage/no_action_is_bound_to_nothing")
	var unbounded: Array = []
	for row in table:
		if String(row["reference"]).strip_edges() == "":
			unbounded.append(String(row["action"]))
	audit.check_eq(unbounded, [], "coverage/every_action_carries_its_reference_anchor")

	var lines := _inventory_lines(table)
	if OS.get_cmdline_user_args().has("--list-actions"):
		for line in lines:
			print(line)
	else:
		audit.report("inventory: %d actions, %d printed lines between the `# input-inventory` markers" % [table.size(), lines.size()])
		for line in lines:
			print(line)

	audit.report("actions=%d keyboard=%d pad=%d pad_only=%d project_declared=%d" % [
		Scheme.ids().size(), Scheme.keyboard_ids().size(), Scheme.pad_ids().size(), pad_only.size(), declared.size(),
	])
	audit.not_ported(
		"coverage/every_action_binds_both_a_pad_button_and_a_keyboard_key",
		"the ticket asks for it (docs/implementation/tickets/accessibility-locales-performance.md:108) but the reference does not do it: %d actions are pad-only by design (%s), and the input map is another lane's file — asserted as a floor instead, and reported above" % [pad_only.size(), ", ".join(PackedStringArray(pad_only))],
	)
	audit.note("the back button: the reference's menuBack fires on b(1) OR b(2) (js/main.js:992) and the port's ui_cancel carries button 1 only (measured in the live InputMap); the model accepts both (nav/button_2_goes_back_too) and the InputMap half is a note for whoever owns godot/project.godot, not a silent drop")
	audit.note("the RT disagreement is the reference's own: index.html:252 labels RT \"Angolo\" (padSprintDesc) while GAMEPLAY_RULES.md:169-171 calls it the analog sprint and godot/project.godot binds padel_sprint to it")


## One line per action, stable enough to diff between runs.
static func _inventory_lines(table: Array) -> Array:
	var lines: Array = ["# input-inventory begin"]
	for row in table:
		lines.append("# input-inventory %s | context=%s | devices=%s | keyboard=%s | pad=%s | remappable=%s | label=%s | %s" % [
			row["action"], row["context"], ",".join(PackedStringArray(row["devices"])),
			"none" if String(row["keyboard"]) == "" else row["keyboard"],
			"none" if String(row["pad"]) == "" else row["pad"],
			"yes" if bool(row["remappable"]) else "no",
			"none" if String(row["label_id"]) == "" else row["label_id"],
			row["reference"],
		])
	lines.append("# input-inventory end")
	return lines
