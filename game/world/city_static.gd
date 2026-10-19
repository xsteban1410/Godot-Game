extends Node3D
## La parte fija de Ciudad STEAM: suelo, plaza, calles con farolas y árboles, discos y arcos de los distritos,
## monumentos, edificios de Kenney, flores, colinas, luces y bordes. `tools/build_city.gd` la genera una vez,
## le desenvuelve las UV2 y la guarda en `world/city_static.scn`, y el plugin `bake_tool` hornea su LightmapGI
## (luz de luna con sombras, farolas, distritos y ventanas que iluminan la calle). En el juego se carga ya
## horneada; si faltara, la ciudad la genera al arrancar con este mismo script, sin luz precalculada.
## Lo que gira (meta "spin") o flota (meta "bob") lo anima la ciudad; las luces con meta "bake_only" solo
## existen para hornear y se apagan al jugar. "Pools" son charcos de luz falsos bajo las farolas: el respaldo
## mientras la ciudad no esté horneada (con lightmap la ciudad los oculta).

const CITY := preload("res://world/city.gd")
const BUILDING_SHADER := preload("res://world/building.gdshader")
const HOLOGRAM_SHADER := preload("res://world/hologram.gdshader")
const GROUND_SHADER := preload("res://world/ground.gdshader")
const TILES_SHADER := preload("res://world/tiles.gdshader")
const POOL_SHADER := preload("res://world/light_pool.gdshader")
const SHOPS := ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k"]  # edificios de Kenney (City Kit Commercial)
const TALL := ["l", "m", "n", "skyscraper-a", "skyscraper-b", "skyscraper-c", "skyscraper-d", "skyscraper-e"]
const HOUSES := "abcdefghijklmnopqrstu"  # casas de Kenney (City Kit Suburban)
const TREES := ["tree_oak", "tree_default", "tree_detailed", "tree_fat", "tree_simple", "tree_tall"]  # Nature Kit
const FLOWERS := ["flower_redA", "flower_redB", "flower_yellowA", "flower_yellowB", "flower_purpleA", "flower_purpleB"]
const CANDY := ["ffffff", "ffcc00", "2ec4ff", "ff4f8b", "4cd964", "9b6bff", "ff8c1a"]

var _canopies := PackedVector3Array()  # de dónde caen las hojas (se guarda como meta "canopies")
var _tower_spots: Array[Vector3] = []  # centro de cada edificio con su radio en y (para no plantar flores dentro)
var _windows := {}  # kit de Kenney -> material de noche con ventanas encendidas
var _tiles := ShaderMaterial.new()
var _horizon := Node3D.new()  # colinas: siempre a la vista, en una sola malla
var _pools := Node3D.new()
var _pool := ShaderMaterial.new()
var _pool_mesh := PlaneMesh.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7  # misma ciudad en cada generación
	for kit in ["commercial", "suburban"]:
		var night := ShaderMaterial.new()
		night.shader = BUILDING_SHADER
		night.set_shader_parameter("colormap", load("res://models/kenney/%s/Textures/colormap.png" % kit))
		night.set_meta("bakeable", true)  # no depende de su nodo: Kit.bake puede fundir los edificios
		_windows[kit] = night
	_tiles.shader = TILES_SHADER
	_pool.shader = POOL_SHADER
	_pool_mesh.size = Vector2(6, 6)
	_pools.name = "Pools"
	_pools.set_meta("no_gi", true)
	add_child(_pools)
	var moon := DirectionalLight3D.new()  # luz de luna; el cielo dibuja la Luna llena en esa dirección
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-38, 35, 0)
	moon.light_color = Color(0.86, 0.9, 1.0)
	moon.light_energy = 1.1
	moon.light_bake_mode = Light3D.BAKE_STATIC
	moon.shadow_enabled = true  # sombras horneadas; al jugar la ciudad las apaga (solo cuentan las del lightmap)
	moon.light_angular_distance = 1.0  # penumbra suave en las sombras horneadas
	add_child(moon)
	var grass := ShaderMaterial.new()
	grass.shader = GROUND_SHADER
	Kit.solid(self, Vector3(CITY.HALF * 2, 1, CITY.HALF * 2), Vector3(0, -0.5, 0), grass)
	Kit.box(self, Vector3(600, 0.2, 600), Vector3(0, -0.15, 0), grass).set_meta("no_gi", true)  # fuera de los muros: sin hornear
	_plaza()
	for id: String in CITY.DISTRICTS:
		_district(id, CITY.DISTRICTS[id])
		_road(CITY.DISTRICTS[id], CITY.DISTRICT_RADIUS)
	_road(CITY.LAUNCH, 4.4)
	_light(CITY.LAUNCH + Vector3(0, 7, 0), Color(1.0, 0.8, 0.6), 13.0, 1.6)
	_towers()
	_flowers()
	_scenery()
	for s in [-1.0, 1.0]:
		Kit.collider(self, Vector3(CITY.HALF * 2, 30, 1), Vector3(0, 15, CITY.HALF * s))
		Kit.collider(self, Vector3(1, 30, CITY.HALF * 2), Vector3(CITY.HALF * s, 15, 0))
	Kit.bake(self)
	Kit.bake(_horizon, [], INF)
	Kit.bake(_pools)
	set_meta("canopies", _canopies)


## Plaza blanca con aros azules, bancos y la terminal holográfica del STEAM LAB en el centro.
func _plaza() -> void:
	_tiled(Kit.cylinder(self, CITY.PLAZA_RADIUS, CITY.PLAZA_RADIUS, 0.12, Vector3(0, 0.06, 0), _tiles, 64), Color("dfe7f2"))
	Kit.torus(self, CITY.PLAZA_RADIUS - 0.6, CITY.PLAZA_RADIUS, Vector3(0, 0.12, 0), Kit.mat(Color("1f6fff"), 1.5))
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
	Kit.banner(self, "STEAM LAB", Vector3(0, 7.8, 0), 140, Color("1f6fff"))
	_light(Vector3(0, 5.0, 0), Color("6fc8ff"), 16.0, 1.4)  # el holograma ilumina la plaza (horneada: no cuesta nada)
	var glow := PlaneMesh.new()
	glow.size = Vector2(26, 26)
	Kit.part(_pools, glow, Vector3(0, 0.13, 0), _pool).set_meta("tint", Color("3fb6ff"))


## Distrito: disco blanco, luz del color del reto, arco de entrada mirando a la plaza y su monumento detrás.
## (El aro de color, que brilla con 3 ★, el rótulo y el reto los pone la ciudad: cambian al jugar.)
func _district(id: String, center: Vector3) -> void:
	var color: Color = Game.info(id).color
	_tiled(Kit.cylinder(self, CITY.DISTRICT_RADIUS, CITY.DISTRICT_RADIUS, 0.16, center + Vector3(0, 0.08, 0), _tiles, 64), Color("f4f7fb"))
	_light(center + Vector3(0, 6, 0), color.lerp(Color.WHITE, 0.55), 13.0, 1.6)
	var gate := Node3D.new()
	gate.transform = CITY.gate(id)
	add_child(gate)
	Kit.torus(gate, 4.4, 5.3, Vector3.ZERO, Kit.mat(color), Vector3(PI / 2, 0, 0))  # medio aro asoma: un arco
	for side in [-1.0, 1.0]:
		Kit.collider(gate, Vector3(0.9, 5.0, 0.9), Vector3(4.85 * side, 2.5, 0))
	Kit.bake(gate)
	var landmark := Node3D.new()
	var dir := center.normalized()
	landmark.transform = Transform3D(Basis.looking_at(dir), center + dir * CITY.LANDMARK)
	add_child(landmark)
	Landmarks.build(id, landmark)


## Calle clara de la plaza hasta `target` (que mide `end_radius`), con bordillos, luces guía, farolas
## y árboles a los lados. Sirve para cualquier dirección: la malla gira hacia el destino.
func _road(target: Vector3, end_radius: float) -> void:
	var dir := target.normalized()
	var side := dir.cross(Vector3.UP)
	var start := CITY.PLAZA_RADIUS - 0.5
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
				_lamp(dir * (t + 3) + side * s, -side * signf(s))


## Farola de calle de Kenney (City Kit Roads) con el brazo hacia `toward` (el centro de la calle), su globo de
## luz y una luz real que solo se usa para hornear el charco de luz en la calle.
func _lamp(p: Vector3, toward: Vector3) -> void:
	# Kit.model centra el modelo en su huella: el poste queda 0,5 m detrás del centro, así que se adelanta
	Kit.model(self, "kenney/roads/light-curved", Transform3D(Basis(Vector3.UP, atan2(-toward.x, -toward.z)).scaled(Vector3.ONE * 6.0), p + toward * 0.51))
	var head := p + toward * 1.1 + Vector3(0, 3.72, 0)
	Kit.sphere(self, 0.17, head, Kit.mat(Color("fff1b8"), 4.0), Vector3(1, 0.6, 1), 12)
	_light(head + Vector3(0, -0.3, 0), Color("ffcf7a"), 9.0, 4.0).set_meta("bake_only", true)
	var pool := Kit.part(_pools, _pool_mesh, Vector3(head.x, 0.09, head.z), _pool)
	pool.set_meta("tint", Color("ffcf7a"))
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.pillar(self, 0.12, 4.0, p + Vector3(0, 2.0, 0))


## Edificios de Kenney en las manzanas libres (fuera de calles, plaza, distritos y cohete): tiendas y oficinas
## cerca del centro, rascacielos detrás y casas en las afueras, con el frente hacia la plaza y ventanas que se
## encienden de noche. Cada uno cabe en su manzana de 13 m.
func _towers() -> void:
	for gx in range(-5, 6):
		for gz in range(-5, 6):
			var p := Vector3(gx * 13.0, 0, gz * 13.0)
			if p.length() < 26.0 or absf(p.x) < 11.0 or absf(p.z) < 11.0 or absf(p.x) > 72.0 or absf(p.z) > 72.0:
				continue
			if absf(absf(p.x) - absf(p.z)) < 13.0 and p.length() < 52.0:  # calles diagonales
				continue
			if p.distance_to(CITY.LAUNCH) < 15.0 or CITY.DISTRICTS.values().any(func(d: Vector3) -> bool:
					return p.distance_to(d) < 19.0 or p.distance_to(d + d.normalized() * CITY.LANDMARK) < 11.0):
				continue
			var kit := "commercial"
			var path: String = "kenney/commercial/building-" + SHOPS[_rng.randi() % SHOPS.size()]
			if p.length() > 62.0 and _rng.randf() < 0.55:
				kit = "suburban"
				path = "kenney/suburban/building-type-" + HOUSES[_rng.randi() % HOUSES.length()]
			elif p.length() > 46.0:
				path = "kenney/commercial/building-" + TALL[_rng.randi() % TALL.size()]
			var size := Kit.model_size(path).size
			var scale := minf(8.0, 10.5 / maxf(size.x, size.z))
			var facing := Basis(Vector3.UP, snappedf(atan2(-p.x, -p.z), PI / 2.0))  # el frente (+Z) hacia la plaza
			var box := Kit.model(self, path, Transform3D(facing.scaled(Vector3.ONE * scale), p), true, _windows[kit])
			_tower_spots.append(Vector3(p.x, maxf(box.size.x, box.size.z) / 2.0, p.z))


## Matas de flores y arbustos del Nature Kit en el césped, lejos de calles y edificios.
func _flowers() -> void:
	var placed := 0
	while placed < 70:
		var p := Vector3(_rng.randf_range(-74, 74), 0, _rng.randf_range(-74, 74))
		var free := absf(p.x) > 8.0 and absf(p.z) > 8.0 and absf(absf(p.x) - absf(p.z)) > 11.0 and p.length() > 19.0
		if not free or p.distance_to(CITY.LAUNCH) < 8.0 or CITY.DISTRICTS.values().any(func(d: Vector3) -> bool:
					return p.distance_to(d) < 13.0 or p.distance_to(d + d.normalized() * CITY.LANDMARK) < 8.0) \
				or _tower_spots.any(func(t: Vector3) -> bool: return Vector2(p.x - t.x, p.z - t.z).length() < t.y + 1.5):
			continue
		placed += 1
		var turn := Basis(Vector3.UP, _rng.randf() * TAU)
		Kit.model(self, "kenney/nature/plant_bush" if placed % 2 else "kenney/nature/plant_bushLarge", Transform3D(turn.scaled(Vector3.ONE * 2.6), p))
		for k in 2:
			var a := TAU * k / 2.0 + _rng.randf()
			Kit.model(self, "kenney/nature/" + FLOWERS[_rng.randi() % FLOWERS.size()],
				Transform3D(turn.scaled(Vector3.ONE * 3.2), p + Vector3(cos(a), 0, sin(a)) * 0.9))


## Colinas alrededor: el horizonte de "mundo de juguete" de Astro Bot (fuera del lightmap: son enormes).
func _scenery() -> void:
	add_child(_horizon)
	_horizon.set_meta("no_gi", true)
	for i in 14:
		var a := TAU * i / 14.0 + _rng.randf_range(-0.1, 0.1)
		var r := _rng.randf_range(35, 60)
		Kit.sphere(_horizon, r, Vector3(cos(a), 0, sin(a)) * _rng.randf_range(130, 170) + Vector3(0, -r * 0.45, 0),
			Kit.mat(Color("6ccf4a") if i % 2 else Color("8fdc5a"), 0.0, 0.0, 0.6), Vector3.ONE, 32)


## Luz horneada (no cuesta nada al jugar). Las que siguen encendidas iluminan además a los personajes.
func _light(pos: Vector3, color: Color, reach: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.omni_range = reach
	light.light_energy = energy
	light.light_bake_mode = Light3D.BAKE_STATIC
	add_child(light)
	return light


func _tiled(mesh: MeshInstance3D, color: Color) -> void:
	mesh.set_meta("tint", color)


## Árbol del Nature Kit de Kenney (seis especies, tamaño y giro al azar).
func _tree(p: Vector3) -> void:
	var scale := _rng.randf_range(3.6, 4.6)
	var box := Kit.model(self, "kenney/nature/" + TREES[_rng.randi() % TREES.size()], Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale), p))
	Kit.pillar(self, 0.3, 2.2, p + Vector3(0, 1.1, 0))
	for k in 2:
		_canopies.append(p + Vector3(_rng.randf_range(-1.0, 1.0), box.size.y * _rng.randf_range(0.5, 0.8), _rng.randf_range(-1.0, 1.0)))
