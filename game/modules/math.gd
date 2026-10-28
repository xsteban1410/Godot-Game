extends Node3D
## Reto Matemáticas: "Mates en el aire". Cuatro plataformas flotan a distintas alturas, cada una con un
## número, y solo se llega a ellas volando con el jetpack (ESPACIO otra vez en el aire). Aterrizar en la
## respuesta correcta suma; en una equivocada, la plataforma se hunde y te lanza fuera. 6 preguntas por
## ronda; estrellas según los errores. Se coloca mirando a la plaza (+Z).

const ROUND := 6
const PADS := [Vector3(-5.0, 2.4, -1.5), Vector3(-2.2, 3.4, -6.0), Vector3(2.4, 4.4, -6.0), Vector3(5.2, 3.0, -1.0)]

var _questions: Array = []  # [texto, respuesta]
var _index := -1  # -1: ronda sin empezar
var _mistakes := 0
var _failed := {}  # plataformas ya falladas en esta pregunta: recaer en una no suma otro error
var _right := 0  # plataforma con la respuesta correcta
var _last := -1  # plataforma donde está el jugador: la siguiente respuesta nunca cae ahí
var _busy := false
var _pads: Array[Node3D] = []
var _rings: Array[MeshInstance3D] = []
var _numbers: Array[Label3D] = []
var _board: Label3D


func _ready() -> void:
	var color: Color = Game.info("math").color
	Kit.stand(self, Vector3(-3.5, 0, 4.0), color, "RETO: MATEMÁTICAS").interacted.connect(start)
	_board = Kit.label(self, "MATES EN EL AIRE\nVuela con el jetpack\nhasta la respuesta", Vector3(0, 7.5, -8.55), 64, Color.WHITE, false, 0.01, 8.2)
	Kit.box(self, Vector3(8.6, 2.6, 0.3), Vector3(0, 7.5, -8.75), Kit.mat(Color("2a2f45")))
	Kit.box(self, Vector3(8.9, 0.25, 0.4), Vector3(0, 8.9, -8.75), Kit.mat(color))
	for x in [-3.6, 3.6]:
		Kit.cylinder(self, 0.12, 0.12, 6.4, Vector3(x, 3.2, -8.8), Kit.mat(Color("f4f7fb")), 10)
	for i in PADS.size():
		var pad := Node3D.new()
		pad.position = PADS[i]
		add_child(pad)
		var hover := Node3D.new()  # el dibujo flota arriba y abajo; la colisión se queda quieta
		pad.add_child(hover)
		Kit.cylinder(hover, 1.35, 1.15, 0.4, Vector3.ZERO, Kit.mat(Color("f4f7fb")), 32)
		_rings.append(Kit.torus(hover, 1.25, 1.45, Vector3(0, 0.12, 0), Kit.mat(color, 1.5)))
		Kit.sphere(hover, 0.45, Vector3(0, -0.3, 0), Kit.mat(Color("4cc9f0"), 3.0), Vector3(1, 0.4, 1))  # motor que la hace flotar
		Kit.bake(hover, _rings)
		var bob := hover.create_tween().set_loops()
		bob.tween_property(hover, "position:y", 0.12, 1.1 + i * 0.1).set_trans(Tween.TRANS_SINE)
		bob.tween_property(hover, "position:y", 0.0, 1.1 + i * 0.1).set_trans(Tween.TRANS_SINE)
		Kit.collider(pad, Vector3(2.5, 0.4, 2.5), Vector3.ZERO)
		_numbers.append(Kit.label(pad, "?", Vector3(0, 1.3, 0), 110, Color.WHITE, true, 0.01))
		var top := Area3D.new()  # lo que cuenta es posarse encima
		top.position.y = 0.5
		top.collision_layer = 0
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(2.2, 0.6, 2.2)
		top.add_child(shape)
		pad.add_child(top)
		top.body_entered.connect(_on_land.bind(i))
		_pads.append(pad)
	Kit.bake(self)


func start() -> void:
	if _busy:
		return
	_questions.clear()
	for i in ROUND:
		_questions.append(question(i))
	_index = 0
	_mistakes = 0
	Sfx.play("pickup")
	Game.notify("Salta y, en el aire, vuelve a saltar: ¡el jetpack te sube! Mantenlo para volar.", Game.TEAL)
	_show_question()


## Pregunta n.º `n` de la ronda (cada vez un poco más difícil): [texto, respuesta].
static func question(n: int) -> Array:
	var a := randi_range(3, 9)
	var b := randi_range(3, 9)
	match n % 6:
		0:
			return ["%d + %d" % [a * 3, b * 4], a * 3 + b * 4]
		1:
			return ["%d × %d" % [a, b], a * b]
		2:
			return ["%d − %d" % [a * b, a], a * b - a]
		3:
			return ["%d ÷ %d" % [a * b, b], a]
		4:
			return ["Área de un\nrectángulo de %d × %d" % [a, b + 2], a * (b + 2)]
		_:
			return ["%d %% de %d" % [[10, 25, 50][a % 3], b * 20], b * [2, 5, 10][a % 3]]  # 10 %, 25 % y 50 % de 20·b


## Tres respuestas falsas creíbles y distintas: vecinas de la buena.
static func distractors(answer: int) -> Array:
	var options := [answer + 1, answer - 1, answer + 2, answer - 2, answer + 10, answer - 10].filter(func(o: int) -> bool: return o > 0)
	options.shuffle()
	return options.slice(0, 3)


func _show_question() -> void:
	var q: Array = _questions[_index]
	_failed.clear()
	var answers := [q[1]] + distractors(q[1])
	answers.shuffle()
	_right = answers.find(q[1])
	if _right == _last:  # la buena nunca donde ya estás de pie
		var other := (_right + 1 + randi() % 3) % PADS.size()
		answers[_right] = answers[other]
		answers[other] = q[1]
		_right = other
	for i in PADS.size():
		_numbers[i].text = str(answers[i])
		_rings[i].material_override = Kit.mat(Game.info("math").color, 1.5)
		_numbers[i].create_tween().tween_property(_numbers[i], "scale", Vector3.ONE, 0.35).from(Vector3.ONE * 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_board.text = "PREGUNTA %d / %d  ·  errores: %d\n%s = ?" % [_index + 1, ROUND, _mistakes, q[0]]


func _on_land(body: Node3D, pad: int) -> void:
	if not body.is_in_group("player"):
		return
	_last = pad
	if _index < 0 or _busy:
		return
	if pad != _right:
		if not _failed.has(pad):
			_failed[pad] = true
			_mistakes += 1
		Sfx.play("error")
		Fx.shake(self, 0.3)
		_rings[pad].material_override = Kit.mat(Game.RED, 3.0)
		Game.notify("¡%s no es la respuesta! Prueba otra plataforma." % _numbers[pad].text, Game.RED)
		body.velocity = (body.global_position - _pads[pad].global_position).normalized() * 6.0 + Vector3(0, 7.0, 0)  # rebote fuera
		var sink := create_tween()
		sink.tween_property(_pads[pad], "position:y", PADS[pad].y - 0.6, 0.15)
		sink.tween_property(_pads[pad], "position:y", PADS[pad].y, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_board.text = "PREGUNTA %d / %d  ·  errores: %d\n%s = ?" % [_index + 1, ROUND, _mistakes, _questions[_index][0]]
		return
	_busy = true
	_rings[pad].material_override = Kit.mat(Game.GREEN, 3.0)
	Sfx.play("success")
	Fx.confetti(self, _pads[pad].position + Vector3(0, 1, 0))
	_board.text = "¡CORRECTO!\n%s = %d" % [_questions[_index][0].replace("\n", " "), _questions[_index][1]]
	_index += 1
	await get_tree().create_timer(1.2).timeout
	_busy = false
	if _index < ROUND:
		_show_question()
	else:
		_finish()


func _finish() -> void:
	var stars := 3 if _mistakes == 0 else 2 if _mistakes <= 2 else 1
	Game.set_stars("math", stars)
	_index = -1
	for i in PADS.size():
		_numbers[i].text = "★"
	_board.text = "¡RONDA COMPLETA!  %s\n%d errores. Usa el atril para repetir" % [UI.stars(stars), _mistakes]
