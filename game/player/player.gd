extends CharacterBody3D
## Explorador de Ciudad STEAM. Port de PlayerController + ThirdPersonCameraFollow + PlayerInteraction:
## movimiento relativo a la cámara con aceleración, coyote time, búfer de salto, salto variable,
## cámara orbital que no atraviesa paredes y elección del interactuable más cercano al que miras.

@export var walk_speed := 5.0
@export var run_speed := 8.5
@export var jump_height := 1.5
@export var gravity := 20.0
@export var footprints := false  # en la Luna el polvo guarda las huellas
@export var mouse_sensitivity := 0.0025  # rad por píxel

const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const ACCEL_GROUND := 60.0
const ACCEL_AIR := 18.0
const PITCH_MIN := -1.2
const PITCH_MAX := 0.35
const CAMERA_HEIGHT := 1.5

@onready var _avatar: Node3D = $Avatar
@onready var _yaw: Node3D = $CamYaw
@onready var _pitch: Node3D = $CamYaw/CamPitch
@onready var _arm: SpringArm3D = $CamYaw/CamPitch/SpringArm3D
@onready var _reach: Area3D = $Reach
@onready var _camera: Camera3D = $CamYaw/CamPitch/SpringArm3D/Camera3D

var _coyote := 0.0
var _jump_buffer := 0.0
var _stride := 0.0
var _zoom := 6.0
var _shake := 0.0
var _clock := 0.0
var _prints: Array[Node3D] = []
var _fall_speed := 0.0
var _spawn: Transform3D
var _nearby: Array[Interactable] = []
var _target: Interactable
var _last_prompt := ""
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D


func _ready() -> void:
	add_to_group("player")
	_spawn = global_transform
	_build_avatar()
	_arm.add_excluded_object(get_rid())
	_yaw.global_position = global_position + Vector3.UP * CAMERA_HEIGHT
	_yaw.rotation.y = rotation.y
	_pitch.rotation.x = -0.35
	_reach.area_entered.connect(_on_reach_entered)
	_reach.area_exited.connect(_on_reach_exited)


func _on_reach_entered(area: Area3D) -> void:
	if area is Interactable:
		_nearby.append(area)


func _on_reach_exited(area: Area3D) -> void:
	if area is Interactable:
		_nearby.erase(area)


## Teletransporta al jugador mirando hacia `yaw` (la cámara queda detrás de él).
func place(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw.rotation.y = yaw
	_avatar.rotation.y = yaw + PI
	_yaw.global_position = pos + Vector3.UP * CAMERA_HEIGHT
	reset_physics_interpolation()


## Sacude la cámara (golpes, explosiones); se apaga sola en ~0,5 s.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## El ratón se lee en _input, antes que la interfaz: ningún Control puede quedarse con el movimiento.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not Game.is_locked() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw.rotation.y -= event.relative.x * mouse_sensitivity
		_pitch.rotation.x = clampf(_pitch.rotation.x - event.relative.y * mouse_sensitivity, PITCH_MIN, PITCH_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_locked():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_zoom - 0.6, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_zoom + 0.6, 10.0)
	elif event.is_action_pressed("interact") and _target:
		Game.notify(_target.interact())


func _process(delta: float) -> void:
	# La cámara se mueve por frame (sin interpolación física) siguiendo la posición interpolada del cuerpo.
	var goal := get_global_transform_interpolated().origin + Vector3.UP * CAMERA_HEIGHT
	_yaw.global_position = _yaw.global_position.lerp(goal, 1.0 - exp(-18.0 * delta))
	_arm.spring_length = lerpf(_arm.spring_length, _zoom, 1.0 - exp(-10.0 * delta))
	_avatar.visible = _arm.get_hit_length() > 1.0  # con una pared detrás, la cámara no se queda mirando el interior del avatar
	_shake = maxf(_shake - delta * 2.0, 0.0)
	_camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.5
	_camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.5


func _physics_process(delta: float) -> void:
	var locked := Game.is_locked()
	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _yaw.global_basis.z * input.y + _yaw.global_basis.x * input.x
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(
		direction * speed, (ACCEL_GROUND if is_on_floor() else ACCEL_AIR) * delta)

	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	_jump_buffer = JUMP_BUFFER if not locked and Input.is_action_just_pressed("jump") else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = sqrt(2.0 * gravity * jump_height)
		_jump_buffer = 0.0
		_coyote = 0.0
		Sfx.play("jump", 0.08)
		Fx.burst(get_parent(), global_position, [Color.WHITE, Color("dfe7f2")], 12, 2.5, 0.2)
		var tween := create_tween()
		tween.tween_property(_avatar, "scale", Vector3(0.75, 1.3, 0.75), 0.08)
		tween.tween_property(_avatar, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	elif not is_on_floor():
		# Caer más rápido que subir y cortar el salto al soltar la tecla da un salto ágil y controlable.
		var released := velocity.y > 0.0 and not Input.is_action_pressed("jump")
		velocity.y -= gravity * (1.6 if velocity.y < 0.0 or released else 1.0) * delta

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var was_on_floor := is_on_floor()
	_fall_speed = -velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor and _fall_speed > 4.0:
		_land(_fall_speed)
	if global_position.y < -15.0:
		place(_spawn.origin, _spawn.basis.get_euler().y)

	_animate(horizontal, delta)
	_pick_target(locked)


func _pick_target(locked: bool) -> void:
	var best: Interactable = null
	var best_score := INF
	if not locked:
		var facing := _avatar.global_basis.z
		for it in _nearby:
			if not is_instance_valid(it) or not it.monitorable:
				continue
			var to := it.global_position - global_position
			to.y = 0.0
			# Más cerca y más de frente gana; así, entre dos objetos juntos, se elige el que miras.
			var score := to.length() - facing.dot(to.normalized()) * 1.5
			if score < best_score:
				best_score = score
				best = it
	if best != _target:
		if is_instance_valid(_target):
			_target.set_focused(false)
		_target = best
		if best:
			best.set_focused(true)
	var text := best.get_prompt() if best else ""
	if text != _last_prompt:
		_last_prompt = text
		Game.set_prompt(text)


func _animate(horizontal: Vector3, delta: float) -> void:
	var speed := horizontal.length()
	_clock += delta
	if speed > 0.3:
		_avatar.rotation.y = lerp_angle(_avatar.rotation.y, atan2(horizontal.x, horizontal.z), 1.0 - exp(-12.0 * delta))
	# Se inclina hacia delante al correr y "respira" parado.
	_avatar.rotation.x = lerpf(_avatar.rotation.x, speed / run_speed * 0.22, 1.0 - exp(-8.0 * delta))
	_avatar.position.y = sin(_clock * 2.5) * 0.03 if speed < 0.3 and is_on_floor() else 0.0
	var swing := 0.0
	if is_on_floor():
		var before := sin(_stride)
		_stride += delta * speed * 2.3
		swing = sin(_stride) * clampf(speed / run_speed, 0.0, 1.0) * 1.2
		if speed > 1.0 and signf(before) != signf(sin(_stride)):
			Sfx.play("step", 0.15)
			if footprints:
				_footprint()
	_arm_l.rotation.x = swing if is_on_floor() else -2.4
	_arm_r.rotation.x = -swing if is_on_floor() else -2.4
	_leg_l.rotation.x = -swing if is_on_floor() else 0.5
	_leg_r.rotation.x = swing if is_on_floor() else -0.3


func _footprint() -> void:
	var side := 0.14 if _prints.size() % 2 == 0 else -0.14
	var foot := Kit.box(get_parent(), Vector3(0.22, 0.012, 0.34), global_position + _avatar.global_basis.x * side + Vector3(0, 0.006, 0),
		Kit.mat(Color("6e7279"), 0.0, 0.0, 1.0), Vector3(0, _avatar.rotation.y, 0))
	_prints.append(foot)
	if _prints.size() > 80:
		_prints.pop_front().queue_free()


## Aterrizaje: aplastón, polvo y sacudida proporcionales a la velocidad de caída.
func _land(fall_speed: float) -> void:
	var k := clampf(fall_speed / 12.0, 0.3, 1.0)
	Sfx.play("land", 0.1)
	Fx.burst(get_parent(), global_position, [Color.WHITE, Color("dfe7f2")], int(10 + 20 * k), 3.0 * k, 0.22)
	shake(0.15 * k)
	var tween := create_tween()
	tween.tween_property(_avatar, "scale", Vector3(1.0 + 0.35 * k, 1.0 - 0.35 * k, 1.0 + 0.35 * k), 0.06)
	tween.tween_property(_avatar, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _build_avatar() -> void:
	var limbs := Kit.robot(_avatar, Color("1f6fff"))
	_arm_l = limbs[0]
	_arm_r = limbs[1]
	_leg_l = limbs[2]
	_leg_r = limbs[3]
