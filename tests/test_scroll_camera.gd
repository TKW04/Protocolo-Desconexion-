# Camara de scroll forzado del Mundo 2 (2026-10-22, paso 2 de
# docs/propuesta-mundo-2.md §8; reglas aprobadas de §3.1-§3.2): ScrollCamera
# (scripts/player/scroll_camera.gd, data/camera_scroll.json) con una seccion
# scroll sintetica (velocidad por tramo, arranque al subir, paradas, inversion,
# avisos, tarjetas seguras, reinicio al reaparecer) y en la sala
# scenes/levels/scroll_test.tscn con Isak simulado (el Debug la frena, el borde
# quita 10 de Sync y devuelve a una tarjeta segura con 1 s de invulnerabilidad,
# un segundo contacto no cuenta, nunca mata de golpe, techo de carga, la muerte
# vuelve el scroll a la parada de la seccion).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const SCROLL_SCENE: PackedScene = preload("res://scenes/levels/scroll_test.tscn")
const LEVEL_2_1: PackedScene = preload("res://scenes/levels/2-1.tscn")
const DT: float = 1.0 / 60.0
const T: float = 64.0
const VIEW: Vector2 = Vector2(1280.0, 720.0)
const EPS: float = 0.01

## Nivel sintetico de 20 x 60: inicio abajo, parada en la fila 33, inversion en la 20.
const CONFIG: Dictionary = {
	"start_resume_row": 56,
	"default_speed_tiles_s": 0.5,
	"stages": [{"y_from": 34, "y_to": 58, "speed_tiles_s": 0.5}, {"y_from": 12, "y_to": 33, "speed_tiles_s": 1.0}],
	"stops": [{"id": "sync_1", "at_row": 33, "resume_row": 30}],
	"reverses": [{"at_row": 20, "duration_s": 2.0, "speed_tiles_s": 0.8}],
	"safe_respawn": [[3, 56], [8, 50], [8, 44], [8, 38], [9, 30], [5, 24], [5, 18], [5, 12]],
}

var _level: GeneratedLevel
var _isak: Isak
var _sim: IsakSim
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_DEBUG, GameState.ABILITY_GROUND_POUND]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.world_time_scale = GameState.WORLD_TIME_SCALE_NORMAL


func _camera() -> ScrollCamera:
	var cam := ScrollCamera.load_from_file()
	cam.configure(VIEW, Rect2(0.0, 0.0, 20.0 * T, 60.0 * T), CONFIG, T)
	return cam


func _feet(col: float, row: int) -> Vector2:
	return Vector2((col + 0.5) * T, float(row + 1) * T)


## Avanza la camara `seconds` del mundo con los pies en `feet`.
func _run(cam: ScrollCamera, feet: Vector2, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		cam.update(feet, DT)


# --- Datos ---

func test_data() -> void:
	var cam := ScrollCamera.load_from_file()
	assert_almost_eq(cam.edge_damage, 10.0, EPS, "El borde quita 10 de Sync")
	assert_almost_eq(cam.edge_invulnerability_s, 1.0, EPS)
	assert_almost_eq(cam.warn_s, 0.75, EPS, "9 cuadros a 12 fps")


# --- Unidad: ScrollCamera ---

func test_starts_parked_at_the_bottom_until_isak_climbs() -> void:
	var cam := _camera()
	assert_true(cam.is_parked())
	assert_eq(cam.get_parked_id(), &"start")
	assert_almost_eq(cam.get_bottom(), 60.0 * T, EPS, "Vista abajo del todo")
	assert_almost_eq(cam.get_center().x, 10.0 * T, EPS, "x fija en el centro (20 tiles)")
	_run(cam, _feet(3, 58), 5.0)
	assert_almost_eq(cam.get_bottom(), 60.0 * T, EPS, "Parado mientras no sube")
	_run(cam, _feet(3, 54), 1.0)
	assert_false(cam.is_parked(), "Arranca al subir por encima de start_resume_row")
	assert_almost_eq(60.0 * T - cam.get_bottom(), 0.5 * T - 0.5 * T * DT, 1.0, "0,5 tiles/s")


func test_speed_by_stage() -> void:
	var cam := _camera()
	assert_almost_eq(cam.speed_at(50.0 * T), 0.5 * T, EPS)
	assert_almost_eq(cam.speed_at(30.0 * T), 1.0 * T, EPS, "Tramo rapido")
	assert_almost_eq(cam.speed_at(5.0 * T), 0.5 * T, EPS, "Fuera de los tramos, la de por defecto")


func test_debug_world_time_halves_the_distance() -> void:
	var a := _camera()
	var b := _camera()
	var feet := _feet(3, 40)
	for i: int in 60:
		a.update(feet, DT)
		b.update(feet, DT * 0.5)
	var moved_a: float = 60.0 * T - a.get_bottom()
	var moved_b: float = 60.0 * T - b.get_bottom()
	assert_almost_eq(moved_b, moved_a * 0.5, 1.0, "El Debug (mundo x0,5) lo frena a la mitad")


func test_stops_at_the_sync_point_and_resumes_above_it() -> void:
	var cam := _camera()
	_run(cam, _feet(3, 40), 60.0)
	assert_true(cam.is_parked(), "Se para")
	assert_eq(cam.get_parked_id(), &"sync_1")
	assert_almost_eq(cam.get_bottom(), 34.0 * T, EPS, "En su at_row")
	_run(cam, _feet(9, 30), 3.0)
	assert_almost_eq(cam.get_bottom(), 34.0 * T, EPS, "Sigue parado con Isak en el punto")
	_run(cam, _feet(5, 28), 0.5)
	assert_false(cam.is_parked(), "Se reanuda al salir por arriba")
	assert_lt(cam.get_bottom(), 34.0 * T)


func test_reverse_runs_down_and_switches_the_damaging_edge() -> void:
	var cam := _camera()
	_run(cam, _feet(3, 40), 60.0)
	_run(cam, _feet(5, 10), 13.2)
	assert_true(cam.is_reversing(), "Invierte al llegar a su fila")
	assert_eq(cam.damaging_edge(), ScrollCamera.EDGE_TOP, "Dana el borde de arriba")
	var b0: float = cam.get_bottom()
	_run(cam, _feet(5, 10), 1.0)
	assert_almost_eq(cam.get_bottom() - b0, 0.8 * T, 2.0, "Baja a 0,8 tiles/s")
	assert_true(cam.touches_edge(_feet(5, 18), cam.get_top() - 1.0), "La cabeza por encima del borde de arriba")
	assert_false(cam.touches_edge(_feet(5, 18), cam.get_top() + 10.0))
	_run(cam, _feet(5, 10), 1.2)
	assert_false(cam.is_reversing(), "Termina a los 2 s")
	assert_eq(cam.damaging_edge(), ScrollCamera.EDGE_BOTTOM)


## Paso 14 (2-3 «Scroll infinito»): una inversion con `trigger` la arma Isak al
## entrar con los pies en la zona y empieza reverse_warn_s despues (con el aviso);
## sin entrar, at_row sigue de respaldo.
func test_reverse_armed_by_its_trigger_zone() -> void:
	var config: Dictionary = CONFIG.duplicate(true)
	config["reverses"] = [{"at_row": 12, "duration_s": 2.0, "speed_tiles_s": 0.8, "trigger": [10, 24, 4, 2]}]
	var cam := ScrollCamera.load_from_file()
	cam.configure(VIEW, Rect2(0.0, 0.0, 20.0 * T, 60.0 * T), config, T)
	_run(cam, _feet(3, 40), 60.0)
	_run(cam, _feet(5, 28), 0.5)
	assert_false(cam.is_reversing())
	_run(cam, _feet(5, 22), 2.0)
	assert_false(cam.is_reversing(), "Fuera de la zona no se arma (at_row aun lejos)")
	assert_false(cam.reverse_soon())
	_run(cam, _feet(11, 25), 0.1)
	assert_true(cam.reverse_soon(), "Armada: aviso de inversion")
	assert_false(cam.is_reversing())
	_run(cam, _feet(11, 25), cam.reverse_warn_s)
	assert_true(cam.is_reversing(), "Empieza reverse_warn_s despues de entrar")
	_run(cam, _feet(11, 25), 2.1)
	assert_false(cam.is_reversing(), "Termina a los 2 s y no se repite")
	_run(cam, _feet(11, 25), 2.0)
	assert_false(cam.is_reversing())


func test_warns_before_a_speed_change_and_a_reverse() -> void:
	var cam := _camera()
	_run(cam, _feet(3, 54), 0.1)
	# Justo antes del tramo rapido (fila 33): el borde de abajo en la linea 34 + 0,3 tiles.
	cam.reset_for(_feet(3, 58))
	_run(cam, _feet(3, 54), 0.1)
	var guard: int = 0
	while cam.get_bottom() > 34.0 * T + 0.3 * T and guard < 10000:
		cam.update(_feet(3, 40), DT)
		guard += 1
	assert_eq(cam.upcoming_change(), 1, "Aviso: mas rapido")
	guard = 0
	while cam.is_parked() == false and guard < 10000:
		cam.update(_feet(3, 40), DT)
		guard += 1
	assert_eq(cam.upcoming_change(), 0, "Parado: sin aviso")
	_run(cam, _feet(5, 28), 0.1)
	guard = 0
	while cam.get_bottom() > 21.0 * T + 0.5 * T and guard < 10000:
		cam.update(_feet(5, 10), DT)
		guard += 1
	assert_true(cam.reverse_soon(), "Aviso de inversion")


func test_edge_and_safe_point() -> void:
	var cam := _camera()
	assert_true(cam.touches_edge(Vector2(100.0, 60.0 * T + 1.0), 0.0), "Pies por debajo del borde de abajo")
	assert_false(cam.touches_edge(Vector2(100.0, 60.0 * T), 0.0))
	var safe: Vector2 = cam.safe_point(Vector2.ZERO)
	assert_eq(safe, _feet(3, 56), "La mas baja a la vista a 2 tiles o mas del borde")


func test_reset_for_respawn_returns_to_the_section_stop() -> void:
	var cam := _camera()
	_run(cam, _feet(3, 40), 60.0)
	_run(cam, _feet(5, 28), 6.0)
	cam.reset_for(_feet(9, 30))
	assert_eq(cam.get_parked_id(), &"sync_1", "Reaparecer en el punto: el scroll vuelve a su parada")
	assert_almost_eq(cam.get_bottom(), 34.0 * T, EPS)
	cam.reset_for(_feet(3, 58))
	assert_eq(cam.get_parked_id(), &"start", "En el vortice: al inicio")
	assert_almost_eq(cam.get_bottom(), 60.0 * T, EPS)


# --- Integracion: sala scroll_test con Isak ---

func _load(scene: PackedScene = SCROLL_SCENE) -> void:
	_level = scene.instantiate() as GeneratedLevel
	_isak = _level.get_node(^"Isak") as Isak
	_sim = IsakSim.new(DT)
	_sim.attach(_isak)
	add_child(_level)
	_sim.take_manual_control()
	await wait_physics_frames(2)
	_sim.settle()


func test_scene_uses_the_scroll_camera() -> void:
	await _load()
	var cam: ScrollCamera = _isak.get_scroll_camera()
	assert_not_null(cam, "camera_mode autoscroll")
	assert_null(_isak.get_tower_camera())
	assert_true(_isak.get_camera().top_level)
	assert_almost_eq(_isak.get_camera().global_position, cam.get_center(), Vector2(EPS, EPS))
	assert_true(cam.is_parked(), "Parado en la sala de inicio")


func test_edge_damages_and_returns_to_a_safe_card() -> void:
	await _load()
	var cam: ScrollCamera = _isak.get_scroll_camera()
	_isak.global_position = Vector2(5.5 * T, cam.get_bottom() + 40.0)
	_isak.velocity = Vector2.ZERO
	var hits: Array = []
	_isak.scroll_edge_hit.connect(func(damaged: bool) -> void: hits.append(damaged))
	_sim.step()
	assert_eq(hits, [true], "Toca el borde")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, EPS, "-10 de Sync")
	assert_lt(_isak.global_position.y, cam.get_bottom() - 64.0, "Reaparece por encima del borde")
	assert_true(_isak.is_invulnerable(), "1 s de invulnerabilidad")
	assert_ne(_isak.get_state_name(), PlayerState.HURT, "Sin retroceso")
	# Segundo contacto antes de 1 s: no cuenta.
	_isak.global_position = Vector2(5.5 * T, cam.get_bottom() + 40.0)
	_sim.step()
	assert_eq(hits, [true, false])
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, EPS, "No quita mas")


func test_edge_never_kills_outright() -> void:
	await _load()
	var cam: ScrollCamera = _isak.get_scroll_camera()
	for i: int in 9:
		_isak.global_position = Vector2(5.5 * T, cam.get_bottom() + 40.0)
		_sim.step()
		_sim.step(_sim.frames(1.05))
	assert_false(_isak.is_dead(), "9 contactos con Sync 100: vivo")
	assert_almost_eq(GameState.sync_rate, 10.0, EPS)


func test_ceiling_stops_isak_running_ahead() -> void:
	await _load()
	var cam: ScrollCamera = _isak.get_scroll_camera()
	var top: float = cam.get_top()
	_isak.global_position = Vector2(5.5 * T, top - 100.0)
	_isak.velocity = Vector2(0.0, -900.0)
	_sim.step()
	assert_almost_eq(_isak.global_position.y - _isak.hitbox_size.y, top - cam.ceiling_above_view_px, 1.0,
			"La cabeza no pasa del techo de carga")
	assert_true(_isak.velocity.y >= 0.0)


func test_debug_slows_the_level_scroll() -> void:
	await _load()
	var cam: ScrollCamera = _isak.get_scroll_camera()
	_isak.global_position = _feet(4, 50)
	_sim.step(2)
	var b0: float = cam.get_bottom()
	_sim.step(60)
	var normal: float = b0 - cam.get_bottom()
	GameState.world_time_scale = 0.5
	b0 = cam.get_bottom()
	_sim.step(60)
	assert_almost_eq(b0 - cam.get_bottom(), normal * 0.5, 1.0, "Con el Debug, a la mitad")


func test_respawn_after_death_resets_the_section() -> void:
	await _load()
	var cam: ScrollCamera = _isak.get_scroll_camera()
	_isak.global_position = _feet(4, 50)
	_sim.step(_sim.frames(4.0))
	assert_lt(cam.get_bottom(), 60.0 * T, "Ya subio")
	_isak.respawn(_feet(3, 58), 1.0)
	assert_eq(cam.get_parked_id(), &"start", "Vuelve a la parada del inicio")
	assert_almost_eq(_isak.get_camera().global_position.y, cam.get_center().y, EPS)


# --- Negativo (paso 21 de docs/propuesta-mundo-2.md §8): el que espera ---

## En el 2-1 real, quedarse quieto tras arrancar el scroll no es seguro: el borde
## lo alcanza una y otra vez (-10 de Sync por contacto, sin retroceso), lo
## devuelve a una tarjeta segura por encima del borde y nunca mata de golpe.
func test_waiting_in_the_2_1_is_punished_by_the_edge_without_killing() -> void:
	await _load(LEVEL_2_1)
	var cam: ScrollCamera = _isak.get_scroll_camera()
	assert_not_null(cam, "El 2-1 usa el scroll forzado")
	var hits: Array = []
	_isak.scroll_edge_hit.connect(func(damaged: bool) -> void: hits.append(damaged))
	# Sube a la tarjeta de la fila 119 (por encima de start_resume_row 121) y se queda quieto.
	_isak.global_position = _feet(4, 118)
	_isak.velocity = Vector2.ZERO
	_sim.step(_sim.frames(1.0))
	assert_false(cam.is_parked(), "El scroll arranca al subir")
	assert_eq(hits.size(), 0, "Aun lejos del borde")
	var below: int = 0
	for i: int in _sim.frames(45.0):
		_sim.step()
		if _isak.global_position.y - _isak.hitbox_size.y >= cam.get_bottom():
			below += 1
	assert_eq(below, 0, "Nunca queda entero por debajo del borde")
	var damaged: int = hits.count(true)
	assert_gte(damaged, 2, "El borde castiga varias veces al que espera (%d)" % damaged)
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0 * damaged, EPS, "-10 por contacto")
	assert_false(_isak.is_dead(), "El borde no mata de golpe")
