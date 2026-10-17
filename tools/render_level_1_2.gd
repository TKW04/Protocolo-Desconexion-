## Capturas a 1:1 (1280x720) del nivel 1-2 «Centro de notificaciones»
## (scenes/levels/1-2.tscn; paso 13 de docs/propuesta-1-2.md §10, 2026-10-16) con la
## camara de torre, la fachada y sus pestanas:
##   00_hub_1_2_disponible.png  hub con el 1-1 completado: panel de la carpeta del
##                              Mundo 1 con el 1-2 «Nuevo» y el 1-3 «Proximamente»
##   01_vestibulo.png           llegada (vestibulo, abajo del todo)
##   02_piso1_mensajes.png      piso 1: zigzag, rellano con dos puntos rojos y overlay_1
##   03_piso2_pasillo.png       piso 2: pasillo del banner y sync_1
##   04_acertijo.png            sala del acertijo «Correo certificado» con el cable
##                              encendido (disparo al lector) desde la repisa alta
##   05_piso3_recordatorios.png piso 3: escalera de recordatorios, grupo de 3b y 3c
##   06_piso4_actualizaciones.png piso 4: pasillo del banner y sala de espera
##   07_azotea.png              azotea con la terminal de salida
##   08_fachada_hueco.png       subida entre pisos (la fachada se mueve con el nivel)
## Junto a cada captura del nivel escribe <nombre>.json con el centro de la camara en px del mundo
## (lo usa tools/measure_tower_contrast.py para medir el contraste de las plataformas con el
## fondo; 2026-10-17).
## Necesita ventana (no funciona con --headless). Usa su propio guardado.
## Uso: Godot --path . -s tools/render_level_1_2.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/1-2.tscn"
const HUB_SCENE: String = "res://scenes/hub/hub.tscn"
const SAVE_PATH: String = "user://tool_level_1_2.json"
const DEFAULT_OUT: String = "user://level_1_2"
const SETTLE_FRAMES: int = 60
const WAIT_FRAMES: int = 600
const T: float = 64.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var state: Node = root.get_node(^"GameState")
	state.call(&"use_save_path", SAVE_PATH, true)
	state.call(&"meet_ally", &"eco")
	state.call(&"meet_ally", &"notas")
	state.call(&"mark_level_completed", &"1-1")
	state.call(&"unlock_level", &"1-2")
	await _hub_shot(out_dir)
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var isak: Node2D = level.get_node(^"Isak")
	await _place(isak, 8.0, 60)
	await _save(isak, out_dir, "01_vestibulo.png")
	await _place(isak, 12.0, 48)
	await _save(isak, out_dir, "02_piso1_mensajes.png")
	await _place(isak, 23.0, 42)
	await _save(isak, out_dir, "03_piso2_pasillo.png")
	var reader: Node = level.get_node(^"Objects/lector_1")
	reader.call(&"on_laser_hit", 10.0, isak)
	await _place(isak, 7.0, 33)
	await _save(isak, out_dir, "04_acertijo.png")
	await _place(isak, 18.0, 24)
	await _save(isak, out_dir, "05_piso3_recordatorios.png")
	await _place(isak, 18.0, 16)
	await _save(isak, out_dir, "06_piso4_actualizaciones.png")
	await _place(isak, 20.0, 5)
	await _save(isak, out_dir, "07_azotea.png")
	await _place(isak, 22.0, 46)
	await _save(isak, out_dir, "08_fachada_hueco.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	quit(0)


func _hub_shot(out_dir: String) -> void:
	var hub: Node = (load(HUB_SCENE) as PackedScene).instantiate()
	root.add_child(hub)
	for i: int in WAIT_FRAMES:
		if hub.call(&"has_arrived"):
			break
		await process_frame
	var folder: Node2D = hub.call(&"get_folder", &"m1")
	var isak: Node2D = hub.call(&"get_isak")
	isak.global_position = Vector2(folder.position.x + 96.0, float(hub.call(&"get_shelf_top_y")))
	for i: int in 30:
		await physics_frame
	folder.call(&"open", isak)
	for i: int in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join("00_hub_1_2_disponible.png")
	root.get_texture().get_image().save_png(path)
	print("render_level_1_2: %s" % path)
	hub.free()
	await process_frame


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
	var center: Vector2 = camera.get_screen_center_position()
	var meta := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	if meta != null:
		meta.store_string(JSON.stringify({"camera_center": [center.x, center.y],
				"viewport": [image.get_width(), image.get_height()], "isak": [isak.global_position.x,
				isak.global_position.y]}))
		meta.close()
	print("render_level_1_2: %s (%s) Isak=%s camara=%s" % [path, error_string(err), isak.global_position,
		camera.get_screen_center_position()])
