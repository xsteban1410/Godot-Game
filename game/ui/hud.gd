extends CanvasLayer
## HUD: estrellas por reto, aviso de interacción, notificaciones y celebración al ganar estrellas.

var _missions: VBoxContainer
var _prompt: PanelContainer
var _prompt_label: Label
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

	var missions_panel := PanelContainer.new()
	missions_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_missions = VBoxContainer.new()
	missions_panel.add_child(_missions)
	column.add_child(missions_panel)

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
	key.add_child(UI.label("E", "Title", Game.NAVY))
	row.add_child(key)
	_prompt_label = UI.label("")
	row.add_child(_prompt_label)
	column.add_child(_prompt)
	column.add_child(UI.label("WASD mover  ·  RATÓN cámara  ·  SHIFT correr  ·  ESPACIO saltar  ·  E interactuar  ·  RUEDA zoom", "Caption"))

	_celebration.layer = 50  # por encima de los paneles de los retos
	add_child(_celebration)
	Game.stars_changed.connect(_on_stars_changed)
	Game.toast.connect(_show_toast)
	Game.prompt_changed.connect(_on_prompt_changed)
	_refresh_missions()
	UI.ignore_mouse(margin)


func _on_prompt_changed(text: String) -> void:
	_prompt.visible = not text.is_empty()
	_prompt_label.text = text


func _refresh_missions() -> void:
	UI.clear(_missions)
	var modules: Dictionary = Game.MOON_MODULES if moon else Game.MODULES
	_missions.add_child(UI.label("%s  ·  ★ %d / 12" % ["MISIONES LUNARES" if moon else "MISIONES", Game.total_stars(modules)], "Caption", Game.TEAL))
	for id: String in modules:
		var info: Dictionary = modules[id]
		_missions.add_child(UI.label("●  %s   %s" % [info.name, UI.stars(int(Game.stars.get(id, 0)))]))
	if not moon:
		_missions.add_child(UI.label("COHETE  ·  %d / 12 piezas" % Game.total_stars(), "Caption", Game.GOLD))
	UI.ignore_mouse(_missions)


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


## Celebración: nombre del reto y estrellas que aparecen una a una con rebote.
func _on_stars_changed(module: String, stars: int) -> void:
	_refresh_missions()
	var center := CenterContainer.new()
	center.theme = UI.THEME
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration.add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)
	var title := UI.label("¡%s!" % String(Game.info(module).name).to_upper(), "Title", Game.info(module).color)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_constant_override("outline_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	UI.ignore_mouse(center)
	UI.pop(title)
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
	var out := center.create_tween()
	out.tween_interval(2.8)
	out.tween_property(center, "modulate:a", 0.0, 0.5)
	out.tween_callback(center.queue_free)
	if Game.MODULES.has(module) and Game.total_stars() == Game.MODULES.size() * 3:
		get_tree().create_timer(3.4).timeout.connect(_show_certificate)


## Con las 12 estrellas: certificado en pantalla unos segundos (sin menú que cerrar).
func _show_certificate() -> void:
	var center := CenterContainer.new()
	center.theme = UI.THEME
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	for line: Array in [["CERTIFICADO STEAM", 72, Game.GOLD], ["★ 12 / 12", 56, Game.GOLD],
			["Ciudad STEAM reconoce a este explorador por completar\nEnergía solar, Ingeniería, Robótica y Reciclaje.", 30, Game.TEXT]]:
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
