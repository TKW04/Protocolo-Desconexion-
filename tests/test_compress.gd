# Pellizcar (gesto Pellizcar, accion gesture_pinch; habilidad compress; paso 1 del
# plan de docs/propuesta-mundo-3.md §8, valores de §3.3.1): interruptor, caja
# 32 x 40 con los pies abajo (cabe por un hueco de 1 tile y sin comprimir no),
# andar a 160 px/s sin correr, salto bajo, vuelta al tamano pedida que espera a
# que haya sitio (icono «sin espacio») y vuelve sola, gratis, con el Debug si,
# sin pulso, laser, dash, golpe al suelo ni Ocultarte comprimido (pellizcarse
# apaga el Ocultarte), no sale sin la habilidad, en el hub ni ocupado, el dano
# lo mantiene comprimido, morir y reaparecer devuelve el tamano, senales para
# los sonidos, pose provisional por escala y Eco bajo el techo. Isak avanza paso
# a paso con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_compress_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const T: float = 64.0
## Hueco de 1 tile: losa con su cara de abajo a 1 tile del suelo, de x 160 a 560.
const GAP_FROM_X: float = 160.0
const GAP_TO_X: float = 560.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}
var _changes: Array = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_changes = []
	EventBus.compress_changed.connect(_on_compress_changed)
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	if EventBus.compress_changed.is_connected(_on_compress_changed):
		EventBus.compress_changed.disconnect(_on_compress_changed)
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_player_hidden(false)
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, false)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _on_compress_changed(compressed: bool) -> void:
	_changes.append(compressed)


# --- Utilidades ---

func _pinch() -> void:
	_sim.input.pinch_pressed = true
	_sim.step()


## Losa solida de `width` x `height` px con su cara de abajo en `bottom_y`.
func _block(x: float, bottom_y: float, width: float, height: float = 256.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(x + width * 0.5, bottom_y - height * 0.5)
	_world.add_child(body)
	return body


## El hueco de 1 tile (64 px) de alto entre el suelo y la losa.
func _gap() -> void:
	_block(GAP_FROM_X, -T, GAP_TO_X - GAP_FROM_X)


func _walk(axis: float, seconds: float) -> void:
	_sim.input.move_axis = axis
	_sim.step(_sim.frames(seconds))
	_sim.input.move_axis = 0.0


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 5:
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Debug activo")


func _shape_height() -> float:
	var hitbox: CollisionShape2D = _isak.get_node("Hitbox") as CollisionShape2D
	return (hitbox.shape as CapsuleShape2D).height


# --- Datos y accion ---

func test_data_and_action() -> void:
	var a: PlayerAbilities = _isak.abilities
	assert_almost_eq(a.compress_width_px, 32.0, EPS)
	assert_almost_eq(a.compress_height_px, 40.0, EPS, "La mitad de alto (§3.3.1)")
	assert_almost_eq(a.compress_squash_s, 0.15, EPS)
	assert_almost_eq(a.compress_walk_speed_px_s, 160.0, EPS)
	assert_almost_eq(a.compress_jump_height_px, 96.0, EPS)
	assert_almost_eq(a.compress_energy_cost, 0.0, EPS, "Gratis")
	assert_true(InputMap.has_action(&"gesture_pinch"), "Accion gesture_pinch")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_I
	assert_true(InputMap.event_is_action(key, &"gesture_pinch"), "I")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	assert_true(InputMap.event_is_action(pad, &"gesture_pinch"), "RB")


func test_toggle_box_and_signals() -> void:
	assert_eq(_isak.get_hitbox_size(), Vector2(32.0, 80.0))
	_pinch()
	assert_true(_isak.is_compressed(), "Pulsar comprime")
	assert_eq(_isak.get_hitbox_size(), Vector2(32.0, 40.0))
	assert_almost_eq(_shape_height(), 40.0, EPS, "Caja de colision comprimida")
	assert_almost_eq(LevelLookup.isak_body_rect(_isak).size.y, 40.0, EPS, "Los objetos miden la caja actual")
	assert_almost_eq(_isak.global_position.y, 0.0, 1.0, "Pies abajo")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS, "Sin coste")
	_sim.step(5)
	assert_true(_isak.is_on_floor(), "Sigue en el suelo")
	_pinch()
	assert_false(_isak.is_compressed(), "Otra pulsacion recupera el tamano")
	assert_almost_eq(_shape_height(), 80.0, EPS)
	assert_eq(_changes, [true, false], "EventBus.compress_changed (sonidos pinch / unpinch)")


func test_fits_through_a_one_tile_gap_only_compressed() -> void:
	_gap()
	_walk(1.0, 3.0)
	assert_lt(_isak.global_position.x, GAP_FROM_X - 15.0, "Sin comprimir no cabe por 1 tile")
	_pinch()
	_walk(1.0, 4.0)
	assert_gt(_isak.global_position.x, GAP_TO_X, "Comprimido cruza el hueco de 64 px")
	assert_true(_isak.is_on_floor())


func test_walk_speed_without_running_and_low_jump() -> void:
	_pinch()
	_sim.input.run_held = true
	_walk(1.0, 1.5)
	_sim.input.run_held = false
	assert_false(_isak.is_running(), "Comprimido no corre")
	_sim.input.move_axis = 1.0
	_sim.input.run_held = true
	_sim.step()
	assert_almost_eq(_isak.velocity.x, 160.0, 1.0, "Anda a 160 px/s aunque se mantenga correr")
	_sim.input.move_axis = 0.0
	_sim.input.run_held = false
	_sim.step(30)
	var floor_y: float = _isak.global_position.y
	_sim.press_jump()
	var top: float = floor_y
	for i: int in 90:
		top = minf(top, _isak.global_position.y)
		_sim.step()
	var rise: float = floor_y - top
	assert_between(rise, 80.0, 96.0, "Salto de ~96 px (%.1f)" % rise)
	assert_true(_isak.is_on_floor(), "Gravedad igual: vuelve al suelo")


func test_uncompress_waits_for_room_and_returns_alone() -> void:
	_gap()
	_pinch()
	_walk(1.0, 2.0)
	assert_between(_isak.global_position.x, GAP_FROM_X + 16.0, GAP_TO_X - 16.0, "Dentro del hueco")
	_pinch()
	assert_true(_isak.is_compressed(), "Bajo el techo no vuelve")
	assert_true(_isak.is_uncompress_pending(), "Queda pedido")
	assert_almost_eq(_shape_height(), 40.0, EPS)
	_sim.step(10)
	assert_true(_isak.get_compress_effect().is_blocked_icon_visible(), "Icono «sin espacio»")
	assert_true(_isak.is_compressed())
	_sim.input.move_axis = 1.0
	_sim.step_until(func() -> bool: return not _isak.is_compressed(), _sim.steps_for(4.0))
	_sim.input.move_axis = 0.0
	assert_false(_isak.is_compressed(), "Vuelve solo al haber sitio")
	assert_gt(_isak.global_position.x, GAP_TO_X + 15.0, "Ya fuera de la losa")
	assert_false(_isak.get_compress_effect().is_blocked_icon_visible(), "Sin icono")
	assert_false(_isak.is_uncompress_pending())
	assert_eq(_changes, [true, false])


func test_second_press_cancels_the_pending_request() -> void:
	_gap()
	_pinch()
	_walk(1.0, 2.0)
	_pinch()
	assert_true(_isak.is_uncompress_pending())
	_pinch()
	assert_false(_isak.is_uncompress_pending(), "Otra pulsacion cancela la vuelta pedida")
	_walk(1.0, 4.0)
	assert_true(_isak.is_compressed(), "Sin pedir, sigue comprimido al salir")


func test_wall_beside_does_not_block_uncompress() -> void:
	_block(40.0, 0.0, 64.0, 256.0)
	_pinch()
	_walk(1.0, 1.0)
	assert_true(_isak.is_on_wall() or _isak.global_position.x > 20.0, "Pegado a la pared")
	_pinch()
	assert_false(_isak.is_compressed(), "Una pared al lado no impide crecer")


# --- Lo que no se hace comprimido ---

func test_no_pulse_laser_dash_pound_or_hide_while_compressed() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, true)
	EcoProgress.meet_eco_with_pulse()
	GameState.upgrade_levels[&"pulso"] = 4
	_pinch()
	assert_true(_isak.is_compressed())
	_sim.input.pulse_pressed = true
	_sim.step()
	assert_ne(_sim.state(), PlayerState.PULSE, "Sin pulso")
	_sim.input.laser_pressed = true
	_sim.step()
	assert_false(_isak.is_laser_charging() or _isak.is_laser_posing(), "Sin laser")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS)
	_sim.input.dash_pressed = true
	_sim.step()
	assert_ne(_sim.state(), PlayerState.DASH, "Sin dash")
	assert_eq(_isak.dash_denial(), Isak.DASH_DENIED_BUSY)
	_sim.input.hold_held = true
	_sim.step(_sim.frames(0.6))
	_sim.input.hold_held = false
	assert_ne(_sim.state(), PlayerState.GROUND_POUND, "Sin golpe al suelo")
	_sim.step()
	_sim.input.hide_pressed = true
	_sim.step()
	assert_false(_isak.is_hidden(), "Sin Ocultarte")
	assert_true(_isak.is_compressed())


func test_pinching_turns_off_hide() -> void:
	EcoProgress.meet_eco_with_pulse()
	GameState.upgrade_levels[&"pulso"] = 4
	_sim.input.hide_pressed = true
	_sim.step()
	assert_true(_isak.is_hidden(), "Ocultarte activo")
	var reasons: Array = []
	_isak.get_hide_mode().ended.connect(func(r: StringName) -> void: reasons.append(r))
	_pinch()
	assert_true(_isak.is_compressed())
	assert_false(_isak.is_hidden(), "Pellizcarse apaga el Ocultarte")
	assert_eq(reasons, [HideMode.REASON_COMPRESS])


func test_works_with_debug() -> void:
	_activate_debug()
	_pinch()
	assert_true(_isak.is_compressed(), "Con el Debug si")
	assert_true(DebugMode.is_active(), "No apaga el Debug")
	_pinch()
	assert_false(_isak.is_compressed())


# --- Cuando no sale ---

func test_without_ability_or_in_hub_does_nothing() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, false)
	_pinch()
	assert_false(_isak.is_compressed(), "Sin la habilidad no sale")
	assert_eq(_isak.compress_denial(), Isak.COMPRESS_DENIED_LOCKED)
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, true)
	_isak.level_mode = false
	_pinch()
	assert_false(_isak.is_compressed(), "En el hub no sale")
	_isak.level_mode = true
	assert_eq(_changes, [])


func test_not_while_busy() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, true)
	# Pulso.
	_sim.input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.PULSE)
	_pinch()
	assert_false(_isak.is_compressed(), "No durante el pulso")
	_sim.settle()
	# Laser.
	_sim.input.laser_pressed = true
	_sim.step()
	assert_true(_isak.is_laser_charging() or _isak.is_laser_posing())
	_pinch()
	assert_false(_isak.is_compressed(), "No durante el laser")
	_sim.step(_sim.steps_for(0.5))
	_sim.settle()
	# Dash.
	_sim.input.dash_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.DASH)
	_pinch()
	assert_false(_isak.is_compressed(), "No durante el dash")
	_sim.step(_sim.steps_for(0.6))
	_sim.settle()
	# Golpe al suelo.
	_sim.input.hold_held = true
	_sim.step_until(func() -> bool: return _isak.is_ground_pounding(), _sim.steps_for(1.0))
	assert_true(_isak.is_ground_pounding())
	_pinch()
	assert_false(_isak.is_compressed(), "No durante el golpe al suelo")
	_sim.input.hold_held = false
	_sim.step(_sim.steps_for(1.0))
	_sim.settle()
	# Hurt.
	assert_true(_isak.take_hit(1.0))
	_pinch()
	assert_false(_isak.is_compressed(), "No en Hurt")
	_sim.step(_sim.steps_for(1.5))
	_sim.settle()
	# De espaldas y vortice.
	assert_true(_isak.face_back())
	_pinch()
	assert_false(_isak.is_compressed(), "No de espaldas")
	assert_eq(_isak.compress_denial(), Isak.COMPRESS_DENIED_BUSY)
	_isak.face_side()
	_isak.begin_warp(false)
	assert_false(_isak.compress(), "No en un vortice")
	_isak.end_warp()
	# Muerto.
	_isak.die()
	assert_false(_isak.compress(), "No muerto")
	assert_eq(_changes, [])


# --- Dano, muerte y reaparicion ---

func test_damage_keeps_compressed() -> void:
	_pinch()
	var before: float = GameState.sync_rate
	GameState.apply_sync_damage(10.0)
	assert_true(_isak.take_hit(1.0))
	assert_almost_eq(GameState.sync_rate, before - 10.0, EPS, "-10 como siempre")
	assert_true(_isak.is_compressed(), "Sigue comprimido tras el golpe")
	_sim.step(_sim.steps_for(1.5))
	assert_true(_isak.is_compressed(), "Y al acabar el golpe")
	assert_almost_eq(_shape_height(), 40.0, EPS)


func test_death_and_respawn_restore_normal_size() -> void:
	_gap()
	_pinch()
	_walk(1.0, 2.0)
	_isak.die()
	assert_true(_isak.is_compressed(), "Bajo el techo, muerto sigue con la caja baja")
	assert_true(_isak.is_uncompress_pending(), "Morir pide el tamano normal")
	_sim.step(10)
	assert_true(_isak.is_compressed())
	_isak.respawn(Vector2(0.0, 0.0))
	assert_false(_isak.is_compressed(), "Reaparecer devuelve el tamano")
	assert_false(_isak.is_uncompress_pending())
	assert_almost_eq(_shape_height(), 80.0, EPS)
	assert_eq(_isak.get_sprite().scale, Vector2.ONE, "Sprite sin aplastar")
	assert_false(_isak.get_compress_effect().is_blocked_icon_visible())
	assert_eq(_changes, [true, false])
	_sim.settle()
	_pinch()
	assert_true(_isak.is_compressed(), "Se puede volver a pellizcar al momento")


func test_warp_requests_normal_size() -> void:
	_pinch()
	_isak.begin_warp(false)
	_sim.step()
	assert_false(_isak.is_compressed(), "Un vortice pide el tamano y, con sitio, vuelve")
	_isak.end_warp()


# --- Pose provisional y Eco ---

func test_provisional_squash_pose() -> void:
	var sprite: AnimatedSprite2D = _isak.get_sprite()
	var base_y: float = sprite.position.y
	_pinch()
	assert_lt(_isak.get_compress_amount(), 1.0, "Se aplasta poco a poco")
	_sim.step(_sim.frames(0.15))
	assert_almost_eq(_isak.get_compress_amount(), 1.0, EPS, "En 0,15 s")
	assert_almost_eq(sprite.scale.y, 0.5, EPS, "Aplastado (squash_scale)")
	assert_almost_eq(sprite.scale.x, 1.15, EPS)
	assert_almost_eq(sprite.position.y, base_y * 0.5, EPS, "Pies quietos")
	_pinch()
	_sim.step(_sim.frames(0.15) + 1)
	assert_eq(sprite.scale, Vector2.ONE, "Vuelve a su escala")
	assert_almost_eq(sprite.position.y, base_y, EPS)


func test_eco_stays_under_a_low_ceiling() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_gap()
	_pinch()
	_walk(1.0, 2.0)
	var eco: EcoCompanion = EcoCompanion.attach(_isak, _world)
	await wait_physics_frames(2)
	var feet: Vector2 = _isak.global_position
	var at: Vector2 = eco.get_follow_position()
	assert_gt(at.y, feet.y - T, "Eco dentro del hueco, por debajo del techo (%.1f)" % (feet.y - at.y))
	assert_lt(at.y, feet.y, "Nunca por debajo de los pies")
