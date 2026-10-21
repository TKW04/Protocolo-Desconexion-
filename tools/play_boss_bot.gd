## Lanzador del bot del jefe Alerta Mayor (paso 14 de docs/propuesta-jefe-alerta-mayor.md
## §6; logica en tools/boss_bot.gd). Pelea en la arena 1-boss real con el Isak real
## y solo acciones del Input Map, vence y vuelve al hub.
## Uso (rapido, sin ventana; codigo 0 si el perfil cumple, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_boss_bot.gd
##        [-- --profile ideal|clumsy|idle] [--lap 1|2|3] [--verbose]
## --profile: ideal (por defecto, pelea limpia: vence sin morir), clumsy (torpe:
## validation_model del JSON del jefe; vence sin quedarse sin energia en una
## ventana) o idle (quieto: debe acabar en game over sin vencer).
## --lap: acceso 1 Caché (por defecto), 2 Kernel o 3 Raíz (GameState.lap).
## Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/boss_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
