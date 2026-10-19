class_name Ivy
extends Node3D
## Ivy, la robot guía: baja en su nube la primera vez que pisas cada zona (una vez por sesión), te la explica
## con voz y, con F (Y en el mando), abre un panel con las preguntas de lo que tienes cerca. Todo lo que dice está
## en `ivy/lineas.json` (editable; ver `ivy/GUIA.md`). Las voces son .ogg grabados antes con Piper
## (`tools/voice.gd`) y nombrados por el hash de la frase: el juego no necesita nada instalado, suena igual en
## Windows y Linux, y una frase cambiada sin volver a grabar se lee en pantalla sin voz (nunca con el audio viejo).
## Las escenas registran sus zonas con `zone()`; fuera de todas rige `home`, cuyo saludo va siempre primero.

const LINES := "res://ivy/lineas.json"
const VOICE := "res://ivy/voz/%s.ogg"

static var _data := {}  # lineas.json, leído una vez
static var _greeted := {}  # zonas ya presentadas en esta sesión (sobrevive a los viajes Tierra–Luna)

var home := "city"
var _zones: Array = []  # [id, centro, radio]
var _player: Node3D
var _robot: RobotModel
var _voice := AudioStreamPlayer.new()
var _bubble: PanelContainer
var _column: VBoxContainer
var _text: Label
var _menu: VBoxContainer  # preguntas del panel F; null con el panel cerrado
var _shown := false
var _tween: Tween
var _quiet := 0.0  # segundos que le quedan hablando (negativo: los que lleva callada)
var _gesture := 0.0  # segundos de saludo o asentir antes de volver a reposo
var _wait := 1.5  # no saluda nada más empezar la escena
var _time := 0.0


## Las frases de lineas.json. Si alguien lo rompe al editarlo, el juego sigue y Ivy se queda callada.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("%s no es un JSON válido: Ivy se queda callada (revisa comas y comillas)" % LINES)
			_data = {"roto": true}
	return _data


## Lo que de verdad lee la voz: cada palabra de "pronunciacion" cambiada por cómo suena.
static func spoken(text: String) -> String:
	var words: Dictionary = data().get("pronunciacion", {})
	for word: String in words:
		text = text.replace(word, words[word])
	return text


## El audio de una frase: su nombre es el hash de lo que se pronuncia.
static func voice_path(text: String) -> String:
	return VOICE % spoken(text).md5_text()


## Todas las frases con voz: saludos, respuestas, historia y la de ayuda (los botones solo se leen).
static func all_lines() -> Array[String]:
	var lines: Array[String] = [str(data().get("general", {}).get("ayuda", ""))]
	for text: Variant in data().get("historia", {}).values():
		lines.append(str(text))
	for area: Dictionary in data().get("zonas", {}).values():
		lines.append(str(area.get("saludo", "")))
		for q: Dictionary in area.get("preguntas", []):
			lines.append(str(q.get("respuesta", "")))
	return lines.filter(func(t: String) -> bool: return not t.is_empty())


func _ready() -> void:
	visible = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # se mueve por fotograma, no en el paso de física
	_player = get_tree().get_first_node_in_group("player")
	var cloud := Node3D.new()
	add_child(cloud)
	var puff := Kit.mat(Color("f4f7fb"), 0.3, 0.0, 0.6)
	for p: Vector4 in [Vector4(0, 0, 0, 0.55), Vector4(0.5, -0.05, 0.1, 0.42), Vector4(-0.5, -0.05, -0.05, 0.45),
			Vector4(0.15, -0.1, 0.45, 0.38), Vector4(-0.1, -0.08, -0.45, 0.4)]:
		Kit.sphere(cloud, p.w, Vector3(p.x, p.y, p.z), puff, Vector3(1, 0.6, 1), 16)
	Kit.bake(cloud)
	var body := Node3D.new()
	body.position.y = 0.25
	body.scale = Vector3.ONE * 0.5
	add_child(body)
	_robot = RobotModel.create(body, Color("f4f7fb"), Color("35b8ff"))
	Kit.label(self, "IVY", Vector3(0, 1.45, 0), 26, Color("9fe8ff"))
	add_child(_voice)
	_build_bubble()


## Zona circular `id` en el suelo (su saludo y sus preguntas están en lineas.json, en "zonas" → id).
func zone(id: String, center: Vector3, radius: float) -> void:
	_zones.append([id, center, radius])


## La zona donde está el jugador (`home` si no está en ninguna).
func current() -> String:
	var p := _player.global_position
	for z: Array in _zones:
		if Vector2(p.x - z[1].x, p.z - z[1].z).length() < z[2]:
			return z[0]
	return home


func _zone(id: String) -> Dictionary:
	return data().get("zonas", {}).get(id, {})


func _process(delta: float) -> void:
	_wait -= delta
	_quiet -= delta
	var busy := Game.is_locked() and not _menu  # un reto, un viaje o una cinemática: se calla y se va
	if busy:
		_leave()
	var id := current() if _greeted.has(home) else home  # la bienvenida (o la llegada a la Luna) primero
	if not busy and _wait <= 0.0 and _quiet <= 0.0 and not _greeted.has(id):
		_greeted[id] = true
		say(str(_zone(id).get("saludo", "")), true)
	elif _shown and _quiet < -1.5 and not _menu:
		_leave()
	if _gesture > 0.0:
		_gesture -= delta
		if _gesture <= 0.0:
			_robot.play("Idle", 0.3)
	if _shown:
		_follow(delta)


## Dice `text`: lo escribe en su bocadillo y lo reproduce si está grabado; `greet`: saluda con la mano.
func say(text: String, greet := false) -> void:
	if text.is_empty():
		return
	_arrive()
	_text.text = text
	_bubble.visible = true
	var path := voice_path(text)
	_quiet = text.length() / 14.0  # sin audio, lo que se tarda en leerla
	_voice.stop()
	if ResourceLoader.exists(path):
		_voice.stream = load(path)
		_voice.play()
		_quiet = _voice.stream.get_length()
	_robot.play("Wave" if greet else "Yes", 0.2)
	_gesture = 1.8


func _unhandled_input(event: InputEvent) -> void:
	if _menu and (event.is_action_pressed("pause") or event.is_action_pressed("ivy")):
		get_viewport().set_input_as_handled()
		_close()
	elif event.is_action_pressed("ivy") and not Game.is_locked():
		get_viewport().set_input_as_handled()
		open()


## Panel con las preguntas de la zona actual (F o Y en el mando), «¿qué hago después?» y cerrar.
func open() -> void:
	var general: Dictionary = data().get("general", {})
	_menu = VBoxContainer.new()
	_column.add_child(_menu)
	for q: Dictionary in _zone(current()).get("preguntas", []):
		_menu.add_child(UI.button(str(q.get("pregunta", "?")), say.bind(str(q.get("respuesta", "")))))
	_menu.add_child(UI.button(str(general.get("boton_despues", "¿Qué hago después?")), func() -> void: say(next_step())))
	_menu.add_child(UI.button(str(general.get("boton_cerrar", "Cerrar")), _close))
	Game.push_lock(self)
	_arrive()
	_bubble.visible = true  # aunque "ayuda" esté vacía o lineas.json roto: el panel siempre se ve
	say(str(general.get("ayuda", "")))
	UI.focus(_menu.get_child(0))


func _close() -> void:
	_menu.queue_free()  # (no free(): el botón que lo cierra aún está emitiendo su señal)
	_menu = null
	Game.pop_lock(self)


## «¿Qué hago después?»: el siguiente paso de la historia (lineas.json → "historia"), como el panel SIGUIENTE.
func next_step() -> String:
	return str(data().get("historia", {}).get(Game.story_step(home == "moon"), ""))


## Baja del cielo junto al jugador.
func _arrive() -> void:
	if _shown:
		return
	_shown = true
	if _tween:
		_tween.kill()
	visible = true
	global_position = _spot() + Vector3(0, 10, 0)
	Sfx.play("whoosh")


## Se calla y sube hasta perderse en el cielo.
func _leave() -> void:
	if not _shown:
		return
	_shown = false
	_voice.stop()
	_bubble.visible = false
	_tween = create_tween()
	_tween.tween_property(self, "global_position", global_position + Vector3(0, 10, 0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)


## A la derecha del jugador según la cámara, a la altura de su cabeza y flotando.
func _spot() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera else Vector3.RIGHT
	return _player.get_global_transform_interpolated().origin + Vector3(right.x, 0.0, right.z).normalized() * 1.7 + Vector3(0, 1.6 + sin(_time * 2.0) * 0.12, 0)


func _follow(delta: float) -> void:
	_time += delta
	global_position = global_position.lerp(_spot(), 1.0 - exp(-4.0 * delta))
	var camera := get_viewport().get_camera_3d()
	if camera:  # el robot mira hacia +Z: de frente a la cámara
		var to := camera.global_position - global_position
		rotation.y = atan2(to.x, to.z)


## Bocadillo abajo a la izquierda, encima de la línea de controles; con el panel abierto lleva las preguntas.
func _build_bubble() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20  # encima de los paneles de los retos (10), debajo de las celebraciones (50)
	add_child(layer)
	var margin := MarginContainer.new()
	margin.theme = UI.THEME
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_bottom", 64)
	layer.add_child(margin)
	_bubble = PanelContainer.new()
	_bubble.visible = false
	margin.add_child(_bubble)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 10)
	_bubble.add_child(_column)
	_column.add_child(UI.label("IVY  ·  ROBOT GUÍA", "Caption", Game.TEAL))
	_text = UI.label("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 600
	_column.add_child(_text)
	UI.ignore_mouse(margin)  # el bocadillo nunca se traga el ratón; los botones del panel sí lo reciben
