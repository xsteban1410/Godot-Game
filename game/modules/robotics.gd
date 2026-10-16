extends Node3D
## Reto Robótica (port de RoboticsGridChallenge). Programa al mini-robot con AVANZAR / IZQUIERDA / DERECHA
## hasta la estrella sin chocar. En Unity el tablero era resoluble por construcción (ruta en escalera);
## aquí un BFS busca la solución más corta, así los tableros son más variados y siempre caben en 15 pasos.
## 3 niveles = 3 estrellas. Se coloca mirando a la plaza (+Z); el tablero crece hacia −Z.
## Con `rover` es el reto lunar "Rover explorador": rocas, suelo gris, un rover y hielo como meta.

const CELL := 1.15
const MAX_PROGRAM := 15
const LEVELS := [[5, 5, 4], [6, 6, 8], [7, 6, 11]]  # ancho, alto, bloques
const ROVER_LEVELS := [[5, 5, 5], [6, 6, 9], [7, 7, 13]]
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]  # rumbo 0 = hacia el fondo
const NAMES := {"F": "AVANZAR", "L": "IZQUIERDA", "R": "DERECHA"}
const BLOCK_COLORS := ["ff4f8b", "ffcc00", "4cd964", "9b6bff", "ff8c1a"]

@export var rover := false

var _module := "robotics"
var _levels: Array = LEVELS
var _goal_name := "la estrella"
var _level := 0
var _size := Vector2i()
var _goal := Vector2i()
var _blocks := {}  # Vector2i -> true
var _program: Array[String] = []
var _cell := Vector2i.ZERO
var _heading := 0
var _running := false
var _board := Node3D.new()
var _robot := Node3D.new()
var _camera := Camera3D.new()
var _previous_camera: Camera3D
var _layer := CanvasLayer.new()
var _chips: HFlowContainer
var _status: Label
var _title: Label


func _ready() -> void:
	if rover:
		_module = "moon_rover"
		_levels = ROVER_LEVELS
		_goal_name = "el hielo"
	_level = mini(int(Game.stars.get(_module, 0)), _levels.size() - 1)
	Kit.stand(self, Vector3(-4.0, 0, 2.0), Game.info(_module).color, "RETO: " + String(Game.info(_module).name).to_upper()).interacted.connect(open)
	Kit.bake(self)
	add_child(_board)
	add_child(_robot)
	var body := Node3D.new()
	body.scale = Vector3.ONE * 0.65
	_robot.add_child(body)
	if rover:
		_build_rover(body)
	else:
		Kit.robot(body, Game.MODULES.robotics.color)
		Kit.blob_shadow(_robot)
	add_child(_camera)
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # se coloca fuera del paso de física
	_build_ui()
	_new_board()


func open() -> void:
	_layer.visible = true
	Game.push_lock(self)
	var center := (_pos(Vector2i.ZERO) + _pos(_goal)) / 2.0
	var aim := center + Vector3(-3.2, 0, 0)  # el panel ocupa la izquierda: el tablero queda a la derecha
	_camera.look_at_from_position(to_global(aim + Vector3(0, 8.0, 4.5)), to_global(aim))
	_previous_camera = get_viewport().get_camera_3d()
	_camera.make_current()
	_say("Llega a %s sin chocar. Programa hasta %d pasos." % [_goal_name, MAX_PROGRAM])


func close() -> void:
	if _running:  # el botón SALIR también: si no, el programa seguía corriendo fuera de cámara
		return
	_layer.visible = false
	Game.pop_lock(self)
	if _previous_camera:
		_previous_camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not _layer.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP: _add("F")
		KEY_LEFT: _add("L")
		KEY_RIGHT: _add("R")
		KEY_BACKSPACE: _remove()
		KEY_ENTER, KEY_KP_ENTER: _run()
		KEY_ESCAPE: close()
		_: return
	get_viewport().set_input_as_handled()


func _add(command: String) -> void:
	if _running or _program.size() >= MAX_PROGRAM:
		return
	_program.append(command)
	Sfx.play("click")
	_refresh_chips()


func _remove() -> void:
	if not _running and not _program.is_empty():
		_program.pop_back()
		Sfx.play("click")
		_refresh_chips()


func _run() -> void:
	if _running or _program.is_empty():
		return
	_running = true
	_reset_robot()
	for i in _program.size():
		_refresh_chips(i)
		var command := _program[i]
		if command == "F":
			var next: Vector2i = _cell + DIRS[_heading]
			if not _free(next):
				await _crash(next)
				return
			_cell = next
			await _hop(_pos(next))
			if _cell == _goal:
				await _win()
				return
		else:
			_heading = (_heading + (3 if command == "L" else 1)) % 4
			await create_tween().tween_property(_robot, "rotation:y", _robot.rotation.y + (PI / 2 if command == "L" else -PI / 2), 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).finished
	Sfx.play("error")
	_say("El programa terminó sin llegar a %s. ¡Ajústalo!" % _goal_name)
	_running = false
	_refresh_chips()


func _hop(to: Vector3) -> void:
	Sfx.play("hop", 0.1)
	var tween := create_tween().set_parallel()
	tween.tween_property(_robot, "position:x", to.x, 0.3)
	tween.tween_property(_robot, "position:z", to.z, 0.3)
	tween.tween_property(_robot, "position:y", to.y + 0.45, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_robot, "position:y", to.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_property(_robot, "scale", Vector3(1.2, 0.8, 1.2), 0.05)
	tween.chain().tween_property(_robot, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tween.finished


## Choque: embiste el obstáculo o el borde, rebota entre chispas y tiembla.
func _crash(target: Vector2i) -> void:
	var from := _robot.position
	var hit := from.lerp(_pos(target), 0.4)
	var tween := create_tween()
	tween.tween_property(_robot, "position", hit, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	Sfx.play("boom")
	Fx.burst(self, hit + Vector3(0, 0.5, 0), [Color("ffcc00"), Color("ff8c1a"), Color.WHITE], 35, 6.0, 0.1)
	Fx.shake(self, 0.35)
	tween = create_tween()
	tween.tween_property(_robot, "position", from, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_robot, "rotation:z", 0.5, 0.1)
	tween.chain().tween_property(_robot, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	var reason := "el borde del tablero" if not _inside(target) else "un bloque"
	_say("¡Choque contra %s en la casilla %d, %d! Corrige el programa." % [reason, target.x + 1, target.y + 1])
	_running = false
	_refresh_chips()


func _win() -> void:
	Sfx.play("success")
	Fx.confetti(self, _pos(_goal) + Vector3(0, 0.5, 0))
	var tween := create_tween().set_parallel()
	tween.tween_property(_robot, "rotation:y", _robot.rotation.y + TAU, 0.6).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_robot, "position:y", _robot.position.y + 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_robot, "position:y", _robot.position.y, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	Game.set_stars(_module, _level + 1)
	if _level < _levels.size() - 1:
		_level += 1
		_say("¡Lo lograste! Nivel %d: un tablero más grande y con más bloques." % (_level + 1))
		_new_board()
	else:
		_say("¡Completaste los 3 niveles! Eres programador de Ciudad STEAM.")
	_running = false


func _new_board() -> void:
	var config: Array = _levels[_level]
	_size = Vector2i(config[0], config[1])
	_goal = _size - Vector2i.ONE
	var cells: Array[Vector2i] = []
	for x in _size.x:
		for y in _size.y:
			if Vector2i(x, y) != Vector2i.ZERO and Vector2i(x, y) != _goal:
				cells.append(Vector2i(x, y))
	for attempt in 200:  # bloques al azar hasta que haya solución dentro del límite
		cells.shuffle()
		_blocks.clear()
		for c in cells.slice(0, config[2]):
			_blocks[c] = true
		var solution := _solve()
		if not solution.is_empty() and solution.size() <= MAX_PROGRAM:
			break

	UI.clear(_board)
	for x in _size.x:
		for y in _size.y:
			var cell := Vector2i(x, y)
			var light := Color("8f939b") if rover else Color("f4f7fb")
			var dark := Color("7a7e86") if rover else Color("dbe9f7")
			var color := Color("ffcc00") if cell == _goal else Color("1fa8ff") if cell == Vector2i.ZERO else light if (x + y) % 2 == 0 else dark
			Kit.box(_board, Vector3(CELL * 0.94, 0.12, CELL * 0.94), _pos(cell) - Vector3(0, 0.06, 0), Kit.mat(color))
			if _blocks.has(cell) and rover:
				Kit.sphere(_board, 0.45, _pos(cell) + Vector3(0, 0.25, 0), Kit.mat(Color("5e626a"), 0.0, 0.0, 0.9), Vector3(1.1, 0.7, 0.95))
			elif _blocks.has(cell):
				var block_color := Color(BLOCK_COLORS[(x * 7 + y * 3) % BLOCK_COLORS.size()])
				Kit.box(_board, Vector3(0.8, 0.7, 0.8), _pos(cell) + Vector3(0, 0.35, 0), Kit.mat(block_color))
				for stud in [Vector3(-0.18, 0, -0.18), Vector3(0.18, 0, -0.18), Vector3(-0.18, 0, 0.18), Vector3(0.18, 0, 0.18)]:
					Kit.cylinder(_board, 0.12, 0.12, 0.1, _pos(cell) + Vector3(0, 0.75, 0) + stud, Kit.mat(block_color), 12)
	var star: Node3D = Kit.label(_board, "★", _pos(_goal) + Vector3(0, 1.0, 0), 160, Game.GOLD, true, 0.006)
	if rover:
		star.queue_free()
		star = Node3D.new()
		star.position = _pos(_goal) + Vector3(0, 1.0, 0)
		_board.add_child(star)
		Kit.cylinder(star, 0.0, 0.25, 0.8, Vector3.ZERO, Kit.mat(Color(0.6, 0.95, 1.0, 0.8), 2.5, 0.0, 0.05), 6)
	var tween := star.create_tween().set_loops()
	tween.tween_property(star, "position:y", 1.3, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(star, "position:y", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	Kit.bake(_board)  # hasta ~100 piezas (casillas, bloques, tetones) en unos pocos draw calls
	_program.clear()
	_reset_robot()
	_refresh_chips()
	if _title:
		_title.text = "%s  ·  NIVEL %d / %d" % [String(Game.info(_module).name).to_upper(), _level + 1, _levels.size()]


## Programa más corto (BFS sobre casilla + rumbo); vacío si no hay camino.
func _solve() -> Array[String]:
	var start := Vector3i(0, 0, 0)
	var previous := {start: null}  # estado -> [estado anterior, orden]
	var queue: Array[Vector3i] = [start]
	while not queue.is_empty():
		var state: Vector3i = queue.pop_front()
		var cell := Vector2i(state.x, state.y)
		if cell == _goal:
			var path: Array[String] = []
			while previous[state] != null:
				path.push_front(previous[state][1])
				state = previous[state][0]
			return path
		for command in ["F", "L", "R"]:
			var next := state
			if command == "F":
				var ahead: Vector2i = cell + DIRS[state.z]
				if not _free(ahead):
					continue
				next = Vector3i(ahead.x, ahead.y, state.z)
			else:
				next.z = (state.z + (3 if command == "L" else 1)) % 4
			if not previous.has(next):
				previous[next] = [state, command]
				queue.append(next)
	return []


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


func _free(cell: Vector2i) -> bool:
	return _inside(cell) and not _blocks.has(cell)


func _pos(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (_size.x - 1) / 2.0) * CELL, 0.22, -1.0 - cell.y * CELL)


func _reset_robot() -> void:
	_cell = Vector2i.ZERO
	_heading = 0
	_robot.position = _pos(_cell)
	_robot.rotation = Vector3(0, PI, 0)  # el modelo mira a +Z; rumbo 0 es −Z


func _say(text: String) -> void:
	_status.text = text


func _refresh_chips(active := -1) -> void:
	UI.clear(_chips)
	for i in _program.size():
		var chip := PanelContainer.new()
		chip.add_child(UI.label("%d %s" % [i + 1, NAMES[_program[i]]], "Caption", Game.GOLD if i == active else Game.TEXT))
		_chips.add_child(chip)
		if i == active:
			UI.pop(chip)
	_chips.add_child(UI.label("%d / %d" % [_program.size(), MAX_PROGRAM], "Caption"))


func _build_ui() -> void:
	_layer.layer = 10
	_layer.visible = false
	add_child(_layer)
	var margin := MarginContainer.new()
	margin.theme = UI.THEME
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)  # el panel mide lo que su contenido: sin hueco vacío
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	_layer.add_child(margin)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	_title = UI.label("", "Caption", Game.info(_module).color)
	column.add_child(_title)
	column.add_child(UI.label("Programa el rover" if rover else "Programa el robot", "Title"))
	_status = UI.label("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_chips = HFlowContainer.new()
	column.add_child(_chips)
	for row in [[["AVANZAR", _add.bind("F")], ["IZQUIERDA", _add.bind("L")], ["DERECHA", _add.bind("R")]],
			[["BORRAR", _remove], ["EJECUTAR", _run], ["SALIR", close]]]:
		var buttons := HBoxContainer.new()
		for spec: Array in row:
			var button := UI.button(spec[0], spec[1])
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buttons.add_child(button)
		column.add_child(buttons)
	column.add_child(UI.label("Teclado: FLECHAS ↑ ← →  ·  RETROCESO borrar  ·  INTRO ejecutar  ·  ESC salir", "Caption"))
	_title.text = "%s  ·  NIVEL %d / %d" % [String(Game.info(_module).name).to_upper(), _level + 1, _levels.size()]


## Rover lunar de juguete mirando hacia +Z: chasis, 6 ruedas, mástil con cámara y panel solar.
func _build_rover(body: Node3D) -> void:
	Kit.box(body, Vector3(1.0, 0.35, 1.3), Vector3(0, 0.55, 0), Kit.mat(Color("f4f7fb")))
	Kit.box(body, Vector3(1.1, 0.06, 0.9), Vector3(0, 0.78, -0.15), Kit.mat(Color("1d3f8f"), 0.3, 0.6, 0.08))
	for x in [-0.6, 0.6]:
		for z in [-0.5, 0.0, 0.5]:
			Kit.cylinder(body, 0.22, 0.22, 0.18, Vector3(x, 0.25, z), Kit.mat(Color("2a2f38")), 16, Vector3(0, 0, PI / 2))
	Kit.cylinder(body, 0.05, 0.05, 0.7, Vector3(0, 1.1, 0.45), Kit.mat(Color("cfd8e6")), 8)
	Kit.box(body, Vector3(0.35, 0.22, 0.25), Vector3(0, 1.5, 0.45), Kit.mat(Game.info("moon_rover").color))
	for side in [-0.08, 0.08]:
		Kit.sphere(body, 0.05, Vector3(side, 1.52, 0.58), Kit.mat(Game.TEAL, 4.0))
