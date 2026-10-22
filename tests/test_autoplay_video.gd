# Video en autoplay (Mundo 2; paso 6 de docs/propuesta-mundo-2.md §8, §3.4):
# se activa al entrar entero en la vista; aviso (miniatura) de 0,75 s = 9
# cuadros a 12 fps sin dano; ola (banner en modo disparo), rayo (onda de campana
# en la columna de Isak) y cuenta (abanico de 3 proyectiles); el dash los
# atraviesa; el pulso lo pausa (cancela el ataque, congela el clip y al
# despertar vuelve a avisar); el laser despierto rebota y aturdido lo rompe
# (vida 2, +25 de energia, no vuelve); el golpe al suelo lo aturde; los clips se
# repiten mientras esta a la vista; reaparecer lo devuelve al inicio.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const VIDEO_SCENE: PackedScene = preload("res://scenes/enemies/autoplay_video.tscn")
const DT: float = 1.0 / 60.0
const EPS: float = 0.001
const T: float = 64.0
## Columna de la celda E de los videos de las pruebas (en el suelo, fila -1).
const COL: int = 10

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _saved: Dictionary = {}
var _in_view := Rect2(Vector2(-2000.0, -2000.0), Vector2(6000.0, 4000.0))
var _out_of_view := Rect2(Vector2(-2000.0, -2000.0), Vector2(100.0, 100.0))


func before_each() -> void:
	_saved = {
		"dash": GameState.is_ability_unlocked(GameState.ABILITY_DASH),
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
	_isak.global_position = Vector2(-3000.0, 0.0)
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, _saved.dash)
	GameState.debug_energy = _saved.energy
	GameState.sync_rate = GameState.SYNC_RATE_MAX


## Video con la celda E en (COL, -1) (tarjeta en las columnas COL y COL + 1,
## filas -2 y -1, sobre el suelo de y = 0).
func _video(clip: String, facing: int = -1, in_view: bool = true) -> AutoplayVideo:
	var v := VIDEO_SCENE.instantiate() as AutoplayVideo
	v.position = Vector2((COL + 0.5) * T, 0.0)
	_world.add_child(v)
	v.set_physics_process(false)
	v.clip = clip
	v.facing = facing
	v.ray_tiles = 2
	v.target = _isak
	v.view_rect_override = _in_view if in_view else _out_of_view
	v.reset_patrol()
	return v


func _stand_at(col: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()


## Avanza hasta que `cond` se cumpla (como mucho 10 s); falla si no llega.
func _step_until(v: AutoplayVideo, cond: Callable, what: String) -> void:
	for i: int in 600:
		if cond.call():
			return
		_step(v)
	fail_test("No llega: %s" % what)


func _step(v: AutoplayVideo, count: int = 1) -> void:
	for i: int in count:
		v.step(DT)
		_sim.step()


func _hits(v: AutoplayVideo) -> Array:
	var hits: Array = []
	v.hit_player.connect(func(a: float) -> void: hits.append(a))
	return hits


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


# --- Activacion por camara ---

func test_activates_only_when_the_whole_card_is_in_view() -> void:
	var v: AutoplayVideo = _video("wave", -1, false)
	_stand_at(2)
	_step(v, 30)
	assert_eq(v.get_state(), AutoplayVideo.STATE_IDLE, "Fuera de la vista: quieto")
	# Media tarjeta a la vista: tampoco.
	var card: Rect2 = v.get_card_rect()
	v.view_rect_override = Rect2(Vector2(card.position.x + T, -2000.0), Vector2(4000.0, 4000.0))
	_step(v, 30)
	assert_eq(v.get_state(), AutoplayVideo.STATE_IDLE, "Entera o nada")
	v.view_rect_override = _in_view
	_step(v)
	assert_eq(v.get_state(), AutoplayVideo.STATE_WARN, "Entera a la vista: empieza el clip con su miniatura")
	assert_eq(v.get_clip_count(), 1)


func test_start_delay_offsets_the_first_clip() -> void:
	var v: AutoplayVideo = _video("ray", -1, false)
	v.start_delay_s = 1.0
	v.reset_patrol()
	_stand_at(2)
	v.view_rect_override = _in_view
	_step(v, roundi(0.9 / DT))
	assert_eq(v.get_state(), AutoplayVideo.STATE_IDLE, "Aun esperando su desfase")
	_step(v, roundi(0.2 / DT))
	assert_eq(v.get_state(), AutoplayVideo.STATE_WARN)


# --- Aviso ---

func test_warning_is_nine_frames_at_twelve_fps_and_harmless() -> void:
	assert_eq(int(roundi(_video("wave").get_warn_s() * 12.0)), 9, "9 cuadros a 12 fps")
	for clip: String in ["wave", "ray", "count"]:
		var v: AutoplayVideo = _video(clip)
		assert_almost_eq(v.get_warn_s(), 0.75, EPS, "%s: aviso de 0,75 s" % clip)
		_stand_at(COL - 2)
		GameState.sync_rate = GameState.SYNC_RATE_MAX
		var hits: Array = _hits(v)
		var warn_steps: int = 0
		_step(v)
		while v.is_warning() and warn_steps < 600:
			assert_false(v.is_dangerous(), "%s: el aviso no dana" % clip)
			assert_eq(hits.size(), 0, "%s: nada antes del ataque" % clip)
			_step(v)
			warn_steps += 1
		assert_almost_eq(float(warn_steps + 1) * DT, 0.75, DT * 1.5, "%s: el aviso dura 0,75 s" % clip)
		assert_eq(v.get_state(), AutoplayVideo.STATE_ATTACK, "%s: despues, el ataque" % clip)
		v.queue_free()
		await wait_physics_frames(1)


# --- Ataques ---

func test_wave_sweeps_the_floor_row_and_hurts() -> void:
	var v: AutoplayVideo = _video("wave", -1)
	var hits: Array = _hits(v)
	_stand_at(COL - 4)
	_step(v)
	var banner: SpamBanner = v.get_banner()
	assert_true(banner.is_busy(), "La ola reutiliza el banner en modo disparo")
	assert_eq(banner.direction, -1, "Hacia facing")
	assert_almost_eq(banner.get_corridor_rect().size.x, 10.0 * T, EPS, "wave_tiles celdas")
	_step(v, roundi(2.0 / DT))
	assert_eq(hits.size(), 1, "La ola le da (una vez: invulnerabilidad)")
	assert_lt(GameState.sync_rate, GameState.SYNC_RATE_MAX)


func test_ray_falls_in_isak_column() -> void:
	var v: AutoplayVideo = _video("ray", -1)
	var hits: Array = _hits(v)
	_stand_at(COL - 3)
	_step(v)
	var bell: AlarmBell = v.get_bell()
	assert_true(bell.is_busy(), "El rayo reutiliza la onda de la campana en modo disparo")
	assert_true(bell.get_wave_rect().has_point(Vector2((COL - 3 + 0.5) * T, -10.0)), "En la columna de Isak")
	assert_almost_eq(bell.get_wave_rect().size.x, bell.damage_width_px, EPS, "Columna de 1 tile")
	_step(v, roundi(1.3 / DT))
	assert_eq(hits.size(), 1, "Quedarse en la columna duele")


func test_changing_column_dodges_the_ray() -> void:
	var v: AutoplayVideo = _video("ray", -1)
	var hits: Array = _hits(v)
	_stand_at(COL - 3)
	_step(v)
	_stand_at(COL - 6)
	_step(v, roundi(1.3 / DT))
	assert_eq(hits.size(), 0, "Cambiar de columna durante el aviso lo esquiva")


func test_count_fires_a_fan_of_three_shots() -> void:
	var v: AutoplayVideo = _video("count", -1)
	var hits: Array = _hits(v)
	_stand_at(COL - 3)
	_step_until(v, func() -> bool: return v.get_state() == AutoplayVideo.STATE_ATTACK, "ataque")
	var shots: Array[NotificationShot] = v.get_shots()
	assert_eq(shots.size(), 3, "3 proyectiles")
	var ys: Array = []
	for shot: NotificationShot in shots:
		assert_lt(shot.heading.x, 0.0, "Hacia facing (izquierda)")
		ys.append(snappedf(shot.heading.y, 0.01))
	ys.sort()
	assert_lt(float(ys[0]), 0.0, "Uno hacia arriba")
	assert_almost_eq(float(ys[1]), 0.0, EPS, "Uno recto")
	assert_gt(float(ys[2]), 0.0, "Uno hacia abajo")
	_step(v, roundi(1.0 / DT))
	assert_eq(hits.size(), 1, "El proyectil recto le da")


func test_dash_passes_through_wave_ray_and_shots() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, true)
	for clip: String in ["wave", "ray", "count"]:
		GameState.debug_energy = GameState.get_debug_energy_max()
		var v: AutoplayVideo = _video(clip, -1)
		var hits: Array = _hits(v)
		_stand_at(COL - 6)
		_isak.facing = 1.0
		# Cuando el ataque le va a dar, Isak se desliza a traves.
		if clip == "ray":
			# Justo antes de que caiga el rayo en su columna.
			_step_until(v, func() -> bool: return v.get_clip_time() >= v.get_warn_s() - 0.05, "rayo a punto")
		else:
			_step_until(v, func() -> bool: return v.is_dangerous(), "%s: peligro" % clip)
		if clip == "wave":
			# El banner llega desde la derecha: esperar a tenerlo encima.
			_step_until(v, func() -> bool:
				return v.get_banner().get_damage_rect().position.x <= _isak.global_position.x + 80.0, "ola cerca")
		elif clip == "count":
			_step_until(v, func() -> bool:
				return v.get_shots().is_empty() or v.get_shots()[0].global_position.x <= _isak.global_position.x + 80.0,
				"proyectil cerca")
		_sim.input.move_axis = 1.0
		_sim.input.dash_pressed = true
		_step(v)
		_sim.input.dash_pressed = false
		assert_true(_isak.is_dashing(), "%s: dash" % clip)
		_step(v, 10)
		_sim.input.move_axis = 0.0
		assert_eq(hits.size(), 0, "%s: el dash lo atraviesa sin dano" % clip)
		v.queue_free()
		await wait_physics_frames(1)
		_isak.set_physics_process(false)


# --- Pulso, laser y golpe al suelo ---

func test_pulse_pauses_the_clip_and_cancels_the_attack() -> void:
	var v: AutoplayVideo = _video("wave", -1)
	var hits: Array = _hits(v)
	_stand_at(COL - 4)
	_step_until(v, func() -> bool: return v.get_banner().is_sweeping(), "barrido")
	EventBus.pulse_fired.emit(_fake_pulse(v.get_card_rect().get_center(), 96.0))
	assert_true(v.is_stunned(), "El pulso lo aturde")
	assert_false(v.get_banner().is_busy(), "La ola se cancela")
	assert_almost_eq(v.get_stun_left(), 3.0 * GameState.get_pulse_stun_multiplier(), EPS, "3 s")
	var frozen: float = v.get_clip_time()
	_step(v, roundi(2.5 / DT))
	assert_true(v.is_stunned())
	assert_almost_eq(v.get_clip_time(), frozen, EPS, "El clip esta en pausa")
	assert_eq(hits.size(), 0)
	_step(v, roundi(0.6 / DT))
	assert_eq(v.get_state(), AutoplayVideo.STATE_WARN, "Al despertar vuelve a avisar")


func test_pulse_out_of_reach_does_nothing() -> void:
	var v: AutoplayVideo = _video("wave", -1)
	_step(v)
	EventBus.pulse_fired.emit(_fake_pulse(v.get_card_rect().get_center() + Vector2(-600.0, 0.0), 96.0))
	assert_false(v.is_stunned())


func test_laser_bounces_awake_and_breaks_it_stunned() -> void:
	var v: AutoplayVideo = _video("ray", -1)
	assert_eq(LaserProjectile.find_laser_target(v.get_node(^"Body")), v, "El laser lo encuentra por su cuerpo")
	var deflects: Array = []
	v.deflected.connect(func() -> void: deflects.append(1))
	v.on_laser_hit(1.0, _isak)
	assert_eq(deflects.size(), 1, "Despierto: chispa gris")
	assert_almost_eq(v.get_health(), 2.0, EPS, "Sin dano")
	assert_false(v.is_laser_vulnerable())
	v.stun()
	assert_true(v.is_laser_vulnerable())
	var energy_before: int = _count_pickups()
	v.on_laser_hit(1.0, _isak)
	assert_almost_eq(v.get_health(), 1.0, EPS)
	v.on_laser_hit(1.0, _isak)
	assert_true(v.is_broken(), "Vida 2: dos disparos aturdido")
	assert_false(v.is_help_available(), "Roto no ayuda")
	assert_eq(_count_pickups(), energy_before + 1, "Suelta su recarga (+25 de energia)")
	v.reset_patrol()
	assert_true(v.is_broken(), "Roto no vuelve al reaparecer")
	_step(v, 60)
	assert_eq(v.get_clip_count(), 0, "Ni reproduce clips")


func test_ground_pound_wave_stuns_it() -> void:
	var v: AutoplayVideo = _video("wave", -1)
	_step(v)
	var rect := Rect2(v.get_card_rect().position + Vector2(-32.0, 64.0), Vector2(96.0, 96.0))
	assert_eq(GroundPoundWave.apply_to_enemies(get_tree(), rect, 1.0), 1)
	assert_true(v.is_stunned(), "La onda lo aturde")
	assert_almost_eq(v.get_health(), 1.0, EPS, "Y le hace su dano")


# --- Repeticion y reaparicion ---

func test_clips_repeat_while_in_view_and_stop_out_of_it() -> void:
	var v: AutoplayVideo = _video("ray", -1)
	_stand_at(COL - 6)
	_step(v, roundi((v.get_clip_s() * 2.0 + 0.1) / DT))
	assert_eq(v.get_clip_count(), 3, "Cada clip_s, otro clip")
	v.view_rect_override = _out_of_view
	_step(v, roundi(v.get_clip_s() / DT) + 2)
	assert_eq(v.get_state(), AutoplayVideo.STATE_IDLE, "Fuera de la vista termina el clip y se queda quieto")
	var count: int = v.get_clip_count()
	_step(v, 120)
	assert_eq(v.get_clip_count(), count)


func test_reset_returns_to_idle_without_attacks() -> void:
	var v: AutoplayVideo = _video("count", -1)
	_stand_at(COL - 3)
	_step_until(v, func() -> bool: return not v.get_shots().is_empty(), "proyectiles")
	v.reset_patrol()
	assert_eq(v.get_state(), AutoplayVideo.STATE_IDLE)
	assert_eq(v.get_shots().size(), 0, "Sin proyectiles")
	assert_false(v.get_banner().is_busy())
	assert_false(v.get_bell().is_busy())


func _count_pickups() -> int:
	var n: int = 0
	for child: Node in _world.get_children():
		if child is RechargePickup and not child.is_queued_for_deletion():
			n += 1
	return n


# --- Sala de prueba ---

## autoplay_test: los params del nivel llegan a cada video y el lejano no se
## activa (su tarjeta no esta en la vista de la camara real).
func test_room_applies_params_and_far_video_waits() -> void:
	var level := (load("res://scenes/levels/autoplay_test.tscn") as PackedScene).instantiate() as GeneratedLevel
	add_child(level)
	await wait_physics_frames(30)
	var ola := level.get_node(^"Enemies/video_ola") as AutoplayVideo
	var rayo := level.get_node(^"Enemies/video_rayo") as AutoplayVideo
	var cuenta := level.get_node(^"Enemies/video_cuenta") as AutoplayVideo
	assert_eq(ola.get_clip(), AutoplayVideo.CLIP_WAVE)
	assert_eq(rayo.get_clip(), AutoplayVideo.CLIP_RAY)
	assert_eq(rayo.ray_tiles, 6, "params.ray_tiles")
	assert_eq(cuenta.get_clip(), AutoplayVideo.CLIP_COUNT)
	assert_eq(cuenta.facing, -1, "params.facing")
	assert_true(cuenta.get_view_rect().has_area(), "Vista de la camara real")
	assert_false(cuenta.is_fully_in_view(), "Lejos de Isak: fuera de la vista")
	assert_eq(cuenta.get_clip_count(), 0, "Sin clips fuera de la vista")
	level.free()
