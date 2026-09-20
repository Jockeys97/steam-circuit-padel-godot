## CoachPanel.gd — the result screen's coach block.
##
## WHAT THIS IS. One block under the result card's own content: the disclosure, one
## button that asks Jev about this match, and whatever came back — an advice sentence
## with the match's own numbers and the exercise it links to, or a truthful state that
## says less. It paints; it never decides where the player goes: a press on the exercise
## button is reported to the screen, which owns the route
## (`godot/src/ui/screens/ResultScreen.gd::_on_coach_drill_requested`).
##
## LITERALS. None: every visible string is a coach message id resolved by
## `godot/src/coach/coach_text.gd` — the UI lane's own scan reads this file like any
## other `res://src/ui/**` script, and the coach's sentences live in `coach_strings.json`.
##
## WHAT IT SHOWS WHEN THE ANSWER IS WEAK. The numbers, and no recommendation: an
## uncertain reading, a bridge that is not running, a match without enough measured
## counters, and an answer that failed its contract are four different sentences, and
## none of them claims Jev analyzed the match when it did not.
##
## THE CONTINUATION RULE. When the screen reports a pending career or tournament
## continuation, the exercise button is not offered: opening the training from here would
## replace the run the player is one press away from continuing
## (`godot/game/match_config.gd::pending_mode`). The named exercise and its hint still
## show, so the advice is not lost, and the block says where the training opens instead.
##
## WHAT IS KEPT, AND WHAT MAY BE ASKED AGAIN. A reading about this match — advice, an
## uncertain reading, or a measured refusal — is not re-asked: the numbers have not changed
## since it was made. A FAILURE (a bridge that was unreachable, an answer that could not be
## verified) says nothing about the match, so the button offers `coachRetry`, and a press
## clears the failed reading before the new request starts. Re-rendering the SAME result
## keeps whatever the block holds, request in flight included; a DIFFERENT result cancels it
## so a late reply to the match the player has left cannot paint.
extends VBoxContainer

const CoachAdvice := preload("res://src/coach/coach_advice.gd")
const CoachClient := preload("res://src/coach/coach_client.gd")
const CoachText := preload("res://src/coach/coach_text.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")

## The exercise button was pressed: the screen owns the route.
signal drill_requested(drill_id: String)

var _client: Node
var _poster: Object = null
var _built := false
var _snapshot: Dictionary = {}
var _record: Dictionary = {}
## The result this block is showing, canonically: a re-render of the SAME match keeps the
## reading (or the request in flight), a different one drops both.
var _result_key := ""
var _pending_continuation := false
var _loading := false
var _title: Label
var _disclosure: Label
var _aggregate: Label
var _status: Label
var _evidence: Label
var _exercise: Label
var _analyze: Button
var _drill: Button


func _ready() -> void:
	_ensure()


func _ensure() -> void:
	if _built:
		return
	_built = true
	name = "Coach"
	add_theme_constant_override("separation", 6)
	_client = CoachClient.new()
	_client.name = "CoachClient"
	add_child(_client)
	_client.analysis_ready.connect(_on_analysis_ready)
	if _poster != null:
		_client.set_poster(_poster)
	_title = _label(self, "CoachTitle")
	_disclosure = _label(self, "CoachDisclosure")
	_aggregate = _label(self, "CoachAggregate")
	_status = _label(self, "CoachStatus")
	_evidence = _label(self, "CoachEvidence")
	_exercise = _label(self, "CoachExercise")
	var row := HBoxContainer.new()
	row.name = "CoachActions"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_analyze = Button.new()
	_analyze.name = "CoachAnalyzeButton"
	_analyze.pressed.connect(press_analyze)
	row.add_child(_analyze)
	_drill = Button.new()
	_drill.name = "CoachDrillButton"
	_drill.pressed.connect(press_drill)
	row.add_child(_drill)


## A test's own transport, installed before the first press.
func set_poster(poster: Object) -> void:
	_poster = poster
	_ensure()
	if _client != null:
		_client.set_poster(poster)


func client() -> Node:
	_ensure()
	return _client


## The payload this block advises on, and whether the run behind it is one press from
## continuing.
func show_result(result: Dictionary, pending_continuation: bool) -> void:
	_ensure()
	_pending_continuation = pending_continuation
	var key := _result_key_of(result)
	if key == _result_key:
		# The same match, rendered again — a language flip, a second `render()`, a capture
		# walk. The reading already paid for is kept, and so is a request still in flight;
		# only the sentences are re-resolved.
		_paint()
		return
	# A different match: whatever was in flight belongs to the one the player has left, so
	# it is cancelled (its reply cannot paint) and the block starts over.
	_client.cancel()
	_loading = false
	_record = {}
	_result_key = key
	_snapshot = _client.snapshot_of(result)
	_paint()


func press_analyze() -> bool:
	_ensure()
	if _loading:
		return false
	if not _record.is_empty() and not retryable():
		# A reading and a measured refusal are answers about THIS match; pressing again
		# would ask the same question about the same numbers.
		return false
	if retryable():
		# A failure said nothing about the match, so the player may ask again — and the
		# failed reading is cleared before the new request starts, so nothing of it can be
		# painted while the bridge is being asked.
		_record = {}
	_loading = true
	_paint()
	var sent: bool = _client.analyze(_snapshot)
	if not sent:
		# Either the snapshot was not sufficient (the record arrived synchronously) or a
		# request was already in flight; the signal paints the first, and the second
		# leaves the loading line up exactly as it was.
		_loading = false
		_paint()
	return sent


func press_drill() -> String:
	_ensure()
	var drill_id := String(_record.get("drill_id", ""))
	if drill_id == "" or _pending_continuation:
		return ""
	drill_requested.emit(drill_id)
	return drill_id


## The screen's exit: whatever is in flight is dropped, and its reply cannot paint.
func cancel() -> void:
	_ensure()
	_client.cancel()
	_loading = false


## True while the block is showing a failure the player may ask again about: the bridge
## was unreachable, or its answer could not be verified. Neither says anything about the
## match, which is exactly what makes a retry meaningful.
func retryable() -> bool:
	var state := String(_record.get("state", ""))
	return state == CoachAdvice.STATE_UNAVAILABLE or state == CoachAdvice.STATE_INVALID


## A canonical fingerprint of one result: the figures the block shows and the counters it
## reads, with the counter keys sorted so two renderings of the same match answer the same
## string whatever order the payload was built in.
static func _result_key_of(result: Dictionary) -> String:
	return JSON.stringify({
		"score": str(result.get("score", "")),
		"won": bool(result.get("won", false)),
		"pointsToWin": int(result.get("pointsToWin", 0)),
		"player": int(result.get("player", 0)),
		"ai": int(result.get("ai", 0)),
		"stats": _sorted(result.get("stats", {})),
	})


static func _sorted(value: Variant) -> Variant:
	if not (value is Dictionary):
		return value
	var source: Dictionary = value
	var keys: Array = source.keys()
	keys.sort()
	var out := {}
	for key in keys:
		out[str(key)] = _sorted(source[key])
	return out


func _on_analysis_ready(record: Dictionary) -> void:
	_loading = false
	_record = record
	_paint()


# ---------------------------------------------------------------------------
# Painting
# ---------------------------------------------------------------------------

func _paint() -> void:
	var state := state_id()
	_title.text = CoachText.t("coachTitle")
	# The evidence line says "your side's numbers" itself, so the standing note about what
	# the numbers are steps aside while it is on screen — the block never says it twice.
	var with_numbers := state == "advice" or state == "uncertain"
	_aggregate.text = CoachText.t("coachAggregate")
	_aggregate.visible = not with_numbers
	_disclosure.visible = state == "idle" or state == "unavailable" or state == "invalid"
	_disclosure.text = CoachText.t("coachDisclosure")
	var status_id := ""
	match state:
		"loading":
			status_id = "coachLoading"
		"insufficient":
			status_id = "coachInsufficient"
		"unavailable":
			status_id = "coachUnavailable"
		"invalid":
			status_id = "coachInvalid"
		"uncertain":
			status_id = "coachUncertain"
	_status.text = CoachText.t(status_id) if status_id != "" else ""
	_status.visible = status_id != ""
	_evidence.visible = with_numbers
	if with_numbers:
		_evidence.text = CoachText.t(String(_record.get("evidence_id", "")), _record.get("evidence_params", {}))
	var drill_id := String(_record.get("drill_id", ""))
	var exercise_shown := state == "advice" and drill_id != ""
	_exercise.visible = exercise_shown
	if exercise_shown:
		_exercise.text = exercise_lines(drill_id)
	_analyze.visible = state == "idle" or state == "unavailable" or state == "invalid"
	_analyze.disabled = state == "loading"
	_analyze.text = CoachText.t("coachAnalyze") if state == "idle" else CoachText.t("coachRetry")
	_drill.visible = exercise_shown and not _pending_continuation
	_drill.text = CoachText.t("coachOpenDrill")


## The advice sentence, the existing exercise's own name, and — with a continuation
## pending — where the training opens instead. Each line is resolved here so a language
## flip reaches the block with the rest of the screen.
func exercise_lines(drill_id: String) -> String:
	var lines: Array[String] = []
	var advice_id := String(_record.get("advice_id", ""))
	if advice_id != "":
		lines.append(CoachText.t(advice_id, _record.get("advice_params", {})))
	# The exercise is named the way the training screen names it: the reference's own
	# generated table for its four, this build's `drill_strings.json` for the Godot-only
	# ones (`drill_text.gd` resolves both).
	lines.append(CoachText.t("coachExercise", {"drill": DrillText.exercise_name(drill_id)}))
	if _pending_continuation:
		lines.append(CoachText.t("coachDrillBlocked"))
	return "\n".join(lines)


## The state this block is in, read back by the audit: `idle`, `loading`,
## `insufficient`, `unavailable`, `invalid`, `uncertain` or `advice`.
func state_id() -> String:
	if _loading and _record.is_empty():
		return "loading"
	if _record.is_empty():
		return "idle" if bool(_snapshot.get("sufficient", false)) else "insufficient"
	var state := String(_record.get("state", ""))
	if state == CoachAdvice.STATE_ADVICE:
		return "advice"
	if state == CoachAdvice.STATE_UNCERTAIN:
		return "uncertain"
	if state == CoachAdvice.STATE_INSUFFICIENT:
		return "insufficient"
	if state == CoachAdvice.STATE_INVALID:
		return "invalid"
	return "unavailable"


func shown_status() -> String:
	_ensure()
	return _status.text if _status.visible else ""


func shown_evidence() -> String:
	_ensure()
	return _evidence.text if _evidence.visible else ""


func shown_exercise() -> String:
	_ensure()
	return _exercise.text if _exercise.visible else ""


func shown_title() -> String:
	_ensure()
	return _title.text


func shown_disclosure() -> String:
	_ensure()
	return _disclosure.text if _disclosure.visible else ""


func shown_analyze_label() -> String:
	_ensure()
	return _analyze.text if _analyze.visible else ""


func analyze_visible() -> bool:
	_ensure()
	return _analyze.visible


func drill_visible() -> bool:
	_ensure()
	return _drill.visible


## The controls the screen registers with the shell's focus model.
func analyze_control() -> Control:
	_ensure()
	return _analyze


func drill_control() -> Control:
	_ensure()
	return _drill


func record() -> Dictionary:
	return _record


## A centred, wrapping label in `parent` — the block's own line shape. It is parented here,
## at the one place a line is made: a label built but never parented draws nothing while
## still answering its own `text`, which is the failure a state-only audit cannot see (the
## visual probe `godot/tests/ui/_probe_coach.gd` is what caught it).
static func _label(parent: Node, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
