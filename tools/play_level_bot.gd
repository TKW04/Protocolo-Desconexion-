## Lanzador del bot de recorrido del 1-1 (logica en tools/level_bot.gd).
## Uso (rapido, sin ventana; termina con codigo 0 si completa el nivel, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_level_bot.gd [-- --no-die]
## Con ventana (para verlo jugar): quita --headless y --fixed-fps.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/level_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
