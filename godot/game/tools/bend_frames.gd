extends SceneTree
## Renders side-by-side comparisons for the "they bend too much" question, with
## labels, into --out=<dir>. Two pairs on one athlete:
##   A: the low-contact adaptation (same clip, same contact frame, level 0 vs 3)
##   B: the anticipation layer (ready stance, layer off vs on)
##
##   $GODOT --rendering-driver opengl3 --resolution 1400x760 --path godot/ \
##     --script res://game/tools/bend_frames.gd -- --out=/tmp/bend
const Spawn = preload("res://src/character/athlete_spawn.gd")
const ATHLETE := &"fiamma"
var STROKE := &"meshy_drive"   # --stroke=<clip> to render another stroke


func _initialize() -> void:
	call_deferred("run")


func _label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 32
	l.pixel_size = 0.005
	l.position = at
	l.modulate = Color(1, 1, 1)
	root.add_child(l)


func _camera(width: float) -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = width
	cam.position = Vector3(0, 1.1, 6.0)
	cam.look_at(Vector3(0, 1.0, 0))


func _light() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.11, 0.13, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.9
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	root.add_child(sun)


func _save(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("FRAME ", path)


func run() -> void:
	var out := ProjectSettings.globalize_path("user://bend")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--stroke="):
			STROKE = StringName(a.substr(9))
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1400, 760)
	_light()

	# --- A: the low-contact adaptation, level 0 vs level 3 -----------------
	var a1 = Spawn.make(ATHLETE, &"base")
	var a2 = Spawn.make(ATHLETE, &"base")
	if a1 == null or a2 == null:
		print("BEND_FRAMES no rig")
		quit(1)
		return
	root.add_child(a1)
	root.add_child(a2)
	a1.position.x = -0.75
	a2.position.x = 0.75
	a1.play_stroke_at(STROKE, 0.34, 1.0, 0.0)
	a2.play_stroke_at(STROKE, 0.34, 1.0, 1.0)
	a1._anim.pause()
	a2._anim.pause()
	for i in 2:
		await process_frame
	_label("palla bassa: livello 0 (clip)", Vector3(-0.75, 2.0, 0))
	_label("palla bassa: livello 3 (adattato)", Vector3(0.75, 2.0, 0))
	_camera(3.2)
	await _save("%s/lowcontact-0-vs-3.png" % out)

	# --- B: the anticipation layer, off vs on ------------------------------
	for c in root.get_children():
		if c is Node3D and c != null and c.get_script() == null and (c is Camera3D or c is Label3D or c is WorldEnvironment or c is DirectionalLight3D):
			c.queue_free()
		elif c == a1 or c == a2:
			c.queue_free()
	await process_frame
	var b1 = Spawn.make(ATHLETE, &"base")
	var b2 = Spawn.make(ATHLETE, &"base")
	root.add_child(b1)
	root.add_child(b2)
	b1.position.x = -0.75
	b2.position.x = 0.75
	for r in [b1, b2]:
		r.play_locomotion(&"ready")
		# Frame 0 of the imported clips is the bind pose, not the stance: sample
		# the clip where it actually reads as "ready" (the same time for both).
		r._anim.seek(0.6, true, true)
		r._anim.pause()
	for i in 2:
		await process_frame
	b2.set_anticipation(STROKE, 1.0, 0.34)   # the rig caps this at ANTICIPATION_MAX
	for i in 2:
		await process_frame
	_label("caricamento: spento", Vector3(-0.75, 2.0, 0))
	_label("caricamento: acceso", Vector3(0.75, 2.0, 0))
	_camera(3.2)
	await _save("%s/windup-%s-off-vs-on.png" % [out, String(STROKE).trim_prefix("meshy_")])
	print("BEND_FRAMES_DONE")
	quit(0)
