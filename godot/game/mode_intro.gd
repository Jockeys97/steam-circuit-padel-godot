extends CanvasLayer
## Presentation clock only: the match controller does not sample/step while active.
const Text = preload("res://src/ui/UiStrings.gd")
const CAREER_SEASON_VOICE = preload("res://assets/audio/announcer-career-season-bruno-en.wav")
const TOURNAMENT_OPENING_VOICE = preload("res://assets/audio/announcer-tournament-opening-bruno-en.wav")
const TOURNAMENT_FINAL_VOICE = preload("res://assets/audio/announcer-tournament-final-bruno-en.wav")
signal completed
var active := false
var elapsed := 0.0
var duration := 5.0
var camera: Camera3D
var original: Transform3D
var card: PanelContainer
var completing := false
var _actors: Dictionary = {}
var _names: Dictionary = {}
var _actor_state: Dictionary = {}
var _shots: Array[Transform3D] = []
var _captions: Array[String] = []
var _beat: Label
var _last_beat := -1
var _kind := "intro"
var _trophy: Node3D
var voice_player: AudioStreamPlayer

static func enabled(mode: String, prefs: Dictionary) -> bool:
	return mode in ["tournament", "career"] and bool(prefs.get("intro_" + mode, true))

static func should_celebrate(mode: String, awarded: Dictionary, won: bool, prefs: Dictionary) -> bool:
	if not won or not enabled(mode, prefs):
		return false
	if mode == "tournament":
		return bool(awarded.get("trophy", false))
	return bool(awarded.get("outcome", {}).get("seasonWon", false))

static func voice_for(mode: String, round: int, match_index: int, language: String) -> AudioStream:
	# Bruno's lines are English in either supported UI language.
	if language != "en" and language != "it":
		return null
	if mode == "career" and match_index == 0:
		return CAREER_SEASON_VOICE
	if mode == "tournament":
		if round == 0:
			return TOURNAMENT_OPENING_VOICE
		if round == 2:
			return TOURNAMENT_FINAL_VOICE
	return null

func begin(cam: Camera3D, title: String, detail: String, seconds: float,
		actors: Dictionary = {}, kind: String = "intro", names: Dictionary = {},
		voice: AudioStream = null) -> void:
	camera = cam
	original = camera.transform
	duration = maxf(seconds, 0.1)
	_actors = actors
	_names = names
	_kind = kind
	_actor_state.clear()
	for role in actors:
		var actor: Node3D = actors[role]
		if is_instance_valid(actor):
			_actor_state[role] = {
				"transform": actor.transform,
				"locomotion": actor.get_locomotion_state() if actor.has_method("get_locomotion_state") else &"",
			}
	if _kind == "victory":
		_build_trophy()
	_build_shots()
	layer = 90
	active = true
	if _kind == "intro" and voice != null:
		voice_player = AudioStreamPlayer.new()
		voice_player.name = "BrunoIntro"
		voice_player.bus = "SFX"
		voice_player.stream = voice
		add_child(voice_player)
		voice_player.play()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -220
	margin.offset_left = 40
	margin.offset_right = -40
	margin.offset_bottom = -30
	add_child(margin)
	card = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.04, 0.12, 0.94)
	box.set_corner_radius_all(16)
	box.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", box)
	margin.add_child(card)
	var column := VBoxContainer.new()
	card.add_child(column)
	for value in [title, detail]:
		var label := Label.new()
		label.text = value
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 28 if value == title else 18)
		label.modulate = Color(0.05, 0.88, 1.0) if value == title else Color.WHITE
		column.add_child(label)
	_beat = Label.new()
	_beat.add_theme_font_size_override("font_size", 17)
	_beat.modulate = Color(1.0, 0.83, 0.32)
	column.add_child(_beat)
	var skip := Button.new()
	skip.text = Text.t("modeIntroSkip")
	skip.pressed.connect(request_skip)
	column.add_child(skip)
	_apply_beat(0)

func _build_shots() -> void:
	_shots.clear()
	_captions.clear()
	var center := Vector3.ZERO
	var count := 0
	for role in _actors:
		var actor: Node3D = _actors[role]
		if is_instance_valid(actor):
			center += actor.global_position
			count += 1
	if count > 0:
		center /= float(count)
	_add_shot(_look_at(original.origin + original.basis.y * 3.0 + original.basis.z * 3.0,
		center + Vector3.UP), Text.t("cinematicArena"))
	if _kind == "victory":
		_add_actor_shot("player", Vector3(-2.8, 2.1, -4.8), Text.t("cinematicWinners"))
		if is_instance_valid(_trophy):
			var target := _trophy.global_position + Vector3.UP * 0.9
			_add_shot(_look_at(target + Vector3(2.7, 1.9, -4.4), target), Text.t("cinematicTrophy"))
	else:
		_add_actor_shot("opponent", Vector3(2.8, 2.1, 4.8), Text.t("cinematicRivals"))
		_add_actor_shot("player", Vector3(-2.8, 2.1, -4.8), Text.t("cinematicYourTeam"))
		_add_shot(original, Text.t("cinematicReady"))

func _build_trophy() -> void:
	var player: Node3D = _actors.get("player", null)
	if not is_instance_valid(player):
		return
	var mate: Node3D = _actors.get("playerMate", null)
	_trophy = Node3D.new()
	_trophy.name = "CinematicTrophy"
	camera.get_parent().add_child(_trophy)
	_trophy.global_position = (player.global_position + mate.global_position) * 0.5 if is_instance_valid(mate) else player.global_position + Vector3(0.8, 0, 0)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.96, 0.68, 0.16)
	gold.metallic = 0.8
	gold.roughness = 0.25
	_add_trophy_part(_trophy, 0.12, 0.23, 0.50, 0.43, gold)
	_add_trophy_part(_trophy, 0.46, 0.50, 0.10, 0.12, gold)
	_add_trophy_part(_trophy, 0.94, 0.48, 0.47, 0.18, gold)
	_add_trophy_part(_trophy, 1.20, 0.08, 0.49, 0.49, gold)

func _add_trophy_part(parent: Node3D, y: float, height: float,
		top_radius: float, bottom_radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position.y = y
	parent.add_child(part)

func _add_actor_shot(role: String, offset: Vector3, caption: String) -> void:
	var actor: Node3D = _actors.get(role, null)
	if is_instance_valid(actor):
		var target := actor.global_position + Vector3.UP * 1.35
		var name := String(_names.get(role, ""))
		_add_shot(_look_at(target + offset, target), caption + (" · " + name if name != "" else ""))

func _add_shot(shot: Transform3D, caption: String) -> void:
	_shots.append(shot)
	_captions.append(caption)

func _look_at(position: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(target - position, Vector3.UP), position)

func _apply_beat(index: int) -> void:
	if index == _last_beat:
		return
	_last_beat = index
	_beat.text = _captions[index]
	for role in _actors:
		var actor: Node3D = _actors[role]
		if is_instance_valid(actor) and actor.has_method("play_locomotion"):
			if _kind == "victory":
				var ceremony: StringName = &"cheer" if String(role).begins_with("player") else &"dejected"
				actor.play_locomotion(ceremony)
				# The last point may still be in its stroke follow-through. A direct clip
				# switches the visual immediately; match simulation remains finished.
				if actor.has_method("play_clip"):
					actor.play_clip(ceremony)
			else:
				actor.play_locomotion(&"ready")

func request_skip() -> void:
	if voice_player != null:
		voice_player.stop()
	completing = true

func handle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		request_skip()
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]:
		request_skip()

func advance(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration: completing = true
	# Wait for held skip/launch buttons to release; never turn a skip into a serve.
	if completing:
		if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_ESCAPE): return
		for device in Input.get_connected_joypads():
			for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]:
				if Input.is_joy_button_pressed(device, button): return
		_finish()
		return
	var progress := clampf(elapsed / duration, 0.0, 0.9999) * float(_shots.size())
	var index := mini(int(progress), _shots.size() - 1)
	_apply_beat(index)
	var blend := smoothstep(0.0, 0.55, progress - float(index))
	var from: Transform3D = original if index == 0 else _shots[index - 1]
	camera.transform = from.interpolate_with(_shots[index], blend)
	card.modulate.a = clampf(elapsed * 3.0, 0.0, 1.0)

func _finish() -> void:
	if voice_player != null:
		voice_player.stop()
	camera.transform = original
	if is_instance_valid(_trophy):
		_trophy.queue_free()
	for role in _actor_state:
		var actor: Node3D = _actors.get(role, null)
		if not is_instance_valid(actor):
			continue
		actor.transform = _actor_state[role]["transform"]
		if actor.has_method("play_locomotion"):
			var previous: StringName = _actor_state[role]["locomotion"]
			if previous != &"":
				actor.play_locomotion(previous)
	active = false
	completed.emit()
	queue_free()
