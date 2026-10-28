extends Node3D
## Ciudad STEAM estilo Astro Bot, de noche: plaza con el STEAM LAB holográfico, siete distritos con arco de color
## (los cuatro retos del cohete en las calles rectas y los tres del laboratorio en las diagonales), la plataforma
## del cohete y edificios, árboles y farolas de Kenney. La parte fija (`city_static.gd`) se genera y hornea antes
## (luz precalculada con LightmapGI) y aquí se carga ya iluminada; este script pone lo que se mueve o cambia:
## retos, robots, aros que brillan con 3 ★, rótulos, nubes, hojas y tuercas. Los personajes llevan una sombra
## redonda: las de la luna solo existen horneadas en lo fijo.

const STATIC_SCENE := "res://world/city_static.scn"
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
const LANDMARK := 14.0  # distancia del monumento de cada distrito a su centro, por detrás
const LANDMARK_BOLTS := {  # tuerca dorada de cada monumento, en sus coordenadas
	"solar": Vector3(-3.4, 6.0, 0.9),  # delante del girasol de la izquierda
	"bridge": Vector3(0, 6.0, 1.8),  # a media altura de la grúa
	"robotics": Vector3(0, 2.4, 1.6),  # sobre la base del brazo robótico
	"recycling": Vector3(-3.2, 8.7, 0),  # sobre el tapón de la botella: se sube desde el camión
	"math": Vector3(3.6, 2.0, 1.4),
	"vision": Vector3(3.6, 6.9, 0.5),  # delante del corazón de píxeles
	"ai": Vector3(3.2, 3.6, 0),  # dentro de la O gigante
}

const WELCOME := "¡Bienvenido a Ciudad STEAM! Gana estrellas en los retos: cada una es una pieza del cohete de agua que te llevará a la Luna."

static var _welcomed := false

var _rings := {}  # id de módulo -> aro del distrito
var _star_labels := {}  # id de módulo -> estrellas sobre el arco
var _spinners: Array[Node3D] = []
var _clouds := Node3D.new()
var _robots: Array[Node3D] = []  # Volt y los ciudadanos: bailan con cada estrella


## Transformación del arco de entrada de un distrito (mirando a la plaza, delante de la cámara al llegar).
static func gate(id: String) -> Transform3D:
	var center: Vector3 = DISTRICTS[id]
	var dir := center.normalized()
	return Transform3D(Basis.looking_at(dir), center - dir * (DISTRICT_RADIUS + 3.0))


func _ready() -> void:
	var fixed: Node3D
	if ResourceLoader.exists(STATIC_SCENE):
		fixed = load(STATIC_SCENE).instantiate()
	else:  # sin hornear (p. ej. tras cambiar la ciudad y antes de tools/build_city.gd): se genera al vuelo
		fixed = Node3D.new()
		fixed.set_script(load("res://world/city_static.gd"))
	fixed.name = "Static"
	add_child(fixed)
	var moon: DirectionalLight3D = fixed.get_node("Moon")
	moon.shadow_enabled = false  # sus sombras ya están horneadas en lo fijo; los personajes llevan la redonda
	for light: Light3D in fixed.find_children("*", "Light3D", true, false):
		light.visible = not light.has_meta("bake_only")
	var lightmap: LightmapGI = fixed.get_node_or_null("LightmapGI")
	fixed.get_node("Pools").visible = not (lightmap and lightmap.light_data)  # con luz horneada sobran los charcos falsos
	for node: Node3D in fixed.find_children("*", "Node3D", true, false):
		if node.has_meta("spin"):
			_spinners.append(node)
		if node.has_meta("bob"):
			var bob := node.create_tween().set_loops()
			bob.tween_property(node, "position:y", node.position.y + 0.4, node.get_meta("bob")).set_trans(Tween.TRANS_SINE)
			bob.tween_property(node, "position:y", node.position.y, node.get_meta("bob")).set_trans(Tween.TRANS_SINE)
	Kit.blob_shadow($Player)
	_terminal()
	for id: String in DISTRICTS:
		_district(id)
	var rocket: Node3D = ROCKET.new()
	rocket.transform = Transform3D(Basis.looking_at(LAUNCH.normalized()), LAUNCH)
	add_child(rocket)
	_clouds_ring()
	_leaves(fixed.get_meta("canopies", PackedVector3Array()))
	_walker(Color("ff8a1f"), PackedVector3Array([Vector3(9, 0, 9), Vector3(9, 0, -9), Vector3(-9, 0, -9), Vector3(-9, 0, 9)]))  # Volt
	for spec: Array in [["solar", Color("ff4f8b"), 1.6], ["bridge", Color("ffcc00"), -1.6], ["recycling", Color("9b6bff"), 1.6], ["robotics", Color("4cd964"), -1.6]]:
		var dir: Vector3 = DISTRICTS[spec[0]].normalized()
		var side: Vector3 = dir.cross(Vector3.UP) * spec[2]  # a un lado de la calle, fuera de las luces guía
		_walker(spec[1], PackedVector3Array([dir * 19.0 + side, dir * 30.0 + side]))
	_bolts()
	if not _welcomed:  # la bienvenida, una vez por sesión (no al volver de la Luna)
		_welcomed = true
		get_tree().create_timer(2.0).timeout.connect(Game.notify.bind(WELCOME, Game.GOLD))
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


## La terminal del STEAM LAB en el centro de la plaza (el pedestal y el holograma están en lo fijo).
func _terminal() -> void:
	var terminal := Kit.interactable(self, "ENTRAR AL STEAM LAB", Vector3(0, 1, 0), 3.8)
	terminal.marker_height = 2.6
	terminal.interacted.connect($SteamLab.open)


## Lo que cambia en cada distrito: el aro de color (brilla con 3 ★), el nombre y las estrellas sobre el arco y el reto.
func _district(id: String) -> void:
	var info: Dictionary = Game.info(id)
	var center: Vector3 = DISTRICTS[id]
	_rings[id] = Kit.torus(self, DISTRICT_RADIUS - 0.6, DISTRICT_RADIUS, center + Vector3(0, 0.16, 0), Kit.mat(info.color, 0.8))
	var arch := Node3D.new()
	arch.transform = gate(id)
	add_child(arch)
	Kit.label(arch, String(info.name).to_upper(), Vector3(0, 6.2, 0), 110, Color.WHITE, false, 0.01)
	_star_labels[id] = Kit.label(arch, "", Vector3(0, 7.4, 0), 120, Game.GOLD, false, 0.01)
	_show_stars(id)
	var module: Node3D = MODULE_SCRIPTS[id].new()
	module.transform = Transform3D(Basis.looking_at(center.normalized()), center)
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
	for robot in _robots:
		robot.dance(3.0)
	if Game.MODULES.has(id) and Game.total_stars() == Game.MODULES.size() * 3:
		_fireworks()


## Final de la misión lunar (lo llama el cohete al aterrizar de vuelta).
func finale() -> void:
	_fireworks()
	$HUD.show_certificate(true)


func _fireworks() -> void:
	for robot in _robots:
		robot.dance(9.0)
	for i in 12:  # fuegos artificiales sobre la plaza
		get_tree().create_timer(1.0 + i * 0.35).timeout.connect(func() -> void:
			Sfx.play("boom", 0.3)
			Fx.confetti(self, Vector3(randf_range(-14, 14), randf_range(12, 20), randf_range(-14, 14))))


## Robot que pasea por `waypoints` (port de SteamRobotNPC) y saluda si te acercas.
func _walker(accent: Color, waypoints: PackedVector3Array) -> void:
	var robot: Node3D = VOLT.new()
	robot.accent = accent
	robot.position = waypoints[0]
	robot.waypoints = waypoints
	add_child(robot)
	Kit.blob_shadow(robot)
	_robots.append(robot)


## Tuercas doradas: sobre la terminal y los arcos, en los monumentos, el tejado solar, el río, los andamios
## del cohete y las cuatro esquinas de la ciudad. Todas se alcanzan saltando o con el jetpack.
func _bolts() -> void:
	var spots: Array[Vector3] = [Vector3(0, 6.5, 0), Vector3(72, 0.8, 72), Vector3(-72, 0.8, 72), Vector3(72, 0.8, -72), Vector3(-72, 0.8, -72)]
	for id: String in DISTRICTS:
		var center: Vector3 = DISTRICTS[id]
		var dir := center.normalized()
		spots.append(center - dir * (DISTRICT_RADIUS + 3.0) + Vector3(0, 5.9, 0))  # sobre el arco de entrada
		spots.append(Transform3D(Basis.looking_at(dir), center + dir * LANDMARK) * LANDMARK_BOLTS[id])
	spots.append(Transform3D(Basis.looking_at(Vector3.FORWARD), DISTRICTS.solar) * Vector3(0, 5.2, -5))  # sobre el tejado solar
	spots.append(Transform3D(Basis.looking_at(Vector3.RIGHT), DISTRICTS.bridge) * Vector3(5.5, 0.8, -3.75))  # en el río
	spots.append(Transform3D(Basis.looking_at(LAUNCH.normalized()), LAUNCH) * Vector3(-3.3, 6.0, 1.2))  # junto a los andamios
	for i in spots.size():
		Bolt.spawn(self, "city_%d" % i, spots[i])


## Nubes que dan la vuelta a la ciudad, iluminadas por la Luna.
func _clouds_ring() -> void:
	add_child(_clouds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cloud := Kit.mat(Color("9aa8d8"), 0.1, 0.0, 0.9)
	for i in 12:
		var a := TAU * i / 12.0
		var center := Vector3(cos(a), 0, sin(a)) * rng.randf_range(60, 110) + Vector3(0, rng.randf_range(30, 45), 0)
		for j in 4:
			var puff := Kit.sphere(_clouds, rng.randf_range(3, 6), center + Vector3(j * 4.0 - 6.0, rng.randf_range(-1, 1.5), rng.randf_range(-2, 2)), cloud, Vector3(1, 0.7, 1), 16)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.bake(_clouds, [], INF)


## Hojas que caen de todas las copas (`canopies`): un solo sistema de partículas (un draw call) que nace en ellas.
func _leaves(canopies: PackedVector3Array) -> void:
	var leaf := Kit.merge([[_leaf_mesh(), 0, Transform3D(Basis.from_euler(Vector3(0.7, 0, 0.4)), Vector3.ZERO), Color.WHITE]])
	var fall := CPUParticles3D.new()
	fall.mesh = leaf
	fall.amount = 140
	fall.lifetime = 7.0
	fall.preprocess = 7.0
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	fall.emission_points = canopies
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
