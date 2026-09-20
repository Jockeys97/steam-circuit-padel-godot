## textfield_declared_audit.gd — "a text field is text only if it declares it".
##
##   cd godot/ && "$GODOT" --headless --path . --script res://tests/input/textfield_declared_audit.gd
##
## The reference asks its question of the DOM: `isTextField` (`js/main.js`, function
## `isTextField`) accepts an `<input>` whose `type` is one of
## `text|search|email|url|tel|password`, **including the empty string**, because an
## `<input>` with no `type` attribute is a text input in HTML. `FocusNav.is_text_field`
## (`godot/src/input/focus_nav.gd`) ported that set verbatim, and the empty string
## travelled with it. In the port the target is not an element but a dictionary:
## `game/menu_focus.gd::_target()` never emits `input_type`, no screen registers one,
## and `Dictionary.get("input_type", "")` cannot tell "absent" from "declared empty".
## So every menu row answered `is_text_field == true`, and `MenuNav.confirm()`
## (`godot/src/input/menu_nav.gd`) took the keyboard branch on an ordinary row instead
## of activating it — with a pad connected that is a confirm that never confirms.
##
## The rule this audit pins down: the reference's table survives for a target that
## *declares* a type (an explicit `""` included, that is the `<input>` with no type),
## and a target that declares nothing is not a text field. A dictionary has no
## default type, so there is nothing to inherit.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const FocusNav := preload("res://src/input/focus_nav.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")


func _initialize() -> void:
	var audit := AuditBase.new("textfield_declared")
	_rule(audit)
	_confirm(audit)
	quit(audit.finish())


## `{id, rect, kind, action, drawn}` — the shape `menu_focus.gd::_target()` emits.
static func _row(id: String, action: String, extra: Dictionary = {}) -> Dictionary:
	var target := {"id": id, "rect": Rect2(64.0, 480.0, 139.0, 52.0), "kind": "button",
		"action": action, "drawn": true}
	for key in extra:
		target[key] = extra[key]
	return target


static func _menu() -> MenuNav:
	var menu := MenuNav.new()
	menu.set_pad_connected(true)
	return menu


# ---------------------------------------------------------------------------
# The rule (`FocusNav.is_text_field`)
# ---------------------------------------------------------------------------
static func _rule(audit: AuditBase) -> void:
	# The defect: a row that declares no type used to be read as a text field.
	audit.check_eq(FocusNav.is_text_field(_row("menu/PlayButton", "to-modes")), false,
		"textfield/a_row_without_a_declared_type_is_not_a_text_field")

	# An explicit `kind` still decides, as before.
	audit.check_eq(FocusNav.is_text_field(_row("fb", "text-field", {"kind": "text_field"})), true,
		"textfield/a_declared_text_field_kind_is_a_text_field")

	# The reference's table, for targets that DO declare `input_type` (`js/main.js`,
	# `isTextField`): every type in the set is text, an explicit empty string included.
	for declared in ["text", "search", "email", "url", "tel", "password", ""]:
		audit.check_eq(FocusNav.is_text_field(_row("fb", "text-field", {"input_type": declared})), true,
			"textfield/declared_input_type_%s_is_a_text_field" % ("empty" if declared == "" else declared))

	# …and a declared type outside the set is not (`<input type="checkbox">`).
	audit.check_eq(FocusNav.is_text_field(_row("cb", "toggle", {"input_type": "checkbox"})), false,
		"textfield/declared_input_type_checkbox_is_not_a_text_field")

	# Absent and declared-empty are now different answers; that difference is the fix.
	audit.check_ne(
		FocusNav.is_text_field({"id": "a", "rect": Rect2(0, 0, 10, 10), "kind": "button", "drawn": true}),
		FocusNav.is_text_field({"id": "b", "rect": Rect2(0, 0, 10, 10), "kind": "button", "input_type": "", "drawn": true}),
		"textfield/absent_input_type_is_not_the_same_as_a_declared_empty_one")

	audit.check_eq(FocusNav.is_text_field({}), false, "textfield/an_empty_target_is_not_a_text_field")


# ---------------------------------------------------------------------------
# The consequence (`MenuNav.confirm`)
# ---------------------------------------------------------------------------
static func _confirm(audit: AuditBase) -> void:
	# Gate 1: with a pad connected, confirming a menu row activates it and names its
	# action — the call the keyboard branch used to swallow.
	var menu := _menu()
	menu.set_screen_targets([_row("menu/PlayButton", "to-modes")])
	var verdict := menu.confirm()
	audit.check_eq(String(verdict.get("kind", "")), "activate",
		"textfield/a_menu_row_confirms_as_an_activation")
	audit.check_eq(String(verdict.get("action", "")), "to-modes",
		"textfield/the_activation_carries_the_rows_own_action")
	audit.check_eq(String(verdict.get("target", "")), "menu/PlayButton",
		"textfield/the_activation_names_the_focused_row")
	audit.check_eq(menu.osk.is_open(), false, "textfield/a_menu_row_raises_no_keyboard")

	# The screen is not the unit: only the row that declares a type takes the
	# keyboard branch (a screen with one real field and one button).
	var mixed := _menu()
	mixed.set_screen_targets([
		_row("fbMessage", "text-field", {"kind": "text_field", "field_label": "Messaggio"}),
		_row("fbSend", "send"),
	])
	audit.check_eq(String(mixed.confirm().get("kind", "")), "osk_open",
		"textfield/a_declared_field_still_opens_the_keyboard_with_a_pad")
	audit.check_eq(String(mixed.osk.target_id()), "fbMessage",
		"textfield/the_keyboard_opens_for_the_declared_field")
	audit.check_eq(mixed.osk.is_open(), true, "textfield/the_keyboard_model_is_open")
	mixed.back()
	audit.check_eq(mixed.osk.is_open(), false, "textfield/back_closes_the_keyboard_again")

	# Without a pad the player types directly: a declared field activates normally.
	var solo := MenuNav.new()
	solo.set_pad_connected(false)
	solo.set_screen_targets([_row("fbMessage", "text-field", {"kind": "text_field"})])
	audit.check_eq(String(solo.confirm().get("kind", "")), "activate",
		"textfield/a_declared_field_activates_without_a_pad")
	audit.check_eq(solo.osk.is_open(), false, "textfield/no_keyboard_without_a_pad")

	# A target that declares a type by `input_type` alone behaves like a declared
	# field (the reference's `<input type="text">`), so the table is not dead code.
	var typed := _menu()
	typed.set_screen_targets([_row("code", "text-field", {"input_type": "text"})])
	audit.check_eq(String(typed.confirm().get("kind", "")), "osk_open",
		"textfield/a_declared_input_type_still_reaches_the_keyboard")
