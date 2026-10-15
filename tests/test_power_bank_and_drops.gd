# Power banks y recargas (decisiones del 2026-10-14): el sobrante de energia
# de Debug con la barra llena carga el power bank (capacidad en
# data/power_bank.json); la Burbuja reventada suelta recargas de energia y de
# Sync Rate (data/enemies/alert_bubble.json, drops) que Isak recoge al tocarlas;
# el HUD muestra el contador; los puntos de atencion no se capturan dos veces
# ni reaparecen al rejugar el nivel.
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
var _capacity: float


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	_capacity = GameState.get_power_bank_capacity()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Desbordamiento ---

func test_capacity_comes_from_data() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/power_bank.json"))
	assert_almost_eq(_capacity, float(data["capacity_energy"]), EPS)
	assert_gt(_capacity, 0.0)


func test_overflow_fills_bar_first_then_power_bank() -> void:
	GameState.debug_energy = 90.0
	var overflow: float = GameState.add_debug_energy(25.0)
	assert_almost_eq(GameState.debug_energy, 100.0, EPS, "Primero llena la barra")
	assert_almost_eq(overflow, 15.0, EPS)
	assert_almost_eq(GameState.power_bank_charge, 15.0, EPS, "El sobrante va al power bank")
	assert_eq(GameState.power_banks, 0)


func test_power_bank_completes_and_keeps_remainder() -> void:
	var banks: Array = []
	var on_changed := func(full: int, charge: float, _cap: float) -> void: banks.append([full, charge])
	EventBus.power_banks_changed.connect(on_changed)
	GameState.add_debug_energy(_capacity - 5.0)
	assert_eq(GameState.power_banks, 0)
	GameState.add_debug_energy(30.0)
	EventBus.power_banks_changed.disconnect(on_changed)
	assert_eq(GameState.power_banks, 1, "Se completa uno")
	assert_almost_eq(GameState.power_bank_charge, 25.0, EPS, "Y sigue cargando el siguiente")
	assert_false(banks.is_empty(), "Avisa por EventBus")
	GameState.add_debug_energy(_capacity * 2.0)
	assert_eq(GameState.power_banks, 3, "Varios de golpe")
	assert_almost_eq(GameState.power_bank_charge, 25.0, EPS)


func test_no_overflow_when_bar_has_room() -> void:
	GameState.debug_energy = 10.0
	GameState.add_debug_energy(25.0)
	assert_almost_eq(GameState.debug_energy, 35.0, EPS)
	assert_almost_eq(GameState.power_bank_charge, 0.0, EPS)


func test_attention_point_energy_overflows_too() -> void:
	GameState.add_attention_points(3)
	assert_eq(GameState.attention_points, 3)
	assert_almost_eq(GameState.power_bank_charge, 3.0 * GameState.ENERGY_PER_ATTENTION_POINT, EPS)


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
	bubble.stun()
	# Caida fuerte sobre la Burbuja aturdida: revienta (C7).
	isak.global_position = Vector2(400.0, bubble.get_platform_top_y() - 300.0)
	isak.velocity = Vector2.ZERO
	for i: int in 90:
		sim.step()
		bubble.step(DT)
		if bubble.get_state() == AlertBubble.STATE_POPPED:
			break
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
	# Isak con la barra llena y algo de dano se planta sobre las recargas.
	GameState.debug_energy = GameState.get_debug_energy_max()
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
	assert_almost_eq(GameState.power_bank_charge, 25.0, EPS, "Barra llena: los 25 de energia al power bank")
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


# --- HUD ---

func test_hud_shows_power_banks_only_when_there_are_some() -> void:
	var hud := HUD_SCENE.instantiate() as Hud
	add_child_autofree(hud)
	assert_false(hud.is_power_bank_shown(), "Sin power banks ni carga: oculto")
	GameState.add_power_bank_charge(_capacity * 0.5)
	assert_true(hud.is_power_bank_shown())
	assert_eq(hud.get_power_bank_text(), "x0")
	assert_almost_eq(hud.get_power_bank_charge_ratio(), 0.5, EPS)
	GameState.add_power_bank_charge(_capacity)
	assert_eq(hud.get_power_bank_text(), "x1")
	var glyphs: String = HudConfig.shared().font_glyphs
	for c: String in hud.get_power_bank_text():
		assert_true(glyphs.contains(c), "Glifo '%s' en la fuente del HUD" % c)


func test_hud_sync_percent_shows_real_value_above_100() -> void:
	GameState.attention_points = 30
	GameState.power_banks = 1
	assert_eq(GameState.purchase_upgrade(&"reinforced_sync"), GameState.PurchaseResult.OK)
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
