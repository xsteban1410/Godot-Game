extends Node3D
## Reto lunar "Energía de la base": girar piezas de cable (E) para llevar la luz de los paneles solares
## al fundidor de hielo. El cable encendido se ve dorado hasta donde llega la corriente. El camino
## solución se genera al azar (siempre hay solución) y las piezas se barajan girándolas.
## 3 niveles = 3 estrellas. La cuadrícula crece hacia −Z; se coloca mirando al jugador (+Z).

const TILE := 1.7
const LEVELS := [Vector2i(4, 3), Vector2i(5, 4), Vector2i(6, 5)]
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]  # N, E, S, O
const SHAPES := {"I": [0, 2], "L": [0, 1]}  # lados conectados sin girar
static var _wire := Kit.mat(Color("8a96a8"), 0.0, 0.6, 0.3)  # cable apagado

var _level := 0
var _size := Vector2i()
var _start := Vector2i()
var _end := Vector2i()
var _path: Array[Vector2i] = []  # el camino solución (lo usa la autocomprobación)
var _tiles := {}  # Vector2i -> {"shape", "turns", "pivot", "cable"}
var _grid := Node3D.new()
var _melter: MeshInstance3D
var _busy := false


func _ready() -> void:
	_level = mini(int(Game.stars.get("moon_power", 0)), LEVELS.size() - 1)
	_grid.position.y = 0.1  # sobre la plataforma del reto (si no, las casillas quedaban hundidas)
	add_child(_grid)
	Kit.banner(self, "ENERGÍA DE LA BASE", Vector3(0, 5.0, 2.0), 110, Game.info("moon_power").color)
	Kit.banner(self, "E en un cable: girarlo. Lleva la luz al fundidor de hielo.", Vector3(0, 4.0, 2.0), 46, Color.WHITE)
	_new_grid()


func _new_grid() -> void:
	_size = LEVELS[_level]
	_start = Vector2i(0, randi() % _size.y)
	_end = Vector2i(_size.x - 1, randi() % _size.y)
	var path := _random_path()
	_path = path
	UI.clear(_grid)
	_tiles.clear()
	for x in _size.x:
		for y in _size.y:
			var cell := Vector2i(x, y)
			var i := path.find(cell)
			var shape: String = ["I", "L"][randi() % 2]
			if i >= 0:  # en el camino: la forma que une el lado de entrada con el de salida
				var entry := 3 if i == 0 else DIRS.find(path[i - 1] - cell)
				var exit := 1 if i == path.size() - 1 else DIRS.find(path[i + 1] - cell)
				shape = "I" if (entry + 2) % 4 == exit else "L"
			_add_tile(cell, shape, randi() % 4)
	while _lit().has(_end):  # nunca empezar ya resuelto (una L puede necesitar dos giros)
		_turn(path[0])
	# Fuente (paneles solares) a la izquierda y fundidor a la derecha.
	var source := _pos(_start) + Vector3(-TILE * 1.3, 0, 0)
	for k in 3:
		Kit.box(_grid, Vector3(1.0, 0.06, 1.5), source + Vector3(-k * 1.1, 1.0, 0), Kit.mat(Color("1d3f8f"), 0.3, 0.6, 0.08), Vector3(0, 0, 0.5))
	Kit.box(_grid, Vector3(0.3, 0.12, TILE * 0.5), _pos(_start) + Vector3(-TILE * 0.75, 0.12, 0), Kit.mat(Game.GOLD, 3.0), Vector3(0, PI / 2, 0))
	var target := _pos(_end) + Vector3(TILE * 1.4, 0, 0)
	Kit.cylinder(_grid, 0.9, 1.0, 1.8, target + Vector3(0, 0.9, 0), Kit.mat(Color("f4f7fb")), 24)
	_melter = Kit.cylinder(_grid, 0.55, 0.55, 1.0, target + Vector3(0, 1.3, 0.0), Kit.mat(Color(0.6, 0.95, 1.0, 0.8), 0.5, 0.0, 0.05), 6)
	Kit.label(_grid, "FUNDIDOR", target + Vector3(0, 2.6, 0), 56, Color.WHITE)
	Kit.bake(_grid, [_melter])
	_refresh()


## Camino aleatorio sin repetir casillas del inicio al final (búsqueda en profundidad con orden al azar).
func _random_path() -> Array[Vector2i]:
	var path: Array[Vector2i] = [_start]
	var seen := {_start: true}
	while path.back() != _end:
		var options := DIRS.map(func(d: Vector2i) -> Vector2i: return path.back() + d).filter(
			func(c: Vector2i) -> bool: return _inside(c) and not seen.has(c))
		if options.is_empty():
			path.pop_back()  # callejón sin salida: retroceder
			continue
		var next: Vector2i = options.pick_random()
		seen[next] = true
		path.append(next)
	return path


func _add_tile(cell: Vector2i, shape: String, turns: int) -> void:
	var p := _pos(cell)
	Kit.box(_grid, Vector3(TILE * 0.94, 0.1, TILE * 0.94), p + Vector3(0, 0.05, 0), Kit.mat(Color("3a4352"), 0.0, 0.3, 0.4))
	var pivot := Node3D.new()
	pivot.position = p + Vector3(0, 0.12, 0)
	pivot.rotation.y = -turns * PI / 2
	_grid.add_child(pivot)
	Kit.sphere(pivot, 0.2, Vector3.ZERO, _wire)
	for side: int in SHAPES[shape]:
		var d: Vector2i = DIRS[side]
		Kit.box(pivot, Vector3(0.28, 0.14, 0.28) + Vector3(absf(d.x), 0, absf(d.y)) * TILE * 0.22, Vector3(d.x, 0, -d.y) * TILE * 0.25, _wire)
	Kit.bake(pivot)  # el cable entero es una sola malla: encenderlo es cambiar un material
	var area := Kit.interactable(_grid, "GIRAR CABLE", p + Vector3(0, 0.6, 0), 0.75)
	area.marker_height = 1.2
	area.interacted.connect(_on_turn.bind(cell))
	_tiles[cell] = {"shape": shape, "turns": turns, "pivot": pivot, "cable": pivot.get_child(0), "tween": null}


func _on_turn(cell: Vector2i) -> void:
	if _busy:
		return
	_turn(cell)
	Sfx.play("click")
	_refresh()


func _turn(cell: Vector2i) -> void:
	var tile: Dictionary = _tiles[cell]
	tile.turns = (tile.turns + 1) % 4
	if tile.tween:
		tile.tween.kill()  # un giro a medias acaba de golpe: lo que se ve sigue siempre a `turns`
	tile.pivot.rotation.y = -(tile.turns - 1) * PI / 2
	tile.tween = create_tween()
	tile.tween.tween_property(tile.pivot, "rotation:y", -tile.turns * PI / 2, 0.15).set_trans(Tween.TRANS_BACK)


func _sides(cell: Vector2i) -> Array:
	var tile: Dictionary = _tiles[cell]
	return SHAPES[tile.shape].map(func(s: int) -> int: return (s + tile.turns) % 4)


## Casillas a las que llega la corriente desde los paneles (entra por el oeste de la primera).
func _lit() -> Dictionary:
	var lit := {}
	if not 3 in _sides(_start):
		return lit
	var queue: Array[Vector2i] = [_start]
	lit[_start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for side: int in _sides(cell):
			var next: Vector2i = cell + DIRS[side]
			if _inside(next) and not lit.has(next) and (side + 2) % 4 in _sides(next):
				lit[next] = true
				queue.append(next)
	return lit


func _refresh() -> void:
	var lit := _lit()
	for cell: Vector2i in _tiles:
		_tiles[cell].cable.material_override = Kit.mat(Game.GOLD, 3.0) if lit.has(cell) else _wire
	if lit.has(_end) and 1 in _sides(_end):
		_solved()


func _solved() -> void:
	_busy = true
	_melter.material_override = Kit.mat(Color("2ec4ff"), 3.0)
	Sfx.play("success")
	Fx.confetti(self, _melter.position + Vector3(0, 1, 0))
	Game.set_stars("moon_power", _level + 1)
	Game.notify("¡Energía! En la Luna no hay nubes: los paneles solares reciben luz todo el día lunar.", Game.GOLD)
	await get_tree().create_timer(2.0).timeout
	_level = mini(_level + 1, LEVELS.size() - 1)  # tras el último nivel, otro tablero igual (antes se quedaba resuelto y repetía el premio)
	_new_grid()
	_busy = false


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


func _pos(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (_size.x - 1) / 2.0) * TILE, 0, -1.5 - cell.y * TILE)
