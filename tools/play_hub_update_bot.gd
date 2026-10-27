## Lanzador del bot del hub «Actualización del sistema» (paso 8 de
## docs/propuesta-hub-mundos-4-6.md; logica en tools/hub_update_bot.gd). Desde un
## guardado tras vencer a La Curadora resuelve V1-V3 en la pagina 2 con el Isak
## real y solo acciones del Input Map, instala, guarda en Notas y abre M4.
## Uso (rapido, sin ventana; codigo 0 si el perfil cumple, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_hub_update_bot.gd
##        [-- --profile ideal|idle|nosave|kept] [--lap 2|3] [--verbose]
## --profile: ideal (por defecto), idle (quieto: no resuelve), nosave (instala sin
## guardar y game over: el upgrade se pierde y el acertijo se repite) o kept
## (Kernel/Raiz con el upgrade conservado: sin acertijo; --lap 2 por defecto).
## Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/hub_update_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
