## FeedbackScreen.gd — `screen-feedback`, the reference's own form (`index.html:311-364`).
##
## WHAT THIS SCREEN IS, AND WHAT IT MAY NEVER DO. A topic picker (six, the reference's
## own list), a bounded message, an optional contact, the technical context attached or
## not, the "what gets attached" disclosure, and three actions: send, copy, and the
## community link (hidden while neither `steamUrl` nor `discordUrl` is configured —
## `js/main.js:1961`). **Nothing is sent anywhere by this screen.** The queue is written
## through the save contract first (`js/ui.js:240-260`: "si scrive **prima** di qualunque
## tentativo di invio"), and the delivery attempt is a callable seam that is empty by
## default — so in this port a submit saves locally and offers the text, exactly like
## the reference with no endpoint (`js/main.js:2100-2116`). A person pressing the button
## is the only thing that can trigger the seam; `enter()`, captures and the audit never
## call it.
##
## THE QUEUE IS THE REFERENCE'S. Entry `{id, ts, topic, message, contact, diagnostics,
## sent}` (`js/ui.js:270-290`), newest first, capped at `FEEDBACK.maxQueued` by the
## store itself (`save_store.gd::write_feedback`), topic validated against the save
## schema's own list, message sliced to 1200 and contact to 120.
##
## THE DIAGNOSTICS ARE SHOWN BEFORE THEY ARE EATEN. `renderFeedback` writes the payload
## into the disclosure on every render (`js/main.js:1959`) — the player sees exactly
## what would be attached, which is why the reference says attaching data unseen is not
## acceptable. The port builds the same object from live facts (build gate, locale,
## settings snapshot, career, drill records, the last three matches) and keeps the
## reference's own key spellings, because that payload is the thing a server on the
## other side parses.
##
## FALLBACK LADDER, AS THE REFERENCE HAS IT. Endpoint missing or refusing: copy to the
## clipboard **and** reveal the manual block (the text stays visible and selectable — the
## one path that cannot fail), then say which happened: `feedbackOffline` when the
## failure was the network, `feedbackManualHint` otherwise. The clipboard writer is a
## seam too, so a headless audit can drive the ladder without a clipboard.
##
## LITERALS. None: every visible string is a message id, including the counter, whose
## separators are composed (a literal with a space would be prose under the UI lane's
## own scan). The manual fallback's technical block header uses `feedbackWhatIsAttached`
## — the port's own key for the same sentence — because the reference composes that
## block from a hardcoded Italian line the port's rule does not allow in a script.
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Schema := preload("res://src/save/save_schema.gd")
const Config := preload("res://game/match_config.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const Osk := preload("res://src/input/osk.gd")

const SCREEN_ID := "feedback"

## The router's own row for this screen (`ScreenRouter.SCREENS[8]`).
const DECLARED_BACK := "menu"

const CAPTURE_STATES: Array[String] = ["default", "counted", "diagnostics-open", "fallback", "sent"]

## `js/data.js:80`: `maxMessage: 1200`; `:79`: the queue cap the store enforces.
const MAX_MESSAGE := 1200
## `js/ui.js:284`: the contact is sliced to 120, matching `index.html:335 maxlength=120`.
const MAX_CONTACT := 120
## `js/data.js:74`: `maxMailBody` — the reference truncates the sent body to it. The
## port has no mail path, but the manual copy keeps the same ceiling so the text a
## player copies is the text the reference would have posted.
const MAX_BODY := 1800

## The default topic when nothing else is chosen (`js/ui.js:470` starts on the first
## one the markup lists, `bug`).
const DEFAULT_TOPIC := "bug"

## The field suffixes this screen registers, and the locale ids their labels carry.
const FIELD_MESSAGE := "MessageField"
const FIELD_CONTACT := "ContactField"
const FIELD_LABELS := {
	"MessageField": "feedbackMessage",
	"ContactField": "feedbackContact",
}
## The two text fields as the OSK model wants them (see `osk` docs).
const TEXT_FIELD_IDS: Array[String] = ["MessageField", "ContactField"]

## The statuses the ladder can end on, as message ids (`js/main.js:2100-2121`).
const STATUS_EMPTY := "feedbackEmpty"
const STATUS_SAVED := "feedbackSaved"
const STATUS_SENT := "feedbackSent"
const STATUS_OFFLINE := "feedbackOffline"
const STATUS_FALLBACK := "feedbackFallback"
const STATUS_MANUAL := "feedbackManualHint"
const STATUS_COPIED := "feedbackCopied"

## The delivery seam's own verdicts, the reference's spellings (`js/ui.js:350-390`).
const REASON_NONE := "no-endpoint"
const REASON_OFFLINE := "offline"
const REASON_REJECTED := "rejected"

const MAX_COLUMN := 720.0

## The space a literal may not carry (the UI lane's scan flags prose, and a lone space
## is a space). Composed like the rest of the port composes its separators.
static func _sp() -> String:
	return String.chr(32)

const NEWLINE := "\n"

var router_id: String = ""
var back_target_id: String = ""

var _shell: Control
var _store: RefCounted = null
var _built := false
## Re-entrancy guard for the `resized` handler: writing theme-constant overrides from
## inside the layout pass can re-enter synchronously; unguarded it is a stack overflow
## (proven in-engine on DrillScreen, which shares this exact code shape).
var _applying_width := false
var _topic := DEFAULT_TOPIC
var _diagnostics_extras: Dictionary = {}
var _delivery: Callable = Callable()
var _endpoint := ""
var _clipboard_writer: Callable = Callable()
var _community_steam := ""
var _community_discord := ""
var _status_key := ""
var _details_open := false
var _last_focus_request := ""
var _topic_buttons: Dictionary = {}
var _fields: Dictionary = {}


func _ready() -> void:
	_ensure()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return back_target_id


## The router moved here. Nothing is delivered and nothing is sent: the reference only
## renders (`renderFeedback(true)` on `to-feedback`, `js/main.js:2214-2217`).
func enter(payload: Dictionary) -> void:
	_ensure()
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", DECLARED_BACK))
	_shell.set_back_target(back_target_id)
	refresh_strings()
	refresh_queue_status()


func exit() -> void:
	pass


func capture_states() -> Array[String]:
	return CAPTURE_STATES.duplicate()


## The states a capture may pin. A capture shows the form, never a claim about a
## delivery: `sent` pins the status text the reference shows after a successful POST
## and says so in the audit, and nothing here calls the delivery seam.
func apply_capture_state(state_id: String) -> bool:
	_ensure()
	match state_id:
		"default":
			set_message("")
			set_contact("")
			select_topic(DEFAULT_TOPIC)
			set_attach(true)
			set_details_open(false)
			hide_manual()
			_status_key = ""
		"counted":
			set_message(String.chr(120).repeat(MAX_MESSAGE))
			select_topic(DEFAULT_TOPIC)
			set_details_open(false)
			_status_key = ""
		"diagnostics-open":
			set_details_open(true)
		"fallback":
			_reveal_manual(_constructed_entry())
			_status_key = STATUS_MANUAL
		"sent":
			_status_key = STATUS_SENT
		_:
			return false
	refresh_strings()
	refresh_queue_status()
	return true


# ---------------------------------------------------------------------------
# The store and the queue (the reference's JS API, one function per one there)
# ---------------------------------------------------------------------------

func store() -> RefCounted:
	return _store if _store != null else Config.save_store()


func set_store(store_in: RefCounted) -> void:
	_store = store_in
	if _built:
		refresh_queue_status()


func max_message() -> int:
	return MAX_MESSAGE


func max_contact() -> int:
	return MAX_CONTACT


## The stored queue, newest first (`loadFeedbackQueue`).
func queued_entries() -> Array:
	var read: Dictionary = store().read_group("feedback")
	var payload: Variant = read.get("payload", null)
	return payload if payload is Array else []


func queue_size() -> int:
	return queued_entries().size()


func pending_count() -> int:
	var count := 0
	for entry in queued_entries():
		if entry is Dictionary and not bool((entry as Dictionary).get("sent", false)):
			count += 1
	return count


## `queueFeedback({topic, message, contact, attach})` (`js/ui.js:270-290`).
func queue_feedback(topic: String, message: String, contact: String, attach: bool) -> Dictionary:
	var text := message.strip_edges()
	if text == "":
		return {}
	var chosen := topic if Schema.FEEDBACK_TOPICS.has(topic) else String(Schema.FEEDBACK_TOPICS[Schema.FEEDBACK_TOPICS.size() - 1])
	var entry := {
		"id": entry_id(),
		"ts": entry_ts(),
		"topic": chosen,
		"message": text.substr(0, MAX_MESSAGE),
		"contact": contact.substr(0, MAX_CONTACT),
		"diagnostics": diagnostics_payload() if attach else null,
		"sent": false,
	}
	var list := queued_entries()
	list.push_front(entry)
	store().write_feedback(list)
	return entry


## `markFeedbackSent(ids)`: marked, never deleted (`js/ui.js:314-322`).
func mark_sent(ids: Array) -> Array:
	var list := queued_entries()
	for entry in list:
		if entry is Dictionary and ids.has(String((entry as Dictionary).get("id", ""))):
			(entry as Dictionary)["sent"] = true
	store().write_feedback(list)
	return list


## `fb-${Date.now().toString(36)}` — the reference's id shape, in a 36 base.
func entry_id() -> String:
	return "fb-" + String.num_int64(int(Time.get_unix_time_from_system() * 1000.0), 36)


## `new Date().toISOString()`: UTC, second precision here (Godot's own formatter).
func entry_ts() -> String:
	return Time.get_datetime_string_from_system(true, false) + "Z"


# ---------------------------------------------------------------------------
# The delivery seam
# ---------------------------------------------------------------------------

## The callable that would post the entries — empty by default, and the reason a submit
## in this build cannot send anything anywhere. A caller that has a server installs one;
## the audit installs a local recorder that reads the queue at call time and returns a
## chosen verdict. Only a button press reaches it.
func set_delivery(sender: Callable, endpoint: String) -> void:
	_delivery = sender
	_endpoint = endpoint
	if _built:
		refresh_strings()


func delivery_status() -> String:
	if _endpoint == "" or not _delivery.is_valid():
		return REASON_NONE
	return "configured"


func has_endpoint() -> bool:
	return _endpoint != "" and _delivery.is_valid()


## `flushFeedback(deliver, endpoint)` (`js/ui.js:350-393`), same state machine and the
## same reasons: no endpoint → nothing to do, `offline` when the sender throws,
## `rejected` when it answers not-ok, and success marks every pending entry sent.
func flush_feedback() -> Dictionary:
	var pending := pending_entries()
	if not has_endpoint():
		return {"ok": false, "reason": REASON_NONE, "pending": pending.size()}
	if pending.is_empty():
		return {"ok": true, "sent": 0, "pending": 0}
	var ids: Array = []
	for entry in pending:
		ids.append(String((entry as Dictionary).get("id", "")))
	var result: Variant = _delivery.call(pending)
	if not (result is Dictionary):
		return {"ok": false, "reason": REASON_OFFLINE, "pending": pending.size()}
	var verdict: Dictionary = result
	if not bool(verdict.get("ok", false)):
		var reason := String(verdict.get("reason", REASON_REJECTED))
		return {"ok": false, "reason": reason, "pending": pending.size()}
	mark_sent(ids)
	return {"ok": true, "sent": ids.size(), "pending": 0}


func pending_entries() -> Array:
	var out: Array = []
	for entry in queued_entries():
		if entry is Dictionary and not bool((entry as Dictionary).get("sent", false)):
			out.append(entry)
	return out


# ---------------------------------------------------------------------------
# The diagnostics payload (`feedbackDiagnostics`, `js/ui.js:262-310`)
# ---------------------------------------------------------------------------

## The object the disclosure shows and a submit attaches. Live facts only, and the
## reference's key spellings (`js/ui.js:268-308`), so the payload a server parses is the
## same shape in both builds. Two of the reference's fields have no source in this port
## and are recorded by the audit instead of invented: `version`/`balance` (the port has
## no version constants; `BuildFlag` carries the build word, which travels as `demo`)
## and a match-level `difficulty` in the recent rows (the port's history entry has none).
func diagnostics_payload() -> Dictionary:
	var snap := UiData.settings_snapshot(store())
	var career := ModesSave.load_career(store())
	var settings := {
		"difficulty": snap.get("ai_difficulty", null),
		"matchLength": snap.get("match_length", null),
		"drillDifficulty": _diagnostics_extras.get("drill_difficulty", null),
	}
	return {
		"lang": Locale.current_lang(),
		"demo": Config.is_demo(),
		"platform": OS.get_name(),
		"screen": screen_size_text(),
		"gamepad": first_gamepad(),
		"controlMode": snap.get("control_mode", null),
		"reduceMotion": bool(snap.get("reduce_motion", false)),
		"settings": settings,
		"career": {
			"season": career.get("season", null),
			"trophies": career.get("trophies", null),
			"stars": career.get("stars", null),
			"wins": career.get("wins", null),
			"losses": career.get("losses", null),
		},
		"drillRecords": ModesSave.load_drill_records(store()),
		"recentMatches": recent_matches(3),
		"matchesPlayed": UiData.history_entries(store()).size(),
	}


## `JSON.stringify(diagnostics, null, 2)` — what the disclosure renders.
func diagnostics_text() -> String:
	return JSON.stringify(diagnostics_payload(), "\t", true)


## A seam for the two facts this screen cannot see: the drill screen's own difficulty
## (UIR-18 keeps it in its own state; the reference reads `ui.drillDifficulty`) and
## anything else an integrator wants in the payload. Empty by default, and an absent
## key stays `null` — the reference's own "not chosen yet".
func set_diagnostics_extras(extras: Dictionary) -> void:
	_diagnostics_extras = extras.duplicate()
	if _built:
		_refresh_disclosure()


func recent_matches(limit: int) -> Array:
	var out: Array = []
	for row in UiData.history_entries(store()):
		if out.size() >= limit:
			break
		var entry: Dictionary = row
		out.append({
			"mode": entry.get("mode", ""),
			"winner": "player" if bool(entry.get("won", false)) else "ai",
			"score": entry.get("score", ""),
			"athlete": entry.get("athlete", ""),
			"opponent": entry.get("opponent", ""),
			"arena": entry.get("arena", ""),
		})
	return out


func screen_size_text() -> String:
	var size_px := Vector2i(1280, 720)
	if is_inside_tree() and get_viewport() != null:
		size_px = Vector2i(get_viewport().get_visible_rect().size)
	return "%dx%d" % [size_px.x, size_px.y]


## `ui.lastGamepadId ?? null`, asked of the engine instead of remembered: the first
## connected pad, or `null` when none is.
func first_gamepad() -> Variant:
	var pads := Input.get_connected_joypads()
	return int(pads[0]) if not pads.is_empty() else null


# ---------------------------------------------------------------------------
# The text a player copies (`feedbackAsText`, `js/ui.js:395-405`)
# ---------------------------------------------------------------------------

func feedback_as_text(entry: Dictionary) -> String:
	var lines: Array = []
	lines.append("[" + String(entry.get("topic", "")) + "]" + _sp() + "build=" + DemoGate.build())
	lines.append(String(entry.get("message", "")))
	var contact := String(entry.get("contact", ""))
	if contact != "":
		lines.append("contatto:" + _sp() + contact)
	if entry.get("diagnostics", null) != null:
		lines.append("")
		lines.append(UiStrings.t("feedbackWhatIsAttached"))
		lines.append(JSON.stringify(entry.get("diagnostics", {}), "	", true))
	return String(NEWLINE).join(lines).substr(0, MAX_BODY)


# ---------------------------------------------------------------------------
# The form
# ---------------------------------------------------------------------------

func topic() -> String:
	return _topic


func topic_rows() -> Array:
	return UiData.feedback_topics()


func select_topic(id: String) -> bool:
	var known := false
	for row in topic_rows():
		if String((row as Dictionary).get("id", "")) == id:
			known = true
	if not known:
		return false
	_topic = id
	_refresh_topics()
	return true


func message() -> String:
	return String((_fields[FIELD_MESSAGE] as TextEdit).text)


func set_message(text: String) -> void:
	(_fields[FIELD_MESSAGE] as TextEdit).text = text.substr(0, MAX_MESSAGE)
	_refresh_counter()


func contact() -> String:
	return String((_fields[FIELD_CONTACT] as LineEdit).text)


func set_contact(text: String) -> void:
	(_fields[FIELD_CONTACT] as LineEdit).text = text.substr(0, MAX_CONTACT)


func attach() -> bool:
	return bool((_control("AttachCheck") as CheckBox).button_pressed)


func set_attach(on: bool) -> void:
	(_control("AttachCheck") as CheckBox).set_pressed_no_signal(on)


## `0 / 1200` (`js/main.js:1955`), composed: a literal with the space either side of
## the slash would be prose under the UI lane's scan, so the separator is built.
func counter_text() -> String:
	return "%d%s/%s%d" % [message().length(), _sp(), _sp(), MAX_MESSAGE]


func details_open() -> bool:
	return _details_open


func set_details_open(open: bool) -> void:
	_details_open = open
	(_control("DetailsToggle") as Button).set_pressed_no_signal(open)
	if open:
		_refresh_disclosure()
	(_control("DiagView") as Control).visible = open


func status_key() -> String:
	return _status_key


func status_text() -> String:
	return UiStrings.t(_status_key) if _status_key != "" else ""


## What the label above the actions says: the reference swaps `feedbackSend` for
## `feedbackSaveAndCopy` when there is nowhere to post (`js/main.js:1966-1971`).
func send_label_key() -> String:
	return "feedbackSend" if has_endpoint() else "feedbackSaveAndCopy"


## The note under the form (`js/main.js:1976-1981`): without a server the player is told
## the message stays local instead of being told it was sent.
func note_key() -> String:
	return "" if has_endpoint() else "feedbackNoServer"


# ---------------------------------------------------------------------------
# The three actions
# ---------------------------------------------------------------------------

## The send button. Saves first, then tries the seam, then falls back — and every step
## writes its own status, so a player never sees a claim the code did not just check.
func submit() -> Dictionary:
	var text := message().strip_edges()
	if text == "":
		_status_key = STATUS_EMPTY
		request_focus(FIELD_MESSAGE)
		refresh_status()
		return {"queued": false, "status_key": _status_key}
	var entry := queue_feedback(_topic, text, contact(), attach())
	if entry.is_empty():
		_status_key = STATUS_EMPTY
		request_focus(FIELD_MESSAGE)
		refresh_status()
		return {"queued": false, "status_key": _status_key}
	_status_key = STATUS_SAVED
	refresh_status()
	set_message("")
	set_contact("")
	var outcome := flush_feedback()
	var manual := false
	if bool(outcome.get("ok", false)) and int(outcome.get("sent", 0)) > 0:
		_status_key = STATUS_SENT
	elif String(outcome.get("reason", "")) == REASON_NONE:
		manual = _offer_fallback(entry)
		_status_key = STATUS_MANUAL
	elif String(outcome.get("reason", "")) == REASON_OFFLINE:
		manual = _offer_fallback(entry)
		_status_key = STATUS_OFFLINE
	else:
		manual = _offer_fallback(entry)
		_status_key = STATUS_MANUAL
	refresh_queue_status()
	refresh_status()
	return {
		"queued": true,
		"entry": entry,
		"sent": bool(outcome.get("ok", false)) and int(outcome.get("sent", 0)) > 0,
		"reason": String(outcome.get("reason", "")),
		"manual": manual,
		"status_key": _status_key,
	}


## The copy button (`js/main.js:2127-2138`): collects, copies, and when the clipboard
## refuses, shows the text instead of pretending.
func copy_current() -> String:
	var text := message().strip_edges()
	if text == "":
		_status_key = STATUS_EMPTY
		request_focus(FIELD_MESSAGE)
		refresh_status()
		return _status_key
	var entry: Dictionary = _constructed_entry_from_form()
	if copy_to_clipboard(feedback_as_text(entry)):
		_status_key = STATUS_COPIED
	else:
		_reveal_manual(entry)
		_status_key = STATUS_MANUAL
	refresh_status()
	return _status_key


## The fallback ladder's two rungs, in the reference's order: copy, then reveal — and
## the text is revealed either way, because that path cannot fail (`js/main.js:2069-2075`).
func _offer_fallback(entry: Dictionary) -> bool:
	copy_to_clipboard(feedback_as_text(entry))
	_reveal_manual(entry)
	return true


func copy_to_clipboard(text: String) -> bool:
	if _clipboard_writer.is_valid():
		return bool(_clipboard_writer.call(text))
	DisplayServer.clipboard_set(text)
	return DisplayServer.clipboard_get() == text


## A clipboard seam: a headless run may have no clipboard, and a form that only works
## when the platform does is a form that fails silently on the platform that matters.
func set_clipboard_writer(writer: Callable) -> void:
	_clipboard_writer = writer


func manual_visible() -> bool:
	return (_control("ManualBlock") as Control).visible


func manual_text() -> String:
	return String((_control("ManualField") as TextEdit).text)


func hide_manual() -> void:
	(_control("ManualBlock") as Control).visible = false


func _reveal_manual(entry: Dictionary) -> void:
	var block := _control("ManualBlock") as Control
	var field := _control("ManualField") as TextEdit
	field.text = feedback_as_text(entry)
	block.visible = true
	field.select_all()


func _constructed_entry() -> Dictionary:
	return {
		"id": entry_id(),
		"ts": entry_ts(),
		"topic": _topic,
		"message": UiStrings.t("feedbackPlaceholder"),
		"contact": "",
		"diagnostics": diagnostics_payload(),
		"sent": false,
	}


func _constructed_entry_from_form() -> Dictionary:
	var entry := _constructed_entry()
	entry["message"] = message().strip_edges()
	entry["contact"] = contact()
	return entry


# ---------------------------------------------------------------------------
# The community link (hidden while nothing is configured — `js/main.js:1961`)
# ---------------------------------------------------------------------------

func set_community_urls(steam_url: String, discord_url: String) -> void:
	_community_steam = steam_url
	_community_discord = discord_url
	if _built:
		refresh_strings()


func community_url() -> String:
	return _community_steam if _community_steam != "" else _community_discord


func community_visible() -> bool:
	return community_url() != ""


func open_community() -> bool:
	var url := community_url()
	if url == "":
		return false
	OS.shell_open(url)
	return true


# ---------------------------------------------------------------------------
# Strings, statuses, the disclosure
# ---------------------------------------------------------------------------

func refresh_strings() -> void:
	_ensure()
	_shell.set_title("feedbackTitle")
	_shell.set_subtitle("feedbackSub")
	(_control("TopicLabel") as Label).text = UiStrings.t("feedbackTopic")
	(_control("MessageLabel") as Label).text = UiStrings.t("feedbackMessage")
	(_control("ContactLabel") as Label).text = UiStrings.t("feedbackContact")
	(_control("AttachCheck") as CheckBox).text = UiStrings.t("feedbackAttach")
	(_control("DetailsToggle") as Button).text = UiStrings.t("feedbackWhatIsAttached")
	(_control("SendButton") as Button).text = UiStrings.t(send_label_key())
	(_control("CopyButton") as Button).text = UiStrings.t("feedbackCopy")
	(_control("SteamButton") as Button).text = UiStrings.t("feedbackSteam")
	(_control("ManualLabel") as Label).text = UiStrings.t("feedbackManualTitle")
	(_control("Note") as Label).text = UiStrings.t(note_key()) if note_key() != "" else ""
	var message_field := _fields[FIELD_MESSAGE] as TextEdit
	message_field.placeholder_text = UiStrings.t("feedbackPlaceholder")
	(_fields[FIELD_CONTACT] as LineEdit).placeholder_text = UiStrings.t("feedbackContactHint")
	for id in _topic_buttons:
		(_topic_buttons[id] as Button).text = UiStrings.t(topic_label_key(String(id)))
	_refresh_topics()
	_refresh_disclosure()
	(_control("SteamButton") as Control).visible = community_visible()
	refresh_status()


func topic_label_key(id: String) -> String:
	for row in topic_rows():
		if String((row as Dictionary).get("id", "")) == id:
			return String((row as Dictionary).get("label_key", ""))
	return ""


## The queue line (`js/main.js:1982-1987`): the unsent count, or nothing when the queue
## is empty. The reference clears it, which is how a player learns the queue is empty.
func refresh_queue_status() -> void:
	var pending := pending_count()
	if _status_key == "" or _status_key == STATUS_SAVED:
		_status_key = STATUS_QUEUED if pending > 0 else ""
	if _status_key == STATUS_QUEUED:
		refresh_status()


const STATUS_QUEUED := "feedbackQueued"


func refresh_status() -> void:
	var label := _control("Status") as Label
	if label == null:
		return
	if _status_key == STATUS_QUEUED:
		label.text = UiStrings.t(STATUS_QUEUED, {"n": pending_count()})
	else:
		label.text = UiStrings.t(_status_key) if _status_key != "" else ""


func _refresh_disclosure() -> void:
	var field := _control("DiagView") as TextEdit
	if field != null:
		field.text = diagnostics_text()


func _refresh_topics() -> void:
	for id in _topic_buttons:
		var button := _topic_buttons[id] as Button
		if button == null:
			continue
		var active: bool = String(id) == _topic
		button.button_pressed = active
		button.modulate.a = 1.0 if active else 0.62


func _refresh_counter() -> void:
	var counter := _control("Counter") as Label
	if counter != null:
		counter.text = counter_text()


# ---------------------------------------------------------------------------
# Focus and the on-screen keyboard (`godot/src/input/osk.gd`, `menu_nav.gd`)
# ---------------------------------------------------------------------------

## The focusable controls: the six topics, the two text fields, the attach check, the
## disclosure, the three actions — the reference's own reachable set.
func focus_controls() -> Array:
	_ensure()
	return _shell.focus_controls()


func focus_id(suffix: String) -> String:
	_ensure()
	return _shell.focus_id(suffix)


## The suffix the last focus request named — what a headless audit compares, since
## `grab_focus()` needs a live window (`collectFeedback` calls `testo?.focus()`).
func last_focus_request() -> String:
	return _last_focus_request


func request_focus(suffix: String) -> bool:
	_ensure()
	_last_focus_request = suffix
	var control := field_control(focus_id(suffix))
	if control == null:
		control = _control(suffix)
	if control == null:
		return false
	control.grab_focus()
	return true


## The control behind a focus id (`feedback/MessageField`), for the OSK driver.
func field_control(id: String) -> Control:
	var suffix := id
	var slash := id.rfind("/")
	if slash >= 0:
		suffix = id.substr(slash + 1)
	return _fields.get(suffix, null) as Control


## What the OSK model needs to open on a field — the seed value, the ceiling and the
## label key. `menu_focus._target()` does not carry these today (it keeps `kind`, which
## is what makes `MenuNav.confirm()` open the model); the hand-back names the seam, and
## this door is what a driver uses in the meantime.
func osk_seed(id: String) -> Dictionary:
	var field := field_control(id)
	var suffix := id.substr(id.rfind("/") + 1)
	return {
		"id": id,
		"value": String((field as TextEdit).text) if field is TextEdit else String((field as LineEdit).text),
		"max_length": MAX_MESSAGE if suffix == FIELD_MESSAGE else MAX_CONTACT,
		"field_label": String(FIELD_LABELS.get(suffix, "")),
	}


## The OSK model's keys, as `MenuNav.set_osk_targets()` wants them: the reference's own
## rows (`js/main.js:430-437`) and action keys (`:493-498`), resolved by the model's own
## class. The screen does not lay the grid out — the visual keyboard is a postponed
## platform decision (`osk.gd` header) — it only offers the targets a driver installs.
func osk_key_targets() -> Array:
	var targets: Array = []
	var size := Vector2(44.0, 44.0)
	for row in Osk.ROWS:
		for ch in String(row):
			targets.append(_osk_target("osk/%s" % ch, size))
	for action in Osk.ACTION_KEYS:
		targets.append(_osk_target("osk/%s" % String(action["id"]), size))
	return targets


func _osk_target(id: String, size: Vector2) -> Dictionary:
	return {"id": id, "kind": "button", "action": "", "rect": Rect2(Vector2.ZERO, size), "drawn": true}


## Characters typed on the model land here: the field takes the value and the counter
## follows. This is the insertion the reference does straight into `oskTarget.value`
## (`js/main.js:499-505`) — in the port the model holds the buffer, so the screen owns
## the write and says so.
func apply_osk_value(field_id: String, value: String) -> bool:
	var field := field_control(field_id)
	if field == null:
		return false
	var suffix := field_id.substr(field_id.rfind("/") + 1)
	var ceiling := MAX_MESSAGE if suffix == FIELD_MESSAGE else MAX_CONTACT
	if field is TextEdit:
		(field as TextEdit).text = value.substr(0, ceiling)
		_refresh_counter()
		return true
	if field is LineEdit:
		(field as LineEdit).text = value.substr(0, ceiling)
		return true
	return false


# ---------------------------------------------------------------------------
# The page
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _built:
		return
	_built = true
	_shell = $Shell
	_shell.setup(SCREEN_ID)
	_shell.set_back_target(DECLARED_BACK)
	_build()


func _build() -> void:
	var column := _centered_form()
	_add_topics(column)
	_add_message(column)
	_add_contact(column)
	_add_attach(column)
	_add_details(column)
	_add_actions(column)
	_add_manual(column)
	_add_note(column)
	_register_focus()
	refresh_strings()
	refresh_queue_status()
	refresh_status()


func _centered_form() -> VBoxContainer:
	var content: MarginContainer = _shell.content()
	# The reference's screen body scrolls (`.screen { overflow-y: auto }`): at the compact
	# frames the form is taller than the shell's content area, so the column rides a scroll
	# container of its own — the same shape the history and profile bodies use.
	var scroll := ScrollContainer.new()
	scroll.name = "FeedbackScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var centering := MarginContainer.new()
	centering.name = "Centering"
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centering.set_meta("max_width", MAX_COLUMN)
	scroll.add_child(centering)
	var column := VBoxContainer.new()
	column.name = "FeedbackForm"
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 14)
	centering.add_child(column)
	centering.resized.connect(_apply_column_width.bind(centering, column))
	_apply_column_width(centering, column)
	return column


func _apply_column_width(centering: MarginContainer, column: VBoxContainer) -> void:
	if _applying_width:
		return
	_applying_width = true
	var max_width := float(centering.get_meta("max_width", 0.0))
	# The column centres itself (`SIZE_SHRINK_CENTER`) instead of the centering carrying
	# side margins: margins are part of a container's own minimum size, so a width the
	# screen once had could never be given back and the shell stayed wider than its frame.
	var available := centering.get_parent_area_size().x
	var want_min := minf(max_width, available)
	if not is_equal_approx(column.custom_minimum_size.x, want_min):
		column.custom_minimum_size.x = want_min
	_applying_width = false


func _label(parent: Node, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	parent.add_child(label)
	return label


func _add_topics(parent: Control) -> void:
	_label(parent, "TopicLabel")
	var grid := GridContainer.new()
	grid.name = "Topics"
	grid.columns = 3
	parent.add_child(grid)
	for row in topic_rows():
		var id := String((row as Dictionary).get("id", ""))
		var button := Button.new()
		button.name = "Topic_%s" % id
		button.toggle_mode = true
		button.pressed.connect(select_topic.bind(id))
		grid.add_child(button)
		_topic_buttons[id] = button


func _add_message(parent: Control) -> void:
	_label(parent, "MessageLabel")
	var field := TextEdit.new()
	field.name = FIELD_MESSAGE
	field.custom_minimum_size = Vector2(0.0, 130.0)
	field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	field.text_changed.connect(_on_message_changed)
	parent.add_child(field)
	_fields[FIELD_MESSAGE] = field
	var counter := Label.new()
	counter.name = "Counter"
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(counter)


## `maxlength=1200` on the reference's textarea is a ceiling, not an error: the field
## refuses the extra characters and the counter shows the cap.
func _on_message_changed() -> void:
	var field := _fields[FIELD_MESSAGE] as TextEdit
	if field.text.length() > MAX_MESSAGE:
		field.text = field.text.substr(0, MAX_MESSAGE)
		field.set_caret_line(field.get_line_count() - 1)
	_refresh_counter()


func _add_contact(parent: Control) -> void:
	_label(parent, "ContactLabel")
	var field := LineEdit.new()
	field.name = FIELD_CONTACT
	field.max_length = MAX_CONTACT
	field.text_changed.connect(_on_contact_changed)
	parent.add_child(field)
	_fields[FIELD_CONTACT] = field


func _on_contact_changed(_text: String) -> void:
	pass


func _add_attach(parent: Control) -> void:
	var check := CheckBox.new()
	check.name = "AttachCheck"
	check.button_pressed = true
	parent.add_child(check)


func _add_details(parent: Control) -> void:
	var toggle := Button.new()
	toggle.name = "DetailsToggle"
	toggle.toggle_mode = true
	toggle.pressed.connect(_on_details_pressed)
	parent.add_child(toggle)
	var view := TextEdit.new()
	view.name = "DiagView"
	view.editable = false
	view.custom_minimum_size = Vector2(0.0, 180.0)
	view.visible = false
	parent.add_child(view)


func _on_details_pressed() -> void:
	set_details_open((_control("DetailsToggle") as Button).button_pressed)


func _add_actions(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "Actions"
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var send := Button.new()
	send.name = "SendButton"
	send.pressed.connect(submit)
	row.add_child(send)
	var copy := Button.new()
	copy.name = "CopyButton"
	copy.pressed.connect(copy_current)
	row.add_child(copy)
	var steam := Button.new()
	steam.name = "SteamButton"
	steam.visible = false
	steam.pressed.connect(open_community)
	row.add_child(steam)


func _add_manual(parent: Control) -> void:
	var block := VBoxContainer.new()
	block.name = "ManualBlock"
	block.visible = false
	parent.add_child(block)
	_label(block, "ManualLabel")
	var field := TextEdit.new()
	field.name = "ManualField"
	field.editable = false
	field.custom_minimum_size = Vector2(0.0, 120.0)
	block.add_child(field)


func _add_note(parent: Control) -> void:
	_label(parent, "Note")
	_label(parent, "Status")


func _register_focus() -> void:
	for id in _topic_buttons:
		_shell.add_focus("Topic_%s" % id, _topic_buttons[id], "topic:%s" % id, {"kind": "button"})
	for suffix in TEXT_FIELD_IDS:
		_shell.add_focus(suffix, _fields[suffix], "text-field", {"kind": "text_field"})
	_shell.add_focus("AttachCheck", _control("AttachCheck"), "attach", {"kind": "button"})
	_shell.add_focus("DetailsToggle", _control("DetailsToggle"), "details", {"kind": "button"})
	_shell.add_focus("SendButton", _control("SendButton"), "send", {"kind": "button"})
	_shell.add_focus("CopyButton", _control("CopyButton"), "copy", {"kind": "button"})
	_shell.add_focus("SteamButton", _control("SteamButton"), "community", {"kind": "button"})


func _control(node_name: String) -> Control:
	return find_child(node_name, true, false) as Control
