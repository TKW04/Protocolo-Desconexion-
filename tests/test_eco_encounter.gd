# Encuentro con Eco del 1-1 (EcoEncounter, data/eco_encounter.json; paso 6 de
# docs/propuesta-asistentes-y-vidas.md §10) y conversion de las lineas de Eco
# del 1-1 (paso 7, §4.1):
# - el 1-1 empieza sin pulso; nada antes del encuentro lo exige;
# - el encuentro se dispara una vez y sigue la secuencia presentacion -> apodo
#   -> regalo -> pulso (con su aviso) -> ultima linea, con el juego en pausa;
#   el pulso no esta antes y si despues; Eco queda conocido al final y el
#   companero aparece; el apodo se guarda y sale en las lineas;
# - con Eco conocido (rejugar, guardado migrado) no se repite;
# - ninguna linea automatica marcada «ayuda Q» o «eliminar» sigue en el 1-1, la
#   historia del laser si, y data/help.json cubre las movidas.
# Usa una ruta de guardado propia.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_PATH: String = "res://data/levels/1-1.json"
const PATH: String = "user://test_eco_encounter_save.json"
const T: float = 64.0
const LONG_STEP_S: float = 5.0
## Pies de Isak dentro de la zona del encuentro (columnas 10-12, suelo en la fila 10).
const IN_ZONE: Vector2 = Vector2(11.5 * T, 10.0 * T)
## Lineas automaticas del 1-1 que pasaron a la ayuda con Q (id de la linea -> tipo de ayuda).
const MOVED_TO_HELP: Dictionary = {
	"eco_punto": "attention_point", "eco_burbuja": "alert_bubble", "eco_receptor": "receiver",
	"eco_power_bank": "power_bank_pickup", "eco_sync": "sync_point", "eco_popup": "popup_blocker",
	"eco_puerta": "exit_terminal", "eco_glitch": "glitch_wall",
}
const REMOVED: Array[String] = ["eco_bienvenida", "eco_foso", "eco_puente", "eco_techo_bajo",
	"eco_pulso_amplio", "eco_sala_laser", "eco_laser_disparo", "eco_escalon"]

var _saved_path: String
var _saved_level: StringName
var _saved_pause_important: bool
var _saved_pulse: bool
var _level: GeneratedLevel
var _main: LevelRunner
var _lines: Array[String] = []
var _important: Array[bool] = []
var _data: Dictionary = EcoEncounter.load_data()


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pause_important = EcoTextBox.pause_important
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	EcoTextBox.pause_important = true
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	_lines.clear()
	_important.clear()
	EventBus.eco_line_requested.connect(_on_line)


func after_each() -> void:
	EventBus.eco_line_requested.disconnect(_on_line)
	if is_instance_valid(_level):
		_level.free()
	_level = null
	if is_instance_valid(_main):
		_main.free()
	_main = null
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	DebugMode.reset()
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.current_level = _saved_level
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _on_line(text: String, _duration_s: float, important: bool) -> void:
	_lines.append(text)
	_important.append(important)


func _load_level() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	add_child(_level)
	await wait_physics_frames(2)


func _encounter(root: Node) -> EcoEncounter:
	return root.get_node(^"Objects/eco_encuentro") as EcoEncounter


func _walk_in(isak: Isak) -> void:
	isak.global_position = IN_ZONE
	isak.velocity = Vector2.ZERO
	await wait_physics_frames(3)


## Cierra la linea importante en pantalla como el jugador (completa y confirma).
func _close_line(box: EcoTextBox) -> void:
	box.finish_typing()
	assert_true(box.confirm(), "Linea importante en pantalla")
	box.advance(LONG_STEP_S)
	await wait_process_frames(2)


## Recorre lo que quede del encuentro como el jugador (deja el apodo o escribe `nickname`).
func _drive(encounter: EcoEncounter, box: EcoTextBox, nickname: String = "") -> void:
	var guard: int = 60
	while encounter.is_running() and guard > 0:
		guard -= 1
		var entry: NicknameEntry = encounter.get_nickname_entry()
		if entry != null and entry.is_open():
			if not nickname.is_empty():
				entry.type_text(nickname)
			entry.activate_selected()
		elif box.is_important():
			box.finish_typing()
			box.confirm()
			box.advance(LONG_STEP_S)
		await wait_process_frames(1)


# --- Datos del 1-1 ---

func test_level_data_starts_without_pulse_and_has_one_encounter() -> void:
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	assert_false(bool(level["abilities_available"]["pulse"]), "El 1-1 empieza sin pulso")
	var encounters: Array = (level["objects"] as Array).filter(
			func(o: Dictionary) -> bool: return o["type"] == "eco_encounter")
	assert_eq(encounters.size(), 1)
	var enc: Dictionary = encounters[0]
	assert_eq([int(enc["x"]), int(enc["y"])], [10, 0], "Columnas 10-12, toda la altura")
	assert_eq(int(enc["params"]["width_tiles"]), 3)
	assert_eq(int(enc["params"]["height_tiles"]), 10)
	# Nada antes del encuentro exige el pulso (receptores, pop-ups, Burbujas, terminal).
	for obj: Dictionary in level["objects"]:
		if obj["type"] in ["receiver", "popup_blocker", "bridge_inactive", "exit_terminal"]:
			assert_gt(int(obj["x"]), 12, "%s tras el encuentro" % obj["type"])
	for enemy: Dictionary in level["enemies"]:
		assert_gt(int(enemy["x"]), 12, "%s tras el encuentro" % enemy["id"])


func test_texts_and_notice_format() -> void:
	assert_eq(String(_data["intro"][0]), "Bienvenido. He optimizado tu espacio.")
	assert_true(String(_data["gift"][0]).contains(GameState.NICKNAME_TAG), "Eco llama al jugador por el apodo")
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	add_child(_level)
	assert_eq(_encounter(_level).get_notice_text(), "Pulso: G / X (mando)", "Control leido del Input Map")


# --- Secuencia ---

func test_fresh_level_has_no_pulse_and_eco_floats_ahead() -> void:
	await _load_level()
	var encounter: EcoEncounter = _encounter(_level)
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Sin pulso antes del encuentro")
	assert_false(GameState.has_met_ally(GameState.ALLY_ECO))
	assert_eq(encounter.get_step(), EcoEncounter.Step.WAITING)
	assert_true(encounter.is_eco_visible(), "Eco flota en el encuentro")
	assert_almost_eq(encounter.get_eco_sprite().global_position.x, 12.5 * T, 1.0, "En la columna 12")
	assert_almost_eq(encounter.get_eco_sprite().global_position.y, 7.5 * T, 5.0, "Fila 7 (con su oscilacion)")
	assert_eq(_lines.size(), 0)
	assert_false(get_tree().paused)


func test_sequence_intro_nickname_gift_pulse_outro() -> void:
	await _load_level()
	var encounter: EcoEncounter = _encounter(_level)
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	var isak := _level.get_node(^"Isak") as Isak
	watch_signals(encounter)
	await _walk_in(isak)
	# 1. Presentacion: pausa y lineas importantes.
	assert_eq(encounter.get_step(), EcoEncounter.Step.INTRO)
	assert_true(get_tree().paused, "Momento de historia: pausa")
	assert_eq(box.get_text(), String(_data["intro"][0]))
	assert_true(box.is_important())
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Aun sin pulso")
	for i: int in (_data["intro"] as Array).size():
		await _close_line(box)
	# 2. Apodo.
	assert_eq(encounter.get_step(), EcoEncounter.Step.NICKNAME)
	var entry: NicknameEntry = encounter.get_nickname_entry()
	assert_not_null(entry, "Entrada del apodo abierta")
	assert_eq(entry.get_text(), "Isak", "Por defecto, el actual")
	assert_true(get_tree().paused, "Sigue en pausa con la entrada abierta")
	entry.type_text("Nova")
	entry.activate_selected()
	await wait_process_frames(2)
	assert_eq(GameState.get_nickname(), "Nova")
	assert_true(GameState.has_unsaved_changes(), "El apodo nuevo marca «sin guardar»")
	# 3. Regalo con el apodo.
	assert_eq(encounter.get_step(), EcoEncounter.Step.GIFT)
	assert_true(get_tree().paused)
	assert_eq(box.get_text(), String(_data["gift"][0]).replace("{apodo}", "Nova"), "Eco llama a Isak por el apodo")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "El pulso llega al cerrar el regalo")
	await _close_line(box)
	# 4. Pulso y su aviso de control.
	assert_eq(encounter.get_step(), EcoEncounter.Step.OUTRO)
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Eco da el pulso")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_PULSE), "Obtenido para siempre (se guarda)")
	assert_true(GameState.is_notice_seen(GameState.ABILITY_PULSE))
	assert_signal_emitted_with_parameters(encounter, "ability_granted", [GameState.ABILITY_PULSE])
	assert_eq(box.get_text(), "Pulso: G / X (mando)", "Aviso de control del pulso")
	assert_true(box.is_important())
	assert_false(GameState.has_met_ally(GameState.ALLY_ECO), "Eco queda conocido al terminar")
	await _close_line(box)
	assert_eq(box.get_text(), String(_data["outro"][0]))
	await _close_line(box)
	# 5. Fin: Eco conocido, sin pausa, sin esfera flotante.
	assert_eq(encounter.get_step(), EcoEncounter.Step.DONE)
	assert_true(GameState.has_met_ally(GameState.ALLY_ECO))
	assert_false(get_tree().paused, "Se reanuda al cerrar la ultima linea")
	assert_false(encounter.is_eco_visible(), "La esfera pasa a ser el companero")
	assert_signal_emit_count(encounter, "started", 1)
	assert_signal_emit_count(encounter, "finished", 1)
	var expected: Array[String] = []
	expected.append_array(_data["intro"])
	expected.append(String(_data["gift"][0]))  # Se pide con el marcador; el cuadro pone el apodo.
	expected.append("Pulso: G / X (mando)")
	expected.append_array(_data["outro"])
	assert_eq(_lines, expected, "Orden: presentacion, regalo, aviso del pulso, ultima linea")
	assert_false(_important.has(false), "Todas importantes")
	# Una sola vez: salir y volver a entrar no lo repite.
	isak.global_position = Vector2(5.5 * T, 10.0 * T)
	await wait_physics_frames(3)
	await _walk_in(isak)
	assert_signal_emit_count(encounter, "started", 1)
	assert_eq(_lines.size(), expected.size())
	assert_false(get_tree().paused)


func test_keeping_the_default_nickname() -> void:
	await _load_level()
	var encounter: EcoEncounter = _encounter(_level)
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	await _walk_in(_level.get_node(^"Isak") as Isak)
	await _drive(encounter, box)
	assert_true(encounter.is_done())
	assert_eq(GameState.get_nickname(), "Isak")
	assert_true(_lines.has(String(_data["gift"][0])))
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE))


func test_main_scene_companion_appears_and_no_duplicate_pulse_notice() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	var notices: AbilityNotices = _main.get_ability_notices()
	notices.auto_advance = false
	await wait_physics_frames(5)
	_main.advance(LONG_STEP_S)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	var guard: int = 600
	while vortex != null and not vortex.is_done() and guard > 0:
		vortex.advance(1.0 / 60.0)
		guard -= 1
	notices.advance(10.0)
	assert_true(notices.is_armed())
	var companion: EcoCompanion = _main.get_eco_companion()
	companion.auto_advance = false
	companion.advance(1.0)
	assert_false(companion.is_shown(), "Sin Eco conocido no hay companero")
	var level: GeneratedLevel = _main.get_level()
	var encounter: EcoEncounter = _encounter(level)
	var from: Vector2 = encounter.get_eco_sprite().global_position
	await _walk_in(_main.get_isak())
	assert_true(encounter.is_running())
	await _drive(encounter, level.get_node(^"EcoTextBox") as EcoTextBox)
	assert_true(encounter.is_done())
	assert_true(companion.is_shown(), "Eco pasa a ser el companero")
	assert_eq(companion.get_state(), EcoCompanion.State.FOLLOW, "Sin destello: vuela desde donde flotaba")
	assert_lt(companion.get_anchor().distance_to(from), 2.0 * float(_data["bob_px"]) + 1.0,
			"Empieza en la esfera del encuentro (salvo la oscilacion)")
	companion.advance(1.5)
	assert_lt(companion.get_anchor().distance_to(companion.get_target_position()), 8.0, "Y llega junto a Isak")
	assert_eq(_lines.count("Pulso: G / X (mando)"), 1, "El aviso del pulso sale una vez")
	assert_false(get_tree().paused)


func test_restart_mid_encounter_releases_the_pause() -> void:
	await _load_level()
	await _walk_in(_level.get_node(^"Isak") as Isak)
	assert_true(get_tree().paused)
	_level.free()
	_level = null
	assert_false(get_tree().paused, "Quitar el nivel libera la pausa")
	assert_false(GameState.has_met_ally(GameState.ALLY_ECO), "A medias no cuenta")


func test_without_pause_switch_lines_close_alone() -> void:
	EcoTextBox.pause_important = false
	await _load_level()
	var encounter: EcoEncounter = _encounter(_level)
	await _walk_in(_level.get_node(^"Isak") as Isak)
	assert_true(encounter.is_running())
	assert_false(get_tree().paused, "Con el interruptor de pruebas el encuentro no pausa")
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	for i: int in 10:
		box.advance(LONG_STEP_S)
		await wait_process_frames(1)
	assert_eq(encounter.get_step(), EcoEncounter.Step.NICKNAME, "Las lineas se cierran solas hasta el apodo")
	assert_true(get_tree().paused, "La entrada del apodo si pausa")
	encounter.get_nickname_entry().activate_selected()
	for i: int in 10:
		box.advance(LONG_STEP_S)
		await wait_process_frames(1)
	assert_true(encounter.is_done())
	assert_false(get_tree().paused)


# --- No se repite ---

func test_known_eco_skips_the_encounter() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.obtain_ability(GameState.ABILITY_PULSE)
	await _load_level()
	var encounter: EcoEncounter = _encounter(_level)
	assert_true(encounter.is_done())
	assert_false(encounter.is_eco_visible(), "Sin esfera flotante")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Pulso obtenido: disponible desde el inicio")
	await _walk_in(_level.get_node(^"Isak") as Isak)
	assert_eq(_lines.size(), 0, "La zona no hace nada")
	assert_false(get_tree().paused)


func test_migrated_save_with_1_1_completed_keeps_pulse_and_eco() -> void:
	assert_true(SaveFile.write(PATH, {"version": 2, "attention_points": 4, "completed_levels": ["1-1"],
		"unlocked_levels": ["1-1", "1-2"], "abilities_obtained": ["laser"]}))
	assert_true(GameState.load_game())
	assert_true(GameState.has_met_ally(GameState.ALLY_ECO))
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_PULSE), "El pulso se conserva")
	assert_true(GameState.is_notice_seen(GameState.ABILITY_PULSE), "Su aviso ya se vio")
	await _load_level()
	assert_true(_encounter(_level).is_done(), "El encuentro no se repite")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE))


func test_v3_save_with_eco_but_no_pulse_gets_the_pulse() -> void:
	# Guardado v3 de antes del encuentro (el 1-1 daba el pulso al empezar y Eco se conocia al hablar).
	assert_true(SaveFile.write(PATH, {"version": 3, "allies_met": ["eco", "notas"], "completed_levels": ["1-1"]}))
	assert_true(GameState.load_game())
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_PULSE))
	assert_true(GameState.save_game())
	assert_true((SaveFile.read(PATH)["abilities_obtained"] as Array).has("pulse"), "Y se guarda")


func test_new_save_has_no_pulse_and_encounter_saves_it() -> void:
	assert_false(GameState.is_ability_obtained(GameState.ABILITY_PULSE))
	await _load_level()
	await _walk_in(_level.get_node(^"Isak") as Isak)
	await _drive(_encounter(_level), _level.get_node(^"EcoTextBox") as EcoTextBox, "Nova")
	assert_true(GameState.save_game())
	var data: Dictionary = SaveFile.read(PATH)
	assert_true((data["abilities_obtained"] as Array).has("pulse"))
	assert_true((data["allies_met"] as Array).has("eco"))
	assert_eq(data["nickname"], "Nova")


# --- Conversion de las lineas del 1-1 (§4.1) ---

func test_converted_lines_are_gone_and_story_remains() -> void:
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	var ids: Array[String] = []
	for obj: Dictionary in level["objects"]:
		if obj["type"] == "eco_line":
			ids.append(String(obj["params"]["id"]))
			assert_true(bool(obj["params"].get("important", false)), "Solo quedan momentos de historia (pausa)")
	for id: String in MOVED_TO_HELP:
		assert_false(ids.has(id), "%s paso a la ayuda con Q" % id)
	for id: String in REMOVED:
		assert_false(ids.has(id), "%s se elimino" % id)
	assert_eq(ids, ["eco_laser"] as Array[String], "Historia: la obtencion del laser")


func test_help_covers_the_moved_lines() -> void:
	var catalog: HelpCatalog = HelpCatalog.shared()
	for id: String in MOVED_TO_HELP:
		assert_true(catalog.has(StringName(MOVED_TO_HELP[id])), "%s -> %s" % [id, MOVED_TO_HELP[id]])
		assert_false(catalog.text(StringName(MOVED_TO_HELP[id])).is_empty())
	# Mismo texto que la linea (§4.1).
	assert_eq(catalog.text(&"attention_point"), "Cada punto de atención cuenta. Yo también los cuento.")
	assert_eq(catalog.text(&"power_bank_pickup"), "Batería externa detectada. Guárdala, quizá te ahorre tiempo.")
	assert_eq(catalog.text(&"popup_blocker"),
			"Un aviso importante. El botón de cerrar es pequeño, por tu bien. Pulso de cerca.")
	assert_eq(catalog.text(&"glitch_wall"), "Eso es un error de visualización. Ignóralo, por favor.")
	assert_eq(catalog.text(&"exit_terminal"), "Marca todo como leído. Lanza un pulso al monitor y te llevo fuera.")
	# El punto de sincronizacion no dice que guarde (no se guarda en los niveles).
	var sync: String = catalog.text(&"sync_point")
	assert_true(sync.begins_with("Punto de sincronización. Si caes, vuelves aquí."), sync)
	assert_false(sync.to_lower().contains("guard"), sync)
	assert_false(sync.to_lower().contains("progreso"), sync)
