class_name RobotModel
extends Node3D
## Robot animado de Ciudad STEAM: «RobotExpressive» de Quaternius (CC0, models/robot/) con 14 animaciones,
## recoloreado con el color de acento de cada personaje y con los ojos encendidos. Opcionalmente lleva el
## jetpack (models/jetpack.glb, de art/jetpack.py) colgado del hueso del torso. Mira hacia +Z y mide ~2 m.
## `play()` usa los nombres del juego (Idle, Walk, Run, Jump, Fall, Fly, Land, Wave, Dance, Cheer, Sit, Point).

const SCENE := preload("res://models/robot/robot_expressive.glb")
const JETPACK := preload("res://models/jetpack.glb")
const GAUGE_SHADER := preload("res://core/gauge.gdshader")
const SCALE := 0.39  # el modelo viene en otra unidad: así mide ~2 m
const BACK := Vector3(0, 1.05, -0.3)  # dónde va el jetpack (en el robot, antes de escalar nada)
## nombre en el juego -> [animación del modelo, en bucle, inicio (s), congelada]
const CLIPS := {
	"Idle": ["Idle", true], "Walk": ["Walking", true], "Run": ["Running", true], "Jump": ["Jump", false],
	"Fall": ["Jump", false, 0.32, true], "Fly": ["WalkJump", false, 0.3, true], "Land": ["Jump", false, 0.5],
	"Wave": ["Wave", true], "Dance": ["Dance", true], "Cheer": ["ThumbsUp", false], "Sit": ["Sitting", false],
	"Point": ["Punch", false], "Yes": ["Yes", false], "No": ["No", false],
}

var nozzles: Array[Node3D] = []  # toberas del jetpack (donde van las llamas); vacío sin jetpack
var current := ""
var _animations: AnimationPlayer
var _gauge: ShaderMaterial
var _eyes: Color


## Robot de color `accent` con ojos `eyes`, ya colgado de `parent` y en reposo.
static func create(parent: Node3D, accent: Color, eyes := Color("35b8ff"), jetpack := false) -> RobotModel:
	var robot := RobotModel.new()
	parent.add_child(robot)
	robot._build(accent, eyes, jetpack)
	return robot


func _build(accent: Color, eyes: Color, jetpack: bool) -> void:
	_eyes = eyes
	var model: Node3D = SCENE.instantiate()
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	_animations = model.get_node("AnimationPlayer")
	for clip: Array in CLIPS.values():
		_animations.get_animation(clip[0]).loop_mode = Animation.LOOP_LINEAR if clip[1] else Animation.LOOP_NONE
	_paint(model, accent, eyes)
	if jetpack:
		_add_jetpack(model, accent, eyes)
	play("Idle", 0.0)


func _paint(model: Node3D, accent: Color, eyes: Color) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(i)
			var material: Material
			match source.resource_name:
				"Main", "Accent":
					material = Kit.mat(accent, 0.0, 0.1, 0.25)
				"Glow":
					material = Kit.mat(eyes, 3.0)
				"Gauge":
					_gauge = ShaderMaterial.new()
					_gauge.shader = GAUGE_SHADER
					_gauge.set_shader_parameter("color", eyes)
					material = _gauge
				_:
					material = Kit.toy(source)
			mesh.set_surface_override_material(i, material)


## El jetpack va en un BoneAttachment3D del torso, colocado respecto a la pose de reposo de ese hueso: así
## sigue al torso en todas las animaciones.
func _add_jetpack(model: Node3D, accent: Color, eyes: Color) -> void:
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "Torso_2"
	skeleton.add_child(attachment)
	var pack: Node3D = JETPACK.instantiate()
	attachment.add_child(pack)
	var bone_rest := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("Torso_2"))
	pack.transform = bone_rest.affine_inverse() * global_transform * Transform3D(Basis(), BACK)
	_paint(pack, accent, eyes)
	for side in ["L", "R"]:
		nozzles.append(pack.find_child("Nozzle" + side, true, false))


## Cambia de animación (mezclando `blend` s) y ajusta su velocidad; volver a pedir la actual solo cambia la velocidad.
func play(anim: String, blend := 0.15, speed := 1.0) -> void:
	var clip: Array = CLIPS[anim]
	if anim != current:
		current = anim
		_animations.play(clip[0], blend, 0.0 if clip.size() > 3 else 1.0)  # congelada con custom_speed: speed_scale = 0 también paraba la mezcla
		if clip.size() > 2:
			_animations.seek(clip[2], true)
	_animations.speed_scale = speed


## Franja de combustible: llena (1) a vacía (0); en rojo si queda poco.
func set_fuel(fraction: float, low: bool) -> void:
	if _gauge:
		_gauge.set_shader_parameter("fill", fraction)
		_gauge.set_shader_parameter("color", Game.ACCENT if low else _eyes)
