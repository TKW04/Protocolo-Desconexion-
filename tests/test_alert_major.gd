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
func _arena(lap: int = 1, auto: bool = false) -> GeneratedLevel:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/alerta_mayor") as AlertMajor
	_boss.intro_on_arrival = false
	_boss.auto_process = auto
	_boss.lap_override = lap
	add_child_autofree(_level)
	await wait_physics_frames(2)
	return _level


func _obj(id: String) -> Node:
	return _level.get_node_or_null(NodePath("Objects/" + id))


func _enemy(id: String) -> Node:
	return _level.get_node_or_null(NodePath("Enemies/" + id))


func _tiles() -> TileMapLayer:
	return _level.get_node(^"Tiles") as TileMapLayer


func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)


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
