extends SceneTree
## jukebox_player_test.gd — the Jukebox player card's own suite.
##
## Run (checks only, dummy audio):
##   godot --headless --path godot --script res://tests/jukebox_player_test.gd
##
## Run (checks + the two native captures, real audio + real renderer):
##   godot --path godot --resolution 1280x720 --script res://tests/jukebox_player_test.gd
##
## WHAT THIS SUITE OWNS. The two catalogue suites already prove the 47 tracks, their
## badges and their routing (`soundtrack_manager_test.gd`, `test_jukebox_screen36.gd`)
## and are left alone. This one covers the player card the redesign introduced: the
## title/arena pair that used to render empty, the readout being the REAL stream rather
## than the selected track's metadata, selection vs playback staying distinguishable,
## the file-less branch, the volume bus handshake, the list/console cost shape, and the
## back/ESC lifecycle the overlay mount depends on.
##
## HONEST HEADLESS BOUNDARY. The dummy audio driver is present in `--headless`
## (`AudioServer.get_driver_name() == "Dummy"`), so the checks that can only be true of
## audio that is really advancing — a moving elapsed clock, a bar above zero — are
## asserted in the native (non-headless) phase, which this same script runs when it is
## given a display. In headless the suite still asserts the real stream's *length* and
## the honest stopped rendering. Nothing here claims a moving clock it did not see.

const JukeboxScene := preload("res://src/ui/jukebox/JukeboxScreen.tscn")
const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")

const SAWANO_ID := "ost_sawano_titan_breach"
const SAWANO_BADGE := "[ SAWANO / TITAN SPECIAL ]"
const DBGT_ID := "ost_dbgt_dan_dan_vocal"
const DBGT_BADGE := "[ DRAGON BALL GT / 90S ANIME ]"
const MENU_ID := "ost_menu"
## A track id no asset can satisfy — the file-less branch, borrowed rather than
## simulated: the screen still resolves title/status/readout through the real manager.
const MISSING_ID := "ost_probe_missing_file"

const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _checks: int = 0
var _failures: int = 0
var _notes: Array[String] = []
var _captured: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var headless := DisplayServer.get_name() == "headless"
	print("[jukebox_player_test] start headless=%s driver=%s" % [str(headless), AudioServer.get_driver_name()])
	await _run_checks(headless)
	await _run_native_phase()
	print("[jukebox_player_test] Results: %d checks, %d failures." % [_checks, _failures])
	for n in _notes:
		print("note: %s" % n)
	for c in _captured:
		print("capture: %s" % c)
	if _failures == 0:
		print("PASS all jukebox player checks!")
	else:
		print("FAIL jukebox player checks.")
	quit(1 if _failures > 0 else 0)


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


func _new_screen() -> Control:
	var screen: Control = JukeboxScene.instantiate()
	root.add_child(screen)
	return screen


func _settle(frames: int = 3) -> void:
	for _i in frames:
		await process_frame


func _all_ids() -> PackedStringArray:
	return SoundtrackManager.all_track_ids()


# ---------------------------------------------------------------------------
# checks (headless-safe)
# ---------------------------------------------------------------------------

func _run_checks(headless: bool) -> void:
	root.size = Vector2i(1280, 720)
	var juke := _new_screen()
	await _settle(3)

	_check_identity_and_badges(juke)
	_check_idle_state(juke)
	await _check_live_readout(juke)
	_check_selection_vs_playback(juke)
	_check_missing_file_branch(juke)
	await _check_volume_handshake()
	await _check_focus_visibility(juke)
	await _check_responsive_layout(juke)
	await _check_expanded_prompt_layout(juke)
	await _check_cost_shape(juke)
	await _check_lifecycle()

	# Astra's boundary: free the screen explicitly, then report what the engine still
	# prints at shutdown. The warnings are recorded, never attributed by guesswork.
	juke.free()
	await _settle(2)
	_notes.append("screen freed explicitly before exit; engine RID/ObjectDB/resource shutdown warnings, if any, are printed by the engine after this line")


## The pair the screen always meant to show and never assigned, plus the two badge
## contracts the existing catalogue suite pins.
func _check_identity_and_badges(juke: Control) -> void:
	var ids := _all_ids()
	_check(juke._track_buttons.size() == 98, "catalogo: 98 righe di lista (got %d)" % juke._track_buttons.size())

	var sawano_idx := ids.find(SAWANO_ID)
	juke._select_track(sawano_idx)
	var sawano_info := SoundtrackManager.track_info(SAWANO_ID)
	_check(String(juke._title_label.text) != "", "titolo traccia popolato (bug _select_track corretto)")
	_check(juke._title_label.text == String(sawano_info.get("title")), "titolo = metadati: '%s'" % juke._title_label.text)
	_check(juke._scene_label.text == "Scena: %s" % String(sawano_info.get("scene")), "scena = metadati: '%s'" % juke._scene_label.text)
	_check(juke._category_badge.text == SAWANO_BADGE, "badge categoria Sawano invariato")
	_check(juke._status_badge.text.contains("✔"), "badge stato contiene ✔ (file su disco)")

	var dbgt_idx := ids.find(DBGT_ID)
	juke._select_track(dbgt_idx)
	_check(juke._category_badge.text == DBGT_BADGE, "badge categoria Dragon Ball GT invariato")
	_check(juke._status_badge.text.contains("✔"), "badge stato DBGT contiene ✔")
	_check(_count_marked(juke) == 0, "nessuna riga marcata ▶ prima di riprodurre")


## Nothing has played yet: the readout must be honestly empty, not a plausible-looking
## zero-length stream.
func _check_idle_state(juke: Control) -> void:
	_check(juke._manager.current_track_id() == "", "stato iniziale: nessuna traccia in riproduzione")
	_check(juke._elapsed_label.text == "0:00", "readout fermo: elapsed 0:00 (got '%s')" % juke._elapsed_label.text)
	_check(juke._duration_label.text == "--:--", "readout fermo: durata sconosciuta --:--")
	_check(juke._progress_bar.value == 0.0, "readout fermo: barra a zero")
	_check(juke._stop_btn.disabled, "Stop disabilitato quando non suona nulla")
	_check(not juke._play_btn.disabled, "Play abilitato per una traccia con file")
	_check(not bool(juke._record.get("_spinning")), "il disco non gira a riproduzione ferma")
	_check(juke._hero_eyebrow.text == "TRACCIA SELEZIONATA", "a riproduzione ferma l'eyebrow dice SELEZIONATA, non IN RIPRODUZIONE")


## The readout is the stream's, not the metadata's. Where audio really advances
## (native phase) this asserts the moving clock; headless asserts what a dummy driver
## can still tell the truth about — the stream it loaded and the honest stopped state.
func _check_live_readout(juke: Control) -> void:
	var ids := _all_ids()
	juke._select_track(ids.find(SAWANO_ID))
	juke._on_play_pressed()
	_check(juke._manager.current_track_id() == SAWANO_ID, "play: il manager riproduce la traccia selezionata")

	await create_timer(0.9).timeout
	juke._refresh_readout()

	var duration: float = juke._manager.playback_duration()
	var position: float = juke._manager.playback_position()
	var progress: float = juke._manager.playback_progress()
	print("  .. readout pos=%.3f dur=%.3f prog=%.4f elapsed=%s duration=%s" % [
		position, duration, progress, juke._elapsed_label.text, juke._duration_label.text
	])
	_check(duration > 0.0, "durata = lunghezza dello stream reale (%.2fs)" % duration)
	_check(juke._duration_label.text == juke._fmt_time(duration), "etichetta durata = durata reale")
	_check(juke._elapsed_label.text == juke._fmt_time(position), "etichetta elapsed = posizione reale")

	if juke._manager.is_playing():
		_check(position > 0.0, "elapsed avanza davvero (%.3fs)" % position)
		_check(progress > 0.0 and progress <= 1.0, "progress = frazione reale dello stream (%.4f)" % progress)
		_check(absf(juke._progress_bar.value - progress * 100.0) < 0.2, "barra = percentuale reale dello stream")
		_check(not juke._stop_btn.disabled, "Stop abilitato mentre suona")
		_check(bool(juke._record.get("_spinning")), "il disco gira mentre l'audio suona")
		_check(juke._now_playing_label.text.contains("In Riproduzione"), "riga now-playing coerente")
		_check(juke._hero_eyebrow.text == "IN RIPRODUZIONE", "eyebrow IN RIPRODUZIONE solo quando la selezione e cio che suona")
		var before := String(juke._elapsed_label.text)
		await create_timer(1.3).timeout
		juke._refresh_readout()
		var after := String(juke._elapsed_label.text)
		_check(before != after, "il readout avanza con l'audio: %s -> %s" % [before, after])
	else:
		_notes.append("headless: dummy audio driver reports playing=false, so the moving-clock checks belong to the native phase; honest stopped rendering asserted here instead")
		_check(juke._progress_bar.value == 0.0, "driver muto: barra resta a zero (nessun valore inventato)")


## Selection and playback are two different facts; the card must show both at once.
func _check_selection_vs_playback(juke: Control) -> void:
	var ids := _all_ids()
	var other_idx := ids.find(MENU_ID)
	juke._select_track(other_idx)
	var menu_title := String(SoundtrackManager.track_info(MENU_ID).get("title"))
	_check(juke._title_label.text == menu_title, "il titolo mostra la SELEZIONE (%s)" % menu_title)
	_check(juke._manager.current_track_id() == SAWANO_ID, "la selezione NON cambia la riproduzione")
	_check(juke._hero_eyebrow.text == "TRACCIA SELEZIONATA", "selezione diversa dal playing: l'eyebrow non mente")

	var sawano_row := ids.find(SAWANO_ID)
	_check(String(juke._track_buttons[sawano_row].text).begins_with("▶"), "la riga in riproduzione porta il marcatore ▶")
	_check(not String(juke._track_buttons[other_idx].text).begins_with("▶"), "la riga selezionata NON porta il marcatore")
	_check(_count_marked(juke) == 1, "esattamente una riga marcata ▶")
	_check(_count_font_overrides(juke) == 1, "solo la riga in riproduzione porta la tinta di stato")
	_check(juke._track_buttons[sawano_row].has_theme_color_override("font_color"), "la tinta e sulla riga in riproduzione")
	if juke._manager.is_playing():
		_check(juke._progress_bar.value > 0.0, "il readout resta quello della traccia in riproduzione, non della selezione")


## The transport must be reachable and visibly focused — a themed focus ring on every
## control, and Play actually taking keyboard focus.
func _check_focus_visibility(juke: Control) -> void:
	for btn in [juke._prev_btn, juke._play_btn, juke._stop_btn, juke._next_btn]:
		var button := btn as Button
		var box := button.get_theme_stylebox("focus") as StyleBoxFlat
		var visible_ring: bool = box != null and (box.border_width_left > 0 or box.draw_center)
		_check(visible_ring, "anello di focus visibile su '%s'" % button.text)
	juke._play_btn.grab_focus()
	await _settle(2)
	_check(juke._play_btn.has_focus(), "Play accetta il focus da tastiera")


## The file-less branch, borrowed from the real catalogue rather than simulated: a
## track id with no asset exercises the same `has_track()`-driven title, badge,
## disabled Play and honest readout the shipped screen uses.
func _check_missing_file_branch(juke: Control) -> void:
	_check(not SoundtrackManager.has_track(MISSING_ID), "probe: la traccia di prova non ha file su disco")
	# Stop first: the file-less branch must be read while nothing else is streaming,
	# otherwise this would be measuring the previous track's audio.
	juke._on_stop_pressed()
	await _settle(2)
	juke._track_ids.append(MISSING_ID)
	var missing_idx: int = juke._track_ids.size() - 1
	juke._select_track(missing_idx)

	_check(juke._title_label.text == MISSING_ID, "titolo ripiega sull'id quando manca il metadato")
	_check(juke._play_btn.disabled, "Play disabilitato per una traccia senza file")
	_check(not juke._status_badge.text.contains("✔"), "badge stato SENZA ✔ quando il file manca")
	juke._on_play_pressed()
	_check(juke._now_playing_label.text.contains("in attesa"), "messaggio onesto di file mancante: '%s'" % juke._now_playing_label.text)
	_check(juke._elapsed_label.text == "0:00" and juke._duration_label.text == "--:--", "readout resta 0:00 / --:-- senza audio")
	_check(juke._progress_bar.value == 0.0, "barra a zero senza audio")
	_check(not bool(juke._record.get("_spinning")), "il disco NON gira senza audio")
	_check(juke._manager.current_track_id() == "", "una traccia senza file non entra in riproduzione")

	juke._track_ids.remove_at(missing_idx)
	juke._select_track(0)
	_check(not juke._play_btn.disabled, "Play torna abilitato su una traccia con file")


## The slider must open on the Music bus's real level, and dragging it must still write
## that level back — the behaviour the screen always had, now starting in step.
func _check_volume_handshake() -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	_check(bus_idx >= 0, "bus Music presente")
	var probe := _new_screen()
	await _settle(3)

	var bus_db := AudioServer.get_bus_volume_db(bus_idx)
	var slider_db := float(probe._volume_slider.value)
	var slider_step := float(probe._volume_slider.step)
	# The handle lives on the slider's own step grid, so "in step with the bus" is
	# within one step — not an exact float equality the widget could never satisfy.
	_check(
		absf(slider_db - bus_db) <= maxf(slider_step, 0.01) + 0.001,
		"slider volume inizializzato dal bus Music (bus %.2f dB, slider %.2f dB, step %.2f)" % [bus_db, slider_db, slider_step]
	)
	_check(absf(float(probe._volume_slider.value)) > 0.01, "lo slider non parte piu da 0.0 dB fisso")
	_check(probe._volume_slider.min_value == -30.0 and probe._volume_slider.max_value == 6.0, "banda dello slider invariata (-30..6 dB)")

	probe._on_volume_changed(-12.0)
	_check(absf(AudioServer.get_bus_volume_db(bus_idx) - (-12.0)) < 0.01, "muovere lo slider scrive sul bus Music (%.2f dB)" % AudioServer.get_bus_volume_db(bus_idx))

	probe._on_volume_changed(bus_db)
	probe.free()
	await _settle(2)


## Responsive: both shipped resolutions, a long title, and no control crossing the
## viewport edge.
func _check_responsive_layout(juke: Control) -> void:
	var ids := _all_ids()
	var longest_idx := _longest_title_index(ids)
	juke._select_track(longest_idx)
	for res in RESOLUTIONS:
		root.size = res
		await _settle(4)
		var vw := float(res.x)
		var vh := float(res.y)
		var offenders := PackedStringArray()
		# The catalogue's scroll CONTENT is legitimately taller than the viewport — that
		# is what the scroll container is for — so the card around it is checked instead.
		for node in [juke._list_card, juke._player_card, juke._progress_bar, juke._next_btn, juke._volume_slider, juke._title_label, juke._now_playing_label, juke._status_badge]:
			if not _within(node, vw, vh):
				offenders.append(String(node.name))
		_check(offenders.is_empty(), "%dx%d: nessun overflow (%s)" % [res.x, res.y, ", ".join(offenders) if not offenders.is_empty() else "ok"])
		_check(juke._title_label.get_line_count() <= 2, "%dx%d: titolo lungo limitato a 2 righe (%d)" % [res.x, res.y, juke._title_label.get_line_count()])
		_check(juke._track_buttons[longest_idx].clip_text and juke._track_buttons[longest_idx].text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "%dx%d: la riga di lista lunga viene troncata" % [res.x, res.y])
	_check(String(juke._title_label.text) == String(SoundtrackManager.track_info(ids[longest_idx]).get("title")), "il titolo piu lungo e quello dei metadati ('%s')" % juke._title_label.text)
	root.size = Vector2i(1280, 720)
	await _settle(2)


## The collapsed console must fit on its own; the EXPANDED prompt may not draw outside
## the card either, so the column scrolls and the prompt has to be reachable by
## scrolling at both shipped sizes.
func _check_expanded_prompt_layout(juke: Control) -> void:
	juke._select_track(_all_ids().find(SAWANO_ID))
	if not juke._prompt_section.visible:
		juke._on_prompt_toggle_pressed()
	await _settle(3)
	_check(juke._prompt_section.visible, "sezione metadati/prompt espansa")
	_check(String(juke._prompt_text.text) != "", "il prompt e popolato con l'espansione")
	_check(String(juke._prompt_toggle_btn.text).begins_with("▾"), "il toggle indica lo stato aperto")

	for res in RESOLUTIONS:
		root.size = res
		await _settle(4)
		var vw := float(res.x)
		var vh := float(res.y)
		var offenders := PackedStringArray()
		for node in [juke._list_card, juke._insp_scroll, juke._prompt_toggle_btn]:
			if not _within(node, vw, vh):
				offenders.append(String(node.name))
		_check(offenders.is_empty(), "%dx%d espanso: nulla disegna fuori dal viewport (%s)" % [res.x, res.y, ", ".join(offenders) if not offenders.is_empty() else "ok"])
		var bar: VScrollBar = juke._insp_scroll.get_v_scroll_bar()
		juke._insp_scroll.scroll_vertical = int(bar.max_value)
		await _settle(3)
		_check(_within(juke._prompt_text, vw, vh), "%dx%d espanso: il prompt e raggiungibile scorrendo la colonna" % [res.x, res.y])
		juke._insp_scroll.scroll_vertical = 0
		await _settle(2)

	# Collapse again so the caller's later checks see the default state.
	juke._on_prompt_toggle_pressed()
	await _settle(2)
	_check(not juke._prompt_section.visible, "la sezione torna richiusa")


## Cost shape: the motif must not add a per-frame redraw, and its spin must exist only
## while audio is really playing.
func _check_cost_shape(juke: Control) -> void:
	_check(not juke._record.is_processing(), "il disco non abilita _process (nessun redraw per frame)")
	_check(not bool(juke._record.get("_spinning")), "a riproduzione ferma il disco non gira")
	var ids := _all_ids()
	juke._select_track(ids.find(SAWANO_ID))
	juke._on_play_pressed()
	await _settle(2)
	if juke._manager.is_playing():
		_check(juke._record.get("_spin_tween") != null, "rotazione guidata da un tween durante la riproduzione")
	else:
		_notes.append("headless: spin tween asserted in the native phase (dummy driver never reaches playing=true)")

	# One tween handle for both directions: a stop/play pair arriving close together
	# must leave exactly the spin running, never a rest tween racing it.
	juke._on_stop_pressed()
	juke._on_play_pressed()
	await _settle(1)
	var handle = juke._record.get("_spin_tween")
	var spin_tween := handle as Tween
	_check(spin_tween != null and spin_tween.is_valid(), "stop/play ravvicinati lasciano un solo tween valido")
	_check(bool(juke._record.get("_spinning")), "stop/play ravvicinati lasciano il disco in rotazione")
	_check(absf(float(juke._record.get("rotation"))) <= TAU * 2.0, "rotazione del disco limitata (nessun accumulo)")

	juke._on_stop_pressed()
	await _settle(2)
	_check(not bool(juke._record.get("_spinning")), "Stop ferma la rotazione")
	_check(juke._elapsed_label.text == "0:00" and juke._progress_bar.value == 0.0, "Stop riporta il readout a zero onesto")
	_check(juke._stop_btn.disabled, "Stop si disabilita dopo lo stop")
	_check(juke._manager.current_track_id() == "", "Stop azzera la traccia corrente")


## The overlay mount (`main_menu.toggle_jukebox`) depends on `closed` + `queue_free`;
## ESC must take the same path.
func _check_lifecycle() -> void:
	var first := _new_screen()
	await _settle(3)
	var first_hits: Array = []
	first.closed.connect(func(): first_hits.append(true))
	first._manager.play_track(SAWANO_ID, 0.05)
	await create_timer(0.4).timeout
	_check(first._manager.current_track_id() == SAWANO_ID, "lifecycle: traccia avviata prima del back")
	first._on_back_pressed()
	_check(first_hits.size() == 1, "back: segnale closed emesso una volta")
	_check(first._manager.current_track_id() == "", "back: la riproduzione viene fermata")
	await _settle(3)
	_check(not is_instance_valid(first), "back: la schermata si libera con queue_free")

	var second := _new_screen()
	await _settle(3)
	var second_hits: Array = []
	second.closed.connect(func(): second_hits.append(true))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	second._unhandled_input(esc)
	_check(second_hits.size() == 1, "ESC: chiude la schermata (lifecycle di ritorno invariato)")
	await _settle(3)
	_check(not is_instance_valid(second), "ESC: la schermata si libera")


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _count_marked(juke: Control) -> int:
	var marked := 0
	for btn in juke._track_buttons:
		if String(btn.text).begins_with("▶"):
			marked += 1
	return marked


## Rows carrying a per-row font tint — the state marker, kept apart from the theme
## variation the selected row uses.
func _count_font_overrides(juke: Control) -> int:
	var tinted := 0
	for btn in juke._track_buttons:
		if btn.has_theme_color_override("font_color"):
			tinted += 1
	return tinted


func _longest_title_index(ids: PackedStringArray) -> int:
	var best := 0
	var best_len := 0
	for i in ids.size():
		var title := String(SoundtrackManager.track_info(ids[i]).get("title", ids[i]))
		if title.length() > best_len:
			best_len = title.length()
			best = i
	return best


func _within(node: Control, vw: float, vh: float) -> bool:
	if node == null or not node.is_visible_in_tree():
		return true
	var rect := node.get_global_rect()
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= vw + 1.0 and rect.end.y <= vh + 1.0


# ---------------------------------------------------------------------------
# native phase: real audio, real renderer, the two captures
# ---------------------------------------------------------------------------

func _run_native_phase() -> void:
	if DisplayServer.get_name() == "headless":
		_notes.append("native phase skipped: headless dummy driver renders blank frames and never reaches playing=true")
		return
	var dir := _capture_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var screen := _new_screen()
	await _settle(3)
	screen._select_track(_all_ids().find(SAWANO_ID))
	screen._on_play_pressed()
	await create_timer(1.0).timeout
	screen._refresh_readout()

	_check(screen._manager.is_playing(), "native: l'audio sta suonando davvero")
	_check(screen._record.get("_spin_tween") != null, "native: la rotazione e guidata dal tween di riproduzione")

	# One window resize per native run, as the ported capture harness does: on macOS the
	# second resize-and-draw in one process is not reliable, so the two 1280x720 states
	# (collapsed, then the expanded prompt) are taken first and the 1920x1080 state last.
	for res in RESOLUTIONS:
		root.size = res
		await _settle(6)
		screen._refresh_readout()
		var position: float = screen._manager.playback_position()
		var progress: float = screen._manager.playback_progress()
		_check(position > 0.0, "native %dx%d: elapsed reale > 0 (%.3fs)" % [res.x, res.y, position])
		_check(progress > 0.0 and progress <= 1.0, "native %dx%d: progress reale %.4f" % [res.x, res.y, progress])
		_check(screen._progress_bar.value > 0.0, "native %dx%d: barra sopra zero mentre suona" % [res.x, res.y])
		await _capture(dir, res)
		if res == Vector2i(1280, 720):
			# The expanded prompt at 1280x720 — the state the collapsed default hides, and
			# the one that has to prove the column still contains itself.
			screen._on_prompt_toggle_pressed()
			await _settle(5)
			screen._refresh_readout()
			await _capture(dir, res, "-prompt")
			screen._on_prompt_toggle_pressed()
			await _settle(3)

	screen._on_stop_pressed()
	await _settle(3)
	screen.free()
	await _settle(2)


func _capture_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../docs/agent-work/jukebox-player/captures").simplify_path()


func _capture(dir: String, res: Vector2i, suffix: String = "") -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	var tex := root.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		_check(false, "capture %dx%d: il viewport non ha prodotto immagine" % [res.x, res.y])
		return
	var path := "%s/jukebox-player-%dx%d%s.png" % [dir, res.x, res.y, suffix]
	var err := img.save_png(path)
	var colours := _sample_colours(img)
	_check(err == OK and colours > 8, "capture %dx%d non vuota (%d colori campionati) -> %s" % [res.x, res.y, colours, path])
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
