## scheme.gd — the reference's control scheme as data: one row per action, with
## what the reference actually wires on each device, the label that names it and
## the source line it comes from.
##
## Two things this file deliberately does NOT do:
##
##   1. It does not declare *which key or button* an action is bound to. The
##      bindings live in `godot/project.godot`, which another lane owns; declaring
##      them twice would create the drift the reference audits exist to catch, so
##      `snapshot()` reads the live `InputMap` instead and the ported audit
##      compares the two. The reference does the same thing in the other
##      direction: `scripts/gamepad-nav-audit.mjs` reads `js/main.js` to learn the
##      bindings rather than restating them.
##   2. It does not invent coverage the reference does not have. `devices` is the
##      set the *browser* wires (`js/main.js:1006-1053` for the keyboard,
##      `:789-899` for the pad, `GAMEPLAY_RULES.md:152-180` for the map), and the
##      audit asserts the port is at least as covered — never more symmetric than
##      the reference, because eight of these actions are pad-only in the browser
##      and inventing keyboard keys for them would be a new feature, not a port.
##      Where the two disagree, the disagreement is printed with its anchor.
##
## Fields of a row:
##   id        the InputMap action name (`godot/project.godot`)
##   context   "gameplay" | "menu"
##   devices   ["keyboard"] | ["pad"] | ["keyboard", "pad"] — the reference's own
##   label_id  the controller-legend label (`index.html:243-257`); "" when the
##             action has no legend row (`port_only` says why)
##   desc_id   the legend's description, or ""
##   remappable  false for the engine's `ui_*` actions: they are Godot built-ins
##             and the port declares them as supersets of the defaults rather than
##             owning them (`godot/project.godot`, `[input]` header)
##   port_only true when the action is the port's own and the browser has no
##             equivalent — named, not hidden
##   reference the anchor that says so
extends RefCounted

const CONTEXT_GAMEPLAY := "gameplay"
const CONTEXT_MENU := "menu"

## `godot/project.godot` declares exactly these gameplay actions; the audit checks
## the live map against this list in both directions.
const ACTIONS := [
	{
		"id": "padel_left", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "moveLbl", "desc_id": "padMoveDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:1007-1010 (WASD/arrows) · :789-800 (left stick)",
	},
	{
		"id": "padel_right", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "moveLbl", "desc_id": "padMoveDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:1007-1010 · :789-800",
	},
	{
		"id": "padel_up", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "moveLbl", "desc_id": "padMoveDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:1009-1010 · :789-800",
	},
	{
		"id": "padel_down", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "moveLbl", "desc_id": "padMoveDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:1009-1010 · :789-800",
	},
	{
		"id": "padel_drive", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "driveLbl", "desc_id": "padDriveDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:1013 (space/meta charge) · :795 (pad A) · GAMEPLAY_RULES.md:157",
	},
	{
		"id": "padel_slice", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "sliceLbl", "desc_id": "padSliceDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:1013,2573-2585 (meta) · :796 (pad X) · GAMEPLAY_RULES.md:157",
	},
	{
		"id": "padel_lob", "context": CONTEXT_GAMEPLAY, "devices": ["pad"],
		"label_id": "lobLbl", "desc_id": "padLobDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:1079 (lob is pad Y only: no keyboard branch exists)",
	},
	{
		"id": "padel_special", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "specialLbl", "desc_id": "padSpecialDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:2571 (alt) · :797 (pad B) · GAMEPLAY_RULES.md:157",
	},
	{
		"id": "padel_switch", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "switchLbl", "desc_id": "padSwitchDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:2572 (tab/z) · :798 (pad LB) · GAMEPLAY_RULES.md:157",
	},
	{
		"id": "padel_split_step", "context": CONTEXT_GAMEPLAY, "devices": ["pad"],
		"label_id": "splitStepLbl", "desc_id": "padSplitStepDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:792 (LT is analog: no keyboard branch) · GAMEPLAY_RULES.md:169",
	},
	{
		"id": "padel_sprint", "context": CONTEXT_GAMEPLAY, "devices": ["pad"],
		"label_id": "sprintLbl", "desc_id": "padSprintDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:793 (RT is analog) · GAMEPLAY_RULES.md:169-171 (analog sprint) — the "
			+ "legend labels the same key \"Angolo\"/\"Angle\" (index.html:252), which is the "
			+ "reference's own disagreement and is reported, not resolved",
	},
	{
		"id": "padel_technical", "context": CONTEXT_GAMEPLAY, "devices": ["pad"],
		"label_id": "technicalLbl", "desc_id": "padTechnicalDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:794 (pad RB) · GAMEPLAY_RULES.md:172",
	},
	{
		"id": "padel_tactic_attack", "context": CONTEXT_GAMEPLAY, "devices": ["pad"],
		"label_id": "tacticsLbl", "desc_id": "padTacticsDesc", "remappable": true, "port_only": false,
		"reference": "GAMEPLAY_RULES.md:174-175 (D-pad sets the pair's tactic: up attacks the net)",
	},
	{
		"id": "padel_tactic_defend", "context": CONTEXT_GAMEPLAY, "devices": ["pad"],
		"label_id": "tacticsLbl", "desc_id": "padTacticsDesc", "remappable": true, "port_only": false,
		"reference": "GAMEPLAY_RULES.md:174-175 (down defends the glass)",
	},
	{
		"id": "padel_tactic_staggered", "context": CONTEXT_GAMEPLAY, "devices": ["pad"],
		"label_id": "tacticsLbl", "desc_id": "padTacticsDesc", "remappable": true, "port_only": false,
		"reference": "GAMEPLAY_RULES.md:174-175 (left staggers the pair)",
	},
	{
		"id": "padel_tactic_balanced", "context": CONTEXT_GAMEPLAY, "devices": ["pad"],
		"label_id": "tacticsLbl", "desc_id": "padTacticsDesc", "remappable": true, "port_only": false,
		"reference": "GAMEPLAY_RULES.md:174-175 (right restores the balance)",
	},
	{
		"id": "padel_pause", "context": CONTEXT_GAMEPLAY, "devices": ["keyboard", "pad"],
		"label_id": "pauseLbl", "desc_id": "padPauseDesc", "remappable": true, "port_only": false,
		"reference": "js/main.js:2511 (escape) · :799-800 (pad start)",
	},
	{
		"id": "menu_quit", "context": CONTEXT_MENU, "devices": ["keyboard"],
		"label_id": "", "desc_id": "", "remappable": true, "port_only": true,
		"reference": "godot/project.godot:161 — a window has a close, a browser tab does not",
	},
	{
		"id": "ui_up", "context": CONTEXT_MENU, "devices": ["keyboard", "pad"],
		"label_id": "", "desc_id": "", "remappable": false, "port_only": false,
		"reference": "js/main.js:944-952 (stick/D-pad up) · the engine's built-in ui_* action",
	},
	{
		"id": "ui_down", "context": CONTEXT_MENU, "devices": ["keyboard", "pad"],
		"label_id": "", "desc_id": "", "remappable": false, "port_only": false,
		"reference": "js/main.js:944-952",
	},
	{
		"id": "ui_left", "context": CONTEXT_MENU, "devices": ["keyboard", "pad"],
		"label_id": "", "desc_id": "", "remappable": false, "port_only": false,
		"reference": "js/main.js:944-952",
	},
	{
		"id": "ui_right", "context": CONTEXT_MENU, "devices": ["keyboard", "pad"],
		"label_id": "", "desc_id": "", "remappable": false, "port_only": false,
		"reference": "js/main.js:944-952",
	},
	{
		"id": "ui_accept", "context": CONTEXT_MENU, "devices": ["keyboard", "pad"],
		"label_id": "", "desc_id": "", "remappable": false, "port_only": false,
		"reference": "js/main.js:983-986 (pad button 0 confirms) · scripts/gamepad-nav-audit.mjs:92",
	},
	{
		"id": "ui_cancel", "context": CONTEXT_MENU, "devices": ["keyboard", "pad"],
		"label_id": "", "desc_id": "", "remappable": false, "port_only": false,
		"reference": "js/main.js:992 (buttons 1 and 2 both go back) · scripts/gamepad-nav-audit.mjs:88-91",
	},
]

## The pad buttons the reference binds the menu actions to, as the audit reads them
## out of `pollGamepadMenu` (`js/main.js:983-996`).
const CONFIRM_PAD_BUTTONS := [0]
## Back is B/Circle **and** X/Square: both are mapped (`js/main.js:992`), because
## "B/Cerchio e' il tasto che tutti provano per tornare indietro" and the square is
## kept "per chi ci si e' abituato". The port's `ui_cancel` carries only the first
## of the two — see the note the audit prints.
const BACK_PAD_BUTTONS := [1, 2]

const STICK_DEADZONE := 0.15
## The right stick is read as an axis, not as an action — `gamepadAxis(pad, 3)`
## (`js/main.js:956`) — so it has no InputMap action in either build.
const SCROLL_AXIS := 3


static func ids() -> Array:
	var out: Array = []
	for row in ACTIONS:
		out.append(String(row["id"]))
	return out


static func row(action_id: String) -> Dictionary:
	for row_in in ACTIONS:
		if String(row_in["id"]) == action_id:
			return row_in
	return {}


static func gameplay_ids() -> Array:
	return ids_for_context(CONTEXT_GAMEPLAY)


static func menu_ids() -> Array:
	return ids_for_context(CONTEXT_MENU)


static func ids_for_context(context: String) -> Array:
	var out: Array = []
	for row_in in ACTIONS:
		if String(row_in["context"]) == context:
			out.append(String(row_in["id"]))
	return out


## Actions the reference wires on a keyboard. The port must have them too; the
## complement is the pad-only set, which is the reference's, not a gap invented
## by the port.
static func keyboard_ids() -> Array:
	return ids_with_device("keyboard")


static func pad_ids() -> Array:
	return ids_with_device("pad")


static func ids_with_device(device: String) -> Array:
	var out: Array = []
	for row_in in ACTIONS:
		if row_in["devices"].has(device):
			out.append(String(row_in["id"]))
	return out


## The reference's device coverage for one action: `["keyboard", "pad"]`.
static func devices(action_id: String) -> Array:
	var found := row(action_id)
	return found.get("devices", [])


## The live `InputMap`, one row per action:
##   {"id":…, "keys":["W","Up"], "buttons":["0"], "axes":["1:-1.0"]}
## `InputEventKey` is reported by its physical keycode, so the layout a player
## actually has is what shows up, not the label printed on the key.
static func snapshot(action_ids: Array = []) -> Array:
	var wanted: Array = action_ids if not action_ids.is_empty() else ids()
	var out: Array = []
	for action_id in wanted:
		var keys: Array = []
		var buttons: Array = []
		var axes: Array = []
		if InputMap.has_action(String(action_id)):
			for event in InputMap.action_get_events(String(action_id)):
				if event is InputEventKey:
					var key := event as InputEventKey
					var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
					keys.append(OS.get_keycode_string(code))
				elif event is InputEventJoypadButton:
					buttons.append(str((event as InputEventJoypadButton).button_index))
				elif event is InputEventJoypadMotion:
					var motion := event as InputEventJoypadMotion
					axes.append("%d:%+.1f" % [motion.axis, motion.axis_value])
		out.append({"id": String(action_id), "keys": keys, "buttons": buttons, "axes": axes})
	return out


## The `padel_*` and `menu_*` actions the project itself declares, read from the
## live `InputMap`. The engine's own actions (`ui_*`, `ui_text_*`, …) are excluded
## by prefix: they are Godot's, not this project's declaration.
static func project_declared_actions() -> Array:
	var out: Array = []
	for action in InputMap.get_actions():
		var name := String(action)
		if name.begins_with("padel_") or name.begins_with("menu_"):
			out.append(name)
	out.sort()
	return out
