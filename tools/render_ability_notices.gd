## Capturas a 1:1 (1280x720) de los avisos de control de las habilidades
## (AbilityNotices, data/ability_notices.json) con el flujo de juego real
## (scenes/main.tscn) y un guardado vacio (user://tool_save.json, se borra al
## arrancar; nunca el guardado del jugador):
##   01_aviso_pulso.png   el aviso del pulso al empezar el 1-1 (tras la bienvenida de Eco)
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
	var ok_pulse: bool = await _wait_for(notices.call(&"notice_text", &"pulse", data))
	await _save(out_dir, "01_aviso_pulso.png")
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
func _wait_for(text: String) -> bool:
	for i: int in WAIT_FRAMES:
		if _started.has(text):
			await create_timer(TYPE_WAIT_S).timeout
			return true
		await process_frame
	return false


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_ability_notices: %s (%s)" % [path, error_string(err)])
