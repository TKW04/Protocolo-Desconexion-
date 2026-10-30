# Obstaculos de los combos y «Prueba gratis» del Mundo 5 (paso 6 de
# docs/propuesta-mundo-5.md §8; reglas de §3.7, anti-redundancia de §3.9 y pruebas de
# §7.4): cada obstaculo SOLO cede a su combo y a ninguna otra habilidad. Persiana:
# golpe al suelo, pulso, laser y Sismo rebotan; la Embestida la rompe (para siempre en
# el intento) y su onda sigue por debajo. Ranura de precios: de pie, comprimido, con el
# dash o con la Embestida, empuja hacia atras; el Filo la cruza. Estanterias de saldos:
# cada golpe suelto (golpe al suelo, Embestida, pulso, laser) se repone a los 0,5 s; el
# Sismo tumba el grupo entero para siempre. «Prueba gratis»: pulso de espaldas, la
# Combinacion, la escena con Eco e Isak (interlocutor y estilo isak), un uso, inerte con
# la Combinacion ya obtenida y cerrada tras perderla. Isak avanza paso a paso con delta
# fijo; los objetos, a mano. Usa su propia ruta de guardado.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const SHUTTER_SCENE: PackedScene = preload("res://scenes/levels/shutter.tscn")
const RAIL_SCENE: PackedScene = preload("res://scenes/levels/price_rail.tscn")
const SHELF_SCENE: PackedScene = preload("res://scenes/levels/clearance_shelf.tscn")
const BOX_SCENE: PackedScene = preload("res://scenes/levels/free_trial_box.tscn")
const TEXT_BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const ROOM_SCENE: String = "res://scenes/levels/combos_test.tscn"
const PATH: String = "user://test_combo_obstacles.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const T: float = 64.0
const ABILITIES: Array[StringName] = [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DASH,
	GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]


## Enemigo de prueba (como el de tests/test_combo.gd): cuerpo de 48 x 64 con los pies en su posicion.
class FakeEnemy:
	extends Node2D
	var size := Vector2(48.0, 64.0)
	var health: float = 3.0
	var stun_duration_s: float = 1.5
	var stuns: Array = []
	var damage_taken: float = 0.0

	func _ready() -> void:
		add_to_group(&"enemy")

	func get_body_rect() -> Rect2:
		return Rect2(global_position + Vector2(-size.x * 0.5, -size.y), size)

	func stun(duration_scale: float = 1.0) -> void:
		stuns.append(duration_scale)

	func get_health() -> float:
		return health

	func take_damage(amount: float) -> bool:
		if health <= 0.0:
			return false
		health -= amount
		damage_taken += amount
		return true


var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}
var _rails: Array[PriceRail] = []
var _shelves: Array[ClearanceShelf] = []
var _pushes: Array = []
var _pause_important: bool = true


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.begin_attempt()
	_saved = {}
	for ability: StringName in ABILITIES:
		_saved[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	_rails = []
	_shelves = []
	_pushes = []
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
	GameState.begin_attempt()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

## Avanza Isak `count` pasos; las ranuras miran a Isak y las estanterias avanzan.
func _step(count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for rail: PriceRail in _rails:
			rail.check_isak(_isak)
		for shelf: ClearanceShelf in _shelves:
			shelf.advance(DT)


func _step_until(condition: Callable, seconds: float = 3.0) -> void:
	for i: int in _sim.steps_for(seconds):
		if condition.call():
			return
		_step()


func _shutter(pos: Vector2, length: int, orientation: StringName = Shutter.ORIENT_FLOOR) -> Shutter:
	var s := SHUTTER_SCENE.instantiate() as Shutter
	s.length_tiles = length
	s.orientation = orientation
	s.position = pos
	_world.add_child(s)
	s.set_process(false)
	return s


func _rail(left: float) -> PriceRail:
	var rail := RAIL_SCENE.instantiate() as PriceRail
	rail.width_tiles = 4
	rail.height_tiles = 4
	rail.slot_row = 2
	# De y = -4T al suelo (y = 0): ranura de -2T a -T, etiquetas por encima y por debajo.
	rail.position = Vector2(left, -4.0 * T)
	_world.add_child(rail)
	rail.set_physics_process(false)
	rail.pushed.connect(func(dir: float) -> void: _pushes.append(dir))
	_rails.append(rail)
	return rail


func _shelf(col: float, group: StringName, height: int = 2) -> ClearanceShelf:
	var shelf := SHELF_SCENE.instantiate() as ClearanceShelf
	shelf.group_id = group
	shelf.height_tiles = height
	shelf.position = Vector2(col * T, -float(height) * T)
	_world.add_child(shelf)
	shelf.set_physics_process(false)
	_shelves.append(shelf)
	return shelf


func _enemy(at: Vector2) -> FakeEnemy:
	var enemy := FakeEnemy.new()
	enemy.position = at
	_world.add_child(enemy)
	return enemy


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


## Pulso en el celular de Isak (como PulseArea).
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
	_step(4)


func _press_dash(axis: float) -> void:
	_sim.input.move_axis = axis
	_sim.input.dash_pressed = true
	_step()
	_sim.input.move_axis = 0.0


## Dispara el laser y lo hace volar hasta que acabe (como tests/test_terms_gate.gd).
func _fire() -> LaserProjectile:
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


## Golpe al suelo en el sitio (mantener abajo en el suelo).
func _ground_pound() -> void:
	_sim.input.hold_held = true
	_step(_sim.frames(0.6))
	_sim.input.hold_held = false
	_step_until(func() -> bool: return _sim.state() != PlayerState.GROUND_POUND, 1.0)
	_step(5)


## Embestida: salto, dash aereo hacia `axis` y abajo hasta aterrizar.
func _ram(axis: float = 1.0) -> void:
	_sim.press_jump()
	_step(12)
	_press_dash(axis)
	assert_eq(_sim.state(), PlayerState.DASH, "Dash aereo")
	_sim.input.hold_held = true
	_step_until(func() -> bool: return _sim.state() != PlayerState.DASH, 0.5)
	assert_eq(_sim.state(), PlayerState.COMBO_RAM, "Embestida")


## Sismo: salto, Pellizcar y abajo hasta aterrizar.
func _quake() -> void:
	_sim.press_jump()
	_step(12)
	_sim.input.pinch_pressed = true
	_step()
	assert_true(_isak.is_compressed(), "Comprimido en el aire")
	_sim.input.hold_held = true
	_step(_sim.frames(0.1) + 1)
	assert_eq(_sim.state(), PlayerState.COMBO_QUAKE, "Sismo")
	_step_until(func() -> bool: return _sim.state() != PlayerState.COMBO_QUAKE, 2.0)
	_sim.input.hold_held = false
	_step(3)


# --- Persiana ---

func test_shutter_only_the_ram_breaks_it() -> void:
	var s: Shutter = _shutter(Vector2(0.0, -T), 2)
	watch_signals(s)
	var rect: Rect2 = s.get_shutter_rect()
	EventBus.ground_pound_landed.emit(rect.grow(4.0), _isak)
	assert_signal_emitted_with_parameters(s, "deflected", [Shutter.BY_POUND])
	assert_true(s.receive_pulse(_fake_pulse(rect.get_center())), "El pulso la alcanza")
	assert_signal_emitted_with_parameters(s, "deflected", [Shutter.BY_PULSE])
	s.on_laser_hit(1.0, null)
	assert_signal_emitted_with_parameters(s, "deflected", [Shutter.BY_LASER])
	EventBus.combo_landed.emit(Isak.COMBO_QUAKE, rect.grow(4.0), _isak)
	assert_signal_emitted_with_parameters(s, "deflected", [Shutter.BY_QUAKE])
	ComboWave.defeat_small(get_tree(), rect, 1.0, {})
	ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_RAM, rect.grow(4.0), 2.0, 3.0)
	assert_false(s.is_broken(), "Golpe al suelo, pulso, laser, Sismo, Filo y la onda a los enemigos rebotan")
	assert_true(s.is_solid())
	assert_eq(s.collision_layer, Shutter.LAYER_WORLD)
	EventBus.combo_landed.emit(Isak.COMBO_RAM, Rect2(rect.position.x - 200.0, rect.position.y - 64.0, 100.0, 72.0), _isak)
	assert_false(s.is_broken(), "Una Embestida lejos no")
	EventBus.combo_landed.emit(Isak.COMBO_RAM, rect.grow(4.0), _isak)
	assert_true(s.is_broken(), "Solo la Embestida la rompe")
	assert_signal_emitted(s, "broken")
	assert_eq(s.collision_layer, 0, "Rota deja pasar")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_true(s.is_broken(), "Para siempre en el intento (reaparecer no la repone)")


func test_real_ground_pound_and_quake_bounce_off_a_floor_shutter() -> void:
	var s: Shutter = _shutter(Vector2(-4.0 * T, -2.0 * T), 8)
	await wait_physics_frames(1)
	watch_signals(s)
	_place(Vector2(0.0, -2.0 * T))
	assert_true(_isak.is_on_floor(), "De pie en la persiana")
	_ground_pound()
	assert_signal_emitted_with_parameters(s, "deflected", [Shutter.BY_POUND])
	_quake()
	assert_signal_emitted_with_parameters(s, "deflected", [Shutter.BY_QUAKE])
	assert_false(s.is_broken())
	assert_almost_eq(_isak.global_position.y, -2.0 * T, 1.0, "Isak sigue encima")


func test_real_ram_breaks_the_floor_shutter_and_its_wave_reaches_below() -> void:
	var s: Shutter = _shutter(Vector2(-T, -2.0 * T), 8)
	await wait_physics_frames(1)
	_place(Vector2(0.0, -2.0 * T))
	assert_true(_isak.is_on_floor(), "De pie en la persiana")
	var under: FakeEnemy = _enemy(Vector2(3.0 * T, 0.0))
	_ram(1.0)
	_step_until(func() -> bool: return s.is_broken(), 2.0)
	assert_true(s.is_broken(), "La Embestida la rompe al aterrizar")
	_sim.input.hold_held = false
	assert_eq(under.stuns.size(), 1, "La onda sigue hasta lo de debajo")
	assert_almost_eq(under.damage_taken, 2.0, EPS, "Con el dano de la Embestida")
	_step_until(func() -> bool: return _isak.is_on_floor() and _isak.global_position.y > -T, 2.0)
	assert_almost_eq(_isak.global_position.y, 0.0, 1.0, "Isak cae a lo de debajo")


func test_wall_shutter_breaks_with_a_ram_landing_next_to_it() -> void:
	var s: Shutter = _shutter(Vector2(3.0 * T, -3.0 * T), 3, Shutter.ORIENT_WALL)
	assert_eq(s.get_size(), Vector2(T, 3.0 * T), "De pared: 1 x 3")
	await wait_physics_frames(1)
	_ram(1.0)
	_step_until(func() -> bool: return _isak.is_on_floor(), 2.0)
	_step(2)
	_sim.input.hold_held = false
	assert_true(s.is_broken(), "La onda de la Embestida que aterriza junto a ella la rompe")


# --- Ranura de precios ---

func test_rail_geometry() -> void:
	var rail: PriceRail = _rail(3.0 * T)
	assert_eq(rail.get_rail_rect(), Rect2(3.0 * T + 32.0, -4.0 * T, 4.0 * T - 64.0, 4.0 * T))
	assert_eq(rail.get_slot_rect(), Rect2(3.0 * T + 32.0, -2.0 * T, 4.0 * T - 64.0, T), "Ranura de 1 tile")
	assert_eq(rail.get_tag_rects().size(), 2, "Etiquetas por encima y por debajo")


func test_rail_pushes_back_standing_compressed_dash_and_ram() -> void:
	var rail: PriceRail = _rail(3.0 * T)
	var left: float = rail.get_rail_rect().position.x
	# De pie, andando.
	_place(Vector2(T, 0.0))
	_sim.input.move_axis = 1.0
	_step(_sim.frames(1.5))
	_sim.input.move_axis = 0.0
	assert_false(_pushes.is_empty(), "Andando la toca y la empuja")
	assert_lt(_isak.global_position.x, left, "De pie no pasa")
	# Comprimido, andando.
	_pushes.clear()
	_place(Vector2(T, 0.0))
	_sim.input.pinch_pressed = true
	_step()
	assert_true(_isak.is_compressed())
	_sim.input.move_axis = 1.0
	_step(_sim.frames(2.0))
	_sim.input.move_axis = 0.0
	assert_false(_pushes.is_empty(), "Comprimido por el suelo tambien")
	assert_lt(_isak.global_position.x, left)
	_sim.input.pinch_pressed = true
	_step(3)
	# Salto y dash aereo (de pie no cabe por la ranura).
	_pushes.clear()
	_place(Vector2(T, 0.0))
	_sim.press_jump()
	_step(14)
	_press_dash(1.0)
	_step_until(func() -> bool: return _isak.is_on_floor(), 2.0)
	assert_false(_pushes.is_empty(), "El dash no la cruza")
	assert_lt(_isak.global_position.x, left)
	# Embestida.
	_pushes.clear()
	_place(Vector2(0.0, 0.0))
	_ram(1.0)
	_step_until(func() -> bool: return _isak.is_on_floor(), 2.0)
	_sim.input.hold_held = false
	assert_false(_pushes.is_empty(), "La Embestida tampoco")
	assert_lt(_isak.global_position.x, left)
	assert_eq(_pushes[0], -1.0, "Hacia atras (por donde llego)")


func test_rail_ignores_pulse_laser_and_ground_pound() -> void:
	var rail: PriceRail = _rail(2.0 * T)
	_place(Vector2(T, 0.0))
	_isak.facing = 1.0
	_sim.input.pulse_pressed = true
	_step(_sim.frames(0.6))
	assert_not_null(_fire(), "Dispara")
	_ground_pound()
	assert_eq(_pushes, [], "Nada de eso la toca ni la cambia")
	_sim.input.move_axis = 1.0
	_step(_sim.frames(1.5))
	_sim.input.move_axis = 0.0
	assert_false(_pushes.is_empty(), "Sigue empujando")
	assert_lt(_isak.global_position.x, rail.get_rail_rect().position.x)


func test_rail_only_the_edge_crosses_the_slot() -> void:
	var rail: PriceRail = _rail(3.0 * T)
	var tags: Rect2 = rail.get_rail_rect()
	# Comprimido junto a la hilera, salto comprimido y, al bajar a la altura de la ranura, Filo.
	_place(Vector2(tags.position.x - 20.0, 0.0))
	_sim.input.pinch_pressed = true
	_step()
	assert_true(_isak.is_compressed())
	_sim.press_jump()
	_step_until(func() -> bool: return _isak.velocity.y > 0.0 and _isak.global_position.y >= -82.0, 1.0)
	var feet_y: float = _isak.global_position.y
	assert_between(feet_y, -88.0, -64.0, "A la altura de la ranura")
	_press_dash(1.0)
	assert_eq(_sim.state(), PlayerState.COMBO_EDGE, "Filo")
	_step_until(func() -> bool: return _isak.is_on_floor(), 2.0)
	assert_eq(_pushes, [], "El Filo cabe por la ranura sin tocar las etiquetas")
	assert_gt(_isak.global_position.x - _isak.get_hitbox_size().x * 0.5, tags.end.x, "Ha cruzado la hilera")


# --- Estanterias de saldos ---

func test_single_hits_restock_after_half_a_second() -> void:
	var a: ClearanceShelf = _shelf(-8.0, &"g")
	var b: ClearanceShelf = _shelf(3.0, &"g")
	var c: ClearanceShelf = _shelf(8.0, &"g")
	assert_true(a.is_solid())
	# Golpe al suelo.
	EventBus.ground_pound_landed.emit(a.get_shelf_rect().grow(8.0), _isak)
	assert_true(a.is_down(), "Un golpe la tumba")
	assert_true(b.is_standing() and c.is_standing())
	assert_eq(a.collision_layer, 0, "Tumbada no estorba")
	_step(_sim.frames(0.4))
	assert_true(a.is_down(), "Aun tumbada a los 0,4 s")
	_step(_sim.frames(0.15))
	assert_true(a.is_standing(), "Se repone a los 0,5 s")
	assert_eq(a.collision_layer, ClearanceShelf.LAYER_WORLD)
	# Embestida, pulso y laser: lo mismo.
	EventBus.combo_landed.emit(Isak.COMBO_RAM, b.get_shelf_rect().grow(8.0), _isak)
	assert_true(b.is_down(), "La Embestida la tumba")
	assert_true(c.receive_pulse(_fake_pulse(c.get_shelf_rect().get_center())), "El pulso la alcanza")
	assert_true(c.is_down())
	_step(_sim.frames(0.6))
	assert_true(b.is_standing() and c.is_standing(), "Se reponen")
	a.on_laser_hit(1.0, null)
	assert_true(a.is_down(), "El laser la tumba")
	_step(_sim.frames(0.6))
	assert_true(a.is_standing())
	assert_false(a.is_cleared() or b.is_cleared() or c.is_cleared(), "Ninguna cae para siempre")


func test_hits_spread_over_more_than_half_a_second_never_clear_the_group() -> void:
	var a: ClearanceShelf = _shelf(-8.0, &"g")
	var b: ClearanceShelf = _shelf(3.0, &"g")
	var c: ClearanceShelf = _shelf(8.0, &"g")
	a.knock(ClearanceShelf.BY_PULSE)
	_step(_sim.frames(0.3))
	b.knock(ClearanceShelf.BY_POUND)
	_step(_sim.frames(0.3))
	assert_true(a.is_standing(), "La primera ya se ha repuesto")
	c.knock(ClearanceShelf.BY_LASER)
	assert_false(c.is_cleared(), "Queda una en pie: no cae el grupo")
	_step(_sim.frames(0.6))
	assert_true(a.is_standing() and b.is_standing() and c.is_standing())


func test_real_quake_knocks_the_whole_group_at_once_for_good() -> void:
	var a: ClearanceShelf = _shelf(-8.0, &"g")
	var b: ClearanceShelf = _shelf(3.0, &"g")
	var c: ClearanceShelf = _shelf(8.0, &"g")
	var other: ClearanceShelf = _shelf(30.0, &"g")
	other.group_id = &"lejos"
	await wait_physics_frames(1)
	_quake()
	for shelf: ClearanceShelf in [a, b, c]:
		assert_true(shelf.is_cleared(), "El Sismo las tumba todas a la vez")
	assert_true(other.is_standing(), "Fuera de la pantalla, otra no")
	_step(_sim.frames(1.0))
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_true(a.is_cleared() and b.is_cleared() and c.is_cleared(), "Para siempre en el intento")
	assert_eq(a.collision_layer, 0)


func test_quake_misses_a_member_off_screen_and_the_group_restocks() -> void:
	var a: ClearanceShelf = _shelf(-8.0, &"g")
	var b: ClearanceShelf = _shelf(3.0, &"g")
	var far: ClearanceShelf = _shelf(14.0, &"g")
	await wait_physics_frames(1)
	_quake()
	assert_true(far.is_standing(), "Una justo fuera de la pantalla")
	assert_false(a.is_cleared() or b.is_cleared())
	_step(_sim.frames(0.6))
	assert_true(a.is_standing() and b.is_standing(), "Se reponen")


func test_a_lonely_shelf_only_falls_to_the_quake() -> void:
	var lone: ClearanceShelf = _shelf(3.0, &"sola")
	lone.knock(ClearanceShelf.BY_POUND)
	assert_false(lone.is_cleared(), "Un golpe suelto no basta aunque sea la unica")
	_step(_sim.frames(0.6))
	assert_true(lone.is_standing())
	lone.knock(ClearanceShelf.BY_QUAKE)
	assert_true(lone.is_cleared(), "El Sismo si")


func test_restock_waits_for_isak_to_leave() -> void:
	var a: ClearanceShelf = _shelf(3.0, &"g")
	_shelf(9.0, &"g")
	a.knock(ClearanceShelf.BY_PULSE)
	_place(Vector2(a.get_shelf_rect().get_center().x, 0.0))
	_step(_sim.frames(1.0))
	assert_true(a.is_down(), "No se materializa con Isak dentro")
	_place(Vector2(0.0, 0.0))
	_step(2)
	assert_true(a.is_standing(), "Al salir, se repone")


# --- «Prueba gratis» ---

func _box() -> FreeTrialBox:
	var box := BOX_SCENE.instantiate() as FreeTrialBox
	box.object_id = &"prueba_gratis"
	box.position = Vector2(2.0 * T, -T)
	_world.add_child(box)
	box.set_process(false)
	return box


func _text_box() -> EcoTextBox:
	var tb := TEXT_BOX_SCENE.instantiate() as EcoTextBox
	tb.name = "EcoTextBox"
	_world.add_child(tb)
	tb.set_process(false)
	return tb


func test_free_trial_back_pulse_gives_the_combo_and_plays_the_scene() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_COMBO, false)
	var tb: EcoTextBox = _text_box()
	var box: FreeTrialBox = _box()
	var said: Array = []
	box.line_said.connect(func(text: String, speaker: StringName, important: bool) -> void:
		said.append([text, speaker, important]))
	assert_false(box.is_on(), "Cerrada")
	watch_signals(box)
	assert_false(box.receive_pulse(_fake_pulse(Vector2(-8.0 * T, 0.0))), "Lejos no")
	_place(Vector2(box.global_position.x + 0.5 * T, 0.0))
	assert_true(box.receive_pulse(_isak_pulse()), "El pulso la abre")
	assert_true(_isak.is_facing_back(), "Isak de espaldas")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_COMBO), "La Combinacion, para siempre")
	assert_true(GameState.is_notice_seen(&"combo_5_2"), "La escena, una vez por partida guardada")
	assert_signal_emitted_with_parameters(box, "switched_on", [&"prueba_gratis", true])
	# Las lineas en orden: Eco, Isak (importantes) y Eco ya sin pausa.
	assert_eq(said, [["Todo tiene un precio.", &"", true], ["Esto no lo compré. Es mío.", FreeTrialBox.SPEAKER_ISAK, true],
		["Una prueba gratis siempre acaba, %s." % GameState.get_nickname(), &"", false]], "Eco, Isak y Eco")
	var texts: Array[String] = [tb.get_text()]
	texts.append_array(Array(tb.get_queued_texts()))
	assert_eq(texts.size(), 3, "Las tres en el cuadro del nivel")
	assert_true(texts.has("Esto no lo compré. Es mío."))
	# La de Isak, con su interlocutor y su estilo de cuadro.
	for i: int in 400:
		if tb.get_text() == "Esto no lo compré. Es mío.":
			break
		tb.advance(0.05)
	assert_eq(tb.get_text(), "Esto no lo compré. Es mío.")
	assert_eq(tb.get_speaker_id(), FreeTrialBox.SPEAKER_ISAK, "Interlocutor isak")
	assert_eq(tb.get_speaker_text(), "Isak")
	assert_eq(tb.get_style_id(), &"isak", "Estilo de cuadro propio")
	assert_eq(tb.get_panel_texture().resource_path, "res://assets/sprites/ui/eco_isak_panel.png")
	# Los gestos se juntan.
	assert_almost_eq(box.get_merge_progress(), 0.0, EPS)
	box._process(2.0)
	assert_almost_eq(box.get_merge_progress(), 1.0, EPS, "Juntos")
	assert_false(box.receive_pulse(_isak_pulse()), "Un solo uso")


func test_free_trial_inert_with_the_combo_and_back_after_losing_it() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_COMBO, false)
	GameState.obtain_ability(GameState.ABILITY_COMBO)
	var said: Array = []
	var box: FreeTrialBox = _box()
	box.line_said.connect(func(text: String, _s: StringName, _i: bool) -> void: said.append(text))
	assert_true(box.is_on() and box.is_inert(), "Con la Combinacion ya obtenida, abierta e inerte")
	_place(Vector2(box.global_position.x + 0.5 * T, 0.0))
	assert_false(box.receive_pulse(_isak_pulse()), "No responde")
	assert_eq(said, [])
	# Rollback sin la Combinacion (pero con la escena ya vista): vuelve cerrada y la da sin escena.
	GameState.mark_notice_seen(&"combo_5_2")
	GameState.obtained_abilities.erase(GameState.ABILITY_COMBO)
	GameState.set_ability_unlocked(GameState.ABILITY_COMBO, false)
	box.queue_free()
	var again: FreeTrialBox = _box()
	again.line_said.connect(func(text: String, _s: StringName, _i: bool) -> void: said.append(text))
	assert_false(again.is_on(), "Tras perderla, cerrada")
	assert_true(again.switch_on())
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_COMBO))
	assert_eq(said, [], "La escena ya vista no se repite")


# --- Sala ---

func test_combos_test_room_loads() -> void:
	var scene := load(ROOM_SCENE) as PackedScene
	assert_not_null(scene, "La sala combos_test existe")
	var room: Node = scene.instantiate()
	add_child_autofree(room)
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group(Shutter.GROUP).size(), 2, "Dos persianas (de suelo y de pared)")
	assert_eq(get_tree().get_nodes_in_group(PriceRail.GROUP).size(), 1)
	assert_eq(get_tree().get_nodes_in_group(ClearanceShelf.GROUP).size(), 3)
	assert_eq(get_tree().get_nodes_in_group(DndSwitch.GROUP).size(), 1, "La «Prueba gratis»")
	# Se quita aqui, antes de after_each: al salir del arbol GeneratedLevel restaura las habilidades
	# que habia al entrar (las de before_each, desbloqueadas); con el autofree salia despues de que
	# after_each las bloqueara y las dejaba desbloqueadas para los scripts siguientes de la suite.
	room.free()
