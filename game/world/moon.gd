extends Node3D
## La Luna: regolito con cráteres, cielo negro estrellado, la Tierra en el horizonte, base de cúpulas
## y el cohete que acaba de aterrizar. Gravedad 1/6 (1,62 m/s²): los saltos son altos y lentos, y el
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
const STORY := [
	"¡Llegaste a la Luna! Aquí la gravedad es 1/6 de la de la Tierra: ¡prueba a saltar!",
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
	_base(Vector3(0, 0, -30))
	var rocket: Node3D = ROCKET.new()
	rocket.moon = true
	rocket.position = Vector3(0, 0, -6)
	add_child(rocket)
	for pos: Vector3 in CHALLENGES:
		var id: String = CHALLENGES[pos]
		var challenge: Node3D = SCRIPTS[id].new()
		if id == "moon_rover":
			challenge.rover = true
		challenge.transform = Transform3D(Basis.looking_at(pos - ARRIVAL), pos)  # +Z mira a la llegada
		add_child(challenge)
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
	for i in STORY.size():
		get_tree().create_timer(6.0 + i * 3.5).timeout.connect(Game.notify.bind(STORY[i], Game.GOLD))


func _process(delta: float) -> void:
	_earth.rotate_y(delta * 0.05)


## Base lunar: tres cúpulas blancas unidas por túneles, antena y campo de paneles solares.
func _base(center: Vector3) -> void:
	var white := Kit.mat(Color("f4f7fb"))
	var glass := Kit.mat(Color("7fdcff"), 1.5, 0.0, 0.05)
	for spec in [[Vector3(0, 0, 0), 6.0], [Vector3(-11, 0, 3), 4.0], [Vector3(11, 0, 3), 4.0]]:
		var p: Vector3 = center + spec[0]
		var r: float = spec[1]
		Kit.sphere(self, r, p, white, Vector3(1, 0.75, 1))
		for a in [-0.7, -0.25, 0.25, 0.7]:  # ojos de buey encendidos, medio hundidos en la cúpula
			Kit.sphere(self, r * 0.08, p + Vector3(sin(a), 0, cos(a)) * r * 0.8 + Vector3(0, r * 0.45, 0), glass)
		Kit.torus(self, r * 0.93, r * 1.0, p + Vector3(0, r * 0.25, 0), Kit.mat(Color("2ec4ff"), 2.0))
		Kit.collider(self, Vector3(r * 1.5, r * 0.75, r * 1.5), p + Vector3(0, r * 0.37, 0))
	for side in [-1.0, 1.0]:
		Kit.cylinder(self, 1.1, 1.1, 6.0, center + Vector3(5.5 * side, 1.0, 1.5), white, 20, Vector3(0, 0, PI / 2))
	# Esclusa de entrada mirando a la llegada: túnel, puerta y marco de luz.
	Kit.cylinder(self, 1.4, 1.4, 3.0, center + Vector3(0, 1.4, 5.6), white, 24, Vector3(PI / 2, 0, 0))
	Kit.box(self, Vector3(1.5, 2.0, 0.2), center + Vector3(0, 1.2, 7.1), Kit.mat(Color("2a3442"), 0.0, 0.3, 0.2))
	Kit.torus(self, 1.3, 1.45, center + Vector3(0, 1.4, 7.12), Kit.mat(Color("2ec4ff"), 2.5), Vector3(PI / 2, 0, 0))
	Kit.cylinder(self, 0.1, 0.1, 6.0, center + Vector3(0, 7.0, 0), Kit.mat(Color("cfd8e6")), 8)
	Kit.sphere(self, 1.4, center + Vector3(0, 10.2, 0), white, Vector3(1, 0.35, 1))
	Kit.sphere(self, 0.25, center + Vector3(0, 10.8, 0), Kit.mat(Game.RED, 4.0))
	for x in range(-3, 4):
		Kit.box(self, Vector3(2.0, 0.08, 1.3), center + Vector3(x * 2.4, 1.0, 9.5), Kit.mat(Color("1d3f8f"), 0.3, 0.6, 0.08), Vector3(-0.5, 0, 0))
	Kit.banner(self, "BASE LUNAR", center + Vector3(0, 7.5, 6), 120, Color("2ec4ff"))
