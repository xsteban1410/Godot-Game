extends SceneTree
## Captura con una cámara libre (para revisar el aspecto sin jugar):
##   godot --path game --script res://tools/shot.gd -- res://world/moon.tscn x,y,z(cámara) x,y,z(mira) salida.png [segundos]


func _initialize() -> void:
	change_scene_to_file(OS.get_cmdline_user_args()[0])
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in 10:
		await process_frame
	var camera := Camera3D.new()
	camera.far = 600.0
	current_scene.add_child(camera)
	var from := args[1].split_floats(",")
	var to := args[2].split_floats(",")
	camera.look_at_from_position(Vector3(from[0], from[1], from[2]), Vector3(to[0], to[1], to[2]))
	camera.make_current()
	await create_timer(float(args[4]) if args.size() > 4 else 1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(args[3])
	quit()
