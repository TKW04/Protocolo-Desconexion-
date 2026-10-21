# Alerta Mayor y su arena «Pantalla de bloqueo» (pasos 5-8 de
# docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21). Paso 5: la arena 1-boss
# generada (sin meta, 4 cargadores de 4 s, Debug a un cuarto, objetos de la
# fase 3 inactivos hasta la fase 3 y plataformas que parpadean que reemplazan a
# las de una via), ajustes por acceso (cargadores, compas, parpadeo), intro al
# terminar la llegada con el flujo real (--start-level=1-boss), reaparicion por
# fase con los cargadores listos y golpe final (gancho final_blow). Los ataques
# de cada fase estan en las secciones siguientes, con el tiempo avanzado a mano
# (advance) y el Isak real.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-boss.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const IsakSim = preload("res://tests/support/isak_sim.gd")
const PATH: String = "user://test_alert_major.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _saved_path: String
var _saved_lap: int
var _saved_abilities: Dictionary = {}
var _main: LevelRunner
var _level: GeneratedLevel
var _boss: AlertMajor
var _lines: Array = []
var _sim: IsakSim
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_lap = GameState.lap
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		_saved_abilities[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.sync_rate = GameState.get_sync_rate_max()
	_lines.clear()
	EventBus.eco_line_requested.connect(_on_line)


func after_each() -> void:
	if EventBus.eco_line_requested.is_connected(_on_line):
		EventBus.eco_line_requested.disconnect(_on_line)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_level = null
	_boss = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.lap = _saved_lap
	GameState.save_path = _saved_path
	for ability: StringName in _saved_abilities:
		GameState.set_ability_unlocked(ability, _saved_abilities[ability])
	GameState.last_checkpoint.clear()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _on_line(text: String, _duration: float, important: bool) -> void:
	_lines.append([text, important])


# --- Utilidades ---

## La arena sin LevelRunner; el jefe sin intro ni proceso propio (advance a mano).
func _arena(lap: int = 1, auto: bool = false, sim: bool = false) -> GeneratedLevel:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/alerta_mayor") as AlertMajor
	_boss.intro_on_arrival = false
	_boss.auto_process = auto
	_boss.lap_override = lap
	_sim = null
	if sim:
		_sim = IsakSim.new(DT)
		_sim.attach(_level.get_isak())
	add_child_autofree(_level)
	if sim:
		_sim.take_manual_control()
	await wait_physics_frames(2)
	if sim:
		_sim.settle()
	return _level


func _obj(id: String) -> Node:
	return _level.get_node_or_null(NodePath("Objects/" + id))


func _enemy(id: String) -> Node:
	return _level.get_node_or_null(NodePath("Enemies/" + id))


func _tiles() -> TileMapLayer:
	return _level.get_node(^"Tiles") as TileMapLayer


## Avanza el jefe, la marca y sus banners (sin proceso propio) `seconds` del mundo;
## con `isak`, tambien el Isak manual.
func _advance(seconds: float, isak: bool = false) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)
		for banner: Variant in _boss.get_banners().values():
			if is_instance_valid(banner):
				(banner as SpamBanner).set_physics_process(false)
				(banner as SpamBanner).step(DT)
		if isak and _sim != null:
			_sim.step()


## Solo los banners y el Isak manual (el jefe quieto: sin barridos propios).
func _step_lanes(seconds: float) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		for banner: Variant in _boss.get_banners().values():
			(banner as SpamBanner).set_physics_process(false)
			(banner as SpamBanner).step(DT)
		_sim.step()


## Coloca a Isak de pie en la celda (col, fila).
func _place_isak(col: int, row: int) -> void:
	var isak: Isak = _level.get_isak()
	isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	isak.velocity = Vector2.ZERO
	if _sim != null:
		_sim.settle()


func _debug_on() -> void:
	if not DebugMode.is_active():
		for i: int in roundi(_config.activation_hold_s / DT):
			DebugMode.step(DT, true)
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


## PulseArea falsa: un circulo de 96 px en `pos`.
func _pulse_area(pos: Vector2) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	area.add_child(shape)
	area.position = pos
	add_child_autofree(area)
	return area


## Marca el nucleo (Debug + pulso encima) y apaga el Debug.
func _mark_core() -> void:
	_debug_on()
	assert_true(_boss.get_core().receive_pulse(_pulse_area(_boss.get_core().global_position)), "El pulso alcanza el nucleo")
	assert_true(_boss.get_core().is_marked(), "Marcado")
	DebugMode.reset()


## Lleva la fase 1 hasta que salen las Burbujas y caen a sus plataformas.
func _spit_and_land() -> void:
	_advance(DT)
	_advance(_boss.frames_s(9) + DT)
	assert_eq(_boss.get_bubbles().size(), 2, "Dos Burbujas")
	await wait_physics_frames(60)


func _to_phase(phase: int) -> void:
	while _boss.get_phase() < phase:
		_boss.take_core_hit(1)


# --- Paso 5: arena ---

func test_arena_is_generated_without_goal() -> void:
	await _arena()
	assert_eq(_level.level_id, "1-boss")
	assert_eq(_level.get_size_px(), Vector2i(24 * 64, 12 * 64), "24 x 12 tiles")
	assert_null(_level.get_node_or_null(^"Goal"), "Sin meta: la pelea acaba con el golpe final")
	assert_not_null(_boss, "Alerta Mayor en la arena")
	assert_eq(_boss.boss_id, &"alert_major")
	assert_eq(_level.get_isak().global_position, Vector2(2.5 * TILE, 10.0 * TILE), "Vortice de llegada en (2, 9)")
	assert_almost_eq(DebugMode.get_level_drain_scale(), 0.25, EPS, "Debug a un cuarto de gasto")
	var cols: Array = []
	for id: String in ["cargador_1", "cargador_2", "cargador_3", "cargador_4"]:
		var charger := _obj(id) as Charger
		assert_not_null(charger, id)
		assert_almost_eq(charger.cooldown_s, 4.0, EPS, "%s: 4 s en Caché" % id)
		cols.append(roundi(charger.global_position.x / TILE))
	assert_eq(cols, [1, 8, 15, 22], "Cargadores en el suelo: columnas 1, 8, 15 y 22")
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		assert_true(GameState.is_ability_unlocked(ability), "Habilidad %s en la arena" % ability)


func test_phase3_objects_start_inactive() -> void:
	await _arena()
	var nodes: Array[Node] = BossBase.phase_nodes(_level)
	assert_eq(nodes.size(), 8, "Metronomo, 4 plataformas que parpadean y 3 campanas")
	for node: Node in nodes:
		assert_false(BossBase.is_phase_node_active(node), "%s inactivo antes de la fase 3" % node.name)
		assert_false((node as CanvasItem).visible, "%s invisible" % node.name)
	assert_eq((_obj("parpadeo_a1") as BlinkPlatform).collision_layer, 0, "Sin colision")
	for c: int in [3, 4, 5, 6, 17, 18, 19, 20]:
		assert_ne(_tiles().get_cell_source_id(Vector2i(c, 8)), -1, "Plataforma de una via en (%d, 8)" % c)
	var bell := _enemy("campana_1") as AlarmBell
	await wait_physics_frames(10)
	assert_eq(bell.get_wave_count(), 0, "Las campanas no suenan antes de la fase 3")


func test_phase3_activation_replaces_the_side_platforms() -> void:
	await _arena()
	_boss.start()
	_to_phase(3)
	assert_eq(_boss.get_phase(), 3)
	for node: Node in BossBase.phase_nodes(_level):
		assert_true(BossBase.is_phase_node_active(node), "%s activo en la fase 3" % node.name)
	for c: int in [3, 4, 5, 6, 17, 18, 19, 20]:
		assert_eq(_tiles().get_cell_source_id(Vector2i(c, 8)), -1, "La celda (%d, 8) la ocupa una plataforma que parpadea" % c)
	for c: int in range(9, 15):
		assert_ne(_tiles().get_cell_source_id(Vector2i(c, 6)), -1, "La central sigue fija")
	var a := _obj("parpadeo_a1") as BlinkPlatform
	assert_eq(a.collision_layer, BlinkPlatform.LAYER_WORLD, "Solida otra vez")
	var rhythm := _obj("ritmo_jefe") as RhythmZone
	assert_true(rhythm.is_started(), "El metronomo arranca")
	assert_almost_eq(rhythm.get_cycle_s(), 2.0, EPS, "Compas de 2,0 s en Caché")
	BossBase.apply_phase_nodes(_level, 0)
	for c: int in [3, 4, 5, 6, 17, 18, 19, 20]:
		assert_ne(_tiles().get_cell_source_id(Vector2i(c, 8)), -1, "Desactivadas: vuelve la de una via")


func test_lap_settings_per_access() -> void:
	var expected: Dictionary = {1: [4.0, [2.0], 0.55], 2: [5.0, [2.0, 1.6], 0.65], 3: [6.0, [2.0, 1.6, 1.4], 0.72]}
	for lap: int in expected:
		await _arena(lap)
		await wait_process_frames(1)
		var e: Array = expected[lap]
		assert_almost_eq((_obj("cargador_2") as Charger).cooldown_s, float(e[0]), EPS, "Cargadores, vuelta %d" % lap)
		assert_eq((_obj("ritmo_jefe") as RhythmZone).tempo_steps_s, e[1], "Compas, vuelta %d" % lap)
		assert_almost_eq((_obj("parpadeo_b1") as BlinkPlatform).on_fraction, float(e[2]), EPS, "Parpadeo, vuelta %d" % lap)
		assert_eq(_boss.get_total_hits(), 9 if lap == 1 else 12)


func test_start_hovers_with_full_counter_and_hidden_core() -> void:
	await _arena()
	_boss.start()
	assert_eq(_boss.get_phase(), 1)
	assert_eq(_boss.get_counter_text(), "99+")
	assert_false(_boss.get_core().is_enabled(), "Arriba el nucleo no es objetivo")
	assert_eq(_boss.get_core_target(), Vector2.INF)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_HOVER)
	var y: float = _boss.get_body_center().y
	assert_almost_eq(y, 3.0 * TILE, 0.5, "Flota con el centro en la fila 3 (filas 1-4)")
	var xs: Array[float] = []
	for i: int in 30:
		_advance(0.5)
		xs.append(_boss.get_body_center().x)
	assert_gt(xs.max() - xs.min(), 4.0 * TILE, "Se desplaza por arriba")
	assert_true(xs.min() >= 4.0 * TILE - 0.5 and xs.max() <= 20.0 * TILE + 0.5, "Entre las columnas 4 y 20")


func test_respawn_restarts_the_phase_and_readies_the_chargers() -> void:
	await _arena()
	_boss.start()
	var charger := _obj("cargador_3") as Charger
	GameState.debug_energy = 10.0
	assert_gt(charger.try_use(_level.get_isak()), 0.0, "Usa el cargador")
	assert_false(charger.is_ready(), "Enfriandose")
	_boss.take_core_hit(1)
	assert_eq(_boss.get_counter_text(), "88")
	GameState.debug_energy = 20.0
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(_boss.get_counter_text(), "99+", "La fase 1 vuelve a empezar")
	assert_true(charger.is_ready(), "Los cargadores vuelven a estar listos")
	assert_almost_eq(GameState.debug_energy, 50.0, EPS, "Energia al menos 50")


func test_final_blow_stops_the_arena_and_emits_the_hook() -> void:
	await _arena()
	var lap: int = GameState.lap
	watch_signals(_boss)
	_boss.start()
	_to_phase(3)
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	assert_signal_emitted(_boss, "final_blow", "Gancho del paso 10")
	assert_eq(_boss.get_counter_label(), "0")
	assert_false(BossBase.is_phase_node_active(_obj("ritmo_jefe")), "El metronomo se para")
	assert_false(BossBase.is_phase_node_active(_enemy("campana_2")), "Las campanas callan")
	var a := _obj("parpadeo_a1") as BlinkPlatform
	assert_true(a.is_held_on() and a.is_solid(), "Las plataformas quedan encendidas")
	assert_eq(_boss.get_attacks_root().get_child_count(), 0, "Sin ataques")
	assert_eq(GameState.lap, lap, "Ni rollback ni cambio de vuelta")


func test_debug_shortcut_and_intro_after_arrival() -> void:
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=1-boss"])), "1-boss",
		"Atajo de depuracion -- --start-level=1-boss")
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-boss"
	add_child(_main)
	assert_eq(_main.get_level_id(), "1-boss")
	var boss := _main.get_level().get_node(^"Objects/alerta_mayor") as AlertMajor
	await wait_physics_frames(3)
	assert_false(boss.is_fighting(), "Espera a que Isak llegue")
	assert_true(_lines.is_empty())
	_main.advance(5.0)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	for i: int in 600:
		if vortex == null or not is_instance_valid(vortex) or vortex.is_done():
			break
		vortex.advance(DT)
	await wait_physics_frames(3)
	assert_eq(_lines.size(), 1, "Linea de intro al terminar la llegada")
	if _lines.size() == 1:
		assert_true(bool(_lines[0][1]), "Importante: pausa")
		assert_string_contains(String(_lines[0][0]), "PROPUESTA")
	assert_false(boss.is_fighting(), "La pelea empieza al cerrar la linea")
	EventBus.eco_line_finished.emit()
	assert_true(boss.is_fighting())
	assert_eq(boss.get_phase(), 1)


# --- Paso 6: fase 1 «99+» ---

func test_phase1_spits_two_bubbles_after_a_9_frame_warning() -> void:
	await _arena()
	watch_signals(_boss)
	_boss.start()
	_advance(DT)
	assert_signal_emitted_with_parameters(_boss, "attack_started", [&"spit"])
	assert_almost_eq(_boss.get_spit_left(), 9.0 / 12.0 - DT, 0.02, "Aviso de 9 cuadros a 12 fps (0,75 s)")
	var arrows: Array = _boss.get_warnings().filter(func(w: Dictionary) -> bool: return w["kind"] == "arrow_down")
	assert_eq(arrows.size(), 2, "Una flecha sobre cada plataforma")
	assert_eq(_boss.get_bubbles().size(), 0, "Sin Burbujas durante el aviso")
	_advance(0.6)
	assert_eq(_boss.get_bubbles().size(), 0)
	_advance(0.2)
	var bubbles: Array[AlertBubble] = _boss.get_bubbles()
	assert_eq(bubbles.size(), 2, "Escupe dos")
	assert_true(_boss.get_warnings().is_empty(), "El aviso desaparece")
	await wait_physics_frames(60)
	var sides: Array = []
	for b: AlertBubble in bubbles:
		assert_almost_eq(b.global_position.y, 8.0 * TILE, 2.0, "Cae en una plataforma lateral (fila 8)")
		var x: float = b.global_position.x / TILE
		sides.append("izquierda" if x > 3.0 and x < 7.0 else ("derecha" if x > 17.0 and x < 21.0 else "fuera"))
	sides.sort()
	assert_eq(sides, ["derecha", "izquierda"], "Una en cada lateral")
	_advance(12.0)
	assert_eq(_boss.get_bubbles().size(), 2, "Nunca mas de 2 vivas")


func test_phase1_sweeps_alternate_lanes_with_the_banner_warning() -> void:
	await _arena()
	_boss.start()
	await _spit_and_land()
	var floor_b := _boss.get_banners()["floor"] as SpamBanner
	var high_b := _boss.get_banners()["high"] as SpamBanner
	assert_eq(floor_b.get_corridor_rect(), Rect2(Vector2(64, 576), Vector2(22 * 64, 64)), "Carril del suelo")
	assert_eq(high_b.get_corridor_rect(), Rect2(Vector2(64, 448), Vector2(22 * 64, 64)), "Carril alto")
	var order: Array[String] = []
	floor_b.state_changed.connect(func(_p: StringName, c: StringName) -> void:
		if c == SpamBanner.STATE_WARN: order.append("floor"))
	high_b.state_changed.connect(func(_p: StringName, c: StringName) -> void:
		if c == SpamBanner.STATE_WARN: order.append("high"))
	var both: bool = false
	for i: int in ceili(10.0 / DT):
		_advance(DT)
		both = both or (floor_b.is_busy() and high_b.is_busy())
	assert_false(both, "Nunca barren los dos carriles a la vez")
	assert_eq(order.slice(0, 3), ["floor", "high", "floor"], "Alternan carril cada 3 s")
	assert_almost_eq(floor_b.get_warn_s(), 0.75, EPS, "Aviso del banner de 9 cuadros")


func test_sweep_hits_the_real_isak_in_its_lane_and_the_other_lane_is_safe() -> void:
	await _arena(1, false, true)
	_boss.start()
	# En la plataforma lateral: el barrido del suelo no le alcanza; el alto si.
	_place_isak(4, 7)
	var sync: float = GameState.sync_rate
	assert_true(_boss.trigger_sweep("floor"))
	_step_lanes(3.0)
	assert_almost_eq(GameState.sync_rate, sync, EPS, "El carril alto es refugio del barrido del suelo")
	_place_isak(4, 7)
	assert_true(_boss.trigger_sweep("high"))
	_step_lanes(3.0)
	assert_almost_eq(GameState.sync_rate, sync - 10.0, EPS, "El barrido alto quita 10")


func test_dash_through_the_floor_sweep_takes_no_damage() -> void:
	await _arena(1, false, true)
	_boss.start()
	_place_isak(12, 9)
	var isak: Isak = _level.get_isak()
	var sync: float = GameState.sync_rate
	var banner := _boss.get_banners()["floor"] as SpamBanner
	assert_true(_boss.trigger_sweep("floor"))
	var dashed: bool = false
	for i: int in ceili(3.0 / DT):
		if not dashed and banner.is_sweeping() and banner.get_banner_center_x() > isak.global_position.x - 150.0:
			_sim.input.move_axis = -1.0
			_sim.input.dash_pressed = true
			dashed = true
		_step_lanes(DT)
		_sim.input.move_axis = 0.0
	assert_true(dashed, "Ha hecho el dash")
	assert_almost_eq(GameState.sync_rate, sync, EPS, "El dash atraviesa el barrido sin dano")
	assert_false(banner.is_busy(), "El barrido ha terminado")
	assert_lt(isak.global_position.x, 12.0 * TILE, "Ha cruzado hacia el banner")


func test_window_opens_only_with_both_bubbles_neutralized() -> void:
	await _arena()
	_boss.start()
	await _spit_and_land()
	var bubbles: Array[AlertBubble] = _boss.get_bubbles()
	bubbles[0].stun()
	_advance(0.5)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_HOVER, "Con una sola aturdida no baja")
	assert_false(_boss.are_bubbles_neutralized())
	bubbles[1].take_damage(10.0)
	assert_eq(_boss.get_bubbles().size(), 1, "La otra, derrotada con el laser")
	# Espera a que no haya barrido en curso y baja.
	for i: int in ceili(4.0 / DT):
		_advance(DT)
		if _boss.get_move() != AlertMajor.MOVE_HOVER:
			break
	assert_eq(_boss.get_move(), AlertMajor.MOVE_DESCEND, "Aturdida + derrotada a la vez: se desinfla y baja")
	assert_false(_boss.get_banners()["floor"].is_busy() or _boss.get_banners()["high"].is_busy(),
		"Sin barridos mientras baja")
	_advance(0.6 + DT)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_DOWN)
	assert_true(_boss.is_window_open())
	assert_almost_eq(_boss.get_window_time_left(), 5.0, 0.05, "Ventana de 5 s del mundo")
	assert_true(_boss.get_core().is_enabled())
	assert_almost_eq(_boss.get_core_target(), Vector2(12.0 * TILE, 10.0 * TILE - 56.0), Vector2.ONE,
		"Nucleo en el suelo del centro, a la altura del celular de Isak")
	# Sin barridos mientras esta abajo.
	_advance(4.0)
	assert_false(_boss.get_banners()["floor"].is_busy() or _boss.get_banners()["high"].is_busy())


func test_three_hits_in_the_window_go_to_phase_2_with_refills() -> void:
	await _arena()
	_boss.start()
	await _spit_and_land()
	for b: AlertBubble in _boss.get_bubbles():
		b.stun()
	for i: int in ceili(4.0 / DT):
		_advance(DT)
		if _boss.is_window_open():
			break
	_advance(0.7)
	assert_true(_boss.is_window_open())
	_mark_core()
	GameState.debug_energy = 40.0
	GameState.sync_rate = 50.0
	for i: int in 3:
		_boss.get_core().on_laser_hit(1.0, null)
	assert_eq(_boss.get_counter_text(), "66", "99+ -> 88 -> 77 -> 66")
	assert_eq(_boss.get_phase(), 2)
	assert_almost_eq(GameState.debug_energy, 65.0, EPS, "+25 de energia al cambiar de fase")
	assert_almost_eq(GameState.sync_rate, 75.0, EPS, "+25 de Sync")
	assert_eq(_boss.get_bubbles().size(), 0, "Las Burbujas de la fase 1 desaparecen")
	assert_eq(_boss.get_banners().size(), 0, "Y los banners")


func test_window_close_loses_the_mark_goes_up_and_needs_new_stuns() -> void:
	await _arena()
	_boss.start()
	await _spit_and_land()
	for b: AlertBubble in _boss.get_bubbles():
		b.stun()
	for i: int in ceili(4.0 / DT):
		_advance(DT)
		if _boss.is_window_open():
			break
	_advance(0.7)
	_mark_core()
	_advance(4.3 + DT)
	assert_false(_boss.is_window_open())
	assert_false(_boss.get_core().is_marked(), "Al subir se pierde la marca")
	assert_eq(_boss.get_move(), AlertMajor.MOVE_ASCEND)
	_advance(0.6 + DT)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_HOVER)
	_advance(2.0)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_HOVER, "Las aturdidas de la ronda anterior no cuentan")
	assert_eq(_boss.get_bubbles().size(), 2, "Sigue con dos (no escupe mas)")


# --- Paso 7: fase 2 «66» ---

## Fase 2 recien empezada (sin ataques todavia).
func _phase2(sim: bool = false) -> void:
	await _arena(1, false, sim)
	_boss.start()
	_to_phase(2)
	assert_eq(_boss.get_phase(), 2)


## Avanza la fase 2 con los pop-ups y las notificaciones sin proceso propio.
func _advance2(seconds: float, isak: bool = false) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)
		for child: Node in _boss.get_attacks_root().get_children():
			if child is OverlayPopup:
				(child as OverlayPopup).set_process(false)
				(child as OverlayPopup).advance(DT)
				var p := child as OverlayPopup
				if p.follow_target != null:
					p.global_position = p.follow_target.global_position + p.follow_offset
			elif child is NotificationShot:
				(child as NotificationShot).auto_process = false
				(child as NotificationShot).step(DT)
		if isak and _sim != null:
			_sim.step()


func test_phase2_popups_cover_a_quarter_away_from_isak_at_most_two() -> void:
	await _phase2()
	_place_isak(2, 9)
	watch_signals(_boss)
	_advance2(1.5 + DT)
	assert_signal_emitted_with_parameters(_boss, "attack_started", [&"popup"])
	var outlines: Array = _boss.get_warnings().filter(func(w: Dictionary) -> bool: return w["kind"] == "outline")
	assert_eq(outlines.size(), 1, "Contorno punteado antes del pop-up")
	assert_eq(_boss.get_popups().size(), 0, "Aun no tapa")
	_advance2(0.75)
	var popups: Array[OverlayPopup] = _boss.get_popups()
	assert_eq(popups.size(), 1, "Sale tras el aviso de 9 cuadros")
	var p: OverlayPopup = popups[0]
	assert_ne(_boss.quarter_of(p.get_window_rect().get_center()), 0, "Nunca en el cuarto de Isak")
	assert_almost_eq(p.get_current_opacity(), 0.7, 0.01, "Translucido al 70 %")
	var button_y: float = p.get_button_rect().get_center().y
	assert_true(absf(button_y - (10.0 * TILE - 56.0)) < 1.0 or absf(button_y - (8.0 * TILE - 56.0)) < 1.0,
		"Boton a la altura del celular en un carril")
	var most: int = 0
	for i: int in 40:
		_advance2(0.5)
		most = maxi(most, _boss.get_popups().size())
	assert_eq(most, 2, "Como mucho 2 a la vez en Caché")
	# Un pulso a su boton lo cierra.
	var open: OverlayPopup = _boss.get_popups()[0]
	open.receive_pulse(_pulse_area(open.get_button_rect().get_center()))
	_advance2(0.5)
	assert_true(open.is_closed() or not is_instance_valid(open), "El pulso a su boton lo cierra")


func test_popup_closes_itself_after_its_life() -> void:
	await _phase2()
	_place_isak(2, 9)
	_advance2(1.5 + 0.75 + DT)
	var p: OverlayPopup = _boss.get_popups()[0]
	_advance2(7.5)
	assert_true(is_instance_valid(p) and p.is_open(), "Dura 8 s")
	_advance2(1.0)
	assert_false(is_instance_valid(p) and p.is_open(), "Y se cierra solo")


func test_burst_warns_then_three_shots_hit_the_real_isak_in_its_lane() -> void:
	await _phase2(true)
	_place_isak(4, 9)
	var sync: float = GameState.sync_rate
	watch_signals(_boss)
	assert_true(_boss.start_burst())
	assert_eq(_boss.get_burst_lane(), "floor", "El carril de Isak")
	assert_eq(_boss.get_burst_state(), &"warn")
	var lane: Array = _boss.get_warnings().filter(func(w: Dictionary) -> bool: return w["kind"] == "lane")
	assert_eq(lane.size(), 1, "Flecha en el muro y linea por el carril")
	assert_eq(int(lane[0]["dir"]), -1, "Entra por el muro mas lejano (el derecho)")
	_advance2(0.7, true)
	assert_eq(_boss.get_shots().size(), 0, "Nada durante el aviso de 9 cuadros")
	_advance2(0.1, true)
	assert_eq(_boss.get_shots().size(), 1, "Primera notificacion")
	_advance2(1.0, true)
	assert_eq(_boss.get_shots().size() + 0, 3, "Tres, separadas 0,5 s")
	_advance2(3.0, true)
	assert_lt(GameState.sync_rate, sync - 5.0, "La rafaga le quita Sync Rate")
	assert_eq(_boss.get_burst_state(), &"", "Rafaga terminada")


func test_the_other_lane_is_safe_from_a_burst_and_dash_goes_through_a_shot() -> void:
	await _phase2(true)
	_place_isak(4, 9)
	assert_true(_boss.start_burst())
	_place_isak(4, 7)
	var sync: float = GameState.sync_rate
	_advance2(5.0, true)
	assert_almost_eq(GameState.sync_rate, sync, EPS, "En la plataforma, la rafaga del suelo no alcanza")
	# Dash a traves de una notificacion.
	_place_isak(12, 9)
	var isak: Isak = _level.get_isak()
	var shot := NotificationShot.new()
	shot.direction = -1
	shot.travel_px = 1200.0
	shot.auto_process = false
	_boss.get_attacks_root().add_child(shot)
	shot.global_position = Vector2(20.0 * TILE, 10.0 * TILE - 56.0)
	var dashed: bool = false
	for i: int in 150:
		if not dashed and shot.global_position.x - isak.global_position.x < 110.0:
			_sim.input.move_axis = 1.0
			_sim.input.dash_pressed = true
			dashed = true
		if is_instance_valid(shot):
			shot.step(DT)
		_sim.step()
		_sim.input.move_axis = 0.0
	assert_true(dashed)
	assert_almost_eq(GameState.sync_rate, sync, EPS, "El dash atraviesa la notificacion")


func test_laser_and_pulse_do_not_stop_a_shot() -> void:
	await _phase2()
	var shot := NotificationShot.new()
	_boss.get_attacks_root().add_child(shot)
	assert_false(shot.has_method(&"on_laser_hit"), "El laser lo atraviesa")
	assert_false(shot.has_method(&"receive_pulse"), "El pulso no le afecta")


func test_shield_window_on_the_far_platform_opened_by_the_real_pulse() -> void:
	await _phase2(true)
	_place_isak(18, 9)
	watch_signals(_boss)
	_advance2(12.0 + DT, true)
	for i: int in 300:
		if _boss.get_move() != AlertMajor.MOVE_HOVER:
			break
		_advance2(DT, true)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_DESCEND, "Cada 12 s baja")
	_advance2(0.6 + DT, true)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_DOWN)
	assert_almost_eq(_boss.get_body_center(), Vector2(5.0 * TILE, 8.0 * TILE - 64.0), Vector2.ONE,
		"En la plataforma lejana de Isak (la izquierda)")
	assert_signal_emitted_with_parameters(_boss, "attack_started", [&"shield"])
	var shield: OverlayPopup = _boss.get_shield()
	assert_true(shield.is_open() and shield.visible, "Tapado por el escudo")
	assert_true(shield.get_window_rect().has_point(_boss.get_core().global_position), "El escudo tapa el nucleo")
	_debug_on()
	_advance2(0.2, true)
	assert_almost_eq(shield.get_current_opacity(), 1.0, EPS, "Opaco: el Debug no ve a traves")
	DebugMode.reset()
	assert_false(_boss.get_core().is_enabled(), "Con el escudo no hay nucleo")
	assert_false(_boss.is_window_open())
	# Isak sube a la plataforma y lanza un pulso de verdad al boton.
	_place_isak(3, 7)
	_level.get_isak().facing = 1.0
	_sim.input.pulse_pressed = true
	_advance2(DT, true)
	_advance2(0.5, true)
	assert_false(shield.is_open(), "El pulso al boton cierra el escudo")
	assert_true(_boss.is_window_open(), "Ventana abierta")
	assert_almost_eq(_boss.get_window_time_left(), 4.0 - 0.5, 0.1, "4 s del mundo")
	assert_true(_boss.get_core().is_enabled())
	assert_almost_eq(_boss.get_core_target(), Vector2(5.0 * TILE, 8.0 * TILE - 56.0), Vector2.ONE,
		"Nucleo a la altura del celular en la plataforma")
	_mark_core()
	_boss.get_core().on_laser_hit(1.0, null)
	_boss.get_core().on_laser_hit(1.0, null)
	assert_eq(_boss.get_counter_text(), "44", "Dos golpes en la ventana del escudo")
	_advance2(3.6, true)
	assert_false(_boss.is_window_open())
	assert_true(shield.is_open(), "El escudo vuelve")
	assert_false(_boss.get_core().is_marked(), "La marca se pierde")
	assert_eq(_boss.get_move(), AlertMajor.MOVE_ASCEND, "Y sube")


func test_shield_never_opened_goes_up_after_perch() -> void:
	await _phase2()
	_place_isak(4, 9)
	for i: int in ceili(18.0 / DT):
		_advance2(DT)
		if _boss.get_move() == AlertMajor.MOVE_DOWN:
			break
	assert_eq(_boss.get_move(), AlertMajor.MOVE_DOWN)
	assert_almost_eq(_boss.get_body_center().x, 19.0 * TILE, 1.0, "Lejos de Isak: la derecha")
	_advance2(6.9)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_DOWN)
	_advance2(0.2)
	assert_eq(_boss.get_move(), AlertMajor.MOVE_ASCEND, "Sin abrir el escudo en 7 s, sube")


func test_respawn_in_phase_2_clears_popups_and_shots() -> void:
	await _phase2()
	_place_isak(2, 9)
	_advance2(3.0)
	assert_true(_boss.start_burst() or _boss.get_burst_state() != &"")
	_advance2(1.0)
	assert_gt(_boss.get_attacks_root().get_child_count(), 1)
	GameState.debug_energy = 10.0
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	await wait_process_frames(1)
	assert_eq(_boss.get_popups().size(), 0)
	assert_eq(_boss.get_shots().size(), 0)
	assert_eq(_boss.get_counter_text(), "66", "Vuelve al principio de la fase 2")
	assert_almost_eq(GameState.debug_energy, 50.0, EPS)
