# El Vendedor, jefe del Mundo 5: datos y logica (paso 15 de docs/propuesta-mundo-5.md
# §8, 2026-10-29; diseño en §5.1-§5.3). Siempre te atiende de frente: se gira
# laps.<n>.turn_s s del mundo despues de que Isak cambie de lado (aviso 9 cuadros
# antes). El «Cancelar» (WeakPoint) va en la espalda y solo esta activo con Isak
# detras: sin el Debug el pulso no marca; detras y con el Debug activo lo marca y
# el laser es UN golpe por marca (laps.<n>.mark_hits = 1) sin el Debug. La marca no
# cae al girarse. Sin arena: el jefe sobre un suelo llano con el Isak real
# (IsakSim) y el tiempo a mano. Las fases en la arena real 5-boss:
# tests/test_vendor_arena.gd (paso 16).
extends GutTest

const VENDOR_SCENE: PackedScene = preload("res://scenes/bosses/vendor.tscn")
const IsakSim = preload("res://tests/support/isak_sim.gd")
const PATH: String = "user://test_vendor_boss.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
## El suelo llano del arnes esta en y = 0; la arena pone el suyo en la fila 10.
const ARENA_OFFSET: Vector2 = Vector2(0.0, -10.0 * TILE)

var _saved_path: String
var _saved_lap: int
var _saved: Dictionary = {}
var _world: Node2D
var _objects: Node2D
var _boss: Vendor
var _isak: Isak
var _sim: IsakSim
var _config: DebugModeConfig = DebugModeConfig.shared()


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_lap = GameState.lap
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.sync_rate = GameState.get_sync_rate_max()


func after_each() -> void:
	_world = null
	_objects = null
	_boss = null
	_isak = null
	_sim = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.lap = _saved_lap
	GameState.save_path = _saved_path
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## El jefe (en su celda de la arena, 8, 5; maquina en las columnas 8-11) sobre un
## suelo llano con Isak en la columna `col` (delante: mira a la izquierda al empezar).
func _setup(lap: int = 1, col: int = 4) -> void:
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	_isak = _sim.isak
	_objects = Node2D.new()
	_objects.name = "Objects"
	_objects.position = ARENA_OFFSET
	_world.add_child(_objects)
	_boss = VENDOR_SCENE.instantiate() as Vendor
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	_boss.lap_override = lap
	_boss.position = Vector2(8, 5) * TILE
	_objects.add_child(_boss)
	add_child_autofree(_world)
	_sim.take_manual_control()
	_boss.get_core().auto_process = false
	await wait_physics_frames(2)
	_place_isak(col)
	_boss.start()
	_advance(DT)


func _place_isak(col: int, facing: float = 1.0) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, 0.0)
	_isak.velocity = Vector2.ZERO
	_isak.facing = facing
	_sim.settle()


func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)


func _advance_until(cond: Callable, max_s: float = 20.0) -> float:
	var t: float = 0.0
	while t < max_s and not cond.call():
		_advance(DT)
		t += DT
	return t


func _debug_on() -> void:
	if not DebugMode.is_active():
		for i: int in roundi(_config.activation_hold_s / DT):
			DebugMode.step(DT, true)
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


func _pulse_area(pos: Vector2, radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = pos
	add_child_autofree(area)
	return area


## Marca con el Debug (pulso en el boton), lo apaga y dispara: un golpe.
func _mark_and_shoot() -> void:
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	assert_true(core.receive_pulse(_pulse_area(core.global_position)), "El pulso alcanza el boton")
	DebugMode.reset()
	assert_true(core.is_marked(), "Marcado")
	core.on_laser_hit(1.0, null)


# --- Datos ---

func test_data_laps_hits_marks_turn_and_tokens() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/vendor.json"))
	assert_eq(data["id"], "vendor")
	assert_eq(int(data["world"]), 5)
	var expect: Dictionary = {"1": [[3, 3, 3], 4.0, 4.0, 1.2, 15.0], "2": [[4, 4, 4], 3.0, 5.0, 1.2, 12.0],
		"3": [[4, 4, 4], 2.5, 6.0, 0.9, 10.0]}
	for lap: String in expect:
		var entry: Dictionary = data["laps"][lap]
		assert_eq(str((entry["hits_per_phase"] as Array).map(func(v: Variant) -> int: return int(v))), str(expect[lap][0]),
			"Golpes por fase, acceso %s" % lap)
		assert_almost_eq(float(entry["mark_duration_s"]), float(expect[lap][1]), EPS, "Marca, acceso %s" % lap)
		assert_eq(int(entry["mark_hits"]), 1, "Un golpe por marca, acceso %s" % lap)
		assert_almost_eq(float(entry["charger_cooldown_s"]), float(expect[lap][2]), EPS, "Cargadores, acceso %s" % lap)
		assert_almost_eq(float(entry["turn_s"]), float(expect[lap][3]), EPS, "Giro, acceso %s" % lap)
		assert_almost_eq(float(entry["countdown_s"]), float(expect[lap][4]), EPS, "Cuenta, acceso %s" % lap)
	assert_eq(int(data["turn"]["warn_frames"]), 9, "Aviso del giro: 9 cuadros")
	assert_eq(float(data["respawn_min_energy"]), 50.0)
	for key: String in ["intro", "final_system", "defeat"]:
		assert_false(String(data["texts"][key]).is_empty(), "texts.%s" % key)
	var eco: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	assert_eq(int(eco["boss_tokens"]["start"]), 12, "12 fichas de regalo")


func test_starts_with_full_life_tokens_and_facing_isak() -> void:
	await _setup()
	assert_eq(_boss.get_remaining_hits(), 9, "Caché: 9 golpes")
	assert_eq(_boss.get_counter_label(), "99+")
	assert_eq(_boss.get_tokens(), 12)
	assert_eq(_boss.get_facing(), Vendor.SIDE_LEFT, "Mira a la izquierda, a Isak")
	assert_false(_boss.is_isak_behind())
	assert_false(_boss.get_core().is_enabled(), "Con Isak delante, el «Cancelar» no esta")
	var m: Rect2 = _boss.get_machine_rect()
	assert_eq(m, Rect2(Vector2(8 * TILE, 5 * TILE) + ARENA_OFFSET, Vector2(4, 5) * TILE), "Maquina de 4 x 5")
	assert_gt(_boss.get_core().global_position.x, m.end.x - 8.0, "El boton, en la espalda (derecha)")
	assert_almost_eq(_boss.get_core().global_position.y, -58.0, 0.5, "A la altura del celular en el suelo")


func test_machine_is_solid() -> void:
	await _setup(1, 6)
	_sim.input.move_axis = 1.0
	_sim.step(_sim.frames(1.5))
	_sim.input.move_axis = 0.0
	var half: float = _isak.get_hitbox_size().x * 0.5
	assert_lte(_isak.global_position.x, _boss.get_machine_rect().position.x - half + 1.0, "No atraviesa la maquina")


# --- La marca ---

func test_in_front_no_mark_even_with_debug() -> void:
	await _setup()
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	assert_false(core.receive_pulse(_pulse_area(core.global_position)), "Delante, el boton no reacciona")
	assert_false(core.is_marked())


func test_behind_without_debug_no_mark_and_the_laser_sparks() -> void:
	await _setup()
	_place_isak(13, -1.0)
	_advance(DT)
	assert_true(_boss.is_isak_behind(), "Detras")
	var core: WeakPoint = _boss.get_core()
	assert_true(core.is_enabled(), "Detras, el «Cancelar» esta")
	assert_false(core.is_exposed(), "Sin el Debug no se ve")
	core.receive_pulse(_pulse_area(core.global_position))
	assert_false(core.is_marked(), "Sin el Debug el pulso no marca")
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 9, "El laser sin marca no dana")
	assert_true(core.is_spark_visible(), "Chispa gris")


func test_behind_with_debug_marks_and_one_hit_per_mark() -> void:
	await _setup()
	_place_isak(13, -1.0)
	_advance(DT)
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	_advance(DT)
	assert_true(core.is_exposed(), "Con el Debug, en rojo")
	assert_true(core.receive_pulse(_pulse_area(core.global_position)), "El pulso lo alcanza")
	assert_true(core.is_marked(), "Marcado")
	assert_almost_eq(core.get_mark_time_left(), 4.0, EPS, "Caché: 4 s del mundo")
	DebugMode.reset()
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 8, "Un golpe sin el Debug")
	assert_false(core.is_marked(), "Un golpe por marca: la marca termina")
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 8, "Sin marca, el segundo laser no cuenta")


func test_laser_4_hits_for_two() -> void:
	await _setup()
	_place_isak(13, -1.0)
	_advance(DT)
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	core.receive_pulse(_pulse_area(core.global_position))
	DebugMode.reset()
	core.on_laser_hit(2.0, null)
	assert_eq(_boss.get_remaining_hits(), 7, "Laser 4: dos golpes")


func test_mark_by_access() -> void:
	for lap: int in [2, 3]:
		await _setup(lap)
		assert_eq(_boss.get_remaining_hits(), 12, "Kernel y Raíz: 12 golpes")
		_place_isak(13, -1.0)
		_advance(DT)
		_debug_on()
		var core: WeakPoint = _boss.get_core()
		core.receive_pulse(_pulse_area(core.global_position))
		assert_almost_eq(core.get_mark_time_left(), [3.0, 2.5][lap - 2], EPS, "Marca, acceso %d" % lap)
		DebugMode.reset()
		_world.queue_free()
		await wait_physics_frames(1)


# --- El giro ---

func test_turns_1_2_s_after_isak_changes_side() -> void:
	await _setup()
	var warned: Array = []
	var turned: Array = []
	_boss.turn_warned.connect(func() -> void: warned.append(_boss.get_time()))
	_boss.turned.connect(func(f: int) -> void: turned.append(f))
	_place_isak(13, -1.0)
	var t0: float = _boss.get_time()
	_advance(DT)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_PENDING, "Isak detras: va a girarse")
	assert_true(_boss.is_window_open(), "La ventana")
	_advance(1.2 - 0.75 - 2.0 * DT)
	assert_true(warned.is_empty(), "Aun sin aviso")
	_advance(3.0 * DT)
	assert_eq(warned.size(), 1, "Aviso 9 cuadros (0,75 s) antes de girarse")
	_advance(1.2 - (_boss.get_time() - t0) - DT)
	assert_eq(_boss.get_facing(), Vendor.SIDE_LEFT, "Antes de 1,2 s sigue de espaldas")
	_advance(2.0 * DT)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_TURNING, "A 1,2 s empieza a girarse")
	assert_true(_boss.get_core().is_enabled(), "Mientras gira, el boton sigue a tiro")
	_advance(0.25)
	assert_eq(turned, [Vendor.SIDE_RIGHT], "Mira a Isak")
	assert_false(_boss.is_isak_behind())
	assert_false(_boss.get_core().is_enabled(), "Ya de frente: sin boton")
	assert_lt(_boss.get_core().global_position.x, _boss.get_machine_rect().position.x + 8.0, "El boton, ahora a la izquierda")
	assert_false(_boss.is_window_open())


func test_going_back_to_the_front_cancels_the_turn() -> void:
	await _setup()
	_place_isak(13, -1.0)
	_advance(0.3)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_PENDING)
	_place_isak(4)
	_advance(DT)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_NONE, "Vuelve delante: no se gira")
	_advance(1.5)
	assert_eq(_boss.get_facing(), Vendor.SIDE_LEFT)


func test_root_turns_in_0_9_s() -> void:
	await _setup(3)
	_place_isak(13, -1.0)
	_advance(0.9 - DT)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_WARN)
	_advance(2.0 * DT)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_TURNING, "Raíz: 0,9 s")


func test_the_mark_does_not_drop_when_it_turns() -> void:
	await _setup()
	_place_isak(13, -1.0)
	_advance(DT)
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	core.receive_pulse(_pulse_area(core.global_position))
	DebugMode.reset()
	assert_true(core.is_marked())
	_advance_until(func() -> bool: return _boss.get_facing() == Vendor.SIDE_RIGHT, 3.0)
	assert_eq(_boss.get_facing(), Vendor.SIDE_RIGHT, "Se ha girado")
	assert_true(core.is_marked(), "La marca es del boton: no cae al girarse")
	assert_true(core.is_enabled())
	core.on_laser_hit(1.0, null)
	assert_eq(_boss.get_remaining_hits(), 8, "El laser a la espalda cuenta")
	_advance(DT)
	assert_false(core.is_enabled(), "Sin marca y de frente: se apaga")


func test_a_hit_makes_it_turn_at_once() -> void:
	await _setup()
	_place_isak(13, -1.0)
	_advance(0.2)
	_mark_and_shoot()
	assert_eq(_boss.get_remaining_hits(), 8)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_TURNING, "El golpe lo hace girarse ya")
	assert_false(_boss.is_window_open(), "Un golpe por ventana")
	_advance(0.3)
	assert_eq(_boss.get_facing(), Vendor.SIDE_RIGHT)


func test_phases_and_the_mark_is_lost_on_phase_change() -> void:
	await _setup()
	for i: int in 2:
		_boss.take_core_hit(1)
	_place_isak(13, -1.0)
	_advance(DT)
	var core: WeakPoint = _boss.get_core()
	_debug_on()
	core.receive_pulse(_pulse_area(core.global_position))
	assert_true(core.is_marked())
	_boss.take_core_hit(1)
	assert_eq(_boss.get_phase(), 2, "Tres golpes: fase 2")
	assert_false(core.is_marked(), "La marca cae al cambiar de fase")


func test_respawn_restarts_the_phase_with_its_tokens() -> void:
	await _setup()
	_boss.take_core_hit(1)
	_boss.set_tokens(4)
	GameState.debug_energy = 10.0
	EventBus.player_respawned.emit(_isak.global_position, true)
	assert_eq(_boss.get_phase(), 1)
	assert_eq(_boss.get_phase_hits_left(), 3, "La fase entera")
	assert_eq(_boss.get_tokens(), 12, "Las fichas que tenia al empezar la fase")
	assert_gte(GameState.debug_energy, 50.0, "Energia >= 50")


func test_defeat_turns_the_screen_off() -> void:
	await _setup()
	var blows: Array = []
	_boss.final_blow.connect(func() -> void: blows.append(true))
	for i: int in 9:
		_boss.take_core_hit(1)
	assert_true(_boss.is_defeated())
	assert_eq(blows.size(), 1)
	assert_true(_boss.is_screen_off())
	assert_false(_boss.get_core().is_enabled())
