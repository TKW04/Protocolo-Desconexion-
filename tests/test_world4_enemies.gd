# Enemigos del Mundo 4 «El Chat» (paso 5 de docs/propuesta-mundo-4.md §8, §3.7 y
# patron 20 de §3.8): Troll (con Isak en linea horizontal y a <= 9 tiles escribe
# 0,75 s y lanza un mensaje horizontal a 240 px/s que quita 10; el pulso lo aturde
# 3 s; despierto el laser rebota y aturdido lo derrota con +20; Agitar borra sus
# mensajes y aturde a varios a la vez), Troll disfrazado (burbuja de amigo; el
# Debug lo revela; a 2 tiles se descubre en 9 cuadros; pisado se hunde 1 tile y
# se descubre; Agitar lo descubre y aturde; vuelve al disfraz al reaparecer) y
# Sticker (persigue a 6 tiles, se infla 9 cuadros a 1,5 tiles y explota con -10;
# desde el 2026-10-28 el pulso lo desinfla para siempre con +5 —con pulse_deflates
# false, lo de antes: lo para 3 s—; laser vida 1; explotado vuelve al reaparecer).
# Agitar esta retirado (2026-10-28): las pruebas de receive_shockwave siguen porque
# la logica se conserva (ShockwaveWave.apply_to_enemies), aunque el juego no la use. La sala grupo_test carga. Desde el paso 6, Fantasma (patrulla y
# dana al contacto; a 3 tiles se esfuma en 0,3 s, 1,0 s despues reaparece 2 tiles
# detras de Isak con aviso de 9 cuadros y 0,5 s despues embiste; con el Debug se
# ve el rastro; el pulso al reaparecer lo aturde y aturdido el laser lo derrota)
# y la sala fantasmas_test. Delta fijo; los enemigos con step().
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const TROLL_SCENE: PackedScene = preload("res://scenes/enemies/troll.tscn")
const MIMIC_SCENE: PackedScene = preload("res://scenes/enemies/troll_mimic.tscn")
const STICKER_SCENE: PackedScene = preload("res://scenes/enemies/sticker.tscn")
const GHOST_SCENE: PackedScene = preload("res://scenes/enemies/ghost.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.01
const T: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved_debug: bool
var _saved_energy: float


func before_each() -> void:
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	_saved_energy = GameState.debug_energy
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
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	GameState.debug_energy = _saved_energy
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _stand_at(col: float) -> void:
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


## Avanza los nodos (con step) e Isak `seconds` segundos.
func _run(nodes: Array, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		for n: Node in nodes:
			n.call(&"step", DT)
		_sim.step()


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	var config: DebugModeConfig = DebugModeConfig.shared()
	for i: int in roundi(config.activation_hold_s / DT):
		DebugMode.step(DT, true)
	for i: int in ceili(config.fade_in_s / DT) + 1:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())


# --- Troll ---

## Troll de pie en la celda (col, -1) (pies en y = 0, sobre el suelo).
func _troll(col: float, facing: int = -1) -> Troll:
	var t := TROLL_SCENE.instantiate() as Troll
	t.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(t)
	t.set_physics_process(false)
	t.facing = facing
	t.target = _isak
	t.reset_patrol()
	return t


func test_troll_waits_until_isak_is_in_its_line_and_in_range() -> void:
	var t: Troll = _troll(20)
	_stand_at(10)
	_run([t], 1.5)
	assert_false(t.is_warning(), "A 10 tiles no lo ve (9 de alcance)")
	assert_eq(t.get_shot_count(), 0)
	_stand_at(12)
	_isak.global_position.y = -3.0 * T
	assert_false(t.sees_isak(), "Fuera de su linea horizontal no lo ve")
	_stand_at(12)
	assert_true(t.sees_isak(), "A 8 tiles en su linea, si")


func test_troll_warns_then_throws_a_horizontal_message_every_interval() -> void:
	var t: Troll = _troll(16, 1)
	_stand_at(10)
	_run([t], DT)
	assert_true(t.is_warning(), "Al verlo escribe en seguida")
	assert_eq(t.get_facing(), -1, "Se gira hacia Isak")
	assert_almost_eq(t.get_warn_s(), 0.75, EPS, "«escribiendo…»: 9 cuadros a 12 fps")
	_run([t], 0.65)
	assert_eq(t.get_shot_count(), 0, "Durante el aviso no lanza")
	_run([t], 0.15)
	assert_eq(t.get_shot_count(), 1, "Tras el aviso, el mensaje")
	var shot: TrollMessage = t.get_shots()[0]
	assert_eq(shot.text, "ok.", "Primer mensaje de la lista")
	assert_almost_eq(shot.speed_px_s, 240.0, EPS)
	var x0: float = shot.global_position.x
	var y0: float = shot.global_position.y
	t.step(0.25)
	assert_almost_eq(shot.global_position.x, x0 - 60.0, 0.5, "Horizontal hacia Isak a 240 px/s")
	assert_almost_eq(shot.global_position.y, y0, EPS)
	_isak.global_position.x = -3000.0
	_run([t], 2.5)
	assert_eq(t.get_shot_count(), 1, "Sin verlo no vuelve a escribir")
	_stand_at(10)
	_run([t], 0.8)
	assert_eq(t.get_shot_count(), 2, "Otro al volver a verlo")
	assert_eq(t.get_shots()[-1].text, "¿y?")


func test_troll_message_hurts_ten_and_the_dash_goes_through() -> void:
	var t: Troll = _troll(14)
	_stand_at(10)
	var hits: Array = []
	t.hit_player.connect(func(a: float) -> void: hits.append(a))
	var sync0: float = GameState.sync_rate
	for i: int in roundi(2.0 / DT):
		t.step(DT)
	assert_eq(hits.size(), 1, "El mensaje le da")
	assert_almost_eq(GameState.sync_rate, sync0 - 10.0, EPS, "-10 de Sync")


func test_pulse_stuns_the_troll_three_seconds_and_cancels_the_warning() -> void:
	var t: Troll = _troll(14)
	_stand_at(10)
	_run([t], 0.4)
	assert_true(t.is_warning())
	assert_true(t.receive_pulse(_fake_pulse(t.get_body_rect().get_center(), 96.0)))
	assert_true(t.is_stunned())
	assert_almost_eq(t.get_stun_left(), 3.0, EPS)
	_run([t], 2.9)
	assert_eq(t.get_shot_count(), 0, "Aturdido no lanza")
	_run([t], 0.2)
	assert_true(t.is_warning(), "Al despertar vuelve a avisar antes de lanzar")
	assert_eq(t.get_shot_count(), 0)


func test_troll_laser_bounces_awake_and_defeats_it_stunned() -> void:
	var t: Troll = _troll(14)
	assert_eq(LaserProjectile.find_laser_target(t.get_node(^"Body")), t, "El laser lo encuentra por su cuerpo")
	var deflects: Array = []
	t.deflected.connect(func() -> void: deflects.append(1))
	t.on_laser_hit(1.0, _isak)
	assert_eq(deflects.size(), 1, "Despierto: chispa gris")
	assert_almost_eq(t.get_health(), 2.0, EPS)
	t.stun()
	var before: int = _count_pickups()
	t.on_laser_hit(1.0, _isak)
	t.on_laser_hit(1.0, _isak)
	assert_true(t.is_defeated(), "Vida 2: dos disparos aturdido")
	assert_eq(_count_pickups(), before + 1, "Suelta su recarga (+20)")
	t.reset_patrol()
	assert_true(t.is_defeated(), "Derrotado no vuelve al reaparecer")


## Arte final con AutoSprite (paso 24, etapa 3b; tools/import_troll.py): idle en
## reposo, typing por el progreso del aviso, shot al lanzar, stunned aturdido e
## idle apagado derrotado. La caja (body_size) no cambia: el dibujo sobresale.
func test_troll_art_follows_its_state() -> void:
	assert_true(Troll.has_art(), "Cuadros de tools/import_troll.py")
	var t: Troll = _troll(14)
	assert_eq(t.get_body_rect().size, Vector2(40.0, 56.0), "La caja no cambia")
	assert_eq(t.get_visual_rect().size.y, 76.0, "El dibujo mide 76 px")
	_isak.global_position.x = -3000.0
	_run([t], 0.5)
	assert_eq(String(t.get_art_frame()[0]), "idle", "En reposo")
	_stand_at(10)
	_run([t], DT)
	assert_eq(t.get_art_frame(), ["typing", 0], "Empieza el aviso")
	_run([t], 0.7)
	assert_eq(t.get_art_frame(), ["typing", 8], "Al final del aviso")
	_run([t], 0.1)
	assert_eq(t.get_shot_count(), 1)
	assert_eq(String(t.get_art_frame()[0]), "shot", "Lanza")
	_run([t], t.get_shot_anim_s())
	assert_eq(String(t.get_art_frame()[0]), "idle", "Tras lanzar vuelve al reposo")
	t.stun()
	assert_eq(String(t.get_art_frame()[0]), "stunned", "Aturdido")
	assert_not_null(t.get_art_texture())
	t.take_damage(5.0)
	assert_eq(t.get_art_frame(), ["idle", 0], "Derrotado: el reposo apagado")


func test_shockwave_stuns_a_group_of_trolls_and_erases_their_messages() -> void:
	var a: Troll = _troll(12, 1)
	var b: Troll = _troll(16, -1)
	var c: Troll = _troll(14)
	c.position.y = -2.0 * T
	_stand_at(14)
	_run([a, b, c], 0.8)
	assert_eq(a.get_shots().size() + b.get_shots().size(), 2, "Los de su linea lanzan")
	assert_false(c.sees_isak(), "El de la repisa no lo ve")
	var center: Vector2 = _isak.global_position + Vector2(0.0, -48.0)
	var erased: Array = []
	a.messages_erased.connect(func(n: int) -> void: erased.append(n))
	var hits: int = ShockwaveWave.apply_to_enemies(get_tree(), center, 160.0, 3.0)
	assert_eq(hits, 3, "Agitar alcanza a los tres")
	for t: Troll in [a, b, c]:
		assert_true(t.is_stunned(), "Aturdido %s" % t.name)
		assert_almost_eq(t.get_stun_left(), 3.0, EPS, "3 s")
	assert_eq(a.get_shots().size() + b.get_shots().size(), 0, "Mensajes borrados")
	assert_eq(erased, [1])


func test_troll_reset_clears_messages_and_faces_its_start() -> void:
	var t: Troll = _troll(14, 1)
	_stand_at(10)
	_run([t], 1.0)
	assert_eq(t.get_shots().size(), 1)
	assert_eq(t.get_facing(), -1)
	t.reset_patrol()
	assert_eq(t.get_shots().size(), 0, "Sin mensajes")
	assert_eq(t.get_shot_count(), 0)
	assert_eq(t.get_facing(), 1, "Vuelve a mirar a su lado inicial")


func test_troll_message_is_drawn_above_the_dark_veil() -> void:
	var t: Troll = _troll(14)
	_stand_at(10)
	_run([t], 0.8)
	var shot: TrollMessage = t.get_shots()[0]
	assert_false(shot.z_as_relative)
	assert_gt(shot.z_index, DarkZone.veil_z(), "Lo que dana se ve siempre")


# --- Troll disfrazado ---

## Disfrazado en la celda (col, -1); la burbuja queda arriba de esa celda.
func _mimic(col: float) -> TrollMimic:
	var m := MIMIC_SCENE.instantiate() as TrollMimic
	m.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(m)
	m.set_physics_process(false)
	m.target = _isak
	m.reset_patrol()
	return m


func test_mimic_looks_like_a_friend_bubble_and_ignores_pulse_and_laser() -> void:
	var m: TrollMimic = _mimic(14)
	assert_true(m.is_disguised())
	var bubble: ChatBubble = m.get_disguise()
	assert_eq(bubble.text, "¿vienes?")
	assert_eq(bubble.get_friend_initial(), "L", "Avatar de Lia")
	assert_true(bubble.is_solid(), "Es una plataforma de una via")
	assert_false(m.receive_pulse(_fake_pulse(m.get_body_rect().get_center(), 96.0)), "El pulso no le hace nada")
	m.on_laser_hit(1.0, _isak)
	assert_almost_eq(m.get_health(), 2.0, EPS, "Ni el laser")
	_stand_at(10)
	_run([m], 2.0)
	assert_eq(m.get_shot_count(), 0, "Disfrazado no lanza")


func test_debug_reveals_the_mimic() -> void:
	var m: TrollMimic = _mimic(14)
	assert_false(m.is_revealed_by_debug())
	_activate_debug()
	assert_true(m.is_revealed_by_debug(), "Con el Debug: avatar anonimo y costuras rojas")


func test_mimic_unmasks_at_two_tiles_in_nine_frames_and_then_throws() -> void:
	var m: TrollMimic = _mimic(14)
	_stand_at(11)
	_run([m], 0.2)
	assert_eq(m.get_mask_state(), TrollMimic.MASK_HIDDEN, "A 2,5 tiles sigue disfrazado")
	_stand_at(12)
	_run([m], DT)
	assert_eq(m.get_mask_state(), TrollMimic.MASK_UNMASKING, "A 2 tiles empieza a descubrirse")
	assert_almost_eq(m.get_unmask_s(), 0.75, EPS)
	_run([m], 0.7)
	assert_true(m.is_disguised())
	_run([m], 0.1)
	assert_false(m.is_disguised(), "Descubierto es un Troll")
	assert_false(m.get_disguise().is_solid(), "La burbuja desaparece")
	_run([m], 0.85)
	assert_eq(m.get_shot_count(), 1, "Y lanza como un Troll")


func test_stepping_on_the_mimic_sinks_it_one_tile_and_unmasks_it() -> void:
	var m: TrollMimic = _mimic(14)
	m.unmask_tiles = 0.0
	var bubble: ChatBubble = m.get_disguise()
	var top0: float = bubble.get_card_rect().position.y
	_isak.global_position = Vector2(bubble.get_card_rect().get_center().x, top0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()
	_run([m], DT)
	assert_eq(m.get_mask_state(), TrollMimic.MASK_SINKING, "Pisada: se hunde")
	_run([m], 0.35)
	assert_almost_eq(bubble.get_card_rect().position.y, top0 + T, 0.5, "1 tile")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, EPS, "Sin dano")
	assert_eq(m.get_mask_state(), TrollMimic.MASK_UNMASKING)
	_run([m], 0.8)
	assert_false(m.is_disguised())


func test_shockwave_unmasks_and_stuns_the_mimic_and_reset_restores_it() -> void:
	var m: TrollMimic = _mimic(14)
	assert_true(ShockwaveWave.apply_to_enemies(get_tree(), m.get_body_rect().get_center(), 160.0, 3.0) >= 1)
	assert_false(m.is_disguised(), "Agitar lo descubre al instante")
	assert_true(m.is_stunned(), "Y lo aturde")
	m.reset_patrol()
	assert_true(m.is_disguised(), "Al reaparecer vuelve al disfraz")
	assert_true(m.get_disguise().is_solid())
	assert_false(m.is_stunned())


# --- Sticker ---

func _sticker(col: float) -> Sticker:
	var s := STICKER_SCENE.instantiate() as Sticker
	s.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(s)
	s.set_physics_process(false)
	s.target = _isak
	return s


func test_sticker_sleeps_far_and_chases_within_six_tiles() -> void:
	var s: Sticker = _sticker(20)
	await wait_physics_frames(2)
	_stand_at(12)
	_run([s], 0.5)
	assert_eq(s.get_state(), Sticker.STATE_SLEEP, "A 8 tiles duerme")
	_stand_at(15)
	var x0: float = s.global_position.x
	_run([s], 0.5)
	assert_eq(s.get_state(), Sticker.STATE_CHASE)
	assert_almost_eq(s.global_position.x, x0 - 60.0, 4.0, "Hacia Isak a 120 px/s")


func test_sticker_inflates_nine_frames_and_explodes_for_ten() -> void:
	var s: Sticker = _sticker(14)
	await wait_physics_frames(2)
	_stand_at(13)
	_run([s], DT)
	assert_true(s.is_inflating(), "A <= 1,5 tiles se infla")
	assert_almost_eq(s.get_warn_s(), 0.75, EPS)
	var booms: Array = []
	s.exploded.connect(func(hit: bool) -> void: booms.append(hit))
	_run([s], 0.7)
	assert_eq(booms.size(), 0, "Durante el aviso no explota")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, EPS, "El cuerpo no dana")
	_run([s], 0.1)
	assert_eq(booms, [true], "Explota y le da")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, EPS, "-10")
	assert_true(s.is_exploded(), "Confeti sin dano")
	s.reset_patrol()
	assert_eq(s.get_state(), Sticker.STATE_SLEEP, "Vuelve al reaparecer")


func test_pulse_deflates_the_sticker_for_good_with_five_energy() -> void:
	var s: Sticker = _sticker(14)
	await wait_physics_frames(2)
	assert_true(s.pulse_deflates, "Datos: el pulso lo desinfla (sustituye a Agitar)")
	_stand_at(13)
	_run([s], 0.3)
	assert_true(s.is_inflating())
	var before: int = _count_pickups()
	watch_signals(s)
	assert_true(s.receive_pulse(_fake_pulse(s.get_body_rect().get_center(), 96.0)))
	assert_true(s.is_defeated(), "Se desinfla y desaparece")
	assert_signal_emitted(s, "deflated")
	assert_eq(_count_pickups(), before + 1, "+5 de energia")
	_run([s], 1.0)
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, EPS, "Ya no explota")
	s.reset_patrol()
	assert_true(s.is_defeated(), "No vuelve")


func test_pulse_stops_the_sticker_and_it_reinflates_if_still_close() -> void:
	var s: Sticker = _sticker(14)
	await wait_physics_frames(2)
	s.pulse_deflates = false  # lo de antes del 2026-10-28
	_stand_at(13)
	_run([s], 0.3)
	assert_true(s.receive_pulse(_fake_pulse(s.get_body_rect().get_center(), 96.0)))
	assert_true(s.is_stunned(), "El pulso cancela el inflado")
	_run([s], 2.9)
	assert_true(s.is_stunned())
	_run([s], 0.2)
	assert_true(s.is_inflating(), "Al despertar con Isak cerca vuelve a inflarse")


func test_shockwave_deflates_the_sticker_for_five_energy() -> void:
	var s: Sticker = _sticker(14)
	var before: int = _count_pickups()
	assert_eq(ShockwaveWave.apply_to_enemies(get_tree(), s.get_center(), 160.0, 3.0), 1)
	assert_true(s.is_defeated(), "Se desinfla y desaparece")
	assert_eq(_count_pickups(), before + 1, "+5 de energia")
	s.reset_patrol()
	assert_true(s.is_defeated(), "No vuelve")


func test_sticker_dies_to_one_laser_shot() -> void:
	var s: Sticker = _sticker(14)
	assert_eq(LaserProjectile.find_laser_target(s), s)
	s.on_laser_hit(1.0, _isak)
	assert_true(s.is_defeated(), "Vida 1")


func test_grupo_test_room_loads() -> void:
	var scene := load("res://scenes/levels/grupo_test.tscn") as PackedScene
	assert_not_null(scene, "Sala grupo_test generada")
	var level: Node = scene.instantiate()
	var enemies: Node = level.get_node(^"Enemies")
	var trolls: int = 0
	var mimics: int = 0
	var stickers: int = 0
	for e: Node in enemies.get_children():
		if e.scene_file_path.ends_with("troll_mimic.tscn"):
			mimics += 1
		elif e.scene_file_path.ends_with("troll.tscn"):
			trolls += 1
		elif e.scene_file_path.ends_with("sticker.tscn"):
			stickers += 1
	assert_eq([trolls, mimics, stickers], [3, 1, 2], "Tres Trolls, un disfrazado y dos Stickers")
	level.free()


# --- Fantasma ---

func _ghost(col: float) -> Ghost:
	var g := GHOST_SCENE.instantiate() as Ghost
	g.position = Vector2((col + 0.5) * T, 0.0)
	_world.add_child(g)
	g.set_physics_process(false)
	g.target = _isak
	return g


## Lleva al Fantasma de la patrulla hasta el aviso de reaparicion (Isak quieto).
func _until(g: Ghost, state: StringName, max_s: float = 4.0) -> float:
	var t: float = 0.0
	while g.get_state() != state and t < max_s:
		g.step(DT)
		t += DT
	return t


func test_ghost_patrols_and_hurts_on_contact() -> void:
	var g: Ghost = _ghost(20)
	g.detect_tiles = 0.0
	var x0: float = g.global_position.x
	_run([g], 1.0)
	assert_almost_eq(absf(g.global_position.x - x0), 60.0, 1.0, "Patrulla a 60 px/s")
	_isak.global_position = g.global_position
	_isak.velocity = Vector2.ZERO
	_sim.settle()
	var hits: Array = []
	g.hit_player.connect(func(a: float) -> void: hits.append(a))
	g.step(DT)
	assert_eq(hits, [10.0], "Contacto: -10")


func test_ghost_vanishes_and_reappears_two_tiles_behind_after_one_second() -> void:
	var g: Ghost = _ghost(16)
	g.speed_px_s = 0.0
	_stand_at(14)
	_isak.facing = 1.0
	g.step(DT)
	assert_eq(g.get_state(), Ghost.STATE_VANISH, "A <= 3 tiles se esfuma")
	assert_false(g.is_visible_ghost() and g.get_alpha() >= 0.6)
	var t_vanish: float = _until(g, Ghost.STATE_HIDDEN)
	assert_almost_eq(t_vanish, 0.3, 0.03, "0,3 s esfumandose")
	assert_false(g.is_visible_ghost(), "Oculto")
	assert_false(g.receive_pulse(_fake_pulse(g.get_body_rect().get_center(), 300.0)), "Oculto, el pulso no lo toca")
	var appeared: Array = []
	g.appearing.connect(func(at: Vector2) -> void: appeared.append(at))
	var t_hidden: float = _until(g, Ghost.STATE_WARN)
	assert_almost_eq(t_hidden, 1.0, 0.03, "1,0 s despues reaparece")
	assert_eq(appeared.size(), 1, "Aviso posicional")
	assert_almost_eq(g.global_position.x, _isak.global_position.x - 2.0 * T, 0.5, "2 tiles detras (mira a la derecha)")
	assert_almost_eq(g.global_position.y, _isak.global_position.y, 0.5, "A la altura de sus pies")
	assert_almost_eq(g.get_warn_s(), 0.75, EPS, "Aviso de 9 cuadros a 12 fps")


func test_ghost_charges_half_a_second_after_its_warning() -> void:
	var g: Ghost = _ghost(16)
	g.speed_px_s = 0.0
	_stand_at(14)
	_isak.facing = -1.0
	_until(g, Ghost.STATE_WARN)
	assert_almost_eq(g.global_position.x, _isak.global_position.x + 2.0 * T, 0.5, "Detras: mira a la izquierda")
	var t_warn: float = _until(g, Ghost.STATE_READY)
	assert_almost_eq(t_warn, 0.75, 0.03)
	var hits: Array = []
	g.hit_player.connect(func(a: float) -> void: hits.append(a))
	var t_ready: float = _until(g, Ghost.STATE_CHARGE)
	assert_almost_eq(t_ready, 0.5, 0.03, "0,5 s despues embiste")
	assert_eq(hits.size(), 0, "Hasta embestir no dana")
	for i: int in roundi(0.6 / DT):
		g.step(DT)
	assert_eq(hits, [10.0], "La embestida le da")


func test_debug_shows_the_trail_to_the_reappearance_point() -> void:
	var g: Ghost = _ghost(16)
	g.speed_px_s = 0.0
	_stand_at(14)
	_isak.facing = 1.0
	_until(g, Ghost.STATE_HIDDEN)
	g.step(DT)
	assert_false(g.is_trail_visible(), "Sin el Debug no hay rastro")
	_activate_debug()
	assert_true(g.is_trail_visible(), "Con el Debug, el rastro")
	assert_almost_eq(g.get_vanish_point().x, (16.5) * T, 0.5, "Desde donde se esfumo")
	assert_almost_eq(g.get_appear_point().x, _isak.global_position.x - 2.0 * T, 0.5, "Hasta donde va a reaparecer")
	_isak.facing = -1.0
	g.step(DT)
	assert_almost_eq(g.get_appear_point().x, _isak.global_position.x + 2.0 * T, 0.5, "Sigue a donde mira Isak")


func test_pulse_on_reappearing_stuns_and_the_laser_defeats_it() -> void:
	var g: Ghost = _ghost(16)
	g.speed_px_s = 0.0
	_stand_at(14)
	_until(g, Ghost.STATE_READY)
	var deflects: Array = []
	g.deflected.connect(func() -> void: deflects.append(1))
	g.on_laser_hit(1.0, _isak)
	assert_eq(deflects.size(), 1, "Despierto: chispa gris")
	assert_true(g.receive_pulse(_fake_pulse(g.get_body_rect().get_center(), 96.0)))
	assert_true(g.is_stunned())
	assert_almost_eq(g.get_stun_left(), 3.0, EPS)
	var before: int = _count_pickups()
	g.on_laser_hit(1.0, _isak)
	g.on_laser_hit(1.0, _isak)
	assert_true(g.is_defeated(), "Vida 2")
	assert_eq(_count_pickups(), before + 1)
	g.reset_patrol()
	assert_true(g.is_defeated(), "No vuelve")


func test_ghost_appears_ahead_when_behind_is_terrain() -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(T, 3.0 * T)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(12.5 * T, -1.5 * T)
	_world.add_child(wall)
	await wait_physics_frames(2)
	var g: Ghost = _ghost(16)
	_stand_at(14)
	_isak.facing = 1.0
	assert_almost_eq(g.compute_appear_point().x, _isak.global_position.x + 2.0 * T, 0.5, "Detras hay pared: delante")


func test_ghost_reset_returns_it_to_its_spot() -> void:
	var g: Ghost = _ghost(16)
	_stand_at(14)
	_until(g, Ghost.STATE_WARN)
	g.reset_patrol()
	assert_eq(g.get_state(), Ghost.STATE_PATROL)
	assert_almost_eq(g.global_position.x, 16.5 * T, 0.5)


func test_fantasmas_test_room_loads() -> void:
	var scene := load("res://scenes/levels/fantasmas_test.tscn") as PackedScene
	assert_not_null(scene, "Sala fantasmas_test generada")
	var level: Node = scene.instantiate()
	var ghosts: int = 0
	for e: Node in level.get_node(^"Enemies").get_children():
		if e.scene_file_path.ends_with("ghost.tscn"):
			ghosts += 1
	assert_eq(ghosts, 2)
	level.free()
