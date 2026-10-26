# Power banks y recargas (decisiones del 2026-10-14; power bank coleccionable
# puro desde el 2026-10-25, mas pruebas en test_power_bank_collectible.gd): el
# sobrante de energia de Debug con la barra llena se pierde; la Burbuja
# reventada suelta recargas de energia y de Sync Rate
# (data/enemies/alert_bubble.json, drops) que Isak recoge al tocarlas; el power
# bank de mapa llega completo una sola vez; los puntos de atencion no se
# capturan dos veces ni reaparecen al rejugar el nivel.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const BUBBLE_DATA: String = "res://data/enemies/alert_bubble.json"
const PATH: String = "user://test_power_bank_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Desbordamiento (el sobrante se pierde) ---

func test_overflow_fills_bar_and_rest_is_lost() -> void:
	GameState.debug_energy = 90.0
	var overflow: float = GameState.add_debug_energy(25.0)
	assert_almost_eq(GameState.debug_energy, 100.0, EPS, "Primero llena la barra")
	assert_almost_eq(overflow, 15.0, EPS, "El resto se pierde")
	assert_eq(GameState.power_banks, 0, "No carga power banks")


func test_no_overflow_when_bar_has_room() -> void:
	GameState.debug_energy = 10.0
	assert_almost_eq(GameState.add_debug_energy(25.0), 0.0, EPS)
	assert_almost_eq(GameState.debug_energy, 35.0, EPS)


func test_attention_point_energy_does_not_overflow() -> void:
	GameState.add_attention_points(3)
	assert_eq(GameState.attention_points, 3)
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS)
	assert_eq(GameState.power_banks, 0, "Los puntos no dan power banks")
	GameState.debug_energy = 0.0
	GameState.add_attention_points(1)
	assert_almost_eq(GameState.debug_energy, GameState.ENERGY_PER_ATTENTION_POINT, EPS, "Pero si llenan la barra")


func test_sync_heal_is_capped_at_effective_max() -> void:
	GameState.sync_rate = 95.0
	GameState.heal_sync(10.0)
	assert_almost_eq(GameState.sync_rate, 100.0, EPS)


# --- Burbuja: drops ---

func _flat_world() -> Array:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	add_child_autofree(world)
	sim.take_manual_control()
	return [sim, world]


func test_bubble_drops_come_from_its_json() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUBBLE_DATA))
	var drops: Dictionary = data["drops"]
	assert_almost_eq(float(drops["debug_energy"]), 25.0, EPS)
	assert_almost_eq(float(drops["sync_rate"]), 10.0, EPS)


func test_popping_bubble_drops_recharges_that_isak_collects() -> void:
	var parts: Array = _flat_world()
	var sim: IsakSim = parts[0]
	var world: Node2D = parts[1]
	var isak: Isak = sim.isak
	isak.global_position = Vector2(-2000.0, 0.0)
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	bubble.position = Vector2(400.0, 0.0)
	bubble.free_on_pop = false
	bubble.target = isak
	world.add_child(bubble)
	bubble.set_physics_process(false)
	await wait_physics_frames(1)
	sim.settle()
	# Muere al quedarse sin vida (laser, 2026-10-15; la caida ya no la revienta).
	for i: int in roundi(bubble.get_max_health()):
		bubble.on_laser_hit(1.0, isak)
	assert_eq(bubble.get_state(), AlertBubble.STATE_POPPED)
	var pickups: Array[Node] = get_tree().get_nodes_in_group(RechargePickup.GROUP)
	assert_eq(pickups.size(), 2, "Suelta energia y Sync Rate")
	var kinds: Dictionary = {}
	for node: Node in pickups:
		var p := node as RechargePickup
		kinds[p.kind] = p.amount
		assert_eq(p.get_parent(), world, "Junto al enemigo, no dentro (se libera)")
	assert_almost_eq(float(kinds[RechargePickup.KIND_ENERGY]), bubble.drops["debug_energy"], EPS)
	assert_almost_eq(float(kinds[RechargePickup.KIND_SYNC]), bubble.drops["sync_rate"], EPS)
	# Isak con la barra casi llena y algo de dano se planta sobre las recargas.
	GameState.debug_energy = GameState.get_debug_energy_max() - 10.0
	GameState.sync_rate = 80.0
	var collected: Array = []
	var on_collected := func(kind: StringName, amount: float) -> void: collected.append(kind)
	EventBus.recharge_collected.connect(on_collected)
	for node: Node in pickups:
		isak.global_position = (node as Node2D).global_position + Vector2(0.0, 40.0)
		isak.velocity = Vector2.ZERO
		await wait_physics_frames(30)
	EventBus.recharge_collected.disconnect(on_collected)
	assert_eq(collected.size(), 2, "Isak recoge las dos al tocarlas")
	assert_almost_eq(GameState.sync_rate, 90.0, EPS, "+10 de Sync Rate")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS, "Llena la barra; el resto se pierde")
	assert_eq(GameState.power_banks, 0, "Sin power banks del sobrante")
	assert_eq(get_tree().get_nodes_in_group(RechargePickup.GROUP).filter(
		func(n: Node) -> bool: return not n.is_queued_for_deletion()).size(), 0, "Se liberan")


func test_pickup_waits_arm_delay() -> void:
	var holder := Node2D.new()
	add_child_autofree(holder)
	var spawned: Array[RechargePickup] = RechargePickup.spawn_drops(holder, Vector2.ZERO, {"debug_energy": 5.0})
	assert_eq(spawned.size(), 1)
	var p: RechargePickup = spawned[0]
	assert_false(p.is_armed(), "Recien salida no se recoge")
	p.advance(float(RechargePickup.data()["arm_delay_s"]) + 0.01)
	assert_true(p.is_armed())
	GameState.debug_energy = 50.0
	assert_true(p.collect())
	assert_false(p.collect(), "Una sola vez")
	assert_almost_eq(GameState.debug_energy, 55.0, EPS)


# --- HUD (contador de power banks: test_power_bank_collectible.gd) ---

func test_hud_sync_percent_shows_real_value_above_100() -> void:
	GameState.attention_points = 150
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.OK, "Sync Rate 3: maximo 120")
	var hud := HUD_SCENE.instantiate() as Hud
	add_child_autofree(hud)
	GameState.sync_rate = 120.0
	assert_eq(hud.get_sync_text(), "120 %")
	assert_almost_eq(hud.get_sync_ratio(), 1.0, EPS)
	GameState.sync_rate = 60.0
	assert_eq(hud.get_sync_text(), "60 %")


# --- Puntos de atencion: no se repiten ---

func test_same_point_counts_only_once() -> void:
	assert_true(GameState.capture_attention_point(&"1-1", &"Point_8_9", 1))
	assert_false(GameState.capture_attention_point(&"1-1", &"Point_8_9", 1), "Ya capturado")
	assert_eq(GameState.attention_points, 1)
	assert_true(GameState.capture_attention_point(&"1-2", &"Point_8_9", 1), "Otro nivel, otro mapa")
	assert_eq(GameState.attention_points, 2)


func test_captured_points_do_not_reappear_when_replaying() -> void:
	var level := LEVEL_SCENE.instantiate() as GeneratedLevel
	add_child(level)
	var points: Node = level.get_node(^"AttentionPoints")
	var total: int = points.get_child_count()
	var first := points.get_child(0) as AttentionPoint
	var first_id: StringName = first.get_point_id()
	assert_eq(first.get_level_id(), &"1-1")
	var isak: Isak = level.get_isak()
	first._on_body_entered(isak)
	assert_eq(GameState.attention_points, 1)
	assert_true(GameState.is_attention_point_captured(&"1-1", first_id))
	level.free()
	# Rejugar: el punto capturado no aparece y no puede volver a contar.
	level = LEVEL_SCENE.instantiate() as GeneratedLevel
	add_child(level)
	points = level.get_node(^"AttentionPoints")
	var alive: int = 0
	for node: Node in points.get_children():
		if not node.is_queued_for_deletion():
			alive += 1
	assert_eq(alive, total - 1, "El punto capturado no reaparece")
	assert_eq(GameState.attention_points, 1, "Ni cuenta otra vez")
	level.free()


## Un power bank de mapa dentro de un nivel generado. El 1-1 ya no tiene ninguno
## (2026-10-15: aparecen desde el 1-2, con el Debug), asi que se anade a su escena.
func _level_with_pickup() -> GeneratedLevel:
	var level := LEVEL_SCENE.instantiate() as GeneratedLevel
	var pickup := (load("res://scenes/levels/power_bank_pickup.tscn") as PackedScene).instantiate() as PowerBankPickup
	pickup.name = "power_bank_a"
	pickup.object_id = &"power_bank_a"
	level.get_node(^"Objects").add_child(pickup)
	add_child(level)
	return level


func test_map_power_bank_pickup_in_level_gives_full_bank_once() -> void:
	var level: GeneratedLevel = _level_with_pickup()
	var pickup := level.get_node(^"Objects/power_bank_a") as PowerBankPickup
	assert_not_null(pickup, "Power bank de mapa en un nivel generado")
	assert_eq(pickup.get_level_id(), &"1-1")
	assert_eq(pickup.get_pickup_id(), &"power_bank_a")
	pickup._on_body_entered(level.get_isak())
	assert_true(pickup.is_taken())
	assert_eq(GameState.power_banks, 1, "Llega completo")
	assert_true(GameState.is_pickup_collected(&"1-1", &"power_bank_a"))
	assert_true((GameState.to_save_data()["collected_pickups"] as Dictionary).has("1-1"), "Se guarda")
	level.free()
	# Rejugar: el power bank recogido no reaparece.
	level = _level_with_pickup()
	var again: Node = level.get_node_or_null(^"Objects/power_bank_a")
	assert_true(again == null or again.is_queued_for_deletion(), "No reaparece")
	assert_eq(GameState.power_banks, 1)
	level.free()
