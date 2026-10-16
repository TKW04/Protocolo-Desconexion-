## Capturas a 1:1 (1280x720) de la sala de prueba de los enemigos del 1-2
## (scenes/levels/mensajes_test.tscn, pasos 4 y 5 de docs/propuesta-1-2.md §10,
## 2026-10-16), jugando con el Isak real (acciones del Input Map) y Eco:
##   01_q_punto_rojo.png        Eco junto al punto rojo con la Q dorada
##   02_ayuda_punto_rojo.png    su ayuda abierta (juego en pausa)
##   03_q_banner.png            Eco junto al banner con la Q
##   04_ayuda_banner.png        su ayuda abierta
##   10_punto_rojo_dormido.png  dormido en su sitio
##   11_punto_rojo_persigue.png persiguiendo (halo)
##   12_punto_rojo_aviso.png    inflandose antes de lanzarse
##   13_punto_rojo_aturdido.png tras el pulso: gris con chispas (escalon)
##   14_primer_disparo.png      aturdido, el laser le quita vida (parpadeo)
##   15_rematado.png            segundo disparo: derrotado y drops
##   16_laser_rebota.png        otro punto rojo despierto: chispa gris, sin dano
##   17_punto_rojo_despierta.png  fin del aturdimiento (aviso)
##   20_banner_aviso.png        ranura parpadeando y linea del suelo (Isak en el nicho)
##   21_banner_barrido.png      el banner barriendo el pasillo con su estela
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_mensajes_test.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/mensajes_test.tscn"
const DEFAULT_OUT: String = "user://mensajes_test"
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
	_state.call(&"mark_notice_seen", &"laser")
	_state.call(&"meet_ally", &"eco")
	# El cargador de la entrada ya conocido: la Q va a los enemigos nuevos.
	_state.call(&"learn_help", &"charger")
	_level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_level)
	_isak = _level.get_node(^"Isak")
	var companion_script: GDScript = load("res://scripts/levels/eco_companion.gd") as GDScript
	companion_script.call(&"attach", _isak, _level)
	var badge_1: Node = _level.get_node(^"Enemies/badge_1")
	var badge_2: Node = _level.get_node(^"Enemies/badge_2")
	var banner_1: Node = _level.get_node(^"Enemies/banner_1")
	var help: Node = _level.get_node(^"Help")
	var box: Node = _level.get_node(^"EcoTextBox")
	# --- Ayudas Q (con los puntos rojos quietos) ---
	var banner_2: Node = _level.get_node(^"Enemies/banner_2")
	for e: Node in [badge_1, badge_2, banner_1, banner_2]:
		e.set_physics_process(false)
	await _place(6.0, 10)
	await _until(func() -> bool: return help.call(&"get_target") == badge_1, 240, "Q del punto rojo")
	await _frames(40)
	await _save("01_q_punto_rojo.png")
	await _ask_help(box)
	await _save("02_ayuda_punto_rojo.png")
	await _close_box(box)
	await _place(23.0, 10)
	await _until(func() -> bool: return help.call(&"get_target") == banner_1, 240, "Q del banner")
	await _frames(40)
	await _save("03_q_banner.png")
	await _ask_help(box)
	await _save("04_ayuda_banner.png")
	await _close_box(box)
	for e: Node in [banner_1, banner_2]:
		e.set_physics_process(true)
		e.call(&"reset_patrol")
	# --- Punto rojo: estados y «aturdir y rematar» ---
	badge_1.set_physics_process(true)
	await _place(2.0, 10)
	await _frames(20)
	await _save("10_punto_rojo_dormido.png")
	_isak.global_position.x = 4.5 * T
	await _until(func() -> bool: return badge_1.call(&"get_state") == &"chase", 120, "persecucion")
	await _frames(25)
	await _save("11_punto_rojo_persigue.png")
	await _until(func() -> bool: return badge_1.call(&"get_state") == &"anticipate", 400, "aviso")
	await _frames(5)
	await _save("12_punto_rojo_aviso.png")
	await _act(&"pulse", 0)
	await _until(func() -> bool: return bool(badge_1.call(&"is_stunned")), 40, "aturdido")
	await _frames(12)
	await _save("13_punto_rojo_aturdido.png")
	await _act(&"laser", 0)
	await _until(func() -> bool: return float(badge_1.call(&"get_health")) < 2.0, 60, "primer disparo")
	await _frames(2)
	await _save("14_primer_disparo.png")
	await _frames(20)
	await _act(&"laser", 0)
	await _until(func() -> bool: return bool(badge_1.call(&"is_defeated")), 60, "rematado")
	await _frames(4)
	await _save("15_rematado.png")
	# --- Otro punto rojo despierto: el laser rebota; despues, fin del aturdimiento ---
	badge_2.set_physics_process(true)
	await _place(8.0, 10)
	await _until(func() -> bool:
		var b: Node2D = badge_2 as Node2D
		var dx: float = b.global_position.x - _isak.global_position.x
		return absf(b.global_position.y - 32.0 - (_isak.global_position.y - 56.0)) < 20.0 \
			and dx > 100.0 and dx < 400.0, 900, "punto rojo a la altura del laser")
	(_isak as Node).set(&"facing", 1.0)
	await _act(&"laser", 0)
	await _until(func() -> bool: return bool(badge_2.call(&"is_deflecting")), 40, "chispa gris")
	await _frames(1)
	await _save("16_laser_rebota.png")
	await _place(9.0, 10)
	await _until(func() -> bool: return badge_2.call(&"get_state") == &"anticipate", 900, "aviso 2")
	await _act(&"pulse", 0)
	await _until(func() -> bool: return badge_2.call(&"get_state") == &"wake", 400, "despertando")
	await _frames(5)
	await _save("17_punto_rojo_despierta.png")
	# --- Banner ---
	badge_2.set_physics_process(false)
	await _place(26.0, 7)
	await _until(func() -> bool: return bool(banner_1.call(&"is_warning")), 400, "aviso del banner")
	# A media ventana de aviso (el otro banner, desfasado, ya ha terminado su barrido).
	await _frames(30)
	await _save("20_banner_aviso.png")
	await _until(func() -> bool: return bool(banner_1.call(&"is_sweeping")) \
		and float(banner_1.call(&"get_banner_center_x")) > 25.0 * T, 400, "barrido")
	await _save("21_banner_barrido.png")
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
	push_error("render_mensajes_test: no se llego a '%s'" % what)


func _act(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	await _frames(frames)


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
		push_error("render_mensajes_test: la ayuda no se abrio")
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
	print("render_mensajes_test: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
