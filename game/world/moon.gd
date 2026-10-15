extends Node3D
## La Luna: regolito con cráteres, cielo negro estrellado, la Tierra en el horizonte, base de cúpulas
## y el cohete que acaba de aterrizar. Gravedad 1/6 (1,62 m/s²): los saltos son altos y lentos, y el
## polvo guarda las huellas (no hay viento que las borre).

const REGOLITH := preload("res://world/regolith.gdshader")
const ROCKET := preload("res://modules/rocket.gd")
const VOLT := preload("res://world/volt.gd")
const ROBOTICS := preload("res://modules/robotics.gd")
const CHALLENGES := {  # posición -> reto lunar
	Vector3(40, 0, -5): preload("res://modules/moon_jump.gd"),
	Vector3(-40, 0, -5): ROBOTICS,
	Vector3(-22, 0, 28): preload("res://modules/moon_power.gd"),
	Vector3(22, 0, 28): preload("res://modules/moon_water.gd"),
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
		var challenge: Node3D = CHALLENGES[pos].new()
		if challenge.get_script() == ROBOTICS:
			challenge.rover = true
		challenge.transform = Transform3D(Basis.looking_at(pos - ARRIVAL), pos)  # +Z mira a la llegada
		add_child(challenge)
	var chief := VOLT.new()
	chief.position = Vector3(-5, 0, -16)
	chief.waypoints = PackedVector3Array([Vector3(-5, 0, -16), Vector3(5, 0, -16)])
	add_child(chief)
	_earth = Node3D.new()
	_earth.position = Vector3(-80, 60, -170)
	add_child(_earth)
	Kit.sphere(_earth, 16, Vector3.ZERO, Kit.mat(Color("1f5fd6"), 0.6, 0.0, 0.3))
	Kit.sphere(_earth, 16.6, Vector3.ZERO, Kit.mat(Color(1, 1, 1, 0.25), 0.4, 0.0, 0.9), Vector3(1, 0.96, 1))
	for i in STORY.size():
		get_tree().create_timer(6.0 + i * 3.5).timeout.connect(Game.notify.bind(STORY[i], Game.GOLD))


func _process(delta: float) -> void:
	_earth.rotate_y(delta * 0.05)


## Base lunar: tres cúpulas blancas unidas por túneles, antena y campo de paneles solares.
func _base(center: Vector3) -> void:
	var white := Kit.mat(Color("f4f7fb"))
	for spec in [[Vector3(0, 0, 0), 6.0], [Vector3(-11, 0, 3), 4.0], [Vector3(11, 0, 3), 4.0]]:
		var p: Vector3 = center + spec[0]
		var r: float = spec[1]
		Kit.sphere(self, r, p, white, Vector3(1, 0.75, 1))
		Kit.torus(self, r * 0.93, r * 1.0, p + Vector3(0, r * 0.25, 0), Kit.mat(Color("2ec4ff"), 2.0))
		Kit.collider(self, Vector3(r * 1.5, r * 0.75, r * 1.5), p + Vector3(0, r * 0.37, 0))
	for side in [-1.0, 1.0]:
		Kit.cylinder(self, 1.1, 1.1, 6.0, center + Vector3(5.5 * side, 1.0, 1.5), white, 20, Vector3(0, 0, PI / 2))
	Kit.cylinder(self, 0.1, 0.1, 6.0, center + Vector3(0, 7.0, 0), Kit.mat(Color("cfd8e6")), 8)
	Kit.sphere(self, 1.4, center + Vector3(0, 10.2, 0), white, Vector3(1, 0.35, 1))
	Kit.sphere(self, 0.25, center + Vector3(0, 10.8, 0), Kit.mat(Game.RED, 4.0))
	for x in range(-3, 4):
		Kit.box(self, Vector3(2.0, 0.08, 1.3), center + Vector3(x * 2.4, 1.0, 9.5), Kit.mat(Color("1d3f8f"), 0.3, 0.6, 0.08), Vector3(-0.5, 0, 0))
	Kit.label(self, "BASE LUNAR", center + Vector3(0, 7.5, 6), 120, Color("2ec4ff"), true, 0.012)
