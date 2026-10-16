extends Node3D
## Volt, el robot que patrulla la plaza (port de SteamRobotNPC): recorre sus puntos balanceando brazos
## y piernas, y si el jugador se acerca se detiene, lo mira y saluda. Con cada estrella baila.

@export var waypoints := PackedVector3Array()
@export var speed := 2.5
@export var accent := Color("ff8a1f")

var _index := 0
var _clock := 0.0
var _dance := 0.0  # segundos de baile que quedan
var _limbs: Array[Node3D]
var _player: Node3D


func _ready() -> void:
	_limbs = Kit.robot(self, accent, Game.TEAL)
	_player = get_tree().get_first_node_in_group("player")


## Celebra: brazos arriba alternos, saltitos y vueltas durante `seconds`.
func dance(seconds: float) -> void:
	_dance = maxf(_dance, seconds)


func _process(delta: float) -> void:
	_clock += delta
	if _dance > 0.0:
		_dance -= delta
		var beat := _clock * 9.0
		rotation.y += delta * 4.0
		position.y = absf(sin(beat)) * 0.35
		_limbs[0].rotation = Vector3(-2.6 + sin(beat) * 0.5, 0, -0.3)
		_limbs[1].rotation = Vector3(-2.6 - sin(beat) * 0.5, 0, 0.3)
		_limbs[2].rotation.x = sin(beat) * 0.4
		_limbs[3].rotation.x = -sin(beat) * 0.4
		if _dance <= 0.0:
			position.y = 0.0
			for limb in _limbs:
				limb.rotation = Vector3.ZERO
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
	var swing := 0.0 if near else deg_to_rad(28.0) * sin(_clock * 8.0)  # mismos ±28° a 8 Hz que en Unity
	for i in _limbs.size():
		_limbs[i].rotation.x = swing * (1.0 if i % 3 == 0 else -1.0)
	if near:  # saluda con el brazo derecho levantado
		_limbs[1].rotation = Vector3(-2.7, 0, sin(_clock * 10.0) * 0.45)
	else:
		_limbs[1].rotation.z = 0.0
