extends Node3D
## Reto lunar "Purificador": llenar la columna del filtro capa a capa (E en cada material) y verter el
## agua del hielo derretido. Desde abajo: carbón activado, arena y grava arriba (la grava frena lo grueso,
## la arena lo fino y el carbón quita olores y sabores). Bien: agua limpia. Mal: agua turbia y explicación.
## Estrellas según los intentos. Se coloca mirando al jugador (+Z).

const LAYERS := {  # material -> color
	"CARBÓN ACTIVADO": Color("222831"),
	"ARENA": Color("e3d6bf"),
	"GRAVA": Color("9aa0a8"),
}
const CORRECT := ["CARBÓN ACTIVADO", "ARENA", "GRAVA"]  # de abajo arriba
const COLUMN := Vector3(0, 0, -3.5)

var _stack := []  # sin tipo, para compararlo directamente con CORRECT
var _layers: Array[Node3D] = []
var _tries := 0
var _tank: MeshInstance3D
var _busy := false


func _ready() -> void:
	Kit.banner(self, "PURIFICADOR DE AGUA", Vector3(0, 6.0, -1.0), 110, Game.info("moon_water").color)
	Kit.banner(self, "Llena el filtro desde abajo y vierte el agua del hielo", Vector3(0, 5.0, -1.0), 46, Color.WHITE)
	Kit.cylinder(self, 0.85, 0.85, 3.0, COLUMN + Vector3(0, 2.3, 0), Kit.mat(Color(0.75, 0.9, 1.0, 0.25), 0.0, 0.0, 0.03), 32)
	Kit.cylinder(self, 1.0, 1.0, 0.8, COLUMN + Vector3(0, 0.4, 0), Kit.mat(Color("f4f7fb")), 32)
	Kit.collider(self, Vector3(2, 4, 2), COLUMN + Vector3(0, 2, 0))
	_tank = Kit.cylinder(self, 0.9, 0.9, 0.1, COLUMN + Vector3(2.6, 0.6, 0), null, 24)  # el agua filtrada; se ve al verter
	_tank.visible = false
	Kit.cylinder(self, 1.0, 1.0, 1.4, COLUMN + Vector3(2.6, 0.7, 0), Kit.mat(Color(0.8, 0.9, 1.0, 0.2), 0.0, 0.0, 0.03), 24)
	var x := -4.5
	for material: String in ["GRAVA", "CARBÓN ACTIVADO", "ARENA"]:  # orden mezclado a propósito
		var crate := Vector3(x, 0, 0)
		Kit.box(self, Vector3(1.4, 0.8, 1.4), crate + Vector3(0, 0.4, 0), Kit.mat(Color("f4f7fb")))
		Kit.box(self, Vector3(1.2, 0.2, 1.2), crate + Vector3(0, 0.85, 0), Kit.mat(LAYERS[material], 0.0, 0.0, 0.9))
		Kit.collider(self, Vector3(1.4, 0.8, 1.4), crate + Vector3(0, 0.4, 0))
		Kit.label(self, material.replace(" ", "\n"), crate + Vector3(0, 1.6, 0), 44, Color.WHITE)  # "CARBÓN ACTIVADO" no cabe en 3 m
		Kit.interactable(self, "PONER CAPA DE " + material, crate + Vector3(0, 1, 0), 1.3).interacted.connect(_add.bind(material))
		x += 3.0
	Kit.interactable(self, "VERTER EL AGUA DEL HIELO", COLUMN + Vector3(-1.6, 1, 0.8), 1.4).interacted.connect(_pour)
	Kit.bake(self, [_tank])
	Bolt.spawn(self, "moon_water", COLUMN + Vector3(0, 4.8, 0))  # sobre la columna del filtro


func _add(material: String) -> void:
	if _busy:
		return
	if material in _stack or _stack.size() == 3:
		Game.notify("Esa capa ya está en el filtro." if material in _stack else "El filtro está lleno: vierte el agua.", Game.WARNING)
		return
	_stack.append(material)
	var target := COLUMN.y + 0.4 + _stack.size() * 0.8  # apoyada sobre la base o sobre la capa anterior
	var layer := Kit.cylinder(self, 0.78, 0.78, 0.8, COLUMN + Vector3(0, target + 3.0, 0), Kit.mat(LAYERS[material], 0.0, 0.0, 0.9), 32)
	_layers.append(layer)
	create_tween().tween_property(layer, "position:y", target, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sfx.play("hop")


func _pour() -> void:
	if _busy:
		return
	if _stack.size() < 3:
		Game.notify("Faltan capas: el filtro necesita las 3.", Game.WARNING)
		return
	_busy = true
	_tries += 1
	var clean := _stack == CORRECT
	Sfx.play("splash")
	Fx.burst(self, COLUMN + Vector3(0, 4, 0), [Color("bfe6ff"), Color.WHITE], 50, 3.0, 0.12)
	var color := Color(0.35, 0.75, 1.0, 0.75) if clean else Color(0.55, 0.42, 0.25, 0.85)
	_tank.material_override = Kit.mat(color, 0.6 if clean else 0.0, 0.0, 0.05)
	_tank.scale.y = 1.0
	_tank.visible = true
	await create_tween().tween_property(_tank, "scale:y", 12.0, 1.2).finished
	if clean:
		var stars := 3 if _tries == 1 else 2 if _tries == 2 else 1
		_tries = 0  # se puede repetir para mejorar la marca
		Sfx.play("success")
		Fx.confetti(self, COLUMN + Vector3(2.6, 2, 0))
		Game.notify("¡Agua limpia! Así recicla el agua la Estación Espacial: filtrar y volver a usar.", Game.SUCCESS)
		Game.set_stars("moon_water", stars)
	else:
		Sfx.play("error")
		Fx.shake(self, 0.3)
		Game.notify("Agua turbia. Arriba la grava frena lo grueso, en medio la arena atrapa lo fino y abajo el carbón quita olores.", Game.DANGER)
	await get_tree().create_timer(2.0).timeout
	for layer in _layers:  # filtro vacío para otro intento
		layer.queue_free()
	_layers.clear()
	_stack.clear()
	_tank.visible = false
	_busy = false
