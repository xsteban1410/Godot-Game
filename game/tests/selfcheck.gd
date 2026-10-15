extends SceneTree
## Autocomprobación sin ventana:  godot --headless --path game --script res://tests/selfcheck.gd
## Las estrellas solo suben (repetir un reto no premia dos veces: bug B2 de Unity) y se guardan.

var _failures := 0


func _initialize() -> void:
	var game_script: GDScript = load("res://autoload/game.gd")
	var game: Node = game_script.new()
	game.save_path = "user://selfcheck.cfg"
	game.set_stars("bridge", 2)
	game.set_stars("bridge", 1)
	game.set_stars("solar", 3)
	_check(game.stars["bridge"] == 2, "las estrellas solo suben")
	_check(game.total_stars() == 5, "el total suma todos los retos")

	var cfg := ConfigFile.new()
	cfg.load(game.save_path)
	_check(cfg.get_value("progress", "stars", {}) == {"bridge": 2, "solar": 3}, "las estrellas se guardan")

	# Puente: cada nivel tiene solución dentro del presupuesto y "todo hormigón" nunca cabe (B1 de Unity).
	var bridge: GDScript = load("res://modules/bridge.gd")
	for level: Array in bridge.LEVELS:
		var cheapest := INF
		for combo in 243:  # 3^5 combinaciones de materiales
			var total := 0
			var holds := true
			for i in 5:
				var m: Array = bridge.MATERIALS[int(combo / pow(3, i)) % 3]
				total += m[1]
				holds = holds and m[2] >= level[1] * bridge.FACTORS[i]
			if holds:
				cheapest = minf(cheapest, total)
		_check(cheapest <= level[2], "el %s tiene solución dentro del presupuesto (%d ≤ %d)" % [level[0], cheapest, level[2]])
		_check(5 * bridge.MATERIALS[2][1] > level[2], "con el %s, todo hormigón no cabe en el presupuesto" % level[0])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	game.free()
	print("SELFCHECK %s (%d fallos)" % ["OK" if _failures == 0 else "FALLÓ", _failures])
	quit(1 if _failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		printerr("  ✗ " + description)
