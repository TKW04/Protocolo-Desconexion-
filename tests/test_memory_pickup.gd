# Mensaje de secreto recogible (memory_pickup; paso 4 de docs/propuesta-recuerdos.md
# §7 y §10, 2026-10-19): el sobre del secreto A del 1-1 (msg_1_1, celda 96, 4) y el
# de la carpeta de Spam del 1-2 (msg_1_2, celda 26, 37). Recogerlo obtiene el
# mensaje sin guardar y saca el aviso del sistema (no Eco); guardado y game over
# como lo demas obtenido; no reaparece si el mensaje ya esta en el registro y
# reaparece en su sitio, en cualquier vuelta, si no. Ayuda Q y ficha del album.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/levels/memory_pickup.tscn")
const PATH: String = "user://test_memory_pickup.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const MSG: StringName = &"msg_1_1"
const FORBIDDEN: Array[String] = ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]

var _saved_path: String
var _pulse_was: bool
var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_pulse_was = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	get_tree().paused = false
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was)


# --- Utilidades ---

func _load(scene: PackedScene = LEVEL_SCENE) -> void:
	_level = scene.instantiate() as GeneratedLevel
	_isak = _level.get_node(^"Isak") as Isak
	_sim = IsakSim.new(DT)
	_sim.attach(_isak)
	add_child(_level)
	_sim.take_manual_control()
	await wait_physics_frames(2)


func _pickup() -> MemoryPickup:
	return _level.get_node_or_null(^"Objects/mensaje_1_1") as MemoryPickup


## Isak de pie en la celda (col, row) (pies abajo); unos frames de fisica para
## que el Area2D se entere.
func _stand(col: int, row: int) -> void:
	_sim.input.move_axis = 0.0
	_isak.global_position = Vector2((col + 0.5) * T, (row + 1) * T)
	_isak.velocity = Vector2.ZERO
	_sim.settle()
	await wait_physics_frames(3)


func _notice() -> MemoryNotice:
	return _level.get_node_or_null(^"MemoryNotice") as MemoryNotice


# --- Recoger ---

func test_secret_a_message_is_collected_with_a_system_notice() -> void:
	await _load()
	var pickup: MemoryPickup = _pickup()
	assert_not_null(pickup, "El sobre esta en el secreto A (96, 4)")
	assert_eq(pickup.memory_id, MSG)
	assert_eq(pickup.position, Vector2(96 * T, 4 * T))
	assert_true(pickup.is_in_group(HelpCatalog.TARGET_GROUP), "Tiene ayuda con Q")
	assert_false(GameState.has_memory(MSG))
	assert_false(GameState.has_unsaved_changes())
	var obtained: Array = []
	var on_obtained := func(id: StringName) -> void: obtained.append(id)
	EventBus.memory_obtained.connect(on_obtained)
	await _stand(96, 4)
	EventBus.memory_obtained.disconnect(on_obtained)
	assert_true(pickup.is_taken(), "Al tocarlo se recoge")
	assert_true(GameState.has_memory(MSG), "El mensaje queda obtenido")
	assert_false(GameState.is_memory_read(MSG), "Sin leer: se lee en Notas")
	assert_true(GameState.has_unsaved_changes(), "Sin guardar")
	assert_eq(obtained, [MSG], "Una sola vez")
	assert_false(pickup.is_help_available(), "Recogido ya no ayuda")
	var notice: MemoryNotice = _notice()
	assert_not_null(notice, "Sale el aviso del sistema en el nivel")
	assert_eq(notice, pickup.get_notice())
	assert_eq(Array(notice.get_lines()), ["Recuerdo obtenido: Mamá.", "Guarda en Notas para conservarlo."])
	assert_true(notice.is_showing())
	assert_gt(notice.layer, (_level.get_node(^"Hud") as CanvasLayer).layer, "Por encima del HUD")
	assert_false(get_tree().paused, "No pausa")
	for line: String in notice.get_lines():
		for word: String in FORBIDDEN:
			assert_false(line.contains(word), "Sin «%s»" % word)
	# El sobre se libera tras su animacion; el aviso sigue (vive en el nivel).
	var pickup_ref: WeakRef = weakref(pickup)
	var notice_ref: WeakRef = weakref(notice)
	await wait_until(func() -> bool: return pickup_ref.get_ref() == null, 2.0)
	assert_null(pickup_ref.get_ref(), "El sobre se libera")
	assert_true(notice_ref.get_ref() != null and notice.is_showing(), "El aviso sigue tras liberarse el sobre")
	await wait_until(func() -> bool: return notice_ref.get_ref() == null, 5.0)
	assert_null(notice_ref.get_ref(), "El aviso se va solo")


func test_collect_only_once() -> void:
	await _load()
	var pickup: MemoryPickup = _pickup()
	assert_true(pickup.collect())
	assert_false(pickup.collect(), "Ya recogido")


# --- Reaparecer o no ---

func test_obtained_message_does_not_reappear_on_reentry_or_after_load() -> void:
	await _load()
	_pickup().collect()
	_level.free()
	await _load()
	assert_null(_pickup(), "Obtenido sin guardar: al reentrar no sale")
	assert_true(GameState.save_game())
	_level.free()
	GameState.reset_progress()
	assert_true(GameState.load_game())
	assert_true(GameState.has_memory(MSG), "Se guarda")
	await _load()
	assert_null(_pickup(), "Guardado: tras cargar no sale")


func test_not_obtained_message_reappears_in_any_lap() -> void:
	for lap: int in [GameState.LAP_EASY, GameState.LAP_NORMAL, GameState.LAP_HARD]:
		GameState.lap = lap
		await _load()
		assert_not_null(_pickup(), "Vuelta interna %d sin el mensaje: sale" % lap)
		_level.free()
	GameState.mark_secret_found(&"1-1", &"secreto_puente_servicio")
	await _load()
	assert_not_null(_pickup(), "No depende de found_secrets")
	_level.free()
	GameState.lap = GameState.LAP_NORMAL
	GameState.obtain_memory(MSG)
	await _load()
	assert_null(_pickup(), "Con el mensaje en el registro no sale, tampoco en otra vuelta")


func test_game_over_without_saving_gives_the_message_back() -> void:
	assert_true(GameState.save_game(), "Copia sin el mensaje")
	await _load()
	_pickup().collect()
	assert_true(GameState.has_memory(MSG))
	_level.free()
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.has_memory(MSG), "Sin guardar, el game over lo quita")
	GameState.recover_trash()
	assert_false(GameState.has_memory(MSG), "No va a la Papelera")
	await _load()
	assert_not_null(_pickup(), "Vuelve a estar en su sitio")


func test_saved_message_survives_game_over() -> void:
	await _load()
	_pickup().collect()
	_level.free()
	assert_true(GameState.save_game())
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	GameState.recover_trash()
	assert_true(GameState.has_memory(MSG), "Guardado, se conserva")
	await _load()
	assert_null(_pickup(), "Y no reaparece")


# --- 1-2: carpeta de Spam ---

func test_spam_message_is_in_the_spam_folder_of_1_2() -> void:
	var level := (load("res://scenes/levels/1-2.tscn") as PackedScene).instantiate() as GeneratedLevel
	add_child_autofree(level)
	await wait_physics_frames(2)
	var pickup := level.get_node_or_null(^"Objects/mensaje_1_2") as MemoryPickup
	assert_not_null(pickup, "Sobre de la carpeta de Spam")
	assert_eq(pickup.memory_id, &"msg_1_2")
	assert_eq(pickup.position, Vector2(26 * T, 37 * T), "Celda (26, 37)")
	assert_not_null(level.get_node_or_null(^"AttentionPoints/Point_26_37"), "El punto de esa celda sigue")
	assert_eq(pickup.get_level_id(), &"1-2")


# --- Objeto suelto y aviso ---

func test_unknown_memory_id_is_not_created() -> void:
	var pickup := PICKUP_SCENE.instantiate() as MemoryPickup
	pickup.memory_id = &"msg_no_existe"
	add_child(pickup)
	assert_true(pickup.is_taken())
	assert_push_error("memory_id desconocido")
	await wait_physics_frames(1)
	assert_false(is_instance_valid(pickup))


func test_loose_pickup_puts_its_notice_on_its_parent() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	var pickup := PICKUP_SCENE.instantiate() as MemoryPickup
	pickup.memory_id = &"msg_1_2"
	host.add_child(pickup)
	await wait_physics_frames(1)
	assert_eq(pickup.get_level_id(), GameState.NO_LEVEL)
	assert_true(pickup.collect())
	assert_eq(pickup.get_notice().get_parent(), host)
	assert_eq(Array(pickup.get_notice().get_lines()), ["Recuerdo obtenido: Mamá.", "Guarda en Notas para conservarlo."])


# --- Ayuda y album ---

func test_help_and_album_card_exist() -> void:
	var catalog: HelpCatalog = HelpCatalog.shared()
	assert_true(catalog.has(&"memory_pickup"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/help.json"))
	var entry: Dictionary = data["types"]["memory_pickup"]
	assert_eq(entry["category"], "object", "Ficha en la pestana Objetos")
	assert_eq(int(entry["world"]), 1)
	for word: String in FORBIDDEN:
		assert_false(catalog.text(&"memory_pickup").contains(word), "Sin «%s»" % word)
		assert_false(String(entry["title"]).contains(word))
	assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_memory_pickup.png"))
	assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_memory_pickup_silhouette.png"))
	assert_eq(String(World1ObjectsConfig.type_entry("memory_pickup").get("help_id", "")), "memory_pickup")
