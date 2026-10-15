class_name UI
## Piezas de interfaz compartidas por el HUD y los menús (en Unity cada menú tenía su propio CreateText/CreateButton).

const THEME := preload("res://ui/theme.tres")


static func label(text: String, variation := "", color := Color(0, 0, 0, 0)) -> Label:
	var node := Label.new()
	node.text = text
	if variation:
		node.theme_type_variation = StringName(variation)
	if color.a > 0.0:
		node.add_theme_color_override("font_color", color)
	return node


static func button(text: String, on_pressed: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.mouse_entered.connect(Sfx.play.bind("hover"))
	node.focus_entered.connect(Sfx.play.bind("hover"))
	node.pressed.connect(Sfx.play.bind("click"))
	node.pressed.connect(on_pressed)
	return node


static func spacer(horizontal: bool) -> Control:
	var node := Control.new()
	if horizontal:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node


## Capa de menú a pantalla completa: fondo oscurecido + contenido centrado. Devuelve el contenedor centrado.
static func overlay(layer: CanvasLayer, dim := 0.6) -> CenterContainer:
	var root := Control.new()
	root.theme = THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	return center


## Vacía un contenedor sin borrar nodos al instante: si el botón pulsado está dentro, borrarlo con free()
## mientras emite su señal cuelga Godot (era el cierre al responder en Energía solar).
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Entrada con rebote: el panel crece desde el 80 % con un pequeño exceso.
static func pop(control: Control) -> void:
	control.pivot_offset = control.get_combined_minimum_size() / 2.0
	control.scale = Vector2.ONE * 0.8
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.15)


## El HUD nunca debe tragarse el ratón: con el cursor capturado está fijo en el centro de la pantalla
## y cualquier Control ahí impedía que la cámara recibiera el movimiento.
static func ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)


## Da el foco del teclado al botón un fotograma después (cuando ya está colocado), salvo que su página
## haya sido reemplazada entretanto.
static func focus(control: Control) -> void:
	(func() -> void: if control.is_inside_tree(): control.grab_focus()).call_deferred()


static func stars(count: int) -> String:
	return "★".repeat(count) + "☆".repeat(3 - count)
