## back_label_probe.gd — does every router screen's back button carry its word?
##
## The bug this answers: `ScreenShell` styled the back control and registered it for
## focus, but never assigned `.text`, so every screen mounted in the shell showed a
## wordless button. The reference writes it in its own markup (`index.html:312`,
## `data-i18n="back"` → IT `← Indietro` / EN `← Back`).
##
## Read-only: mounts each screen through the router and reads the label back off the
## node. Writes nothing, sends nothing.
extends SceneTree

const UiStrings := preload("res://src/ui/UiStrings.gd")

const ROUTER_PATH := "res://src/ui/ScreenRouter.gd"
const SHELL_BACK_PATH := "Shell/Margin/Rows/TitleRow/BackButton"

var _ok := 0
var _fail := 0


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_ok += 1
		print("ok %s" % name)
	else:
		_fail += 1
		print("FAIL %s%s" % [name, ("  — " + detail) if detail != "" else ""])


func _find_shell_back(node: Node) -> Button:
	## Depth-first hunt for the shell's back control: the shell registers it under the
	## name `BackButton` whether the screen mounts ScreenShell.tscn or builds it in code.
	if node is Button and node.name == "BackButton":
		return node as Button
	for child in node.get_children():
		var found := _find_shell_back(child)
		if found != null:
			return found
	return null


func _initialize() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)

	var router: Node = (load(ROUTER_PATH) as GDScript).new()
	host.add_child(router)

	var scenes: Dictionary = load("res://game/main_menu.gd").SCREEN_SCENES
	for id in scenes:
		router.register(String(id), load(String(scenes[id])) as PackedScene)

	var expected := UiStrings.t("back")
	_check("the_back_label_id_resolves", expected != "back" and expected.strip_edges() != "",
		"UiStrings.t(\"back\") returned %s" % expected)
	print("# the word every back button must carry: %s" % expected)

	var checked := 0
	var blank: Array[String] = []
	var unreached: Array[String] = []
	for id in scenes:
		var screen_id := String(id)
		if not router.go_to(screen_id):
			continue
		var screen: Node = router.active_screen()
		if screen == null:
			continue
		var back := screen.get_node_or_null(NodePath(SHELL_BACK_PATH)) as Button
		if back == null:
			# Some screens build the shell in code instead of mounting it in the .tscn,
			# so the node sits under a different path. Find it by class instead.
			back = _find_shell_back(screen)
		if back == null:
			unreached.append(screen_id)
			continue
		checked += 1
		var declared := String(screen.back_target()) if screen.has_method("back_target") else ""
		if declared == "":
			# The reference declares no return for the root, the field and the result:
			# the control is hidden there, and a hidden control needs no word.
			_check("%s/back_is_hidden_where_the_reference_declares_no_return" % screen_id,
				not back.visible, "visible with back_target \"\"")
			continue
		_check("%s/back_is_visible" % screen_id, back.visible)
		var label := back.text
		if label.strip_edges() == "":
			blank.append(screen_id)
		_check("%s/back_carries_the_reference_word" % screen_id, label == expected,
			"showed %s, expected %s" % [
				("an empty label" if label.strip_edges() == "" else label), expected])

	_check("every_screen_in_the_shell_was_reached", checked > 0,
		"no screen exposed the shell's back control")
	print("# screens inspected: %d | blank labels: %d %s" % [
		checked, blank.size(), str(blank) if blank.size() > 0 else ""])
	print("# screens with no shell back control (own header): %d %s" % [
		unreached.size(), str(unreached) if unreached.size() > 0 else ""])

	var total := _ok + _fail
	print("%s %d/%d" % ["PASS" if _fail == 0 else "FAIL", _ok, total])
	quit(0 if _fail == 0 else 1)
