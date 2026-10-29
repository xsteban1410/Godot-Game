extends CanvasLayer
## Menú del STEAM LAB (port de SteamLabUI). Muestra el progreso real (antes era "XP: 100" fijo) y
## cada tarjeta lleva a su distrito: los cuatro retos del cohete, la plataforma de lanzamiento y los
## tres del laboratorio (en Unity eran "PRÓXIMAMENTE" y pulsarlos desactivaba todos los botones).

signal travel_requested(module: String)

var _content: CenterContainer
var _first_card: Button


func _ready() -> void:
	layer = 10
	_content = UI.overlay(self, 0.72)
	visible = false


func open() -> void:
	if visible:
		return
	_build()
	visible = true
	Game.push_lock(self)
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, 0.2)
	UI.focus(_first_card)


func close() -> void:
	if not visible:
		return
	visible = false
	Game.pop_lock(self)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	UI.clear(_content)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 1280
	_content.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := UI.label("STEAM LAB", "Title")
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var motto := UI.label("LABORATORIO DE DESAFÍOS  ·  ELIGE TU MISIÓN. RESUELVE. AVANZA.", "Caption")
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(motto)
	var progress := UI.label("COHETE ★ %02d / 12    ·    LABORATORIO ★ %02d / 9" % [Game.total_stars(), Game.total_stars(Game.LAB_MODULES)], "Mono")
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(progress)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	_first_card = null
	for id: String in Game.MODULES:
		var card := _card(_text(id), Game.MODULES[id].color, _choose.bind(id))
		grid.add_child(card)
		if not _first_card:
			_first_card = card
	grid.add_child(_card("COHETE DE AGUA\nPlataforma de lanzamiento\n%d / 12 piezas" % Game.total_stars(), Color("ff8c1a"), _choose.bind("rocket")))
	for id: String in Game.LAB_MODULES:
		grid.add_child(_card(_text(id), Game.LAB_MODULES[id].color, _choose.bind(id)))

	var hint := UI.label("ELIGE UN RETO PARA VIAJAR A SU DISTRITO   ·   ESC / B  CERRAR", "Caption")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _text(id: String) -> String:
	var info: Dictionary = Game.info(id)
	return "%s\n%s\n%s" % [String(info.name).to_upper(), info.desc, UI.stars(int(Game.stars.get(id, 0)))]


func _card(text: String, color: Color, on_pressed: Callable) -> Button:
	var card := UI.button(text, on_pressed)
	card.custom_minimum_size = Vector2(300, 170)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_font_size_override("font_size", 24)
	var strip := ColorRect.new()  # filete superior fino del color del reto (un StyleBox pinta los 4 bordes de un color)
	strip.color = color
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 3
	card.add_child(strip)
	return card


func _choose(id: String) -> void:
	close()
	travel_requested.emit(id)
