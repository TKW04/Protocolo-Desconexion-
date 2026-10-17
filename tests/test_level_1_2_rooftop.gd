# Azotea del 1-2 REAL con el acertijo del encuentro con Calc (tanda H2 del paso
# 14 de docs/propuesta-1-2.md, 2026-10-17; diseno en
# docs/propuesta-calc-encuentro.md). La sala calc_test (tanda H1) ya prueba las
# piezas; aqui se prueban en la torre de 28 x 66:
#   - escena generada: la azotea (filas 0-10) con la terminal apagada, la pared
#     con glitch, el cuarto a oscuras, los tres interruptores, el punto de carga,
#     Calc al 3 %, el cargador y el guion de Eco;
#   - secuencia completa con el Isak real y la entrada falsa (pulso, laser y
#     Debug): Eco y la terminal sin corriente, el Debug abre la pared, tres
#     pulsos de espaldas (luz y puerta), el laser desde la repisa baja (desde el
#     suelo no llega), el panel oculto con el Debug, Calc entra, se carga y se
#     teletransporta en el tiempo que espera el validador, y la terminal con
#     corriente responde al pulso;
#   - con el flujo real (scenes/main.tscn, LevelRunner): camara de torre quieta
#     en la azotea, muerte y reaparicion en sync_2 a mitad del acertijo sin
#     perder lo hecho, un intento nuevo empieza de cero, la terminal con
#     corriente completa el nivel (Calc no queda conocida: es la tanda H3) y con
#     Calc conocida todo arranca resuelto y el guion no sale.
# Usa sus propias rutas de guardado y ajustes (nunca las reales).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-2.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const PATH: String = "user://test_level_1_2_rooftop.json"
const LEVEL_ID: String = "1-2"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const LONG_STEP_S: float = 5.0
## Espera de Calc que calcula tools/validate_level.py para esta azotea (despertar 0,3 + caminar 4,9 +
## carga 3,0 + cara despierta 0,8 + vortice 1,5 + 4 cuadros; tests/test_level_1_2.py la fija igual).
const VALIDATOR_CALC_WAIT_S: float = 10.585
const PIECES: Array[String] = ["interruptor_luz", "interruptor_laser", "panel_oculto", "dock_calc", "calc", "cuarto",
		"pared_glitch", "terminal_azotea"]

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _eco: EcoCompanion
var _main: LevelRunner
var _saved_pause: bool
var _saved_path: String
var _settings_path: String
var _lines: Array[String] = []
var _teleported: Array[StringName] = []


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	_settings_path = GameSettings.settings_path()
	GameSettings.use_path(_settings_path, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	# Se llega a la azotea con Eco, el pulso, el laser y el Debug (chip del piso 2).
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.obtain_debug()
	GameState.obtained_abilities[GameState.ABILITY_LASER] = true
	GameState.seen_notices[GameState.ABILITY_LASER] = true
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()
	_lines.clear()
	_teleported.clear()
	EventBus.eco_line_requested.connect(_on_line)
	EventBus.ally_teleported.connect(_on_teleported)


func after_each() -> void:
	EventBus.eco_line_requested.disconnect(_on_line)
	EventBus.ally_teleported.disconnect(_on_teleported)
	if is_instance_valid(_level):
		_level.free()
	_level = null
	if is_instance_valid(_main):
		_main.free()
	_main = null
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.last_checkpoint.clear()
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameSettings.use_path(_settings_path, true)


func _on_line(text: String, _d: float, important: bool) -> void:
	_lines.append(("!" if important else "") + text)


func _on_teleported(ally: StringName) -> void:
	_teleported.append(ally)


func _has_line(fragment: String) -> bool:
	for line: String in _lines:
		if line.contains(fragment):
			return true
	return false


# --- Escena suelta (secuencia con el Isak real) ---

func _load() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	# Los enemigos de los pisos no intervienen en la azotea.
	for child: Node in _level.get_node(^"Enemies").get_children():
		child.free()
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	_eco = EcoCompanion.attach(_isak, _level)
	_eco.auto_advance = false
	await wait_physics_frames(2)
	_run_eco(0.5)


func _obj(id: String) -> Node:
	var level: Node = _level if is_instance_valid(_level) else _main.get_level()
	return level.get_node_or_null(NodePath("Objects/" + id))


func _guide() -> EcoGuide:
	return _obj("guia_calc") as EcoGuide


func _stand(col: float, row: int, facing: float = 1.0) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	_isak.facing = facing
	await wait_physics_frames(1)
	_sim.settle()
	await wait_physics_frames(2)


func _run_eco(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_eco.advance(DT)
		t += DT


## Avanza el guion y las piezas `seconds` de juego (sin esperar cuadros reales).
func _run(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		for id: String in PIECES:
			var node: Node = _obj(id)
			if node != null and node.has_method(&"advance"):
				node.call(&"advance", DT)
		_guide().advance(DT)
		_eco.advance(DT)
		(_level.get_node(^"EcoTextBox") as EcoTextBox).advance(DT)
		t += DT


func _run_until(cond: Callable, max_s: float) -> void:
	var t: float = 0.0
	while t < max_s and not cond.call():
		_run(DT)
		t += DT


func _pulse() -> void:
	_sim.input.pulse_pressed = true
	_sim.step(40)


func _fire() -> void:
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_sim.step()
	for i: int in 40:
		if not fired.is_empty():
			break
		_sim.step()
	_isak.laser_fired.disconnect(on_fired)
	assert_false(fired.is_empty(), "Sale el laser")
	if fired.is_empty():
		return
	var p: LaserProjectile = fired[0]
	p.auto_process = false
	for i: int in 120:
		if p.is_finished():
			break
		p.step(DT)
	_sim.step(ceili(_isak.abilities.laser_cooldown_s / DT) + 30)


func _activate_debug() -> void:
	for i: int in roundi(DebugModeConfig.shared().activation_hold_s / DT) + 1:
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


func test_scene_has_the_rooftop_puzzle_unsolved() -> void:
	await _load()
	assert_eq(_level.get_size_px(), Vector2i(28 * 64, 66 * 64), "Torre de 28 x 66")
	var terminal := _obj("terminal_azotea") as ExitTerminal
	var wall := _obj("pared_glitch") as GlitchWall
	var room := _obj("cuarto") as DarkRoom
	var calc := _obj("calc") as CalcActor
	var dock := _obj("dock_calc") as ChargeDock
	var panel := _obj("panel_oculto") as PowerSwitch
	assert_true(terminal.requires_power)
	assert_false(terminal.is_powered(), "Terminal apagada")
	assert_lt(terminal.global_position.y, 11.0 * TILE, "En la azotea (filas 0-10)")
	assert_true(wall.is_solid(), "Pared con glitch solida")
	assert_almost_eq(room.get_veil_alpha(), 0.9, 0.001, "Cuarto a oscuras")
	assert_eq(room.get_room_rect(), Rect2(13 * TILE, 1 * TILE, 14 * TILE, 9 * TILE))
	assert_eq(calc.get_state(), CalcActor.State.OFF)
	assert_eq(calc.get_battery(), 3.0, "Calc al 3 %")
	assert_eq(dock.get_state(), ChargeDock.State.IDLE)
	assert_false(panel.visible, "Panel oculto sin Debug")
	assert_eq((_obj("interruptor_luz") as PowerSwitch).get_required(), 3)
	assert_true(_obj("cargador_3") is Charger, "Cargador de la azotea")
	assert_false(_guide().is_inert())
	await _stand(10, 9)
	_pulse()
	assert_eq(terminal.get_state(), ExitTerminal.State.OFF, "El pulso no la enciende sin corriente")


func test_full_sequence_with_pulse_laser_and_debug() -> void:
	await _load()
	var terminal := _obj("terminal_azotea") as ExitTerminal
	var wall := _obj("pared_glitch") as GlitchWall
	var room := _obj("cuarto") as DarkRoom
	var light := _obj("interruptor_luz") as PowerSwitch
	var laser := _obj("interruptor_laser") as LaserSwitch
	var panel := _obj("panel_oculto") as PowerSwitch
	var dock := _obj("dock_calc") as ChargeDock
	var calc := _obj("calc") as CalcActor
	var help := _level.get_node(^"Help") as HelpSystem
	help.set_process(false)
	# 1. Eco va a la terminal apagada y a la pared (lineas no importantes, sin decir «Debug»).
	await _stand(9, 9)
	_run(0.2)
	assert_true(_eco.is_guiding(), "Eco vuela a la terminal")
	assert_true(_has_line("no tiene corriente"))
	_run(7.0)
	assert_lt(_eco.get_guide_point().distance_to(wall.get_world_rect().get_center()), 64.0, "Eco va a la pared")
	assert_true(_has_line("viene de detrás de esta pared"))
	for line: String in _lines:
		assert_false(line.begins_with("!"), "Lineas del guion no importantes: %s" % line)
		assert_false(line.contains("Debug"), "Eco no dice que use el Debug")
	_run(8.0)
	# 2. El Debug disuelve la pared; dentro, a oscuras, la Q del interruptor.
	await _stand(11, 9)
	assert_true(wall.is_solid(), "Sin Debug la pared no se cruza")
	_activate_debug()
	await wait_until(func() -> bool: return wall.is_open(), 3.0)
	assert_true(wall.is_open(), "El Debug abre la pared")
	DebugMode.reset()
	await _stand(13, 9)
	_run(0.2)
	assert_true(_has_line("Qué oscuro"))
	_run_eco(0.3)
	help.refresh()
	assert_eq(help.get_target(), light, "Q del interruptor")
	# 3 pulsos de espaldas: luz por tercios y la pared se vuelve puerta.
	await _stand(14, 9)
	for i: int in 3:
		_pulse()
		assert_eq(light.get_count(), i + 1, "Pulso %d" % (i + 1))
		assert_true(_isak.is_facing_back(), "De espaldas al interruptor")
		_run(0.6)
		assert_false(_isak.is_facing_back(), "Vuelve de perfil")
		assert_almost_eq(room.get_target_light(), (i + 1) / 3.0, 0.001, "Luz por tercios")
		_sim.step(10)
	assert_true(light.is_activated())
	_run(0.5)
	assert_true(room.is_lit())
	assert_true(wall.is_door(), "La pared es una puerta")
	assert_false(wall.is_solid())
	# 3. Laser: desde el suelo no llega; desde la repisa baja (fila 8) se activa para siempre.
	await _stand(25, 9)
	_fire()
	assert_false(laser.is_activated(), "Desde el suelo no llega")
	await _stand(20, 7)
	assert_true(_isak.is_on_floor(), "De pie en la repisa baja")
	_fire()
	assert_true(laser.is_activated(), "El laser lo activa")
	_run(0.2)
	assert_eq(wall.get_lit_lamps(), 2)
	# 4. Panel oculto sobre la repisa alta: sin Debug no responde; con el Debug aparece y queda marcado.
	await _stand(25, 3)
	assert_true(_isak.is_on_floor(), "De pie en la repisa alta")
	_pulse()
	assert_false(panel.is_activated(), "Oculto: el pulso no hace nada")
	_activate_debug()
	_run(0.3)
	assert_true(panel.is_revealed(), "El Debug lo descubre")
	DebugMode.reset()
	_run(0.1)
	_pulse()
	assert_true(panel.is_activated(), "Pulso de espaldas al panel")
	assert_true(_isak.is_facing_back())
	# 5. Calc entra por la puerta, se carga y se teletransporta en el tiempo que espera el validador.
	var t: float = 0.0
	var through_door: bool = false
	while t < 30.0 and not dock.is_power_on():
		_run(DT)
		t += DT
		if absf(calc.get_feet().x - wall.get_world_rect().get_center().x) < 8.0:
			through_door = true
	assert_true(through_door, "Calc cruza la puerta")
	assert_true(dock.is_power_on(), "El punto de carga tiene corriente")
	assert_almost_eq(t, VALIDATOR_CALC_WAIT_S, 0.3, "Espera de Calc como en el validador")
	assert_eq(_teleported, [&"calc"] as Array[StringName], "Gancho del hub (H3)")
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC), "Calc se conoce en el hub (H3), no aqui")
	# 6. La terminal tiene corriente y el pulso la enciende.
	assert_true(terminal.is_powered())
	await _stand(10, 9)
	_pulse()
	assert_ne(terminal.get_state(), ExitTerminal.State.OFF, "Se enciende con el pulso")


# --- Flujo real (LevelRunner) ---

func _start(level_id: String = LEVEL_ID) -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = level_id
	add_child(_main)


func _arrive() -> void:
	_main.advance(LONG_STEP_S)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	for i: int in 600:
		if vortex == null or not is_instance_valid(vortex) or vortex.is_done():
			break
		vortex.advance(DT)
	_isak = _main.get_isak()
	_isak.input = PlayerInput.new()
	await wait_physics_frames(30)


func _teleport(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	_isak.snap_camera()


func _die() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_isak.is_dead(), "Muere con Sync Rate 0")
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)


## Hace las piezas como el jugador (sin recorrer el camino) y deja correr a Calc.
func _solve_pieces() -> void:
	(_obj("pared_glitch") as GlitchWall).open_with_debug()
	(_obj("interruptor_luz") as PowerSwitch).activate()
	(_obj("interruptor_laser") as LaserSwitch).activate()
	(_obj("panel_oculto") as PowerSwitch).activate()
	var dock := _obj("dock_calc") as ChargeDock
	for i: int in 1800:
		if dock.is_power_on():
			break
		for id: String in ["dock_calc", "calc", "pared_glitch", "terminal_azotea"]:
			_obj(id).call(&"advance", DT)


func test_tower_camera_rests_on_the_rooftop() -> void:
	_start()
	await _arrive()
	_teleport(2, 9)
	await wait_physics_frames(60)
	assert_true(_isak.is_on_floor(), "De pie en la azotea al salir del hueco")
	assert_eq(_isak.camera_mode, Isak.CAMERA_TOWER)
	var camera: Camera2D = _isak.get_camera()
	var center: Vector2 = camera.get_screen_center_position()
	var view := Vector2(1280.0, 720.0)
	var top: float = center.y - view.y * 0.5
	assert_lte(top, 2.0, "La azotea (11 filas, 704 px) cabe entera: la camara llega al techo")
	assert_gte(center.y + view.y * 0.5, 11.0 * TILE - 2.0, "y al suelo de la azotea")
	_teleport(20, 7)
	await wait_physics_frames(60)
	assert_almost_eq(camera.get_screen_center_position().y, center.y, 2.0, "Dentro del piso la camara no se mueve")


func test_death_mid_puzzle_keeps_progress_and_a_new_attempt_resets() -> void:
	_start()
	await _arrive()
	var sync_2 := _main.get_level().get_node(^"Checkpoints/sync_2") as Checkpoint
	sync_2.activate()
	_teleport(14, 9)
	(_obj("pared_glitch") as GlitchWall).open_with_debug()
	(_obj("pared_glitch") as GlitchWall).advance(2.0)
	(_obj("interruptor_luz") as PowerSwitch).activate()
	(_obj("interruptor_laser") as LaserSwitch).activate()
	await wait_physics_frames(3)
	var lives: int = GameState.lives
	_die()
	assert_eq(GameState.lives, lives - 1, "Morir resta una vida")
	assert_true(_isak.global_position.is_equal_approx(sync_2.get_spawn_position()), "Reaparece en sync_2")
	assert_true((_obj("interruptor_luz") as PowerSwitch).is_activated(), "El interruptor sigue activado")
	assert_true((_obj("interruptor_laser") as LaserSwitch).is_activated(), "El laser sigue activado")
	assert_true((_obj("pared_glitch") as GlitchWall).is_door(), "La puerta sigue abierta")
	assert_false((_obj("terminal_azotea") as ExitTerminal).is_powered(), "Falta el panel")
	(_obj("panel_oculto") as PowerSwitch).activate()
	var dock := _obj("dock_calc") as ChargeDock
	dock.advance(DT)
	assert_true(dock.is_armed(), "Con lo de antes de morir y el panel se arma")
	# Un intento nuevo (R) empieza de cero mientras Calc no sea conocida.
	assert_true(_main.start_level(LEVEL_ID))
	_main.advance(LONG_STEP_S)
	await _arrive()
	assert_false((_obj("interruptor_luz") as PowerSwitch).is_activated(), "Intento nuevo: de cero")
	assert_false((_obj("pared_glitch") as GlitchWall).is_door())
	assert_false((_obj("terminal_azotea") as ExitTerminal).is_powered())


func test_powered_terminal_completes_the_level() -> void:
	_start()
	await _arrive()
	_teleport(10, 9)
	_solve_pieces()
	var terminal := _obj("terminal_azotea") as ExitTerminal
	assert_true(terminal.is_powered(), "Calc se fue: la terminal tiene corriente")
	assert_true(terminal.activate(_isak), "El pulso activa la terminal")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	assert_true(GameState.is_level_completed(&"1-2"), "1-2 completado")
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC), "Calc se conoce en el hub (H3)")


func test_calc_known_starts_solved_and_the_guide_does_not_run() -> void:
	EcoProgress.meet_calc()
	_start()
	await _arrive()
	var terminal := _obj("terminal_azotea") as ExitTerminal
	var wall := _obj("pared_glitch") as GlitchWall
	assert_true(terminal.is_powered(), "Terminal con corriente")
	assert_true(wall.is_door(), "La pared ya es una puerta")
	assert_true((_obj("cuarto") as DarkRoom).is_lit(), "Cuarto con luz")
	assert_eq((_obj("calc") as CalcActor).get_state(), CalcActor.State.GONE, "Calc esta en el hub")
	for id: String in ["interruptor_luz", "interruptor_laser", "panel_oculto", "dock_calc"]:
		assert_true(_obj(id).call(&"is_activated"), "%s hecho" % id)
		assert_false(HelpCatalog.is_help_live(_obj(id)), "%s sin Q" % id)
	assert_true((_obj("guia_calc") as EcoGuide).is_inert(), "El guion no corre")
	_teleport(9, 9)
	await wait_physics_frames(30)
	_main.advance(3.0)
	assert_false(_has_line("no tiene corriente"), "Eco no repite el guion")
	assert_true(terminal.activate(_isak), "Directo a la terminal")


func test_rooftop_economy() -> void:
	_start()
	await _arrive()
	var level: GeneratedLevel = _main.get_level()
	var chargers: Array[Charger] = []
	for child: Node in level.get_node(^"Objects").get_children():
		if child is Charger:
			chargers.append(child)
	assert_eq(chargers.size(), 3, "2 cargadores en los pisos y 1 en la azotea")
	var roof := _obj("cargador_3") as Charger
	assert_lt(roof.global_position.y, 11.0 * TILE, "cargador_3 en la azotea")
	var points: int = 0
	var roof_points: int = 0
	for point: Node in level.get_node(^"AttentionPoints").get_children():
		points += 1
		if (point as Node2D).global_position.y < 11.0 * TILE:
			roof_points += 1
	assert_eq(points, 9, "9 puntos de atencion")
	assert_eq(roof_points, 1, "1 en la azotea")
	GameState.debug_energy = 10.0
	_teleport(6, 9)
	await wait_physics_frames(6)
	assert_eq(GameState.debug_energy, 60.0, "El cargador de la azotea da 50")
