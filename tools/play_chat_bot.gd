## Lanzador del bot del chat (Mundo 4; paso 12 de docs/propuesta-mundo-4.md;
## logica en tools/chat_bot.gd, que extiende tools/gallery_bot.gd, tools/dnd_bot.gd
## y tools/tower_bot.gd). Sigue el camino que exporta tools/validate_level.py
## (formato isak-path/1: pasos pulse_seen, wait_typing, wait_autocorrect,
## wait_ghost y shake, esperas de las zonas «Visto» con ciclo y pulsos al Troll
## incluidos) con la fisica real y las acciones del Input Map.
## Uso (rapido, sin ventana; codigo 0 si completa el nivel y vuelve al hub sin
## morir ni congelarse y con la duracion entre el 40 y el 55 % del objetivo, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_chat_bot.gd
##        [-- --level 4-1|<sala>_test] [--path <camino.json>] [--verbose] [--shots <carpeta>]
## Sin --path el bot exporta el camino con el validador.
## Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/chat_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
