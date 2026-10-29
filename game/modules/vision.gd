extends Node3D
## Reto Visión IA: para una cámara, una imagen es una cuadrícula de números. Cada baldosa de la cuadrícula
## de 5 × 5 es un píxel: pisarla la enciende (1) o la apaga (0); salta o vuela con el jetpack para no
## pisar las que no quieres. E en la cámara: la IA compara tu dibujo con los ejemplos que aprendió, dice
## qué ve y con qué seguridad. Cada figura reconocida (≥ 70 %) es una estrella. Mira a la plaza (+Z).

const N := 5
const TILE := 1.5
const CONFIDENCE := 70  # % mínimo para dar la figura por reconocida
const SHAPES := {  # lo que la IA aprendió; la primera fila es la del fondo (la que queda lejos al llegar)
	"CRUZ": "..#.. ..#.. ##### ..#.. ..#..",
	"EQUIS": "#...# .#.#. ..#.. .#.#. #...#",
	"CUADRADO": "##### #...# #...# #...# #####",
	"FLECHA": "..#.. .###. #.#.# ..#.. ..#..",
	"CORAZÓN": ".#.#. ##### ##### .###. ..#..",
}
const GOALS := ["CRUZ", "CUADRADO", "FLECHA"]  # figura de la 1.ª, 2.ª y 3.ª estrella
const OFF := Color(0.23, 0.26, 0.32, 0.0)

var _pixels: Array[int] = []
var _level := 0
var _playing := false
var _busy := false
var _standing := Vector2i(-1, -1)  # baldosa pisada: cambia al entrar en otra o al volver a caer en ella
var _grid := MultiMeshInstance3D.new()
var _stand: Interactable
var _board: Label3D
var _matrix: Label3D
var _results: Label3D
var _scanner: MeshInstance3D
var _player: CharacterBody3D


func _ready() -> void:
	var color: Color = Game.info("vision").color
	_level = mini(int(Game.stars.get("vision", 0)), GOALS.size() - 1)
	_player = get_tree().get_first_node_in_group("player")
	_pixels.resize(N * N)
	var pixels := MultiMesh.new()  # 25 baldosas, un solo draw call
	pixels.transform_format = MultiMesh.TRANSFORM_3D
	pixels.use_colors = true
	pixels.mesh = Kit.rounded(Vector3(TILE * 0.9, 0.08, TILE * 0.9))
	pixels.instance_count = N * N
	for i in N * N:
		pixels.set_instance_transform(i, Transform3D(Basis(), _pos(i) + Vector3(0, 0.22, 0)))  # sobre la plataforma (0,16 m)
	_grid.multimesh = pixels
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://modules/pixel.gdshader")
	_grid.material_override = paint
	add_child(_grid)
	_draw(SHAPES["CORAZÓN"])  # dibujo de muestra hasta que empiece el reto
	Kit.box(self, Vector3(N * TILE + 0.5, 0.04, N * TILE + 0.5), Vector3(0, 0.18, -4.0), Kit.mat(Color("2a2c33")))
	_stand = Kit.stand(self, Vector3(-5.2, 0, 2.0), color, "RETO: VISIÓN IA")
	_stand.interacted.connect(_on_stand)
	Kit.box(self, Vector3(0.9, 0.5, 0.5), Vector3(5.2, 0.25, 2.0), Kit.mat(Color("ffd9e6")))  # goma de borrar gigante
	Kit.box(self, Vector3(0.9, 0.2, 0.52), Vector3(5.2, 0.4, 2.0), Kit.mat(Color("abe7ff")))
	Kit.collider(self, Vector3(0.9, 0.6, 0.5), Vector3(5.2, 0.3, 2.0))
	Kit.interactable(self, "BORRAR EL DIBUJO", Vector3(5.2, 0.6, 2.0), 1.6).interacted.connect(func() -> void: if not _busy: _clear())
	_camera_model(color)
	_scanner = Kit.box(self, Vector3(N * TILE, 0.06, 0.25), Vector3(0, 0.4, 0), Kit.mat(Color(color, 0.7), 3.0))
	_scanner.visible = false
	_scanner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.bake(self, [_scanner])
	_show_goal()


## Cámara de la IA en un trípode al fondo y su pantalla: a la izquierda los números que ve, a la derecha qué cree que es.
func _camera_model(color: Color) -> void:
	var white := Kit.mat(Color("f4f7fb"))
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		Kit.cylinder(self, 0.06, 0.08, 2.6, Vector3(sin(a) * 0.6, 1.2, -8.9 + cos(a) * 0.6), Kit.mat(Color("3a4352")), 8,
			Vector3(cos(a) * 0.25, 0, -sin(a) * 0.25))
	Kit.box(self, Vector3(1.8, 1.2, 1.1), Vector3(0, 2.9, -8.9), white)
	Kit.box(self, Vector3(0.5, 0.25, 0.5), Vector3(-0.4, 3.6, -8.9), Kit.mat(color))
	Kit.cylinder(self, 0.5, 0.55, 0.6, Vector3(0, 2.9, -8.1), Kit.mat(Color("3a4352")), 24, Vector3(PI / 2, 0, 0))
	Kit.sphere(self, 0.42, Vector3(0, 2.9, -7.8), Kit.mat(Color("090a0c"), 0.0, 0.3, 0.03), Vector3(1, 1, 0.4))
	Kit.sphere(self, 0.14, Vector3(0, 2.9, -7.65), Kit.mat(color, 4.0), Vector3(1, 1, 0.4))  # iris encendido
	Kit.collider(self, Vector3(1.8, 3.4, 1.4), Vector3(0, 1.7, -8.8))
	Kit.box(self, Vector3(8.4, 3.8, 0.3), Vector3(0, 6.3, -9.3), Kit.mat(Color("2a2c33")))
	Kit.box(self, Vector3(8.7, 0.25, 0.4), Vector3(0, 8.25, -9.3), Kit.mat(color))
	for x in [-3.8, 3.8]:
		Kit.cylinder(self, 0.12, 0.12, 4.4, Vector3(x, 2.2, -9.4), white, 10)
	_board = Kit.label(self, "", Vector3(0, 7.6, -9.1), 52, Color.WHITE, false, 0.01, 8.0)
	_matrix = Kit.label(self, "", Vector3(-2.2, 5.7, -9.1), 38, Color("d9f6ff"), false, 0.01)
	_results = Kit.label(self, "", Vector3(1.9, 5.7, -9.1), 40, Color.WHITE, false, 0.01, 4.0)


func _on_stand() -> void:
	if _busy:
		return
	if not _playing:
		_playing = true
		_stand.prompt = "ANALIZAR EL DIBUJO"
		_clear()
		Sfx.play("pickup")
		Game.notify("Pisa las baldosas para encender píxeles. Salta (o usa el jetpack) para no pisar las que no quieres.", Game.INK)
		_show_goal()
	else:
		_analyze()


func _physics_process(_delta: float) -> void:
	if not _playing or _busy:
		return
	var local := to_local(_player.global_position)
	var cell := Vector2i(roundi(local.x / TILE + 2.0), roundi((local.z + 4.0) / TILE + 2.0))
	if not _player.is_on_floor() or cell.x < 0 or cell.y < 0 or cell.x >= N or cell.y >= N:
		_standing = Vector2i(-1, -1)  # en el aire: al caer en la misma baldosa, cambia otra vez
		return
	if cell != _standing:
		_standing = cell
		toggle(cell.y * N + cell.x)


func toggle(i: int) -> void:
	_pixels[i] = 1 - _pixels[i]
	_paint(i)
	Sfx.play("hop" if _pixels[i] else "click", 0.1)
	_show_matrix()


## La IA compara el dibujo con cada figura aprendida (píxeles en común / píxeles encendidos en alguno de
## los dos) y reparte su seguridad entre todas: cuanto más parecido, mucha más seguridad (exponencial).
static func classify(pixels: Array) -> Array:
	var scores := {}
	var total := 0.0
	for shape: String in SHAPES:
		var model: String = SHAPES[shape].replace(" ", "")
		var both := 0
		var either := 0
		for i in pixels.size():
			both += int(model[i] == "#" and pixels[i] == 1)
			either += int(model[i] == "#" or pixels[i] == 1)
		scores[shape] = exp(8.0 * both / maxf(either, 1.0))
		total += scores[shape]
	var ranking := scores.keys().map(func(shape: String) -> Array: return [shape, roundi(100.0 * scores[shape] / total)])
	ranking.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return ranking


func _analyze() -> void:
	_busy = true
	Sfx.play("whoosh")
	_scanner.visible = true
	await create_tween().tween_property(_scanner, "position:z", -0.25, 1.0).from(-7.75).finished
	_scanner.visible = false
	var ranking := classify(_pixels)
	var lines := PackedStringArray()
	for guess: Array in ranking.slice(0, 3):
		lines.append("%s  %d %%" % guess)
	_results.text = "LA IA CREE QUE ES:\n" + "\n".join(lines)
	var goal: String = GOALS[_level]
	if ranking[0][0] == goal and ranking[0][1] >= CONFIDENCE:
		Sfx.play("success")
		Fx.confetti(self, Vector3(0, 1, -4.0))
		Game.set_stars("vision", _level + 1)
		Game.notify("¡La IA reconoce tu dibujo: %s, con un %d %% de seguridad!" % [goal, ranking[0][1]], Game.SUCCESS)
		await get_tree().create_timer(2.0).timeout
		if _level < GOALS.size() - 1:
			_level += 1
			_clear()
		else:
			_playing = false
			_stand.prompt = "RETO: VISIÓN IA"
		_show_goal()
	else:
		Sfx.play("error")
		Game.notify("La IA ve %s al %d %%. Para la estrella tiene que ver %s al %d %% o más: ¡corrige el dibujo!"
			% [ranking[0][0], ranking[0][1], goal, CONFIDENCE], Game.WARNING)
	_busy = false


func _show_goal() -> void:
	if not _playing:
		_board.text = "VISIÓN IA · usa el atril" if int(Game.stars.get("vision", 0)) < 3 else "¡LA IA RECONOCE TODAS TUS FIGURAS!"
		_results.text = "Para la IA, una imagen\nes una cuadrícula\nde números"
	else:
		_board.text = "DIBUJA:  %s  (%d / %d)" % [GOALS[_level], _level + 1, GOALS.size()]
		_results.text = "Pisa las baldosas\ny usa el atril\npara que la IA mire"
	_show_matrix()


func _clear() -> void:
	_pixels.fill(0)
	for i in N * N:
		_paint(i)
	_show_matrix()


func _draw(shape: String) -> void:
	var model := shape.replace(" ", "")
	for i in N * N:
		_pixels[i] = int(model[i] == "#")
		_paint(i)


func _paint(i: int) -> void:
	_grid.multimesh.set_instance_color(i, Color(Game.info("vision").color, 1.0) if _pixels[i] else OFF)


## Los números que "ve" la cámara: 1 = píxel encendido.
func _show_matrix() -> void:
	var rows := PackedStringArray()
	for r in N:
		rows.append(" ".join(_pixels.slice(r * N, r * N + N).map(func(p: int) -> String: return str(p))))
	_matrix.text = "\n".join(rows)


func _pos(i: int) -> Vector3:
	return Vector3((i % N - 2) * TILE, 0, -4.0 + (floori(i / float(N)) - 2) * TILE)
