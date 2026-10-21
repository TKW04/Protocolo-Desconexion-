# BossBase (paso 2 de docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21):
# contador 99+ -> 66 -> 33 -> 0 (9 golpes en Caché, 12 en Kernel y Raíz), cambio
# de fase al llegar a 66/33 con +25 de energia y de Sync Rate, reaparicion al
# principio de la fase con energia max(actual, 50), golpe final al llegar a 0
# (sin rollback ni cambio de vuelta), ventanas en tiempo del mundo y senales de
# EventBus (sin boss_rollback_attempted).
extends GutTest

var _boss: BossBase
var _events: Array = []
var _saved_energy: float
var _saved_sync: float
var _saved_lap: int


func before_each() -> void:
	_saved_energy = GameState.debug_energy
	_saved_sync = GameState.sync_rate
	_saved_lap = GameState.lap
	_events.clear()
	EventBus.boss_started.connect(_on_started)
	EventBus.boss_phase_changed.connect(_on_phase)
	EventBus.boss_weak_point_hit.connect(_on_hit)
	EventBus.boss_defeated.connect(_on_defeated)


func after_each() -> void:
	EventBus.boss_started.disconnect(_on_started)
	EventBus.boss_phase_changed.disconnect(_on_phase)
	EventBus.boss_weak_point_hit.disconnect(_on_hit)
	EventBus.boss_defeated.disconnect(_on_defeated)
	GameState.debug_energy = _saved_energy
	GameState.sync_rate = _saved_sync
	GameState.lap = _saved_lap


func _on_started(id: StringName) -> void:
	_events.append(["started", id])


func _on_phase(id: StringName, phase: int) -> void:
	_events.append(["phase", id, phase])


func _on_hit(id: StringName, remaining: int) -> void:
	_events.append(["hit", id, remaining])


func _on_defeated(id: StringName) -> void:
	_events.append(["defeated", id])


func _spawn(lap: int = 1) -> BossBase:
	_boss = BossBase.new()
	_boss.boss_id = &"alert_major"
	_boss.auto_process = false
	_boss.lap_override = lap
	add_child_autofree(_boss)
	return _boss


func _hits(n: int, damage: int = 1) -> void:
	for i: int in n:
		_boss.take_core_hit(damage)


func test_data_and_group() -> void:
	_spawn()
	assert_true(_boss.is_in_group(BossBase.GROUP), "Grupo boss (PassiveRegen)")
	assert_eq(_boss.get_hits_per_phase(), [3, 3, 3] as Array[int], "Caché: 3/3/3")
	assert_eq(_boss.get_total_hits(), 9)
	assert_false(_boss.is_combat_active(), "Antes de empezar no hay combate")
	assert_false(EventBus.has_signal(&"boss_rollback_attempted"), "Sin rollback (decision 1)")


func test_counter_goes_99_plus_to_0_and_phases_at_66_and_33() -> void:
	_spawn()
	_boss.start()
	assert_eq(_events, [["started", &"alert_major"]])
	assert_eq(_boss.get_phase(), 1)
	assert_true(_boss.is_combat_active())
	var labels: Array[String] = [_boss.get_counter_label()]
	var phases: Array[int] = [_boss.get_phase()]
	for i: int in 9:
		assert_true(_boss.take_core_hit(1))
		labels.append(_boss.get_counter_label())
		phases.append(_boss.get_phase())
	assert_eq(labels, ["99+", "88", "77", "66", "55", "44", "33", "22", "11", "0"] as Array[String])
	assert_eq(phases, [1, 1, 1, 2, 2, 2, 3, 3, 3, 3] as Array[int])
	var phase_events: Array = _events.filter(func(e: Array) -> bool: return e[0] == "phase")
	assert_eq(phase_events, [["phase", &"alert_major", 2], ["phase", &"alert_major", 3]])
	assert_eq(_events.filter(func(e: Array) -> bool: return e[0] == "hit").size(), 9)
	assert_eq(_events[_events.size() - 1], ["defeated", &"alert_major"])


func test_phase_change_refills_energy_and_sync() -> void:
	_spawn()
	_boss.start()
	GameState.debug_energy = 10.0
	GameState.sync_rate = 50.0
	_hits(2)
	assert_eq(GameState.debug_energy, 10.0, "Golpes normales: nada")
	_hits(1)
	assert_almost_eq(GameState.debug_energy, 35.0, 0.001, "+25 de energia al cambiar de fase")
	assert_almost_eq(GameState.sync_rate, 75.0, 0.001, "+25 de Sync Rate")


func test_respawn_restarts_current_phase_with_energy_at_least_50() -> void:
	_spawn()
	_boss.start()
	_hits(4)
	assert_eq(_boss.get_phase(), 2)
	assert_eq(_boss.get_counter_label(), "55")
	GameState.debug_energy = 20.0
	var restarted: Array[int] = []
	_boss.phase_restarted.connect(func(p: int) -> void: restarted.append(p))
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(restarted, [2] as Array[int])
	assert_eq(_boss.get_phase(), 2, "Sigue en la fase 2")
	assert_eq(_boss.get_counter_label(), "66", "Contador al principio de la fase")
	assert_eq(_boss.get_phase_hits_left(), 3)
	assert_eq(GameState.debug_energy, 50.0, "max(20, 50)")
	GameState.debug_energy = 80.0
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(GameState.debug_energy, 80.0, "max(80, 50)")
	# Reaparecer sin morir (caida) no reinicia la fase.
	_hits(1)
	EventBus.player_respawned.emit(Vector2.ZERO, false)
	assert_eq(_boss.get_counter_label(), "55")


func test_respawn_in_phase_1_restores_full_counter() -> void:
	_spawn()
	_boss.start()
	_hits(2)
	_boss.restart_phase()
	assert_eq(_boss.get_counter_label(), "99+")
	assert_eq(_boss.get_phase(), 1)


func test_final_blow_defeats_without_rollback() -> void:
	_spawn()
	_boss.start()
	var lap_before: int = GameState.lap
	var defeated: Array[bool] = []
	_boss.defeated.connect(func() -> void: defeated.append(true))
	_hits(9)
	assert_eq(defeated, [true])
	assert_true(_boss.is_defeated())
	assert_eq(_boss.get_counter(), 0)
	assert_false(_boss.is_combat_active(), "Ya no hay combate")
	assert_false(_boss.take_core_hit(1), "Tras el golpe final no cuenta nada")
	assert_eq(GameState.lap, lap_before, "Sin cambio de vuelta")
	_boss.restart_phase()
	assert_true(_boss.is_defeated(), "Reaparecer no revive al jefe")


func test_extra_damage_does_not_cross_a_phase() -> void:
	_spawn()
	_boss.start()
	_hits(2)
	_boss.take_core_hit(2)
	assert_eq(_boss.get_phase(), 2)
	assert_eq(_boss.get_remaining_hits(), 6, "El segundo golpe del laser 4 se pierde al acabar la fase")
	_boss.take_core_hit(2)
	assert_eq(_boss.get_remaining_hits(), 4, "Dentro de la fase cuenta 2")


func test_kernel_has_12_hits_and_same_thresholds() -> void:
	_spawn(2)
	_boss.start()
	assert_eq(_boss.get_total_hits(), 12)
	_hits(4)
	assert_eq(_boss.get_phase(), 2)
	assert_eq(_boss.get_counter_label(), "66")
	_hits(4)
	assert_eq(_boss.get_counter_label(), "33")


func test_window_counts_world_time_and_closes() -> void:
	_spawn()
	_boss.start()
	var closed: Array[bool] = []
	_boss.window_closed.connect(func() -> void: closed.append(true))
	_boss.open_window(5.0)
	assert_true(_boss.is_window_open())
	_boss.advance(2.0)
	assert_almost_eq(_boss.get_window_time_left(), 3.0, 0.001)
	_boss.advance(3.0)
	assert_false(_boss.is_window_open())
	assert_eq(closed, [true])
	assert_eq(_boss.get_window_time_left(), 0.0)
	# Un cambio de fase cierra la ventana.
	_boss.open_window(5.0)
	_hits(3)
	assert_false(_boss.is_window_open(), "La fase nueva empieza sin ventana")


func test_bot_api_defaults() -> void:
	_spawn()
	assert_eq(_boss.get_phase(), 0)
	assert_eq(_boss.get_attack_state(), BossBase.ATTACK_NONE)
	assert_eq(_boss.get_core_target(), Vector2.INF)
	assert_false(_boss.take_core_hit(1), "Sin empezar no cuenta")
