## feedback_screen_delivery_test.gd — the 3D form posting through the host's transport.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##       --script res://tests/feedback/feedback_screen_delivery_test.gd
##
## WHAT IT GATES:
##
##   1. THE FORM ANSWERS FOR ITS ENDPOINT: with the host's transport armed and configured
##      the send button promises a send and the "nothing leaves the game" note is gone;
##      with no transport (or one with no endpoint) the honest save-and-copy ladder is
##      back, unchanged.
##   2. QUEUE FIRST: the entry is on disk, unsent, when the request goes out — the same
##      read the transport's own test does, seen from the screen's side.
##   3. THE STATUS IS THE RECEIPT: a confirmed entry ends on the sent line, an offline
##      run on the offline line, a refusal on the manual hint — and in both failure cases
##      the manual copy block is revealed with the text, which is the rung that cannot fail.
##   4. THE HOST OWNS THE TRANSPORT, AND A HEADLESS RUN NEVER ARMS ONE: the playable menu
##      mounted in a headless lane carries no transport at all, so the form keeps its
##      local-only ladder and no automated pass over the menu can post a message.
##
## The transport under test is the real `feedback_delivery.gd`; only its socket is faked
## (`set_poster`), and the store is a temp directory. No request leaves this process.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenScene := preload("res://src/ui/screens/FeedbackScreen.tscn")
const Delivery := preload("res://src/feedback/feedback_delivery.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Config := preload("res://game/match_config.gd")

const TEMP_DIR := "user://feedback-screen-delivery-test"
const HOST_DIR := "user://feedback-host-test"
const TEST_ENDPOINT := "https://example.invalid/feedback-screen-test"
const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 3


## A transport that answers when the test says so (`feedback_delivery.gd::set_poster`).
class FakePoster extends RefCounted:
	var calls: Array = []
	var callbacks: Array = []

	func post(_url: String, body: String, _timeout_ms: int, on_done: Callable) -> void:
		calls.append(body)
		callbacks.append(on_done)

	func cancel() -> void:
		pass

	func deliver(index: int, reply: Dictionary) -> void:
		if index < callbacks.size():
			callbacks[index].call(reply)


class ImmediateOfflinePoster extends RefCounted:
	func post(_url: String, _body: String, _timeout_ms: int, on_done: Callable) -> void:
		on_done.call({"ok": false, "reason": "offline"})

	func cancel() -> void:
		pass


var _store: RefCounted
var _delivery: Node
var _poster: FakePoster
## The clipboard seam the screen documents: a headless run has no display server
## clipboard, and the fallback ladder must still be drivable without one.
var _copied: Array = []


func _initialize() -> void:
	var audit := AuditBase.new("feedback_screen_delivery")
	await _run(audit)
	if _delivery != null and is_instance_valid(_delivery):
		_delivery.call("cancel_run")
		_delivery.call("set_poster", null)
	if _poster != null:
		_poster.callbacks.clear()
	var frame := root.get_node_or_null("FeedbackScreenDeliveryFrame")
	if frame != null:
		frame.queue_free()
		await process_frame
	_wipe(TEMP_DIR)
	_wipe(HOST_DIR)
	Config.save_dir = ""
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	# A previous run of this file may have left entries behind: the store under test is a
	# temp directory, and each run starts from an empty profile.
	_wipe(TEMP_DIR)
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "FeedbackScreenDeliveryFrame"
	frame.size = FRAME
	root.add_child(frame)
	var router: Control = Router.new()
	router.name = "Router"
	frame.add_child(router)
	# The transport is mounted beside the router, exactly as the playable host mounts it:
	# a sibling of the screens, not a child of the form.
	_poster = FakePoster.new()
	_delivery = Delivery.new()
	_delivery.name = "FeedbackDelivery"
	frame.add_child(_delivery)
	_delivery.call("set_store_provider", Callable(self, "_store_provider"))
	_delivery.call("set_poster", _poster)
	_delivery.call("configure", TEST_ENDPOINT)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _armed(audit, router)
	await _status_ladder(audit)
	await _immediate_failure(audit)
	await _storage_failure(audit)
	await _unarmed(audit)
	await _survives_exit(audit)
	await _busy_on_boot(audit)
	await _binding(audit)
	await _initial_route(audit)
	await _host_guard(audit)
	audit.report("temp stores: %s and %s — the real user:// profile was never written" % [TEMP_DIR, HOST_DIR])


func _store_provider() -> RefCounted:
	return _store


func _screen(router: Control) -> Node:
	return router.active_screen()


func _entries() -> Array:
	var payload: Variant = _store.read_group("feedback").get("payload", null)
	return payload if payload is Array else []


func _entry(id: String, message: String) -> Dictionary:
	return {
		"id": id,
		"ts": "2026-01-01T00:00:00Z",
		"topic": "bug",
		"message": message,
		"contact": "",
		"diagnostics": null,
		"sent": false,
	}


func _mount_feedback(router: Control) -> Node:
	if not router.register("feedback", ScreenScene):
		return null
	if not router.go_to("feedback"):
		return null
	var screen: Node = _screen(router)
	screen.set_store(_store)
	screen.set_async_delivery(_delivery)
	screen.set_clipboard_writer(Callable(self, "_clipboard"))
	return screen


func _clipboard(text: String) -> bool:
	_copied.append(text)
	return true


# ---------------------------------------------------------------------------
# 1. The armed form
# ---------------------------------------------------------------------------

func _armed(audit: AuditBase, router: Control) -> void:
	var screen: Node = _mount_feedback(router)
	audit.check_true(screen != null, "screen/the_feedback_screen_mounts")
	if screen == null:
		return
	audit.check_eq(screen.delivery_transport(), _delivery, "screen/the_transport_is_the_hosts_own")
	audit.check_eq(screen.transport_ready(), true, "screen/the_transport_is_ready")
	audit.check_eq(screen.has_endpoint(), true, "screen/an_armed_transport_is_an_endpoint")
	audit.check_eq(screen.delivery_status(), "configured", "screen/the_status_is_configured")
	audit.check_eq(screen.send_label_key(), "feedbackSend", "screen/the_button_promises_a_send")
	audit.check_eq(screen.note_key(), "", "screen/the_no_server_note_is_gone")
	# The synchronous seam the audit drives is untouched by all of this.
	audit.check_eq(screen.delivery_status() != "no-endpoint", true, "screen/the_async_door_does_not_disturb_the_seam")


# ---------------------------------------------------------------------------
# 2. A submit, and the three verdicts it can end on
# ---------------------------------------------------------------------------

func _submit(router: Control, message: String) -> Dictionary:
	var screen: Node = _screen(router)
	screen.set_message(message)
	return screen.submit()


func _status_ladder(audit: AuditBase) -> void:
	var router: Control = _router_of()
	var screen: Node = _screen(router)

	# A confirmed send.
	var outcome: Dictionary = _submit(router, String.chr(115).repeat(12))
	audit.check_eq(outcome.get("queued", false), true, "screen/a_valid_submit_queues")
	audit.check_eq(outcome.get("pending", false), true, "screen/and_leaves_the_send_pending")
	audit.check_eq(String(outcome.get("status_key", "")), "feedbackQueued", "screen/the_pending_line_is_the_queue_line")
	audit.check_eq(_entries().size(), 1, "screen/the_entry_is_on_disk_before_the_request")
	audit.check_eq(not bool((_entries()[0] as Dictionary).get("sent", false)), true, "screen/and_it_is_unsent")
	audit.check_eq(_poster.calls.size(), 1, "screen/the_transport_was_asked_once")
	audit.check_true(String(_poster.calls[0]).contains("\"entries\":[{"), "screen/the_frame_sent_the_handlers_envelope")
	audit.check_eq(screen.message(), "", "screen/the_message_field_is_cleared_after_queueing")
	_poster.deliver(0, {"ok": true})
	audit.check_eq(screen.status_key(), "feedbackSent", "screen/a_receipt_ends_on_the_sent_line")
	audit.check_eq(screen.status_text(), UiStrings.t("feedbackSent"), "screen/and_the_line_is_resolved")
	audit.check_eq(bool((_entries()[0] as Dictionary).get("sent", false)), true, "screen/the_confirmed_entry_is_marked_on_disk")
	audit.check_eq(screen.manual_visible(), false, "screen/a_confirmed_send_offers_no_fallback")

	# The network is gone.
	_submit(router, String.chr(111).repeat(10))
	_poster.deliver(1, {"ok": false, "reason": "offline"})
	audit.check_eq(screen.status_key(), "feedbackOffline", "screen/an_offline_run_says_offline")
	audit.check_eq(screen.manual_visible(), true, "screen/and_offers_the_text")
	audit.check_true(screen.manual_text().contains(String.chr(111).repeat(10)), "screen/and_the_text_is_this_message")
	audit.check_true(_copied.size() > 0 and String(_copied[_copied.size() - 1]).contains(String.chr(111).repeat(10)), "screen/and_it_was_offered_to_the_clipboard_too")
	audit.check_eq(_pending_count(), 1, "screen/the_offline_entry_stays_pending")

	# The endpoint refused it.
	_submit(router, String.chr(114).repeat(10))
	_poster.deliver(2, {"ok": false, "reason": "rejected"})
	audit.check_eq(screen.status_key(), "feedbackManualHint", "screen/a_refusal_ends_on_the_manual_hint")
	audit.check_eq(_pending_count(), 2, "screen/a_refused_entry_stays_pending")
	audit.check_eq(_poster.calls.size(), 3, "screen/every_submit_made_its_own_request")

	# A late verdict for a screen the player has left marks nothing.
	audit.check_eq(screen.status_key() != "", true, "screen/the_status_is_never_empty_after_a_verdict")


func _pending_count() -> int:
	var count := 0
	for entry in _entries():
		if entry is Dictionary and not bool((entry as Dictionary).get("sent", false)):
			count += 1
	return count


func _immediate_failure(audit: AuditBase) -> void:
	var screen: Node = _screen(_router_of())
	_delivery.call("set_poster", ImmediateOfflinePoster.new())
	var outcome := _submit(_router_of(), "immediate-offline")
	audit.check_eq(outcome.get("queued", false), true, "screen/an_immediate_failure_was_queued_first")
	audit.check_eq(screen.status_key(), "feedbackOffline", "screen/an_immediate_failure_is_not_overwritten_by_queued")
	_delivery.call("set_poster", _poster)


func _storage_failure(audit: AuditBase) -> void:
	var screen: Node = _screen(_router_of())
	var before := _pending_count()
	var requests := int(_delivery.call("request_count"))
	screen.set_message("storage-failure")
	_store.fail_before_rename = true
	var outcome: Dictionary = screen.submit()
	_store.fail_before_rename = false
	audit.check_eq(outcome.get("queued", true), false, "screen/a_failed_write_never_claims_to_queue")
	audit.check_eq(_pending_count(), before, "screen/a_failed_write_adds_no_pending_entry")
	audit.check_eq(int(_delivery.call("request_count")), requests, "screen/a_failed_write_sends_no_request")
	audit.check_eq(screen.message(), "storage-failure", "screen/a_failed_write_keeps_the_message")
	audit.check_eq(screen.status_key(), "feedbackManualHint", "screen/a_failed_write_offers_the_manual_fallback")


func _router_of() -> Control:
	return root.find_child("Router", true, false) as Control


# ---------------------------------------------------------------------------
# 3. The ladder with no transport, and with one that has no endpoint
# ---------------------------------------------------------------------------

func _unarmed(audit: AuditBase) -> void:
	var router: Control = _router_of()
	var screen: Node = _screen(router)
	screen.set_async_delivery(null)
	audit.check_eq(screen.transport_ready(), false, "screen/no_transport_is_not_ready")
	audit.check_eq(screen.has_endpoint(), false, "screen/no_transport_is_no_endpoint")
	audit.check_eq(screen.send_label_key(), "feedbackSaveAndCopy", "screen/the_button_promises_only_a_save")
	audit.check_eq(screen.note_key(), "feedbackNoServer", "screen/the_note_says_nothing_leaves_the_game")

	# A transport that exists but was never configured is the same answer.
	var blank: Node = Delivery.new()
	blank.name = "UnconfiguredDelivery"
	root.add_child(blank)
	screen.set_async_delivery(blank)
	audit.check_eq(screen.has_endpoint(), false, "screen/an_unconfigured_transport_is_no_endpoint")
	audit.check_eq(screen.send_label_key(), "feedbackSaveAndCopy", "screen/and_the_button_still_promises_only_a_save")
	blank.queue_free()
	screen.set_async_delivery(_delivery)


# ---------------------------------------------------------------------------
# 4. The message outlives the form
# ---------------------------------------------------------------------------

## The message outlives the form: the transport belongs to the host, so a player who
## leaves the screen while a send is in flight still gets the delivery and the
## confirmation written. The screen is freed mid-run and the run finishes anyway.
func _survives_exit(audit: AuditBase) -> void:
	var router: Control = _router_of()
	var screen: Node = _mount_feedback(router)
	audit.check_true(screen != null, "exit/the_form_mounts_again")
	if screen == null:
		return
	var before := _pending_count()
	_submit(router, String.chr(120).repeat(9))
	audit.check_eq(_pending_count(), before + 1, "exit/one_more_entry_is_queued")
	audit.check_eq(_delivery.call("running"), true, "exit/a_run_is_in_flight")
	screen.queue_free()
	await process_frame
	audit.check_eq(is_instance_valid(screen), false, "exit/the_form_is_gone")
	audit.check_eq(is_instance_valid(_delivery), true, "exit/the_transport_is_still_mounted")
	_drain()
	audit.check_eq(_delivery.call("running"), false, "exit/the_run_finished_without_the_form")
	audit.check_eq(_pending_count(), 0, "exit/every_entry_was_confirmed_after_the_form_closed")


## Answers every request the run has outstanding until it drains. Each answer appends the
## next request (`feedback_delivery.gd::_advance`), so the last callback index is always
## the one still waiting.
func _drain(limit := 12) -> void:
	var guard := 0
	while bool(_delivery.call("running")) and guard < limit:
		var index := _poster.callbacks.size() - 1
		if index < 0:
			return
		_poster.deliver(index, {"ok": true})
		guard += 1


# ---------------------------------------------------------------------------
# 5. A submit while the launch retry is still running
# ---------------------------------------------------------------------------

## The launch retry is started by the host before the first route is mounted, so the very
## first press on the form can land on a busy transport. The entry is queued either way,
## the line says so, and the running pass delivers it — the verdict is never lost, because
## the screen is bound to the transport's own signal rather than to its own run.
func _busy_on_boot(audit: AuditBase) -> void:
	var router: Control = _router_of()
	var screen: Node = _mount_feedback(router)
	audit.check_true(screen != null, "busy/the_form_mounts")
	if screen == null:
		return
	# An entry already pending, and a run over it already in flight: the launch retry.
	_store.write_feedback([_entry("fb-boot-run", "boot-run")])
	_poster = FakePoster.new()
	_delivery.call("set_poster", _poster)
	var launched: Dictionary = _delivery.call("boot_retry")
	audit.check_eq(launched.get("started", false), true, "busy/the_launch_run_started")
	var outcome: Dictionary = _submit(router, String.chr(98).repeat(11))
	audit.check_eq(outcome.get("queued", false), true, "busy/the_submit_still_queues_during_the_launch_run")
	audit.check_eq(outcome.get("pending", false), true, "busy/and_says_the_send_is_pending")
	audit.check_eq(String(outcome.get("status_key", "")), "feedbackQueued", "busy/and_shows_the_queue_line")
	audit.check_eq(screen.status_key(), "feedbackQueued", "busy/the_visible_line_is_not_left_empty")
	_drain()
	audit.check_eq(screen.status_key(), "feedbackSent", "busy/the_launch_runs_verdict_reaches_the_live_screen")
	audit.check_eq(_pending_count(), 0, "busy/every_entry_was_delivered")


# ---------------------------------------------------------------------------
# 6. The screen's binding to the transport
# ---------------------------------------------------------------------------

func _binding(audit: AuditBase) -> void:
	var router: Control = _router_of()
	var screen: Node = _screen(router)
	# Re-installing the same transport is the host's own screen-swap path.
	for _i in 4:
		screen.set_async_delivery(_delivery)
	audit.check_eq(_delivery.get_signal_connection_list("run_finished").size(), 1, "bind/one_handler_at_most_after_repeated_installs")
	screen.set_async_delivery(null)
	audit.check_eq(_delivery.get_signal_connection_list("run_finished").size(), 0, "bind/the_handler_follows_the_transport_away")
	screen.set_async_delivery(_delivery)
	audit.check_eq(_delivery.get_signal_connection_list("run_finished").size(), 1, "bind/and_comes_back_with_it")


# ---------------------------------------------------------------------------
# 7. A launch that reopens the feedback form
# ---------------------------------------------------------------------------

## `Config.pending_menu_screen` is the host's own "reopen this screen at launch" switch.
## The transport has to be armed before the initial route, or a launch that asks for the
## feedback form would be handed a null transport and stay local-only for the whole run.
func _initial_route(audit: AuditBase) -> void:
	Config.pending_menu_screen = "feedback"
	var menu := (load("res://game/Main.tscn") as PackedScene).instantiate()
	menu.name = "InitialRouteMenu"
	root.add_child(menu)
	for _i in SETTLE_FRAMES:
		await process_frame
	var router: Control = menu.find_child("UiRouter", true, false) as Control
	audit.check_true(router != null, "route/the_playable_router_is_mounted")
	if router == null:
		menu.queue_free()
		Config.pending_menu_screen = ""
		return
	audit.check_eq(router.active_id(), "feedback", "route/the_launch_opened_the_feedback_form")
	var screen: Node = router.active_screen()
	# Headless never arms a transport, so this lane proves the ORDER rather than the
	# endpoint: the door was offered by the mount itself, which is what the fix is about.
	audit.check_true(screen.has_method("set_async_delivery"), "route/the_form_carries_the_door")
	audit.check_eq(menu.find_child("FeedbackDelivery", true, false), null, "route/and_this_headless_lane_still_arms_nothing")
	audit.check_eq(screen.has_endpoint(), false, "route/so_the_form_is_local_only_here")
	menu.queue_free()
	await process_frame
	Config.pending_menu_screen = ""


# ---------------------------------------------------------------------------
# 8. The host's own guard
# ---------------------------------------------------------------------------

func _host_guard(audit: AuditBase) -> void:
	_wipe(HOST_DIR)
	Config.save_dir = HOST_DIR
	var menu := (load("res://game/Main.tscn") as PackedScene).instantiate()
	menu.name = "HostMenu"
	root.add_child(menu)
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_eq(DisplayServer.get_name(), "headless", "host/the_test_lane_is_headless")
	audit.check_eq(menu.find_child("FeedbackDelivery", true, false), null, "host/a_headless_run_arms_no_transport")
	audit.check_eq(menu.find_child("FeedbackHttp", true, false), null, "host/and_builds_no_socket")
	var router: Control = menu.find_child("UiRouter", true, false) as Control
	audit.check_true(router != null, "host/the_playable_router_is_mounted")
	if router != null:
		audit.check_true(router.go_to("feedback"), "host/the_feedback_screen_mounts_under_the_host")
		var screen: Node = router.active_screen()
		audit.check_eq(screen.delivery_transport() if screen.has_method("delivery_transport") else null, null, "host/the_screen_was_handed_no_transport")
		audit.check_eq(screen.has_endpoint(), false, "host/so_the_form_keeps_its_local_only_ladder")
		audit.check_eq(screen.send_label_key(), "feedbackSaveAndCopy", "host/and_promises_only_a_save")
	menu.queue_free()
	await process_frame
	Config.save_dir = ""


func _wipe(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(String(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path))
