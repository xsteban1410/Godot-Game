extends SceneTree
## FPS medios en varios puntos de la ciudad y la Luna (ventana real, sin vsync):
##   godot --path game --script res://tools/bench.gd -- res://world/city.tscn

const SPOTS := {
	"res://world/city.tscn": [[Vector3(0, 0.2, 22), 0.0], [Vector3(0, 0.2, 40), PI], [Vector3(21, 0.2, -21), -PI / 4], [Vector3(-34, 0.2, 0), PI / 2]],
	"res://world/moon.tscn": [[Vector3(0, 0.2, 8), PI], [Vector3(0, 0.2, 20), 0.0], [Vector3(28, 0.2, -3), -PI / 2]],
}


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file(scene)
	_run.call_deferred(scene)


func _run(scene: String) -> void:
	for i in 300:  # ~3 s: que compilen los shaders; si no, el primer punto mide el arranque
		await process_frame
	var player = get_first_node_in_group("player")
	for spot: Array in SPOTS[scene]:
		player.place(spot[0], spot[1])
		for i in 60:
			await process_frame
		var start := Time.get_ticks_usec()
		for i in 200:
			await process_frame
		var fps := 200.0 / ((Time.get_ticks_usec() - start) / 1e6)
		print("BENCH %s %s fps=%.1f draws=%d" % [scene.get_file(), spot[0], fps,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
