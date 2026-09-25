## feedback_delivery_test.gd — the transport's own states, and its real socket.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##       --script res://tests/feedback/feedback_delivery_test.gd
##
## WHAT IT GATES, and why each one is a state a player can end up in:
##
##   1. THE GUARDS: nothing is sent with no endpoint, and a run that finds an empty
##      queue does not start one. Both refuse *before* a request exists
##      (`request_count()` is the check, not the return value).
##   2. QUEUE FIRST: the entry is on disk, still unsent, at the instant the request goes
##      out — the read happens inside the transport's own call, not asserted from source.
##   3. ONE ENTRY PER REQUEST, IN ORDER, ONCE: three queued messages make three POSTs of
##      exactly one entry each, in the store's own order, with no id repeated.
##   4. A RECEIPT IS THE ONLY THING THAT MARKS: the handler's own
##      `{ok: true, received: 1}` marks that exact id `sent` on disk and moves on. A
##      malformed 200, a 200 that claims the wrong count, an HTTP failure, a timeout and
##      a dead socket each stop the run and leave every unconfirmed entry pending.
##   5. ONE RUN AT A TIME: a submit and a second boot retry arriving while a run is in
##      flight are refused, the request count does not move, and the running pass still
##      delivers the newer entry — no duplicate POST of the same message.
##   6. THE BOOT RETRY IS ONCE: the launch retry sends the pending queue, and the next
##      call is refused without a request.
##   7. A CANCELLED RUN CLAIMS NOTHING: a reply that arrives after `cancel_run()` is
##      discarded instead of marking an entry the run no longer owns.
##
## NOTHING HERE REACHES THE REAL ENDPOINT. The states are driven through the transport's
## own poster seam, and the HTTP mapping is proved against a loopback stub this file
## starts on 127.0.0.1. The endpoint the game ships is never contacted.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Delivery := preload("res://src/feedback/feedback_delivery.gd")
const SaveStore := preload("res://src/save/save_store.gd")

const TEMP_DIR := "user://feedback-delivery-test"
## A test address, not the shipped one: no test may ever post a real message.
const TEST_ENDPOINT := "https://example.invalid/feedback-delivery-test"
const STUB_PORT := 18791
const CLOSED_PORT := 18792
const STUB_FRAMES := 240
const SETTLE_FRAMES := 3
## The transport's wait for the timeout case only; the shipped value is 12 s.
const TEST_TIMEOUT := 0.4


## A transport that answers when the test says so, through exactly the service's own
## callback shape (`feedback_delivery.gd::set_poster`).
class FakePoster extends RefCounted:
	var calls: Array = []
	var callbacks: Array = []
	var cancelled := 0

	func post(url: String, body: String, timeout_ms: int, on_done: Callable) -> void:
		calls.append({"url": url, "body": body, "timeout_ms": timeout_ms})
		callbacks.append(on_done)

	func cancel() -> void:
		cancelled += 1

	func deliver(index: int, reply: Dictionary) -> void:
		if index < callbacks.size():
			callbacks[index].call(reply)

	## The body of the n-th request, parsed: what the transport actually put on the wire.
	func body_of(index: int) -> Dictionary:
		var parsed: Variant = JSON.parse_string(String((calls[index] as Dictionary).get("body", "")))
		return parsed if parsed is Dictionary else {}

	## The single entry of the n-th request, or `{}` when the request carried none or many.
	func entry_of(index: int) -> Dictionary:
		var entries: Variant = body_of(index).get("entries", null)
		if not (entries is Array) or (entries as Array).size() != 1:
			return {}
		return (entries as Array)[0] if (entries as Array)[0] is Dictionary else {}


var _store: RefCounted
var _delivery: Node


func _initialize() -> void:
	var audit := AuditBase.new("feedback_delivery")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "FeedbackDeliveryTestFrame"
	root.add_child(frame)
	_delivery = Delivery.new()
	_delivery.name = "FeedbackDelivery"
	frame.add_child(_delivery)
	_delivery.call("set_store_provider", Callable(self, "_store_provider"))
	_delivery.call("set_endpoint", TEST_ENDPOINT)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _guards(audit)
	await _queue_first(audit)
	await _one_by_one(audit)
	await _busy(audit)
	await _boot_retry(audit)
	await _cancel(audit)
	await _storage_failure(audit)
	await _duplicate_ids(audit)
	await _sockets(audit)
	audit.report("temp store: %s — the real user:// profile was never written" % TEMP_DIR)


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

func _store_provider() -> RefCounted:
	return _store


func _seed(entries: Array) -> void:
	_store.write_feedback(entries)


func _entry(id: String, message: String, sent := false) -> Dictionary:
	return {
		"id": id,
		"ts": "2026-01-01T00:00:00Z",
		"topic": "bug",
		"message": message,
		"contact": "",
		"diagnostics": null,
		"sent": sent,
	}


## The ids still unsent on disk, in the store's own order.
func _pending_ids() -> Array:
	var out: Array = []
	for entry in _store.read_group("feedback").get("payload", []):
		if entry is Dictionary and not bool((entry as Dictionary).get("sent", false)):
			out.append(String((entry as Dictionary).get("id", "")))
	return out


func _sent_ids() -> Array:
	var out: Array = []
	for entry in _store.read_group("feedback").get("payload", []):
		if entry is Dictionary and bool((entry as Dictionary).get("sent", false)):
			out.append(String((entry as Dictionary).get("id", "")))
	return out


func _fresh() -> void:
	_seed([])
	_delivery.call("set_poster", null)
	_delivery.call("set_timeout_seconds", Delivery.TIMEOUT_SECONDS)


# ---------------------------------------------------------------------------
# 1. The guards
# ---------------------------------------------------------------------------

func _guards(audit: AuditBase) -> void:
	_fresh()
	_delivery.call("set_endpoint", TEST_ENDPOINT)
	var empty: Dictionary = _delivery.call("submit_pending")
	audit.check_eq(empty.get("started", true), false, "delivery/an_empty_queue_starts_no_run")
	audit.check_eq(String(empty.get("reason", "")), "empty", "delivery/and_says_the_queue_is_empty")
	audit.check_eq(_delivery.call("request_count"), 0, "delivery/an_empty_queue_sends_nothing")

	_seed([_entry("fb-guard", "guard")])
	_delivery.call("set_endpoint", "")
	audit.check_eq(_delivery.call("has_endpoint"), false, "delivery/with_no_endpoint_there_is_nowhere_to_post")
	var nowhere: Dictionary = _delivery.call("submit_pending")
	audit.check_eq(String(nowhere.get("reason", "")), "no-endpoint", "delivery/no_endpoint_is_named")
	audit.check_eq(_delivery.call("request_count"), 0, "delivery/no_endpoint_sends_nothing")
	audit.check_eq(_pending_ids(), ["fb-guard"], "delivery/the_entry_is_still_pending")
	_delivery.call("set_endpoint", TEST_ENDPOINT)


# ---------------------------------------------------------------------------
# 2. The queue is written before the request leaves
# ---------------------------------------------------------------------------

func _queue_first(audit: AuditBase) -> void:
	_fresh()
	_seed([_entry("fb-first", "first")])
	var poster := FakePoster.new()
	_delivery.call("set_poster", poster)
	# What the store held at the instant the POST was handed to the transport.
	var seen: Array = []
	var started: Dictionary = _delivery.call("submit_pending")
	seen = _pending_ids()
	audit.check_eq(started.get("started", false), true, "delivery/a_queued_entry_starts_a_run")
	audit.check_eq(started.get("count", 0), 1, "delivery/the_run_reports_what_it_owes")
	audit.check_eq(poster.calls.size(), 1, "delivery/one_request_is_in_flight")
	audit.check_eq(seen, ["fb-first"], "delivery/the_request_went_out_with_the_entry_already_stored_and_unsent")
	var entry := poster.entry_of(0)
	audit.check_eq(String(entry.get("id", "")), "fb-first", "delivery/the_wire_entry_is_the_stored_one")
	audit.check_eq(String(entry.get("message", "")), "first", "delivery/the_wire_entry_carries_the_message")
	audit.check_eq(String(entry.get("ts", "")), "2026-01-01T00:00:00Z", "delivery/the_wire_entry_carries_the_timestamp")
	audit.check_eq(entry.has("sent"), true, "delivery/the_wire_entry_keeps_the_schema_field")
	var parsed: Variant = JSON.parse_string(String((poster.calls[0] as Dictionary).get("body", "")))
	audit.check_true(parsed is Dictionary and (parsed as Dictionary).has("entries"), "delivery/the_body_is_the_handlers_own_envelope")
	audit.check_eq(String((poster.calls[0] as Dictionary).get("url", "")), TEST_ENDPOINT, "delivery/the_request_used_the_configured_endpoint")
	audit.check_eq(int((poster.calls[0] as Dictionary).get("timeout_ms", 0)), int(Delivery.TIMEOUT_SECONDS * 1000.0), "delivery/the_request_carries_the_bounded_wait")
	poster.deliver(0, {"ok": true})
	audit.check_eq(_sent_ids(), ["fb-first"], "delivery/a_receipt_marks_that_exact_id_sent_on_disk")
	audit.check_eq(_delivery.call("running"), false, "delivery/the_run_ends_when_the_queue_is_drained")


# ---------------------------------------------------------------------------
# 3. One entry per request, in order, once
# ---------------------------------------------------------------------------

func _one_by_one(audit: AuditBase) -> void:
	_fresh()
	var before := int(_delivery.call("request_count"))
	# The store's own order: newest first (`queue_feedback` unshifts).
	_seed([_entry("fb-c", "third"), _entry("fb-b", "second"), _entry("fb-a", "first")])
	var poster := FakePoster.new()
	_delivery.call("set_poster", poster)
	var done: Array = []
	var recorder := func(summary: Dictionary) -> void:
		done.append(summary)
	var started: Dictionary = _delivery.call("submit_pending", Callable(recorder))
	audit.check_eq(started.get("count", 0), 3, "delivery/three_pending_entries_are_owed")
	audit.check_eq(poster.calls.size(), 1, "delivery/only_one_request_is_in_flight_at_a_time")
	for index in 3:
		audit.check_eq(String(poster.entry_of(index).get("id", "")), ["fb-c", "fb-b", "fb-a"][index], "delivery/request_%d_carries_one_entry_in_store_order" % index)
		var entries: Variant = poster.body_of(index).get("entries", null)
		var count := (entries as Array).size() if entries is Array else -1
		audit.check_eq(count, 1, "delivery/request_%d_is_exactly_one_entry" % index)
		poster.deliver(index, {"ok": true})
	audit.check_eq(poster.calls.size(), 3, "delivery/three_entries_make_three_posts")
	audit.check_eq(_sent_ids().size(), 3, "delivery/every_confirmed_entry_is_marked_sent")
	audit.check_eq(_pending_ids().size(), 0, "delivery/nothing_is_left_pending")
	audit.check_eq(_delivery.call("last_reason"), "", "delivery/a_stored_run_names_no_failure")
	audit.check_eq(int(_delivery.call("request_count")) - before, 3, "delivery/the_count_matches_the_posts")
	audit.check_eq(done.size(), 1, "delivery/the_run_reports_once")
	var summary: Dictionary = done[0] if not done.is_empty() else {}
	audit.check_eq(summary.get("ok", false), true, "delivery/a_drained_queue_is_ok")
	audit.check_eq(String(summary.get("reason", "")), "", "delivery/a_drained_queue_names_no_reason")
	var sent: Array = summary.get("sent", []) if summary.get("sent", null) is Array else []
	audit.check_eq(sent, ["fb-c", "fb-b", "fb-a"], "delivery/the_summary_names_what_was_confirmed")
	audit.check_eq(sent.size(), _unique(sent).size(), "delivery/no_message_is_posted_twice")


func _unique(values: Array) -> Array:
	var out: Array = []
	for value in values:
		if not out.has(value):
			out.append(value)
	return out


# ---------------------------------------------------------------------------
# 4. One run at a time
# ---------------------------------------------------------------------------

func _busy(audit: AuditBase) -> void:
	_fresh()
	var before := int(_delivery.call("request_count"))
	_seed([_entry("fb-one", "one")])
	var poster := FakePoster.new()
	_delivery.call("set_poster", poster)
	_delivery.call("submit_pending")
	audit.check_eq(_delivery.call("running"), true, "delivery/a_run_is_in_flight")
	# The player queues a second message and presses send while the first is going out.
	var list: Array = _store.read_group("feedback").get("payload", [])
	list.push_front(_entry("fb-two", "two"))
	_store.write_feedback(list)
	var second: Dictionary = _delivery.call("submit_pending")
	audit.check_eq(second.get("started", true), false, "delivery/a_second_submit_mid_run_is_refused")
	audit.check_eq(String(second.get("reason", "")), "busy", "delivery/the_refusal_names_the_running_pass")
	audit.check_eq(int(_delivery.call("request_count")) - before, 1, "delivery/the_refused_submit_sends_nothing")
	# The running pass re-reads the store, so the newer entry is not stranded.
	poster.deliver(0, {"ok": true})
	audit.check_eq(poster.calls.size(), 2, "delivery/the_running_pass_picks_up_the_newer_entry")
	audit.check_eq(String(poster.entry_of(1).get("id", "")), "fb-two", "delivery/and_that_entry_is_the_new_one")
	poster.deliver(1, {"ok": true})
	audit.check_eq(int(_delivery.call("request_count")) - before, 2, "delivery/each_message_was_posted_exactly_once")
	audit.check_eq(_pending_ids().size(), 0, "delivery/both_entries_are_confirmed")


# ---------------------------------------------------------------------------
# 5. The boot retry is one attempt
# ---------------------------------------------------------------------------

func _boot_retry(audit: AuditBase) -> void:
	_fresh()
	var before := int(_delivery.call("request_count"))
	_seed([_entry("fb-boot", "boot")])
	var poster := FakePoster.new()
	_delivery.call("set_poster", poster)
	var first: Dictionary = _delivery.call("boot_retry")
	audit.check_eq(first.get("started", false), true, "delivery/the_launch_retry_sends_the_pending_queue")
	audit.check_eq(int(_delivery.call("request_count")) - before, 1, "delivery/the_launch_retry_made_one_request")
	poster.deliver(0, {"ok": true})
	audit.check_eq(_sent_ids(), ["fb-boot"], "delivery/the_launch_retry_confirmed_the_entry")
	# A second launch retry in the same process: refused, and no request.
	var list: Array = _store.read_group("feedback").get("payload", [])
	list.push_front(_entry("fb-after", "after"))
	_store.write_feedback(list)
	var again: Dictionary = _delivery.call("boot_retry")
	audit.check_eq(again.get("started", true), false, "delivery/the_second_launch_retry_is_refused")
	audit.check_eq(int(_delivery.call("request_count")) - before, 1, "delivery/the_refused_retry_sends_nothing")
	audit.check_eq(_pending_ids(), ["fb-after"], "delivery/the_later_entry_waits_for_the_next_launch")


# ---------------------------------------------------------------------------
# 6. A cancelled run claims nothing
# ---------------------------------------------------------------------------

func _cancel(audit: AuditBase) -> void:
	_fresh()
	_seed([_entry("fb-cancel", "cancel")])
	var poster := FakePoster.new()
	_delivery.call("set_poster", poster)
	_delivery.call("submit_pending")
	_delivery.call("cancel_run")
	audit.check_eq(poster.cancelled, 1, "delivery/the_cancel_reached_the_transport")
	audit.check_eq(_delivery.call("running"), false, "delivery/the_run_no_longer_owns_the_reply")
	poster.deliver(0, {"ok": true})
	audit.check_eq(_sent_ids().size(), 0, "delivery/a_late_reply_marks_nothing")
	audit.check_eq(_pending_ids(), ["fb-cancel"], "delivery/the_entry_is_still_pending")


# ---------------------------------------------------------------------------
# 7. A receipt that cannot be recorded
# ---------------------------------------------------------------------------

## The store's own failure hook (`save_store.gd::fail_before_rename`): the file is not
## committed. The receipt was real, but a run that kept going would re-read the same entry
## as pending and post it a second time, so it has to stop and say why.
func _storage_failure(audit: AuditBase) -> void:
	_fresh()
	_seed([_entry("fb-store", "store"), _entry("fb-store-2", "store-2")])
	var poster := FakePoster.new()
	_delivery.call("set_poster", poster)
	_delivery.call("submit_pending")
	audit.check_eq(poster.calls.size(), 1, "delivery/the_first_entry_went_out")
	_store.fail_before_rename = true
	poster.deliver(0, {"ok": true})
	_store.fail_before_rename = false
	audit.check_eq(poster.calls.size(), 1, "delivery/a_failed_write_stops_the_run_before_the_next_post")
	audit.check_eq(String(_delivery.call("last_reason")), "storage", "delivery/a_failed_write_names_the_storage_failure")
	audit.check_eq(_delivery.call("running"), false, "delivery/a_failed_write_ends_the_run")
	audit.check_eq(_sent_ids().size(), 0, "delivery/nothing_is_claimed_as_sent_when_the_write_failed")
	audit.check_eq(_pending_ids(), ["fb-store", "fb-store-2"], "delivery/both_entries_are_still_pending")
	var sent: Array = _delivery.call("sent_ids")
	audit.check_eq(sent.size(), 0, "delivery/the_run_reports_nothing_confirmed")

	# A later run writes them for real: the failure is not sticky.
	var retry := FakePoster.new()
	_delivery.call("set_poster", retry)
	_delivery.call("submit_pending")
	for index in 2:
		retry.deliver(index, {"ok": true})
	audit.check_eq(retry.calls.size(), 2, "delivery/the_next_run_posts_both_entries")
	audit.check_eq(_sent_ids().size(), 2, "delivery/and_records_both_confirmed")
	audit.check_eq(_pending_ids().size(), 0, "delivery/with_nothing_left_pending")


# ---------------------------------------------------------------------------
# 8. One id, two queue rows
# ---------------------------------------------------------------------------

## `fb-` ids are millisecond-shaped (`FeedbackScreen.gd::entry_id`), so two entries can
## carry the same one. A receipt belongs to exactly one of them: marking both would clear
## a message that was never delivered.
func _duplicate_ids(audit: AuditBase) -> void:
	_fresh()
	_seed([_entry("fb-twin", "second"), _entry("fb-twin", "first")])
	var poster := FakePoster.new()
	_delivery.call("set_poster", poster)
	_delivery.call("submit_pending")
	audit.check_eq(poster.calls.size(), 1, "delivery/one_request_is_in_flight")
	poster.deliver(0, {"ok": true})
	audit.check_eq(_sent_ids().size(), 1, "delivery/one_receipt_marks_one_entry_even_when_the_id_repeats")
	audit.check_eq(_sent_ids(), ["fb-twin"], "delivery/and_the_id_it_marked_is_the_one_delivered")
	audit.check_eq(_pending_ids().size(), 1, "delivery/the_other_copy_is_still_pending")
	audit.check_eq(poster.calls.size(), 2, "delivery/so_the_run_posts_the_second_copy_too")
	poster.deliver(1, {"ok": true})
	audit.check_eq(_sent_ids().size(), 2, "delivery/the_second_copy_is_confirmed_by_its_own_receipt")
	audit.check_eq(_pending_ids().size(), 0, "delivery/both_copies_end_confirmed")
	audit.check_eq(poster.calls.size(), 2, "delivery/two_copies_two_posts")


# ---------------------------------------------------------------------------
# 9. The real path: the engine's own HTTPRequest, against a loopback stub
# ---------------------------------------------------------------------------

func _request_complete(request: String) -> bool:
	var at := request.find("\r\n\r\n")
	if at < 0:
		return false
	var head := request.substr(0, at)
	var length := 0
	for line in head.split("\r\n"):
		if String(line).to_lower().begins_with("content-length:"):
			length = int(String(line).substr(15).strip_edges())
	return request.substr(at + 4).length() >= length


func _http_response(code: int, phrase: String, body: String) -> String:
	return "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [code, phrase, body.to_utf8_buffer().size(), body]


## Serves exactly one connection with the canned raw reply and returns the raw request.
## A `reply` of `""` holds the connection open without answering (the timeout case).
##
## The waits are wall-clock, not frame counts: a headless `SceneTree` runs frames as fast
## as it can, so a frame budget would race the client's own timer instead of measuring it.
func _serve_once(server: TCPServer, reply: String) -> String:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if server.is_connection_available():
			var peer := server.take_connection()
			var request := ""
			while Time.get_ticks_msec() < deadline and not _request_complete(request):
				peer.poll()
				var available := peer.get_available_bytes()
				if available > 0:
					request += peer.get_utf8_string(available)
				await process_frame
			if reply != "":
				peer.put_data(reply.to_utf8_buffer())
				peer.poll()
				peer.disconnect_from_host()
			else:
				# Hold the socket open and silent past the client's own wait: the run has
				# to end on its timer, not on a disconnect this stub chose.
				await create_timer(TEST_TIMEOUT * 3.0).timeout
				peer.poll()
				peer.disconnect_from_host()
			return request
		await process_frame
	return ""


func _await_idle() -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if not bool(_delivery.call("running")):
			return
		await process_frame


## One real request against the stub, with the queue reset to a single entry.
func _socket_case(audit: AuditBase, server: TCPServer, reply: String, id: String, label: String) -> String:
	_fresh()
	_delivery.call("set_timeout_seconds", TEST_TIMEOUT)
	_seed([_entry(id, "socket")])
	var port := server.get_local_port()
	_delivery.call("set_endpoint", "http://127.0.0.1:%d/api/feedback" % port)
	_delivery.call("submit_pending")
	var request := await _serve_once(server, reply)
	await _await_idle()
	audit.check_true(request.contains("POST /api/feedback"), "delivery/%s_used_a_real_post" % label)
	audit.check_true(request.contains("Content-Type: application/json"), "delivery/%s_carried_the_json_content_type" % label)
	return request


func _sockets(audit: AuditBase) -> void:
	var server := TCPServer.new()
	audit.check_eq(server.listen(STUB_PORT, "127.0.0.1"), OK, "delivery/the_stub_listens_on_loopback")
	_delivery.call("set_timeout_seconds", TEST_TIMEOUT)

	# A receipt: the handler's own shape (`api/feedback.js:180`).
	var request := await _socket_case(audit, server, _http_response(200, "OK", "{\"ok\":true,\"received\":1}"), "fb-net-ok", "a_receipt")
	audit.check_true(request.contains("\"entries\":[{"), "delivery/the_real_body_carried_the_envelope")
	audit.check_eq(_sent_ids(), ["fb-net-ok"], "delivery/a_real_receipt_marks_the_entry_sent")
	audit.check_eq(String(_delivery.call("last_reason")), "", "delivery/a_real_receipt_names_no_failure")

	# A 200 that is not a receipt: not JSON, then JSON with no receipt in it.
	await _socket_case(audit, server, _http_response(200, "OK", "not json at all"), "fb-net-junk", "a_malformed_body")
	audit.check_eq(String(_delivery.call("last_reason")), "unconfirmed", "delivery/a_malformed_200_is_unconfirmed")
	audit.check_eq(_pending_ids(), ["fb-net-junk"], "delivery/a_malformed_200_leaves_the_entry_pending")

	await _socket_case(audit, server, _http_response(200, "OK", "{}"), "fb-net-empty", "an_empty_object")
	audit.check_eq(_pending_ids(), ["fb-net-empty"], "delivery/a_200_without_a_receipt_leaves_the_entry_pending")

	# A 200 that claims a different count than the one entry this request asked about.
	await _socket_case(audit, server, _http_response(200, "OK", "{\"ok\":true,\"received\":2}"), "fb-net-count", "a_wrong_count")
	audit.check_eq(_pending_ids(), ["fb-net-count"], "delivery/a_receipt_for_another_count_is_not_this_entrys")

	# The handler's own refusals (`api/feedback.js:173-177`).
	await _socket_case(audit, server, _http_response(503, "Service Unavailable", "{\"error\":\"not-configured\"}"), "fb-net-503", "a_refusal")
	audit.check_eq(String(_delivery.call("last_reason")), "rejected", "delivery/an_http_failure_is_a_refusal")
	audit.check_eq(_pending_ids(), ["fb-net-503"], "delivery/an_http_failure_leaves_the_entry_pending")

	await _socket_case(audit, server, _http_response(502, "Bad Gateway", "{\"error\":\"delivery-failed\"}"), "fb-net-502", "a_delivery_error")
	audit.check_eq(String(_delivery.call("last_reason")), "rejected", "delivery/a_gateway_failure_is_a_refusal")

	# A socket that speaks and then says nothing: the bounded wait has to end the run.
	await _socket_case(audit, server, "", "fb-net-timeout", "a_silent_socket")
	audit.note("the silent socket's own detail: %s" % String(_delivery.call("last_detail")))
	audit.check_eq(String(_delivery.call("last_reason")), "timeout", "delivery/a_silent_endpoint_times_out")
	audit.check_eq(_pending_ids(), ["fb-net-timeout"], "delivery/a_timeout_leaves_the_entry_pending")

	server.stop()

	# No socket at all: the request cannot connect, and that is offline, not a receipt.
	_fresh()
	_seed([_entry("fb-net-offline", "offline")])
	_delivery.call("set_endpoint", "http://127.0.0.1:%d/api/feedback" % _closed_port())
	_delivery.call("submit_pending")
	await _await_idle()
	audit.check_eq(String(_delivery.call("last_reason")), "offline", "delivery/a_closed_port_is_offline")
	audit.check_eq(_pending_ids(), ["fb-net-offline"], "delivery/an_offline_attempt_leaves_the_entry_pending")
	audit.note("every socket in this section is 127.0.0.1: the shipped endpoint is never contacted")


## A port nothing is listening on: bound, read, then released.
func _closed_port() -> int:
	var probe := TCPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		return CLOSED_PORT
	var port := probe.get_local_port()
	probe.stop()
	return port


func _wipe() -> void:
	var dir := DirAccess.open(TEMP_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(String(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))
