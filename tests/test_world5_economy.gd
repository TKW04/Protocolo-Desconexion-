# Economia del Mundo 5 en el nivel (paso 3 de docs/propuesta-mundo-5.md §8; reglas de
# §3.1, §3.6 y §3.7 y pruebas de §7.4): GameState.spend_attention (saldo real, SIN
# DEUDA: el saldo nunca baja de 0; gastar marca «sin guardar»), tienda (shop_item:
# +25 de Sync o +40 de energia, uno por intento, «Saldo insuficiente»), atajo
# (shortcut_door: solido hasta pagar, trampa processing con el congelado y su golpe,
# el Debug ensena la trampa, solo lo pagado con trampa es devoluble), Devoluciones
# (refund_desk: solo lo del nivel e intento, bonus una vez, una vez por intento) y el
# rollback de un game over devuelve lo gastado sin guardar (va a la Papelera con la
# copia). Sala tienda_test. Usa su propia ruta de guardado.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const SHOP_SCENE: PackedScene = preload("res://scenes/levels/shop_item.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/levels/shortcut_door.tscn")
const DESK_SCENE: PackedScene = preload("res://scenes/levels/refund_desk.tscn")
const ROOM_SCENE: String = "res://scenes/levels/tienda_test.tscn"
const PATH: String = "user://test_world5_economy.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const LEVEL: StringName = &"5-1"

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved_debug: bool
var _spent: Array = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)
	GameState.begin_attempt()
	GameState.current_level = LEVEL
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_spent = []
	EventBus.attention_spent.connect(_on_spent)
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = Vector2(-2000.0, 0.0)
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	EventBus.attention_spent.disconnect(_on_spent)
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.current_level = GameState.NO_LEVEL
	GameState.begin_attempt()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _on_spent(amount: int, reason: StringName) -> void:
	_spent.append([amount, reason])


# --- Utilidades ---

## Saldo `points` sin marca de «sin guardar».
func _balance(points: int) -> void:
	GameState.attention_points = points
	assert_true(GameState.save_game(), "Copia guardada con %d puntos" % points)
	assert_false(GameState.has_unsaved_changes())


func _shop(product: StringName, col: float = 2.0) -> ShopItem:
	var item := SHOP_SCENE.instantiate() as ShopItem
	item.product = product
	item.position = Vector2(col * T, -T)
	_world.add_child(item)
	item.set_process(false)
	return item


func _door(trap: StringName, col: float = 6.0, cost: int = -1) -> ShortcutDoor:
	var door := DOOR_SCENE.instantiate() as ShortcutDoor
	door.object_id = &"atajo_prueba"
	door.trap = trap
	door.cost = cost
	door.position = Vector2(col * T, -3.0 * T)
	_world.add_child(door)
	door.set_process(false)
	return door


func _desk(id: StringName = &"devoluciones_prueba") -> RefundDesk:
	var desk := DESK_SCENE.instantiate() as RefundDesk
	desk.object_id = id
	desk.position = Vector2(12.0 * T, -T)
	_world.add_child(desk)
	desk.set_process(false)
	return desk


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


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_revealing(), "Debug revelando")


# --- spend_attention ---

func test_spend_attention_never_goes_into_debt() -> void:
	_balance(2)
	assert_false(GameState.can_afford(3))
	assert_false(GameState.spend_attention(3, &"prueba"), "No llega: no gasta")
	assert_eq(GameState.attention_points, 2, "El saldo no cambia")
	assert_false(GameState.has_unsaved_changes(), "Sin gasto no hay «sin guardar»")
	assert_false(GameState.spend_attention(-1), "Un gasto negativo no vale")
	assert_true(GameState.spend_attention(2, &"prueba"), "Justo lo que hay")
	assert_eq(GameState.attention_points, 0, "Saldo 0, nunca negativo")
	assert_true(GameState.has_unsaved_changes(), "Gastar marca «sin guardar»")
	assert_eq(_spent, [[2, &"prueba"]], "attention_spent")
	assert_false(GameState.spend_attention(1), "Con 0 no se gasta nada")
	assert_eq(GameState.attention_points, 0)
	var energy: float = GameState.debug_energy
	assert_true(GameState.spend_attention(0), "0 no gasta")
	assert_eq(GameState.debug_energy, energy, "Gastar no quita energia")


func test_refund_registry_is_per_level_and_attempt() -> void:
	_balance(10)
	assert_true(GameState.spend_attention(3, &"shortcut_door", LEVEL, GameState.REFUND_SHORTCUT_TRAP))
	GameState.note_refundable(LEVEL, GameState.REFUND_SUBSCRIPTION, 2)
	GameState.note_refundable(&"5-2", GameState.REFUND_SUBSCRIPTION, 4)
	assert_true(GameState.spend_attention(2, &"calc"), "Un gasto sin tipo no es devoluble")
	assert_eq(GameState.get_refundable(LEVEL), 5)
	assert_eq(GameState.get_refundable(&"5-2"), 4)
	GameState.begin_attempt()
	assert_eq(GameState.get_refundable(LEVEL), 0, "Un intento nuevo vacia el registro")
	assert_eq(GameState.get_refundable(&"5-2"), 0)


# --- Tienda ---

func test_shop_sells_sync_once_per_attempt() -> void:
	_balance(5)
	GameState.sync_rate = 50.0
	var item: ShopItem = _shop(ShopItem.PRODUCT_SYNC)
	assert_eq(item.get_cost(), 3, "Precio de data/economy.json")
	watch_signals(item)
	assert_eq(item.buy(), ShopItem.RESULT_OK)
	assert_eq(GameState.attention_points, 2, "Paga 3 del saldo real")
	assert_almost_eq(GameState.sync_rate, 75.0, 0.001, "+25 de Sync al instante")
	assert_signal_emitted_with_parameters(item, "bought", [ShopItem.PRODUCT_SYNC, 3])
	assert_true(GameState.has_unsaved_changes())
	assert_eq(_spent, [[3, ShopItem.GROUP]])
	GameState.attention_points = 9
	assert_eq(item.buy(), ShopItem.RESULT_SOLD_OUT, "Uno por intento")
	assert_eq(item.get_message(), "Agotado")
	assert_eq(GameState.attention_points, 9, "Agotado no cobra")
	assert_false(item.is_help_available())


func test_shop_energy_and_no_funds() -> void:
	_balance(1)
	GameState.debug_energy = 10.0
	var item: ShopItem = _shop(ShopItem.PRODUCT_ENERGY)
	assert_eq(item.get_cost(), 2)
	watch_signals(item)
	assert_eq(item.buy(), ShopItem.RESULT_NO_FUNDS)
	assert_eq(item.get_message(), "Saldo insuficiente")
	assert_true(item.is_sparking(), "Chispa gris")
	assert_signal_emitted_with_parameters(item, "rejected", [PayPoint.REJECT_NO_FUNDS])
	assert_eq(GameState.attention_points, 1, "Sin deuda")
	assert_almost_eq(GameState.debug_energy, 10.0, 0.001, "Sin efecto")
	assert_false(item.is_sold_out(), "No gasta el uso")
	GameState.attention_points = 2
	assert_eq(item.buy(), ShopItem.RESULT_OK)
	assert_eq(GameState.attention_points, 0)
	assert_almost_eq(GameState.debug_energy, 50.0, 0.001, "+40 de energia")


func test_pulse_from_behind_buys_and_turns_isak_around() -> void:
	_balance(3)
	var item: ShopItem = _shop(ShopItem.PRODUCT_SYNC, 2.0)
	_isak.global_position = Vector2(2.5 * T, 0.0)
	_sim.settle()
	var area := _isak.get_node(^"PulseArea") as Area2D
	assert_true(item.receive_pulse(area), "El pulso de Isak alcanza el producto")
	assert_true(_isak.is_facing_back(), "Isak se pone de espaldas")
	assert_eq(GameState.attention_points, 0, "Comprado")
	assert_true(item.is_sold_out())
	item.advance(0.5)
	assert_false(_isak.is_facing_back(), "Y vuelve de perfil")
	assert_false(item.receive_pulse(_fake_pulse(Vector2(20.0 * T, -T))), "Lejos no lo alcanza")


# --- Atajo ---

func test_door_is_solid_until_paid_and_only_trap_doors_are_refundable() -> void:
	_balance(6)
	var trap_door: ShortcutDoor = _door(ShortcutDoor.TRAP_PROCESSING)
	var body := trap_door.get_node(^"Body") as StaticBody2D
	assert_eq(body.collision_layer, ShortcutDoor.LAYER_WORLD, "Cerrada es solida")
	assert_eq(trap_door.get_cost(), 3)
	assert_true(trap_door.pay())
	assert_true(trap_door.is_open())
	assert_eq(body.collision_layer, 0, "Abierta deja pasar")
	assert_eq(GameState.attention_points, 3)
	assert_eq(GameState.get_refundable(LEVEL, [GameState.REFUND_SHORTCUT_TRAP]), 3, "Con trampa: devoluble")
	assert_false(trap_door.pay(), "Un uso por intento: ya abierta no cobra")
	assert_eq(GameState.attention_points, 3)
	var calc_door: ShortcutDoor = _door(ShortcutDoor.TRAP_NONE, 9.0, 2)
	assert_true(calc_door.pay())
	assert_eq(GameState.attention_points, 1)
	assert_eq(GameState.get_refundable(LEVEL), 3, "Sin trampa (atajo legitimo) no es devoluble")


func test_door_without_funds_stays_closed() -> void:
	_balance(2)
	var door: ShortcutDoor = _door(ShortcutDoor.TRAP_PROCESSING)
	watch_signals(door)
	assert_true(door.receive_pulse(_fake_pulse(door.get_door_rect().get_center())), "El pulso la alcanza")
	assert_false(door.is_open())
	assert_eq(door.get_message(), "Saldo insuficiente")
	assert_signal_emitted(door, "rejected")
	assert_eq(GameState.attention_points, 2)


func test_processing_trap_freezes_isak_once_when_crossing() -> void:
	_balance(3)
	var door: ShortcutDoor = _door(ShortcutDoor.TRAP_PROCESSING, 6.0)
	assert_true(door.pay())
	watch_signals(door)
	_isak.global_position = Vector2(4.5 * T, 0.0)
	_sim.settle()
	door.advance(DT)
	assert_false(door.is_trap_sprung(), "Fuera de la puerta no salta")
	_isak.global_position = Vector2(6.5 * T, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.step()
	door.advance(DT)
	assert_true(door.is_trap_sprung(), "Al cruzar salta la trampa")
	assert_signal_emitted_with_parameters(door, "trap_sprung", [ShortcutDoor.TRAP_PROCESSING])
	assert_eq(door.get_message(), "Verificando pago…")
	assert_true(_isak.is_frozen(), "«Verificando pago…»: congelado")
	assert_almost_eq(_isak.get_frozen_left(), 1.5, 0.001, "1,5 s")
	assert_eq(_isak.get_frozen_source(), ShortcutDoor.FREEZE_SOURCE)
	var sync: float = GameState.sync_rate
	_sim.step(_sim.frames(1.6))
	assert_false(_isak.is_frozen())
	assert_lt(GameState.sync_rate, sync, "Golpe al liberarse")
	assert_false(door.spring_trap(_isak), "Solo una vez")


func test_debug_reveals_the_trap_on_the_door() -> void:
	var door: ShortcutDoor = _door(ShortcutDoor.TRAP_PROCESSING)
	var legit: ShortcutDoor = _door(ShortcutDoor.TRAP_NONE, 9.0)
	assert_false(door.is_trap_revealed(), "Sin el Debug no se ve")
	_activate_debug()
	assert_true(door.is_trap_revealed(), "Con el Debug se ve el icono de la trampa")
	assert_false(legit.is_trap_revealed(), "El atajo legitimo no tiene nada que ver")


# --- Devoluciones ---

func test_refund_desk_returns_only_this_level_and_attempt() -> void:
	_balance(10)
	var door: ShortcutDoor = _door(ShortcutDoor.TRAP_PROCESSING)
	assert_true(door.pay())
	GameState.note_refundable(LEVEL, GameState.REFUND_SUBSCRIPTION, 2)
	GameState.note_refundable(&"5-2", GameState.REFUND_SUBSCRIPTION, 4)
	assert_true(GameState.spend_attention(2, &"calc"), "Lo gastado en Calc no se devuelve")
	assert_eq(GameState.attention_points, 5)
	var desk: RefundDesk = _desk()
	assert_eq(desk.get_pending(), 5)
	watch_signals(desk)
	assert_eq(desk.claim(), 7, "3 del atajo + 2 drenados + 2 del secreto")
	assert_signal_emitted_with_parameters(desk, "refunded", [5, 2])
	assert_eq(GameState.attention_points, 12)
	assert_eq(desk.get_message(), "Devuelto: 7")
	assert_eq(GameState.get_refundable(&"5-2"), 4, "No toca otros niveles")
	assert_eq(desk.claim(), -1, "Una vez por intento")
	assert_true(desk.is_closed())
	assert_eq(GameState.attention_points, 12)


func test_refund_bonus_is_given_once_per_save() -> void:
	_balance(0)
	var desk: RefundDesk = _desk()
	assert_eq(desk.claim(), 2, "Sin nada que devolver, solo el bonus")
	assert_true(desk.is_bonus_claimed())
	desk.free()
	GameState.begin_attempt()
	var again: RefundDesk = _desk()
	assert_eq(again.claim(), 0, "Otro intento: el bonus ya se dio")
	assert_eq(GameState.attention_points, 2)


func test_refund_desk_by_pulse() -> void:
	_balance(3)
	var door: ShortcutDoor = _door(ShortcutDoor.TRAP_PROCESSING)
	assert_true(door.pay())
	var desk: RefundDesk = _desk()
	assert_true(desk.receive_pulse(_fake_pulse(desk.get_hit_rect().get_center())))
	assert_eq(GameState.attention_points, 5, "Devuelve 3 + 2")


# --- Rollback ---

func test_game_over_rollback_returns_what_was_spent_unsaved() -> void:
	_balance(10)
	var item: ShopItem = _shop(ShopItem.PRODUCT_SYNC)
	assert_eq(item.buy(), ShopItem.RESULT_OK)
	var door: ShortcutDoor = _door(ShortcutDoor.TRAP_PROCESSING)
	assert_true(door.pay())
	assert_eq(GameState.attention_points, 4)
	var report: Dictionary = GameState.apply_rollback()
	assert_true(report.get("had_copy"), "Habia copia")
	assert_eq(int(GameState.get_trash().get(GameState.TRASH_POINTS, 0)), 10, "La copia (con lo gastado) va a la Papelera")
	assert_eq(GameState.get_refundable(LEVEL), 0, "El rollback vacia el registro de Devoluciones")
	assert_true(GameState.recover_trash())
	assert_eq(GameState.attention_points, 10, "Lo gastado sin guardar vuelve")


# --- Sala de prueba ---

func test_tienda_test_room_loads() -> void:
	var scene := load(ROOM_SCENE) as PackedScene
	assert_not_null(scene)
	var room: Node = scene.instantiate()
	add_child_autofree(room)
	await wait_physics_frames(1)
	var count := func(group: StringName) -> int:
		return get_tree().get_nodes_in_group(group).filter(func(n: Node) -> bool: return room.is_ancestor_of(n)).size()
	assert_eq(count.call(ShopItem.GROUP), 2, "Dos productos")
	assert_eq(count.call(ShortcutDoor.GROUP), 2, "Dos atajos")
	assert_eq(count.call(RefundDesk.GROUP), 1, "Devoluciones")
	var traps: Array = get_tree().get_nodes_in_group(ShortcutDoor.GROUP).filter(
		func(n: Node) -> bool: return room.is_ancestor_of(n) and (n as ShortcutDoor).has_trap())
	assert_eq(traps.size(), 1, "Uno con trampa (processing)")
	assert_eq((traps[0] as ShortcutDoor).trap, ShortcutDoor.TRAP_PROCESSING)
