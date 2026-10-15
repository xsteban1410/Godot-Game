extends CanvasLayer
## Menú del STEAM LAB (port de SteamLabUI). Muestra el progreso real (antes era "XP: 100" fijo) y
## cada módulo lleva a su distrito. Los módulos aún vacíos se ven bloqueados sin romper el menú
## (en Unity, pulsarlos desactivaba todos los botones).

signal travel_requested(module: String)

const LOCKED := ["MATEMÁTICAS", "VISIÓN IA", "DESAFÍO IA"]

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

	var title := UI.label("STEAM LAB", "Title", Game.TEAL)
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var motto := UI.label("LABORATORIO DE DESAFÍOS  ·  ELIGE TU MISIÓN. RESUELVE. AVANZA.", "Caption")
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(motto)
	var progress := UI.label("★ %d / 12" % Game.total_stars(), "Title", Game.GOLD)
	progress.add_theme_font_size_override("font_size", 28)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(progress)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	_first_card = null
	for id: String in Game.MODULES:
		var info: Dictionary = Game.MODULES[id]
		var text := "%s\n%s\n%s" % [String(info.name).to_upper(), info.desc, UI.stars(int(Game.stars.get(id, 0)))]
		var card := _card(text, info.color)
		card.pressed.connect(_choose.bind(id))
		grid.add_child(card)
		if not _first_card:
			_first_card = card
	for locked: String in LOCKED:
		var card := _card("%s\nPRÓXIMAMENTE" % locked, Color("5a6b7d"))
		card.disabled = true
		grid.add_child(card)

	var hint := UI.label("ELIGE UN MÓDULO PARA VIAJAR A SU DISTRITO   ·   ESC  CERRAR", "Caption")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _card(text: String, color: Color) -> Button:
	var card := UI.button(text, func() -> void: pass)
	card.custom_minimum_size = Vector2(300, 170)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "disabled"]:
		var style: StyleBoxFlat = UI.THEME.get_stylebox(state, "Button").duplicate()
		style.border_width_top = 8
		style.border_color = color if state != "disabled" else color.darkened(0.5)
		if state == "hover":
			style.bg_color = color.darkened(0.55)
		card.add_theme_stylebox_override(state, style)
	var focus: StyleBoxFlat = UI.THEME.get_stylebox("focus", "Button").duplicate()
	focus.border_color = color
	card.add_theme_stylebox_override("focus", focus)
	return card


func _choose(id: String) -> void:
	close()
	travel_requested.emit(id)
