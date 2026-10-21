# WeakPoint con LA MARCA (2026-10-21, docs/propuesta-jefe-alerta-mayor.md §2.3;
# antes, paso 3: dano solo con el Debug activo). El Debug revela el nucleo; un
# pulso con el Debug ACTIVO lo marca mark_duration_s s del MUNDO; mientras dura,
# el laser dana sin Debug (1; 2 con el Laser 4) y el pulso solo refresca la marca
# con el Debug. Sin marca, el laser no dana: oculto, chispa gris en el borde del
# cuerpo (no delata el nucleo); expuesto, chispa en el nucleo. El dash nunca dana.
# La marca caduca en tiempo del mundo (a medio ritmo con el Debug), se pierde al
# desactivarse el nucleo, al cambiar de fase y al reaparecer. Con el Isak real
# (IsakSim): pulso, laser, Laser 4 y dash. Con el jefe «saco» (BossDummy): baja,
# se marca y se golpea; duracion por acceso (Caché / Kernel / Raíz). Sala
# boss_test generada con el Debug a un cuarto.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const WEAK_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/bosses/boss_dummy.tscn")
const DT: float = 1.0 / 60.0
const MAX_STEPS: int = 240
const EPS: float = 0.001

var _config: DebugModeConfig = DebugModeConfig.shared()
var _saved: Dictionary = {}
var _hits: Array = []
var _deflects: Array = []
var _marks: Array = []
var _expired: int = 0
var _warnings: int = 0


func before_each() -> void:
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, true)
	_saved["energy"] = GameState.debug_energy
	_saved["lap"] = GameState.lap
	_saved["upgrades"] = GameState.upgrade_levels.duplicate()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.sync_rate = GameState.get_sync_rate_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_hits.clear()
	_deflects.clear()
	_marks.clear()
	_expired = 0
	_warnings = 0


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.debug_energy = _saved["energy"]
	GameState.lap = _saved["lap"]
	GameState.upgrade_levels = _saved["upgrades"]
	GameState.sync_rate = GameState.SYNC_RATE_MAX


## Debug activo (tras la carga de 1 s) y, con `full`, a plena intensidad (mundo x0,5).
func _debug_on(full: bool = false) -> void:
	if not DebugMode.is_active():
		for i: int in roundi(_config.activation_hold_s / DT):
			DebugMode.step(DT, true)
		DebugMode.step(DT, false)
	if full:
		for i: int in ceili(_config.fade_in_s / DT) + 1:
			DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


func _debug_off() -> void:
	DebugMode.reset()
	assert_false(DebugMode.is_active())


func _weak(pos: Vector2 = Vector2(200.0, -50.0), auto: bool = false) -> WeakPoint:
	var wp := WEAK_SCENE.instantiate() as WeakPoint
	wp.position = pos
	wp.auto_process = auto
	add_child_autofree(wp)
	wp.hit.connect(func(d: int, s: Node) -> void: _hits.append([d, s]))
	wp.deflected.connect(func(s: Node) -> void: _deflects.append(s))
	wp.marked.connect(func(d: float, r: bool) -> void: _marks.append([d, r]))
	wp.mark_expired.connect(func() -> void: _expired += 1)
	wp.mark_warning.connect(func() -> void: _warnings += 1)
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


## Marca el nucleo con el Debug (pulso falso encima) y apaga el Debug.
func _mark(wp: WeakPoint, keep_debug: bool = false) -> void:
	_debug_on()
	assert_true(wp.receive_pulse(_pulse_area(wp.global_position)), "El pulso lo alcanza")
	assert_true(wp.is_marked(), "Marcado")
	if not keep_debug:
		_debug_off()


# --- WeakPoint solo ---

func test_layer_group_and_defaults() -> void:
	var wp: WeakPoint = _weak()
	await wait_physics_frames(1)
	assert_true(wp.is_in_group(LaserProjectile.GROUP_LASER_ACTIVATABLE), "El laser lo ve")
	assert_true(wp.is_enabled())
	assert_almost_eq(wp.get_mark_duration(), 4.0, EPS, "Marca por defecto (data/weak_point.json)")
	assert_eq(wp.get_core_layer(), 0, "Oculto: el nucleo no es objetivo del laser")
	_debug_on()
	await wait_physics_frames(1)
	assert_eq(wp.get_core_layer(), LaserProjectile.LAYER_ENEMY, "Revelado: capa enemy")


func test_pulse_without_debug_does_not_mark() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	assert_false(wp.receive_pulse(_pulse_area(wp.position)), "Oculto y sin cuerpo: nada")
	assert_false(wp.is_marked())
	assert_eq(_marks.size() + _hits.size() + _deflects.size(), 0)


func test_debug_charging_does_not_mark() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	DebugMode.step(DT, true)
	assert_true(DebugMode.is_engaged() and not DebugMode.is_active(), "Cargando")
	wp.receive_pulse(_pulse_area(wp.position))
	assert_false(wp.is_marked(), "Solo el Debug ACTIVO permite marcar")


func test_debug_and_pulse_marks_without_damage() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	_debug_on()
	EventBus.pulse_fired.emit(_pulse_area(wp.position))
	assert_true(wp.is_marked(), "Debug + pulso: marcado")
	assert_eq(_marks, [[4.0, false]], "Senal marked con la duracion")
	assert_eq(_hits.size(), 0, "El pulso no quita contador")
	assert_almost_eq(wp.get_mark_time_left(), 4.0, EPS)


func test_pulse_reaches_by_circles() -> void:
	var wp: WeakPoint = _weak(Vector2(200.0, -50.0))
	await wait_process_frames(1)
	_debug_on()
	var far: Area2D = _pulse_area(Vector2(200.0 - 96.0 - 24.0 - 2.0, -50.0))
	var near: Area2D = _pulse_area(Vector2(200.0 - 96.0 - 24.0 + 2.0, -50.0))
	assert_false(wp.receive_pulse(far), "Fuera de alcance")
	assert_false(wp.is_marked())
	assert_true(wp.receive_pulse(near), "Toca el borde del nucleo")
	assert_true(wp.is_marked())


func test_laser_without_mark_does_no_damage() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	wp.on_laser_hit(1.0, null)
	assert_eq(_hits.size() + _deflects.size(), 0, "Oculto sin cuerpo: ni dano ni chispa")
	_debug_on()
	wp.on_laser_hit(1.0, null)
	assert_eq(_hits.size(), 0, "Revelado sin marca: sin dano")
	assert_eq(_deflects.size(), 1, "Chispa gris")
	assert_true(wp.is_spark_visible())
	assert_almost_eq(wp.get_spark_position(), wp.global_position, Vector2.ONE * 0.5, "En el nucleo (ya visible)")
	for i: int in 60:
		await wait_process_frames(1)
		if not wp.is_spark_visible():
			break
	assert_false(wp.is_spark_visible(), "La chispa se apaga sola")


func test_laser_with_mark_damages_without_debug() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	_mark(wp)
	assert_false(DebugMode.is_active(), "Debug apagado")
	await wait_physics_frames(1)
	assert_true(wp.is_revealed(), "Marcado se ve sin el Debug")
	assert_eq(wp.get_core_layer(), LaserProjectile.LAYER_ENEMY, "Marcado: objetivo del laser")
	wp.on_laser_hit(1.0, null)
	wp.on_laser_hit(2.0, null)
	wp.on_laser_hit(1.0, null)
	assert_eq(_hits.map(func(h: Array) -> int: return h[0]), [1, 2, 1],
		"Todos los disparos que quepan: 1, Laser 4 = 2, 1")
	assert_true(wp.is_marked(), "Los golpes no gastan la marca")
	assert_eq(_deflects.size(), 0)


func test_mark_expires_in_world_time() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	_mark(wp)
	wp.advance_mark(2.9)
	assert_true(wp.is_marked())
	assert_eq(_warnings, 0)
	wp.advance_mark(0.2)
	assert_eq(_warnings, 1, "Aviso al quedar 1 s")
	wp.advance_mark(0.89)
	assert_true(wp.is_marked(), "Quedan 0,01 s")
	wp.advance_mark(0.02)
	assert_false(wp.is_marked(), "Caducada")
	assert_eq(_expired, 1)
	wp.on_laser_hit(1.0, null)
	assert_eq(_hits.size(), 0, "Sin marca el laser ya no dana")
	await wait_process_frames(1)
	assert_false(wp.is_revealed(), "Vuelve a estar oculto")


func test_mark_counts_down_at_half_speed_with_debug() -> void:
	var wp: WeakPoint = _weak(Vector2(200.0, -50.0), true)
	await wait_physics_frames(1)
	_mark(wp, true)
	_debug_on(true)
	assert_almost_eq(GameState.world_time_scale, 0.5, EPS, "Mundo a la mitad")
	var before: float = wp.get_mark_time_left()
	await wait_physics_frames(60)
	var spent: float = before - wp.get_mark_time_left()
	assert_almost_eq(spent, 0.5, 0.05, "1 s real con el Debug = 0,5 s de marca")
	_debug_off()
	before = wp.get_mark_time_left()
	await wait_physics_frames(30)
	assert_almost_eq(before - wp.get_mark_time_left(), 0.5, 0.05, "Sin Debug, a ritmo normal")


func test_pulse_refreshes_mark_only_with_debug() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	_mark(wp)
	wp.advance_mark(2.0)
	wp.receive_pulse(_pulse_area(wp.position))
	assert_almost_eq(wp.get_mark_time_left(), 2.0, EPS, "Sin Debug el pulso no refresca")
	assert_eq(_deflects.size(), 1, "Chispa gris en el nucleo")
	_debug_on()
	wp.receive_pulse(_pulse_area(wp.position))
	assert_almost_eq(wp.get_mark_time_left(), 4.0, EPS, "Con el Debug la refresca entera")
	assert_eq(_marks, [[4.0, false], [4.0, true]], "Segunda marca = refresco")
	assert_eq(_hits.size(), 0)


func test_halo_counts_down_and_blinks() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	assert_eq(wp.get_mark_segments_lit(), 0)
	_mark(wp)
	assert_eq(wp.get_mark_segments_lit(), 8, "8 segmentos al marcar")
	wp.advance_mark(2.0)
	assert_eq(wp.get_mark_segments_lit(), 4, "Mitad")
	assert_false(wp.is_mark_blink_off(), "Sin parpadeo antes del ultimo segundo")
	wp.advance_mark(1.5)
	assert_eq(wp.get_mark_segments_lit(), 1)
	var states: Dictionary = {}
	for i: int in 12:
		states[wp.is_mark_blink_off()] = true
		wp.advance_mark(0.03)
	assert_eq(states.size(), 2, "Parpadea en el ultimo segundo")


func test_disabled_clears_mark_and_ignores_everything() -> void:
	var wp: WeakPoint = _weak()
	await wait_process_frames(1)
	_mark(wp)
	wp.set_enabled(false)
	assert_false(wp.is_marked(), "Desactivar pierde la marca")
	assert_eq(_expired, 0, "Sin mark_expired")
	_debug_on()
	wp.on_laser_hit(1.0, null)
	assert_false(wp.receive_pulse(_pulse_area(wp.position)))
	assert_eq(_hits.size() + _deflects.size(), 0)
	await wait_process_frames(1)
	assert_false(wp.is_revealed(), "Desactivado no se dibuja")


func test_hidden_core_sparks_on_body_edge_without_revealing() -> void:
	var wp: WeakPoint = _weak(Vector2(200.0, -50.0))
	# Cuerpo de 128 x 128 con el nucleo 20 px por debajo de su centro.
	wp.set_shell_rect(Rect2(Vector2(-64.0, -84.0), Vector2(128.0, 128.0)))
	await wait_physics_frames(1)
	assert_eq(wp.get_core_layer(), 0, "Oculto: el nucleo no es objetivo")
	assert_eq(wp.get_shell_layer(), LaserProjectile.LAYER_ENEMY, "El cuerpo para el laser")
	var shooter := Node2D.new()
	shooter.position = Vector2(-200.0, -60.0)
	add_child_autofree(shooter)
	wp.on_laser_hit(1.0, shooter)
	assert_eq(_hits.size(), 0)
	assert_eq(_deflects.size(), 1, "Chispa gris")
	assert_almost_eq(wp.get_spark_position(), Vector2(136.0, -60.0), Vector2.ONE * 0.5,
		"En el borde del cuerpo hacia quien dispara, a su altura")
	assert_gt(wp.get_spark_position().distance_to(wp.global_position), WeakPoint.radius_px() + 8.0,
		"Lejos del nucleo: no lo delata")
	# Pulso que toca el cuerpo pero no el nucleo: chispa en el borde, sin marca.
	assert_true(wp.receive_pulse(_pulse_area(Vector2(50.0, -50.0))))
	assert_eq(_deflects.size(), 2)
	assert_almost_eq(wp.get_spark_position(), Vector2(136.0, -50.0), Vector2.ONE * 0.5)
	assert_false(wp.is_marked())
	# Revelado: el cuerpo deja pasar el laser y el nucleo es el objetivo.
	_debug_on()
	await wait_physics_frames(1)
	assert_eq(wp.get_shell_layer(), 0)
	assert_eq(wp.get_core_layer(), LaserProjectile.LAYER_ENEMY)


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


func _cooldown(sim: IsakSim) -> void:
	sim.step(ceili(sim.isak.abilities.laser_cooldown_s / DT) + 30)


func _real_pulse(sim: IsakSim) -> void:
	sim.input.pulse_pressed = true
	sim.step()
	sim.step(sim.steps_for(0.6))


## Nucleo a `dx` px de la boca del laser, a su altura, con un cuerpo de 2 x 2 tiles.
func _real_core(sim: IsakSim, dx: float) -> WeakPoint:
	var origin: Vector2 = sim.isak.global_position + sim.isak.get_laser_origin()
	var wp: WeakPoint = _weak(Vector2(origin.x + dx, origin.y))
	wp.set_shell_rect(Rect2(Vector2(-64.0, -84.0), Vector2(128.0, 128.0)))
	return wp


func test_real_pulse_without_debug_does_not_mark() -> void:
	var sim: IsakSim = await _isak_world()
	var wp: WeakPoint = _real_core(sim, 80.0)
	await wait_physics_frames(1)
	_real_pulse(sim)
	assert_false(wp.is_marked(), "Pulso sin Debug: no marca")
	assert_eq(_hits.size(), 0)
	assert_eq(_deflects.size(), 1, "Chispa gris en el cuerpo")
	assert_gt(wp.get_spark_position().distance_to(wp.global_position), WeakPoint.radius_px(),
		"La chispa no sale en el nucleo")


func test_real_laser_without_mark_does_not_damage() -> void:
	var sim: IsakSim = await _isak_world()
	var wp: WeakPoint = _real_core(sim, 320.0)
	await wait_physics_frames(2)
	var p: LaserProjectile = _fire_laser(sim)
	assert_not_null(p)
	assert_eq(p.get_hit_target(), wp, "Oculto: el haz se para en el cuerpo")
	assert_lt(p.global_position.x, wp.global_position.x - 64.0 + 2.0, "En el borde del cuerpo, no en el nucleo")
	assert_eq(_hits.size(), 0, "Sin marca no cuenta")
	assert_eq(_deflects.size(), 1, "Chispa gris")
	_cooldown(sim)
	_debug_on()
	await wait_physics_frames(1)
	p = _fire_laser(sim)
	assert_eq(p.get_hit_target(), wp, "Revelado: el haz llega al nucleo")
	assert_gt(p.global_position.x, wp.global_position.x - WeakPoint.radius_px() - 2.0)
	assert_eq(_hits.size(), 0, "Revelado sin marca: tampoco cuenta")
	assert_eq(_deflects.size(), 2)


func test_real_debug_pulse_marks_and_laser_damages_without_debug() -> void:
	var sim: IsakSim = await _isak_world()
	var wp: WeakPoint = _real_core(sim, 80.0)
	await wait_physics_frames(1)
	_debug_on()
	await wait_physics_frames(1)
	_real_pulse(sim)
	assert_true(wp.is_marked(), "Debug + pulso del Isak real: marcado")
	assert_eq(_hits.size(), 0, "El pulso no dana")
	_debug_off()
	await wait_physics_frames(1)
	var p: LaserProjectile = _fire_laser(sim)
	assert_not_null(p)
	assert_eq(p.get_hit_target(), wp)
	assert_eq(_hits.map(func(h: Array) -> int: return h[0]), [1], "Laser con marca y sin Debug: 1 golpe")
	_cooldown(sim)
	p = _fire_laser(sim)
	assert_eq(_hits.size(), 2, "Otro disparo dentro de la marca")


func test_real_laser_4_counts_two() -> void:
	GameState.upgrade_levels[&"laser"] = 4
	var sim: IsakSim = await _isak_world()
	assert_almost_eq(sim.isak.abilities.laser_damage, 2.0, EPS, "Laser 4")
	var wp: WeakPoint = _real_core(sim, 320.0)
	await wait_physics_frames(1)
	_mark(wp)
	await wait_physics_frames(1)
	_fire_laser(sim)
	assert_eq(_hits.map(func(h: Array) -> int: return h[0]), [2], "Laser 4 con marca: 2 golpes")


func test_dash_never_damages_the_core() -> void:
	var sim: IsakSim = await _isak_world()
	var start: Vector2 = sim.isak.global_position
	# El nucleo, marcado (visible y objetivo), justo en la trayectoria del dash.
	var wp: WeakPoint = _weak(Vector2(start.x + 96.0, start.y - 48.0))
	await wait_physics_frames(1)
	_mark(wp)
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

func _dummy(lap: int = 1) -> BossDummy:
	var dummy := DUMMY_SCENE.instantiate() as BossDummy
	dummy.auto_process = false
	dummy.auto_start = false
	dummy.lap_override = lap
	dummy.position = Vector2(576.0, 576.0)
	add_child_autofree(dummy)
	dummy.get_core().auto_process = false
	return dummy


func _advance(dummy: BossDummy, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		dummy.advance(DT)
		dummy.get_core().advance_mark(DT)


func _down(dummy: BossDummy) -> void:
	_advance(dummy, dummy.up_s + dummy.move_s + DT)
	assert_eq(dummy.get_move(), BossDummy.MOVE_DOWN)


func test_dummy_goes_down_gets_marked_hit_and_goes_up() -> void:
	var dummy: BossDummy = _dummy()
	await wait_process_frames(1)
	dummy.start()
	assert_eq(dummy.get_move(), BossDummy.MOVE_UP)
	assert_false(dummy.get_core().is_enabled(), "Arriba: nucleo desactivado")
	assert_eq(dummy.get_core_target(), Vector2.INF)
	assert_eq(dummy.get_counter_text(), "99+")
	assert_true(dummy.get_core().has_shell(), "El cuerpo del saco es el del nucleo")
	_down(dummy)
	assert_true(dummy.is_window_open())
	assert_true(dummy.get_core().is_enabled())
	assert_almost_eq(dummy.get_body_center(), dummy.get_down_center(), Vector2.ONE * 0.5)
	assert_almost_eq(dummy.get_core_target().y, 576.0 + 20.0, 0.5, "Nucleo a la altura del pecho de Isak")
	assert_eq(dummy.get_core().get_shell_global_rect(),
		Rect2(dummy.get_down_center() - Vector2(64.0, 64.0), Vector2(128.0, 128.0)), "Cuerpo de 2 x 2 tiles")
	# Sin marca: chispa y nada (tambien con el Debug).
	dummy.get_core().on_laser_hit(1.0, null)
	assert_eq(dummy.get_counter_text(), "99+")
	_debug_on()
	dummy.get_core().on_laser_hit(1.0, null)
	assert_eq(dummy.get_counter_text(), "99+", "Revelado sin marca: nada")
	_mark(dummy.get_core())
	dummy.get_core().on_laser_hit(1.0, null)
	assert_eq(dummy.get_counter_text(), "88")
	dummy.get_core().on_laser_hit(1.0, null)
	dummy.get_core().on_laser_hit(1.0, null)
	assert_eq(dummy.get_counter_text(), "66")
	assert_eq(dummy.get_phase(), 2)
	assert_eq(dummy.get_move(), BossDummy.MOVE_UP, "Al cambiar de fase vuelve arriba")
	assert_false(dummy.get_core().is_enabled())
	assert_false(dummy.get_core().is_marked(), "El cambio de fase pierde la marca")


func test_dummy_window_close_loses_mark() -> void:
	var dummy: BossDummy = _dummy()
	await wait_process_frames(1)
	dummy.start()
	_down(dummy)
	_mark(dummy.get_core())
	_advance(dummy, dummy.window_s + DT)
	assert_eq(dummy.get_move(), BossDummy.MOVE_ASCEND)
	assert_false(dummy.get_core().is_marked(), "Al subir se pierde la marca")
	_advance(dummy, dummy.move_s + DT)
	assert_eq(dummy.get_move(), BossDummy.MOVE_UP)
	assert_almost_eq(dummy.get_body_center(), dummy.get_up_center(), Vector2.ONE * 0.5)


func test_dummy_respawn_clears_mark() -> void:
	var dummy: BossDummy = _dummy()
	await wait_process_frames(1)
	dummy.start()
	_down(dummy)
	_mark(dummy.get_core())
	dummy.get_core().on_laser_hit(1.0, null)
	assert_eq(dummy.get_counter_text(), "88")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_false(dummy.get_core().is_marked(), "Reaparecer limpia la marca")
	assert_eq(dummy.get_counter_text(), "99+", "Y la fase vuelve a empezar")


func test_mark_duration_per_access() -> void:
	var expected: Dictionary = {1: 4.0, 2: 3.0, 3: 2.5}
	for lap: int in expected:
		var dummy: BossDummy = _dummy(lap)
		await wait_process_frames(1)
		assert_almost_eq(dummy.get_mark_duration(), expected[lap], EPS, "Vuelta %d" % lap)
		assert_almost_eq(dummy.get_core().get_mark_duration(), expected[lap], EPS, "Nucleo, vuelta %d" % lap)
		dummy.start()
		_down(dummy)
		_mark(dummy.get_core())
		assert_almost_eq(dummy.get_core().get_mark_time_left(), expected[lap], EPS)
		dummy.get_core().advance_mark(expected[lap] - 0.05)
		assert_true(dummy.get_core().is_marked())
		dummy.get_core().advance_mark(0.1)
		assert_false(dummy.get_core().is_marked(), "Caduca a los %.1f s (vuelta %d)" % [expected[lap], lap])
		dummy.queue_free()


func test_dummy_final_blow() -> void:
	var dummy: BossDummy = _dummy()
	await wait_process_frames(1)
	dummy.start()
	for phase: int in 3:
		_down(dummy)
		_mark(dummy.get_core())
		for i: int in 3:
			dummy.get_core().on_laser_hit(1.0, null)
	assert_true(dummy.is_defeated())
	assert_eq(dummy.get_move(), BossDummy.MOVE_GONE)
	assert_eq(dummy.get_counter_label(), "0")
	assert_false(dummy.get_core().is_marked())


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
	assert_almost_eq(DebugMode.get_level_drain_scale(), 0.25, EPS, "Debug a un cuarto, como la arena")
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=boss_test"])), "boss_test")
