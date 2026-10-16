# Pruebas del punto rojo (scripts/enemies/notification_badge.gd, paso 4 de
# docs/propuesta-1-2.md §10): dormido hasta que Isak se acerca, persecucion lenta
# (Isak lo deja atras), correa y vuelta a su sitio, el terreno lo para, aviso de
# 6-12 cuadros antes de lanzarse y dano solo lanzado (-10 con la invulnerabilidad
# de Isak), aturdimiento por el pulso (plataforma, aviso al despertar),
# INMUNE AL LASER DESPIERTO (chispa gris, el disparo se consume sin dano) y
# vulnerable aturdido (aturdir y rematar: dos disparos, drops), reaparicion y
# tiempo del mundo con el Debug. Isak y el punto rojo avanzan paso a paso.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BADGE_SCENE: PackedScene = preload("res://scenes/enemies/notification_badge.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const FAR: Vector2 = Vector2(-3000.0, 0.0)
const MAX_STEPS: int = 600

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {
		"laser": GameState.is_ability_unlocked(GameState.ABILITY_LASER),
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
		"energy": GameState.debug_energy,
	}
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = FAR
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved.laser)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)
	GameState.debug_energy = _saved.energy
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Utilidades ---

## Punto rojo con los pies en `feet` (por defecto flotando con el centro a la
## altura del celular de Isak de pie en el suelo: 56 px).
func _badge(feet: Vector2 = Vector2(400.0, -24.0)) -> NotificationBadge:
	var b := BADGE_SCENE.instantiate() as NotificationBadge
	b.position = feet
	b.free_on_pop = false
	b.target = _isak
	_world.add_child(b)
	b.set_physics_process(false)
	return b


func _step(badges: Array, count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for b: NotificationBadge in badges:
			b.step(DT)


func _place_isak(feet: Vector2) -> void:
	_isak.global_position = feet
	_isak.velocity = Vector2.ZERO


func _fake_pulse(center: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	add_child_autofree(area)
	return area


func _steps_until_state(b: NotificationBadge, state: StringName, max_steps: int = MAX_STEPS) -> int:
	for i: int in max_steps:
		if b.get_state() == state:
			return i
		_step([b])
	return -1


## Dispara el laser de Isak (real) y lo hace volar hasta que termine.
func _fire_and_fly(badges: Array) -> LaserProjectile:
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_sim.step()
	_sim.input.laser_pressed = false
	for i: int in ceili(_isak.abilities.laser_windup_s / DT) + 2:
		if not fired.is_empty():
			break
		_sim.step()
	_isak.laser_fired.disconnect(on_fired)
	if fired.is_empty():
		return null
	var p: LaserProjectile = fired[0]
	p.auto_process = false
	for i: int in MAX_STEPS:
		if p.is_finished():
			break
		p.step(DT)
	_sim.step(ceili(_isak.abilities.laser_cooldown_s / DT) + 1)
	return p


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())


# --- Capas y datos ---

func test_layers_and_data() -> void:
	var b: NotificationBadge = _badge()
	assert_eq(b.collision_layer, NotificationBadge.LAYER_ENEMY, "Capa enemy (el laser lo encuentra)")
	assert_eq(b.collision_mask, NotificationBadge.LAYER_WORLD, "Choca solo con el terreno")
	assert_true(b.is_in_group(NotificationBadge.GROUP), "Grupo enemy: LevelRunner lo reinicia al reaparecer")
	assert_eq(b.get_max_health(), 2.0, "Vida 2: dos disparos")
	assert_eq(b.drops, {"debug_energy": 25.0, "sync_rate": 10.0}, "Drops como la Burbuja")
	assert_between(b.anticipation_frames, 6, 12, "Aviso de 6-12 cuadros antes de danar")
	assert_between(b.wake_warn_frames, 6, 12, "Aviso de 6-12 cuadros antes de volver a perseguir")
	assert_lt(b.chase_speed_px_s, _isak.physics.walk_speed, "Persigue LENTO: mas despacio que Isak caminando")


# --- Dormido y persecucion ---

func test_sleeps_until_isak_comes_close_then_chases_slowly() -> void:
	var b: NotificationBadge = _badge()
	_place_isak(Vector2(400.0 - b.wake_radius_px - 200.0, 0.0))
	_step([b], 60)
	assert_eq(b.get_state(), NotificationBadge.STATE_IDLE, "Lejos: dormido")
	assert_almost_eq(b.global_position, b.get_spawn_position(), Vector2(EPS, EPS), "Quieto en su sitio")
	_place_isak(Vector2(400.0 - b.wake_radius_px + 64.0, 0.0))
	_step([b])
	assert_eq(b.get_state(), NotificationBadge.STATE_CHASE, "Cerca: despierta y persigue")
	var x0: float = b.global_position.x
	_step([b], 30)
	assert_lt(b.global_position.x, x0, "Va hacia Isak")
	assert_almost_eq(b.velocity.length(), b.chase_speed_px_s, 0.5, "A chase_speed_px_s")


func test_isak_walking_away_leaves_it_behind() -> void:
	var b: NotificationBadge = _badge()
	_place_isak(Vector2(200.0, 0.0))
	_step([b])
	assert_eq(b.get_state(), NotificationBadge.STATE_CHASE)
	var d0: float = b.get_center().distance_to(_isak.global_position)
	_sim.input.move_axis = -1.0
	_step([b], 60)
	_sim.input.move_axis = 0.0
	assert_gt(b.get_center().distance_to(_isak.global_position), d0 + 100.0, "No quedarse quieto: Isak se aleja")
	assert_ne(b.get_state(), NotificationBadge.STATE_LUNGE, "No lo alcanza")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sin dano")


func test_leaves_and_goes_home_when_isak_is_far_or_out_of_leash() -> void:
	var b: NotificationBadge = _badge()
	_place_isak(Vector2(200.0, 0.0))
	_step([b], 60)
	assert_eq(b.get_state(), NotificationBadge.STATE_CHASE)
	assert_ne(b.global_position, b.get_spawn_position(), "Se ha movido")
	_place_isak(Vector2(400.0 - b.leash_width_px, 0.0))
	_step([b])
	assert_eq(b.get_state(), NotificationBadge.STATE_RETURN, "Fuera de la correa: vuelve")
	assert_gt(_steps_until_state(b, NotificationBadge.STATE_IDLE), -1, "Llega a su sitio")
	assert_almost_eq(b.global_position, b.get_spawn_position(), Vector2(EPS, EPS), "Y se duerme alli")


func test_never_leaves_its_leash() -> void:
	var b: NotificationBadge = _badge()
	b.leash_width_px = 256.0
	b.give_up_radius_px = 2000.0
	_place_isak(Vector2(400.0 - 200.0, 0.0))
	_step([b], 240)
	var leash: Rect2 = b.get_leash_rect()
	assert_true(leash.grow(EPS).has_point(b.get_center()), "Dentro de su correa")


func test_terrain_stops_it() -> void:
	var b: NotificationBadge = _badge()
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32.0, 400.0)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(300.0, -200.0)
	_world.add_child(wall)
	_place_isak(Vector2(150.0, 0.0))
	await wait_physics_frames(2)
	_step([b], 180)
	assert_gt(b.get_body_rect().position.x, 300.0 + 16.0 - 1.0, "No atraviesa la pared")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)


# --- Aviso y dano ---

func test_warns_before_lunging_and_only_hurts_when_lunging() -> void:
	var b: NotificationBadge = _badge()
	# Isak justo dentro del radio de lanzamiento.
	_place_isak(Vector2(400.0 - 80.0, 0.0))
	_step([b])
	assert_eq(_steps_until_state(b, NotificationBadge.STATE_ANTICIPATE, 10), 1, "Se para y avisa")
	assert_false(b.is_dangerous(), "Avisando no dana")
	var frames: int = 0
	while b.get_state() == NotificationBadge.STATE_ANTICIPATE and frames < MAX_STEPS:
		assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sin dano durante el aviso")
		_step([b])
		frames += 1
	var anticipation_s: float = frames * DT
	assert_almost_eq(anticipation_s, b.get_anticipation_s(), DT * 1.5, "Dura anticipation_frames a anim_fps")
	assert_between(roundi(anticipation_s * 60.0 / 5.0), 6, 12, "Entre 6 y 12 cuadros de 12 fps")
	assert_eq(b.get_animation(), &"lunge")
	var hits: Array = []
	b.hit_player.connect(func(a: float) -> void: hits.append(a))
	_step([b], roundi(b.lunge_s / DT) + 2)
	assert_eq(hits, [10.0], "Lanzado lo alcanza: -10 de Sync Rate")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, EPS)
	assert_true(_isak.is_invulnerable(), "Invulnerabilidad breve ya existente")
	_step([b], 30)
	assert_eq(hits.size(), 1, "Un solo golpe mientras dura la invulnerabilidad")


func test_touching_while_chasing_does_not_hurt() -> void:
	var b: NotificationBadge = _badge()
	b.lunge_radius_px = -1.0  # sin lanzarse
	_place_isak(Vector2(400.0, 0.0))
	_step([b], 30)
	assert_eq(b.get_state(), NotificationBadge.STATE_CHASE)
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sin aviso no hay dano")


# --- Pulso ---

func test_pulse_stuns_it_into_a_platform_then_it_warns_and_wakes() -> void:
	var b: NotificationBadge = _badge()
	_place_isak(Vector2(200.0, 0.0))
	_step([b], 10)
	assert_false(b.receive_pulse(_fake_pulse(b.get_center() + Vector2(200.0, 0.0), 96.0)), "Fuera del radio, nada")
	assert_true(b.receive_pulse(_fake_pulse(b.get_center() + Vector2(60.0, 0.0), 96.0)), "Dentro del radio")
	assert_eq(b.get_state(), NotificationBadge.STATE_STUNNED)
	assert_true(b.is_platform(), "Aturdido: plataforma de una via")
	assert_false(b.is_dangerous())
	var pos: Vector2 = b.global_position
	var steps: int = _steps_until_state(b, NotificationBadge.STATE_WAKE)
	assert_almost_eq(steps * DT, b.stun_duration_s - b.get_wake_warn_s(), DT * 1.5, "Aviso al final")
	assert_eq(b.global_position, pos, "Quieto en el aire")
	assert_eq(b.get_animation(), &"wake")
	steps = _steps_until_state(b, NotificationBadge.STATE_CHASE)
	assert_almost_eq(steps * DT, b.get_wake_warn_s(), DT * 1.5, "Despierta tras el aviso")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)


# --- Laser ---

func test_awake_it_is_immune_to_the_laser_and_the_shot_is_spent() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	var b: NotificationBadge = _badge(Vector2(500.0, -24.0))
	_place_isak(Vector2(200.0, 0.0))
	_sim.settle()
	var deflects: Array = []
	b.deflected.connect(func() -> void: deflects.append(true))
	var energy0: float = GameState.debug_energy
	var p: LaserProjectile = _fire_and_fly([])
	assert_not_null(p, "Disparo")
	assert_eq(p.get_hit_target(), b, "El disparo choca con el (no lo atraviesa)")
	assert_eq(b.get_health(), b.get_max_health(), "Despierto: sin dano")
	assert_eq(deflects.size(), 1, "Chispa gris")
	assert_true(b.is_deflecting())
	assert_almost_eq(GameState.debug_energy, energy0 - _isak.abilities.laser_energy_cost, EPS,
		"Se consume solo lo del disparo")
	b.step(b.deflect_s + DT)
	assert_false(b.is_deflecting(), "La chispa se apaga")


func test_stun_and_finish_with_two_shots_drops_recharges() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	var b: NotificationBadge = _badge(Vector2(500.0, -24.0))
	_place_isak(Vector2(200.0, 0.0))
	_sim.settle()
	b.stun()
	_fire_and_fly([])
	assert_eq(b.get_health(), 1.0, "Aturdido: el laser le hace dano")
	assert_true(b.is_flashing())
	assert_false(b.is_deflecting())
	_fire_and_fly([])
	assert_true(b.is_defeated(), "Dos disparos: derrotado")
	assert_false(b.is_help_available(), "Derrotado: ya no ayuda")
	var drops: int = 0
	for child: Node in _world.get_children():
		if child is RechargePickup:
			drops += 1
	assert_eq(drops, 2, "Suelta energia y Sync Rate")
	b.receive_pulse(_fake_pulse(b.get_center(), 96.0))
	assert_true(b.is_defeated(), "Muerto no se aturde")


# --- Reaparicion ---

func test_reset_on_respawn_and_dead_stays_dead() -> void:
	var b: NotificationBadge = _badge()
	_place_isak(Vector2(200.0, 0.0))
	_step([b], 60)
	b.stun()
	b.take_damage(1.0)
	b.reset_patrol()
	assert_eq(b.get_state(), NotificationBadge.STATE_IDLE, "Dormido")
	assert_eq(b.global_position, b.get_spawn_position(), "En su sitio")
	assert_eq(b.get_health(), b.get_max_health(), "Vida llena")
	assert_false(b.is_platform())
	b.pop()
	b.reset_patrol()
	assert_true(b.is_defeated(), "Derrotado no reaparece")


# --- Tiempo del mundo ---

func test_debug_slows_chase_and_stun() -> void:
	var b: NotificationBadge = _badge()
	b.lunge_radius_px = -1.0  # sin lanzarse
	_place_isak(Vector2(400.0 - 300.0, 0.0))
	_step([b])
	var x0: float = b.global_position.x
	_step([b], 30)
	var normal: float = x0 - b.global_position.x
	_activate_debug()
	x0 = b.global_position.x
	_step([b], 30)
	var slowed: float = x0 - b.global_position.x
	assert_almost_eq(slowed / normal, 0.5, 0.03, "Con el Debug persigue a x0,5")
	b.stun()
	_step([b], 60)
	assert_almost_eq(b.get_stun_left(), b.stun_duration_s - 0.5, 0.02, "El aturdimiento corre a x0,5")
