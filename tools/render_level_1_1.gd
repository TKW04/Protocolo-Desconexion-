## Capturas a 1:1 (1280x720) de la escena generada del 1-1 (scenes/levels/1-1.tscn):
##   1_inicio.png          Isak tras caer desde P (Tramo 1)
##   2_puente_retraido.png Isak junto al receptor, puente sin activar
##   3_puente_activo.png   tras el pulso: puente extendido
##   4_burbuja_techo.png   la Burbuja patrullando bajo el techo bajo (Tramo 3)
##   5_popup.png           Isak pegado al pop-up (boton a la altura del celular)
##   6_puerta.png          la puerta "Marcar como leído" y la pared con glitch
## Mueve a Isak teletransportandolo (no es una partida). Necesita ventana (no
## funciona con --headless); con --write-movie guarda tambien todos los cuadros.
## Uso: Godot --path . -s tools/render_level_1_1.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/1-1.tscn"
const DEFAULT_OUT: String = "user://level_1_1"
const SETTLE_FRAMES: int = 60
const TILE: float = 64.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var isak: Node2D = level.get_node(^"Isak")
	for i: int in 90:
		await physics_frame
	await _save(out_dir, "1_inicio.png")
	await _teleport(isak, 46.0, 9)
	await _save(out_dir, "2_puente_retraido.png")
	Input.action_press(&"pulse")
	await physics_frame
	Input.action_release(&"pulse")
	for i: int in 50:
		await physics_frame
	var bridge: Node = level.get_node(^"Objects/puente_1")
	print("render_level_1_1: puente extendido=%s" % bridge.call(&"is_extended"))
	await _save(out_dir, "3_puente_activo.png")
	await _teleport(isak, 79.0, 9)
	await _save(out_dir, "4_burbuja_techo.png")
	await _teleport(isak, 111.25, 9)
	await _save(out_dir, "5_popup.png")
	await _teleport(isak, 127.0, 9)
	await _save(out_dir, "6_puerta.png")
	level.queue_free()
	await process_frame
	quit(0)


func _teleport(isak: Node2D, col: float, row: int) -> void:
	isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE - 1.0)
	isak.set(&"velocity", Vector2.ZERO)
	isak.set(&"facing", 1.0)
	for i: int in SETTLE_FRAMES:
		await physics_frame


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_level_1_1: %s (%s)" % [path, error_string(err)])
