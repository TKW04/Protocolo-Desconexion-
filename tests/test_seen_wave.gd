# Ola de «Visto» (seen_wave; paso 7 del plan de docs/propuesta-mundo-4.md §8, §3.5 y
# decision 4 de §9): espera a que Isak cruce start_col; avanza con la velocidad de
# su seccion (y acelera dentro de una con speed_to); se para en sus paradas hasta
# que Isak sale de ellas; al alcanzar a Isak quita 10 sin matar y lo congela 2,0 s
# con el frente quieto; al descongelarse solo retrocede 4 tiles y con Agitar se
# queda a 1; morir congelado no cuenta como descongelarse y al reaparecer vuelve a
# la parada de su seccion; en end_col se apaga; la sala ola_test carga. Isak y la
# ola avanzan con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const WAVE_SCENE: PackedScene = preload("res://scenes/levels/seen_wave.tscn")
const PATH: String = "user://test_seen_wave_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const T: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_SHOCKWAVE]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


## Ola con el frente en la columna 0 (el suelo de la prueba esta en y = 0).
func _wave(stops: Array = [], end_col: int = -1) -> SeenWave:
	var wave := WAVE_SCENE.instantiate() as SeenWave
	wave.position = Vector2(0.0, -10.0 * T)
	wave.start_col = 3
	wave.end_col = end_col
	wave.sections = [
		{"x_from": 0, "x_to": 10, "speed_tiles_s": 1.0},
		{"x_from": 10, "x_to": 30, "speed_tiles_s": 1.2, "speed_to_tiles_s": 1.6},
	]
	wave.stops = stops
	wave.auto_process = false
	wave.isak = _isak
	wave.height_px = 11.0 * T
	_world.add_child(wave)
	return wave


func _stand_at(col: float) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()


func _step(wave: SeenWave, n: int = 1) -> void:
	for i: int in n:
		_sim.step()
		wave.advance(WorldTime.scaled_delta(DT))


func _isak_back() -> float:
	return LevelLookup.isak_body_rect(_isak).position.x


## Pone el frente justo en la espalda de Isak y avanza un paso: lo alcanza.
func _catch(wave: SeenWave) -> void:
	_step(wave)
	wave.set_front_x(_isak_back() + 1.0)
	_step(wave)


func test_waits_for_isak_then_moves_at_its_section_speed() -> void:
	var wave: SeenWave = _wave()
	_stand_at(2)
	_step(wave, 60)
	assert_eq(wave.get_state(), SeenWave.State.WAITING, "Quieta hasta que Isak cruza start_col")
	assert_almost_eq(wave.get_front_x(), 0.0, EPS)
	_stand_at(8)
	_step(wave)
	assert_eq(wave.get_state(), SeenWave.State.MOVING)
	var x0: float = wave.get_front_x()
	_step(wave, 60)
	assert_almost_eq(wave.get_front_x() - x0, 64.0, 1.5, "1,0 tiles/s en la primera seccion")
	assert_almost_eq(wave.speed_at(10.0), 1.2, EPS)
	assert_almost_eq(wave.speed_at(20.0), 1.4, EPS, "Acelera dentro de la seccion (1,2 -> 1,6)")
	assert_almost_eq(wave.speed_at(50.0), 1.0, EPS, "Fuera de las secciones, la de por defecto")


func test_stops_until_isak_leaves_the_stop() -> void:
	var wave: SeenWave = _wave([{"id": "sync_1", "at_col": 2, "resume_col": 8}])
	_stand_at(5)
	var stopped: Array = []
	var resumed: Array = []
	wave.stopped_at.connect(func(id: StringName) -> void: stopped.append(id))
	wave.resumed.connect(func(id: StringName) -> void: resumed.append(id))
	_step(wave, roundi(2.2 / DT))
	assert_eq(wave.get_state(), SeenWave.State.STOPPED, "Se para en at_col")
	assert_almost_eq(wave.get_front_x(), 2.0 * T, EPS)
	assert_eq(stopped, [&"sync_1"])
	_step(wave, 120)
	assert_almost_eq(wave.get_front_x(), 2.0 * T, EPS, "Espera mientras Isak sigue en la parada")
	_stand_at(9)
	_step(wave)
	assert_eq(wave.get_state(), SeenWave.State.MOVING, "Isak sale de la parada: sigue")
	assert_eq(resumed, [&"sync_1"])
	_step(wave, 30)
	assert_gt(wave.get_front_x(), 2.0 * T, "Cada parada una vez")


func test_catching_isak_takes_ten_freezes_two_seconds_and_holds() -> void:
	var wave: SeenWave = _wave()
	_stand_at(6)
	var caught: Array = []
	wave.caught_isak.connect(func(d: bool) -> void: caught.append(d))
	_catch(wave)
	assert_eq(caught, [true])
	assert_almost_eq(GameState.sync_rate, GameState.get_sync_rate_max() - 10.0, EPS, "-10 de Sync")
	assert_true(_isak.is_frozen(), "Congelado")
	assert_eq(_isak.get_frozen_source(), Isak.FREEZE_SOURCE_WAVE)
	assert_almost_eq(_isak.get_frozen_total(), 2.0, EPS, "2,0 s")
	assert_eq(wave.get_state(), SeenWave.State.HOLDING)
	var front: float = wave.get_front_x()
	_step(wave, 60)
	assert_almost_eq(wave.get_front_x(), front, EPS, "El frente espera mientras Isak esta congelado")
	assert_eq(caught.size(), 1, "Un solo golpe")


func test_the_wave_never_kills_alone() -> void:
	var wave: SeenWave = _wave()
	_stand_at(6)
	GameState.sync_rate = 8.0
	_catch(wave)
	assert_almost_eq(GameState.sync_rate, 1.0, EPS, "Sin matar: se queda en 1")
	assert_false(_isak.is_dead())


func test_thawing_alone_pushes_the_wave_back_four_tiles() -> void:
	var wave: SeenWave = _wave()
	_stand_at(8)
	var released: Array = []
	wave.released.connect(func(b: bool, x: float) -> void: released.append([b, x]))
	_catch(wave)
	var steps: int = 0
	while _isak.is_frozen() and steps < 200:
		_step(wave)
		steps += 1
	_step(wave)
	assert_almost_eq(float(steps) * DT, 2.0, 0.05, "Se descongela solo a los 2,0 s")
	assert_eq(released.size(), 1)
	assert_false(released[0][0], "Sin Agitar")
	assert_almost_eq(_isak_back() - wave.get_front_x(), 4.0 * T, 3.0, "«Ya te leyo»: 4 tiles detras")
	assert_eq(wave.get_state(), SeenWave.State.MOVING, "Y sigue avanzando")


func test_shake_breaks_free_but_leaves_the_wave_one_tile_away() -> void:
	var wave: SeenWave = _wave()
	_stand_at(8)
	var released: Array = []
	wave.released.connect(func(b: bool, x: float) -> void: released.append([b, x]))
	_catch(wave)
	_step(wave, 10)
	_sim.input.shake_pressed = true
	_step(wave)
	_step(wave)
	assert_false(_isak.is_frozen(), "Agitar rompe la congelacion")
	assert_eq(released.size(), 1)
	assert_true(released[0][0], "Con Agitar")
	assert_almost_eq(_isak_back() - wave.get_front_x(), 1.0 * T, 3.0, "La ola se queda a 1 tile")


func test_dying_frozen_is_ignored_and_respawn_returns_to_the_start() -> void:
	var wave: SeenWave = _wave()
	_stand_at(8)
	var released: Array = []
	wave.released.connect(func(b: bool, x: float) -> void: released.append([b, x]))
	_catch(wave)
	_isak.die()
	wave.advance(DT)
	assert_eq(released.size(), 0, "Morir congelado no es descongelarse")
	assert_eq(wave.get_state(), SeenWave.State.HOLDING)
	_isak.respawn(Vector2(1.5 * T, 0.0))
	EventBus.player_respawned.emit(_isak.global_position, true)
	assert_eq(wave.get_state(), SeenWave.State.WAITING, "Sin paradas: vuelve a esperar en su sitio")
	assert_almost_eq(wave.get_front_x(), 0.0, EPS)


func test_respawn_returns_the_wave_to_the_stop_of_its_section() -> void:
	var wave: SeenWave = _wave([{"id": "sync_1", "at_col": 2, "resume_col": 8}])
	_stand_at(5)
	_step(wave, roundi(2.2 / DT))
	_stand_at(12)
	_step(wave, 60)
	assert_gt(wave.get_front_x(), 2.0 * T)
	_isak.respawn(Vector2(5.5 * T, 0.0))
	EventBus.player_respawned.emit(_isak.global_position, true)
	assert_eq(wave.get_state(), SeenWave.State.STOPPED, "Vuelve a la parada de su seccion")
	assert_almost_eq(wave.get_front_x(), 2.0 * T, EPS)
	assert_eq(wave.get_stop_id(), &"sync_1")
	_stand_at(9)
	_step(wave)
	assert_eq(wave.get_state(), SeenWave.State.MOVING, "Y sale de nuevo al dejar la parada")


func test_end_col_turns_the_wave_off() -> void:
	var wave: SeenWave = _wave([], 2)
	_stand_at(10)
	_step(wave, roundi(2.2 / DT))
	assert_true(wave.is_off(), "En end_col se para y se apaga")
	assert_almost_eq(wave.get_front_x(), 2.0 * T, EPS)
	_stand_at(1)
	_step(wave)
	assert_false(_isak.is_frozen(), "Apagada no alcanza")


func test_ola_test_room_loads() -> void:
	var scene := load("res://scenes/levels/ola_test.tscn") as PackedScene
	assert_not_null(scene, "Sala ola_test generada")
	var level: Node = scene.instantiate()
	var wave := level.get_node(^"Objects/ola_prueba") as SeenWave
	assert_not_null(wave)
	assert_eq(wave.start_col, 6)
	assert_eq(wave.stops.size(), 1)
	assert_eq(wave.sections.size(), 2)
	level.free()
