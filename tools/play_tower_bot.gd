## Lanzador del bot vertical del 1-2 (paso 15 de docs/propuesta-1-2.md; logica en
## tools/tower_bot.gd). Sigue el camino que exporta tools/validate_level.py
## (formato isak-path/1) con la fisica real y las acciones del Input Map.
## Uso (rapido, sin ventana; codigo 0 si completa el nivel y el hub, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_tower_bot.gd [-- --case unknown|known]
##        [--path <camino.json>] [--shots <carpeta>]
## --case unknown (por defecto): Calc desconocida (azotea completa y escena de Calc
## en el hub); --case known: Calc ya conocida (camino directo). Sin --path el bot
## exporta el camino del caso con el validador. Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/tower_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
