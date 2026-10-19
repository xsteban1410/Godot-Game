extends CanvasLayer
## HUD: estrellas por reto, aviso de interacción, notificaciones y celebración al ganar estrellas.

var _missions: VBoxContainer
var _objective: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _key: Label  # tecla del aviso: E con teclado, X con mando
var _toasts: VBoxContainer
var _celebration := CanvasLayer.new()
@export var moon := false  # en la Luna se listan los retos lunares


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.theme = UI.THEME
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 20)
	column.add_child(top)
	var objective_panel := PanelContainer.new()  # «SIGUIENTE»: qué toca hacer en la historia
	objective_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	objective_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL | Control.SIZE_SHRINK_BEGIN
	var objective_column := VBoxContainer.new()
	objective_panel.add_child(objective_column)
	objective_column.add_child(UI.label("SIGUIENTE", "Caption", Game.GOLD))
	_objective = UI.label("")
	_objective.custom_minimum_size.x = 420
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_column.add_child(_objective)
	top.add_child(objective_panel)
	var missions_panel := PanelContainer.new()
	_missions = VBoxContainer.new()
	missions_panel.add_child(_missions)
	top.add_child(missions_panel)

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
	_key = UI.label("E", "Title", Game.NAVY)
	key.add_child(_key)
	row.add_child(key)
	_prompt_label = UI.label("")
	row.add_child(_prompt_label)
	column.add_child(_prompt)
	column.add_child(UI.label("WASD mover  ·  RATÓN cámara  ·  SHIFT correr  ·  ESPACIO saltar (otra vez en el aire: JETPACK)  ·  E interactuar  ·  RUEDA zoom  ·  MANDO: A saltar, X usar", "Caption"))

	_celebration.layer = 50  # por encima de los paneles de los retos
	add_child(_celebration)
	Game.stars_changed.connect(_on_stars_changed)
	Game.bolts_changed.connect(_on_bolts_changed)
	Game.toast.connect(_show_toast)
	Game.prompt_changed.connect(_on_prompt_changed)
	_refresh_missions()
	UI.ignore_mouse(margin)


## El aviso muestra la tecla del último control usado (el movimiento del ratón no cuenta: haría parpadear).
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_key.text = "X"
	elif event is InputEventKey or event is InputEventMouseButton:
		_key.text = "E"


func _on_prompt_changed(text: String) -> void:
	_prompt.visible = not text.is_empty()
	_prompt_label.text = text


func _refresh_missions() -> void:
	UI.clear(_missions)
	if moon:
		_mission_list("MISIONES LUNARES", Game.MOON_MODULES)
	else:
		_mission_list("MISIONES", Game.MODULES)
		_missions.add_child(UI.label("COHETE  ·  %d / 12 piezas" % Game.total_stars(), "Caption", Game.GOLD))
		_mission_list("LABORATORIO", Game.LAB_MODULES)
	_missions.add_child(UI.label("TUERCAS DORADAS  ·  %d / %d" % [Game.bolts.size(), Game.BOLTS_TOTAL], "Caption", Game.GOLD))
	UI.ignore_mouse(_missions)
	_objective.text = objective(moon)


## El siguiente paso de la historia: piezas del cohete → la Luna → volver → completarlo todo.
static func objective(on_moon: bool) -> String:
	var moon_done := Game.MOON_MODULES.keys().filter(func(id: String) -> bool: return int(Game.stars.get(id, 0)) > 0).size()
	if on_moon:
		if moon_done < 4:
			return "Busca hielo para el cohete: gana una ★ en cada reto lunar (%d / 4). Sigue las balizas de colores." % moon_done
		return "¡Ya tienes agua! Vuelve al cohete para regresar a la Tierra."
	if Game.total_stars() < 12:
		return "Gana estrellas en los retos: cada una es una pieza del cohete (%d / 12)." % Game.total_stars()
	if moon_done < 4:
		return "¡Cohete completo! Ve a la plataforma de lanzamiento (el haz de luz) y viaja a la Luna."
	return "Consigue todas las estrellas y las tuercas doradas (%d / %d) para el traje dorado." % [Game.bolts.size(), Game.BOLTS_TOTAL]


func _on_bolts_changed(_count: int) -> void:
	_refresh_missions()
	if Game.golden():
		_shout("¡TRAJE DORADO!", Game.GOLD, "Encontraste las %d tuercas" % Game.BOLTS_TOTAL)


func _mission_list(title: String, modules: Dictionary) -> void:
	_missions.add_child(UI.label("%s  ·  ★ %d / %d" % [title, Game.total_stars(modules), modules.size() * 3], "Caption", Game.TEAL))
	for id: String in modules:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.label("•", "Title", modules[id].color))  # «●» no está en Rubik: en Windows salía un cuadro
		var label := UI.label(modules[id].name)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(UI.label(UI.stars(int(Game.stars.get(id, 0))), "", Game.GOLD))
		_missions.add_child(row)


func _show_toast(text: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.add_child(UI.label(text, "", color))
	_toasts.add_child(panel)
	UI.ignore_mouse(panel)
	UI.pop(panel)
	var tween := panel.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)


## Rótulo grande en el centro que aparece con rebote y se desvanece; devuelve su columna para añadir más.
func _shout(text: String, color: Color, subtitle := "") -> VBoxContainer:
	var center := CenterContainer.new()
	center.theme = UI.THEME
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration.add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)
	var title := UI.label(text, "Title", color)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_constant_override("outline_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	if subtitle:
		var sub := UI.label(subtitle, "Title", Game.TEXT)
		sub.add_theme_constant_override("outline_size", 12)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(sub)
	UI.ignore_mouse(center)
	UI.pop(title)
	var out := center.create_tween()
	out.tween_interval(2.8)
	out.tween_property(center, "modulate:a", 0.0, 0.5)
	out.tween_callback(center.queue_free)
	return column


## Celebración: nombre del reto y estrellas que aparecen una a una con rebote.
func _on_stars_changed(module: String, stars: int) -> void:
	_refresh_missions()
	var column := _shout("¡%s!" % String(Game.info(module).name).to_upper(), Game.info(module).color)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in 3:
		var star := UI.label("★" if i < stars else "☆", "Title", Game.GOLD)
		star.add_theme_font_size_override("font_size", 150)
		star.add_theme_constant_override("outline_size", 20)
		row.add_child(star)
		star.modulate.a = 0.0
		var tween := star.create_tween()
		tween.tween_interval(0.25 + i * 0.25)
		tween.tween_callback(func() -> void:
			UI.pop(star)
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
	var lines := [["CERTIFICADO STEAM", 72, Game.GOLD], ["★ 12 / 12", 56, Game.GOLD],
			["Ciudad STEAM reconoce a este explorador por completar\nEnergía solar, Ingeniería, Robótica y Reciclaje.", 30, Game.TEXT]]
	if astronaut:
		lines = [["CERTIFICADO DE ASTRONAUTA STEAM", 64, Game.GOLD],
			["★ %d / 24" % (Game.total_stars() + Game.total_stars(Game.MOON_MODULES)), 56, Game.GOLD],
			["Viajó a la Luna en un cohete de agua, encontró hielo, le dio energía\na la base, purificó el agua y volvió sano y salvo a casa.", 30, Game.TEXT]]
	for line: Array in lines:
		var label := UI.label(line[0], "Title", line[2])
		label.add_theme_font_size_override("font_size", line[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	UI.ignore_mouse(center)
	UI.pop.call_deferred(panel)
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
	for line: Array in [["CIUDAD STEAM · MISIÓN LUNAR", 64, Game.GOLD], ["", 30, Game.TEXT],
			["Basado en el juego de Unity «Ciudad STEAM»", 32, Game.TEXT], ["Llevado a Godot 4.7 y ampliado con la Misión Lunar", 32, Game.TEXT],
			["", 30, Game.TEXT], ["Ciencia · Tecnología · Ingeniería · Arte · Matemáticas", 32, Game.TEAL],
			["", 30, Game.TEXT], ["¡Gracias por jugar!", 56, Game.GOLD]]:
		var label := UI.label(line[0], "Title", line[2])
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_constant_override("outline_size", 14)  # legible sobre el suelo claro
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	UI.ignore_mouse(column)
	var height := get_viewport().get_visible_rect().size.y
	column.position.y = height
	var roll := column.create_tween()
	roll.tween_property(column, "position:y", -height * 0.6, 16.0)
	roll.tween_callback(column.queue_free)
