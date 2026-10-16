# Ajustes del jugador (GameSettings; 2026-10-16, paso 13 de
# docs/propuesta-asistentes-y-vidas.md y pregunta 6 de
# docs/propuesta-hub-y-guardado.md): se guardan al instante en su ConfigFile,
# aparte del guardado de la partida (no marcan «sin guardar» ni tocan
# save.json); GUT usa user://test_settings.cfg (nunca user://settings.cfg) y
# ISAK_SETTINGS_PATH cambia la ruta; se cargan al reiniciar. «Ayudas de Eco:
# Ocultar» quita todas las Q (y por tanto no se aprende nada sin pedirlo) sin
# olvidar lo aprendido; «Mostrar» las devuelve.
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const ECO_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const SAVE_PATH: String = "user://test_game_settings_save.json"
const ALT_PATH: String = "user://test_game_settings_alt.cfg"
const TILE: float = 64.0
const ISAK_FEET: Vector2 = Vector2(640.0, 400.0)

var _saved_path: String
var _settings_path: String
var _root: Node2D
var _help: HelpSystem


func before_each() -> void:
	_saved_path = GameState.save_path
	_settings_path = GameSettings.settings_path()
	GameState.use_save_path(SAVE_PATH, true)
	GameSettings.use_path(_settings_path, true)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null
	get_tree().paused = false
	GameState.reset_progress()
	SaveFile.delete(SAVE_PATH)
	GameState.save_path = _saved_path
	if FileAccess.file_exists(ALT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ALT_PATH))
	GameSettings.use_path(_settings_path, true)


func _value_on_disk(path: String) -> Variant:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return null
	return config.get_value(GameSettings.SECTION_HELP, String(GameSettings.KEY_SHOW_ECO_HELP), null)


func test_tests_use_their_own_settings_file() -> void:
	assert_eq(GameSettings.settings_path(), GameSettings.PATH_TESTS, "GUT: user://test_settings.cfg")
	assert_ne(GameSettings.settings_path(), GameSettings.PATH_DEFAULT)
	assert_eq(GameSettings.resolve_path(PackedStringArray(), ""), GameSettings.PATH_DEFAULT, "El juego normal")
	assert_eq(GameSettings.resolve_path(PackedStringArray(["-s", "addons/gut/gut_cmdln.gd"]), ""),
		GameSettings.PATH_TESTS)
	assert_eq(GameSettings.resolve_path(PackedStringArray(["-s", "res://tools/play_level_bot.gd"]), ""),
		GameSettings.PATH_TOOLS, "Bots y capturas")
	assert_eq(GameSettings.resolve_path(PackedStringArray(), "user://x.cfg"), "user://x.cfg", "ISAK_SETTINGS_PATH")
	assert_eq(GameSettings.PATH_ENV, "ISAK_SETTINGS_PATH")


func test_eco_help_defaults_to_shown() -> void:
	assert_true(GameSettings.is_eco_help_shown(), "Por defecto, Mostrar")
	assert_false(FileAccess.file_exists(GameSettings.settings_path()), "Sin cambios no hay archivo")


func test_change_is_saved_at_once_and_loaded_on_restart() -> void:
	var changes: Array = []
	var on_change := func(key: StringName, value: Variant) -> void: changes.append([key, value])
	EventBus.settings_changed.connect(on_change)
	assert_true(GameSettings.set_eco_help_shown(false))
	EventBus.settings_changed.disconnect(on_change)
	assert_eq(changes, [[GameSettings.KEY_SHOW_ECO_HELP, false]])
	assert_eq(_value_on_disk(GameSettings.settings_path()), false, "Guardado al instante")
	assert_false(GameSettings.set_eco_help_shown(false), "Sin cambio no hace nada")
	GameSettings.reset_defaults()
	assert_true(GameSettings.is_eco_help_shown())
	GameSettings.load_from_disk()
	assert_false(GameSettings.is_eco_help_shown(), "Al reiniciar se carga del disco")
	GameSettings.set_eco_help_shown(true)
	GameSettings.load_from_disk()
	assert_true(GameSettings.is_eco_help_shown())


func test_other_path_like_isak_settings_path() -> void:
	GameSettings.use_path(ALT_PATH, true)
	GameSettings.set_eco_help_shown(false)
	assert_eq(_value_on_disk(ALT_PATH), false)
	GameSettings.use_path(_settings_path, true)
	assert_true(GameSettings.is_eco_help_shown(), "Cada ruta, sus ajustes")


func test_settings_are_not_progress() -> void:
	GameState.attention_points = 7
	GameState.save_game()
	var before: String = FileAccess.get_file_as_string(SAVE_PATH)
	GameSettings.set_eco_help_shown(false)
	assert_false(GameState.has_unsaved_changes(), "No marca «sin guardar»")
	assert_eq(FileAccess.get_file_as_string(SAVE_PATH), before, "No toca save.json")
	assert_false(before.contains(String(GameSettings.KEY_SHOW_ECO_HELP)), "No va en el guardado")
	GameState.save_game()
	assert_false(FileAccess.get_file_as_string(SAVE_PATH).contains(String(GameSettings.KEY_SHOW_ECO_HELP)))
	GameState.load_game()
	assert_false(GameSettings.is_eco_help_shown(), "Cargar la partida no cambia los ajustes")


# --- Ayudas de Eco: Mostrar / Ocultar ---

func _build_level() -> Node2D:
	_root = Node2D.new()
	_root.name = "SettingsHelpLevel"
	var isak := ISAK_SCENE.instantiate() as Isak
	isak.name = "Isak"
	isak.position = ISAK_FEET
	_root.add_child(isak)
	var box := ECO_SCENE.instantiate() as EcoTextBox
	box.name = "EcoTextBox"
	_root.add_child(box)
	_help = HelpSystem.new()
	_help.name = "Help"
	_root.add_child(_help)
	add_child(_root)
	var target := Node2D.new()
	target.name = "Receiver"
	var center: Vector2 = ISAK_FEET + Vector2(0.0, HelpCatalog.shared().isak_center_y()) + Vector2(TILE, 0.0)
	target.position = center - HelpCatalog.shared().center_offset(&"receiver")
	HelpCatalog.tag(target, &"receiver")
	_root.add_child(target)
	return target


func test_hidden_help_shows_no_q_and_shown_brings_it_back() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	var target: Node2D = _build_level()
	await wait_process_frames(2)
	_help.refresh()
	assert_true(_help.is_prompt_visible(), "Mostrar: hay Q")
	assert_eq(_help.get_target(), target)
	GameSettings.set_eco_help_shown(false)
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "Ocultar: ninguna Q")
	assert_null(_help.find_target())
	assert_false(_help.request_help(), "Sin Q, help no hace nada")
	assert_false(GameState.is_help_learned(&"receiver"), "No se aprende sin pedirlo")
	GameSettings.set_eco_help_shown(true)
	_help.refresh()
	assert_true(_help.is_prompt_visible(), "Mostrar otra vez: vuelve la Q")


func test_hiding_keeps_what_was_learned() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.learn_help(&"receiver")
	GameSettings.set_eco_help_shown(false)
	assert_true(GameState.is_help_learned(&"receiver"), "El album conserva lo aprendido")
	GameSettings.set_eco_help_shown(true)
	assert_true(GameState.is_help_learned(&"receiver"))


# --- Accesibilidad: Sync bajo y contorno del Debug (2026-10-16) ---

func test_accessibility_defaults_match_previous_behaviour() -> void:
	assert_false(GameSettings.is_low_sync_reduced(), "Por defecto, efectos completos")
	assert_false(GameSettings.is_debug_outline_high_contrast(), "Por defecto, contorno del Debug")
	assert_false(GameState.reduce_low_sync_effects)
	assert_false(GameState.debug_high_contrast_outline)


func test_accessibility_settings_save_load_and_apply() -> void:
	var reduced: Array = []
	var on_reduce := func(enabled: bool) -> void: reduced.append(enabled)
	EventBus.reduce_low_sync_effects_changed.connect(on_reduce)
	assert_true(GameSettings.set_low_sync_reduced(true))
	EventBus.reduce_low_sync_effects_changed.disconnect(on_reduce)
	assert_eq(reduced, [true], "El HUD recibe el cambio al momento")
	assert_true(GameSettings.set_debug_outline_high_contrast(true))
	assert_true(GameState.debug_high_contrast_outline, "Las plataformas ocultas, al momento")
	GameSettings.reset_defaults()
	assert_false(GameState.reduce_low_sync_effects)
	GameSettings.load_from_disk()
	assert_true(GameSettings.is_low_sync_reduced(), "Se cargan del disco")
	assert_true(GameState.reduce_low_sync_effects, "Y se aplican al cargar")
	assert_true(GameState.debug_high_contrast_outline)
	assert_false(GameState.has_unsaved_changes())


func test_old_settings_file_migrates_without_losing_values() -> void:
	# settings.cfg de la version anterior: solo [help].
	var old := ConfigFile.new()
	old.set_value(GameSettings.SECTION_HELP, String(GameSettings.KEY_SHOW_ECO_HELP), false)
	old.save(GameSettings.settings_path())
	GameSettings.load_from_disk()
	assert_false(GameSettings.is_eco_help_shown(), "Conserva lo que habia")
	assert_false(GameSettings.is_low_sync_reduced(), "Lo nuevo, por defecto")
	assert_false(GameSettings.is_debug_outline_high_contrast())
	# Valor que no es booleano: por defecto, sin romper los demas.
	old.set_value(GameSettings.SECTION_ACCESSIBILITY, "reduce_low_sync_effects", "quizas")
	old.save(GameSettings.settings_path())
	GameSettings.load_from_disk()
	assert_false(GameSettings.is_low_sync_reduced())
	assert_false(GameSettings.is_eco_help_shown())
	GameSettings.set_low_sync_reduced(true)
	var config := ConfigFile.new()
	config.load(GameSettings.settings_path())
	assert_eq(config.get_value(GameSettings.SECTION_HELP, String(GameSettings.KEY_SHOW_ECO_HELP)), false,
		"Guardar uno nuevo no pisa los anteriores")


# --- Pantalla: modo y tamano de ventana (2026-10-16) ---

func test_display_defaults_are_the_previous_window() -> void:
	assert_eq(GameSettings.get_window_mode(), GameSettings.WINDOW_MODE_WINDOWED, "Ventana")
	assert_eq(GameSettings.get_window_size(), Vector2i(1280, 720), "1280x720")
	assert_true(GameSettings.is_display_default())
	assert_eq(GameSettings.base_size(), Vector2i(1280, 720), "Resolucion base de project.godot")


func test_window_presets_are_valid() -> void:
	var presets: Array[Vector2i] = GameSettings.window_presets()
	assert_eq(presets[0], GameSettings.base_size(), "La base, la primera")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		assert_true(presets.has(size), "Preset %s" % size)
	for size: Vector2i in presets:
		assert_true(size.x >= 1280 and size.y >= 720, "Nunca menor que la base: %s" % size)
		assert_eq(size.x * 9, size.y * 16, "16:9 como la base: %s" % size)


func test_presets_never_exceed_the_screen() -> void:
	var fits: Array[Vector2i] = GameSettings.available_presets(Vector2i(1920, 1080))
	assert_true(fits.has(Vector2i(1920, 1080)))
	assert_false(fits.has(Vector2i(2560, 1440)), "Uno mayor que el monitor no se ofrece")
	var small: Array[Vector2i] = GameSettings.available_presets(Vector2i(1366, 768))
	assert_eq(small, [Vector2i(1280, 720)] as Array[Vector2i], "En un monitor pequeno, solo la base")
	var tiny: Array[Vector2i] = GameSettings.available_presets(Vector2i(1024, 600))
	assert_eq(tiny, [Vector2i(1280, 720)] as Array[Vector2i], "La base siempre (es la ventana por defecto)")
	assert_eq(GameSettings.available_presets(Vector2i.ZERO), GameSettings.window_presets(),
		"Sin pantalla conocida (headless), todos")


func test_integer_scale_and_letterbox() -> void:
	assert_eq(GameSettings.integer_scale(Vector2i(1280, 720)), 1)
	assert_false(GameSettings.has_letterbox(Vector2i(1280, 720)))
	assert_eq(GameSettings.integer_scale(Vector2i(1600, 900)), 1, "1600x900: x1")
	assert_true(GameSettings.has_letterbox(Vector2i(1600, 900)), "Con bordes")
	assert_eq(GameSettings.integer_scale(Vector2i(1920, 1080)), 1, "1920x1080: x1 (escala entera)")
	assert_true(GameSettings.has_letterbox(Vector2i(1920, 1080)))
	assert_eq(GameSettings.integer_scale(Vector2i(2560, 1440)), 2, "2560x1440: x2")
	assert_false(GameSettings.has_letterbox(Vector2i(2560, 1440)), "Sin bordes")
	assert_eq(GameSettings.integer_scale(Vector2i(2560, 1600)), 2, "Pantalla 16:10: x2")
	assert_true(GameSettings.has_letterbox(Vector2i(2560, 1600)), "Con bordes arriba y abajo")


func test_display_settings_save_load_and_never_touch_the_window_in_tests() -> void:
	var window_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var window_size: Vector2i = DisplayServer.window_get_size()
	assert_false(GameSettings.can_change_window(), "En GUT no se toca la ventana")
	assert_false(GameSettings.apply_display())
	assert_true(GameSettings.set_fullscreen(true))
	assert_true(GameSettings.is_fullscreen())
	assert_true(GameSettings.set_window_size(Vector2i(1600, 900)))
	assert_false(GameSettings.set_window_size(Vector2i(1000, 500)), "Solo presets")
	assert_false(GameSettings.set_window_mode("ventanita"), "Solo modos conocidos")
	assert_eq(DisplayServer.window_get_mode(), window_mode, "La ventana real no cambia")
	assert_eq(DisplayServer.window_get_size(), window_size)
	var config := ConfigFile.new()
	assert_eq(config.load(GameSettings.settings_path()), OK, "Guardado al instante")
	assert_eq(config.get_value(GameSettings.SECTION_DISPLAY, "window_mode"), "fullscreen")
	assert_eq(config.get_value(GameSettings.SECTION_DISPLAY, "window_size"), Vector2i(1600, 900))
	GameSettings.reset_defaults()
	assert_true(GameSettings.is_display_default())
	GameSettings.load_from_disk()
	assert_true(GameSettings.is_fullscreen(), "Se carga al arrancar")
	assert_eq(GameSettings.get_window_size(), Vector2i(1600, 900))
	assert_eq(DisplayServer.window_get_mode(), window_mode, "Cargar tampoco toca la ventana en GUT")
	assert_false(GameState.has_unsaved_changes(), "No es progreso")


func test_bad_display_values_fall_back_to_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value(GameSettings.SECTION_DISPLAY, "window_mode", "maximizada")
	config.set_value(GameSettings.SECTION_DISPLAY, "window_size", Vector2i(123, 45))
	config.set_value(GameSettings.SECTION_HELP, String(GameSettings.KEY_SHOW_ECO_HELP), false)
	config.save(GameSettings.settings_path())
	GameSettings.load_from_disk()
	assert_true(GameSettings.is_display_default(), "Valores desconocidos: ventana de 1280x720 (%s, %s)" % [
		GameSettings.get_window_mode(), GameSettings.get_window_size()])
	assert_false(GameSettings.is_eco_help_shown(), "Sin perder los demas")
