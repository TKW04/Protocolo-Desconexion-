## Capturas a 1:1 (1280x720) de la ayuda de Eco con Q (HelpSystem,
## data/help.json; docs/propuesta-asistentes-y-vidas.md §3) con el flujo de
## juego real (scenes/main.tscn) y un guardado vacio (user://tool_save.json, se
## borra al arrancar; nunca el guardado del jugador):
##   01_q_receptor.png    la Q sobre el receptor del Tramo 2a (tipo no aprendido)
##   02_ayuda_pausa.png   tras pulsar help: el juego en pausa y Eco explicando el tipo
##   03_receptor_sin_q.png el mismo receptor tras cerrar la ayuda, ya sin Q (el
##                         puente, de otro tipo, conserva la suya)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_help.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const DEFAULT_OUT: String = "user://help_shots"
const TILE: float = 64.0
const RECEIVER_PATH: NodePath = ^"Objects/receiver_56_9"
const WAIT_FRAMES: int = 60 * 10
## Segundos reales para que el cuadro de Eco termine de escribir.
const TYPE_WAIT_S: float = 2.5

var _main: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node = (load(SCENE) as PackedScene).instantiate()
	# Partida que ya paso por el encuentro con Eco (2026-10-16): Eco conocido y
	# el pulso obtenido (el 1-1 empieza sin pulso; el encuentro se captura con
	# tools/render_eco_encounter.gd).
	var game_state: Node = root.get_node(^"GameState")
	game_state.call(&"meet_ally", &"eco")
	game_state.call(&"mark_notice_seen", &"pulse")
	game_state.call(&"obtain_ability", &"pulse")
	main.set(&"start_level_id", "1-1")
	root.add_child(main)
	_main = main
	# Llegada por el vortice (Eco entra con Isak).
	var isak: Node2D = main.call(&"get_isak")
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		_confirm_lines()
		await process_frame
		if not paused and not isak.call(&"is_warping"):
			break
	for i: int in 30:
		_confirm_lines()
		await process_frame
	var level: Node = main.call(&"get_level")
	var help: Node = level.get_node(^"Help")
	var receiver: Node2D = level.get_node(RECEIVER_PATH)
	# Entre el receptor y el foso del puente, lejos de la Burbuja del 2a.
	isak.global_position = Vector2(57.6 * TILE, 10.0 * TILE)
	isak.set(&"velocity", Vector2.ZERO)
	var ok_q: bool = false
	for i: int in WAIT_FRAMES:
		_confirm_lines()
		await process_frame
		if help.call(&"get_target") == receiver:
			ok_q = true
			break
	await create_timer(0.3).timeout
	var shown: Node = help.call(&"get_target")
	ok_q = ok_q and shown == receiver
	print("render_help: Q sobre %s" % (shown.name if shown != null else "nada"))
	await _save(out_dir, "01_q_receptor.png")
	var press := InputEventAction.new()
	press.action = &"help"
	press.pressed = true
	root.push_input(press)
	await create_timer(TYPE_WAIT_S).timeout
	var ok_pause: bool = paused
	var box: Node = level.get_node(^"EcoTextBox")
	var text: String = box.call(&"get_text")
	box.call(&"finish_typing")
	await create_timer(0.3).timeout
	await _save(out_dir, "02_ayuda_pausa.png")
	while box.call(&"confirm"):
		pass
	await create_timer(1.0).timeout
	var ok_after: bool = not paused and help.call(&"get_target") != receiver
	await _save(out_dir, "03_receptor_sin_q.png")
	print("render_help: q=%s pausa=%s sin_q_despues=%s texto=«%s»" % [ok_q, ok_pause, ok_after, text])
	main.queue_free()
	await process_frame
	quit(0 if ok_q and ok_pause and ok_after else 1)


## Cierra (como el jugador) las lineas importantes de Eco, que pausan el juego.
func _confirm_lines() -> void:
	var level: Node = _main.call(&"get_level")
	var box: Node = level.get_node_or_null(^"EcoTextBox") if is_instance_valid(level) else null
	while box != null and box.call(&"is_important") and box.call(&"confirm"):
		pass


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_help: %s (%s)" % [path, error_string(err)])
