## Logica de tools/render_level_1_3.gd (capturas del nivel 1-3 «No molestar»; paso 12 de
## docs/propuesta-1-3.md §7, 2026-10-22). Lista de capturas en el lanzador.
extends Node

signal finished(code: int)

const MAIN_SCENE: String = "res://scenes/main.tscn"
const DEFAULT_OUT: String = "user://render_level_1_3"
const T: float = 64.0
const DT: float = 1.0 / 60.0
const SETTLE_FRAMES: int = 40

var _out: String
var _main: LevelRunner
var _level: Node
var _isak: Isak
var _ok: bool = true
var _started: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	GameState.use_save_path("user://tool_save.json", true)
	GameSettings.use_path("user://tool_settings.cfg", true)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	# Progreso de quien acaba de completar el 1-2 (sin el dash).
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, &"calc"]:
		GameState.meet_ally(ally)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG]:
		GameState.obtain_ability(ability)
		GameState.mark_notice_seen(ability)
	for id: StringName in [&"1-1", &"1-2"]:
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"1-3")
	# Capturas del nivel, no de la ayuda: todo aprendido y las ayudas ocultas (sin Q de relectura).
	for id: StringName in HelpCatalog.shared().ids():
		GameState.learn_help(id)
	GameSettings.set_eco_help_shown(false)
	EventBus.eco_line_started.connect(func(text: String) -> void: _started.append(text))
	_main = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	_main.start_level_id = "1-3"
	get_tree().root.add_child(_main)
	_isak = _main.get_isak()
	await _wait(func() -> bool: return not get_tree().paused and not _isak.is_warping() \
			and _main.get_phase() == 0, 30.0, "llegada")
	await _frames(30)
	_level = _main.get_level()
	await _ajustes()
	await _tramo_1()
	await _tramo_2()
	await _excepciones()
	await _tramo_3()
	await _tunel()
	await _place(237.6, 5, 1.0)
	await _save("17_secreto_c.png")
	await _place(252.0, 9)
	await _save("18_pantalla_bloqueo.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tool_save.json"))
	finished.emit(0 if _ok else 1)


func _ajustes() -> void:
	var sw: DndSwitch = _level.get_node(^"Objects/dnd_1_3") as DndSwitch
	await _place(10.0, 9)
	await _save("01_ajustes.png")
	await _place(14.0, 9)
	Input.action_press(&"pulse")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(&"pulse")
	var story: String = sw.get_story_text()
	await _wait(func() -> bool: return _box_text().length() > 12 and story.begins_with(_box_text().substr(0, 12)),
		10.0, "linea del interruptor")
	await _real(2.5)
	await _save("02_no_molestar_linea.png")
	var notice: String = AbilityNotices.notice_text(&"dash", AbilityNotices.load_data())
	await _wait(func() -> bool:
		_confirm_other_lines(notice)
		return _started.has(notice), 10.0, "aviso de Deslizar")
	await _real(1.2)
	await _save("03_aviso_deslizar.png")
	await _wait(func() -> bool:
		_confirm_other_lines("")
		return not get_tree().paused and not _isak.is_facing_back(), 5.0, "cerrar el aviso")
	_check(GameState.is_ability_obtained(GameState.ABILITY_DASH), "el interruptor no dio el dash")
	await _real(1.2)
	await _place(17.0, 9)
	_check(sw.is_room_tinted(), "sin tinte tras encender el interruptor")
	await _save("04_ajustes_tinte.png")


func _tramo_1() -> void:
	var banner: SpamBanner = _level.get_node(^"Enemies/banner_dash") as SpamBanner
	# En la celda de entrada (26), fuera del pasillo: el barrido no la alcanza.
	await _place(26.0, 9, 1.0)
	# A mitad del aviso, en un cuadro con la linea del suelo encendida (parpadea cada 0,125 s).
	await _wait(func() -> bool: return banner.is_warning() and float(banner.get(&"_warn_time")) > 0.3 \
			and fmod(float(banner.get(&"_warn_time")), 0.25) < 0.1, 8.0, "aviso del banner")
	await _save("05_banner_aviso.png")
	# Dash cuando el barrido esta a menos de 3 tiles por delante.
	await _wait(func() -> bool: return banner.is_sweeping() \
			and banner.get_banner_center_x() - _isak.global_position.x < 3.0 * T, 6.0, "barrido cerca")
	Input.action_press(&"move_right")
	Input.action_press(&"gesture_swipe")
	await _frames(2)
	Input.action_release(&"gesture_swipe")
	await _wait(func() -> bool: return _isak.is_dashing(), 1.0, "dash 1a")
	await _frames(5)
	await _save("06_banner_dash.png")
	await _wait(func() -> bool: return not _isak.is_dashing(), 1.0, "fin del dash 1a")
	Input.action_release(&"move_right")
	await _frames(10)
	await _save("07_banner_despues.png")


func _tramo_2() -> void:
	var zone: RhythmZone = _level.get_node(^"Objects/ritmo_2") as RhythmZone
	await _place(80.0, 9, 1.0)
	await _wait(func() -> bool: return zone.is_started(), 3.0, "metronomo")
	# Una del grupo encendida con sus segmentos (sin aviso) y la otra apagada.
	var a: BlinkPlatform = _level.get_node(^"Objects/blink_2a_a") as BlinkPlatform
	var a2: BlinkPlatform = _level.get_node(^"Objects/blink_2a_b") as BlinkPlatform
	await _wait(func() -> bool: return (a.is_solid() and not a.is_warning() and not a2.is_solid()) \
			or (a2.is_solid() and not a2.is_warning() and not a.is_solid()), 8.0, "grupos alternos")
	await _save("08_ritmo_lento.png")
	# Al compas rapido (paso 3 de 3: ciclos 8-11) sin esperar 23 s: se avanza el reloj de la zona.
	while zone.get_step_index() < 2:
		zone.advance(0.5)
	_check(absf(zone.get_cycle_s() - 2.0) < 0.01, "compas rapido")
	var b: BlinkPlatform = _level.get_node(^"Objects/blink_2b_b") as BlinkPlatform
	# Recien encendida (le queda casi todo el tiempo): Isak en la B y la A ya apagandose.
	await _wait(func() -> bool: return b.is_solid() and b.get_time_to_off() > b.get_warn_s() + 0.2, 6.0,
		"B encendida")
	_place_now(100.5, 5)
	await _frames(8)
	print("render_level_1_3: B solida=%s quedan %.2f s, Isak en el suelo=%s" % [b.is_solid(), b.get_time_to_off(),
		_isak.is_on_floor()])
	await _save("09_ritmo_rapido.png")


func _excepciones() -> void:
	var wall: GlitchWall = _level.get_node(^"Objects/pared_excepciones") as GlitchWall
	await _place(118.0, 4, 1.0)
	_check(not wall.is_glitch_shown(), "la pared se ve sin el Debug")
	# Sin el Debug la sala queda tapada por terreno falso (2026-10-22).
	_check(wall.is_cover_shown(), "el interior de «Excepciones» se ve desde fuera")
	await _save("10a_excepciones_tapada.png")
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	for i: int in roundi(DebugMode.get_activation_hold_s() / DT) + 2:
		DebugMode.step(DT, true)
		await get_tree().physics_frame
	DebugMode.step(DT, false)
	await _wait(func() -> bool: return wall.is_dissolving(), 5.0, "disolucion de la pared")
	await _real(0.25)
	await _save("10_excepciones_debug.png")
	await _wait(func() -> bool: return wall.is_open(), 5.0, "pared abierta")
	DebugMode.reset()
	DebugMode.input_enabled = true
	_check(not wall.is_cover_shown(), "el terreno falso sigue tras abrir la pared")
	await _place(123.0, 4, 1.0)
	await _save("11_sala_excepciones.png")


func _tramo_3() -> void:
	await _place(136.0, 9, 1.0)
	await _save("12_cortina_3a.png")
	var badge: NotificationBadge = _level.get_node(^"Enemies/badge_3b_a") as NotificationBadge
	await _place(150.0, 9, 1.0)
	Input.action_press(&"move_right")
	await _wait(func() -> bool: return badge.get_state() == &"anticipate", 8.0, "punto rojo inflandose")
	Input.action_release(&"move_right")
	await _wait(func() -> bool: return badge.get_state() == &"lunge", 3.0, "lanzamiento")
	_isak.set(&"facing", signf(badge.get_center().x - _isak.global_position.x))
	var dir: StringName = &"move_right" if badge.get_center().x > _isak.global_position.x else &"move_left"
	Input.action_press(dir)
	Input.action_press(&"gesture_swipe")
	await _frames(2)
	Input.action_release(&"gesture_swipe")
	await _frames(5)
	await _save("13_punto_rojo_dash.png")
	Input.action_release(dir)
	await _frames(30)


func _tunel() -> void:
	var tunnel: RhythmZone = _level.get_node(^"Objects/tunel_alarmas") as RhythmZone
	var shots: Array = [[198.0, &"bell_4a_2", "14_tunel_4a.png", 2.0], [213.0, &"bell_4b_2", "15_tunel_4b.png", 1.6],
		[228.0, &"bell_4c_2", "16_tunel_4c.png", 1.4]]
	for shot: Array in shots:
		await _place(float(shot[0]) - 1.5, 9, 1.0)
		var bell: Node = _level.get_node(NodePath("Enemies/" + String(shot[1])))
		await _wait(func() -> bool: return absf(tunnel.get_cycle_s() - float(shot[3])) < 0.01, 3.0,
			"compas %s" % shot[3])
		await _wait(func() -> bool: return bool(bell.call(&"is_wave")), 6.0, "onda %s" % shot[1])
		await _frames(5)
		await _save(String(shot[2]))


# --- Utilidades ---

func _place(col: float, row: int, facing: float = 0.0) -> void:
	_place_now(col + 0.5, row)
	if facing != 0.0:
		_isak.set(&"facing", facing)
	await _frames(SETTLE_FRAMES)


func _place_now(x_cells: float, row: int) -> void:
	_isak.global_position = Vector2(x_cells * T, (row + 1) * T)
	_isak.velocity = Vector2.ZERO
	_isak.snap_camera()


func _box() -> EcoTextBox:
	return _level.get_node_or_null(^"EcoTextBox") as EcoTextBox if is_instance_valid(_level) else null


func _box_text() -> String:
	var box: EcoTextBox = _box()
	return box.get_text() if box != null and box.is_showing() else ""


func _confirm_other_lines(text: String) -> void:
	var box: EcoTextBox = _box()
	while box != null and box.is_important() and box.get_text() != text and box.confirm():
		pass


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _wait(cond: Callable, max_s: float, what: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(max_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(cond.call()):
			return true
		await get_tree().process_frame
	_check(false, "no se llego a '%s'" % what)
	return false


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		push_error("render_level_1_3: %s" % what)


func _save(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_level_1_3: %s (%s) Isak=%s" % [path, error_string(err), _isak.global_position])
