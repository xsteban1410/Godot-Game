extends CanvasLayer
## HUD: minimapa con el objetivo y las estrellas por reto, aviso de interacción, notificaciones y celebraciones.

const MINIMAP := preload("res://ui/minimap.gd")
const SIDE := 320.0  # ancho de la columna derecha (minimapa y objetivos)
const TOAST_WIDTH := 1000.0  # los avisos largos se parten: así no tapan la columna derecha

var minimap: Control  # las escenas le dan sus puntos: minimap.add_point(posición, id)
var _objectives: VBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _key: Label  # tecla del aviso: E con teclado, X con mando
var _controls: Label  # línea de controles del último control usado
var _toasts: VBoxContainer
var _celebration := CanvasLayer.new()
var _shout_until := 0.0  # hasta cuándo (s de reloj) ocupa la pantalla el último rótulo de _shout
@export var moon := false  # en la Luna se listan los retos lunares

const KEYBOARD := "WASD MOVER  ·  RATÓN CÁMARA  ·  SHIFT CORRER  ·  ESPACIO SALTAR (EN EL AIRE: JETPACK)  ·  E USAR  ·  RUEDA ZOOM"
const GAMEPAD := "STICK IZQ. MOVER  ·  STICK DER. CÁMARA  ·  RB CORRER  ·  A SALTAR (EN EL AIRE: JETPACK)  ·  X USAR  ·  B CERRAR"


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.theme = UI.THEME
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	var side := VBoxContainer.new()  # arriba a la derecha: minimapa y, debajo, el objetivo y los retos
	side.theme = UI.THEME
	side.add_theme_constant_override("separation", 12)
	side.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 28)
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(side)
	minimap = MINIMAP.new()
	minimap.moon = moon
	side.add_child(minimap)
	var objectives_panel := PanelContainer.new()
	objectives_panel.custom_minimum_size.x = SIDE
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override("separation", 4)
	objectives_panel.add_child(_objectives)
	side.add_child(objectives_panel)

	_toasts = VBoxContainer.new()
	_toasts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_toasts)
	column.add_child(UI.spacer(false))

	_prompt = PanelContainer.new()
	_prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_prompt.add_child(row)
	var key := PanelContainer.new()
	key.theme_type_variation = &"KeyCap"
	_key = UI.label("E", "Mono", Game.INK)
	key.add_child(_key)
	row.add_child(key)
	_prompt_label = UI.label("")
	row.add_child(_prompt_label)
	column.add_child(_prompt)
	var controls := PanelContainer.new()  # sobre el suelo claro, el texto pequeño necesita su panel
	controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_controls = UI.label(KEYBOARD, "Caption")
	controls.add_child(_controls)
	column.add_child(controls)

	_celebration.layer = 50  # por encima de los paneles de los retos
	add_child(_celebration)
	Game.stars_changed.connect(_on_stars_changed)
	Game.bolts_changed.connect(_on_bolts_changed)
	Game.toast.connect(_show_toast)
	Game.prompt_changed.connect(_on_prompt_changed)
	_refresh_objectives()
	UI.ignore_mouse(margin)
	UI.ignore_mouse(side)


## El aviso y la línea de controles siguen al último control usado (el movimiento del ratón no cuenta: haría parpadear).
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_key.text = "X"
		_controls.text = GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton:
		_key.text = "E"
		_controls.text = KEYBOARD


func _on_prompt_changed(text: String) -> void:
	_prompt.visible = not text.is_empty()
	_prompt_label.text = text


## Objetivo de la historia y, debajo, cada reto con sus estrellas, las piezas del cohete y las tuercas.
func _refresh_objectives() -> void:
	UI.clear(_objectives)
	_objectives.add_child(UI.label("OBJETIVO", "Caption", Game.ACCENT))
	var text := UI.label(objective(moon))
	text.add_theme_font_size_override("font_size", 20)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objectives.add_child(text)
	_objectives.add_child(HSeparator.new())
	if moon:
		_challenge_rows(Game.MOON_MODULES)
	else:
		_challenge_rows(Game.MODULES)
		_objectives.add_child(_counter("COHETE", Game.total_stars(), 12))
		_challenge_rows(Game.LAB_MODULES)
	_objectives.add_child(_counter("TUERCAS", Game.bolts.size(), Game.BOLTS_TOTAL))
	UI.ignore_mouse(_objectives)


## El siguiente paso de la historia: piezas del cohete → la Luna → volver → completarlo todo.
static func objective(on_moon: bool) -> String:
	match Game.story_step(on_moon):
		"hielo":
			return "Busca hielo para el cohete: gana una ★ en cada reto lunar (%d / 4). Sigue las balizas de colores." % Game.moon_done()
		"volver":
			return "¡Ya tienes agua! Vuelve al cohete para regresar a la Tierra."
		"estrellas":
			return "Gana estrellas en los retos: cada una es una pieza del cohete (%d / 12)." % Game.total_stars()
		"lanzar":
			return "¡Cohete completo! Ve a la plataforma de lanzamiento (el haz de luz) y viaja a la Luna."
	return "Consigue todas las estrellas y las tuercas doradas (%d / %d) para el traje dorado." % [Game.bolts.size(), Game.BOLTS_TOTAL]


func _on_bolts_changed(_count: int) -> void:
	_refresh_objectives()
	if Game.golden():
		_shout("¡TRAJE DORADO!", Game.INK, "Encontraste las %d tuercas" % Game.BOLTS_TOTAL)


## Una fila por reto: cuadrado de su color (como en el minimapa), nombre y estrellas.
func _challenge_rows(modules: Dictionary) -> void:
	for id: String in modules:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.color = modules[id].color
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var label := UI.label(modules[id].name)
		label.add_theme_font_size_override("font_size", 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var stars := UI.label(UI.stars(int(Game.stars.get(id, 0))), "", Game.INK)
		stars.add_theme_font_size_override("font_size", 20)
		row.add_child(stars)
		_objectives.add_child(row)


## Contador técnico en mono: «COHETE        07 / 12».
func _counter(title: String, count: int, total: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := UI.label(title, "Caption")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(UI.label("%02d / %d" % [count, total], "Caption", Game.INK))
	return row


func _show_toast(text: String, color: Color) -> void:
	var panel := PanelContainer.new()
	var label := UI.label(text, "", color)
	if UI.THEME.default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.THEME.default_font_size).x > TOAST_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = TOAST_WIDTH
	panel.add_child(label)
	_toasts.add_child(panel)
	UI.ignore_mouse(panel)
	UI.pop(panel)
	var tween := panel.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)


## Rótulo grande en el centro que aparece con rebote y se desvanece; devuelve su columna para añadir más.
## Si ya hay otro en pantalla, espera a que se vaya (nunca dos encimados).
func _shout(text: String, color: Color, subtitle := "") -> VBoxContainer:
	var now := Time.get_ticks_msec() / 1000.0
	var wait := _shout_until - now
	_shout_until = maxf(_shout_until, now) + 3.3
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	var center := CenterContainer.new()
	center.theme = UI.THEME
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration.add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)
	var title := UI.label(text, "Title", color)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	if subtitle:
		var sub := UI.label(subtitle, "Title", Game.INK_2)
		sub.add_theme_constant_override("outline_size", 8)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(sub)
	UI.ignore_mouse(center)
	UI.pop(title, 0.28)
	var out := center.create_tween()
	out.tween_interval(2.8)
	out.tween_property(center, "modulate:a", 0.0, 0.5)
	out.tween_callback(center.queue_free)
	return column


## Celebración: nombre del reto y estrellas que aparecen una a una.
func _on_stars_changed(module: String, stars: int) -> void:
	_refresh_objectives()
	var column: VBoxContainer = await _shout("¡%s!" % String(Game.info(module).name).to_upper(), Game.info(module).color)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in 3:
		var star := UI.label("★" if i < stars else "☆", "Title", Game.INK if i < stars else Game.LINE_STRONG)
		star.add_theme_font_size_override("font_size", 150)
		star.add_theme_constant_override("outline_size", 10)
		row.add_child(star)
		star.modulate.a = 0.0
		var tween := star.create_tween()
		tween.tween_interval(0.25 + i * 0.25)
		tween.tween_callback(func() -> void:
			UI.pop(star, 0.28)
			if i < stars:
				Sfx.play("pickup", 0.0))
	if Game.MODULES.has(module) and Game.total_stars() == Game.MODULES.size() * 3:
		get_tree().create_timer(3.4).timeout.connect(show_certificate)


## Con las 12 estrellas: certificado en pantalla unos segundos (sin menú que cerrar).
## `astronaut`: al volver de la Luna, con las 24 estrellas posibles y los créditos después.
func show_certificate(astronaut := false) -> void:
	var center := CenterContainer.new()
	center.theme = UI.THEME
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	# [texto, tamaño, color, variación]: el número en matriz de puntos (Doto) es el único motivo expresivo.
	var lines := [["CIUDAD STEAM  ·  COHETE DE AGUA", 0, Game.MUTED, "Caption"], ["Certificado STEAM", 72, Game.INK, "Title"],
			["12/12", 140, Game.INK, "Display"],
			["Ciudad STEAM reconoce a este explorador por completar\nEnergía solar, Ingeniería, Robótica y Reciclaje.", 30, Game.INK_2, ""]]
	if astronaut:
		lines = [["CIUDAD STEAM  ·  MISIÓN LUNAR", 0, Game.MUTED, "Caption"], ["Certificado de astronauta STEAM", 64, Game.INK, "Title"],
			["%d/24" % (Game.total_stars() + Game.total_stars(Game.MOON_MODULES)), 140, Game.INK, "Display"],
			["Viajó a la Luna en un cohete de agua, encontró hielo, le dio energía\na la base, purificó el agua y volvió sano y salvo a casa.", 30, Game.INK_2, ""]]
	for line: Array in lines:
		var label := UI.label(line[0], line[3], line[2])
		if line[1]:
			label.add_theme_font_size_override("font_size", line[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	UI.ignore_mouse(center)
	UI.pop.call_deferred(panel, 0.28)
	Sfx.play("success")
	var out := center.create_tween()
	out.tween_interval(8.0)
	out.tween_property(center, "modulate:a", 0.0, 0.8)
	out.tween_callback(center.queue_free)
	if astronaut:
		out.tween_callback(_roll_credits)


## Créditos que suben por la pantalla y desaparecen.
func _roll_credits() -> void:
	var column := VBoxContainer.new()
	column.theme = UI.THEME
	column.add_theme_constant_override("separation", 18)
	column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_celebration.add_child(column)
	for line: Array in [["CIUDAD STEAM · MISIÓN LUNAR", 64, Game.INK], ["", 30, Game.INK],
			["Basado en el juego de Unity «Ciudad STEAM»", 32, Game.INK_2], ["Llevado a Godot 4.7 y ampliado con la Misión Lunar", 32, Game.INK_2],
			["", 30, Game.INK], ["Ciencia · Tecnología · Ingeniería · Arte · Matemáticas", 32, Game.MUTED],
			["", 30, Game.INK], ["¡Gracias por jugar!", 56, Game.INK]]:
		var label := UI.label(line[0], "Title", line[2])
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_constant_override("outline_size", 10)  # legible sobre el suelo claro
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	UI.ignore_mouse(column)
	var height := get_viewport().get_visible_rect().size.y
	column.position.y = height
	var roll := column.create_tween()
	roll.tween_property(column, "position:y", -height * 0.6, 16.0)
	roll.tween_callback(column.queue_free)
