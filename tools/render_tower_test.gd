## Capturas a 1:1 (1280x720) de la torre de prueba (scenes/levels/tower_test.tscn,
## 2026-10-16, pasos 1 y 2 de docs/propuesta-1-2.md §10) con la camara de torre y
## el fondo vertical:
##   1_abajo.png         Isak en el vestibulo (camara en el limite de abajo)
##   2_media_altura.png  Isak en el suelo del piso 2 (el piso entero en pantalla)
##   3_media_salto.png   el mismo sitio en lo alto de un salto (la camara no se mueve)
##   4_arriba.png        Isak en la azotea junto a la terminal (limite de arriba)
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_tower_test.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/tower_test.tscn"
const DEFAULT_OUT: String = "user://tower_test"
const SETTLE_FRAMES: int = 60
const T: float = 64.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var isak: Node2D = level.get_node(^"Isak")
	await _place(isak, 8.0, 38)
	await _save(isak, out_dir, "1_abajo.png")
	await _place(isak, 14.0, 22)
	await _save(isak, out_dir, "2_media_altura.png")
	Input.action_press(&"jump")
	var best_y: float = isak.global_position.y
	for i: int in 40:
		await physics_frame
		best_y = minf(best_y, isak.global_position.y)
		if i > 4 and (isak.get(&"velocity") as Vector2).y >= 0.0:
			break
	Input.action_release(&"jump")
	await _save(isak, out_dir, "3_media_salto.png")
	for i: int in SETTLE_FRAMES:
		await physics_frame
	await _place(isak, 20.0, 2)
	await _save(isak, out_dir, "4_arriba.png")
	quit(0)


func _place(isak: Node2D, col: float, row: int) -> void:
	isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	isak.set(&"velocity", Vector2.ZERO)
	isak.call(&"snap_camera")
	for i: int in SETTLE_FRAMES:
		await physics_frame


func _save(isak: Node2D, out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	var camera: Camera2D = isak.call(&"get_camera")
	print("render_tower_test: %s (%s) Isak=%s camara=%s" % [path, error_string(err), isak.global_position,
		camera.get_screen_center_position()])
