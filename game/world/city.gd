extends Node3D
## Ciudad STEAM estilo Astro Bot, construida por código (no vino la escena de Unity): plaza con el
## STEAM LAB holográfico, cuatro distritos con arco de color (uno por reto), calles, torres de juguete,
## árboles piruleta, colinas, nubes y Volt patrullando.

const TOWER_SHADER := preload("res://world/tower.gdshader")
const HOLOGRAM_SHADER := preload("res://world/hologram.gdshader")
const GROUND_SHADER := preload("res://world/ground.gdshader")
const TILES_SHADER := preload("res://world/tiles.gdshader")
const VOLT := preload("res://world/volt.gd")
const MODULE_SCRIPTS := {
	"solar": preload("res://modules/solar.gd"),
	"bridge": preload("res://modules/bridge.gd"),
	"robotics": preload("res://modules/robotics.gd"),
	"recycling": preload("res://modules/recycling.gd"),
}

const HALF := 80.0
const PLAZA_RADIUS := 16.0
const DISTRICT_RADIUS := 10.0
const DISTRICTS := {
	"solar": Vector3(0, 0, -44),
	"bridge": Vector3(44, 0, 0),
	"recycling": Vector3(0, 0, 44),
	"robotics": Vector3(-44, 0, 0),
}
const LAUNCH := Vector3(30, 0, -30)  # plataforma del cohete, en la diagonal noreste
const ROCKET := preload("res://modules/rocket.gd")
const CANDY := ["ffffff", "ffcc00", "2ec4ff", "ff4f8b", "4cd964", "9b6bff", "ff8c1a"]

var terminal: Interactable
var _rings := {}  # id de módulo -> aro del distrito
var _star_labels := {}  # id de módulo -> estrellas sobre el arco
var _spinners: Array[Node3D] = []
var _tower_material := ShaderMaterial.new()
var _tiles := ShaderMaterial.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-55, 35, 0)
	_rng.seed = 7  # misma ciudad en cada partida
	_tower_material.shader = TOWER_SHADER
	_tiles.shader = TILES_SHADER
	var grass := ShaderMaterial.new()
	grass.shader = GROUND_SHADER
	Kit.solid(self, Vector3(HALF * 2, 1, HALF * 2), Vector3(0, -0.5, 0), grass)
	Kit.box(self, Vector3(600, 0.2, 600), Vector3(0, -0.15, 0), grass)
	_plaza()
	for id: String in DISTRICTS:
		_district(id, DISTRICTS[id])
		_road(DISTRICTS[id])
	_launch_site()
	_towers()
	_scenery()
	var volt := VOLT.new()
	volt.position = Vector3(12, 0, 12)
	volt.waypoints = PackedVector3Array([Vector3(12, 0, 12), Vector3(12, 0, -12), Vector3(-12, 0, -12), Vector3(-12, 0, 12)])
	add_child(volt)
	for s in [-1.0, 1.0]:
		Kit.collider(self, Vector3(HALF * 2, 30, 1), Vector3(0, 15, HALF * s))
		Kit.collider(self, Vector3(1, 30, HALF * 2), Vector3(HALF * s, 15, 0))
	$SteamLab.travel_requested.connect(_travel_to_district)
	Game.stars_changed.connect(_on_stars_changed)


func _process(delta: float) -> void:
	for node in _spinners:
		node.rotate_y(delta * float(node.get_meta("spin")))


## Llega a la entrada del distrito, ya dentro del aro, mirando al stand del reto.
func _travel_to_district(id: String) -> void:
	var center: Vector3 = DISTRICTS[id]
	var look := center.normalized()
	Game.travel(center - look * (DISTRICT_RADIUS - 2.5) + Vector3(0, 0.2, 0), atan2(-look.x, -look.z))


## Plaza blanca con aros azules y la terminal holográfica del STEAM LAB en el centro.
func _plaza() -> void:
	_tiled(Kit.cylinder(self, PLAZA_RADIUS, PLAZA_RADIUS, 0.12, Vector3(0, 0.06, 0), _tiles, 64), Color("dfe7f2"))
	Kit.torus(self, PLAZA_RADIUS - 0.6, PLAZA_RADIUS, Vector3(0, 0.12, 0), Kit.mat(Color("1f6fff"), 1.5))
	Kit.torus(self, 6.4, 6.8, Vector3(0, 0.12, 0), Kit.mat(Color("4cc9f0"), 1.5))

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
	Kit.label(self, "STEAM LAB", Vector3(0, 7.8, 0), 140, Color("1f6fff"), true, 0.012)
	terminal = Kit.interactable(self, "ENTRAR AL STEAM LAB", Vector3(0, 1, 0), 3.8)
	terminal.marker_height = 2.6
	terminal.interacted.connect($SteamLab.open)


## Distrito: plataforma blanca con aro de color, arco de entrada mirando a la plaza y stand del reto.
func _district(id: String, center: Vector3) -> void:
	var info: Dictionary = Game.MODULES[id]
	var color: Color = info.color
	var title := String(info.name).to_upper()
	_tiled(Kit.cylinder(self, DISTRICT_RADIUS, DISTRICT_RADIUS, 0.16, center + Vector3(0, 0.08, 0), _tiles, 64), Color("f4f7fb"))
	_rings[id] = Kit.torus(self, DISTRICT_RADIUS - 0.6, DISTRICT_RADIUS, center + Vector3(0, 0.16, 0), Kit.mat(color, 0.8))

	var toward_plaza := -center.normalized()
	var gate := Node3D.new()
	gate.transform = Transform3D(Basis.looking_at(-toward_plaza), center + toward_plaza * (DISTRICT_RADIUS + 3.0))  # delante de la cámara al llegar
	add_child(gate)
	Kit.torus(gate, 4.4, 5.3, Vector3.ZERO, Kit.mat(color), Vector3(PI / 2, 0, 0))  # medio aro asoma: un arco
	for side in [-1.0, 1.0]:
		Kit.collider(gate, Vector3(0.9, 5.0, 0.9), Vector3(4.85 * side, 2.5, 0))
	Kit.label(gate, title, Vector3(0, 6.2, 0), 110, Color.WHITE, false, 0.01)
	_star_labels[id] = Kit.label(gate, "", Vector3(0, 7.4, 0), 120, Game.GOLD, false, 0.01)
	_show_stars(id)

	var module: Node3D = MODULE_SCRIPTS[id].new()
	module.transform = Transform3D(Basis.looking_at(-toward_plaza), center)
	add_child(module)


## Estrellas sobre el arco; con las 3, el aro del distrito brilla. Con las 12, fuegos artificiales.
func _show_stars(id: String) -> void:
	var stars := int(Game.stars.get(id, 0))
	_star_labels[id].text = UI.stars(stars)
	if stars == 3:
		_rings[id].material_override = Kit.mat(Game.MODULES[id].color, 4.0)


func _on_stars_changed(id: String, _stars: int) -> void:
	if not Game.MODULES.has(id):
		return
	_show_stars(id)
	if Game.total_stars() < Game.MODULES.size() * 3:
		return
	for i in 12:  # fuegos artificiales sobre la plaza
		get_tree().create_timer(1.0 + i * 0.35).timeout.connect(func() -> void:
			Sfx.play("boom", 0.3)
			Fx.confetti(self, Vector3(randf_range(-14, 14), randf_range(12, 20), randf_range(-14, 14))))


## Calle clara de la plaza al distrito, con bordillos blancos, luces guía y árboles piruleta.
func _road(district: Vector3) -> void:
	var dir := district.normalized()
	var side := Vector3(dir.z, 0, dir.x)
	var start := PLAZA_RADIUS - 0.5
	var length := district.length() - DISTRICT_RADIUS - start + 0.5
	var along_x := absf(dir.x) > 0.5
	var mid := dir * (start + length / 2.0)
	_tiled(Kit.box(self, Vector3(length, 0.06, 8.0) if along_x else Vector3(8.0, 0.06, length), mid + Vector3(0, 0.03, 0), _tiles), Color("cdd8e8"))
	for s in [-4.2, 4.2]:
		Kit.box(self, Vector3(length, 0.2, 0.5) if along_x else Vector3(0.5, 0.2, length), mid + side * s + Vector3(0, 0.1, 0), Kit.mat(Color.WHITE))
	var guide := Kit.mat(Color("4cc9f0"), 2.0)
	for d in range(int(start) + 2, int(start + length) - 1, 3):
		Kit.sphere(self, 0.16, dir * d + Vector3(0, 0.08, 0), guide, Vector3(1, 0.4, 1))
	for t in range(int(start) + 3, int(start + length) - 2, 6):
		for s in [-6.5, 6.5]:
			_tree(dir * t + side * s)


## Plataforma del cohete con su camino diagonal desde la plaza.
func _launch_site() -> void:
	var rocket: Node3D = ROCKET.new()
	rocket.transform = Transform3D(Basis.looking_at(LAUNCH.normalized()), LAUNCH)
	add_child(rocket)
	var length := LAUNCH.length() - PLAZA_RADIUS - 4.0
	var mid := LAUNCH.normalized() * (PLAZA_RADIUS + length / 2.0 - 0.5)
	_tiled(Kit.box(self, Vector3(6.0, 0.06, length), mid + Vector3(0, 0.03, 0), _tiles, Vector3(0, -PI / 4, 0)), Color("cdd8e8"))


## Torres de juguete en las manzanas libres (fuera de calles, plaza y distritos).
func _towers() -> void:
	for gx in range(-5, 6):
		for gz in range(-5, 6):
			var p := Vector3(gx * 13.0, 0, gz * 13.0)
			if Vector2(p.x, p.z).length() < 26.0 or absf(p.x) < 11.0 or absf(p.z) < 11.0 or absf(p.x) > 72.0 or absf(p.z) > 72.0:
				continue
			if p.distance_to(LAUNCH) < 15.0 or DISTRICTS.values().any(func(d: Vector3) -> bool: return p.distance_to(d) < 19.0):
				continue
			p += Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
			var radius := _rng.randf_range(2.8, 4.4)
			var height := _rng.randf_range(6, 12) + (absf(p.x) + absf(p.z)) * 0.1
			var body := Color(CANDY[_rng.randi() % CANDY.size()])
			var accent := Color(CANDY[_rng.randi() % CANDY.size()])
			var mesh := Kit.cylinder(self, radius, radius, height, p + Vector3(0, height / 2.0, 0), _tower_material, 32)
			mesh.set_instance_shader_parameter("body_color", Vector3(body.r, body.g, body.b))
			mesh.set_instance_shader_parameter("seed", _rng.randf() * 100.0)
			Kit.collider(self, Vector3(radius * 1.8, height, radius * 1.8), p + Vector3(0, height / 2.0, 0))
			Kit.sphere(self, radius, p + Vector3(0, height, 0), Kit.mat(accent), Vector3(1, 0.55, 1))
			Kit.torus(self, radius - 0.05, radius + 0.35, p + Vector3(0, height * 0.35, 0), Kit.mat(accent))
			if _rng.randf() < 0.5:
				Kit.sphere(self, 0.35, p + Vector3(0, height + radius * 0.55 + 0.4, 0), Kit.mat(Color("4cc9f0"), 4.0))


## Colinas y nubes alrededor: el horizonte de "mundo de juguete" de Astro Bot.
func _scenery() -> void:
	for i in 14:
		var a := TAU * i / 14.0 + _rng.randf_range(-0.1, 0.1)
		var r := _rng.randf_range(35, 60)
		Kit.sphere(self, r, Vector3(cos(a), 0, sin(a)) * _rng.randf_range(130, 170) + Vector3(0, -r * 0.45, 0),
			Kit.mat(Color("6ccf4a") if i % 2 else Color("8fdc5a"), 0.0, 0.0, 0.6))
	var cloud := Kit.mat(Color.WHITE, 0.25, 0.0, 0.9)
	for i in 12:
		var a := TAU * i / 12.0
		var center := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(60, 110) + Vector3(0, _rng.randf_range(30, 45), 0)
		for j in 4:
			Kit.sphere(self, _rng.randf_range(3, 6), center + Vector3(j * 4.0 - 6.0, _rng.randf_range(-1, 1.5), _rng.randf_range(-2, 2)), cloud, Vector3(1, 0.7, 1))


func _tiled(mesh: MeshInstance3D, color: Color) -> void:
	mesh.set_instance_shader_parameter("base", Vector3(color.r, color.g, color.b))


func _tree(p: Vector3) -> void:
	Kit.cylinder(self, 0.18, 0.22, 1.8, p + Vector3(0, 0.9, 0), Kit.mat(Color("8a5a35")), 12)
	var leaves := Color("3fcf5a") if _rng.randf() < 0.5 else Color("7bd389")
	Kit.sphere(self, 1.2, p + Vector3(0, 2.6, 0), Kit.mat(leaves))
	Kit.sphere(self, 0.7, p + Vector3(0.35, 3.35, 0.25), Kit.mat(leaves.lightened(0.2)))
	Kit.collider(self, Vector3(0.45, 2, 0.45), p + Vector3(0, 1, 0))
