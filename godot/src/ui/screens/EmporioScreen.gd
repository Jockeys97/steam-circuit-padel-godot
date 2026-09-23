## EmporioScreen.gd — the Emporio OST: the shop that sells the soundtrack.
##
## WHAT IT IS. An overlay screen over the initial menu, built the same way the Jukebox
## is (`main_menu.gd::toggle_jukebox`): the menu mounts it, it sits in `ScreenShell`
## chrome, its Back control and Escape close it, and the menu's right-stick host treats
## it as the modal surface so the right stick scrolls the shelf.
##
## IT OWNS NO RULE. Every number and every decision comes from
## `godot/src/economy/economy_service.gd`: the shelf (`shop_rows`), the price, whether a
## track is owned or affordable, and the purchase itself. This screen renders answers and
## asks for a purchase; it never decides a price and never writes a save group itself.
##
## CONFIRM BEFORE DEBIT. Pressing a buyable row does not buy it: it opens a confirmation
## panel naming the track and its price, and only `Conferma` calls `purchase()`. Cancel
## and Escape back out with nothing written.
##
## LITERALS. The strings here are Italian/English pairs resolved by `_t()`, the same
## convention the Jukebox screen uses (the reference's locale table is generated and
## carries no shop keys; the OST lane carries its own text, as the Jukebox already does).
extends Control

## Emitted when the player leaves: the Back control, Escape, or `ui_cancel`. The host
## (`main_menu.gd`) frees the overlay.
signal closed

const Economy := preload("res://src/economy/economy_service.gd")
const Catalog := preload("res://src/economy/ost_catalog.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")
const Config := preload("res://game/match_config.gd")

const SCREEN_ID := "emporio"
const BACK_TARGET := "menu"

## Palette sampled from the theme's own navy/cyan (same source the Jukebox uses).
const NAVY_DEEP := Color(0.02352941, 0.07843137, 0.14901961)
const NAVY_ROW := Color(0.04313725, 0.14117648, 0.26666668)
const CYAN := Color(0.0, 0.89803922, 1.0)
const GOLD := Color(1.0, 0.88, 0.55)
const INK := Color(0.9647059, 0.96862745, 0.98431373)
const MUTED := Color(1.0, 1.0, 1.0, 0.48)
const LINE := Color(1.0, 1.0, 1.0, 0.12)

var _store: RefCounted = null
var _lang: String = "it"
var _shell: Control = null
var _list_box: VBoxContainer = null
var _balance_label: Label = null
var _status_label: Label = null
var _confirm_panel: PanelContainer = null
var _confirm_label: Label = null
var _confirm_btn: Button = null
var _cancel_btn: Button = null
var _rows: Array = []
var _row_buttons: Array[Button] = []
var _pending_id: String = ""
var _last_purchase: Dictionary = {}
## Set once the player leaves, so a second cancel/back cannot emit `closed` twice.
var _closing: bool = false


func _ready() -> void:
	theme = DefaultTheme
	# The overlay OWNS input while it is up: `_input` consumes cancel so nothing leaks
	# past the modal, and the host withholds its own focus dispatch (see
	# `main_menu.gd::_overlay_owns_input`). Accept is deliberately NOT consumed here so
	# the GUI still delivers `ui_accept` to the focused row/confirm button.
	set_process_input(true)
	set_process_unhandled_input(true)
	if _store == null:
		_store = Config.save_store()
	_lang = _read_lang()
	_build_ui()
	refresh()
	_focus_first_row()


## The store a test hands in (an isolated directory). Never the real profile unless the
## caller leaves it unset, in which case the config's own store is used.
func set_store(store: RefCounted) -> void:
	_store = store
	if _shell != null:
		_lang = _read_lang()
		refresh()


func store() -> RefCounted:
	return _store if _store != null else Config.save_store()


## The rows last rendered, so a test reads the same data the screen shows.
func rows() -> Array:
	return _rows.duplicate(true)


func balance_text() -> String:
	return _balance_label.text if _balance_label != null else ""


func status_text() -> String:
	return _status_label.text if _status_label != null else ""


func confirm_visible() -> bool:
	return _confirm_panel != null and _confirm_panel.visible


func pending_id() -> String:
	return _pending_id


## The last purchase result (`{}` before any), for a test that drove the confirm path.
func last_purchase() -> Dictionary:
	return _last_purchase.duplicate(true)


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.10, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_shell = ShellScene.instantiate()
	add_child(_shell)
	_shell.setup(SCREEN_ID)
	_shell.set_title_text(_t("EMPORIO OST", "OST EMPORIUM"))
	_shell.set_subtitle_text(_t(
		"Acquista le tracce con i Crediti Circuito guadagnati giocando",
		"Buy tracks with the Circuit Credits you earn by playing"))
	_shell.set_back_target(BACK_TARGET)
	var back_btn: Button = _shell.back_control()
	if back_btn != null:
		back_btn.pressed.connect(_on_back_pressed)

	var content: MarginContainer = _shell.content()
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_bottom", 16)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	content.add_child(column)

	_balance_label = Label.new()
	_balance_label.theme_type_variation = &"HeroTitle"
	_balance_label.add_theme_font_size_override("font_size", 22)
	_balance_label.add_theme_color_override("font_color", GOLD)
	column.add_child(_balance_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)

	# The shelf: a ScrollContainer so the right stick (host-side) has something to drive.
	var scroll := ScrollContainer.new()
	scroll.name = "EmporioScroll"
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_box)

	_build_confirm_panel(column)


func _build_confirm_panel(parent: VBoxContainer) -> void:
	_confirm_panel = PanelContainer.new()
	_confirm_panel.name = "EmporioConfirm"
	_confirm_panel.visible = false
	_confirm_panel.add_theme_stylebox_override("panel", _panel_style(NAVY_ROW, CYAN, 8, 1))
	parent.add_child(_confirm_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_confirm_panel.add_child(box)

	_confirm_label = Label.new()
	_confirm_label.add_theme_font_size_override("font_size", 15)
	_confirm_label.add_theme_color_override("font_color", INK)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	_confirm_btn = Button.new()
	_confirm_btn.name = "EmporioConfirmBuy"
	_confirm_btn.text = _t("Conferma", "Confirm")
	_confirm_btn.focus_mode = Control.FOCUS_ALL
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_btn)

	_cancel_btn = Button.new()
	_cancel_btn.name = "EmporioConfirmCancel"
	_cancel_btn.text = _t("Annulla", "Cancel")
	_cancel_btn.focus_mode = Control.FOCUS_ALL
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	buttons.add_child(_cancel_btn)


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func refresh() -> void:
	_rows = Economy.shop_rows(store())
	for child in _list_box.get_children():
		child.queue_free()
	_row_buttons.clear()
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var b := Button.new()
		b.name = "EmporioRow%d" % i
		b.text = _row_text(row)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 30)
		b.pressed.connect(_on_row_pressed.bind(String(row["id"])))
		_list_box.add_child(b)
		_row_buttons.append(b)
	_balance_label.text = _t("Crediti Circuito: %d", "Circuit Credits: %d") % Economy.balance(store())
	if _status_label.text == "":
		_status_label.text = _t(
			"Le tracce contrassegnate come bloccate si acquistano qui.",
			"Tracks marked locked can be bought here.")


func _row_text(row: Dictionary) -> String:
	var price := int(row["price"])
	var state := ""
	if bool(row.get("relocked", false)):
		state = _t("Bloccata (Alelu)", "Locked (Alelu)")
	elif bool(row.get("accessible", false)) and not bool(row.get("owned", false)):
		state = _t("Sbloccata", "Unlocked")
	elif bool(row.get("owned", false)):
		state = _t("Acquistata", "Owned")
	elif bool(row.get("affordable", false)):
		state = _t("%d cr", "%d cr") % price
	else:
		state = _t("%d cr — Crediti insufficienti", "%d cr — Not enough credits") % price
	return "%s — %s — %s" % [String(row["title"]), String(row["category"]), state]


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

## A row press. Owned/unlocked rows report and do nothing; an unaffordable row says so;
## a buyable row opens the confirmation instead of debiting.
func _on_row_pressed(track_id: String) -> void:
	for row in _rows:
		if String(row["id"]) != track_id:
			continue
		if bool(row.get("relocked", false)):
			_status_label.text = _t("Blocco Alelu attivo: usa Lucale per sbloccare.", "Alelu lock active: use Lucale to unlock.")
			return
		if bool(row.get("owned", false)):
			_status_label.text = _t("Già acquistata.", "Already owned.")
			return
		if bool(row.get("accessible", false)):
			_status_label.text = _t("Sbloccata: disponibile nel Jukebox.", "Unlocked: available in the Jukebox.")
			return
		if not bool(row.get("affordable", false)):
			_status_label.text = _t("Crediti insufficienti.", "Not enough credits.")
			return
		_open_confirm(row)
		return


func _open_confirm(row: Dictionary) -> void:
	_pending_id = String(row["id"])
	_confirm_label.text = _t(
		"Acquistare «%s» per %d crediti? Saldo attuale: %d.",
		"Buy \"%s\" for %d credits? Current balance: %d."
	) % [String(row["title"]), int(row["price"]), Economy.balance(store())]
	_confirm_panel.visible = true
	_confirm_btn.grab_focus()


func _on_confirm_pressed() -> void:
	if _pending_id == "":
		return
	var result: Dictionary = Economy.purchase(store(), _pending_id)
	_last_purchase = result
	_confirm_panel.visible = false
	_pending_id = ""
	_status_label.text = _purchase_status(result)
	refresh()
	_focus_first_row()


func _on_cancel_pressed() -> void:
	_confirm_panel.visible = false
	_pending_id = ""
	_status_label.text = _t("Acquisto annullato.", "Purchase cancelled.")
	_focus_first_row()


func _purchase_status(result: Dictionary) -> String:
	match String(result.get("reason", "")):
		"purchased":
			return _t("Acquisto completato. Saldo: %d.", "Purchase complete. Balance: %d.") % int(result.get("balance", 0))
		"insufficient":
			return _t("Crediti insufficienti.", "Not enough credits.")
		"owned":
			return _t("Già acquistata.", "Already owned.")
		"unlocked":
			return _t("Già sbloccata: nessun addebito.", "Already unlocked: nothing debited.")
		"write_failed":
			return _t("Acquisto non salvato: nessun addebito.", "Purchase not saved: nothing debited.")
		"refused":
			return _t("Profilo rifiutato: nessun addebito.", "Profile refused: nothing debited.")
		_:
			return _t("Acquisto non disponibile.", "Purchase unavailable.")


func _focus_first_row() -> void:
	for b in _row_buttons:
		if is_instance_valid(b):
			b.grab_focus()
			return
	var back_btn: Button = _shell.back_control()
	if back_btn != null:
		back_btn.grab_focus()


func _on_back_pressed() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()


## The overlay's own input owner. Cancel/Escape closes the confirmation if one is open
## and the screen otherwise, and the event is marked handled so it cannot also reach the
## menu behind the modal. `ui_accept` and pad navigation are left alone on purpose: the
## GUI delivers them to the focused control, which is how a pad buys a track.
func _input(event: InputEvent) -> void:
	if _closing:
		return
	var cancel := event.is_action_pressed("ui_cancel") \
		or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE)
	if not cancel:
		return
	if confirm_visible():
		_on_cancel_pressed()
	else:
		_on_back_pressed()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# The same rule as `_input`, kept as the fallback path when something earlier in the
	# GUI chain consumed `ui_cancel` without acting on it.
	_input(event)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _read_lang() -> String:
	var read: Dictionary = store().read_group("prefs")
	var payload: Variant = read.get("payload", null)
	if payload is Dictionary:
		var lang := String((payload as Dictionary).get("lang", ""))
		if lang == "en" or lang == "it":
			return lang
	return "it"


func _t(it: String, en: String) -> String:
	return it if _lang == "it" else en


func _panel_style(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
