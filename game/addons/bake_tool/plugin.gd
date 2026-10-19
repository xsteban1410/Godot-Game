@tool
extends EditorPlugin
## LightmapGI solo se hornea con el botón «Bake Lightmaps» del editor: este plugin abre la escena pedida,
## selecciona su LightmapGI, pulsa ese botón, espera a que termine, guarda y cierra el editor.
## Uso: godot -e --path game -- --bake=res://world/city_static.tscn


func _enter_tree() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bake="):
			_bake.call_deferred(arg.trim_prefix("--bake="))


func _bake(path: String) -> void:
	var tree := get_tree()
	for i in 60:
		await tree.process_frame
	EditorInterface.open_scene_from_path(path)
	for i in 30:
		await tree.process_frame
	var root := EditorInterface.get_edited_scene_root()
	var lightmap: LightmapGI = root.find_children("*", "LightmapGI", true, false)[0]
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(lightmap)
	EditorInterface.edit_node(lightmap)
	for i in 10:
		await tree.process_frame
	var buttons := EditorInterface.get_base_control().find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == "Bake Lightmaps" and b.is_visible_in_tree())
	if buttons.is_empty():
		push_error("BAKE: no encuentro el botón Bake Lightmaps")
		tree.quit(1)
		return
	var start := Time.get_ticks_msec()
	print("BAKE: horneando ", path)
	buttons[0].pressed.emit()
	await tree.process_frame
	while lightmap.light_data == null and Time.get_ticks_msec() - start < 1800000:
		await tree.create_timer(1.0).timeout
	print("BAKE: listo en %.1f s" % ((Time.get_ticks_msec() - start) / 1000.0))
	EditorInterface.save_scene()
	for i in 10:
		await tree.process_frame
	tree.quit(0 if lightmap.light_data else 1)
