extends SceneTree
## jukebox_transport_test.gd — the Jukebox transport: click-to-seek and hold/release.
##
## Run (checks only):
##   godot --headless --path godot --script res://tests/jukebox_transport_test.gd
## Run (checks + the 1280x720 capture, real renderer):
##   godot --rendering-driver opengl3 --path godot --resolution 1280x720 \
##     --script res://tests/jukebox_transport_test.gd
##
## WHAT THIS OWNS. The two catalogue suites and `jukebox_player_test.gd` already cover
## the player card's readout, badges, selection/playback split and layout, and are left
## alone. This suite covers the transport additions only: seeking by click, holding and
## releasing, seeking while held, and the states around them.
##
## THE CLICKS ARE REAL EVENTS. Every seek below is delivered with
## `Viewport.push_input()` at the bar's own global rect, so it travels the engine's GUI
## path into `_progress_bar.gui_input` exactly as a player's click does — the handler is
## never called directly.
##
## MEASURED BEHAVIOUR, NOT ASSUMED. On Godot 4.7 a held `AudioStreamPlayer` reports
## `playing == false` and refuses `seek()` until it is released, which is why this suite
## checks "still held after a seek" and "resumes at the sought position" rather than
## expecting the engine to jump while frozen.

const JukeboxScene := preload("res://src/ui/jukebox/JukeboxScreen.tscn")
const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")

const TITAN := "ost_sawano_titan_breach"
const MENU := "ost_menu"
## A track id no asset satisfies: the file-less branch, borrowed from the real catalogue.
const MISSING := "ost_probe_missing_file"
const TOL := 0.75

var _checks: int = 0
var _failures: int = 0
var _notes: Array[String] = []
var _captured: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	print("[jukebox_transport_test] start headless=%s" % str(DisplayServer.get_name() == "headless"))
	root.size = Vector2i(1280, 720)
	var juke := JukeboxScene.instantiate()
	root.add_child(juke)
	await _settle(3)

	await _check_idle_guard(juke)
	await _check_pause_holds(juke)
	await _check_click_seek(juke)
	await _check_seek_while_held(juke)
	await _check_stop_then_replay(juke)
	await _check_selection_independent_seek(juke)
	await _check_fresh_track_while_held(juke)
	await _check_missing_track_safe(juke)
	await _check_bar_value_compatibility(juke)
	await _check_missing_request_while_held(juke)
	await _check_held_stop_is_silent(juke)
	await _check_keyboard_and_drag_flags(juke)
	await _native_capture(juke)

	juke.free()
	await _settle(2)
	print("[jukebox_transport_test] Results: %d checks, %d failures." % [_checks, _failures])
	for n in _notes:
		print("note: %s" % n)
	for c in _captured:
		print("capture: %s" % c)
	if _failures == 0:
		print("PASS all jukebox transport checks!")
	else:
		print("FAIL jukebox transport checks.")
	quit(1 if _failures > 0 else 0)


## "No fake action": with nothing loaded the bar is not seekable, shows an arrow cursor
## and does nothing when clicked.
func _check_idle_guard(juke: Control) -> void:
	_check(juke._manager.current_track_id() == "", "idle: nessuna traccia caricata")
	_check(not juke._seekable(), "idle: la barra non e cercabile")
	_check(juke._progress_bar.mouse_default_cursor_shape == Control.CURSOR_ARROW, "idle: cursore a freccia, nessuna falsa azione")
	_check(juke._pause_btn.disabled, "idle: il controllo Pausa e disabilitato")
	await _click_bar(juke, 0.5, true)
	await _click_bar(juke, 0.5, false)
	await _settle(2)
	_check(juke._manager.current_track_id() == "", "idle: il clic sulla barra non avvia nulla")
	_check(juke._progress_bar.value == 0.0, "idle: la barra resta a zero")


## The transport must be reachable and visibly focusable.
func _check_focus_cues(juke: Control) -> void:
	var box: StyleBox = juke._progress_bar.get_theme_stylebox("focus")
	_check(juke._progress_bar.focus_mode == Control.FOCUS_ALL, "la barra accetta il focus")
	_check(box != null and box.border_width_left > 0, "la barra ha un anello di focus visibile")
	juke._progress_bar.grab_focus()
	await _settle(2)
	_check(juke._progress_bar.has_focus(), "la barra prende il focus da tastiera")


## Hold: the stream freezes and stays frozen, and the readout keeps reporting it.
func _check_pause_holds(juke: Control) -> void:
	await _start_track(juke, TITAN)
	await _settle(2)
	var duration := float(juke._manager.playback_duration())
	juke._on_pause_pressed()
	await _settle(2)
	_check(bool(juke._manager.is_paused()), "pausa: lo stato e 'in pausa'")
	_check(not bool(juke._manager.is_playing()), "pausa: l'audio non sta avanzando")
	_check(String(juke._pause_btn.text).contains("Riprendi"), "pausa: il controllo invita a riprendere")
	_check(not juke._stop_btn.disabled, "pausa: Stop resta disponibile su una traccia ferma")
	var held_at := float(juke._manager.playback_position())
	_check(held_at > 0.0, "pausa: la posizione e quella raggiunta (%.2fs)" % held_at)
	_check(absf(float(juke._progress_bar.value) - float(juke._manager.playback_progress()) * 100.0) < 0.5, "pausa: la barra resta sulla frazione raggiunta")
	await create_timer(0.6).timeout
	var still := float(juke._manager.playback_position())
	_check(absf(still - held_at) <= 0.05, "pausa: il tempo e fermo (%.3f -> %.3f, durata %.1fs)" % [held_at, still, duration])

	# Release from here; this is the "resume same position" case.
	juke._on_pause_pressed()
	await create_timer(0.4).timeout
	var resumed := float(juke._manager.playback_position())
	_check(not bool(juke._manager.is_paused()), "riprendi: lo stato torna in riproduzione")
	_check(bool(juke._manager.is_playing()), "riprendi: l'audio riparte davvero")
	_check(resumed >= held_at - 0.05 and resumed <= held_at + 0.9, "riprendi: riparte dallo stesso punto (%.3f, atteso ~%.3f)" % [resumed, held_at])


## Click-to-seek at 25% and 75%, delivered as real GUI mouse events.
func _check_click_seek(juke: Control) -> void:
	await _start_track(juke, TITAN)
	juke._progress_bar.grab_focus()
	await _settle(2)
	_check(juke._seekable(), "seek: la barra e cercabile mentre suona")
	_check(juke._progress_bar.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "seek: cursore a mano mentre e cercabile")
	for frac: float in [0.25, 0.75]:
		var duration := float(juke._manager.playback_duration())
		await _click_bar(juke, frac, true)
		await _click_bar(juke, frac, false)
		await create_timer(0.25).timeout
		var position := float(juke._manager.playback_position())
		var wanted := duration * frac
		_check(absf(position - wanted) <= TOL + 0.3, "seek: clic a %d%% porta a %.1fs (atteso ~%.1fs)" % [int(frac * 100.0), position, wanted])
		_check(absf(float(juke._progress_bar.value) - frac * 100.0) <= 2.0, "seek: la barra segue il clic al %d%% (%.1f)" % [int(frac * 100.0), float(juke._progress_bar.value)])
		_check(String(juke._elapsed_label.text) == juke._fmt_time(position), "seek: l'etichetta elapsed resta quella reale")
		_check(bool(juke._manager.is_playing()), "seek: la riproduzione continua dopo il salto")


## A seek requested while held must keep the stream held and be honoured on release.
func _check_seek_while_held(juke: Control) -> void:
	await _start_track(juke, TITAN)
	await create_timer(0.4).timeout
	juke._on_pause_pressed()
	await _settle(2)
	var held_at := float(juke._manager.playback_position())
	await _click_bar(juke, 0.5, true)
	await _click_bar(juke, 0.5, false)
	await _settle(2)
	var duration := float(juke._manager.playback_duration())
	var reported := float(juke._manager.playback_position())
	_check(bool(juke._manager.is_paused()), "seek in pausa: resta in pausa")
	_check(not bool(juke._manager.is_playing()), "seek in pausa: nessun audio riparte")
	_check(absf(reported - duration * 0.5) <= TOL, "seek in pausa: la posizione richiesta e quella mostrata (%.1fs)" % reported)
	_check(absf(reported - held_at) > 1.0, "seek in pausa: la posizione e davvero cambiata (da %.2fs a %.2fs)" % [held_at, reported])
	_check(absf(float(juke._progress_bar.value) - 50.0) <= 2.0, "seek in pausa: la barra mostra il 50%")
	await create_timer(0.5).timeout
	_check(absf(float(juke._manager.playback_position()) - reported) <= 0.05, "seek in pausa: il tempo resta fermo sul nuovo punto")
	juke._on_pause_pressed()
	await create_timer(0.4).timeout
	var resumed := float(juke._manager.playback_position())
	_check(not bool(juke._manager.is_paused()), "seek in pausa: il rilascio toglie la pausa")
	_check(resumed >= reported - 0.05 and resumed <= reported + 0.9, "seek in pausa: riprende dal punto cercato (%.2f, atteso ~%.2f)" % [resumed, reported])


## Stop ends the transport state; a following play starts a fresh, unheld stream.
func _check_stop_then_replay(juke: Control) -> void:
	await _start_track(juke, TITAN)
	await _click_bar(juke, 0.5, true)
	await _click_bar(juke, 0.5, false)
	juke._on_pause_pressed()
	await _settle(2)
	_check(bool(juke._manager.is_paused()), "stop: la traccia era in pausa prima dello stop")
	juke._on_stop_pressed()
	await _settle(2)
	_check(not bool(juke._manager.is_paused()), "stop: azzera lo stato di pausa")
	_check(juke._manager.current_track_id() == "", "stop: nessuna traccia attiva")
	_check(juke._progress_bar.value == 0.0, "stop: barra a zero")
	_check(juke._pause_btn.disabled and juke._stop_btn.disabled, "stop: i controlli di trasporto si disabilitano")
	juke._on_play_pressed()
	await create_timer(0.5).timeout
	var position := float(juke._manager.playback_position())
	_check(not bool(juke._manager.is_paused()), "stop+play: la nuova riproduzione non eredita la pausa")
	_check(bool(juke._manager.is_playing()), "stop+play: sta suonando")
	_check(position >= 0.0 and position < 3.0, "stop+play: riparte dall'inizio (%.2fs)" % position)
	_check(not _any_player_frozen(juke), "stop+play: nessun player resta congelato")


## The bar targets the ACTIVE stream, not the selected row.
func _check_selection_independent_seek(juke: Control) -> void:
	await _start_track(juke, TITAN)
	var ids := SoundtrackManager.all_track_ids()
	juke._select_track(ids.find(MENU))
	await _settle(2)
	_check(juke._manager.current_track_id() == TITAN, "selezione: la riproduzione resta la traccia attiva")
	_check(juke._title_label.text == String(SoundtrackManager.track_info(MENU).get("title")), "selezione: il pannello mostra la riga selezionata")
	await _click_bar(juke, 0.6, true)
	await _click_bar(juke, 0.6, false)
	await create_timer(0.25).timeout
	var duration := float(juke._manager.playback_duration())
	var position := float(juke._manager.playback_position())
	_check(absf(position - duration * 0.6) <= TOL + 0.3, "selezione: il clic cerca nella traccia ATTIVA (%.1fs di %.1fs)" % [position, duration])
	_check(juke._manager.current_track_id() == TITAN, "selezione: il salto non ha cambiato traccia")


## A fresh track asked for while one is held must open playing, not silent.
func _check_fresh_track_while_held(juke: Control) -> void:
	await _start_track(juke, TITAN)
	await create_timer(0.4).timeout
	juke._on_pause_pressed()
	await _settle(2)
	_check(bool(juke._manager.is_paused()), "traccia nuova: la precedente era in pausa")
	var ids := SoundtrackManager.all_track_ids()
	juke._select_track(ids.find(MENU))
	juke._on_play_pressed()
	await create_timer(0.6).timeout
	_check(juke._manager.current_track_id() == MENU, "traccia nuova: e quella caricata")
	_check(not bool(juke._manager.is_paused()), "traccia nuova: parte senza ereditare la pausa")
	_check(bool(juke._manager.is_playing()), "traccia nuova: suona davvero")
	_check(float(juke._manager.playback_position()) > 0.0, "traccia nuova: il tempo avanza")
	_check(not _any_player_frozen(juke), "traccia nuova: nessun player resta congelato dalla pausa precedente")


## Idle after a stop, plus a row with no file: the bar must offer nothing and survive a
## click on it.
func _check_missing_track_safe(juke: Control) -> void:
	juke._on_stop_pressed()
	await _settle(2)
	juke._track_ids.append(MISSING)
	var missing_idx: int = juke._track_ids.size() - 1
	juke._select_track(missing_idx)
	await _settle(2)
	_check(not SoundtrackManager.has_track(MISSING), "file mancante: la traccia di prova non ha audio")
	_check(not juke._seekable(), "file mancante: la barra non e cercabile")
	_check(juke._pause_btn.disabled, "file mancante: Pausa disabilitata")
	await _click_bar(juke, 0.7, true)
	await _click_bar(juke, 0.7, false)
	await _settle(2)
	_check(juke._manager.current_track_id() == "", "file mancante: il clic non avvia nulla")
	_check(juke._progress_bar.value == 0.0, "file mancante: la barra resta a zero")
	juke._track_ids.remove_at(missing_idx)
	juke._select_track(0)
	await _settle(2)


## The bar keeps reporting the stream's own fraction (the value the existing player
## suite also reads).
func _check_bar_value_compatibility(juke: Control) -> void:
	await _start_track(juke, TITAN)
	await create_timer(0.4).timeout
	juke._refresh_readout()
	var expected := float(juke._manager.playback_progress()) * 100.0
	var actual := float(juke._progress_bar.value)
	_check(actual >= 0.0 and actual <= 100.0, "barra: valore nella banda 0..100 (%.2f)" % actual)
	_check(absf(actual - expected) <= 0.5, "barra: valore = frazione reale dello stream (%.2f vs %.2f)" % [actual, expected])


## A request for a track that cannot be loaded, made while another is HELD, must be
## refused without touching the transport: the held track keeps its position, stays
## frozen, and no audio is released.
func _check_missing_request_while_held(juke: Control) -> void:
	await _start_track(juke, TITAN)
	await create_timer(0.4).timeout
	juke._on_pause_pressed()
	await _settle(2)
	var held_id := String(juke._manager.current_track_id())
	var held_at := float(juke._manager.playback_position())
	var accepted := bool(juke._manager.play_track(MISSING, 0.05))
	await _settle(2)
	_check(not accepted, "richiesta mancante in pausa: rifiutata (false)")
	_check(String(juke._manager.current_track_id()) == held_id, "richiesta mancante in pausa: la traccia tenuta resta quella")
	_check(bool(juke._manager.is_paused()), "richiesta mancante in pausa: resta in pausa")
	_check(absf(float(juke._manager.playback_position()) - held_at) <= 0.05, "richiesta mancante in pausa: la posizione non si muove")
	_check(_any_player_frozen(juke), "richiesta mancante in pausa: i player restano congelati")
	juke._on_pause_pressed()
	await create_timer(0.3).timeout
	_check(bool(juke._manager.is_playing()), "richiesta mancante in pausa: il rilascio riprende normalmente")


## Stopping a HELD stream must silence it outright — no fade, no short resumption — and
## leave both players released so the next play cannot open frozen.
func _check_held_stop_is_silent(juke: Control) -> void:
	await _start_track(juke, TITAN)
	await create_timer(0.4).timeout
	juke._on_pause_pressed()
	await _settle(2)
	_check(bool(juke._manager.is_paused()), "stop in pausa: la traccia era in pausa")
	juke._on_stop_pressed()
	# Deliberately no await: this is the state immediately after the stop.
	_check(not _any_player_playing(juke), "stop in pausa: nessun player suona subito dopo lo stop")
	_check(not _any_player_frozen(juke), "stop in pausa: i player sono rilasciati (nessun congelamento residuo)")
	_check(juke._manager.current_track_id() == "", "stop in pausa: nessuna traccia attiva")
	_check(not bool(juke._manager.is_paused()), "stop in pausa: lo stato di pausa e azzerato")
	await create_timer(0.3).timeout
	_check(not _any_player_playing(juke), "stop in pausa: nessun audio riemerge durante il fade")
	_check(absf(float(juke._manager.playback_position())) < 0.01, "stop in pausa: la posizione e azzerata")
	_check(not bool(juke._manager.is_active()), "stop in pausa: il trasporto non e piu attivo")


## Keyboard seeking and the drag flag: the bar keeps focus, so it owes the keyboard the
## same action, and a drag must not survive a stop.
func _check_keyboard_and_drag_flags(juke: Control) -> void:
	# A refused pause at idle must not change what the transport says.
	var pause_text := String(juke._pause_btn.text)
	var line_text := String(juke._now_playing_label.text)
	juke._on_pause_pressed()
	await _settle(2)
	_check(String(juke._pause_btn.text) == pause_text, "pausa rifiutata: l'etichetta non cambia")
	_check(String(juke._now_playing_label.text) == line_text, "pausa rifiutata: la riga di stato non cambia")
	_check(not bool(juke._manager.is_active()), "idle: il trasporto non e attivo")

	await _start_track(juke, TITAN)
	await create_timer(0.4).timeout
	_check(bool(juke._manager.is_active()), "in riproduzione: il trasporto e attivo")
	juke._progress_bar.grab_focus()
	await _settle(2)
	var duration := float(juke._manager.playback_duration())
	await _press_key(juke, KEY_END)
	await create_timer(0.2).timeout
	var end_position := float(juke._manager.playback_position())
	_check(end_position > duration - 3.0, "tastiera: Fine porta in fondo alla traccia (%.1fs di %.1fs)" % [end_position, duration])
	await _press_key(juke, KEY_HOME)
	await create_timer(0.2).timeout
	var home_position := float(juke._manager.playback_position())
	_check(home_position < 2.0, "tastiera: Home riporta all'inizio (%.2fs)" % home_position)
	await _press_key(juke, KEY_RIGHT)
	await create_timer(0.2).timeout
	_check(float(juke._manager.playback_position()) >= home_position + 3.0, "tastiera: freccia destra avanza di 5s")

	await _click_bar(juke, 0.3, true)
	_check(bool(juke._dragging), "trascinamento: il flag e attivo durante il click")
	juke._on_stop_pressed()
	_check(not bool(juke._dragging), "trascinamento: lo stop azzera il flag")
	await _settle(2)


func _any_player_playing(juke: Control) -> bool:
	for player_name in ["MusicPlayerA", "MusicPlayerB"]:
		var player: AudioStreamPlayer = juke._manager.get_node_or_null(player_name)
		if player != null and player.playing:
			return true
	return false


## A real key event, pushed through the viewport to the focused control.
func _press_key(juke: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event, false)
	await process_frame


# ---------------------------------------------------------------------------
# harness
# ---------------------------------------------------------------------------

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("  ok: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _settle(frames: int = 3) -> void:
	for _i in frames:
		await process_frame


## Plays a catalogue track through the screen's own Play path and waits for audio.
func _start_track(juke: Control, track_id: String) -> void:
	var ids := SoundtrackManager.all_track_ids()
	juke._select_track(ids.find(track_id))
	juke._on_play_pressed()
	await create_timer(0.5).timeout
	juke._refresh_readout()


## A REAL mouse event, pushed through the viewport so it reaches the bar's own
## `gui_input` the way a player's click does.
func _click_bar(juke: Control, frac: float, pressed_state: bool) -> void:
	var rect: Rect2 = juke._progress_bar.get_global_rect()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed_state
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed_state else 0
	event.position = Vector2(rect.position.x + rect.size.x * clampf(frac, 0.0, 1.0), rect.position.y + rect.size.y * 0.5)
	event.global_position = event.position
	root.push_input(event, false)
	await process_frame


func _any_player_frozen(juke: Control) -> bool:
	for player_name in ["MusicPlayerA", "MusicPlayerB"]:
		var player: AudioStreamPlayer = juke._manager.get_node_or_null(player_name)
		if player != null and player.stream_paused:
			return true
	return false


# ---------------------------------------------------------------------------
# native capture
# ---------------------------------------------------------------------------

func _native_capture(juke: Control) -> void:
	if DisplayServer.get_name() == "headless":
		_notes.append("native capture skipped: headless dummy driver renders blank frames")
		return
	await _start_track(juke, TITAN)
	await _check_focus_cues(juke)
	# Mid-track, so the capture shows a real position on the bar rather than 0:00.
	await _click_bar(juke, 0.4, true)
	await _click_bar(juke, 0.4, false)
	await create_timer(0.6).timeout
	juke._refresh_readout()
	var dir := ProjectSettings.globalize_path("res://").path_join("../docs/agent-work/jukebox-player/captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	var tex := root.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		_check(false, "capture: il viewport non ha prodotto immagine")
		return
	var path := "%s/jukebox-transport-1280x720.png" % dir
	var err := img.save_png(path)
	var colours := _sample_colours(img)
	_check(err == OK and colours > 8, "capture 1280x720 non vuota (%d colori campionati) -> %s" % [colours, path])
	if err == OK:
		_captured.append("%s (%dx%d, %d colori)" % [path, img.get_width(), img.get_height(), colours])


func _sample_colours(img: Image) -> int:
	var colours := {}
	var step_x := maxi(img.get_width() / 24, 1)
	var step_y := maxi(img.get_height() / 14, 1)
	var x := 0
	while x < img.get_width():
		var y := 0
		while y < img.get_height():
			colours[img.get_pixel(x, y).to_rgba32()] = true
			y += step_y
		x += step_x
	return colours.size()
