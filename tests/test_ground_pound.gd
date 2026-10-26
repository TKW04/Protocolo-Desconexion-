# Golpe al suelo de Isak (gesto Mantener presionado; paso 1 del plan de
# docs/propuesta-mundo-2.md §8, decisiones del usuario del 2026-10-22): datos de
# la seccion ground_pound de data/isak_abilities.json, control (move_down
# mantenido), golpe en el aire (anticipacion y caida a 960 px/s) y en el suelo
# (carga de 0,35 s con 3 pasos y saltito), onda (radio, aturde y 1 de dano),
# gratis, con el Debug si, durante el dash no y tras un dash aereo si, apaga el
# Ocultarte, soltar entre golpes, enfriamiento, sin la habilidad o en el hub no
# sale, plataformas de una via lo paran y lo que se rompe con el golpe deja
# seguir cayendo. Isak avanza paso a paso con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const PATH: String = "user://test_ground_pound_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}
var _landed: Array[Rect2] = []


## Tarjeta de prueba que se rompe con la onda (contrato de GroundPoundWave).
class BreakableCard:
	extends StaticBody2D
	var broken: bool = false

	func _ready() -> void:
		EventBus.ground_pound_landed.connect(_on_pound)

	func _on_pound(rect: Rect2, _source: Node2D) -> void:
		var shape := get_child(0) as CollisionShape2D
		var r := (shape.shape as RectangleShape2D).size
		var mine := Rect2(global_position - r * 0.5, r)
		if rect.intersects(mine):
			broken = true
			shape.disabled = true

	func is_broken_by_pound() -> bool:
		return broken


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_DEBUG, GameState.ABILITY_DASH,
			GameState.ABILITY_GROUND_POUND]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_landed.clear()
	_isak.ground_pound_landed.connect(func(rect: Rect2) -> void: _landed.append(rect))
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_player_hidden(false)
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

func _hold(held: bool) -> void:
	_sim.input.hold_held = held


## Sube con un salto hasta el apogeo (en el aire, alto).
func _jump_to_apex() -> void:
	_sim.press_jump()
	_sim.step()
	_sim.step_until(func() -> bool: return _isak.velocity.y >= 0.0, _sim.steps_for(1.0))


## Mantiene el gesto hasta que aterriza el golpe; devuelve los pasos.
func _pound_until_landed() -> int:
	_hold(true)
	var count: int = _landed.size()
	return _sim.step_until(func() -> bool: return _landed.size() > count, _sim.steps_for(3.0))


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 5:
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Debug activo")


func _bubble_at(dx: float) -> AlertBubble:
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	bubble.position = Vector2(_isak.global_position.x + dx, 0.0)
	bubble.patrol_range_px = 0.0
	bubble.free_on_pop = false
	bubble.target = _isak
	_world.add_child(bubble)
	bubble.set_physics_process(false)
	return bubble


# --- Datos y control ---

func test_data_and_control() -> void:
	var a: PlayerAbilities = _isak.abilities
	assert_almost_eq(a.pound_air_hold_s, 0.12, EPS)
	assert_almost_eq(a.pound_ground_hold_s, 0.35, EPS)
	assert_almost_eq(a.pound_anticipation_s, 0.1, EPS)
	assert_almost_eq(a.pound_drop_speed_px_s, 960.0, EPS)
	assert_almost_eq(a.pound_wave_half_width_px, 96.0, EPS, "1,5 tiles a cada lado")
	assert_almost_eq(a.pound_wave_height_px, 64.0, EPS)
	assert_almost_eq(a.pound_damage, 1.0, EPS)
	assert_almost_eq(a.pound_land_pose_s, 0.35, EPS)
	assert_almost_eq(a.pound_cooldown_s, 0.4, EPS)
	assert_almost_eq(a.pound_energy_cost, 0.0, EPS, "Gratis")
	# Control (decision 2026-10-22): los eventos de move_down, sin tecla nueva.
	assert_true(InputMap.has_action(&"move_down"))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_S
	assert_true(InputMap.action_has_event(&"move_down", key), "S mantiene el gesto")


func test_action_input_reads_move_down_held() -> void:
	var input := ActionPlayerInput.new()
	Input.action_press(&"move_down")
	input.poll()
	assert_true(input.hold_held, "move_down mantenido = gesto")
	Input.action_release(&"move_down")
	input.poll()
	assert_false(input.hold_held)
	Input.action_press(&"move_down", 0.3)
	input.poll()
	assert_false(input.hold_held, "Stick poco inclinado: no cuenta")
	Input.action_release(&"move_down")


# --- En el aire ---

func test_air_pound_anticipates_then_drops_vertically() -> void:
	_jump_to_apex()
	_hold(true)
	_sim.input.move_axis = 1.0
	var steps: int = _sim.step_until(func() -> bool: return _isak.is_ground_pounding(), _sim.steps_for(1.0))
	assert_almost_eq(float(steps) * DT, 0.12, DT * 1.5, "Mantener 0,12 s en el aire")
	assert_eq(_isak.get_ground_pound_phase(), GroundPoundState.Phase.ANTICIPATE)
	var y0: float = _isak.global_position.y
	var x0: float = _isak.global_position.x
	var still: int = 1
	while _isak.get_ground_pound_phase() == GroundPoundState.Phase.ANTICIPATE and still < 60:
		assert_almost_eq(_isak.global_position.y, y0, 0.5, "Quieto en el aire durante la anticipacion")
		_sim.step()
		still += 1
	assert_almost_eq(float(still) * DT, 0.1, DT * 1.5, "Anticipacion de 0,1 s")
	assert_eq(_isak.get_ground_pound_phase(), GroundPoundState.Phase.DROP)
	assert_almost_eq(_isak.velocity.y, 960.0, EPS, "Cae a 960 px/s")
	assert_almost_eq(_isak.velocity.x, 0.0, EPS, "Sin control horizontal")
	_sim.step_until(func() -> bool: return not _landed.is_empty(), _sim.steps_for(2.0))
	assert_eq(_landed.size(), 1, "La onda nace al aterrizar")
	assert_almost_eq(_isak.global_position.x, x0, 1.0, "Cae en vertical")
	assert_eq(_isak.get_ground_pound_phase(), GroundPoundState.Phase.LAND)


func test_land_pose_blocks_movement_and_then_cools_down() -> void:
	_jump_to_apex()
	_pound_until_landed()
	_hold(false)
	_sim.input.move_axis = 1.0
	var x0: float = _isak.global_position.x
	var steps: int = _sim.step_until(func() -> bool: return not _isak.is_ground_pounding(), _sim.steps_for(1.0))
	assert_almost_eq(float(steps) * DT, 0.35, DT * 2.0, "Pose de 0,35 s")
	assert_almost_eq(_isak.global_position.x, x0, 2.0, "Sin moverse durante la pose")
	assert_almost_eq(_isak.get_ground_pound_cooldown_left(), 0.4, DT * 2.0, "Enfriamiento de 0,4 s")


func test_pose_uses_the_autosprite_frames_without_scaling() -> void:
	_jump_to_apex()
	_hold(true)
	_sim.step_until(func() -> bool: return _isak.is_ground_pounding(), _sim.steps_for(1.0))
	var sprite: AnimatedSprite2D = _isak.get_sprite()
	assert_eq(sprite.animation, Isak.ANIM_GROUND_POUND_AIR, "Encogido en el aire")
	assert_eq(sprite.scale, Vector2.ONE, "Sin el estirado provisional")
	_pound_until_landed()
	assert_eq(sprite.animation, Isak.ANIM_GROUND_POUND_LAND, "Agachado al aterrizar")
	assert_eq(sprite.scale, Vector2.ONE, "Sin el aplastado provisional")
	_hold(false)
	_sim.step_until(func() -> bool: return not _isak.is_ground_pounding(), _sim.steps_for(1.0))
	assert_ne(sprite.animation, Isak.ANIM_GROUND_POUND_LAND, "Al terminar vuelve a su animacion")


func test_short_tap_in_air_does_nothing() -> void:
	_jump_to_apex()
	_hold(true)
	_sim.step(4)
	_hold(false)
	_sim.step()
	assert_false(_isak.is_ground_pounding(), "Menos de 0,12 s: nada")


# --- En el suelo ---

func test_ground_pound_charges_in_three_steps_then_hops() -> void:
	var effect: GroundPoundEffect = _isak.get_ground_pound_effect()
	_hold(true)
	_sim.step(roundi(0.13 / DT))
	assert_eq(effect.get_charge_steps_lit(), 1, "Primer paso de la carga")
	_sim.step(roundi(0.12 / DT))
	assert_eq(effect.get_charge_steps_lit(), 2)
	assert_false(_isak.is_ground_pounding(), "Aun cargando")
	var y0: float = _isak.global_position.y
	_sim.step_until(func() -> bool: return _isak.is_ground_pounding(), _sim.steps_for(0.5))
	assert_almost_eq(_isak.get_ground_pound_charge_s(), 0.0, EPS, "La carga se gasta")
	assert_eq(_isak.get_ground_pound_phase(), GroundPoundState.Phase.HOP)
	var top: float = y0
	for i: int in 30:
		_sim.step()
		top = minf(top, _isak.global_position.y)
	assert_almost_eq(y0 - top, 32.0, 6.0, "Saltito de medio tile")
	assert_eq(_landed.size(), 1, "Y golpe al volver al suelo")


func test_releasing_the_charge_cancels_it() -> void:
	_hold(true)
	_sim.step(10)
	_hold(false)
	_sim.step()
	assert_almost_eq(_isak.get_ground_pound_charge_s(), 0.0, EPS)
	_hold(true)
	_sim.step(10)
	assert_false(_isak.is_ground_pounding(), "La carga empieza de cero")


func test_must_release_between_pounds() -> void:
	_pound_until_landed()
	_sim.step(_sim.steps_for(1.5))
	assert_false(_isak.is_ground_pounding())
	assert_eq(_landed.size(), 1, "Mantener sin soltar no repite el golpe")
	_hold(false)
	_sim.step()
	_pound_until_landed()
	assert_eq(_landed.size(), 2, "Tras soltar, otro golpe")


# --- Onda ---

func test_wave_rect_is_ground_level_and_one_and_a_half_tiles_wide() -> void:
	_pound_until_landed()
	var rect: Rect2 = _landed[0]
	var feet: Vector2 = _isak.global_position
	assert_almost_eq(rect.position.x, feet.x - 96.0, 1.0)
	assert_almost_eq(rect.size.x, 192.0, 1.0)
	assert_almost_eq(rect.end.y, feet.y + 8.0, 1.0, "Alcanza lo que se pisa")
	assert_almost_eq(rect.position.y, feet.y - 64.0, 1.0)


func test_wave_stuns_and_damages_enemies_in_range_only() -> void:
	var near := _bubble_at(80.0)
	var far := _bubble_at(220.0)
	var health: float = near.get_health()
	_pound_until_landed()
	assert_true(near.is_stunned(), "Aturde dentro de la onda")
	assert_almost_eq(near.get_health(), health - 1.0, EPS, "1 de dano")
	assert_false(far.is_stunned(), "Fuera de la onda no le hace nada")
	assert_almost_eq(far.get_health(), health, EPS)


func test_pound_is_free() -> void:
	GameState.debug_energy = 0.0
	_pound_until_landed()
	assert_eq(_landed.size(), 1, "Sin energia tambien")
	assert_almost_eq(GameState.debug_energy, 0.0, EPS)


func test_works_with_debug_active() -> void:
	_activate_debug()
	_pound_until_landed()
	assert_eq(_landed.size(), 1, "Con el Debug si")


func test_not_during_dash_but_after_air_dash() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	_jump_to_apex()
	_sim.input.dash_pressed = true
	_sim.step()
	assert_true(_isak.is_dashing())
	_hold(true)
	_sim.step_until(func() -> bool: return not _isak.is_dashing(), _sim.steps_for(1.0))
	assert_false(_isak.is_ground_pounding(), "No durante el dash")
	_sim.step_until(func() -> bool: return _isak.is_ground_pounding(), _sim.steps_for(0.5))
	assert_true(_isak.is_ground_pounding(), "Tras el dash aereo, golpe normal")


func test_ends_hide_mode() -> void:
	EcoProgress.meet_eco_with_pulse()
	GameState.upgrade_levels[&"pulso"] = 4
	_sim.input.hide_pressed = true
	_sim.step()
	assert_true(_isak.is_hidden(), "Ocultarte activo")
	var reasons: Array = []
	_isak.get_hide_mode().ended.connect(func(r: StringName) -> void: reasons.append(r))
	_pound_until_landed()
	assert_false(_isak.is_hidden(), "El golpe apaga el Ocultarte")
	assert_eq(reasons, [HideMode.REASON_POUND])


func test_locked_without_ability_and_in_hub() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, false)
	_hold(true)
	_sim.step(_sim.steps_for(1.0))
	assert_false(_isak.is_ground_pounding(), "Sin la habilidad no sale")
	assert_eq(_isak.ground_pound_denial(), Isak.POUND_DENIED_LOCKED)
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, true)
	_isak.level_mode = false
	_sim.step(_sim.steps_for(1.0))
	assert_false(_isak.is_ground_pounding(), "En el hub no sale")
	_isak.level_mode = true


func test_hurt_cancels_and_restores_sprite() -> void:
	_jump_to_apex()
	_hold(true)
	_sim.step_until(func() -> bool: return _isak.is_ground_pounding(), _sim.steps_for(1.0))
	_isak.take_hit(1.0)
	assert_eq(_isak.get_state_name(), PlayerState.HURT)
	assert_eq(_isak.get_sprite().scale, Vector2.ONE, "Sin el aplastado")


func test_one_way_platform_stops_the_drop() -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(256.0, 16.0)
	shape.shape = rect
	shape.one_way_collision = true
	body.add_child(shape)
	body.position = _isak.global_position + Vector2(0.0, -120.0)
	_world.add_child(body)
	_sim.press_jump()
	_sim.step()
	_sim.step_until(func() -> bool: return _isak.global_position.y < body.position.y - 40.0 and _isak.velocity.y >= 0.0,
			_sim.steps_for(1.0))
	_pound_until_landed()
	assert_almost_eq(_isak.global_position.y, body.position.y - 8.0, 2.0, "Aterriza en la de una via")


func test_breakable_floor_lets_isak_keep_falling() -> void:
	var card := BreakableCard.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(256.0, 16.0)
	shape.shape = rect
	card.add_child(shape)
	card.position = _isak.global_position + Vector2(0.0, -120.0)
	_world.add_child(card)
	_isak.global_position = card.position + Vector2(0.0, -8.0 - 120.0)
	_sim.step()
	_sim.step_until(func() -> bool: return _isak.is_on_floor(), _sim.steps_for(1.0))
	assert_almost_eq(_isak.global_position.y, card.position.y - 8.0, 2.0, "De pie en la tarjeta")
	_pound_until_landed()
	assert_true(card.broken, "La onda la rompe")
	_sim.step_until(func() -> bool: return _landed.size() >= 2, _sim.steps_for(2.0))
	assert_almost_eq(_isak.global_position.y, 0.0, 2.0, "Sigue cayendo hasta el suelo")
