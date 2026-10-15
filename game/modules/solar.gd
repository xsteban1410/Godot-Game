extends Node3D
## Reto Energía solar (port de MissionManager + MissionUI + MissionData, cuyo asset con las preguntas no vino).
## 5 preguntas al azar de 12, respuestas barajadas. Fallar cuesta puntos (100/50/25/0) en vez de ser gratis,
## cada acierto explica el porqué y enciende una ventana de la casa solar. Se coloca mirando a la plaza (+Z).

const ROUND := 5
const POINTS := [100, 50, 25, 0]
# [pregunta, respuestas (la primera es la correcta), explicación]
const BANK := [
	["¿Qué dispositivo convierte la luz del Sol en electricidad?", ["Panel fotovoltaico", "Turbina eólica", "Batería", "Transformador"],
		"Sus celdas fotovoltaicas convierten la luz directamente en electricidad."],
	["¿Qué tipo de corriente produce un panel solar?", ["Continua (CC)", "Alterna (CA)", "Trifásica", "Estática"],
		"El panel da corriente continua: los electrones fluyen en un solo sentido."],
	["¿Qué equipo convierte la CC del panel en la CA de los enchufes?", ["Inversor", "Fusible", "Diodo", "Medidor"],
		"El inversor transforma la corriente continua en alterna."],
	["En una casa solar sin red, ¿para qué sirve la batería?", ["Guardar energía para la noche", "Enfriar el panel", "Subir el voltaje", "Medir el consumo"],
		"Almacena la energía que sobra de día para usarla cuando no hay Sol."],
	["¿En qué unidad se mide la potencia eléctrica?", ["Vatio (W)", "Voltio (V)", "Amperio (A)", "Ohmio (Ω)"],
		"La potencia va en vatios; el voltio mide tensión y el amperio, corriente."],
	["Un panel da 18 V y 5 A. Con P = V × I, ¿qué potencia entrega?", ["90 W", "23 W", "13 W", "3,6 W"],
		"P = V × I = 18 V × 5 A = 90 W."],
	["¿Qué material es el más usado en las celdas solares?", ["Silicio", "Cobre", "Plomo", "Aluminio"],
		"El silicio es un semiconductor abundante: la base de casi todas las celdas."],
	["Un panel de 100 W recibe 5 horas de Sol pleno. ¿Cuánta energía produce?", ["500 Wh", "105 Wh", "50 Wh", "20 Wh"],
		"Energía = potencia × tiempo = 100 W × 5 h = 500 Wh."],
	["Dos paneles de 12 V conectados en serie dan…", ["24 V", "12 V", "6 V", "144 V"],
		"En serie los voltajes se suman: 12 V + 12 V = 24 V."],
	["¿Qué reduce más la producción de un panel?", ["Una sombra sobre sus celdas", "El frío", "El viento", "Que sea de día"],
		"Una sombra en pocas celdas frena la corriente de todo el panel."],
	["La energía solar es una fuente…", ["Renovable", "Fósil", "No renovable", "Nuclear"],
		"El Sol vuelve a salir cada día: no se agota al usarlo."],
	["En Colombia, cerca del ecuador, ¿cómo conviene instalar un panel fijo?", ["Casi horizontal, algo inclinado al sur", "Vertical hacia el norte", "Mirando al este", "Bocabajo"],
		"El Sol pasa casi por encima; una leve inclinación capta luz y deja escurrir la lluvia."],
]

var _questions: Array = []
var _index := 0
var _score := 0
var _misses := 0
var _answers: Array = []  # respuestas de la pregunta actual, barajadas
var _windows: Array[MeshInstance3D] = []
var _layer := CanvasLayer.new()
var _content: CenterContainer
var _grid: GridContainer
var _feedback: Label


func _ready() -> void:
	var white := Kit.mat(Color("f4f7fb"))
	Kit.box(self, Vector3(5, 3, 4), Vector3(0, 1.5, -5), white)
	Kit.collider(self, Vector3(5, 3, 4), Vector3(0, 1.5, -5))
	var roof := PrismMesh.new()
	roof.size = Vector3(5.8, 1.6, 4.6)
	Kit.part(self, roof, Vector3(0, 3.8, -5), Kit.mat(Color("ff8c1a")))
	Kit.box(self, Vector3(1.0, 1.7, 0.1), Vector3(0, 0.85, -2.98), Kit.mat(Color("1f6fff")))
	for p in [Vector3(-1.5, 2.2, -2.95), Vector3(0, 2.2, -2.95), Vector3(1.5, 2.2, -2.95), Vector3(-1.5, 1.0, -2.95), Vector3(1.5, 1.0, -2.95)]:
		_windows.append(Kit.box(self, Vector3(0.8, 0.7, 0.1), p, Kit.mat(Color("2a3442"))))
	for x in [-4.6, 4.6]:
		Kit.cylinder(self, 0.08, 0.08, 1.4, Vector3(x, 0.7, -4), Kit.mat(Color("cfd8e6"), 0.0, 0.7), 8)
		Kit.box(self, Vector3(2.6, 0.1, 1.6), Vector3(x, 1.45, -4), Kit.mat(Color("1d3f8f"), 0.3, 0.6, 0.08), Vector3(0.5, 0, 0))
	Kit.cylinder(self, 0.7, 0.9, 1.1, Vector3(0, 0.55, 0), Kit.mat(Game.MODULES.solar.color), 32)
	Kit.collider(self, Vector3(1.4, 1.1, 1.4), Vector3(0, 0.55, 0))
	Kit.interactable(self, "RETO: ENERGÍA SOLAR", Vector3(0, 1, 0), 2.2).interacted.connect(start)

	_layer.layer = 10
	add_child(_layer)
	_content = UI.overlay(_layer, 0.65)
	_layer.visible = false


func start() -> void:
	_questions = BANK.duplicate()
	_questions.shuffle()
	_questions.resize(ROUND)
	_index = 0
	_score = 0
	for w in _windows:
		w.material_override = Kit.mat(Color("2a3442"))
	_layer.visible = true
	Game.push_lock(self)
	_show_question()


func close() -> void:
	_layer.visible = false
	Game.pop_lock(self)


func _unhandled_input(event: InputEvent) -> void:
	if _layer.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _show_question() -> void:
	_misses = 0
	var q: Array = _questions[_index]
	_answers = q[1].duplicate()
	_answers.shuffle()
	var column := _page("PREGUNTA %d / %d   ·   %d PUNTOS" % [_index + 1, ROUND, _score], q[0])
	_grid = GridContainer.new()
	_grid.columns = 2
	column.add_child(_grid)
	for i in _answers.size():
		var button := UI.button(_answers[i], _answer.bind(i))
		button.custom_minimum_size = Vector2(500, 70)
		_grid.add_child(button)
	_feedback = UI.label("", "", Game.RED)
	column.add_child(_feedback)
	UI.focus(_grid.get_child(0))


func _answer(choice: int) -> void:
	var q: Array = _questions[_index]
	if _answers[choice] != q[1][0]:
		_misses += 1
		_grid.get_child(choice).disabled = true
		Sfx.play("error")
		_feedback.text = "Incorrecto. Intenta otra vez: ahora vale %d puntos." % POINTS[mini(_misses, POINTS.size() - 1)]
		Fx.shake(self, 0.25)
		return
	var points: int = POINTS[mini(_misses, POINTS.size() - 1)]
	_score += points
	var window := _windows[_index]
	window.material_override = Kit.mat(Color("ffd23f"), 4.0)
	window.scale = Vector3.ONE * 1.8
	create_tween().tween_property(window, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Fx.confetti(self, window.position + Vector3(0, 0, 0.5))
	Sfx.play("success")
	var column := _page("¡CORRECTO!  +%d PUNTOS" % points, q[2])
	_index += 1
	var next := UI.button("SIGUIENTE" if _index < ROUND else "VER RESULTADO", _show_question if _index < ROUND else _finish)
	column.add_child(next)
	UI.focus(next)


func _finish() -> void:
	var stars := 3 if _score == ROUND * POINTS[0] else 2 if _score >= ROUND * POINTS[0] * 0.7 else 1
	Game.set_stars("solar", stars)
	for w in _windows:
		Fx.confetti(self, w.position + Vector3(0, 1, 0.5))
	var column := _page("¡CASA ENCENDIDA!  %s" % UI.stars(stars),
		"%d / %d puntos. %s" % [_score, ROUND * POINTS[0], "¡Perfecto, sin fallos!" if stars == 3 else "Sin fallos consigues 3 estrellas."])
	var done := UI.button("CERRAR", close)
	column.add_child(done)
	UI.focus(done)


func _page(title: String, text: String) -> VBoxContainer:
	UI.clear(_content)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 1060
	_content.add_child(panel)
	UI.pop.call_deferred(panel)  # cuando ya tiene contenido: así crece desde su centro
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	column.add_child(UI.label("ENERGÍA SOLAR  ·  " + title, "Caption", Game.MODULES.solar.color))
	var body := UI.label(text, "Title")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	return column
