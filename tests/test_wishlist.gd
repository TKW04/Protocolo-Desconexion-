# Lista de deseos, tachon y caja registradora de Calc del Mundo 5 (paso 7 de
# docs/propuesta-mundo-5.md §8; reglas de §3.3, §3.7, §4.2.1 y §4.3.1): la lista de
# deseos tira como una Oferta y se suma con las demas hasta el TOPE (deriva 90 px/s,
# x0,45 al alejarse); quedarse 1,5 s sobre el objeto = «Añadido al carrito» y una
# Suscripcion enganchada (una vez; despues deja de tirar); pasar sin pararse no; el
# pulso apaga el tiron 3 s. Tachon: parece terreno sin el Debug, la linea solo se lee
# con el Debug y la pared se abre con el. Caja de Calc: el ATAJO LEGITIMO (precio de
# data/economy.json, sin trampa, no devoluble, sin saldo no abre) y Calc habla con su
# LCD. Isak avanza paso a paso con delta fijo; los objetos, a mano. Usa su propia ruta
# de guardado.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const WISH_SCENE: PackedScene = preload("res://scenes/levels/wishlist_platform.tscn")
const OFFER_SCENE: PackedScene = preload("res://scenes/enemies/offer_sign.tscn")
const STRIKE_SCENE: PackedScene = preload("res://scenes/levels/wish_strike.tscn")
const REGISTER_SCENE: PackedScene = preload("res://scenes/levels/calc_register.tscn")
const TEXT_BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const ROOM_SCENE: String = "res://scenes/levels/deseos_test.tscn"
const PATH: String = "user://test_wishlist.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const T: float = 64.0
const ABILITIES: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_DASH, GameState.ABILITY_DEBUG,
	GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}
var _wishes: Array[WishlistPlatform] = []
var _offers: Array[OfferSign] = []
var _registers: Array[CalcRegister] = []
var _pause_important: bool = true


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.begin_attempt()
	GameState.current_level = &"5-3"
	_saved = {}
	for ability: StringName in ABILITIES:
		_saved[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	GameState.attention_points = 3
	DebugMode.input_enabled = false
	DebugMode.reset()
	_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	_wishes = []
	_offers = []
	_registers = []
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	EcoTextBox.pause_important = _pause_important
	DebugMode.reset()
	DebugMode.input_enabled = true
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.current_level = GameState.NO_LEVEL
	GameState.begin_attempt()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

func _step(count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for wish: WishlistPlatform in _wishes:
			wish.advance(DT)
		for offer: OfferSign in _offers:
			offer.step(DT)
		for reg: CalcRegister in _registers:
			reg.advance(DT)


## Deseo con la tarjeta arriba de la celda (col, row) (filas: y = row x T; el suelo es y = 0).
func _wish(col: float, row: float, width: int = 3) -> WishlistPlatform:
	var wish := WISH_SCENE.instantiate() as WishlistPlatform
	wish.object_id = &"deseo_%d" % _wishes.size()
	wish.width_tiles = width
	wish.position = Vector2(col * T, row * T)
	_world.add_child(wish)
	wish.set_physics_process(false)
	_wishes.append(wish)
	return wish


func _offer(x: float) -> OfferSign:
	var offer := OFFER_SCENE.instantiate() as OfferSign
	offer.position = Vector2(x, 0.0)
	_world.add_child(offer)
	offer.set_physics_process(false)
	offer.target = _isak
	_offers.append(offer)
	return offer


func _register(col: float) -> CalcRegister:
	var reg := REGISTER_SCENE.instantiate() as CalcRegister
	reg.object_id = &"caja_calc"
	reg.position = Vector2(col * T, -3.0 * T)
	_world.add_child(reg)
	reg.set_process(false)
	_registers.append(reg)
	return reg


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


func _place(at: Vector2) -> void:
	_isak.global_position = at
	_isak.velocity = Vector2.ZERO
	_sim.step(3)


func _steady_speed(axis: float) -> float:
	_sim.input.move_axis = axis
	_step(_sim.frames(0.4))
	var v: float = _isak.velocity.x
	_sim.input.move_axis = 0.0
	return v


func _activate_debug() -> void:
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 5:
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Debug activo")


# --- Lista de deseos: el tiron ---

func test_wishlist_pulls_toward_its_item_like_an_offer() -> void:
	var wish: WishlistPlatform = _wish(3.0, -1.0)
	assert_eq(wish.get_item_feet(), Vector2(4.5 * T, -T), "Objeto en el centro, sobre la tarjeta")
	_step(_sim.frames(0.6))
	var field: TemptationField = _isak.get_temptation()
	assert_eq(field.sources, 1, "Tira como una Oferta")
	assert_almost_eq(field.get_drift(), 60.0, EPS, "Sola: deriva de 60")
	assert_almost_eq(_isak.velocity.x, 60.0, 0.5, "Hacia el objeto")
	# Zona: 6 tiles a cada lado del objeto.
	var c: Vector2 = wish.get_item_rect().get_center()
	assert_eq(wish.get_pull_weight(c + Vector2(-5.5 * T, 0.0)), 1.0, "A 5,5 tiles tira")
	assert_eq(wish.get_pull_weight(c + Vector2(-6.5 * T, 0.0)), 0.0, "A 6,5 no")


func test_wishlist_adds_up_with_an_offer_to_the_cap() -> void:
	_wish(3.0, -1.0)
	_offer(5.0 * T)
	_step(_sim.frames(0.6))
	var field: TemptationField = _isak.get_temptation()
	assert_eq(field.sources, 2, "El deseo y la Oferta")
	assert_almost_eq(field.get_drift(), 90.0, EPS, "Tiron al tope: 90 px/s")
	assert_almost_eq(field.get_multiplier(-1.0), 0.45, 0.001, "x0,45 al alejarse")
	assert_almost_eq(_isak.velocity.x, 90.0, 0.5)
	assert_almost_eq(_steady_speed(-1.0), -9.0, 0.5, "Andar alejandose: -99 + 90 (aun se sale)")


# --- Lista de deseos: «Añadido al carrito» ---

func test_staying_on_the_item_adds_it_to_the_cart() -> void:
	var wish: WishlistPlatform = _wish(3.0, -2.0)
	watch_signals(wish)
	_place(Vector2(wish.get_item_feet().x + 30.0, -2.0 * T))
	assert_true(_isak.is_on_floor(), "De pie en la tarjeta")
	_step(_sim.frames(1.2))
	assert_true(wish.is_isak_on_item(_isak), "La deriva lo deja encima del objeto")
	assert_false(wish.is_added(), "Aun no")
	_step(_sim.frames(0.7))
	assert_true(wish.is_added(), "1,5 s encima: «Añadido al carrito»")
	assert_eq(wish.get_message(), "Añadido al carrito")
	assert_signal_emitted(wish, "added_to_cart")
	var sub: Subscription = wish.get_subscription()
	assert_not_null(sub, "Y una Suscripcion")
	assert_true(sub.is_attached(), "Enganchada")
	assert_eq(sub.get_host(), _isak)
	assert_eq(wish.get_pull_weight(_isak.global_position + Vector2(-T, -40.0)), 0.0, "En el carrito ya no tira")
	assert_false(wish.add_to_cart(_isak), "Una vez")


func test_crossing_without_stopping_does_not_add() -> void:
	var wish: WishlistPlatform = _wish(2.0, -2.0, 4)
	_place(Vector2(2.0 * T + 16.0, -2.0 * T))
	_sim.input.move_axis = 1.0
	_sim.input.run_held = true
	_step(_sim.frames(1.0))
	_sim.input.move_axis = 0.0
	_sim.input.run_held = false
	assert_gt(_isak.global_position.x, wish.get_item_feet().x + 32.0, "Ha cruzado el objeto")
	assert_false(wish.is_added(), "Sin pararse 1,5 s no lo añade")
	assert_null(wish.get_subscription())


func test_pulse_turns_the_pull_off_for_three_seconds() -> void:
	var wish: WishlistPlatform = _wish(3.0, -1.0)
	var c: Vector2 = wish.get_item_rect().get_center()
	assert_true(wish.receive_pulse(_fake_pulse(c)), "El pulso alcanza el objeto")
	assert_true(wish.is_pull_stunned())
	assert_eq(wish.get_pull_weight(c + Vector2(-2.0 * T, 0.0)), 0.0, "Sin tiron")
	_step(_sim.frames(2.9))
	assert_true(wish.is_pull_stunned())
	_step(_sim.frames(0.2))
	assert_false(wish.is_pull_stunned(), "A los 3 s vuelve a tirar")
	assert_eq(wish.get_pull_weight(c + Vector2(-2.0 * T, 0.0)), 1.0)


# --- Tachon ---

func test_wish_strike_only_shows_with_the_debug_and_opens_with_it() -> void:
	var strike := STRIKE_SCENE.instantiate() as WishStrike
	strike.object_id = &"tachon"
	strike.position = Vector2(4.0 * T, -2.0 * T)
	_world.add_child(strike)
	strike.set_process(false)
	await wait_process_frames(1)
	assert_true(strike.visible_only_with_debug, "Siempre solo con el Debug")
	assert_eq(strike.get_strike_text(), "arreglar la radio del Abuelito")
	assert_true(strike.is_solid(), "Sin Debug, solida")
	assert_false(strike.is_glitch_shown(), "Parece terreno")
	assert_false(strike.is_text_shown(), "La linea no se lee")
	assert_not_null(strike.get_strike_line(), "La linea va en un hermano")
	assert_eq(strike.get_strike_line().get_parent(), _world)
	_activate_debug()
	assert_true(strike.is_text_shown(), "Con el Debug se lee el tachon")
	assert_true(strike.is_glitch_shown())
	assert_true(strike.open_with_debug())
	for i: int in 120:
		if strike.is_open():
			break
		strike.advance(DT)
	assert_true(strike.is_open(), "Se abre")
	assert_false(strike.is_solid())
	DebugMode.reset()
	assert_true(strike.is_text_shown(), "Abierta, la linea se queda a la vista")


# --- Caja registradora de Calc ---

func test_calc_register_sells_the_legit_shortcut() -> void:
	var reg: CalcRegister = _register(4.0)
	var said: Array = []
	reg.calc_said.connect(func(text: String, kind: StringName) -> void: said.append([kind, text]))
	assert_eq(reg.get_cost(), 2, "prices.calc_register: 2")
	assert_false(reg.has_trap(), "Sin trampa")
	reg.trap = ShortcutDoor.TRAP_PROCESSING
	assert_false(reg.has_trap(), "Nunca con trampa, aunque se le ponga")
	# Pulso de espaldas: paga y abre.
	_place(Vector2(reg.get_door_rect().position.x - 20.0, 0.0))
	assert_eq(said.size(), 0)
	_step(2)
	assert_eq(said.size(), 1, "Calc habla al acercarse")
	assert_eq(said[0][0], &"near")
	assert_true(String(said[0][1]).begins_with("Atajo: 2"))
	assert_true(reg.receive_pulse(_isak_pulse()), "El pulso la alcanza")
	assert_true(_isak.is_facing_back(), "De espaldas")
	assert_true(reg.is_open(), "Abierto")
	assert_eq(GameState.attention_points, 1, "Cobra 2")
	assert_eq(GameState.get_refundable(GameState.current_level), 0, "Sin trampa: no va a Devoluciones")
	assert_eq(said[said.size() - 1][0], &"paid")
	assert_eq(said[said.size() - 1][1], "Precio: 2. Trampa: 0. Eco llama a esto mal negocio.")
	assert_eq(reg.get_node("Body").collision_layer, 0, "Deja pasar")
	# Cruzarla no hace saltar nada.
	_isak.face_side()
	_place(reg.get_door_rect().get_center() + Vector2(0.0, 3.0 * T))
	_step(5)
	assert_false(reg.is_trap_sprung(), "Ninguna trampa")
	assert_false(_isak.is_frozen(), "Sin «Verificando pago…»")
	assert_eq(get_tree().get_nodes_in_group(Subscription.SUBSCRIPTION_GROUP).size(), 0, "Sin Suscripcion")


func test_calc_register_without_funds_stays_closed() -> void:
	GameState.attention_points = 1
	var reg: CalcRegister = _register(4.0)
	watch_signals(reg)
	assert_false(reg.pay(), "Con 1 no llega")
	assert_false(reg.is_open())
	assert_eq(GameState.attention_points, 1, "Sin deuda")
	assert_eq(reg.get_message(), "Saldo insuficiente")
	assert_signal_emitted_with_parameters(reg, "rejected", [PayPoint.REJECT_NO_FUNDS])


func test_calc_speaks_with_its_lcd_style() -> void:
	var tb := TEXT_BOX_SCENE.instantiate() as EcoTextBox
	tb.name = "EcoTextBox"
	_world.add_child(tb)
	tb.set_process(false)
	var reg: CalcRegister = _register(4.0)
	reg.say("Precio: 2.", &"paid")
	assert_eq(tb.get_speaker_id(), CalcRegister.SPEAKER_CALC, "Habla Calc")
	assert_eq(tb.get_style_id(), &"lcd", "Con su LCD")
	assert_false(tb.is_important(), "No importante")


# --- Sala ---

func test_deseos_test_room_loads() -> void:
	var scene := load(ROOM_SCENE) as PackedScene
	assert_not_null(scene, "La sala deseos_test existe")
	var room: Node = scene.instantiate()
	add_child_autofree(room)
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group(WishlistPlatform.GROUP).size(), 3, "Tres deseos")
	assert_eq(get_tree().get_nodes_in_group(WishStrike.STRIKE_GROUP).size(), 1, "El tachon")
	assert_eq(get_tree().get_nodes_in_group(CalcRegister.REGISTER_GROUP).size(), 1, "La caja de Calc")
