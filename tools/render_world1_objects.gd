## Capturas a 1:1 (1280x720) de scenes/levels/world1_objects_test.tscn:
##   1_puente_antes.png     Isak junto al receptor apagado, puente retraido
##   2_puente_extendiendo.png  justo despues del pulso (G): receptor activado,
##                             tiles apareciendo de izquierda a derecha
##   3_puente_despues.png   Isak cruzando sobre el puente extendido
##   4_pared_glitch.png     Isak junto a la pared con glitch, durante una rafaga
##   5_debug.png            la misma vista con el Debug activo (tinte sobre el fondo)
## Necesita ventana (no funciona con --headless). Se puede lanzar con
## --write-movie para guardar tambien todos los cuadros.
## Uso: Godot --path . -s tools/render_world1_objects.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/world1_objects_test.tscn"
const DEFAULT_OUT: String = "user://world1_objects"
const SETTLE_FRAMES: int = 40
## Isak a la izquierda del receptor, mirando a la derecha (pies en y = 576).
const ISAK_AT_RECEIVER: Vector2 = Vector2(550, 575)
const ISAK_ON_BRIDGE: Vector2 = Vector2(864, 575)
const ISAK_AT_WALL: Vector2 = Vector2(1330, 575)
const HOLD_DEBUG_FRAMES: int = 70


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var isak: Node2D = level.get_node(^"Isak")
	var bridge: Node = level.get_node(^"Bridge")
	var wall: Node = level.get_node(^"GlitchWall")
	await _place(isak, ISAK_AT_RECEIVER, SETTLE_FRAMES)
	await _save(out_dir, "1_puente_antes.png")
	Input.action_press(&"pulse")
	await physics_frame
	Input.action_release(&"pulse")
	for i: int in 14:
		await physics_frame
	await _save(out_dir, "2_puente_extendiendo.png")
	for i: int in 40:
		await physics_frame
	print("render_world1_objects: puente extendido = %s" % bridge.call(&"is_extended"))
	# Cruza caminando hasta el centro del puente
	Input.action_press(&"move_right")
	for i: int in 300:
		await physics_frame
		if isak.global_position.x >= ISAK_ON_BRIDGE.x:
			break
	Input.action_release(&"move_right")
	for i: int in 6:
		await physics_frame
	print("render_world1_objects: Isak en x=%.0f y=%.0f" % [isak.global_position.x, isak.global_position.y])
	await _save(out_dir, "3_puente_despues.png")
	await _place(isak, ISAK_AT_WALL, SETTLE_FRAMES)
	for i: int in 400:
		await process_frame
		if int(wall.call(&"get_cell_frame", 0)) != 0 or int(wall.call(&"get_cell_frame", 1)) != 0:
			break
	await _save(out_dir, "4_pared_glitch.png")
	Input.action_press(&"debug")
	for i: int in HOLD_DEBUG_FRAMES:
		await physics_frame
	Input.action_release(&"debug")
	for i: int in 30:
		await physics_frame
	await _save(out_dir, "5_debug.png")
	quit(0)


func _place(isak: Node2D, pos: Vector2, frames: int) -> void:
	isak.global_position = pos
	isak.set(&"velocity", Vector2.ZERO)
	for i: int in frames:
		await physics_frame


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_world1_objects: %s (%s)" % [path, error_string(err)])
