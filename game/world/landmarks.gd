class_name Landmarks
## Monumento de juguete detrás de cada distrito: se ve desde la plaza y dice de un vistazo de qué va el reto.
## `root` mira a la plaza (+Z) y está detrás del disco del distrito. Devuelve los pivotes que giran
## (con la velocidad en el meta "spin"; los que flotan, con el meta "bob"), que la ciudad anima.


static func build(id: String, root: Node3D) -> Array[Node3D]:
	var spinners: Array[Node3D] = []
	match id:
		"solar": _sunflowers(root)
		"bridge": spinners.append(_crane(root))
		"robotics": spinners.append(_robot_arm(root))
		"recycling": _bottle_and_truck(root)
		"math": spinners.append_array(_solids(root))
		"vision": _camera_and_heart(root)
		"ai": spinners.append_array(_x_and_o(root))
	Kit.bake(root, spinners)
	return spinners


static func _spinner(root: Node3D, pos: Vector3, speed: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.set_meta("spin", speed)
	root.add_child(pivot)
	return pivot


## Tres girasoles gigantes mirando a la plaza: la flor que sigue al Sol.
static func _sunflowers(root: Node3D) -> void:
	for spec: Array in [[-3.4, 6.0], [0.0, 7.6], [3.4, 5.6]]:
		var x: float = spec[0]
		var h: float = spec[1]
		Kit.cylinder(root, 0.2, 0.28, h, Vector3(x, h / 2.0, 0), Kit.mat(Color("78a884")), 12)
		Kit.pillar(root, 0.3, h, Vector3(x, h / 2.0, 0))
		for side in [-1.0, 1.0]:
			Kit.sphere(root, 0.7, Vector3(x + 0.55 * side, h * 0.4 + side * 0.3, 0), Kit.mat(Color("95cfa0")), Vector3(1.4, 0.25, 0.8), 12)
		var head := Vector3(x, h, 0.3)
		Kit.cylinder(root, 1.0, 1.0, 0.35, head, Kit.mat(Color("7a6758")), 24, Vector3(PI / 2, 0, 0))
		for k in 12:
			var a := TAU * k / 12.0
			Kit.sphere(root, 0.5, head + Vector3(cos(a), sin(a), -0.05) * 1.45, Kit.mat(Color("ffeb99")), Vector3(1.0, 0.5, 0.25), 10).rotation.z = a


## Grúa torre amarilla: el brazo gira despacio con una viga colgando del gancho.
static func _crane(root: Node3D) -> Node3D:
	var yellow := Kit.mat(Color("ffeb99"))
	var dark := Kit.mat(Color("383c42"))
	Kit.box(root, Vector3(2.2, 0.6, 2.2), Vector3(0, 0.3, 0), Kit.mat(Color("b9b4aa")))
	Kit.box(root, Vector3(1.0, 12.0, 1.0), Vector3(0, 6.0, 0), yellow)
	for y in range(1, 12, 2):
		Kit.box(root, Vector3(1.08, 0.14, 1.08), Vector3(0, y, 0), dark)
	Kit.collider(root, Vector3(2.2, 12.6, 2.2), Vector3(0, 6.3, 0))
	var jib := _spinner(root, Vector3(0, 12.3, 0), 0.15)
	Kit.box(jib, Vector3(10.0, 0.6, 0.7), Vector3(2.0, 0, 0), yellow)  # corto: al girar no atraviesa las torres
	Kit.box(jib, Vector3(1.8, 1.4, 1.6), Vector3(-3.4, -0.4, 0), Kit.mat(Color("b9b4aa")))  # contrapeso
	Kit.box(jib, Vector3(1.3, 1.1, 1.3), Vector3(0, -0.9, 1.0), Kit.mat(Color("f4f7fb")))  # cabina
	Kit.box(jib, Vector3(1.0, 0.5, 0.05), Vector3(0, -0.8, 1.66), Kit.mat(Color("090a0c"), 0.0, 0.3, 0.05))
	Kit.cylinder(jib, 0.04, 0.04, 5.0, Vector3(6.0, -2.5, 0), dark, 6)
	Kit.box(jib, Vector3(3.0, 0.35, 0.45), Vector3(6.0, -5.2, 0), Kit.mat(Game.MODULES.bridge.color))  # viga
	Kit.cylinder(jib, 0.08, 0.08, 1.6, Vector3(0, 1.0, 0), dark, 6)
	Kit.sphere(jib, 0.16, Vector3(0, 1.85, 0), Kit.mat(Game.ACCENT, 4.0), Vector3.ONE, 10)  # luz de aviso
	Kit.bake(jib)
	return jib


## Brazo robótico industrial que gira sobre su base sujetando un bloque.
static func _robot_arm(root: Node3D) -> Node3D:
	var white := Kit.mat(Color("f4f7fb"))
	var blue := Kit.mat(Game.MODULES.robotics.color)
	var joint := Kit.mat(Color("3a4352"), 0.0, 0.4, 0.3)
	Kit.cylinder(root, 1.6, 1.9, 1.0, Vector3(0, 0.5, 0), joint, 32)
	Kit.pillar(root, 1.9, 1.0, Vector3(0, 0.5, 0))
	Kit.pillar(root, 1.2, 2.2, Vector3(0, 1.1, 0))
	var turret := _spinner(root, Vector3(0, 1.0, 0), 0.4)
	Kit.cylinder(turret, 1.2, 1.2, 0.8, Vector3(0, 0.4, 0), blue, 32)
	Kit.sphere(turret, 0.8, Vector3(0, 1.2, 0), joint)
	Kit.box(turret, Vector3(0.8, 4.2, 0.8), Vector3(1.0, 3.04, 0), white, Vector3(0, 0, -0.5))
	Kit.sphere(turret, 0.6, Vector3(2.01, 4.89, 0), blue)
	Kit.box(turret, Vector3(0.6, 3.2, 0.6), Vector3(3.46, 4.22, 0), white, Vector3(0, 0, -2.0))
	Kit.sphere(turret, 0.42, Vector3(4.92, 3.56, 0), joint)
	for side in [-0.32, 0.32]:
		Kit.box(turret, Vector3(0.14, 0.6, 0.3), Vector3(4.92 + side, 3.0, 0), joint)
	Kit.box(turret, Vector3(0.5, 0.5, 0.5), Vector3(4.92, 2.85, 0), Kit.mat(Color("ffb9d1")))  # el bloque que sujeta
	Kit.bake(turret)
	return turret


## Botella PET gigante (el material del cohete) y un camión de reciclaje verde.
static func _bottle_and_truck(root: Node3D) -> void:
	var pet := Kit.mat(Color(0.6, 0.88, 1.0, 0.55), 0.2, 0.0, 0.05)
	var green := Kit.mat(Game.MODULES.recycling.color)
	var b := Vector3(-3.2, 0, 0)
	Kit.cylinder(root, 2.0, 2.2, 0.5, b + Vector3(0, 0.25, 0), Kit.mat(Color("f4f7fb")), 32)
	Kit.cylinder(root, 1.6, 1.6, 5.0, b + Vector3(0, 3.0, 0), pet, 32)
	Kit.cylinder(root, 1.62, 1.62, 1.2, b + Vector3(0, 3.0, 0), green, 32)  # etiqueta
	Kit.cylinder(root, 0.5, 1.6, 1.4, b + Vector3(0, 6.2, 0), pet, 32)
	Kit.cylinder(root, 0.5, 0.5, 0.6, b + Vector3(0, 7.2, 0), pet, 16)
	Kit.cylinder(root, 0.6, 0.6, 0.5, b + Vector3(0, 7.7, 0), green, 16)
	Kit.pillar(root, 2.2, 8.0, b + Vector3(0, 4.0, 0))
	var t := Vector3(3.6, 0, 0)  # el camión mira a la plaza
	Kit.box(root, Vector3(2.4, 2.6, 4.2), t + Vector3(0, 2.0, -1.0), green)
	Kit.box(root, Vector3(2.5, 0.3, 4.3), t + Vector3(0, 3.0, -1.0), Kit.mat(Color("f4f7fb")))  # franja
	Kit.box(root, Vector3(2.2, 2.0, 1.8), t + Vector3(0, 1.7, 2.1), Kit.mat(Color("f4f7fb")))
	Kit.box(root, Vector3(1.9, 0.8, 0.05), t + Vector3(0, 2.1, 3.0), Kit.mat(Color("090a0c"), 0.0, 0.3, 0.05))
	for x in [-0.7, 0.7]:
		Kit.sphere(root, 0.16, t + Vector3(x, 1.1, 3.0), Kit.mat(Color("fff3b0"), 3.0), Vector3(1, 1, 0.5), 10)
	for x in [-1.25, 1.25]:
		for z in [-2.2, 0.0, 2.0]:
			Kit.cylinder(root, 0.55, 0.55, 0.4, t + Vector3(x, 0.55, z), Kit.mat(Color("222831")), 16, Vector3(0, 0, PI / 2))
	Kit.collider(root, Vector3(2.6, 3.2, 6.4), t + Vector3(0, 1.6, 0))


## Sólidos geométricos que flotan y giran sobre sus pedestales: cubo, pirámide y esfera.
static func _solids(root: Node3D) -> Array[Node3D]:
	var pivots: Array[Node3D] = []
	var specs := [[-3.6, Color("d7c4ff"), "cube"], [0.0, Color("ffeb99"), "pyramid"], [3.6, Color("ffb9d1"), "sphere"]]
	for i in specs.size():
		var spec: Array = specs[i]
		var p := Vector3(spec[0], 0, 0)
		Kit.cylinder(root, 1.0, 1.2, 1.4, p + Vector3(0, 0.7, 0), Kit.mat(Color("f4f7fb")), 24)
		Kit.torus(root, 0.9, 1.05, p + Vector3(0, 1.42, 0), Kit.mat(Color("aee0f0"), 2.0))
		Kit.pillar(root, 1.2, 1.4, p + Vector3(0, 0.7, 0))
		var pivot := _spinner(root, p + Vector3(0, 3.4 + i * 0.5, 0), 0.6 - i * 0.2)
		match spec[2]:
			"cube":
				Kit.box(pivot, Vector3(1.6, 1.6, 1.6), Vector3.ZERO, Kit.mat(spec[1]), Vector3(0.6, 0, 0.6))
			"pyramid":
				Kit.cylinder(pivot, 0.0, 1.4, 2.2, Vector3.ZERO, Kit.mat(spec[1]), 4)
			"sphere":
				Kit.sphere(pivot, 1.0, Vector3.ZERO, Kit.mat(spec[1]))
		pivot.set_meta("bob", 1.4 + i * 0.2)  # la ciudad lo hace flotar (s por medio ciclo)
		pivots.append(pivot)
	return pivots


## Cámara gigante en su trípode y un corazón de píxeles: para una IA, una imagen es una cuadrícula.
static func _camera_and_heart(root: Node3D) -> void:
	var color: Color = Game.LAB_MODULES.vision.color
	var c := Vector3(-3.0, 0, 0)
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		Kit.cylinder(root, 0.12, 0.16, 7.2, c + Vector3(sin(a) * 1.2, 3.5, cos(a) * 1.2), Kit.mat(Color("3a4352")), 8,
			Vector3(cos(a) * 0.17, 0, -sin(a) * 0.17))
	Kit.pillar(root, 1.4, 7.0, c + Vector3(0, 3.5, 0))
	Kit.box(root, Vector3(3.0, 2.0, 2.0), c + Vector3(0, 7.9, 0), Kit.mat(Color("f4f7fb")))
	Kit.box(root, Vector3(0.8, 0.4, 0.8), c + Vector3(-0.8, 9.1, 0), Kit.mat(color))
	Kit.cylinder(root, 0.9, 1.0, 1.0, c + Vector3(0, 7.9, 1.4), Kit.mat(Color("3a4352")), 24, Vector3(PI / 2, 0, 0))
	Kit.sphere(root, 0.75, c + Vector3(0, 7.9, 1.9), Kit.mat(Color("090a0c"), 0.0, 0.3, 0.03), Vector3(1, 1, 0.4))
	Kit.sphere(root, 0.26, c + Vector3(0, 7.9, 2.15), Kit.mat(color, 4.0), Vector3(1, 1, 0.4))
	Kit.sphere(root, 0.18, c + Vector3(1.1, 9.0, 0.6), Kit.mat(Game.ACCENT, 4.0), Vector3.ONE, 10)  # luz de grabación
	var heart: String = ".#.#. ##### ##### .###. ..#..".replace(" ", "")
	var h := Vector3(3.6, 0, 0)
	Kit.box(root, Vector3(5.0, 5.0, 0.3), h + Vector3(0, 4.4, -0.3), Kit.mat(Color("2a2c33")))
	for x in [-2.2, 2.2]:
		Kit.cylinder(root, 0.12, 0.12, 2.0, h + Vector3(x, 1.0, -0.3), Kit.mat(Color("f4f7fb")), 8)
	Kit.collider(root, Vector3(5.0, 7.0, 0.6), h + Vector3(0, 3.5, -0.3))
	for i in 25:
		var lit := heart[i] == "#"
		Kit.box(root, Vector3(0.82, 0.82, 0.3), h + Vector3((i % 5 - 2) * 0.9, 6.2 - floori(i / 5.0) * 0.9, -0.05),
			Kit.mat(color, 2.0) if lit else Kit.mat(Color("383b42")))


## Una X y una O gigantes que giran despacio: las fichas del tres en raya contra NOVA.
static func _x_and_o(root: Node3D) -> Array[Node3D]:
	var pivots: Array[Node3D] = []
	for spec: Array in [[-3.2, 0.3], [3.2, -0.3]]:
		var p := Vector3(spec[0], 0, 0)
		Kit.cylinder(root, 1.3, 1.5, 0.6, p + Vector3(0, 0.3, 0), Kit.mat(Color("f4f7fb")), 24)
		Kit.pillar(root, 1.5, 0.6, p + Vector3(0, 0.3, 0))
		pivots.append(_spinner(root, p + Vector3(0, 3.6, 0), spec[1]))
	for a in [PI / 4, -PI / 4]:
		Kit.box(pivots[0], Vector3(0.9, 4.4, 0.9), Vector3.ZERO, Kit.mat(Color("a5c5ff")), Vector3(0, 0, a))
	Kit.torus(pivots[1], 1.2, 2.1, Vector3.ZERO, Kit.mat(Game.LAB_MODULES.ai.color), Vector3(PI / 2, 0, 0))
	for pivot in pivots:
		Kit.bake(pivot)
	return pivots
