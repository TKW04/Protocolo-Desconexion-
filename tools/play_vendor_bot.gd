## Lanzador del bot del jefe El Vendedor (paso 19 de docs/propuesta-mundo-5.md §8,
## 2026-10-29; logica en tools/vendor_bot.gd). Igual que
## tools/play_boss_bot.gd -- --boss vendor, con las mismas opciones:
##   Godot --headless --fixed-fps 60 --path . -s tools/play_vendor_bot.gd
##        [-- --profile ideal|clumsy|idle] [--lap 1|2|3] [--verbose] [--trace]
## Codigo 0 si el perfil cumple, 1 si no. Con ventana: quita --headless.
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load("res://tools/vendor_bot.gd"))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
