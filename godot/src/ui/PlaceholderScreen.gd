## PlaceholderScreen.gd — the screen a router slot shows before its own ticket lands.
##
## WHAT IT IS FOR. UIR-03 has to land the router before any screen is designed, and a
## router that can mount nothing cannot be audited. This screen gives every one of the
## thirteen ids a real node: the id it was mounted under, its name, and the declared
## back target the router told it. UIR-07 through UIR-21 replace the registered scene
## for their own id; nothing else about the router changes.
##
## THE ONE LITERAL. The label below is the only user-facing string in `godot/src/ui/**`
## outside the locale seam. `godot/tests/ui/router_audit.gd` scans for prose and
## whitelists exactly this literal, by path, with its reason — a scan that skipped
## whole files instead would be a scan nobody can trust. The screen asks the locale
## seam first (`UiStrings.has`), so the day a key exists the literal stops being used.
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")

## The locale id this label would like to be; it does not resolve yet.
const NOT_BUILT_KEY := "ui_placeholder_not_built"

## The fallback the label shows while no key resolves it — whitelisted in the audit.
const NOT_BUILT_LABEL := "not built yet"

## The router id this screen was mounted under (set by `enter()`).
var router_id: String = ""

## The declared back target the router handed over (`""` for menu/game/result).
var back_target_id: String = ""

var shell: Control

var _label: Label


func _ready() -> void:
	_build()


func screen_id() -> String:
	return router_id


func back_target() -> String:
	return back_target_id


## The router's payload carries its own facts (`ScreenRouter.go_to`): the id it mounted
## and the declared back target. The screen shows what it was told instead of looking
## the values up a second time.
func enter(payload: Dictionary) -> void:
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", ""))
	_build()
	shell.setup(router_id)
	shell.set_title_text(router_id)
	shell.set_back_target(back_target_id)
	_label.text = label_text()


func exit() -> void:
	pass


## The label text: the locale seam first, the whitelisted fallback only while the key
## resolves to nothing.
func label_text() -> String:
	if UiStrings.has(NOT_BUILT_KEY):
		return UiStrings.t(NOT_BUILT_KEY)
	return NOT_BUILT_LABEL


func _build() -> void:
	if shell != null:
		return
	shell = ShellScene.instantiate()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shell)
	_label = Label.new()
	_label.name = "PlaceholderLabel"
	_label.text = label_text()
	shell.content().add_child(_label)
