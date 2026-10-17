# Recordatorio y boton Posponer (paso 6 de docs/propuesta-1-2.md §10,
# 2026-10-16) en la sala de prueba data/levels/recordatorios_test.json (escena
# generada scenes/levels/recordatorios_test.tscn) con el Isak real: pisar un
# recordatorio arranca la cuenta de su grupo, aviso de 6 cuadros, caida (sin
# dano; Isak cae al foso), reposicion (espera si Isak ocupa su sitio), tiempo
# del mundo (Debug x0,5, la pausa lo para), estado inicial al reaparecer; el
# laser al Posponer alarga la cuenta de sus grupos (tope y enfriamiento), sin
# efecto si no cuentan o ya han caido; y la combinacion de la sala: pisar,
# disparar desde el segundo recordatorio y cruzar sin caer.
# Los objetos se avanzan a mano junto a Isak (paso a paso).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/recordatorios_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _objects: Array[Node] = []
var _saved_pause: bool


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	_objects.clear()
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is ReminderPlatform or node is SnoozeButton:
			node.set_physics_process(false)
			_objects.append(node)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	get_tree().paused = false
	GameState.world_time_scale = 1.0
	EcoTextBox.pause_important = _saved_pause
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _obj(id: String) -> Node:
	return _level.get_node_or_null(NodePath("Objects/" + id))


func _r(id: String) -> ReminderPlatform:
	return _obj(id) as ReminderPlatform


func _step(count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for node: Node in _objects:
			node.call(&"advance", WorldTime.scaled_delta(DT))


func _stand(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()
	await wait_physics_frames(2)


func _fire() -> LaserProjectile:
	await wait_physics_frames(1)
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_step()
	for i: int in 40:
		if not fired.is_empty():
			break
		_step()
	_isak.laser_fired.disconnect(on_fired)
	if fired.is_empty():
		return null
	var p: LaserProjectile = fired[0]
	p.auto_process = false
	for i: int in 120:
		if p.is_finished():
			break
		p.step(DT)
	return p


func test_scene_has_the_reminders_and_the_snooze_button() -> void:
	assert_eq(_level.level_id, "recordatorios_test")
	var a := _r("posponer_a")
	assert_not_null(a)
	assert_eq(a.group_id, &"posponer_1")
	assert_eq(a.timer_s, 2.0, "params.timer_s del nivel")
	assert_eq(a.get_group_members().size(), 3, "Tres recordatorios en el grupo")
	assert_eq(_r("suelto_a").get_group_members().size(), 1, "Un recordatorio suelto, solo")
	var snooze := _obj("snooze_1") as SnoozeButton
	assert_not_null(snooze)
	assert_eq(snooze.get_targets().size(), 3, "Enlazado al grupo posponer_1")
	assert_eq(snooze.extend_s, 4.0)
	assert_eq(snooze.cap_s, 8.0)
	assert_true(snooze.is_in_group(LaserProjectile.GROUP_LASER_ACTIVATABLE))
	assert_eq(HelpCatalog.help_id_of(a), &"reminder_platform")
	assert_eq(HelpCatalog.help_id_of(snooze), &"snooze_button")
	assert_true(a.is_solid())
	assert_eq(a.get_lit_segments(), ReminderPlatform.SEG_COUNT, "En reposo, el indicador lleno")


func test_stepping_on_one_starts_the_whole_group() -> void:
	await _stand(13, 7)
	_step(2)
	for id: String in ["posponer_a", "posponer_b", "posponer_c"]:
		assert_true(_r(id).is_counting(), "%s cuenta" % id)
		assert_almost_eq(_r(id).get_time_left(), _r("posponer_a").get_time_left(), 0.0001, "Cuenta compartida")
	assert_false(_r("suelto_a").is_counting(), "Otro grupo no")
	assert_eq(_r("posponer_c").get_lit_segments(), ReminderPlatform.SEG_COUNT)
	_step(roundi(1.0 / DT))
	assert_lt(_r("posponer_c").get_lit_segments(), ReminderPlatform.SEG_COUNT, "El indicador baja")


func test_warning_fall_without_damage_and_respawn() -> void:
	var a := _r("suelto_a")
	var warned: Array = []
	a.warning_started.connect(func() -> void: warned.append(true))
	await _stand(4, 7)
	_step(2)
	assert_true(a.is_counting())
	# Aviso: los ultimos warn_s (6 cuadros a 12 fps).
	assert_almost_eq(a.warn_s * 12.0, 6.0, 0.001, "Aviso de 6 cuadros")
	while a.get_time_left() > a.warn_s + 0.02:
		_step()
	assert_false(a.is_warning())
	_step(3)
	assert_true(a.is_warning(), "Avisa antes de caer")
	assert_eq(warned.size(), 1)
	var y0: float = _isak.global_position.y
	_step(roundi(a.warn_s / DT) + 2)
	assert_eq(a.get_state(), ReminderPlatform.State.FALLING, "Ha vencido: cae")
	assert_false(a.is_solid())
	assert_eq(a.get_fall_count(), 1)
	_step(roundi(1.0 / DT))
	assert_gt(_isak.global_position.y, y0 + TILE * 2.0, "Isak cae al foso")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sin dano")
	assert_false(_isak.is_dead())
	assert_false(HelpCatalog.is_help_live(a), "Caido no ayuda")
	# Vuelve a los respawn_s.
	_step(roundi(a.respawn_s / DT) + 30)
	assert_eq(a.get_state(), ReminderPlatform.State.IDLE, "Repuesto")
	assert_true(a.is_solid())
	assert_true(HelpCatalog.is_help_live(a))


func test_does_not_come_back_inside_isak() -> void:
	var a := _r("suelto_a")
	a.start_countdown()
	a.expire()
	a.advance(1.0)
	assert_eq(a.get_state(), ReminderPlatform.State.GONE)
	# Isak justo donde vuelve (saltando en el foso, por ejemplo).
	_isak.global_position = a.get_card_rect().get_center() + Vector2(0.0, 40.0)
	a.advance(a.respawn_s + 1.0)
	assert_eq(a.get_state(), ReminderPlatform.State.GONE, "Espera a que Isak se aparte")
	_isak.global_position = Vector2(2.5 * TILE, 8.0 * TILE)
	a.advance(DT)
	assert_eq(a.get_state(), ReminderPlatform.State.RESPAWNING)


func test_world_time_debug_and_pause() -> void:
	var a := _r("suelto_b")
	a.start_countdown()
	GameState.world_time_scale = 0.5
	for i: int in 60:
		a._physics_process(DT)
	assert_almost_eq(a.get_time_left(), a.timer_s - 0.5, 0.01, "Con el Debug, 1 s real = 0,5 s de cuenta")
	GameState.world_time_scale = 1.0
	var left: float = a.get_time_left()
	a.set_physics_process(true)
	get_tree().paused = true
	await wait_physics_frames(10)
	assert_almost_eq(a.get_time_left(), left, 0.0001, "En pausa no cuenta")
	get_tree().paused = false
	a.set_physics_process(false)


func test_respawn_of_isak_resets_reminders_and_snooze() -> void:
	var a := _r("posponer_a")
	var snooze := _obj("snooze_1") as SnoozeButton
	a.trigger()
	snooze.snooze()
	assert_true(snooze.is_cooling_down())
	_r("suelto_a").start_countdown()
	_r("suelto_a").expire()
	EventBus.player_respawned.emit(Vector2(2.5 * TILE, 8.0 * TILE), true)
	for id: String in ["posponer_a", "posponer_b", "posponer_c", "suelto_a"]:
		assert_eq(_r(id).get_state(), ReminderPlatform.State.IDLE, "%s vuelve al principio" % id)
		assert_true(_r(id).is_solid())
	assert_false(snooze.is_cooling_down(), "El Posponer vuelve a estar listo")


func test_laser_snoozes_with_cap_and_cooldown() -> void:
	var snooze := _obj("snooze_1") as SnoozeButton
	var b := _r("posponer_b")
	await _stand(16, 7)
	_step(2)
	assert_true(b.is_counting(), "Pisarlo arranca la cuenta")
	assert_eq(snooze.get_animation(), &"snooze_ready", "Diana encendida: hay algo que posponer")
	var before: float = b.get_time_left()
	var p: LaserProjectile = await _fire()
	assert_not_null(p)
	assert_eq(p.get_hit_target(), snooze, "El laser alcanza el boton desde el segundo recordatorio")
	assert_eq(snooze.get_snooze_count(), 1)
	assert_gt(b.get_time_left(), before + 3.0, "+4 s")
	assert_true(snooze.is_cooling_down(), "Se enfria")
	for id: String in ["posponer_a", "posponer_c"]:
		assert_almost_eq(_r(id).get_time_left(), b.get_time_left(), 0.0001, "Todo el grupo")
	# Enfriandose: otro impacto no hace nada (chispa gris).
	var left: float = b.get_time_left()
	snooze.on_laser_hit(1.0, null)
	assert_almost_eq(b.get_time_left(), left, 0.0001, "Enfriandose no pospone")
	assert_true(snooze.is_sparking())
	# Tras el enfriamiento, el tope.
	for i: int in roundi(snooze.cooldown_s / DT) + 2:
		snooze.advance(DT)
	assert_false(snooze.is_cooling_down())
	snooze.on_laser_hit(1.0, null)
	assert_almost_eq(b.get_time_left(), snooze.cap_s, 0.0001, "Tope de 8 s")


func test_snooze_does_nothing_without_a_countdown_or_after_the_fall() -> void:
	var snooze := _obj("snooze_1") as SnoozeButton
	var none: Array = []
	snooze.nothing_to_snooze.connect(func() -> void: none.append(true))
	assert_eq(snooze.get_animation(), &"snooze_wait", "Apagado: nada que posponer")
	assert_false(snooze.snooze(), "Sin cuenta, nada que posponer")
	assert_true(snooze.is_sparking(), "Chispa gris")
	assert_false(snooze.is_cooling_down(), "Sin enfriamiento")
	var a := _r("posponer_a")
	a.trigger()
	for id: String in ["posponer_a", "posponer_b", "posponer_c"]:
		_r(id).expire()
	assert_false(snooze.snooze(), "Ya caidos: sin efecto")
	assert_eq(a.get_state(), ReminderPlatform.State.FALLING)
	assert_eq(none.size(), 2)


func test_pulse_does_not_snooze() -> void:
	var snooze := _obj("snooze_1") as SnoozeButton
	_r("posponer_a").trigger()
	await _stand(27, 7)
	_sim.input.pulse_pressed = true
	_step(30)
	assert_eq(snooze.get_snooze_count(), 0, "El pulso no le hace nada")


## La combinacion de la sala: sin Posponer no da tiempo; con el, se cruza.
func test_crossing_needs_the_snooze() -> void:
	assert_false(await _cross(false), "Caminando sin posponer, el grupo cae antes de llegar")
	EventBus.player_respawned.emit(Vector2(2.5 * TILE, 8.0 * TILE), false)
	assert_true(await _cross(true), "Pisar, disparar desde el segundo y cruzar")


## Cruza el grupo posponer_1 hacia la derecha saltando sus huecos. Verdadero si
## llega a la repisa de la columna 23 sin caer al foso.
func _cross(with_snooze: bool) -> bool:
	await _stand(12, 7)
	var gaps: Array[int] = [15, 18, 21]
	var shot: bool = not with_snooze
	for i: int in roundi(8.0 / DT):
		var col: int = floori(_isak.global_position.x / TILE)
		if not shot and col == 16 and _isak.global_position.x > 16.5 * TILE and _isak.is_on_floor():
			_sim.input.move_axis = 0.0
			_isak.facing = 1.0
			var p: LaserProjectile = await _fire()
			shot = true
			if p == null or p.get_hit_target() != _obj("snooze_1"):
				return false
		_sim.input.move_axis = 1.0
		var ahead: int = floori((_isak.global_position.x + 40.0) / TILE)
		if _isak.is_on_floor() and gaps.has(ahead):
			_sim.press_jump()
			for node: Node in _objects:
				node.call(&"advance", DT)
		else:
			_step()
		if _isak.global_position.y > 9.0 * TILE:
			_sim.input.move_axis = 0.0
			return false
		if _isak.global_position.x > 23.5 * TILE and _isak.is_on_floor():
			_sim.input.move_axis = 0.0
			return true
	_sim.input.move_axis = 0.0
	return false
