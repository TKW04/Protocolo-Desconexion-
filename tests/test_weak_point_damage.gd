# WeakPoint danable (paso 3 de docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21;
# §2.3): solo con el Debug activo cuentan el pulso (1) y el laser (su dano; 2 con
# el Laser 4); sin el Debug, chispa gris y nada; la carga del Debug no basta;
# desactivado no reacciona; el dash nunca dana. Con el Isak real (IsakSim): pulso,
# laser y dash contra el nucleo. Con el jefe «saco» (BossDummy): baja, se golpea,
# el contador baja de 99+ y sube; sala boss_test generada y cargable.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const WEAK_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/bosses/boss_dummy.tscn")
const DT: float = 1.0 / 60.0
const MAX_STEPS: int = 240

var _config: DebugModeConfig = DebugModeConfig.shared()
var _saved: Dictionary = {}
var _hits: Array = []
var _deflects: Array = []


func before_each() -> void:
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, true)
	_saved["energy"] = GameState.debug_energy
	_saved["lap"] = GameState.lap
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.sync_rate = GameState.get_sync_rate_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_hits.clear()
	_deflects.clear()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.debug_energy = _saved["energy"]
	GameState.lap = _saved["lap"]
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _debug_on() -> void:
	for i: int in roundi(_config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


func _weak(pos: Vector2 = Vector2(200.0, -50.0)) -> WeakPoint:
	var wp := WEAK_SCENE.instantiate() as WeakPoint
	wp.position = pos
	add_child_autofree(wp)
	wp.hit.connect(func(d: int, s: Node) -> void: _hits.append([d, s]))
	wp.deflected.connect(func(s: Node) -> void: _deflects.append(s))
	return wp


## PulseArea falsa: un circulo de `radius` en `pos`.
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


# --- WeakPoint solo ---

func test_layer_group_and_defaults() -> void:
	var wp: WeakPoint = _weak()
	await wait_physics_frames(1)
	assert_true(wp.is_in_group(LaserProjectile.GROUP_LASER_ACTIVATABLE), "El laser lo ve")
	assert_eq(wp.collision_layer, LaserProjectile.LAYER_ENEMY, "Capa enemy")
	assert_true(wp.is_enabled())
	assert_eq(WeakPoint.pulse_damage(), 1)


func test_laser_without_debug_sparks_and_does_no_damage() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	wp.on_laser_hit(1.0, null)
	assert_eq(_hits.size(), 0, "Sin Debug no hay dano")
	assert_eq(_deflects.size(), 1, "Chispa gris")
	assert_true(wp.is_spark_visible())
	for i: int in 60:
		await wait_process_frames(1)
		if not wp.is_spark_visible():
			break
	assert_false(wp.is_spark_visible(), "La chispa se apaga sola")


func test_laser_with_debug_counts_its_damage() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	_debug_on()
	wp.on_laser_hit(1.0, null)
	wp.on_laser_hit(2.0, null)
	assert_eq(_hits.map(func(h: Array) -> int: return h[0]), [1, 2], "Laser 1 y Laser 4 (2)")
	assert_eq(_deflects.size(), 0)


func test_debug_charging_is_not_enough() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	DebugMode.step(DT, true)
	assert_true(DebugMode.is_engaged() and not DebugMode.is_active(), "Cargando")
	wp.on_laser_hit(1.0, null)
	assert_eq(_hits.size(), 0, "Solo con el Debug activo")
	assert_eq(_deflects.size(), 1)


func test_pulse_reaches_by_circles() -> void:
	var wp: WeakPoint = _weak(Vector2(200.0, -50.0))
	await wait_process_frames(1)
	var far: Area2D = _pulse_area(Vector2(200.0 - 96.0 - 24.0 - 2.0, -50.0))
	var near: Area2D = _pulse_area(Vector2(200.0 - 96.0 - 24.0 + 2.0, -50.0))
	assert_false(wp.receive_pulse(far), "Fuera de alcance")
	assert_eq(_deflects.size() + _hits.size(), 0)
	assert_true(wp.receive_pulse(near), "Toca el borde del nucleo")
	assert_eq(_deflects.size(), 1, "Sin Debug: chispa")
	_debug_on()
	EventBus.pulse_fired.emit(near)
	assert_eq(_hits.map(func(h: Array) -> int: return h[0]), [1], "Con Debug: 1 golpe por pulso")


func test_disabled_ignores_everything() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	_debug_on()
	wp.set_enabled(false)
	wp.on_laser_hit(1.0, null)
	assert_false(wp.receive_pulse(_pulse_area(wp.position)))
	assert_eq(_hits.size() + _deflects.size(), 0)
	await wait_process_frames(1)
	assert_false(wp.is_revealed(), "Desactivado no se dibuja")
	wp.set_enabled(true)
	wp.on_laser_hit(1.0, null)
	assert_eq(_hits.size(), 1)


# --- Con el Isak real ---

func _isak_world() -> IsakSim:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	add_child_autofree(world)
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	return sim


func _fire_laser(sim: IsakSim) -> LaserProjectile:
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	sim.isak.laser_fired.connect(on_fired)
	sim.input.laser_pressed = true
	sim.step()
	for i: int in ceili(sim.isak.abilities.laser_windup_s / DT) + 2:
		if not fired.is_empty():
			break
		sim.step()
	sim.isak.laser_fired.disconnect(on_fired)
	if fired.is_empty():
		return null
	var p: LaserProjectile = fired[0]
	p.auto_process = false
	for i: int in MAX_STEPS:
		if p.is_finished():
			break
		p.step(DT)
	return p


func test_real_laser_hits_core_only_with_debug() -> void:
	var sim: IsakSim = await _isak_world()
	var origin: Vector2 = sim.isak.global_position + sim.isak.get_laser_origin()
	var wp: WeakPoint = _weak(Vector2(origin.x + 320.0, origin.y))
	await wait_physics_frames(2)
	var p: LaserProjectile = _fire_laser(sim)
	assert_not_null(p)
	assert_eq(p.get_hit_target(), wp, "El haz se para en el nucleo")
	assert_eq(_hits.size(), 0, "Sin Debug no cuenta")
	assert_eq(_deflects.size(), 1, "Chispa gris")
	sim.step(ceili(sim.isak.abilities.laser_cooldown_s / DT) + 30)
	_debug_on()
	p = _fire_laser(sim)
	assert_not_null(p)
	assert_eq(_hits.size(), 1, "Con Debug cuenta")
	assert_eq(_hits[0][0], roundi(sim.isak.abilities.laser_damage))


func test_real_pulse_hits_core_only_with_debug() -> void:
	var sim: IsakSim = await _isak_world()
	var origin: Vector2 = sim.isak.global_position + sim.isak.get_pulse_origin()
	_weak(Vector2(origin.x + 80.0, origin.y))
	await wait_physics_frames(1)
	sim.input.pulse_pressed = true
	sim.step()
	assert_eq(_deflects.size(), 1, "Pulso sin Debug: chispa gris")
	assert_eq(_hits.size(), 0)
	sim.step(sim.steps_for(0.6))
	_debug_on()
	sim.input.pulse_pressed = true
	sim.step()
	assert_eq(_hits.size(), 1, "Pulso con Debug: 1 golpe")
	assert_eq(_hits[0][0], 1)


func test_dash_never_damages_the_core() -> void:
	var sim: IsakSim = await _isak_world()
	var start: Vector2 = sim.isak.global_position
	# El nucleo justo en la trayectoria del dash, a la altura del cuerpo.
	_weak(Vector2(start.x + 96.0, start.y - 48.0))
	await wait_physics_frames(1)
	sim.input.move_axis = 1.0
	sim.input.dash_pressed = true
	sim.step()
	assert_true(sim.isak.is_dashing(), "Dash sin Debug")
	sim.step_until(func() -> bool: return not sim.isak.is_dashing(), sim.steps_for(1.0))
	sim.input.move_axis = 0.0
	assert_gt(sim.isak.global_position.x, start.x + 150.0, "Ha atravesado el nucleo")
	assert_eq(_hits.size() + _deflects.size(), 0, "El dash ni dana ni saca chispa")
	# Con el Debug activo el dash no sale (no se combinan), asi que tampoco dana.
	_debug_on()
	sim.input.move_axis = -1.0
	sim.input.dash_pressed = true
	sim.step()
	assert_false(sim.isak.is_dashing(), "Con el Debug no hay dash")
	sim.step(sim.steps_for(0.5))
	assert_eq(_hits.size(), 0)


# --- Jefe saco ---

func _dummy() -> BossDummy:
	var dummy := DUMMY_SCENE.instantiate() as BossDummy
	dummy.auto_process = false
	dummy.auto_start = false
	dummy.lap_override = 1
	dummy.position = Vector2(576.0, 576.0)
	add_child_autofree(dummy)
	return dummy


func _advance(dummy: BossDummy, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		dummy.advance(DT)


func test_dummy_goes_down_gets_hit_and_goes_up() -> void:
	var dummy: BossDummy = _dummy()
	await wait_process_frames(1)
	dummy.start()
	assert_eq(dummy.get_move(), BossDummy.MOVE_UP)
	assert_false(dummy.get_core().is_enabled(), "Arriba: nucleo desactivado")
	assert_eq(dummy.get_core_target(), Vector2.INF)
	assert_eq(dummy.get_counter_text(), "99+")
	_advance(dummy, dummy.up_s + dummy.move_s + DT)
	assert_eq(dummy.get_move(), BossDummy.MOVE_DOWN)
	assert_true(dummy.is_window_open())
	assert_true(dummy.get_core().is_enabled())
	assert_almost_eq(dummy.get_body_center(), dummy.get_down_center(), Vector2.ONE * 0.5)
	assert_almost_eq(dummy.get_core_target().y, 576.0 + 20.0, 0.5, "Nucleo a la altura del pecho de Isak")
	# Sin Debug: chispa y nada.
	dummy.get_core().on_laser_hit(1.0, null)
	assert_eq(dummy.get_counter_text(), "99+")
	_debug_on()
	dummy.get_core().on_laser_hit(1.0, null)
	assert_eq(dummy.get_counter_text(), "88")
	dummy.get_core().on_laser_hit(1.0, null)
	dummy.get_core().on_laser_hit(1.0, null)
	assert_eq(dummy.get_counter_text(), "66")
	assert_eq(dummy.get_phase(), 2)
	assert_eq(dummy.get_move(), BossDummy.MOVE_UP, "Al cambiar de fase vuelve arriba")
	assert_false(dummy.get_core().is_enabled())


func test_dummy_window_times_out_and_ascends() -> void:
	var dummy: BossDummy = _dummy()
	await wait_process_frames(1)
	dummy.start()
	_advance(dummy, dummy.up_s + dummy.move_s + DT)
	_advance(dummy, dummy.window_s + DT)
	assert_eq(dummy.get_move(), BossDummy.MOVE_ASCEND)
	_advance(dummy, dummy.move_s + DT)
	assert_eq(dummy.get_move(), BossDummy.MOVE_UP)
	assert_almost_eq(dummy.get_body_center(), dummy.get_up_center(), Vector2.ONE * 0.5)


func test_dummy_final_blow_and_respawn() -> void:
	var dummy: BossDummy = _dummy()
	await wait_process_frames(1)
	dummy.start()
	_debug_on()
	for phase: int in 3:
		_advance(dummy, dummy.up_s + dummy.move_s + DT)
		for i: int in 3:
			dummy.get_core().on_laser_hit(1.0, null)
	assert_true(dummy.is_defeated())
	assert_eq(dummy.get_move(), BossDummy.MOVE_GONE)
	assert_eq(dummy.get_counter_label(), "0")


func test_boss_test_room_is_generated() -> void:
	var packed: PackedScene = load("res://scenes/levels/boss_test.tscn")
	assert_not_null(packed, "scenes/levels/boss_test.tscn")
	var level: Node = packed.instantiate()
	add_child_autofree(level)
	await wait_process_frames(2)
	var dummy := level.find_child("saco", true, false) as BossDummy
	assert_not_null(dummy, "El saco esta en la sala")
	assert_eq(dummy.boss_id, &"boss_dummy")
	assert_eq(dummy.get_down_center(), Vector2(10.0 * 64.0, 9.0 * 64.0), "Columnas 9-10, de pie en la fila 9")
	assert_true(dummy.is_fighting(), "Empieza solo")
	var charger := level.find_child("cargador_saco", true, false)
	assert_almost_eq(float(charger.get(&"cooldown_s")), 4.0, 0.001, "Cargador de 4 s")
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=boss_test"])), "boss_test")
