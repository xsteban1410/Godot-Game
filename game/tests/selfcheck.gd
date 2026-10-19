extends SceneTree
## Autocomprobación sin ventana:  godot --headless --path game --script res://tests/selfcheck.gd
## Las estrellas solo suben (repetir un reto no premia dos veces: bug B2 de Unity) y se guardan.

var _failures := 0


func _initialize() -> void:
	var game_script: GDScript = load("res://autoload/game.gd")
	var game: Node = game_script.new()
	game.save_path = "user://selfcheck.cfg"
	game.set_stars("bridge", 2)
	game.set_stars("bridge", 1)
	game.set_stars("solar", 3)
	_check(game.stars["bridge"] == 2, "las estrellas solo suben")
	_check(game.total_stars() == 5, "el total suma todos los retos")

	var cfg := ConfigFile.new()
	cfg.load(game.save_path)
	_check(cfg.get_value("progress", "stars", {}) == {"bridge": 2, "solar": 3}, "las estrellas se guardan")

	# Puente: cada nivel tiene solución dentro del presupuesto y "todo hormigón" nunca cabe (B1 de Unity).
	var bridge: GDScript = load("res://modules/bridge.gd")
	for level: Array in bridge.LEVELS:
		var cheapest := INF
		for combo in 243:  # 3^5 combinaciones de materiales
			var total := 0
			var holds := true
			for i in 5:
				var m: Array = bridge.MATERIALS[int(combo / pow(3, i)) % 3]
				total += m[1]
				holds = holds and m[2] >= level[1] * bridge.FACTORS[i]
			if holds:
				cheapest = minf(cheapest, total)
		_check(cheapest <= level[2], "el %s tiene solución dentro del presupuesto (%d ≤ %d)" % [level[0], cheapest, level[2]])
		_check(5 * bridge.MATERIALS[2][1] > level[2], "con el %s, todo hormigón no cabe en el presupuesto" % level[0])

	# Caja redondeada de Kit: mide lo pedido, normales hacia fuera y caras en sentido horario (las que Godot dibuja).
	var mesh: Mesh = load("res://core/kit.gd")._rounded_box(Vector3(2, 1, 0.5))
	_check(mesh.get_aabb().size.is_equal_approx(Vector3(2, 1, 0.5)), "la caja redondeada mide lo pedido")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var outward := true
	for i in vertices.size():
		outward = outward and vertices[i].dot(normals[i]) > 0.0
	var clockwise := true
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var face := (vertices[indices[t + 1]] - a).cross(vertices[indices[t + 2]] - a)
		clockwise = clockwise and face.dot(normals[indices[t]] + normals[indices[t + 1]] + normals[indices[t + 2]]) <= 0.0
	_check(outward and clockwise, "la caja redondeada no sale del revés")

	# Desafío IA: la IA minimax (nivel 3) no pierde contra ninguna secuencia de jugadas; la del nivel 2 gana o tapa.
	var ai: GDScript = load("res://modules/ai.gd")
	var board: Array[int] = []
	board.resize(9)
	_check(not _x_can_win(ai, board), "ninguna partida le gana a la IA minimax")
	board.assign([1, 1, 0, 0, 2, 0, 0, 0, 0])
	_check(ai.choose(board, 1) == 2, "la IA del nivel 2 tapa la raya del jugador")
	board.assign([2, 2, 0, 1, 1, 0, 1, 0, 0])
	_check(ai.choose(board, 1) == 2, "la IA del nivel 2 prefiere ganar a tapar")

	# Visión IA: cada figura aprendida se reconoce como ella misma y con seguridad; un dibujo vacío, no.
	var vision: GDScript = load("res://modules/vision.gd")
	for shape: String in vision.SHAPES:
		var pixels := Array(vision.SHAPES[shape].replace(" ", "").split("")).map(func(c: String) -> int: return int(c == "#"))
		var guess: Array = vision.classify(pixels)[0]
		_check(guess[0] == shape and guess[1] >= vision.CONFIDENCE, "la IA reconoce %s (%s %d %%)" % [shape, guess[0], guess[1]])
	var empty := []
	empty.resize(25)
	empty.fill(0)
	_check(vision.classify(empty)[0][1] < vision.CONFIDENCE, "con el dibujo vacío la IA no está segura de nada")

	# Matemáticas: respuestas enteras positivas y tres opciones falsas distintas.
	var math: GDScript = load("res://modules/math.gd")
	var sane := true
	for round in 20:
		for n in math.ROUND:
			var q: Array = math.question(n)
			var wrong: Array = math.distractors(q[1])
			sane = sane and q[1] > 0 and wrong.size() == 3 and not q[1] in wrong and wrong.all(func(w: int) -> bool: return w > 0 and wrong.count(w) == 1)
	_check(sane, "las preguntas de mates tienen respuesta y 3 opciones falsas distintas")

	# Fuente de símbolos: lo que Rubik no tiene (estrellas, flechas, ohmio) no depende de las fuentes del sistema.
	var symbols: FontFile = load("res://ui/fonts/Symbols.ttf")
	_check(Array("★☆←↑→Ω".split("")).all(func(c: String) -> bool: return symbols.has_char(c.unicode_at(0))), "Symbols.ttf tiene ★ ☆ ← ↑ → Ω")

	# Ivy: lineas.json (lo edita el usuario, ver ivy/GUIA.md) bien escrito, completo y con cada frase grabada.
	var json := JSON.new()
	var parsed := json.parse(FileAccess.get_file_as_string("res://ivy/lineas.json"))
	_check(parsed == OK and json.data is Dictionary, "ivy/lineas.json es un JSON válido%s" % [
		"" if parsed == OK else " (línea %d: %s)" % [json.get_error_line(), json.get_error_message()]])
	if parsed == OK and json.data is Dictionary:
		var missing: Array[String] = []
		for path in ["general/ayuda", "general/boton_despues", "general/boton_cerrar", "historia/estrellas",
				"historia/lanzar", "historia/hielo", "historia/volver", "historia/todo"]:
			if not _text(json.data, path.split("/")):
				missing.append(path)
		var zones: Array = load("res://world/city.gd").DISTRICTS.keys() + ["city", "plaza", "rocket", "moon"] \
			+ load("res://world/moon.gd").CHALLENGES.values()
		for id: String in zones:
			if not _text(json.data, ["zonas", id, "saludo"]):
				missing.append("zonas/%s/saludo" % id)
			var questions: Variant = json.data.get("zonas", {}).get(id, {}).get("preguntas", [])
			if not questions is Array or not questions.all(func(q: Variant) -> bool: return _text(q, ["pregunta"]) and _text(q, ["respuesta"])):
				missing.append("zonas/%s/preguntas (cada una con «pregunta» y «respuesta»)" % id)
		_check(missing.is_empty(), "ivy/lineas.json tiene todas sus partes%s" % ["" if missing.is_empty() else ": falta " + ", ".join(missing)])
		var ivy: GDScript = load("res://ivy/ivy.gd")
		var silent: Array = ivy.all_lines().filter(func(t: String) -> bool: return not FileAccess.file_exists(ivy.voice_path(t)))
		_check(silent.is_empty(), "cada frase de Ivy tiene su voz grabada%s" % [
			"" if silent.is_empty() else " (faltan %d: pasa tools/voice.gd; la primera: «%s»)" % [silent.size(), silent[0]]])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	game._fade.free()  # sin _ready no cuelga de nadie: se liberaría solo al salir, como fuga
	game.free()
	print("SELFCHECK %s (%d fallos)" % ["OK" if _failures == 0 else "FALLÓ", _failures])
	quit(1 if _failures else 0)


## ¿Siguiendo las claves `path` desde `data` hay un texto no vacío?
func _text(data: Variant, path: Array) -> bool:
	for key in path:
		if not data is Dictionary or not data.has(key):
			return false
		data = data[key]
	return data is String and not data.is_empty()


## ¿Hay alguna forma de que X gane si la IA del nivel 3 responde a cada jugada?
func _x_can_win(ai: GDScript, board: Array[int]) -> bool:
	for i in 9:
		if board[i] != 0:
			continue
		board[i] = 1
		var wins: bool = ai.winner(board) == 1
		if not wins and board.has(0):
			var reply: int = ai.choose(board, 2)
			board[reply] = 2
			wins = ai.winner(board) == 0 and _x_can_win(ai, board)
			board[reply] = 0
		board[i] = 0
		if wins:
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		printerr("  ✗ " + description)
