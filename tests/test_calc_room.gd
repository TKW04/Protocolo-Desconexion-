# Sala de prueba del encuentro con Calc (data/levels/calc_test.json, escena
# generada scenes/levels/calc_test.tscn; tanda H1 del paso 14 de
# docs/propuesta-1-2.md, 2026-10-17; diseno en docs/propuesta-calc-encuentro.md)
# de principio a fin con el Isak real y la entrada falsa: Eco se acerca a la
# terminal apagada y a la pared con glitch (guion propio, lineas no
# importantes), el Debug abre la pared, el cuarto a oscuras, la Q del
# interruptor, tres pulsos de espaldas (luz por tercios y la pared se vuelve
# puerta), el laser al interruptor lejano, el panel oculto con el Debug, Calc
# entra, se carga y se teletransporta (sin darla por conocida) y la terminal ya
# tiene corriente. Ademas: con Calc conocida todo arranca resuelto y el guion no
# sale; con las ayudas ocultas el guion senala con una linea; la muerte y la
# pausa no rompen el guion.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/calc_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _eco: EcoCompanion
var _saved_pause: bool
var _settings_path: String
var _lines: Array[String] = []
var _teleported: Array[StringName] = []


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	_settings_path = GameSettings.settings_path()
	GameSettings.use_path(_settings_path, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.meet_ally(GameState.ALLY_ECO)
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
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameSettings.use_path(_settings_path, true)


func _on_line(text: String, _d: float, important: bool) -> void:
	_lines.append(("!" if important else "") + text)


func _on_teleported(ally: StringName) -> void:
	_teleported.append(ally)


func _load() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
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
	return _level.get_node_or_null(NodePath("Objects/" + id))


func _guide() -> EcoGuide:
	return _obj("guia_calc") as EcoGuide


func _stand(col: int, row: int, facing: float = 1.0) -> void:
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
		for id: String in ["interruptor_luz", "interruptor_laser", "panel_oculto", "dock_calc", "calc", "cuarto",
				"pared_glitch", "terminal_azotea"]:
			var node: Node = _obj(id)
			if node != null and node.has_method(&"advance"):
				node.call(&"advance", DT)
		_guide().advance(DT)
		_eco.advance(DT)
		(_level.get_node(^"EcoTextBox") as EcoTextBox).advance(DT)
		t += DT


## Avanza como _run hasta que `cond` sea cierta (como mucho `max_s`).
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
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	for i: int in roundi(DebugModeConfig.shared().activation_hold_s / DT) + 1:
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


func _has_line(fragment: String) -> bool:
	for line: String in _lines:
		if line.contains(fragment):
			return true
	return false


# --- Estado inicial ---

func test_scene_is_up_to_date_and_starts_unsolved() -> void:
	await _load()
	assert_eq(_level.level_id, "calc_test")
	var terminal := _obj("terminal_azotea") as ExitTerminal
	var wall := _obj("pared_glitch") as GlitchWall
	var room := _obj("cuarto") as DarkRoom
	var calc := _obj("calc") as CalcActor
	var dock := _obj("dock_calc") as ChargeDock
	var panel := _obj("panel_oculto") as PowerSwitch
	assert_true(terminal.requires_power)
	assert_false(terminal.is_powered(), "Terminal apagada")
	assert_false(terminal.is_help_available(), "Sin corriente no da Q (no mentiria)")
	assert_true(wall.is_solid(), "Pared con glitch solida")
	assert_false(wall.is_door())
	assert_almost_eq(room.get_veil_alpha(), 0.9, 0.001, "Cuarto a oscuras")
	assert_eq(calc.get_state(), CalcActor.State.OFF)
	assert_eq(calc.get_animation(), &"calc_low")
	assert_eq(calc.get_battery(), 3.0)
	assert_eq(dock.get_state(), ChargeDock.State.IDLE)
	assert_false(panel.visible, "Panel oculto sin Debug")
	assert_false(HelpCatalog.is_help_live(panel), "Oculto no ayuda")
	assert_false(_guide().is_inert())
	await _stand(10, 9)
	_pulse()
	assert_eq(terminal.get_state(), ExitTerminal.State.OFF, "El pulso no la enciende sin corriente")
	assert_false(terminal.is_key_hint_visible())


# --- Secuencia completa ---

func test_full_sequence() -> void:
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
	# 1. Eco se acerca a la terminal y a la pared (lineas no importantes, sin decir «Debug»).
	await _stand(9, 9)
	_run(0.2)
	assert_true(_eco.is_guiding(), "Eco vuela a la terminal")
	assert_lt(_eco.get_guide_point().distance_to(terminal.get_hit_rect().get_center()), 96.0)
	assert_true(_has_line("no tiene corriente"))
	_run(7.0)
	assert_lt(_eco.get_guide_point().distance_to(wall.get_world_rect().get_center()), 64.0, "Eco va a la pared")
	assert_true(_has_line("La corriente que alimenta la terminal viene de detrás de esta pared."))
	for line: String in _lines:
		assert_false(line.begins_with("!"), "Lineas del guion no importantes: %s" % line)
		assert_false(line.contains("Debug"), "Eco no dice que use el Debug")
	_run(8.0)
	assert_false(_eco.is_guiding(), "Vuelve con Isak")
	# 2. Debug: la pared se disuelve; dentro, a oscuras, la Q del interruptor.
	await _stand(12, 9)
	_activate_debug()
	await wait_until(func() -> bool: return wall.is_open(), 3.0)
	assert_true(wall.is_open(), "El Debug abre la pared")
	DebugMode.reset()
	await _stand(15, 9)
	_run(0.2)
	assert_true(_has_line("Qué oscuro"))
	_run_eco(0.3)
	help.refresh()
	assert_eq(help.get_target(), light, "Q del interruptor")
	assert_eq(_eco.get_help_target(), light, "Eco junto al interruptor (ayuda Q)")
	assert_true(help.request_help(), "Pedir la ayuda")
	assert_true(GameState.is_help_learned(&"power_switch"))
	_run(0.1)
	# 3 pulsos de espaldas: luz por tercios.
	await _stand(16, 9)
	for i: int in 3:
		_pulse()
		assert_eq(light.get_count(), i + 1, "Pulso %d" % (i + 1))
		assert_true(_isak.is_facing_back(), "De espaldas al interruptor")
		assert_eq(light.get_lit_lamps(), i + 1)
		_run(0.6)
		assert_false(_isak.is_facing_back(), "Vuelve de perfil")
		assert_almost_eq(room.get_target_light(), (i + 1) / 3.0, 0.001, "Luz por tercios")
		_sim.step(10)
	assert_true(light.is_activated())
	assert_false(HelpCatalog.is_help_live(light), "Activado no ayuda")
	_run(0.5)
	assert_true(room.is_lit())
	assert_true(wall.is_door(), "La pared es una puerta")
	assert_false(wall.is_solid())
	assert_eq(wall.get_lit_lamps(), 1)
	assert_true(_has_line("falta energía"))
	_run_until(func() -> bool: return _guide().get_current_action() == "wait_done", 30.0)
	# 3. Laser desde la primera plataforma (desde el suelo no se alcanza).
	await _stand(29, 9)
	_fire()
	assert_false(laser.is_activated(), "Desde el suelo no llega")
	await _stand(24, 7)
	_fire()
	assert_true(laser.is_activated(), "El laser lo activa para siempre")
	_run(0.2)
	assert_eq(wall.get_lit_lamps(), 2)
	assert_true(_has_line("Solo falta uno."))
	assert_lt(_eco.get_guide_point().distance_to(wall.get_world_rect().get_center()), 64.0, "Eco en la puerta")
	_run(5.0)
	# 4. Panel oculto arriba: sin Debug no responde; con el Debug aparece.
	await _stand(28, 3)
	_pulse()
	assert_false(panel.is_activated(), "Oculto: el pulso no hace nada")
	_activate_debug()
	_run(0.3)
	assert_true(panel.is_revealed(), "El Debug lo descubre")
	DebugMode.reset()
	_run(0.1)
	assert_true(panel.visible, "Queda marcado")
	_pulse()
	assert_true(panel.is_activated(), "Pulso de espaldas")
	assert_true(_isak.is_facing_back())
	_run(0.6)
	assert_eq(wall.get_lit_lamps(), 3)
	# 5. Calc entra por la puerta, se carga y se teletransporta.
	_run(0.1)
	assert_true(dock.is_armed())
	assert_ne(calc.get_state(), CalcActor.State.OFF, "Calc se despierta")
	var through_door: bool = false
	for i: int in 1200:
		_run(DT)
		if absf(calc.get_feet().x - wall.get_world_rect().get_center().x) < 8.0:
			through_door = true
		if calc.get_state() == CalcActor.State.CHARGING:
			break
	assert_true(through_door, "Entra por la puerta")
	assert_eq(calc.get_state(), CalcActor.State.CHARGING)
	assert_true(calc.get_feet().is_equal_approx(dock.get_calc_feet()), "Colocada en el punto de carga")
	_run(1.5)
	assert_true(dock.are_sparks_visible(), "Chispas")
	assert_gt(calc.get_battery(), 3.0)
	assert_lt(calc.get_battery(), 100.0)
	assert_gt(dock.get_lit_segments(), 2)
	_run(1.6)
	assert_eq(calc.get_battery(), 100.0)
	assert_eq(dock.get_lit_segments(), 10)
	assert_true(calc.get_state() == CalcActor.State.CHARGED or calc.get_state() == CalcActor.State.TELEPORT)
	assert_false(terminal.is_powered(), "Hasta que se va, sin corriente")
	_run(1.0)
	assert_eq(calc.get_state(), CalcActor.State.TELEPORT)
	assert_true(calc.is_vortex_visible(), "Vortice")
	assert_eq(calc.get_animation(), &"calc_teleport")
	_run(4.0)
	assert_eq(calc.get_state(), CalcActor.State.GONE)
	assert_false(calc.visible)
	assert_eq(_teleported, [&"calc"] as Array[StringName], "Gancho del hub (H3)")
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC), "Calc se conoce en el hub, no aqui")
	assert_true(dock.is_power_on())
	# 6. La terminal tiene corriente: Eco lo dice y el pulso la activa.
	assert_true(terminal.is_powered())
	_run_until(func() -> bool: return _has_line("La terminal ya tiene corriente"), 30.0)
	assert_true(_has_line("La terminal ya tiene corriente"))
	_run_until(func() -> bool: return _guide().is_finished(), 30.0)
	assert_true(_guide().is_finished(), "El guion termina")
	await _stand(9, 9)
	terminal.advance(DT)
	await wait_physics_frames(2)
	terminal.advance(DT)
	assert_true(terminal.is_key_hint_visible(), "Prompt con corriente")
	_pulse()
	assert_ne(terminal.get_state(), ExitTerminal.State.OFF, "Se enciende con el pulso")



# --- Calc ya conocida: pasa de largo ---

func test_calc_known_starts_solved_and_guide_is_inert() -> void:
	GameState.meet_ally(GameState.ALLY_CALC)
	await _load()
	var wall := _obj("pared_glitch") as GlitchWall
	assert_true((_obj("terminal_azotea") as ExitTerminal).is_powered(), "Terminal con corriente")
	assert_true(wall.is_door(), "Ya es puerta")
	_run(0.1)
	assert_eq(wall.get_lit_lamps(), 3)
	assert_eq(wall.get_door_animation(), &"power_door_open")
	assert_true((_obj("cuarto") as DarkRoom).is_lit())
	assert_eq((_obj("calc") as CalcActor).get_state(), CalcActor.State.GONE)
	assert_false((_obj("calc") as CalcActor).visible, "Calc esta en el hub")
	assert_true((_obj("dock_calc") as ChargeDock).is_power_on())
	for id: String in ["interruptor_luz", "interruptor_laser", "panel_oculto", "dock_calc", "pared_glitch"]:
		assert_false(HelpCatalog.is_help_live(_obj(id)), "%s inerte, sin Q" % id)
	assert_true(_guide().is_inert())
	await _stand(9, 9)
	_run(3.0)
	assert_eq(_lines.size(), 0, "Sin guia")
	assert_false(_eco.is_guiding())


# --- Ayudas ocultas: el guion es historia ---

func test_hidden_help_guide_points_with_a_line() -> void:
	GameSettings.set_eco_help_shown(false)
	await _load()
	var light := _obj("interruptor_luz") as PowerSwitch
	var guide: EcoGuide = _guide()
	await _stand(9, 9)
	_run(14.0)
	assert_true(_has_line("detrás de esta pared"), "La historia sale con las ayudas ocultas")
	(_obj("pared_glitch") as GlitchWall).open_with_debug()
	(_obj("pared_glitch") as GlitchWall).advance(2.0)
	await _stand(16, 9)
	_run(0.3)
	assert_true(_has_line("Ese interruptor quiere pulsos"), "Sin Q: Eco lo senala con una linea")
	assert_true(_eco.is_guiding())
	assert_lt(_eco.get_guide_point().distance_to(light.get_hit_rect().get_center()), 96.0)
	assert_eq(guide.get_current_action(), "wait_done")
	assert_false(GameState.is_help_learned(&"power_switch"), "No se aprende nada")


func test_learned_help_also_falls_back_to_a_line() -> void:
	GameState.learn_help(&"power_switch")
	await _load()
	_guide()._index = 10  # point_help del interruptor
	await _stand(16, 9)
	_run(0.2)
	assert_true(_has_line("Ese interruptor quiere pulsos"))


# --- Muerte y pausa ---

func test_death_waits_and_keeps_progress() -> void:
	await _load()
	var light := _obj("interruptor_luz") as PowerSwitch
	await _stand(9, 9)
	_run(0.2)
	assert_true(_eco.is_guiding())
	var step: int = _guide().get_step_index()
	_isak.die()
	_run_eco(0.1)
	assert_false(_eco.is_guiding(), "Isak muerto: Eco suelta el punto")
	_run(4.0)
	assert_lte(_guide().get_step_index(), step + 2, "Las acciones esperan a que Isak tenga el control")
	_isak.respawn(Vector2(2.5 * TILE, 10 * TILE))
	light.receive_pulse(null)
	assert_eq(light.get_count(), 0)
	_run(12.0)
	assert_true(_has_line("detrás de esta pared"), "Sigue tras reaparecer")


func test_pause_stops_the_guide() -> void:
	await _load()
	await _stand(9, 9)
	# El guion corre en _process (cuadros reales): en los cuadros de _stand ya puede
	# haber pasado la espera junto a la terminal y quedarse en la linea siguiente
	# (2026-10-23, paso 21 de docs/propuesta-mundo-2.md: la prueba exigia el paso 0 y
	# dependia del ritmo de los cuadros). Lo que se prueba es que en pausa no avanza.
	var before: int = _guide().get_step_index()
	get_tree().paused = true
	_guide().advance(5.0)
	assert_eq(_guide().get_step_index(), before, "Con el arbol en pausa no avanza")
	get_tree().paused = false
	_run(16.0)  # mas que la espera maxima de wait_quiet (15 s)
	assert_gt(_guide().get_step_index(), before, "Sin pausa sigue")
