extends Node3D
## La Luna: regolito con cráteres y rocas, cielo negro estrellado, la Tierra en el horizonte, base de cúpulas,
## un módulo lunar con su bandera, balizas del color de cada reto que marcan el camino desde la llegada y
## el cohete que acaba de aterrizar. Gravedad 1/6 (1,62 m/s²): los saltos son altos y lentos, y el
## polvo guarda las huellas (no hay viento que las borre).

const REGOLITH := preload("res://world/regolith.gdshader")
const ROCKET := preload("res://modules/rocket.gd")
const VOLT := preload("res://world/volt.gd")
const EARTH := preload("res://world/earth.gdshader")
const CHALLENGES := {  # posición -> reto lunar
	Vector3(40, 0, -5): "moon_jump",
	Vector3(-40, 0, -5): "moon_rover",
	Vector3(-22, 0, 28): "moon_power",
	Vector3(22, 0, 28): "moon_water",
}
const SCRIPTS := {
	"moon_jump": preload("res://modules/moon_jump.gd"),
	"moon_rover": preload("res://modules/robotics.gd"),
	"moon_power": preload("res://modules/moon_power.gd"),
	"moon_water": preload("res://modules/moon_water.gd"),
}
const ARRIVAL := Vector3(0, 0, 8)
const BASE := Vector3(0, 0, -30)
const LANDER := Vector3(24, 0, -24)
const BOLTS := [  # tuercas doradas de la llanura (las del cráter y el purificador las pone su reto)
	Vector3(3.0, 6.4, -30),  # sobre la cúpula de cristal
	Vector3(0, 4.6, -40),  # sobre la antena parabólica, detrás de la cúpula
	Vector3(13, 5.6, -28), Vector3(-13, 5.6, -28),  # sobre los hangares
	Vector3(24, 3.4, -24),  # sobre la nave de carga
	Vector3(-95, 0.8, -60), Vector3(80, 0.8, 85),  # lejos, en la llanura
]
const STORY := [  # (la bienvenida y la gravedad las cuenta Ivy al aterrizar)
	"JEFE DE BASE: Tu cohete funciona con agua… y aquí no hay ríos ni lluvia.",
	"JEFE DE BASE: Pero en los cráteres del polo, donde nunca llega el Sol, hay hielo. ¡Será tu combustible para volver!",
]

var _earth: Node3D


func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-35, -30, 0)
	var player := $Player
	player.gravity = 20.0 / 6.0
	player.jump_height = 4.5
	player.footprints = true
	var ground := ShaderMaterial.new()
	ground.shader = REGOLITH
	Kit.solid(self, Vector3(400, 1, 400), Vector3(0, -0.5, 0), ground)
	for s in [-1.0, 1.0]:  # bordes invisibles: antes se podía caer por el borde del suelo
		Kit.collider(self, Vector3(240, 30, 1), Vector3(0, 15, 120 * s))
		Kit.collider(self, Vector3(1, 30, 240), Vector3(120 * s, 15, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 14:  # cráteres grandes: anillos bajos de polvo
		var a := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(4, 10)
		var torus := Kit.torus(self, r, r + 2.0, Vector3(cos(a), 0, sin(a)) * rng.randf_range(35, 110), Kit.mat(Color("8f939b"), 0.0, 0.0, 0.95))
		torus.scale.y = 0.25
	_base(BASE)
	_lander(LANDER)
	_rocks(rng)
	var rocket: Node3D = ROCKET.new()
	rocket.moon = true
	rocket.position = Vector3(0, 0, -6)
	add_child(rocket)
	var ivy := Ivy.new()
	ivy.home = "moon"
	add_child(ivy)
	for pos: Vector3 in CHALLENGES:
		var id: String = CHALLENGES[pos]
		ivy.zone(id, pos, 16.0 if id == "moon_jump" else 11.0)
		var challenge: Node3D = SCRIPTS[id].new()
		if id == "moon_rover":
			challenge.rover = true
		challenge.transform = Transform3D(Basis.looking_at(pos - ARRIVAL), pos)  # +Z mira a la llegada
		add_child(challenge)
		_beacons(pos, Game.info(id).color, 18.0 if id == "moon_jump" else 11.0)
		if id != "moon_jump":  # plataforma con el aro del color del reto, como los distritos de la Tierra
			Kit.cylinder(challenge, 9.0, 9.4, 0.1, Vector3(0, 0.05, -3.0), Kit.mat(Color("d9dde3"), 0.0, 0.2, 0.5), 64)
			Kit.torus(challenge, 8.6, 9.1, Vector3(0, 0.1, -3.0), Kit.mat(Game.info(id).color, 1.2))
			Kit.bake(challenge)
	var chief := VOLT.new()
	chief.accent = Color("9b6bff")
	chief.position = Vector3(-5, 0, -16)
	chief.waypoints = PackedVector3Array([Vector3(-5, 0, -16), Vector3(5, 0, -16)])
	add_child(chief)
	Kit.label(chief, "JEFE DE BASE", Vector3(0, 2.4, 0), 40, Color("d4c4ff"))
	_earth = Node3D.new()
	_earth.position = Vector3(-80, 60, -170)
	add_child(_earth)
	var planet := ShaderMaterial.new()
	planet.shader = EARTH
	Kit.sphere(_earth, 16, Vector3.ZERO, planet)
	Kit.bake(self)
	for i in BOLTS.size():
		Bolt.spawn(self, "moon_%d" % i, BOLTS[i])
	for i in STORY.size():
		get_tree().create_timer(16.0 + i * 4.0).timeout.connect(Game.notify.bind(STORY[i], Game.GOLD))  # tras el saludo de Ivy


func _process(delta: float) -> void:
	_earth.rotate_y(delta * 0.05)


## Postes con luz del color del reto cada 4,5 m, de la llegada hasta `stop` metros antes del reto.
func _beacons(target: Vector3, color: Color, stop: float) -> void:
	var dir := (target - ARRIVAL).normalized()
	var length := ARRIVAL.distance_to(target) - stop
	var light := Kit.mat(color, 3.0)
	for d in range(6, int(length), 5):
		var p := ARRIVAL + dir * d
		Kit.cylinder(self, 0.06, 0.09, 0.8, p + Vector3(0, 0.4, 0), Kit.mat(Color("cfd8e6"), 0.0, 0.6), 8)
		Kit.sphere(self, 0.15, p + Vector3(0, 0.88, 0), light, Vector3.ONE, 10)


func _on_path(p: Vector3) -> bool:
	for target: Vector3 in CHALLENGES:
		if p.distance_to(Geometry3D.get_closest_point_to_segment(p, ARRIVAL, target)) < 5.0:
			return true
	return false


## Rocas del Space Kit de Kenney (recoloreadas en gris lunar) por la llanura, lejos de los caminos, la base y los
## retos; las grandes tienen colisión.
func _rocks(rng: RandomNumberGenerator) -> void:
	var kinds := ["rock_largeA", "rock_largeB", "rock", "rocks_smallA", "rocks_smallB"]
	var placed := 0
	while placed < 40:
		var p := Vector3(rng.randf_range(-105, 105), 0, rng.randf_range(-105, 105))
		if p.length() < 22.0 or p.distance_to(BASE) < 24.0 or p.distance_to(LANDER) < 9.0 or _on_path(p) \
				or CHALLENGES.keys().any(func(c: Vector3) -> bool: return p.distance_to(c) < 18.0):
			continue
		placed += 1
		var kind: String = kinds[rng.randi() % kinds.size()]
		var scale := rng.randf_range(2.5, 5.0)
		Kit.model(self, "kenney/space/" + kind, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), p),
			kind.begins_with("rock_large"), null, Kit.MOON_ROCK)


## Nave de carga del Space Kit aparcada junto a su bandera (la del STEAM LAB: en la Luna no hay viento, así que
## la tela cuelga de una barra) y dos astronautas que trabajan cerca.
func _lander(p: Vector3) -> void:
	Kit.model(self, "kenney/space/craft_cargoA", Transform3D(Basis(Vector3.UP, 2.4).scaled(Vector3.ONE * 3.0), p), true)
	var flag := p + Vector3(-6, 0, 4)
	Kit.cylinder(self, 0.05, 0.05, 3.2, flag + Vector3(0, 1.6, 0), Kit.mat(Color("cfd8e6"), 0.0, 0.7), 8)
	Kit.cylinder(self, 0.04, 0.04, 1.7, flag + Vector3(0.82, 3.15, 0), Kit.mat(Color("cfd8e6"), 0.0, 0.7), 6, Vector3(0, 0, PI / 2))
	Kit.box(self, Vector3(1.6, 1.0, 0.04), flag + Vector3(0.82, 2.62, 0), Kit.mat(Color("1f6fff")))
	Kit.box(self, Vector3(1.6, 0.22, 0.05), flag + Vector3(0.82, 2.62, 0), Kit.mat(Game.GOLD))
	Kit.label(self, "STEAM", flag + Vector3(0.82, 2.62, 0.04), 36, Color("1d2a3a"), false, 0.008)
	Kit.pillar(self, 0.15, 3.2, flag + Vector3(0, 1.6, 0))
	for spec: Array in [["astronautA", Vector3(-6, 0, -5), 0.6], ["astronautB", Vector3(6, 0, 5), -2.2]]:
		Kit.model(self, "kenney/space/" + spec[0], Transform3D(Basis(Vector3.UP, spec[2]).scaled(Vector3.ONE * 1.3), p + spec[1]), true)


## Base lunar del Space Kit: cúpula de cristal en el centro, dos hangares redondos unidos por pasillos, antena
## parabólica, generador y bidones, con el rótulo encima.
func _base(center: Vector3) -> void:
	Kit.model(self, "kenney/space/hangar_roundGlass", Transform3D(Basis().scaled(Vector3.ONE * 4.0), center), true)
	for side in [-1.0, 1.0]:
		Kit.model(self, "kenney/space/hangar_roundA", Transform3D(Basis(Vector3.UP, PI if side > 0 else 0.0).scaled(Vector3.ONE * 2.6), center + Vector3(13 * side, 0, 2)), true)
		Kit.model(self, "kenney/space/corridor_window",  # pasillo entre la cúpula (6,5 m de radio) y el hangar
			Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * 2.4), center + Vector3(7.6 * side, 0, 1)), true)
	Kit.model(self, "kenney/space/satelliteDish_large", Transform3D(Basis(Vector3.UP, 0.6).scaled(Vector3.ONE * 4.0), center + Vector3(0, 0, -10)), true)
	Kit.model(self, "kenney/space/machine_generatorLarge", Transform3D(Basis().scaled(Vector3.ONE * 2.2), center + Vector3(-8, 0, 8)), true)
	for k in 3:
		Kit.model(self, "kenney/space/machine_barrel", Transform3D(Basis(Vector3.UP, k).scaled(Vector3.ONE * 1.8), center + Vector3(8 + k * 1.3, 0, 8 - k * 0.4)), true)
	Kit.banner(self, "BASE LUNAR", center + Vector3(0, 9.5, 4), 120, Color("2ec4ff"))
