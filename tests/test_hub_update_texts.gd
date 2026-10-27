# Textos y pistas del acertijo «Actualizacion del sistema» (2026-10-27, paso 6
# de docs/propuesta-hub-mundos-4-6.md §1, §2.4 y §2.6; seccion hub_update_hints
# de data/hub.json): comentario de Calc al volver de 3-boss, linea de Eco al
# entrar por primera vez en la pagina 2, pista de Eco a los 90 s, la tecla tras
# 2 fallos, «Actualización: n/3» en Notas, la pantalla del instalador y el
# recordatorio de Notas al instalar. Cada linea sale una vez por partida
# guardada (seen_notices) y con «Ayudas de Eco: Ocultar» no salen las pistas 3 y 4.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_hub_update_texts.json"
const T: float = 64.0
const X0: float = 1280.0
const FLOOR_Y: float = 576.0
const UPGRADE: StringName = &"hub_update_4_6"
const ALL: Array[StringName] = [&"pulse", &"laser", &"debug", &"dash", &"ground_pound", &"compress"]

var _hub: HubRoom
var _puzzle: HubUpdatePuzzle
var _isak: Isak
var _input: PlayerInput
var _saved_path: String
var _saved: Dictionary = {}
var _saved_help: bool = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved = {}
	for ability: StringName in ALL:
		_saved[ability] = GameState.is_ability_unlocked(ability)
	_saved_help = GameSettings.is_eco_help_shown()
	GameSettings.set_eco_help_shown(true)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	_puzzle = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameSettings.set_eco_help_shown(_saved_help)
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	for ability: StringName in _saved:
		GameState.set_ability_unlocked(ability, _saved[ability])


# --- Utilidades ---

func _hints() -> Dictionary:
	return HubData.section("hub_update_hints")


func _obtain() -> void:
	for ability: StringName in ALL:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)


func _spawn(from_level: String = "") -> HubRoom:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = HUB_SCENE.instantiate() as HubRoom
	_hub.arrived_from_level = from_level
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_puzzle = _hub.get_update_puzzle()
	_isak = _hub.get_isak()
	_input = PlayerInput.new()
	_isak.input = _input
	return _hub


## Tras vencer a La Curadora, con todo obtenido (acertijo pendiente).
func _setup(from_level: String = "") -> void:
	_obtain()
	GameState.mark_level_completed(&"3-boss")
	_spawn(from_level)


func _box() -> EcoTextBox:
	return _hub.get_text_box()


func _close_line() -> void:
	var box: EcoTextBox = _box()
	box.finish_typing()
	box.confirm()
	box.advance(10.0)
	await get_tree().process_frame
	await get_tree().process_frame


## Isak a la pagina `page` (columna local `col`), con el deslizamiento terminado.
func _go_to_page(page: int, col: float = 5.0) -> void:
	_isak.global_position = Vector2(float(page - 1) * X0 + col * T, FLOOR_Y)
	_isak.velocity = Vector2.ZERO
	await wait_physics_frames(3)
	_hub.finish_page_slide()
	await get_tree().process_frame


func _intro_text() -> String:
	return String((_hints().get("intro", {}).get("lines", [""]) as Array)[0]).replace("{apodo}", GameState.get_nickname())


# --- Comentario de Calc ---

func test_calc_remark_after_the_curator_once_per_save() -> void:
	EcoProgress.meet_calc()
	_setup("3-boss")
	await get_tree().process_frame
	assert_true(GameState.is_notice_seen(&"calc_remark_update_3_boss"), "Calc lo comenta al volver de la Curadora")
	assert_eq(_box().get_speaker_id(), &"calc")
	assert_string_contains(_box().get_text(), "Actualización detectada")
	assert_false(_box().is_important(), "No importante: no pausa")
	_spawn("3-boss")
	assert_true(_hub.pending_calc_remark().is_empty(), "Una vez por partida guardada")


func test_calc_remark_needs_the_puzzle_pending() -> void:
	EcoProgress.meet_calc()
	_obtain()
	GameState.mark_level_completed(&"3-boss")
	GameState.install_hub_upgrade(UPGRADE)
	_spawn("3-boss")
	assert_true(_hub.pending_calc_remark().is_empty(), "Con el upgrade instalado no hay «Actualización detectada»")
	assert_false(GameState.is_notice_seen(&"calc_remark_update_3_boss"))


# --- Linea de Eco al entrar en la pagina 2 ---

func test_eco_intro_on_first_entry_to_page_two_once_per_save() -> void:
	_setup()
	assert_false(_box().is_showing(), "En la pagina 1 Eco no dice nada")
	await _go_to_page(2)
	assert_eq(_hub.get_current_page(), 2)
	assert_true(_box().is_showing(), "Eco habla al entrar en la pagina 2")
	assert_eq(_box().get_text(), _intro_text(), "Con el apodo")
	assert_true(_box().is_important(), "Importante: pausa")
	assert_true(get_tree().paused)
	assert_true(GameState.is_notice_seen(&"hub_update_intro"))
	await _close_line()
	assert_false(get_tree().paused, "Al cerrarla vuelve el control")
	await _go_to_page(1)
	await _go_to_page(2)
	assert_false(_box().is_showing(), "No se repite en la misma visita")
	_spawn()
	await _go_to_page(2)
	assert_false(_box().is_showing(), "Ni en la siguiente visita")


func test_eco_intro_is_story_and_shows_with_help_hidden() -> void:
	GameSettings.set_eco_help_shown(false)
	_setup()
	await _go_to_page(2)
	assert_true(_box().is_showing(), "Historia: sale con las ayudas ocultas")
	await _close_line()


func test_seen_lines_survive_a_save_and_a_load() -> void:
	_setup()
	await _go_to_page(2)
	await _close_line()
	assert_true(GameState.save_game())
	GameState.seen_notices.erase(&"hub_update_intro")
	assert_true(GameState.load_game())
	assert_true(GameState.is_notice_seen(&"hub_update_intro"), "Visto en la partida guardada")


# --- Pista 3: Eco a los 90 s ---

func test_eco_hint_after_ninety_seconds_on_page_two_once_per_save() -> void:
	GameState.mark_notice_seen(&"hub_update_intro")
	_setup()
	var after: float = float(_hints().get("eco_hint", {}).get("after_s", 0.0))
	assert_eq(after, 90.0)
	_puzzle.advance_hints(after + 1.0)
	assert_false(_box().is_showing(), "En la pagina 1 no cuenta")
	assert_eq(_puzzle.get_idle_seconds(), 0.0)
	await _go_to_page(2)
	_puzzle.advance_hints(after - 1.0)
	assert_false(_box().is_showing(), "Antes de los 90 s, nada")
	_puzzle.advance_hints(1.5)
	assert_true(_box().is_showing(), "A los 90 s, Eco da la pista")
	assert_string_contains(_box().get_text(), "Cada color es un sitio")
	assert_false(_box().is_important(), "No importante")
	assert_true(GameState.is_notice_seen(&"hub_update_hint_eco"))
	_spawn()
	await _go_to_page(2)
	_puzzle.advance_hints(after + 1.0)
	assert_false(_box().is_showing(), "Una vez por partida guardada")


func test_eco_hint_timer_restarts_with_each_new_check() -> void:
	GameState.mark_notice_seen(&"hub_update_intro")
	_setup()
	await _go_to_page(2)
	_puzzle.advance_hints(60.0)
	_puzzle.get_check(&"v2").complete()
	assert_eq(_puzzle.get_idle_seconds(), 0.0, "Una verificacion nueva reinicia la cuenta")
	_puzzle.advance_hints(60.0)
	assert_false(_box().is_showing())
	_puzzle.advance_hints(31.0)
	assert_true(_box().is_showing(), "90 s desde la ultima verificacion")


func test_eco_hint_not_shown_with_help_hidden() -> void:
	GameState.mark_notice_seen(&"hub_update_intro")
	GameSettings.set_eco_help_shown(false)
	_setup()
	await _go_to_page(2)
	_puzzle.advance_hints(200.0)
	assert_false(_box().is_showing(), "Con las ayudas ocultas no sale la pista 3")
	assert_false(GameState.is_notice_seen(&"hub_update_hint_eco"), "Ni se da por vista")


# --- Pista 4: la tecla tras 2 fallos ---

func test_key_hint_after_two_failures() -> void:
	GameState.mark_notice_seen(&"hub_update_intro")
	_setup()
	await _go_to_page(2)
	var reader: LaserReceiver = _puzzle.get_reader1()
	reader.power()
	reader.advance(reader.window_s + 0.1)
	assert_eq(_puzzle.get_failure_count(&"v1"), 1, "Se acaba la corriente de lector1: un fallo")
	_puzzle.advance_hints(0.1)
	assert_false(_puzzle.is_key_hint_visible(&"v1"), "Con un fallo, nada")
	reader.power()
	reader.advance(reader.window_s + 0.1)
	_puzzle.advance_hints(0.1)
	assert_true(_puzzle.is_key_hint_visible(&"v1"), "Con dos, la tecla")
	assert_eq(_puzzle.get_key_hint_text(&"v1"), PulsePrompt.key_text(&"pulse", "?"), "Tecla del pulso (Input Map)")
	_puzzle.get_check(&"v1").complete()
	assert_false(_puzzle.is_key_hint_visible(&"v1"), "Hecha, se quita")
	# V2: baja la plataforma sin llegar.
	var plate: PoundPlate = _puzzle.get_plate()
	for i: int in 2:
		plate.press()
		plate.advance(plate.up_s + 0.1)
	assert_eq(_puzzle.get_failure_count(&"v2"), 2)
	_puzzle.advance_hints(0.1)
	assert_true(_puzzle.is_key_hint_visible(&"v2"))
	assert_eq(_puzzle.get_key_hint_text(&"v2"), PulsePrompt.key_text(&"gesture_swipe", "?"), "Tecla de Deslizar")
	# V3: laser con el marco cerrado; Pellizcar con el marco abierto.
	_puzzle.register_failure(&"v3")
	_puzzle.register_failure(&"v3")
	_puzzle.advance_hints(0.1)
	assert_true(_puzzle.is_key_hint_visible(&"v3"))
	assert_eq(_puzzle.get_key_hint_text(&"v3"), PulsePrompt.key_text(&"laser", "?"), "Marco cerrado: laser")
	_puzzle.get_reader3().power()
	assert_true(_puzzle.is_frame_lit())
	_puzzle.advance_hints(0.1)
	assert_eq(_puzzle.get_key_hint_text(&"v3"), PulsePrompt.key_text(&"gesture_pinch", "?"), "Marco abierto: Pellizcar")


func test_bumping_the_frame_uncompressed_counts_as_a_failure() -> void:
	GameState.mark_notice_seen(&"hub_update_intro")
	_setup()
	var frame_x: float = X0 + 17.0 * T
	for i: int in 2:
		await _go_to_page(2, 14.0)
		_input.move_axis = 1.0
		for f: int in 120:
			await wait_physics_frames(1)
			if _puzzle.get_failure_count(&"v3") > i:
				break
		_input.move_axis = 0.0
		assert_lt(_isak.global_position.x, frame_x, "El marco lo para")
	assert_eq(_puzzle.get_failure_count(&"v3"), 2, "Dos choques, dos fallos")
	await wait_physics_frames(2)
	assert_true(_puzzle.is_key_hint_visible(&"v3"))


func test_key_hint_not_shown_with_help_hidden_and_failures_reset_each_visit() -> void:
	GameState.mark_notice_seen(&"hub_update_intro")
	GameSettings.set_eco_help_shown(false)
	_setup()
	await _go_to_page(2)
	_puzzle.register_failure(&"v1")
	_puzzle.register_failure(&"v1")
	_puzzle.advance_hints(0.1)
	assert_false(_puzzle.is_key_hint_visible(&"v1"), "Con las ayudas ocultas no sale la pista 4")
	GameSettings.set_eco_help_shown(true)
	_puzzle.advance_hints(0.1)
	assert_true(_puzzle.is_key_hint_visible(&"v1"), "Al mostrarlas, sale")
	_spawn()
	assert_eq(_puzzle.get_failure_count(&"v1"), 0, "Los fallos son de la visita")


# --- Pista 2 y pantalla del instalador ---

func test_notas_progress_line_and_installer_screen() -> void:
	GameState.mark_notice_seen(&"hub_update_intro")
	GameSettings.set_eco_help_shown(false)
	_setup()
	assert_eq(_puzzle.get_progress_line(), "Actualización: 0/3 · Falta: Integridad, Búfer, Recorte")
	var notas: NotasStation = _hub.get_notas()
	notas.open(_isak)
	await get_tree().process_frame
	var panel: NotasPanel = notas.get_notas_panel()
	assert_eq(panel.update_progress_text(), _puzzle.get_progress_line(), "Notas lo apunta (tambien con las ayudas ocultas)")
	notas.close(true)
	_puzzle.get_check(&"v1").complete()
	assert_eq(_puzzle.get_progress_line(), "Actualización: 1/3 · Falta: Búfer, Recorte")
	for id: StringName in [&"v2", &"v3"]:
		_puzzle.get_check(id).complete()
	assert_eq(_puzzle.get_progress_line(), "Actualización: 3/3")
	var installer: HubInstaller = _puzzle.get_installer()
	assert_eq(installer.get_plate_text(), "Verificaciones 3/3")
	_hub.apply_update_install(UPGRADE)
	await get_tree().process_frame
	notas.open(_isak)
	await get_tree().process_frame
	assert_eq(notas.get_notas_panel().update_progress_text(), "", "Instalado: sin linea")
	notas.close(true)


func test_no_progress_line_before_the_curator() -> void:
	_spawn()
	assert_null(_hub.get_update_puzzle())
	var notas: NotasStation = _hub.get_notas()
	notas.open(_isak)
	await get_tree().process_frame
	assert_eq(notas.get_notas_panel().update_progress_text(), "")
	notas.close(true)


# --- Recordatorio de Notas al instalar ---

func test_saved_reminder_after_install_once_per_save() -> void:
	GameState.mark_notice_seen(&"hub_update_intro")
	_setup()
	await _go_to_page(2, 8.0)
	for id: StringName in _puzzle.get_check_ids():
		_puzzle.get_check(id).complete()
	_puzzle.install_requested.emit(UPGRADE)
	var install: HubUpdateInstall = _hub.get_update_install()
	assert_not_null(install)
	install.advance(install.get_bar_s() + 0.01)
	install.advance(install.get_flash_s() + 0.01)
	assert_true(_box().is_important(), "La linea importante de Notas")
	await _close_line()
	await get_tree().process_frame
	assert_true(install.is_done())
	assert_true(GameState.is_notice_seen(&"hub_update_saved_reminder"))
	var reminder: String = String(_hints().get("saved_reminder", {}).get("text", ""))
	var shown: bool = _box().get_text() == reminder or _box().get_queued_texts().has(reminder)
	assert_true(shown, "Notas recuerda guardar")
	assert_eq(_box().get_speaker_id(), &"notas")
	assert_false(_box().is_important(), "No importante")
	assert_false(get_tree().paused)
	assert_false(install.show_saved_reminder(), "Una vez por partida guardada")


# --- Datos ---

func test_texts_are_marked_proposed_and_use_the_approved_names() -> void:
	var notes: String = String(_hints().get("_notes", ""))
	assert_string_contains(notes, "PROPUESTOS")
	var data: Dictionary = HubUpdatePuzzle.load_data()
	var names: Array[String] = []
	for entry: Variant in data.get("checks", []):
		names.append(String((entry as Dictionary).get("name", "")))
	assert_eq(names, ["Integridad", "Búfer", "Recorte"])
	assert_eq(String(data.get("texts", {}).get("title", "")), "Actualización del sistema")
	assert_false(String(data.get("texts", {}).get("ready", "")).contains("provisional"))
