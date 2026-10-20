## Lanzador del bot del 1-3 «No molestar» (paso 11 de docs/propuesta-1-3.md;
## logica en tools/dnd_bot.gd, que extiende tools/tower_bot.gd). Sigue el camino
## que exporta tools/validate_level.py (formato isak-path/1: pasos dash y
## wait_beat incluidos) con la fisica real y las acciones del Input Map.
## Uso (rapido, sin ventana; codigo 0 si completa el nivel y vuelve al hub, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_dnd_bot.gd
##        [-- --path <camino.json>] [--verbose] [--shots <carpeta>]
## Sin --path el bot exporta el camino con el validador (unos 40 s de pared).
## Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/dnd_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
