extends Node3D
## Visual gate for the standard right-hand racket attachment.
##
## It renders the same Colosso rig and procedural racket used by the match, once
## in idle and once inside the authored drive. The image is review evidence only;
## `out/` is ignored and no prototype resource ships in an export preset.

const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const Court := preload("res://game/court.gd")
const AthletesView := preload("res://game/athletes_view.gd")

const OUTPUT := "res://prototypes/racket_review/out/colosso-racket.png"


func _ready() -> void:
	_build_world()
	_place_colosso(-0.85, &"idle", 0.0)
	_place_colosso(0.85, &"drive", 0.28)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(OUTPUT)
	print("RACKET_REVIEW %s err=%d size=%dx%d" % [
		ProjectSettings.globalize_path(OUTPUT), err, image.get_width(), image.get_height()])
	get_tree().quit(0 if err == OK else 1)


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("222936")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.6
	add_child(sun)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 6.0)
	floor.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("131923")
	floor.material_override = floor_material
	add_child(floor)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.35, 4.6)
	camera.fov = 34.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.make_current()


func _place_colosso(x: float, clip: StringName, time: float) -> void:
	var rig: Node3D = AthleteSpawn.make(&"colosso", &"base", {
		"name": "Colosso_%s" % clip,
		"position": Vector3(x, 0.0, 0.0),
		"facing_degrees": 0.0,
		"locomotion": &"idle",
	})
	if rig == null:
		push_error("RacketReview: Colosso did not spawn")
		return
	add_child(rig)
	var attachment: BoneAttachment3D = rig.make_standard_bone_attachment(
		&"RightHand", StringName("RacketAnchor_%s" % clip))
	if attachment == null:
		push_error("RacketReview: missing standard RightHand attachment")
		return
	var racket := Court.make_racket_view(attachment, "Racket", Color("e2b52d"))
	racket.position = AthletesView.RACKET_HAND_LOCAL
	racket.rotation_degrees = AthletesView.RACKET_HAND_ROTATION
	if clip == &"idle":
		rig.play_locomotion(&"idle")
	else:
		rig.play_stroke(clip)
	rig.sample_at(time)
