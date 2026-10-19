## Capturas a 1:1 (1280x720) de la sala de prueba «Vibracion»
## (scenes/levels/vibracion_test.tscn, paso 5 de docs/propuesta-1-3.md §7,
## 2026-10-19), con el Isak real y el metronomo en marcha (ritmo solo visual):
##   01_foso_a_encendida.png   compas lento: A encendida (segmentos), B apagada (punteada), icono latiendo
##   02_foso_a_aviso.png       A parpadea antes de apagarse (9 cuadros)
##   03_foso_b_encendida.png   B encendida, A apagada
##   04_isak_en_b.png          Isak de pie en B
##   05_ola_escalera.png       la ola de tres grupos en la escalera (con el punto de B)
##   06_compas_rapido.png      el compas mas rapido (2,0 s), tras 8 ciclos
##   07_debug.png              con el Debug activo (el compas va en tiempo del mundo: mas lento)
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_vibracion_test.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/vibracion_test.tscn"
const DEFAULT_OUT: String = "user://vibracion_test"
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
	_state.call(&"mark_notice_seen", &"debug")
	_level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_level)
	_isak = _level.get_node(^"Isak")
	var rhythm: Node = _level.get_node(^"Objects/ritmo_v")
	var a: Node = _level.get_node(^"Objects/blink_2a_a")
	var b: Node = _level.get_node(^"Objects/blink_2a_b")
	# --- Foso: grupos alternos ---
	await _place(7.0, 9)
	await _until(func() -> bool: return bool(rhythm.call(&"is_started")), 60, "arranque")
	await _until(func() -> bool: return float(rhythm.call(&"get_beat_phase")) > 0.15, 200, "solo A")
	await _save("01_foso_a_encendida.png")
	await _until(func() -> bool: return bool(a.call(&"is_warning")), 200, "aviso de A")
	await _frames(8)
	await _save("02_foso_a_aviso.png")
	await _until(func() -> bool: return not bool(a.call(&"is_solid")), 200, "A apagada")
	await _frames(6)
	await _save("03_foso_b_encendida.png")
	_isak.global_position = Vector2(13.0 * T, 10.0 * T - 4.0)
	_isak.set(&"velocity", Vector2.ZERO)
	await _frames(10)
	await _save("04_isak_en_b.png")
	# --- Escalera en ola ---
	await _place(20.0, 9)
	await _until(func() -> bool:
		var ph: float = float(rhythm.call(&"get_beat_phase"))
		return ph > 0.38 and ph < 0.45, 400, "ola: A y B")
	await _save("05_ola_escalera.png")
	# --- Compas rapido ---
	await _until(func() -> bool: return int(rhythm.call(&"get_step_index")) == 2, 60 * 30, "compas rapido")
	await _place(11.0, 9)
	await _save("06_compas_rapido.png")
	# --- Debug ---
	Input.action_press(&"debug")
	await _until(func() -> bool: return bool(root.get_node(^"DebugMode").call(&"is_active")), 120, "Debug")
	await _frames(20)
	await _save("07_debug.png")
	Input.action_release(&"debug")
	if b == null:
		_ok = false
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
	push_error("render_vibracion_test: no se llego a '%s'" % what)


## Pide la ayuda (accion help, como un jugador) y completa el texto de Eco.
func _ask_help(box: Node) -> void:
	var press := InputEventAction.new()
	press.action = &"help"
	press.pressed = true
	root.push_input(press)
	await create_timer(0.6).timeout
	var release := InputEventAction.new()
	release.action = &"help"
	release.pressed = false
	root.push_input(release)
	if not bool(box.call(&"is_showing")):
		_ok = false
		push_error("render_vibracion_test: la ayuda no se abrio")
	box.call(&"finish_typing")
	await create_timer(0.3).timeout


func _close_box(box: Node) -> void:
	while box.call(&"confirm"):
		pass
	await create_timer(0.8).timeout


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_vibracion_test: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
