## Capturas a 1:1 (1280x720) de la sala de prueba del encuentro con Calc
## (scenes/levels/calc_test.tscn; tanda H1 del paso 14 de docs/propuesta-1-2.md,
## 2026-10-17; docs/propuesta-calc-encuentro.md), con el Isak real (acciones del
## Input Map) y Eco companero:
##   01_eco_terminal.png      Eco junto a la terminal apagada y su linea
##   02_eco_glitch.png        Eco en la pared con glitch («la corriente... detras»)
##   03_debug_pared.png       el Debug disuelve la pared
##   04_cuarto_oscuro.png     dentro, a oscuras (halo de Eco y del interruptor)
##   05_q_interruptor.png     Eco con la Q dorada junto al interruptor
##   06_ayuda_interruptor.png la ayuda abierta (pausa)
##   07_luz_1.png / 08_luz_2.png  un pulso y dos, de espaldas (luz por tercios)
##   09_puerta.png            tercer pulso: luz completa y la pared se vuelve puerta
##   10_laser_interruptor.png laser desde la primera plataforma al interruptor lejano
##   11_eco_puerta.png        Eco en la puerta: «Solo falta uno»
##   12_panel_debug.png       arriba, el Debug descubre el panel oculto
##   13_panel_pulso.png       pulso de espaldas al panel
##   14_calc_entra.png        Calc cruza la puerta
##   15_calc_carga.png        Calc cargando (medidor por segmentos y chispas)
##   16_calc_teleporte.png    vortice: Calc se va al hub
##   17_terminal_corriente.png la terminal ya tiene corriente (prompt)
##   18_icono_en_linea.png    linea con {puntos} y el icono del punto de atencion
## Necesita ventana (no funciona con --headless). Usa el guardado de herramientas.
## Uso: Godot --path . -s tools/render_calc_test.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/levels/calc_test.tscn"
const DEFAULT_OUT: String = "user://calc_test"
const SETTLE_FRAMES: int = 30
const T: float = 64.0

var _out: String
var _level: Node
var _isak: Node2D
var _box: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	var game_state: Node = root.get_node(^"GameState")
	game_state.call(&"reset_progress")
	game_state.call(&"meet_ally", &"eco")
	for ability: StringName in [&"laser", &"debug", &"pulse"]:
		game_state.call(&"mark_notice_seen", ability)
	_level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_level)
	_isak = _level.get_node(^"Isak")
	var eco_script: GDScript = load("res://scripts/levels/eco_companion.gd")
	eco_script.call(&"attach", _isak, _level)
	_box = _level.get_node(^"EcoTextBox")
	var terminal: Node = _obj("terminal_azotea")
	var wall: Node = _obj("pared_glitch")
	var calc: Node = _obj("calc")
	await _place(9.0, 9)
	await _frames(70)
	await _save("01_eco_terminal.png")
	await _frames(110)
	await _save("02_eco_glitch.png")
	await _frames(200)
	await _place(12.0, 9)
	await _debug_on()
	await _frames(14)
	await _save("03_debug_pared.png")
	for i: int in 300:
		if bool(wall.call(&"is_open")):
			break
		await physics_frame
	await _debug_off()
	await _place(15.0, 9)
	await _frames(40)
	await _save("04_cuarto_oscuro.png")
	await _place(16.6, 9, -1.0)
	await _frames(40)
	await _save("05_q_interruptor.png")
	var press := InputEventAction.new()
	press.action = &"help"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"help"
	Input.parse_input_event(release)
	await _frames(70, true)
	_box.call(&"finish_typing")
	await _save("06_ayuda_interruptor.png")
	_box.call(&"confirm")
	await _frames(20, true)
	await _place(16.0, 9)
	await _act(&"pulse", 8)
	await _frames(30)
	await _save("07_luz_1.png")
	await _act(&"pulse", 8)
	await _frames(30)
	await _save("08_luz_2.png")
	await _act(&"pulse", 50)
	await _save("09_puerta.png")
	await _frames(160)
	await _place(24.0, 7)
	await _act(&"laser", 6)
	await _save("10_laser_interruptor.png")
	await _place(16.0, 9, -1.0)
	await _frames(20)
	await _save("11_eco_puerta.png")
	await _frames(120)
	await _place(28.0, 3, -1.0)
	await _debug_on()
	await _frames(30)
	await _save("12_panel_debug.png")
	await _debug_off()
	await _act(&"pulse", 6)
	await _save("13_panel_pulso.png")
	await _frames(30)
	await _place(11.0, 9)
	var wall_x: float = 13.5 * T
	for i: int in 1200:
		if absf(float((calc.call(&"get_feet") as Vector2).x) - wall_x) < 6.0:
			break
		await physics_frame
	await _save("14_calc_entra.png")
	await _place(16.0, 9, -1.0)
	for i: int in 1200:
		if int(calc.call(&"get_state")) == 3:  # CHARGING
			break
		await physics_frame
	await _frames(100)
	await _save("15_calc_carga.png")
	for i: int in 1200:
		if int(calc.call(&"get_state")) == 5:  # TELEPORT
			break
		await physics_frame
	await _frames(24)
	await _save("16_calc_teleporte.png")
	for i: int in 600:
		if bool(terminal.call(&"is_powered")):
			break
		await physics_frame
	await _place(9.6, 9, 1.0)
	await _frames(60)
	await _save("17_terminal_corriente.png")
	await _frames(240)
	game_state.set(&"attention_points", 37)
	_box.call(&"show_line", "Eco sabe sumar atención. Tienes {puntos} {icono:atencion} por gastar.")
	await _frames(150)
	await _save("18_icono_en_linea.png")
	quit(0)


func _obj(id: String) -> Node:
	return _level.get_node(NodePath("Objects/" + id))


func _place(col: float, row: int, facing: float = 1.0) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	_isak.set(&"velocity", Vector2.ZERO)
	_isak.set(&"facing", facing)
	if _isak.has_method(&"snap_camera"):
		_isak.call(&"snap_camera")
	for i: int in SETTLE_FRAMES:
		await physics_frame


func _frames(count: int, process: bool = false) -> void:
	for i: int in count:
		if process:
			await process_frame
		else:
			await physics_frame


func _debug_on() -> void:
	root.get_node(^"GameState").set(&"debug_energy", 100.0)
	Input.action_press(&"debug")
	for i: int in 75:
		await physics_frame
	Input.action_release(&"debug")
	await physics_frame


func _debug_off() -> void:
	Input.action_press(&"debug")
	await physics_frame
	await physics_frame
	Input.action_release(&"debug")
	await physics_frame


## Pulsa `action` un cuadro y espera `frames` cuadros de fisica.
func _act(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)
	for i: int in frames:
		await physics_frame


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_calc_test: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
