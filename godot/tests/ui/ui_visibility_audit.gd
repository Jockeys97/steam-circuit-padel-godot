## ui_visibility_audit.gd — the in-match UI visibility bundle's focused audit.
##
##   godot --headless --path godot/ --script res://tests/ui/ui_visibility_audit.gd
##
## Same machine-readable contract as the other audits: `ok <name>` / `FAIL <name>`
## and one `PASS n/n` line, exit 0 on PASS and 1 on FAIL. The bundle is
## `docs/agent-work/ui-visibility-settings/PLAN.md`; this file asserts its
## acceptance items against the real match scene, not against a stub.
##
## WHAT IT ASSERTS, and the seam each question crosses:
##
##   1. the four presets produce the EXACT component map the contract names, and the
##      applied HUD profile and the panels themselves agree with the map;
##   2. each of the six toggles changes only its own component, with the shipping
##      HUD's panels and the controller's world-space marks following immediately;
##   3. a disabled component is never re-shown by a refresh (`_sync_views` rewrites
##      the ring, the pin, the drill target and the timing marks every frame);
##   4. the clean gesture restores the EXACT prior profile — a custom map and a
##      preset alike — instead of forcing `all`;
##   5. the restore hint: mounted beside the HUD, shown only in clean live play,
##      localized, input-transparent, hidden by the pause card and hidden on restore;
##   6. the fourth pause tab: four tabs and all ten UI controls in the focus table,
##      the presets and toggles writing through the bound controller, `rows()` left
##      as the controller tab's own table, and the new ids resolvable in both locales;
##   7. a rematch is a reset: the profile, its restore memory and the hint all go
##      back to the full view.
##
## THIS AUDIT WRITES ONLY TO A TEMP PROFILE (`user://ui-visibility-audit`) and
## removes it again. The real `user://save` is never touched.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Config := preload("res://game/match_config.gd")
const ControllerClass := preload("res://game/match_controller.gd")
const HudClass := preload("res://src/ui/Hud.gd")
const OverlayClass := preload("res://src/ui/screens/PauseOverlay.gd")
const Locale := preload("res://src/locale/locale.gd")

const MATCH_SCENE := preload("res://game/Match.tscn")
const TEMP_DIR := "user://ui-visibility-audit"
const SETTLE_FRAMES := 3
const TICK := 1.0 / 120.0

## The contract's own four maps, written out here as literals: the audit must not
## read the table it checks.
const ALL := {"score": true, "time": true, "map": true, "guidance": true, "indicators": true, "events": true}
const ESSENTIAL := {"score": true, "time": true, "map": false, "guidance": false, "indicators": true, "events": true}
const SCORE_ONLY := {"score": true, "time": false, "map": false, "guidance": false, "indicators": false, "events": false}
const CLEAN := {"score": false, "time": false, "map": false, "guidance": false, "indicators": false, "events": false}
const PRESETS := {"all": ALL, "essential": ESSENTIAL, "score_only": SCORE_ONLY, "clean": CLEAN}
const COMPONENTS := ["score", "time", "map", "guidance", "indicators", "events"]
const BUNDLE_IDS := ["tabUi", "uiVisibility", "uiPresets", "uiPresetAll",
	"uiPresetEssential", "uiPresetScoreOnly", "uiPresetClean", "uiCompScore",
	"uiCompTime", "uiCompMap", "uiCompGuidance", "uiCompIndicators", "uiCompEvents",
	"uiHintRestore", "uiShortcutNote"]

var _saved_dir := ""


func _initialize() -> void:
	var audit := AuditBase.new("ui_visibility")
	_saved_dir = Config.save_dir
	Config.save_dir = TEMP_DIR
	await _mirrors(audit)
	await _presets(audit)
	await _toggles(audit)
	await _restore(audit)
	await _hint(audit)
	await _tab(audit)
	await _rematch(audit)
	Config.save_dir = _saved_dir
	_wipe()
	quit(audit.finish())


# ---------------------------------------------------------------------------
# 0. The three id lists cannot drift apart
# ---------------------------------------------------------------------------

## The controller owns the vocabulary; the HUD and the pause tab mirror it. A mirror
## that stops matching is the bug this pin exists for.
func _mirrors(audit: AuditBase) -> void:
	audit.check_eq(ControllerClass.UI_COMPONENTS, COMPONENTS, "ids/the_controller_names_the_six_components")
	audit.check_eq(HudClass.COMPONENT_IDS, COMPONENTS, "ids/the_hud_mirrors_the_six_components")
	audit.check_eq(OverlayClass.UI_COMPONENT_IDS, COMPONENTS, "ids/the_pause_tab_mirrors_the_six_components")
	audit.check_eq(ControllerClass.UI_PRESET_IDS, ["all", "essential", "score_only", "clean"],
		"ids/the_four_presets_are_declared")
	audit.check_eq(OverlayClass.UI_PRESET_IDS, ["all", "essential", "score_only", "clean"],
		"ids/the_pause_tab_lists_the_four_presets")


# ---------------------------------------------------------------------------
# 1. The four presets, exactly
# ---------------------------------------------------------------------------

func _presets(audit: AuditBase) -> void:
	var node := await _new_match()
	var hud: Node = node.get_node_or_null("HudLayer/UiHud")
	if hud == null:
		audit.check_true(false, "presets/the_shipping_hud_is_mounted")
		node.free()
		return
	for id in ["all", "essential", "score_only", "clean"]:
		audit.check_eq(bool(node.call("set_ui_preset", id)), true, "presets/%s_is_accepted" % id)
		var wanted: Dictionary = PRESETS[id]
		audit.check_eq(node.call("ui_visibility_snapshot"), wanted, "presets/%s_is_the_exact_map" % id)
		audit.check_eq(String(node.call("ui_preset_id")), id, "presets/%s_round_trips_through_ui_preset_id" % id)
		audit.check_eq(hud.call("component_visibility"), wanted, "presets/%s_reaches_the_hud_profile" % id)
		audit.check_eq(_panels_follow(hud, wanted), true, "presets/%s_hides_exactly_its_own_panels" % id)
		audit.check_eq(bool(node.call("is_hud_hidden")), id == "clean",
			"presets/%s_sets_the_clean_flag" % id)
	audit.check_eq(bool(node.call("set_ui_preset", "nope")), false, "presets/an_unknown_preset_is_refused")
	audit.check_eq(node.call("ui_visibility_snapshot"), CLEAN, "presets/a_refused_preset_changes_nothing")
	node.free()


# ---------------------------------------------------------------------------
# 2. The six toggles, one component at a time (and 3. the refresh)
# ---------------------------------------------------------------------------

func _toggles(audit: AuditBase) -> void:
	var node := await _new_match()
	var hud: Node = node.get_node_or_null("HudLayer/UiHud")
	node.call("set_ui_preset", "all")
	for id in COMPONENTS:
		var component := String(id)
		audit.check_eq(bool(node.call("set_ui_component", component, false)), true,
			"toggles/%s_off_is_accepted" % component)
		var want_off := ALL.duplicate()
		want_off[component] = false
		audit.check_eq(node.call("ui_visibility_snapshot"), want_off,
			"toggles/%s_off_changes_only_its_own_component" % component)
		audit.check_eq(String(node.call("ui_preset_id")), "",
			"toggles/%s_off_leaves_no_preset_selected" % component)
		audit.check_eq(bool(node.call("is_ui_component_visible", component)), false,
			"toggles/%s_off_is_readable_back" % component)
		audit.check_eq(_panels_follow(hud, want_off), true,
			"toggles/%s_off_hides_its_own_panels" % component)
		if component == "indicators":
			audit.check_eq(bool(node.get_node("ActiveRing").visible), false,
				"toggles/indicators_off_hides_the_active_ring_immediately")
			audit.check_eq(bool(node.get_node("TimingEnergyBar").visible), false,
				"toggles/indicators_off_hides_the_energy_bar_immediately")
		audit.check_eq(bool(node.call("set_ui_component", component, true)), true,
			"toggles/%s_on_is_accepted" % component)
		audit.check_eq(node.call("ui_visibility_snapshot"), ALL,
			"toggles/%s_on_returns_the_full_view" % component)
		audit.check_eq(String(node.call("ui_preset_id")), "all",
			"toggles/%s_on_is_the_all_preset_again" % component)
	audit.check_eq(bool(node.call("set_ui_component", "nope", false)), false,
		"toggles/an_unknown_component_is_refused")
	audit.check_eq(node.call("ui_visibility_snapshot"), ALL, "toggles/a_refused_component_changes_nothing")
	# 3. A disabled component survives the every-frame rewrite.
	node.call("set_ui_component", "events", false)
	node.call("set_ui_component", "indicators", false)
	for _i in SETTLE_FRAMES:
		node.call("apply_frame", {}, TICK)
	var after: Dictionary = node.call("ui_visibility_snapshot")
	audit.check_eq(bool(after.get("events", true)), false, "refresh/events_stay_off_across_frames")
	audit.check_eq(bool(after.get("indicators", true)), false, "refresh/indicators_stay_off_across_frames")
	audit.check_eq(_panels_follow(hud, after), true, "refresh/no_disabled_panel_is_re_shown")
	audit.check_eq(bool(node.get_node("ActiveRing").visible), false, "refresh/the_ring_stays_hidden")
	audit.check_eq(bool(node.get_node("TimingEnergyBar").visible), false, "refresh/the_marks_stay_hidden")
	audit.check_eq(hud.call("component_visibility"), after, "refresh/the_hud_profile_survives_the_rewrite")
	node.free()


# ---------------------------------------------------------------------------
# 4. The clean gesture restores the exact prior profile
# ---------------------------------------------------------------------------

func _restore(audit: AuditBase) -> void:
	var node := await _new_match()
	var hud: Node = node.get_node_or_null("HudLayer/UiHud")
	# A custom map: everything on but the mini-map and the guidance strip.
	node.call("set_ui_component", "map", false)
	node.call("set_ui_component", "guidance", false)
	var custom: Dictionary = node.call("ui_visibility_snapshot")
	audit.check_ne(custom, ALL, "restore/a_custom_profile_is_not_all")
	audit.check_eq(bool(node.call("toggle_hud_hidden")), true, "restore/the_toggle_enters_clean")
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "restore/clean_is_in_force")
	audit.check_eq(node.call("ui_visibility_snapshot"), CLEAN, "restore/clean_is_the_all_off_map")
	audit.check_eq(bool(node.call("toggle_hud_hidden")), false, "restore/the_toggle_leaves_clean")
	audit.check_eq(node.call("ui_visibility_snapshot"), custom, "restore/the_exact_custom_profile_returns")
	audit.check_eq(hud.call("component_visibility"), custom, "restore/the_hud_follows_the_restored_profile")
	# A preset is remembered as itself.
	node.call("set_ui_preset", "essential")
	node.call("set_hud_hidden", true)
	node.call("set_hud_hidden", false)
	audit.check_eq(node.call("ui_visibility_snapshot"), ESSENTIAL, "restore/a_preset_returns_as_that_preset")
	audit.check_eq(String(node.call("ui_preset_id")), "essential", "restore/the_restored_preset_is_identifiable")
	# The explicit seam keeps its old shape: `set_hud_hidden(true/false)`.
	node.call("set_hud_hidden", true)
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "restore/set_hud_hidden_true_still_hides")
	node.call("set_hud_hidden", false)
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "restore/set_hud_hidden_false_still_shows")
	node.free()


# ---------------------------------------------------------------------------
# 5. The restore hint
# ---------------------------------------------------------------------------

func _hint(audit: AuditBase) -> void:
	var node := await _new_match()
	var hint: Control = node.get_node_or_null("HudLayer/UiRestoreHint")
	var overlay: Node = node.get_node_or_null("HudLayer/PauseOverlay")
	audit.check_true(hint != null, "hint/the_hint_is_mounted_beside_the_hud")
	if hint == null or overlay == null:
		node.free()
		return
	var chip := hint.get_node_or_null("HintChip") as Control
	var label := hint.get_node_or_null("HintChip/HintLabel") as Label
	audit.check_true(chip != null and label != null, "hint/the_chip_and_its_label_are_mounted")
	audit.check_eq(bool(hint.visible), false, "hint/it_starts_hidden_in_live_play")
	node.call("set_hud_hidden", true)
	audit.check_eq(bool(hint.visible), true, "hint/clean_live_play_shows_it")
	audit.check_eq(label.text, Locale.t("uiHintRestore"), "hint/the_text_is_the_localized_string")
	audit.check_ne(label.text, "uiHintRestore", "hint/the_string_resolves_rather_than_leaking_its_id")
	audit.check_eq(hint.mouse_filter, Control.MOUSE_FILTER_IGNORE, "hint/the_root_ignores_the_mouse")
	audit.check_eq(chip.mouse_filter, Control.MOUSE_FILTER_IGNORE, "hint/the_chip_ignores_the_mouse")
	audit.check_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "hint/the_label_ignores_the_mouse")
	# The pause card hides it, and closing the card in clean mode brings it back.
	node.call("set_match_paused", true)
	audit.check_eq(bool(hint.visible), false, "hint/the_pause_card_hides_it")
	node.call("set_match_paused", false)
	audit.check_eq(bool(hint.visible), true, "hint/closing_the_card_in_clean_play_shows_it_again")
	for _i in SETTLE_FRAMES:
		node.call("apply_frame", {}, TICK)
	audit.check_eq(bool(hint.visible), true, "hint/it_survives_a_refresh_in_clean_play")
	node.call("set_hud_hidden", false)
	audit.check_eq(bool(hint.visible), false, "hint/the_restore_hides_it_immediately")
	# The other locale.
	var lang := Locale.current_lang()
	var other := ""
	for candidate in Locale.locales():
		if String(candidate) != lang:
			other = String(candidate)
	audit.check_ne(other, "", "hint/there_is_a_second_locale")
	Locale.set_lang(other)
	node.call("set_hud_hidden", true)
	audit.check_eq(label.text, Locale.t("uiHintRestore", {}, other), "hint/the_text_follows_the_active_locale")
	Locale.set_lang(lang)
	node.free()


# ---------------------------------------------------------------------------
# 6. The fourth pause tab
# ---------------------------------------------------------------------------

func _tab(audit: AuditBase) -> void:
	var node := await _new_match()
	var overlay: Node = node.get_node_or_null("HudLayer/PauseOverlay")
	audit.check_true(overlay != null, "tab/the_pause_card_is_mounted")
	if overlay == null:
		node.free()
		return
	node.call("set_match_paused", true)
	audit.check_eq(String(overlay.call("active_tab")), "match", "tab/the_card_opens_on_the_match_tab")
	audit.check_eq(bool(overlay.call("set_tab", "ui")), true, "tab/the_ui_tab_switches")
	var panel: Node = overlay.find_child("PanelUi", true, false)
	audit.check_true(panel != null and bool((panel as Control).visible), "tab/the_ui_panel_is_shown")
	audit.check_eq((overlay.call("ui_rows") as Dictionary).size(), 6, "tab/the_ui_rows_are_six")
	audit.check_eq((overlay.call("rows") as Dictionary).size(), 3, "tab/the_controller_rows_are_untouched")
	# The focus order: the four tabs first, then the four presets, then the six toggles.
	var ids: Array = []
	for entry in overlay.call("focus_controls"):
		ids.append(String((entry as Dictionary).get("id", "")))
	audit.check_eq(ids.size(), 14, "tab/four_tabs_and_ten_ui_controls_are_focusable")
	audit.check_eq(ids.slice(0, 4), ["pause/tab-match", "pause/tab-controller", "pause/tab-controls", "pause/tab-ui"],
		"tab/the_four_tabs_lead_the_focus_order")
	audit.check_eq(ids.slice(4, 8), ["pause/ui-preset:all", "pause/ui-preset:essential",
		"pause/ui-preset:score_only", "pause/ui-preset:clean"],
		"tab/the_four_presets_follow_the_tabs")
	audit.check_eq(ids.slice(8, 14), ["pause/ui-component:score", "pause/ui-component:time",
		"pause/ui-component:map", "pause/ui-component:guidance",
		"pause/ui-component:indicators", "pause/ui-component:events"],
		"tab/the_six_toggles_follow_the_presets")
	# The controls write through the bound CONTROLLER, not through a copy of their own.
	var buttons: Dictionary = overlay.call("ui_preset_buttons")
	(buttons["score_only"] as Button).pressed.emit()
	audit.check_eq(node.call("ui_visibility_snapshot"), SCORE_ONLY,
		"tab/a_preset_press_reaches_the_match_profile")
	audit.check_eq(String(overlay.call("ui_preset_id")), "score_only", "tab/the_tab_reads_the_selected_preset_back")
	var events_row := (overlay.call("ui_rows") as Dictionary)["events"] as Control
	(events_row.get_node("Check") as CheckBox).button_pressed = true
	audit.check_eq(bool(node.call("is_ui_component_visible", "events")), true,
		"tab/a_toggle_flip_reaches_the_match_profile")
	audit.check_eq(String(overlay.call("ui_preset_id")), "", "tab/a_custom_profile_selects_no_preset")
	audit.check_eq(bool(overlay.call("set_row_value", "events", 0.0)), true,
		"tab/the_model_stepped_door_writes_a_ui_row")
	audit.check_eq(bool(node.call("is_ui_component_visible", "events")), false,
		"tab/the_model_stepped_write_reaches_the_match")
	# Back hierarchy: leaving the UI tab returns to the match tab, like the others.
	node.call("set_match_paused", false)
	node.call("set_match_paused", true)
	audit.check_eq(bool(overlay.call("set_tab", "ui")), true, "tab/the_ui_tab_reopens")
	var back: Dictionary = overlay.call("back")
	audit.check_eq(String(back.get("kind", "")), "tab_back", "tab/back_leaves_the_ui_tab_before_resuming")
	audit.check_eq(String(overlay.call("active_tab")), "match", "tab/back_lands_on_the_match_tab")
	node.call("set_match_paused", false)
	_strings(audit, overlay)
	node.free()


## Every id this bundle adds resolves in BOTH locales — the reference's own rule for
## a visible string (`locale.gd`: an id that cannot resolve is shown as itself).
func _strings(audit: AuditBase, overlay: Node) -> void:
	var unresolved: Array = []
	for id in BUNDLE_IDS:
		for lang in Locale.locales():
			if not Locale.is_resolvable(String(id), String(lang)):
				unresolved.append("%s/%s" % [id, lang])
	audit.check_eq(unresolved, [], "strings/every_new_id_resolves_in_both_locales")
	var buttons := overlay.call("ui_preset_buttons") as Dictionary
	audit.check_eq(buttons.size(), 4, "strings/the_four_preset_buttons_exist")
	for entry in buttons.values():
		audit.check_ne((entry as Button).text, "", "strings/a_preset_button_carries_text")


# ---------------------------------------------------------------------------
# 7. A rematch is a reset
# ---------------------------------------------------------------------------

func _rematch(audit: AuditBase) -> void:
	var node := await _new_match()
	node.call("set_ui_component", "map", false)
	node.call("set_hud_hidden", true)
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "rematch/clean_is_on_before_the_rematch")
	node.call("rematch")
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "rematch/the_flag_clears")
	audit.check_eq(node.call("ui_visibility_snapshot"), ALL, "rematch/the_profile_is_all_again")
	audit.check_eq(String(node.call("ui_preset_id")), "all", "rematch/the_preset_is_all_again")
	var hint: Control = node.get_node_or_null("HudLayer/UiRestoreHint")
	audit.check_eq(bool(hint.visible) if hint != null else false, false, "rematch/the_hint_is_hidden")
	# And a clean → restore after the rematch returns `all`, not the pre-rematch map.
	node.call("set_hud_hidden", true)
	node.call("set_hud_hidden", false)
	audit.check_eq(node.call("ui_visibility_snapshot"), ALL, "rematch/restore_after_a_rematch_is_all")
	node.free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Every node of every component the profile turns OFF is hidden. The check is
## one-directional on purpose: `guidance`'s panels and the serve banner are also
## view-driven, so an ON component may legitimately show nothing — an OFF one may
## never show a panel.
func _panels_follow(hud: Node, profile: Dictionary) -> bool:
	for id in profile.keys():
		if bool(profile[id]):
			continue
		for node in hud.call("component_nodes", String(id)):
			if node != null and bool((node as Control).visible):
				return false
	return true


func _new_match() -> Node:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 0
	var node: Node = MATCH_SCENE.instantiate()
	node.harness_mode()
	root.add_child(node)
	for _i in SETTLE_FRAMES:
		await process_frame
	node.start_match()
	return node


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists(TEMP_DIR.trim_prefix("user://")):
		dir.remove(TEMP_DIR.trim_prefix("user://"))
