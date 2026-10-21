## Ajustes del jugador (docs/propuesta-hub-y-guardado.md §4.1 y preguntas 6 y 9;
## docs/propuesta-asistentes-y-vidas.md §3.4 y paso 13 de §10). No son progreso:
## - Se guardan AL INSTANTE al cambiarlos, en un ConfigFile aparte
##   (user://settings.cfg), nunca en save.json: no marcan «sin guardar», no los
##   toca el guardado manual de Notas ni un game over (rollback).
## - Ruta: ISAK_SETTINGS_PATH si esta definida; dentro de GUT,
##   user://test_settings.cfg, y con otro script (-s: bots, capturas),
##   user://tool_settings.cfg (estas dos se borran al arrancar, como los
##   guardados de pruebas). Solo el juego normal usa user://settings.cfg.
## - «Ayudas de Eco: Mostrar / Ocultar» (show_eco_help, seccion help, por
##   defecto Mostrar). Oculto, no sale ninguna Q (HelpSystem) y por tanto no se
##   aprende nada sin pedirlo; lo ya aprendido sigue en el album de Notas y los
##   momentos de historia de Eco (encuentro, laser, Debug, game over) salen igual.
## - Accesibilidad (2026-10-16, seccion accessibility; antes solo en memoria):
##   «Efectos de Sync bajo: Normal / Reducidos» (reduce_low_sync_effects: con
##   Sync Rate bajo la senal y el porcentaje del HUD se quedan en rojo sin
##   parpadear) y «Contorno del Debug: Normal / Alto contraste»
##   (debug_high_contrast_outline: las plataformas ocultas del Debug con un
##   contorno mas claro y grueso). Por defecto Normal (false). Se aplican al
##   momento a GameState (que avisa al HUD y a las plataformas) al cargar y al
##   cambiarlos. Migracion: un settings.cfg anterior sin estas claves (o con un
##   valor que no es booleano) usa el valor por defecto sin tocar las demas.
## - Pantalla (2026-10-16, seccion display; datos en data/settings.json):
##   modo de ventana («Ventana» / «Pantalla completa», window_mode) y tamano de
##   la ventana (window_size, uno de window_presets que quepa en el monitor).
##   El juego se dibuja siempre a 1280x720 y se escala por un factor ENTERO
##   (project.godot: stretch viewport, scale_mode integer): si el tamano no es
##   multiplo exacto, queda centrado con bordes negros (letterbox). Por defecto,
##   ventana de 1280x720 (el comportamiento anterior: con los valores por
##   defecto no se toca la ventana al arrancar). Se aplica al cambiarlo y al
##   arrancar (apply_display); NUNCA en GUT, con scripts -s (bots, capturas) ni
##   sin ventana (headless): can_change_window().
## - Controles (2026-10-16, seccion controls): las acciones reasignadas en
##   Ajustes > Controles (ControlBindings) se guardan como eventos serializados
##   (tecla fisica, boton o eje) solo si difieren de project.godot y se aplican
##   al cargar sobre el Input Map. Sin la seccion: los de project.godot.
## - Sonido (2026-10-20, seccion audio; docs/lista-sonidos.md, «Integracion»):
##   volumen de cada bus de default_bus_layout.tres (Master, Music, World,
##   Ambience, Voice, UI) de 0 a 1 en pasos de data/settings.json (audio);
##   se aplica al AudioServer al cargar y al cambiarlo (0 = bus en silencio).
##   «Senales sonoras de ritmo» (rhythm_sound_cues, seccion accessibility, por
##   defecto Si, decision 2026-10-20): el tic del metronomo y el aviso de las
##   plataformas que parpadean (entradas cue de data/audio.json).
## Clase estatica (sin autoload): la carga la primera consulta o GameState al
## arrancar (use_path). Cambios: EventBus.settings_changed(key, value).
class_name GameSettings
extends RefCounted

const PATH_DEFAULT: String = "user://settings.cfg"
## Ruta de las pruebas GUT (nunca los ajustes reales del jugador).
const PATH_TESTS: String = "user://test_settings.cfg"
## Ruta de los scripts de herramientas (-s tools/*.gd).
const PATH_TOOLS: String = "user://tool_settings.cfg"
## Variable de entorno que fuerza otra ruta.
const PATH_ENV: String = "ISAK_SETTINGS_PATH"

const SECTION_HELP: String = "help"
const SECTION_ACCESSIBILITY: String = "accessibility"
const SECTION_DISPLAY: String = "display"
const SECTION_CONTROLS: String = "controls"
const SECTION_AUDIO: String = "audio"
## Buses de audio con volumen ajustable (default_bus_layout.tres).
const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"World", &"Ambience", &"Voice", &"UI"]
const VOLUME_DEFAULT: float = 1.0
const VOLUME_STEP_DEFAULT: float = 0.1
## Senales sonoras de ritmo (metronomo y plataformas que parpadean).
const KEY_RHYTHM_CUES: StringName = &"rhythm_sound_cues"
const DATA_PATH: String = "res://data/settings.json"
const KEY_WINDOW_MODE: StringName = &"window_mode"
const KEY_WINDOW_SIZE: StringName = &"window_size"
const WINDOW_MODE_WINDOWED: String = "windowed"
const WINDOW_MODE_FULLSCREEN: String = "fullscreen"
const WINDOW_MODES: Array[String] = [WINDOW_MODE_WINDOWED, WINDOW_MODE_FULLSCREEN]
## Mostrar las Q de la ayuda de Eco.
const KEY_SHOW_ECO_HELP: StringName = &"show_eco_help"
const SHOW_ECO_HELP_DEFAULT: bool = true
## Reducir los efectos de Sync Rate bajo (GameState.reduce_low_sync_effects).
const KEY_REDUCE_LOW_SYNC: StringName = &"reduce_low_sync_effects"
## Contorno de alto contraste del Debug (GameState.debug_high_contrast_outline).
const KEY_DEBUG_OUTLINE: StringName = &"debug_high_contrast_outline"
## Ajustes booleanos: clave -> [seccion, valor por defecto].
const BOOLS: Dictionary = {
	&"show_eco_help": [SECTION_HELP, SHOW_ECO_HELP_DEFAULT],
	&"reduce_low_sync_effects": [SECTION_ACCESSIBILITY, false],
	&"debug_high_contrast_outline": [SECTION_ACCESSIBILITY, false],
	&"rhythm_sound_cues": [SECTION_ACCESSIBILITY, true],
}
## Ajustes que se aplican a una propiedad de GameState del mismo nombre.
const GAME_STATE_KEYS: Array[StringName] = [&"reduce_low_sync_effects", &"debug_high_contrast_outline"]

static var _path: String = ""
static var _loaded: bool = false
static var _bools: Dictionary = {}
static var _window_mode: String = WINDOW_MODE_WINDOWED
static var _window_size: Vector2i = Vector2i.ZERO
static var _data: Dictionary = {}
## Volumen lineal (0-1) por bus de AUDIO_BUSES.
static var _volumes: Dictionary = {}


## Ruta segun los argumentos de Godot y ISAK_SETTINGS_PATH (como el guardado).
static func resolve_path(args: PackedStringArray, env_path: String) -> String:
	if not env_path.is_empty():
		return env_path
	if GameState.is_running_tests(args):
		return PATH_TESTS
	if GameState.is_running_script(args):
		return PATH_TOOLS
	return PATH_DEFAULT


## Ruta de los ajustes (la resuelve la primera vez).
static func settings_path() -> String:
	_ensure_loaded()
	return _path


## Usa `path` y carga sus ajustes; con `fresh`, borra antes el archivo (rutas
## de pruebas y herramientas) y quedan los valores por defecto.
static func use_path(path: String, fresh: bool = false) -> void:
	_path = path
	_loaded = true
	if fresh and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	load_from_disk()


## Vuelve a leer los ajustes del disco (sin archivo: valores por defecto).
## (No se llama reload: GameSettings.reload() desde fuera llamaria a
## GDScript.reload() del recurso del script y borraria su estado estatico.)
static func load_from_disk() -> void:
	_ensure_path()
	var config := ConfigFile.new()
	var loaded: bool = FileAccess.file_exists(_path) and config.load(_path) == OK
	for key: StringName in BOOLS:
		var spec: Array = BOOLS[key]
		var value: Variant = config.get_value(String(spec[0]), String(key), spec[1]) if loaded else spec[1]
		_bools[key] = value if value is bool else bool(spec[1])
	_apply_game_state()
	_window_mode = WINDOW_MODE_WINDOWED
	_window_size = base_size()
	if loaded:
		var mode: Variant = config.get_value(SECTION_DISPLAY, String(KEY_WINDOW_MODE), WINDOW_MODE_WINDOWED)
		if mode is String and WINDOW_MODES.has(mode as String):
			_window_mode = mode as String
		var stored: Variant = config.get_value(SECTION_DISPLAY, String(KEY_WINDOW_SIZE), base_size())
		if stored is Vector2i and window_presets().has(stored as Vector2i):
			_window_size = stored as Vector2i
	var controls: Dictionary = {}
	if loaded and config.has_section(SECTION_CONTROLS):
		for key: String in config.get_section_keys(SECTION_CONTROLS):
			controls[key] = config.get_value(SECTION_CONTROLS, key)
	ControlBindings.apply_overrides(controls)
	for bus: StringName in AUDIO_BUSES:
		var stored_volume: Variant = config.get_value(SECTION_AUDIO, volume_key(bus), volume_default(bus)) if loaded \
			else volume_default(bus)
		_volumes[bus] = _clean_volume(stored_volume, volume_default(bus))
	apply_audio()
	if not is_display_default():
		apply_display()


## Valores por defecto en memoria (no escribe). Para pruebas.
static func reset_defaults() -> void:
	_ensure_path()
	for key: StringName in BOOLS:
		_bools[key] = bool(BOOLS[key][1])
	_apply_game_state()
	_window_mode = WINDOW_MODE_WINDOWED
	_window_size = base_size()
	ControlBindings.restore_defaults(false)
	EventBus.controls_changed.emit()
	for bus: StringName in AUDIO_BUSES:
		_volumes[bus] = volume_default(bus)
	apply_audio()


## Escribe todos los ajustes en su archivo. Falso si no se pudo.
static func save() -> bool:
	_ensure_path()
	var config := ConfigFile.new()
	for key: StringName in BOOLS:
		config.set_value(String(BOOLS[key][0]), String(key), _bools.get(key, BOOLS[key][1]))
	config.set_value(SECTION_DISPLAY, String(KEY_WINDOW_MODE), _window_mode)
	config.set_value(SECTION_DISPLAY, String(KEY_WINDOW_SIZE), _window_size)
	for bus: StringName in AUDIO_BUSES:
		config.set_value(SECTION_AUDIO, volume_key(bus), get_volume(bus))
	var controls: Dictionary = ControlBindings.overrides()
	for action: Variant in controls:
		config.set_value(SECTION_CONTROLS, String(action), controls[action])
	var error: Error = config.save(_path)
	if error != OK:
		push_warning("GameSettings: no se pudieron guardar los ajustes en '%s' (%s)." % [_path, error_string(error)])
		return false
	return true


## Se muestran las Q de la ayuda de Eco.
static func is_eco_help_shown() -> bool:
	return get_bool(KEY_SHOW_ECO_HELP)


## Cambia «Ayudas de Eco» y lo guarda al instante. Devuelve verdadero si cambio.
static func set_eco_help_shown(value: bool) -> bool:
	return set_bool(KEY_SHOW_ECO_HELP, value)


## «Efectos de Sync bajo: Reducidos».
static func is_low_sync_reduced() -> bool:
	return get_bool(KEY_REDUCE_LOW_SYNC)


static func set_low_sync_reduced(value: bool) -> bool:
	return set_bool(KEY_REDUCE_LOW_SYNC, value)


## «Contorno del Debug: Alto contraste».
static func is_debug_outline_high_contrast() -> bool:
	return get_bool(KEY_DEBUG_OUTLINE)


static func set_debug_outline_high_contrast(value: bool) -> bool:
	return set_bool(KEY_DEBUG_OUTLINE, value)


## Valor de un ajuste booleano de BOOLS.
static func get_bool(key: StringName) -> bool:
	_ensure_loaded()
	return bool(_bools.get(key, BOOLS.get(key, [null, false])[1]))


## Cambia un ajuste booleano, lo guarda al instante y lo aplica (los de
## GAME_STATE_KEYS, a GameState). Devuelve verdadero si cambio.
static func set_bool(key: StringName, value: bool) -> bool:
	_ensure_loaded()
	if not BOOLS.has(key) or value == get_bool(key):
		return false
	_bools[key] = value
	save()
	_apply_game_state()
	EventBus.settings_changed.emit(key, value)
	return true


# --- Sonido ---

## «Senales sonoras de ritmo: Si» (por defecto).
static func are_rhythm_cues_enabled() -> bool:
	return get_bool(KEY_RHYTHM_CUES)


static func set_rhythm_cues_enabled(value: bool) -> bool:
	return set_bool(KEY_RHYTHM_CUES, value)


## Clave del volumen de `bus` en la seccion audio («volume_music»).
static func volume_key(bus: StringName) -> String:
	return "volume_%s" % String(bus).to_lower()


## Volumen por defecto de `bus` (data/settings.json, audio.defaults; si no, 1).
static func volume_default(bus: StringName) -> float:
	var defaults: Variant = _settings_data().get("audio", {}).get("defaults", {})
	var value: Variant = (defaults as Dictionary).get(String(bus), VOLUME_DEFAULT) if defaults is Dictionary else VOLUME_DEFAULT
	return _clean_volume(value, VOLUME_DEFAULT)


## Paso de los volumenes en Ajustes > Sonido (data/settings.json, audio.step).
static func volume_step() -> float:
	var step: float = float(_settings_data().get("audio", {}).get("step", VOLUME_STEP_DEFAULT))
	return step if step > 0.0 and step <= 1.0 else VOLUME_STEP_DEFAULT


## Nombre de `bus` en la UI (data/settings.json, audio.buses; si no, el del bus).
static func volume_label(bus: StringName) -> String:
	var buses: Variant = _settings_data().get("audio", {}).get("buses", [])
	if buses is Array:
		for item: Variant in buses:
			if item is Dictionary and String((item as Dictionary).get("bus", "")) == String(bus):
				return String((item as Dictionary).get("name", bus))
	return String(bus)


## Volumen lineal (0-1) de `bus` (uno de AUDIO_BUSES).
static func get_volume(bus: StringName) -> float:
	_ensure_loaded()
	return float(_volumes.get(bus, volume_default(bus)))


## Cambia el volumen de `bus` (se ajusta a 0-1 y al paso), lo guarda al instante
## y lo aplica al AudioServer. Verdadero si cambio.
static func set_volume(bus: StringName, value: float) -> bool:
	_ensure_loaded()
	if not AUDIO_BUSES.has(bus):
		return false
	var clean: float = _clean_volume(value, get_volume(bus))
	if is_equal_approx(clean, get_volume(bus)):
		return false
	_volumes[bus] = clean
	save()
	apply_audio()
	EventBus.settings_changed.emit(StringName(volume_key(bus)), clean)
	return true


## Lleva los volumenes al AudioServer (los buses que no existan se ignoran).
static func apply_audio() -> void:
	_ensure_loaded()
	for bus: StringName in AUDIO_BUSES:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var volume: float = float(_volumes.get(bus, VOLUME_DEFAULT))
		AudioServer.set_bus_mute(index, volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


## Numero entre 0 y 1 redondeado al paso; `fallback` si no es un numero.
static func _clean_volume(value: Variant, fallback: float) -> float:
	if not (value is float or value is int):
		return fallback
	var step: float = volume_step()
	return clampf(snappedf(float(value), step), 0.0, 1.0)


# --- Pantalla ---

## Resolucion base del juego (project.godot: 1280x720).
static func base_size() -> Vector2i:
	return Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))


## Tamanos de ventana de data/settings.json (la base siempre, la primera).
static func window_presets() -> Array[Vector2i]:
	var out: Array[Vector2i] = [base_size()]
	var raw: Variant = _settings_data().get("display", {}).get("window_presets", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Array and (item as Array).size() >= 2:
				var size := Vector2i(int(item[0]), int(item[1]))
				if size.x >= out[0].x and size.y >= out[0].y and not out.has(size):
					out.append(size)
	return out


## Tamanos que caben en una pantalla de `screen` px (nunca uno mayor; la base
## siempre). Pantalla desconocida (0x0, sin ventana): todos.
static func available_presets(screen: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for size: Vector2i in window_presets():
		if screen.x <= 0 or screen.y <= 0 or (size.x <= screen.x and size.y <= screen.y) or size == base_size():
			out.append(size)
	return out


## Tamano de la pantalla en que esta la ventana (0x0 sin ventana).
static func screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


## Area que puede ocupar el CONTENIDO de una ventana sin que el sistema la
## recorte: el area util de la pantalla (sin barra de menus ni Dock) menos los
## bordes y la barra de titulo de la ventana (0x0 sin ventana). En macOS, una
## ventana de 1920x1080 en un monitor de 1920x1080 se queda en 1920x924: no se
## ofrece (2026-10-20, «cambio la resolucion y se queda igual»).
static func window_area() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	return fit_area(usable, window_decorations())


## Tamano de los bordes y la barra de titulo de la ventana (0x0 en pantalla
## completa o sin ventana).
static func window_decorations() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	return (DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()).max(Vector2i.ZERO)


## Area util `usable` menos los bordes `decorations` (nunca negativa).
static func fit_area(usable: Vector2i, decorations: Vector2i) -> Vector2i:
	return (usable - decorations.max(Vector2i.ZERO)).max(Vector2i.ZERO)


## Factor de escala ENTERO con que se ve el juego en un area de `area` px.
static func integer_scale(area: Vector2i) -> int:
	var base: Vector2i = base_size()
	return maxi(1, mini(area.x / base.x, area.y / base.y))


## Con el factor entero, el juego no llena `area` (quedan bordes negros).
static func has_letterbox(area: Vector2i) -> bool:
	var scale_factor: int = integer_scale(area)
	return area != base_size() * scale_factor


static func get_window_mode() -> String:
	_ensure_loaded()
	return _window_mode


static func is_fullscreen() -> bool:
	return get_window_mode() == WINDOW_MODE_FULLSCREEN


static func get_window_size() -> Vector2i:
	_ensure_loaded()
	return _window_size


## Ventana de 1280x720: el comportamiento de siempre.
static func is_display_default() -> bool:
	return _window_mode == WINDOW_MODE_WINDOWED and _window_size == base_size()


## Cambia el modo (WINDOW_MODES), lo guarda y lo aplica. Verdadero si cambio.
static func set_window_mode(mode: String) -> bool:
	_ensure_loaded()
	if not WINDOW_MODES.has(mode) or mode == _window_mode:
		return false
	_window_mode = mode
	save()
	apply_display()
	EventBus.settings_changed.emit(KEY_WINDOW_MODE, mode)
	return true


static func set_fullscreen(value: bool) -> bool:
	return set_window_mode(WINDOW_MODE_FULLSCREEN if value else WINDOW_MODE_WINDOWED)


## Cambia el tamano de la ventana (uno de window_presets), lo guarda y lo
## aplica (en pantalla completa se usara al volver a la ventana).
static func set_window_size(size: Vector2i) -> bool:
	_ensure_loaded()
	if not window_presets().has(size) or size == _window_size:
		return false
	_window_size = size
	save()
	apply_display()
	EventBus.settings_changed.emit(KEY_WINDOW_SIZE, size)
	return true


## Se puede tocar la ventana real: juego normal con ventana (nunca en GUT, con
## scripts -s ni headless).
static func can_change_window() -> bool:
	return DisplayServer.get_name() != "headless" and not GameState.is_running_tests() \
		and not GameState.is_running_script()


## Aplica modo y tamano a la ventana. Falso si no se puede (can_change_window).
static func apply_display() -> bool:
	if not can_change_window():
		return false
	if _window_mode == WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return true
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen: int = DisplayServer.window_get_current_screen()
	var size: Vector2i = _window_size
	if not available_presets(window_area()).has(size):
		size = base_size()
	DisplayServer.window_set_size(size)
	# Centrada con la barra de titulo dentro del area util (sin salirse por arriba).
	var area: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var outer: Vector2i = size + window_decorations()
	DisplayServer.window_set_position(area.position + ((area.size - outer) / 2).max(Vector2i.ZERO))
	return true


static func _settings_data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"_": true}
	return _data


## Lleva los ajustes de accesibilidad a GameState (que avisa al HUD y a las
## plataformas ocultas) solo si cambian.
static func _apply_game_state() -> void:
	for key: StringName in GAME_STATE_KEYS:
		var value: bool = bool(_bools.get(key, BOOLS[key][1]))
		if bool(GameState.get(key)) != value:
			GameState.set(key, value)


static func _ensure_path() -> void:
	if _path.is_empty():
		_path = resolve_path(OS.get_cmdline_args(), OS.get_environment(PATH_ENV))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	load_from_disk()
