# Sala de prueba de los enemigos del 1-2 (data/levels/mensajes_test.json, escena
# generada scenes/levels/mensajes_test.tscn; pasos 4 y 5 de docs/propuesta-1-2.md
# §10, 2026-10-16) con el Isak real: la escena trae los dos puntos rojos y los
# dos banners con los params del nivel, la combinacion «aturdir y rematar»
# (pulso al punto rojo que se infla y dos disparos: derrotado y drops), el
# laser no le hace nada despierto, el banner del pasillo golpea a Isak de pie y
# no en el nicho, y todos se reinician al reaparecer (grupo enemy).
# Los enemigos se avanzan a mano junto a Isak (paso a paso).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/mensajes_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _enemies: Array[Node] = []
var _saved_pause: bool


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	_enemies.clear()
	for e: Node in _level.get_node(^"Enemies").get_children():
		e.set_physics_process(false)
		_enemies.append(e)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _enemy(id: String) -> Node:
	return _level.get_node_or_null(NodePath("Enemies/" + id))


func _step(count: int = 1) -> void:
	for i: int in count:
		_sim.step()
		for e: Node in _enemies:
			if is_instance_valid(e):
				e.call(&"step", DT)


func _stand(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()
	await wait_physics_frames(2)


## Dispara el laser. Antes espera un cuadro de fisica: los enemigos se mueven a
## mano (move_and_slide fuera del paso de fisica) y el servidor de fisica recibe
## su posicion al vaciarse las notificaciones de transformacion del cuadro.
func _fire() -> LaserProjectile:
	await wait_physics_frames(1)
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_step()
	_sim.input.laser_pressed = false
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
	_step(ceili(_isak.abilities.laser_cooldown_s / DT) + 2)
	return p


func test_scene_has_the_enemies_with_level_params() -> void:
	assert_eq(_level.level_id, "mensajes_test")
	var b1 := _enemy("badge_1") as NotificationBadge
	var b2 := _enemy("badge_2") as NotificationBadge
	var s1 := _enemy("banner_1") as SpamBanner
	var s2 := _enemy("banner_2") as SpamBanner
	assert_not_null(b1)
	assert_not_null(b2)
	assert_not_null(s1)
	assert_not_null(s2)
	assert_eq(b1.leash_width_px, 1088.0, "params.leash_width_px del nivel")
	assert_eq(b2.leash_width_px, 832.0)
	assert_eq(b1.get_state(), NotificationBadge.STATE_IDLE, "Dormido al empezar")
	assert_eq(s1.direction, 1)
	assert_eq(s1.corridor_tiles, 14)
	assert_eq(s2.direction, -1, "params.direction -1")
	assert_almost_eq(s2.get_cycle_time(), 1.5, 0.001, "params.phase_s desfasa el ciclo")
	for e: Node in _enemies:
		assert_true(e.is_in_group(AlertBubble.GROUP), "%s en el grupo enemy (LevelRunner lo reinicia)" % e.name)
		assert_true(e.has_method(&"reset_patrol"))
		assert_true(e.is_in_group(HelpCatalog.TARGET_GROUP), "%s con ayuda Q" % e.name)
	assert_eq(HelpCatalog.help_id_of(b1), &"notification_badge")
	assert_eq(HelpCatalog.help_id_of(s1), &"spam_banner")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER), "La sala da el laser")


func test_stun_and_finish_combination() -> void:
	var b1 := _enemy("badge_1") as NotificationBadge
	b1.drops = {"debug_energy": 25.0, "sync_rate": 10.0}
	await _stand(5, 10)
	# Despierta y se acerca; al inflarse (aviso) Isak lanza el pulso.
	var woke: bool = false
	for i: int in 600:
		_step()
		if b1.get_state() == NotificationBadge.STATE_ANTICIPATE:
			woke = true
			break
	assert_true(woke, "El punto rojo despierta, persigue y avisa antes de lanzarse")
	_sim.input.pulse_pressed = true
	for i: int in 40:
		_step()
		if b1.is_stunned():
			break
	assert_true(b1.is_stunned(), "El pulso lo aturde durante el aviso")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sin dano")
	var energy0: float = GameState.debug_energy
	assert_eq((await _fire()).get_hit_target(), b1, "Primer disparo")
	assert_eq(b1.get_health(), 1.0, "Aturdido: el laser le hace dano")
	assert_eq((await _fire()).get_hit_target(), b1, "Segundo disparo")
	assert_true(b1.is_defeated(), "Rematado")
	assert_almost_eq(GameState.debug_energy, energy0 - 2.0 * _isak.abilities.laser_energy_cost, 0.001)
	var drops: int = 0
	for child: Node in b1.get_parent().get_children():
		if child is RechargePickup:
			drops += 1
	assert_eq(drops, 2, "Suelta energia y Sync Rate")


func test_awake_red_dot_shrugs_off_the_laser() -> void:
	var b1 := _enemy("badge_1") as NotificationBadge
	await _stand(5, 10)
	for i: int in 600:
		_step()
		if b1.get_state() == NotificationBadge.STATE_ANTICIPATE:
			break
	var p: LaserProjectile = await _fire()
	assert_eq(p.get_hit_target(), b1, "El disparo choca con el")
	assert_eq(b1.get_health(), b1.get_max_health(), "Despierto: el laser no le hace nada")


func test_banner_hits_isak_in_the_corridor_but_not_in_the_niche() -> void:
	var s1 := _enemy("banner_1") as SpamBanner
	var hits: Array = []
	s1.hit_player.connect(func(a: float) -> void: hits.append(a))
	for e: Node in _enemies:
		if e is NotificationBadge:
			e.queue_free()
	await _stand(25, 10)
	for i: int in roundi(3.5 / DT):
		_step()
		_isak.velocity.x = 0.0
	assert_eq(hits, [10.0], "De pie en el pasillo, el barrido lo alcanza")
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	hits.clear()
	var s2 := _enemy("banner_2") as SpamBanner
	s2.hit_player.connect(func(a: float) -> void: hits.append(a))
	await _stand(26, 7)
	for i: int in roundi(6.5 / DT):
		_step()
	assert_eq(hits.size(), 0, "En el nicho de una via no le alcanza ninguno")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)


func test_enemies_reset_when_isak_respawns() -> void:
	var b1 := _enemy("badge_1") as NotificationBadge
	var s1 := _enemy("banner_1") as SpamBanner
	await _stand(5, 10)
	_step(90)
	assert_ne(b1.global_position, b1.get_spawn_position())
	# Lo que hace LevelRunner._respawn con los enemigos del nivel.
	for enemy: Node in get_tree().get_nodes_in_group(AlertBubble.GROUP):
		if _level.is_ancestor_of(enemy) and enemy.has_method(&"reset_patrol"):
			enemy.call(&"reset_patrol")
	assert_eq(b1.global_position, b1.get_spawn_position(), "El punto rojo vuelve a su sitio")
	assert_eq(b1.get_state(), NotificationBadge.STATE_IDLE)
	assert_almost_eq(s1.get_cycle_time(), 0.0, 0.001, "El banner vuelve al inicio de su ciclo")
