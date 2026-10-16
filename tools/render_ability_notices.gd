## Capturas a 1:1 (1280x720) de los avisos de control de las habilidades
## (AbilityNotices, data/ability_notices.json) con el flujo de juego real
## (scenes/main.tscn) y un guardado vacio (user://tool_save.json, se borra al
## arrancar; nunca el guardado del jugador):
##   01_aviso_pulso.png   el aviso del pulso en el encuentro con Eco (columnas 10-12; Isak camina hasta alli)
##   02_aviso_laser.png   el aviso del laser al recogerlo en la sala del 3b
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_ability_notices.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
## Se carga en tiempo de ejecucion: un script -s no ve los autoloads al compilar.
const NOTICES_SCRIPT: String = "res://scripts/ui/ability_notices.gd"
const DEFAULT_OUT: String = "user://ability_notices"
const TILE: float = 64.0
## Cuadros maximos esperando a que el cuadro de Eco empiece un aviso.
const WAIT_FRAMES: int = 60 * 30
## Segundos reales tras empezar el aviso (maquina de escribir terminada).
const TYPE_WAIT_S: float = 1.2

var _started: Array[String] = []
var _main: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var event_bus: Node = root.get_node(^"EventBus")
	event_bus.connect(&"eco_line_started", func(text: String) -> void: _started.append(text))
	var notices: GDScript = load(NOTICES_SCRIPT)
	var data: Dictionary = notices.call(&"load_data")
	var main: Node = (load(SCENE) as PackedScene).instantiate()
	main.set(&"start_level_id", "1-1")
	root.add_child(main)
	_main = main
	# Encuentro con Eco (2026-10-16): el aviso del pulso sale cuando Eco lo regala.
	var encounter: Node = main.call(&"get_level").get_node(^"Objects/eco_encuentro")
	Input.action_press(&"move_right")
	var ok_pulse: bool = await _wait_for(encounter.call(&"get_notice_text"))
	Input.action_release(&"move_right")
	await _save(out_dir, "01_aviso_pulso.png")
	# Cierra el aviso y la ultima linea del encuentro (2 s de tiempo real).
	var until: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		_confirm_other_lines("")
		await process_frame
	var isak: Node2D = main.call(&"get_isak")
	isak.global_position = Vector2(173.5 * TILE, 6.0 * TILE - 1.0)
	isak.set(&"velocity", Vector2.ZERO)
	var ok_laser: bool = await _wait_for(notices.call(&"notice_text", &"laser", data))
	await _save(out_dir, "02_aviso_laser.png")
	print("render_ability_notices: pulso=%s laser=%s lineas=%s" % [ok_pulse, ok_laser, _started])
	main.queue_free()
	await process_frame
	quit(0 if ok_pulse and ok_laser else 1)


## Espera a que el cuadro de Eco empiece `text` y a que se termine de escribir.
## Cierra (como el jugador) las otras lineas importantes, que pausan el juego.
func _wait_for(text: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_FRAMES * 1000.0 / 60.0)
	while Time.get_ticks_msec() < deadline:
		if _started.has(text):
			await create_timer(TYPE_WAIT_S).timeout
			return true
		_confirm_other_lines(text)
		await process_frame
	return false


func _confirm_other_lines(text: String) -> void:
	var level: Node = _main.call(&"get_level")
	var encounter: Node = level.get_node_or_null(^"Objects/eco_encuentro") if is_instance_valid(level) else null
	var entry: Node = encounter.call(&"get_nickname_entry") if encounter != null else null
	if entry != null and entry.call(&"is_open"):
		entry.call(&"activate_selected")
	var box: Node = level.get_node_or_null(^"EcoTextBox") if is_instance_valid(level) else null
	while box != null and box.call(&"is_important") and box.call(&"get_text") != text \
			and box.call(&"confirm"):
		pass


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_ability_notices: %s (%s)" % [path, error_string(err)])
