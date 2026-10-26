# Enemigos del Mundo 3 «La Vitrina» (paso 5 de docs/propuesta-mundo-3.md §8,
# §3.6 y decision 6 de §9): Influencer bot (ve a Isak en linea horizontal a <= 8
# tiles sin terreno entre medias, carga el flash 0,75 s con aviso, ceguera sin
# dano al 70 % / 40 % con «Reducir efectos», el terreno tapa, el pulso lo aturde
# y cancela la carga, aturdido el laser lo derrota con +20 de energia y 2
# corazones) y Ladron de likes (patrulla, aviso de 9 cuadros, persigue a 140
# px/s, roba hasta 5 likes sin quitar Sync, huye 2 s, el pulso le hace soltar lo
# robado como corazones recuperables, sin likes «busca», laser aturdido) y la
# sala vitrina_test.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const INFLUENCER_SCENE: PackedScene = preload("res://scenes/enemies/influencer_bot.tscn")
const THIEF_SCENE: PackedScene = preload("res://scenes/enemies/like_thief.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const T: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_reduced: bool


func before_each() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.reset_likes()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_saved_reduced = GameSettings.is_low_sync_reduced()
	GameSettings.set_low_sync_reduced(false)
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = Vector2(-3000.0, 0.0)
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	GameSettings.set_low_sync_reduced(_saved_reduced)
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.reset_likes()


func _stand_at(col: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()


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


## Columna de terreno (capa world) de 1 tile de ancho y `rows` de alto sobre el suelo.
func _column(col: int, rows: int = 3) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(T, T * rows)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2((col + 0.5) * T, -T * rows * 0.5)
	_world.add_child(body)
	return body


func _count(kind: Variant) -> int:
	var n: int = 0
	for child: Node in _world.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion():
			n += 1
	return n


func _dropped_hearts() -> Array[HeartPickup]:
	var out: Array[HeartPickup] = []
	for child: Node in _world.get_children():
		if child is HeartPickup and (child as HeartPickup).is_dropped() and not child.is_queued_for_deletion():
			out.append(child as HeartPickup)
	return out


# --- Influencer bot ---

func _influencer(col: int) -> InfluencerBot:
	var b := INFLUENCER_SCENE.instantiate() as InfluencerBot
	b.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(b)
	b.set_physics_process(false)
	b.target = _isak
	b.reset_patrol()
	return b


func _step_bot(b: InfluencerBot, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		b.step(DT)
		var veil: FlashVeil = FlashVeil.find(b)
		if veil != null:
			veil.advance(DT)
		_sim.step()


func _veil_alpha(b: InfluencerBot) -> float:
	var veil: FlashVeil = FlashVeil.find(b)
	return veil.get_alpha() if veil != null else 0.0


func test_influencer_warns_for_0_75_s_then_flashes_without_damage() -> void:
	var b: InfluencerBot = _influencer(4)
	_stand_at(9)
	var sync_before: float = GameState.sync_rate
	assert_almost_eq(b.get_warn_s(), 0.75, EPS, "9 cuadros a 12 fps")
	_step_bot(b, DT)
	assert_true(b.is_charging(), "Ve a Isak a 5 tiles: carga")
	_step_bot(b, 0.7)
	assert_true(b.is_charging(), "Aun avisando")
	assert_eq(b.get_flash_count(), 0)
	assert_almost_eq(_veil_alpha(b), 0.0, EPS, "Sin velo durante el aviso")
	_step_bot(b, 0.07)
	assert_eq(b.get_flash_count(), 1, "Flash al terminar los 0,75 s")
	assert_almost_eq(_veil_alpha(b), 0.7, 0.02, "Velo blanco al 70 %")
	assert_almost_eq(GameState.sync_rate, sync_before, EPS, "El flash no dana")
	assert_eq(b.get_state(), InfluencerBot.STATE_COOLDOWN)
	_step_bot(b, 1.6)
	assert_almost_eq(_veil_alpha(b), 0.0, EPS, "El velo se desvanece en 1,5 s")
	assert_false(b.is_charging(), "Enfriamiento de 3 s")
	_step_bot(b, 1.5)
	assert_true(b.is_charging(), "Pasado el enfriamiento vuelve a cargar")


func test_influencer_sight_is_horizontal_and_limited_to_8_tiles() -> void:
	var b: InfluencerBot = _influencer(4)
	_stand_at(13)
	assert_false(b.can_see_isak(), "A 9 tiles no lo ve")
	_stand_at(12)
	assert_true(b.can_see_isak(), "A 8 tiles si")
	_stand_at(0)
	assert_true(b.can_see_isak(), "facing 0: tambien al otro lado")
	b.facing = 1
	assert_false(b.can_see_isak(), "facing 1: no mira a la izquierda")
	b.facing = 0
	_isak.global_position = Vector2(8.5 * T, -3.0 * T)
	assert_false(b.can_see_isak(), "Fuera de la franja de la lente (mas alto) no lo ve")


func test_terrain_between_blocks_the_sight() -> void:
	var b: InfluencerBot = _influencer(4)
	_stand_at(9)
	var column: StaticBody2D = _column(6)
	await wait_physics_frames(2)
	assert_false(b.can_see_isak(), "La columna tapa")
	_step_bot(b, 1.0)
	assert_false(b.is_charging(), "Tapado no carga")
	column.free()
	await wait_physics_frames(2)
	assert_true(b.can_see_isak())


func test_hiding_during_the_charge_blocks_the_flash() -> void:
	var b: InfluencerBot = _influencer(4)
	_stand_at(9)
	var results: Array = []
	b.flashed.connect(func(blinded: bool) -> void: results.append(blinded))
	_step_bot(b, 0.3)
	assert_true(b.is_charging())
	_column(7)
	await wait_physics_frames(2)
	_step_bot(b, 0.6)
	assert_eq(results, [false], "Dispara, pero la columna tapa el flash")
	assert_almost_eq(_veil_alpha(b), 0.0, EPS, "Sin ceguera")


func test_pulse_stuns_before_the_flash_and_cancels_it() -> void:
	var b: InfluencerBot = _influencer(4)
	_stand_at(9)
	_step_bot(b, 0.4)
	assert_true(b.is_charging())
	assert_true(b.receive_pulse(_fake_pulse(b.get_body_rect().get_center())))
	assert_true(b.is_stunned())
	_step_bot(b, 2.9)
	assert_eq(b.get_flash_count(), 0, "Aturdido no dispara: la carga se cancelo")
	assert_almost_eq(_veil_alpha(b), 0.0, EPS)
	_step_bot(b, 0.2)
	assert_true(b.is_charging(), "Al despertar vuelve a avisar antes de disparar")
	assert_lt(b.get_charge_t(), 0.2, "Carga nueva, desde el principio")


func test_reduced_effects_lowers_the_veil_to_40_percent() -> void:
	GameSettings.set_low_sync_reduced(true)
	var b: InfluencerBot = _influencer(4)
	_stand_at(9)
	_step_bot(b, 0.8)
	assert_eq(b.get_flash_count(), 1)
	assert_almost_eq(_veil_alpha(b), 0.4, 0.02, "«Reducir efectos»: 40 %")


func test_veil_keeps_the_outline_of_what_hurts() -> void:
	var b: InfluencerBot = _influencer(4)
	_stand_at(9)
	var spikes := SpikeHazard.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(T, 16.0)
	shape.shape = rect
	spikes.add_child(shape)
	spikes.position = Vector2(2.5 * T, -8.0)
	_world.add_child(spikes)
	_step_bot(b, 0.8)
	var veil: FlashVeil = FlashVeil.find(b)
	assert_not_null(veil)
	var rects: Array[Rect2] = veil.get_danger_rects()
	assert_eq(rects.size(), 1, "Los pinchos conservan su contorno")
	assert_true(rects[0].has_point(Vector2(2.5 * T, -8.0)))
	assert_eq(veil.z_index, 50, "Con el z de los pop-ups translucidos")


func test_influencer_laser_bounces_awake_and_defeats_it_stunned_with_drops() -> void:
	var b: InfluencerBot = _influencer(4)
	assert_eq(LaserProjectile.find_laser_target(b.get_node(^"Body")), b, "El laser lo encuentra por su cuerpo")
	var deflects: Array = []
	b.deflected.connect(func() -> void: deflects.append(1))
	b.on_laser_hit(1.0, _isak)
	assert_eq(deflects.size(), 1, "Despierto: chispa gris")
	assert_almost_eq(b.get_health(), 2.0, EPS)
	b.stun()
	var pickups: int = _count(RechargePickup)
	b.on_laser_hit(1.0, _isak)
	b.on_laser_hit(1.0, _isak)
	assert_true(b.is_defeated(), "Vida 2: dos disparos aturdido")
	assert_eq(_count(RechargePickup), pickups + 1, "+20 de energia")
	assert_eq(_dropped_hearts().size(), 2, "Y 2 corazones")
	b.reset_patrol()
	assert_true(b.is_defeated(), "Derrotado no vuelve al reaparecer")


func test_influencer_respawn_restores_its_initial_state_and_clears_the_veil() -> void:
	var b: InfluencerBot = _influencer(4)
	_stand_at(9)
	_step_bot(b, 0.8)
	assert_gt(_veil_alpha(b), 0.0)
	EventBus.player_respawned.emit(_isak.global_position, false)
	b.reset_patrol()
	assert_almost_eq(_veil_alpha(b), 0.0, EPS, "Sin velo al reaparecer")
	assert_eq(b.get_state(), InfluencerBot.STATE_IDLE)
	assert_eq(b.get_flash_count(), 0)


# --- Ladron de likes ---

func _thief(col: int, range_px: float = 0.0) -> LikeThief:
	var t := THIEF_SCENE.instantiate() as LikeThief
	t.patrol_range_px = range_px
	t.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(t)
	t.set_physics_process(false)
	t.target = _isak
	return t


func _step_thief(t: LikeThief, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		t.step(DT)
		_sim.step()


func _step_until(t: LikeThief, condition: Callable, max_s: float) -> bool:
	for i: int in roundi(max_s / DT):
		if condition.call():
			return true
		t.step(DT)
		_sim.step()
	return condition.call()


func test_thief_patrols_while_isak_is_far() -> void:
	var t: LikeThief = _thief(4, 256.0)
	GameState.set_likes(8)
	var x0: float = t.global_position.x
	_step_thief(t, 0.5)
	assert_eq(t.get_state(), LikeThief.STATE_PATROL)
	assert_gt(absf(t.global_position.x - x0), 20.0, "Patrulla")


func test_thief_warns_9_frames_then_chases_at_140() -> void:
	var t: LikeThief = _thief(4)
	GameState.set_likes(8)
	_stand_at(7)
	_step_thief(t, DT)
	assert_true(t.is_noticing(), "A 3 tiles se fija en Isak")
	var x0: float = t.global_position.x
	_step_thief(t, 0.7)
	assert_true(t.is_noticing(), "Aviso de 0,75 s (dedos encendidos)")
	assert_almost_eq(t.global_position.x, x0, 1.0, "Quieto durante el aviso")
	_step_thief(t, 0.07)
	assert_true(t.is_chasing())
	var x1: float = t.global_position.x
	_step_thief(t, 0.5)
	assert_almost_eq(t.global_position.x - x1, 70.0, 6.0, "Persigue a 140 px/s")


func test_thief_steals_up_to_5_likes_without_sync_and_flees() -> void:
	var t: LikeThief = _thief(4)
	GameState.set_likes(8)
	_stand_at(7)
	var sync_before: float = GameState.sync_rate
	assert_true(_step_until(t, t.is_fleeing, 4.0), "Al contacto roba y huye")
	assert_eq(GameState.likes, 3, "Hasta 5 likes")
	assert_eq(t.get_carried(), 5, "Lleva la bolsa con 5")
	assert_almost_eq(GameState.sync_rate, sync_before, EPS, "No quita Sync")
	var x0: float = t.global_position.x
	_step_thief(t, 1.0)
	assert_true(t.is_fleeing())
	assert_lt(t.global_position.x, x0 - 100.0, "Huye alejandose de Isak")
	_step_thief(t, 1.05)
	assert_false(t.is_fleeing(), "Huye 2 s")
	assert_eq(t.get_carried(), 5, "Sigue con la bolsa")


func test_thief_steals_only_what_isak_has() -> void:
	var t: LikeThief = _thief(4)
	GameState.set_likes(3)
	_stand_at(7)
	assert_true(_step_until(t, t.is_fleeing, 4.0))
	assert_eq(GameState.likes, 0)
	assert_eq(t.get_carried(), 3)


func test_pulse_stuns_the_thief_and_it_drops_what_it_stole() -> void:
	var t: LikeThief = _thief(4)
	GameState.set_likes(8)
	_stand_at(7)
	assert_true(_step_until(t, t.is_fleeing, 4.0))
	assert_true(t.receive_pulse(_fake_pulse(t.get_body_rect().get_center())))
	assert_true(t.is_stunned())
	assert_eq(t.get_carried(), 0, "Suelta lo robado")
	var hearts: Array[HeartPickup] = _dropped_hearts()
	assert_eq(hearts.size(), 5, "Como 5 corazones de 1 like")
	assert_almost_eq(hearts[0].get_life_left(), 2.0, EPS, "2 s para recogerlos (parpadean)")
	for heart: HeartPickup in hearts:
		heart.advance(0.5)
		assert_true(heart.collect())
	assert_eq(GameState.likes, 8, "Recuperados")
	_step_thief(t, 2.9)
	assert_true(t.is_stunned(), "Aturdido 3 s")
	_step_thief(t, 0.2)
	assert_false(t.is_stunned())


func test_thief_without_likes_only_stops_and_searches() -> void:
	var t: LikeThief = _thief(4)
	GameState.set_likes(0)
	_stand_at(5)
	var x0: float = t.global_position.x
	_step_thief(t, DT)
	assert_true(t.is_searching(), "Sin likes se para y busca («?»)")
	_step_thief(t, 2.0)
	assert_false(t.is_chasing())
	assert_false(t.is_fleeing())
	assert_almost_eq(t.global_position.x, x0, 4.0, "No persigue")
	assert_eq(t.get_carried(), 0)


func test_thief_laser_bounces_awake_and_defeats_it_stunned() -> void:
	var t: LikeThief = _thief(4)
	assert_eq(LaserProjectile.find_laser_target(t), t)
	var deflects: Array = []
	t.deflected.connect(func() -> void: deflects.append(1))
	t.on_laser_hit(1.0, _isak)
	assert_eq(deflects.size(), 1, "Despierto: chispa gris")
	t.stun()
	t.on_laser_hit(1.0, _isak)
	t.on_laser_hit(1.0, _isak)
	assert_true(t.is_defeated(), "Vida 2 aturdido")
	t.reset_patrol()
	assert_true(t.is_defeated(), "No vuelve")


func test_thief_defeated_drops_what_it_carries() -> void:
	var t: LikeThief = _thief(4)
	GameState.set_likes(8)
	_stand_at(7)
	assert_true(_step_until(t, t.is_fleeing, 4.0))
	t.take_damage(1.0)
	t.take_damage(1.0)
	assert_true(t.is_defeated())
	assert_eq(_dropped_hearts().size(), 5, "Suelta lo que lleve")


func test_thief_respawn_returns_it_home_without_the_bag() -> void:
	var t: LikeThief = _thief(4)
	var home: Vector2 = t.global_position
	GameState.set_likes(8)
	_stand_at(7)
	assert_true(_step_until(t, t.is_fleeing, 4.0))
	_step_thief(t, 0.5)
	t.reset_patrol()
	assert_eq(t.get_state(), LikeThief.STATE_PATROL)
	assert_eq(t.get_carried(), 0)
	assert_almost_eq(t.global_position.x, home.x, EPS)


# --- Sala vitrina_test ---

func test_vitrina_room_has_its_enemies_and_objects() -> void:
	var level := (load("res://scenes/levels/vitrina_test.tscn") as PackedScene).instantiate() as GeneratedLevel
	add_child(level)
	await wait_physics_frames(2)
	assert_eq(level.world, 3)
	assert_not_null(level.get_node_or_null(^"Likes"), "Sistema de likes del Mundo 3")
	var bot := level.get_node(^"Enemies/influencer") as InfluencerBot
	assert_not_null(bot)
	var thief := level.get_node(^"Enemies/ladron") as LikeThief
	assert_not_null(thief)
	var platform := level.get_node(^"Objects/likes_10") as LikePlatform
	assert_eq(platform.threshold, 10)
	assert_not_null(level.get_node_or_null(^"Objects/publicacion"))
	assert_lt(thief.global_position.x, platform.global_position.x, "El ladron va antes del umbral 10")
	level.free()
