## Lanzador del bot de la tienda (Mundo 5; paso 11 de docs/propuesta-mundo-5.md;
## logica en tools/mall_bot.gd, que extiende tools/chat_bot.gd, tools/gallery_bot.gd,
## tools/dnd_bot.gd y tools/tower_bot.gd). Sigue el camino que exporta
## tools/validate_level.py (formato isak-path/1: pasos resist_pull,
## cancel_subscription, buy, pay_door, refund y wait_countdown incluidos; con
## --profile comprador, el camino de `--buy`) con la fisica real y las acciones del
## Input Map.
## Uso (rapido, sin ventana; codigo 0 si completa el nivel y vuelve al hub sin morir,
## sin «Añadido al carrito», con el saldo nunca por debajo de 0 y, en frugal, sin gastar
## nada y con la duracion entre el 40 y el 55 % del objetivo; 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_mall_bot.gd
##        [-- --level 5-1|<sala>_test] [--profile frugal|comprador] [--path <camino.json>]
##        [--verbose] [--shots <carpeta>]
## Sin --path el bot exporta el camino con el validador.
## Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPT: String = "res://tools/mall_bot.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot: Node = Node.new()
	bot.set_script(load(BOT_SCRIPT))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
