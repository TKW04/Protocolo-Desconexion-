# El Vendedor en su arena «Gran almacén» (paso 16 de docs/propuesta-mundo-5.md §8,
# 2026-10-29; diseño en §5.2-§5.6): la arena 5-boss (cabe entera en pantalla,
# estantes de una via, la maquina solida del jefe, dos Ofertas de la fase 3, 4
# cargadores, Debug x0,25 / x0,7) y las fases 1-3 con el tiempo avanzado a mano
# (advance) y el Isak real de la arena con entrada falsa (IsakSim): fase 1, la
# plataforma que se paga con un pulso desde el estante (fichas y «te fio»), la
# trampa que se pliega, el techo de la maquina y el «Cancelar» a tiro desde el suelo
# por detras; fase 2, las tandas de cajas con su contenido fijo, la bomba (mecha,
# aturdida con el pulso) y el ticket que lo deja sin girarse con la bandeja abierta;
# fase 3, la cuenta, el tiron hacia la bandeja, «Procesando pago…» sin que nada
# ataque, el escaparate que solo rompe la Embestida y la ranura (sin el Filo, fuera).
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/5-boss.tscn")
const IsakSim = preload("res://tests/support/isak_sim.gd")
const PATH: String = "user://test_vendor_arena.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const COMBO_ABILITIES: Array[StringName] = [GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND,
	GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]

var _saved_path: String
var _saved_lap: int
var _saved: Dictionary = {}
var _level: GeneratedLevel
var _boss: Vendor
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
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG] + COMBO_ABILITIES:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG]:
		GameState.set_ability_unlocked(ability, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.sync_rate = GameState.get_sync_rate_max()


func after_each() -> void:
	# La arena se quita antes de restaurar: GeneratedLevel restaura al salir las habilidades que habia al entrar
	# (las de before_each); con el autofree salia despues y las dejaba desbloqueadas para la suite.
	if is_instance_valid(_level):
		_level.free()
	_level = null
	_boss = null
	_sim = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.lap = _saved_lap
	GameState.save_path = _saved_path
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.last_checkpoint.clear()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## La arena sin LevelRunner; el jefe sin intro ni proceso propio (advance a mano) y
## el Isak de la arena con entrada falsa.
func _arena(lap: int = 1) -> GeneratedLevel:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/vendor") as Vendor
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	_boss.lap_override = lap
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_isak())
	add_child_autofree(_level)
	_boss.get_core().auto_process = false
	_sim.take_manual_control()
	await wait_physics_frames(2)
	_sim.settle()
	return _level


## Avanza el jefe, la marca, las cajas e Isak `seconds` del mundo.
func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)
		for box: SurpriseBox in _boss.get_boxes():
			box.step(DT)
		_sim.step()


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


## Pasa a la fase `phase` con golpes directos. En la fase 3, sin el cartel que baja
## (offer.start_grace_s, paso 19) salvo `keep_grace`: la cuenta y la ranura ya en marcha.
func _to_phase(phase: int, keep_grace: bool = false) -> void:
	while _boss.get_phase() < phase:
		_boss.take_core_hit(1)
	if phase == 3 and not keep_grace:
		_skip_grace()


func _skip_grace() -> void:
	_advance_until(func() -> bool: return _boss.get_offer_grace_left() <= 0.0, 10.0)
	_boss._countdown_left = _boss.get_countdown_s()


func _isak() -> Isak:
	return _level.get_isak()


func _place_isak(col: int, row: int, facing: float = 1.0) -> void:
	var isak: Isak = _isak()
	isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	isak.velocity = Vector2.ZERO
	isak.facing = facing
	_sim.settle()


## Pulso real de Isak: devuelve su area (la del EventBus) o null.
func _real_pulse() -> Area2D:
	var got: Array = []
	var on_pulse := func(area: Area2D) -> void: got.append(area)
	EventBus.pulse_fired.connect(on_pulse)
	_sim.input.pulse_pressed = true
	for i: int in 30:
		_sim.step()
		if not got.is_empty():
			break
	EventBus.pulse_fired.disconnect(on_pulse)
	return got[0] if not got.is_empty() else null


func _box_with(content: StringName) -> SurpriseBox:
	for box: SurpriseBox in _boss.get_boxes():
		if box.content == content:
			return box
	return null


# --- Arena ---

func test_arena_fits_the_screen_with_its_pieces() -> void:
	await _arena()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/5-boss.json"))
	assert_eq(data["kind"], "boss")
	assert_eq(data["boss"], "vendor")
	assert_eq((data["grid"] as Array).size(), 11, "11 filas")
	assert_eq(String(data["grid"][0]).length(), 20, "20 columnas: 1280 x 704, cabe en pantalla")
	assert_almost_eq(float(data["debug_drain_scale"]), 0.25, EPS)
	assert_almost_eq(float(data["debug_world_scale"]), 0.7, EPS)
	assert_eq(String(data["grid"][8]).substr(2, 4), "----", "Estante izquierdo de una via (cols 2-5)")
	assert_eq(String(data["grid"][8]).substr(14, 4), "----", "Estante derecho (cols 14-17)")
	for row: int in range(5, 10):
		assert_eq(String(data["grid"][row]).substr(8, 4), "....", "La maquina es '.' en el grid (fila %d)" % row)
	var chargers: Array[int] = []
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is Charger:
			chargers.append(roundi((node as Charger).global_position.x / TILE - 0.5))
	assert_eq(chargers.size(), 4, "4 cargadores")
	assert_eq(_boss.get_machine_rect(), Rect2(8 * TILE, 5 * TILE, 4 * TILE, 5 * TILE), "Maquina: cols 8-11, filas 5-9")
	assert_lte(_boss.get_machine_rect().end.y, 10.0 * TILE, "Apoyada en el suelo")


func test_charger_cooldown_by_access() -> void:
	for lap: int in [1, 2, 3]:
		await _arena(lap)
		await wait_physics_frames(1)
		var charger := _level.get_node(^"Objects/cargador_1") as Charger
		assert_almost_eq(charger.cooldown_s, [4.0, 5.0, 6.0][lap - 1], EPS, "Cargadores, acceso %d" % lap)
		_level.queue_free()
		await wait_physics_frames(1)


func test_offers_only_in_phase_3() -> void:
	await _arena()
	_boss.start()
	var offer := _level.get_node(^"Enemies/oferta_izq") as OfferSign
	assert_false(BossBase.is_phase_node_active(offer), "Fase 1: sin Ofertas")
	_to_phase(3)
	assert_true(BossBase.is_phase_node_active(offer), "Fase 3: las Ofertas de los estantes")


# --- Fase 1: plataformas con precio ---

func test_phase1_pay_a_platform_from_the_shelf_and_stand_on_it() -> void:
	await _arena()
	_boss.start()
	_place_isak(4, 7, 1.0)
	assert_true(_isak().is_on_floor(), "De pie en el estante")
	assert_not_null(_real_pulse(), "Pulso")
	assert_true(_boss.is_platform_solid("a"), "La etiqueta de encima: pagada")
	assert_eq(_boss.get_tokens(), 10, "2 fichas")
	_place_isak(4, 5, 1.0)
	assert_true(_isak().is_on_floor(), "De pie en la plataforma de la fila 6")
	assert_almost_eq(_isak().global_position.y, 6.0 * TILE, 0.5)
	_advance(6.1)
	assert_false(_boss.is_platform_active("a"), "Dura life_s (6 s)")


func test_phase1_trap_folds_and_drops_into_the_tray() -> void:
	await _arena()
	_boss.start()
	assert_true(_boss.pay_platform("b"), "b: trampa en Caché")
	assert_true(_boss.is_trap("b"))
	var sync_before: float = GameState.sync_rate
	_place_isak(6, 5, 1.0)
	assert_true(_isak().is_on_floor(), "Sobre la trampa")
	_advance(0.2)
	assert_true(_boss.is_platform_solid("b"), "Aun no se pliega")
	_advance(0.15)
	assert_true(_boss.is_platform_folded("b"), "Se pliega 0,3 s despues de pisarla")
	_advance_until(func() -> bool: return GameState.sync_rate < sync_before, 2.0)
	assert_almost_eq(GameState.sync_rate, sync_before - 10.0, EPS, "-10 al caer")
	assert_lt(_isak().velocity.x, 0.0, "Empuje al frente, lejos de la maquina")


func test_phase1_debug_reveals_the_trap_label() -> void:
	await _arena()
	_boss.start()
	assert_true(_boss.is_trap("b") and _boss.is_trap("c"), "Una de cada par: b y c")
	assert_false(_boss.is_trap("a") or _boss.is_trap("d"))


func test_phase1_with_no_tokens_it_lends_and_a_subscription_drains_energy() -> void:
	await _arena()
	_boss.start()
	_boss.set_tokens(1)
	_place_isak(4, 7, 1.0)
	_real_pulse()
	assert_true(_boss.is_platform_solid("a"), "Te fio: la plataforma sale igual")
	assert_eq(_boss.get_tokens(), 1, "No cobra")
	var subs: Array[Subscription] = _boss.get_credit_subscriptions()
	assert_eq(subs.size(), 1, "Se engancha una Suscripcion")
	assert_true(subs[0].is_attached())
	var e0: float = GameState.debug_energy
	for i: int in 60:
		subs[0].step(DT)
	assert_almost_eq(GameState.debug_energy, e0 - 2.0, 0.1, "Drena 2 de energia por segundo")
	assert_true(subs[0].cancel(), "El pulso o el golpe al suelo la cancelan")
	await wait_physics_frames(1)
	assert_eq(_boss.get_credit_subscriptions().size(), 0, "Cancelada, fuera")


func test_phase1_from_the_platform_to_the_roof_and_behind_the_core_is_in_reach() -> void:
	await _arena()
	_boss.start()
	_boss.pay_platform("a")
	_place_isak(8, 4, 1.0)
	assert_true(_isak().is_on_floor(), "De pie en el techo de la maquina")
	assert_almost_eq(_isak().global_position.y, 5.0 * TILE, 0.5)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_NONE, "Sobre el techo no cuenta como detras")
	_debug_on()
	# Baja por detras y se pega a la maquina.
	_place_isak(12, 9, -1.0)
	_advance(DT)
	assert_true(_boss.is_isak_behind())
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_PENDING, "Empieza el giro de 1,2 s")
	_sim.input.move_axis = -1.0
	_sim.step(10)
	_sim.input.move_axis = 0.0
	var core: WeakPoint = _boss.get_core()
	var origin: Vector2 = _isak().global_position + (_isak().call(&"get_laser_origin") as Vector2)
	assert_lte(absf(origin.y - core.global_position.y), WeakPoint.radius_px(), "El laser a la altura del boton")
	assert_not_null(_real_pulse(), "Pulso")
	assert_true(core.is_marked(), "Desde el suelo por detras: marcado")
	DebugMode.reset()
	core.on_laser_hit(1.0, _isak())
	assert_eq(_boss.get_remaining_hits(), 8, "Un golpe")


func test_phase1_arm_sweep_and_coins_hurt_after_their_warning() -> void:
	await _arena()
	_boss.start()
	_place_isak(4, 7, 1.0)
	var s0: float = GameState.sync_rate
	_boss.start_attack(Vendor.ATTACK_ARM_SWEEP)
	assert_eq(_boss.get_sweep_side(), Vendor.SIDE_LEFT, "El estante de Isak primero")
	_advance(0.7)
	assert_almost_eq(GameState.sync_rate, s0, EPS, "Aviso de 9 cuadros: sin dano")
	_advance(0.2)
	assert_almost_eq(GameState.sync_rate, s0 - 10.0, EPS, "El brazo barre el estante")
	_advance(2.0)
	_place_isak(3, 9, 1.0)
	_advance_until(func() -> bool: return _boss.get_attack_state() == Vendor.ATTACK_GAP, 3.0)
	_boss.start_attack(Vendor.ATTACK_COINS)
	assert_true(_boss.get_coin_columns().has(3), "Una moneda en la columna de Isak")
	for col: int in _boss.get_coin_columns():
		assert_true(col < 8 or col > 11, "Ninguna sobre la maquina")
	var s1: float = GameState.sync_rate
	_advance(0.7)
	assert_almost_eq(GameState.sync_rate, s1, EPS, "Sombra 9 cuadros")
	_advance(0.6)
	assert_lt(GameState.sync_rate, s1, "La moneda cae")


# --- Fase 2: cajas sorpresa ---

func test_phase2_batches_land_where_the_data_says() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_place_isak(1, 9, 1.0)
	var boxes: Array[SurpriseBox] = _boss.launch_batch()
	assert_eq(boxes.size(), 3, "Tanda de 3")
	_advance(1.5)
	var expect: Array = [[3, 8, SurpriseBox.CONTENT_TOKENS], [13, 10, SurpriseBox.CONTENT_BOMB], [16, 8, SurpriseBox.CONTENT_TICKET]]
	for i: int in 3:
		var b: SurpriseBox = boxes[i]
		assert_eq(b.content, expect[i][2], "Contenido fijo")
		assert_eq(b.get_state(), SurpriseBox.STATE_CLOSED, "%s ha caido" % b.content)
		assert_eq(roundi(b.get_body_rect().get_center().x / TILE - 0.5), int(expect[i][0]), "%s en su columna" % b.content)
		assert_almost_eq(b.get_body_rect().end.y, float(expect[i][1]) * TILE, 1.0, "%s en su superficie" % b.content)


func test_phase2_tokens_box_and_the_bomb_fuse() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_place_isak(1, 9, 1.0)
	_boss.launch_batch()
	_advance(1.2)
	var good: SurpriseBox = _box_with(SurpriseBox.CONTENT_TOKENS)
	assert_true(good.open())
	assert_eq(_boss.get_tokens(), 14, "Caja buena: +2 fichas")
	var bomb: SurpriseBox = _box_with(SurpriseBox.CONTENT_BOMB)
	assert_gt(_boss.get_fuse_left(bomb), 0.0, "La mecha corre desde que cae")
	_place_isak(12, 9, 1.0)
	var s0: float = GameState.sync_rate
	var blasts: Array = []
	_boss.bomb_exploded.connect(func(at: Vector2) -> void: blasts.append(at))
	_advance_until(func() -> bool: return not blasts.is_empty(), 3.0)
	assert_eq(blasts.size(), 1, "Explota a los 2,5 s de caer")
	assert_almost_eq(GameState.sync_rate, s0 - 10.0, EPS, "-10 a 1,5 tiles")


func test_phase2_pulse_stuns_a_bomb_into_a_step() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_place_isak(1, 9, 1.0)
	_boss.spawn_box(3, 10, SurpriseBox.CONTENT_BOMB)
	_advance(1.0)
	var bomb: SurpriseBox = _box_with(SurpriseBox.CONTENT_BOMB)
	assert_eq(bomb.get_state(), SurpriseBox.STATE_CLOSED)
	_place_isak(2, 9, 1.0)
	_real_pulse()
	assert_true(bomb.is_stunned(), "El pulso aturde a la bomba")
	assert_true(bomb.is_solid(), "Sirve de escalon")
	var fuse: float = _boss.get_fuse_left(bomb)
	_advance(1.0)
	assert_almost_eq(_boss.get_fuse_left(bomb), fuse, EPS, "Aturdida, la mecha se para")
	assert_false(bomb.is_opened(), "No explota")


func test_phase2_ticket_stops_the_turn_and_opens_the_tray() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_place_isak(1, 9, 1.0)
	_boss.spawn_box(6, 10, SurpriseBox.CONTENT_TICKET)
	_advance(1.2)
	var ticket: SurpriseBox = _box_with(SurpriseBox.CONTENT_TICKET)
	assert_true(ticket.open())
	assert_true(_boss.is_refunding(), "«Procesando devolución…»")
	assert_true(_boss.is_tray_open(), "La bandeja se abre")
	assert_eq(_boss.get_sign(), "Procesando devolución…")
	_place_isak(13, 9, -1.0)
	_advance(3.5)
	assert_eq(_boss.get_facing(), Vendor.SIDE_LEFT, "Procesando: no se gira")
	assert_true(_boss.is_window_open(), "Ventana mientras procesa")
	_advance(0.6)
	assert_false(_boss.is_refunding(), "4 s del mundo")
	assert_false(_boss.is_tray_open(), "La bandeja se cierra")
	_advance(1.5)
	assert_eq(_boss.get_facing(), Vendor.SIDE_RIGHT, "Despues, se gira como siempre")


func test_phase2_tray_tunnel_is_crossed_compressed() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_boss.start_refund()
	var tunnel: Rect2 = _boss.get_tray_tunnel_rect()
	assert_eq(tunnel, Rect2(8 * TILE, 9 * TILE, 4 * TILE, TILE), "Bandeja: fila 9 bajo la maquina")
	assert_gte(tunnel.size.y, 48.0, "Cabe Isak comprimido")
	assert_lt(tunnel.size.y, _isak().get_hitbox_size().y, "De pie no cabe")


# --- Fase 3: oferta por tiempo limitado ---

func test_phase3_countdown_payment_and_nothing_attacks_while_frozen() -> void:
	await _arena()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3)
	assert_almost_eq(_boss.get_countdown_left(), 15.0, EPS, "Caché: 15 s")
	var ticks: Array = []
	_boss.countdown_ticked.connect(func(left: int) -> void: ticks.append(left))
	var paid: Array = []
	_boss.payment_processed.connect(func(by_tray: bool) -> void: paid.append(by_tray))
	# Isak en el estante: lejos de la bandeja (el tiron lo acerca poco a poco).
	_place_isak(3, 7, 1.0)
	var shutter: Shutter = _boss.get_shutter()
	for i: int in 900:
		_boss.advance(DT)
		if not paid.is_empty():
			break
	assert_eq(paid, [false], "A 0: «Procesando pago…»")
	assert_gte(ticks.size(), 15, "Un tic por segundo")
	assert_true(_isak().is_frozen(), "Congelado")
	assert_eq(_isak().get_frozen_source(), Vendor.FREEZE_SOURCE_PAY)
	assert_almost_eq(_boss.get_countdown_left(), 15.0, EPS, "La cuenta vuelve a empezar")
	assert_ne(_boss.get_shutter(), shutter, "Con el escaparate repuesto")
	var s0: float = GameState.sync_rate
	_boss.start_attack(Vendor.ATTACK_COINS)
	_advance(1.5)
	assert_almost_eq(GameState.sync_rate, s0, EPS, "Congelado, nada ataca")
	assert_almost_eq(_boss.get_countdown_left(), 15.0, EPS, "La cuenta espera")


func test_phase3_pull_toward_the_tray_and_touching_it_buys() -> void:
	await _arena()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3)
	assert_eq(_boss.get_facing(), Vendor.SIDE_LEFT, "Mira a Isak")
	var front := Vector2(4.5 * TILE, 9.5 * TILE)
	assert_almost_eq(_boss.get_pull_weight(front), 1.5, EPS, "Por delante, hacia la bandeja: al tope")
	var back := Vector2(14.5 * TILE, 9.5 * TILE)
	assert_almost_eq(_boss.get_pull_weight(back), -1.5, EPS, "Por detras, hacia la maquina")
	var field := TemptationField.load_default()
	field.sample(get_tree(), Vector2(1.5 * TILE, 9.5 * TILE))
	assert_almost_eq(field.get_drift(), 90.0, EPS, "Deriva 90 px/s")
	var paid: Array = []
	_boss.payment_processed.connect(func(by_tray: bool) -> void: paid.append(by_tray))
	_place_isak(6, 9, 1.0)
	_advance_until(func() -> bool: return not paid.is_empty(), 4.0)
	assert_eq(paid, [true], "Quieto, el tiron lo lleva a la bandeja: «Compra realizada»")
	assert_true(_isak().is_frozen())


func test_phase3_does_not_turn_and_the_showcase_only_breaks_with_the_ram() -> void:
	await _arena()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3)
	var shutter: Shutter = _boss.get_shutter()
	assert_not_null(shutter, "Escaparate en el techo")
	assert_eq(shutter.get_shutter_rect(), Rect2(11 * TILE, 2 * TILE, TILE, 3 * TILE), "Pegado a la espalda, 3 de alto")
	assert_eq(_boss.get_showcases().size(), 2, "Dos vitrinas gratis")
	EventBus.ground_pound_landed.emit(shutter.get_shutter_rect(), _isak())
	assert_false(shutter.is_broken(), "El golpe al suelo rebota")
	EventBus.combo_landed.emit(Isak.COMBO_RAM, shutter.get_shutter_rect().grow(8.0), _isak())
	assert_true(shutter.is_broken(), "La Embestida lo rompe")
	_place_isak(13, 9, -1.0)
	_advance(3.0)
	assert_eq(_boss.get_facing(), Vendor.SIDE_LEFT, "Ocupado vendiendo: no se gira")
	assert_true(_boss.is_window_open(), "Detras: ventana")
	assert_true(_boss.get_core().is_enabled())


func test_phase3_the_slot_pushes_out_without_the_edge() -> void:
	await _arena()
	_boss.start()
	_place_isak(2, 9, 1.0)
	assert_false(_boss.is_slot_open(), "Fase 1: la ranura esta cerrada")
	_to_phase(3)
	assert_true(_boss.is_slot_open(), "Fase 3: abierta")
	var slot: Rect2 = _boss.get_slot_rect()
	assert_eq(slot, Rect2(8 * TILE, 6 * TILE, 4 * TILE, 2 * TILE),
		"Ranura: filas 6-7 de lado a lado (4 tiles = un Filo exacto; 2 de alto desde el paso 17)")
	var pushed: Array = []
	_boss.slot_pushed.connect(func(d: float) -> void: pushed.append(d))
	_place_isak(5, 7, 1.0)
	_advance(DT)
	_isak().global_position = Vector2(slot.position.x + 40.0, slot.end.y - 2.0)
	_advance(DT)
	assert_eq(pushed, [-1.0], "Sin el Filo, fuera por donde entro")
	assert_lt(_isak().global_position.x, slot.position.x, "Fuera de la ranura")


# --- Fase 3 con el Isak real (paso 17, 2026-10-29): Embestida desde la vitrina y
# Filo desde el estante, con la entrada falsa cuadro a cuadro (lo que mide el
# validador de arenas) ---

func _combo_ready() -> void:
	for ability: StringName in COMBO_ABILITIES:
		GameState.set_ability_unlocked(ability, true)


## La fase 3 sin ataques ni cuenta que corra (solo la geometria): el tiron sigue.
func _quiet_phase3() -> void:
	_boss._attack = Vendor.ATTACK_GAP
	_boss._gap_left = 999.0
	_boss._countdown_left = 999.0


func _frame(n: int = 1) -> void:
	for i: int in n:
		_advance(DT)


## Salta desde donde esta; en el cuadro `dash_at` Deslizar hacia la derecha y, `hold_after`
## cuadros despues, abajo (Embestida). Devuelve si el escaparate se rompio.
func _ram_from_showcase(dash_at: int, hold_after: int) -> bool:
	var shutter: Shutter = _boss.get_shutter()
	_sim.input.jump_pressed = true
	_sim.input.jump_held = true
	_frame()
	for k: int in range(1, 90):
		if k == dash_at:
			_sim.input.move_axis = 1.0
			_sim.input.dash_pressed = true
		if k == dash_at + hold_after:
			_sim.input.hold_held = true
		_frame()
		if _isak().is_on_floor() and k > dash_at + hold_after:
			break
	_sim.input.hold_held = false
	_sim.input.jump_held = false
	_sim.input.move_axis = 0.0
	_frame(6)
	return shutter.is_broken()


## Pellizca en el estante, salta comprimido y Filo hacia la derecha en el cuadro
## `edge_at` (o Deslizar sin comprimir con compressed = false). Devuelve la x final.
func _edge_from_shelf(edge_at: int, compressed: bool = true) -> float:
	if compressed:
		_sim.input.pinch_pressed = true
		_frame()
		assert_true(_isak().is_compressed(), "Comprimido en el estante")
	_sim.input.jump_pressed = true
	_sim.input.jump_held = true
	_frame()
	for k: int in range(1, 60):
		if k == edge_at:
			_sim.input.move_axis = 1.0
			_sim.input.dash_pressed = true
		_frame()
		if _isak().is_on_floor() and k > edge_at:
			break
	_sim.input.jump_held = false
	_sim.input.move_axis = 0.0
	_frame(60)
	return _isak().global_position.x


func test_phase3_real_ram_from_a_showcase_breaks_the_shutter() -> void:
	await _arena()
	_combo_ready()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3)
	_quiet_phase3()
	var landed: Array = []
	EventBus.combo_landed.connect(func(kind: StringName, _r: Rect2, _s: Node2D) -> void: landed.append(kind))
	# En la cumbre del salto desde la vitrina b, dash aereo y abajo al final del dash.
	_place_isak(7, 5, 1.0)
	assert_true(_isak().is_on_floor(), "De pie en la vitrina b (fila 6)")
	assert_true(_ram_from_showcase(12, 6), "La Embestida desde la vitrina rompe el escaparate")
	assert_eq(landed, [Isak.COMBO_RAM], "Una Embestida")
	assert_almost_eq(_isak().global_position.y, 5.0 * TILE, 1.0, "Aterriza en el techo de la maquina")
	# Sin romperla, el escaparate no se cruza andando ni saltando.
	_boss._place_shutter()
	await wait_physics_frames(1)
	_place_isak(9, 4, 1.0)
	_sim.input.move_axis = 1.0
	_frame(90)
	_sim.input.jump_pressed = true
	_sim.input.jump_held = true
	_frame(60)
	_sim.input.jump_held = false
	_sim.input.move_axis = 0.0
	assert_lt(_isak().global_position.x, 11.0 * TILE, "El escaparate entero (3 tiles) para el salto")
	assert_false(_boss.get_shutter().is_broken())


func test_phase3_real_ram_window_is_wide() -> void:
	await _arena()
	_combo_ready()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3)
	_quiet_phase3()
	var ok: int = 0
	var tried: int = 0
	for dash_at: int in [10, 14, 18, 22]:
		for hold_after: int in [2, 5]:
			if _isak().is_frozen():
				_isak().change_state(PlayerState.IDLE)
			GameState.debug_energy = GameState.get_debug_energy_max()
			_place_isak(6, 5, 1.0)
			tried += 1
			if _ram_from_showcase(dash_at, hold_after):
				ok += 1
			_boss._place_shutter()
			await wait_physics_frames(1)
	assert_eq(ok, tried, "Dash aereo del cuadro 10 al 22 del salto (cumbre a los 24) y abajo pronto o tarde: siempre llega")


func test_phase3_real_edge_from_the_shelf_crosses_the_slot() -> void:
	await _arena()
	_combo_ready()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3)
	_quiet_phase3()
	var machine: Rect2 = _boss.get_machine_rect()
	var pushed: Array = []
	_boss.slot_pushed.connect(func(d: float) -> void: pushed.append(d))
	# Del principio al final del salto comprimido (unos 30 cuadros): cualquier cuadro vale.
	for edge_at: int in [2, 8, 15, 22, 28]:
		if _isak().is_frozen():
			_isak().change_state(PlayerState.IDLE)
		GameState.debug_energy = GameState.get_debug_energy_max()
		_place_isak(5, 7, 1.0)
		if _isak().is_compressed():
			_sim.input.pinch_pressed = true
			_frame()
		_sim.settle()
		var x: float = _edge_from_shelf(edge_at)
		assert_gt(x, machine.end.x, "Filo en el cuadro %d del salto: sale por detras" % edge_at)
	assert_true(pushed.all(func(d: float) -> bool: return d > 0.0), "Si el Filo acaba dentro, sale por el otro lado")


func test_phase3_real_plain_dash_into_the_slot_goes_back() -> void:
	await _arena()
	_combo_ready()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3)
	_quiet_phase3()
	_place_isak(5, 7, 1.0)
	var x: float = _edge_from_shelf(4, false)
	assert_lt(x, _boss.get_machine_rect().position.x, "Un dash normal no cruza la ranura: vuelve delante")


# --- Ajustes del paso 19 (2026-10-29, bot del jefe) ---

func test_phase1_labels_restock_after_a_hit() -> void:
	await _arena()
	_boss.start()
	var restocked: Array = []
	_boss.shelf_restocked.connect(func() -> void: restocked.append(true))
	_boss.take_core_hit(1)
	var restock: float = float(_boss.section("priced_platforms").get("restock_s", 0.0))
	assert_gt(restock, 0.0, "restock_s en los datos")
	assert_almost_eq(_boss.get_restock_left(), restock, EPS, "Tras el golpe, las etiquetas se reponen")
	assert_false(_boss.pay_platform("a"), "Reponiendo: no se puede pagar")
	assert_eq(_boss.get_tokens(), 12, "Sin cobrar")
	_advance(restock + DT)
	assert_eq(restocked, [true], "shelf_restocked al acabar")
	assert_true(_boss.pay_platform("a"), "Repuestas: se paga")


func test_phase2_starts_facing_isak_without_a_free_window() -> void:
	await _arena()
	_boss.start()
	_place_isak(14, 9, -1.0)
	_advance(DT)
	assert_true(_boss.is_isak_behind(), "Detras en la fase 1")
	_to_phase(2)
	assert_eq(_boss.get_facing(), Vendor.SIDE_RIGHT, "La fase 2 empieza mirando a Isak")
	assert_false(_boss.is_window_open(), "Sin ventana regalada")
	_advance(2.0)
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_NONE)
	assert_false(_boss.is_window_open())


func test_phase2_a_hit_ends_the_refund_and_turns() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	_place_isak(14, 9, -1.0)
	_boss.start_refund()
	_advance(0.5)
	assert_true(_boss.is_refunding())
	assert_true(_boss.is_window_open(), "Detras procesando: ventana")
	var finished: Array = []
	_boss.refund_finished.connect(func() -> void: finished.append(true))
	_boss.take_core_hit(1)
	assert_false(_boss.is_refunding(), "Un golpe por ventana: la devolucion se da por procesada")
	assert_eq(finished, [true])
	assert_eq(_boss.get_turn_stage(), Vendor.TURN_TURNING, "Y se gira ya")


func test_phase3_offer_grace_then_countdown() -> void:
	await _arena()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3, true)
	var grace: float = float(_boss.section("offer").get("start_grace_s", 0.0))
	assert_gt(grace, 0.0)
	assert_almost_eq(_boss.get_offer_grace_left(), grace, EPS, "El cartel baja")
	assert_false(_boss.is_slot_open(), "Con la ranura cerrada")
	assert_false(_boss.is_pulling(), "Sin tiron")
	var paid: Array = []
	_boss.payment_processed.connect(func(by_tray: bool) -> void: paid.append(by_tray))
	_isak().global_position = _boss.get_tray_zone_rect().get_center() + Vector2(0.0, 31.0)
	_sim.settle()
	_advance(grace - 0.5)
	assert_eq(paid, [], "En la bandeja durante el cartel: no compra")
	assert_almost_eq(_boss.get_countdown_left(), _boss.get_countdown_s(), EPS, "La cuenta espera")
	_place_isak(2, 9, 1.0)
	_advance(0.6)
	assert_true(_boss.is_slot_open(), "Despues, la ranura se abre")
	assert_true(_boss.is_pulling(), "y tira")
	assert_lt(_boss.get_countdown_left(), _boss.get_countdown_s(), "y la cuenta corre")


func test_phase3_a_hit_sells_another_offer() -> void:
	await _arena()
	_boss.start()
	_place_isak(2, 9, 1.0)
	_to_phase(3)
	assert_eq(_boss.get_facing(), Vendor.SIDE_LEFT)
	var shutter: Shutter = _boss.get_shutter()
	_place_isak(14, 9, -1.0)
	_advance(3.0)
	assert_true(_boss.is_isak_behind())
	_boss.take_core_hit(1)
	assert_eq(_boss.get_facing(), Vendor.SIDE_RIGHT, "Mira a Isak: hay que volver delante")
	assert_almost_eq(_boss.get_countdown_left(), _boss.get_countdown_s(), EPS, "La cuenta vuelve a empezar")
	assert_gt(_boss.get_offer_grace_left(), 0.0, "Con el cartel que baja otra vez")
	assert_false(_boss.is_slot_open(), "Ranura cerrada mientras baja")
	assert_ne(_boss.get_shutter(), shutter, "Escaparate repuesto")

