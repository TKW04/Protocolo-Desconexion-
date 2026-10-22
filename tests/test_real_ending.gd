# Gancho del final real (paso 8 de docs/propuesta-recuerdos.md, §11.4;
# docs/06-finales.md §14.1): GameState.real_ending_unlocked() exige Raíz y TODOS
# los recuerdos de data/memories.json (las 18 capas de jefe y todos los mensajes
# de secretos); real_ending_missing() dice cuales faltan (con before_final_boss,
# sin la capa Raíz del Mundo 6, que entrega la propia pelea). Cuenta lo obtenido
# sin guardar; sobrevive a guardar y cargar; un guardado v4 migrado no trae
# recuerdos; un game over pierde lo no guardado. El final aun no existe: aqui solo
# se prueba la condicion. Usa su propia ruta de guardado.
extends GutTest

const PATH: String = "user://test_real_ending.json"

var _saved_path: String


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()


func after_each() -> void:
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path


func _obtain_all(except: Array[StringName] = []) -> void:
	for id: StringName in MemoryCatalog.shared().ids():
		if not except.has(id):
			GameState.obtain_memory(id)


func test_nothing_obtained_misses_everything() -> void:
	GameState.lap = GameState.LAP_HARD
	assert_false(GameState.real_ending_unlocked())
	assert_eq(GameState.real_ending_missing(), MemoryCatalog.shared().ids(), "Todo el catalogo, en su orden")


func test_requirement_is_every_boss_layer_and_every_message() -> void:
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var bosses: int = 0
	var messages: int = 0
	for id: StringName in catalog.ids():
		if catalog.is_boss(id):
			bosses += 1
		else:
			messages += 1
	assert_eq(bosses, 18, "6 jefes x 3 capas")
	assert_gt(messages, 0, "Y los mensajes de secretos (decision del 2026-10-19)")
	assert_eq(GameState.real_ending_missing().size(), bosses + messages)


func test_only_in_root_with_everything() -> void:
	_obtain_all()
	for lap: int in [GameState.LAP_EASY, GameState.LAP_NORMAL]:
		GameState.lap = lap
		assert_false(GameState.real_ending_unlocked(), "Solo en Raíz (vuelta %d)" % lap)
	GameState.lap = GameState.LAP_HARD
	assert_true(GameState.real_ending_unlocked())
	assert_eq(GameState.real_ending_missing(), [] as Array[StringName])


func test_a_missing_message_blocks_the_real_ending() -> void:
	_obtain_all([&"msg_1_2"])
	GameState.lap = GameState.LAP_HARD
	assert_true(GameState.has_memory(&"boss_w6_l3"), "Todas las capas de jefe")
	assert_false(GameState.real_ending_unlocked(), "Falta el mensaje de la carpeta de Spam")
	assert_eq(GameState.real_ending_missing(), [&"msg_1_2"] as Array[StringName])


func test_a_missing_boss_layer_blocks_the_real_ending() -> void:
	_obtain_all([&"boss_w3_l2"])
	GameState.lap = GameState.LAP_HARD
	assert_false(GameState.real_ending_unlocked())
	assert_eq(GameState.real_ending_missing(), [&"boss_w3_l2"] as Array[StringName])


func test_before_final_boss_ignores_the_final_root_layer() -> void:
	_obtain_all([&"boss_w6_l3"])
	GameState.lap = GameState.LAP_HARD
	assert_eq(GameState.real_ending_missing(true), [] as Array[StringName], "Lista para el jefe final")
	assert_eq(GameState.real_ending_missing(), [&"boss_w6_l3"] as Array[StringName])
	assert_false(GameState.real_ending_unlocked(), "Aun sin la capa de Isak Optimizado")
	# La pelea la entrega (sin guardar) y justo despues se comprueba.
	BossReward.grant(GameState.REAL_ENDING_FINAL_WORLD, GameState.LAP_HARD)
	assert_true(GameState.has_unsaved_changes(), "Recien entregada, sin guardar")
	assert_true(GameState.real_ending_unlocked(), "Cuenta aunque no se haya guardado")


func test_survives_save_and_load() -> void:
	_obtain_all()
	GameState.lap = GameState.LAP_HARD
	assert_true(GameState.save_game())
	GameState.reset_progress()
	assert_false(GameState.real_ending_unlocked())
	assert_true(GameState.load_game())
	assert_eq(GameState.lap, GameState.LAP_HARD, "La vuelta se guarda")
	assert_true(GameState.real_ending_unlocked(), "Los recuerdos guardados cuentan tras cargar")


func test_v4_save_in_root_is_migrated_without_memories() -> void:
	SaveFile.write(PATH, {"version": 4, "lap": GameState.LAP_HARD, "allies_met": ["eco", "notas"]})
	assert_true(GameState.load_game(), "Un v4 se carga")
	assert_eq(GameState.lap, GameState.LAP_HARD)
	assert_false(GameState.real_ending_unlocked(), "Un guardado anterior a los recuerdos no los trae")
	assert_eq(GameState.real_ending_missing().size(), MemoryCatalog.shared().ids().size())


func test_game_over_loses_unsaved_memories_for_the_real_ending() -> void:
	_obtain_all([&"msg_1_3"])
	GameState.lap = GameState.LAP_HARD
	assert_true(GameState.save_game(), "Copia sin el mensaje del 1-3")
	GameState.obtain_memory(&"msg_1_3")
	assert_true(GameState.real_ending_unlocked())
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.real_ending_unlocked(), "Sin guardar, el game over se lo lleva")
	assert_eq(GameState.real_ending_missing(), [&"msg_1_3"] as Array[StringName],
		"Reaparece en su secreto: hay que volver a por el")
