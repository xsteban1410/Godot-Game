extends Node3D
## Reto Ingeniería (port de BridgeConstructionManager + BridgePlacementPoint, rediseñado).
## En Unity el coste era siempre 20 × resistencia: solo existía una solución y el hormigón nunca servía.
## Aquí cada material tiene su relación precio/resistencia y el centro del puente carga más (flexión),
## así que la lección es "lo fuerte en el centro, lo barato en los apoyos". E sobre un tramo cambia su
## material; el botón rojo lanza el vehículo. 3 niveles = 3 estrellas. Se coloca mirando a la plaza (+Z).

const MATERIALS := [  # nombre, coste (CR), aguanta (t), color
	["MADERA", 10, 3, Color("c98a4b")],
	["METAL", 25, 6, Color("9aa6b8")],
	["HORMIGÓN", 40, 10, Color("b9b4aa")],
]
const LEVELS := [["COCHE", 3, 120], ["CAMIÓN", 4, 170], ["VOLQUETA", 5, 190]]  # vehículo, peso (t), presupuesto
const FACTORS := [1.0, 1.5, 2.0, 1.5, 1.0]  # carga de cada tramo respecto al peso: máxima en el centro
const SLOT_Z := [-0.75, -2.25, -3.75, -5.25, -6.75]
const START := Vector3(0, 1.0, 1.8)
const WATER := preload("res://world/water.gdshader")
const END := Vector3(0, 1.0, -9.3)

var _slots := [-1, -1, -1, -1, -1]  # material de cada tramo, -1 = vacío
var _pieces: Array[Node3D] = [null, null, null, null, null]
var _slot_areas: Array[Interactable] = []
var _board: Label3D
var _truck: Node3D
var _level := 0
var _testing := false


func _ready() -> void:
	_level = mini(int(Game.stars.get("bridge", 0)), LEVELS.size() - 1)
	var stone := Kit.mat(Color("e8ecf2"))
	for z in [1.5, -9.0]:
		Kit.solid(self, Vector3(6, 1, 3), Vector3(0, 0.5, z), stone)
	var river := ShaderMaterial.new()
	river.shader = WATER
	Kit.box(self, Vector3(16, 0.12, 7.5), Vector3(0, 0.22, -3.75), river)
	for i in SLOT_Z.size():
		Kit.box(self, Vector3(3.4, 0.04, 1.36), Vector3(0, 0.9, SLOT_Z[i]), Kit.mat(Color(1, 1, 1, 0.3)))
		var slot := Kit.interactable(self, "", Vector3(0, 1.0, SLOT_Z[i]), 1.4)
		slot.interacted.connect(_cycle.bind(i))
		_slot_areas.append(slot)

	Kit.box(self, Vector3(5.2, 3.0, 0.2), Vector3(-4.6, 2.15, 3.6), Kit.mat(Color.WHITE))
	Kit.box(self, Vector3(5.4, 0.16, 0.26), Vector3(-4.6, 3.7, 3.6), Kit.mat(Game.MODULES.bridge.color))
	Kit.cylinder(self, 0.08, 0.08, 1.2, Vector3(-4.6, 0.3, 3.6), Kit.mat(Color("cfd8e6")), 8)
	_board = Kit.label(self, "", Vector3(-4.6, 2.15, 3.72), 30, Color("1d2a3a"), false, 0.0072)  # cabe la línea más larga
	Kit.cylinder(self, 0.5, 0.6, 1.0, Vector3(4.2, 0.5, 3.6), Kit.mat(Color("f4f7fb")), 24)
	Kit.sphere(self, 0.42, Vector3(4.2, 1.0, 3.6), Kit.mat(Color("ff3b3b"), 0.6), Vector3(1, 0.6, 1))
	Kit.collider(self, Vector3(1.2, 1.2, 1.2), Vector3(4.2, 0.6, 3.6))
	Kit.label(self, "PROBAR", Vector3(4.2, 0.55, 4.18), 40, Game.RED, false, 0.008)
	Kit.interactable(self, "PROBAR EL PUENTE", Vector3(4.2, 1.0, 3.6), 1.6).interacted.connect(_test)
	Kit.bake(self)
	_build_truck()
	_refresh()


func cost() -> int:
	var total := 0
	for s: int in _slots:
		if s >= 0:
			total += MATERIALS[s][1]
	return total


func _cycle(i: int) -> void:
	if _testing:
		return
	_slots[i] = -1 if _slots[i] == MATERIALS.size() - 1 else _slots[i] + 1
	if _pieces[i]:
		_pieces[i].queue_free()
		_pieces[i] = null
	if _slots[i] >= 0:
		_pieces[i] = Kit.solid(self, Vector3(3.4, 0.24, 1.46), Vector3(0, 0.88, SLOT_Z[i]), Kit.mat(MATERIALS[_slots[i]][3], 0.0, 0.5 if _slots[i] == 1 else 0.0)).get_parent()
	Sfx.play("click")
	_refresh()


func _refresh() -> void:
	var level: Array = LEVELS[_level]
	for i in SLOT_Z.size():
		var holds: String = "VACÍO" if _slots[i] < 0 else "%s · aguanta %d t" % [MATERIALS[_slots[i]][0], MATERIALS[_slots[i]][2]]
		_slot_areas[i].prompt = "TRAMO %d · necesita %s t · %s  →  cambiar" % [i + 1, String.num(level[1] * FACTORS[i]), holds]
	_board.text = "NIVEL %d / 3 · %s DE %d t\nPRESUPUESTO: %d / %d CR\n\nMADERA  10 CR · 3 t\nMETAL  25 CR · 6 t\nHORMIGÓN  40 CR · 10 t\n\nE en un tramo: cambiar material" % [
		_level + 1, level[0], level[1], cost(), level[2]]


func _test() -> void:
	if _testing:
		return
	var level: Array = LEVELS[_level]
	if -1 in _slots:
		Game.notify("Faltan tramos: el puente necesita los 5.", Game.RED)
		return
	if cost() > level[2]:
		Game.notify("Te pasas del presupuesto: %d de %d CR." % [cost(), level[2]], Game.RED)
		return
	_testing = true
	for i in SLOT_Z.size():
		await _drive(Vector3(0, 1.0, SLOT_Z[i]))
		var need: float = level[1] * FACTORS[i]
		if MATERIALS[_slots[i]][2] < need:
			await _collapse(i, need)
			return
	await _drive(END)
	Sfx.play("success")
	Fx.confetti(self, END + Vector3(0, 1, 0))
	var hop := create_tween()
	hop.tween_property(_truck, "position:y", END.y + 1.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(_truck, "position:y", END.y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await hop.finished
	Game.set_stars("bridge", _level + 1)
	if _level < LEVELS.size() - 1:
		_level += 1
		Game.notify("¡Puente superado! Ahora prueba con un %s de %d t." % [LEVELS[_level][0], LEVELS[_level][1]], Game.GREEN)
		_build_truck()
	else:
		Game.notify("¡Superaste los 3 niveles! Eres ingeniero de Ciudad STEAM.", Game.GREEN)
		_truck.position = START
	_testing = false
	_refresh()


func _drive(to: Vector3) -> void:
	await create_tween().tween_property(_truck, "position", to, _truck.position.distance_to(to) / 2.5).finished


## El tramo revienta en trozos con física, el camión vuelca al río y salpica.
func _collapse(i: int, need: float) -> void:
	var material: Array = MATERIALS[_slots[i]]
	Sfx.play("boom")
	Fx.shake(self, 0.7)
	Game.notify("El tramo %d necesitaba %s t y la %s aguanta %d t." % [i + 1, String.num(need), material[0].to_lower(), material[2]], Game.RED)
	Fx.burst(self, Vector3(0, 1.0, SLOT_Z[i]), [material[3], material[3].darkened(0.3), Color.WHITE], 40, 8.0, 0.18)
	Fx.shatter(_pieces[i], Vector3(3.4, 0.24, 1.46), Kit.mat(material[3]), Vector3(0, 2, 0))
	_pieces[i] = null
	var tween := create_tween().set_parallel()
	tween.tween_property(_truck, "position:y", -0.6, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_truck, "rotation", Vector3(-1.1, 0.0, 0.6), 0.7)
	await tween.finished
	Sfx.play("splash")
	Fx.burst(self, Vector3(0, 0.3, SLOT_Z[i]), [Color("2ea8ff"), Color("bfe6ff"), Color.WHITE], 70, 9.0, 0.16)
	await get_tree().create_timer(1.2).timeout
	_slots[i] = -1
	_testing = false
	_truck.position = START
	_truck.rotation = Vector3.ZERO
	_refresh()


## Camión de juguete mirando hacia −Z; lleva un bloque gris por cada tonelada.
func _build_truck() -> void:
	if _truck:
		_truck.queue_free()
	_truck = Node3D.new()
	_truck.position = START
	add_child(_truck)
	Kit.box(_truck, Vector3(1.5, 0.45, 2.2), Vector3(0, 0.5, 0), Kit.mat(Game.MODULES.bridge.color))
	Kit.box(_truck, Vector3(1.3, 0.6, 0.75), Vector3(0, 1.0, -0.62), Kit.mat(Color("f4f7fb")))
	Kit.box(_truck, Vector3(1.15, 0.32, 0.05), Vector3(0, 1.08, -1.0), Kit.mat(Color("05070c"), 0.0, 0.3, 0.05))
	for x in [-0.5, 0.5]:  # faros
		Kit.sphere(_truck, 0.11, Vector3(x, 0.55, -1.1), Kit.mat(Color("fff3b0"), 3.0), Vector3(1, 1, 0.5))
	for x in [-0.78, 0.78]:
		for z in [-0.7, 0.7]:
			Kit.cylinder(_truck, 0.3, 0.3, 0.24, Vector3(x, 0.3, z), Kit.mat(Color("222831")), 16, Vector3(0, 0, PI / 2))
	var tons: int = LEVELS[_level][1]
	for k in tons:
		Kit.box(_truck, Vector3(0.55, 0.36, 0.55), Vector3(-0.3 + 0.6 * (k % 2), 0.92 + 0.38 * int(k / 2.0), 0.45), Kit.mat(Color("8a96a8"), 0.0, 0.6))
	Kit.label(_truck, "%d t" % tons, Vector3(0, 2.6, 0.3), 64, Color.WHITE)
	Kit.bake(_truck)
