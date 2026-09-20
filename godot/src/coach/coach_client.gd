## coach_client.gd — the coach's only way to the loopback bridge.
##
## WHAT IT TALKS TO. A development bridge a person starts themselves
## (`scripts/coach/jev_bridge.mjs`) on `127.0.0.1`, at the contract's own path, carrying
## the contract's own wire version, the bounded counter snapshot and the candidate list
## this match actually supports. It never sees an API key: the key lives in the bridge's
## environment, and nothing here reads a file, an environment secret or a remote host.
##
## NOTHING RUNS ON ITS OWN. `analyze()` is called by an explicit press on
## `Analizza con Jev`. A render, a capture state and a language flip never reach here,
## and a match whose snapshot is not sufficient is answered from the snapshot alone —
## with no request at all.
##
## ONE REQUEST AT A TIME, AND STALE REPLIES DROP. A press while a request is in flight
## is refused (not queued, not doubled); `cancel()` — the result screen's exit — bumps a
## generation, so a reply that arrives afterwards is discarded instead of painting a
## screen the player has left.
##
## THE TEST SEAM. `set_poster()` replaces the HTTPRequest with an object that answers
## through the same shape: `post(url, body, timeout_ms, on_done)` and `cancel()`. The
## default poster is the engine's own HTTPRequest, and the coach tests drive both — a
## fake for the states, and the real client against a loopback stub server — so the seam
## is not a second implementation of the transport.
extends Node

## The finished record (`coach_advice.gd`'s shape): emitted once per `analyze()`, for the
## insufficient case too, which never leaves the machine.
signal analysis_ready(record: Dictionary)

const Contract := preload("res://src/coach/coach_contract.gd")
const Stats := preload("res://src/coach/coach_stats.gd")
const Advice := preload("res://src/coach/coach_advice.gd")

## What a transport reports, before the answer's own contract is checked.
const STATUS_OK := "ok"
const STATUS_INVALID := "invalid"
const STATUS_UNAVAILABLE := "unavailable"
const STATUS_TIMEOUT := "timeout"
const STATUS_UNREACHABLE := "unreachable"
const STATUS_TOO_LARGE := "too_large"
const STATUS_ERROR := "error"

## The extra seconds the client allows over the bridge's own upstream bound: the bridge
## may spend its whole budget on TypeSafe and still answer.
const TIMEOUT_MARGIN_SECONDS := 2.0

var _http: HTTPRequest
var _poster: Object = null
var _generation := 0
var _pending := false
## The one-shot completion connection of the request in flight, kept so it can be
## disconnected instead of accumulating: a cancelled request, and a request the engine
## refused before it started, must not leave a bound callable behind.
var _completion: Callable = Callable()
var _snapshot: Dictionary = {}
var _record: Dictionary = {}
var _requests := 0
var _last_detail := ""


func _ready() -> void:
	_ensure_http()


## How many requests this client has actually sent. The result-screen audit reads it to
## prove that a render, a capture and a double press do not call the bridge.
func request_count() -> int:
	return _requests


func pending() -> bool:
	return _pending


## How many completion handlers are attached to the request object: one at most while a
## request is in flight, and none once it has finished, been cancelled, or been refused
## before it started. The client test reads it to prove no bound callable accumulates.
func open_completion_handlers() -> int:
	return _http.request_completed.get_connections().size() if _http != null else 0


## The last finished record, or `{}` before the first one.
func record() -> Dictionary:
	return _record


## The reason behind the last non-answer, for a test or a log — never player-facing.
func last_detail() -> String:
	return _last_detail


func snapshot() -> Dictionary:
	return _snapshot


## The snapshot of one result payload without sending anything: the panel's own
## presentation decision (is there enough measured match to ask about at all?) reads it
## here, so the block and the request can never disagree about what was measured.
func snapshot_of(result: Dictionary) -> Dictionary:
	return Stats.snapshot(result)


## The bridge's address: loopback only, the contract's own path, and the port from the
## declared environment variable when it is a usable TCP port.
func url() -> String:
	return "http://127.0.0.1:%d%s" % [port(), String(Contract.wire().get("path", "/coach/jev"))]


func port() -> int:
	var declared := int(Contract.wire().get("defaultPort", 8787))
	var env_name := String(Contract.wire().get("portEnv", "COACH_PORT"))
	var raw := OS.get_environment(env_name)
	if raw == "" or not raw.is_valid_int():
		return declared
	var value := int(raw)
	return value if value >= 1024 and value <= 65535 else declared


## The client's own bound, in seconds.
func timeout_seconds() -> float:
	var raw: Variant = Contract.upstream().get("timeoutMs", 8000)
	var ms := 8000.0
	if raw is float or raw is int:
		ms = float(raw)
	return ms / 1000.0 + TIMEOUT_MARGIN_SECONDS


## A test's own transport, or the engine's HTTPRequest when none is set.
func set_poster(poster: Object) -> void:
	_poster = poster


func poster() -> Object:
	return _poster


## Asks about one SNAPSHOT (`coach_stats.gd`'s own shape, from `snapshot_of()`). Returns
## true when a request was sent: a match without enough measured counters answers
## insufficient from here and never touches the bridge, and a press while one request is
## in flight is refused.
func analyze(snapshot_in: Dictionary) -> bool:
	if _pending:
		_last_detail = "a request is already in flight"
		return false
	if not snapshot_in.has("counters"):
		# A raw result payload here would be measured twice and read as an empty match —
		# the exact failure this guard exists to make loud.
		push_error("coach_client.gd: analyze() takes a snapshot; call snapshot_of(result) first")
		return false
	_snapshot = snapshot_in
	if not bool(_snapshot.get("sufficient", false)):
		_record = Advice.evaluate(_snapshot, {})
		_last_detail = String(_record.get("detail", ""))
		analysis_ready.emit(_record)
		return false
	_ensure_http()
	_generation += 1
	var generation := _generation
	_pending = true
	_requests += 1
	var payload := request_body()
	var url_text := url()
	if _poster != null:
		_poster.call("post", url_text, payload, int(timeout_seconds() * 1000.0), _on_transport.bind(generation))
		return true
	# One shot per request, bound to this request's generation: a reply from a request
	# the player's exit already cancelled arrives with a stale generation and is dropped
	# instead of being painted.
	_drop_completion()
	_completion = _on_http_completed.bind(generation)
	_http.request_completed.connect(_completion, CONNECT_ONE_SHOT)
	var error := _http.request(url_text, headers(), HTTPClient.METHOD_POST, payload)
	if error != OK:
		_drop_completion()
		_pending = false
		_last_detail = "HTTPRequest refused the call: %d" % error
		_record = Advice.evaluate(_snapshot, {"status": STATUS_ERROR})
		analysis_ready.emit(_record)
		return false
	return true


## Drops whatever is in flight and invalidates its reply. Called on the screen's exit.
func cancel() -> void:
	_pending = false
	_generation += 1
	if _poster != null:
		if _poster.has_method("cancel"):
			_poster.call("cancel")
		return
	if _http != null and _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	_drop_completion()


## Disconnects the request's own completion handler if it is still connected. A one-shot
## connection disappears when it fires, so this is a no-op then — and it is what keeps a
## cancelled or never-started request from leaving a callable on the signal.
func _drop_completion() -> void:
	if _completion.is_valid() and _http != null and _http.request_completed.is_connected(_completion):
		_http.request_completed.disconnect(_completion)
	_completion = Callable()


## The bounded wire body: the contract's version, the allowlisted counters and the
## candidates this match supports. Nothing else — no free text, no score, no mode.
func request_body() -> String:
	var wires := {
		"version": int(Contract.wire().get("version", 1)),
		"stats": _snapshot.get("counters", {}),
		"candidates": _snapshot.get("candidates", []),
	}
	return JSON.stringify(wires)


func headers() -> PackedStringArray:
	# No Origin and no Referer: the bridge refuses a browser's own request, and this
	# client is not one.
	return PackedStringArray(["Content-Type: application/json"])


func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.name = "CoachHttp"
	_http.timeout = timeout_seconds()
	_http.body_size_limit = int(Contract.wire().get("maxResponseBytes", 65536))
	_http.accept_gzip = false
	add_child(_http)


## The HTTPRequest outcome, as the transport shape the coach speaks. `generation` arrives
## last because `Callable.bind()` appends its arguments (`godot/src/coach/coach_client.gd`
## connects one shot per request); a stale completion is dropped before anything reads it.
func _on_http_completed(result: int, response_code: int, _headers_in: PackedStringArray, body: PackedByteArray, generation: int) -> void:
	# The one-shot connection has just fired; the field must not point at a dead callable.
	_completion = Callable()
	if generation != _generation:
		return
	_on_transport(_transport_result(result, response_code, body), generation)


func _transport_result(result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result == HTTPRequest.RESULT_TIMEOUT:
		return {"status": STATUS_TIMEOUT, "detail": "the bridge did not answer in time"}
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		return {"status": STATUS_TOO_LARGE, "detail": "the bridge's answer was over the declared bound"}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"status": STATUS_UNREACHABLE, "detail": "no loopback bridge answered (result %d)" % result}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"status": STATUS_INVALID, "detail": "the bridge's answer was not JSON"}
	var reply: Dictionary = parsed
	var status := String(reply.get("status", ""))
	if response_code == 200 and status == STATUS_OK:
		return {"status": STATUS_OK, "body": reply}
	if status == STATUS_INVALID or status == "upstream_invalid":
		return {"status": STATUS_INVALID, "detail": "the bridge refused the upstream answer"}
	return {"status": STATUS_UNAVAILABLE, "detail": "the bridge answered %d (%s)" % [response_code, status]}


## The one place a transport report becomes a rendered record. A stale generation is
## ignored here too, so both posters share the same rule.
func _on_transport(reply: Dictionary, generation: int) -> void:
	if generation != _generation:
		return
	_pending = false
	_record = Advice.evaluate(_snapshot, reply)
	_last_detail = String(_record.get("detail", ""))
	analysis_ready.emit(_record)
