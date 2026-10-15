class_name Fx
## Efectos compartidos por todos los retos: estallidos de partículas, sacudida de cámara y piezas que
## revientan en trozos con física real.

static var _confetti_material: StandardMaterial3D


## Estallido de una sola vez (confeti, chispas, polvo, agua…); se borra solo al terminar.
static func burst(parent: Node3D, pos: Vector3, colors: Array, amount := 40, speed := 6.0, size := 0.14) -> void:
	if not _confetti_material:
		_confetti_material = StandardMaterial3D.new()
		_confetti_material.vertex_color_use_as_albedo = true
		_confetti_material.roughness = 0.3
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 1.4
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14, 0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, size, size * 0.3)
	p.mesh = mesh
	p.material_override = _confetti_material
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(colors)
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT  # cada partícula, un color puro
	p.color_initial_ramp = ramp
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func confetti(parent: Node3D, pos: Vector3) -> void:
	burst(parent, pos, [Color("ffcc00"), Color("2ec4ff"), Color("ff4f8b"), Color("4cd964"), Color.WHITE], 70, 9.0)


static func shake(node: Node, strength := 0.4) -> void:
	node.get_tree().get_first_node_in_group("player").shake(strength)


## Reemplaza una caja por 6 trozos con física que salen despedidos y desaparecen a los 3 s.
static func shatter(piece: Node3D, size: Vector3, material: Material, push := Vector3(0, 4, 0)) -> void:
	var parent := piece.get_parent()
	var origin := piece.global_transform
	piece.queue_free()
	for i in 6:
		var body := RigidBody3D.new()
		var chunk := size * Vector3(0.33, 1.0, 0.5)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = chunk
		body.add_child(shape)
		Kit.box(body, chunk, Vector3.ZERO, material)
		parent.add_child(body)
		body.global_transform = origin.translated_local(Vector3((i % 3 - 1) * chunk.x, 0, (int(i / 3.0) - 0.5) * chunk.z))
		body.apply_impulse(push + Vector3(randf_range(-3, 3), randf_range(0, 3), randf_range(-3, 3)))
		body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		body.get_tree().create_timer(3.0).timeout.connect(body.queue_free)
