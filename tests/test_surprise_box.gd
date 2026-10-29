# Caja sorpresa del Mundo 5 (paso 4 de docs/propuesta-mundo-5.md §8; reglas de §3.4 y
# pruebas de §7.4): contenido FIJO en los datos (energia +30, puntos capturados una vez,
# Suscripcion, Oferta o vacia), abrir con el pulso de cara desde el suelo (no de
# espaldas ni mirando a otro lado), con el golpe al suelo encima (no al lado) o con la
# Embestida; el Debug ensena el contenido; el laser la destruye sin abrirla; es solida
# (se pisa); lanzada, el pulso la deja aturdida 3 s como escalon y despues cae y queda
# como una caja normal; el Filo destruye a la aturdida y el Sismo no le hace nada; la
# sala cajas_test carga. Usa su propia ruta de guardado.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BOX_SCENE: PackedScene = preload("res://scenes/levels/surprise_box.tscn")
const ROOM_SCENE: String = "res://scenes/levels/cajas_test.tscn"
const PATH: String = "user://test_surprise_box.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const LEVEL: StringName = &"5-1"

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved_debug: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)
	GameState.begin_attempt()
	GameState.current_level = LEVEL
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = 20.0
	DebugMode.input_enabled = false
	DebugMode.reset()
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
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## Caja en la celda de la columna `col` apoyada en el suelo (y = 0) o a `row` filas.
func _box(content: StringName, col: float = 1.0, row: float = -1.0, id: StringName = &"caja") -> SurpriseBox:
	var box := BOX_SCENE.instantiate() as SurpriseBox
	box.object_id = id
	box.content = content
	box.position = Vector2(col * T, row * T)
	_world.add_child(box)
	box.set_physics_process(false)
	return box


## Pulso de Isak: area hija de Isak (como la del pulso real) centrada en su celular.
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


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_revealing(), "Debug revelando")


# --- Contenido fijo ---

func test_energy_box_gives_30_energy() -> void:
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY)
	watch_signals(box)
	assert_true(box.open())
	assert_almost_eq(GameState.debug_energy, 50.0, 0.001, "+30 de energia")
	assert_true(box.is_opened())
	assert_signal_emitted_with_parameters(box, "opened", [SurpriseBox.CONTENT_ENERGY])
	assert_false(box.open(), "Una sola vez")
	assert_almost_eq(GameState.debug_energy, 50.0, 0.001)
	assert_eq(box.collision_layer, 0, "Abierta deja de ser solida")


func test_points_box_is_captured_once_per_save() -> void:
	GameState.attention_points = 0
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_POINTS, 1.0, -1.0, &"caja_puntos")
	box.amount = 2
	assert_true(box.open())
	assert_eq(GameState.attention_points, 2, "+2 puntos")
	assert_true(GameState.is_attention_point_captured(LEVEL, &"box:caja_puntos"), "Se captura como un punto")
	assert_true(GameState.has_unsaved_changes(), "Sin guardar")
	var again: SurpriseBox = _box(SurpriseBox.CONTENT_POINTS, 3.0, -1.0, &"caja_puntos")
	again.amount = 2
	assert_eq(again.get_effective_content(), SurpriseBox.CONTENT_EMPTY, "Ya capturados: vacia (la ayuda no miente)")
	again.open()
	assert_eq(GameState.attention_points, 2, "No da puntos otra vez")


func test_subscription_and_offer_boxes_release_them() -> void:
	var sub_box: SurpriseBox = _box(SurpriseBox.CONTENT_SUBSCRIPTION, 4.0)
	var offer_box: SurpriseBox = _box(SurpriseBox.CONTENT_OFFER, 8.0)
	sub_box.open()
	offer_box.open()
	var sub := sub_box.get_released() as Subscription
	assert_not_null(sub, "Sale una Suscripcion")
	assert_eq(sub.get_state(), Subscription.STATE_ALERT, "Sale avisando (y luego persigue)")
	assert_almost_eq(sub.global_position.x, sub_box.get_body_rect().get_center().x, 0.5)
	var offer := offer_box.get_released() as OfferSign
	assert_not_null(offer, "Sale una Oferta")
	assert_true(offer.is_awake())
	assert_almost_eq(offer.global_position.y, 0.0, 0.5, "De pie en el suelo")


func test_empty_box_gives_nothing() -> void:
	GameState.attention_points = 4
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_EMPTY)
	assert_true(box.open())
	assert_eq(GameState.attention_points, 4)
	assert_almost_eq(GameState.debug_energy, 20.0, 0.001)
	assert_null(box.get_released())


func test_content_is_fixed_in_the_data() -> void:
	for i: int in 3:
		var box: SurpriseBox = _box(SurpriseBox.CONTENT_SUBSCRIPTION, 2.0 + 2.0 * i)
		assert_eq(box.get_effective_content(), SurpriseBox.CONTENT_SUBSCRIPTION, "Siempre la misma (nunca aleatoria)")
	var bad: SurpriseBox = _box(&"lottery", 10.0)
	assert_eq(bad.content, SurpriseBox.CONTENT_EMPTY, "Un contenido desconocido es una caja vacia")


# --- Abrir ---

func test_pulse_facing_it_from_the_floor_opens_it() -> void:
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY, 1.0)
	_isak.facing = -1.0
	assert_false(box.receive_pulse(_isak_pulse()), "Mirando a otro lado no la abre")
	assert_true(box.is_closed())
	_isak.facing = 1.0
	assert_true(box.receive_pulse(_isak_pulse()), "De cara la abre")
	assert_true(box.is_opened())


func test_pulse_facing_back_or_in_the_air_does_not_open_it() -> void:
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY, 1.0)
	_isak.facing = 1.0
	assert_true(_isak.face_back())
	assert_false(box.receive_pulse(_isak_pulse()), "De espaldas no (eso es pagar)")
	_isak.face_side()
	_isak.global_position = Vector2(0.0, -40.0)
	_isak.velocity = Vector2.ZERO
	_sim.step()
	assert_false(_isak.is_on_floor())
	assert_false(box.receive_pulse(_isak_pulse()), "En el aire no")
	assert_true(box.is_closed())
	assert_false(box.receive_pulse(_fake_pulse(Vector2(12.0 * T, -T))), "Lejos no la alcanza")


func test_ground_pound_on_top_opens_it_but_not_beside() -> void:
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY, 3.0)
	var top: float = box.get_body_rect().position.y
	_isak.global_position = Vector2(1.5 * T, 0.0)
	EventBus.ground_pound_landed.emit(Rect2(0.0, -64.0, 4.0 * T, 72.0), _isak)
	assert_true(box.is_closed(), "Golpe al lado: la onda no la abre")
	GroundPoundWave.apply_to_enemies(get_tree(), Rect2(0.0, -64.0, 6.0 * T, 72.0), 1.0)
	assert_true(box.is_closed(), "Tampoco la onda de GroundPoundWave")
	_isak.global_position = Vector2(box.get_body_rect().get_center().x, top)
	EventBus.ground_pound_landed.emit(Rect2(), _isak)
	assert_true(box.is_opened(), "Golpe al suelo encima: se abre")


func test_real_ground_pound_on_top_opens_it() -> void:
	var had: bool = GameState.is_ability_unlocked(GameState.ABILITY_GROUND_POUND)
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, true)
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY, 1.0)
	_isak.global_position = Vector2(box.get_body_rect().get_center().x, -3.0 * T)
	_isak.velocity = Vector2.ZERO
	_sim.step(_sim.frames(0.1))
	_sim.input.hold_held = true
	var steps: int = _sim.step_until(func() -> bool: return box.is_opened(), _sim.frames(2.0))
	_sim.input.hold_held = false
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, had)
	assert_true(box.is_opened(), "Golpe al suelo real sobre la tapa (%d pasos)" % steps)


func test_ram_opens_it() -> void:
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY, 1.0)
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_RAM, Rect2(-T, -T, 4.0 * T, 2.0 * T), 2.0, 3.0)
	assert_true(box.is_opened(), "La Embestida la abre")


# --- Debug y laser ---

func test_debug_shows_what_is_inside() -> void:
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_SUBSCRIPTION, 1.0)
	assert_false(box.is_revealed(), "Sin Debug no se ve")
	_activate_debug()
	assert_true(box.is_revealed(), "Con el Debug se ve dentro")
	assert_eq(box.get_effective_content(), SurpriseBox.CONTENT_SUBSCRIPTION)
	box.open()
	assert_false(box.is_revealed(), "Abierta ya no hay nada que ver")


func test_laser_destroys_it_and_the_content_is_lost() -> void:
	var good: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY, 1.0)
	var bad: SurpriseBox = _box(SurpriseBox.CONTENT_SUBSCRIPTION, 4.0)
	watch_signals(good)
	good.on_laser_hit(1.0, _isak)
	bad.on_laser_hit(1.0, _isak)
	assert_true(good.is_destroyed())
	assert_signal_emitted(good, "destroyed")
	assert_signal_not_emitted(good, "opened")
	assert_almost_eq(GameState.debug_energy, 20.0, 0.001, "Lo bueno se pierde")
	assert_true(bad.is_destroyed())
	assert_null(bad.get_released(), "Y lo malo tambien")
	assert_false(good.open(), "Destruida no se abre")


# --- Solida, lanzada y aturdida ---

func test_isak_can_stand_on_the_box() -> void:
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_EMPTY, 1.0)
	_isak.global_position = Vector2(box.get_body_rect().get_center().x, -3.0 * T)
	_isak.velocity = Vector2.ZERO
	_sim.step(_sim.frames(1.0))
	assert_true(_isak.is_on_floor())
	assert_almost_eq(_isak.global_position.y, box.get_body_rect().position.y, 1.5, "De pie sobre la tapa")


func test_stunned_launched_box_is_a_step_for_3_seconds() -> void:
	var box: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY, 1.0, -5.0)
	box.launch(Vector2.ZERO)
	assert_true(box.is_flying())
	assert_false(box.is_solid(), "Lanzada no es solida")
	box.step(DT)
	assert_true(box.receive_pulse(_fake_pulse(box.get_body_rect().get_center())), "El pulso la alcanza")
	assert_true(box.is_stunned(), "Aturdida, no abierta")
	assert_true(box.is_closed())
	assert_almost_eq(box.get_stun_left(), 3.0, 0.001)
	var y0: float = box.global_position.y
	_isak.global_position = Vector2(box.get_body_rect().get_center().x, box.get_body_rect().position.y - 100.0)
	_isak.velocity = Vector2.ZERO
	for i: int in _sim.frames(2.5):
		_sim.step()
		box.step(DT)
	assert_almost_eq(box.global_position.y, y0, 0.01, "Inerte en el aire")
	assert_true(_isak.is_on_floor(), "Isak se apoya en ella")
	assert_almost_eq(_isak.global_position.y, box.get_body_rect().position.y, 1.5, "Sirve de escalon")
	for i: int in _sim.frames(0.6):
		box.step(DT)
	assert_true(box.is_flying(), "A los 3 s sigue cayendo")
	_isak.global_position = Vector2(-4.0 * T, 0.0)
	for i: int in _sim.frames(2.0):
		box.step(DT)
	assert_eq(box.get_state(), SurpriseBox.STATE_CLOSED, "En el suelo queda como una caja normal")
	assert_almost_eq(box.get_body_rect().end.y, 0.0, 1.0)
	assert_true(box.is_solid())


func test_resting_box_ignores_stun_and_quake_but_edge_breaks_a_stunned_one() -> void:
	var resting: SurpriseBox = _box(SurpriseBox.CONTENT_ENERGY, 1.0)
	resting.stun()
	assert_eq(resting.get_state(), SurpriseBox.STATE_CLOSED, "En reposo no se aturde")
	var wide := Rect2(-2000.0, -1000.0, 4000.0, 1200.0)
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_QUAKE, wide, 0.0, 3.0)
	assert_eq(resting.get_state(), SurpriseBox.STATE_CLOSED, "El Sismo no le hace nada")
	ComboWave.defeat_small(get_tree(), wide, 1.0, {})
	assert_true(resting.is_closed(), "El Filo no rompe una caja en reposo")
	var flying: SurpriseBox = _box(SurpriseBox.CONTENT_SUBSCRIPTION, 6.0, -5.0)
	flying.launch(Vector2.ZERO)
	flying.stun()
	ComboWave.defeat_small(get_tree(), wide, 1.0, {})
	assert_true(flying.is_destroyed(), "El Filo destruye a la aturdida (vida 1)")
	assert_null(flying.get_released())


# --- Sala de prueba ---

func test_cajas_test_room_loads() -> void:
	var scene := load(ROOM_SCENE) as PackedScene
	assert_not_null(scene, "Existe la escena de la sala")
	var room: Node = scene.instantiate()
	add_child_autofree(room)
	await wait_physics_frames(1)
	var contents: Array = []
	for node: Node in get_tree().get_nodes_in_group(SurpriseBox.GROUP):
		if room.is_ancestor_of(node):
			contents.append((node as SurpriseBox).content)
	assert_eq(contents.size(), 4, "Cuatro cajas")
	for c: StringName in [SurpriseBox.CONTENT_ENERGY, SurpriseBox.CONTENT_POINTS, SurpriseBox.CONTENT_SUBSCRIPTION,
			SurpriseBox.CONTENT_EMPTY]:
		assert_true(contents.has(c), "Caja de %s" % c)
	var subs: int = 0
	for node: Node in get_tree().get_nodes_in_group(Subscription.SUBSCRIPTION_GROUP):
		if room.is_ancestor_of(node):
			subs += 1
	assert_eq(subs, 1, "Una Suscripcion dormida")
	var doors: Array = get_tree().get_nodes_in_group(ShortcutDoor.GROUP).filter(
		func(n: Node) -> bool: return room.is_ancestor_of(n))
	assert_eq(doors.size(), 1)
	assert_eq((doors[0] as ShortcutDoor).trap, ShortcutDoor.TRAP_SUBSCRIPTION)
