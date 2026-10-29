extends Node3D
## Reto Desafío IA: tres en raya gigante contra NOVA, una IA robot. E en una casilla pone tu ficha (X) y
## NOVA camina hasta la suya (O). Nivel 1: juega al azar. Nivel 2: mira una jugada (gana si puede, si no
## bloquea): se le gana con una doble amenaza. Nivel 3: minimax, imagina todas las partidas posibles
## hasta el final y nunca pierde; empatarle ya es la tercera estrella. Se coloca mirando a la plaza (+Z).

const CELL := 2.4
const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
const LEVELS := ["NOVATA: juega al azar", "LISTA: mira una jugada adelante", "MAESTRA: minimax, piensa todas las jugadas"]
const NOVA_HOME := Vector3(5.6, 0, -4.0)

static var _memo := {}  # tablero (en base 3) -> valor minimax; compartido: se calcula una vez

var _board: Array[int] = []  # 0 vacío, 1 jugador (X), 2 NOVA (O)
var _level := 0
var _playing := false
var _busy := false
var _pieces: Array[Node3D] = []
var _nova := Node3D.new()
var _robot: RobotModel
var _sign: Label3D
var _thought: Label3D


func _ready() -> void:
	var color: Color = Game.info("ai").color
	_level = mini(int(Game.stars.get("ai", 0)), LEVELS.size() - 1)
	_board.resize(9)
	_pieces.resize(9)
	Kit.stand(self, Vector3(-5.4, 0, 2.6), color, "RETO: DESAFÍO IA").interacted.connect(start)
	Kit.box(self, Vector3(CELL * 3 + 0.4, 0.04, CELL * 3 + 0.4), Vector3(0, 0.18, -4.0), Kit.mat(Color("2a2c33")))  # sobre la plataforma (0,16 m)
	for i in 9:
		Kit.box(self, Vector3(CELL * 0.92, 0.06, CELL * 0.92), _pos(i) + Vector3(0, 0.21, 0), Kit.mat(Color("f4f7fb") if i % 2 == 0 else Color("dbe9f7")))
		var cell := Kit.interactable(self, "PONER TU FICHA (X)", _pos(i) + Vector3(0, 1, 0), 1.1)
		cell.marker_height = 1.8
		cell.interacted.connect(_on_cell.bind(i))
	Kit.box(self, Vector3(8.2, 2.6, 0.3), Vector3(0, 6.4, -9.2), Kit.mat(Color("2a2c33")))
	Kit.box(self, Vector3(8.5, 0.25, 0.4), Vector3(0, 7.8, -9.2), Kit.mat(color))
	for x in [-3.7, 3.7]:
		Kit.cylinder(self, 0.12, 0.12, 5.2, Vector3(x, 2.6, -9.3), Kit.mat(Color("f4f7fb")), 10)
	_sign = Kit.label(self, "", Vector3(0, 6.4, -9.0), 46, Color.WHITE, false, 0.01, 7.8)
	Kit.bake(self)
	_nova.position = NOVA_HOME
	_nova.rotation.y = -PI / 2  # mira al tablero
	add_child(_nova)
	_robot = RobotModel.create(_nova, color, Color("ffb9d1"))
	Kit.blob_shadow(_nova)
	Kit.label(_nova, "NOVA", Vector3(0, 2.4, 0), 44, color.lightened(0.4))
	_thought = Kit.label(_nova, "", Vector3(0, 3.0, 0), 40, Color.WHITE)
	_say("NOVA, la IA del tres en raya\nNivel %d: %s" % [_level + 1, LEVELS[_level]])


func start() -> void:
	if _busy:
		return
	_board.fill(0)
	for i in 9:
		if _pieces[i]:
			_pieces[i].queue_free()
			_pieces[i] = null
	_playing = true
	Sfx.play("pickup")
	_say("NIVEL %d · %s\nTu turno: elige una casilla" % [_level + 1, LEVELS[_level]])


func _on_cell(i: int) -> void:
	if not _playing or _busy:
		return
	if _board[i] != 0:
		Game.notify("Esa casilla ya está ocupada.", Game.WARNING)
		return
	_busy = true
	_place(i, 1)
	if not await _check_end():
		await _nova_turn()
	_busy = false


## NOVA piensa, camina a su casilla y pone su ficha.
func _nova_turn() -> void:
	_say("NIVEL %d · %s\nNOVA está pensando…" % [_level + 1, LEVELS[_level]])
	_thought.text = "…"
	await get_tree().create_timer(0.6).timeout
	var move := choose(_board, _level)
	_thought.text = ""
	var spot := _pos(move) + Vector3(0, 0, 1.0)
	_robot.play("Walk", 0.15, 1.4)
	_nova.look_at(to_global(spot), Vector3.UP, true)
	await create_tween().tween_property(_nova, "position", spot, 0.9).set_trans(Tween.TRANS_SINE).finished
	_robot.play("Point", 0.1)  # señala la casilla
	_place(move, 2)
	await get_tree().create_timer(0.4).timeout
	_robot.play("Walk", 0.15, 1.4)
	_nova.look_at(to_global(NOVA_HOME), Vector3.UP, true)
	await create_tween().tween_property(_nova, "position", NOVA_HOME, 0.8).finished
	_nova.rotation.y = -PI / 2
	_robot.play("Idle", 0.25)
	if not await _check_end():
		_say("NIVEL %d · %s\nTu turno: elige una casilla" % [_level + 1, LEVELS[_level]])


## Casilla que elige NOVA (ficha 2) según su nivel.
static func choose(board: Array[int], level: int) -> int:
	var free := range(9).filter(func(i: int) -> bool: return board[i] == 0)
	if level >= 2:
		var best := -INF
		var pick: int = free[0]
		for i: int in free:
			board[i] = 2
			var value := minimax(board, 1)
			board[i] = 0
			if value > best:
				best = value
				pick = i
		return pick
	if level == 1:
		for who in [2, 1]:  # primero ganar; si no, tapar la jugada ganadora del rival
			for i: int in free:
				board[i] = who
				var wins: bool = winner(board) == who
				board[i] = 0
				if wins:
					return i
	return free.pick_random()


## Valor del tablero para NOVA con juego perfecto de los dos: +10 gana (antes, mejor), −10 pierde, 0 empate.
static func minimax(board: Array[int], turn: int) -> int:
	var key := 0
	for cell in board:
		key = key * 3 + cell
	key = key * 3 + turn
	if _memo.has(key):
		return _memo[key]
	var w := winner(board)
	var empty := board.count(0)
	var value := 0
	if w != 0:
		value = (1 + empty) * (1 if w == 2 else -1)
	elif empty > 0:
		value = -100 if turn == 2 else 100
		for i in 9:
			if board[i] == 0:
				board[i] = turn
				var v := minimax(board, 3 - turn)
				board[i] = 0
				value = maxi(value, v) if turn == 2 else mini(value, v)
	_memo[key] = value
	return value


static func winner(board: Array[int]) -> int:
	for line: Array in LINES:
		if board[line[0]] != 0 and board[line[0]] == board[line[1]] and board[line[1]] == board[line[2]]:
			return board[line[0]]
	return 0


## Fin de la partida: raya, empate o nada. Gana estrellas: ganar al nivel 1 o 2, o no perder contra el 3.
func _check_end() -> bool:
	var w := winner(_board)
	if w == 0 and _board.has(0):
		return false
	_playing = false
	var won := w == 1 or (w == 0 and _level == LEVELS.size() - 1)
	if w != 0:
		_highlight(w)
	if won:
		Sfx.play("success")
		Fx.confetti(self, Vector3(0, 1.5, -4.0))
		Game.set_stars("ai", _level + 1)
		var text := "¡Empataste contra la IA perfecta! Minimax nunca pierde: es lo máximo posible." if w == 0 else "¡Ganaste a NOVA!"
		_say(text + "\nUsa el atril para jugar otra vez")
		if _level < LEVELS.size() - 1:
			_level += 1
			text += " Siguiente nivel: " + LEVELS[_level]
		Game.notify(text, Game.SUCCESS)
	else:
		Sfx.play("error")
		_nova_cheer()
		_say(("¡NOVA gana!" if w == 2 else "¡Empate!") + "\nUsa el atril para la revancha")
		Game.notify("Pista: amenaza dos rayas a la vez; NOVA solo puede tapar una." if _level == 1 else "¡Inténtalo otra vez!", Game.WARNING)
	await get_tree().create_timer(0.8).timeout
	return true


func _place(i: int, who: int) -> void:
	_board[i] = who
	var piece := Node3D.new()
	piece.position = _pos(i) + Vector3(0, 0.6, 0)
	add_child(piece)
	if who == 1:
		for a in [PI / 4, -PI / 4]:
			Kit.box(piece, Vector3(1.7, 0.3, 0.42), Vector3.ZERO, Kit.mat(Color("a5c5ff"), 0.5), Vector3(0, a, 0))
	else:
		Kit.torus(piece, 0.5, 0.85, Vector3.ZERO, Kit.mat(Game.info("ai").color, 0.5))
	Kit.bake(piece)
	_pieces[i] = piece
	Sfx.play("hop")
	create_tween().tween_property(piece, "scale", Vector3.ONE, 0.35).from(Vector3.ONE * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## La raya ganadora salta y brilla.
func _highlight(who: int) -> void:
	for line: Array in LINES:
		if line.all(func(i: int) -> bool: return _board[i] == who):
			for i: int in line:
				var hop := create_tween()
				hop.tween_property(_pieces[i], "position:y", 1.6, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				hop.tween_property(_pieces[i], "position:y", 0.6, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			return


func _nova_cheer() -> void:
	_robot.play("Cheer", 0.1)
	await get_tree().create_timer(1.6).timeout
	_robot.play("Idle", 0.3)


func _say(text: String) -> void:
	_sign.text = text


func _pos(i: int) -> Vector3:
	return Vector3((i % 3 - 1) * CELL, 0, -4.0 + (floori(i / 3.0) - 1) * CELL)
