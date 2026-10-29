class_name Bolt
extends Area3D
## Tuerca dorada coleccionable (estilo Astro Bot): flota girando en sitios a los que se llega saltando o con
## el jetpack. Tocarla la guarda en `Game.bolts`; las ya recogidas no vuelven a aparecer.

var id := ""


## Pone la tuerca `bolt_id` en `pos` (coordenadas de `parent`), salvo que ya se haya recogido.
static func spawn(parent: Node3D, bolt_id: String, pos: Vector3) -> void:
	if Game.bolts.has(bolt_id):
		return
	var bolt := Bolt.new()
	bolt.id = bolt_id
	bolt.position = pos
	parent.add_child(bolt)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = 0.8
	add_child(shape)
	var nut := Node3D.new()
	add_child(nut)
	Kit.cylinder(nut, 0.36, 0.36, 0.16, Vector3.ZERO, Kit.mat(Game.WARNING, 1.2, 0.8, 0.2), 6, Vector3(PI / 2, 0, 0))
	Kit.cylinder(nut, 0.15, 0.15, 0.18, Vector3.ZERO, Kit.mat(Color("6b4a10"), 0.0, 0.6, 0.3), 12, Vector3(PI / 2, 0, 0))
	Kit.bake(nut)  # una sola malla: un draw call por tuerca
	nut.create_tween().set_loops().tween_property(nut, "rotation:y", TAU, 1.6).from(0.0)
	var bob := nut.create_tween().set_loops()
	bob.tween_property(nut, "position:y", 0.15, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(nut, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	Game.collect_bolt(id)
	Sfx.play("pickup", 0.05)
	Fx.burst(get_parent(), position, [Game.WARNING, Color.WHITE, Color("ffe08a")], 30, 5.0, 0.12)
	Game.notify("¡Tuerca dorada! %d / %d" % [Game.bolts.size(), Game.BOLTS_TOTAL], Game.WARNING)
	queue_free()
