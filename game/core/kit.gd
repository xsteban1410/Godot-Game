class_name Kit
## Fábrica de mallas, materiales y textos 3D procedurales, compartida por todo el juego.
## En Unity, cada script tenía su propio CreatePrimitive/CreateMaterial; aquí hay uno solo con caché.

const TITLE_FONT := preload("res://ui/fonts/Rubik-ExtraBold.ttf")
const EYE_SHADER := preload("res://core/eye.gdshader")

static var _materials := {}


## Plástico de juguete estilo Astro Bot: brillante, con barniz y un borde de luz que separa la silueta.
static func mat(color: Color, emission := 0.0, metallic := 0.0, roughness := 0.3) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), emission, metallic, roughness]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		m.clearcoat_enabled = true
		m.clearcoat = 0.7
		m.clearcoat_roughness = 0.12
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
	var mesh := BoxMesh.new()
	mesh.size = size
	return part(parent, mesh, pos, material, rot)


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16 if radius < 0.3 else 32 if radius < 4.0 else 48  # el valor por defecto (64) sobra y pesa en GPU integrada
	mesh.rings = mesh.radial_segments / 2
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
	mesh.rings = 40
	mesh.ring_segments = 16
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
		limbs.append(pivot)
	return limbs


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


## Zona con la que el jugador puede interactuar, con forma esférica.
static func interactable(parent: Node3D, prompt: String, pos: Vector3, radius := 1.5, message := "") -> Interactable:
	var node := Interactable.new()
	node.prompt = prompt
	node.message = message
	node.position = pos
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	node.add_child(shape)
	parent.add_child(node)
	return node
