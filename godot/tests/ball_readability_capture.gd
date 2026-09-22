extends SceneTree
const BallShader = preload("res://game/ball_readable.gdshader")
const Court = preload("res://game/court.gd")
func _initialize(): call_deferred("run")
func run():
	DisplayServer.window_set_size(Vector2i(960,540))
	root.size=Vector2i(960,540)
	root.content_scale_size=Vector2i(960,540)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=8.0
	root.add_child(camera)
	camera.position=Vector3(0,0,10)
	camera.current=true
	var material := ShaderMaterial.new()
	material.shader=BallShader
	var balls: Array[MeshInstance3D] = []
	var backgrounds := [Color("598af0"),Color("fff5bb"),Color("11172b")]
	for col in 3:
		var x := (col-1)*4.6
		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size=Vector2(4.6,8)
		panel.mesh=quad
		var bg := StandardMaterial3D.new()
		bg.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		bg.albedo_color=backgrounds[col]
		panel.material_override=bg
		panel.position=Vector3(x,0,-1)
		root.add_child(panel)
		for row in 2:
			var ball := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius=Court.BALL_R
			sphere.height=Court.BALL_R*2
			ball.mesh=sphere
			ball.material_override=material
			ball.position=Vector3(x,1.5 if row == 0 else -1.5,0)
			# Top: close-up; bottom: unchanged runtime radius at a distant camera.
			ball.scale=Vector3.ONE*(8.0 if row == 0 else 1.0)
			root.add_child(ball)
			balls.append(ball)
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var failures := 0
	for ball in balls:
		var point := camera.unproject_position(ball.global_position)
		var center := screenshot.get_pixel(int(point.x),int(point.y))
		if center.g < 0.6 or center.r < 0.5 or center.b > 0.6:
			failures += 1
			push_error("Ball lost bright lime center: "+str(center))
	var destination := ProjectSettings.globalize_path("res://../docs/agent-work/ball-readability")
	DirAccess.make_dir_recursive_absolute(destination)
	screenshot.save_png(destination.path_join("comparison.png"))
	print("BALL_READABILITY ",6-failures,"/6 radius=",Court.BALL_R)
	quit(1 if failures else 0)
