extends Control
## Minimapa del HUD (arriba a la derecha): norte arriba, centrado en el jugador, ~60 m de radio.
## Solo `_draw()`, sin SubViewport ni cámara extra: unas decenas de primitivas por fotograma (Radeon 610M).
## Dibuja los retos (cuadrado de su color con sus ★), el cohete, la terminal del STEAM LAB, las tuercas que
## faltan y, en rojo, el siguiente objetivo de la historia; si queda fuera, una flecha roja en el borde.
## Las escenas registran sus puntos con `add_point` (city.gd, moon.gd); las tuercas se leen del grupo "bolt".

const RADIUS := 60.0  # metros del centro al borde
const GRID := 8.0  # metros entre puntos de la rejilla («dot signal»)
const SIZE := 320.0

var moon := false
var _points: Array[Array] = []  # [posición, id]: id de reto, "rocket" o "lab"
var _last_state := []


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_point(pos: Vector3, id: String) -> void:
	_points.append([pos, id])


## Redibuja solo si algo cambió (jugador, cámara, tuercas o estrellas): quieto, no cuesta nada.
func _process(_delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var camera := get_viewport().get_camera_3d()
	if not player or not camera:
		return
	var state := [player.global_position.snapped(Vector3.ONE * 0.05), snappedf(camera.global_rotation.y, 0.01),
		get_tree().get_node_count_in_group("bolt"), Game.stars.hash()]
	if state != _last_state:
		_last_state = state
		queue_redraw()


## Posición (mundo) del siguiente objetivo según la historia, la más cercana a `from`; Vector3.INF si no hay.
func target(from: Vector3) -> Vector3:
	var candidates: Array[Vector3] = []
	var step := Game.story_step(moon)
	for point: Array in _points:
		var id: String = point[1]
		var stars := int(Game.stars.get(id, 0))
		var wanted := false
		match step:
			"estrellas":
				wanted = Game.MODULES.has(id) and stars < 3
			"lanzar", "volver":
				wanted = id == "rocket"
			"hielo":
				wanted = Game.MOON_MODULES.has(id) and stars == 0
			"todo":
				wanted = (Game.MODULES.has(id) or Game.LAB_MODULES.has(id) or Game.MOON_MODULES.has(id)) and stars < 3
		if wanted:
			candidates.append(point[0])
	if step == "todo":
		for bolt: Node3D in get_tree().get_nodes_in_group("bolt"):
			candidates.append(bolt.global_position)
	var best := Vector3.INF
	for pos in candidates:
		if best == Vector3.INF or _flat(pos - from) < _flat(best - from):
			best = pos
	return best


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length_squared()


func _draw() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var rect := Rect2(Vector2.ZERO, size)
	get_theme_stylebox("panel", "PanelContainer").draw(get_canvas_item(), rect)
	if not player:
		return
	var origin := player.global_position
	var center := size / 2.0
	var zoom := (minf(size.x, size.y) / 2.0 - 8.0) / RADIUS
	var to_map := func(p: Vector3) -> Vector2: return center + Vector2(p.x - origin.x, p.z - origin.z) * zoom
	var inner := rect.grow(-12.0)

	# Rejilla de puntos anclada al mundo: al andar se desliza y se nota el movimiento.
	var step := GRID * zoom
	var first := Vector2(fposmod(-origin.x * zoom + center.x, step), fposmod(-origin.z * zoom + center.y, step))
	var x := first.x
	while x < size.x:
		var y := first.y
		while y < size.y:
			draw_rect(Rect2(x - 1.0, y - 1.0, 2.0, 2.0), Game.LINE_STRONG)
			y += step
		x += step

	var font := get_theme_font("font", "Mono")
	for bolt: Node3D in get_tree().get_nodes_in_group("bolt"):
		var at: Vector2 = to_map.call(bolt.global_position)
		if inner.has_point(at):
			draw_circle(at, 2.5, Game.MUTED)
	for point: Array in _points:
		var at: Vector2 = to_map.call(point[0])
		if not inner.has_point(at):
			continue
		var id: String = point[1]
		match id:
			"rocket":
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(6, 4), at + Vector2(0, 1), at + Vector2(-6, 4)]), Game.INK)
			"lab":
				draw_arc(at, 7.0, 0.0, TAU, 24, Game.INK_2, 1.5, true)
			_:
				draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), Game.info(id).color)
				draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), Game.BG, false, 1.0)
				draw_string(font, at + Vector2(-30, 22), UI.stars(int(Game.stars.get(id, 0))), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Game.INK_2)

	var goal := target(origin)
	if goal != Vector3.INF:
		var at: Vector2 = to_map.call(goal)
		if inner.has_point(at):
			draw_arc(at, 11.0, 0.0, TAU, 32, Game.ACCENT, 2.0, true)
		else:  # flecha en el borde, apuntando hacia el objetivo
			var dir := (at - center).normalized()
			var reach := minf(absf((inner.size.x / 2.0) / dir.x) if dir.x else INF, absf((inner.size.y / 2.0) / dir.y) if dir.y else INF)
			var tip := center + dir * reach
			var wing := dir.orthogonal() * 6.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12.0 + wing, tip - dir * 12.0 - wing]), Game.ACCENT)

	# Jugador: triángulo que apunta hacia donde mira la cámara.
	var forward := Vector2(0, -1)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var f := -camera.global_basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			forward = Vector2(f.x, f.z).normalized()
	var side := forward.orthogonal() * 6.0
	draw_colored_polygon(PackedVector2Array([center + forward * 10.0, center - forward * 6.0 + side, center - forward * 3.0, center - forward * 6.0 - side]), Game.INK)
	draw_string(font, Vector2(0, 22), "N", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Game.MUTED)
