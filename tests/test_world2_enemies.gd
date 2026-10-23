# Enemigos y objetos del feed del Mundo 2 (paso 7 de docs/propuesta-mundo-2.md
# §8, §3.4): «Un video mas» (clone_zone + video_clone: nace un clon cada 1,5 s
# con Isak dentro tras un aviso de 0,75 s, tope 6, en el borde mas lejano; un
# golpe al suelo dentro de la zona los elimina todos; clon de vida 1 que
# patrulla, dana al contacto, el pulso lo aturde y no suelta nada), Comentarista
# (bocadillo vertical cada 2,5 s con aviso de 0,75 s; el pulso lo aturde; el
# laser rebota despierto y aturdido lo derrota) y muro «Cargando mas…» (el pulso
# y el laser rebotan; solo se rompe con 3 golpes al suelo cercanos, para siempre).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ZONE_SCENE: PackedScene = preload("res://scenes/levels/clone_zone.tscn")
const CLONE_SCENE: PackedScene = preload("res://scenes/enemies/video_clone.tscn")
const COMMENTER_SCENE: PackedScene = preload("res://scenes/enemies/commenter.tscn")
const WALL_SCENE: PackedScene = preload("res://scenes/levels/loading_wall.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const T: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D


func before_each() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = Vector2(-3000.0, 0.0)
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _stand_at(col: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()


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


func _count_pickups() -> int:
	var n: int = 0
	for child: Node in _world.get_children():
		if child is RechargePickup and not child.is_queued_for_deletion():
			n += 1
	return n


# --- Zona de clones ---

## Zona de las columnas 0-9 y filas -4..-1 (sobre el suelo de y = 0). Los clones
## que nacen quedan sin _physics_process (avanzan con step) y sin liberarse.
func _zone() -> CloneZone:
	var z := ZONE_SCENE.instantiate() as CloneZone
	z.zone = [0, -4, 10, 4]
	_world.add_child(z)
	z.set_physics_process(false)
	z.target = _isak
	z.clone_spawned.connect(func(c: VideoClone) -> void:
		c.set_physics_process(false)
		c.free_on_pop = false)
	return z


func _step_zone(z: CloneZone, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		z.step(DT)


func test_zone_spawns_a_clone_every_spawn_s_after_its_warning() -> void:
	var z: CloneZone = _zone()
	assert_almost_eq(z.spawn_s, 1.5, EPS, "Cada 1,5 s (§3.4)")
	assert_almost_eq(z.get_warn_s(), 0.75, EPS, "Aviso de 9 cuadros a 12 fps")
	_stand_at(3)
	assert_true(z.is_player_inside())
	_step_zone(z, 1.45)
	assert_false(z.is_warning(), "Antes de 1,5 s, nada")
	_step_zone(z, 0.1)
	assert_true(z.is_warning(), "A los 1,5 s empieza el aviso (marco de video)")
	assert_eq(z.get_clone_count(), 0, "Durante el aviso aun no hay clon: nada dana")
	_step_zone(z, 0.8)
	assert_eq(z.get_clone_count(), 1, "Tras el aviso nace el clon")
	_step_zone(z, 1.5)
	assert_eq(z.get_spawned_total(), 2, "Otro a los 3 s")


func test_zone_caps_clones_at_six() -> void:
	var z: CloneZone = _zone()
	_stand_at(3)
	_step_zone(z, 20.0)
	assert_eq(z.max_clones, 6)
	assert_eq(z.get_clone_count(), 6, "Tope 6")
	assert_eq(z.get_spawned_total(), 6)


func test_zone_spawns_at_the_far_edge_and_clones_stay_inside() -> void:
	var z: CloneZone = _zone()
	_stand_at(2)
	var points: Array = []
	z.spawn_warned.connect(func(p: Vector2) -> void: points.append(p))
	_step_zone(z, 2.3)
	assert_eq(points.size(), 1)
	assert_almost_eq(points[0].x, 9.5 * T, EPS, "Isak a la izquierda: nace en el borde derecho")
	assert_almost_eq(points[0].y, 0.0, EPS, "A ras de la fila de abajo de la zona")
	var clone: VideoClone = z.get_clones()[0]
	assert_eq(clone.get_direction(), -1.0, "Entra hacia el centro de la zona")
	for i: int in 600:
		clone.step(DT)
		assert_true(clone.global_position.x >= 0.5 * T - 4.0 and clone.global_position.x <= 9.5 * T + 4.0,
			"Patrulla dentro de las columnas de la zona")
		if clone.get_state() != VideoClone.STATE_PATROL:
			break


func test_leaving_the_zone_resets_the_clock() -> void:
	var z: CloneZone = _zone()
	_stand_at(3)
	_step_zone(z, 1.2)
	_stand_at(14)
	assert_false(z.is_player_inside())
	_step_zone(z, 0.1)
	assert_almost_eq(z.get_inside_time(), 0.0, EPS, "Fuera, el reloj vuelve a cero")
	_step_zone(z, 5.0)
	assert_eq(z.get_spawned_total(), 0, "Sin Isak dentro no nace nada")
	_stand_at(3)
	_step_zone(z, 1.2)
	assert_false(z.is_warning(), "Al volver empieza otra vez desde cero")


func test_one_ground_pound_inside_clears_every_clone() -> void:
	var z: CloneZone = _zone()
	_stand_at(5)
	_step_zone(z, 9.0)
	var clones: Array[VideoClone] = z.get_clones()
	assert_gt(clones.size(), 3, "Varios clones")
	var cleared: Array = []
	z.cleared.connect(func(n: int) -> void: cleared.append(n))
	# Onda de 1,5 tiles a cada lado de los pies de Isak (no alcanza a todos por si sola).
	var rect := Rect2(_isak.global_position.x - 96.0, -64.0, 192.0, 72.0)
	GroundPoundWave.apply_to_enemies(get_tree(), rect, 1.0)
	EventBus.ground_pound_landed.emit(rect, _isak)
	for c: VideoClone in clones:
		assert_true(c.is_popped(), "Todos eliminados a la vez")
	assert_eq(z.get_clone_count(), 0)
	assert_false(z.is_warning(), "Y el aviso en curso se cancela")
	assert_eq(cleared.size(), 1)
	assert_eq(_count_pickups(), 0, "Sin drops")


func test_ground_pound_outside_the_zone_does_nothing() -> void:
	var z: CloneZone = _zone()
	_stand_at(5)
	_step_zone(z, 2.3)
	assert_eq(z.get_clone_count(), 1)
	EventBus.ground_pound_landed.emit(Rect2(30.0 * T, -64.0, 192.0, 72.0), _isak)
	assert_eq(z.get_clone_count(), 1, "La onda lejos de la zona no la limpia")


func test_respawn_removes_the_clones() -> void:
	var z: CloneZone = _zone()
	_stand_at(5)
	_step_zone(z, 5.0)
	assert_gt(z.get_clone_count(), 0)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(z.get_clone_count(), 0, "Al reaparecer no queda ninguno")
	assert_false(z.is_warning())
	assert_almost_eq(z.get_inside_time(), 0.0, EPS)


# --- Clon ---

func _clone(col: int, direction: float = 1.0) -> VideoClone:
	var c := CLONE_SCENE.instantiate() as VideoClone
	c.position = Vector2((col + 0.5) * T, 0.0)
	c.start_direction = direction
	c.free_on_pop = false
	_world.add_child(c)
	c.set_physics_process(false)
	c.target = _isak
	return c


func test_clone_hurts_on_contact() -> void:
	var c: VideoClone = _clone(6, -1.0)
	_stand_at(6)
	var hits: Array = []
	c.hit_player.connect(func(a: float) -> void: hits.append(a))
	c.step(DT)
	assert_eq(hits.size(), 1, "Dana al contacto")
	assert_lt(GameState.sync_rate, GameState.SYNC_RATE_MAX)


func test_clone_pulse_stuns_with_warning_and_laser_kills_in_one_shot() -> void:
	var c: VideoClone = _clone(6)
	c.step(DT)
	assert_true(c.receive_pulse(_fake_pulse(c.get_body_rect().get_center(), 96.0)))
	assert_true(c.is_stunned())
	assert_false(c.is_dangerous(), "Aturdido no dana")
	var x: float = c.global_position.x
	for i: int in roundi((c.stun_s - c.get_anticipation_s() - 0.05) / DT):
		c.step(DT)
	assert_almost_eq(c.global_position.x, x, 0.5, "Quieto")
	assert_false(c.is_anticipating())
	for i: int in 6:
		c.step(DT)
	assert_true(c.is_anticipating(), "Ultimos 9 cuadros: avisa de que vuelve a danar")
	assert_almost_eq(c.get_anticipation_s(), 0.75, EPS)
	var before: int = _count_pickups()
	c.on_laser_hit(1.0, _isak)
	assert_true(c.is_popped(), "Vida 1: un disparo")
	assert_eq(_count_pickups(), before, "Sin drops (§3.4)")


func test_ground_pound_wave_kills_a_clone() -> void:
	var c: VideoClone = _clone(6)
	c.step(DT)
	var rect := Rect2(c.global_position.x - 96.0, -64.0, 192.0, 72.0)
	assert_eq(GroundPoundWave.apply_to_enemies(get_tree(), rect, 1.0), 1)
	assert_true(c.is_popped(), "La onda (1 de dano) lo elimina")


# --- Comentarista ---

## Comentarista en la celda (col, -1) mirando a `facing`; el bocadillo sube por col + facing.
func _commenter(col: int, facing: int = 1) -> Commenter:
	var c := COMMENTER_SCENE.instantiate() as Commenter
	c.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(c)
	c.set_physics_process(false)
	c.facing = facing
	c.target = _isak
	c.reset_patrol()
	return c


func _step_commenter(c: Commenter, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		c.step(DT)
		_sim.step()


func test_commenter_warns_then_spits_a_rising_bubble_every_interval() -> void:
	var c: Commenter = _commenter(4)
	assert_almost_eq(c.get_warn_s(), 0.75, EPS, "Aviso: el bocadillo se infla 9 cuadros a 12 fps")
	assert_almost_eq(c.get_interval_s(), 2.5, EPS)
	assert_true(c.is_warning(), "Empieza avisando")
	_step_commenter(c, 0.7)
	assert_eq(c.get_spit_count(), 0, "Durante el aviso no sale nada")
	_step_commenter(c, 0.1)
	assert_eq(c.get_spit_count(), 1, "Tras el aviso, el bocadillo")
	var shot: NotificationShot = c.get_shots()[0]
	assert_almost_eq(shot.global_position.x, 5.5 * T, EPS, "Por la columna de delante")
	var y0: float = shot.global_position.y
	_step_commenter(c, 0.25)
	assert_lt(shot.global_position.y, y0 - 60.0, "Sube en vertical (320 px/s)")
	assert_almost_eq(shot.global_position.x, 5.5 * T, EPS)
	_step_commenter(c, 2.25)
	assert_eq(c.get_spit_count(), 2, "Otro cada 2,5 s")


func test_commenter_bubble_hurts_isak_above() -> void:
	var c: Commenter = _commenter(4)
	_stand_at(5)
	_isak.global_position.y = -3.0 * T
	var hits: Array = []
	c.hit_player.connect(func(a: float) -> void: hits.append(a))
	for i: int in roundi(1.6 / DT):
		c.step(DT)
	assert_gt(hits.size(), 0, "El bocadillo que sube le da")


func test_commenter_offset_delays_the_first_warning() -> void:
	var c: Commenter = _commenter(4)
	c.offset_s = 1.0
	assert_false(c.is_warning(), "Con offset_s espera antes del primer aviso")
	_step_commenter(c, 1.05)
	assert_true(c.is_warning())


func test_pulse_silences_the_commenter_and_cancels_the_warning() -> void:
	var c: Commenter = _commenter(4)
	_step_commenter(c, 0.4)
	assert_true(c.receive_pulse(_fake_pulse(c.get_body_rect().get_center(), 96.0)))
	assert_true(c.is_stunned())
	_step_commenter(c, 2.9)
	assert_eq(c.get_spit_count(), 0, "Aturdido no escupe")
	_step_commenter(c, 0.2)
	assert_true(c.is_warning(), "Al despertar vuelve a avisar antes de escupir")
	assert_eq(c.get_spit_count(), 0)


func test_commenter_laser_bounces_awake_and_defeats_it_stunned() -> void:
	var c: Commenter = _commenter(4)
	assert_eq(LaserProjectile.find_laser_target(c.get_node(^"Body")), c, "El laser lo encuentra por su cuerpo")
	var deflects: Array = []
	c.deflected.connect(func() -> void: deflects.append(1))
	c.on_laser_hit(1.0, _isak)
	assert_eq(deflects.size(), 1, "Despierto: chispa gris")
	assert_almost_eq(c.get_health(), 2.0, EPS)
	c.stun()
	var before: int = _count_pickups()
	c.on_laser_hit(1.0, _isak)
	c.on_laser_hit(1.0, _isak)
	assert_true(c.is_defeated(), "Vida 2: dos disparos aturdido")
	assert_eq(_count_pickups(), before + 1, "Suelta su recarga")
	c.reset_patrol()
	assert_true(c.is_defeated(), "Derrotado no vuelve al reaparecer")
	_step_commenter(c, 3.0)
	assert_eq(c.get_spit_count(), 0)


func test_terrain_stops_the_bubble() -> void:
	var c: Commenter = _commenter(4)
	var ceiling := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(T * 3.0, T)
	shape.shape = rect
	ceiling.add_child(shape)
	ceiling.position = Vector2(5.5 * T, -3.5 * T)
	_world.add_child(ceiling)
	await wait_physics_frames(2)
	for i: int in roundi(2.0 / DT):
		c.step(DT)
	assert_eq(c.get_spit_count(), 1)
	assert_eq(c.get_shots().size(), 0, "El techo apaga el bocadillo")


func test_commenter_reset_clears_bubbles_and_restarts() -> void:
	var c: Commenter = _commenter(4)
	_step_commenter(c, 1.0)
	assert_eq(c.get_shots().size(), 1)
	c.reset_patrol()
	assert_eq(c.get_shots().size(), 0, "Sin bocadillos")
	assert_eq(c.get_spit_count(), 0)
	assert_true(c.is_warning(), "Reloj a cero")


# --- Muro «Cargando mas…» ---

## Muro en la columna `col`, filas -3..-1 (sobre el suelo).
func _wall(col: int) -> LoadingWall:
	var w := WALL_SCENE.instantiate() as LoadingWall
	w.position = Vector2(col * T, -3.0 * T)
	_world.add_child(w)
	w.set_physics_process(false)
	return w


## Onda de un golpe con los pies de Isak en `feet_x` (radio 1,5 tiles).
func _pound_at(feet_x: float) -> void:
	EventBus.ground_pound_landed.emit(Rect2(feet_x - 96.0, -64.0, 192.0, 72.0), _isak)


func test_wall_blocks_and_bounces_pulse_and_laser() -> void:
	var w: LoadingWall = _wall(8)
	assert_eq(w.get_wall_size(), Vector2(T, 3.0 * T), "1 x 3 tiles")
	assert_eq(w.collision_layer, 1, "Solido (capa world)")
	var deflects: Array = []
	w.deflected.connect(func() -> void: deflects.append(1))
	w.on_laser_hit(1.0, _isak)
	w._on_pulse_fired(_fake_pulse(Vector2(7.5 * T, -0.5 * T), 96.0))
	assert_eq(deflects.size(), 2, "Pulso y laser rebotan (chispa gris)")
	assert_eq(w.get_filled(), 0, "No le hacen nada")
	assert_false(w.is_broken())


func test_wall_breaks_only_with_three_nearby_pounds_for_good() -> void:
	var w: LoadingWall = _wall(8)
	_pound_at(8.0 * T - 1.5 * T - 8.0)
	assert_eq(w.get_filled(), 0, "A mas de 1,5 tiles no llega")
	_pound_at(7.5 * T)
	assert_eq(w.get_filled(), 1, "Un segmento")
	_pound_at(7.5 * T)
	assert_eq(w.get_filled(), 2)
	assert_false(w.is_broken(), "Con dos aun no")
	_pound_at(9.5 * T)
	assert_true(w.is_broken(), "Con tres se rompe (tambien desde el otro lado)")
	assert_eq(w.collision_layer, 0, "Sin colision")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_true(w.is_broken(), "Para siempre")


func test_wall_segments_reset_when_isak_respawns() -> void:
	var w: LoadingWall = _wall(8)
	_pound_at(7.5 * T)
	_pound_at(7.5 * T)
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_eq(w.get_filled(), 0, "Al reaparecer sin romperlo vuelve a cero")


# --- Salas de prueba ---

func test_clones_room_has_its_zone_and_commenter() -> void:
	var level := (load("res://scenes/levels/clones_test.tscn") as PackedScene).instantiate() as GeneratedLevel
	add_child(level)
	await wait_physics_frames(2)
	var z := level.get_node(^"Objects/zona_clones") as CloneZone
	assert_eq(z.zone, [6, 5, 14, 5])
	var c := level.get_node(^"Enemies/comentarista") as Commenter
	assert_eq(c.facing, -1, "params.facing")
	assert_false(z.is_player_inside(), "Isak empieza fuera de la zona")
	level.free()


func test_carga_room_has_its_wall_and_zone() -> void:
	var level := (load("res://scenes/levels/carga_test.tscn") as PackedScene).instantiate() as GeneratedLevel
	add_child(level)
	await wait_physics_frames(2)
	var w := level.get_node(^"Objects/muro_carga") as LoadingWall
	assert_eq(w.pounds_needed, 3)
	assert_eq(w.get_wall_rect(), Rect2(14.0 * T, 7.0 * T, T, 3.0 * T))
	assert_not_null(level.get_node(^"Objects/zona_muro") as CloneZone)
	level.free()
