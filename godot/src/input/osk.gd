## osk.gd — the on-screen keyboard as a model: the reference's key grid, its
## shift/space/backspace/done behaviour, and the text it holds for the field it was
## opened for. No scene, no Control, no text field.
##
## The reference marks touch and the on-screen keyboard a *postponed platform
## decision* (`docs/wayfinder/tickets/product-scope-and-platforms.md`), so this is
## the MODEL and nothing else: the rows, the labels, the editing rules and the
## focus hand-off are the reference's (`js/main.js:430-542`), and no key, no layout
## and no input method is invented on top of them. Building the visual grid is the
## UI lane's, and remains postponed until the platform answer says otherwise.
##
## Ported behaviour, with its anchor:
##
##   OSK_ROWS (`js/main.js:430-437`): five rows, digits, qwerty, the two home rows
##     and the accented/symbol row the reference needs for an e-mail address.
##   `oskShift` uppercases the *character* keys (`js/main.js:451-455,486`) and is
##     not cleared by typing: the reference leaves it on until it is toggled back.
##   `oskInsert` refuses the whole insertion when it would exceed `maxLength`
##     (`js/main.js:459-466`) — it does not truncate the text.
##   `oskDelete` removes one character and is a no-op on an empty field
##     (`js/main.js:468-473`).
##   `openOsk` clears shift, composes the label from the field's own name plus the
##     hint (`js/main.js:512-524`) and hands the focus to the keyboard;
##     `closeOsk` gives the field back (`js/main.js:533-542`).
##   `done` is `closeOsk` (`js/main.js:497`).
##
## API for the UI lane:
##
##   var osk := Osk.new()
##   osk.open_for("fbMessage", "", 400, "Messaggio")   # field id, value, max, label
##   osk.is_open()                                     # -> true
##   osk.press_char("q")                               # -> true, value "q"
##   osk.toggle_shift() ; osk.press_char("q")          # -> value "qQ"
##   osk.press("backspace")                            # -> true, value "q"
##   osk.press("done")                                 # -> "closed", osk.is_open() false
##   osk.label()                                       # "Messaggio · Stick per muoverti …"
##   osk.close()                                       # -> "fbMessage": the field to refocus
##   osk.rows()                                        # rows of {char, label, shifted}
extends RefCounted

const InputStrings := preload("res://src/input/strings.gd")

## `OSK_ROWS` (`js/main.js:430-437`), verbatim, in the reference's order.
const ROWS := [
	"1234567890",
	"qwertyuiop",
	"asdfghjkl",
	"zxcvbnm",
	"àèéìòù@._-+",
]

## The action row (`js/main.js:493-498`): id, then the locale id of its label.
const ACTION_KEYS := [
	{"id": "shift", "label_id": "oskShift"},
	{"id": "space", "label_id": "oskSpace"},
	{"id": "backspace", "label_id": "oskBackspace"},
	{"id": "done", "label_id": "oskDone"},
]

## `Number(maxLength) > 0 ? … : Infinity` (`js/main.js:461`).
const UNBOUNDED := 0

var _open := false
var _target_id := ""
var _value := ""
var _max_length := UNBOUNDED
var _field_label := ""
var _shift := false


## `openOsk(field)` (`js/main.js:512-531`). The caller decides *when* — the
## reference opens it only when a pad is connected and the focus is on a text
## field (`js/main.js:701-704`), and that decision belongs to `menu_nav.gd`.
func open_for(target_id: String, value: String, max_length: int = UNBOUNDED, field_label: String = "") -> void:
	_open = true
	_target_id = target_id
	_value = value
	_max_length = max_length
	_field_label = field_label
	_shift = false


## `closeOsk()` (`js/main.js:533-542`): closes and reports the field that had the
## focus, so the caller can give it back. `""` when nothing was open.
func close() -> String:
	if not _open:
		return ""
	_open = false
	var previous := _target_id
	_target_id = ""
	_shift = false
	return previous


## `oskOpen()` (`js/main.js:444-446`).
func is_open() -> bool:
	return _open


func target_id() -> String:
	return _target_id


func value() -> String:
	return _value


func max_length() -> int:
	return _max_length


func shift() -> bool:
	return _shift


## `oskRefresh`'s shift toggle (`js/main.js:455,494`).
func toggle_shift() -> bool:
	_shift = not _shift
	return _shift


## `oskInsert(text)` (`js/main.js:459-466`): the whole insertion is refused when it
## would not fit. Returns whether it was accepted.
func insert(text: String) -> bool:
	if not _open or text == "":
		return false
	if _max_length > 0 and _value.length() + text.length() > _max_length:
		return false
	_value += text
	return true


## The character keys go through the shift state (`js/main.js:486`); the action
## keys do not.
func press_char(char: String) -> bool:
	return insert(char.to_upper() if _shift else char)


## `oskDelete()` (`js/main.js:468-473`): one character, no-op when empty.
func delete_char() -> bool:
	if not _open or _value == "":
		return false
	_value = _value.substr(0, _value.length() - 1)
	return true


## The action row (`js/main.js:493-508`). Returns what happened: `"shift"`,
## `"space"`, `"backspace"`, `"done"`, `"closed"` or `""` when nothing happened.
func press(key_id: String) -> String:
	if not _open:
		return ""
	match key_id:
		"shift":
			toggle_shift()
			return "shift"
		"space":
			insert(" ")
			return "space"
		"backspace":
			delete_char()
			return "backspace"
		"done":
			close()
			return "closed"
	return ""


## `buildOsk` + `oskRefresh` (`js/main.js:475-509`): the grid as data, character
## keys already shifted, action keys named through the locale seam.
func rows(lang: String = "") -> Array:
	var out: Array = []
	for row in ROWS:
		var keys: Array = []
		for char in row:
			keys.append({"char": char, "label": char.to_upper() if _shift else char, "shifted": _shift})
		out.append({"kind": "chars", "keys": keys})
	var actions: Array = []
	for key in ACTION_KEYS:
		actions.append({
			"id": String(key["id"]),
			"label_id": String(key["label_id"]),
			"label": InputStrings.text(String(key["label_id"]), lang),
		})
	out.append({"kind": "actions", "keys": actions})
	return out


## The keyboard's own name for a screen reader (`ariaOsk`, `index.html`) and the
## label `openOsk` writes into `#oskLabel`.
func aria_label(lang: String = "") -> String:
	return InputStrings.text(InputStrings.OSK_ARIA, lang)


func label(lang: String = "") -> String:
	return InputStrings.osk_label(_field_label, lang)


## The character keys a pad or a click can press, in row order — the enumeration
## the audit walks to prove every key of the reference's grid exists.
func chars() -> Array:
	var out: Array = []
	for row in ROWS:
		for char in row:
			out.append(char)
	return out
