extends Node
## Estado global de Ciudad STEAM: estrellas por reto (guardadas), bloqueo de controles y viajes con fundido.
## Sustituye a PlayerProgression y a los cinco "guardar cursor / desactivar jugador" del juego de Unity.

signal stars_changed(module: String, stars: int)
signal toast(text: String, color: Color)
signal prompt_changed(text: String)

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
	"recycling": {"name": "Reciclaje", "color": Color("3fcf5a"), "desc": "Clasifica los residuos a tiempo"},
}

var save_path := "user://save.cfg"
var arriving := false  # true mientras el cohete viaja: la escena de destino reproduce el aterrizaje
var stars := {}  # id de módulo -> 0..3; solo sube, así repetir un reto nunca premia dos veces
var _locks := {}  # quién bloquea -> si necesita el cursor visible
var _fade := ColorRect.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		stars = cfg.get_value("progress", "stars", {})
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
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "stars", stars)
	if cfg.save(save_path) != OK:
		push_error("No se pudo guardar el progreso en " + save_path)
	stars_changed.emit(module, value)


## Estrellas de los retos de la Tierra (por defecto) o de la Luna.
func total_stars(modules := MODULES) -> int:
	var total := 0
	for id: String in modules:
		total += int(stars.get(id, 0))
	return total


func info(id: String) -> Dictionary:
	return MODULES[id] if MODULES.has(id) else MOON_MODULES[id]


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
	if event.is_action_pressed("pause"):  # ESC libera el ratón; un clic lo recupera
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
	push_lock(_fade, false)
	await create_tween().tween_property(_fade, "color:a", 1.0, 0.6).finished
	_locks = {_fade: false}  # los bloqueos de la escena anterior desaparecen con ella
	get_tree().change_scene_to_file(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await create_tween().tween_property(_fade, "color:a", 0.0, 0.8).finished
	pop_lock(_fade)


func _register_inputs() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "interact": [KEY_E], "pause": [KEY_ESCAPE],
	}
	for action: String in map:
		InputMap.add_action(action)
		for key: Key in map[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
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
