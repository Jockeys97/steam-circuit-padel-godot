## Review-only Meshy trial. Does not modify the runtime athlete or simulation.
extends SceneTree
func _initialize():
	call_deferred("run")
func find_type(node: Node, type: String):
	if node.is_class(type): return node
	for child in node.get_children():
		var result = find_type(child, type)
		if result != null: return result
	return null
func run():
	var path := ProjectSettings.globalize_path("res://../docs/agent-work/meshy-fiamma-trial/fiamma-forehand.glb")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("Missing Meshy trial asset")
		quit(1)
		return
	var model := doc.generate_scene(state)
	root.add_child(model)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.position = Vector3(2.2, 1.5, 3.3)
	camera.look_at(Vector3(0, 0.85, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-40, -25, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.15, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	root.add_child(env)
	var label := Label.new()
	label.text = "FIAMMA — prova Meshy: diritto (non ancora integrato in partita)"
	label.position = Vector2(20, 20)
	root.add_child(label)
	var ap: AnimationPlayer = find_type(model, "AnimationPlayer")
	if ap == null:
		quit(1)
		return
	for clip in ap.get_animation_list():
		if clip == "RESET" or ap.get_animation(clip).length < 1.0: continue
		ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		ap.play(clip)
		print("MESHY_PREVIEW_OK clip=", clip, " length=", ap.get_animation(clip).length)
		return
	quit(1)
