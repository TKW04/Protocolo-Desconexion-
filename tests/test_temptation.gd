# Tentacion del Mundo 5 (paso 2 de docs/propuesta-mundo-5.md §8; reglas de §3.3 y
# pruebas de §7.4): la Oferta (offer_sign) tira de Isak (TemptationField): quieto
# deriva a 60 px/s en el suelo y en el aire; alejarse x0,6 (andar 132 - 60) y acercarse
# x1,15; fuera de la zona nada; varias Ofertas suman con tope (90 px/s, x0,45) y las
# opuestas se restan; el dash y los combos la ignoran (y la pose de espaldas); el pulso
# la apaga 3 s; despierta el laser rebota y aturdida la derrota (vida 2, +15); el Sismo
# no alcanza a la colgada y el Filo no la derrota; vuelve despierta al reaparecer; la
# sala ofertas_test carga. Isak y las Ofertas avanzan paso a paso con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const OFFER_SCENE: PackedScene = preload("res://scenes/enemies/offer_sign.tscn")
const ROOM_SCENE: String = "res://scenes/levels/ofertas_test.tscn"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const ABILITIES: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_DASH,
	GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved: Dictionary = {}
var _offers: Array[OfferSign] = []


func before_each() -> void:
	_saved = {}
	for ability: StringName in ABILITIES:
		_saved[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_offers = []
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
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## Oferta con los pies en (x, 0) (suelo de IsakSim).
func _offer(x: float, mount: StringName = OfferSign.MOUNT_FLOOR) -> OfferSign:
	var offer := OFFER_SCENE.instantiate() as OfferSign
	offer.position = Vector2(x, 0.0)
	_world.add_child(offer)
	offer.set_physics_process(false)
	offer.mount = mount
	offer.target = _isak
	_offers.append(offer)
	return offer


## Avanza Isak y las Ofertas `count` pasos.
func _step(count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for offer: OfferSign in _offers:
			offer.step(DT)


func _fake_pulse(center: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	add_child_autofree(area)
	return area


func _stun(offer: OfferSign) -> void:
	assert_true(offer.receive_pulse(_fake_pulse(offer.get_body_rect().get_center(), 96.0)), "El pulso la alcanza")


## Velocidad horizontal estable con el eje `axis` (corriendo si `run`).
func _steady_speed(axis: float, run: bool = false) -> float:
	_sim.input.move_axis = axis
	_sim.input.run_held = run
	_step(_sim.frames(0.4))
	var v: float = _isak.velocity.x
	_sim.input.move_axis = 0.0
	_sim.input.run_held = false
	return v


func _count_pickups() -> int:
	var n: int = 0
	for child: Node in _world.get_children():
		if child is RechargePickup and not child.is_queued_for_deletion():
			n += 1
	return n


# --- Deriva y multiplicadores ---

func test_standing_still_drifts_toward_the_offer_at_60() -> void:
	_offer(3.0 * T)
	var x0: float = _isak.global_position.x
	_step(_sim.frames(1.0))
	assert_almost_eq(_isak.velocity.x, 60.0, 0.5, "Quieto deriva hacia la Oferta a 60 px/s")
	assert_gt(_isak.global_position.x, x0 + 40.0, "Se ha movido hacia ella")
	assert_eq(_sim.state(), PlayerState.IDLE, "Sigue en Idle (no anda)")
	assert_true(_isak.get_temptation().is_pulling())


func test_drift_also_pulls_in_the_air() -> void:
	var offer: OfferSign = _offer(-3.0 * T)
	# Zona de 5 tiles de alto para seguir dentro durante el salto.
	offer.height_tiles = 5.0
	_sim.press_jump()
	_step(8)
	assert_false(_isak.is_on_floor(), "En el aire")
	assert_almost_eq(_isak.velocity.x, -60.0, 0.5, "En el aire tambien deriva (hacia la izquierda)")


func test_walking_away_is_heavier_and_walking_toward_is_easier() -> void:
	_offer(4.5 * T)
	_isak.global_position.x = 4.0 * T
	# Alejarse andando: 220 x 0,6 = 132 contra 60 de deriva = 72 (siempre se sale).
	assert_almost_eq(_steady_speed(-1.0), -72.0, 0.5, "Andar alejandose: -132 + 60")
	_isak.global_position.x = 4.0 * T
	_isak.velocity = Vector2.ZERO
	assert_almost_eq(_steady_speed(-1.0, true), -156.0, 0.5, "Correr alejandose: -216 + 60")
	_isak.global_position.x = 0.0
	_isak.velocity = Vector2.ZERO
	assert_almost_eq(_steady_speed(1.0), 313.0, 0.5, "Andar hacia ella: 220 x 1,15 + 60")


func test_outside_the_zone_there_is_no_pull() -> void:
	var offer: OfferSign = _offer(6.0 * T)
	_step(_sim.frames(0.5))
	assert_almost_eq(_isak.velocity.x, 0.0, 0.01, "A 6 tiles (radio 5) no tira")
	assert_false(offer.is_pulling_isak())
	# Por encima de su altura (3 tiles centrada en el cartel), tampoco.
	assert_eq(offer.get_pull_weight(offer.get_body_rect().get_center() + Vector2(-2.0 * T, -2.0 * T)), 0.0)
	assert_eq(offer.get_pull_weight(offer.get_body_rect().get_center() + Vector2(-2.0 * T, 0.0)), 1.0)
	assert_eq(offer.get_pull_weight(offer.get_body_rect().get_center() + Vector2(2.0 * T, 0.0)), -1.0)


func test_isak_stops_on_the_offer_not_past_it() -> void:
	var offer: OfferSign = _offer(1.0 * T)
	_step(_sim.frames(4.0))
	assert_almost_eq(_isak.global_position.x, offer.global_position.x, 12.0, "Se queda encima de la Oferta")
	assert_almost_eq(absf(_isak.velocity.x), 0.0, 61.0)


func test_several_offers_add_up_with_a_cap() -> void:
	_offer(2.0 * T)
	_offer(3.0 * T)
	_step(_sim.frames(0.6))
	var field: TemptationField = _isak.get_temptation()
	assert_eq(field.sources, 2)
	assert_almost_eq(field.get_drift(), 90.0, 0.01, "Dos Ofertas: deriva con tope 90")
	assert_almost_eq(field.get_multiplier(-1.0), 0.45, 0.001, "Alejarse con tope x0,45")
	assert_almost_eq(field.get_multiplier(1.0), 1.225, 0.001, "Acercarse con el peso topado")
	assert_almost_eq(_isak.velocity.x, 90.0, 0.5)
	assert_almost_eq(_steady_speed(-1.0), -9.0, 0.5, "Andar alejandose de dos: -99 + 90 (aun se sale)")


func test_offers_on_both_sides_cancel_out() -> void:
	_offer(-3.0 * T)
	_offer(3.0 * T)
	_step(_sim.frames(0.6))
	assert_almost_eq(_isak.get_temptation().weight, 0.0, 0.001)
	assert_almost_eq(_isak.velocity.x, 0.0, 0.01, "Fuerzas opuestas se restan")


# --- Lo que la ignora ---

func test_dash_ignores_the_pull() -> void:
	_offer(3.0 * T)
	_step(_sim.frames(0.5))
	_sim.input.move_axis = -1.0
	_sim.input.dash_pressed = true
	_step()
	_sim.input.move_axis = 0.0
	assert_eq(_sim.state(), PlayerState.DASH)
	var expected: float = _isak.abilities.dash_distance_px / _isak.abilities.dash_duration_s
	_step(3)
	assert_eq(_sim.state(), PlayerState.DASH)
	assert_false(_isak.is_tempted(), "Durante el dash no tienta")
	assert_almost_eq(_isak.get_temptation().weight, 0.0, 0.001)
	assert_almost_eq(_isak.velocity.x, -expected, 0.5, "El dash va a su velocidad, sin deriva ni x0,6")


func test_combos_ignore_the_pull() -> void:
	_offer(3.0 * T)
	_sim.press_jump()
	_step(10)
	_sim.input.move_axis = -1.0
	_sim.input.dash_pressed = true
	_step()
	_sim.input.move_axis = 0.0
	assert_eq(_sim.state(), PlayerState.DASH, "Dash aereo")
	_sim.input.hold_held = true
	_step(_sim.frames(0.2))
	assert_eq(_sim.state(), PlayerState.COMBO_RAM, "Embestida")
	var vx: float = _isak.velocity.x
	_step(2)
	assert_false(_isak.is_tempted(), "Durante el combo no tienta")
	assert_almost_eq(_isak.get_temptation().weight, 0.0, 0.001)
	assert_almost_eq(_isak.velocity.x, vx, 0.01, "La Embestida no cambia por el tiron")
	assert_lt(_isak.velocity.x, -600.0, "Sigue en diagonal hacia donde iba, contra el tiron")
	_sim.input.hold_held = false


func test_facing_back_is_not_pulled() -> void:
	_offer(3.0 * T)
	assert_true(_isak.face_back())
	var x0: float = _isak.global_position.x
	_step(_sim.frames(0.5))
	assert_almost_eq(_isak.global_position.x, x0, 0.5, "De espaldas (pagando en una tienda) no deriva")
	_isak.face_side()


# --- Pulso, laser y ondas ---

func test_pulse_turns_the_pull_off_for_3_seconds() -> void:
	var offer: OfferSign = _offer(1.5 * T)
	_stun(offer)
	assert_true(offer.is_stunned())
	assert_almost_eq(offer.get_stun_left(), 3.0, 0.001)
	var x0: float = _isak.global_position.x
	_step(_sim.frames(2.9))
	assert_almost_eq(_isak.global_position.x, x0, 0.5, "Aturdida no tira")
	assert_eq(offer.get_pull_weight(LevelLookup.isak_body_rect(_isak).get_center()), 0.0)
	_step(_sim.frames(0.2))
	assert_true(offer.is_awake(), "A los 3 s despierta")
	_step(_sim.frames(0.5))
	assert_gt(_isak.global_position.x, x0 + 5.0, "Y vuelve a tirar")


func test_laser_bounces_while_awake_and_defeats_it_stunned() -> void:
	var offer: OfferSign = _offer(4.0 * T)
	watch_signals(offer)
	offer.on_laser_hit(1.0, _isak)
	assert_signal_emitted(offer, "deflected", "Despierta: chispa gris")
	assert_eq(offer.get_health(), 2.0, "Sin dano")
	_stun(offer)
	offer.on_laser_hit(1.0, _isak)
	assert_eq(offer.get_health(), 1.0)
	assert_false(offer.is_defeated())
	offer.on_laser_hit(1.0, _isak)
	assert_true(offer.is_defeated(), "Vida 2: dos disparos aturdida")
	assert_signal_emitted(offer, "defeated")
	assert_eq(_count_pickups(), 1, "Suelta su recarga (+15 de energia)")
	assert_eq(offer.drops.get("debug_energy"), 15.0)
	_step(_sim.frames(0.5))
	assert_almost_eq(_isak.velocity.x, 0.0, 0.01, "Derrotada no tira")
	offer.reset_patrol()
	assert_true(offer.is_defeated(), "La derrotada no vuelve al reaparecer")


func test_reset_on_respawn_wakes_it_up() -> void:
	var offer: OfferSign = _offer(4.0 * T)
	_stun(offer)
	offer.reset_patrol()
	assert_true(offer.is_awake(), "Al reaparecer Isak vuelve despierta")


func test_quake_skips_wall_offers_and_edge_does_not_defeat_it() -> void:
	var standing: OfferSign = _offer(4.0 * T)
	var hanging: OfferSign = _offer(8.0 * T, OfferSign.MOUNT_WALL)
	var wide := Rect2(-2000.0, -200.0, 4000.0, 400.0)
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_QUAKE, wide, 0.0, 3.0)
	assert_true(standing.is_stunned(), "El Sismo aturde a la de pie")
	assert_true(hanging.is_awake(), "El Sismo no alcanza a la colgada")
	standing.reset_patrol()
	ComboWave.defeat_small(get_tree(), wide, 1.0, {})
	assert_false(standing.is_defeated(), "El Filo no derrota (vida 2 > 1)")
	assert_eq(standing.get_health(), 2.0)
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_RAM, wide, 2.0, 3.0)
	assert_true(standing.is_defeated(), "La Embestida (dano 2) si")


# --- Sala de prueba ---

func test_ofertas_test_room_loads() -> void:
	var scene := load(ROOM_SCENE) as PackedScene
	assert_not_null(scene, "Existe la escena de la sala")
	var room: Node = scene.instantiate()
	add_child_autofree(room)
	await wait_physics_frames(1)
	var offers: Array[OfferSign] = []
	for node: Node in get_tree().get_nodes_in_group(TemptationField.GROUP):
		if room.is_ancestor_of(node):
			offers.append(node as OfferSign)
	assert_eq(offers.size(), 3, "Tres Ofertas")
	var mounts: Array = offers.map(func(o: OfferSign) -> StringName: return o.mount)
	assert_true(mounts.has(OfferSign.MOUNT_WALL), "Una colgada (params.mount)")
	# Se quita antes de after_each: GeneratedLevel restaura al salir las habilidades que habia al entrar
	# (las de before_each); con el autofree salia despues y las dejaba desbloqueadas para la suite.
	room.free()
