## demo_matrix_audit.gd — UIR-23's contract audit: the limited-build content matrix
## across the recreated screens, one run per build.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/demo_matrix_audit.gd                  # the full column
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/demo_matrix_audit.gd -- --demo        # the demo column
##
## WHAT IT PROVES. The runnable cells of UIR-23's matrix, on the screens the router
## actually mounts, under the build this process actually is (`tests/build/BuildFlag.gd`):
## the athletes and arenas a build lists, locks and cannot select (`js/build.js:58-75`,
## `js/ui.js:734`), the modes and the pinned difficulty (`js/ui.js:737-770`), the badge
## and its build chip (`index.html:49-52`, `:78-80`; `js/ui.js:742-750`), the result CTA copy (`js/main.js:2392-2420`) and the two
## languages. The exposed / locked / selectable distinction is measured from the rows
## the screens render; the rule is not re-derived here.
##
## THE BETA COLUMN IS NOT RUNNABLE IN THE PORT TODAY. `tests/build/BuildFlag.gd:49-66`
## resolves one boolean over (feature tag, args); the reference's third build label
## (`js/build.js`, `BUILD === "beta"`) has no port equivalent. The beta cells are
## recorded as traceability, not a pass: `not_ported` for the column, and the two beta
## keys are still asked through their own door (`DemoGateAdapter.badge_text_key_for`;
## `ResultScreen.set_store_config(url, "follow")`). `betaResultBody` has no frozen
## locale entry, so the id renders — the reference's own visible fallback, the same gap
## `tests/ui/data_audit.gd:93` records.
##
## MOUNTED READ-ONLY. The screens are reached through the playable host
## (`res://game/Main.tscn` -> its router), the same mount `uir22_integration_audit.gd`
## uses; nothing here writes a screen, a gate module or a real profile. This audit
## writes only to a temp profile (`user://uir23-demo-matrix-audit`) and removes it again.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const Config := preload("res://game/match_config.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const BuildFlag := preload("res://tests/build/BuildFlag.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const Gate := preload("res://game/content_gate.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const MenuScreenClass := preload("res://src/ui/screens/MenuScreen.gd")

const HOST_SCENE := preload("res://game/Main.tscn")
const TEMP_DIR := "user://uir23-demo-matrix-audit"
const FRAME := Vector2(1280.0, 720.0)
const SETTLE_FRAMES := 3

## The reference's own limited-build table (`js/build.js:43-56`), pinned literally so a
## drift in the generated table is caught here even while the gate agrees with itself.
const REF_DEMO_ATHLETES: Array[String] = ["maestro", "steamer"]
const REF_DEMO_ARENAS: Array[String] = ["clockwork"]
const REF_DEMO_MODES: Array[String] = ["quick"]
const REF_DEMO_DIFFICULTY := "medium"
const REF_ALL_MODES: Array[String] = ["quick", "tournament", "career"]
const REF_ALL_DIFFICULTIES: Array[String] = ["easy", "medium", "hard", "legend"]
## The reference's eight menu actions (`js/main.js:2199-2246`; `ScreenRouter.SCREENS[0]`).
const REF_MENU_ACTIONS: Array[String] = [
	"to-challenges", "to-drill", "to-feedback", "to-help", "to-history", "to-modes",
	"to-profile", "to-settings",
]

var _saved := {}


func _initialize() -> void:
	var audit := AuditBase.new("demo_matrix")
	_saved = {
		"dir": Config.save_dir,
		"tier": Config.tier_index,
		"athlete": Config.athlete_index,
		"arena": Config.arena_index,
		"mode": Config.pending_mode,
		"lang": Locale.current_lang(),
	}
	Config.save_dir = TEMP_DIR
	Locale.set_lang("it")
	var demo := BuildFlag.is_demo()
	audit.report("build=%s (BuildFlag.resolve: feature tag first, args second)" % BuildFlag.label())
	await _gate_vs_reference(audit, demo)
	var pair: Array = await _mount_host()
	var host: Control = pair[1]
	var router: Control = host.call("ui_router")
	audit.check_true(router != null, "host/the_playable_ui_is_what_this_matrix_mounts")
	if router != null:
		await _menu_badge_and_nav(audit, router, demo)
		await _menu_language(audit, router)
		await _characters(audit, router, demo)
		await _arena(audit, router, demo)
		await _modes(audit, router, demo)
		await _result_cta(audit, router, demo)
	_beta_traceability(audit)
	(pair[0] as Node).queue_free()
	_restore()
	_wipe()
	quit(audit.finish())


func _restore() -> void:
	Config.save_dir = String(_saved.get("dir", ""))
	Config.tier_index = int(_saved.get("tier", 0))
	Config.athlete_index = int(_saved.get("athlete", 0))
	Config.arena_index = int(_saved.get("arena", 0))
	Config.pending_mode = String(_saved.get("mode", "quick"))
	Locale.set_lang(String(_saved.get("lang", "it")))


# ---------------------------------------------------------------------------
# 0. The gate vs the reference's table (both runs; the table is process-level)
# ---------------------------------------------------------------------------

func _gate_vs_reference(audit: AuditBase, demo: bool) -> void:
	audit.check_eq(Gate.is_demo(), demo, "build/the_gate_reports_the_flag_the_run_is")
	audit.check_eq(DemoGate.build(), "demo" if demo else "full", "build/the_adapter_answers_demo_or_full_only")
	audit.check_eq(str(DemoContent.allowed_athlete_ids()), str(REF_DEMO_ATHLETES), "gate/the_demo_table_still_names_maestro_and_steamer")
	audit.check_eq(str(DemoContent.allowed_arena_ids()), str(REF_DEMO_ARENAS), "gate/the_demo_table_still_names_clockwork")
	audit.check_eq(str(DemoContent.allowed_mode_ids()), str(REF_DEMO_MODES), "gate/the_demo_table_still_grants_quick_only")
	audit.check_eq(DemoContent.difficulty(), REF_DEMO_DIFFICULTY, "gate/the_demo_table_still_pins_medium")
	audit.check_eq(str(DemoContent.all_mode_ids()), str(REF_ALL_MODES), "gate/the_full_mode_set_is_the_references_three")
	audit.check_true(DemoContent.outfit_challenges_enabled(), "gate/outfit_challenges_stay_available_in_every_build")
	var challenge_total := 0
	for id in REF_DEMO_ATHLETES:
		challenge_total += int(DemoContent.outfit_challenges().get(id, 0))
	audit.check_eq(challenge_total, 8, "gate/the_two_demo_athletes_still_carry_eight_challenge_outfits")
	var expected_tier := int(Gate.DIFFICULTY_TIERS.get(REF_DEMO_DIFFICULTY, -99))
	audit.check_eq(Gate.fixed_tier_index(), expected_tier if demo else -1, "gate/the_fixed_tier_index_is_the_demos_own_or_none")
	if demo:
		audit.check_eq(str(Gate.modes()), str(REF_DEMO_MODES), "gate/a_demo_exposes_quick_only")
		audit.check_eq(str(_ids_of(Gate.roster())), str(REF_DEMO_ATHLETES), "gate/a_demo_exposes_both_granted_athletes")
		audit.check_eq(str(_ids_of(Gate.arenas())), str(REF_DEMO_ARENAS), "gate/a_demo_exposes_its_one_arena")
	else:
		audit.check_eq(Gate.modes().size(), 3, "gate/a_full_build_exposes_all_three_modes")
		audit.check_eq(Gate.roster().size(), Frozen.athletes().size(), "gate/a_full_build_exposes_the_whole_roster")
		audit.check_eq(Gate.arenas().size(), Frozen.arenas().size(), "gate/a_full_build_exposes_every_arena")


# ---------------------------------------------------------------------------
# 1. Menu: the badge (row 8) and the nav/actions (row 11)
# ---------------------------------------------------------------------------

func _mount_host() -> Array:
	var frame := Control.new()
	frame.name = "DemoMatrixFrame"
	frame.size = FRAME
	root.add_child(frame)
	var host: Control = HOST_SCENE.instantiate()
	frame.add_child(host)
	for _i in SETTLE_FRAMES:
		await process_frame
	return [frame, host]


func _go(router: Control, id: String) -> Node:
	router.call("go_to", id)
	for _i in SETTLE_FRAMES:
		await process_frame
	return router.call("active_screen")


func _menu_badge_and_nav(audit: AuditBase, router: Control, demo: bool) -> void:
	audit.check_eq(String(router.call("active_id")), "menu", "menu/a_boot_lands_on_the_menu")
	var screen: Node = router.call("active_screen")
	# The reference's two distinct nodes: the hero badge line (`index.html:49-52`), a
	# `data-i18n="heroBadge"` label that is never hidden, and the tag row's build chip
	# (`index.html:78-80`), which only a limited build turns on and writes.
	var hero_row: Control = screen.find_child("Badge", true, false)
	var hero_label: Label = screen.find_child("BadgeLabel", true, false)
	var chip: Label = screen.find_child("BuildBadge", true, false)
	audit.check_true(hero_row != null and hero_label != null, "menu/the_badge_row_mounts")
	audit.check_true(chip != null, "menu/the_build_chip_mounts")
	audit.check_true(hero_row.visible, "menu/the_hero_badge_row_is_always_visible")
	audit.check_eq(hero_label.text, UiStrings.t("heroBadge"), "menu/the_hero_badge_line_shows_heroBadge")
	audit.check_ne(hero_label.text, "heroBadge", "menu/the_hero_badge_text_is_the_locale_copy")
	audit.check_eq(bool(screen.call("badge_visible_shown")), demo, "menu/the_badge_follows_the_build_gate")
	audit.check_eq(chip.visible, demo, "menu/the_build_chip_follows_the_build_gate")
	audit.check_eq(String(screen.call("badge_key_shown")), DemoGate.badge_text_key(), "menu/the_badge_key_is_the_adapters_answer")
	if demo:
		audit.check_eq(String(screen.call("badge_key_shown")), DemoGate.BADGE_DEMO_KEY, "menu/a_demo_shows_the_demo_key")
		audit.check_true(chip.visible, "menu/a_demo_shows_the_build_chip")
		audit.check_eq(chip.text, UiStrings.t("demoBadge"), "menu/the_badge_text_is_the_demos_own")
		audit.check_eq(chip.text, "DEMO", "menu/and_it_reads_DEMO")
	else:
		audit.check_true(not chip.visible, "menu/a_full_build_hides_the_build_chip")
		audit.check_eq(chip.text, "", "menu/a_full_build_shows_no_badge_text")
	audit.check_eq(hero_label.text, UiStrings.t("heroBadge"), "menu/and_the_hero_badge_line_is_still_its_own")
	# Row 11: the same eight actions and the top-nav buttons in both builds.
	var actions: Array = Router.to_actions_of("menu")
	actions.sort()
	var expected: Array = REF_MENU_ACTIONS.duplicate()
	expected.sort()
	audit.check_eq(str(actions), str(expected), "menu/the_router_row_carries_the_references_eight_actions")
	var mapped: Array = MenuScreenClass.ACTION_TARGETS.keys()
	mapped.sort()
	audit.check_eq(str(mapped), str(expected), "menu/the_screens_own_action_map_is_the_same_eight")
	for action in expected:
		var slot := String(MenuScreenClass.ACTION_SLOTS.get(action, ""))
		var button: Control = screen.find_child(slot, true, false) if slot != "" else null
		audit.check_true(button != null, "menu/%s_carries_%s" % [slot if slot != "" else action, action])
		audit.check_true(button != null and button.visible, "menu/%s_is_visible_in_this_build" % (slot if slot != "" else action))
	var toggle: Control = screen.find_child(String(MenuScreenClass.LANG_NODE), true, false)
	audit.check_true(toggle != null and toggle.visible, "menu/the_language_toggle_is_part_of_the_top_nav")


# ---------------------------------------------------------------------------
# 2. Language handling (row 12): it/en resolve both builds' copy, the toggle flips
# ---------------------------------------------------------------------------

func _menu_language(audit: AuditBase, router: Control) -> void:
	audit.check_eq(str(MenuScreenClass.LANGS), str(["it", "en"]), "lang/the_toggle_is_the_references_two_languages")
	for lang in ["it", "en"]:
		Locale.set_lang(String(lang))
		audit.check_eq(UiStrings.t("demoBadge"), "DEMO", "lang/the_badge_copy_resolves_in_%s" % String(lang))
		audit.check_true(UiStrings.has("demoOnlyFull"), "lang/the_arena_lock_copy_resolves_in_%s" % String(lang))
		audit.check_true(UiStrings.has("demoLockedMode"), "lang/the_mode_lock_copy_resolves_in_%s" % String(lang))
		audit.check_true(UiStrings.has("demoResultBody"), "lang/the_demo_cta_body_resolves_in_%s" % String(lang))
		audit.check_eq(UiStrings.has("storeFollow"), false, "lang/the_follow_label_is_the_recorded_locale_gap_in_%s" % String(lang))
		audit.check_eq(UiStrings.t("storeFollow"), "storeFollow", "lang/and_a_missing_id_renders_as_itself_in_%s" % String(lang))
	var screen: Node = router.call("active_screen")
	Locale.set_lang("it")
	screen.call("refresh_strings")
	var it_text := String((screen.find_child("PlayButton", true, false) as Button).text)
	audit.check_eq(Locale.current_lang(), "it", "lang/the_run_talks_italian_first")
	audit.check_eq(it_text, UiStrings.t("playNow"), "lang/the_play_button_carries_the_italian_sentence")
	screen.call("toggle_language")
	audit.check_eq(Locale.current_lang(), "en", "lang/the_toggle_flips_to_english")
	var en_text := String((screen.find_child("PlayButton", true, false) as Button).text)
	audit.check_eq(en_text, UiStrings.t("playNow"), "lang/the_play_button_carries_the_english_sentence")
	audit.check_ne(en_text, it_text, "lang/and_the_two_tables_differ_on_it")
	screen.call("toggle_language")
	audit.check_eq(Locale.current_lang(), "it", "lang/and_back_to_italian")


# ---------------------------------------------------------------------------
# 3. Characters (rows 1-2): exposed, and visible+locked+not selectable
# ---------------------------------------------------------------------------

func _characters(audit: AuditBase, router: Control, demo: bool) -> void:
	var screen: Node = await _go(router, "characters")
	audit.check_eq(String(screen.call("screen_id")), "characters", "char/the_characters_screen_is_the_one_mounted")
	var rows: Array = screen.call("athlete_rows_now")
	var all_ids := _ids_of(Frozen.athletes())
	var shown_ids: Array = []
	for row_in in rows:
		shown_ids.append(String((row_in as Dictionary).get("id", "")))
	audit.check_eq(str(shown_ids), str(all_ids), "char/the_whole_roster_is_listed_in_this_build")
	for row_in in rows:
		var row: Dictionary = row_in
		var id := String(row.get("id", ""))
		var withheld := demo and not REF_DEMO_ATHLETES.has(id)
		audit.check_eq(bool(row.get("demo_locked", false)), withheld, "char/row_%s_demo_lock_is_the_builds_own" % id)
		audit.check_eq(bool(row.get("selectable", false)), not withheld, "char/row_%s_selectable_follows_the_build" % id)
		if withheld:
			audit.check_true(bool(row.get("locked", false)), "char/row_%s_is_locked_visibly" % id)
			audit.check_true(bool(screen.call("athlete_locked_shown", id)), "char/row_%s_renders_locked" % id)
			audit.check_eq(bool(screen.call("select_athlete", id)), false, "char/row_%s_cannot_be_selected" % id)
			audit.check_eq(bool(screen.call("unlock_tap", id)), false, "char/row_%s_is_not_openable_by_any_code" % id)


# ---------------------------------------------------------------------------
# 4. Arena (rows 3-4): exposed and locked cards with the full-game sentence
# ---------------------------------------------------------------------------

func _arena(audit: AuditBase, router: Control, demo: bool) -> void:
	var screen: Node = await _go(router, "arena")
	audit.check_eq(String(screen.call("screen_id")), "arena", "arena/the_arena_screen_is_the_one_mounted")
	var rows: Array = screen.call("arena_rows_now")
	var all_ids := _ids_of(Frozen.arenas())
	var shown_ids: Array = []
	for row_in in rows:
		shown_ids.append(String((row_in as Dictionary).get("id", "")))
	audit.check_eq(str(shown_ids), str(all_ids), "arena/the_whole_arena_set_is_listed_in_this_build")
	var withheld: Array = []
	for row_in in rows:
		var row: Dictionary = row_in
		var id := String(row.get("id", ""))
		var locked_here := demo and not REF_DEMO_ARENAS.has(id)
		audit.check_eq(bool(row.get("demo_locked", false)), locked_here, "arena/row_%s_demo_lock_is_the_builds_own" % id)
		if locked_here:
			withheld.append(id)
			audit.check_eq(String(screen.call("arena_card_state", id)), "locked", "arena/row_%s_card_carries_the_lock" % id)
			audit.check_true(bool(screen.call("arena_locked_shown", id)), "arena/row_%s_lock_is_visible" % id)
			audit.check_eq(String(screen.call("arena_line_key", id)), "demoOnlyFull", "arena/row_%s_says_in_the_full_game" % id)
			audit.check_eq(bool(screen.call("select_arena", id)), false, "arena/row_%s_cannot_be_chosen" % id)
		else:
			audit.check_ne(String(screen.call("arena_line_key", id)), "demoOnlyFull", "arena/row_%s_never_claims_the_full_game" % id)
	var career_wall := _career_locked_arenas()
	if demo:
		audit.check_eq(str(screen.call("locked_ids")), str(withheld), "arena/a_demos_lock_list_is_exactly_what_it_withholds")
		audit.check_eq(String(screen.call("selected_arena_id")), "clockwork", "arena/a_demo_lands_on_its_one_granted_arena")
		audit.check_true(bool(screen.call("can_start")), "arena/and_that_arena_can_start")
	else:
		audit.check_eq(str(screen.call("locked_ids")), str(career_wall), "arena/a_full_build_locks_only_the_careers_own_wall")
		audit.check_ne(String(screen.call("selected_arena_id")), "", "arena/a_full_build_has_a_startable_selection")
		var reachable := 0
		for id in all_ids:
			if bool(screen.call("select_arena", id)):
				reachable += 1
		audit.check_eq(reachable, all_ids.size() - career_wall.size(), "arena/every_arena_outside_the_career_wall_can_be_chosen")


## The arenas a fresh career does not grant: the frozen table's own unlock costs
## (`CareerRules.is_unlocked` over an empty career — no trophies, no stars).
func _career_locked_arenas() -> Array:
	var out: Array = []
	for arena in Frozen.arenas():
		var unlock: Variant = (arena as Dictionary).get("unlock")
		if unlock == null:
			continue
		var cost: Dictionary = unlock
		if int(cost.get("trophies", 0)) > 0 or int(cost.get("stars", 0)) > 0:
			out.append(String((arena as Dictionary).get("id", "")))
	return out


# ---------------------------------------------------------------------------
# 5. Modes (row 5) and the pinned difficulty (row 6)
# ---------------------------------------------------------------------------

func _modes(audit: AuditBase, router: Control, demo: bool) -> void:
	var screen: Node = await _go(router, "modes")
	audit.check_eq(String(screen.call("screen_id")), "modes", "modes/the_modes_screen_is_the_one_mounted")
	var rows: Array = screen.call("mode_rows_now")
	var ids: Array = []
	for row_in in rows:
		ids.append(String((row_in as Dictionary).get("id", "")))
	audit.check_eq(str(ids), str(REF_ALL_MODES), "modes/all_three_reference_modes_are_listed")
	for id in REF_ALL_MODES:
		var locked_here := demo and not REF_DEMO_MODES.has(id)
		audit.check_eq(bool(screen.call("mode_locked_shown", id)), locked_here, "modes/row_%s_lock_is_the_builds_own" % id)
	if demo:
		audit.check_eq(bool(screen.call("select_mode", "tournament")), false, "modes/a_demo_cannot_open_tournament")
		audit.check_eq(bool(screen.call("select_mode", "career")), false, "modes/a_demo_cannot_open_career")
		audit.check_eq(bool(screen.call("select_mode", "quick")), true, "modes/a_demo_opens_quick")
		for _i in SETTLE_FRAMES:
			await process_frame
		audit.check_eq(String(router.call("active_id")), "characters", "modes/and_quick_lands_on_characters")
	else:
		audit.check_eq(bool(screen.call("select_mode", "tournament")), true, "modes/a_full_build_opens_tournament")
		for _i in SETTLE_FRAMES:
			await process_frame
		audit.check_eq(String(router.call("active_id")), "characters", "modes/and_tournament_lands_on_characters")
	screen = await _go(router, "modes")
	# Row 6: the difficulty segmented, as rendered.
	for key in REF_ALL_DIFFICULTIES:
		var button: Button = screen.find_child("DiffButton_%s" % key, true, false)
		audit.check_true(button != null, "diff/the_%s_button_mounts" % key)
		var allowed := bool(screen.call("difficulty_allowed", String(key)))
		audit.check_eq(button != null and button.disabled, not allowed, "diff/the_%s_button_disabled_state_is_the_builds_answer" % key)
		if demo:
			audit.check_eq(allowed, String(key) == REF_DEMO_DIFFICULTY, "diff/a_demo_grants_%s_only" % REF_DEMO_DIFFICULTY)
		else:
			audit.check_eq(allowed, true, "diff/a_full_build_grants_%s" % String(key))
	if demo:
		audit.check_eq(String(screen.call("pinned_rung")), REF_DEMO_DIFFICULTY, "diff/a_demo_pins_medium")
		audit.check_eq(bool(screen.call("select_difficulty", "hard")), false, "diff/a_demo_refuses_hard")
		audit.check_eq(bool(screen.call("select_difficulty", "medium")), true, "diff/a_demo_takes_medium")
		audit.check_eq(Config.tier_index, int(Gate.DIFFICULTY_TIERS.get(REF_DEMO_DIFFICULTY, -1)), "diff/and_the_session_tier_is_the_pinned_one")
	else:
		audit.check_eq(String(screen.call("pinned_rung")), "", "diff/a_full_build_pins_nothing")
		audit.check_eq(bool(screen.call("select_difficulty", "legend")), true, "diff/a_full_build_takes_legend")
		audit.check_eq(Config.tier_index, 3, "diff/and_the_session_tier_moved_with_it")


# ---------------------------------------------------------------------------
# 6. Result CTA (rows 9-10): hidden while unconfigured; the copy follows the build
# ---------------------------------------------------------------------------

func _result_cta(audit: AuditBase, router: Control, demo: bool) -> void:
	var screen: Node = await _go(router, "result")
	audit.check_eq(String(screen.call("screen_id")), "result", "cta/the_result_screen_is_the_one_mounted")
	audit.check_eq(bool(screen.call("cta_visible")), false, "cta/the_block_starts_hidden_no_store_url_is_configured")
	audit.check_eq(bool(UiStrings.has("demoResultBody")), true, "cta/the_demo_body_copy_exists_in_the_frozen_tables")
	audit.check_eq(bool(UiStrings.has("betaResultBody")), false, "cta/the_beta_body_key_has_no_entry_visible_fallback")
	audit.check_eq(String(screen.call("cta_body_key")), "demoResultBody" if demo else "betaResultBody", "cta/the_body_key_is_the_builds_own")
	audit.check_eq(bool(screen.call("apply_capture_state", "demo-cta")), true, "cta/the_demo_cta_capture_applies")
	audit.check_eq(bool(screen.call("cta_visible")), true, "cta/a_configured_url_shows_the_block")
	audit.check_eq(String(screen.call("cta_label_key")), "demoWishlist", "cta/a_wishlist_destination_wishes")
	audit.check_eq(String((screen.find_child("CtaButton", true, false) as Button).text), UiStrings.t("demoWishlist"), "cta/the_button_carries_the_wishlist_label")
	audit.check_eq(bool(screen.call("apply_capture_state", "beta-cta")), true, "cta/the_beta_cta_capture_applies")
	audit.check_eq(String(screen.call("cta_label_key")), "storeFollow", "cta/a_follow_destination_follows")
	audit.check_eq(String((screen.find_child("CtaButton", true, false) as Button).text), UiStrings.t("storeFollow"), "cta/the_button_carries_the_follow_label")
	audit.check_eq(bool(screen.call("apply_capture_state", "default")), true, "cta/the_default_capture_applies")
	audit.check_eq(bool(screen.call("cta_visible")), false, "cta/and_the_block_hides_again")


# ---------------------------------------------------------------------------
# 7. The beta column: recorded, not run
# ---------------------------------------------------------------------------

func _beta_traceability(audit: AuditBase) -> void:
	audit.check_eq(DemoGate.badge_text_key_for("beta"), DemoGate.BADGE_BETA_KEY, "beta/the_beta_badge_key_is_the_adapters_own")
	audit.check_ne(DemoGate.badge_text_key_for("beta"), "", "beta/a_build_that_cannot_be_reached_still_answers")
	audit.note("the beta column is not runnable in the port today: tests/build/BuildFlag.gd:49-66 resolves ONE boolean over (feature tag, args) — resolve()/is_demo(); the reference's third label (js/build.js, BUILD === 'beta') has no port equivalent. The beta keys are still asked through their own doors (DemoGateAdapter.badge_text_key_for; ResultScreen.set_store_config(url, 'follow')), and betaResultBody has no locale entry so the id renders — the reference's own visible fallback")
	audit.not_ported("beta/build_column", "no beta build exists in the port today (BuildFlag.gd is one boolean); recorded as traceability, never emulated by string substitution")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _ids_of(items: Array) -> Array:
	var out: Array = []
	for item in items:
		out.append(String((item as Dictionary).get("id", "")))
	return out


func _wipe() -> void:
	var dir := DirAccess.open(TEMP_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(String(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))
