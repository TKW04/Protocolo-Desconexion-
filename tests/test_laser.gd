# Pruebas del laser de Isak (decision del usuario 2026-10-15): teclas (pulso en
# G, ya no en J; laser en F), habilitacion por GameState, gasto de la energia
# compartida con el Debug, sin energia no dispara (chispa y laser_denied),
# enfriamiento, direccion, choque con el terreno y vida de la Burbuja (dos
# disparos la matan y suelta sus drops; el pulso solo aturde; params.health).
# Isak, la Burbuja y el proyectil avanzan paso a paso con delta fijo.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const MAX_STEPS: int = 120

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {
		"laser": GameState.is_ability_unlocked(GameState.ABILITY_LASER),
		"energy": GameState.debug_energy,
	}
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
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
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved.laser)
	GameState.debug_energy = _saved.energy
	GameState.sync_rate = GameState.SYNC_RATE_MAX


# --- Utilidades ---

## Pulsa laser un paso y avanza hasta que sale el disparo (o nada). Devuelve el
## proyectil o null.
func _fire() -> LaserProjectile:
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_sim.step()
	var steps: int = ceili(_isak.abilities.laser_windup_s / DT) + 2
	for i: int in steps:
		if not fired.is_empty():
			break
		_sim.step()
	_isak.laser_fired.disconnect(on_fired)
	if fired.is_empty():
		return null
	fired[0].auto_process = false
	return fired[0]


## Avanza el proyectil hasta que termine (choque o alcance).
func _fly(p: LaserProjectile, bubbles: Array = []) -> void:
	for i: int in MAX_STEPS:
		if p.is_finished():
			return
		p.step(DT)
		for b: AlertBubble in bubbles:
			b.step(DT)


func _wait_cooldown() -> void:
	_sim.step(ceili(_isak.abilities.laser_cooldown_s / DT) + 1)


func _bubble(x: float) -> AlertBubble:
	var b := BUBBLE_SCENE.instantiate() as AlertBubble
	b.position = Vector2(x, 0.0)
	b.patrol_range_px = 0.0
	b.free_on_pop = false
	b.target = _isak
	_world.add_child(b)
	b.set_physics_process(false)
	return b


func _wall(x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64.0, 256.0)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(x + 32.0, -128.0)
	_world.add_child(body)
	return body


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	return ev


# --- Teclas ---

func test_pulse_is_g_not_j_and_laser_is_f() -> void:
	assert_true(InputMap.has_action(&"laser"), "Accion laser en el Input Map")
	assert_true(InputMap.event_is_action(_key(KEY_G), &"pulse"), "G lanza el pulso")
	assert_false(InputMap.event_is_action(_key(KEY_J), &"pulse"), "J ya no lanza el pulso")
	assert_true(InputMap.event_is_action(_key(KEY_F), &"laser"), "F dispara el laser")
	assert_false(InputMap.event_is_action(_key(KEY_F), &"pulse"))
	assert_false(InputMap.event_is_action(_key(KEY_G), &"laser"))
	for action: StringName in InputMap.get_actions():
		if action != &"pulse" and not String(action).begins_with("ui_"):
			assert_false(InputMap.event_is_action(_key(KEY_G), action), "G solo es pulso (%s)" % action)
		if action != &"laser" and not String(action).begins_with("ui_"):
			assert_false(InputMap.event_is_action(_key(KEY_F), action), "F solo es laser (%s)" % action)
	var pad := InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_TRIGGER_LEFT
	pad.axis_value = 1.0
	assert_true(InputMap.event_is_action(pad, &"laser"), "Gatillo izquierdo del mando")


func test_values_from_data() -> void:
	var a: PlayerAbilities = _isak.abilities
	assert_almost_eq(a.laser_energy_cost, 10.0, EPS)
	assert_almost_eq(a.laser_damage, 1.0, EPS)
	assert_almost_eq(a.laser_cooldown_s, 0.4, EPS)
	assert_gt(a.laser_windup_s, 0.0, "Anticipacion minima")
	assert_lte(a.laser_windup_s, 0.1)
	assert_gt(a.laser_speed_px_s, 0.0)
	assert_gt(a.laser_range_px, 0.0)


# --- Disparo y energia ---

func test_fire_spends_energy_and_spawns_projectile() -> void:
	var before: float = GameState.debug_energy
	var p: LaserProjectile = _fire()
	assert_not_null(p, "Sale el disparo")
	assert_almost_eq(GameState.debug_energy, before - _isak.abilities.laser_energy_cost, EPS,
		"Gasta la energia del Debug (compartida)")
	assert_eq(p.get_parent(), _world, "El proyectil va en el nivel, no dentro de Isak")
	assert_almost_eq(p.global_position.y, _isak.global_position.y + _isak.get_pulse_origin().y, EPS,
		"Sale a la altura del celular")
	assert_almost_eq(p.direction, 1.0, EPS, "Hacia donde mira Isak")


func test_windup_before_projectile() -> void:
	_sim.input.laser_pressed = true
	_sim.step()
	assert_true(_isak.is_laser_charging(), "Primero la anticipacion")
	assert_eq(_isak.get_laser_muzzle().get_mode(), LaserMuzzle.Mode.CHARGE, "Destello en el celular")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS, "Aun no cobra")


func test_without_energy_does_not_fire() -> void:
	GameState.debug_energy = _isak.abilities.laser_energy_cost - 1.0
	var denied: Array[bool] = []
	var on_denied := func() -> void: denied.append(true)
	EventBus.laser_denied.connect(on_denied)
	var p: LaserProjectile = _fire()
	EventBus.laser_denied.disconnect(on_denied)
	assert_null(p, "Sin energia suficiente no dispara")
	assert_almost_eq(GameState.debug_energy, _isak.abilities.laser_energy_cost - 1.0, EPS, "No gasta")
	assert_eq(denied.size(), 1, "Avisa con EventBus.laser_denied")
	assert_eq(_isak.get_laser_muzzle().get_mode(), LaserMuzzle.Mode.FIZZLE, "Chispa sutil en el celular")


func test_locked_ability_does_nothing() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, false)
	var p: LaserProjectile = _fire()
	assert_null(p, "Bloqueado hasta obtenerlo")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), EPS)


func test_cooldown_between_shots() -> void:
	var first: LaserProjectile = _fire()
	assert_not_null(first)
	var second: LaserProjectile = _fire()
	assert_null(second, "Dentro del enfriamiento no dispara")
	_wait_cooldown()
	var third: LaserProjectile = _fire()
	assert_not_null(third, "Tras laser_cooldown_s vuelve a disparar")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max() - 2.0 * _isak.abilities.laser_energy_cost, EPS)


func test_fires_left_when_facing_left() -> void:
	_sim.input.move_axis = -1.0
	_sim.step(3)
	_sim.input.move_axis = 0.0
	_sim.settle()
	var p: LaserProjectile = _fire()
	assert_almost_eq(p.direction, -1.0, EPS)
	var x0: float = p.global_position.x
	p.step(DT)
	assert_lt(p.global_position.x, x0, "Vuela a la izquierda")


func test_projectile_expires_at_range() -> void:
	var p: LaserProjectile = _fire()
	var expired: Array[bool] = []
	p.expired.connect(func() -> void: expired.append(true))
	_fly(p)
	assert_true(p.is_finished())
	assert_eq(expired.size(), 1, "Se apaga al llegar al alcance")
	assert_almost_eq(p.get_traveled(), _isak.abilities.laser_range_px, 1.0)


func test_projectile_stops_at_wall() -> void:
	var wall_x: float = _isak.global_position.x + 200.0
	_wall(wall_x)
	await wait_physics_frames(2)
	var p: LaserProjectile = _fire()
	var hits: Array = []
	p.hit.connect(func(target: Node, _damage: float) -> void: hits.append(target))
	_fly(p)
	assert_eq(hits.size(), 1, "Choca con el terreno")
	assert_null(hits[0], "El terreno no tiene on_laser_hit")
	assert_almost_eq(p.global_position.x, wall_x, 1.0, "Se para en la cara del muro")


func test_laser_target_lookup_walks_parents() -> void:
	var b: AlertBubble = _bubble(-3000.0)
	var plank: Node = b.get_node(^"Platform")
	assert_eq(LaserProjectile.find_laser_target(plank), b, "La plataforma lleva a la Burbuja")
	assert_null(LaserProjectile.find_laser_target(_world))


# --- Pose del laser (Isak sube el celular; 2026-10-15) ---

## Hay un pixel opaco del cuadro `frame` de ANIM_LASER a 3 px o menos de `offset`.
func _phone_near(frame: int, offset: Vector2) -> bool:
	var sprite := _isak.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var image: Image = sprite.sprite_frames.get_frame_texture(Isak.ANIM_LASER, frame).get_image()
	var at := Vector2i(image.get_width() / 2, image.get_height()) + Vector2i(offset)
	for y: int in range(at.y - 3, at.y + 4):
		for x: int in range(at.x - 3, at.x + 4):
			if image.get_pixel(x, y).a > 0.5:
				return true
	return false


func test_laser_pose_offsets_are_on_the_phone() -> void:
	var sprite := _isak.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var count: int = sprite.sprite_frames.get_frame_count(Isak.ANIM_LASER)
	assert_eq(_isak.laser_pose_phone_offsets.size(), count, "Un celular por cuadro de la pose")
	for i: int in count:
		assert_true(_phone_near(i, _isak.laser_pose_phone_offsets[i]), "Celular del cuadro %d" % i)
	assert_eq(_isak.laser_pose_phone_offsets[count - 1], _isak.pulse_effect_origin,
		"Con el brazo extendido, el mismo punto que la onda del pulso")


func test_laser_pose_raises_phone_and_beam_starts_on_it() -> void:
	_sim.input.laser_pressed = true
	_sim.step()
	assert_true(_isak.is_laser_posing(), "La anticipacion ya muestra la pose")
	assert_eq(_isak.get_animation(), Isak.ANIM_LASER)
	assert_eq(_isak.get_animation_frame(), 0, "Empieza con el celular abajo")
	assert_almost_eq(_isak.get_laser_muzzle().position, _isak.get_laser_origin(), Vector2.ONE * EPS,
		"El destello sigue al celular")
	var fired: Array[LaserProjectile] = []
	var on_fired := func(q: LaserProjectile) -> void: fired.append(q)
	_isak.laser_fired.connect(on_fired)
	_sim.step_until(func() -> bool: return not fired.is_empty(), 10)
	_isak.laser_fired.disconnect(on_fired)
	assert_eq(fired.size(), 1)
	var p: LaserProjectile = fired[0]
	var last: int = _isak.laser_pose_phone_offsets.size() - 1
	assert_eq(_isak.get_animation_frame(), last, "Dispara con el brazo extendido")
	assert_almost_eq(p.global_position, _isak.global_position + _isak.get_laser_origin(), Vector2.ONE * EPS,
		"El haz nace en el celular del cuadro")
	_sim.step(roundi(_isak.laser_pose_hold_s / DT) - 2)
	assert_true(_isak.is_laser_posing(), "Mantiene la pose un momento")
	_sim.step(4)
	assert_false(_isak.is_laser_posing(), "Luego la quita")
	assert_eq(_isak.get_animation(), Isak.ANIM_IDLE, "Y vuelve a la animacion del estado")


func test_hurt_cuts_laser_pose() -> void:
	assert_not_null(_fire())
	assert_true(_isak.is_laser_posing())
	_isak.take_hit(1.0)
	assert_false(_isak.is_laser_posing())
	assert_eq(_isak.get_animation(), Isak.ANIM_HURT)


## Avanza hasta que termina la pose del laser (con margen).
func _wait_pose_end() -> void:
	_sim.step_until(func() -> bool: return not _isak.is_laser_posing(),
		_sim.steps_for(_isak.abilities.laser_windup_s + _isak.laser_pose_hold_s))


func test_laser_locks_movement_from_data() -> void:
	assert_true(_isak.abilities.laser_locks_movement, "laser_locks_movement en isak_abilities.json")


# Cambio 2026-10-15: antes Isak se movia libre durante la pose; ahora se detiene
# como con el pulso (apply_horizontal(0): friccion en el suelo).
func test_moving_and_firing_stops_on_ground() -> void:
	_sim.input.move_axis = 1.0
	_sim.step(60)
	assert_almost_eq(_isak.velocity.x, _isak.physics.walk_speed, EPS, "Ya camina a velocidad maxima")
	_sim.input.laser_pressed = true
	_sim.step()
	assert_true(_isak.is_laser_locking_movement(), "La anticipacion ya bloquea el movimiento")
	var x0: float = _isak.global_position.x
	var v0: float = _isak.velocity.x
	_sim.step()
	assert_almost_eq(_isak.velocity.x, move_toward(v0, 0.0, _isak.physics.ground_friction * DT), EPS,
		"Frena con la friccion del suelo, como el pulso")
	_sim.step(_sim.frames(_isak.physics.walk_speed / _isak.physics.ground_friction) + 1)
	assert_true(_isak.is_laser_posing(), "Sigue la pose")
	assert_almost_eq(_isak.velocity.x, 0.0, EPS, "Quieto aunque se mantenga la direccion")
	var x_stopped: float = _isak.global_position.x
	_sim.step(3)
	assert_almost_eq(_isak.global_position.x, x_stopped, EPS, "No se desliza")
	assert_lt(x_stopped - x0, 16.0, "Apenas avanza al frenar")
	assert_eq(_isak.get_state_name(), PlayerState.RUN, "Sigue en su estado")
	assert_eq(_isak.get_animation(), Isak.ANIM_LASER, "Con la pose del laser")


func test_running_and_firing_also_stops() -> void:
	_sim.input.move_axis = 1.0
	_sim.input.run_held = true
	_sim.step(60)
	_sim.input.laser_pressed = true
	_sim.step(1 + _sim.frames(_isak.physics.run_speed / _isak.physics.ground_friction) + 1)
	assert_true(_isak.is_laser_posing())
	assert_almost_eq(_isak.velocity.x, 0.0, EPS, "Corriendo tambien se detiene")


func test_opposite_direction_does_not_turn_during_pose() -> void:
	_sim.input.laser_pressed = true
	_sim.step()
	_sim.input.move_axis = -1.0
	_sim.step(4)
	assert_true(_isak.is_laser_posing())
	assert_eq(_isak.facing, 1.0, "No se gira durante la pose")
	assert_almost_eq(_isak.velocity.x, 0.0, EPS, "Ni se mueve")


func test_air_behaves_like_pulse() -> void:
	_sim.input.move_axis = 1.0
	_sim.step(60)
	_sim.press_jump()
	_sim.step(3)
	assert_false(_isak.is_on_floor(), "En el aire")
	_sim.input.laser_pressed = true
	_sim.step()
	assert_true(_isak.is_laser_locking_movement())
	var v0: Vector2 = _isak.velocity
	_sim.step()
	assert_false(_isak.is_on_floor())
	assert_almost_eq(_isak.velocity.x, move_toward(v0.x, 0.0, _isak.physics.air_acceleration * DT), EPS,
		"En el aire frena con air_acceleration (apply_horizontal(0), como el pulso)")
	var g: float = _isak.physics.gravity * (_isak.physics.fall_gravity_multiplier if v0.y >= 0.0 else 1.0)
	assert_almost_eq(_isak.velocity.y, v0.y + g * DT, EPS, "La gravedad no cambia")


func test_control_returns_after_pose() -> void:
	_sim.input.move_axis = 1.0
	_sim.step(60)
	_sim.input.laser_pressed = true
	_sim.step()
	_wait_pose_end()
	assert_false(_isak.is_laser_locking_movement(), "Sin pose, sin bloqueo")
	_sim.step(30)
	assert_almost_eq(_isak.velocity.x, _isak.physics.walk_speed, EPS, "Recupera el control")
	assert_eq(_isak.get_animation(), Isak.ANIM_WALK, "Y la animacion de caminar")


func test_lock_lasts_as_long_as_pose() -> void:
	_sim.input.laser_pressed = true
	_sim.step()
	var steps: int = _sim.step_until(func() -> bool: return not _isak.is_laser_locking_movement(), 60)
	var expected: int = _sim.frames(_isak.abilities.laser_windup_s + _isak.laser_pose_hold_s)
	assert_almost_eq(steps, expected, 2, "Bloqueo = anticipacion + brazo extendido (0,30 s)")


func test_lock_can_be_disabled_in_data() -> void:
	_isak.abilities.laser_locks_movement = false
	_sim.input.move_axis = 1.0
	_sim.step(60)
	_sim.input.laser_pressed = true
	_sim.step(6)
	assert_true(_isak.is_laser_posing())
	assert_almost_eq(_isak.velocity.x, _isak.physics.walk_speed, EPS, "Con false se mueve libre (antes)")
	_isak.abilities.laser_locks_movement = true


func test_lock_does_not_change_cooldown() -> void:
	assert_almost_eq(_isak.abilities.laser_cooldown_s, 0.4, EPS, "Enfriamiento sin cambios")
	_sim.input.move_axis = 1.0
	_sim.step(60)
	_sim.input.laser_pressed = true
	_sim.step()
	assert_almost_eq(_isak.get_laser_cooldown_left(), _isak.abilities.laser_cooldown_s, EPS)
	_wait_pose_end()
	assert_gt(_isak.get_laser_cooldown_left(), 0.0, "La pose acaba antes que el enfriamiento")
	_sim.input.laser_pressed = true
	_sim.step()
	assert_false(_isak.is_laser_posing(), "No dispara durante el enfriamiento")


func test_hurt_ends_lock_with_knockback() -> void:
	_sim.input.laser_pressed = true
	_sim.step(3)
	assert_true(_isak.is_laser_locking_movement())
	_isak.take_hit(-1.0)
	assert_false(_isak.is_laser_locking_movement(), "El golpe corta la pose")
	_sim.step()
	assert_lt(_isak.velocity.x, 0.0, "El retroceso no se bloquea")


func test_jump_during_pose_keeps_lock_until_pose_ends() -> void:
	_sim.input.laser_pressed = true
	_sim.step()
	_sim.input.move_axis = 1.0
	_sim.press_jump()
	assert_eq(_isak.get_state_name(), PlayerState.JUMP, "Puede saltar durante la pose (como antes)")
	assert_true(_isak.is_laser_posing(), "El salto no corta la pose (como antes)")
	assert_almost_eq(_isak.velocity.x, 0.0, EPS, "Sube en vertical mientras dura")
	_wait_pose_end()
	_sim.step(10)
	assert_gt(_isak.velocity.x, 0.0, "Luego recupera el control en el aire")


# --- Vida de la Burbuja ---

func test_bubble_health_from_data() -> void:
	var b: AlertBubble = _bubble(-3000.0)
	assert_almost_eq(b.get_max_health(), 2.0, EPS, "health 2 en data/enemies/alert_bubble.json")
	assert_almost_eq(b.get_health(), 2.0, EPS)


func test_level_params_override_health() -> void:
	var b: AlertBubble = _bubble(-3000.0)
	# GeneratedLevel aplica params.health -> max_health tras _ready.
	assert_eq(GeneratedLevel.ENEMY_PARAM_ALIASES.get("health"), "max_health")
	b.set(&"max_health", 5.0)
	assert_almost_eq(b.get_max_health(), 5.0, EPS)
	assert_almost_eq(b.get_health(), 5.0, EPS, "Vida llena con el nuevo maximo")


func test_two_shots_kill_bubble_with_drops() -> void:
	var b: AlertBubble = _bubble(_isak.global_position.x + 300.0)
	await wait_physics_frames(2)
	var defeated: Array[Node2D] = []
	var on_defeat := func(enemy: Node2D) -> void: defeated.append(enemy)
	EventBus.enemy_defeated.connect(on_defeat)
	var p: LaserProjectile = _fire()
	_fly(p, [b])
	assert_eq(p.get_hit_target(), b, "El disparo alcanza a la Burbuja")
	assert_almost_eq(b.get_health(), 1.0, EPS, "Un disparo: 1 de dano")
	assert_true(b.is_flashing(), "Parpadea al recibir dano")
	assert_eq(b.get_state(), AlertBubble.STATE_PATROL, "Sigue viva")
	_wait_cooldown()
	var p2: LaserProjectile = _fire()
	_fly(p2, [b])
	EventBus.enemy_defeated.disconnect(on_defeat)
	assert_eq(b.get_state(), AlertBubble.STATE_POPPED, "Segundo disparo: vida 0, muere")
	assert_eq(defeated, [b] as Array[Node2D], "Avisa por EventBus.enemy_defeated")
	var kinds: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(RechargePickup.GROUP):
		var r := node as RechargePickup
		kinds[r.kind] = r.amount
	assert_almost_eq(float(kinds.get(RechargePickup.KIND_ENERGY, 0.0)), 25.0, EPS, "Suelta +25 de energia")
	assert_almost_eq(float(kinds.get(RechargePickup.KIND_SYNC, 0.0)), 10.0, EPS, "Suelta +10 de Sync")


func test_stunned_bubble_also_takes_damage_and_pulse_only_stuns() -> void:
	var b: AlertBubble = _bubble(-3000.0)
	b.stun()
	assert_almost_eq(b.get_health(), 2.0, EPS, "El pulso aturde pero no quita vida")
	assert_true(b.take_damage(1.0))
	assert_true(b.is_stunned(), "Sigue aturdida tras el golpe")
	assert_true(b.take_damage(1.0))
	assert_eq(b.get_state(), AlertBubble.STATE_POPPED)
	assert_false(b.take_damage(1.0), "Muerta no recibe mas dano")


func test_enemy_health_component() -> void:
	var h := EnemyHealth.new(3.0)
	assert_false(h.take_damage(1.0))
	assert_false(h.take_damage(0.0), "Dano 0 no cuenta")
	assert_almost_eq(h.health, 2.0, EPS)
	assert_true(h.take_damage(5.0), "Llega a 0")
	assert_true(h.is_depleted())
	assert_almost_eq(h.health, 0.0, EPS)
	var drops: Dictionary = EnemyHealth.parse_drops({"_notes": "x", "debug_energy": 25, "sync_rate": 10.0})
	assert_eq(drops, {"debug_energy": 25.0, "sync_rate": 10.0})
