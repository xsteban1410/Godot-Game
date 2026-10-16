extends Node3D
## Ciudad STEAM estilo Astro Bot, de noche y construida por código (no vino la escena de Unity): plaza con el
## STEAM LAB holográfico, siete distritos con arco de color (los cuatro retos del cohete en las calles
## rectas y los tres del laboratorio en las diagonales), la plataforma del cohete, torres de juguete,
## árboles que se mecen y sueltan hojas, farolas, flores, bancos, colinas, nubes que pasan y Volt.
## La noche la iluminan las ventanas, aros y farolas (brillo propio + glow), unas pocas luces reales (plaza,
## distritos y cohete) y charcos de luz falsos bajo las farolas, que no cuestan nada. Sin sombras de la Luna
## (3,5 ms en la Radeon 610M): cada personaje lleva una sombra redonda debajo.
## Todo lo fijo se funde al final con `Kit.bake`: pocos draw calls, culling por trozos y LOD.

const TOWER_SHADER := preload("res://world/tower.gdshader")
const HOLOGRAM_SHADER := preload("res://world/hologram.gdshader")
const GROUND_SHADER := preload("res://world/ground.gdshader")
const TILES_SHADER := preload("res://world/tiles.gdshader")
const FOLIAGE_SHADER := preload("res://world/foliage.gdshader")
const POOL_SHADER := preload("res://world/light_pool.gdshader")
const VOLT := preload("res://world/volt.gd")
const ROCKET := preload("res://modules/rocket.gd")
const MODULE_SCRIPTS := {
	"solar": preload("res://modules/solar.gd"),
	"bridge": preload("res://modules/bridge.gd"),
	"robotics": preload("res://modules/robotics.gd"),
	"recycling": preload("res://modules/recycling.gd"),
	"math": preload("res://modules/math.gd"),
	"vision": preload("res://modules/vision.gd"),
	"ai": preload("res://modules/ai.gd"),
}

const HALF := 80.0
const PLAZA_RADIUS := 16.0
const DISTRICT_RADIUS := 10.0
const DISTRICTS := {
	"solar": Vector3(0, 0, -44),
	"bridge": Vector3(44, 0, 0),
	"recycling": Vector3(0, 0, 44),
	"robotics": Vector3(-44, 0, 0),
	"math": Vector3(30, 0, 30),
	"vision": Vector3(-30, 0, 30),
	"ai": Vector3(-30, 0, -30),
}
const LAUNCH := Vector3(30, 0, -30)  # plataforma del cohete, en la diagonal noreste
const CANDY := ["ffffff", "ffcc00", "2ec4ff", "ff4f8b", "4cd964", "9b6bff", "ff8c1a"]

var _rings := {}  # id de módulo -> aro del distrito
var _star_labels := {}  # id de módulo -> estrellas sobre el arco
var _spinners: Array[Node3D] = []
var _clouds := Node3D.new()
var _horizon := Node3D.new()  # colinas y nubes: siempre a la vista, cada grupo en una sola malla
var _canopies := PackedVector3Array()  # de dónde caen las hojas
var _tower_spots: Array[Vector3] = []  # centro de cada torre con su radio en y (para no plantar flores dentro)
var _volt: Node3D
var _tower_material := ShaderMaterial.new()
var _tiles := ShaderMaterial.new()
var _foliage := ShaderMaterial.new()
var _pool := ShaderMaterial.new()
var _pool_mesh := PlaneMesh.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-38, 35, 0)  # luz de luna; el cielo dibuja la Luna llena en esa dirección
	_rng.seed = 7  # misma ciudad en cada partida
	_tower_material.shader = TOWER_SHADER
	_tiles.shader = TILES_SHADER
	_foliage.shader = FOLIAGE_SHADER
	_pool.shader = POOL_SHADER
	_pool_mesh.size = Vector2(6, 6)
	Kit.blob_shadow($Player)  # de noche la luna no da sombras (costaban 3,5 ms): sombra redonda bajo cada personaje
	var grass := ShaderMaterial.new()
	grass.shader = GROUND_SHADER
	Kit.solid(self, Vector3(HALF * 2, 1, HALF * 2), Vector3(0, -0.5, 0), grass)
	Kit.box(self, Vector3(600, 0.2, 600), Vector3(0, -0.15, 0), grass)
	_plaza()
	for id: String in DISTRICTS:
		_district(id, DISTRICTS[id])
		_road(DISTRICTS[id], DISTRICT_RADIUS)
	var rocket: Node3D = ROCKET.new()
	rocket.transform = Transform3D(Basis.looking_at(LAUNCH.normalized()), LAUNCH)
	add_child(rocket)
	_road(LAUNCH, 4.4)
	_light(self, LAUNCH + Vector3(0, 7, 0), Color(1.0, 0.8, 0.6), 13.0, 1.6)
	_towers()
	_flowers()
	_scenery()
	_leaves()
	_volt = VOLT.new()
	_volt.position = Vector3(9, 0, 9)
	_volt.waypoints = PackedVector3Array([Vector3(9, 0, 9), Vector3(9, 0, -9), Vector3(-9, 0, -9), Vector3(-9, 0, 9)])
	add_child(_volt)
	Kit.blob_shadow(_volt)
	for s in [-1.0, 1.0]:
		Kit.collider(self, Vector3(HALF * 2, 30, 1), Vector3(0, 15, HALF * s))
		Kit.collider(self, Vector3(1, 30, HALF * 2), Vector3(HALF * s, 15, 0))
	Kit.bake(self, _rings.values())
	Kit.bake(_horizon, [], INF)
	Kit.bake(_clouds, [], INF)
	$SteamLab.travel_requested.connect(_travel_to_district)
	Game.stars_changed.connect(_on_stars_changed)


func _process(delta: float) -> void:
	for node in _spinners:
		node.rotate_y(delta * float(node.get_meta("spin")))
	_clouds.rotate_y(delta * 0.004)  # las nubes dan la vuelta a la ciudad en ~26 min


## Llega a la entrada del distrito (o de la plataforma del cohete), mirando al stand del reto.
func _travel_to_district(id: String) -> void:
	var center: Vector3 = DISTRICTS.get(id, LAUNCH)
	var look := center.normalized()
	Game.travel(center - look * (DISTRICT_RADIUS - 2.5) + Vector3(0, 0.2, 0), atan2(-look.x, -look.z))


## Plaza blanca con aros azules, bancos y la terminal holográfica del STEAM LAB en el centro.
func _plaza() -> void:
	_tiled(Kit.cylinder(self, PLAZA_RADIUS, PLAZA_RADIUS, 0.12, Vector3(0, 0.06, 0), _tiles, 64), Color("dfe7f2"))
	Kit.torus(self, PLAZA_RADIUS - 0.6, PLAZA_RADIUS, Vector3(0, 0.12, 0), Kit.mat(Color("1f6fff"), 1.5))
	Kit.torus(self, 6.4, 6.8, Vector3(0, 0.12, 0), Kit.mat(Color("4cc9f0"), 1.5))
	for k in 8:  # bancos entre las calles, mirando al centro
		var a := TAU * (k + 0.5) / 8.0
		var place := Transform3D(Basis(Vector3.UP, a + PI / 2), Vector3(cos(a), 0, -sin(a)) * 13.5)
		var turn := Vector3(0, a + PI / 2, 0)
		var seat := Kit.mat(Color(CANDY[1 + k % 6]))
		Kit.box(self, Vector3(2.2, 0.16, 0.62), place * Vector3(0, 0.5, 0), seat, turn)
		Kit.box(self, Vector3(2.2, 0.5, 0.14), place * Vector3(0, 0.85, 0.3), seat, turn)
		for x in [-0.85, 0.85]:
			Kit.box(self, Vector3(0.16, 0.45, 0.5), place * Vector3(x, 0.22, 0), Kit.mat(Color("f4f7fb")), turn)
		Kit.collider(self, Vector3(2.2, 1.0, 0.7), place * Vector3(0, 0.5, 0.05)).rotation = turn

	Kit.cylinder(self, 2.6, 3.0, 0.7, Vector3(0, 0.35, 0), Kit.mat(Color("f4f7fb")), 48)
	Kit.collider(self, Vector3(4.4, 0.7, 4.4), Vector3(0, 0.35, 0))
	Kit.cylinder(self, 0.6, 0.9, 3.0, Vector3(0, 2.2, 0), Kit.mat(Color("1f6fff"), 0.0, 0.2))
	Kit.collider(self, Vector3(1.6, 3.0, 1.6), Vector3(0, 2.2, 0))
	Kit.collider(self, Vector3(5.2, 2.6, 5.2), Vector3(0, 4.6, 0))  # la cámara nunca se mete dentro del holograma
	var holo := ShaderMaterial.new()
	holo.shader = HOLOGRAM_SHADER
	Kit.sphere(self, 1.0, Vector3(0, 4.6, 0), holo)
	for ring in [[1.5, 0.4, 0.8], [2.0, -0.6, -0.5], [2.5, 0.2, 0.3]]:
		var pivot := Node3D.new()
		pivot.position.y = 4.6
		pivot.set_meta("spin", ring[2])
		add_child(pivot)
		Kit.torus(pivot, ring[0], ring[0] + 0.1, Vector3.ZERO, holo, Vector3(ring[1], 0, 0))
		_spinners.append(pivot)
	Kit.banner(self, "STEAM LAB", Vector3(0, 7.8, 0), 140, Color("1f6fff"))
	var glow := PlaneMesh.new()  # el holograma "ilumina" la plaza con un charco de luz falso: una luz real ahí costaba 1,5 ms
	glow.size = Vector2(26, 26)
	Kit.part(self, glow, Vector3(0, 0.13, 0), _pool).set_meta("tint", Color("3fb6ff"))
	var terminal := Kit.interactable(self, "ENTRAR AL STEAM LAB", Vector3(0, 1, 0), 3.8)
	terminal.marker_height = 2.6
	terminal.interacted.connect($SteamLab.open)


## Distrito: plataforma blanca con aro de color, arco de entrada mirando a la plaza y el reto.
func _district(id: String, center: Vector3) -> void:
	var info: Dictionary = Game.info(id)
	var color: Color = info.color
	_tiled(Kit.cylinder(self, DISTRICT_RADIUS, DISTRICT_RADIUS, 0.16, center + Vector3(0, 0.08, 0), _tiles, 64), Color("f4f7fb"))
	_rings[id] = Kit.torus(self, DISTRICT_RADIUS - 0.6, DISTRICT_RADIUS, center + Vector3(0, 0.16, 0), Kit.mat(color, 0.8))
	_light(self, center + Vector3(0, 6, 0), color.lerp(Color.WHITE, 0.55), 13.0, 1.6)

	var toward_plaza := -center.normalized()
	var gate := Node3D.new()
	gate.transform = Transform3D(Basis.looking_at(-toward_plaza), center + toward_plaza * (DISTRICT_RADIUS + 3.0))  # delante de la cámara al llegar
	add_child(gate)
	Kit.torus(gate, 4.4, 5.3, Vector3.ZERO, Kit.mat(color), Vector3(PI / 2, 0, 0))  # medio aro asoma: un arco
	for side in [-1.0, 1.0]:
		Kit.collider(gate, Vector3(0.9, 5.0, 0.9), Vector3(4.85 * side, 2.5, 0))
	Kit.label(gate, String(info.name).to_upper(), Vector3(0, 6.2, 0), 110, Color.WHITE, false, 0.01)
	_star_labels[id] = Kit.label(gate, "", Vector3(0, 7.4, 0), 120, Game.GOLD, false, 0.01)
	_show_stars(id)

	var module: Node3D = MODULE_SCRIPTS[id].new()
	module.transform = Transform3D(Basis.looking_at(-toward_plaza), center)
	add_child(module)


## Estrellas sobre el arco; con las 3, el aro del distrito brilla.
func _show_stars(id: String) -> void:
	var stars := int(Game.stars.get(id, 0))
	_star_labels[id].text = UI.stars(stars)
	if stars == 3:
		_rings[id].material_override = Kit.mat(Game.info(id).color, 4.0)


## Cada estrella hace bailar a Volt; con las 12 del cohete, fuegos artificiales.
func _on_stars_changed(id: String, _stars: int) -> void:
	if not _rings.has(id):
		return
	_show_stars(id)
	_volt.dance(3.0)
	if Game.MODULES.has(id) and Game.total_stars() == Game.MODULES.size() * 3:
		_fireworks()


## Final de la misión lunar (lo llama el cohete al aterrizar de vuelta).
func finale() -> void:
	_fireworks()
	$HUD.show_certificate(true)


func _fireworks() -> void:
	_volt.dance(9.0)
	for i in 12:  # fuegos artificiales sobre la plaza
		get_tree().create_timer(1.0 + i * 0.35).timeout.connect(func() -> void:
			Sfx.play("boom", 0.3)
			Fx.confetti(self, Vector3(randf_range(-14, 14), randf_range(12, 20), randf_range(-14, 14))))


## Calle clara de la plaza hasta `target` (que mide `end_radius`), con bordillos, luces guía, farolas
## y árboles a los lados. Sirve para cualquier dirección: la malla gira hacia el destino.
func _road(target: Vector3, end_radius: float) -> void:
	var dir := target.normalized()
	var side := dir.cross(Vector3.UP)
	var start := PLAZA_RADIUS - 0.5
	var length := target.length() - end_radius - start + 0.5
	var mid := dir * (start + length / 2.0)
	var yaw := Vector3(0, atan2(dir.x, dir.z), 0)
	_tiled(Kit.box(self, Vector3(8.0, 0.06, length), mid + Vector3(0, 0.03, 0), _tiles, yaw), Color("cdd8e8"))
	for s in [-4.2, 4.2]:
		Kit.box(self, Vector3(0.5, 0.2, length), mid + side * s + Vector3(0, 0.1, 0), Kit.mat(Color.WHITE), yaw)
	var guide := Kit.mat(Color("4cc9f0"), 2.0)
	for d in range(int(start) + 2, int(start + length) - 1, 3):
		Kit.sphere(self, 0.16, dir * d + Vector3(0, 0.08, 0), guide, Vector3(1, 0.4, 1), 10)
	for t in range(int(start) + 3, int(start + length) - 2, 6):
		for s in [-6.5, 6.5]:
			_tree(dir * t + side * s)
		if t + 3 < start + length - 1:
			for s in [-4.9, 4.9]:
				_lamp(dir * (t + 3) + side * s)


## Farola de juguete: poste blanco y globo de luz cálida.
func _lamp(p: Vector3) -> void:
	Kit.cylinder(self, 0.07, 0.1, 3.0, p + Vector3(0, 1.5, 0), Kit.mat(Color("f4f7fb")), 10)
	Kit.cylinder(self, 0.28, 0.16, 0.12, p + Vector3(0, 3.0, 0), Kit.mat(Color("1f6fff")), 12)
	Kit.sphere(self, 0.24, p + Vector3(0, 3.28, 0), Kit.mat(Color("fff1b8"), 3.0), Vector3.ONE, 12)
	var pool := Kit.part(self, _pool_mesh, p + Vector3(0, 0.09, 0), _pool)
	pool.set_meta("tint", Color("ffcf7a"))
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.collider(self, Vector3(0.25, 3.0, 0.25), p + Vector3(0, 1.5, 0))


## Torres de juguete en las manzanas libres (fuera de calles, plaza, distritos y cohete).
func _towers() -> void:
	for gx in range(-5, 6):
		for gz in range(-5, 6):
			var p := Vector3(gx * 13.0, 0, gz * 13.0)
			if p.length() < 26.0 or absf(p.x) < 11.0 or absf(p.z) < 11.0 or absf(p.x) > 72.0 or absf(p.z) > 72.0:
				continue
			if absf(absf(p.x) - absf(p.z)) < 13.0 and p.length() < 52.0:  # calles diagonales
				continue
			if p.distance_to(LAUNCH) < 15.0 or DISTRICTS.values().any(func(d: Vector3) -> bool: return p.distance_to(d) < 19.0):
				continue
			p += Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
			var radius := _rng.randf_range(2.8, 4.4)
			var height := _rng.randf_range(6, 12) + (absf(p.x) + absf(p.z)) * 0.1
			var body := Color(CANDY[_rng.randi() % CANDY.size()])
			var accent := Kit.mat(Color(CANDY[_rng.randi() % CANDY.size()]))
			_tower_spots.append(Vector3(p.x, radius, p.z))
			var mesh := Kit.cylinder(self, radius, radius, height, p + Vector3(0, height / 2.0, 0), _tower_material, 32)
			mesh.set_meta("tint", Color(body, _rng.randf()))  # alfa = semilla de las ventanas encendidas
			Kit.collider(self, Vector3(radius * 1.8, height, radius * 1.8), p + Vector3(0, height / 2.0, 0))
			Kit.cylinder(self, radius + 0.35, radius + 0.45, 0.6, p + Vector3(0, 0.3, 0), accent, 32)  # zócalo
			Kit.sphere(self, radius, p + Vector3(0, height, 0), accent, Vector3(1, 0.55, 1))
			Kit.torus(self, radius - 0.05, radius + 0.35, p + Vector3(0, height * 0.35, 0), accent)
			if _rng.randf() < 0.5:
				Kit.cylinder(self, 0.05, 0.05, 1.2, p + Vector3(0, height + radius * 0.55 + 0.4, 0), Kit.mat(Color("f4f7fb")), 8)
				Kit.sphere(self, 0.3, p + Vector3(0, height + radius * 0.55 + 1.1, 0), Kit.mat(Color("4cc9f0"), 2.0), Vector3.ONE, 12)


## Matas de flores de colores en el césped, lejos de calles y edificios.
func _flowers() -> void:
	var stem := Kit.mat(Color("2fa84f"))
	var placed := 0
	while placed < 70:
		var p := Vector3(_rng.randf_range(-74, 74), 0, _rng.randf_range(-74, 74))
		var free := absf(p.x) > 8.0 and absf(p.z) > 8.0 and absf(absf(p.x) - absf(p.z)) > 11.0 and p.length() > 19.0
		if not free or DISTRICTS.values().any(func(d: Vector3) -> bool: return p.distance_to(d) < 13.0) or p.distance_to(LAUNCH) < 8.0 \
				or _tower_spots.any(func(t: Vector3) -> bool: return Vector2(p.x - t.x, p.z - t.z).length() < t.y + 1.5):
			continue
		placed += 1
		Kit.sphere(self, 0.4, p, stem, Vector3(1.4, 0.45, 1.1), 10)
		var petal := Kit.mat(Color(CANDY[1 + _rng.randi() % 6]))
		for k in 3:
			var a := TAU * k / 3.0 + _rng.randf()
			Kit.sphere(self, 0.15, p + Vector3(cos(a) * 0.32, 0.24 + 0.08 * k, sin(a) * 0.32), petal, Vector3.ONE, 8)


## Colinas y nubes alrededor: el horizonte de "mundo de juguete" de Astro Bot. Las nubes giran despacio.
func _scenery() -> void:
	add_child(_horizon)
	for i in 14:
		var a := TAU * i / 14.0 + _rng.randf_range(-0.1, 0.1)
		var r := _rng.randf_range(35, 60)
		Kit.sphere(_horizon, r, Vector3(cos(a), 0, sin(a)) * _rng.randf_range(130, 170) + Vector3(0, -r * 0.45, 0),
			Kit.mat(Color("6ccf4a") if i % 2 else Color("8fdc5a"), 0.0, 0.0, 0.6), Vector3.ONE, 32)
	add_child(_clouds)
	var cloud := Kit.mat(Color("9aa8d8"), 0.1, 0.0, 0.9)  # nubes iluminadas por la Luna
	for i in 12:
		var a := TAU * i / 12.0
		var center := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(60, 110) + Vector3(0, _rng.randf_range(30, 45), 0)
		for j in 4:
			var puff := Kit.sphere(_clouds, _rng.randf_range(3, 6), center + Vector3(j * 4.0 - 6.0, _rng.randf_range(-1, 1.5), _rng.randf_range(-2, 2)), cloud, Vector3(1, 0.7, 1), 16)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Luz real (sin sombra): solo unas pocas, la GPU integrada paga cada una en cada píxel que alcanza.
func _light(parent: Node3D, pos: Vector3, color: Color, reach: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.omni_range = reach
	light.light_energy = energy
	parent.add_child(light)


func _tiled(mesh: MeshInstance3D, color: Color) -> void:
	mesh.set_meta("tint", color)


## Árbol de juguete: tronco y copa de cuatro bolas que se mece con el viento; algunos dan fruta.
func _tree(p: Vector3) -> void:
	Kit.cylinder(self, 0.15, 0.26, 2.2, p + Vector3(0, 1.1, 0), Kit.mat(Color("9a6238")), 10)
	var green := Color("3fcf5a") if _rng.randf() < 0.5 else Color("72d65e")
	for blob: Array in [[Vector3(0, 2.8, 0), 1.25], [Vector3(0.8, 2.45, 0.25), 0.8], [Vector3(-0.7, 2.5, -0.3), 0.85], [Vector3(0.15, 3.65, 0.1), 0.78]]:
		Kit.sphere(self, blob[1], p + blob[0], _foliage, Vector3.ONE, 18).set_meta("tint", green.lightened(0.18) if blob[0].y > 3.0 else green)
	if _rng.randf() < 0.35:
		for k in 3:
			var a := TAU * k / 3.0
			Kit.sphere(self, 0.13, p + Vector3(cos(a) * 1.1, 2.4 + 0.3 * k, sin(a) * 1.1), Kit.mat(Color("ff4f5e")), Vector3.ONE, 8)
	Kit.collider(self, Vector3(0.5, 2.2, 0.5), p + Vector3(0, 1.1, 0))
	for k in 2:
		_canopies.append(p + Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(2.2, 3.4), _rng.randf_range(-1.0, 1.0)))


## Hojas que caen de todas las copas: un solo sistema de partículas (un draw call) que nace en ellas.
func _leaves() -> void:
	var leaf := Kit.merge([[_leaf_mesh(), Transform3D(Basis.from_euler(Vector3(0.7, 0, 0.4)), Vector3.ZERO), Color.WHITE]])
	var fall := CPUParticles3D.new()
	fall.mesh = leaf
	fall.amount = 140
	fall.lifetime = 7.0
	fall.preprocess = 7.0
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	fall.emission_points = _canopies
	fall.direction = Vector3(1, 0, 0.3)
	fall.spread = 180.0
	fall.initial_velocity_min = 0.2
	fall.initial_velocity_max = 0.8
	fall.gravity = Vector3(0.35, -0.55, 0.1)  # caen despacio, empujadas por la brisa
	fall.particle_flag_rotate_y = true
	fall.angular_velocity_min = -220.0
	fall.angular_velocity_max = 220.0
	fall.angle_max = 360.0
	fall.scale_amount_min = 0.7
	fall.scale_amount_max = 1.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.85, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	fall.scale_amount_curve = shrink
	var colors := Gradient.new()
	colors.colors = PackedColorArray([Color("3fcf5a"), Color("8fdc5a"), Color("ffcc33"), Color("ff9f43")])
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	fall.color_initial_ramp = colors
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.4
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	fall.material_override = paint
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)


func _leaf_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.06
	mesh.radial_segments = 8
	mesh.rings = 3
	return mesh
