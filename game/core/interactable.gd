class_name Interactable
extends Area3D
## Algo que el jugador activa con E estando cerca: `prompt` es el texto del aviso y la señal
## `interacted` lo que pasa al pulsar E.

signal interacted

const LAYER := 2  # capa de física 2: solo la ve el detector del jugador

@export var prompt := "INTERACTUAR"
@export var marker_height := 2.4

var _marker: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 0
	monitoring = false
	_marker = Kit.cylinder(self, 0.2, 0.0, 0.34, Vector3(0, marker_height, 0), Kit.mat(Game.ACCENT, 3.0), 4)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false


func interact() -> void:
	interacted.emit()


func set_focused(focused: bool) -> void:
	_marker.visible = focused


## Se usa para retirar el objeto de la interacción sin borrarlo (p. ej. una pieza ya recogida).
func set_enabled(enabled: bool) -> void:
	monitorable = enabled
	if not enabled:
		_marker.visible = false


func _process(delta: float) -> void:
	if _marker.visible:
		_time += delta
		_marker.position.y = marker_height + sin(_time * 4.0) * 0.08
		_marker.rotate_y(delta * 2.5)
