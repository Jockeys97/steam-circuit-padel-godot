## coach_client_test.gd — the client's own states, and its real socket.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##       --script res://tests/coach_client_test.gd
##
## WHAT IT GATES:
##   1. THE ADDRESS IS THE CONTRACT'S: loopback, the declared path, and the declared
##      environment variable — with the contract's default when it says nothing usable.
##   2. THE REQUEST BODY IS BOUNDED: the wire version, the allowlisted counters and the
##      candidate list, and nothing else — no sentence, no mode, no score.
##   3. NOTHING RUNS ON ITS OWN: a match without enough measured counters answers from the
##      snapshot and sends nothing at all (`request_count()` stays 0).
##   4. ONE REQUEST AT A TIME: a second press while one is in flight is refused, and the
##      count does not move.
##   5. A STALE REPLY CANNOT PAINT: after `cancel()` — what the screen's exit calls — the
##      first request's own callback arriving late leaves the record exactly as it was.
##   6. EVERY TRANSPORT OUTCOME BECOMES A TRUTHFUL STATE, driven through the client's test
##      seam: a 200 with a Choice is advice or uncertainty by the gate, a timeout, a closed
##      socket, an oversized answer and an invalid answer are the refusals they say they
##      are.
##   7. THE REAL PATH WORKS: the engine's own `HTTPRequest` against a loopback stub server
##      this file starts — a canned Choice comes back as an advice — and with NO server on
##      the port the client reports unavailable instead of inventing an analysis.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const Advice := preload("res://src/coach/coach_advice.gd")
const AuditBase := preload("res://src/audits/audit_base.gd")
const Client := preload("res://src/coach/coach_client.gd")
const CoachText := preload("res://src/coach/coach_text.gd")
const Contract := preload("res://src/coach/coach_contract.gd")

## The port a test binds its stub on; the client reads it from the contract's own
## environment variable.
const PORT_ENV := "COACH_PORT"
const STUB_PORT := 18787
const CLOSED_PORT := 18788
const STUB_FRAMES := 240

## A transport that answers when the test says so, through exactly the client's own
## callback shape — the seam `coach_client.gd::set_poster` documents.
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


var _records: Array = []


func _initialize() -> void:
	var audit := AuditBase.new("coach_client")
	OS.set_environment(PORT_ENV, str(STUB_PORT))
	await _address(audit)
	await _seam(audit)
	await _sockets(audit)
	OS.set_environment(PORT_ENV, "")
	quit(audit.finish())


func _stats(overrides: Dictionary = {}) -> Dictionary:
	var out := {
		"pointsWon": {"player": 11, "ai": 7},
		"aces": {"player": 2, "ai": 1},
		"winners": {"player": 5, "ai": 3},
		"errors": {"player": 4, "ai": 6},
		"doubleFaults": {"player": 3, "ai": 1},
		"smashWinners": {"player": 1, "ai": 0},
		"rallyCount": 9,
		"totalRallyHits": 32,
		"longestRally": 7,
	}
	for key in overrides.keys():
		out[key] = overrides[key]
	return out


func _result(overrides: Dictionary = {}) -> Dictionary:
	return {"stats": _stats(overrides)}


## A client in the tree, with its records collected.
func _client(audit: AuditBase) -> Node:
	var client := Client.new()
	client.name = "CoachClientUnderTest"
	root.add_child(client)
	_records.clear()
	client.analysis_ready.connect(func(record: Dictionary) -> void: _records.append(record))
	return client


# ---------------------------------------------------------------------------
# 1. The address
# ---------------------------------------------------------------------------

func _address(audit: AuditBase) -> void:
	var client := _client(audit)
	var declared_path := String(Contract.wire().get("path", ""))
	var default_port := int(Contract.wire().get("defaultPort", 0))
	audit.check_eq(client.url(), "http://127.0.0.1:%d%s" % [STUB_PORT, declared_path], "client/the_url_is_loopback_and_the_contracts_own_path")
	audit.check_eq(client.port(), STUB_PORT, "client/the_port_comes_from_the_environment")
	OS.set_environment(PORT_ENV, "not-a-port")
	audit.check_eq(client.port(), default_port, "client/a_nonsense_port_falls_back_to_the_contract")
	OS.set_environment(PORT_ENV, "80")
	audit.check_eq(client.port(), default_port, "client/an_out_of_range_port_falls_back_to_the_contract")
	OS.set_environment(PORT_ENV, "")
	audit.check_eq(client.port(), default_port, "client/an_empty_environment_falls_back_to_the_contract")
	OS.set_environment(PORT_ENV, str(STUB_PORT))
	var upstream_ms := float(Contract.upstream().get("timeoutMs", 8000))
	audit.check_eq(client.timeout_seconds(), upstream_ms / 1000.0 + Client.TIMEOUT_MARGIN_SECONDS, "client/the_bound_is_the_upstreams_plus_one_margin")
	audit.check_eq(client.request_count(), 0, "client/a_mounted_client_has_asked_nothing")
	client.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 2. The seam: what is sent, when it is sent, and what a reply becomes
# ---------------------------------------------------------------------------

func _seam(audit: AuditBase) -> void:
	var poster := FakePoster.new()
	var client := _client(audit)
	client.set_poster(poster)

	var thin: Dictionary = client.snapshot_of(_result({"pointsWon": {"player": 1, "ai": 2}}))
	audit.check_eq(bool(thin.get("sufficient", true)), false, "client/a_match_without_enough_counters_is_not_askable")
	audit.check_eq(client.analyze(thin), false, "client/and_no_request_is_sent")
	audit.check_eq(client.request_count(), 0, "client/the_bridge_was_not_called_at_all")
	audit.check_eq(poster.calls.size(), 0, "client/the_poster_was_not_asked")
	audit.check_eq(String(_last_record().get("state", "")), Advice.STATE_INSUFFICIENT, "client/and_the_record_says_so")
	client.queue_free()
	await process_frame

	poster = FakePoster.new()
	client = _client(audit)
	client.set_poster(poster)
	var snapshot: Dictionary = client.snapshot_of(_result())
	audit.check_eq(snapshot.get("candidates", []).size() > 1, true, "client/a_measured_match_offers_more_than_one_option")
	audit.check_true(client.analyze(snapshot), "client/an_explicit_press_sends_one_request")
	audit.check_eq(client.request_count(), 1, "client/and_counts_exactly_one")
	audit.check_eq(poster.calls.size(), 1, "client/the_poster_was_asked_once")

	var sent := String((poster.calls[0] as Dictionary).get("body", ""))
	var parsed: Variant = JSON.parse_string(sent)
	audit.check_eq(parsed is Dictionary, true, "client/the_body_is_json")
	var keys: Array = (parsed as Dictionary).keys()
	keys.sort()
	audit.check_eq(keys, ["candidates", "stats", "version"], "client/the_body_carries_only_the_declared_fields")
	audit.check_eq(int((parsed as Dictionary).get("version", 0)), Contract.WIRE_VERSION, "client/the_body_carries_the_wire_version")
	var stats_sent: Dictionary = (parsed as Dictionary).get("stats", {})
	audit.check_eq(stats_sent.keys().size(), Contract.group_names().size() + Contract.counter_names().size(), "client/the_body_carries_the_counter_allowlist_and_nothing_more")
	audit.check_eq(int((stats_sent.get("pointsWon", {}) as Dictionary).get("player", -1)), 11, "client/the_body_carries_the_measured_points")
	audit.check_true(not sent.contains("coachAdvice"), "client/no_sentence_leaves_the_machine")
	audit.check_eq(String((poster.calls[0] as Dictionary).get("url", "")), client.url(), "client/the_poster_got_the_clients_own_address")

	audit.check_eq(client.analyze(snapshot), false, "client/a_press_while_one_is_in_flight_is_refused")
	audit.check_eq(client.request_count(), 1, "client/and_sends_nothing_else")
	audit.check_eq(poster.calls.size(), 1, "client/and_asks_the_poster_nothing_else")

	poster.deliver(0, _reply_for(snapshot.get("candidates", []), "serve_accuracy", 0.8))
	await process_frame
	audit.check_eq(String(_last_record().get("state", "")), Advice.STATE_ADVICE, "client/a_confident_answer_arrives_as_advice")
	audit.check_eq(String(_last_record().get("drill_id", "")), "serve", "client/and_carries_the_exercise")
	audit.check_eq(client.pending(), false, "client/the_client_is_idle_again")

	# The gate, through the same seam: the same answer, less certainty.
	var weak_poster := FakePoster.new()
	var weak_client := _client(audit)
	weak_client.set_poster(weak_poster)
	var weak_snapshot: Dictionary = weak_client.snapshot_of(_result())
	weak_client.analyze(weak_snapshot)
	weak_poster.deliver(0, _reply_for(weak_snapshot.get("candidates", []), "serve_accuracy", 0.3))
	await process_frame
	audit.check_eq(String(_last_record().get("state", "")), Advice.STATE_UNCERTAIN, "client/an_answer_under_the_gate_arrives_as_uncertain")
	audit.check_eq(String(_last_record().get("drill_id", "")), "", "client/and_offers_no_exercise")
	weak_client.queue_free()
	await process_frame

	# Every transport outcome, one by one.
	for entry in [
		["timeout", Advice.STATE_UNAVAILABLE, ""],
		["unreachable", Advice.STATE_UNAVAILABLE, ""],
		["error", Advice.STATE_UNAVAILABLE, ""],
		["too_large", Advice.STATE_UNAVAILABLE, ""],
		["invalid", Advice.STATE_INVALID, ""],
		["upper", Advice.STATE_INVALID, "1.4"],
		["unoffered", Advice.STATE_INVALID, "win_more"],
	]:
		var status := String(entry[0])
		var transport := FakePoster.new()
		var one := _client(audit)
		one.set_poster(transport)
		var source: Dictionary = one.snapshot_of(_result())
		one.analyze(source)
		var reply: Dictionary = {}
		if status == "upper" or status == "unoffered":
			reply = _reply_for(source.get("candidates", []), "serve_accuracy", float(entry[2]) if status == "upper" else 0.8)
			if status == "unoffered":
				(reply["body"] as Dictionary)["choice"] = "win_more"
		else:
			reply = {"status": status}
		transport.deliver(0, reply)
		await process_frame
		audit.check_eq(String(_last_record().get("state", "")), String(entry[1]), "client/a_%s_transport_is_%s" % [status, String(entry[1])])
		audit.check_eq(String(_last_record().get("advice_id", "")), "", "client/a_%s_transport_claims_nothing" % status)
		audit.check_eq(one.pending(), false, "client/a_%s_transport_leaves_the_client_idle" % status)
		one.queue_free()
		await process_frame

	# The stale reply: the answer to a screen the player already left.
	var stale_poster := FakePoster.new()
	var stale_client := _client(audit)
	stale_client.set_poster(stale_poster)
	var stale_snapshot: Dictionary = stale_client.snapshot_of(_result())
	stale_client.analyze(stale_snapshot)
	audit.check_true(stale_client.pending(), "client/a_request_is_in_flight_before_the_exit")
	stale_client.cancel()
	audit.check_eq(stale_poster.cancelled, 1, "client/the_exit_cancelled_the_transport")
	audit.check_eq(stale_client.pending(), false, "client/and_the_client_is_no_longer_waiting")
	var records_before := _records.size()
	stale_poster.deliver(0, _reply_for(stale_client.snapshot().get("candidates", []), "serve_accuracy", 0.8))
	await process_frame
	audit.check_eq(_records.size(), records_before, "client/a_late_reply_paints_nothing")
	audit.check_eq(stale_client.record().is_empty(), true, "client/and_leaves_no_record_behind")
	# A new press after the exit is a new generation, not a revival of the old one.
	audit.check_true(stale_client.analyze(stale_snapshot), "client/a_press_after_the_exit_is_a_fresh_request")
	audit.check_eq(stale_client.request_count(), 2, "client/and_is_counted_as_its_own")
	stale_poster.deliver(1, _reply_for(stale_client.snapshot().get("candidates", []), "rally_consistency", 0.8))
	await process_frame
	audit.check_eq(String(_last_record().get("state", "")), Advice.STATE_ADVICE, "client/the_fresh_request_still_works")
	audit.check_eq(String(_last_record().get("drill_id", "")), "rally", "client/and_carries_its_own_exercise")
	stale_client.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 3. The real path: the engine's own HTTPRequest, against a loopback stub
# ---------------------------------------------------------------------------

## The stub's answer, in the shape the BRIDGE sends (its own bounded envelope — not
## TypeSafe's body, which never leaves the bridge): a Choice over exactly what the client
## offered, the serve when it was offered and the first drillable candidate otherwise.
func _stub_answer(offered: Array) -> String:
	var choice := String(offered[0])
	if offered.has("serve_accuracy"):
		choice = "serve_accuracy"
	var rest := (1.0 - 0.8) / float(maxi(offered.size() - 1, 1))
	var probabilities := {}
	for id in offered:
		probabilities[String(id)] = 0.8 if String(id) == choice else rest
	return JSON.stringify({
		"status": "ok",
		"type": "choice",
		"choice": choice,
		"confidence": 0.82,
		"probabilities": probabilities,
	})


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


## A port nothing is listening on: bound, read, then released.
func _closed_port() -> int:
	var probe := TCPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		return CLOSED_PORT
	var port := probe.get_local_port()
	probe.stop()
	return port


func _sockets(audit: AuditBase) -> void:
	var server := TCPServer.new()
	audit.check_eq(server.listen(STUB_PORT, "127.0.0.1"), OK, "client/the_stub_listens_on_loopback")
	var client := _client(audit)
	var snapshot: Dictionary = client.snapshot_of(_result())
	audit.check_true(client.analyze(snapshot), "client/the_real_path_sends_its_request")
	var request := ""
	var answered := false
	for _frame in STUB_FRAMES:
		if server.is_connection_available():
			var peer := server.take_connection()
			for _read in STUB_FRAMES:
				peer.poll()
				var available := peer.get_available_bytes()
				if available > 0:
					request += peer.get_utf8_string(available)
				if _request_complete(request):
					break
				await process_frame
			var body := _stub_answer(client.snapshot().get("candidates", [])).to_utf8_buffer()
			var head := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
			peer.put_data(head.to_utf8_buffer())
			peer.put_data(body)
			peer.poll()
			# A closed connection, not an idle one: `Connection: close` has to mean it, or
			# the client sits waiting for the end of the body it already has.
			peer.disconnect_from_host()
			answered = true
			break
		await process_frame
	for _frame in 60:
		if not client.pending():
			break
		await process_frame
	audit.check_true(answered, "client/the_stub_answered_a_real_request")
	audit.check_true(request.contains("POST %s" % String(Contract.wire().get("path", ""))), "client/the_real_request_used_the_contracts_path")
	audit.check_true(request.contains("\"version\":%d" % Contract.WIRE_VERSION), "client/the_real_request_carried_the_wire_version")
	audit.check_true(request.to_lower().contains("content-type: application/json"), "client/the_real_request_declared_json")
	audit.check_true(not request.to_lower().contains("origin:"), "client/the_real_request_sends_no_origin")
	audit.report("real path: state=%s detail=%s" % [String(_last_record().get("state", "")), client.last_detail()])
	audit.check_eq(String(_last_record().get("state", "")), Advice.STATE_ADVICE, "client/the_real_http_path_comes_back_as_advice")
	audit.check_eq(String(_last_record().get("drill_id", "")), "serve", "client/and_links_the_exercise_the_stub_chose")
	audit.check_eq(client.open_completion_handlers(), 0, "client/a_finished_request_leaves_no_completion_handler")
	# A request cancelled while it is in flight drops its handler too, and cancelling twice is
	# safe: nothing accumulates on the request object across asks.
	audit.check_true(client.analyze(client.snapshot()), "client/a_second_real_request_goes_out")
	audit.check_eq(client.open_completion_handlers(), 1, "client/an_in_flight_request_holds_exactly_one_handler")
	client.cancel()
	audit.check_eq(client.open_completion_handlers(), 0, "client/cancelling_drops_the_handler")
	client.cancel()
	audit.check_eq(client.open_completion_handlers(), 0, "client/cancelling_twice_is_safe")
	client.queue_free()
	server.stop()
	await process_frame

	# No bridge at all: the truthful offline state, not an invented analysis.
	OS.set_environment(PORT_ENV, str(_closed_port()))
	var offline := _client(audit)
	var offline_snapshot: Dictionary = offline.snapshot_of(_result())
	offline.analyze(offline_snapshot)
	for _frame in 180:
		if not offline.pending():
			break
		await process_frame
	audit.check_eq(String(_last_record().get("state", "")), Advice.STATE_UNAVAILABLE, "client/with_no_bridge_listening_the_state_is_unavailable")
	audit.check_eq(String(_last_record().get("advice_id", "")), "", "client/and_nothing_is_claimed")
	audit.check_true(offline.last_detail() != "", "client/and_the_reason_is_kept_for_a_log")
	audit.check_true(CoachText.has("coachUnavailable", "it"), "client/and_the_screen_has_a_sentence_for_it")
	offline.queue_free()
	OS.set_environment(PORT_ENV, str(STUB_PORT))
	await process_frame


func _reply_for(offered: Array, choice: String, confidence: float, peak := 0.8) -> Dictionary:
	var rest := (1.0 - peak) / float(maxi(offered.size() - 1, 1))
	var probabilities := {}
	for id in offered:
		probabilities[String(id)] = peak if String(id) == choice else rest
	return {
		"status": "ok",
		"body": {"type": "choice", "choice": choice, "confidence": confidence, "probabilities": probabilities},
	}


func _last_record() -> Dictionary:
	return _records[_records.size() - 1] if not _records.is_empty() else {}
