extends Node3D
## Volt, el robot que patrulla la plaza (port de SteamRobotNPC): recorre sus puntos balanceando brazos
## y piernas, y si el jugador se acerca se detiene, lo mira y saluda. Con cada estrella baila.

@export var waypoints := PackedVector3Array()
@export var speed := 2.5
@export var accent := Color("ff8a1f")

var _index := 0
var _dance := 0.0  # segundos de baile que quedan
var _robot: RobotModel
var _player: Node3D


func _ready() -> void:
	_robot = RobotModel.create(self, accent, Game.INK_2)
	_player = get_tree().get_first_node_in_group("player")


## Celebra bailando y girando durante `seconds`.
func dance(seconds: float) -> void:
	_dance = maxf(_dance, seconds)


func _process(delta: float) -> void:
	if _dance > 0.0:
		_dance -= delta
		rotation.y += delta * 2.5
		_robot.play("Dance")
		return
	var near := position.distance_to(_player.position) < 3.5
	var target := _player.position if near else waypoints[_index]
	if not near:
		position = position.move_toward(target, speed * delta)
		if position.distance_to(target) < 0.05:
			_index = (_index + 1) % waypoints.size()
	var to := target - position
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-8.0 * delta))
	if near:
		_robot.play("Wave", 0.2)  # se para, te mira y saluda
	else:
		_robot.play("Walk", 0.2, speed / 5.0 * 1.3)
