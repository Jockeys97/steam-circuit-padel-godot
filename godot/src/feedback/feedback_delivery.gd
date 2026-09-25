## feedback_delivery.gd — the playable build's only way to the feedback endpoint.
##
## WHAT IT TALKS TO. `https://steam-circuit-padel-pro.vercel.app/api/feedback`, the
## endpoint the 2D reference already reads (`js/data.js:79`) and whose handler lives in
## `api/feedback.js`. The Discord webhook is the server's own environment variable and
## never travels here: this client sends JSON and a `Content-Type`, and nothing that
## looks like a secret ever enters it.
##
## ONE ENTRY PER REQUEST, AND ONLY A CONFIRMED ONE IS MARKED. The server truncates a
## Discord body to 1900 characters per call, so batching several messages would spend
## the budget of the newest on the oldest. Every POST therefore carries exactly one
## entry, and an entry leaves the queue only when the answer is both an HTTP 2xx and
## the handler's own receipt (`{"ok": true, "received": 1}` — `api/feedback.js:180`).
## Anything else — a refusal, a malformed body, a timeout, a socket that never answered
## — stops the run and leaves every unconfirmed entry pending for the next attempt.
##
## ONE RUN AT A TIME. A submit or a boot retry that arrives while a run is in flight is
## refused rather than queued: two runs over the same queue would post the same message
## twice, and the API has no idempotency key to undo that.
##
## THE TEST SEAM. `set_poster()` replaces the HTTPRequest with an object that answers
## through the same shape the coach client's seam uses — `post(url, body, timeout_ms,
## on_done)` and `cancel()` — so an isolated test drives every state without a socket
## and without a real message leaving the machine. The default poster is the engine's
## own HTTPRequest.
extends Node

## The finished run: `{ok, reason, sent, pending, requests}`. Emitted once per run,
## refusals included, so a listener (the screen, a log) never has to poll.
signal run_finished(summary: Dictionary)

## The endpoint the 2D build posts to (`js/data.js:79`). Kept as the default rather
## than the only value: `configure()` takes the address so a test can point elsewhere.
const ENDPOINT := "https://steam-circuit-padel-pro.vercel.app/api/feedback"

## A bounded wait. The handler answers only after it has delivered, so this is the
## ceiling on "the player is left on a pending line", not a pacing knob.
const TIMEOUT_SECONDS := 12.0
## The handler answers with a small receipt. A bigger body is not one, and is refused
## rather than buffered.
const MAX_RESPONSE_BYTES := 65536

## Why a run stopped, in the reference's own spellings where they exist
## (`js/ui.js:350-393`) plus the two the async path adds.
const REASON_NONE := "no-endpoint"
const REASON_EMPTY := "empty"
const REASON_BUSY := "busy"
const REASON_OFFLINE := "offline"
const REASON_TIMEOUT := "timeout"
const REASON_REJECTED := "rejected"
const REASON_UNCONFIRMED := "unconfirmed"
## The receipt arrived and the confirmation could not be written down. The entry stays
## pending: an entry this run cannot prove it stored is an entry the next run would post
## again, and posting the same message twice is worse than posting it late.
const REASON_STORAGE := "storage"

## The save group the queue lives in (`save_schema.gd:90`, `save_store.gd:135`).
const GROUP := "feedback"

const Config := preload("res://game/match_config.gd")

var _endpoint := ""
## The bounded wait actually used. `TIMEOUT_SECONDS` is the shipped value; the setter
## exists so a test can prove the timeout branch against a real socket in under a second
## instead of holding a run open for twelve.
var _timeout := TIMEOUT_SECONDS
var _store_provider: Callable = Callable()
var _poster: Object = null
var _http: HTTPRequest
var _pending := false
var _generation := 0
## The one-shot completion connection of the request in flight, kept so it can be
## disconnected instead of accumulating (`coach_client.gd` keeps the same one).
var _completion: Callable = Callable()
var _current_id := ""
var _requests := 0
var _sent: Array = []
var _last_reason := ""
var _last_detail := ""
var _boot_done := false
var _on_done: Callable = Callable()


func _ready() -> void:
	_ensure_http()


# ---------------------------------------------------------------------------
# Wiring
# ---------------------------------------------------------------------------

## The endpoint and the store a confirmation is written back into. The store is a
## callable and not a value because `Config.save_store()` builds a fresh reader per
## call (`match_config.gd:211`): holding one would hold a path a test moved.
func configure(endpoint_in: String, store_provider: Callable = Callable()) -> void:
	_endpoint = endpoint_in
	if store_provider.is_valid():
		_store_provider = store_provider


## The address the 2D build posts to, for a host that just wants the default.
static func default_endpoint() -> String:
	return ENDPOINT


func set_endpoint(endpoint_in: String) -> void:
	_endpoint = endpoint_in


func endpoint() -> String:
	return _endpoint


## True when there is somewhere to post. The screen asks this instead of assuming, so
## a build without an endpoint keeps the honest "save and copy" ladder.
func has_endpoint() -> bool:
	return _endpoint != ""


func set_store_provider(provider: Callable) -> void:
	_store_provider = provider


func set_timeout_seconds(value: float) -> void:
	_timeout = maxf(value, 0.1)
	if _http != null:
		_http.timeout = _timeout


func timeout_seconds() -> float:
	return _timeout


# ---------------------------------------------------------------------------
# The test seam (the shape `coach_client.gd::set_poster` documents)
# ---------------------------------------------------------------------------

func set_poster(poster: Object) -> void:
	_poster = poster


func poster() -> Object:
	return _poster


## How many requests this service has actually sent. A test reads it to prove that a
## guard refused the call instead of quietly posting anyway.
func request_count() -> int:
	return _requests


## The ids confirmed during the last run, in the order they were accepted.
func sent_ids() -> Array:
	return _sent.duplicate()


## The reason the last run stopped, or `""` when it finished the queue.
func last_reason() -> String:
	return _last_reason


## The transport's own words behind the last non-answer, for a test or a log — never
## player-facing.
func last_detail() -> String:
	return _last_detail


func running() -> bool:
	return _pending


func http_status() -> int:
	return _http.get_http_client_status() if _http != null else HTTPClient.STATUS_DISCONNECTED


# ---------------------------------------------------------------------------
# The queue: read from, and confirmations written back to, the save contract
# ---------------------------------------------------------------------------

func store() -> RefCounted:
	if _store_provider.is_valid():
		return _store_provider.call()
	return Config.save_store()


## The stored queue, newest first — the store's own order (`js/ui.js:283-290`).
func queued_entries() -> Array:
	var read: Dictionary = store().read_group(GROUP)
	var payload: Variant = read.get("payload", null)
	return payload if payload is Array else []


## The entries this service still owes a delivery for, in the store's own order.
func pending_entries() -> Array:
	var out: Array = []
	for entry in queued_entries():
		if entry is Dictionary and not bool((entry as Dictionary).get("sent", false)):
			out.append(entry)
	return out


func pending_count() -> int:
	return pending_entries().size()


## Marks the one pending entry this id names, through the same group contract the screen
## writes (`save_store.gd::write_feedback`), and reports whether the write committed.
##
## ONE ENTRY, NOT EVERY MATCH: a queue that carries the same id twice must not have both
## copies cleared by a receipt for one of them — the id is the only handle the API has,
## and the second copy was never delivered. The first still-unsent match is the one this
## receipt belongs to.
##
## THE RETURN VALUE IS THE CONTRACT. `false` means the write did not commit, and a caller
## that kept going would re-read the same entry as pending and post it again.
func mark_sent(id: String) -> bool:
	if id == "":
		return false
	var list := queued_entries()
	for entry in list:
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == id and not bool((entry as Dictionary).get("sent", false)):
			(entry as Dictionary)["sent"] = true
			break
	var write: Dictionary = store().write_feedback(list)
	return bool(write.get("ok", false))


# ---------------------------------------------------------------------------
# The runs
# ---------------------------------------------------------------------------

## Sends the pending queue, one entry per request, in the store's order.
##
## Returns whether a run started and why not when it did not. `on_done` is called once
## with the same summary `run_finished` carries; a run that starts and finds nothing to
## do does not start at all (`reason: "empty"`), so a boot with an empty queue makes no
## request and says so.
func submit_pending(on_done: Callable = Callable()) -> Dictionary:
	if _pending:
		return {"started": false, "reason": REASON_BUSY, "count": pending_count()}
	if not has_endpoint():
		return {"started": false, "reason": REASON_NONE, "count": pending_count()}
	var pending := pending_entries()
	if pending.is_empty():
		return {"started": false, "reason": REASON_EMPTY, "count": 0}
	_on_done = on_done
	_sent = []
	_last_reason = ""
	_pending = true
	_generation += 1
	_advance(_generation)
	return {"started": true, "reason": "", "count": pending.size()}


## The boot's one retry: the same run, allowed once per process. The second call is
## refused with its own reason instead of starting a second pass over the queue.
func boot_retry(on_done: Callable = Callable()) -> Dictionary:
	if _boot_done:
		return {"started": false, "reason": REASON_BUSY, "count": pending_count()}
	_boot_done = true
	return submit_pending(on_done)


## Drops whatever is in flight and invalidates its reply (the shape
## `coach_client.gd::cancel` uses). A reply that arrives afterwards is discarded
## instead of marking an entry the run no longer owns.
func cancel_run() -> void:
	if not _pending:
		return
	_pending = false
	_generation += 1
	if _poster != null:
		if _poster.has_method("cancel"):
			_poster.call("cancel")
		return
	if _http != null and _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	_drop_completion()


## Sends the next pending entry, or ends the run when the queue is drained. Re-reads
## the store every step so an entry queued while the run is in flight is picked up
## instead of waiting for a restart — and so nothing is ever sent twice: what leaves
## the pending set is exactly what a receipt has confirmed.
func _advance(generation: int) -> void:
	if generation != _generation or not _pending:
		return
	var pending := pending_entries()
	if pending.is_empty():
		_finish("", generation)
		return
	var entry: Dictionary = pending[0]
	_current_id = String(entry.get("id", ""))
	_pending_request(entry, generation)


func _pending_request(entry: Dictionary, generation: int) -> void:
	var payload := request_body(entry)
	_requests += 1
	if _poster != null:
		_poster.call("post", _endpoint, payload, int(_timeout * 1000.0), _on_transport.bind(generation))
		return
	_ensure_http()
	_drop_completion()
	_completion = _on_http_completed.bind(generation)
	_http.request_completed.connect(_completion, CONNECT_ONE_SHOT)
	var error := _http.request(_endpoint, headers(), HTTPClient.METHOD_POST, payload)
	if error != OK:
		_drop_completion()
		_on_transport({"ok": false, "reason": REASON_OFFLINE, "detail": "HTTPRequest refused the call: %d" % error}, generation)
		return
	_last_detail = ""


## The wire body: the handler's own envelope with exactly one entry in it
## (`api/feedback.js:160`: `sanitize(body?.entries)`).
func request_body(entry: Dictionary) -> String:
	return JSON.stringify({"entries": [entry]})


func headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json"])


func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.name = "FeedbackHttp"
	_http.timeout = _timeout
	_http.body_size_limit = MAX_RESPONSE_BYTES
	_http.accept_gzip = false
	add_child(_http)


func _drop_completion() -> void:
	if _completion.is_valid() and _http != null and _http.request_completed.is_connected(_completion):
		_http.request_completed.disconnect(_completion)
	_completion = Callable()


func _on_http_completed(result: int, response_code: int, _headers_in: PackedStringArray, body: PackedByteArray, generation: int) -> void:
	_completion = Callable()
	if generation != _generation:
		return
	_on_transport(_transport_result(result, response_code, body), generation)


## One transport report, in the shape this service speaks: `ok` plus the reason when it
## is not. A receipt is the handler's own (`api/feedback.js:180`): the HTTP status is a
## 2xx **and** the body says `ok: true` and `received: 1` — the count this exact
## single-entry request asked for. A 200 carrying anything else is not a delivery.
func _transport_result(result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result == HTTPRequest.RESULT_TIMEOUT:
		return {"ok": false, "reason": REASON_TIMEOUT, "detail": "the endpoint did not answer in time"}
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		return {"ok": false, "reason": REASON_UNCONFIRMED, "detail": "the answer was over the declared bound"}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "reason": REASON_OFFLINE, "detail": "no endpoint answered (result %d)" % result}
	if response_code < 200 or response_code >= 300:
		return {"ok": false, "reason": REASON_REJECTED, "detail": "the endpoint answered %d" % response_code}
	# `JSON.new().parse()` and not `JSON.parse_string()`: a refused body is an expected
	# state here, and the one-shot parser prints an engine error for it.
	var reader := JSON.new()
	if reader.parse(body.get_string_from_utf8()) != OK or not (reader.data is Dictionary):
		return {"ok": false, "reason": REASON_UNCONFIRMED, "detail": "the answer was not one entry's receipt"}
	var receipt: Dictionary = reader.data
	if bool(receipt.get("ok", false)) and int(receipt.get("received", 0)) == 1:
		return {"ok": true}
	return {"ok": false, "reason": REASON_UNCONFIRMED, "detail": "the answer did not confirm one entry"}


## The one place a transport report becomes a run step. A stale generation is dropped
## here too, so both posters share the same rule.
func _on_transport(reply: Dictionary, generation: int) -> void:
	if generation != _generation or not _pending:
		return
	if bool(reply.get("ok", false)):
		if not mark_sent(_current_id):
			# The receipt was real but the queue could not record it. Stop here rather
			# than re-read the same entry as pending and post it a second time.
			_pending = false
			_last_detail = "the confirmation could not be written to the queue"
			_finish(REASON_STORAGE, generation, true)
			return
		_last_detail = ""
		_sent.append(_current_id)
		_advance(generation)
		return
	_last_detail = String(reply.get("detail", ""))
	_pending = false
	_finish(String(reply.get("reason", REASON_UNCONFIRMED)), generation, true)


func _finish(reason: String, generation: int, stopped := false) -> void:
	if generation != _generation:
		return
	_pending = false
	_last_reason = reason
	var summary := {
		"ok": reason == "" and not stopped,
		"reason": reason,
		"sent": _sent.duplicate(),
		"pending": pending_count(),
		"requests": _requests,
	}
	# A screen that was freed mid-run leaves an invalid callable here; the one-shot is
	# cleared either way so a later run cannot call a dead target.
	var done := _on_done
	_on_done = Callable()
	if done.is_valid():
		done.call(summary)
	run_finished.emit(summary)
