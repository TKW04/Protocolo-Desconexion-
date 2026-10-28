# Agitar (gesto Agitar, accion gesture_shake; habilidad shockwave; paso 1 del plan
# de docs/propuesta-mundo-4.md §8, valores de §3.2.1): pulsar en el suelo, pose de
# 0,15 s de sacudida + 0,25 s expuesto sin moverse ni saltar (sin invulnerabilidad),
# onda de 160 px alrededor del celular que aturde 3 s a todos los enemigos que
# alcanza (a los dos lados, sin dano), 10 de energia (sin ella, chispa y aviso),
# enfriamiento de 1 s desde el final de la pose, solo en el suelo, con el Debug si,
# no comprimido ni durante el pulso, el laser, el dash o el golpe al suelo, no sale
# sin la habilidad ni en el hub, apaga el Ocultarte, un golpe lo corta, senales,
# aviso de control y fila reasignable en Ajustes > Controles. Isak avanza paso a
# paso con delta fijo.
# RETIRADO (2026-10-28, prueba del usuario: «hace lo mismo que el pulso»): con
# shockwave.enabled false (data/isak_abilities.json) Agitar no sale nunca, sin
# aviso ni fila en Ajustes (test_retired_*). La logica se conserva: el resto de
# estas pruebas la fuerza con abilities.shockwave_enabled = true en este Isak.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const PATH: String = "user://test_shockwave_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.01

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_path: String
var _saved: Dictionary = {}
var _fired: Array = []
var _bus_fired: Array = []
var _denied: Array = []


## Enemigo de prueba que decide el mismo (contrato receive_shockwave de ShockwaveWave).
class Receiver:
	extends Node2D
	var calls: Array = []

	func receive_shockwave(center: Vector2, radius: float, stun_s: float) -> bool:
		calls.append([center, radius, stun_s])
		return true


## Enemigo con su aturdimiento propio en stun_s (como los de los Mundos 2 y 3).
class StunS:
	extends RefCounted
	var stun_s: float = 1.5


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS,
			GameState.ABILITY_SHOCKWAVE]:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, true)
	GameState.sync_rate = GameState.get_sync_rate_max()
	GameState.debug_energy = GameState.get_debug_energy_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_fired = []
	_bus_fired = []
	_denied = []
	EventBus.shockwave_fired.connect(_on_bus_fired)
	EventBus.shockwave_denied.connect(_on_bus_denied)
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.shockwave_fired.connect(func(center: Vector2, radius: float) -> void: _fired.append([center, radius]))
	await wait_physics_frames(1)
	_sim.settle()
	assert_false(_isak.abilities.shockwave_enabled, "Retirado por datos")
	_isak.abilities.shockwave_enabled = true


func after_each() -> void:
	if EventBus.shockwave_fired.is_connected(_on_bus_fired):
		EventBus.shockwave_fired.disconnect(_on_bus_fired)
	if EventBus.shockwave_denied.is_connected(_on_bus_denied):
		EventBus.shockwave_denied.disconnect(_on_bus_denied)
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


func _on_bus_fired(center: Vector2, radius: float, source: Node2D) -> void:
	_bus_fired.append([center, radius, source])


func _on_bus_denied(reason: StringName) -> void:
	_denied.append(reason)


# --- Utilidades ---

func _shake() -> void:
	_sim.input.shake_pressed = true
	_sim.step()


## Agita y avanza hasta que nace la onda; devuelve los pasos desde la pulsacion.
func _shake_until_fired() -> int:
	var count: int = _fired.size()
	_shake()
	return 1 + _sim.step_until(func() -> bool: return _fired.size() > count, _sim.steps_for(1.0))


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

func test_data_and_action() -> void:
	var a: PlayerAbilities = _isak.abilities
	assert_almost_eq(a.shockwave_radius_px, 160.0, EPS, "2,5 tiles")
	assert_almost_eq(a.shockwave_windup_s, 0.15, EPS)
	assert_almost_eq(a.shockwave_exposed_s, 0.25, EPS)
	assert_almost_eq(a.shockwave_windup_s + a.shockwave_exposed_s, 0.4, EPS, "Pose total 0,4 s")
	assert_almost_eq(a.shockwave_stun_s, 3.0, EPS)
	assert_almost_eq(a.shockwave_energy_cost, 10.0, EPS)
	assert_almost_eq(a.shockwave_cooldown_s, 1.0, EPS)
	assert_true(InputMap.has_action(&"gesture_shake"), "Accion gesture_shake")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_U
	assert_true(InputMap.event_is_action(key, &"gesture_shake"), "U")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	assert_true(InputMap.event_is_action(pad, &"gesture_shake"), "LB")


func test_input_intent_is_a_flank() -> void:
	assert_eq(ActionPlayerInput.ACTION_SHAKE, &"gesture_shake", "Lee gesture_shake del Input Map")
	var input := PlayerInput.new()
	assert_false(input.has_any_intent())
	input.shake_pressed = true
	assert_true(input.has_any_intent(), "Corta la animacion de terminal")
	input.clear_just_pressed()
	assert_false(input.shake_pressed, "Flanco: se borra tras el paso")


# --- Pose, onda y coste ---

func test_pose_wave_cost_and_signals() -> void:
	var start_x: float = _isak.global_position.x
	var steps: int = _shake_until_fired()
	assert_eq(_sim.state(), PlayerState.SHOCKWAVE)
	assert_almost_eq(steps * DT, 0.15, DT * 1.5, "La onda nace a los 0,15 s")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max() - 10.0, EPS, "10 de energia")
	var center: Vector2 = _fired[0][0]
	assert_eq(center, _isak.get_shockwave_center(), "Centro en el celular")
	assert_almost_eq(center.y, _isak.global_position.y + _isak.get_pulse_origin().y, 1.0)
	assert_almost_eq(float(_fired[0][1]), 160.0, EPS)
	assert_eq(_bus_fired.size(), 1, "EventBus.shockwave_fired")
	assert_eq(_bus_fired[0][2], _isak, "Con Isak como fuente")
	assert_true(_isak.get_shockwave_effect().is_wave_visible(), "Anillo provisional")
	_sim.step(3)
	assert_gt(_isak.get_shockwave_effect().get_ring_radius(), 0.0, "El anillo crece")
	assert_almost_eq(_isak.global_position.x, start_x, 1.0, "Sin moverse")


func test_exposed_without_moving_or_jumping_then_rests() -> void:
	_shake_until_fired()
	var x: float = _isak.global_position.x
	_sim.input.move_axis = 1.0
	_sim.press_jump()
	_sim.step(_sim.frames(0.2))
	assert_eq(_sim.state(), PlayerState.SHOCKWAVE, "Sigue en la pose durante los 0,25 s")
	assert_true(_isak.is_on_floor(), "No salta")
	assert_almost_eq(_isak.global_position.x, x, 1.0, "No se mueve")
	assert_false(_isak.is_invulnerable(), "Sin invulnerabilidad: expuesto")
	_sim.step(_sim.frames(0.1))
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "Termina a los 0,4 s")
	_sim.input.move_axis = 0.0


## Pose final con AutoSprite (paso 24 del Mundo 4, 2026-10-28): sacude el celular
## (shockwave_shake, cuadro por el progreso de windup_s) sin mover el sprite y, al
## nacer la onda, el brazo extendido (shockwave_hold) durante la exposicion.
func test_pose_uses_the_autosprite_frames_without_the_provisional_shake() -> void:
	assert_true(_isak.has_shockwave_art(), "shockwave_shake / shockwave_hold en isak_frames.tres")
	var sprite: AnimatedSprite2D = _isak.get_sprite()
	var base: Vector2 = sprite.position
	_shake()
	assert_true(_isak.is_shockwaving())
	assert_eq(sprite.animation, Isak.ANIM_SHOCKWAVE_SHAKE, "Sacude el celular")
	var seen: Dictionary = {}
	while _fired.is_empty():
		seen[sprite.frame] = true
		assert_eq(sprite.position, base, "Sin la sacudida provisional del sprite")
		_sim.step()
	assert_gt(seen.size(), 1, "Los cuadros avanzan con la anticipacion")
	assert_eq(sprite.animation, Isak.ANIM_SHOCKWAVE_HOLD, "Onda: brazo extendido")
	assert_almost_eq(sprite.sprite_frames.get_frame_count(Isak.ANIM_SHOCKWAVE_HOLD) / sprite.sprite_frames.get_animation_speed(Isak.ANIM_SHOCKWAVE_HOLD),
		_isak.abilities.shockwave_exposed_s, 0.001, "Dura la exposicion")
	_sim.step_until(func() -> bool: return not _isak.is_shockwaving(), _sim.steps_for(1.0))
	assert_ne(sprite.animation, Isak.ANIM_SHOCKWAVE_HOLD, "Al terminar vuelve a su animacion")


func test_hurt_during_the_pose_cuts_it() -> void:
	_shake_until_fired()
	assert_true(_isak.take_hit(1.0), "Expuesto: el golpe entra")
	assert_eq(_sim.state(), PlayerState.HURT)
	assert_almost_eq(_isak.get_shockwave_cooldown_left(), 1.0, EPS, "El enfriamiento empieza al salir")


func test_hurt_before_the_wave_cancels_it() -> void:
	_shake()
	assert_eq(_sim.state(), PlayerState.SHOCKWAVE)
	_isak.take_hit(1.0)
	_sim.step(_sim.steps_for(0.3))
	assert_eq(_fired.size(), 0, "Cortado antes de nacer, no hay onda")


func test_stuns_every_enemy_in_range_on_both_sides_without_damage() -> void:
	var ahead := _bubble_at(200.0)
	var behind := _bubble_at(-150.0)
	var far := _bubble_at(260.0)
	var health: float = ahead.get_health()
	_shake_until_fired()
	assert_true(ahead.is_stunned(), "Delante, fuera del pulso (96 px) pero dentro de 160 px")
	assert_true(behind.is_stunned(), "Detras tambien: a todos los cercanos")
	assert_false(far.is_stunned(), "Fuera de la onda no le hace nada")
	assert_almost_eq(ahead.get_health(), health, EPS, "0 de dano")
	assert_almost_eq(behind.get_health(), health, EPS)


func test_receivers_decide_and_stun_scale() -> void:
	var receiver := Receiver.new()
	receiver.add_to_group(&"enemy")
	_world.add_child(receiver)
	_shake_until_fired()
	assert_eq(receiver.calls.size(), 1, "receive_shockwave(center, radius, stun_s)")
	assert_almost_eq(float(receiver.calls[0][1]), 160.0, EPS)
	assert_almost_eq(float(receiver.calls[0][2]), 3.0, EPS)
	assert_almost_eq(ShockwaveWave.stun_scale_for(StunS.new(), 3.0), 2.0, EPS, "3 s con su stun_s de 1,5 s")
	assert_almost_eq(ShockwaveWave.stun_scale_for(RefCounted.new(), 3.0), 1.0, EPS, "Sin aturdimiento propio, el suyo")
	assert_true(ShockwaveWave.reaches(Vector2.ZERO, 160.0, Rect2(150.0, -10.0, 20.0, 20.0)))
	assert_false(ShockwaveWave.reaches(Vector2.ZERO, 160.0, Rect2(120.0, 120.0, 20.0, 20.0)), "Circulo, no caja")


# --- Reglas ---

func test_cooldown_from_the_end_of_the_pose() -> void:
	_shake_until_fired()
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.SHOCKWAVE, _sim.steps_for(1.0))
	assert_almost_eq(_isak.get_shockwave_cooldown_left(), 1.0, DT * 1.5)
	_shake()
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "En enfriamiento no sale")
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_COOLDOWN)
	_sim.step(_sim.steps_for(1.0))
	assert_eq(_isak.shockwave_denial(), &"")
	_shake()
	assert_eq(_sim.state(), PlayerState.SHOCKWAVE, "Pasado 1 s, otra vez")


func test_without_energy_fizzles_and_warns() -> void:
	GameState.debug_energy = 9.0
	_shake()
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE)
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_ENERGY)
	assert_eq(_denied, [Isak.SHOCKWAVE_DENIED_ENERGY], "EventBus.shockwave_denied")
	assert_almost_eq(GameState.debug_energy, 9.0, EPS, "No cobra")


func test_only_on_the_floor() -> void:
	_sim.press_jump()
	_sim.step(5)
	assert_false(_isak.is_on_floor())
	_shake()
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "En el aire no sale")
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_AIR)
	assert_eq(_denied, [], "Sin aviso")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS)


func test_works_with_debug_active() -> void:
	_activate_debug()
	_shake_until_fired()
	assert_eq(_fired.size(), 1, "Con el Debug si")
	assert_true(DebugMode.is_active(), "No apaga el Debug")


func test_not_while_compressed() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, true)
	_sim.input.pinch_pressed = true
	_sim.step()
	assert_true(_isak.is_compressed())
	_shake()
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "Comprimido no sale")
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_BUSY)


func test_not_during_pulse_laser_or_dash_and_they_wait_for_it() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	GameState.set_ability_unlocked(GameState.ABILITY_GROUND_POUND, true)
	GameState.set_ability_unlocked(GameState.ABILITY_COMPRESS, true)
	_sim.input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.PULSE)
	_shake()
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_BUSY, "No durante el pulso")
	_sim.step_until(func() -> bool: return _sim.state() != PlayerState.PULSE, _sim.steps_for(1.0))
	_sim.input.laser_pressed = true
	_sim.step()
	assert_true(_isak.is_laser_charging() or _isak.is_laser_posing())
	_shake()
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "No durante el laser")
	_sim.step_until(func() -> bool: return not (_isak.is_laser_charging() or _isak.is_laser_posing()), _sim.steps_for(2.0))
	_sim.step(_sim.steps_for(0.5))
	_shake()
	assert_eq(_sim.state(), PlayerState.SHOCKWAVE)
	_sim.input.laser_pressed = true
	_sim.input.dash_pressed = true
	_sim.input.pulse_pressed = true
	_sim.step()
	assert_eq(_sim.state(), PlayerState.SHOCKWAVE, "Ni pulso, ni dash, ni laser durante Agitar")
	assert_eq(_isak.dash_denial(), Isak.DASH_DENIED_BUSY)
	assert_false(_isak.is_laser_charging(), "Sin laser")
	assert_eq(_isak.ground_pound_denial(), Isak.POUND_DENIED_BUSY)
	assert_eq(_isak.compress_denial(), Isak.COMPRESS_DENIED_BUSY)


func test_locked_without_ability_and_in_hub() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, false)
	_shake()
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "Sin la habilidad no sale")
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_LOCKED)
	GameState.set_ability_unlocked(GameState.ABILITY_SHOCKWAVE, true)
	_isak.level_mode = false
	_shake()
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "En el hub no sale")
	assert_eq(_denied, [], "Sin aviso")
	_isak.level_mode = true


func test_ends_hide_mode() -> void:
	EcoProgress.meet_eco_with_pulse()
	GameState.upgrade_levels[&"pulso"] = 4
	_sim.input.hide_pressed = true
	_sim.step()
	assert_true(_isak.is_hidden(), "Ocultarte activo")
	var reasons: Array = []
	_isak.get_hide_mode().ended.connect(func(r: StringName) -> void: reasons.append(r))
	_shake()
	assert_false(_isak.is_hidden(), "Agitar apaga el Ocultarte")
	assert_eq(reasons, [HideMode.REASON_SHOCKWAVE])
	_sim.step(3)
	_sim.input.hide_pressed = true
	_sim.step()
	assert_false(_isak.is_hidden(), "Durante la pose no se oculta")


func test_respawn_clears_pose_and_cooldown() -> void:
	_shake_until_fired()
	_isak.respawn(Vector2(_isak.global_position.x, 0.0))
	assert_eq(_sim.state(), PlayerState.IDLE)
	assert_almost_eq(_isak.get_shockwave_cooldown_left(), 0.0, EPS)
	assert_false(_isak.get_shockwave_effect().is_wave_visible())


# --- Retirado (2026-10-28) ---

func test_retired_by_data_never_fires_even_with_the_ability() -> void:
	_isak.abilities.shockwave_enabled = false
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_SHOCKWAVE), "Aunque este desbloqueado")
	assert_eq(_isak.shockwave_denial(), Isak.SHOCKWAVE_DENIED_LOCKED)
	_shake()
	_sim.step(_sim.steps_for(0.5))
	assert_ne(_sim.state(), PlayerState.SHOCKWAVE, "No entra en Agitar")
	assert_eq(_fired.size(), 0, "Sin onda")
	assert_eq(_bus_fired.size(), 0)
	assert_eq(_denied.size(), 0, "Sin chispa ni aviso")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS, "No gasta energia")


func test_retired_without_notice_nor_controls_row() -> void:
	var notices: Dictionary = AbilityNotices.load_data()
	assert_false((notices.get("abilities", {}) as Dictionary).has("shockwave"), "Sin aviso de control")
	assert_false(ControlBindings.actions().has(&"gesture_shake"), "Sin fila en Ajustes > Controles")
	assert_true(InputMap.has_action(&"gesture_shake"), "La accion sigue en el Input Map (gestos del port a movil)")
