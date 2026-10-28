extends Node
## Estado global de Ciudad STEAM: estrellas por reto (guardadas), bloqueo de controles y viajes con fundido.
## Sustituye a PlayerProgression y a los cinco "guardar cursor / desactivar jugador" del juego de Unity.

signal stars_changed(module: String, stars: int)
signal toast(text: String, color: Color)
signal prompt_changed(text: String)
signal bolts_changed(count: int)

const NAVY := Color("09131f")
const TEAL := Color("1fd1c6")
const GOLD := Color("ffb84d")
const TEXT := Color("e0f0f5")
const GREEN := Color("5be37d")
const RED := Color("ff5d5d")

const MOON_MODULES := {
	"moon_jump": {"name": "Salto lunar", "color": Color("2ec4ff")},
	"moon_rover": {"name": "Rover explorador", "color": Color("ff8c1a")},
	"moon_power": {"name": "Energía de la base", "color": Color("ffcc00")},
	"moon_water": {"name": "Purificador", "color": Color("4cd964")},
}
const MODULES := {
	"solar": {"name": "Energía solar", "color": Color("ffb020"), "desc": "Responde y enciende la casa solar"},
	"bridge": {"name": "Ingeniería", "color": Color("ff5a36"), "desc": "Diseña un puente que resista"},
	"robotics": {"name": "Robótica", "color": Color("1fa8ff"), "desc": "Programa al robot hasta la meta"},
	"recycling": {"name": "Reciclaje", "color": Color("3fcf5a"), "desc": "Clasifica cada residuo en su caneca"},
}
const LAB_MODULES := {  # retos extra del STEAM LAB: no son piezas del cohete
	"math": {"name": "Matemáticas", "color": Color("9b6bff"), "desc": "Vuela con el jetpack a la respuesta"},
	"vision": {"name": "Visión IA", "color": Color("ff4f8b"), "desc": "Dibuja con tus pasos para la cámara IA"},
	"ai": {"name": "Desafío IA", "color": Color("00c2a8"), "desc": "Gana a NOVA, la IA del tres en raya"},
}

const BOLTS_TOTAL := 32  # tuercas doradas: 22 en la ciudad y 10 en la Luna (play_test lo comprueba)
const SYMBOLS := preload("res://ui/fonts/Symbols.ttf")  # ★ ☆ ← ↑ → Ω, que Rubik no tiene

var save_path := "user://save.cfg"
var arriving := false  # true mientras el cohete viaja: la escena de destino reproduce el aterrizaje
var stars := {}  # id de módulo -> 0..3; solo sube, así repetir un reto nunca premia dos veces
var bolts := {}  # id de tuerca -> true
var ice := {}  # cristales del salto lunar ya recogidos: índice -> true
var _locks := {}  # quién bloquea -> si necesita el cursor visible
var _fade := ColorRect.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	# Sin esto, los símbolos dependían de las fuentes del sistema (bajo Wine, «●» salía como un cuadro).
	for font: FontFile in [preload("res://ui/fonts/Rubik-Medium.ttf"), preload("res://ui/fonts/Rubik-ExtraBold.ttf")]:
		font.fallbacks = [SYMBOLS]
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		stars = cfg.get_value("progress", "stars", {})
		bolts = cfg.get_value("progress", "bolts", {})
		ice = cfg.get_value("progress", "ice", {})
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade.color = Color(0.85, 0.95, 1.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_apply_lock()
	_handle_debug_args()


func set_stars(module: String, value: int) -> void:
	if value <= int(stars.get(module, 0)):
		return
	stars[module] = value
	_save()
	stars_changed.emit(module, value)


func collect_bolt(id: String) -> void:
	if bolts.has(id):
		return
	bolts[id] = true
	_save()
	bolts_changed.emit(bolts.size())


## Cristal de hielo `index` del salto lunar: cada uno distinto es una ★ de "moon_jump".
func collect_ice(index: int) -> void:
	ice[index] = true
	_save()
	set_stars("moon_jump", ice.size())


## Retos lunares con al menos 1 ★ (hielo encontrado, extraído, derretido y filtrado): con los 4 se vuelve a la Tierra.
func moon_done() -> int:
	return MOON_MODULES.keys().filter(func(id: String) -> bool: return int(stars.get(id, 0)) > 0).size()


## El siguiente paso de la historia (piezas del cohete → la Luna → volver → completarlo todo), como clave de
## lineas.json → "historia": "estrellas", "lanzar", "hielo", "volver" o "todo". Lo usan el panel SIGUIENTE e Ivy.
func story_step(on_moon: bool) -> String:
	if on_moon:
		return "volver" if moon_done() == 4 else "hielo"
	return "estrellas" if total_stars() < 12 else "lanzar" if moon_done() < 4 else "todo"


## Con todas las tuercas, el traje del robot es dorado.
func golden() -> bool:
	return bolts.size() >= BOLTS_TOTAL


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "bolts", bolts)
	cfg.set_value("progress", "ice", ice)
	if cfg.save(save_path) != OK:
		push_error("No se pudo guardar el progreso en " + save_path)


## Estrellas de los retos de la Tierra (por defecto) o de la Luna.
func total_stars(modules := MODULES) -> int:
	var total := 0
	for id: String in modules:
		total += int(stars.get(id, 0))
	return total


func info(id: String) -> Dictionary:
	return MODULES.get(id, LAB_MODULES.get(id, MOON_MODULES.get(id)))


func set_prompt(text: String) -> void:
	prompt_changed.emit(text)


func notify(text: String, color := TEXT) -> void:
	if not text.is_empty():
		toast.emit(text, color)


# --- Bloqueo de controles: cada interfaz hace push_lock(self) al abrirse y pop_lock(self) al cerrarse.

func push_lock(who: Object, show_cursor := true) -> void:
	_locks[who] = show_cursor
	_apply_lock()


func pop_lock(who: Object) -> void:
	if _locks.erase(who):
		_apply_lock()


func is_locked() -> bool:
	return not _locks.is_empty()


func wants_cursor() -> bool:
	return true in _locks.values()


func _apply_lock() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if wants_cursor() else Input.MOUSE_MODE_CAPTURED


## Al arrancar sin foco (p. ej. en la pestaña Game del editor) la captura falla: se repite al recibir el foco.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_apply_lock()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("pause"):  # ESC libera el ratón (B del mando no); un clic lo recupera
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not is_locked():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Funde a blanco, coloca al jugador mirando hacia `yaw` y vuelve a abrir la imagen.
func travel(pos: Vector3, yaw: float) -> void:
	if _locks.has(_fade):
		return
	push_lock(_fade, false)
	await create_tween().tween_property(_fade, "color:a", 1.0, 0.3).finished
	get_tree().get_first_node_in_group("player").place(pos, yaw)
	Sfx.play("whoosh")
	await create_tween().tween_property(_fade, "color:a", 0.0, 0.4).finished
	pop_lock(_fade)


## Viaja a otra escena (la Luna, la Tierra) con el mismo fundido.
func go_to(scene: String) -> void:
	if _locks.has(_fade):
		return
	push_lock(_fade, false)
	await create_tween().tween_property(_fade, "color:a", 1.0, 0.6).finished
	_locks = {_fade: false}  # los bloqueos de la escena anterior desaparecen con ella
	get_tree().change_scene_to_file(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await create_tween().tween_property(_fade, "color:a", 0.0, 0.8).finished
	pop_lock(_fade)


## Teclado y mando: stick izquierdo mover, derecho cámara, A saltar, X usar, Y (o F) Ivy, B/START = ESC, RB o L3 correr.
func _register_inputs() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "interact": [KEY_E], "pause": [KEY_ESCAPE],
		"ivy": [KEY_F], "look_up": [], "look_down": [], "look_left": [], "look_right": [],
	}
	var buttons := {"jump": [JOY_BUTTON_A], "sprint": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_STICK],
		"interact": [JOY_BUTTON_X], "pause": [JOY_BUTTON_B, JOY_BUTTON_START], "ivy": [JOY_BUTTON_Y]}
	var sticks := {
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
	}
	for action: String in keys:
		InputMap.add_action(action, 0.2)  # zona muerta pequeña: el stick inclinado poco mueve despacio
		for key: Key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		for button: JoyButton in buttons.get(action, []):
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
		if sticks.has(action):
			var event := InputEventJoypadMotion.new()
			event.axis = sticks[action][0]
			event.axis_value = sticks[action][1]
			InputMap.action_add_event(action, event)


# Verificación: godot --path game -- --at=x,y,z,yaw_grados --shot=/ruta/captura.png
func _handle_debug_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			_debug_place.call_deferred(Vector3(v[0], v[1], v[2]), deg_to_rad(v[3]))
		elif arg.begins_with("--shot="):
			await get_tree().create_timer(3.0).timeout
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--shot="))
			get_tree().quit()


func _debug_place(pos: Vector3, yaw: float) -> void:
	get_tree().get_first_node_in_group("player").place(pos, yaw)
