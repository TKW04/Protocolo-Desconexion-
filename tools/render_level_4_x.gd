## Capturas a 1:1 (1280x720) del Mundo 4 «El Chat» (paso 22 de
## docs/propuesta-mundo-4.md §8, 2026-10-28) con el flujo real (scenes/main.tscn,
## LevelRunner), el HUD y Eco, jugadas por los bots (guardado user://bot_save.json
## y ajustes de herramientas; nunca el guardado real):
##   4-1, 4-2, 4-3   tools/render_level_4_x_chat.gd (extiende tools/chat_bot.gd):
##                   llegada, burbujas, Linterna y Modo oscuro, «escribiendo…»,
##                   zonas «Visto» y su pulso, Troll, autocorrector, Fantasma,
##                   Sticker, Papelera, «¿Deshacer escritura?», muro de texto,
##                   ola, Troll disfrazado, tinta, salida y hub (lista
##                   completa en ese archivo; solo las que tiene el nivel y su camino)
##   4-boss          tools/render_level_4_x_boss.gd (extiende tools/seen_bot.gd,
##                   perfil ideal, Caché): intro, las tres fases con su ataque y su
##                   ventana, rastro, marca, escudo con el pulso, «escribiendo…»
##                   gigante, congelacion (escenificada), golpe final, desarme,
##                   recompensa y hub con la pieza coral
## El hub con las carpetas M4/M5 y sus filas: tools/render_hub_m4.gd.
## Necesita ventana para escribir imagenes (renderiza en su propio viewport). Con
## --headless es un modo de prueba: juega igual y lista las capturas que habria hecho.
## Uso:
##   Godot --fixed-fps 60 --path . -s tools/render_level_4_x.gd [-- --level 4-1|4-2|4-3|4-boss|<sala>_test|all] [--out <carpeta>]
## --level all (por defecto) lanza un proceso por nivel, en serie (en paralelo los
## bots pueden fallar por la carga de la maquina). Sin --out las capturas van a
## assets/levels_preview/<nivel>/ (con --out, a <carpeta>/<nivel>/).
## Código 0 si todos los bots completan su recorrido.
extends SceneTree

const LEVELS: PackedStringArray = ["4-1", "4-2", "4-3", "4-boss"]
const CHAT_NODE: String = "res://tools/render_level_4_x_chat.gd"
const BOSS_NODE: String = "res://tools/render_level_4_x_boss.gd"


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
	# Tambien una sala de prueba del Mundo 4 (p. ej. oscuro_test: pinchos bajo el
	# velo del Modo oscuro, que no salen en el camino de los niveles reales).
	if not LEVELS.has(level) and not level.ends_with("_test"):
		print("render_level_4_x: nivel desconocido «%s» (4-1, 4-2, 4-3, 4-boss, <sala>_test, all)" % level)
		quit(1)
		return
	var dir: String = ProjectSettings.globalize_path("res://assets/levels_preview").path_join(level) \
		if out.is_empty() else out.path_join(level)
	var headless: bool = DisplayServer.get_name() == "headless"
	var node: Node = Node.new()
	if level == "4-boss":
		node.set_script(load(BOSS_NODE))
		node.set(&"shots_dir", "" if headless else dir)
	else:
		# El bot del chat lee --level de la linea de ordenes (la misma que esta).
		node.set_script(load(CHAT_NODE))
		if not headless:
			DirAccess.make_dir_recursive_absolute(dir)
			node.set(&"_shots_dir", dir)
	node.connect(&"finished", func(code: int) -> void:
		var names: PackedStringArray = node.call(&"taken_shots")
		print("render_level_4_x %s: %s; %d capturas%s: %s" % [level, "OK" if code == 0 else "FALLO", names.size(),
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
			"res://tools/render_level_4_x.gd", "--", "--level", level])
		if not out.is_empty():
			sub.append_array(["--out", out])
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), sub, output, true)
		for line: String in String("".join(output)).split("\n"):
			if line.begins_with("render_level_4_x") or line.contains("FALLO"):
				print(line)
		worst = maxi(worst, code)
	quit(worst)
