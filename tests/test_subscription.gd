# Suscripcion del Mundo 5 (paso 4 de docs/propuesta-mundo-5.md §8; reglas de §3.1, §3.5
# y pruebas de §7.4): dormida hasta 5 tiles, aviso de 9 cuadros, persigue a 90 px/s y
# se engancha sin dano; drena 1 punto cada 2 s al registro de Devoluciones con tope 5 y
# despues se suelta saciada; con saldo 0, «Pago rechazado» y se suelta a los 3 s; el
# pulso y el golpe al suelo la cancelan (aturdida 3 s en el suelo); aturdida, el laser
# la derrota (+5) y despierta rebota; el Filo la derrota (no enganchada); el Sismo no
# alcanza a la que vuela; nunca dana; reaparicion; y las trampas subscription y offer
# del atajo. Usa su propia ruta de guardado.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const SUB_SCENE: PackedScene = preload("res://scenes/enemies/subscription.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/levels/shortcut_door.tscn")
const PATH: String = "user://test_subscription.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const LEVEL: StringName = &"5-1"

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _subs: Array[Subscription] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.begin_attempt()
	GameState.current_level = LEVEL
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = 20.0
	GameState.attention_points = 10
	DebugMode.input_enabled = false
	DebugMode.reset()
	_subs = []
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
	GameState.current_level = GameState.NO_LEVEL
	GameState.begin_attempt()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## Suscripcion con los pies en (x, y) (el suelo de IsakSim esta en y = 0).
func _sub(x: float, y: float = -T) -> Subscription:
	var sub := SUB_SCENE.instantiate() as Subscription
	sub.position = Vector2(x, y)
	_world.add_child(sub)
	sub.set_physics_process(false)
	sub.target = _isak
	_subs.append(sub)
	return sub


func _step(count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for sub: Subscription in _subs:
			if is_instance_valid(sub):
				sub.step(DT)


## Engancha `sub` a Isak al momento (atajo para las pruebas del drenaje).
func _attached(points: int = 10) -> Subscription:
	GameState.attention_points = points
	var sub: Subscription = _sub(0.0)
	sub.attach_to(_isak)
	return sub


func _isak_pulse(radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = Vector2(0.0, -56.0)
	_isak.add_child(area)
	return area


func _fake_pulse(center: Vector2, radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	add_child_autofree(area)
	return area


func _count_pickups() -> int:
	var n: int = 0
	for child: Node in _world.get_children():
		if child is RechargePickup and not child.is_queued_for_deletion():
			n += 1
	return n


# --- Persecucion ---

func test_sleeps_far_away_and_wakes_within_5_tiles_with_a_9_frame_warning() -> void:
	var sub: Subscription = _sub(8.0 * T)
	_step(30)
	assert_eq(sub.get_state(), Subscription.STATE_IDLE, "A 8 tiles duerme")
	assert_almost_eq(sub.global_position.x, 8.0 * T, 0.01)
	sub.global_position = Vector2(4.5 * T, -T)
	_step()
	assert_eq(sub.get_state(), Subscription.STATE_ALERT, "A 4,5 tiles se ilumina")
	assert_eq(sub.get_message(), "¡Bienvenido!")
	assert_almost_eq(sub.get_alert_s(), 0.75, 0.001, "9 cuadros a 12 fps")
	var x0: float = sub.global_position.x
	_step(_sim.frames(0.7))
	assert_eq(sub.get_state(), Subscription.STATE_ALERT, "Aun avisa")
	assert_almost_eq(sub.global_position.x, x0, 0.01, "Quieta mientras avisa")
	_step(_sim.frames(0.1))
	assert_eq(sub.get_state(), Subscription.STATE_CHASE, "Despues persigue")


func test_chases_at_90_px_s_and_attaches_without_damage() -> void:
	var sub: Subscription = _sub(4.0 * T, -40.0)
	watch_signals(sub)
	_step(_sim.frames(0.8))
	assert_true(sub.is_chasing())
	var p0: Vector2 = sub.get_center()
	_step(_sim.frames(1.0))
	assert_almost_eq(p0.distance_to(sub.get_center()), 90.0, 3.0, "Vuela a 90 px/s")
	var sync: float = GameState.sync_rate
	_step(_sim.frames(4.0))
	assert_true(sub.is_attached(), "Se engancha al tocarlo")
	assert_signal_emitted(sub, "attached")
	assert_eq(sub.get_host(), _isak)
	assert_eq(GameState.sync_rate, sync, "Sin dano")
	assert_false(sub.is_dangerous())
	_isak.global_position.x += 3.0 * T
	_step()
	assert_lt(absf(sub.global_position.x - _isak.global_position.x), 32.0, "Va en la espalda de Isak")


func test_gives_up_when_isak_goes_far_and_returns_home() -> void:
	var sub: Subscription = _sub(3.0 * T)
	_step(_sim.frames(1.6))
	assert_true(sub.is_chasing())
	assert_lt(sub.global_position.x, 3.0 * T - 40.0, "Se ha acercado")
	_isak.global_position = Vector2(-20.0 * T, 0.0)
	_step()
	assert_eq(sub.get_state(), Subscription.STATE_RETURN)
	_step(_sim.frames(3.0))
	assert_eq(sub.get_state(), Subscription.STATE_IDLE, "De vuelta a su sitio, dormida")
	assert_almost_eq(sub.global_position.x, 3.0 * T, 0.5)


# --- Drenaje ---

func test_drains_one_point_every_2_seconds_into_refunds_up_to_5() -> void:
	var sub: Subscription = _attached(10)
	watch_signals(sub)
	_step(_sim.frames(1.9))
	assert_eq(GameState.attention_points, 10, "Aun no")
	_step(_sim.frames(0.2))
	assert_eq(GameState.attention_points, 9, "1 punto a los 2 s")
	assert_true(GameState.has_unsaved_changes(), "Drenar marca «sin guardar»")
	_step(_sim.frames(8.0))
	assert_eq(GameState.attention_points, 5, "5 en 10 s")
	assert_eq(sub.get_drained(), 5)
	assert_true(sub.is_spent(), "Con el tope se suelta saciada")
	assert_false(sub.is_attached())
	_step(_sim.frames(6.0))
	assert_eq(GameState.attention_points, 5, "Tope 5 por Suscripcion")
	assert_eq(GameState.get_refundable(LEVEL, [GameState.REFUND_SUBSCRIPTION]), 5, "Al registro de Devoluciones")
	assert_signal_emit_count(sub, "drained", 5)
	_step(_sim.frames(2.0))
	assert_almost_eq(sub.get_body_rect().end.y, 0.0, 1.5, "Saciada cae al suelo")
	assert_false(sub.is_chasing(), "Y ya no persigue")


func test_with_zero_balance_payment_is_declined_and_it_lets_go_after_3_s() -> void:
	var sub: Subscription = _attached(0)
	assert_eq(sub.get_state(), Subscription.STATE_DECLINED, "Saldo 0: al momento")
	assert_eq(sub.get_message(), "Pago rechazado")
	_step(_sim.frames(2.9))
	assert_true(sub.is_attached(), "Sigue enganchada hasta los 3 s")
	assert_eq(GameState.attention_points, 0, "Sin deuda")
	_step(_sim.frames(0.2))
	assert_true(sub.is_stunned(), "Se suelta sola (aturdida)")
	assert_eq(GameState.attention_points, 0)


func test_balance_runs_out_while_draining() -> void:
	var sub: Subscription = _attached(1)
	_step(_sim.frames(2.1))
	assert_eq(GameState.attention_points, 0)
	_step(_sim.frames(2.0))
	assert_eq(sub.get_state(), Subscription.STATE_DECLINED, "El siguiente drenaje se rechaza")
	assert_eq(sub.get_drained(), 1)


# --- Cancelar ---

func test_pulse_cancels_it_and_leaves_it_stunned_on_the_floor() -> void:
	var sub: Subscription = _attached(10)
	watch_signals(sub)
	assert_true(sub.receive_pulse(_isak_pulse()), "Isak se la quita con el pulso")
	assert_signal_emitted(sub, "cancelled")
	assert_true(sub.is_stunned())
	assert_almost_eq(sub.get_stun_left(), 3.0, 0.001)
	_step(_sim.frames(1.5))
	assert_almost_eq(sub.get_body_rect().end.y, 0.0, 1.5, "Cae al suelo")
	assert_eq(GameState.attention_points, 10, "Cancelada no drena")
	_step(_sim.frames(1.6))
	assert_true(sub.is_chasing() or sub.is_attached(), "Al despertar vuelve a buscar a Isak")


func test_pulse_stuns_a_chasing_one_it_reaches() -> void:
	var sub: Subscription = _sub(3.0 * T)
	_step(_sim.frames(0.8))
	assert_false(sub.receive_pulse(_fake_pulse(Vector2(12.0 * T, -T))), "Lejos no")
	assert_true(sub.receive_pulse(_fake_pulse(sub.get_center())))
	assert_true(sub.is_stunned())


func test_ground_pound_cancels_it() -> void:
	var sub: Subscription = _attached(10)
	GroundPoundWave.apply_to_enemies(get_tree(), GroundPoundWave.rect_at(_isak.global_position, _isak.abilities), 1.0)
	assert_true(sub.is_stunned(), "La onda la suelta")
	assert_eq(sub.get_health(), 1.0, "Sin dano")
	var free: Subscription = _sub(4.0 * T, 0.0)
	GroundPoundWave.apply_to_enemies(get_tree(), Rect2(3.0 * T, -T, 2.0 * T, T + 8.0), 1.0)
	assert_true(free.is_stunned(), "Suelta y alcanzada: aturdida")


# --- Laser, Filo, Embestida y Sismo ---

func test_laser_bounces_awake_and_defeats_it_stunned() -> void:
	var sub: Subscription = _sub(3.0 * T)
	watch_signals(sub)
	sub.on_laser_hit(1.0, _isak)
	assert_signal_emitted(sub, "deflected", "Despierta: chispa gris")
	assert_false(sub.is_defeated())
	sub.stun()
	sub.on_laser_hit(1.0, _isak)
	assert_true(sub.is_defeated(), "Aturdida: vida 1")
	assert_signal_emitted(sub, "defeated")
	assert_eq(_count_pickups(), 1, "Suelta su recarga")
	assert_eq(sub.drops.get("debug_energy"), 5.0, "+5 de energia")
	sub.reset_patrol()
	assert_true(sub.is_defeated(), "La derrotada no vuelve")


## El laser real de Isak (a la altura del celular, 56 px sobre los pies) alcanza a la Suscripcion tumbada en el
## mismo suelo: aturdida, su zona de golpe sube down_hit_height_px desde los pies (bot del 5-1, paso 11: antes el rayo
## pasaba por encima del cuerpo de 28 px y el validador la daba por derrotada).
func test_real_laser_from_the_same_floor_defeats_it_stunned() -> void:
	var saved: bool = GameState.is_ability_unlocked(GameState.ABILITY_LASER)
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	var sub: Subscription = _sub(3.0 * T, 0.0)
	sub.stun()
	assert_true(sub.is_stunned())
	assert_gt(sub.down_hit_height_px, absf(_isak.get_laser_origin().y), "La zona en el suelo llega al celular")
	_isak.facing = 1.0
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_sim.step()
	_sim.input.laser_pressed = false
	for i: int in 40:
		if not fired.is_empty():
			break
		_sim.step()
	_isak.laser_fired.disconnect(on_fired)
	assert_eq(fired.size(), 1, "Sale el laser")
	if not fired.is_empty():
		var p: LaserProjectile = fired[0]
		p.auto_process = false
		for i: int in 120:
			if p.is_finished():
				break
			p.step(DT)
	assert_true(sub.is_defeated(), "El laser desde el mismo suelo la derrota aturdida")
	sub.reset_patrol()
	var awake: Subscription = _sub(5.0 * T, 0.0)
	assert_almost_eq(awake.get_body_rect().size.y, 28.0, 0.01, "Despierta, el cuerpo de siempre")
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, saved)


func test_edge_defeats_it_but_not_attached_and_quake_skips_flying_ones() -> void:
	var flying: Subscription = _sub(4.0 * T)
	var attached: Subscription = _attached(10)
	var wide := Rect2(-2000.0, -400.0, 4000.0, 500.0)
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_QUAKE, wide, 0.0, 3.0)
	assert_eq(flying.get_state(), Subscription.STATE_IDLE, "El Sismo no alcanza a la que vuela")
	assert_true(attached.is_stunned(), "A la enganchada la suelta")
	attached.reset_patrol()
	attached.attach_to(_isak)
	ComboWave.defeat_small(get_tree(), wide, 1.0, {})
	assert_true(flying.is_defeated(), "El Filo la derrota (vida 1)")
	assert_true(attached.is_attached(), "Enganchada, el Filo no (va en la espalda)")


func test_ram_cancels_attached_and_defeats_free_ones() -> void:
	var free: Subscription = _sub(4.0 * T)
	var attached: Subscription = _attached(10)
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_RAM, Rect2(-2000.0, -400.0, 4000.0, 500.0), 2.0, 3.0)
	assert_true(attached.is_stunned(), "Enganchada: la suelta")
	assert_true(free.is_defeated(), "Suelta: dano 2")


func test_reset_on_respawn_goes_home_asleep_and_keeps_what_it_drained() -> void:
	var sub: Subscription = _attached(10)
	_step(_sim.frames(4.1))
	assert_eq(sub.get_drained(), 2)
	sub.reset_patrol()
	assert_eq(sub.get_state(), Subscription.STATE_IDLE)
	assert_false(sub.is_attached())
	assert_eq(sub.get_drained(), 2, "Lo drenado cuenta para el tope")


# --- Trampas del atajo ---

func test_subscription_trap_releases_one_beyond_the_door() -> void:
	var door := DOOR_SCENE.instantiate() as ShortcutDoor
	door.object_id = &"atajo"
	door.trap = ShortcutDoor.TRAP_SUBSCRIPTION
	door.position = Vector2(6.0 * T, -3.0 * T)
	_world.add_child(door)
	door.set_process(false)
	door.open()
	_isak.global_position = Vector2(6.5 * T, 0.0)
	_isak.facing = 1.0
	_isak.velocity = Vector2.ZERO
	assert_true(door.spring_trap(_isak))
	var sub := door.get_trap_spawn() as Subscription
	assert_not_null(sub, "Te espera dentro")
	assert_almost_eq(sub.global_position.x, door.get_door_rect().get_center().x + 2.0 * T, 0.5, "2 tiles mas alla")
	assert_eq(sub.get_state(), Subscription.STATE_ALERT, "Avisa y persigue")


func test_offer_trap_places_an_offer_beyond_the_door() -> void:
	var door := DOOR_SCENE.instantiate() as ShortcutDoor
	door.object_id = &"atajo"
	door.trap = ShortcutDoor.TRAP_OFFER
	door.position = Vector2(6.0 * T, -3.0 * T)
	_world.add_child(door)
	door.set_process(false)
	door.open()
	_isak.global_position = Vector2(6.5 * T, 0.0)
	_isak.velocity = Vector2(-200.0, 0.0)
	assert_true(door.spring_trap(_isak))
	var offer := door.get_trap_spawn() as OfferSign
	assert_not_null(offer, "Una Oferta al salir")
	assert_almost_eq(offer.global_position.x, door.get_door_rect().get_center().x - 2.0 * T, 0.5,
		"Hacia donde cruza Isak")
	assert_almost_eq(offer.global_position.y, 0.0, 0.5, "De pie en el suelo")
	assert_false(door.spring_trap(_isak), "Solo una vez")
