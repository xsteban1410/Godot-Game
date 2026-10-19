extends Node3D
## Reto lunar "Salto lunar": una espiral de plataformas dentro de un cráter en sombra perpetua.
## Solo se sube aprovechando la gravedad lunar (saltos de ~4,5 m; en la Tierra serían 1,5 m).
## Cada cristal de hielo es una estrella y queda guardado.

const STEPS := 9
const CRYSTALS := [2, 5, 8]  # plataformas con hielo

var _crystals: Array[Area3D] = []


func _ready() -> void:
	var rim := Kit.torus(self, 13.0, 16.0, Vector3.ZERO, Kit.mat(Color("7d828b"), 0.0, 0.0, 0.95))
	rim.scale.y = 0.35
	Kit.cylinder(self, 13.0, 13.0, 0.05, Vector3(0, 0.03, 0), Kit.mat(Color("2c2f36"), 0.0, 0.0, 1.0), 48)  # sombra perpetua
	Kit.banner(self, "SALTO LUNAR", Vector3(0, 6.0, 14), 110, Game.info("moon_jump").color)
	Kit.banner(self, "Aquí la gravedad es 1/6: ¡salta!", Vector3(0, 4.9, 14), 52, Color.WHITE)
	var rock := Kit.mat(Color("b9bdc6"), 0.0, 0.0, 0.8)
	for i in STEPS:
		var a := i * TAU / 6.0
		var p := Vector3(cos(a) * 7.0, 1.0 + i * 2.4, sin(a) * 7.0)
		Kit.cylinder(self, 1.7, 1.4, 0.6, p, rock, 24)
		Kit.torus(self, 1.55, 1.75, p + Vector3(0, 0.3, 0), Kit.mat(Game.info("moon_jump").color, 1.5))
		Kit.collider(self, Vector3(2.8, 0.6, 2.8), p)
		if i in CRYSTALS:
			_crystal(CRYSTALS.find(i), p + Vector3(0, 1.3, 0))
		elif i in [3, 6]:  # tuercas doradas en dos escalones sin hielo
			Bolt.spawn(self, "moon_crater_%d" % i, p + Vector3(0, 1.3, 0))
	Kit.bake(self)


func _crystal(index: int, pos: Vector3) -> void:
	if int(Game.stars.get("moon_jump", 0)) > index:
		return  # ya recogido en otra visita
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = 1.0
	area.add_child(shape)
	var ice := Kit.MOON_ROCK.merged({"crystal": Kit.mat(Color(0.6, 0.95, 1.0), 2.5, 0.0, 0.05)})
	Kit.model(area, "kenney/space/rock_crystals", Transform3D(Basis().scaled(Vector3.ONE * 2.0), Vector3(0, -1.0, 0)), false, null, ice)
	add_child(area)
	var spin := area.create_tween().set_loops()
	spin.tween_property(area, "rotation:y", TAU, 3.0).from(0.0)
	area.body_entered.connect(_collect.bind(area))
	_crystals.append(area)


func _collect(body: Node3D, area: Area3D) -> void:
	if not body.is_in_group("player") or not is_instance_valid(area):
		return
	Sfx.play("pickup")
	Fx.burst(self, area.position, [Color("bfe6ff"), Color.WHITE, Color("2ec4ff")], 40, 6.0, 0.12)
	area.queue_free()
	_crystals.erase(area)
	var found := int(Game.stars.get("moon_jump", 0)) + 1
	Game.notify("¡Hielo! %d / 3. En los cráteres donde nunca da el Sol, el agua sigue congelada." % found, Color("bfe6ff"))
	Game.set_stars("moon_jump", found)
