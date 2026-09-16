## remap.gd — the remap model: what a player may rebind, what the model refuses,
## and why. Plain data and validation, no input dialog and no scene.
##
## The reference has no rebinding UI — it has a *scheme*: `js/main.js:1006-1093`
## and `:789-930` wire the keyboard and the pad, `GAMEPLAY_RULES.md:152-180` states
## the map, and `scripts/gamepad-nav-audit.mjs` guards the part that must not
## drift (confirm on A/Cross, back on B/Circle). So this model is not a feature
## the reference lacks: it is the reference's scheme made assignable, and every
## rule it enforces is one the reference audits already enforce:
##
##   - **The device has to match the slot.** `js/main.js` reads movement and the
##     charge actions from `keys` (a `Set` of key names) and the pad from
##     `navigator.getGamepads()`. A pad button cannot be a keyboard binding: the
##     two are read by different code, and pretending otherwise would silently
##     drop the binding. → `wrong_device`.
##   - **Contexts are disjoint, so bindings may repeat across them.** The browser
##     dispatches to `pollGamepadGameplay` or `pollGamepadMenu` and never both
##     (`js/main.js:756-758`); B is the special inside a match and the back button
##     in the menus, and the port's own map does the same (measured: `padel_special`
##     = button 1, `ui_cancel` = button 1). Conflicts are therefore checked within
##     one context. → `conflict`, naming the action that already owns the binding.
##   - **The engine's navigation actions are not remappable.** `ui_accept`,
##     `ui_cancel` and `ui_up/down/left/right` are Godot built-ins;
##     `godot/project.godot` re-declares them as supersets of the defaults rather
##     than owning them, and a game that rebinds "back" breaks the pad contract the
##     reference audit asserts. → `reserved`.
##   - **Coverage is a floor, not a target.** The reference wires eight actions on
##     the pad only (`scheme.gd`, `devices`), so a remap may not take away a device
##     the reference uses — but it is never required to invent one. → `coverage`.
##
## API for the UI lane:
##
## Every binding the `InputMap` declares for a slot is kept, not just the first:
## `padel_switch` really carries both Tab and Z, and the arrows and the movement
## keys are two bindings of the same action. A conflict is therefore checked
## against *every* binding another action holds, and an assignment replaces the
## slot's whole set — which is what a settings row does.
##
##   var remap := RemapModel.new()                  # seeded from the live InputMap
##   remap.binding("padel_drive", "keyboard")       # {"kind": "key", "value": "Space"}
##   remap.binding_values("padel_switch", "keyboard")  # ["Tab", "Z"]
##   remap.assign("padel_drive", "keyboard", {"kind": "key", "value": "F"})
##   #   -> {"ok": true, "action": "padel_drive", "slot": "keyboard", "previous": {…}}
##   remap.assign("padel_drive", "pad", {"kind": "key", "value": "F"})
##   #   -> {"ok": false, "reason": "wrong_device", "expected": ["button", "axis"]}
##   remap.overrides()                              # what to persist: the diff only
##   remap.reset()                                  # back to the InputMap's bindings
extends RefCounted

const Scheme := preload("res://src/input/scheme.gd")

const SLOT_KEYBOARD := "keyboard"
const SLOT_PAD := "pad"
const SLOTS := [SLOT_KEYBOARD, SLOT_PAD]

const KIND_KEY := "key"
const KIND_BUTTON := "button"
const KIND_AXIS := "axis"
## The kinds each slot accepts. A pad axis is a binding like any other
## (`padel_sprint` is `RT`, an analog trigger, `js/main.js:793`).
const SLOT_KINDS := {
	SLOT_KEYBOARD: [KIND_KEY],
	SLOT_PAD: [KIND_BUTTON, KIND_AXIS],
}

const REASON_EMPTY := "empty_binding"
const REASON_UNKNOWN_ACTION := "unknown_action"
const REASON_UNKNOWN_SLOT := "unknown_slot"
const REASON_WRONG_DEVICE := "wrong_device"
const REASON_CONFLICT := "conflict"
const REASON_RESERVED := "reserved"
const REASON_COVERAGE := "coverage"
const REASON_NOTHING_TO_CLEAR := "nothing_to_clear"

var _bindings := {}
var _baseline := {}


## Seeded from the live `InputMap`, so the model never restates a binding the
## project already declares (`godot/project.godot` owns them; this file owns the
## rules). The first key, the first pad button and the first pad axis of each
## action are the ones it carries.
func _init() -> void:
	var snapshot := Scheme.snapshot()
	for row in snapshot:
		var action := String(row["id"])
		var slots := {SLOT_KEYBOARD: [], SLOT_PAD: []}
		for key in row["keys"]:
			slots[SLOT_KEYBOARD].append({"kind": KIND_KEY, "value": String(key)})
		for button in row["buttons"]:
			slots[SLOT_PAD].append({"kind": KIND_BUTTON, "value": String(button)})
		if (slots[SLOT_PAD] as Array).is_empty():
			for axis in row["axes"]:
				slots[SLOT_PAD].append({"kind": KIND_AXIS, "value": String(axis)})
		_bindings[action] = slots
	_baseline = _bindings.duplicate(true)


func actions() -> Array:
	var out: Array = _bindings.keys()
	out.sort()
	return out


## Every binding of one slot, in `InputMap` order.
func bindings(action: String, slot: String) -> Array:
	return _bindings.get(action, {}).get(slot, [])


## The slot's first binding: `{}` when the slot is empty.
func binding(action: String, slot: String) -> Dictionary:
	var found := bindings(action, slot)
	return {} if found.is_empty() else found[0]


## The slot's values, as text — what a settings row would show.
func binding_values(action: String, slot: String) -> Array:
	var out: Array = []
	for entry in bindings(action, slot):
		out.append(String(entry["value"]))
	return out


func binding_text(action: String, slot: String) -> String:
	return ", ".join(PackedStringArray(binding_values(action, slot)))


## Assigning a binding, with the reference's rules. Returns
## `{"ok": true, …previous…}` or `{"ok": false, "reason": …, …explanation…}`.
func assign(action: String, slot: String, new_binding: Dictionary) -> Dictionary:
	if not Scheme.ids().has(action):
		return {"ok": false, "reason": REASON_UNKNOWN_ACTION, "action": action, "known": Scheme.ids()}
	if not SLOTS.has(slot):
		return {"ok": false, "reason": REASON_UNKNOWN_SLOT, "slot": slot, "slots": SLOTS}
	var value := String(new_binding.get("value", ""))
	var kind := String(new_binding.get("kind", ""))
	if value == "" or kind == "":
		return {"ok": false, "reason": REASON_EMPTY, "action": action, "slot": slot}
	if not (SLOT_KINDS[slot] as Array).has(kind):
		return {"ok": false, "reason": REASON_WRONG_DEVICE, "slot": slot, "kind": kind, "expected": SLOT_KINDS[slot]}
	var row := Scheme.row(action)
	if not bool(row.get("remappable", true)):
		return {"ok": false, "reason": REASON_RESERVED, "action": action, "reference": String(row.get("reference", ""))}
	var owners := conflicts(action, slot, new_binding)
	if not owners.is_empty():
		return {"ok": false, "reason": REASON_CONFLICT, "action": action, "slot": slot, "value": value, "owner": owners[0], "owners": owners}
	var previous: Dictionary = binding(action, slot).duplicate()
	var previous_all := binding_values(action, slot)
	_bindings[action][slot] = [{"kind": kind, "value": value}]
	return {
		"ok": true, "action": action, "slot": slot, "value": value,
		"previous": previous, "previous_all": previous_all,
	}


## Which actions already carry that binding, in the same context. Empty means the
## assignment is free.
func conflicts(action: String, slot: String, candidate: Dictionary) -> Array:
	var context := String(Scheme.row(action).get("context", ""))
	var value := String(candidate.get("value", ""))
	var kind := String(candidate.get("kind", ""))
	var out: Array = []
	for other in actions():
		if other == action:
			continue
		if String(Scheme.row(other).get("context", "")) != context:
			continue
		for found in bindings(other, slot):
			if String(found.get("value", "")) == value and String(found.get("kind", "")) == kind:
				out.append(other)
				break
	out.sort()
	return out


## Whether the slot could be emptied. The reference's device coverage is the floor:
## a slot the reference wires cannot be cleared, or the port would end up less
## covered than the browser.
func can_clear(action: String, slot: String) -> bool:
	if not Scheme.ids().has(action):
		return false
	if bindings(action, slot).is_empty():
		return false
	return not Scheme.devices(action).has(slot)


func clear(action: String, slot: String) -> Dictionary:
	if not Scheme.ids().has(action):
		return {"ok": false, "reason": REASON_UNKNOWN_ACTION, "action": action}
	if bindings(action, slot).is_empty():
		return {"ok": false, "reason": REASON_NOTHING_TO_CLEAR, "action": action, "slot": slot}
	if not can_clear(action, slot):
		return {
			"ok": false, "reason": REASON_COVERAGE, "action": action, "slot": slot,
			"reference": String(Scheme.row(action).get("reference", "")),
			"devices": Scheme.devices(action),
		}
	_bindings[action][slot] = []
	return {"ok": true, "action": action, "slot": slot}


## Actions with no binding in a slot their own reference coverage requires — after
## any remap this must be empty, and the audit asserts it.
func uncovered() -> Array:
	var out: Array = []
	for action in actions():
		for device in Scheme.devices(action):
			if bindings(action, device).is_empty():
				out.append({"action": action, "slot": device})
	return out


## What to persist: the slots that differ from the `InputMap`'s own bindings.
func overrides() -> Dictionary:
	var out := {}
	for action in actions():
		for slot in SLOTS:
			var now := bindings(action, slot)
			var was: Array = _baseline.get(action, {}).get(slot, [])
			if now != was:
				out["%s.%s" % [action, slot]] = now
	return out


func reset() -> void:
	_bindings = _baseline.duplicate(true)


## The map as an enumerable table for the evidence file:
## `[{action, context, devices, keyboard, pad, label_id}]`.
func table() -> Array:
	var out: Array = []
	for action in actions():
		var row := Scheme.row(action)
		out.append({
			"action": action,
			"context": String(row.get("context", "")),
			"devices": row.get("devices", []),
			"keyboard": binding_text(action, SLOT_KEYBOARD),
			"pad": binding_text(action, SLOT_PAD),
			"remappable": bool(row.get("remappable", true)),
			"label_id": String(row.get("label_id", "")),
			"reference": String(row.get("reference", "")),
		})
	return out
