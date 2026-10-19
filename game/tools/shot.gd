extends SceneTree
## Captura a 1920×1080, la resolución de diseño, aunque el gestor de ventanas encoja la ventana:
##   godot --path game --script res://tools/shot.gd -- res://world/moon.tscn x,y,z(cámara) x,y,z(mira) salida.png [segundos]
##   godot --path game --script res://tools/shot.gd -- res://world/city.tscn jugador x,y,z,yaw_grados salida.png [segundos]
## (La primera es una vista limpia, sin interfaz; la segunda coloca al jugador y usa su cámara, con la interfaz.)


func _initialize() -> void:
	change_scene_to_file(OS.get_cmdline_user_args()[0])
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in 10:
		await process_frame
	var view := SubViewport.new()  # comparte el mundo 3D de la ventana; solo cambia el tamaño
	view.size = Vector2i(1920, 1080)
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.far = 600.0
	view.add_child(camera)
	var follow: Camera3D = null
	if args[1] == "jugador":
		var p := args[2].split_floats(",")
		get_first_node_in_group("player").place(Vector3(p[0], p[1], p[2]), deg_to_rad(p[3]))
		follow = root.get_camera_3d()
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP  # la interfaz se coloca en 1920×1080 justos
		for layer: CanvasLayer in current_scene.find_children("*", "CanvasLayer", true, false):
			layer.custom_viewport = view  # vista del jugador: con HUD, bocadillos y paneles
	else:
		var from := args[1].split_floats(",")
		var to := args[2].split_floats(",")
		camera.fov = 55.0  # menos deformación en los bordes que con los 75° del juego
		camera.look_at_from_position(Vector3(from[0], from[1], from[2]), Vector3(to[0], to[1], to[2]))
	var seconds := float(args[4]) if args.size() > 4 else 1.5
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if follow:
			camera.global_transform = follow.global_transform
			camera.fov = follow.fov
		await process_frame
	view.get_texture().get_image().save_png(args[3])
	quit()
