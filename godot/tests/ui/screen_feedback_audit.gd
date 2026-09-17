## screen_feedback_audit.gd — UIR-17's contract audit: the feedback screen in a router.
##
## WHAT IT PROVES, and the reference each question comes from:
##
##   1. the router mounts the screen and the screen declares its own facts
##      (`screen_id`, the router's own back target, its capture states);
##   2. the six topics are the reference's (`index.html:322-327` via
##      `UiData.feedback_topics`), one is active, and an unknown one is refused;
##   3. the message is bounded at `FEEDBACK.maxMessage` and the contact at 120
##      (`js/data.js:80`, `index.html:335`), with the counter composed as the reference
##      composes it (`js/main.js:1955`);
##   4. **the queue is written before any delivery attempt** (`js/ui.js:240-260`): the
##      delivery seam reads the save group at call time and records what it saw, so the
##      order is observed rather than asserted from the source;
##   5. the fallback ladder is the reference's (`js/main.js:2100-2121`): `offline` and
##      `no-endpoint` and `rejected` each end on their own status, the clipboard is
##      offered, and the text is revealed in the one path that cannot fail;
##   6. a success verdict marks every pending entry sent through the store — read back
##      from disk, not from the return value;
##   7. nothing is delivered by entering the screen, by a capture, or by any path other
##      than a button press: the seam's counter is the check;
##   8. the diagnostics payload is the reference's own object (keys compared one by one),
##      shown before it is attached, and attach=false writes `null`;
##   9. the OSK model path: with a pad connected, confirming the message field opens the
##      keyboard for that field, characters land in the field through the screen's own
##      insertion, and back closes it and returns the focus
##      (`godot/src/input/menu_nav.gd:219-259`);
##  10. a language flip moves every string the two tables differ on;
##  11. zero prose literals in `FeedbackScreen.gd` (the same scan `router_audit.gd`
##      applies to the whole UI lane, with the scan's own synthetic proof);
##  12. the five declared capture states apply and each is observable.
##
## THE DELIVERY SEAM IN THIS AUDIT IS LOCAL. It is a callable that inspects the temp
## save and returns a chosen verdict — no network call is made, and no real data leaves
## this process. The seam's verdicts are the reference's own words (`ok`/`offline`/
## `rejected`/`no-endpoint`, `js/ui.js:350-393`).
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/FeedbackScreen.gd")
const ScreenScene := preload("res://src/ui/screens/FeedbackScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")
const Osk := preload("res://src/input/osk.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const Schema := preload("res://src/save/save_schema.gd")

const SCREEN_PATH := "res://src/ui/screens/FeedbackScreen.gd"
const TEMP_DIR := "user://uir17-feedback-audit"
const REFERENCE_SCREEN_COUNT := 13
const SETTLE_FRAMES := 3
const FRAME := Vector2(1280, 720)

## The diagnostics keys the reference builds (`js/ui.js:268-308`), as a sorted list so
## the comparison is against the reference's list and not against the screen's output.
const DIAGNOSTIC_KEYS := [
	"career", "controlMode", "demo", "drillRecords", "gamepad", "lang", "matchesPlayed",
	"platform", "reduceMotion", "recentMatches", "screen", "settings",
]
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"feedbackTopic\")\n## a comment quoting \"prose in a comment\"\n"

var _router: Control
var _store: RefCounted
var _deliveries: Array = []


func _initialize() -> void:
	var audit := AuditBase.new("screen_feedback")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "ScreenFeedbackAuditFrame"
	frame.size = FRAME
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _mount(audit)
	await _facts(audit)
	await _topics(audit)
	await _bounds(audit)
	await _queue_first(audit)
	await _ladder(audit)
	await _success(audit)
	await _no_endpoint(audit)
	await _copy_paths(audit)
	await _diagnostics(audit)
	await _strings(audit)
	await _osk(audit)
	await _captures(audit)
	_literal_scan(audit)
	await _no_delivery_on_enter(audit)
	audit.report("temp store: %s (%d entries, %d groups) — the real user:// profile was never written" % [
		TEMP_DIR, _entries(_store).size(), Schema.group_names().size(),
	])


func _screen() -> Node:
	return _router.active_screen()


func _entries(store: RefCounted) -> Array:
	var read: Dictionary = store.read_group("feedback")
	var payload: Variant = read.get("payload", null)
	return payload if payload is Array else []


# ---------------------------------------------------------------------------
# 1. The router, and the screen's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "feedback/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "feedback/all_thirteen_slots_register")
	audit.check_true(_router.register("feedback", ScreenScene), "feedback/the_scene_registers_under_the_feedback_id")
	audit.check_eq(_router.go_to("feedback"), true, "feedback/go_to_mounts_the_screen")
	audit.check_eq(_router.active_id(), "feedback", "feedback/the_screen_is_active")
	audit.check_eq(_router.screen_count(), 1, "feedback/one_screen_is_mounted")
	var screen: Node = _screen()
	audit.check_true(screen != null, "feedback/the_mounted_screen_exists")
	audit.check_true(screen is ScreenClass, "feedback/the_mounted_scene_carries_FeedbackScreen_gd")
	audit.check_true(screen.theme != null, "feedback/the_scene_mounts_the_theme")
	screen.set_store(_store)
	audit.check_eq(screen.store().dir, TEMP_DIR, "feedback/the_audit_store_is_the_temp_one")


func _facts(audit: AuditBase) -> void:
	await process_frame
	var screen: Node = _screen()
	audit.check_eq(screen.screen_id(), "feedback", "feedback/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), "menu", "feedback/the_declared_return_is_the_router_own")
	audit.check_eq(screen.back_target(), Router.back_target_of("feedback"), "feedback/the_return_is_not_hardcoded")
	var states: Array = Array(screen.capture_states())
	var declared: Array = Array(ScreenClass.CAPTURE_STATES)
	audit.check_eq(states, declared, "feedback/the_declared_capture_states_are_the_screen_own")
	audit.check_eq(screen.apply_capture_state("nope"), false, "feedback/an_undeclared_capture_state_is_refused")
	audit.check_eq(screen.delivery_status(), "no-endpoint", "feedback/with_no_seam_installed_there_is_nowhere_to_send")


# ---------------------------------------------------------------------------
# 2. Topics and bounds
# ---------------------------------------------------------------------------

func _topics(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var rows: Array = UiData.feedback_topics()
	audit.check_eq(rows.size(), 6, "feedback/the_reference_lists_six_topics")
	var shown: Array = []
	for row in rows:
		var id := String((row as Dictionary)["id"])
		var button := screen.find_child("Topic_%s" % id, true, false) as Button
		if button == null:
			shown.append("%s:<missing>" % id)
			continue
		shown.append("%s:%s" % [id, button.text])
	audit.check_eq(shown.size(), 6, "feedback/every_topic_is_a_button")
	var expected: Array = []
	for row in rows:
		expected.append("%s:%s" % [String((row as Dictionary)["id"]), UiStrings.t(String((row as Dictionary)["label_key"]))])
	audit.check_eq(shown, expected, "feedback/every_topic_shows_its_own_label")
	audit.check_eq(screen.topic(), "bug", "feedback/the_first_topic_is_the_default")
	audit.check_eq(screen.select_topic("other"), true, "feedback/a_known_topic_can_be_chosen")
	audit.check_eq(screen.topic(), "other", "feedback/the_choice_is_the_one_made")
	audit.check_eq(screen.select_topic("bogus"), false, "feedback/an_unknown_topic_is_refused")
	audit.check_eq(screen.topic(), "other", "feedback/a_refused_choice_changes_nothing")
	screen.select_topic("bug")


func _bounds(audit: AuditBase) -> void:
	var screen: Node = _screen()
	audit.check_eq(screen.max_message(), 1200, "feedback/the_message_ceiling_is_FEEDBACK_maxMessage")
	audit.check_eq(Schema.FEEDBACK_MAX_QUEUED, 40, "feedback/the_queue_cap_is_the_reference_own")
	screen.set_message(String.chr(120).repeat(1200))
	audit.check_eq(screen.message().length(), 1200, "feedback/a_message_at_the_ceiling_is_kept_whole")
	audit.check_eq(screen.counter_text(), "1200" + String.chr(32) + "/" + String.chr(32) + "1200", "feedback/the_counter_shows_the_ceiling")
	screen.set_message(String.chr(120).repeat(1300))
	audit.check_eq(screen.message().length(), 1200, "feedback/a_longer_message_is_refused_on_screen")
	audit.check_eq(screen.counter_text(), "1200" + String.chr(32) + "/" + String.chr(32) + "1200", "feedback/the_counter_shows_the_cap")
	var contact := screen.find_child("ContactField", true, false) as LineEdit
	audit.check_eq(contact.max_length, 120, "feedback/the_contact_field_carries_the_reference_ceiling")
	screen.set_message("")


# ---------------------------------------------------------------------------
# 3. The queue is written before the delivery attempt
# ---------------------------------------------------------------------------

func _queue_first(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var seen: Array = []
	var seam := func(entries: Array) -> Dictionary:
		seen.append(_entries(_store).size())
		return {"ok": false, "reason": "rejected"}
	screen.set_delivery(Callable(seam), "https://example.invalid/uir17")
	screen.select_topic("controls")
	screen.set_message(String.chr(97).repeat(24))
	screen.set_contact(String.chr(98).repeat(140))
	var outcome: Dictionary = screen.submit()
	audit.check_eq(seen, [1], "feedback/the_delivery_saw_the_entry_already_queued")
	audit.check_eq(outcome.get("queued", false), true, "feedback/a_valid_submit_queues")
	audit.check_eq(outcome.get("status_key", ""), "feedbackManualHint", "feedback/a_rejected_delivery_ends_on_the_manual_hint")
	var stored: Array = _entries(_store)
	audit.check_eq(stored.size(), 1, "feedback/one_entry_is_on_disk")
	var entry: Dictionary = stored[0]
	audit.check_eq(bool(entry.get("sent", true)), false, "feedback/the_entry_is_unsent_until_a_seam_says_otherwise")
	audit.check_eq(String(entry.get("topic", "")), "controls", "feedback/the_stored_topic_is_the_chosen_one")
	audit.check_eq(String(entry.get("message", "")).length(), 24, "feedback/the_stored_message_is_whole")
	audit.check_eq(String(entry.get("contact", "")).length(), 120, "feedback/the_stored_contact_is_sliced_to_the_reference_length")
	audit.check_true(String(entry.get("id", "")).begins_with("fb-"), "feedback/the_id_is_the_reference_shape")
	audit.check_true(String(entry.get("ts", "")).contains("T"), "feedback/the_timestamp_is_iso")
	audit.check_true(screen.manual_visible(), "feedback/the_manual_block_is_revealed")
	audit.check_eq(screen.manual_text(), screen.feedback_as_text(entry), "feedback/the_revealed_text_is_the_entry_text")
	audit.check_eq(screen.message(), "", "feedback/the_message_field_is_cleared_after_queueing")


# ---------------------------------------------------------------------------
# 4. The ladder's other rungs
# ---------------------------------------------------------------------------

func _ladder(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.set_message(String.chr(99).repeat(8))
	var offline := func(_entries_in: Array) -> Dictionary:
		return {"ok": false, "reason": "offline"}
	screen.set_delivery(Callable(offline), "https://example.invalid/uir17")
	var outcome: Dictionary = screen.submit()
	audit.check_eq(outcome.get("status_key", ""), "feedbackOffline", "feedback/an_offline_delivery_says_offline")
	audit.check_true(screen.manual_visible(), "feedback/offline_still_offers_the_text")
	audit.check_eq(_entries(_store).size(), 2, "feedback/the_offline_entry_stays_queued")


func _success(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.set_message(String.chr(100).repeat(8))
	var ok := func(_entries_in: Array) -> Dictionary:
		return {"ok": true}
	screen.set_delivery(Callable(ok), "https://example.invalid/uir17")
	var outcome: Dictionary = screen.submit()
	audit.check_eq(outcome.get("sent", false), true, "feedback/a_success_verdict_reports_sent")
	audit.check_eq(outcome.get("status_key", ""), "feedbackSent", "feedback/a_success_verdict_says_sent")
	var sent := 0
	for entry in _entries(_store):
		if bool((entry as Dictionary).get("sent", false)):
			sent += 1
	audit.check_eq(sent, 3, "feedback/a_success_marks_every_pending_entry_sent_on_disk")
	audit.note("the seam's verdicts (rejected/offline/ok) are simulated locally: this audit makes no network call and writes only to %s" % TEMP_DIR)


func _no_endpoint(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.set_delivery(Callable(), "")
	audit.check_eq(screen.delivery_status(), "no-endpoint", "feedback/with_no_seam_there_is_no_endpoint")
	audit.check_eq(screen.send_label_key(), "feedbackSaveAndCopy", "feedback/the_send_button_promises_only_a_save")
	audit.check_eq(screen.note_key(), "feedbackNoServer", "feedback/the_note_says_nothing_leaves_the_game")
	screen.set_message(String.chr(101).repeat(8))
	var outcome: Dictionary = screen.submit()
	audit.check_eq(String(outcome.get("reason", "")), "no-endpoint", "feedback/a_submit_without_an_endpoint_names_the_reason")
	audit.check_eq(outcome.get("status_key", ""), "feedbackManualHint", "feedback/with_no_endpoint_the_text_is_offered")
	audit.check_eq(_entries(_store).size(), 4, "feedback/the_entry_is_still_queued_without_an_endpoint")
	audit.check_eq(screen.status_text(), UiStrings.t("feedbackManualHint"), "feedback/the_status_line_shows_the_key")


# ---------------------------------------------------------------------------
# 5. The copy path and its failure
# ---------------------------------------------------------------------------

func _copy_paths(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var copied: Array = []
	var recorder := func(text: String) -> bool:
		copied.append(text)
		return true
	screen.set_clipboard_writer(Callable(recorder))
	screen.set_message(String.chr(102).repeat(6))
	var status: String = screen.copy_current()
	audit.check_eq(status, "feedbackCopied", "feedback/a_successful_copy_says_copied")
	audit.check_eq(copied.size(), 1, "feedback/the_writer_was_asked_once")
	audit.check_true(String(copied[0]).contains(String.chr(102).repeat(6)), "feedback/the_copied_text_carries_the_message")
	screen.set_message(String.chr(103).repeat(6))
	var refusing := func(_text: String) -> bool:
		return false
	screen.set_clipboard_writer(Callable(refusing))
	var refused: String = screen.copy_current()
	audit.check_eq(refused, "feedbackManualHint", "feedback/a_refused_clipboard_falls_back_to_the_text")
	audit.check_true(screen.manual_visible(), "feedback/the_refused_copy_still_shows_the_text")
	audit.check_true(screen.manual_text().contains(String.chr(103).repeat(6)), "feedback/the_revealed_text_is_this_message")
	screen.set_message("")
	var empty_status: String = screen.copy_current()
	audit.check_eq(empty_status, "feedbackEmpty", "feedback/copy_with_an_empty_field_is_reported")


# ---------------------------------------------------------------------------
# 6. The diagnostics payload
# ---------------------------------------------------------------------------

func _diagnostics(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.select_topic("balance")
	screen.set_message(String.chr(104).repeat(4))
	var payload: Dictionary = screen.diagnostics_payload()
	var keys: Array = payload.keys()
	keys.sort()
	var expected: Array = DIAGNOSTIC_KEYS.duplicate()
	expected.sort()
	audit.check_eq(keys, expected, "feedback/the_payload_carries_the_reference_keys")
	audit.check_eq(String(payload.get("lang", "")), Locale.current_lang(), "feedback/the_payload_names_the_session_language")
	audit.check_eq(String(payload.get("platform", "")), OS.get_name(), "feedback/the_payload_names_the_platform")
	audit.check_true(String(payload.get("screen", "")).contains("x"), "feedback/the_payload_carries_the_frame_size")
	var settings: Dictionary = payload.get("settings", {})
	audit.check_eq(settings.keys().size(), 3, "feedback/the_payload_carries_the_three_settings")
	var career: Dictionary = payload.get("career", {})
	audit.check_eq(career.keys().size(), 5, "feedback/the_payload_carries_the_five_career_figures")
	audit.check_eq(screen.diagnostics_text(), JSON.stringify(payload, "\t", true), "feedback/the_disclosure_shows_the_payload_verbatim")
	screen.set_attach(false)
	screen.set_message(String.chr(105).repeat(4))
	var detached: Dictionary = screen.queue_feedback("bug", String.chr(105).repeat(4), "", false)
	audit.check_eq(detached.get("diagnostics", "x"), null, "feedback/attach_off_stores_null")
	screen.set_attach(true)


# ---------------------------------------------------------------------------
# 7. Strings
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var language_at_start := Locale.current_lang()
	audit.check_eq(language_at_start, Locale.default_lang(), "feedback/the_run_starts_in_the_default_language")
	var unresolved: Array = []
	for row in UiData.feedback_topics():
		var key := String((row as Dictionary)["label_key"])
		for lang in Locale.locales():
			if not Locale.is_resolvable(key, String(lang)):
				unresolved.append("%s/%s" % [key, lang])
	for key in ["feedbackTitle", "feedbackSub", "feedbackTopic", "feedbackMessage", "feedbackContact",
			"feedbackAttach", "feedbackWhatIsAttached", "feedbackCopy", "feedbackSteam",
			"feedbackManualTitle", "feedbackPlaceholder", "feedbackContactHint", "feedbackNoServer",
			"feedbackEmpty", "feedbackSaved", "feedbackSent", "feedbackOffline", "feedbackFallback",
			"feedbackManualHint", "feedbackCopied", "feedbackQueued", "feedbackSaveAndCopy", "feedbackSend"]:
		for lang in Locale.locales():
			if not Locale.is_resolvable(key, String(lang)):
				unresolved.append("%s/%s" % [key, lang])
	audit.check_eq(unresolved, [], "feedback/every_visible_key_resolves_in_both_locales")

	var other := ""
	for lang in Locale.locales():
		if String(lang) != language_at_start:
			other = String(lang)
	audit.check_true(other != "", "feedback/there_is_a_second_locale_to_flip_to")
	var slots := _slots(screen)
	var before := _visible_texts(screen)
	Locale.set_lang(other)
	screen.refresh_strings()
	await process_frame
	var after := _visible_texts(screen)
	var moved := 0
	var wrong: Array = []
	for slot in slots:
		var key := String(slots[slot])
		var expected_text := Locale.resolve(key, other)
		if String(after[slot]) != expected_text:
			wrong.append("%s expected <%s> got <%s>" % [slot, expected_text, after[slot]])
		if Locale.resolve(key, language_at_start) != expected_text:
			moved += 1
	audit.check_eq(wrong, [], "feedback/the_flip_shows_the_other_tables_own_text")
	audit.check_gt(moved, 0, "feedback/the_flip_moved_strings_that_differ")
	audit.report("language flip: %d of %d visible slots differ between tables, all now show %s" % [moved, slots.size(), other])
	Locale.set_lang(language_at_start)
	screen.refresh_strings()
	await process_frame
	var restored := _visible_texts(screen)
	var still_wrong: Array = []
	for slot in slots:
		if String(restored[slot]) != String(before[slot]):
			still_wrong.append(slot)
	audit.check_eq(still_wrong, [], "feedback/the_flip_back_restores_every_slot")


## Every visible slot the screen owns, as slot → the message id it shows. The send
## button's id follows the screen's own state (`feedbackSend` only when a delivery
## endpoint exists; `feedbackSaveAndCopy` without one — `send_label_key()`), so the
## slot is read from the screen and not pinned. The language buttons carry no id (the
## reference writes IT/EN as literals) and are left out.
func _slots(screen: Node) -> Dictionary:
	var out := {}
	for row in UiData.feedback_topics():
		var id := String((row as Dictionary)["id"])
		out["topic/%s" % id] = String((row as Dictionary)["label_key"])
	out["send"] = screen.send_label_key()
	out["copy"] = "feedbackCopy"
	out["steam"] = "feedbackSteam"
	out["attach"] = "feedbackAttach"
	out["details"] = "feedbackWhatIsAttached"
	out["manual"] = "feedbackManualTitle"
	out["message_label"] = "feedbackMessage"
	out["contact_label"] = "feedbackContact"
	out["topic_label"] = "feedbackTopic"
	return out


## …and what those slots actually show, read back from the scene.
func _visible_texts(screen: Node) -> Dictionary:
	var out := {}
	for row in UiData.feedback_topics():
		var id := String((row as Dictionary)["id"])
		var button := screen.find_child("Topic_%s" % id, true, false) as Button
		out["topic/%s" % id] = button.text if button != null else "<missing>"
	out["send"] = _text_of(screen, "SendButton")
	out["copy"] = _text_of(screen, "CopyButton")
	out["steam"] = _text_of(screen, "SteamButton")
	out["attach"] = _text_of(screen, "AttachCheck")
	out["details"] = _text_of(screen, "DetailsToggle")
	out["manual"] = _text_of(screen, "ManualLabel")
	out["message_label"] = _text_of(screen, "MessageLabel")
	out["contact_label"] = _text_of(screen, "ContactLabel")
	out["topic_label"] = _text_of(screen, "TopicLabel")
	return out


func _text_of(screen: Node, node_name: String) -> String:
	var node := screen.find_child(node_name, true, false)
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	if node is CheckBox:
		return (node as CheckBox).text
	return "<missing>"


# ---------------------------------------------------------------------------
# 8. The OSK model path
# ---------------------------------------------------------------------------

func _osk(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.set_message("")
	var focus: RefCounted = MenuFocus.new()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(screen, focus, _router)
	var nav: MenuNav = focus.menu
	nav.set_pad_connected(true)
	audit.check_true(bridge.set_focus(screen.focus_id("MessageField")), "feedback/the_message_field_takes_the_focus")
	audit.check_eq(nav.osk.is_open(), false, "feedback/the_keyboard_starts_closed")
	audit.check_eq(bridge.dispatch(_key_event(KEY_ENTER)), true, "feedback/confirm_on_the_field_is_handled")
	audit.check_eq(nav.osk.is_open(), true, "feedback/with_a_pad_confirm_opens_the_keyboard_model")
	audit.check_eq(String(bridge.last_dispatch().get("kind", "")), "osk_open", "feedback/the_verdict_names_the_keyboard")
	audit.check_eq(nav.osk.target_id(), screen.focus_id("MessageField"), "feedback/the_keyboard_opened_for_the_message_field")
	var seed_data: Dictionary = screen.osk_seed(screen.focus_id("MessageField"))
	audit.check_eq(int(seed_data.get("max_length", 0)), 1200, "feedback/the_field_offers_the_reference_ceiling_to_the_keyboard")
	audit.check_eq(String(seed_data.get("field_label", "")), "feedbackMessage", "feedback/the_field_names_its_own_label_to_the_keyboard")
	var expected_targets := Osk.ACTION_KEYS.size()
	for row in Osk.ROWS:
		expected_targets += String(row).length()
	audit.check_eq(screen.osk_key_targets().size(), expected_targets, "feedback/the_keyboard_targets_are_the_reference_rows")
	nav.set_osk_targets(screen.osk_key_targets())
	audit.check_eq(nav.osk.press_char("z"), true, "feedback/the_keyboard_model_takes_a_character")
	audit.check_eq(nav.osk.press_char("q"), true, "feedback/a_second_character_lands_in_the_model")
	audit.check_eq(nav.osk.value(), "zq", "feedback/the_model_holds_what_was_typed")
	audit.check_eq(screen.apply_osk_value(nav.osk.target_id(), nav.osk.value()), true, "feedback/the_screen_accepts_the_models_value")
	audit.check_eq(screen.message(), "zq", "feedback/the_typed_characters_land_in_the_field")
	audit.check_eq(screen.counter_text(), "2" + String.chr(32) + "/" + String.chr(32) + "1200", "feedback/the_counter_follows_the_typed_text")
	var over := nav.osk.value() + String.chr(120).repeat(1300)
	audit.check_eq(screen.apply_osk_value(nav.osk.target_id(), over), true, "feedback/an_over_long_value_is_accepted_by_the_field")
	audit.check_eq(screen.message().length(), 1200, "feedback/and_is_capped_at_the_ceiling")
	audit.check_eq(bridge.dispatch(_key_event(KEY_ESCAPE)), true, "feedback/back_with_the_keyboard_open_is_handled")
	audit.check_eq(nav.osk.is_open(), false, "feedback/back_closes_the_keyboard_model")
	audit.check_eq(String(bridge.last_dispatch().get("kind", "")), "osk_close", "feedback/the_verdict_names_the_close")
	audit.check_eq(bridge.focus_id(), screen.focus_id("MessageField"), "feedback/closing_the_keyboard_gives_the_field_back")


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


# ---------------------------------------------------------------------------
# 9. The capture states
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = _screen()
	for state_id in ScreenClass.CAPTURE_STATES:
		audit.check_eq(screen.apply_capture_state(String(state_id)), true, "feedback/capture_state_%s_applies" % state_id)
	var counted: bool = screen.apply_capture_state("counted")
	audit.check_eq(counted, true, "feedback/the_counted_state_applies")
	audit.check_eq(screen.counter_text(), "1200" + String.chr(32) + "/" + String.chr(32) + "1200", "feedback/the_counted_state_fills_the_counter")
	audit.check_eq(screen.apply_capture_state("diagnostics-open"), true, "feedback/the_diagnostics_state_applies")
	audit.check_true((screen.find_child("DiagView", true, false) as Control).visible, "feedback/the_diagnostics_state_opens_the_disclosure")
	audit.check_eq(screen.apply_capture_state("fallback"), true, "feedback/the_fallback_state_applies")
	audit.check_true(screen.manual_visible(), "feedback/the_fallback_state_shows_the_text")
	audit.check_eq(screen.apply_capture_state("sent"), true, "feedback/the_sent_state_applies")
	audit.check_eq(screen.status_text(), UiStrings.t("feedbackSent"), "feedback/the_sent_state_pins_the_sent_line")
	audit.check_eq(screen.apply_capture_state("default"), true, "feedback/the_default_state_applies")
	audit.check_eq(screen.message(), "", "feedback/the_default_state_clears_the_field")


# ---------------------------------------------------------------------------
# 10. The literal scan, and the promise that entering delivers nothing
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "feedback/the_literal_scan_flags_prose_and_ignores_developer_text")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "feedback/the_screen_source_is_readable")
	audit.check_eq(_offenders_in_source(SCREEN_PATH, source), [], "feedback/FeedbackScreen_gd_carries_no_prose_literal")


func _no_delivery_on_enter(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var calls: Array = []
	var counting := func(entries: Array) -> Dictionary:
		calls.append(entries.size())
		return {"ok": true}
	screen.set_delivery(Callable(counting), "https://example.invalid/uir17")
	screen.enter({"router_id": "feedback", "back_target": "menu"})
	screen.apply_capture_state("default")
	await process_frame
	audit.check_eq(calls, [], "feedback/entering_and_capturing_deliver_nothing")
	var pressed: Array = []
	var counting_again := func(entries: Array) -> Dictionary:
		pressed.append(entries.size())
		return {"ok": false, "reason": "rejected"}
	screen.set_delivery(Callable(counting_again), "https://example.invalid/uir17")
	screen.set_message(String.chr(106).repeat(5))
	screen.submit()
	audit.check_eq(pressed.size(), 1, "feedback/only_a_button_press_reaches_the_seam")


# ---------------------------------------------------------------------------
# Internals: the scan the UI lane runs, and the temp directory's own cleanup
# ---------------------------------------------------------------------------

func _offenders_in_source(path: String, source: String) -> Array:
	var out: Array = []
	var lines := source.split("\n")
	for index in lines.size():
		var code := String(lines[index]).split("#")[0]
		var developer := false
		for marker in DEVELOPER_MARKERS:
			if code.contains(marker):
				developer = true
				break
		if developer:
			continue
		for literal in _literals(code):
			if not String(literal).contains(" "):
				continue
			out.append("%s:%d \"%s\"" % [path, index + 1, literal])
	return out


func _literals(code: String) -> Array:
	var out: Array = []
	var i := 0
	while i < code.length():
		if code[i] == "\"":
			var j := i + 1
			var buffer := ""
			while j < code.length() and code[j] != "\"":
				if code[j] == "\\":
					j += 1
					if j < code.length():
						buffer += code[j]
				else:
					buffer += code[j]
				j += 1
			out.append(buffer)
			i = j + 1
		else:
			i += 1
	return out


func _wipe() -> void:
	var dir := DirAccess.open(TEMP_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(String(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))
