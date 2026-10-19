extends SceneTree
## Genera la parte fija de la ciudad (world/city_static.gd), le desenvuelve las UV2 para el lightmap y la guarda en
## world/city_static.scn con su LightmapGI listo para hornear. Después hay que hornear la luz (necesita ventana):
##   godot --headless --path game --script res://tools/build_city.gd
##   godot -e --path game -- --bake=res://world/city_static.scn

const OUT := "res://world/city_static.scn"
const TEXEL := 0.6  # metros por píxel del lightmap
# El horneado colgó la Radeon 610M (2026-10-18) con los valores por defecto: atlas de hasta 16384 px y pasadas
# largas. Atlas de 2048 px y, en project.godot, regiones de 64 px y 1 rayo por pasada: cada envío a la GPU es corto.


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var city := Node3D.new()
	city.name = "CityStatic"
	city.set_script(load("res://world/city_static.gd"))
	root.add_child(city)  # su _ready construye la ciudad
	await process_frame
	var canopies: PackedVector3Array = city.get_meta("canopies")
	city.set_script(null)  # la escena guardada no vuelve a generarse al cargarla
	city.set_meta("canopies", canopies)
	var unwrapped := {}
	var baked := 0
	for mesh: MeshInstance3D in city.find_children("*", "MeshInstance3D", true, false):
		if _dynamic(mesh, city):
			mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC  # lo ilumina el lightmap con sus sondas
			continue
		var data := mesh.mesh
		if data is PrimitiveMesh:  # las primitivas no guardan UV2: se pasan a ArrayMesh
			var array := ArrayMesh.new()
			array.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.get_mesh_arrays())
			array.surface_set_material(0, data.material)
			data = array
		elif unwrapped.has(data):  # malla compartida: cada instancia necesita su propio hueco en el lightmap
			data = data.duplicate()
		if data.lightmap_unwrap(mesh.global_transform, TEXEL) != OK:
			push_warning("sin UV2: " + str(mesh.get_path()))
			mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			continue
		unwrapped[data] = true
		mesh.mesh = data
		mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		baked += 1
	var lightmap := LightmapGI.new()
	lightmap.name = "LightmapGI"
	lightmap.quality = LightmapGI.BAKE_QUALITY_LOW
	lightmap.bounces = 2
	lightmap.max_texture_size = 2048
	lightmap.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_4
	lightmap.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR  # el cielo nocturno como luz ambiente
	lightmap.environment_custom_color = Color(0.5, 0.56, 0.9)
	lightmap.environment_custom_energy = 0.2
	city.add_child(lightmap)
	_own(city, city)
	var packed := PackedScene.new()
	packed.pack(city)
	var error := ResourceSaver.save(packed, OUT, ResourceSaver.FLAG_COMPRESS)
	print("CIUDAD: %d mallas con UV2 -> %s (%s)" % [baked, OUT, error_string(error)])
	quit(error)


## Lo que gira, lo que queda fuera de los muros y el holograma no se hornean.
func _dynamic(mesh: MeshInstance3D, city: Node) -> bool:
	var node: Node = mesh
	while node != city:
		if node.has_meta("spin") or node.has_meta("bob") or node.has_meta("no_gi"):
			return true
		node = node.get_parent()
	var material := mesh.get_active_material(0)
	return material is ShaderMaterial and material.shader.resource_path.ends_with("hologram.gdshader")


func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)
