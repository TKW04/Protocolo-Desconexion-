# Recuerdos en GameState y en el guardado (paso 2 de docs/propuesta-recuerdos.md
# §7; §4 y §10): GameState.memories (ids de data/memories.json), obtain_memory
# con EventBus.memory_obtained y «sin guardar», has_all_memories (las 18 capas de
# jefe y todos los mensajes de secretos), lectura (memories_read, sin «sin
# guardar»), guardado v5 con migracion que crea la lista vacia, y el rollback:
# lo guardado se conserva (no va a la Papelera: es registro, como found_secrets)
# y lo obtenido sin guardar se pierde con el game over.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_memories_state.json"

var _saved_path: String
var _saved_pulse: bool
var _obtained: Array[StringName] = []
var _read: Array[StringName] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	_obtained.clear()
	_read.clear()
	EventBus.memory_obtained.connect(_on_obtained)
	EventBus.memory_read.connect(_on_read)


func after_each() -> void:
	EventBus.memory_obtained.disconnect(_on_obtained)
	EventBus.memory_read.disconnect(_on_read)
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


func _on_obtained(id: StringName) -> void:
	_obtained.append(id)


func _on_read(id: StringName) -> void:
	_read.append(id)


# --- Catalogo ---

func test_catalog_has_18_boss_layers_and_the_world_1_messages() -> void:
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	var bosses: int = 0
	for world: int in range(1, 7):
		var ids: Array[StringName] = catalog.ids_of(world, MemoryCatalog.KIND_BOSS)
		assert_eq(ids.size(), 3, "Mundo %d: tres capas" % world)
		for layer: int in [1, 2, 3]:
			assert_ne(catalog.boss_id(world, layer), &"", "Mundo %d, capa %d" % [world, layer])
		bosses += ids.size()
	assert_eq(bosses, 18)
	var messages: Array[StringName] = catalog.ids_of(1, MemoryCatalog.KIND_SECRET)
	assert_eq(messages, [&"msg_1_1", &"msg_1_2", &"msg_1_3"] as Array[StringName], "Uno por subnivel, en orden")
	assert_eq(catalog.secret(&"msg_1_2"), "secreto_spam")
	assert_eq(catalog.sender(&"msg_1_1"), "Mamá")
	assert_true(catalog.is_reached(&"boss_w1_l1", GameState.LAP_EASY))
	assert_false(catalog.is_reached(&"boss_w1_l2", GameState.LAP_EASY), "Kernel no se alcanza en Caché")
	assert_true(catalog.is_reached(&"msg_1_1", GameState.LAP_HARD), "Un mensaje de Caché sigue en Raíz")


# --- Obtener y leer ---

func test_obtain_memory_marks_unsaved_and_emits_once() -> void:
	assert_false(GameState.has_unsaved_changes())
	assert_true(GameState.obtain_memory(&"boss_w1_l1"))
	assert_true(GameState.has_memory(&"boss_w1_l1"))
	assert_true(GameState.has_unsaved_changes(), "Obtenido sin guardar")
	assert_eq(_obtained, [&"boss_w1_l1"] as Array[StringName], "EventBus.memory_obtained")
	assert_false(GameState.obtain_memory(&"boss_w1_l1"), "Una vez")
	assert_eq(_obtained.size(), 1)
	assert_false(GameState.obtain_memory(&"no_existe"))
	assert_push_error("unknown memory")
	assert_false(GameState.has_memory(&"no_existe"))


func test_reading_does_not_mark_unsaved() -> void:
	assert_false(GameState.mark_memory_read(&"msg_1_2"), "Sin obtener no se lee")
	GameState.obtain_memory(&"msg_1_2")
	assert_true(GameState.save_game())
	assert_true(GameState.has_unread_memories(), "Nuevo")
	assert_true(GameState.mark_memory_read(&"msg_1_2"))
	assert_false(GameState.mark_memory_read(&"msg_1_2"), "Una vez")
	assert_eq(_read, [&"msg_1_2"] as Array[StringName])
	assert_false(GameState.has_unread_memories())
	assert_false(GameState.has_unsaved_changes(), "Leer no es progreso")


func test_has_all_memories_needs_every_boss_layer_and_every_message() -> void:
	var catalog: MemoryCatalog = MemoryCatalog.shared()
	assert_false(GameState.has_all_memories())
	for id: StringName in catalog.ids():
		if catalog.is_boss(id):
			GameState.obtain_memory(id)
	assert_false(GameState.has_all_memories(), "Las 18 capas no bastan: tambien los mensajes (2026-10-19)")
	var messages: Array[StringName] = catalog.ids_of(1, MemoryCatalog.KIND_SECRET)
	for id: StringName in messages.slice(0, messages.size() - 1):
		GameState.obtain_memory(id)
	assert_false(GameState.has_all_memories(), "Falta un mensaje")
	for id: StringName in catalog.ids():
		GameState.obtain_memory(id)
	assert_true(GameState.has_all_memories())


# --- Guardado v5 ---

func test_round_trip_keeps_memories_and_read_marks() -> void:
	GameState.obtain_memory(&"boss_w1_l1")
	GameState.obtain_memory(&"msg_1_1")
	GameState.mark_memory_read(&"msg_1_1")
	assert_true(GameState.save_game())
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data["version"]), 5)
	assert_eq(data["memories"], ["boss_w1_l1", "msg_1_1"], "Lista ordenada")
	assert_eq(data["memories_read"], ["msg_1_1"])
	GameState.reset_progress()
	assert_true(GameState.memories.is_empty())
	assert_true(GameState.load_game())
	assert_true(GameState.has_memory(&"boss_w1_l1"))
	assert_true(GameState.has_memory(&"msg_1_1"))
	assert_true(GameState.is_memory_read(&"msg_1_1"))
	assert_false(GameState.is_memory_read(&"boss_w1_l1"))
	assert_false(GameState.has_unsaved_changes())


func test_v4_save_is_migrated_with_empty_memories() -> void:
	SaveFile.write(PATH, {"version": 4, "attention_points": 3, "found_secrets": {"1-1": ["secreto_techo"]},
		"allies_met": ["eco", "notas"]})
	assert_true(GameState.load_game(), "Un v4 se carga")
	assert_true(GameState.memories.is_empty(), "La migracion crea la lista vacia")
	assert_eq(GameState.attention_points, 3, "Nada mas cambia")
	assert_true(GameState.is_secret_found(&"1-1", &"secreto_techo"))
	assert_false(GameState.has_unsaved_changes(), "Migrar no marca sin guardar")
	assert_true(GameState.save_game())
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data["version"]), GameState.SAVE_VERSION)
	assert_eq(data["memories"], [])
	# Un v4 que trajera la clave (no deberia) no la usa.
	SaveFile.write(PATH, {"version": 4, "memories": ["boss_w1_l1"]})
	assert_true(GameState.load_game())
	assert_true(GameState.memories.is_empty())


func test_odd_memory_fields_are_tolerated() -> void:
	SaveFile.write(PATH, {"version": 5, "memories": ["boss_w1_l1", "nada", 3], "memories_read": ["msg_1_2", "boss_w1_l1"]})
	assert_true(GameState.load_game())
	assert_eq(GameState.memories.keys(), [&"boss_w1_l1"], "Ids desconocidos se ignoran")
	assert_eq(GameState.memories_read.keys(), [&"boss_w1_l1"], "Solo se lee lo obtenido")
	SaveFile.write(PATH, {"version": 5, "memories": "boss_w1_l1"})
	assert_true(GameState.load_game())
	assert_true(GameState.memories.is_empty())


# --- Rollback y papelera ---

func test_saved_memories_survive_the_rollback_and_unsaved_ones_are_lost() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.attention_points = 5
	GameState.obtain_memory(&"boss_w1_l1")
	GameState.mark_memory_read(&"boss_w1_l1")
	assert_true(GameState.save_game(), "Copia con el recuerdo")
	GameState.obtain_memory(&"msg_1_2")
	assert_true(GameState.has_unsaved_changes(), "El mensaje esta sin guardar")
	var report: Dictionary = GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(report["had_copy"])
	assert_true(GameState.has_memory(&"boss_w1_l1"), "Lo guardado se conserva")
	assert_true(GameState.is_memory_read(&"boss_w1_l1"), "y sigue leido")
	assert_false(GameState.has_memory(&"msg_1_2"), "Lo obtenido sin guardar se pierde")
	assert_true(GameState.has_trash_pending(), "Los puntos van a la papelera")
	var trash: Dictionary = GameState.get_trash()
	for key: Variant in trash:
		assert_false(String(key).contains("memor"), "Los recuerdos no van a la papelera (%s)" % key)
	assert_true(GameState.has_memory(&"boss_w1_l1"), "Con la papelera llena, el recuerdo sigue en el registro")
	assert_true(GameState.recover_trash())
	assert_eq(GameState.memories.keys(), [&"boss_w1_l1"], "Recuperar no toca los recuerdos")


func test_rollback_without_copy_loses_everything() -> void:
	GameState.obtain_memory(&"boss_w1_l1")
	GameState.apply_rollback()
	assert_true(GameState.memories.is_empty(), "Sin copia guardada no queda nada")
