extends Node3D
## Standalone proof of the real playable outfit path.
## Wardrobe cards are promotional portraits, not captures from this test stage.

const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

const VARIANTS := [
	{
		"athlete": &"fiamma", "outfit": &"solar_sprint", "title": "FIAMMA  /  SOLAR SPRINT",
	},
	{
		"athlete": &"maestro", "outfit": &"polar_ace", "title": "MAESTRO  /  POLAR ACE",
	},
]

var _subjects: Array[Node3D] = []
var _title: Label
var _left_label: Label
var _right_label: Label


func _ready() -> void:
	_make_stage()
	var output_dir := OS.get_environment("OUTFIT_REVIEW_DIR")
	if output_dir.is_empty():
		output_dir = OS.get_user_data_dir().path_join("outfit-review")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("OUTFIT_REVIEW_FAIL: cannot create output directory")
		get_tree().quit(1)
		return
	for entry in VARIANTS:
		if not _show_pair(entry):
			get_tree().quit(1)
			return
		if not await _capture(output_dir.path_join("%s-preview.png" % String(entry["athlete"]))):
			get_tree().quit(1)
			return
		for subject in _subjects:
			subject.play_locomotion(&"run")
			subject.sample_at(0.22)
		if not await _capture(output_dir.path_join("%s-motion.png" % String(entry["athlete"]))):
			get_tree().quit(1)
			return
	get_tree().quit(0)


func _capture(path: String) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("OUTFIT_REVIEW %s err=%d size=%dx%d" % [path, err, image.get_width(), image.get_height()])
	return err == OK


func _make_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b32")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c7ddfa")
	environment.ambient_light_energy = 0.6
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 8.0)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("1b3559")
	floor.material_override = floor_material
	add_child(floor)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.25, 3.8)
	camera.fov = 39.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.91, 0.0), Vector3.UP)
	camera.make_current()

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_title = _label(canvas, Vector2(38, 22), 29, Color.WHITE)
	_left_label = _label(canvas, Vector2(230, 648), 22, Color("b6cbe4"))
	_right_label = _label(canvas, Vector2(850, 648), 22, Color("66e5e8"))
	_label(canvas, Vector2(38, 687), 13, Color("8799af")).text = "3D outfit check | actual in-game material | no Meshy"


func _label(canvas: CanvasLayer, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	canvas.add_child(label)
	return label


func _show_pair(entry: Dictionary) -> bool:
	for subject in _subjects:
		subject.queue_free()
	_subjects.clear()
	var athlete_id: StringName = entry["athlete"]
	_title.text = String(entry["title"])
	_left_label.text = "BASE ATTUALE"
	_right_label.text = "NEL GIOCO"
	for i in 2:
		var outfit_id: StringName = &"base" if i == 0 else entry["outfit"]
		var rig: Node3D = AthleteSpawn.make(athlete_id, outfit_id, {
			"position": Vector3(-0.95 if i == 0 else 0.95, 0.0, 0.0),
			"facing_degrees": 0.0,
			"locomotion": &"idle",
		})
		if rig == null:
			push_error("OUTFIT_REVIEW_FAIL: could not spawn %s" % athlete_id)
			return false
		add_child(rig)
		_subjects.append(rig)
		rig.sample_at(0.15)
	return true
