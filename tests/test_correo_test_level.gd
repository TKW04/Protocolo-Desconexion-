# Sala de prueba del acertijo «Correo certificado» (data/levels/correo_test.json,
# escena generada scenes/levels/correo_test.tscn; pasos 3 y 9 de
# docs/propuesta-1-2.md §10, 2026-10-16) de principio a fin con el Isak real:
# laser al lector desde el suelo, fallar la ventana (se reinicia sola, sin dano
# ni muerte), resolverla (puente), romper el anuncio, cerrar el pop-up y
# recoger el chip del Debug (Debug desbloqueado y energia llena). Al volver a
# cargar la sala con el Debug obtenido el chip no esta. Isak se coloca en cada
# punto (la ruta a pie la comprueba tools/validate_level.py) y dispara o lanza
# el pulso con la entrada falsa.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/correo_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _saved_pause: bool


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()
	await _load()


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _load() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	await wait_physics_frames(2)


func _obj(id: String) -> Node:
	return _level.get_node_or_null(NodePath("Objects/" + id))


## Pone a Isak de pie en la celda (col, fila) y espera a que se asiente.
func _stand(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(1)
	_sim.settle()
	await wait_physics_frames(2)


func _fire() -> LaserProjectile:
	var fired: Array[LaserProjectile] = []
	var on_fired := func(p: LaserProjectile) -> void: fired.append(p)
	_isak.laser_fired.connect(on_fired)
	_sim.input.laser_pressed = true
	_sim.step()
	for i: int in 40:
		if not fired.is_empty():
			break
		_sim.step()
	_isak.laser_fired.disconnect(on_fired)
	if fired.is_empty():
		return null
	var p: LaserProjectile = fired[0]
	p.auto_process = false
	for i: int in 120:
		if p.is_finished():
			break
		p.step(DT)
	_sim.step(ceili(_isak.abilities.laser_cooldown_s / DT) + 30)
	return p


func _pulse() -> void:
	_sim.input.pulse_pressed = true
	_sim.step(40)


func test_scene_is_up_to_date_and_has_the_puzzle() -> void:
	assert_eq(_level.level_id, "correo_test")
	for id: String in ["lector_1", "receptor_enlazado_1", "puente_correo", "popup_buzon", "anuncio_buzon",
			"debug_1_2", "cargador_1", "terminal_correo"]:
		assert_not_null(_obj(id), "Objeto %s" % id)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_LASER), "La sala da el laser")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Sin Debug hasta el chip")
	var charger := _obj("cargador_1") as Charger
	var reader := _obj("lector_1") as LaserReceiver
	assert_lte(absf(charger.position.x - 4.0 * TILE) / TILE, 3.0, "Cargador junto al punto de disparo")
	assert_eq(reader.window_s, 6.0)


func test_failing_the_window_resets_without_damage_then_solving_gives_the_debug() -> void:
	var reader := _obj("lector_1") as LaserReceiver
	var relay := _obj("receptor_enlazado_1") as RelayReceiver
	var bridge := _obj("puente_correo") as PulseBridge
	var popup := _obj("popup_buzon") as PopupBlocker
	var ad := _obj("anuncio_buzon") as AdCover
	var lives_before: int = GameState.lives
	# 1. Disparo desde el suelo de la sala.
	await _stand(4, 10)
	var shot: LaserProjectile = await _fire()
	assert_eq(shot.get_hit_target(), reader, "Desde el suelo, al lector")
	assert_true(reader.is_powered())
	assert_lt(GameState.debug_energy, GameState.get_debug_energy_max(), "Cada disparo gasta energia")
	# Fallo: vence la ventana (tiempo del mundo) antes del pulso.
	reader.advance(6.5)
	assert_false(reader.is_powered(), "Vencida")
	await _stand(7, 6)
	_pulse()
	assert_false(relay.is_active(), "Fuera de tiempo el pulso no hace nada")
	assert_gt(relay.get_rejection_count(), 0, "Chispa gris")
	assert_eq(bridge.get_state(), PulseBridge.State.RETRACTED)
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Sin dano")
	assert_false(_isak.is_dead(), "Sin muerte")
	assert_eq(GameState.lives, lives_before, "Sin gastar vidas")
	# 2. Otra vez, a tiempo; ahora pegado al bloque (el celular queda dentro de la
	# pared: el lector cuenta el disparo igual).
	await _stand(14, 10)
	var close_shot: LaserProjectile = await _fire()
	assert_eq(close_shot.get_hit_target(), reader, "Pegado al lector tambien cuenta")
	assert_true(reader.is_powered())
	await _stand(7, 6)
	assert_gt(reader.get_power_left(), 0.0)
	_pulse()
	assert_true(relay.is_active(), "Con corriente se activa")
	await wait_physics_frames(40)
	assert_true(bridge.is_extended(), "El puente llega a la caja fuerte")
	# 3. Final del puente: el pulso rebota en el anuncio.
	await _stand(14, 6)
	assert_true(_isak.is_on_floor(), "De pie sobre el puente")
	_pulse()
	assert_true(popup.is_open(), "Con el anuncio encima no se cierra")
	assert_gt(ad.get_bounce_count(), 0)
	var ad_shot: LaserProjectile = await _fire()
	assert_eq(ad_shot.get_hit_target(), ad, "El laser rompe el anuncio")
	assert_true(ad.is_broken())
	# 4. Pulso al boton.
	_pulse()
	assert_false(popup.is_open(), "El pop-up se cierra")
	await wait_physics_frames(30)
	assert_true(popup.is_closed())
	# 5. Chip del Debug.
	GameState.debug_energy = 12.0
	await _stand(18, 6)
	_isak.global_position.x = 19.5 * TILE
	await wait_physics_frames(3)
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DEBUG), "Debug obtenido")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Debug desbloqueado")
	assert_eq(GameState.debug_energy, GameState.get_debug_energy_max(), "Energia llena")
	# Volver a la sala con el Debug: el chip no esta.
	await _load()
	var chip: Node = _obj("debug_1_2")
	assert_true(chip == null or chip.is_queued_for_deletion() or not (chip as AbilityPickup).is_help_available(),
		"El chip no reaparece")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "El nivel no bloquea un Debug obtenido")
