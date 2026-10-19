# Dash de Isak (gesto Deslizar, accion gesture_swipe; 2026-10-19, paso 1 del plan
# de docs/propuesta-1-3.md §7, decisiones de §8 aprobadas con sus recomendaciones):
# distancia y tiempos de la seccion dash de data/isak_abilities.json, coste de
# energia al salir, enfriamiento desde el final, direccion (mantenida o hacia
# donde mira), dash aereo (uno por estancia en el aire, gravedad 0), velocidad
# final, invulnerabilidad desde el inicio (Burbuja sin dano ni aturdirla),
# paredes y plataformas de una via, sin energia o con el Debug = chispa gris,
# apaga el Ocultarte, no durante el pulso ni el laser, ni en un vortice ni en el
# hub; morir durante el dash y reaparecer; coyote al salir de un borde y salto
# con el buffer al terminar. Isak avanza paso a paso con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const PATH: String = "user://test_dash_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
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
	GameState.set_player_hidden(false)
	GameState.reset_progress()
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, false)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


# --- Utilidades ---

func _press_dash(axis: float = 0.0) -> void:
	_sim.input.move_axis = axis
	_sim.input.dash_pressed = true
	_sim.step()


## Pulsa el dash y avanza hasta que termina. Devuelve los pasos en Dash.
func _dash(axis: float = 0.0) -> int:
	_press_dash(axis)
	var steps: int = 1 if _isak.is_dashing() else 0
	steps += _sim.step_until(func() -> bool: return not _isak.is_dashing(), _sim.steps_for(1.0))
	return steps


## Posicion y velocidad de Isak justo al terminar el dash (signal dash_ended).
var _end_position := Vector2.INF
var _end_velocity := Vector2.ZERO


func _track_end() -> void:
	_end_position = Vector2.INF
	if not _isak.dash_ended.is_connected(_on_dash_ended):
		_isak.dash_ended.connect(_on_dash_ended)


func _on_dash_ended() -> void:
	_end_position = _isak.global_position
	_end_velocity = _isak.velocity


func _wall(x: float, height: float = 256.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64.0, height)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(x + 32.0, -height * 0.5)
	_world.add_child(body)
	return body


## Plataforma de una via de 1 tile de grosor y `width` px desde x, techo en y.
func _one_way(x: float, y: float, width: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 16.0)
	shape.shape = rect
	shape.one_way_collision = true
	body.add_child(shape)
	body.position = Vector2(x + width * 0.5, y + 8.0)
	_world.add_child(body)
	return body


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	for i: int in ceili(DebugMode.get_activation_hold_s() / DT) + 5:
		DebugMode.step(DT, true)
	assert_true(DebugMode.is_active(), "Debug activo")


# --- Datos y accion ---

func test_data_and_action() -> void:
	var a: PlayerAbilities = _isak.abilities
	assert_almost_eq(a.dash_distance_px, 192.0, EPS, "3 tiles (§2.1)")
	assert_almost_eq(a.dash_duration_s, 0.2, EPS)
	assert_almost_eq(a.dash_invulnerable_s, 0.3, EPS)
	assert_almost_eq(a.dash_energy_cost, 10.0, EPS)
	assert_almost_eq(a.dash_cooldown_s, 0.5, EPS)
	assert_almost_eq(a.dash_end_speed_px_s, 360.0, EPS)
	assert_eq(a.dash_air_dashes, 1)
	assert_true(InputMap.has_action(&"gesture_swipe"), "Accion gesture_swipe")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_L
	assert_true(InputMap.event_is_action(key, &"gesture_swipe"), "L desliza")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	assert_true(InputMap.event_is_action(pad, &"gesture_swipe"), "B del mando desliza")


# --- Suelo: distancia, tiempo, coste, velocidad final ---

func test_ground_dash_distance_time_and_cost() -> void:
	var start: Vector2 = _isak.global_position
	var energy: float = GameState.debug_energy
	var started: Array = []
	_isak.dash_started.connect(func(d: float) -> void: started.append(d))
	_track_end()
	_press_dash()
	assert_eq(_sim.state(), PlayerState.DASH, "Pulsar gesture_swipe empieza el dash")
	assert_almost_eq(GameState.debug_energy, energy - 10.0, EPS, "Cobra 10 de energia al salir")
	assert_eq(started, [1.0], "Hacia donde mira (derecha)")
	var steps: int = 1 + _sim.step_until(func() -> bool: return not _isak.is_dashing(), _sim.steps_for(1.0))
	assert_almost_eq(_end_position.x - start.x, 192.0, 1.0, "Recorre 192 px")
	assert_almost_eq(_end_position.y, start.y, 0.5, "En el suelo la altura no cambia")
	assert_between(float(steps) * DT, 0.2 - EPS, 0.2 + 2.0 * DT + EPS, "Dura unos 0,2 s")
	assert_almost_eq(_end_velocity.x, 360.0, EPS, "Al terminar conserva la velocidad de correr")
	assert_almost_eq(GameState.debug_energy, energy - 10.0, EPS, "Un solo cobro")


func test_direction_follows_held_axis() -> void:
	var start_x: float = _isak.global_position.x
	_dash(-1.0)
	_sim.input.move_axis = 0.0
	assert_lt(_isak.global_position.x, start_x - 180.0, "Con izquierda mantenida va a la izquierda")
	assert_eq(_isak.facing, -1.0, "Y mira hacia alla")
	_sim.step(_sim.steps_for(0.6))
	var x2: float = _isak.global_position.x
	_dash()
	assert_lt(_isak.global_position.x, x2 - 180.0, "Sin direccion, hacia donde mira")


func test_cooldown_from_end() -> void:
	_dash()
	_sim.input.move_axis = 0.0
	assert_almost_eq(_isak.get_dash_cooldown_left(), 0.5, 2.0 * DT, "Enfriamiento de 0,5 s desde el final")
	var energy: float = GameState.debug_energy
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "Durante el enfriamiento no sale")
	assert_almost_eq(GameState.debug_energy, energy, EPS, "Ni cobra")
	assert_eq(_isak.dash_denial(), Isak.DASH_DENIED_COOLDOWN)
	_sim.step(_sim.frames(0.5) + 1)
	assert_eq(_isak.get_dash_cooldown_left(), 0.0)
	_press_dash()
	assert_eq(_sim.state(), PlayerState.DASH, "Tras el enfriamiento, otro dash")


# --- Aire ---

func test_air_dash_keeps_height_one_per_air_time() -> void:
	_sim.press_jump()
	_sim.step_until(func() -> bool: return _isak.velocity.y >= 0.0, _sim.steps_for(1.0))
	var y: float = _isak.global_position.y
	var x: float = _isak.global_position.x
	_track_end()
	_press_dash()
	assert_eq(_sim.state(), PlayerState.DASH, "Dash aereo")
	assert_eq(_isak.get_air_dashes_left(), 0, "Gasta el dash aereo")
	_sim.step_until(func() -> bool: return not _isak.is_dashing(), _sim.steps_for(1.0))
	assert_almost_eq(_end_position.y, y, 0.5, "Gravedad 0 durante el dash")
	assert_almost_eq(_end_position.x - x, 192.0, 1.0, "Tambien 192 px en el aire")
	assert_eq(_sim.state(), PlayerState.FALL, "Despues cae")
	_sim.step(_sim.frames(0.5) + 2)
	if not _isak.is_on_floor():
		var energy: float = GameState.debug_energy
		_press_dash()
		assert_ne(_sim.state(), PlayerState.DASH, "Un solo dash por estancia en el aire")
		assert_almost_eq(GameState.debug_energy, energy, EPS)
	_sim.settle()
	assert_eq(_isak.get_air_dashes_left(), 1, "Se repone al tocar el suelo")


func test_ground_dash_off_a_ledge_gives_coyote() -> void:
	# Plataforma de 2 tiles por encima del suelo: el dash sale de su borde.
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(128.0, 32.0)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(_isak.global_position.x + 32.0, -128.0 - 16.0)
	_world.add_child(body)
	_isak.global_position = Vector2(_isak.global_position.x, -128.0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()
	assert_true(_isak.is_on_floor())
	_dash()
	assert_false(_isak.is_on_floor(), "Sale del borde")
	assert_true(_isak.can_jump(), "Coyote normal al salir de un borde")
	assert_eq(_isak.get_air_dashes_left(), 1, "El dash del suelo no gasta el aereo")


func test_jump_buffer_during_last_part_of_dash() -> void:
	_press_dash()
	_sim.step(_sim.frames(0.2) - 3)
	assert_true(_isak.is_dashing())
	_sim.press_jump()
	assert_true(_isak.is_dashing(), "El salto no corta el dash")
	_sim.step_until(func() -> bool: return not _isak.is_dashing(), 10)
	_sim.step(2)
	assert_lt(_isak.velocity.y, 0.0, "El buffer de salto vale al terminar en el suelo")


# --- Invulnerabilidad ---

func test_invulnerable_from_start_for_dash_invulnerable_s() -> void:
	_press_dash()
	assert_true(_isak.is_invulnerable(), "Invulnerable desde el inicio")
	assert_false(_isak.take_hit(1.0), "Un golpe no hace nada")
	_sim.step(_sim.frames(0.3) - 3)
	assert_true(_isak.is_invulnerable(), "Sigue invulnerable en la cola (0,3 s)")
	_sim.step(4)
	assert_false(_isak.is_invulnerable(), "Pasados 0,3 s ya no")
	assert_true(_isak.take_hit(1.0), "Ya recibe golpes")


func test_passes_through_bubble_without_damage_or_stun() -> void:
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	bubble.position = Vector2(_isak.global_position.x + 96.0, 0.0)
	bubble.patrol_range_px = 0.0
	bubble.free_on_pop = false
	bubble.target = _isak
	_world.add_child(bubble)
	bubble.set_physics_process(false)
	var sync: float = GameState.sync_rate
	_press_dash()
	for i: int in _sim.frames(0.3):
		bubble.step(DT)
		_sim.step()
	assert_gt(_isak.global_position.x, bubble.global_position.x + 32.0, "La atraviesa")
	assert_almost_eq(GameState.sync_rate, sync, EPS, "Sin dano")
	assert_false(bubble.is_stunned(), "Sin aturdirla")
	assert_ne(_sim.state(), PlayerState.HURT)


# --- Terreno ---

func test_wall_stops_dash_early_without_damage() -> void:
	var wall_x: float = _isak.global_position.x + 96.0
	_wall(wall_x)
	var sync: float = GameState.sync_rate
	var steps: int = _dash()
	assert_lt(_isak.global_position.x, wall_x, "No atraviesa la pared")
	assert_gt(_isak.global_position.x, wall_x - 32.0, "Llega hasta ella")
	assert_lt(float(steps) * DT, 0.2, "Termina antes")
	assert_almost_eq(_isak.velocity.x, 0.0, EPS, "Sin rebote")
	assert_almost_eq(GameState.sync_rate, sync, EPS, "Sin dano")


func test_one_way_platform_does_not_stop_horizontal_dash() -> void:
	# Plataforma de una via a la altura del pecho de Isak, delante de el.
	var x: float = _isak.global_position.x
	_one_way(x + 48.0, -48.0, 64.0)
	_track_end()
	_dash()
	assert_almost_eq(_end_position.x - x, 192.0, 1.0, "La cruza en horizontal")


# --- Cuando no sale ---

func test_without_energy_grey_spark_and_denied() -> void:
	GameState.debug_energy = 5.0
	var denied: Array = []
	_isak.dash_denied.connect(func(r: StringName) -> void: denied.append(r))
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "Sin energia no sale")
	assert_almost_eq(GameState.debug_energy, 5.0, EPS, "Ni cobra")
	assert_eq(_isak.get_laser_muzzle().get_mode(), LaserMuzzle.Mode.FIZZLE, "Chispa gris en el celular")
	assert_eq(denied, [Isak.DASH_DENIED_ENERGY])


func test_not_with_debug_active_or_charging() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	DebugMode.step(DT, true)
	assert_true(DebugMode.is_engaged(), "Debug cargando")
	var denied: Array = []
	_isak.dash_denied.connect(func(r: StringName) -> void: denied.append(r))
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "Cargando el Debug no sale")
	_activate_debug()
	var energy: float = GameState.debug_energy
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "Con el Debug activo no sale")
	assert_true(DebugMode.is_active(), "El Debug sigue activo (no se pierde por error)")
	assert_almost_eq(GameState.debug_energy, energy, EPS)
	assert_eq(denied, [Isak.DASH_DENIED_DEBUG, Isak.DASH_DENIED_DEBUG])
	assert_eq(_isak.get_laser_muzzle().get_mode(), LaserMuzzle.Mode.FIZZLE, "Chispa gris")


func test_locked_or_in_hub_does_nothing() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, false)
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "Sin la habilidad no sale")
	assert_eq(_isak.get_laser_muzzle().get_mode(), LaserMuzzle.Mode.NONE, "Sin aviso")
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	_isak.level_mode = false
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "En el hub no sale")
	_isak.level_mode = true


func test_not_during_pulse_or_laser_pose_and_no_laser_during_dash() -> void:
	_sim.input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.PULSE)
	_press_dash()
	assert_eq(_sim.state(), PlayerState.PULSE, "Durante la pose del pulso no sale")
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.PULSE, _sim.steps_for(1.0))
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	_sim.input.laser_pressed = true
	_sim.step()
	assert_true(_isak.is_laser_posing() or _isak.is_laser_charging())
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "Durante la pose del laser no sale")
	_sim.step(_sim.steps_for(0.6))
	_press_dash()
	assert_eq(_sim.state(), PlayerState.DASH)
	_sim.input.laser_pressed = true
	_sim.input.pulse_pressed = true
	_sim.step()
	assert_false(_isak.is_laser_charging() or _isak.is_laser_posing(), "Sin laser durante el dash")
	assert_eq(_sim.state(), PlayerState.DASH, "Ni pulso")


func test_not_in_warp_or_facing_back() -> void:
	_isak.begin_warp(false)
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "En un vortice no sale")
	_isak.end_warp()
	_isak.face_back()
	_press_dash()
	assert_ne(_sim.state(), PlayerState.DASH, "De espaldas no sale")
	_isak.face_side()


func test_dash_turns_off_hide_and_no_hide_while_dashing() -> void:
	EcoProgress.meet_eco_with_pulse()
	GameState.upgrade_levels[&"pulso"] = 4
	_sim.input.hide_pressed = true
	_sim.step()
	assert_true(_isak.is_hidden(), "Ocultarte activo")
	var reasons: Array = []
	_isak.get_hide_mode().ended.connect(func(r: StringName) -> void: reasons.append(r))
	_press_dash()
	assert_eq(_sim.state(), PlayerState.DASH)
	assert_false(_isak.is_hidden(), "El dash apaga el Ocultarte")
	assert_eq(reasons, [HideMode.REASON_DASH])
	_sim.input.hide_pressed = true
	_sim.step()
	assert_false(_isak.is_hidden(), "No se oculta durante el dash")


# --- Muerte y reaparicion ---

func test_death_during_dash_and_respawn_resets() -> void:
	_sim.press_jump()
	_sim.step(10)
	_press_dash()
	assert_eq(_sim.state(), PlayerState.DASH)
	_isak.die()
	assert_eq(_sim.state(), PlayerState.DEAD, "Morir corta el dash")
	assert_almost_eq(_isak.velocity.x, 0.0, EPS)
	_isak.respawn(Vector2(0.0, 0.0))
	assert_eq(_sim.state(), PlayerState.IDLE)
	assert_eq(_isak.get_dash_cooldown_left(), 0.0, "Se reinicia el enfriamiento")
	assert_eq(_isak.get_air_dashes_left(), 1, "Se repone el dash aereo")
	assert_false(_isak.is_invulnerable(), "Sin la invulnerabilidad del dash")
	assert_false(_isak.get_dash_effect().is_trail_visible(), "Sin estela")
	_sim.settle()
	_press_dash()
	assert_eq(_sim.state(), PlayerState.DASH, "Puede deslizarse otra vez al momento")


func test_provisional_pose_and_trail() -> void:
	_press_dash()
	assert_eq(_isak.get_animation(), Isak.ANIM_RUN, "Pose provisional: cuadro de correr")
	assert_ne(_isak.get_sprite().rotation, 0.0, "Inclinado hacia delante")
	_sim.step(3)
	assert_true(_isak.get_dash_effect().is_trail_visible(), "Estela de datos")
	_sim.step_until(func() -> bool: return not _isak.is_dashing(), 30)
	assert_eq(_isak.get_sprite().rotation, 0.0, "Se endereza al terminar")
	assert_gt(_isak.get_dash_effect().get_cooldown_fraction(), 0.0, "Anillo del enfriamiento")
	_sim.step(_sim.steps_for(0.6))
	assert_false(_isak.get_dash_effect().is_trail_visible(), "La estela se apaga")
	assert_eq(_isak.get_dash_effect().get_cooldown_fraction(), 0.0)
