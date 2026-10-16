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
}
## Ajustes que se aplican a una propiedad de GameState del mismo nombre.
const GAME_STATE_KEYS: Array[StringName] = [&"reduce_low_sync_effects", &"debug_high_contrast_outline"]

static var _path: String = ""
static var _loaded: bool = false
static var _bools: Dictionary = {}


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
	reload()


## Vuelve a leer los ajustes del disco (sin archivo: valores por defecto).
static func reload() -> void:
	_ensure_path()
	var config := ConfigFile.new()
	var loaded: bool = FileAccess.file_exists(_path) and config.load(_path) == OK
	for key: StringName in BOOLS:
		var spec: Array = BOOLS[key]
		var value: Variant = config.get_value(String(spec[0]), String(key), spec[1]) if loaded else spec[1]
		_bools[key] = value if value is bool else bool(spec[1])
	_apply_game_state()


## Valores por defecto en memoria (no escribe). Para pruebas.
static func reset_defaults() -> void:
	_ensure_path()
	for key: StringName in BOOLS:
		_bools[key] = bool(BOOLS[key][1])
	_apply_game_state()


## Escribe todos los ajustes en su archivo. Falso si no se pudo.
static func save() -> bool:
	_ensure_path()
	var config := ConfigFile.new()
	for key: StringName in BOOLS:
		config.set_value(String(BOOLS[key][0]), String(key), _bools.get(key, BOOLS[key][1]))
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
	reload()
