## Capturas a 1:1 (1280x720) de las salas de prueba de los pisos 3 y 4 del 1-2
## (pasos 6, 7 y 8 de docs/propuesta-1-2.md §10, 2026-10-16), jugando con el
## Isak real (acciones del Input Map) y Eco:
##   recordatorios_test
##     01_q_recordatorio.png        Eco junto al recordatorio con la Q dorada
##     02_ayuda_recordatorio.png    su ayuda abierta (juego en pausa)
##     03_recordatorio_estable.png  en reposo, con el indicador lleno
##     04_recordatorio_contando.png Isak encima: la cuenta baja (segmentos)
##     05_recordatorio_aviso.png    los ultimos cuadros: suena y tiembla
##     06_recordatorio_cayendo.png  ha vencido: se parte y cae (Isak cae al foso)
##     07_recordatorio_caido.png    sin recordatorio, Isak en el foso
##     08_recordatorio_repuesto.png vuelve a su sitio
##     09_q_posponer.png            Eco junto al boton Posponer con la Q
##     10_ayuda_posponer.png        su ayuda abierta
##     11_posponer_sin_cuenta.png   laser sin nada que posponer: chispa gris
##     12_posponer_golpeado.png     desde el segundo recordatorio: «Zzz» y «Zz» en el grupo
##     13_posponer_enfriandose.png  el anillo se rellena (enfriamiento)
##   overlay_test
##     20_overlay_sin_debug.png     el pop-up tapa la plataforma de la subida
##     21_q_overlay.png / 22_ayuda_overlay.png
##     23_overlay_con_debug.png     con el Debug se ve a traves (contorno cian)
##     24_overlay_cerrandose.png    pulso al boton desde el suelo: se pliega
##     25_overlay_cerrado.png       cerrado: se ve la plataforma
##   actualizaciones_test
##     30_barra_97.png              la puerta-barra «Instalando… 97 %»
##     31_q_barra.png / 32_ayuda_barra.png
##     33_barra_trabada.png         Isak en la sala: trabada en 99 %
##     34_oleada_aviso.png          flechas rojas en el techo y sombras en el suelo
##     35_paquetes_cayendo.png      los paquetes caen
##     36_oleada_enemigos.png       Burbujas sueltas en la sala
##     37_barra_calculando.png      «Calculando tiempo restante…» con puntos rojos
##     38_barra_completada.png      100 % «Reiniciando…»: los que quedan se apagan
##     39_barra_abierta.png         la puerta recogida: paso libre
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_tower_rooms.gd [-- carpeta_salida]
extends SceneTree

const DEFAULT_OUT: String = "user://tower_rooms"
const SETTLE_FRAMES: int = 30
const T: float = 64.0

var _out: String
var _level: Node
var _isak: Node2D
var _state: Node
var _ok: bool = true
var _keep_alive: bool = false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	_state = root.get_node(^"GameState")
	_state.call(&"reset_progress")
	_state.call(&"mark_notice_seen", &"laser")
	_state.call(&"mark_notice_seen", &"debug")
	_state.call(&"meet_ally", &"eco")
	for id: StringName in [&"charger", &"exit_terminal", &"alert_bubble", &"notification_badge"]:
		_state.call(&"learn_help", id)
	await _reminders()
	await _overlay()
	await _update_bar()
	quit(0 if _ok else 1)


# --- Recordatorios y Posponer ---

func _reminders() -> void:
	await _load("res://scenes/levels/recordatorios_test.tscn")
	var a: Node = _level.get_node(^"Objects/suelto_a")
	var snooze: Node = _level.get_node(^"Objects/snooze_1")
	var help: Node = _level.get_node(^"Help")
	var box: Node = _level.get_node(^"EcoTextBox")
	await _place(2.0, 7)
	await _until(func() -> bool: return help.call(&"get_target") == a, 240, "Q del recordatorio")
	await _frames(40)
	await _save("01_q_recordatorio.png")
	await _ask_help(box)
	await _save("02_ayuda_recordatorio.png")
	await _close_box(box)
	await _frames(30)
	await _save("03_recordatorio_estable.png")
	await _place(4.5, 7)
	await _frames(36)
	await _save("04_recordatorio_contando.png")
	await _until(func() -> bool: return bool(a.call(&"is_warning")), 200, "aviso")
	await _frames(3)
	await _save("05_recordatorio_aviso.png")
	await _until(func() -> bool: return a.call(&"get_state") == 2, 200, "caida")
	await _frames(4)
	await _save("06_recordatorio_cayendo.png")
	await _until(func() -> bool: return a.call(&"get_state") == 3, 200, "caido")
	await _frames(20)
	await _save("07_recordatorio_caido.png")
	await _until(func() -> bool: return a.call(&"get_state") == 4, 400, "reposicion")
	await _frames(2)
	await _save("08_recordatorio_repuesto.png")
	# Posponer.
	_state.call(&"learn_help", &"reminder_platform")
	await _place(26.0, 7)
	await _until(func() -> bool: return help.call(&"get_target") == snooze, 240, "Q del Posponer")
	await _frames(40)
	await _save("09_q_posponer.png")
	await _ask_help(box)
	await _save("10_ayuda_posponer.png")
	await _close_box(box)
	_state.call(&"learn_help", &"snooze_button")
	_isak.set(&"facing", 1.0)
	await _act(&"laser", 0)
	await _until(func() -> bool: return bool(snooze.call(&"is_sparking")), 60, "chispa gris")
	await _frames(1)
	await _save("11_posponer_sin_cuenta.png")
	await _frames(30)
	await _place(16.5, 7)
	_isak.set(&"facing", 1.0)
	await _act(&"laser", 0)
	await _until(func() -> bool: return int(snooze.call(&"get_snooze_count")) > 0, 60, "pospuesto")
	await _frames(3)
	var camera: Camera2D = _isak.call(&"get_camera")
	camera.offset.x = 300.0
	await _frames(2)
	await _save("12_posponer_golpeado.png")
	await _frames(12)
	await _save("13_posponer_enfriandose.png")
	camera.offset.x = 0.0


# --- Pop-up translucido ---

func _overlay() -> void:
	await _load("res://scenes/levels/overlay_test.tscn")
	var overlay: Node = _level.get_node(^"Objects/overlay_1")
	var help: Node = _level.get_node(^"Help")
	var box: Node = _level.get_node(^"EcoTextBox")
	_state.set(&"debug_energy", 100.0)
	await _place(11.0, 10)
	await _until(func() -> bool: return help.call(&"get_target") == overlay, 240, "Q del pop-up")
	await _frames(40)
	await _save("21_q_overlay.png")
	await _ask_help(box)
	await _save("22_ayuda_overlay.png")
	await _close_box(box)
	_state.call(&"learn_help", &"overlay_popup")
	await _place(8.0, 10)
	await _frames(20)
	await _save("20_overlay_sin_debug.png")
	var debug: Node = root.get_node(^"DebugMode")
	Input.action_press(&"debug")
	await _until(func() -> bool: return float(debug.call(&"get_intensity")) >= 1.0, 240, "Debug activo")
	Input.action_release(&"debug")
	await _frames(10)
	await _save("23_overlay_con_debug.png")
	debug.call(&"reset")
	await _place(11.0, 10)
	await _act(&"pulse", 0)
	await _until(func() -> bool: return overlay.call(&"get_state") == 1, 60, "cerrandose")
	await _frames(6)
	await _save("24_overlay_cerrandose.png")
	await _until(func() -> bool: return bool(overlay.call(&"is_closed")), 60, "cerrado")
	await _frames(10)
	await _save("25_overlay_cerrado.png")


# --- Barra del 99 % ---

func _update_bar() -> void:
	await _load("res://scenes/levels/actualizaciones_test.tscn")
	var bar: Node = _level.get_node(^"Objects/barra_99")
	var help: Node = _level.get_node(^"Help")
	var box: Node = _level.get_node(^"EcoTextBox")
	_keep_alive = true
	bar.set_physics_process(false)
	await _place(22.0, 10)
	await _frames(10)
	await _save("30_barra_97.png")
	await _until(func() -> bool: return help.call(&"get_target") == bar, 240, "Q de la barra")
	await _frames(40)
	await _save("31_q_barra.png")
	await _ask_help(box)
	await _save("32_ayuda_barra.png")
	await _close_box(box)
	_state.call(&"learn_help", &"update_bar")
	bar.set_physics_process(true)
	await _until(func() -> bool: return bool(bar.call(&"is_waiting")), 120, "trabada")
	await _frames(20)
	await _save("33_barra_trabada.png")
	await _place(13.0, 10)
	await _until(func() -> bool: return int(bar.call(&"get_warning_count")) > 0, 400, "aviso de oleada")
	await _frames(4)
	await _save("34_oleada_aviso.png")
	await _until(func() -> bool: return int(bar.call(&"get_falling_count")) > 0, 120, "paquetes")
	await _frames(6)
	await _save("35_paquetes_cayendo.png")
	await _frames(50)
	await _save("36_oleada_enemigos.png")
	await _until(func() -> bool: return float(bar.call(&"get_wait_elapsed")) > 11.0, 900, "calculando")
	await _place(20.0, 10)
	await _frames(20)
	await _save("37_barra_calculando.png")
	await _until(func() -> bool: return int(bar.call(&"get_state")) == 3, 900, "100 %")
	await _frames(4)
	await _save("38_barra_completada.png")
	await _until(func() -> bool: return bool(bar.call(&"is_open")), 120, "abierta")
	await _frames(10)
	await _save("39_barra_abierta.png")
	_keep_alive = false


# --- Utilidades ---

func _load(path: String) -> void:
	if is_instance_valid(_level):
		_level.queue_free()
		await process_frame
	_level = (load(path) as PackedScene).instantiate()
	root.add_child(_level)
	_isak = _level.get_node(^"Isak")
	var companion_script: GDScript = load("res://scripts/levels/eco_companion.gd") as GDScript
	companion_script.call(&"attach", _isak, _level)
	await _frames(10)


func _place(col: float, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	_isak.set(&"velocity", Vector2.ZERO)
	if _isak.has_method(&"snap_camera"):
		_isak.call(&"snap_camera")
	await _frames(SETTLE_FRAMES)


func _frames(count: int) -> void:
	for i: int in count:
		if _keep_alive:
			_state.set(&"sync_rate", 100.0)
		await physics_frame


func _until(condition: Callable, max_frames: int, what: String) -> void:
	for i: int in max_frames:
		if condition.call():
			return
		await _frames(1)
	_ok = false
	push_error("render_tower_rooms: no se llego a '%s'" % what)


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
		push_error("render_tower_rooms: la ayuda no se abrio")
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
	print("render_tower_rooms: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
