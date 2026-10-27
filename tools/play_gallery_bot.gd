## Lanzador del bot de la galeria (Mundo 3; paso 11 de docs/propuesta-mundo-3.md;
## logica en tools/gallery_bot.gd, que extiende tools/dnd_bot.gd y
## tools/tower_bot.gd). Sigue el camino que exporta tools/validate_level.py
## (formato isak-path/1: pasos heart, pinch, unpinch, like_reset, wait_hunter,
## wait_reflection y pulsos a publicaciones, Ladron e Influencer incluidos) con la
## fisica real y las acciones del Input Map.
## Uso (rapido, sin ventana; codigo 0 si completa el nivel y vuelve al hub sin
## morir ni ser robado, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_gallery_bot.gd
##        [-- --level 3-1|3-2|3-3|<sala>_test] [--path <camino.json>] [--verbose] [--shots <carpeta>]
## Sin --path el bot exporta el camino con el validador (unos 25 s de pared en el 3-1 y unos
## 20 s en el 3-2, que obtiene Pellizcar en «Recortar»).
## Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/gallery_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
