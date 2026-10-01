extends SceneTree
## stuck_key_charge_test.gd — a shot key whose release the game never saw must not
## keep charging (2026-09-30, owner: the charge started on its own while recording the
## screen; Cmd+Shift+5 swallowed the Command key-up, and Command is the keyboard slice).

const InputSource := preload("res://game/input_map.gd")
const Sim := preload("res://src/sim/sim.gd")

var passed := 0
var failed := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("ok " + name)
	else:
		failed += 1
		print("FAIL %s: %s" % [name, detail])


func _key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _initialize() -> void:
	var source = InputSource.new()
	var slice_code := 0
	for event in InputMap.action_get_events("padel_slice"):
		if event is InputEventKey:
			slice_code = event.physical_keycode
	check("the keyboard slice has a key", slice_code != 0)
	_key(slice_code, true)
	var held: Dictionary = source.sample(null)
	check("a held slice key charges", bool(held.get("charging", false)), str(held))
	# The system took the shortcut: no key-up ever arrives. A focus change clears it.
	InputSource.release_stuck_keys()
	Input.flush_buffered_events()
	source.forget_keys()
	var after: Dictionary = source.sample(null)
	check("after the focus change the key no longer charges", not bool(after.get("charging", false)), str(after))
	check("and no phantom release fires a shot", not bool(after.get("hit", false)), str(after))
	print("%s %d/%d" % ["PASS" if failed == 0 else "FAIL", passed, passed + failed])
	quit(0 if failed == 0 else 1)
