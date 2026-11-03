extends GutTest
# Vidas en TODOS los niveles y jefes (bug del usuario 2026-11-03: «te mueres en
# un mapa y cuando sales al hub recuperas la vida»). Integracion real con
# scenes/main.tscn: en cada nivel (1-1 ... 5-boss) se pierde una vida por dano y
# otra por caida, se vuelve al hub por cada camino (completar, «Salir al hub»,
# R desde el hub) y se entra a otro nivel; las vidas nunca se reponen salvo
# game over, partida nueva y guardar en Notas. Ademas: cerrar y abrir el juego
# sin guardar tras perder vidas no las rellena (lives se apunta en el guardado
# al perderlas).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_lives_all_paths.json"
const LONG_STEP_S: float = 5.0
const LEVELS: Array[String] = [
	"1-1", "1-2", "1-3", "1-boss",
	"2-1", "2-2", "2-3", "2-boss",
	"3-1", "3-2", "3-3", "3-boss",
	"4-1", "4-2", "4-3", "4-boss",
	"5-1", "5-2", "5-3", "5-boss",
]

var _saved_path: String
var _saved_level: StringName
var _main: LevelRunner


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	GameState.use_save_path(PATH, true)
	DebugMode.input_enabled = false


func after_each() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.last_checkpoint.clear()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _veteran(lives_max: int) -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	for id: String in LEVELS:
		GameState.unlock_level(StringName(id))
	GameState.lives_max = lives_max
	GameState.refill_lives()


func _boot(level_id: String) -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = level_id
	add_child(_main)
	_main.advance(LONG_STEP_S)
	await wait_physics_frames(5)


func _settle() -> void:
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	await wait_physics_frames(3)


func _die_by_damage() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	await wait_physics_frames(2)
	_main.advance(_main.get_death_wait_s() + 0.01)
	await _settle()


func _die_by_fall() -> void:
	var isak: Isak = _main.get_isak()
	isak.global_position = Vector2(isak.global_position.x, _main.get_fall_limit_y() + 256.0)
	isak.velocity = Vector2.ZERO
	assert_true(_main.check_fall(), "La caida se detecta")
	await _settle()


func _complete(level_id: String) -> void:
	EventBus.level_completed.emit(level_id)
	await _settle()


func _hud_lives(where: String) -> int:
	var hud: Hud = null
	if _main.is_in_hub():
		hud = _main.get_hub().get_hud()
	elif _main.get_level() != null:
		hud = _main.get_level().get_node_or_null(^"Hud") as Hud
	assert_not_null(hud, "HUD en %s" % where)
	return hud.get_lives_lit() if hud != null else -1


func _assert_lives(expected: int, where: String) -> void:
	assert_eq(GameState.lives, expected, "GameState.lives en %s" % where)
	assert_eq(_hud_lives(where), expected, "HUD en %s" % where)


# Cada nivel y jefe: dano + caida restan; completar lleva al hub con las mismas;
# entrar al siguiente nivel las mantiene.
# (Con 5 de maximo el HUD dibuja un telefono por vida; al empezar cada nivel,
# ya comprobada la entrada, la prueba vuelve a poner 5 para no llegar a 0.)
func test_every_level_and_boss_keeps_lost_lives_through_hub_and_next_level() -> void:
	_veteran(5)
	await _boot(LEVELS[0])
	var expected: int = 5
	for i: int in LEVELS.size():
		var id: String = LEVELS[i]
		if i > 0:
			assert_true(_main.enter_level(id), "Entrar a %s desde el hub" % id)
			await _settle()
		assert_eq(_main.get_level_id(), id)
		assert_false(_main.is_in_hub(), "En %s" % id)
		_assert_lives(expected, "entrada de %s" % id)
		GameState.refill_lives()
		expected = 5
		await _die_by_damage()
		expected -= 1
		assert_false(_main.is_in_hub(), "%s: con vidas sigue en el nivel" % id)
		_assert_lives(expected, "%s tras morir por dano" % id)
		await _die_by_fall()
		expected -= 1
		_assert_lives(expected, "%s tras caer" % id)
		await _complete(id)
		assert_true(_main.is_in_hub(), "%s completado: hub" % id)
		_assert_lives(expected, "hub tras %s" % id)


# «Salir al hub» desde cada nivel ya completado (tambien jefes) y R desde el hub.
func test_exit_to_hub_and_restart_from_hub_in_every_level_keep_lives() -> void:
	_veteran(5)
	for id: String in LEVELS:
		GameState.mark_level_completed(StringName(id))
	await _boot(LEVELS[0])
	var expected: int = 5
	for i: int in LEVELS.size():
		var id: String = LEVELS[i]
		if i > 0:
			assert_true(_main.enter_level(id), "Entrar a %s" % id)
			await _settle()
			_assert_lives(expected, "entrada de %s" % id)
		GameState.refill_lives()
		expected = 5
		await _die_by_damage()
		expected -= 1
		assert_true(_main.request_exit_to_hub(), "%s: «Salir al hub»" % id)
		await _settle()
		assert_true(_main.is_in_hub())
		_assert_lives(expected, "hub tras salir de %s" % id)
		# R desde el hub vuelve a empezar el ultimo nivel: tampoco las repone.
		assert_true(_main.request_restart(), "R desde el hub")
		await _settle()
		assert_eq(_main.get_level_id(), id)
		_assert_lives(expected, "%s tras R desde el hub" % id)
		assert_true(_main.request_restart(), "R dentro del nivel")
		await _settle()
		_assert_lives(expected, "%s tras R" % id)
		assert_true(_main.request_exit_to_hub())
		await _settle()


# Cerrar el juego tras perder una vida (sin guardar despues) y volver a abrirlo:
# se arranca en el hub con las vidas perdidas, no con las del ultimo guardado.
func test_closing_and_reopening_without_saving_keeps_lost_lives() -> void:
	_veteran(3)
	GameState.mark_level_completed(&"1-1")
	assert_true(GameState.save_game_and_rest(), "Copia con las vidas llenas")
	await _boot("1-1")
	await _die_by_damage()
	_assert_lives(2, "1-1 tras morir")
	assert_false(GameState.has_unsaved_changes(), "Perder una vida no marca «sin guardar»")
	assert_true(_main.request_exit_to_hub())
	await _settle()
	_assert_lives(2, "hub")
	# Cierre y nueva apertura del juego.
	_main.free()
	_main = null
	GameState.reset_progress()
	GameState.use_save_path(PATH, false)
	assert_true(GameState.started_from_save, "Hay partida")
	assert_eq(GameState.lives, 2, "Al abrir, las vidas perdidas siguen perdidas")
	await _boot("hub")
	_assert_lives(2, "hub al abrir")
	# Lo no guardado (p. ej. puntos) no se escribio por perder la vida.
	assert_true(GameState.is_level_completed(&"1-1"))


# Perder una vida en una partida nueva (sin copia en disco) no crea guardado.
func test_losing_a_life_without_a_save_file_does_not_create_one() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	assert_false(FileAccess.file_exists(PATH))
	GameState.lose_life()
	assert_false(FileAccess.file_exists(PATH), "Sin copia no se escribe nada")


# Un game over sigue reponiendo y deja la copia con las vidas llenas.
func test_game_over_refills_and_disk_matches() -> void:
	_veteran(3)
	assert_true(GameState.save_game_and_rest())
	await _boot("1-1")
	await _die_by_damage()
	await _die_by_damage()
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	await wait_physics_frames(2)
	_main.advance(_main.get_death_wait_s() + 0.01)
	await _settle()
	assert_eq(_main.get_game_over_count(), 1)
	_assert_lives(3, "hub tras game over")
	GameState.reset_progress()
	assert_true(GameState.load_game())
	assert_eq(GameState.lives, 3, "Tras el game over, al abrir: llenas")


# Bug del usuario 2026-11-03: el game over rellena hasta el lives_max guardado
# (vidas extra ya guardadas), no hasta las 3 iniciales. Tambien tras cerrar y abrir.
func _game_over_with_saved_max(lives_max: int, reopen_before: bool) -> void:
	_veteran(3)
	for i: int in lives_max - GameState.LIVES_MAX_DEFAULT:
		assert_true(GameState.collect_extra_life(&"1-1", StringName("vida_%d" % i)), "Vida extra %d" % i)
	assert_eq(GameState.lives_max, lives_max)
	assert_true(GameState.save_game_and_rest(), "Copia con lives_max %d" % lives_max)
	if reopen_before:
		GameState.reset_progress()
		GameState.use_save_path(PATH, false)
		assert_eq(GameState.lives_max, lives_max, "Al abrir, lives_max guardado")
	await _boot("1-1")
	for i: int in lives_max:
		await _die_by_damage()
	assert_eq(_main.get_game_over_count(), 1, "Game over con lives_max %d" % lives_max)
	assert_true(_main.is_in_hub())
	assert_eq(GameState.lives_max, lives_max, "El game over no quita vidas extra guardadas")
	_assert_lives(lives_max, "hub tras game over (max %d)" % lives_max)
	# Cerrar y abrir tras el game over: siguen todas.
	_main.free()
	_main = null
	GameState.reset_progress()
	GameState.use_save_path(PATH, false)
	assert_eq(GameState.lives_max, lives_max, "Al abrir tras el game over: lives_max")
	assert_eq(GameState.lives, lives_max, "Al abrir tras el game over: llenas")
	await _boot("hub")
	_assert_lives(lives_max, "hub al abrir tras game over (max %d)" % lives_max)


func test_game_over_refills_to_saved_max_4() -> void:
	await _game_over_with_saved_max(4, false)


func test_game_over_refills_to_saved_max_5_after_reopen() -> void:
	await _game_over_with_saved_max(5, true)


# Una vida extra recogida y NO guardada se pierde con el game over (como todo lo
# no guardado; vuelve a estar en su secreto): rellena hasta el maximo guardado.
func test_game_over_loses_unsaved_extra_life_but_keeps_saved_ones() -> void:
	_veteran(3)
	assert_true(GameState.collect_extra_life(&"1-1", &"vida_guardada"))
	assert_true(GameState.save_game_and_rest())
	assert_true(GameState.collect_extra_life(&"1-2", &"vida_sin_guardar"))
	assert_eq(GameState.lives_max, 5)
	await _boot("1-1")
	for i: int in 5:
		await _die_by_damage()
	assert_eq(_main.get_game_over_count(), 1)
	assert_eq(GameState.lives_max, 4, "Solo se pierde la vida extra sin guardar")
	_assert_lives(4, "hub tras game over")
	assert_false(GameState.is_secret_found(&"1-2", &"vida_sin_guardar"), "La vida sin guardar reaparece")


# --- Vida extra real del 1-1 y game over (confirmacion del usuario 2026-11-03) ---

func _extra_life_pickup() -> ExtraLifePickup:
	var level: Node = _main.get_level()
	return level.get_node_or_null(^"Objects/vida_extra_1_1") as ExtraLifePickup if level != null else null


## Abre la pared con glitch del secreto D y recoge la vida extra real.
func _collect_real_extra_life() -> void:
	var pickup: ExtraLifePickup = _extra_life_pickup()
	assert_not_null(pickup, "La vida extra del 1-1 esta en el nivel")
	if pickup == null:
		return
	var wall: GlitchWall = pickup.get_wall()
	assert_not_null(wall, "La tapa la pared con glitch")
	assert_true(wall.open_with_debug(), "La pared se disuelve")
	for i: int in 20:
		wall.advance(0.1)
	await wait_physics_frames(3)
	assert_true(pickup.is_shown(), "La vida extra se ve")
	assert_true(pickup.collect(), "Se recoge la vida extra")
	await wait_physics_frames(2)


func _game_over_in_current_level() -> void:
	for i: int in 12:
		if _main.is_in_hub():
			break
		await _die_by_damage()
	assert_eq(_main.get_game_over_count(), 1, "Game over")
	assert_true(_main.is_in_hub(), "Tras el game over, en el hub")


## Vuelve a entrar al 1-1 desde el hub (recupera antes la papelera, si tiene algo).
func _reenter_1_1() -> void:
	GameState.recover_trash()
	assert_true(_main.enter_level("1-1"), "Volver a entrar al 1-1")
	await _settle()
	await wait_physics_frames(3)
	assert_eq(_main.get_level_id(), "1-1")


# (A) Vida extra recogida y NO guardada: game over → lives_max 3 con 3 vidas, y
# la vida extra reaparece en el 1-1 para volver a cogerla.
func test_unsaved_real_extra_life_is_lost_on_game_over_and_reappears() -> void:
	_veteran(3)
	GameState.mark_level_completed(&"1-1")
	assert_true(GameState.save_game_and_rest(), "Copia con lives_max 3")
	await _boot("1-1")
	await _collect_real_extra_life()
	assert_eq(GameState.lives_max, 4, "Con la vida extra: 4")
	assert_eq(GameState.lives, 4)
	assert_true(GameState.has_unsaved_changes(), "La vida extra queda sin guardar")
	await _game_over_in_current_level()
	assert_eq(GameState.lives_max, 3, "Sin guardar, el maximo vuelve a 3")
	_assert_lives(3, "hub tras game over (A)")
	assert_false(GameState.is_secret_found(&"1-1", &"D"), "El secreto D vuelve a estar sin encontrar")
	await _reenter_1_1()
	var pickup: ExtraLifePickup = _extra_life_pickup()
	assert_not_null(pickup, "La vida extra reaparece en el 1-1")
	if pickup != null:
		assert_false(pickup.is_taken(), "Y se puede volver a coger")
	await _collect_real_extra_life()
	assert_eq(GameState.lives_max, 4, "Recogida otra vez: 4")


# (B) Vida extra recogida y GUARDADA: game over → lives_max 4 con las 4 llenas,
# y la vida extra no reaparece en el 1-1. Tambien tras cerrar y abrir.
func test_saved_real_extra_life_survives_game_over_and_does_not_reappear() -> void:
	_veteran(3)
	GameState.mark_level_completed(&"1-1")
	await _boot("1-1")
	await _collect_real_extra_life()
	assert_eq(GameState.lives_max, 4)
	assert_true(_main.request_exit_to_hub(), "Salir al hub")
	await _settle()
	assert_true(GameState.save_game_and_rest(), "Guardar en Notas con la vida extra")
	assert_true(GameState.has_unsaved_changes() == false)
	await _reenter_1_1()
	assert_null(_extra_life_pickup(), "Guardada: la vida extra no esta en el 1-1")
	await _game_over_in_current_level()
	assert_eq(GameState.lives_max, 4, "El game over conserva la vida extra guardada")
	_assert_lives(4, "hub tras game over (B)")
	assert_true(GameState.is_secret_found(&"1-1", &"D"))
	await _reenter_1_1()
	assert_null(_extra_life_pickup(), "Tras el game over la vida extra no reaparece")
	_assert_lives(4, "1-1 tras game over (B)")
	# Cerrar y abrir: sigue el maximo guardado y la vida extra no vuelve.
	_main.free()
	_main = null
	GameState.reset_progress()
	GameState.use_save_path(PATH, false)
	assert_eq(GameState.lives_max, 4, "Al abrir: lives_max 4")
	assert_eq(GameState.lives, 4, "Al abrir: llenas")
	await _boot("1-1")
	assert_null(_extra_life_pickup(), "Al abrir: la vida extra no reaparece")
	_assert_lives(4, "1-1 al abrir (B)")
