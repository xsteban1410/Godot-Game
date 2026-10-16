class_name Kit
## Fábrica de mallas, materiales y textos 3D procedurales, compartida por todo el juego.
## En Unity, cada script tenía su propio CreatePrimitive/CreateMaterial; aquí hay uno solo con caché.

const TITLE_FONT := preload("res://ui/fonts/Rubik-ExtraBold.ttf")
const EYE_SHADER := preload("res://core/eye.gdshader")
const TOY_SHADER := preload("res://core/toy.gdshader")

const CHUNK := 32.0  # lado (m) de los trozos de `bake`: más grandes, menos draw calls; más pequeños, mejor culling

static var _materials := {}
static var _boxes := {}  # tamaño -> malla de caja redondeada (cajas iguales comparten malla)
static var _toys := {}  # "metal|rugosidad" -> material de juguete con el color y la luz en los vértices
static var _blob: GradientTexture2D


## Plástico de juguete estilo Astro Bot: brillante y con un borde de luz que separa la silueta.
## Sin clearcoat: costaba 3,3 ms de GPU a 1080p en la Radeon 610M y una rugosidad baja da el mismo brillo.
static func mat(color: Color, emission := 0.0, metallic := 0.0, roughness := 0.22) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), emission, metallic, roughness]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		m.rim_enabled = true
		m.rim = 0.3
		m.rim_tint = 0.7
		if emission > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = emission
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = m
	return _materials[key]


static func part(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return part(parent, rounded(size), pos, material, rot)


## La malla de caja redondeada de ese tamaño (cajas iguales comparten malla).
static func rounded(size: Vector3) -> Mesh:
	if not _boxes.has(size):
		_boxes[size] = _rounded_box(size)
	return _boxes[size]


## Caja de juguete: aristas redondeadas que recogen brillo como el plástico. Cada cara es una rejilla cuyos
## bordes se proyectan sobre el redondeo (caja interior + dirección × radio); el centro de la cara queda plano.
static func _rounded_box(size: Vector3) -> Mesh:
	var radius := minf(minf(minf(size.x, size.y), size.z) * 0.25, 0.12)
	if radius < 0.01:  # tan fina que el redondeo no se vería
		var flat := BoxMesh.new()
		flat.size = size
		return flat
	var inner := size / 2.0 - Vector3.ONE * radius
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var su := _stops(inner[u], radius)
		var sv := _stops(inner[v], radius)
		for side in [-1.0, 1.0]:
			var outward := Vector3.ZERO
			outward[axis] = side
			for i in su.size() - 1:
				for j in sv.size() - 1:
					var quad: Array[Vector3] = []
					for c in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
						var p := outward * (inner[axis] + radius)
						p[u] = su[c.x]
						p[v] = sv[c.y]
						quad.append(p)
					for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
						if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(outward) > 0.0:
							tri.reverse()  # Godot dibuja las caras en sentido horario
						for p: Vector3 in tri:
							var core := p.clamp(-inner, inner)
							var normal := (p - core).normalized()
							st.set_normal(normal)
							st.add_vertex(core + normal * radius)
	st.index()
	return st.commit()


## Cortes de la rejilla en un eje: media arista redondeada en dos pasos (0°, 22,5°, 45°) a cada lado.
static func _stops(inner: float, radius: float) -> Array[float]:
	var band := radius * tan(PI / 8.0)
	return [-inner - radius, -inner - band, -inner, inner, inner + band, inner + radius]


## Funde las mallas fijas que cuelgan directamente de `root` en una por trozo de CHUNK m y por material, con el
## color de cada pieza en sus vértices: cientos de draw calls pasan a decenas, cada trozo se sigue descartando
## al salir de la cámara (frustum y occlusion culling) y lleva LOD automáticos (menos triángulos de lejos).
## Lo que va en sub-nodos (pivotes que giran, piezas que se recogen) no se toca; `keep`: mallas que cambian.
## `chunk`: lado de los trozos (el horizonte, siempre a la vista, va entero en uno).
static func bake(root: Node3D, keep: Array = [], chunk := CHUNK) -> void:
	var groups := {}  # [trozo, material, sombra] -> [[malla, transformación, color], …]
	for node in root.get_children():
		var piece := node as MeshInstance3D
		if not piece or piece in keep or not piece.material_override:
			continue
		var material := piece.material_override
		var color := Color.WHITE
		if material is StandardMaterial3D:
			if material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:  # lo transparente conserva su material
				color = Color(material.albedo_color, material.emission_energy_multiplier / 8.0 if material.emission_enabled else 0.0)
				material = _toy(material.metallic, material.roughness)
		elif piece.has_meta("tint") or material in _toys.values():  # (un trozo ya fundido trae su color en los vértices)
			color = piece.get_meta("tint", Color.WHITE)
		else:
			continue  # sombreadores que dependen de su propio nodo (ojos que parpadean, holograma, agua)
		var key := [Vector3i((piece.position / chunk).round()), material, piece.cast_shadow]  # trozos centrados: una pieza pequeña nunca se parte en dos
		if not groups.has(key):
			groups[key] = []
		groups[key].append([piece.mesh, piece.transform, color])
		root.remove_child(piece)
		piece.queue_free()
	for key: Array in groups:
		var merged := MeshInstance3D.new()
		merged.mesh = merge(groups[key])
		merged.material_override = key[1]
		merged.cast_shadow = key[2]
		root.add_child(merged)


## Una malla con todas las piezas [malla, transformación, color] y sus LOD generados por Godot.
static func merge(pieces: Array) -> Mesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for piece: Array in pieces:
		var arrays: Array = piece[0].surface_get_arrays(0)
		var xf: Transform3D = piece[1]
		var start := vertices.size()
		var count: int = arrays[Mesh.ARRAY_VERTEX].size()
		vertices.append_array(xf * arrays[Mesh.ARRAY_VERTEX])
		normals.append_array(Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * arrays[Mesh.ARRAY_NORMAL])
		var tint: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] else PackedColorArray()
		if tint.is_empty():  # (si ya traía color por vértice, es un trozo ya fundido: se conserva)
			tint.resize(count)
			tint.fill(piece[2])
		colors.append_array(tint)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
		uv.resize(count)
		uvs.append_array(uv)
		for i: int in arrays[Mesh.ARRAY_INDEX]:
			indices.append(start + i)
	var merged := []
	merged.resize(Mesh.ARRAY_MAX)
	merged[Mesh.ARRAY_VERTEX] = vertices
	merged[Mesh.ARRAY_NORMAL] = normals
	merged[Mesh.ARRAY_COLOR] = colors
	merged[Mesh.ARRAY_TEX_UV] = uvs
	merged[Mesh.ARRAY_INDEX] = indices
	var lod := ImporterMesh.new()
	lod.add_surface(Mesh.PRIMITIVE_TRIANGLES, merged)
	lod.generate_lods(25.0, 60.0, [])
	return lod.get_mesh()


## Material de juguete compartido (Kit.mat lo emula pieza a pieza; este lo lee de los vértices).
static func _toy(metallic: float, roughness: float) -> ShaderMaterial:
	var key := "%s|%s" % [metallic, roughness]
	if not _toys.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOY_SHADER
		m.set_shader_parameter("metallic", metallic)
		m.set_shader_parameter("roughness", roughness)
		_toys[key] = m
	return _toys[key]


## `segments`: 0 = según el radio; el decorado que se ve pequeño (flores, nubes, copas) pide menos.
static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material, squash := Vector3.ONE, segments := 0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments if segments else 16 if radius < 0.3 else 32 if radius < 4.0 else 48  # el valor por defecto (64) sobra y pesa en GPU integrada
	mesh.rings = mesh.radial_segments >> 1
	var node := part(parent, mesh, pos, material)
	node.scale = squash
	return node


static func capsule(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 4
	return part(parent, mesh, pos, material, rot)


static func cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3,
		material: Material, segments := 24, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	return part(parent, mesh, pos, material, rot)


static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = clampi(int(outer * 16.0), 16, 64)  # un cinturón de robot no necesita los mismos segmentos que el aro de la plaza
	mesh.ring_segments = clampi(int((outer - inner) * 40.0), 8, 16)
	return part(parent, mesh, pos, material, rot)


## Robot estilo Astro Bot mirando hacia +Z, de ~1,9 m: cabeza grande blanca, visor negro con reflejo y ojos LED
## que parpadean, hombreras, cinturón y botas del color `accent`.
## Devuelve los pivotes [brazo izq., brazo der., pierna izq., pierna der.].
static func robot(parent: Node3D, accent: Color, eyes := Color("35b8ff")) -> Array[Node3D]:
	var white := mat(Color("f4f7fb"), 0.0, 0.0, 0.15)
	var joint := mat(Color("3a4352"), 0.0, 0.4, 0.3)
	var color := mat(accent, 0.0, 0.1, 0.2)
	var eye := ShaderMaterial.new()
	eye.shader = EYE_SHADER
	eye.set_shader_parameter("color", eyes)
	sphere(parent, 0.4, Vector3(0, 1.6, 0), white)
	sphere(parent, 0.35, Vector3(0, 1.6, 0.13), mat(Color("05070c"), 0.0, 0.3, 0.03), Vector3(1.0, 0.76, 0.66))
	sphere(parent, 0.06, Vector3(-0.17, 1.74, 0.33), mat(Color.WHITE, 1.5), Vector3(1.6, 0.6, 0.3))  # reflejo del visor
	cylinder(parent, 0.17, 0.2, 0.12, Vector3(0, 1.22, 0), joint, 16)  # cuello
	for side in [-1.0, 1.0]:
		sphere(parent, 0.065, Vector3(0.12 * side, 1.63, 0.36), eye, Vector3(0.8, 1.35, 0.4))
		cylinder(parent, 0.11, 0.11, 0.08, Vector3(0.4 * side, 1.6, 0), color, 16, Vector3(0, 0, PI / 2))
		sphere(parent, 0.06, Vector3(0.44 * side, 1.6, 0), mat(eyes, 3.0))
	capsule(parent, 0.27, 0.66, Vector3(0, 0.98, 0), white)
	cylinder(parent, 0.1, 0.1, 0.04, Vector3(0, 1.04, 0.26), mat(eyes, 2.5), 20, Vector3(PI / 2, 0, 0))
	# Mochila propulsora (jetpack): la cámara siempre ve la espalda. Va en su propio nodo para que el jugador
	# encienda las toberas y use la franja de luz ("Gauge") como indicador de combustible.
	var pack := Node3D.new()
	pack.name = "Jetpack"
	parent.add_child(pack)
	box(pack, Vector3(0.4, 0.44, 0.2), Vector3(0, 1.02, -0.3), color)
	var gauge := box(pack, Vector3(0.3, 0.06, 0.04), Vector3(0, 1.14, -0.41), mat(eyes, 2.5))
	gauge.name = "Gauge"
	for side in [-0.1, 0.1]:
		cylinder(pack, 0.06, 0.08, 0.14, Vector3(side, 0.74, -0.3), joint, 12)
		cylinder(pack, 0.045, 0.045, 0.02, Vector3(side, 0.66, -0.3), mat(eyes, 3.0), 12)
	bake(pack, [gauge])
	torus(parent, 0.22, 0.29, Vector3(0, 0.8, 0), color)  # cinturón
	sphere(parent, 0.22, Vector3(0, 0.72, 0), joint, Vector3(1.0, 0.6, 0.9))
	var limbs: Array[Node3D] = []
	for spec in [[Vector3(0.34, 1.18, 0), false], [Vector3(-0.34, 1.18, 0), false],
			[Vector3(0.13, 0.72, 0), true], [Vector3(-0.13, 0.72, 0), true]]:
		var pivot := Node3D.new()
		pivot.position = spec[0]
		parent.add_child(pivot)
		if spec[1]:
			sphere(pivot, 0.1, Vector3.ZERO, joint)
			capsule(pivot, 0.1, 0.42, Vector3(0, -0.24, 0), white)
			capsule(pivot, 0.14, 0.4, Vector3(0, -0.58, 0.06), color, Vector3(PI / 2, 0, 0))
			box(pivot, Vector3(0.24, 0.05, 0.4), Vector3(0, -0.7, 0.06), joint)  # suela
		else:
			sphere(pivot, 0.13, Vector3.ZERO, color, Vector3(1.1, 0.9, 1.1))  # hombrera
			capsule(pivot, 0.085, 0.4, Vector3(0, -0.2, 0), white)
			cylinder(pivot, 0.095, 0.095, 0.06, Vector3(0, -0.3, 0), color, 16)
			sphere(pivot, 0.12, Vector3(0, -0.44, 0), white)  # guante
		bake(pivot)
		limbs.append(pivot)
	bake(parent)  # ~45 piezas en ~20 draw calls
	return limbs


## Sombra redonda bajo un personaje para las escenas sin sombras del Sol (la Tierra de noche): un decal que
## cae en vertical sobre lo que haya debajo (hasta 11 m) y no sobre el propio personaje (sus mallas pasan a la capa 2).
static func blob_shadow(character: Node3D) -> void:
	if not _blob:
		var fade := Gradient.new()
		fade.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0)])
		_blob = GradientTexture2D.new()
		_blob.gradient = fade
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
	for mesh: GeometryInstance3D in character.find_children("*", "GeometryInstance3D", true, false):
		mesh.layers = 2
	var decal := Decal.new()
	decal.texture_albedo = _blob
	decal.size = Vector3(1.6, 12.0, 1.6)
	decal.position.y = -5.0  # de 1 m por encima de los pies a 11 m por debajo
	decal.cull_mask = 1
	decal.upper_fade = 0.0  # a ras de suelo, entera; se aclara al subir (más lejos, abajo en el decal)
	decal.lower_fade = 0.8
	character.add_child(decal)


## Caja sólida (malla + colisión). Devuelve la malla; su padre es el StaticBody3D.
static func solid(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var body := collider(parent, size, pos)
	return box(body, size, Vector3.ZERO, material)


## Colisión invisible en forma de caja.
static func collider(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body


static func label(parent: Node3D, text: String, pos: Vector3, font_size: int, color: Color,
		billboard := true, pixel := 0.01) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font = TITLE_FONT
	node.font_size = font_size
	node.pixel_size = pixel
	node.modulate = color
	node.outline_size = int(font_size / 6.0)
	node.outline_modulate = Color(0.02, 0.04, 0.08, 0.85)
	node.position = pos
	if billboard:
		node.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	parent.add_child(node)
	return node


## Rótulo grande que mira a la cámara; se desvanece al acercarse para no tapar la vista.
static func banner(parent: Node3D, text: String, pos: Vector3, font_size: int, color: Color) -> Label3D:
	var node := label(parent, text, pos, font_size, color, true, 0.009)
	node.visibility_range_begin = 11.0
	node.visibility_range_begin_margin = 3.0
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return node


## Atril de un reto: pedestal blanco con un gran botón de arcade del color del reto y un cartel «¡JUGAR!»
## que flota encima: se entiende de un vistazo que ahí empieza el reto.
static func stand(parent: Node3D, pos: Vector3, color: Color, prompt: String) -> Interactable:
	cylinder(parent, 0.6, 0.8, 1.0, pos + Vector3(0, 0.5, 0), mat(Color("f4f7fb")), 32)
	torus(parent, 0.5, 0.66, pos + Vector3(0, 1.0, 0), mat(color.lightened(0.3), 1.5))
	sphere(parent, 0.46, pos + Vector3(0, 1.02, 0), mat(color, 0.5), Vector3(1, 0.42, 1))
	collider(parent, Vector3(1.6, 1.2, 1.6), pos + Vector3(0, 0.6, 0))
	var sign := label(parent, "¡JUGAR!", pos + Vector3(0, 2.1, 0), 60, color.lightened(0.25), true, 0.009)
	sign.outline_size = 14
	var bob := sign.create_tween().set_loops()
	bob.tween_property(sign, "position:y", pos.y + 2.35, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sign, "position:y", pos.y + 2.1, 0.7).set_trans(Tween.TRANS_SINE)
	return interactable(parent, prompt, pos + Vector3(0, 1, 0), 2.2)


## Zona con la que el jugador puede interactuar, con forma esférica.
static func interactable(parent: Node3D, prompt: String, pos: Vector3, radius := 1.5) -> Interactable:
	var node := Interactable.new()
	node.prompt = prompt
	node.position = pos
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	node.add_child(shape)
	parent.add_child(node)
	return node
