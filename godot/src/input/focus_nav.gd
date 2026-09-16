## focus_nav.gd — the focus model of the reference's menu navigation, with no
## scene, no Control node and no DOM in it.
##
## The reference (`js/main.js`, commit 2979588) navigates its menus geometrically:
## `collectMenuTargets` (`:559-580`) decides what *can* take the focus,
## `findMenuTarget` (`:630-673`) picks the next one in a direction,
## `moveMenuFocus` (`:675-695`) moves it and reports whether it moved,
## `ensureMenuFocus` (`:592-599`) guarantees a focus exists, and
## `scrollContainer`/`scrollMenu` (`:605-627`) scroll when it cannot move.
## This file is those five functions as plain data and arithmetic, so a headless
## audit can drive them and a UI lane can call them from any Control tree.
##
## PORTED RULES, and the one thing the reference does NOT do:
##
##   - **No wrapping.** `findMenuTarget` only considers targets that are at least
##     `8` px away on the primary axis (`js/main.js:646-649`); at the edge of a
##     screen no candidate qualifies, `move_focus()` returns `false`, and the
##     caller scrolls instead (`js/main.js:2555-2557`, `:965-969`). There is no
##     wrap-around and none is invented here: a model that wrapped would hide the
##     "the focus cannot go anywhere" case the reference uses to decide to scroll.
##   - Wide targets win. A candidate that *overlaps* the focused rect on the
##     transverse axis scores by the primary distance alone; one that does not
##     pays `+3` per px of transverse distance plus `600` (`js/main.js:660-667`).
##     Before that rule a wide control — the feedback textarea — was in the target
##     list and still unreachable, which is the defect
##     `scripts/gamepad-nav-audit.mjs:155-176` exists to catch.
##   - Ties keep the first target in insertion order: the score comparison is
##     strict `<` (`js/main.js:667`).
##
## API for the UI lane — everything below is `String`/`Dictionary`/`Rect2`:
##
##   var nav := FocusNav.new()
##   nav.register_container({"id": "screen-feedback", "parent": "", "scrolls": true,
##                           "content_height": 1800, "view_height": 700})
##   nav.add_target({"id": "back", "kind": "button", "action": "to-menu",
##                   "rect": Rect2(0, 0, 120, 40), "container": "screen-feedback"})
##   nav.ensure_focus()            # -> "back"
##   nav.move_focus("down")        # -> bool: did the focus move?
##   nav.find_target("down")       # -> {…} next target, focus NOT moved
##   nav.focus()                   # -> {…} focused target or {}
##   nav.scroll(90.0)              # -> focused container's offset, or page scroll
##   nav.set_focus("msg") ; nav.activate()  # -> {"kind": "…", "target": "…"}
##
## Target descriptor keys (all optional except `id` and `rect`):
##   id              String  unique, the identity `set_focus`/`activate` use
##   rect            Rect2   position and size in the same units the reference
##                           used px for (the thresholds are px)
##   kind            String  "button" | "text_field" | "range" | "card"
##   action          String  the menu action this target fires
##   disabled        bool    the reference's `el.disabled`
##   hidden          bool    the reference's `[hidden]` ancestor
##   locked          bool    the reference's `.mode-card--locked`
##   drawn           bool    the reference's `offsetParent !== null`
##   contains_buttons bool   the reference's "a card that holds its own buttons is
##                           a container, not a target" (`js/main.js:571-577`)
##   container       String  the scrolling container this target lives in
##   min/max/step/value      only read when `kind` is "range"
extends RefCounted

const DIRECTIONS := ["up", "down", "left", "right"]

## `Math.abs(dx) < 8` / `< -8`: a candidate must move at least this far on the
## primary axis to count (`js/main.js:646-649`).
const DIRECTION_THRESHOLD := 8.0
## The centre-distance penalty of a candidate that does not overlap transversally
## (`js/main.js:666`).
const TRANSVERSE_PENALTY := 3.0
const NO_OVERLAP_PENALTY := 600.0
## `scrollContainer`: `scrollHeight > clientHeight + 2` (`js/main.js:609`).
const SCROLL_OVERFLOW_MARGIN := 2.0

var _targets: Array = []
var _containers: Array = []
var _focus_id: String = ""
var _page_scroll: float = 0.0


# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

func add_target(target: Dictionary) -> void:
	_targets.append(target.duplicate(true))


func clear_targets() -> void:
	_targets.clear()
	_focus_id = ""


## `collectMenuTargets` (`js/main.js:559-580`): what the focus may land on, in
## insertion order — which is the markup order in the reference.
func targets() -> Array:
	var out: Array = []
	for target in _targets:
		if _selectable(target):
			out.append(target)
	return out


## The reference's filter, branch for branch and in its order.
static func _selectable(target: Dictionary) -> bool:
	if bool(target.get("disabled", false)):
		return false
	if bool(target.get("hidden", false)):
		return false
	if bool(target.get("locked", false)):
		return false
	# A card that holds its own buttons is a container, not a target; in the
	# jersey and arena pickers the card *is* the button, so there it stays one.
	if String(target.get("kind", "button")) != "button" and bool(target.get("contains_buttons", false)):
		return false
	if not bool(target.get("drawn", true)):
		return false
	return true


func has_target(target_id: String) -> bool:
	for target in targets():
		if String(target["id"]) == target_id:
			return true
	return false


func focus() -> Dictionary:
	var targets_in := targets()
	for target in targets_in:
		if String(target["id"]) == _focus_id:
			return target
	return {}


func focus_id() -> String:
	return _focus_id


## `setMenuFocus` (`js/main.js:582-590`). In the reference this also paints the
## `menu-focus` class and calls `scrollIntoView`; both are the caller's, because
## they are presentation. Returns whether the focus changed.
func set_focus(target_id: String) -> bool:
	if _focus_id == target_id:
		return false
	_focus_id = target_id
	return true


func clear_focus() -> void:
	_focus_id = ""


## `ensureMenuFocus` (`js/main.js:592-599`): with no targets the focus is cleared;
## with a focus that is not in the list any more, the first target takes it.
func ensure_focus() -> String:
	var targets_in := targets()
	if targets_in.is_empty():
		_focus_id = ""
		return ""
	if not has_target(_focus_id):
		_focus_id = String(targets_in[0]["id"])
	return _focus_id


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

## `findMenuTarget` (`js/main.js:630-673`): the next target in that direction,
## without moving the focus. `{}` when nothing qualifies — the reference's signal
## that the caller should scroll instead.
func find_target(dir: String) -> Dictionary:
	var targets_in := targets()
	if targets_in.is_empty():
		return {}
	var current := focus()
	if current.is_empty():
		return targets_in[0]
	var current_rect: Rect2 = current["rect"]
	var current_centre := current_rect.position + current_rect.size * 0.5
	var best: Dictionary = {}
	var best_score := INF
	for target in targets_in:
		if String(target["id"]) == String(current["id"]):
			continue
		var rect: Rect2 = target["rect"]
		var centre := rect.position + rect.size * 0.5
		var dx := centre.x - current_centre.x
		var dy := centre.y - current_centre.y
		var qualifies := false
		match dir:
			"left":
				qualifies = dx < -DIRECTION_THRESHOLD
			"right":
				qualifies = dx > DIRECTION_THRESHOLD
			"up":
				qualifies = dy < -DIRECTION_THRESHOLD
			"down":
				qualifies = dy > DIRECTION_THRESHOLD
			_:
				qualifies = false
		if not qualifies:
			continue
		var vertical := dir == "up" or dir == "down"
		var overlap := 0.0
		if vertical:
			overlap = minf(current_rect.position.x + current_rect.size.x, rect.position.x + rect.size.x) - maxf(current_rect.position.x, rect.position.x)
		else:
			overlap = minf(current_rect.position.y + current_rect.size.y, rect.position.y + rect.size.y) - maxf(current_rect.position.y, rect.position.y)
		var along := absf(dy) if vertical else absf(dx)
		var transverse := absf(dx) if vertical else absf(dy)
		var score := along if overlap > 0.0 else along + transverse * TRANSVERSE_PENALTY + NO_OVERLAP_PENALTY
		if score < best_score:
			best_score = score
			best = target
	return best


## `moveMenuFocus` (`js/main.js:675-695`). The return value is the contract:
## it says whether the focus moved, so the caller knows when to scroll instead.
func move_focus(dir: String) -> bool:
	var targets_in := targets()
	if targets_in.is_empty():
		return false
	var current := focus()
	if current.is_empty():
		_focus_id = String(targets_in[0]["id"])
		return true
	# A range steps its own value on left/right instead of giving up the focus
	# (`js/main.js:683-689`).
	if String(current.get("kind", "")) == "range" and (dir == "left" or dir == "right"):
		_adjust_range(current, dir)
		return true
	var best := find_target(dir)
	if best.is_empty():
		return false
	_focus_id = String(best["id"])
	return true


func _adjust_range(target: Dictionary, dir: String) -> void:
	var step := float(target.get("step", 0.01))
	if step == 0.0:
		step = 0.01
	var direction := -1.0 if dir == "left" else 1.0
	var value := float(target.get("value", 0.0)) + step * direction
	value = minf(float(target.get("max", 1.0)), maxf(float(target.get("min", 0.0)), value))
	target["value"] = value


## `isTextField` (`js/main.js:545-549`), as the model's kind test: a target whose
## text is entered with the on-screen keyboard.
static func is_text_field(target: Dictionary) -> bool:
	if target.is_empty():
		return false
	if String(target.get("kind", "")) == "text_field":
		return true
	# The reference also accepts an `<input type>` in this set, and its empty
	# string — an `<input>` with no `type` is a text input in HTML.
	return ["text", "search", "email", "url", "tel", "password", ""].has(String(target.get("input_type", "")))


# ---------------------------------------------------------------------------
# Scrolling
# ---------------------------------------------------------------------------

## `{id, parent, scrolls, content_height, view_height}` — the model's stand-in for
## the DOM ancestor chain. `parent` is `""` at the page.
func register_container(container: Dictionary) -> void:
	_containers.append(container.duplicate(true))


func container(container_id: String) -> Dictionary:
	for known in _containers:
		if String(known["id"]) == container_id:
			return known
	return {}


## `scrollContainer` (`js/main.js:605-613`): the nearest ancestor that actually
## scrolls — a panel that scrolls on its own, or the page. `""` means the page.
func scroll_container_id() -> String:
	var current := focus()
	if current.is_empty():
		return ""
	var container_id := String(current.get("container", ""))
	while container_id != "":
		var known := container(container_id)
		if known.is_empty():
			return ""
		if bool(known.get("scrolls", false)) and float(known.get("content_height", 0.0)) > float(known.get("view_height", 0.0)) + SCROLL_OVERFLOW_MARGIN:
			return container_id
		container_id = String(known.get("parent", ""))
	return ""


## `scrollMenu` (`js/main.js:623-627`): the focused container if there is one,
## the page otherwise. Returns the offset applied to.
func scroll(delta: float) -> Dictionary:
	var container_id := scroll_container_id()
	if container_id == "":
		_page_scroll += delta
		return {"container": "", "offset": _page_scroll}
	for known in _containers:
		if String(known["id"]) == container_id:
			known["offset"] = float(known.get("offset", 0.0)) + delta
			return {"container": container_id, "offset": known["offset"]}
	return {"container": "", "offset": _page_scroll}


func scroll_offset(container_id: String) -> float:
	if container_id == "":
		return _page_scroll
	return float(container(container_id).get("offset", 0.0))


func page_scroll() -> float:
	return _page_scroll
