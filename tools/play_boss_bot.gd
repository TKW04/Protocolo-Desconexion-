## Lanzador de los bots de jefe: Alerta Mayor (paso 14 de
## docs/propuesta-jefe-alerta-mayor.md §6; logica en tools/boss_bot.gd) y
## Autoplay (paso 19 de docs/propuesta-mundo-2.md §8; logica en
## tools/autoplay_bot.gd). Pelea en la arena real (1-boss o 2-boss) con el Isak
## real y solo acciones del Input Map, vence y vuelve al hub.
## Uso (rapido, sin ventana; codigo 0 si el perfil cumple, 1 si no):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_boss_bot.gd
##        [-- --boss alert_major|autoplay] [--profile ideal|clumsy|idle] [--lap 1|2|3] [--verbose] [--trace]
## --boss: alert_major (por defecto, arena 1-boss) o autoplay (arena 2-boss).
## --profile: ideal (por defecto, pelea limpia: vence sin morir), clumsy (torpe:
## validation_model del JSON del jefe; vence sin quedarse sin energia en una
## ventana) o idle (quieto: debe acabar en game over sin vencer).
## --lap: acceso 1 Caché (por defecto), 2 Kernel o 3 Raíz (GameState.lap).
## Con ventana: quita --headless.
extends SceneTree

const BOT_SCRIPTS: Dictionary = {
	"alert_major": "res://tools/boss_bot.gd",
	"autoplay": "res://tools/autoplay_bot.gd",
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var boss: String = "alert_major"
	var at: int = args.find("--boss")
	if at >= 0 and at + 1 < args.size():
		boss = args[at + 1]
	if not BOT_SCRIPTS.has(boss):
		print("play_boss_bot: jefe desconocido «%s» (alert_major, autoplay)" % boss)
		quit(1)
		return
	var bot: Node = Node.new()
	bot.set_script(load(String(BOT_SCRIPTS[boss])))
	bot.connect(&"finished", func(code: int) -> void: quit(code))
	root.add_child(bot)
