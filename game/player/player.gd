extends CharacterBody3D
## Explorador de Ciudad STEAM. Port de PlayerController + ThirdPersonCameraFollow + PlayerInteraction:
## movimiento relativo a la cámara con aceleración, coyote time, búfer de salto, salto variable,
## jetpack (volver a pulsar ESPACIO en el aire), cámara orbital que no atraviesa paredes y elección del
## interactuable más cercano al que miras.

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
const JET_FUEL := 1.3  # segundos de empuje; se recarga al pisar suelo
const JET_LIFT := 5.5  # velocidad de subida con el jetpack (m/s)
const MAX_PRINTS := 80
const PAD_TURN := 3.0  # giro de la cámara con el stick derecho (rad/s)
const BLUE := Color("a5c5ff")
const GOLD := Color("ffb627")  # traje con todas las tuercas doradas

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
var _prints: MultiMeshInstance3D  # huellas: una sola malla instanciada, un draw call para todas
var _print_count := 0
var _fuel := JET_FUEL
var _jetting := false
var _jet_sound := 0.0
var _robot: RobotModel
var _landing := 0.0  # segundos de la animación de aterrizaje que quedan
var _flames: Array[Node3D] = []
var _smoke := CPUParticles3D.new()
var _fall_speed := 0.0
var _spawn: Transform3D
var _nearby: Array[Interactable] = []
var _target: Interactable
var _last_prompt := ""
var _golden := false


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
	Game.bolts_changed.connect(func(_count: int) -> void: if Game.golden() and not _golden: _redress())


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
	_jetting = false
	_yaw.rotation.y = yaw
	_avatar.rotation.y = yaw + PI
	_yaw.global_position = pos + Vector3.UP * CAMERA_HEIGHT
	reset_physics_interpolation()


## Color del traje: azul, o dorado con todas las tuercas.
func accent() -> Color:
	return GOLD if _golden else BLUE


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
	elif event.is_action_pressed("interact") and is_instance_valid(_target):
		_target.interact()


func _process(delta: float) -> void:
	if not Game.is_locked():
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		_yaw.rotation.y -= look.x * PAD_TURN * delta
		_pitch.rotation.x = clampf(_pitch.rotation.x - look.y * PAD_TURN * delta, PITCH_MIN, PITCH_MAX)
	# La cámara se mueve por frame (sin interpolación física) siguiendo la posición interpolada del cuerpo.
	var goal := get_global_transform_interpolated().origin + Vector3.UP * CAMERA_HEIGHT
	_yaw.global_position = _yaw.global_position.lerp(goal, 1.0 - exp(-18.0 * delta))
	_arm.spring_length = lerpf(_arm.spring_length, _zoom, 1.0 - exp(-10.0 * delta))
	_avatar.visible = _arm.get_hit_length() > 1.0  # con una pared detrás, la cámara no se queda mirando el interior del avatar
	_shake = maxf(_shake - delta * 2.0, 0.0)
	_camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.5
	_camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.5
	for flame in _flames:  # las llamas parpadean cada fotograma
		flame.visible = _jetting
		flame.scale = Vector3(1, randf_range(0.7, 1.3), 1)
	_smoke.emitting = _jetting
	_robot.set_fuel(_fuel / JET_FUEL, _fuel < JET_FUEL * 0.3)


func _physics_process(delta: float) -> void:
	var locked := Game.is_locked()
	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _yaw.global_basis.z * input.y + _yaw.global_basis.x * input.x
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR * (1.8 if _jetting else 1.0)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, accel * delta)

	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	var pressed := not locked and Input.is_action_just_pressed("jump")
	_jump_buffer = JUMP_BUFFER if pressed else _jump_buffer - delta
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
		# En el aire, volver a pulsar ESPACIO enciende el jetpack mientras se mantenga y quede combustible.
		_jetting = (_jetting or pressed) and _fuel > 0.0 and not locked and Input.is_action_pressed("jump")
		if _jetting:  # (el búfer sigue: pulsar justo antes de aterrizar salta al tocar el suelo)
			_fuel -= delta
			velocity.y = move_toward(velocity.y, JET_LIFT, maxf(gravity, 12.0) * 2.5 * delta)
			_jet_sound -= delta
			if _jet_sound <= 0.0:
				Sfx.play("jet", 0.1)
				_jet_sound = 0.11
		else:
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
	if is_on_floor():
		_jetting = false
		_fuel = minf(_fuel + delta * 1.5, JET_FUEL)
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
	var text := best.prompt if best else ""
	if text != _last_prompt:
		_last_prompt = text
		Game.set_prompt(text)


func _animate(horizontal: Vector3, delta: float) -> void:
	var speed := horizontal.length()
	var lean := 0.0
	if speed > 0.3:
		var turn := angle_difference(_avatar.rotation.y, atan2(horizontal.x, horizontal.z))
		_avatar.rotation.y += turn * (1.0 - exp(-12.0 * delta))
		lean = -clampf(turn, -0.8, 0.8) * 0.3 * speed / run_speed  # se inclina hacia el lado al que gira
	_avatar.rotation.z = lerpf(_avatar.rotation.z, lean, 1.0 - exp(-8.0 * delta))
	if is_on_floor():
		var before := sin(_stride)
		_stride += delta * speed * 2.3
		if speed > 1.0 and signf(before) != signf(sin(_stride)):
			Sfx.play("step", 0.15)
			if footprints:
				_footprint()
	# Animación según el estado; andar y correr van a la velocidad real para que los pies no patinen.
	_landing -= delta
	if _jetting:
		_robot.play("Fly")
	elif not is_on_floor():
		_robot.play("Jump" if velocity.y > 0.0 else "Fall", 0.12)
	elif speed > walk_speed + 0.5:
		_robot.play("Run", 0.15, speed / run_speed * 1.15)
	elif speed > 0.3:
		_robot.play("Walk", 0.15, speed / walk_speed * 1.3)
	elif _landing > 0.0:
		_robot.play("Land", 0.05)
	else:
		_robot.play("Idle", 0.25)


func _footprint() -> void:
	if not _prints:
		var foot := BoxMesh.new()
		foot.size = Vector3(0.22, 0.012, 0.34)
		_prints = MultiMeshInstance3D.new()
		_prints.multimesh = MultiMesh.new()
		_prints.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		_prints.multimesh.mesh = foot
		_prints.multimesh.instance_count = MAX_PRINTS
		_prints.material_override = Kit.mat(Color("6e7279"), 0.0, 0.0, 1.0)
		_prints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(_prints)
	var steps := _prints.multimesh
	var side := 0.14 if _print_count % 2 == 0 else -0.14
	steps.set_instance_transform(_print_count % MAX_PRINTS, Transform3D(Basis(Vector3.UP, _avatar.rotation.y),
		global_position + _avatar.global_basis.x * side + Vector3(0, 0.006, 0)))
	_print_count += 1
	steps.visible_instance_count = mini(_print_count, MAX_PRINTS)  # las más viejas se reutilizan


## Aterrizaje: aplastón, polvo y sacudida proporcionales a la velocidad de caída.
func _land(fall_speed: float) -> void:
	var k := clampf(fall_speed / 12.0, 0.3, 1.0)
	Sfx.play("land", 0.1)
	_landing = 0.3
	Fx.burst(get_parent(), global_position, [Color.WHITE, Color("dfe7f2")], int(10 + 20 * k), 3.0 * k, 0.22)
	shake(0.15 * k)
	var tween := create_tween()
	tween.tween_property(_avatar, "scale", Vector3(1.0 + 0.35 * k, 1.0 - 0.35 * k, 1.0 + 0.35 * k), 0.06)
	tween.tween_property(_avatar, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Robot del jugador con su jetpack: dos llamas que salen de las toberas, humo y la franja de combustible.
func _build_avatar() -> void:
	_golden = Game.golden()
	_robot = RobotModel.create(_avatar, accent(), Color("aee3ff"), true)
	for nozzle in _robot.nozzles:
		var flame := Node3D.new()  # pivote en la tobera: la llama se estira hacia abajo
		flame.visible = false
		nozzle.add_child(flame)
		Kit.cylinder(flame, 0.055, 0.0, 0.36, Vector3(0, -0.18, 0), Kit.mat(Color("ffe1b5"), 4.0), 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.cylinder(flame, 0.03, 0.0, 0.2, Vector3(0, -0.1, 0), Kit.mat(Color("fff6c8"), 6.0), 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flames.append(flame)
	var puff := SphereMesh.new()
	puff.radius = 0.09
	puff.height = 0.18
	puff.radial_segments = 8
	puff.rings = 4
	_smoke.mesh = puff
	_smoke.material_override = Kit.mat(Color("f4f7fb"), 0.4, 0.0, 0.6)
	_smoke.amount = 24
	_smoke.lifetime = 0.5
	_smoke.emitting = false
	_smoke.local_coords = false
	_smoke.position = (_robot.nozzles[0].position + _robot.nozzles[1].position) / 2.0 + Vector3(0, -0.2, 0)
	_smoke.direction = Vector3.DOWN
	_smoke.spread = 18.0
	_smoke.initial_velocity_min = 3.0
	_smoke.initial_velocity_max = 5.0
	_smoke.gravity = Vector3.ZERO
	_smoke.damping_min = 6.0
	_smoke.damping_max = 8.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(0.4, 1.4))
	grow.add_point(Vector2(1.0, 0.0))
	_smoke.scale_amount_curve = grow
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_robot.nozzles[0].get_parent().add_child(_smoke)


## Cambia el traje (al conseguir la última tuerca) reconstruyendo el robot con su jetpack.
func _redress() -> void:
	for child in _avatar.get_children():
		_avatar.remove_child(child)
		child.queue_free()
	_flames.clear()
	_smoke = CPUParticles3D.new()
	_build_avatar()
	if find_children("*", "Decal", false, false):  # con sombra redonda, el robot no debe recibirla (Kit.blob_shadow)
		for mesh: GeometryInstance3D in _avatar.find_children("*", "GeometryInstance3D", true, false):
			mesh.layers = 2
	Fx.confetti(get_parent(), global_position + Vector3.UP)
