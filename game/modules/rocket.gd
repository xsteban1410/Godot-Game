extends Node3D
## Plataforma de lanzamiento del cohete de agua. En la Tierra se arma solo con las estrellas (piezas =
## estrellas: nada nuevo que guardar) y, con las 12, se lanza en tres pasos con E: llenar de agua
## (lo ideal es ~1/3), bombear aire hasta la zona verde y cuenta atrás. En la Luna (`moon`) llega
## aterrizando con retrocohetes. Se coloca mirando a la plaza (+Z).

const PARTS := {  # reto -> piezas de ★1, ★2, ★3
	"recycling": ["Botella PET (tanque de agua)", "Segunda botella", "Boquilla de salida"],
	"bridge": ["Aletas estabilizadoras", "Anillos de estructura", "Cabina de cristal"],
	"solar": ["Panel solar", "Batería", "Antena de radio"],
	"robotics": ["Computadora de vuelo", "Giroscopio", "Paracaídas de regreso"],
}
const BASE := 1.3  # altura de la boquilla sobre el suelo
const TANK := 4.8  # altura total de las dos botellas
const GOOD_WATER := Vector2(0.2, 0.5)  # con más o menos agua el cohete no despega
const GREEN_ZONE := Vector2(0.7, 0.9)

@export var moon := false

var _parts := {}  # "reto:i" -> Node3D
var _ship := Node3D.new()  # todas las piezas: es lo que despega
var _pad: Interactable
var _gyro: Node3D
var _water_mesh: MeshInstance3D
var _gauge: Label3D
var _camera := Camera3D.new()
var _previous_camera: Camera3D
var _stage := ""  # "", "water", "pump", "launch"
var _water := 0.0
var _pressure := 0.0
var _in_zone := 0.0


func _ready() -> void:
	var white := Kit.mat(Color("f4f7fb"))
	Kit.cylinder(self, 4.0, 4.4, 0.7, Vector3(0, 0.35, 0), white, 48)
	Kit.collider(self, Vector3(7, 0.7, 7), Vector3(0, 0.35, 0))
	Kit.torus(self, 3.5, 3.9, Vector3(0, 0.72, 0), Kit.mat(Color("ff8c1a"), 0.8))
	if not moon:
		for x in [-2.6, -4.0]:  # torre de andamios
			for z in [-0.7, 0.7]:
				Kit.cylinder(self, 0.08, 0.08, 9.0, Vector3(x, 4.5, z), Kit.mat(Color("ff5a36")), 8)
		for y in range(1, 9, 2):
			Kit.box(self, Vector3(1.5, 0.1, 1.5), Vector3(-3.3, y + 0.5, 0), Kit.mat(Color("cfd8e6")))
		Kit.collider(self, Vector3(1.6, 9, 1.6), Vector3(-3.3, 4.5, 0))
		Kit.label(self, "PLATAFORMA DE LANZAMIENTO", Vector3(0, 10.5, 0), 110, Color("1f6fff"), true, 0.012)
	add_child(_ship)
	add_child(_camera)
	_water_mesh = Kit.cylinder(_ship, 0.86, 0.86, 1.0, Vector3(0, BASE, 0), Kit.mat(Color("2ea8ff"), 0.3, 0.0, 0.05), 32)
	for module: String in PARTS:
		for i in 3:
			var part := Node3D.new()
			_ship.add_child(part)
			_build(part, module, i)
			part.visible = moon or int(Game.stars.get(module, 0)) > i
			_parts["%s:%d" % [module, i]] = part
	_gauge = Kit.label(self, "", Vector3(3.2, 3.2, 2.0), 64, Color("1d2a3a"))
	_pad = Kit.interactable(self, "", Vector3(0, 1.2, 4.0), 2.2)
	_pad.interacted.connect(_on_pad)
	if moon:
		_set_water(0.0)
		_pad.prompt = "COHETE DE AGUA · sin agua no puedes volver"
		if Game.arriving:
			_land.call_deferred()
	else:
		_set_water(0.2 if _parts["recycling:0"].visible else 0.0)
		Game.stars_changed.connect(_on_stars_changed)
		_refresh()


func _process(delta: float) -> void:
	_gyro.rotate_y(delta * 3.0)
	match _stage:
		"water":
			_set_water(minf(_water + delta / 6.0, 1.0))
			_pad.prompt = "CERRAR EL AGUA · %d %%  (lo ideal: 1/3)" % roundi(_water * 100)
		"pump":
			_pressure = maxf(_pressure - delta * 0.05, 0.0)  # el aire se escapa poco a poco
			var green := _pressure >= GREEN_ZONE.x and _pressure <= GREEN_ZONE.y
			_in_zone = _in_zone + delta if green else 0.0
			_gauge.text = "PRESIÓN %d %%\nzona verde: 70–90 %%" % roundi(_pressure * 100)
			_gauge.modulate = Color("1f9e4a") if green else Game.RED if _pressure > GREEN_ZONE.y else Color("1d2a3a")
			if _in_zone > 1.0:
				_launch()
		"launch":
			_camera.look_at(_ship.global_position + Vector3(0, 4, 0))


func _count() -> int:
	return _parts.values().filter(func(p: Node3D) -> bool: return p.visible).size()


func _refresh() -> void:
	var missing := 12 - _count()
	_pad.prompt = "COHETE DE AGUA · faltan %d piezas" % missing if missing > 0 else "PREPARAR EL LANZAMIENTO: LLENAR DE AGUA"


func _set_water(level: float) -> void:
	_water = level
	_water_mesh.scale.y = maxf(level * TANK, 0.01)
	_water_mesh.position.y = BASE + 0.1 + level * TANK / 2.0


func _on_pad() -> void:
	if moon:
		Game.notify("Necesitas agua para volver: búscala en los cráteres.", Game.GOLD)
		return
	match _stage:
		"":
			if _count() < 12:
				Game.notify("Cada estrella de los retos es una pieza del cohete.", Game.GOLD)
				return
			_stage = "water"
			_set_water(0.0)
			Sfx.play("splash")
		"water":
			_stage = "pump"
			_pressure = 0.0
			_pad.prompt = "BOMBEAR AIRE (pulsa E varias veces)"
			Game.notify("Agua: %d %%. Ahora bombea aire hasta la zona verde." % roundi(_water * 100), Game.TEXT)
		"pump":
			_pressure += 0.11
			Sfx.play("hop", 0.1)
			if _pressure > 1.0:  # bombear demasiado rápido: salta la válvula de seguridad
				_pressure = 0.35
				Sfx.play("error")
				Fx.burst(self, Vector3(0, BASE, 0), [Color.WHITE, Color("bfe6ff")], 30, 6.0, 0.15)
				Fx.shake(self, 0.3)
				Game.notify("¡Saltó la válvula de seguridad! Bombea con más calma.", Game.RED)


## Cuenta atrás, el robot sube a la cabina y despega con el chorro de agua.
func _launch() -> void:
	_stage = "launch"
	_gauge.text = ""
	_pad.prompt = ""
	var player := get_tree().get_first_node_in_group("player")
	Game.push_lock(self, false)
	player.visible = false
	var pilot := Node3D.new()
	pilot.position = Vector3(0, BASE + 4.75, 0)
	pilot.scale = Vector3.ONE * 0.6
	_ship.add_child(pilot)
	var limbs := Kit.robot(pilot, Color("1f6fff"))
	limbs[1].rotation = Vector3(-2.7, 0, 0.3)  # saluda desde la cabina
	_camera.position = Vector3(6, 3, 16)
	_previous_camera = get_viewport().get_camera_3d()
	_camera.make_current()
	_camera.look_at(_ship.global_position + Vector3(0, 4, 0))
	for n in [3, 2, 1]:
		var number := Kit.label(self, str(n), Vector3(0, 9, 3), 400, Game.GOLD, true, 0.01)
		Sfx.play("click")
		await create_tween().tween_property(number, "scale", Vector3.ONE * 0.2, 0.9).from(Vector3.ONE * 1.4).finished
		number.queue_free()
	var good := _water >= GOOD_WATER.x and _water <= GOOD_WATER.y
	var jet := _jet()
	Sfx.play("boom")
	Fx.shake(self, 0.6)
	Fx.burst(self, Vector3(0, 1, 0), [Color("2ea8ff"), Color.WHITE], 80, 10.0, 0.18)
	if not good:
		await _fail_hop(jet, player, pilot)
		return
	Game.notify("¡El agua sale hacia abajo y el cohete sube! (tercera ley de Newton)", Game.GREEN)
	var climb := create_tween()
	climb.tween_property(_ship, "position:y", 160.0, 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	climb.parallel().tween_property(_camera, "position", Vector3(4, 25, 10), 5.0)
	await get_tree().create_timer(3.8).timeout
	Game.arriving = true
	Game.go_to("res://world/moon.tscn")


## Con mal reparto de agua el cohete solo da un saltito: se explica por qué y se puede repetir.
func _fail_hop(jet: CPUParticles3D, player: Node3D, pilot: Node3D) -> void:
	var hop := create_tween()
	hop.tween_property(_ship, "position:y", 3.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(_ship, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await hop.finished
	jet.queue_free()
	Sfx.play("error")
	Game.notify("Con %d %% de agua no hay empuje suficiente." % roundi(_water * 100) if _water < GOOD_WATER.x
		else "Con %d %% de agua pesa demasiado y queda poco aire para empujar." % roundi(_water * 100), Game.RED)
	pilot.queue_free()
	player.visible = true
	_previous_camera.make_current()
	Game.pop_lock(self)
	_stage = ""
	_set_water(0.0)
	_refresh()


## En la Luna: el cohete baja del cielo frenando con el chorro y deja al jugador junto a la plataforma.
func _land() -> void:
	Game.arriving = false
	var player := get_tree().get_first_node_in_group("player")
	Game.push_lock(self, false)
	player.visible = false
	_ship.position.y = 70.0
	_camera.position = Vector3(10, 4, 18)
	_previous_camera = get_viewport().get_camera_3d()
	_camera.make_current()
	var jet := _jet()
	await create_tween().tween_property(_ship, "position:y", 0.0, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).finished
	jet.emitting = false
	Sfx.play("land")
	Fx.burst(self, Vector3(0, 0.8, 0), [Color("b8bcc4"), Color("8a8f98")], 60, 6.0, 0.2)
	Fx.shake(self, 0.4)
	await get_tree().create_timer(0.8).timeout
	player.visible = true
	_previous_camera.make_current()
	Game.pop_lock(self)
	_stage = ""


func _jet() -> CPUParticles3D:
	var jet := CPUParticles3D.new()
	jet.position = Vector3(0, BASE - 0.4, 0)
	jet.amount = 140
	jet.lifetime = 0.7
	jet.direction = Vector3.DOWN
	jet.spread = 10.0
	jet.initial_velocity_min = 12.0
	jet.initial_velocity_max = 18.0
	jet.gravity = Vector3(0, -9.8, 0)
	jet.scale_amount_min = 0.6
	jet.scale_amount_max = 1.6
	var drop := SphereMesh.new()
	drop.radius = 0.12
	drop.height = 0.24
	drop.radial_segments = 8
	drop.rings = 4
	jet.mesh = drop
	jet.material_override = Kit.mat(Color(0.75, 0.9, 1.0, 0.8), 1.0)
	_ship.add_child(jet)
	jet.emitting = true
	return jet


## La pieza nueva baja desde el cielo dentro de un haz de luz y rebota en su sitio.
func _on_stars_changed(module: String, stars: int) -> void:
	if not PARTS.has(module):
		return
	for i in stars:
		var part: Node3D = _parts["%s:%d" % [module, i]]
		if part.visible:
			continue
		part.visible = true
		var beam := Kit.cylinder(self, 1.4, 1.4, 14.0, Vector3(0, 7, 0), Kit.mat(Color(0.5, 0.85, 1.0, 0.35), 2.0), 24)
		part.position.y = 8.0
		part.scale = Vector3.ONE * 0.2
		var tween := create_tween().set_parallel()
		tween.tween_property(part, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(part, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(beam, "scale", Vector3(0.01, 1, 0.01), 1.2).set_delay(0.6)
		tween.chain().tween_callback(beam.queue_free)
		Fx.confetti(self, Vector3(0, BASE + 3, 0))
		Game.notify("¡Nueva pieza para el cohete: %s! (%d / 12)" % [PARTS[module][i], _count()], Game.GOLD)
	if module == "recycling" and _stage == "":
		_set_water(0.2)
	_refresh()


## Cohete de agua de juguete: dos botellas PET con aletas, cabina de cristal arriba y extras.
func _build(part: Node3D, module: String, i: int) -> void:
	var glass := Kit.mat(Color(0.6, 0.85, 1.0, 0.45), 0.0, 0.0, 0.05)
	var orange := Kit.mat(Color("ff8c1a"))
	var white := Kit.mat(Color("f4f7fb"))
	match "%s:%d" % [module, i]:
		"recycling:0":
			Kit.cylinder(part, 0.9, 0.9, 2.6, Vector3(0, BASE + 1.4, 0), glass, 32)
		"recycling:1":
			Kit.cylinder(part, 0.9, 0.9, 2.2, Vector3(0, BASE + 3.8, 0), glass, 32)
		"recycling:2":
			Kit.cylinder(part, 0.25, 0.55, 0.5, Vector3(0, BASE - 0.15, 0), Kit.mat(Color("2a3442"), 0.0, 0.6), 24)
		"bridge:0":
			for k in 4:
				var a := TAU * k / 4.0
				Kit.box(part, Vector3(0.12, 1.5, 1.1), Vector3(sin(a) * 1.25, BASE + 0.8, cos(a) * 1.25), orange, Vector3(0, a, 0))
		"bridge:1":
			for y in [0.1, 2.75, 4.9]:
				Kit.torus(part, 0.86, 1.04, Vector3(0, BASE + y, 0), white)
		"bridge:2":
			Kit.sphere(part, 0.95, Vector3(0, BASE + 5.4, 0), Kit.mat(Color(0.75, 0.95, 1.0, 0.35), 0.0, 0.0, 0.02), Vector3(1, 1.25, 1))
		"solar:0":
			for side in [-1.0, 1.0]:
				Kit.box(part, Vector3(1.7, 0.06, 0.9), Vector3(1.75 * side, BASE + 3.0, 0), Kit.mat(Color("1d3f8f"), 0.3, 0.6, 0.08))
				Kit.cylinder(part, 0.05, 0.05, 0.9, Vector3(0.95 * side, BASE + 3.0, 0), white, 8, Vector3(0, 0, PI / 2))
		"solar:1":
			Kit.box(part, Vector3(0.55, 0.85, 0.4), Vector3(0, BASE + 2.2, 1.0), Kit.mat(Color("3fcf5a")))
			Kit.box(part, Vector3(0.45, 0.12, 0.42), Vector3(0, BASE + 2.45, 1.01), Kit.mat(Color("ffcc00"), 2.0))
		"solar:2":
			Kit.cylinder(part, 0.04, 0.04, 1.2, Vector3(0.3, BASE + 7.3, 0), white, 8)
			Kit.sphere(part, 0.12, Vector3(0.3, BASE + 7.95, 0), Kit.mat(Game.RED, 4.0))
		"robotics:0":
			Kit.box(part, Vector3(0.8, 0.6, 0.2), Vector3(0, BASE + 3.9, -0.95), Kit.mat(Color("2a3442")))
			Kit.box(part, Vector3(0.6, 0.35, 0.05), Vector3(0, BASE + 3.95, -1.06), Kit.mat(Game.TEAL, 3.0))
		"robotics:1":
			_gyro = Node3D.new()
			_gyro.position = Vector3(0, BASE + 1.6, -1.0)
			part.add_child(_gyro)
			Kit.torus(_gyro, 0.25, 0.32, Vector3.ZERO, Kit.mat(Color("ffcc00"), 1.0), Vector3(PI / 2, 0, 0))
			Kit.torus(_gyro, 0.25, 0.32, Vector3.ZERO, Kit.mat(Color("ffcc00"), 1.0), Vector3(0, 0, PI / 2))
		"robotics:2":
			Kit.sphere(part, 0.55, Vector3(0, BASE + 6.85, 0), Kit.mat(Color("ff4f8b")), Vector3(1, 0.45, 1))
			Kit.torus(part, 0.5, 0.6, Vector3(0, BASE + 6.8, 0), white)
