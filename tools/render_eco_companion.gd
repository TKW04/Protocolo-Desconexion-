## Capturas a 1:1 (1280x720) de Eco companero (EcoCompanion,
## data/eco_companion.json) y de la entrada del apodo (NicknameEntry,
## data/nickname_entry.json); docs/propuesta-asistentes-y-vidas.md, pasos 4 y 5
## de §10. Flujo real (scenes/main.tscn) con un guardado vacio de herramientas
## (user://tool_save.json; nunca el guardado del jugador):
##   01_eco_hablando.png       la bienvenida del 1-1 (pausa): Eco acaba de aparecer y habla
##   01_eco_hablando_zoom.png  recorte x3 alrededor de Isak y Eco
##   02_eco_junto_a_isak.png   Eco siguiendo a Isak en el Tramo 1 (tras caminar)
##   02_eco_junto_a_isak_zoom.png
##   03_hub_atenuada.png       Eco en el hub, atenuada (sin cobertura)
##   03_hub_atenuada_zoom.png
##   04_apodo.png              la entrada del apodo recien abierta («Isak»)
##   05_apodo_escrito.png      tras escribir otro apodo
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_eco_companion.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const HUB_SCENE: String = "res://scenes/hub/hub.tscn"
const NICKNAME_SCENE: String = "res://scenes/ui/nickname_entry.tscn"
const DEFAULT_OUT: String = "user://eco_companion_shots"
const ZOOM: int = 3
const CROP: Vector2i = Vector2i(200, 150)

var _main: Node
var _out: String


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	var game_state: Node = root.get_node(^"GameState")
	_main = (load(SCENE) as PackedScene).instantiate()
	_main.set(&"start_level_id", "1-1")
	root.add_child(_main)
	var isak: Node2D = _main.call(&"get_isak")
	var eco: Node2D = _main.call(&"get_eco_companion")
	var level: Node = _main.call(&"get_level")
	var box: Node = level.get_node(^"EcoTextBox")
	# Bienvenida: Eco queda conocido, aparece y habla con el juego en pausa.
	var ok_talk: bool = false
	for i: int in 60 * 20:
		await process_frame
		if paused and box.call(&"is_important") and eco.call(&"is_shown"):
			break
	await create_timer(1.6).timeout
	ok_talk = eco.call(&"get_animation") == &"talk"
	await _save("01_eco_hablando.png", isak.get_global_transform_with_canvas().origin)
	# Cierra las lineas importantes y camina un poco a la derecha.
	for i: int in 60 * 20:
		_confirm_lines(box)
		await process_frame
		if game_state.call(&"is_notice_seen", &"pulse") and not paused and not isak.call(&"is_warping"):
			break
	Input.action_press(&"move_right")
	await create_timer(0.8).timeout
	Input.action_release(&"move_right")
	await create_timer(0.9).timeout
	var ok_follow: bool = eco.call(&"is_shown") and eco.global_position.distance_to(isak.global_position) < 200.0
	await _save("02_eco_junto_a_isak.png", isak.get_global_transform_with_canvas().origin)
	_main.queue_free()
	await process_frame
	# Hub: Eco ya conocido, entra atenuada con Isak.
	var hub: Node = (load(HUB_SCENE) as PackedScene).instantiate()
	root.add_child(hub)
	await create_timer(2.5).timeout
	var hub_eco: Node2D = hub.call(&"get_eco_companion")
	var ok_hub: bool = hub_eco != null and hub_eco.call(&"is_shown") and hub_eco.call(&"is_dim")
	var hub_isak: Node2D = hub.call(&"get_isak")
	await _save("03_hub_atenuada.png", hub_isak.get_global_transform_with_canvas().origin)
	# Entrada del apodo sobre el hub.
	var entry: Node = (load(NICKNAME_SCENE) as PackedScene).instantiate()
	entry.set(&"free_on_close", false)
	root.add_child(entry)
	await create_timer(0.3).timeout
	var ok_pause: bool = paused
	await _save("04_apodo.png")
	entry.call(&"type_text", "Ñandú 7")
	await create_timer(0.2).timeout
	await _save("05_apodo_escrito.png")
	entry.call(&"accept")
	var ok_name: bool = game_state.call(&"get_nickname") == "Ñandú 7" and not paused
	print("render_eco_companion: habla=%s sigue=%s hub=%s pausa=%s apodo=%s"
		% [ok_talk, ok_follow, ok_hub, ok_pause, ok_name])
	entry.queue_free()
	hub.queue_free()
	await process_frame
	quit(0 if ok_talk and ok_follow and ok_hub and ok_pause and ok_name else 1)


func _confirm_lines(box: Node) -> void:
	while box != null and is_instance_valid(box) and box.call(&"is_important") and box.call(&"confirm"):
		pass


## Guarda la pantalla y, con `focus` (px de pantalla), un recorte ampliado xZOOM.
func _save(file_name: String, focus: Vector2 = Vector2(-1, -1)) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	print("render_eco_companion: %s (%s)" % [path, error_string(image.save_png(path))])
	if focus.x < 0.0:
		return
	var size: Vector2i = CROP
	var origin := Vector2i(focus) - Vector2i(size.x / 2, size.y * 3 / 4)
	origin = origin.clamp(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()) - size)
	var crop: Image = image.get_region(Rect2i(origin, size))
	crop.resize(size.x * ZOOM, size.y * ZOOM, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join(file_name.get_basename() + "_zoom.png"))
