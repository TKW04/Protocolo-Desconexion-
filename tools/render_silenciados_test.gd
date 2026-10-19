## Capturas a 1:1 (1280x720) de la sala de prueba «Silenciados»
## (scenes/levels/silenciados_test.tscn, paso 4 de docs/propuesta-1-3.md §7,
## 2026-10-19), jugando con el Isak real (acciones del Input Map) y Eco:
##   01_q_banner_dash.png       Eco junto al banner obligatorio con la Q dorada
##   02_ayuda_banner_dash.png   su ayuda propia (spam_banner_dash; texto propuesto)
##   10_aviso.png               la ranura avisa (Isak en la entrada del pasillo)
##   11_barrido.png             el banner barre el pasillo de techo bajo hacia Isak
##   12_dash_atraviesa.png      Isak se desliza a traves del banner (invulnerable)
##   13_tras_el_dash.png        Isak detras del banner, sin dano
##   14_golpe_vuelta.png        andando: el golpe lo devuelve a la entrada (-10)
##   20_nicho.png               el banner del 1b pasa por debajo del nicho
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_silenciados_test.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/silenciados_test.tscn"
const DEFAULT_OUT: String = "user://silenciados_test"
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
	_state.call(&"meet_ally", &"eco")
	# El cargador de la entrada ya conocido: la Q va al banner.
	_state.call(&"learn_help", &"charger")
	_level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_level)
	_isak = _level.get_node(^"Isak")
	var companion_script: GDScript = load("res://scripts/levels/eco_companion.gd") as GDScript
	companion_script.call(&"attach", _isak, _level)
	var banner: Node = _level.get_node(^"Enemies/banner_dash")
	var banner_1b: Node = _level.get_node(^"Enemies/banner_1b")
	var help: Node = _level.get_node(^"Help")
	var box: Node = _level.get_node(^"EcoTextBox")
	# --- Ayuda Q (banners quietos) ---
	for e: Node in [banner, banner_1b]:
		e.set_physics_process(false)
	await _place(15.0, 10)
	await _until(func() -> bool: return help.call(&"get_target") == banner, 240, "Q del banner obligatorio")
	await _frames(40)
	await _save("01_q_banner_dash.png")
	await _ask_help(box)
	await _save("02_ayuda_banner_dash.png")
	await _close_box(box)
	_state.call(&"learn_help", &"spam_banner")
	for e: Node in [banner, banner_1b]:
		e.set_physics_process(true)
		e.call(&"reset_patrol")
	# --- Pasillo obligatorio: aviso, barrido y dash ---
	await _place(5.0, 10)
	await _until(func() -> bool: return bool(banner.call(&"is_warning")), 400, "aviso")
	await _frames(25)
	await _save("10_aviso.png")
	await _until(func() -> bool: return bool(banner.call(&"is_sweeping")), 120, "barrido")
	Input.action_press(&"move_right")
	Input.action_press(&"run")
	await _until(func() -> bool:
		var rect: Rect2 = banner.call(&"get_damage_rect")
		return rect.position.x - _isak.global_position.x < 260.0, 240, "banner cerca")
	await _save("11_barrido.png")
	await _until(func() -> bool:
		var rect: Rect2 = banner.call(&"get_damage_rect")
		return rect.position.x - _isak.global_position.x < 80.0, 240, "banner a un tile")
	var sync0: float = float(_state.get(&"sync_rate"))
	Input.action_press(&"gesture_swipe")
	await physics_frame
	await physics_frame
	Input.action_release(&"gesture_swipe")
	await _frames(4)
	await _save("12_dash_atraviesa.png")
	await _until(func() -> bool: return not bool(_isak.call(&"is_dashing")), 60, "fin del dash")
	Input.action_release(&"run")
	Input.action_release(&"move_right")
	await _frames(12)
	await _save("13_tras_el_dash.png")
	if float(_state.get(&"sync_rate")) < sync0:
		_ok = false
		push_error("render_silenciados_test: el dash no atraveso el banner sin dano")
	# --- Andando: el golpe devuelve a la entrada ---
	await _place(5.0, 10)
	await _until(func() -> bool: return bool(banner.call(&"is_sweeping")), 400, "barrido 2")
	Input.action_press(&"move_right")
	var hit_sync: float = float(_state.get(&"sync_rate"))
	await _until(func() -> bool: return float(_state.get(&"sync_rate")) < hit_sync, 400, "golpe")
	Input.action_release(&"move_right")
	await _frames(10)
	await _save("14_golpe_vuelta.png")
	# --- Nicho del 1b ---
	await _place(27.0, 8)
	await _until(func() -> bool: return bool(banner_1b.call(&"is_sweeping")) \
		and float(banner_1b.call(&"get_banner_center_x")) > 26.0 * T, 400, "barrido bajo el nicho")
	await _save("20_nicho.png")
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
	push_error("render_silenciados_test: no se llego a '%s'" % what)


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
		push_error("render_silenciados_test: la ayuda no se abrio")
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
	print("render_silenciados_test: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
