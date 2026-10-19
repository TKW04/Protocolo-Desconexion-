## Capturas a 1:1 (1280x720) de la sala de prueba «Alarmas»
## (scenes/levels/alarmas_test.tscn, paso 6 de docs/propuesta-1-3.md §7,
## 2026-10-19), con el Isak real (acciones del Input Map):
##   01_entrada.png           la entrada del tunel (icono de vibracion del metronomo)
##   02_4a_aviso.png          4a (2,0 s): una campana tiembla y marca su columna en el suelo
##   03_4a_onda.png           su onda hasta el suelo
##   04_4a_banner.png         el banner del 4a barre en el mismo compas
##   05_4b_techo_bajo.png     4b (1,6 s): techo de 2 filas con la campana
##   06_4c_onda.png           4c (1,4 s): onda bajo el techo bajo
##   07_4c_dash.png           Isak se desliza a traves de la onda
##   08_4c_banner.png         el banner del 4c, mas rapido
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_alarmas_test.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/alarmas_test.tscn"
const DEFAULT_OUT: String = "user://alarmas_test"
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
	_state.call(&"mark_notice_seen", &"dash")
	_level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_level)
	_isak = _level.get_node(^"Isak")
	var tunnel: Node = _level.get_node(^"Objects/tunel_alarmas")
	var bell_4a: Node = _level.get_node(^"Enemies/bell_4a_1")
	var bell_4b: Node = _level.get_node(^"Enemies/bell_4b_2")
	var bell_4c: Node = _level.get_node(^"Enemies/bell_4c_1")
	var banner_4a: Node = _level.get_node(^"Enemies/banner_4a")
	var banner_4c: Node = _level.get_node(^"Enemies/banner_4c")
	await _place(3.0, 10)
	await _save("01_entrada.png")
	await _place(7.0, 10)
	# A mitad del aviso, en un cuadro con la linea del suelo encendida (parpadea cada 0,125 s).
	await _until(func() -> bool: return bool(bell_4a.call(&"is_warning")) \
		and float(bell_4a.call(&"get_cycle_time")) > 0.27 and float(bell_4a.call(&"get_cycle_time")) < 0.35, 400,
		"aviso 4a")
	await _save("02_4a_aviso.png")
	await _until(func() -> bool: return bool(bell_4a.call(&"is_wave")), 120, "onda 4a")
	await _frames(6)
	await _save("03_4a_onda.png")
	await _until(func() -> bool: return bool(banner_4a.call(&"is_sweeping")), 300, "banner 4a")
	await _frames(8)
	await _save("04_4a_banner.png")
	await _place(19.0, 10)
	await _until(func() -> bool: return bool(bell_4b.call(&"is_wave")), 300, "onda 4b")
	await _frames(6)
	await _save("05_4b_techo_bajo.png")
	await _place(24.0, 10)
	await _until(func() -> bool: return absf(float(tunnel.call(&"get_cycle_s")) - 1.4) < 0.01, 60, "compas 4c")
	await _until(func() -> bool: return bool(bell_4c.call(&"is_wave")), 300, "onda 4c")
	await _frames(4)
	await _save("06_4c_onda.png")
	(_isak as Node).set(&"facing", 1.0)
	Input.action_press(&"move_right")
	Input.action_press(&"gesture_swipe")
	await physics_frame
	await physics_frame
	Input.action_release(&"gesture_swipe")
	await _frames(5)
	await _save("07_4c_dash.png")
	Input.action_release(&"move_right")
	await _place(25.0, 10)
	await _until(func() -> bool: return bool(banner_4c.call(&"is_sweeping")), 300, "banner 4c")
	await _frames(6)
	await _save("08_4c_banner.png")
	quit(0 if _ok else 1)


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
	push_error("render_alarmas_test: no se llego a '%s'" % what)


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_alarmas_test: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
