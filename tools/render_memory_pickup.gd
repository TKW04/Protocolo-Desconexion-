## Capturas a 1:1 (1280x720) del mensaje de secreto recogible (memory_pickup; paso 4
## de docs/propuesta-recuerdos.md §7, 2026-10-19) con el flujo de juego real
## (scenes/main.tscn) y el guardado de herramientas (user://tool_save.json; nunca el
## del jugador). La partida conoce a Eco y a Notas y ha aprendido todos los tipos
## salvo el mensaje:
##   01_sobre_secreto_a.png   el sobre en el secreto A del 1-1 (celda 96, 4) junto al
##                            punto del secreto
##   02_aviso_recuerdo.png    tras recogerlo: aviso del sistema «Recuerdo obtenido:
##                            Mamá.» / «Guarda en Notas para conservarlo.»
##   03_spam_sobre_y_punto.png carpeta de Spam del 1-2: el sobre en la mitad alta de la
##                            celda (26, 37), sobre el punto de esa celda
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_memory_pickup.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const DEFAULT_OUT: String = "user://memory_pickup_shots"
const TILE: float = 64.0

var _main: Node
var _ok: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var state: Node = root.get_node(^"GameState")
	state.call(&"meet_ally", &"eco")
	state.call(&"meet_ally", &"notas")
	state.call(&"mark_notice_seen", &"pulse")
	state.call(&"obtain_ability", &"pulse")
	var catalog: Object = load("res://scripts/levels/help_catalog.gd").call(&"shared")
	for id: StringName in catalog.call(&"ids"):
		if id != &"memory_pickup":
			state.call(&"learn_help", id)
	# (1) y (2): 1-1.
	await _start("1-1")
	var isak: Node2D = _main.call(&"get_isak")
	var level: Node = _main.call(&"get_level")
	var pickup: Node2D = level.get_node_or_null(^"Objects/mensaje_1_1")
	_check(pickup != null, "no esta el sobre del 1-1")
	_stand(isak, 99, 4, -1.0)
	await _frames(120)
	await _save(out_dir, "01_sobre_secreto_a.png")
	_stand(isak, 96, 4, -1.0)
	await _frames(20)
	_check(bool(state.call(&"has_memory", &"msg_1_1")), "no se obtuvo msg_1_1")
	_check(level.get_node_or_null(^"MemoryNotice") != null, "no salio el aviso")
	await _save(out_dir, "02_aviso_recuerdo.png")
	# (3): 1-2, carpeta de Spam.
	_main.queue_free()
	await _frames(2)
	await _start("1-2")
	isak = _main.call(&"get_isak")
	_stand(isak, 23, 37, 1.0)
	await _frames(120)
	await _save(out_dir, "03_spam_sobre_y_punto.png")
	print("render_memory_pickup: %s" % ("OK" if _ok else "con errores"))
	quit(0 if _ok else 1)


func _start(level_id: String) -> void:
	_main = (load(SCENE) as PackedScene).instantiate()
	_main.set(&"start_level_id", level_id)
	root.add_child(_main)
	var isak: Node2D = _main.call(&"get_isak")
	await _wait(func() -> bool: return not paused and not isak.call(&"is_warping"), 30.0)
	await _frames(30)


func _stand(isak: Node2D, col: int, row: int, facing: float) -> void:
	isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	isak.set(&"velocity", Vector2.ZERO)
	isak.set(&"facing", facing)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		push_error("render_memory_pickup: " + what)


func _wait(cond: Callable, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_confirm_lines()
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _frames(n: int) -> void:
	for i: int in n:
		_confirm_lines()
		await process_frame


## Cierra (como el jugador) las lineas importantes de Eco, que pausan el juego.
func _confirm_lines() -> void:
	if not is_instance_valid(_main):
		return
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
	print("render_memory_pickup: %s (%s)" % [path, error_string(err)])
