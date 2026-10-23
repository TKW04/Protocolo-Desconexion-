## Capturas a 1:1 (1280x720) del Mundo 2 «El Feed» (paso 22 de
## docs/propuesta-mundo-2.md §8, 2026-10-23) con el flujo real (scenes/main.tscn,
## LevelRunner), el HUD y Eco, jugadas por los bots (guardado user://bot_save.json
## y ajustes de herramientas; nunca el guardado real):
##   2-1, 2-2, 2-3   tools/render_level_2_x_feed.gd (extiende tools/feed_bot.gd):
##                   inicio, scroll, videos (aviso y clip), bucle, frágiles,
##                   clones, Comentarista, Historias, reproductor y golpe al
##                   suelo, inversión, muro «Cargando más…», cuenta final y hub
##                   (lista completa en ese archivo; solo las que tiene el nivel)
##   2-boss          tools/render_level_2_x_boss.gd (extiende tools/autoplay_bot.gd,
##                   perfil ideal, Caché): intro, fases y sus pausas, la cuenta,
##                   golpe final, desarme, recompensa, hub con la pieza ámbar y la
##                   carpeta del Mundo 3 «Próximamente»
## Necesita ventana para escribir imágenes (renderiza en su propio viewport; no
## hace falta permiso de grabación de pantalla). Con --headless es un modo de
## prueba: juega igual y lista las capturas que habría hecho.
## Uso:
##   Godot --fixed-fps 60 --path . -s tools/render_level_2_x.gd [-- --level 2-1|2-2|2-3|2-boss|all] [--out <carpeta>]
## --level all (por defecto) lanza un proceso por nivel, en serie. Sin --out las
## capturas van a assets/levels_preview/<nivel>/ (con --out, a <carpeta>/<nivel>/).
## Código 0 si todos los bots completan su recorrido.
extends SceneTree

const LEVELS: PackedStringArray = ["2-1", "2-2", "2-3", "2-boss"]
const FEED_NODE: String = "res://tools/render_level_2_x_feed.gd"
const BOSS_NODE: String = "res://tools/render_level_2_x_boss.gd"


func _init() -> void:
	_run.call_deferred()


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level: String = _arg(args, "--level", "all")
	var out: String = _arg(args, "--out", "")
	if level == "all":
		_run_all(out)
		return
	if not LEVELS.has(level):
		print("render_level_2_x: nivel desconocido «%s» (2-1, 2-2, 2-3, 2-boss, all)" % level)
		quit(1)
		return
	var dir: String = ProjectSettings.globalize_path("res://assets/levels_preview").path_join(level) \
		if out.is_empty() else out.path_join(level)
	var headless: bool = DisplayServer.get_name() == "headless"
	var node: Node = Node.new()
	if level == "2-boss":
		node.set_script(load(BOSS_NODE))
		node.set(&"shots_dir", "" if headless else dir)
	else:
		node.set_script(load(FEED_NODE))
		node.set(&"_feed_level", level)
		if not headless:
			DirAccess.make_dir_recursive_absolute(dir)
			node.set(&"_shots_dir", dir)
	node.connect(&"finished", func(code: int) -> void:
		var names: PackedStringArray = node.call(&"taken_shots")
		print("render_level_2_x %s: %s; %d capturas%s: %s" % [level, "OK" if code == 0 else "FALLO", names.size(),
			" (modo de prueba, sin imagen)" if headless else " en " + dir, ", ".join(names)])
		quit(code))
	root.add_child(node)


## Un proceso por nivel (los bots leen sus argumentos de la línea de órdenes).
func _run_all(out: String) -> void:
	var worst: int = 0
	for level: String in LEVELS:
		var sub: PackedStringArray = []
		if DisplayServer.get_name() == "headless":
			sub.append("--headless")
		sub.append_array(["--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "-s",
			"res://tools/render_level_2_x.gd", "--", "--level", level])
		if not out.is_empty():
			sub.append_array(["--out", out])
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), sub, output, true)
		for line: String in String("".join(output)).split("\n"):
			if line.begins_with("render_level_2_x") or line.contains("FALLO"):
				print(line)
		worst = maxi(worst, code)
	quit(worst)
