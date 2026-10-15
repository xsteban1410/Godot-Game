extends SceneTree
## Prueba de juego automática sobre la ciudad real (sin ventana):
##   godot --headless --path game --script res://tests/play_test.gd
## Pulsa teclas por código y mide: andar, correr, saltar, aterrizar, aviso de interacción y bloqueo.

var _failures := 0
var _game: Node


func _initialize() -> void:
	_game = root.get_node("Game")
	_game.save_path = "user://play_test.cfg"  # nunca tocar la partida real
	_game.stars = {}  # empezar de cero aunque la partida real tenga estrellas
	change_scene_to_file("res://world/city.tscn")
	_run.call_deferred()


func _run() -> void:
	await _frames(20)
	var player: CharacterBody3D = get_first_node_in_group("player")
	_check(player != null, "la ciudad tiene jugador")
	_check(player.is_on_floor(), "el jugador empieza en el suelo")
	var grabbers := current_scene.get_node("HUD").find_children("*", "Control", true, false).filter(
		func(c: Control) -> bool: return c.mouse_filter != Control.MOUSE_FILTER_IGNORE)
	_check(grabbers.is_empty(), "el HUD no atrapa el ratón (si lo hace, la cámara no gira)")

	var start := player.global_position
	await _hold("move_forward", 60)
	var walked := start.z - player.global_position.z
	_check(walked > 3.5 and walked < 6.0, "andar 1 s avanza ~5 m hacia la cámara (%.2f m)" % walked)

	Input.action_press("sprint")
	start = player.global_position
	await _hold("move_forward", 30)
	Input.action_release("sprint")
	var sprinted := start.z - player.global_position.z
	_check(sprinted > walked / 2.0 * 1.3, "correr es más rápido que andar (%.2f m en 0,5 s)" % sprinted)
	await _frames(30)

	var ground_y := player.global_position.y
	Input.action_press("jump")
	var peak := ground_y
	for i in 40:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	Input.action_release("jump")
	_check(peak - ground_y > 1.2 and peak - ground_y < 1.8, "el salto alcanza ~1,5 m (%.2f m)" % (peak - ground_y))
	await _frames(60)
	_check(player.is_on_floor(), "el jugador aterriza")

	var prompts: Array[String] = []
	_game.prompt_changed.connect(func(t: String) -> void: prompts.append(t))
	player.place(Vector3(0, 0.5, 5), 0.0)
	await _frames(20)
	_check("ENTRAR AL STEAM LAB" in prompts, "cerca de la terminal aparece su aviso")

	_game.push_lock(self)
	start = player.global_position
	await _hold("move_forward", 30)
	_check(start.distance_to(player.global_position) < 0.05, "con un menú abierto el jugador no se mueve")
	_check(prompts.back() == "", "con un menú abierto se oculta el aviso")
	_game.pop_lock(self)
	_check(not _game.is_locked(), "al cerrar el menú se recupera el control")


	# --- Fase 2: STEAM LAB, viajes y pausa ---
	var lab: CanvasLayer = current_scene.get_node("SteamLab")
	player.place(Vector3(0, 0.5, 5), 0.0)
	await _frames(10)
	_press("interact")
	await _frames(5)
	_check(lab.visible and _game.is_locked(), "E en la terminal abre el STEAM LAB y detiene al jugador")
	_check(_game.wants_cursor(), "con el STEAM LAB abierto se ve el cursor")
	_press("pause")
	await _frames(5)
	_check(not lab.visible and not _game.is_locked(), "ESC cierra el STEAM LAB")

	lab.open()
	lab._choose("bridge")
	await _frames(15)
	_check(_game.is_locked() and not _game.wants_cursor(), "durante el viaje el jugador espera y no aparece el cursor")
	await _frames(70)
	var to_bridge := player.global_position.distance_to(Vector3(44, 0, 0))
	_check(to_bridge < 9.0 and not _game.is_locked(), "el módulo Ingeniería lleva a su distrito (%.1f m del centro)" % to_bridge)


	# --- Fase 3: Energía solar ---
	var solar: Node3D = current_scene.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method("_answer"))[0]
	player.place(solar.global_position + solar.global_basis.z * 2.0 + Vector3(0, 0.5, 0), 0.0)
	await _frames(10)
	_press("interact")
	await _frames(5)
	_check(_game.is_locked() and solar._questions.size() == 5, "E en el stand solar abre 5 preguntas")
	# Se pulsan los botones reales (llamar a _answer directamente ocultó el cierre al responder).
	var wrong: int = solar._answers.find(solar._answers.filter(func(a: String) -> bool: return a != solar._questions[0][1][0])[0])
	solar._grid.get_child(wrong).pressed.emit()
	await _frames(2)
	_check(solar._misses == 1 and solar._grid.get_child(wrong).disabled, "un fallo desactiva esa respuesta")
	solar._grid.get_child(solar._answers.find(solar._questions[0][1][0])).pressed.emit()
	await _frames(2)
	_check(solar._score == 50, "acertar tras un fallo vale 50 puntos (sin colgarse al pulsar)")
	_check(solar._windows[0].material_override.emission_enabled, "acertar enciende una ventana")
	solar.start()
	for i in 5:
		await _frames(2)
		solar._grid.get_child(solar._answers.find(solar._questions[i][1][0])).pressed.emit()
		await _frames(2)
		_button(solar._content, "SIGUIENTE" if i < 4 else "VER RESULTADO").pressed.emit()
	await _frames(2)
	_check(_game.stars.get("solar") == 3, "5 aciertos sin fallos dan 3 estrellas")
	_button(solar._content, "CERRAR").pressed.emit()
	await _frames(2)
	_check(not _game.is_locked(), "cerrar el reto devuelve el control")

	# --- Fase 4: puente ---
	var bridge: Node3D = current_scene.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method("_collapse"))[0]
	for i in 5:
		bridge._cycle(i)  # todo madera: el centro (6 t con el coche de 3 t) no aguanta
	_check(bridge.cost() == 50, "cinco tramos de madera cuestan 50 CR")
	await bridge._test()
	_check(bridge._slots[1] == -1 and bridge._pieces[1] == null and _game.stars.get("bridge", 0) == 0,
		"un tramo débil se hunde y queda vacío; sin estrella")
	for i in [1, 2, 3]:
		while bridge._slots[i] != 1:
			bridge._cycle(i)  # metal en el centro: W M M M W = 95 CR, la solución óptima
	await bridge._test()
	_check(_game.stars.get("bridge", 0) == 1 and bridge._level == 1, "el puente óptimo cruza: 1 estrella y sube al camión")

	# --- Fase 5: robótica ---
	var robotics: Node3D = current_scene.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method("_solve"))[0]
	for level in 3:
		robotics._level = level
		robotics._new_board()
		var solution: Array[String] = robotics._solve()
		_check(not solution.is_empty() and solution.size() <= 15, "el tablero del nivel %d tiene solución en %d pasos" % [level + 1, solution.size()])
	robotics._level = 0
	robotics._new_board()
	robotics.open()
	_check(get_root().get_viewport().get_camera_3d() == robotics._camera, "abrir Robótica pasa a la cámara cenital")
	_press_key(KEY_LEFT)
	_press_key(KEY_UP)
	await _frames(2)
	_check(robotics._program == ["L", "F"], "las flechas del teclado programan el robot")
	await robotics._run()
	_check(robotics._cell == Vector2i.ZERO and not robotics._running, "salir del tablero es un choque y el robot vuelve")
	robotics._program.assign(robotics._solve())
	await robotics._run()
	_check(_game.stars.get("robotics", 0) == 1 and robotics._level == 1, "la solución llega a la estrella: 1 estrella y nivel 2")
	robotics.close()
	_check(get_root().get_viewport().get_camera_3d() != robotics._camera and not _game.is_locked(), "cerrar devuelve la cámara y el control")

	# --- Fase 6: reciclaje (interact() es el mismo camino que pulsar E) ---
	var recycling: Node3D = current_scene.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method("_throw"))[0]
	recycling.start()
	_check(recycling._items.size() == 8, "empezar el reto reparte 8 residuos")
	_check(not _game.is_locked(), "el reciclaje se juega sin bloquear la cámara")
	var first: Area3D = recycling._items[0]
	var right: String = first.get_meta("data")[1]
	first.interact()
	_check(recycling._carried == first and not first.monitorable, "E recoge el residuo y lo lleva encima")
	recycling._items[1].interact()
	_check(recycling._carried == first, "no se pueden llevar dos residuos")
	recycling._bins["negra" if right != "negra" else "verde"][0].interact()
	while recycling._busy:
		await physics_frame
	_check(recycling._mistakes == 1 and first.monitorable and recycling._carried == null, "caneca equivocada: error y el residuo vuelve a su sitio")
	while not recycling._items.is_empty():
		var item: Area3D = recycling._items[0]
		item.interact()
		recycling._bins[item.get_meta("data")[1]][0].interact()
		while recycling._busy:
			await physics_frame
	_check(recycling._done == 8 and _game.stars.get("recycling", 0) == 2, "8 aciertos con 1 error dan 2 estrellas")

	# --- Fase 8: piezas del cohete (piezas = estrellas) ---
	var rocket: Node3D = current_scene.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method("_count"))[0]
	_check(rocket._count() == _game.total_stars(), "el cohete tiene una pieza por estrella (%d)" % rocket._count())
	_game.set_stars("bridge", 2)
	_check(rocket._parts["bridge:1"].visible, "ganar la 2.ª estrella de Ingeniería monta los anillos")

	# --- Fase 7: cierre ---
	for id in ["solar", "bridge", "robotics", "recycling"]:
		_game.set_stars(id, 3)
	var city: Node3D = current_scene
	_check(city._star_labels["bridge"].text == "★★★", "el arco del distrito muestra sus estrellas")
	_check(city._rings["bridge"].material_override.emission_energy_multiplier > 1.0, "con 3 estrellas el aro del distrito brilla")
	await _frames(240)
	var certificate: Array = current_scene.get_node("HUD").find_children("*", "Label", true, false).filter(
		func(l: Label) -> bool: return l.text == "CERTIFICADO STEAM")
	_check(not certificate.is_empty(), "con las 12 estrellas aparece el certificado")
	_check(rocket._count() == 12 and "LANZAMIENTO" in rocket._pad.prompt, "con 12 estrellas el cohete está completo")

	# --- Fase 9: lanzamiento (E en la plataforma) ---
	rocket._pad.interact()
	_check(rocket._stage == "water", "con 12 piezas, E empieza a llenar de agua")
	rocket._set_water(0.05)
	rocket._pad.interact()
	for i in 8:
		rocket._pad.interact()
	await _frames(400)
	_check(rocket._stage == "" and current_scene.name == "City" and not _game.is_locked(),
		"con 5 % de agua el cohete solo da un saltito y se puede repetir")
	rocket._pad.interact()
	rocket._set_water(0.33)
	rocket._pad.interact()
	for i in 10:
		rocket._pad.interact()
	_check(is_equal_approx(rocket._pressure, 0.35), "bombear demasiado hace saltar la válvula")
	for i in 5:
		rocket._pad.interact()
	await _frames(1000)
	_check(current_scene.name == "Moon", "con 1/3 de agua y presión verde el cohete llega a la Luna")
	await _frames(500)
	var astronaut: CharacterBody3D = get_first_node_in_group("player")
	_check(astronaut.gravity < 4.0 and astronaut.visible and not _game.is_locked(), "en la Luna: gravedad 1/6 y control tras el aterrizaje")

	# --- Fase 11: retos lunares ---
	var moon_nodes := current_scene.find_children("*", "", true, false)
	var moon_floor := astronaut.global_position.y
	var top := moon_floor
	_press("jump")
	for i in 120:
		await physics_frame
		top = maxf(top, astronaut.global_position.y)
	Input.action_release("jump")
	_check(top - moon_floor > 4.0, "en la Luna se salta %.1f m (en la Tierra, 1,5)" % (top - moon_floor))
	var jump: Node3D = moon_nodes.filter(func(n: Node) -> bool: return n.has_method("_collect"))[0]
	_check(jump.STEPS > 1 and 2.4 < top - moon_floor, "cada escalón del salto lunar (2,4 m) se alcanza saltando")
	astronaut.global_position = jump._crystals[0].global_position
	await _frames(10)
	_check(_game.stars.get("moon_jump", 0) == 1, "tocar un cristal de hielo da una estrella lunar")

	moon_nodes = current_scene.find_children("*", "", true, false)  # el cristal recogido ya no existe
	var rover: Node3D = moon_nodes.filter(func(n: Node) -> bool: return n.has_method("_solve"))[0]
	for level in 3:
		rover._level = level
		rover._new_board()
		_check(rover._solve().size() in range(1, 16), "el tablero lunar %d tiene solución" % (level + 1))
	rover._level = 0
	rover._new_board()
	rover.open()
	rover._program.assign(rover._solve())
	await rover._run()
	rover.close()
	_check(_game.stars.get("moon_rover", 0) == 1, "el rover llega al hielo: estrella lunar")

	var power: Node3D = moon_nodes.filter(func(n: Node) -> bool: return n.has_method("_lit"))[0]
	_check(not power._lit().has(power._end), "el circuito empieza sin resolver")
	for i in power._path.size():  # girar cada pieza del camino hasta que una su entrada y su salida
		var cell: Vector2i = power._path[i]
		var entry: int = 3 if i == 0 else power.DIRS.find(power._path[i - 1] - cell)
		var exit: int = 1 if i == power._path.size() - 1 else power.DIRS.find(power._path[i + 1] - cell)
		while not (entry in power._sides(cell) and exit in power._sides(cell)):
			power._turn(cell)
	power._refresh()
	_check(_game.stars.get("moon_power", 0) == 1, "llevar la corriente al fundidor da una estrella lunar")

	var water: Node3D = moon_nodes.filter(func(n: Node) -> bool: return n.has_method("_pour"))[0]
	for layer in ["GRAVA", "ARENA", "CARBÓN ACTIVADO"]:
		water._add(layer)
	await water._pour()
	_check(_game.stars.get("moon_water", 0) == 0 and water._stack.is_empty(), "orden equivocado: agua turbia y filtro vacío")
	for layer in ["CARBÓN ACTIVADO", "ARENA", "GRAVA"]:
		water._add(layer)
	await water._pour()
	_check(_game.stars.get("moon_water", 0) == 2, "orden correcto al segundo intento: 2 estrellas")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(_game.save_path))
	print("PLAY TEST %s (%d fallos)" % ["OK" if _failures == 0 else "FALLÓ", _failures])
	quit(1 if _failures else 0)


func _button(container: Node, text: String) -> Button:
	return container.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == text)[0]


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	print(("  ✓ " if condition else "  ✗ ") + description)
	if not condition:
		_failures += 1
