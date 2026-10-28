## Capturas a 1:1 (1280x720) del arte final del Troll y de la pose de Agitar
## (paso 24 de docs/propuesta-mundo-4.md, etapa 3b, 2026-10-28;
## docs/plan-arte-mundo-4.md), con el Isak real (acciones del Input Map):
##   Sala grupo_test (tres Trolls, un disfrazado):
##   01_troll_reposo.png        reposo (Isak fuera de su alcance)
##   02_troll_aviso.png         «escribiendo…»: el bocadillo sobre la capucha
##   03_troll_lanza.png         lanza el mensaje (sube el movil)
##   04_agitar_sacude.png       Isak sacude el celular (anticipacion)
##   05_agitar_onda.png         la onda nace: brazo extendido
##   06_trolls_aturdidos.png    los tres aturdidos por Agitar
##   07_disfrazado.png          el disfrazado (burbuja de amigo)
##   08_disfrazado_debug.png    con el Debug: costuras rojas
##   09_descubriendose.png      Isak cerca: el avatar aparece
##   10_descubierto.png         Troll normal tras descubrirse
##   Sala oscuro_test (se anade un Troll dentro del Modo oscuro, sin Linterna):
##   11_oscuro_reposo.png       contorno rojo por encima del velo
##   12_oscuro_aviso.png        el aviso por encima del velo
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --fixed-fps 60 --path . -s tools/render_troll_art.gd [-- carpeta_salida]
extends SceneTree

const DEFAULT_OUT: String = "user://troll_art"
const SETTLE_FRAMES: int = 30
const T: float = 64.0

var _out: String
var _level: Node
var _isak: Node2D
var _state: Node
var _ok: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	_state = root.get_node(^"GameState")
	_state.call(&"reset_progress")
	for notice: StringName in [&"shockwave", &"pulse", &"laser", &"debug"]:
		_state.call(&"mark_notice_seen", notice)
	await _grupo()
	await _oscuro()
	quit(0 if _ok else 1)


func _load(scene: String) -> void:
	if _level != null:
		_level.queue_free()
		await process_frame
	_level = (load(scene) as PackedScene).instantiate()
	root.add_child(_level)
	_isak = _level.get_node(^"Isak")
	await _frames(5)


func _grupo() -> void:
	await _load("res://scenes/levels/grupo_test.tscn")
	var suelo: Node = _level.get_node(^"Enemies/troll_suelo")
	var mimic: Node = _level.get_node(^"Enemies/troll_lia")
	await _place(1.0, 9)
	await _frames(30)
	await _save("01_troll_reposo.png")
	await _place(6.0, 9)
	await _until(func() -> bool: return _typing_frame(suelo) >= 5, 300, "aviso")
	await _save("02_troll_aviso.png")
	await _until(func() -> bool: return String(suelo.call(&"get_art_frame")[0]) == "shot", 60, "lanza")
	await _frames(3)
	await _save("03_troll_lanza.png")
	# Agitar entre los tres Trolls (radio 160).
	_state.set(&"debug_energy", 100.0)
	await _place(13.0, 9)
	for e: Node in _level.get_node(^"Enemies").get_children():
		if e.has_method(&"reset_patrol"):
			e.call(&"reset_patrol")
	Input.action_press(&"gesture_shake")
	await physics_frame
	Input.action_release(&"gesture_shake")
	await _until(func() -> bool: return bool(_isak.call(&"is_shockwaving")), 20, "Agitar")
	await _frames(4)
	await _save("04_agitar_sacude.png")
	await _until(func() -> bool: return (_isak.call(&"get_shockwave_effect") as Node).call(&"is_wave_visible"), 30, "onda")
	await _frames(5)
	await _save("05_agitar_onda.png")
	await _frames(40)
	await _save("06_trolls_aturdidos.png")
	if not bool(suelo.call(&"is_stunned")):
		_ok = false
		push_error("render_troll_art: Agitar no aturdio al Troll del suelo")
	# Disfrazado.
	for e: Node in _level.get_node(^"Enemies").get_children():
		if e.has_method(&"reset_patrol"):
			e.call(&"reset_patrol")
	await _place(17.0, 9)
	await _save("07_disfrazado.png")
	_state.call(&"set_ability_unlocked", &"debug", true)
	_state.set(&"debug_energy", 100.0)
	Input.action_press(&"debug")
	await _until(func() -> bool: return bool(mimic.call(&"is_revealed_by_debug")), 120, "Debug")
	await _frames(10)
	await _save("08_disfrazado_debug.png")
	Input.action_release(&"debug")
	await _frames(120)
	await _place(19.5, 9)
	await _until(func() -> bool: return mimic.call(&"get_mask_state") == &"unmasking", 60, "descubriendose")
	await _frames(5)
	await _save("09_descubriendose.png")
	await _until(func() -> bool: return mimic.call(&"get_mask_state") == &"open", 60, "descubierto")
	await _frames(3)
	await _save("10_descubierto.png")


func _oscuro() -> void:
	await _load("res://scenes/levels/oscuro_test.tscn")
	var troll: Node2D = (load("res://scenes/enemies/troll.tscn") as PackedScene).instantiate()
	troll.position = Vector2(13.5 * T, 10.0 * T)
	troll.set(&"facing", 1)
	var host: Node = _level.get_node_or_null(^"Enemies")
	(host if host != null else _level).add_child(troll)
	await _place(28.0, 9)
	await _frames(30)
	await _save("11_oscuro_reposo.png")
	await _place(19.0, 9)
	await _until(func() -> bool: return _typing_frame(troll) >= 5, 300, "aviso en el Modo oscuro")
	await _save("12_oscuro_aviso.png")
	if not bool(troll.call(&"is_in_dark")):
		_ok = false
		push_error("render_troll_art: el Troll no quedo bajo el velo")


## Cuadro del arte de «escribiendo…» (-1 si no avisa).
func _typing_frame(troll: Node) -> int:
	var f: Array = troll.call(&"get_art_frame")
	return int(f[1]) if String(f[0]) == "typing" else -1


func _place(col: float, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	_isak.set(&"velocity", Vector2.ZERO)
	if _isak.has_method(&"snap_camera"):
		_isak.call(&"snap_camera")
	await _frames(SETTLE_FRAMES)


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _until(condition: Callable, max_frames: int, what: String) -> void:
	for i: int in max_frames:
		if condition.call():
			return
		await physics_frame
	_ok = false
	push_error("render_troll_art: no se llego a '%s'" % what)


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_troll_art: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
