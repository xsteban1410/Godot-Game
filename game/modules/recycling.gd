extends Node3D
## Reto Reciclaje (port de RecyclingChallenge y sus Interactables). Código de colores de Colombia
## (Resolución 2184 de 2019): verde orgánicos, blanca aprovechables, negra no aprovechables.
## Se juega en 3D sin panel (en Unity el reto liberaba el cursor y la cámara dejaba de girar):
## E recoge un residuo, E junto a una caneca lo lanza. Estrellas según los errores.
## Se coloca mirando a la plaza (+Z).

const ROUND := 8
const BINS := {  # caneca -> [nombre, color, x]
	"verde": ["CANECA VERDE · ORGÁNICOS", Color("3fae5a"), -3.2],
	"blanca": ["CANECA BLANCA · APROVECHABLES", Color("f4f7fb"), 0.0],
	"negra": ["CANECA NEGRA · NO APROVECHABLES", Color("2a2f38"), 3.2],
}
const SPOTS := [Vector3(-6, 0, 3), Vector3(6, 0, 3), Vector3(-7, 0, -1), Vector3(7, 0, -1),
	Vector3(-2.2, 0, 5.2), Vector3(4, 0, 6), Vector3(-7.5, 0, -4.5), Vector3(7.5, 0, -4.5)]
# [residuo, caneca, explicación, forma, color]; los 10 primeros son los del juego original.
const ITEMS := [
	["Cáscara de plátano", "verde", "Es un resto de alimento y se degrada con los orgánicos.", "peel", Color("ffd23f")],
	["Restos de comida", "verde", "Los restos de comida y cocina son orgánicos aprovechables.", "ball", Color("c98a4b")],
	["Hojas secas", "verde", "Los residuos vegetales y agrícolas van en la caneca verde.", "leaves", Color("d9822b")],
	["Botella plástica vacía", "blanca", "El plástico limpio y vacío es aprovechable.", "bottle", Color("9fd8ff")],
	["Papel y cartón limpios", "blanca", "El papel y el cartón limpios se aprovechan en la blanca.", "box", Color("d9b38c")],
	["Frasco de vidrio limpio", "blanca", "El vidrio limpio es un residuo aprovechable.", "jar", Color("7fe0d0")],
	["Lata metálica limpia", "blanca", "Los metales limpios se clasifican como aprovechables.", "can", Color("c0c8d4")],
	["Papel higiénico usado", "negra", "El papel higiénico usado no es aprovechable: va en la negra.", "roll", Color("f4f7fb")],
	["Servilleta con comida", "negra", "Las servilletas sucias no se reciclan con el papel limpio.", "flat", Color("ffe9c9")],
	["Cartón con grasa", "negra", "El cartón con comida o grasa ya no se puede aprovechar.", "box", Color("8a6a4a")],
	["Cáscara de huevo", "verde", "Es un resto de alimento: se descompone con los orgánicos.", "ball", Color("fff3dd")],
	["Periódico", "blanca", "El papel seco y limpio se recicla.", "flat", Color("e8e8e8")],
	["Tetra pak enjuagado", "blanca", "Enjuagado y aplastado, el tetra pak es aprovechable.", "box", Color("2ec4ff")],
	["Posos de café", "verde", "Los restos de café son orgánicos y sirven para compost.", "ball", Color("5a3b24")],
	["Pañal usado", "negra", "Los pañales usados no se pueden aprovechar.", "flat", Color("dfe7f2")],
	["Icopor con comida", "negra", "El icopor sucio no se puede reciclar: va en la negra.", "box", Color("fafafa")],
]

var _items: Array[Interactable] = []
var _bins := {}  # caneca -> [Interactable, tapa]
var _carried: Interactable
var _done := 0
var _mistakes := 0
var _busy := false
var _board: Label3D


func _ready() -> void:
	Kit.stand(self, Vector3(-5.0, 0, 5.8), Game.MODULES.recycling.color, "RETO: RECICLAJE").interacted.connect(start)
	for id: String in BINS:
		var spec: Array = BINS[id]
		var base := Vector3(spec[2], 0, -6)
		Kit.cylinder(self, 0.85, 0.75, 1.6, base + Vector3(0, 0.8, 0), Kit.mat(spec[1]), 32)
		Kit.pillar(self, 0.85, 1.6, base + Vector3(0, 0.8, 0))
		Kit.torus(self, 0.78, 0.92, base + Vector3(0, 1.2, 0), Kit.mat(Game.MODULES.recycling.color if id != "verde" else Color.WHITE))
		var lid := Node3D.new()  # pivote en el borde trasero para abrir la tapa hacia atrás
		lid.position = base + Vector3(0, 1.62, -0.85)
		add_child(lid)
		Kit.cylinder(lid, 0.9, 0.9, 0.14, Vector3(0, 0, 0.85), Kit.mat(Color(spec[1]).darkened(0.2)), 32)
		Kit.label(self, id.to_upper(), base + Vector3(0, 0.8, 0.9), 48, Color.WHITE if id == "negra" else Color("1d2a3a"), false)
		var area := Kit.interactable(self, spec[0], base + Vector3(0, 1, 0.6), 1.5)
		area.interacted.connect(_throw.bind(id))
		_bins[id] = [area, lid]
	_board = Kit.label(self, "RECICLAJE\nUsa el atril para empezar", Vector3(0, 3.6, -6), 56, Color.WHITE)
	Kit.bake(self)


func start() -> void:
	if _busy:
		return
	for item in _items:
		item.queue_free()
	_items.clear()
	if _carried:
		_carried.queue_free()
		_carried = null
	_done = 0
	_mistakes = 0
	var bank := ITEMS.duplicate()
	bank.shuffle()
	for i in ROUND:
		var data: Array = bank[i]
		var home: Vector3 = SPOTS[i] + Vector3(0, 0.17, 0)  # sobre la plataforma
		var item := Kit.interactable(self, "RECOGER: " + String(data[0]).to_upper(), home, 1.0)
		item.marker_height = 1.3
		item.set_meta("data", data)
		item.set_meta("home", home)
		_model(item, data[3], data[4])
		item.interacted.connect(_pickup.bind(item))
		_items.append(item)
		item.scale = Vector3.ONE * 0.01
		create_tween().tween_property(item, "scale", Vector3.ONE * 1.5, 0.4).set_delay(i * 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("pickup")
	_refresh()


func _pickup(item: Interactable) -> void:
	if _carried:
		Game.notify("Ya llevas un residuo: lánzalo a una caneca.", Game.WARNING)
	if _busy or _carried:
		return
	_carried = item
	item.set_enabled(false)
	item.reparent(get_tree().get_first_node_in_group("player"), false)
	item.position = Vector3(0, 2.6, 0)
	item.rotation = Vector3.ZERO
	item.scale = Vector3.ONE * 2.6
	create_tween().tween_property(item, "scale", Vector3.ONE * 1.9, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("hop")
	_refresh()


## Lanza el residuo en arco a la caneca: si acierta, la tapa se abre entre confeti; si no, rebota y vuelve.
func _throw(id: String) -> void:
	if _busy:
		return
	if not _carried:
		Game.notify("Primero recoge un residuo con E.", Game.WARNING)
		return
	_busy = true
	var item := _carried
	_carried = null
	var data: Array = item.get_meta("data")
	item.reparent(self)
	var target := Vector3(BINS[id][2], 1.8, -6)
	var peak := maxf(item.position.y, target.y) + 1.8
	Sfx.play("jump")
	var tween := create_tween().set_parallel()
	tween.tween_property(item, "position:x", target.x, 0.55)
	tween.tween_property(item, "position:z", target.z, 0.55)
	tween.tween_property(item, "rotation", Vector3(TAU, PI, 0), 0.55)
	tween.tween_property(item, "position:y", peak, 0.27).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(item, "position:y", target.y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if data[1] == id:
		_done += 1
		item.queue_free()
		_items.erase(item)
		var lid: Node3D = _bins[id][1]
		var flap := create_tween()
		flap.tween_property(lid, "rotation:x", -1.4, 0.12)
		flap.tween_property(lid, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Fx.confetti(self, target + Vector3(0, 0.5, 0))
		Sfx.play("success")
		Game.notify("¡Bien! %s → %s." % [data[0], id], Game.SUCCESS)
	else:
		_mistakes += 1
		Sfx.play("error")
		Fx.burst(self, target, [Color("ff5d5d"), Color("5a6b7d"), Color("2a2f38")], 30, 5.0, 0.2)
		Fx.shake(self, 0.3)
		Game.notify("¡No va en la %s! %s" % [id, data[2]], Game.DANGER)
		await _send_home(item)
	_busy = false
	_refresh()
	if _done == ROUND:
		_finish()


## Si te alejas del reto con un residuo en la mano, vuelve a su sitio (no se pasea por la ciudad).
func _process(_delta: float) -> void:
	if _carried and not _busy and _carried.global_position.distance_to(global_position) > 14.0:
		var item := _carried
		_carried = null
		item.reparent(self)
		Game.notify("El residuo vuelve a su sitio: recíclalo sin salir del reto.", Game.WARNING)
		_refresh()
		_send_home(item)


## El residuo vuelve de un salto a su plataforma y se puede recoger otra vez.
func _send_home(item: Interactable) -> void:
	var back := create_tween().set_parallel()
	back.tween_property(item, "position", item.get_meta("home"), 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	back.tween_property(item, "scale", Vector3.ONE * 1.5, 0.6)
	back.tween_property(item, "rotation", Vector3.ZERO, 0.6)
	await back.finished
	item.set_enabled(true)


func _finish() -> void:
	var stars := 3 if _mistakes == 0 else 2 if _mistakes <= 2 else 1
	Game.set_stars("recycling", stars)
	for id: String in BINS:
		Fx.confetti(self, Vector3(BINS[id][2], 2.2, -6))
	_board.text = "¡CIUDAD LIMPIA!  %s\n%d errores. Usa el atril para repetir" % [UI.stars(stars), _mistakes]


func _refresh() -> void:
	if _done < ROUND:
		_board.text = "RECICLAJE  ·  %d / %d  ·  errores: %d\n%s" % [_done, ROUND, _mistakes,
			"Lleva: " + String(_carried.get_meta("data")[0]) if _carried else "Recoge un residuo con E"]
	for id: String in BINS:
		_bins[id][0].prompt = ("LANZAR A LA " if _carried else "") + BINS[id][0]


## Modelos de juguete de los residuos, con el color de cada uno.
func _model(parent: Node3D, shape: String, color: Color) -> void:
	var main := Kit.mat(color, 0.0, 0.6 if shape == "can" else 0.0, 0.25)
	match shape:
		"bottle":
			Kit.cylinder(parent, 0.15, 0.15, 0.5, Vector3(0, 0.25, 0), Kit.mat(Color(color, 0.75)), 16)
			Kit.cylinder(parent, 0.06, 0.12, 0.14, Vector3(0, 0.57, 0), Kit.mat(Color(color, 0.75)), 16)
			Kit.cylinder(parent, 0.07, 0.07, 0.07, Vector3(0, 0.67, 0), Kit.mat(Color("1f6fff")), 12)
		"can":
			Kit.cylinder(parent, 0.15, 0.15, 0.34, Vector3(0, 0.17, 0), main, 16)
			Kit.cylinder(parent, 0.152, 0.152, 0.12, Vector3(0, 0.17, 0), Kit.mat(Color("ff4f8b")), 16)
		"jar":
			Kit.cylinder(parent, 0.18, 0.18, 0.34, Vector3(0, 0.17, 0), Kit.mat(Color(color, 0.6), 0.0, 0.0, 0.05), 16)
			Kit.cylinder(parent, 0.15, 0.15, 0.08, Vector3(0, 0.38, 0), Kit.mat(Color("ffcc00")), 16)
		"box":
			Kit.box(parent, Vector3(0.45, 0.32, 0.34), Vector3(0, 0.16, 0), main)
			Kit.box(parent, Vector3(0.47, 0.04, 0.08), Vector3(0, 0.33, 0), Kit.mat(color.darkened(0.25)))
		"flat":
			Kit.box(parent, Vector3(0.5, 0.06, 0.4), Vector3(0, 0.05, 0), main, Vector3(0, 0.4, 0.06))
			Kit.box(parent, Vector3(0.4, 0.05, 0.32), Vector3(0.03, 0.1, 0), main, Vector3(0, -0.3, 0))
		"roll":
			Kit.cylinder(parent, 0.16, 0.16, 0.26, Vector3(0, 0.16, 0), main, 16, Vector3(PI / 2, 0, 0))
			Kit.cylinder(parent, 0.06, 0.06, 0.27, Vector3(0, 0.16, 0), Kit.mat(Color("c98a4b")), 12, Vector3(PI / 2, 0, 0))
		"ball":
			Kit.sphere(parent, 0.2, Vector3(0, 0.15, 0), main, Vector3(1.2, 0.7, 1.0))
			Kit.sphere(parent, 0.12, Vector3(0.14, 0.22, 0.05), Kit.mat(color.lightened(0.2)), Vector3(1, 0.7, 1))
		"peel":
			for angle in [-0.7, 0.0, 0.7]:
				Kit.capsule(parent, 0.06, 0.42, Vector3(sin(angle) * 0.12, 0.1, cos(angle) * 0.12), main, Vector3(PI / 2 - 0.3, angle, 0))
		"leaves":
			for k in 3:
				Kit.sphere(parent, 0.2, Vector3(k * 0.14 - 0.14, 0.06 + k * 0.04, 0), Kit.mat(color.darkened(k * 0.15)), Vector3(1.3, 0.25, 0.8))
