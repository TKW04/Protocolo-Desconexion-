## Lanzador del bot de los niveles del feed (Mundo 2; paso 12 de
## docs/propuesta-mundo-2.md; logica en tools/feed_bot.gd, que extiende
## tools/dnd_bot.gd y tools/tower_bot.gd). Sigue el camino que exporta
## tools/validate_level.py (formato isak-path/1: pasos wait_scroll, ground_pound
## y wait_phase con clip_cycle_s incluidos) con la fisica real y las acciones del
## Input Map.
## Uso (rapido, sin ventana; codigo 0 si completa el nivel y vuelve al hub sin
## tocar el borde ni morir, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_feed_bot.gd
##        [-- --level 2-1|2-2|2-3] [--path <camino.json>] [--verbose] [--shots <carpeta>]
## Sin --path el bot exporta el camino con el validador (unos 30 s de pared en el 2-1).
## Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/feed_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
