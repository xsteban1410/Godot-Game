extends SceneTree
## Demo automática para exponer: abre el juego a pantalla completa y lo juega solo, a ritmo de presentación (~7 min):
## paseo (correr, saltar, jetpack), STEAM LAB, los retos de la ciudad, una tuerca, el cohete, la Luna y la vuelta.
##   godot --path game --script res://tools/demo.gd
##   godot --headless --path game --script res://tools/demo.gd -- --rapido   (comprobarla en ~2 min, sin ventana)
## Usa su propia partida (user://demo.cfg, se borra al empezar): la partida real no se toca. Al acabar, sigue abierto.

var _game: Node
var _speed := 1.0  # factor de las esperas: 1 en la exposición, 0,15 con --rapido


func _initialize() -> void:
	if "--rapido" in OS.get_cmdline_user_args():
		_speed = 0.15
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_game = root.get_node("Game")
	_game.save_path = "user://demo.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_game.save_path))
	_game.stars = {}
	_game.bolts = {}
	_game.ice = {}
	change_scene_to_file("res://world/city.tscn")
	_run.call_deferred()


func _run() -> void:
	await _wait(5.0)  # bienvenida
	var player: CharacterBody3D = get_first_node_in_group("player")

	# --- Paseo: andar, correr, saltar y jetpack ---
	player.place(Vector3(0, 0.5, 34), 0.0)
	await _wait(1.5)
	await _hold("move_forward", 2.0)
	Input.action_press("sprint")
	await _hold("move_forward", 1.2)
	Input.action_release("sprint")
	await _wait(0.6)
	await _hold("jump", 0.3)
	await _wait(1.5)
	_say("Saltando otra vez en el aire se enciende el jetpack")
	await _hold("jump", 0.25)
	await _wait(0.15)
	await _hold("jump", 1.6)
	await _wait(3.0)

	# --- STEAM LAB ---
	player.place(Vector3(0, 0.5, 6), 0.0)
	await _wait(1.5)
	var lab: CanvasLayer = current_scene.get_node("SteamLab")
	lab.open()
	await _wait(5.0)

	# --- Energía solar: una respuesta mal y el resto bien ---
	lab._choose("solar")
	await _wait(2.0)
	var solar: Node3D = _find("_answer")
	solar.start()
	await _wait(3.0)
	for i in 5:
		if i == 0:
			var wrong: int = solar._answers.find(solar._answers.filter(func(a: String) -> bool: return a != solar._questions[0][1][0])[0])
			solar._grid.get_child(wrong).pressed.emit()
			await _wait(2.5)
		solar._grid.get_child(solar._answers.find(solar._questions[i][1][0])).pressed.emit()
		await _wait(3.0)
		_button(solar._content, "SIGUIENTE" if i < 4 else "VER RESULTADO").pressed.emit()
		await _wait(2.0)
	await _wait(3.0)
	_button(solar._content, "CERRAR").pressed.emit()
	await _wait(3.0)

	# --- Ingeniería: el puente óptimo (madera, metal, metal, metal, madera) ---
	await _travel("bridge")
	var bridge: Node3D = _find("_collapse")
	for i in [1, 2, 3]:
		while bridge._slots[i] != 1:
			bridge._cycle(i)
			await _wait(0.4)
	for i in [0, 4]:
		while bridge._slots[i] != 0:
			bridge._cycle(i)
			await _wait(0.4)
	await _wait(1.0)
	await bridge._test()
	await _wait(4.0)

	# --- Robótica: programa paso a paso y lo ejecuta ---
	await _travel("robotics")
	var robotics: Node3D = _find("_solve")
	robotics.open()
	await _wait(2.0)
	for command: String in robotics._solve():
		robotics._add(command)
		await _wait(0.45)
	await _wait(0.8)
	await robotics._run()
	await _wait(3.0)
	robotics.close()
	await _wait(1.5)

	# --- Reciclaje: cada residuo a su caneca ---
	await _travel("recycling")
	var recycling: Node3D = _find("_throw")
	player.place(recycling.to_global(Vector3(0, 0.5, 4)), recycling.global_rotation.y)
	recycling.start()
	await _wait(2.0)
	while not recycling._items.is_empty():
		var item: Area3D = recycling._items[0]
		item.interact()
		await _wait(0.9)
		recycling._bins[item.get_meta("data")[1]][0].interact()
		while recycling._busy:
			await physics_frame
		await _wait(0.5)
	await _wait(4.0)

	# --- Matemáticas: aterrizar en la plataforma con la respuesta ---
	await _travel("math")
	var math: Node3D = _find("_on_land")
	math.start()
	await _wait(3.0)
	for q in math.ROUND:
		player.place(math._pads[math._right].global_position + Vector3(0, 3.0, 0), 0.0)
		var limit := 400
		while math._index <= q and limit > 0:
			await physics_frame
			limit -= 1
		await _wait(1.6)
	await _wait(3.0)

	# --- Visión IA: dibujar la figura pisando baldosas ---
	await _travel("vision")
	var vision: Node3D = _find("toggle")
	player.place(vision.to_global(Vector3(0, 0.5, 6)), vision.global_rotation.y)
	vision._on_stand()
	await _wait(2.0)
	var shape: String = vision.SHAPES[vision.GOALS[vision._level]].replace(" ", "")
	for i in 25:
		if shape[i] == "#" and vision._pixels[i] == 0:
			player.place(vision.to_global(vision._pos(i)) + Vector3(0, 0.3, 0), vision.global_rotation.y)
			await _wait(0.5)
	player.place(vision.to_global(Vector3(0, 0.5, 6)), vision.global_rotation.y)
	await _wait(1.0)
	for i in 25:  # por si algún paso no encendió su baldosa
		if vision._pixels[i] != int(shape[i] == "#"):
			vision.toggle(i)
	await vision._analyze()
	await _wait(4.0)

	# --- Desafío IA: tres en raya contra NOVA ---
	await _travel("ai")
	var duel: Node3D = _find("_nova_turn")
	duel.start()
	await _wait(2.0)
	while duel._playing:
		var best := -1
		var lowest := 1000
		for i in 9:
			if duel._board[i] == 0:
				duel._board[i] = 1
				var value: int = duel.minimax(duel._board, 2)
				duel._board[i] = 0
				if value < lowest:
					lowest = value
					best = i
		await duel._on_cell(best)
		await _wait(1.0)
	await _wait(4.0)

	# --- Una tuerca dorada ---
	var bolts: Array = current_scene.find_children("*", "", true, false).filter(
		func(n: Node) -> bool: return n.get_script() != null and n.get_script().get_global_name() == &"Bolt")
	if not bolts.is_empty():
		var bolt: Area3D = bolts[0]
		player.place(bolt.global_position + Vector3(0, -0.9, 4.0), 0.0)
		await _wait(1.5)
		player.place(bolt.global_position - Vector3(0, 0.9, 0), 0.0)
		await _wait(3.0)

	# --- Avance rápido hasta las 12 piezas del cohete ---
	_say("Avance rápido: completamos los retos que faltan")
	await _wait(2.0)
	for id: String in _game.MODULES:
		_game.set_stars(id, 3)
	await _wait(24.0)  # celebraciones en fila y certificado STEAM

	# --- Cohete de agua: llenar 1/3, bombear a la zona verde y despegar ---
	await _travel("rocket")
	var rocket: Node3D = _find("_count")
	await _wait(1.5)
	rocket._pad.interact()
	while rocket._water < 0.33:
		await physics_frame
	rocket._pad.interact()
	await _wait(1.5)
	while rocket._stage == "pump":
		if rocket._pressure < 0.78:
			rocket._pad.interact()
		await _wait(0.45 if _speed == 1.0 else 0.1)
	while current_scene == null or current_scene.name != "Moon":
		await physics_frame
	await _wait(9.0)  # aterrizaje

	# --- La Luna ---
	var astronaut: CharacterBody3D = get_first_node_in_group("player")
	_say("En la Luna la gravedad es 1/6: se salta mucho más alto")
	await _wait(1.0)
	await _hold("jump", 0.4)
	await _wait(4.0)

	var jump: Node3D = _find("_collect")
	await _moon_travel(jump.global_position)
	for crystal: Node3D in jump._crystals:
		if is_instance_valid(crystal):
			astronaut.global_position = crystal.global_position
			await _wait(2.0)
	await _wait(2.0)

	var rover: Node3D = _find("_solve")
	await _moon_travel(rover.global_position)
	rover.open()
	await _wait(2.0)
	for command: String in rover._solve():
		rover._add(command)
		await _wait(0.4)
	await rover._run()
	await _wait(3.0)
	rover.close()
	await _wait(1.0)

	var power: Node3D = _find("_lit")
	await _moon_travel(power.global_position)
	await _wait(1.0)
	for i in power._path.size():  # girar cada pieza del camino hasta unir entrada y salida
		var cell: Vector2i = power._path[i]
		var entry: int = 3 if i == 0 else power.DIRS.find(power._path[i - 1] - cell)
		var exit: int = 1 if i == power._path.size() - 1 else power.DIRS.find(power._path[i + 1] - cell)
		while not (entry in power._sides(cell) and exit in power._sides(cell)):
			power._turn(cell)
			power._refresh()
			await _wait(0.3)
	while power._busy:
		await physics_frame
	await _wait(4.0)

	var water: Node3D = _find("_pour")
	await _moon_travel(water.global_position)
	await _wait(1.0)
	for layer in ["CARBÓN ACTIVADO", "ARENA", "GRAVA"]:
		water._add(layer)
		await _wait(1.2)
	await water._pour()
	await _wait(5.0)

	# --- Vuelta a la Tierra: certificado de astronauta y créditos ---
	var moon_rocket: Node3D = _find("_set_water")
	await _moon_travel(moon_rocket.global_position + Vector3(0, 0, 8))
	await _wait(1.5)
	moon_rocket._pad.interact()
	while current_scene == null or current_scene.name != "City":
		await physics_frame
	await _wait(40.0)
	if _speed < 1.0:
		print("DEMO OK  ★ %d  tuercas %d" % [_game.total_stars() + _game.total_stars(_game.LAB_MODULES) + _game.total_stars(_game.MOON_MODULES), _game.bolts.size()])
		quit()


## Viaja con fundido a un distrito de la ciudad (como las tarjetas del STEAM LAB).
func _travel(id: String) -> void:
	current_scene._travel_to_district(id)
	await _wait(2.0)


## Viaja con fundido cerca de un punto de la Luna, mirándolo desde el lado de la llegada.
func _moon_travel(target: Vector3) -> void:
	var from := target + (Vector3(0, 0, 8) - target).normalized() * 9.0
	from.y = 0.5
	var dir := target - from
	await _game.travel(from, atan2(-dir.x, -dir.z))
	await _wait(1.5)


func _say(text: String) -> void:
	_game.notify(text, _game.INK_2)


func _find(method: String) -> Node:
	return current_scene.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method(method))[0]


func _button(container: Node, text: String) -> Button:
	return container.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == text)[0]


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await create_timer(seconds).timeout  # sin acortar: con menos tiempo el salto o el jetpack serían otros
	Input.action_release(action)


## Espera en segundos; con --rapido, mucho menos.
func _wait(seconds: float) -> void:
	await create_timer(seconds * _speed).timeout
